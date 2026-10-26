class_name Actors
extends RefCounted
## Fábricas de los actores de la ciudad: terreno en venta, local propio, local de la competencia y autos.

const REP_Y := {0: 4.7, 1: 7.3, 2: 10.7}   # altura de las estrellas de reputación sobre cada tamaño de local
static var symbol_font: SystemFont


static func symbols() -> SystemFont:
	if symbol_font == null:
		symbol_font = SystemFont.new()
		symbol_font.font_names = PackedStringArray(["Segoe UI Symbol", "Segoe UI", "Arial"])
		symbol_font.font_weight = 700
	return symbol_font


## Terreno en venta: pasto (o arena en la playa), estacas y el cartel SE VENDE.
static func lot(parent: Node3D, plot: Array, index: int, price: String) -> Dictionary:
	var beach: bool = index in D.BEACH_PLOTS
	var root := Node3D.new()
	root.position = Vector3(plot[0], 0, plot[1] * Blueprints.FRONT)
	root.rotation.y = 0.0 if plot[1] == 1 else PI
	parent.add_child(root)
	var b := Boxes.new()
	b.box(Vector3(0, 0.015, 11), Vector3(20.5, 0.03, 20), Color8(222, 205, 160) if beach else Color8(125, 150, 95))
	for px in [-10, 10]:
		for pz in [1, 21]:
			b.box(Vector3(px, 0.5, pz), Vector3(0.2, 1.0, 0.2), Blueprints.PALETTE.wood)
	b.box(Vector3(0, 0.7, 1.2), Vector3(0.12, 1.4, 0.12), Blueprints.PALETTE.wood)
	b.box(Vector3(0, 1.8, 1.2), Vector3(2.8, 1.3, 0.12), Blueprints.PALETTE.green)
	b.node(root, Mats.standard)
	Building.label(root, "SE VENDE", Vector3(0, 2.05, 1.13), 14, Color.WHITE)
	Building.label(root, "Terreno %d%s · desde %s" % [index + 1, " · Playa" if beach else "", price],
			Vector3(0, 1.6, 1.13), 8, Color.WHITE, false)
	return {"root": root, "manage": Blueprints.to_world(plot, 0, -0.6)}


static func rep_color(value: float) -> Color:
	return Color8(120, 230, 90) if value >= 60 else (Color8(240, 160, 50) if value >= 35 else Color8(240, 70, 60))


## Local de la competencia: borde rojo que se ve de día y de noche, letrero COMPETENCIA y empleados del rival.
static func competitor(parent: Node3D, key: String, plot: Array) -> Dictionary:
	var r := D.rival_for(key)
	var bld := Building.new(parent, plot, 1, Blueprints.PRODUCT_COLORS[key], "COMPETENCIA",
			"%s · %s" % [r.company, D.PRODUCTS[key].name], 17, absi(int(plot[0] * 13 + plot[1] * 7)) + 500, key)
	var w := 14.0
	var h := 4.5
	var z0 := 2.0
	var z1 := 14.0
	var zc := (z0 + z1) / 2
	var red := Color8(235, 45, 45)
	var e := Boxes.new()
	# Solo una franja roja en el suelo alrededor del local (el edificio queda sin marco)
	for bx in [[Vector3(0, 0.05, z0 - 0.8), Vector3(w + 1.8, 0.05, 0.3)], [Vector3(0, 0.05, z1 + 0.8), Vector3(w + 1.8, 0.05, 0.3)],
			[Vector3(-w / 2 - 0.9, 0.05, zc), Vector3(0.3, 0.05, z1 - z0 + 1.9)], [Vector3(w / 2 + 0.9, 0.05, zc), Vector3(0.3, 0.05, z1 - z0 + 1.9)]]:
		e.box(bx[0], bx[1], red)
	e.node(bld.root, Mats.emissive, false)
	Store.stock_shelves(bld.root, 1, key, bld.local)   # sus repisas también están llenas
	Store.add_registers(bld.root, 1, bld.local)
	var staff := []
	for i in min(2, bld.spots.staff.size()):
		var p := Person.new(r.color, null, true)
		parent.add_child(p)
		p.position = bld.spots.staff[i]
		p.rotation.y = bld.spots.face_yaw
		staff.append(p)
	return {"key": key, "rival": r, "bld": bld, "rects": bld.rects, "spots": bld.spots, "staff": staff}


static func free_competitor(c: Dictionary) -> void:
	for p in c.staff:
		p.queue_free()
	c.bld.destroy()


