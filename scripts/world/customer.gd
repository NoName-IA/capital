class_name Customer
extends RefCounted
## Cliente: sigue un camino por la vereda, entra, hace fila, paga (o se va enojado si no lo atienden).

const SIDEWALK := 7.5

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


func leave(path_extra := []) -> void:
	if line != null and self in line.members:
		line.members.erase(self)
	line = null
	path = path_extra + away
	state = "leave"


func update(dt: float) -> void:
	if dog:
		dog.update(dt)
	if state == "queue":
		var idx: int = line.members.find(self)
		var target: Vector3 = line.slots[min(idx, line.slots.size() - 1)]
		if not step_to(target, dt, 2.2):
			body.rotation.y = lerp_angle(body.rotation.y, store.spots.face_yaw + PI, dt * 8)
			wait += dt
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
			store.take_item()
			body.hold(store.loc.product)
			if store.loc.size == 2:  # sale del pasillo por detrás de las góndolas antes de ir a la fila
				var lx: float = (body.position.x - store.plot[0]) * store.plot[1]
				path = [Blueprints.to_world(store.plot, lx, 11.0)]
			pick_at = null
			state = "enter"
		return
	if path.is_empty():
		if state == "enter":
			join_line()
		else:
			done = true
		return
	if not step_to(path[0], dt, 3.0 if state == "leave" and angry else 2.4):
		if buy_at != null and path[0] == buy_at:
			state = "buying"
			wait = 0.0
		elif pick_at != null and path[0] == pick_at[0]:
			state = "picking"
			wait = 0.0
		path.pop_front()


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
		leave()
		return
	best.members.append(self)
	line = best
	state = "queue"
	wait = 0.0


func destroy() -> void:
	if dog:
		dog.destroy()
	if line != null and self in line.members:
		line.members.erase(self)
	body.queue_free()
