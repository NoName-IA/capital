class_name Store
extends RefCounted
## Un local tuyo en un terreno de la avenida: edificio, empleados, estrellas de reputación y filas de clientes.

var city
var plot_index: int
var plot: Array
var loc: Dictionary
var sig: Array
var bld: Building
var rects: Array
var spots: Dictionary
var staff := []
var acc := randf()
var rep: Label3D
var rep_value := -1
var shelf := []                   # los productos en las repisas, uno por modelo (se ven tantos como diga `fill`)
var fill := 1.0                   # qué tan llenas están las repisas
var restocker: Person = null      # el empleado que va a la bodega y repone
var route := []                   # camino del reponedor: [posición en el mundo, qué hace al llegar]
var route_t := 0.0


func _init(owner_city, index: int, location: Dictionary) -> void:
	city = owner_city
	plot_index = index
	plot = owner_city.PLOTS[index]
	loc = location
	sig = [loc.id, loc.size, loc.product]
	var name: String = D.PRODUCTS[loc.product].name
	bld = Building.new(city, plot, loc.size, Blueprints.PRODUCT_COLORS[loc.product], name.to_upper(), D.SIZES[loc.size].name)
	rects = bld.rects
	spots = bld.spots
	rep = Label3D.new()
	rep.font = Actors.symbols()
	rep.font_size = 56
	rep.pixel_size = 0.012
	rep.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	rep.outline_size = 10
	rep.outline_modulate = Color(0, 0, 0, 0.55)
	rep.position = Vector3(0, Actors.REP_Y[loc.size], 2.5)
	bld.root.add_child(rep)
	shelf = stock_shelves(bld.root, loc.size, loc.product)
	add_registers(bld.root, loc.size)


func sync_rep(reputation: float) -> void:
	var value := roundi(reputation)
	if value == rep_value:
		return
	rep_value = value
	var stars := roundi(value / 20.0)
	rep.text = "★".repeat(stars) + "☆".repeat(5 - stars) + " %d" % value
	rep.modulate = Actors.rep_color(value)


func sync_staff() -> void:
	var want: int = min(loc.employees, spots.staff.size())
	while staff.size() < want:
		var p := Person.new(Blueprints.PRODUCT_COLORS[loc.product], null, true)
		city.add_child(p)
		p.position = spots.staff[staff.size()]
		p.set_meta("home", p.position)
		p.rotation.y = spots.face_yaw
		staff.append(p)
	while staff.size() > want:
		var gone: Person = staff.pop_back()
		if gone == restocker:
			restocker = null
			route = []
		gone.queue_free()
	# Con dos empleados o más, el último repone las repisas (en la megatienda, los que no están en las cajas)
	var first_floor := 3 if loc.size == 2 else 1
	var r: Person = staff[staff.size() - 1] if staff.size() > first_floor else null
	if r != restocker:
		if restocker != null and is_instance_valid(restocker):
			restocker.hold("")
			restocker.position = restocker.get_meta("home")
		restocker = r
		route = []


## Quién atiende una fila: el empleado más cercano al primer lugar de la fila (o tú, si atiendes sin empleados).
func server_for(line) -> Person:
	var front: Vector3 = line.slots[0]
	var best: Person = null
	for p in staff:
		if p == restocker:
			continue
		if best == null or p.position.distance_to(front) < best.position.distance_to(front):
			best = p
	if best == null and city.serving == self:
		best = city.player
	return best


## Atender: mientras dura la venta, el empleado mira al cliente, prepara el producto y estira el brazo para darlo.
func serve(server: Person, customer_pos: Vector3, progress: float, dt: float) -> void:
	server.serve_t = 0.25
	var d := customer_pos - server.position
	server.rotation.y = lerp_angle(server.rotation.y, atan2(d.x, d.z), dt * 8)
	if has_shelves():  # el cliente ya trae el producto: el cajero lo pasa por la caja y cobra
		server.set_reach(0.35 + 0.15 * sin(progress * 18.0))
		return
	if progress > 0.2:
		server.hold(loc.product)
	server.set_reach(smoothstep(0.45, 0.9, progress))


