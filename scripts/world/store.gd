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
var rep: Node3D                   # estrellas del local, grandes sobre el letrero (Icons.star_row)
var rep_stars: MeshInstance3D = null
var rep_full := -1
var rep_sub: Label3D              # nota con un decimal debajo
var rep_value := -1
var bounce := 0.0                 # salto de las estrellas cuando suben o bajan
var shelf := []                   # los productos en las repisas, uno por modelo (MultiMesh)
var items := []                   # cada producto de la repisa: {mm, i, xf, pos (mundo), gone, since}
var fill := 1.0                   # qué tan llenas están las repisas (productos que quedan / total)
var restocker: Person = null      # el empleado que va a la bodega y repone
var jobs := {}                    # empleado -> tarea que está haciendo (ver _idle_job)
var seated := {}                  # silla de los clientes (índice en spots.chairs) -> el Customer sentado ahí


func _init(owner_city, index: int, location: Dictionary) -> void:
	city = owner_city
	plot_index = index
	plot = owner_city.PLOTS[index]
	loc = location
	sig = [loc.id, loc.size, loc.product]
	var name: String = D.PRODUCTS[loc.product].name
	var company: String = city.game.company if city.game != null else D.SIZES[loc.size].name
	# Cada local tiene su propio interior: la semilla sale de la sucursal y del terreno
	bld = Building.new(city, plot, loc.size, Blueprints.PRODUCT_COLORS[loc.product], name.to_upper(), company, 0.0,
			int(loc.id) * 31 + index, loc.product)
	rects = bld.rects
	spots = bld.spots
	rep = Node3D.new()
	rep.position = Vector3(0, Actors.REP_Y[loc.size], 2.5)
	bld.root.add_child(rep)
	rep_sub = Label3D.new()
	rep_sub.font = Building.title_font
	rep_sub.font_size = 40
	rep_sub.pixel_size = 0.009
	rep_sub.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	rep_sub.outline_size = 8
	rep_sub.outline_modulate = Color(0, 0, 0, 0.55)
	rep_sub.position = rep.position + Vector3(0, -0.62, 0)
	bld.root.add_child(rep_sub)
	shelf = stock_shelves(bld.root, loc.size, loc.product, bld.local)
	for s in shelf:   # cada producto por separado: así se saca y se repone uno por uno
		for i in s.multimesh.instance_count:
			var xf: Transform3D = s.multimesh.get_instance_transform(i)
			items.append({"mm": s.multimesh, "i": i, "xf": xf, "pos": bld.root.transform * xf.origin, "gone": false, "since": 0.0})
	add_registers(bld.root, loc.size, bld.local)
	_build_nav()


## Las estrellas del local (cada local tiene las suyas): llenas, media y vacías, con la nota debajo.
func sync_stars() -> void:
	var stars := Game.stars_of(loc)
	var value := roundi(stars * 10)
	if value == rep_value:
		return
	rep_value = value
	var full := floori(stars + 0.25)
	if full != rep_full:  # la fila de estrellas solo se rehace cuando cambia una estrella entera
		rep_full = full
		if rep_stars != null:
			rep_stars.queue_free()
		rep_stars = Icons.star_row(full)
		rep.add_child(rep_stars)
	rep_sub.text = Lang.f("%s de 5 · reseñas", Fmt.num(stars, 1))
	rep_sub.modulate = Color(1, 1, 1, 0.9)


## Las estrellas saltan y sueltan un "+★" o "−★" cuando el local cruza una estrella entera.
func star_burst(up: bool) -> void:
	bounce = 1.0
	city.pop(rep.global_position + Vector3(0, -1.6, 0), "+1 estrella" if up else "−1 estrella", "orange" if up else "red", 26, 2.2)
	city.sfx.play("record" if up else "bad", 0.6 * city.near(rep.global_position))


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
		jobs.erase(gone)
		gone.queue_free()
	# Uno por caja atiende; con más gente, el último repone las repisas y los demás hacen tareas (ver _idle_job)
	var first_floor := cashiers()
	var r: Person = staff[staff.size() - 1] if staff.size() > first_floor else null
	if r != restocker:
		if restocker != null and is_instance_valid(restocker):
			restocker.hold("")
		restocker = r


## Cuántas cajas tiene el local (puesto 1, local 2, megatienda 3): los primeros empleados son los cajeros.
func cashiers() -> int:
	return max(1, bld.local.get("registers", [0]).size())