## Auto: carrocería, cabina de vidrio, ruedas y focos. lane −1 va hacia +x, lane 1 hacia −x.
static func car(parent: Node3D, lane: int, x: float) -> Node3D:
	var root := Node3D.new()
	root.position = Vector3(x, 0, lane * 2.7)
	var dir := 1 if lane < 0 else -1
	root.rotation.y = PI / 2 if dir > 0 else -PI / 2
	var b := Boxes.new()
	b.box(Vector3(0, 0.65, 0), Vector3(1.8, 0.7, 4.0), Person.SHIRTS.pick_random())
	for wx in [-0.85, 0.85]:
		for wz in [-1.3, 1.3]:
			b.box(Vector3(wx, 0.32, wz), Vector3(0.3, 0.64, 0.64), Blueprints.PALETTE.dark)
	b.box(Vector3(0, 0.62, -2.02), Vector3(1.5, 0.15, 0.05), Color8(200, 40, 40))
	b.node(root, Mats.smooth)
	var cab := Boxes.new()
	cab.box(Vector3(0, 1.25, -0.3), Vector3(1.6, 0.6, 2.0), Color8(120, 150, 180))
	cab.node(root, Mats.glass, true)
	var lights := Boxes.new()
	for lx in [-0.6, 0.6]:
		lights.box(Vector3(lx, 0.7, 2.0), Vector3(0.35, 0.18, 0.05), Color8(255, 245, 200))
	lights.node(root, Mats.emissive, false)
	Mats.add_light(root, Vector3(0, 0.7, 3.0), 11.0, false, true)   # de noche los focos alumbran la calle de adelante
	root.set_meta("dir", dir)
	root.set_meta("speed", randf_range(7, 12))
	root.set_meta("brake", 0.0)
	parent.add_child(root)
	return root


const ROAD_WEST := -240.0  # al oeste los autos se pierden en el valle de los cerros
const ROAD_END := 178.0   # la calle termina bajo el agua: de ahí salen los autos y ahí se meten


## Altura de la calle en x: plana en la ciudad y, pasada la orilla, bajando con la arena hasta meterse al mar.
static func road_y(x: float) -> float:
	return 0.0 if x <= 157.0 else Terrain.height(x, 0.0)


const CAR_GAP := 7.0   # distancia mínima con el auto de adelante (un auto mide 4 m)


static func drive(car: Node3D, dt: float, cars: Array = []) -> void:
	var brake: float = car.get_meta("brake")
	if brake > 0:  # frenó después de atropellar a alguien
		car.set_meta("brake", brake - dt)
		return
	var dir: int = car.get_meta("dir")
	# Sigue al de adelante en su pista: frena si se acerca y nunca lo atraviesa
	var speed: float = car.get_meta("speed")
	var gap := INF
	for other in cars:
		if other != car and other.get_meta("dir") == dir:
			var d: float = (other.position.x - car.position.x) * dir
			if d > 0.0 and d < gap:
				gap = d
	if gap < CAR_GAP * 2.0:
		speed *= clampf((gap - CAR_GAP) / CAR_GAP, 0.0, 1.0)
	car.position.x += dir * speed * dt
	if car.position.x > ROAD_END or car.position.x < ROAD_WEST:
		var start := ROAD_WEST if dir > 0 else ROAD_END
		var free := true
		for other in cars:
			if other != car and other.get_meta("dir") == dir and absf(other.position.x - start) < CAR_GAP + 2.0:
				free = false
		if free:
			car.position.x = start
		else:  # el lugar de entrada está ocupado: espera escondido fuera de la calle
			car.position.x = clampf(car.position.x, ROAD_WEST - 0.5, ROAD_END + 0.5)
			return
	# Sigue la rampa: inclinado hacia abajo al entrar al mar y hacia arriba al salir
	var x := car.position.x
	car.position.y = road_y(x)
	car.rotation.x = 0.0
	car.rotation.z = 0.0
	if x > 156.0:
		var slope := atan2(road_y(x + 1.0) - road_y(x - 1.0), 2.0)
		car.rotation.x = -slope * car.get_meta("dir")


static var _items := {}
static var _register: Mesh


## Caja registradora: base, teclado inclinado, pantalla verde y el cajón del dinero. La pantalla mira hacia −z.
static func cash_register() -> Mesh:
	if _register:
		return _register
	var b := Boxes.new()
	b.box(Vector3(0, 0.07, 0), Vector3(0.56, 0.14, 0.44), Color8(45, 47, 54))
	b.box(Vector3(0, 0.025, -0.225), Vector3(0.4, 0.06, 0.01), Color8(120, 122, 128))   # cajón
	b.box_rot(Vector3(0, 0.18, -0.06), Vector3(0.44, 0.04, 0.24), Color8(70, 72, 80), Vector3(-18, 0, 0))
	for i in 3:
		for j in 4:
			b.box_rot(Vector3(-0.12 + j * 0.08, 0.205 + i * 0.016, -0.12 + i * 0.05), Vector3(0.05, 0.015, 0.035),
					Color8(210, 210, 215), Vector3(-18, 0, 0))
	b.box(Vector3(0.12, 0.32, 0.12), Vector3(0.05, 0.22, 0.05), Color8(45, 47, 54))
	b.box_rot(Vector3(0.12, 0.45, 0.1), Vector3(0.3, 0.18, 0.03), Color8(30, 32, 36), Vector3(-12, 0, 0))
	b.box_rot(Vector3(0.12, 0.45, 0.084), Vector3(0.26, 0.14, 0.01), Color8(90, 220, 140), Vector3(-12, 0, 0))
	_register = b.build()
	return _register