## Los empleados que nadie necesita vuelven a mirar a la calle con las manos vacías.
func update(dt: float) -> void:
	if restocker != null and is_instance_valid(restocker):
		_update_restocker(dt)
	for p in staff:
		if p == restocker:
			continue
		if p.serve_t > 0.0:
			p.serve_t -= dt
			continue
		if p.item:
			p.hold("")
		p.set_reach(lerpf(-p.arms[1].rotation.x / deg_to_rad(80.0), 0.0, min(1.0, dt * 6)))
		p.rotation.y = lerp_angle(p.rotation.y, spots.face_yaw, dt * 4)


# ---------- repisas, bodega y cajas ----------
## Pone los productos en las repisas del local (coordenadas del local), mezclando los distintos modelos (todos al
## mismo precio). Devuelve un nodo por modelo. La usan también los locales de la competencia.
static func stock_shelves(root: Node3D, kind: int, product: String) -> Array:
	var nv := Actors.variants(product)
	var k := 1.5                                     # algo más grandes que en la mano, para que se vean
	var slots := []                                  # [posición sobre la tabla, giro]
	if kind == 0:  # puesto: en el mostrador
		for i in 9:
			slots.append([Vector3(-1.6 + i * 0.4, 1.15, 4.55), PI])
	else:
		var levels := [0.5, 1.2, 1.9] if kind == 1 else [0.5, 1.3, 2.1]
		var rows := []                              # [x de la tabla, z desde, z hasta, hacia dónde mira (±1 en x)]
		if kind == 1:
			rows = [[-5.5, 4.9, 12.1, 1], [5.5, 4.9, 12.1, -1]]
		else:
			for c in [-6.5, -2.0, 2.0, 6.5]:
				rows += [[c - 0.82, 5.4, 9.6, -1], [c + 0.82, 5.4, 9.6, 1]]
			rows += [[-9.47, 5.4, 13.6, 1], [9.47, 5.4, 13.6, -1]]
		for r in rows:
			var n := int((r[2] - r[1]) / 0.5) + 1
			for y in levels:
				for i in n:
					slots.append([Vector3(r[0], y + 0.025, r[1] + i * 0.5), -PI / 2 * r[3] + PI])
	# Orden mezclado: al vaciarse desaparecen productos salteados, no una repisa entera
	var rng := RandomNumberGenerator.new()
	rng.seed = kind * 31 + product.hash()
	for i in range(slots.size() - 1, 0, -1):
		var j := rng.randi_range(0, i)
		var t = slots[i]
		slots[i] = slots[j]
		slots[j] = t
	var out := []
	for v in nv:
		var mesh := Actors.product_item(product, v)
		var lift := -mesh.get_aabb().position.y * k   # apoyado sobre la tabla
		var mine := []
		for i in range(v, slots.size(), nv):
			mine.append(slots[i])
		var mm := MultiMesh.new()
		mm.transform_format = MultiMesh.TRANSFORM_3D
		mm.mesh = mesh
		mm.instance_count = mine.size()
		for i in mine.size():
			mm.set_instance_transform(i, Transform3D(Basis(Vector3.UP, mine[i][1]).scaled(Vector3.ONE * k),
					mine[i][0] + Vector3(0, lift, 0)))
		var mmi := MultiMeshInstance3D.new()
		mmi.multimesh = mm
		mmi.material_override = Mats.smooth
		mmi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		root.add_child(mmi)
		out.append(mmi)
	return out


## Cajas registradoras donde pagan los clientes (una por mostrador; en la megatienda, una por caja con su letrero).
static func add_registers(root: Node3D, kind: int) -> void:
	var spots := []   # [posición, giro]
	if kind == 0:
		spots = [[Vector3(1.2, 1.15, 3.5), 0.0]]
	elif kind == 1:
		spots = [[Vector3(0.0, 1.15, 9.25), 0.0]]
	else:
		for rx in [-6, -2, 2, 6]:
			spots.append([Vector3(rx, 1.15, 15.25), 0.0])   # el cajero detrás, los clientes llegan desde la puerta
	var n := 1
	for s in spots:
		var mi := MeshInstance3D.new()
		mi.mesh = Actors.cash_register()
		mi.material_override = Mats.smooth
		mi.position = s[0]
		mi.rotation.y = s[1]
		root.add_child(mi)
		if kind == 2:
			var sign := Building.label(root, "CAJA %d" % n, s[0] + Vector3(0, 1.75, 0), 9, Color8(255, 220, 120), true, false)
			sign.rotation.y = s[1]
			var pole := MeshInstance3D.new()
			var pm := BoxMesh.new()
			pm.size = Vector3(0.06, 1.3, 0.06)
			pole.mesh = pm
			pole.material_override = Mats.smooth
			pole.position = s[0] + Vector3(0.5, 0.65, 0)
			root.add_child(pole)
		n += 1