## Quién atiende una fila: el cajero más cercano al primer lugar de la fila (o tú, si atiendes sin empleados).
func server_for(line) -> Person:
	var front: Vector3 = line.slots[0]
	var best: Person = null
	for p in staff.slice(0, cashiers()):
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


## Cada cuadro: los cajeros solo se mueven al cobrar; los demás hacen tareas (con su camino por el local, sin
## atravesar paredes, repisas, mesones ni a otros empleados) y de vez en cuando se sientan a descansar.
func update(dt: float) -> void:
	if bounce > 0.0:
		bounce = max(0.0, bounce - dt * 1.4)
		var k := sin(bounce * PI * 3.0) * bounce
		rep.scale = Vector3.ONE * (1.0 + 0.45 * absf(k))
		rep.position.y = Actors.REP_Y[loc.size] + 0.5 * absf(k)
	if restocker == null:   # sin reponedor (solo cajeros): lo que falta vuelve solo al rato (en el puesto, de la caja de abajo)
		var now := Time.get_ticks_msec() / 1000.0
		var wait := 8.0 if loc.size == 0 else 45.0
		for it in items:
			if it.gone and now - it.since > wait:
				_restore(it)
	var n_cash := cashiers()
	for i in staff.size():
		var p: Person = staff[i]
		if p.serve_t > 0.0:
			p.serve_t -= dt
			continue
		if jobs.has(p):
			_do_job(p, jobs[p], dt)
			continue
		# Quieto en su lugar: las manos vuelven a su posición y mira hacia la calle
		if p.item:
			p.hold("")
		var reach := -p.arms[1].rotation.x / deg_to_rad(80.0)
		p.animate(0, dt)
		p.set_reach(lerpf(reach, 0.0, min(1.0, dt * 6)))
		if i < n_cash:  # los cajeros no salen de la caja ni se sientan
			p.rotation.y = lerp_angle(p.rotation.y, spots.face_yaw, dt * 4)
			continue
		var idle: float = p.get_meta("idle", 0.0) + dt
		p.set_meta("idle", idle)
		# mira un poco a los lados mientras decide qué hacer
		p.rotation.y = lerp_angle(p.rotation.y, spots.face_yaw + sin(idle * 0.7 + i) * 0.5, dt * 2)
		if p == restocker and needs_restock():
			jobs[p] = _restock_job(p)
		elif idle > p.get_meta("wait", 2.0):
			p.set_meta("idle", 0.0)
			p.set_meta("wait", randf_range(1.5, 4.0))
			var job := _idle_job(p)
			if not job.is_empty():
				jobs[p] = job


# ---------- caminos dentro del local ----------
const CELL := 0.35
var nav: AStarGrid2D
var nav_origin := Vector2.ZERO   # esquina del local (x, z locales) que corresponde a la celda (0, 0)


func _w(lx: float, lz: float) -> Vector3:
	return Blueprints.to_world(plot, lx, lz)


func _to_local(p: Vector3) -> Vector2:
	return Vector2((p.x - plot[0]) * plot[1], p.z * plot[1] - Blueprints.FRONT)


func _cell(l: Vector2) -> Vector2i:
	return Vector2i(int(floor((l.x - nav_origin.x) / CELL)), int(floor((l.y - nav_origin.y) / CELL)))


func _cell_world(c: Vector2i) -> Vector3:
	return _w(nav_origin.x + (c.x + 0.5) * CELL, nav_origin.y + (c.y + 0.5) * CELL)


