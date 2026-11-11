class_name Mall
extends RefCounted
## Un centro comercial: el de la avenida, frente a tu oficina (lado sur), y el de la playa, del lado de la oficina,
## sobre el pasto justo antes de la arena. Los dos miran a la avenida. Mientras no lo compras es un terreno en obra con su cartel; cuando lo compras se
## construye el edificio: un pasillo con fuente y 16 vitrinas (6 a cada lado y 4 al fondo). Cada vitrina con una
## sucursal tuya muestra su letrero, mostrador, repisas y un vendedor; las vacías tienen la cortina metálica abajo y el
## cartel SE ARRIENDA. Adentro pasea gente que mira tus vitrinas. Ver D.MALLS y Game.open_location.

# Dónde va cada uno: [x, lado de la calle], como un terreno.
const PLOTS := [[-84, -1], [85, 1]]
const PLOT := [-84, -1]   # el de la avenida
const W := 36.0       # ancho (x local)
const Z0 := 2.0       # frente (z local, hacia adentro)
const Z1 := 33.0      # fondo (detrás del de la playa pasa el pasaje del barrio)
const H := 7.5        # alto del cielo del pasillo
const HALL := 10.0    # el pasillo va de −HALL a HALL
const SHOP_H := 3.6   # alto de la entrada de cada vitrina
const BACK_Z := 26.5  # las vitrinas del fondo van de BACK_Z a Z1
const SIDE_Z := [4.0, 26.5]
const LANE := 8.0     # por donde camina la gente a cada lado del pasillo (entre las bancas y las vitrinas)

var city
var idx := 0          # 0 = frente a la oficina, 1 = la playa
var plot: Array = PLOT
var shoppers := []    # gente paseando: {node, at (local), path (local), wait, stops, leaving}
var spawn_t := 0.0
var built := false
var root: Node3D
var bld: Building = null
var rects := []
var spots := {}
var slots := []       # por vitrina: {rect (local) [x0, x1, z0, z1], face (dirección local hacia el pasillo), node, sig, staff, front}
var lot_spot := Vector3.ZERO
var collide := []     # todo lo que choca (edificio + vitrinas), armado en cada sync


func _init(owner_city, index := 0) -> void:
	city = owner_city
	idx = index
	plot = PLOTS[idx]


## Número global de la vitrina i de este centro comercial (como lo guarda Game en loc.mall).
func gslot(i: int) -> int:
	return idx * int(D.MALL.slots) + i


## Rectángulo local [x0, x1, z0, z1] de la vitrina i y hacia dónde mira su entrada (en x o z local).
static func slot_rect(i: int) -> Array:
	var side_w := (SIDE_Z[1] - SIDE_Z[0]) / 6.0
	if i < 6:    # lado izquierdo (x local negativo), la entrada mira a +x
		return [[-W / 2, -HALL, SIDE_Z[0] + i * side_w, SIDE_Z[0] + (i + 1) * side_w], Vector2(1, 0)]
	if i < 12:   # lado derecho, la entrada mira a −x
		var k := i - 6
		return [[HALL, W / 2, SIDE_Z[0] + k * side_w, SIDE_Z[0] + (k + 1) * side_w], Vector2(-1, 0)]
	var back_w := HALL * 2 / 4.0   # fondo, la entrada mira hacia la puerta (−z)
	var j := i - 12
	return [[-HALL + j * back_w, -HALL + (j + 1) * back_w, BACK_Z, Z1], Vector2(0, -1)]


## Centro (x, z) en el mundo del rectángulo que ocupa el centro comercial, para el mapa.
static func world_rect(i := 0) -> Rect2:
	var a := Blueprints.to_world(PLOTS[i], -W / 2, Z0)
	var b := Blueprints.to_world(PLOTS[i], W / 2, Z1)
	return Rect2(min(a.x, b.x), min(a.z, b.z), absf(a.x - b.x), absf(a.z - b.z))


## Dónde quedas al viajar al centro comercial: en la vereda, frente a la puerta.
static func entrance(i := 0) -> Vector3:
	return Blueprints.to_world(PLOTS[i], 0, -2.0)


