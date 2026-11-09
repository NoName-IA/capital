class_name Mall
extends RefCounted
## El centro comercial frente a tu oficina central (lado sur de la avenida). Mientras no lo compras es un terreno en
## obra con su cartel; cuando lo compras se construye el edificio: un pasillo con fuente y 16 vitrinas (6 a cada
## lado y 4 al fondo). Cada vitrina con una sucursal tuya muestra su letrero, mostrador, repisas y un vendedor; las
## vacías tienen la cortina metálica abajo y el cartel SE ARRIENDA. Ver D.MALL y Game.open_location.

const PLOT := [-83, -1]
const W := 32.0       # ancho (x local)
const Z0 := 2.0       # frente (z local, hacia adentro)
const Z1 := 32.0      # fondo
const H := 7.0        # alto del cielo del pasillo
const HALL := 9.0     # el pasillo va de −HALL a HALL
const SHOP_H := 3.6   # alto de la entrada de cada vitrina
const BACK_Z := 26.0  # las vitrinas del fondo van de BACK_Z a Z1
const SIDE_Z := [4.0, 26.0]

var city
var built := false
var root: Node3D
var bld: Building = null
var rects := []
var spots := {}
var slots := []       # por vitrina: {rect (local) [x0, x1, z0, z1], face (dirección local hacia el pasillo), node, sig, staff, front}
var lot_spot := Vector3.ZERO
var collide := []     # todo lo que choca (edificio + vitrinas), armado en cada sync


func _init(owner_city) -> void:
	city = owner_city


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
static func world_rect() -> Rect2:
	var a := Blueprints.to_world(PLOT, -W / 2, Z0)
	var b := Blueprints.to_world(PLOT, W / 2, Z1)
	return Rect2(min(a.x, b.x), min(a.z, b.z), absf(a.x - b.x), absf(a.z - b.z))


## Dónde quedas al viajar al centro comercial: en la vereda, frente a la puerta.
static func entrance() -> Vector3:
	return Blueprints.to_world(PLOT, 0, -2.0)


func destroy() -> void:
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
	if g.mall != built or (root == null and bld == null):
		destroy()
		built = g.mall
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
	root.position = Vector3(PLOT[0], 0, PLOT[1] * Blueprints.FRONT)
	root.rotation.y = PI
	city.add_child(root)
	var b := Boxes.new()
	b.box(Vector3(0, 0.015, (Z0 + Z1) / 2), Vector3(W, 0.03, Z1 - Z0), Color8(150, 135, 110))   # tierra
	# Cerco de obra: paneles azules con postes, abierto al medio para entrar a mirar
	var blue := Color8(40, 80, 150)
	for x in range(-16, 17, 4):
		b.box(Vector3(x, 1.1, Z0), Vector3(0.12, 2.2, 0.12), Color8(200, 200, 200))
	for seg in [[-16.0, -3.0], [3.0, 16.0]]:
		var cx: float = (seg[0] + seg[1]) / 2
		var w: float = seg[1] - seg[0]
		b.box(Vector3(cx, 1.0, Z0), Vector3(w, 1.8, 0.05), blue)
		rects.append(_world_rect(seg[0], seg[1], Z0 - 0.1, Z0 + 0.1, 2.0))
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
	Building.label(root, Lang.f("%d vitrinas · cómpralo por %s", [int(D.MALL.slots), Fmt.short(g.mall_cost())]),
			Vector3(0, 3.55, Z0 - 0.69), 8, Color.WHITE, false)
	Building.label(root, "Presiona E aquí", Vector3(0, 2.95, Z0 - 0.69), 6, Color8(200, 210, 230), false)
	lot_spot = Blueprints.to_world(PLOT, 0, -1.4)


func _world_rect(x0: float, x1: float, z0: float, z1: float, top: float) -> Array:
	var a := Blueprints.to_world(PLOT, x0, z0)
	var e := Blueprints.to_world(PLOT, x1, z1)
	return [min(a.x, e.x), max(a.x, e.x), min(a.z, e.z), max(a.z, e.z), top]


# ---------- el edificio ----------
func _build() -> void:
	bld = Building.new(city, PLOT, "mall", Color.WHITE, "")
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
				"front": Blueprints.to_world(PLOT, front.x, front.y)})


## Pone o cambia lo que hay en cada vitrina según tus sucursales.
func _sync_slots(g: Game) -> void:
	var by_slot := {}
	for loc in g.locations:
		if Game.mall_of(loc) >= 0:
			by_slot[Game.mall_of(loc)] = loc
	for i in slots.size():
		var s: Dictionary = slots[i]
		var loc = by_slot.get(i)
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
	var sub := Building.label(n, D.SIZES[loc.size].name, Vector3(0, SHOP_H + 0.14, -0.07), 4, Color(1, 1, 1, 0.85), false)
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
	city.confirm(Lang.f("¿Comprar el centro comercial por %s?", Fmt.money(g.mall_cost())), mall_pitch(g),
			Lang.f("Sí, construir (%s)", Fmt.short(g.mall_cost())), func():
				var res: Array = g.buy_mall()
				if res[0]:
					city.sfx.play("record", 0.8)
				city.toast(res[1], "good" if res[0] else "bad"))


## Qué ganas con el centro comercial (para el botón de compra y la tablet).
static func mall_pitch(g: Game) -> String:
	return Lang.f("%d vitrinas para puestos y locales cuando ya no quedan terrenos en la avenida. Las tiendas de adentro tienen +%d%% de clientes, están techadas y pagan la mitad del alquiler. Mantenimiento y seguridad: %s/mes. Es una inversión (CAPEX) que se deprecia en 5 años.", [int(D.MALL.slots), roundi((D.MALL.traffic - 1) * 100), Fmt.money(D.MALL.upkeep * g.price_index)])


## Lugares donde se apreta E: el cartel del terreno o la entrada de cada vitrina.
func interactables(g: Game) -> Array:
	var items := []
	if not built:
		items.append([lot_spot, Lang.f("Comprar el centro comercial (%s)", Fmt.money(g.mall_cost())), ask_buy.bind(g)])
		return items
	for i in slots.size():
		var s: Dictionary = slots[i]
		if s.get("loc") == null:
			items.append([s.front, Lang.f("Abrir una tienda en la vitrina %d", i + 1), func(): city.overlays.show("vitrina", i)])
		else:
			var loc: Dictionary = s.loc
			var key: String = loc.product
			items.append([s.front, Lang.f("Administrar %s de %s (vitrina %d)", [Lang.noun(D.SIZES[loc.size].name), Lang.noun(D.PRODUCTS[key].name), i + 1]),
					func(): city.manage_market(key)])
	return items