## La grilla por donde caminan los empleados: todo lo que toca el piso (paredes, repisas, mesones, mesas, cajas
## de la bodega, maceteros...) queda bloqueado con el ancho de una persona de margen.
func _build_nav() -> void:
	var area: Rect2
	match loc.size:
		0:
			area = Rect2(-3.4, 5.3, 6.8, 2.4)    # el puesto: solo detrás del mostrador
		1:
			area = Rect2(-6.85, 2.15, 13.7, 11.7)
		_:
			area = Rect2(-Blueprints.MEGA_W / 2 + 0.15, 2.15, Blueprints.MEGA_W - 0.3, 17.7)
	nav_origin = area.position
	nav = AStarGrid2D.new()
	nav.region = Rect2i(0, 0, ceili(area.size.x / CELL), ceili(area.size.y / CELL))
	nav.cell_size = Vector2.ONE
	nav.diagonal_mode = AStarGrid2D.DIAGONAL_MODE_ONLY_IF_NO_OBSTACLES
	nav.update()
	var margin := 0.28
	for b in bld.blueprint_boxes:
		var c: Vector3 = b[0]
		var s: Vector3 = b[1]
		var bottom := c.y - s.y / 2
		if bottom > 2.3 or (s.y < 0.08 and c.y < 0.2) or c.y + s.y / 2 < 0.25:
			continue   # cuelga del techo o es parte del piso (baldosas, alfombra); las tablas de las repisas sí cuentan
		_block(Rect2(c.x - s.x / 2 - margin, c.z - s.z / 2 - margin, s.x + margin * 2, s.z + margin * 2))
	# Los cajeros no se mueven: su lugar también está ocupado
	for i in min(cashiers(), spots.staff.size()):
		var h := _to_local(spots.staff[i])
		_block(Rect2(h.x - 0.35, h.y - 0.35, 0.7, 0.7))


func _block(r: Rect2) -> void:
	var a := _cell(r.position)
	var e := _cell(r.end)
	for x in range(max(a.x, 0), min(e.x + 1, nav.region.size.x)):
		for y in range(max(a.y, 0), min(e.y + 1, nav.region.size.y)):
			var mid := nav_origin + Vector2((x + 0.5) * CELL, (y + 0.5) * CELL)
			if r.has_point(mid):
				nav.set_point_solid(Vector2i(x, y), true)


## La celda libre más cercana (si el destino cae dentro de un mueble).
func _free_cell(c: Vector2i) -> Vector2i:
	c = c.clamp(Vector2i.ZERO, nav.region.size - Vector2i.ONE)
	if not nav.is_point_solid(c):
		return c
	for r in range(1, 10):
		for dx in range(-r, r + 1):
			for dy in [-r, r]:
				for q in [Vector2i(c.x + dx, c.y + dy), Vector2i(c.x + dy, c.y + dx)]:
					if nav.is_in_boundsv(q) and not nav.is_point_solid(q):
						return q
	return c


## Camino (puntos del mundo) de `from` a `to` esquivando los muebles; `avoid` son celdas ocupadas por otros.
func _nav_path(from: Vector3, to: Vector3, avoid := []) -> Array:
	var a := _free_cell(_cell(_to_local(from)))
	var b := _free_cell(_cell(_to_local(to)))
	var marked := []   # solo se liberan después las celdas que se marcaron aquí (no los muebles)
	for c in avoid:
		if nav.is_in_boundsv(c) and c != a and c != b and not nav.is_point_solid(c):
			nav.set_point_solid(c, true)
			marked.append(c)
	var ids := nav.get_id_path(a, b)
	for c in marked:
		nav.set_point_solid(c, false)
	if ids.is_empty() and not marked.is_empty():   # esquivando no hay salida: el camino de siempre
		ids = nav.get_id_path(a, b)
	var out := []
	var last_dir := Vector2i.ZERO
	for k in range(1, ids.size()):   # solo las esquinas del camino
		var d: Vector2i = ids[k] - ids[k - 1]
		if d != last_dir and k > 1:
			out.append(_cell_world(ids[k - 1]))
		last_dir = d
	var dest := to if _cell(_to_local(to)) == b else _cell_world(b)
	out.append(dest)
	return out


