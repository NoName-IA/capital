class_name Customer
extends RefCounted
## Cliente: sigue un camino por la vereda, entra, toma el producto de la repisa, hace fila, paga (o se va enojado
## si no lo atienden). Con el producto en la mano a veces duda: le pregunta a otro cliente si comprarlo, llama por
## teléfono, mira el precio, compara, se saca una foto o le pide consejo a un empleado; según la respuesta lo
## compra o lo devuelve a la repisa. En la calle los peatones conversan, miran tus vitrinas, sacan el paraguas si
## llueve y comentan el clima. Todo eso es para que la ciudad se vea viva: las ventas las calcula la simulación.

const SIDEWALK := 7.5
const MAX_SCENES := 4      # conversaciones a la vez en toda la ciudad (para que no sea un griterío)

static var scenes := 0

var city
var store = null
var angry := false
var body: Person
var path := []
var away := []
var state := "leave"
var line = null
var wait := 0.0
var done := false
var dog: Dog = null   # algunos peatones pasean a su perro
var buy_at = null     # peatón que se detiene a comprar en ELDIARIO
var pick_at = null    # [lugar frente a la repisa, hacia dónde mira]
var last_pick = null  # la repisa de donde sacó el producto (para devolverlo)
# Conversaciones: pasos [quién habla (Person), texto, color, segundos] y qué hace al terminar
var scene := []
var scene_t := 0.0
var after := ""
var partner = null    # el otro Customer de la conversación
var resume := ""      # estado al que vuelve quien escuchaba
var face_to = null    # a quién mira mientras habla o escucha
var chatted := false  # cada peatón conversa una vez como mucho
var windowed := false # ya miró una vitrina
var weather_said := false
var annoyed := 0.0    # segundos que el jugador le tapa el paso
var punch_t := 0.0    # > 0 mientras te empuja por no dejarlo pasar
var pusher := randf() < 0.45   # no todos empujan: los demás solo piden permiso y protestan
var push_dir := Vector3.ZERO   # hacia dónde te empuja (fuera de su camino)
var chair := -1                # la silla del local donde se sienta a comer (índice en store.spots.chairs)
var sit_time := 0.0            # cuánto se queda sentado

const SIT_CHANCE := 0.5        # de los que compran en un local con mesas, cuántos se sientan a comer ahí


func _init(owner_city, target_store = null, is_angry := false) -> void:
	city = owner_city
	store = target_store
	angry = is_angry
	var side: float = (1.0 if randf() < 0.5 else -1.0) if store == null else float(store.plot[1])
	var start_x: float
	if store:
		var fx: float = store.spots.front.x
		start_x = clampf(fx + (1 if randf() < 0.5 else -1) * randf_range(25, 60), -98, 152)
		path = [Vector3(fx, 0, side * SIDEWALK)]
		if store.spots.get("door") != null:
			path.append(store.spots.door)
		var pick: Array = store.pick_spot()
		if not pick.is_empty():  # primero elige el producto en la repisa
			var lx: float = (pick[0].x - store.plot[0]) * store.plot[1]
			if store.loc.size == 2:  # entra al pasillo por delante de las góndolas
				path.append(Blueprints.to_world(store.plot, lx, 4.0))
			path.append(pick[0])
			pick_at = pick
		away = [store.spots.front, Vector3(fx, 0, side * SIDEWALK),
				Vector3(clampf(fx + (1 if randf() < 0.5 else -1) * randf_range(30, 70), -99, 153), 0, side * SIDEWALK)]
		state = "enter"
	else:
		# Peatón que pasa de una punta de la avenida a la otra
		start_x = -99.0 if randf() < 0.5 else 153.0
		var end_x := 153.0 if start_x < 0 else -99.0
		path = [Vector3(end_x, 0, side * (SIDEWALK + randf_range(-0.8, 0.8)))]
		if side > 0 and randf() < 0.3:  # de pasada compra el diario en el kiosco
			buy_at = WorldBuilder.DIARIO_BUY
			var walk := Vector3(buy_at.x, 0, SIDEWALK)
			path = [walk, buy_at, walk] + path
	body = Person.new()
	city.add_child(body)
	body.position = Vector3(start_x, 0, side * SIDEWALK)
	if store == null and randf() < 0.4:
		dog = Dog.new(body)
		city.add_child(dog)
		dog.position = body.position + Vector3(0.7, 0, 0)
	if store == null and _raining() and randf() < 0.7:
		body.hold("paraguas")


