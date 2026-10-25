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
					leave(line.exit)
		return
	if state == "buying":
		_buy_diario(dt)
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
	var name: String = D.PRODUCTS[store.loc.product].name.to_lower()
	var price := Fmt.money(p.price, 2 if p.price < 100 else 0)
	var me := body
	match pick:
		"friend":
			var yes := [["¡Sí! Yo siempre compro acá.", "green"], ["¡Llévalo, está buenísimo!", "green"],
					["Este local tiene %s estrellas, confía." % Fmt.num(stars, 1), "green"], ["A ese precio, ni lo pienses.", "green"]]
			var no := [["Mmm... está caro para lo que es.", "orange"], ["Yo no lo compraría, dicen que es malo.", "red"],
					["Donde %s es más barato." % D.rival_for(store.loc.product).short, "orange"], ["Mejor no, ya comimos.", "orange"]]
			var ans: Array = (yes if buy else no).pick_random()
			_start([[me, ["¿Lo llevo? ¿Qué dices?", "¿Este %s vale la pena?" % name, "¿Tú has probado este?"].pick_random(), "white", 1.7],
					[friend.body, ans[0], ans[1], 2.0],
					[me, "¡Lo llevo!" if buy else "Tienes razón, lo dejo.", "green" if buy else "white", 1.4]],
					"line" if buy else "putback", friend)
		"phone":
			body.hold("celular")
			var who: String = ["mi amor", "mamá", "jefe", "compadre"].pick_random()
			_start([[me, "Aló, %s... ¿compro %s?" % [who, name], "white", 1.9],
					[me, ["Ya, llevo uno.", "Ok, ok, lo llevo."].pick_random() if buy else ["¿Que no? Bueno, lo dejo.", "Ya, mejor no."].pick_random(),
					"green" if buy else "orange", 1.6]], "line" if buy else "putback")
		"price":
			var ratio: float = p.price / city.game.ref_price(p)
			var line_txt := "¿%s? ¡Qué barato!" % price if ratio < 0.9 else ("¿%s? Uf, carísimo..." % price if ratio > 1.2 else "%s... está bien." % price)
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
			_start([[me, ["¡Foto para mis historias!", "¡Este local es lo máximo!", "#%s" % city.game.company.replace(" ", "")].pick_random(), "gold", 2.0]], "line")
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
		lines += ["Con %s estrellas, normal que haya fila." % Fmt.num(Game.stars_of(store.loc), 1)]
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
					var name: String = D.PRODUCTS[st.loc.product].name.to_lower()
					var txt: String = (["Mmm, se ve rico...", "¡%s estrellas! Tengo que probar." % Fmt.num(stars, 1)] if stars >= 3.5
							else ["Dicen que acá atienden mal.", "Mmm... no sé."]).pick_random()
					if st.loc.product in ["ropa", "tech"]:
						txt = ["¡Mira esa vitrina!", "Qué lindo eso..."].pick_random() if stars >= 3 else "Muy caro para mí."
					face_to = st.bld.root
					state = "window"
					wait = 0.0
					city.say(body, txt.replace("rico", "rico el %s" % name) if txt.begins_with("Mmm, se ve") else txt,
							"gold" if stars >= 3.5 else "white", 1.9)
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
			var name: String = D.PRODUCTS[loc.product].name.to_lower()
			var stars := Game.stars_of(loc)
			var good := stars >= 3.3
			return [[me, "¿Probaste el %s de %s?" % [name, g.company], "white", 2.0],
					[you, ["¡Sí! Tiene %s estrellas." % Fmt.num(stars, 1), "Es mi favorito.", "¡Buenísimo y a buen precio!"].pick_random() if good
					else ["Uf, la fila era eterna.", "Me atendieron mal...", "Muy caro para lo que es."].pick_random(), "green" if good else "orange", 2.2],
					[me, "¡Voy a ir!" if good else "Entonces no voy.", "white", 1.4]]
		1:  # el clima
			var w: Dictionary = D.WEATHER[g.weather]
			var nxt: Dictionary = D.WEATHER[g.weather_next]
			return [[me, "¿Viste el clima? %s." % w.name, "white", 1.8],
					[you, "Dicen que en %d días viene %s." % [g.weather_days, nxt.name.to_lower()], "white", 2.2]]
		2:  # la competencia
			var key: String = D.PRODUCT_ORDER.pick_random()
			var r: Dictionary = D.rival_for(key)
			return [[me, "¿Supiste de %s?" % r.company, "white", 1.7],
					[you, ["Dicen que va a abrir otro local.", "¡%s siempre está peleando!" % r.name, "Prefiero a %s." % g.company].pick_random(), "white", 2.2]]
		_:  # el diario
			var headline := ""
			for i in range(g.news.size() - 1, -1, -1):
				if g.news[i].kind in ["good", "bad", "info"] and not String(g.news[i].text).begins_with("Consejo"):
					headline = g.news[i].text
					break
			if headline.length() > 60:
				headline = headline.left(57) + "..."
			return [[me, "¿Leíste el diario?", "white", 1.5], [you, "«%s»" % headline if headline else "No, ¿qué pasó?", "white", 2.6]]


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


func step_to(target: Vector3, dt: float, speed: float) -> bool:
	var delta := Vector3(target.x - body.position.x, 0, target.z - body.position.z)
	var dist := delta.length()
	if dist < 0.08:
		body.animate(0, dt)
		return false
	body.position += delta.normalized() * min(dist, speed * dt)
	body.rotation.y = lerp_angle(body.rotation.y, atan2(delta.x, delta.z), dt * 10)
	body.animate(speed, dt)
	return true


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
	body.queue_free()