## Hacia dónde miras al llegar a la entrada (grados, como City.yaw): hacia adentro.
static func entrance_yaw(i := 0) -> float:
	var d := Blueprints.to_world(PLOTS[i], 0, 1.0) - Blueprints.to_world(PLOTS[i], 0, 0.0)
	return rad_to_deg(atan2(d.x, d.z))


static func name_of(i: int) -> String:
	return D.MALLS[i].name


func destroy() -> void:
	_clear_shoppers()
	if guard != null and is_instance_valid(guard):
		guard.queue_free()
	guard = null
	for s in slots:
		_clear_slot(s)
	slots = []
	if bld:
		bld.destroy()
		bld = null
	if root and is_instance_valid(root):
		root.queue_free()
	root = null
	rects = []
	spots = {}
	collide = []


## Construye el terreno en obra o el edificio, según si ya lo compraste.
func sync(g: Game) -> void:
	if g == null:
		return
	if g.has_mall(idx) != built or (root == null and bld == null):
		destroy()
		built = g.has_mall(idx)
		if built:
			_build()
			bld.set_brand(g.company)
		else:
			_build_lot(g)
	if built:
		_sync_slots(g)
	collide = all_rects()


# ---------- terreno en obra ----------
func _build_lot(g: Game) -> void:
	root = Node3D.new()
	root.transform = Blueprints.plot_xf(plot)
	city.add_child(root)
	var b := Boxes.new()
	b.box(Vector3(0, 0.015, (Z0 + Z1) / 2), Vector3(W, 0.03, Z1 - Z0), Color8(150, 135, 110))   # tierra
	# Cerco de obra: paneles azules con postes alrededor de todo el terreno (el cartel queda afuera, en la vereda)
	var blue := Color8(40, 80, 150)
	var post := Color8(200, 200, 200)
	var hw := W / 2
	for side in [[Vector2(-hw, Z0), Vector2(GATE[0], Z0)], [Vector2(GATE[1], Z0), Vector2(hw, Z0)], [Vector2(-hw, Z1), Vector2(hw, Z1)],
			[Vector2(-hw, Z0), Vector2(-hw, Z1)], [Vector2(hw, Z0), Vector2(hw, Z1)]]:
		var a: Vector2 = side[0]
		var e: Vector2 = side[1]
		var along_x := absf(e.x - a.x) > 0.1
		var length := a.distance_to(e)
		var c := (a + e) / 2
		b.box(Vector3(c.x, 1.0, c.y), Vector3(length if along_x else 0.05, 1.8, 0.05 if along_x else length), blue)
		var n := ceili(length / 4.0)
		for i in n + 1:
			var p := a.lerp(e, float(i) / n)
			b.box(Vector3(p.x, 1.1, p.y), Vector3(0.12, 2.2, 0.12), post)
		rects.append(_world_rect(min(a.x, e.x) - 0.1, max(a.x, e.x) + 0.1, min(a.y, e.y) - 0.1, max(a.y, e.y) + 0.1, 2.0))
	# La silla del guardia, con una mesita y su radio
	var gp := Vector2(4.0, 10.0)
	b.box(Vector3(gp.x, 0.43, gp.y + 0.05), Vector3(0.56, 0.07, 0.56), Color8(60, 90, 160))
	b.box(Vector3(gp.x, 0.82, gp.y + 0.33), Vector3(0.56, 0.72, 0.06), Color8(60, 90, 160))
	for lx in [-0.24, 0.24]:
		for lz in [-0.2, 0.3]:
			b.box(Vector3(gp.x + lx, 0.2, gp.y + lz), Vector3(0.05, 0.4, 0.05), Color8(150, 150, 155))
	b.box(Vector3(gp.x + 0.9, 0.35, gp.y), Vector3(0.6, 0.7, 0.6), Color8(170, 120, 70))
	b.box(Vector3(gp.x + 0.9, 0.82, gp.y), Vector3(0.22, 0.24, 0.1), Color8(30, 30, 34))
	# Maqueta: grúa y cimientos
	b.box(Vector3(-6, 0.3, 18), Vector3(14, 0.6, 10), Color8(170, 170, 165))
	b.box(Vector3(9, 6.0, 22), Vector3(0.8, 12.0, 0.8), Color8(240, 190, 40))
	b.box(Vector3(5, 12.2, 22), Vector3(14, 0.5, 0.6), Color8(240, 190, 40))
	b.box(Vector3(11, 11.6, 22), Vector3(1.6, 1.0, 1.0), Color8(80, 80, 85))
	rects.append(_world_rect(-13, 1, 13, 23, 0.6))
	rects.append(_world_rect(8.5, 9.5, 21.5, 22.5, 12))
	# Cartel grande del proyecto
	b.box(Vector3(0, 1.6, Z0 - 0.6), Vector3(0.15, 3.2, 0.15), Blueprints.PALETTE.wood)
	b.box(Vector3(0, 3.6, Z0 - 0.6), Vector3(7.5, 2.4, 0.15), Color8(25, 45, 85))
	b.node(root, Mats.standard)
	Building.label(root, "CENTRO COMERCIAL", Vector3(0, 4.25, Z0 - 0.69), 15, Color8(240, 190, 60))
	Building.label(root, Lang.f("%d vitrinas · cómpralo por %s", [int(D.MALL.slots), Fmt.short(g.mall_cost(idx))]),
			Vector3(0, 3.55, Z0 - 0.69), 8, Color.WHITE, false)
	Building.label(root, "Presiona E aquí", Vector3(0, 2.95, Z0 - 0.69), 6, Color8(200, 210, 230), false)
	lot_spot = Blueprints.to_world(plot, 0, -1.4)
	_make_guard()