func _raining() -> bool:
	return city.game != null and city.game.weather in [3, 5]


func leave(path_extra := []) -> void:
	if line != null and self in line.members:
		line.members.erase(self)
	line = null
	path = path_extra + away
	state = "leave"


func busy() -> bool:
	return state in ["talk", "listen", "window", "putback"]


func update(dt: float) -> void:
	if dog:
		dog.update(dt)
	match state:
		"talk":
			_update_talk(dt)
			return
		"listen":
			_face(dt)
			body.animate(0, dt)
			return
		"window":
			wait += dt
			_face(dt)
			body.animate(0, dt)
			if wait > 1.8:
				face_to = null
				state = "leave"
			return
		"putback":
			wait += dt
			body.animate(0, dt)
			body.rotation.y = lerp_angle(body.rotation.y, last_pick[1], dt * 8)
			body.set_reach(sin(clampf(wait / 0.8, 0.0, 1.0) * PI) * 0.8)
			if wait > 0.4 and body.item:
				body.hold("")
				store.put_back(body.position)
			if wait > 0.8:
				leave(_exit_path())
			return
	if state == "queue":
		var idx: int = line.members.find(self)
		var target: Vector3 = line.slots[min(idx, line.slots.size() - 1)]
		if not step_to(target, dt, 2.2):
			body.rotation.y = lerp_angle(body.rotation.y, store.spots.face_yaw + PI, dt * 8)
			wait += dt
			_queue_chatter(idx, dt)
			if angry and wait > 4.0:
				city.complain(body.position, store)
				leave(line.exit)
			elif idx == 0 and not angry:
				var server: Person = store.server_for(line)
				var t: float = store.service_time()
				if server != null and server != city.player:
					store.serve(server, body.position, wait / t, dt)
				if wait >= t:
					city.pay(store, body.position)
					if not store.has_shelves() and server != null:   # en el puesto sale del mostrador
						store.take_item(server.position)
					if server != null and server != city.player:
						server.hold("")
					body.hold(store.loc.product)  # se lleva lo que compró
					if not _go_sit(line.exit):    # algunos se sientan a comer; si no hay silla libre, se van
						leave(line.exit)
		return
	if state == "buying":
		_buy_diario(dt)
		return
	if state == "seated":
		_eat(dt)
		return
	if state == "picking":
		wait += dt
		body.animate(0, dt)
		body.rotation.y = lerp_angle(body.rotation.y, pick_at[1], dt * 8)
		body.set_reach(sin(clampf(wait / 0.9, 0.0, 1.0) * PI) * 0.8)   # estira la mano a la repisa
		if wait > 0.9:
			store.take_item(body.position)
			body.hold(store.loc.product)
			last_pick = pick_at
			pick_at = null
			if not _maybe_doubt():
				_go_to_line()
		return
	if path.is_empty():
		if state == "enter":
			join_line()
		elif state == "to_seat":
			state = "seated"
			wait = 0.0
		else:
			done = true
		return
	if store == null:
		_street_life()
		if busy():
			return
	var speed := 2.4
	if state == "leave" and angry:
		speed = 3.0
	elif store == null and _raining() and body.item == null:
		speed = 3.6  # sin paraguas, corre para no mojarse
	if not step_to(path[0], dt, speed):
		if buy_at != null and path[0] == buy_at:
			state = "buying"
			wait = 0.0
		elif pick_at != null and path[0] == pick_at[0]:
			state = "picking"
			wait = 0.0
		path.pop_front()


# ---------- sentarse a comer ----------
## Después de pagar, a veces va a una silla libre del local a comer lo que compró. Devuelve false si no se sienta
## (no le dieron ganas, el local no tiene mesas o están todas ocupadas).
func _go_sit(exit: Array) -> bool:
	if store.spots.get("chairs", []).is_empty() or randf() > SIT_CHANCE:
		return false
	chair = store.free_chair()
	if chair < 0:
		return false
	store.seated[chair] = self
	if line != null and self in line.members:
		line.members.erase(self)
	line = null
	var c: Dictionary = store.spots.chairs[chair]
	# En la megatienda baja primero por el pasillo de su fila (si no, atravesaría las góndolas)
	path = ([exit[0], exit[1]] if store.loc.size == 2 else [exit[0]]) + [c.near, c.seat]
	state = "to_seat"
	sit_time = randf_range(9.0, 16.0)
	return true