## Camina hacia `target` por la grilla. Si otro empleado le tapa el paso, espera y después busca otro camino; si
## igual sigue trabado (dos que se tapan entre sí, o uno quieto en un pasillo angosto), pasa de largo un rato sin
## esquivar a nadie. Devuelve la distancia que avanzó, o -1 cuando llegó.
func _walk(p: Person, job: Dictionary, target: Vector3, speed: float, dt: float) -> float:
	if job.get("goal") != target:
		job.goal = target
		job.path = _nav_path(p.position, target)
		job.blocked = 0.0
		job.retries = 0
		job.pass = 0.0
		job.walk_t = 0.0
	var path: Array = job.path
	if path.is_empty():
		return -1.0
	job.walk_t += dt
	if job.walk_t > 30.0:   # nunca debería pasar, pero si se quedó dando vueltas aparece donde iba
		p.position = Vector3(target.x, p.position.y, target.z)
		return -1.0
	var next: Vector3 = path[0]
	var d := Vector3(next.x - p.position.x, 0, next.z - p.position.z)
	var dist := d.length()
	if dist < 0.05:
		path.pop_front()
		return 0.0 if not path.is_empty() else -1.0
	var dir := d / dist
	job.pass = maxf(0.0, job.pass - dt)
	# ¿Hay otro empleado justo adelante?
	for o in staff:
		if o == p or job.pass > 0.0:
			continue
		var to_o: Vector3 = o.position - p.position
		to_o.y = 0
		if to_o.length() < 0.7 and to_o.normalized().dot(dir) > 0.4:
			var at_goal := Vector2(o.position.x - target.x, o.position.z - target.z).length() < 0.6
			if at_goal and Vector2(p.position.x - target.x, p.position.z - target.z).length() < 1.2:
				return -1.0   # el otro está parado justo donde iba: se queda al lado y hace lo suyo ahí
			job.blocked += dt
			p.animate(0, dt)
			if job.blocked > 0.9:   # se cansó de esperar: rodea a la otra persona
				job.blocked = 0.0
				job.retries += 1
				if job.retries >= 3:   # ya probó rodearlo y no hay caso: pasa igual
					job.pass = 1.6
					job.retries = 0
					job.path = _nav_path(p.position, target)
					return 0.0
				var oc := _cell(_to_local(o.position))
				var around := []
				for dx in range(-1, 2):
					for dy in range(-1, 2):
						around.append(oc + Vector2i(dx, dy))
				job.path = _nav_path(p.position, target, around)
			return 0.0
	job.blocked = 0.0
	var turn := absf(wrapf(atan2(dir.x, dir.z) - p.rotation.y, -PI, PI))
	p.rotation.y = lerp_angle(p.rotation.y, atan2(dir.x, dir.z), dt * 9)
	if turn > 1.2:   # primero se da vuelta, después camina
		p.animate(0, dt)
		return 0.0
	var mv: float = min(dist, speed * dt)
	p.position += dir * mv
	p.animate(speed, dt)
	return mv


# ---------- tareas ----------
## Un paso de una tarea: ir a `to` (o quedarse), y hacer `do` durante `time` segundos mirando hacia `yaw`.
static func _step(to, do := "", time := 0.0, yaw = null, item = null, extra := {}) -> Dictionary:
	var s := {"to": to, "do": do, "time": time, "yaw": yaw, "item": item}
	s.merge(extra)
	return s


func _face(face: int) -> float:
	return atan2(float(face * plot[1]), 0.0)


func _home_job(p: Person, steps: Array) -> Dictionary:
	steps.append(_step(p.get_meta("home"), "", 0.0, spots.face_yaw, ""))
	return {"steps": steps, "i": 0, "t": 0.0}


## ¿Hay que reponer? Cuando faltan varios productos, o cuando uno falta hace rato.
func needs_restock() -> bool:
	var missing := 0
	var oldest := 0.0
	var now := Time.get_ticks_msec() / 1000.0
	for it in items:
		if it.gone:
			missing += 1
			oldest = max(oldest, now - it.since)
	return missing >= max(4, items.size() / 12) or (missing > 0 and oldest > 15.0)


## El reponedor saca una caja de la bodega y va a cada hueco de las repisas a poner los productos que faltan.
func _restock_job(p: Person) -> Dictionary:
	var home: Vector3 = p.get_meta("home")
	var s := 1.0 if _to_local(home).x >= 0.0 else -1.0
	var steps := []
	match loc.size:
		0:
			steps = [_step(_w(-1.9, 6.4), "pick", 1.0, null, "caja")]
		1:
			steps = [_step(_w(s * 4.6, 13.0), "pick", 1.0, null, "caja")]
		_:
			var x: float = bld.local.get("restock", {"x": 8.05}).x
			steps = [_step(_w(s * (x - 0.35), 18.9), "pick", 1.0, null, "caja")]
	# Los huecos, agrupados por el lugar del pasillo desde donde se alcanzan
	var picks: Array = bld.local.get("picks", [])
	var faces: Array = bld.local.get("pick_faces", [])
	var groups := {}
	for it in items:
		if not it.gone:
			continue
		var key := -1
		var best := INF
		for k in picks.size():
			var d: float = Vector2(_w(picks[k][0], picks[k][1]).x - it.pos.x, _w(picks[k][0], picks[k][1]).z - it.pos.z).length()
			if d < best:
				best = d
				key = k
		if not groups.has(key):
			groups[key] = []
		groups[key].append(it)
	for key in groups:
		var spot: Vector3
		var yaw = null
		if key < 0:   # puesto: se reponen desde detrás del mostrador
			spot = _w(0.0, 5.45)
			yaw = spots.face_yaw
		else:
			# se para frente al hueco (a la altura del producto que falta), en el pasillo
			var first: Dictionary = groups[key][0]
			var pk: Vector3 = _w(picks[key][0], picks[key][1])
			spot = Vector3(pk.x, 0, first.pos.z)   # las repisas van a lo largo del local: en el pasillo, frente al hueco
			yaw = _face(faces[key] if key < faces.size() else 1)
		steps.append(_step(spot, "refill", 0.4 + 0.45 * groups[key].size(), yaw, null, {"refill": groups[key]}))
	return _home_job(p, steps)