func _world_rect(x0: float, x1: float, z0: float, z1: float, top: float) -> Array:
	var a := Blueprints.to_world(plot, x0, z0)
	var e := Blueprints.to_world(plot, x1, z1)
	return [min(a.x, e.x), max(a.x, e.x), min(a.z, e.z), max(a.z, e.z), top]


# ---------- el edificio ----------
func _build() -> void:
	bld = Building.new(city, plot, "mall", Color.WHITE, "")
	root = bld.root
	rects = bld.rects
	spots = bld.spots
	for i in int(D.MALL.slots):
		var sr: Array = slot_rect(i)
		var r: Array = sr[0]
		var face: Vector2 = sr[1]
		var cx: float = (r[0] + r[1]) / 2
		var cz: float = (r[2] + r[3]) / 2
		# Punto del pasillo frente a la entrada (donde se apreta E)
		var front: Vector2
		if face.x > 0:
			front = Vector2(r[1] + 1.0, cz)
		elif face.x < 0:
			front = Vector2(r[0] - 1.0, cz)
		else:
			front = Vector2(cx, r[2] - 1.0)
		slots.append({"rect": r, "face": face, "node": null, "sig": "x", "staff": null, "rects": [],
				"front": Blueprints.to_world(plot, front.x, front.y), "front_local": front})


## Pone o cambia lo que hay en cada vitrina según tus sucursales.
func _sync_slots(g: Game) -> void:
	var by_slot := {}
	for loc in g.locations:
		var m := Game.mall_of(loc)
		if m >= 0 and Game.mall_index(m) == idx:
			by_slot[m - gslot(0)] = loc
	for i in slots.size():
		var s: Dictionary = slots[i]
		var loc = by_slot.get(i)
		var rival_key = g.rival_mall.get(str(gslot(i)))
		if loc == null and rival_key != null:   # la arrienda un rival: se arma como un local suyo
			loc = {"id": -1, "size": 1, "product": rival_key, "rival": D.rival_for(rival_key)}
		var sig = null if loc == null else [loc.id, loc.size, loc.product]
		if s.sig is String or s.sig != sig:
			_clear_slot(s)
			s.sig = sig
			s.loc = loc
			_fill_slot(i, s, loc)
		else:
			s.loc = loc


func _clear_slot(s: Dictionary) -> void:
	if s.node != null and is_instance_valid(s.node):
		s.node.queue_free()
	if s.staff != null and is_instance_valid(s.staff):
		s.staff.queue_free()
	s.node = null
	s.staff = null
	s.rects = []