## Sentado frente a la mesa: se acomoda, come a bocados y al terminar se para, suelta la silla y sale por la puerta.
func _eat(dt: float) -> void:
	var c: Dictionary = store.spots.chairs[chair]
	wait += dt
	body.animate(0, dt)
	var d: Vector3 = c.table - c.seat
	body.rotation.y = lerp_angle(body.rotation.y, atan2(d.x, d.z), dt * 8)
	if wait < 0.5:
		body.position = body.position.lerp(Vector3(c.seat.x, 0, c.seat.z), min(1.0, dt * 8))
	if body.item:   # un bocado cada tanto (la mano a la boca y de vuelta)
		body.set_reach(0.35 + 0.5 * pow(maxf(0.0, sin(wait * 1.6)), 4))
		if wait > sit_time * 0.8:
			body.hold("")   # se lo terminó
	else:
		body.set_reach(0.0)
	body.sit(clampf(wait / 0.5, 0, 1) * clampf((sit_time - wait) / 0.5, 0, 1))
	if wait > 1.2 and wait - dt <= 1.2 and randf() < 0.3 and not body.camera_far():
		city.say(body, ["¡Qué rico!", "Justo lo que necesitaba.", "Mmm...", "Aquí se está bien."].pick_random(), "white", 1.8)
	if wait >= sit_time:
		body.sit(0.0)
		store.seated.erase(chair)
		chair = -1
		var out: Array = [c.near]
		if store.spots.get("door") != null:
			out.append(store.spots.door)
		leave(out)


func _go_to_line() -> void:
	if store.loc.size == 2:  # sale del pasillo por detrás de las góndolas antes de ir a la fila
		var lx: float = (body.position.x - store.plot[0]) * store.plot[1]
		path = [Blueprints.to_world(store.plot, lx, 11.0)]
	else:
		path = []
	state = "enter"


## Camino para salir del local desde la repisa sin atravesar paredes.
func _exit_path() -> Array:
	var out := []
	if store.loc.size == 2:
		var lx: float = (body.position.x - store.plot[0]) * store.plot[1]
		out.append(Blueprints.to_world(store.plot, lx, 4.0))
	if store.spots.get("door") != null:
		out.append(store.spots.door)
	return out