## Algo que hacer para un empleado libre. Cada tanto, en vez de trabajar, se sienta a descansar.
func _idle_job(p: Person) -> Dictionary:
	var picks: Array = bld.local.get("picks", [])
	var faces: Array = bld.local.get("pick_faces", [])
	var tables: Array = bld.local.get("tables", []) + bld.local.get("mega_tables", [])
	var seats: Array = bld.local.get("seats", [])
	var done: int = p.get_meta("tasks", 0)
	p.set_meta("tasks", done + 1)
	var options := []   # [tarea, peso]
	if not seats.is_empty():
		options.append(["rest", 1.0 + done * 0.5])   # cuanto más trabajó, más ganas de descansar
	if loc.size == 0:
		options += [["arrange", 3.0], ["wipe", 2.0]]
	else:
		if not picks.is_empty():
			options += [["shelf", 3.0], ["inventory", 2.0], ["sweep", 2.0], ["mop", 1.0], ["carry", 2.0]]
		if not tables.is_empty():
			options.append(["tables", 2.0])
		options.append(["window", 1.0])
	var total := 0.0
	for o in options:
		total += o[1]
	var r := randf() * total
	var kind: String = options[0][0]
	for o in options:
		r -= o[1]
		if r <= 0:
			kind = o[0]
			break
	var steps := []
	var shelf_spot := func() -> Array:
		var i := randi() % picks.size()
		return [_w(picks[i][0], picks[i][1] + randf_range(-0.5, 0.5)), _face(faces[i] if i < faces.size() else 1)]
	match kind:
		"rest":
			p.set_meta("tasks", 0)
			var seat: Array = seats.pick_random()
			steps = [_step(_w(seat[0], seat[1]), "sit", randf_range(8.0, 15.0), spots.face_yaw,
					"celular" if randf() < 0.4 else "")]
		"arrange":
			steps = [_step(null, "shelf", randf_range(2.5, 4.0), spots.face_yaw, "")]
		"wipe":
			steps = [_step(null, "wipe", randf_range(2.0, 3.5), spots.face_yaw, "trapo")]
		"shelf":
			var sp: Array = shelf_spot.call()
			steps = [_step(sp[0], "shelf", randf_range(3.0, 5.0), sp[1], "caja" if randf() < 0.4 else "")]
		"inventory":
			var sp: Array = shelf_spot.call()
			var sp2: Array = shelf_spot.call()
			steps = [_step(sp[0], "inventory", randf_range(2.5, 4.0), sp[1], "tabla"),
					_step(sp2[0], "inventory", randf_range(2.0, 3.5), sp2[1], "tabla")]
		"sweep", "mop":
			var item := "escoba" if kind == "sweep" else "trapeador"
			for k in 3:
				var pk: Array = picks.pick_random()
				steps.append(_step(_w(pk[0] * randf_range(0.2, 0.8), pk[1] + randf_range(-1.0, 1.0)), "", 0.0, null, item,
						{"anim": "sweep", "speed": 1.0}))
		"carry":   # trae una caja de la bodega a una repisa
			var crate: Vector3 = _w((1.0 if randf() < 0.5 else -1.0) * (4.6 if loc.size == 1 else 7.8), 13.0 if loc.size == 1 else 18.9)
			var sp: Array = shelf_spot.call()
			steps = [_step(crate, "pick", 1.0, null, "caja"), _step(sp[0], "shelf", randf_range(2.0, 3.0), sp[1], null)]
		"tables":
			var t: Array = tables.pick_random()
			var side := 1.0 if t[0] < 0 else -1.0
			steps = [_step(_w(t[0] + side * 0.95, t[1]), "wipe", randf_range(2.5, 4.0), atan2(-side * plot[1], 0.0), "trapo")]
		"window":   # limpia la vitrina de adentro
			var gx: float = (5.5 if loc.size == 1 else 7.9) * (1.0 if randf() < 0.5 else -1.0)
			steps = [_step(_w(gx, 2.75), "window", randf_range(3.0, 5.0), spots.face_yaw, "trapo")]
	return _home_job(p, steps)