## Transformación local de la vitrina: su origen en el centro de la entrada y +z hacia adentro de la tienda.
func _slot_xf(s: Dictionary) -> Transform3D:
	var r: Array = s.rect
	var face: Vector2 = s.face
	var origin: Vector3
	var yaw: float
	if face.x > 0:
		origin = Vector3(r[1], 0, (r[2] + r[3]) / 2)
		yaw = -PI / 2       # +z local de la vitrina = −x del centro comercial
	elif face.x < 0:
		origin = Vector3(r[0], 0, (r[2] + r[3]) / 2)
		yaw = PI / 2
	else:
		origin = Vector3((r[0] + r[1]) / 2, 0, r[2])
		yaw = 0.0
	return Transform3D(Basis(Vector3.UP, yaw), origin)


func _fill_slot(i: int, s: Dictionary, loc) -> void:
	var r: Array = s.rect
	var face: Vector2 = s.face
	var width: float = (r[3] - r[2]) if face.x != 0 else (r[1] - r[0])
	var depth: float = (r[1] - r[0]) if face.x != 0 else (r[3] - r[2])
	var n := Node3D.new()
	n.transform = _slot_xf(s)
	root.add_child(n)
	s.node = n
	var b := Boxes.new()
	var glow := Boxes.new()
	var hw := width / 2 - 0.15
	if loc == null:
		# Cortina metálica abajo, con rayas, y el cartel SE ARRIENDA
		b.box(Vector3(0, SHOP_H / 2, 0.12), Vector3(width - 0.3, SHOP_H, 0.06), Color8(150, 155, 162))
		for k in 10:
			b.box(Vector3(0, 0.25 + k * 0.34, 0.08), Vector3(width - 0.3, 0.04, 0.02), Color8(120, 124, 130))
		b.box(Vector3(0, 1.7, 0.06), Vector3(1.6, 0.8, 0.03), Color8(245, 245, 240))
		b.box(Vector3(0, SHOP_H + 0.35, -0.02), Vector3(width - 0.3, 0.7, 0.08), Color8(70, 74, 82))
		b.node(n, Mats.standard)
		var l := Building.label(n, "SE ARRIENDA", Vector3(0, 1.82, 0.03), 6, Color8(200, 50, 40))
		l.rotation.y = PI
		var l2 := Building.label(n, Lang.f("Vitrina %d", i + 1), Vector3(0, 1.52, 0.03), 4, Color8(60, 60, 66), false)
		l2.rotation.y = PI
		var l3 := Building.label(n, Lang.f("VITRINA %d", i + 1), Vector3(0, SHOP_H + 0.35, -0.07), 6, Color(1, 1, 1, 0.8))
		l3.rotation.y = PI
		s.rects = [_slot_world_rect(s, -width / 2, width / 2, 0.0, 0.25, SHOP_H)]
		return
	var pc: Color = Blueprints.PRODUCT_COLORS[loc.product]
	var name: String = D.PRODUCTS[loc.product].name
	if loc.has("rival"):   # vitrina de la competencia: su color y su marca
		pc = loc.rival.color
		name = loc.rival.company
	# Piso, letrero con el color de la marca y una franja de luz
	b.box(Vector3(0, 0.07, depth / 2), Vector3(width - 0.3, 0.02, depth - 0.2), pc.lerp(Color.WHITE, 0.7))
	b.box(Vector3(0, SHOP_H + 0.35, -0.02), Vector3(width - 0.3, 0.7, 0.08), pc)
	glow.box(Vector3(0, SHOP_H + 0.02, -0.05), Vector3(width - 0.4, 0.05, 0.05), Color8(255, 240, 200))
	# Vidrio a los costados de la entrada
	for sx in [-1, 1]:
		b.box(Vector3(sx * (hw - 0.05), SHOP_H / 2, 0.02), Vector3(0.1, SHOP_H, 0.1), Color8(70, 74, 82))
	# Mostrador con la caja y el vendedor detrás
	var cz := depth * 0.45
	b.box(Vector3(0, 0.5, cz), Vector3(width * 0.6, 1.0, 0.6), Blueprints.PALETTE.wood)
	b.box(Vector3(0, 1.03, cz), Vector3(width * 0.62, 0.06, 0.7), Color8(45, 47, 54))
	# Repisa del fondo con productos del color de la marca
	var back := depth - 0.45
	b.box(Vector3(0, 1.3, back), Vector3(width - 0.6, 2.6, 0.5), Blueprints.PALETTE.shelf)
	for y in [0.6, 1.3, 2.0]:
		for k in int((width - 1.0) / 0.45):
			var x := -width / 2 + 0.7 + k * 0.45
			b.box(Vector3(x, y + 0.17, back - 0.2), Vector3(0.3, 0.3, 0.25), pc.lerp(Color.WHITE, 0.15 * (k % 3)))
	# Un exhibidor a un costado de la entrada
	b.box(Vector3(-width / 2 + 0.7, 0.5, 1.0), Vector3(0.7, 1.0, 0.7), Color8(235, 235, 235))
	b.box(Vector3(-width / 2 + 0.7, 1.15, 1.0), Vector3(0.4, 0.3, 0.4), pc)
	b.node(n, Mats.standard)
	glow.node(n, Mats.emissive, false)
	var reg := MeshInstance3D.new()
	reg.mesh = Actors.cash_register()
	reg.material_override = Mats.smooth
	reg.visibility_range_end = 40.0
	reg.position = Vector3(0.5, 1.07, cz)
	reg.rotation.y = PI   # el teclado mira al vendedor (que está más adentro)
	n.add_child(reg)
	var sign := Building.label(n, name.to_upper(), Vector3(0, SHOP_H + 0.42, -0.07), 9 if width > 4 else 8, Color.WHITE)
	sign.rotation.y = PI
	if loc.has("rival") and Admin.rival_texture(loc.rival.key) != null:   # el logo del rival junto al letrero
		var logo := Sprite3D.new()
		logo.texture = Admin.rival_texture(loc.rival.key)
		logo.pixel_size = 0.6 / 256.0
		logo.position = Vector3(width / 2 - 0.55, SHOP_H + 0.35, -0.12)
		logo.rotation.y = PI
		logo.shaded = false
		logo.alpha_cut = SpriteBase3D.ALPHA_CUT_DISCARD
		n.add_child(logo)
	var sub := Building.label(n, D.PRODUCTS[loc.product].name if loc.has("rival") else D.SIZES[loc.size].name,
			Vector3(0, SHOP_H + 0.14, -0.07), 4, Color(1, 1, 1, 0.85), false)
	sub.rotation.y = PI
	Mats.add_light(n, Vector3(0, SHOP_H - 0.3, depth / 2), 9.0, true)
	# Vendedor detrás del mostrador, mirando al pasillo
	var p := Person.new(pc, null, true)
	city.add_child(p)
	p.position = n.global_transform * Vector3(-0.4, 0, cz + 0.8)
	p.rotation.y = n.global_rotation.y + PI
	s.staff = p
	s.rects = [_slot_world_rect(s, -width * 0.31, width * 0.31, cz - 0.3, cz + 0.3, 1.06),
			_slot_world_rect(s, -width / 2, width / 2, back - 0.25, back + 0.25, 2.6),
			_slot_world_rect(s, -width / 2 + 0.35, -width / 2 + 1.05, 0.65, 1.35, 1.0)]