# ---------- dudas con el producto en la mano ----------
## Con el producto recién sacado de la repisa, a veces el cliente duda y hace algo antes de decidir.
## Devuelve true si empezó una escena (la escena decide si va a la fila o lo devuelve).
func _maybe_doubt() -> bool:
	if scenes >= MAX_SCENES or randf() > 0.45 or body.camera_far():
		return false
	var p: Dictionary = city.game.products[store.loc.product]
	var stars := Game.stars_of(store.loc)
	var options := [["phone", 2.0], ["price", 2.0], ["staff", 1.0]]
	var friend = _find_partner(7.0, true)
	if friend != null:
		options.append(["friend", 4.0])
	if stars >= 4.0:
		options.append(["selfie", 1.5])
	if store.loc.size == 1:
		options.append(["compare", 1.2])
	var total := 0.0
	for o in options:
		total += o[1]
	var r := randf() * total
	var pick: String = options[0][0]
	for o in options:
		r -= o[1]
		if r <= 0:
			pick = o[0]
			break
	var buy: bool = randf() < city.buy_chance(store)
	var name: String = Lang.noun(D.PRODUCTS[store.loc.product].name)
	var price := Fmt.money(p.price, 2 if p.price < 100 else 0)
	var me := body
	match pick:
		"friend":
			var yes := [["¡Sí! Yo siempre compro acá.", "green"], ["¡Llévalo, está buenísimo!", "green"],
					[Lang.f("Este local tiene %s estrellas, confía.", Fmt.num(stars, 1)), "green"], ["A ese precio, ni lo pienses.", "green"]]
			var no := [["Mmm... está caro para lo que es.", "orange"], ["Yo no lo compraría, dicen que es malo.", "red"],
					[Lang.f("Donde %s es más barato.", D.rival_for(store.loc.product).short), "orange"], ["Mejor no, ya comimos.", "orange"]]
			var ans: Array = (yes if buy else no).pick_random()
			_start([[me, ["¿Lo llevo? ¿Qué dices?", Lang.f("¿Este %s vale la pena?", name), "¿Tú has probado este?"].pick_random(), "white", 1.7],
					[friend.body, ans[0], ans[1], 2.0],
					[me, "¡Lo llevo!" if buy else "Tienes razón, lo dejo.", "green" if buy else "white", 1.4]],
					"line" if buy else "putback", friend)
		"phone":
			body.hold("celular")
			var who: String = ["mi amor", "mamá", "jefe", "compadre"].pick_random()
			_start([[me, Lang.f("Aló, %s... ¿compro %s?", [who, name]), "white", 1.9],
					[me, ["Ya, llevo uno.", "Ok, ok, lo llevo."].pick_random() if buy else ["¿Que no? Bueno, lo dejo.", "Ya, mejor no."].pick_random(),
					"green" if buy else "orange", 1.6]], "line" if buy else "putback")
		"price":
			var ratio: float = p.price / city.game.ref_price(p)
			var line_txt := Lang.f("¿%s? ¡Qué barato!", price) if ratio < 0.9 else (Lang.f("¿%s? Uf, carísimo...", price) if ratio > 1.2 else Lang.f("%s... está bien.", price))
			_start([[me, line_txt, "green" if ratio < 0.9 else ("red" if ratio > 1.2 else "white"), 1.9]], "line" if buy else "putback")
		"staff":
			var clerk: Person = store.server_for(store.spots.lines[0]) if store.spots.lines else null
			if clerk == null or clerk == city.player:
				_start([[me, "Mmm... ¿cuál será el mejor?", "white", 1.6]], "line")
			else:
				var tip: String = ["¡Ese es el más vendido!", "Ese salió hoy, fresquito.", "Le va a encantar.", "Llévese dos, sale mejor."].pick_random()
				_start([[me, "Disculpe, ¿este es bueno?", "white", 1.6], [clerk, tip, "gold", 1.8],
						[me, "¡Perfecto, gracias!" if buy else "Lo voy a pensar...", "green" if buy else "white", 1.3]],
						"line" if buy else "putback")
		"selfie":
			_start([[me, ["¡Foto para mis historias!", "¡Este local es lo máximo!", Lang.f("#%s", city.game.company.replace(" ", ""))].pick_random(), "gold", 2.0]], "line")
			body.set_reach(1.0)
		"compare":
			var other: Array = store.pick_spot()
			_start([[me, "Mmm... ¿este o el otro?", "white", 1.5]], "compare")
			after = "compare"
			last_pick = other if not other.is_empty() else last_pick
	return true


## Otro cliente cerca que no esté ocupado, para conversar.
func _find_partner(radius: float, same_store: bool):
	var best = null
	var best_d := radius
	for c in city.customers:
		if c == self or c.busy() or c.done or c.state == "queue":
			continue
		if same_store and c.store != store:
			continue
		if not same_store and c.store != null:
			continue
		var d: float = c.body.position.distance_to(body.position)
		if d < best_d:
			best = c
			best_d = d
	return best


func _start(steps: Array, what_next: String, other = null) -> void:
	scenes += 1
	scene = steps
	scene_t = 0.0
	after = what_next
	partner = other
	resume = state
	state = "talk"
	if other != null:
		other.resume = other.state
		other.state = "listen"
		other.face_to = body
		face_to = other.body
	if not steps.is_empty():
		city.say(steps[0][0], steps[0][1], steps[0][2], steps[0][3] + 0.3)


func _update_talk(dt: float) -> void:
	scene_t += dt
	body.animate(0, dt)
	_face(dt)
	if scene.is_empty() or scene_t < scene[0][3]:
		return
	scene.pop_front()
	scene_t = 0.0
	if not scene.is_empty():
		city.say(scene[0][0], scene[0][1], scene[0][2], scene[0][3] + 0.3)
		return
	_end_scene()