## Lo que vende cada negocio, para que el empleado lo entregue y el cliente se lo lleve en la mano. El centro de la
## malla queda en la palma de la mano.
## Cuántos modelos hay de cada producto (todos valen lo mismo; solo se ven distintos).
static func variants(key: String) -> int:
	return {"pan": 5, "cafe": 3, "burger": 2, "ropa": 4, "tech": 3, "paraguas": 4}.get(key, 1)


static func product_item(key: String, variant := 0) -> Mesh:
	var id := "%s%d" % [key, variant]
	if _items.has(id):
		return _items[id]
	var b := Boxes.new()
	var crust := Color8(205, 140, 65)
	var crumb := Color8(245, 205, 130)
	if key == "pan" and variant > 0:
		match variant:
			1:  # croissant: medialuna de trozos que se curvan
				for k in 5:
					var a := (k - 2) * 0.42
					var w: float = 0.1 - absf(k - 2) * 0.02
					b.box_rot(Vector3(sin(a) * 0.1, 0, cos(a) * 0.1 - 0.06), Vector3(0.07, w * 0.8, w * 1.1), crust.lerp(crumb, 0.15 * (k % 2)), Vector3(0, rad_to_deg(a), 0))
			2:  # pan redondo con corte en cruz
				b.box(Vector3(0, 0, 0), Vector3(0.18, 0.1, 0.18), crust)
				b.box(Vector3(0, 0.051, 0), Vector3(0.14, 0.01, 0.025), crumb)
				b.box(Vector3(0, 0.051, 0), Vector3(0.025, 0.01, 0.14), crumb)
			3:  # pan de molde
				b.box(Vector3(0, 0.02, 0), Vector3(0.13, 0.12, 0.22), Color8(220, 165, 90))
				b.box(Vector3(0, 0.09, 0), Vector3(0.14, 0.03, 0.23), Color8(170, 105, 45))
			4:  # marraqueta: dos bollos pegados
				for z in [-0.055, 0.055]:
					b.box(Vector3(0, 0, z), Vector3(0.12, 0.08, 0.1), crust.lerp(crumb, 0.25))
					b.box(Vector3(0, 0.041, z), Vector3(0.02, 0.01, 0.07), crumb)
		_items[id] = b.build()
		return _items[id]
	match key:
		"cafe":  # vaso de café para llevar con tapa y faja (tres tamaños)
			var hc: float = [0.13, 0.1, 0.16][variant % 3]
			b.box(Vector3(0, 0.0, 0), Vector3(0.09, hc, 0.09), Color8(245, 242, 235))
			b.box(Vector3(0, 0.0, 0), Vector3(0.095, 0.05, 0.095), [Color8(150, 95, 55), Color8(60, 120, 80), Color8(190, 60, 60)][variant % 3])
			b.box(Vector3(0, 0.075, 0), Vector3(0.1, 0.025, 0.1), Color8(60, 40, 30))
		"pan":  # pan largo con cortes
			b.box(Vector3(0, 0, 0.04), Vector3(0.09, 0.08, 0.36), Color8(215, 155, 75))
			for z in [-0.08, 0.04, 0.16]:
				b.box(Vector3(0, 0.042, z), Vector3(0.06, 0.01, 0.05), Color8(245, 205, 130))
		"burger":  # hamburguesa en capas (la doble lleva otra carne)
			b.box(Vector3(0, -0.04, 0), Vector3(0.15, 0.035, 0.15), Color8(215, 160, 85))
			b.box(Vector3(0, -0.012, 0), Vector3(0.16, 0.03, 0.16), Color8(95, 55, 35))
			b.box(Vector3(0, 0.01, 0), Vector3(0.165, 0.015, 0.165), Color8(90, 175, 60))
			b.box(Vector3(0, 0.02, 0), Vector3(0.155, 0.012, 0.155), Color8(240, 190, 40))
			if variant == 1:
				b.box(Vector3(0, 0.04, 0), Vector3(0.16, 0.03, 0.16), Color8(95, 55, 35))
			b.box(Vector3(0, 0.05 + 0.03 * variant, 0), Vector3(0.15, 0.05, 0.15), Color8(225, 165, 85))
		"caja":  # caja de mercadería de la bodega, con cinta
			b.box(Vector3(0, -0.12, 0.05), Vector3(0.42, 0.3, 0.32), Color8(176, 132, 82))
			b.box(Vector3(0, 0.032, 0.05), Vector3(0.43, 0.01, 0.07), Color8(220, 200, 150))
		"escoba":  # escoba: el palo sube desde la mano y el cepillo queda en el suelo, adelante
			b.box(Vector3(0, -0.35, 0.18), Vector3(0.035, 1.0, 0.035), Color8(150, 110, 70))
			b.box(Vector3(0, -0.86, 0.32), Vector3(0.36, 0.08, 0.12), Color8(60, 60, 66))
			b.box(Vector3(0, -0.93, 0.32), Vector3(0.34, 0.07, 0.1), Color8(220, 190, 110))
		"trapeador":  # trapeador: palo y mopa de tiras en el suelo
			b.box(Vector3(0, -0.35, 0.18), Vector3(0.035, 1.0, 0.035), Color8(200, 200, 205))
			b.box(Vector3(0, -0.88, 0.32), Vector3(0.32, 0.1, 0.18), Color8(235, 235, 225))
			b.box(Vector3(0, -0.94, 0.32), Vector3(0.36, 0.05, 0.24), Color8(215, 215, 205))
		"trapo":  # paño de limpieza
			b.box(Vector3(0, -0.06, 0.04), Vector3(0.16, 0.03, 0.12), Color8(90, 160, 220))
		"tabla":  # tabla con hojas para revisar el inventario
			b.box(Vector3(0, -0.04, 0.06), Vector3(0.24, 0.3, 0.02), Color8(150, 110, 70))
			b.box(Vector3(0, -0.06, 0.072), Vector3(0.2, 0.24, 0.005), Color8(245, 245, 240))
			b.box(Vector3(0, 0.1, 0.075), Vector3(0.1, 0.03, 0.01), Color8(170, 170, 175))
		"celular":  # teléfono en la mano, con la pantalla prendida
			b.box(Vector3(0, -0.06, 0.02), Vector3(0.08, 0.16, 0.015), Color8(30, 32, 38))
			b.box(Vector3(0, -0.06, 0.029), Vector3(0.068, 0.14, 0.002), Color8(120, 190, 255))
		"paraguas":  # paraguas abierto: el palo sube desde la mano y la tela queda sobre la cabeza
			b.box(Vector3(0, 0.55, 0), Vector3(0.03, 1.1, 0.03), Color8(50, 50, 55))
			b.box(Vector3(0, 1.1, 0), Vector3(1.05, 0.06, 1.05), [Color8(200, 50, 60), Color8(40, 90, 170), Color8(240, 200, 60),
					Color8(40, 40, 45)][variant % 4])
			b.box(Vector3(0, 1.16, 0), Vector3(0.7, 0.06, 0.7), [Color8(220, 70, 80), Color8(60, 110, 190), Color8(250, 215, 90),
					Color8(60, 60, 66)][variant % 4])
		"diario":  # diario doblado
			b.box(Vector3(0, -0.12, 0), Vector3(0.05, 0.3, 0.22), Color8(238, 235, 225))
			b.box(Vector3(0.027, -0.05, 0), Vector3(0.005, 0.06, 0.18), Color8(40, 40, 45))
			b.box(Vector3(0.027, -0.15, 0.04), Vector3(0.005, 0.1, 0.08), Color8(200, 45, 45))
		"ropa":  # bolsa de compras con manillas
			b.box(Vector3(0, -0.17, 0), Vector3(0.26, 0.28, 0.1), [Blueprints.PRODUCT_COLORS.ropa, Color8(60, 140, 200),
					Color8(220, 90, 120), Color8(60, 60, 70)][variant % 4])
			b.box(Vector3(0, -0.02, 0), Vector3(0.14, 0.03, 0.02), Color8(240, 240, 240))
			b.box(Vector3(0, -0.15, 0.052), Vector3(0.12, 0.08, 0.005), Color8(240, 240, 240))
		_:  # electrónica: caja de un equipo nuevo
			b.box(Vector3(0, -0.11, 0), Vector3(0.3, 0.2, 0.08), Color8(240, 242, 245))
			b.box(Vector3(0, -0.11, 0.041), Vector3(0.22, 0.13, 0.005), [Blueprints.PRODUCT_COLORS.tech, Color8(40, 40, 45),
					Color8(200, 200, 205)][variant % 3])
	_items[id] = b.build()
	return _items[id]