## Rectángulo local de la vitrina (x a lo ancho, z hacia adentro) a [x0, x1, z0, z1, alto] en el mundo.
func _slot_world_rect(s: Dictionary, x0: float, x1: float, z0: float, z1: float, top: float) -> Array:
	var xf: Transform3D = root.transform * _slot_xf(s)
	var a := xf * Vector3(x0, 0, z0)
	var e := xf * Vector3(x1, 0, z1)
	return [min(a.x, e.x), max(a.x, e.x), min(a.z, e.z), max(a.z, e.z), top]


## Todas las cajas que chocan (edificio y lo que hay en cada vitrina).
func all_rects() -> Array:
	var out := rects.duplicate()
	for s in slots:
		out += s.rects
	return out


## Pregunta antes de comprar el centro comercial.
func ask_buy(g: Game) -> void:
	city.confirm(Lang.f("¿Comprar %s por %s?", [Lang.noun(name_of(idx)), Fmt.money(g.mall_cost(idx))]), mall_pitch(g, idx),
			Lang.f("Sí, construir (%s)", Fmt.short(g.mall_cost(idx))), func():
				var res: Array = g.buy_mall(idx)
				if res[0]:
					city.sfx.play("record", 0.8)
				city.toast(res[1], "good" if res[0] else "bad"))