func _end_scene() -> void:
	scenes = max(0, scenes - 1)
	face_to = null
	if partner != null and is_instance_valid(partner.body) and partner.state == "listen":
		partner.state = partner.resume
		partner.face_to = null
	partner = null
	if body.item and body.item.mesh == Actors.product_item("celular", 0):
		body.hold(store.loc.product if store != null else "")
	body.set_reach(0.0)
	match after:
		"line":
			_go_to_line()
		"putback":
			state = "putback"
			wait = 0.0
		"compare":  # deja el primero y va a buscar otro a la otra repisa
			body.hold("")
			store.put_back(body.position)
			pick_at = last_pick
			path = [pick_at[0]]
			state = "enter"
		_:
			state = resume if resume != "" else "leave"


func _face(dt: float) -> void:
	if face_to != null and is_instance_valid(face_to):
		var d: Vector3 = face_to.position - body.position
		body.rotation.y = lerp_angle(body.rotation.y, atan2(d.x, d.z), dt * 8)


# ---------- en la fila ----------
func _queue_chatter(idx: int, dt: float) -> void:
	if idx < 2 or angry or randf() > dt * 0.05 or body.camera_far():
		return
	var lines := ["¡Esta fila no avanza!", "Vale la pena esperar, ya verás.", "¿Siempre está así de lleno?",
			"Dicen que este local es el mejor.", "¡Contraten más gente!"]
	if Game.stars_of(store.loc) >= 4.0:
		lines += [Lang.f("Con %s estrellas, normal que haya fila.", Fmt.num(Game.stars_of(store.loc), 1))]
	city.say(body, lines.pick_random(), "white" if randf() < 0.6 else "orange", 2.2)


# ---------- en la calle ----------
## Los peatones conversan, miran vitrinas y comentan el clima.
func _street_life() -> void:
	if body.camera_far():
		return
	var g = city.game
	if g == null:
		return
	# El clima: un comentario al pasar
	if not weather_said and randf() < 0.002:
		weather_said = true
		var by_weather := {0: ["¡Qué lindo día!", "Día perfecto para la playa."], 2: ["Se viene la lluvia...", "Qué día más gris."],
				3: ["¡Qué lluvia!", "¡Me estoy mojando!", "Hoy es día de café."], 4: ["¡Qué calor!", "¡Me derrito!", "Vamos a la playa."],
				5: ["¡Qué tormenta!", "¡Corran!", "¡Se corta la luz!"]}
		var opts: Array = by_weather.get(g.weather, [])
		if not opts.is_empty():
			city.say(body, opts.pick_random(), "white", 2.0)
	# Mirar la vitrina de un local tuyo al pasar
	if not windowed and scenes < MAX_SCENES:
		for st in city.stores.values():
			if body.position.distance_to(st.spots.front) < 1.6:
				windowed = true
				if randf() < 0.18:
					var stars := Game.stars_of(st.loc)
					var name := Lang.noun(D.PRODUCTS[st.loc.product].name)
					var txt: String = ([Lang.f("Mmm, se ve rico el %s...", name), Lang.f("¡%s estrellas! Tengo que probar.", Fmt.num(stars, 1))] if stars >= 3.5
							else ["Dicen que acá atienden mal.", "Mmm... no sé."]).pick_random()
					if st.loc.product in ["ropa", "tech"]:
						txt = ["¡Mira esa vitrina!", "Qué lindo eso..."].pick_random() if stars >= 3 else "Muy caro para mí."
					face_to = st.bld.root
					state = "window"
					wait = 0.0
					city.say(body, txt, "gold" if stars >= 3.5 else "white", 1.9)
				break
	# Conversar con otro peatón que viene
	if chatted or scenes >= MAX_SCENES or randf() > 0.02:
		return
	var other = _find_partner(2.4, false)
	if other == null or other.chatted:
		return
	chatted = true
	other.chatted = true
	_start(_street_talk(g, other), "", other)