func has_shelves() -> bool:
	return loc.size > 0


## Un cliente saca productos de la repisa.
func take_item() -> void:
	var total := 0
	for s in shelf:
		total += s.multimesh.instance_count
	fill = max(0.08, fill - 4.0 / total)
	_show_fill()


func _show_fill() -> void:
	for s in shelf:
		s.multimesh.visible_instance_count = roundi(fill * s.multimesh.instance_count)


func pick_spot() -> Array:
	var picks: Array = spots.get("picks", [])
	if picks.is_empty():
		return []
	var i := randi() % picks.size()
	var face: int = spots.pick_faces[i] if i < spots.pick_faces.size() else 1
	return [picks[i], atan2(float(face * plot[1]), 0.0)]


## El reponedor: va a la bodega, saca una caja, camina a lo largo de la repisa llenándola y vuelve a su lugar.
func _plan_restock() -> void:
	var home: Vector3 = restocker.get_meta("home")
	var lh: float = (home.x - plot[0]) * plot[1]   # x local de su lugar
	var s := 1.0 if lh >= 0.0 else -1.0
	var w := func(lx: float, lz: float) -> Vector3: return Blueprints.to_world(plot, lx, lz)
	match loc.size:
		0:
			route = [[w.call(-1.9, 6.4), "pick"], [w.call(-1.4, 5.25), ""], [w.call(1.4, 5.25), "fill"], [home, "end"]]
		1:
			route = [[w.call(s * 4.6, 12.0), ""], [w.call(s * 4.6, 13.1), "pick"], [w.call(s * 4.75, 11.8), ""],
					[w.call(s * 4.75, 5.8), "fill"], [w.call(s * 4.6, 11.6), ""], [home, "end"]]
		2:  # por el pasillo del costado hasta la bodega (detrás de las cajas) y llena la repisa del costado
			route = [[w.call(s * 8.4, 18.9), ""], [w.call(s * 8.4, 18.9), "pick"], [w.call(s * 8.75, 13.6), ""],
					[w.call(s * 8.75, 5.4), "fill"], [w.call(s * 8.4, 12.0), ""], [home, "end"]]
	route_t = 0.0


func _update_restocker(dt: float) -> void:
	var p := restocker
	if route.is_empty():
		if fill < 0.75:
			_plan_restock()
		return
	p.serve_t = 0.25   # ocupado: no atiende
	var step: Array = route[0]
	if step[1] == "picking":
		route_t += dt
		p.animate(0, dt)
		if route_t > 1.0:
			p.hold("caja")
			route.pop_front()
		return
	var target: Vector3 = step[0]
	var d := Vector3(target.x - p.position.x, 0, target.z - p.position.z)
	var dist := d.length()
	var speed := 1.3 if step[1] == "fill" else 2.2
	if dist > 0.05:
		var mv: float = min(dist, speed * dt)
		p.position += d / dist * mv
		p.rotation.y = lerp_angle(p.rotation.y, atan2(d.x, d.z), dt * 10)
		p.animate(speed, dt)
		if step[1] == "fill":  # va llenando la repisa mientras camina a su lado
			fill = min(1.0, fill + mv * 0.12)
			_show_fill()
		return
	match step[1]:
		"pick":
			route[0] = [target, "picking"]
			route_t = 0.0
			return
		"fill":
			fill = 1.0
			_show_fill()
			p.hold("")
		"end":
			p.rotation.y = spots.face_yaw
	route.pop_front()


func service_time() -> float:
	var helpers := staff.size() + (1 if loc.get("owner", false) else 0)
	return 3.0 / helpers if helpers else 999.0


func destroy() -> void:
	for p in staff:
		p.queue_free()
	bld.destroy()