## Qué ganas con el centro comercial (para el botón de compra y la tablet).
static func mall_pitch(g: Game, i := 0) -> String:
	var m: Dictionary = D.MALLS[i]
	return Lang.f("%d vitrinas para puestos y locales. +%d%% de clientes, techado y mitad de alquiler. Mantenimiento: %s/mes.", [int(m.slots), roundi((m.traffic - 1) * 100), Fmt.money(m.upkeep * g.price_index)])


## Lugares donde se apreta E: el cartel del terreno o la entrada de cada vitrina.
func interactables(g: Game) -> Array:
	var items := []
	if not built:
		items.append([lot_spot, Lang.f("Comprar %s (%s)", [Lang.noun(name_of(idx)), Fmt.money(g.mall_cost(idx))]), ask_buy.bind(g)])
		return items
	for i in slots.size():
		var s: Dictionary = slots[i]
		if s.get("loc") == null:
			var gi := gslot(i)
			items.append([s.front, Lang.f("Abrir una tienda en la vitrina %d", i + 1), func(): city.overlays.show("vitrina", gi)])
		elif s.loc.has("rival"):
			var key: String = s.loc.product
			var gi := gslot(i)
			if city.refusing("m%d" % gi):
				continue
			items.append([s.front, Lang.f("Comprar este local de %s (%s · %s)", [s.loc.rival.company, Lang.noun(D.PRODUCTS[key].name), Fmt.money(g.acquire_cost(key))]),
					func(): city.buy_competitor(key, -1, gi)])
		else:
			var loc: Dictionary = s.loc
			var key: String = loc.product
			items.append([s.front, Lang.f("Administrar %s de %s (vitrina %d)", [Lang.noun(D.SIZES[loc.size].name), Lang.noun(D.PRODUCTS[key].name), i + 1]),
					func(): city.manage_market(key)])
	return items


# ---------- gente paseando adentro ----------
## Cuánta gente pasea: más mientras más vitrinas tuyas hay abiertas (de noche, poca).
func _want_shoppers() -> int:
	var open := _open_slots().size()
	if open == 0:
		return 0
	var n := mini(3 + open, 14)
	if city.sky != null and city.sky.night:
		n = maxi(1, n / 3)
	return n


func _open_slots() -> Array:
	var out := []
	for i in slots.size():
		if slots[i].get("loc") != null:
			out.append(i)
	return out


## Camino (en coordenadas locales) desde `from` hasta el frente de la vitrina i, por el carril de su lado del pasillo
## (así no pasa por la fuente, las bancas ni los maceteros).
func _path_to_slot(from: Vector2, i: int) -> Array:
	var s: Dictionary = slots[i]
	var f: Vector2 = s.front_local
	var lane := LANE if f.x > 0 else -LANE
	var pts := []
	if absf(from.x - lane) > 0.3:
		if absf(from.x) < LANE - 0.5:   # está en la entrada: primero entra un poco
			pts.append(Vector2(from.x, 3.2))
			pts.append(Vector2(lane, 3.2))
		else:                          # está en el otro carril o frente a una vitrina: cruza por adelante
			pts.append(Vector2(signf(from.x) * LANE, from.y))
			if signf(from.x) != signf(lane):
				pts.append(Vector2(signf(from.x) * LANE, 3.2))
				pts.append(Vector2(lane, 3.2))
	pts.append(Vector2(lane, f.y))
	var face: Vector2 = s.face
	if face.y != 0:   # las del fondo: de lado hasta su frente
		pts.append(f + Vector2(randf_range(-0.6, 0.6), randf_range(-0.3, 0.2)))
	else:
		pts.append(f + Vector2(0, randf_range(-0.6, 0.6)))
	return pts