## Una conversación corta entre dos peatones: sobre tus locales, el clima, la competencia o el diario.
func _street_talk(g, other) -> Array:
	var me := body
	var you: Person = other.body
	var kind := randi() % 4
	if g.locations.is_empty():
		kind = 1
	match kind:
		0:  # sobre uno de tus locales
			var loc: Dictionary = g.locations.pick_random()
			var name: String = Lang.noun(D.PRODUCTS[loc.product].name)
			var stars := Game.stars_of(loc)
			var good := stars >= 3.3
			return [[me, Lang.f("¿Probaste el %s de %s?", [name, g.company]), "white", 2.0],
					[you, [Lang.f("¡Sí! Tiene %s estrellas.", Fmt.num(stars, 1)), "Es mi favorito.", "¡Buenísimo y a buen precio!"].pick_random() if good
					else ["Uf, la fila era eterna.", "Me atendieron mal...", "Muy caro para lo que es."].pick_random(), "green" if good else "orange", 2.2],
					[me, "¡Voy a ir!" if good else "Entonces no voy.", "white", 1.4]]
		1:  # el clima
			var w: Dictionary = D.WEATHER[g.weather]
			var nxt: Dictionary = D.WEATHER[g.weather_next]
			return [[me, Lang.f("¿Viste el clima? %s.", w.name), "white", 1.8],
					[you, Lang.f("Dicen que en %d días viene %s.", [g.weather_days, Lang.noun(nxt.name)]), "white", 2.2]]
		2:  # la competencia
			var key: String = D.PRODUCT_ORDER.pick_random()
			var r: Dictionary = D.rival_for(key)
			return [[me, Lang.f("¿Supiste de %s?", r.company), "white", 1.7],
					[you, ["Dicen que va a abrir otro local.", Lang.f("¡%s siempre está peleando!", r.name), Lang.f("Prefiero a %s.", g.company)].pick_random(), "white", 2.2]]
		_:  # el diario
			var headline := ""
			for i in range(g.news.size() - 1, -1, -1):
				if g.news[i].kind in ["good", "bad", "info"] and not String(g.news[i].text).begins_with("Consejo"):
					headline = g.news[i].text
					break
			if headline.length() > 60:
				headline = headline.left(57) + "..."
			return [[me, "¿Leíste el diario?", "white", 1.5], [you, Lang.f("«%s»", headline) if headline else "No, ¿qué pasó?", "white", 2.6]]


## Compra en ELDIARIO: el vendedor se gira, saca un diario y se lo pasa; el peatón sigue caminando con él.
func _buy_diario(dt: float) -> void:
	wait += dt
	body.animate(0, dt)
	body.rotation.y = lerp_angle(body.rotation.y, 0.0, dt * 8)   # mirando al kiosco
	var seller: Person = city.builder.diario_seller
	var d := body.position - seller.position
	seller.rotation.y = lerp_angle(seller.rotation.y, atan2(d.x, d.z), dt * 6)
	if wait > 0.7:
		seller.hold("diario")
	seller.set_reach(smoothstep(0.7, 1.8, wait))
	if wait > 2.2:
		seller.hold("")
		seller.set_reach(0.0)
		seller.rotation.y = PI
		body.hold("diario")
		buy_at = null
		state = "leave"
		if randf() < 0.35:
			city.say(seller, ["¡Gracias, vuelva pronto!", "¡Que le vaya bien!", "Hoy viene buenísimo."].pick_random(), "white", 1.8)


## ¿Está por llegar a donde va? (cerca de su próximo punto: ahí no se lo aparta ni esquiva, para que pueda llegar
## aunque el lugar esté ocupado, como el kiosco o la misma repisa)
func near_goal() -> bool:
	if path.is_empty() or not is_instance_valid(body):
		return false
	var p: Vector3 = path[0]
	return Vector2(p.x - body.position.x, p.z - body.position.z).length() < 1.0


func step_to(target: Vector3, dt: float, speed: float) -> bool:
	if punch_t > 0:
		_punch(dt)
		return true
	var delta := Vector3(target.x - body.position.x, 0, target.z - body.position.z)
	var dist := delta.length()
	if dist < 0.08:
		body.animate(0, dt)
		return false
	var dir := delta.normalized()
	if _player_in_way(dir, dist, dt):
		return true
	# Si alguien está justo adelante, se corre hacia su derecha para pasarlo (como en la vereda)
	for other in city.customers:
		if other == self or not is_instance_valid(other.body):
			continue
		var o: Vector3 = other.body.position - body.position
		o.y = 0
		var od := o.length()
		if od > 0.05 and od < 1.1 and od < dist - 0.3 and dir.dot(o / od) > 0.75:   # solo si está antes del destino
			dir = (dir + Vector3(-dir.z, 0, dir.x) * 0.9 * (1.1 - od)).normalized()
			break
	body.position += dir * min(dist, speed * dt)
	body.rotation.y = lerp_angle(body.rotation.y, atan2(delta.x, delta.z), dt * 10)
	body.animate(speed, dt)
	return true