func _do_job(p: Person, job: Dictionary, dt: float) -> void:
	var steps: Array = job.steps
	if job.i >= steps.size():
		p.hold("")
		p.set_reach(0.0)
		jobs.erase(p)
		return
	var st: Dictionary = steps[job.i]
	if not job.get("held", false):   # al empezar el paso toma lo que necesita (la caja, recién al llegar a la bodega)
		if st.do == "pick":
			p.hold("")
		elif st.item != null:
			p.hold(st.item)
		job.held = true
	# 1) caminar hasta el lugar
	if st.to != null and not job.get("arrived", false):
		var speed: float = st.get("speed", 1.4)
		var moved := _walk(p, job, st.to, speed, dt)
		if st.get("anim") == "sweep":   # barre o trapea mientras avanza
			p.set_reach(0.3 + 0.18 * sin(Time.get_ticks_msec() / 150.0))
		if moved >= 0:
			return
		job.arrived = true
	# 2) hacer la tarea en el lugar
	job.t += dt
	if st.yaw != null:
		p.rotation.y = lerp_angle(p.rotation.y, st.yaw, dt * 6)
	p.animate(0, dt)   # primero las piernas quietas; después los brazos y sentarse (si no, el paso los pisa)
	var sit := 0.0
	match st.do:
		"shelf":      # acomoda productos, a distintas alturas
			p.set_reach(0.45 + 0.35 * absf(sin(job.t * 2.2)))
		"inventory":  # mira la tabla y anota
			p.set_reach(0.42 + 0.04 * sin(job.t * 9.0))
		"wipe":       # pasa el trapo
			p.set_reach(0.5 + 0.15 * sin(job.t * 11.0))
		"window":     # limpia el vidrio a la altura de la cara
			p.set_reach(0.85 + 0.12 * sin(job.t * 8.0))
		"refill":     # saca de la caja y pone en la repisa, uno por uno
			p.set_reach(0.45 + 0.35 * absf(sin(job.t * 4.0)))
			var put: int = int(job.t / 0.45)
			var todo: Array = st.refill
			for k in min(put, todo.size()):
				if todo[k].gone:
					_restore(todo[k])
			if job.t >= st.time - 0.05:
				p.hold("")
		"pick":       # se agacha a sacar una caja
			p.set_reach(0.7 * sin(clampf(job.t / st.time, 0, 1) * PI))
			if job.t > st.time * 0.5 and st.item and p.item == null:
				p.hold(st.item)
		"sit":   # se acomoda sobre el asiento y se sienta; al final se para
			if job.t < 0.5:
				p.position = p.position.lerp(Vector3(st.to.x, 0, st.to.z), min(1.0, dt * 8))
			sit = clampf(job.t / 0.5, 0, 1) * clampf((st.time - job.t) / 0.5, 0, 1)
			p.set_reach(0.45 if p.item else 0.0)
	p.sit(sit)
	if job.t >= st.time:
		p.sit(0.0)
		job.i += 1
		job.t = 0.0
		job.arrived = false
		job.held = false
		job.erase("goal")
		if job.i >= steps.size():
			p.rotation.y = spots.face_yaw
			p.set_reach(0.0)
			p.hold("")
			jobs.erase(p)