func _spawn_shopper(inside := false) -> void:
	var open := _open_slots()
	if open.is_empty():
		return
	var p := Person.new()
	city.add_child(p)
	var at := Vector2(randf_range(-1.5, 1.5), -3.0)   # entra desde la vereda
	var path := [Vector2(at.x, 2.5)] + _path_to_slot(Vector2(at.x, 2.5), open.pick_random())
	if inside:   # al llegar ya hay gente adentro: empieza en el carril, cerca de su vitrina
		at = path[-2]
		path = [path[-1]]
	p.position = Blueprints.to_world(plot, at.x, at.y)
	shoppers.append({"node": p, "at": at, "path": path, "wait": 0.0, "stops": randi_range(1, 3), "leaving": false})


func _clear_shoppers() -> void:
	for sh in shoppers:
		if is_instance_valid(sh.node):
			sh.node.queue_free()
	shoppers = []


func _nearest_slot(at: Vector2) -> int:
	var best := -1
	var bd := 1e9
	for i in slots.size():
		var dd: float = (slots[i].front_local as Vector2).distance_to(at)
		if dd < bd:
			bd = dd
			best = i
	return best


## Mueve a la gente por el pasillo: va a una vitrina, se queda mirando un rato (a veces sale con algo en la mano),
## va a otra y al final sale por la puerta. Solo si estás cerca: lejos no se ve.
func update(dt: float) -> void:
	if not built and root != null:
		_update_guard(dt)
		return
	if not built or root == null or slots.is_empty():
		return
	var center := Blueprints.to_world(plot, 0, (Z0 + Z1) / 2)
	if city.player.position.distance_to(center) > 90.0:
		if shoppers:
			_clear_shoppers()
		return
	var want := _want_shoppers()
	if shoppers.is_empty() and want > 0:
		for k in mini(want, 6):
			_spawn_shopper(true)
	spawn_t -= dt
	if spawn_t <= 0.0 and shoppers.size() < want:
		spawn_t = randf_range(1.5, 4.0)
		_spawn_shopper()
	var speed := 1.3
	for sh in shoppers.duplicate():
		var p: Person = sh.node
		if not is_instance_valid(p):
			shoppers.erase(sh)
			continue
		if sh.wait > 0.0:
			sh.wait -= dt
			p.animate(0.0, dt)
			continue
		if sh.path.is_empty():
			if sh.leaving:
				p.queue_free()
				shoppers.erase(sh)
				continue
			_arrive(sh)
			continue
		var goal: Vector2 = sh.path[0]
		var d: Vector2 = goal - sh.at
		var step := speed * dt
		if d.length() <= step:
			sh.at = goal
			sh.path.pop_front()
		else:
			sh.at += d.normalized() * step
		var w := Blueprints.to_world(plot, sh.at.x, sh.at.y)
		var dir := w - p.position
		p.position = w
		if dir.length() > 0.001:
			p.rotation.y = atan2(dir.x, dir.z)
		p.animate(speed, dt)


## Llegó frente a una vitrina: la mira un rato, a veces compra algo, y decide a cuál ir o si se va.
func _arrive(sh: Dictionary) -> void:
	var p: Person = sh.node
	sh.wait = randf_range(2.5, 6.0)
	sh.stops -= 1
	var i := _nearest_slot(sh.at)
	if i >= 0:
		var s: Dictionary = slots[i]
		var r: Array = s.rect
		var c := Blueprints.to_world(plot, (r[0] + r[1]) / 2, (r[2] + r[3]) / 2)
		p.rotation.y = atan2(c.x - p.position.x, c.z - p.position.z)
		if s.get("loc") != null and p.item == null and randf() < 0.45:
			p.hold(s.loc.product)
	var open := _open_slots()
	if sh.stops <= 0 or open.is_empty():
		var lane := LANE if sh.at.x > 0 else -LANE
		var out_x := randf_range(-1.5, 1.5)
		sh.path = [Vector2(lane, sh.at.y), Vector2(lane, 3.2), Vector2(out_x, 2.5), Vector2(out_x, -3.0)]
		sh.leaving = true
	else:
		sh.path = _path_to_slot(sh.at, open.pick_random())


# ---------- guardia del terreno en obra ----------
# Se puede entrar por el portón, pero es propiedad privada: si entras sin haber comprado el terreno, el guardia corre
# hacia ti, te pega con la tonfa y sales volando a la vereda (City.hit_by_guard).
const GATE := [6.0, 10.0]        # el portón del cerco de adelante (x local)
const GUARD_POST := Vector2(4.0, 10.0)   # su silla, en medio de la obra (entre el portón y los cimientos)
var guard: Person = null
var guard_state := "post"        # post, chase, swing, back
var guard_t := 0.0