## Si el jugador se le pone adelante y no lo deja pasar: primero pide permiso, después grita y al final (solo los
## `pusher`) lo empuja fuera de su camino; los demás refunfuñan. Devuelve true si empezó a empujar (ese cuadro no camina).
const ASK_AFTER := 0.25
const SHOUT_AFTER := 0.6
const PUNCH_AFTER := 1.0

func _player_in_way(dir: Vector3, dist: float, dt: float) -> bool:
	var o: Vector3 = city.player.position - body.position
	var od := Vector2(o.x, o.z).length()
	if not city.can_be_shoved() or absf(o.y) > 1.0 or od > 1.0 or od > dist + 0.3 or Vector3(o.x, 0, o.z).dot(dir) < 0.5 * od:
		annoyed = max(0.0, annoyed - dt * 0.5)
		return false
	var before := annoyed
	annoyed += dt
	if before < ASK_AFTER and annoyed >= ASK_AFTER:
		city.say(body, ["Permiso...", "Con permiso.", "¿Me deja pasar?"].pick_random(), "white", 1.6)
	elif before < SHOUT_AFTER and annoyed >= SHOUT_AFTER:
		city.say(body, ["¡Muévete!", "¡Oye, quítate del medio!", "¡Que me dejes pasar!"].pick_random(), "orange", 1.6)
		city.sfx.play("angry", 0.5 * city.near(body.position), randf_range(0.9, 1.15))
	elif annoyed >= PUNCH_AFTER:
		annoyed = SHOUT_AFTER - 0.3   # si sigues ahí, en un momento vuelve a pasar
		if not pusher:
			city.say(body, ["Uf, qué gente...", "¿En serio?", "Ay, por favor..."].pick_random(), "orange", 1.6)
			return false
		# Te empuja hacia el costado (del lado donde ya estás), no hacia adelante: así te saca de su camino
		var side := Vector3(-dir.z, 0, dir.x)
		var lean := side.dot(o)
		push_dir = side * (signf(lean) if absf(lean) > 0.05 else [-1.0, 1.0].pick_random())
		punch_t = 0.5
		city.say(body, ["¡Toma!", "¡Te dije que te movieras!", "¡Quítate!"].pick_random(), "red", 1.8)
		return true
	return false


## Empujón con el brazo derecho: mira al jugador, estira el brazo y a mitad del golpe lo saca de su camino.
func _punch(dt: float) -> void:
	var before := punch_t
	punch_t -= dt
	var o: Vector3 = city.player.position - body.position
	body.rotation.y = lerp_angle(body.rotation.y, atan2(o.x, o.z), dt * 14)
	body.animate(0, dt)
	body.arms[1].rotation.x = deg_to_rad(-95.0 * sin(clampf(1.0 - punch_t / 0.5, 0.0, 1.0) * PI))
	if before > 0.25 and punch_t <= 0.25:
		city.shoved_by(push_dir)
	if punch_t <= 0:
		body.set_reach(0.45 if body.item else 0.0)


func join_line() -> void:
	var lines: Array = store.spots.lines
	var best = lines[0]
	for ln in lines:
		if ln.members.size() < best.members.size():
			best = ln
	if best.members.size() >= best.slots.size():
		city.complain(body.position, store)
		if body.item:
			body.hold("")
			store.put_back(body.position)
		leave()
		return
	best.members.append(self)
	line = best
	state = "queue"
	wait = 0.0
	# En los puestos (sin repisa) a veces piden consejo al llegar
	if not store.has_shelves() and randf() < 0.25 and not body.camera_far():
		city.say(body, ["¿Qué me recomienda?", "¡Lo de siempre!", "¿Qué hay de nuevo hoy?"].pick_random(), "white", 1.8)


func destroy() -> void:
	if state == "talk":
		scenes = max(0, scenes - 1)
		if partner != null and partner.state == "listen":
			partner.state = partner.resume
			partner.face_to = null
	if dog:
		dog.destroy()
	if line != null and self in line.members:
		line.members.erase(self)
	if chair >= 0 and store != null and store.seated.get(chair) == self:
		store.seated.erase(chair)
	body.queue_free()