# ---------- repisas, bodega y cajas ----------
## Pone los productos en las repisas del local (coordenadas del local), mezclando los distintos modelos (todos al
## mismo precio). Devuelve un nodo por modelo. La usan también los locales de la competencia.
static func stock_shelves(root: Node3D, kind: int, product: String, layout := {}) -> Array:
	var nv := Actors.variants(product)
	var k := 1.5 if product != "pan" else 1.25       # algo más grandes que en la mano, para que se vean
	var along := PI / 2 if product == "pan" else 0.0 # los panes largos van a lo largo de la repisa, no atravesados
	var slots := []                                  # [posición sobre la tabla, giro]
	if layout.has("shelf_rows"):  # interior propio del local
		for r in layout.shelf_rows:
			var n := int((r[2] - r[1]) / 0.5) + 1
			for y in layout.levels:
				for i in n:
					slots.append([Vector3(r[0], y + 0.025, r[1] + i * 0.5), -PI / 2 * r[3] + PI])
	elif layout.has("stall_slots"):
		slots = layout.stall_slots.duplicate()
	elif kind == 0:  # puesto: en el mostrador
		slots = Blueprints.stall_slots()
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
			mm.set_instance_transform(i, Transform3D(Basis(Vector3.UP, mine[i][1] + (along if kind > 0 else 0.0)).scaled(Vector3.ONE * k),
					mine[i][0] + Vector3(0, lift, 0)))
		var mmi := MultiMeshInstance3D.new()
		mmi.multimesh = mm
		mmi.material_override = Mats.smooth
		mmi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		mmi.visibility_range_end = 55.0   # los productos de las repisas solo se ven de cerca
		root.add_child(mmi)
		out.append(mmi)
	return out


## Cajas registradoras donde pagan los clientes (una por mostrador; en la megatienda, una por caja con su letrero).
static func add_registers(root: Node3D, kind: int, layout := {}) -> void:
	var spots := []   # [posición, giro]
	if layout.has("registers"):
		spots = layout.registers
	elif kind == 0:
		spots = [Blueprints.STALL_REGISTER]
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
		mi.visibility_range_end = 50.0
		mi.position = s[0]
		mi.rotation.y = s[1]
		root.add_child(mi)
		if kind == 2:
			var sign := Building.label(root, Lang.f("CAJA %d", n), s[0] + Vector3(0, 1.75, 0), 9, Color8(255, 220, 120), true, false)
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


## Una silla libre para que un cliente se siente a comer (al azar), o -1 si no hay o están todas ocupadas.
func free_chair() -> int:
	var free := []
	for i in spots.get("chairs", []).size():
		if not seated.has(i) or not is_instance_valid(seated[i].body):
			free.append(i)
	return -1 if free.is_empty() else free.pick_random()


## Un cliente saca un producto: desaparece de la repisa el que tiene más a mano (lo compró), hasta que lo repongan.
func take_item(near: Vector3) -> void:
	var close := []
	for it in items:
		if not it.gone:
			close.append([Vector2(it.pos.x - near.x, it.pos.z - near.z).length(), it])
	if close.is_empty():
		return
	close.sort_custom(func(a, b): return a[0] < b[0])
	var it: Dictionary = close[randi() % min(4, close.size())][1]   # uno de los más cercanos, a cualquier altura
	it.gone = true
	it.since = Time.get_ticks_msec() / 1000.0
	it.mm.set_instance_transform(it.i, Transform3D(Basis.from_scale(Vector3.ONE * 0.0001), it.xf.origin))
	_update_fill()


## Un cliente que se arrepintió devuelve el producto al hueco más cercano.
func put_back(near: Vector3) -> void:
	var best = null
	var best_d := INF
	for it in items:
		if it.gone:
			var d := Vector2(it.pos.x - near.x, it.pos.z - near.z).length()
			if d < best_d:
				best = it
				best_d = d
	if best != null:
		_restore(best)


func _restore(it: Dictionary) -> void:
	it.gone = false
	it.mm.set_instance_transform(it.i, it.xf)
	_update_fill()


func _update_fill() -> void:
	var left := 0
	for it in items:
		if not it.gone:
			left += 1
	fill = float(left) / max(1, items.size())


func pick_spot() -> Array:
	var picks: Array = spots.get("picks", [])
	if picks.is_empty():
		return []
	var i := randi() % picks.size()
	var face: int = spots.pick_faces[i] if i < spots.pick_faces.size() else 1
	return [picks[i], atan2(float(face * plot[1]), 0.0)]


func service_time() -> float:
	var helpers := staff.size() + (1 if loc.get("owner", false) else 0)
	return 3.0 / helpers if helpers else 999.0


func destroy() -> void:
	for p in staff:
		p.queue_free()
	bld.destroy()