func _make_guard() -> void:
	var look: Dictionary = Wardrobe.DEFAULT_LOOK.duplicate()
	look.shirt = [32, 58, 128]      # uniforme azul de guardia
	look.pants = [24, 34, 70]
	look.shoes = [20, 20, 24]
	look.hat = "gorra"
	look.hair_style = "corto"
	look.skin = [196, 150, 110]
	guard = Person.new(null, null, false, look)
	city.add_child(guard)
	# La tonfa: palo negro con el mango de lado, en la mano derecha
	var b := Boxes.new()
	b.box(Vector3(0, 0, 0.22), Vector3(0.06, 0.06, 0.62), Color8(18, 18, 20))
	b.box(Vector3(0, -0.08, 0.05), Vector3(0.05, 0.16, 0.05), Color8(18, 18, 20))
	var baton := b.node(guard.arms[1], Mats.smooth, false)
	baton.position = Vector3(0, -0.74, 0.04)
	guard.position = Blueprints.to_world(plot, GUARD_POST.x, GUARD_POST.y)
	guard.rotation.y = _yaw_to(Blueprints.to_world(plot, GUARD_POST.x, -5.0) - guard.position)
	guard_state = "post"
	guard.sit(1.0)


static func _yaw_to(d: Vector3) -> float:
	return atan2(d.x, d.z)


## ¿El jugador está dentro del terreno (en coordenadas locales)?
func _inside(p: Vector3) -> bool:
	var l: Vector3 = root.transform.affine_inverse() * p
	return absf(l.x) < W / 2 - 0.2 and l.z > Z0 + 0.25 and l.z < Z1 - 0.2


func _update_guard(dt: float) -> void:
	if guard == null or not is_instance_valid(guard):
		return
	var p: Vector3 = city.player.position
	var trespass: bool = _inside(p) and city.knock == null and not city.overlays.open()
	guard_t += dt
	match guard_state:
		"post", "back":
			if trespass:
				guard_state = "chase"
				guard.sit(0.0)   # se para de un salto
				city.pop(guard.position + Vector3(0, 0.4, 0), "¡Oiga! ¡Propiedad privada!", "red")
			elif guard_state == "back":
				var home := Blueprints.to_world(plot, GUARD_POST.x, GUARD_POST.y)
				if _walk(home, 3.5, dt):
					guard_state = "post"
					guard.rotation.y = _yaw_to(Blueprints.to_world(plot, GUARD_POST.x, -5.0) - guard.position)
			else:
				guard.animate(0.0, dt)
				guard.sit(1.0)   # sentado en su silla, mirando el portón
		"chase":
			if not trespass:
				guard_state = "back"
			elif Vector2(p.x - guard.position.x, p.z - guard.position.z).length() < 1.6:
				guard_state = "swing"
				guard_t = 0.0
			else:
				_walk(p, 9.0, dt)   # corre más rápido que tú (no te escapas corriendo)
		"swing":
			guard.rotation.y = _yaw_to(p - guard.position)
			guard.animate(0.0, dt)
			# Levanta la tonfa y la baja de golpe
			var k := guard_t / 0.2
			guard.arms[1].rotation.x = deg_to_rad(lerpf(-170.0, -30.0, clampf(k, 0.0, 1.0)))
			if guard_t >= 0.12 and city.knock == null and _inside(p):
				city.hit_by_guard(guard.position, self)
			if guard_t > 0.5:
				guard.arms[1].rotation.x = 0.0
				guard_state = "back"


## Camina hacia `to` (sin chocar: el terreno está vacío). Devuelve true al llegar.
func _walk(to: Vector3, speed: float, dt: float) -> bool:
	var d := Vector3(to.x - guard.position.x, 0, to.z - guard.position.z)
	if d.length() < 0.15:
		guard.animate(0.0, dt)
		return true
	var step: float = min(d.length(), speed * dt)
	guard.position += d.normalized() * step
	guard.rotation.y = _yaw_to(d)
	guard.animate(speed, dt)
	return false
