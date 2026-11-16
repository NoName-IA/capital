class_name Tower
extends RefCounted
## El último piso de la oficina central (la presidencia) y los pisos de ejecutivos que hay debajo. En el vestíbulo, al
## fondo y de frente a la puerta, está el ascensor: con E subes directo a la presidencia (un fundido y listo). En la
## presidencia, con E en el ascensor vuelves al vestíbulo. El viaje en la cabina de vidrio pasando por los pisos de
## ejecutivos se ve solo en el final (go_up_finale).
##
## Como el suelo de la ciudad es plano (City.floor_at y City.blocked solo saben de alturas de cajas, no de pisos
## apilados), la presidencia está armada aparte, lejos de la ciudad (ORIGIN), a la altura del suelo; los pisos de
## ejecutivos van debajo de ella (solo se ven en el viaje) y alrededor hay una ciudad de mentira vista desde lo alto.
## Coordenadas locales: el piso de la presidencia en y = 0, x de −8 a 8, z de −7 (el frente, con el ascensor) a 7.

const ORIGIN := Vector3(-80.0, 0.0, -300.0)
const W := 16.0
const D := 14.0
const ROOM_H := 3.8
const FLOOR_H := 4.2
const CAB_Z := -8.1              # el centro de la cabina de vidrio, pegada al frente
const LOBBY_LIFT := Vector3(0, 0, 14.4)    # en la oficina (City.HQ): frente al ascensor del vestíbulo (al fondo)
const ARRIVE := Vector3(0, 0, -5.6)        # donde quedas al llegar a la presidencia
const DESK := Vector3(0, 0, 3.9)
const PC_SCREEN_Z := 0.38        # la cara de la pantalla (relativa al escritorio): mira hacia el sillón
const PC_SEAT_Z := 1.25          # el sillón, detrás del escritorio
const FADE := 0.35
const DOORS := 0.8

var city
var root: Node3D
var offices: Node3D
var cab: Node3D
var doors: Array[Node3D] = []
var typists := []          # [holder, persona, fase]
var lights_office := []
var rects := []            # choques de la presidencia, en el mundo
var spots := {}            # "ceiling" (para la cámara y el clima)
var pc_spots := {}         # la computadora: computer (donde aprietas E), pc_seat, pc_screen, pc_screen_w/h (en el mundo)
var floors := 1            # pisos de ejecutivos debajo de la presidencia
var company_label: Label3D
var worth_label: Label3D

var phase := ""            # "", "out" (se oscurece) / "in" (se aclara arriba), "down"; en el final "ride", "doors"
var t := 0.0
var ride_time := 3.0
var fade := 0.0
var anim_t := 0.0
var finale_mode := false   # la subida del final (Finale): más lenta, los ejecutivos de pie celebrando mirándote y el visor con los años
var milestones := []       # [año, título] de cada rango que conseguiste, del primero al último
var lobby_doors: Array[Node3D] = []   # las puertas del ascensor del vestíbulo (en la oficina)
var lux := 0               # cuánto lujo tiene la presidencia: sube con tu rango (ver LUXURY)

# Lo que estrena la presidencia en cada rango (el índice es el rango; 0 = Vendedor ambulante: lo básico).
const LUXURY := [
	"",
	"una alfombra y una biblioteca",
	"una sala con sillones de cuero y la pantalla con lo que vale tu empresa",
	"un techo con luces cálidas, mármol con filos dorados y más plantas",
	"un bar con botellas iluminadas",
	"una lámpara de aros dorados, una vitrina con lingotes de oro y un ascensor dorado",
]


## El lujo de la presidencia para un rango.
static func lux_for(rank: int) -> int:
	return clampi(rank, 0, LUXURY.size() - 1)


func _init(owner_city) -> void:
	city = owner_city


func w(v: Vector3) -> Vector3:
	return ORIGIN + v


## ¿`p` (en el mundo) está en la presidencia?
func inside(p: Vector3) -> bool:
	return absf(p.x - ORIGIN.x) < 9.0 and p.z > ORIGIN.z - 10.0 and p.z < ORIGIN.z + 8.0


func busy() -> bool:
	return phase != ""


## El piso de la presidencia según el aspecto de la oficina: abajo quedan los demás pisos (al menos uno de ejecutivos).
func build(tier: int) -> void:
	if root != null and is_instance_valid(root):
		root.queue_free()
	root = Node3D.new()
	root.name = "Presidencia"
	root.position = ORIGIN
	city.add_child(root)
	floors = maxi(1, [1, 2, 4, 6][tier] - 1)
	typists.clear()
	lights_office.clear()
	doors.clear()
	rects.clear()
	_ceo_room()
	offices = Node3D.new()
	offices.visible = false
	root.add_child(offices)
	for k in range(1, floors + 1):
		_office_floor(k)
	_cab()
	_skyline()
	_lobby_lift()
	spots = {"ceiling": [ORIGIN.x - 9.0, ORIGIN.x + 9.0, ORIGIN.z - 10.0, ORIGIN.z + 8.0, ROOM_H]}
	pc_spots = {"computer": w(DESK + Vector3(1.3, 0, PC_SEAT_Z)), "pc_seat": w(DESK + Vector3(0, 0, PC_SEAT_Z)),
			"pc_screen": w(DESK + Vector3(0, 1.3, PC_SCREEN_Z)), "pc_screen_w": 0.96, "pc_screen_h": 0.6}


func _rect(x0: float, x1: float, z0: float, z1: float, h: float) -> void:
	rects.append([ORIGIN.x + x0, ORIGIN.x + x1, ORIGIN.z + z0, ORIGIN.z + z1, h])


func _light(parent: Node3D, pos: Vector3, rng: float, energy: float, col := Color(1.0, 0.92, 0.8)) -> OmniLight3D:
	var l := OmniLight3D.new()
	l.position = pos
	l.omni_range = rng
	l.light_energy = energy
	l.light_color = col
	l.shadow_enabled = false
	parent.add_child(l)
	return l


# ---------- la presidencia ----------
func _ceo_room() -> void:
	var b := Boxes.new()
	var shell := Boxes.new()   # techo y paredes: sin sombra, así el sol no deja la oficina a oscuras
	var glow := Boxes.new()
	var warm := Boxes.new()    # luces cálidas (la cornisa del techo, los focos, la lámpara colgante)
	var marble := Color8(236, 232, 224)
	var black_marble := Color8(28, 28, 32)
	var walnut := Color8(112, 72, 46)
	var lacquer := Color8(22, 22, 26)
	var gold := Color8(206, 170, 96)   # dorado champaña, más sobrio
	var ceiling := Color8(244, 240, 232)
	var leather := Color8(118, 74, 46)   # cuero coñac
	# Piso de mármol claro en losas grandes con juntas doradas y un borde de mármol negro
	b.box(Vector3(0, -0.15, 0), Vector3(W, 0.3, D), marble)
	if lux >= 3:
		_floor_trim(b, black_marble)
	if lux >= 1:
		_rug(b, gold)
	_ceiling(shell, warm, ceiling)
	if lux >= 5:
		_chandelier(b, warm, gold)
	_walls(b, shell, walnut, black_marble, lacquer, gold)
	_desk(b, glow, warm, lacquer, gold, leather)
	if lux >= 1:
		_bookcase(b, warm, lacquer, gold)
	if lux >= 5:
		_gold_vitrine(b, warm, black_marble, gold)
	if lux >= 2:
		_lounge(b, black_marble, gold, leather)
	if lux >= 4:
		_bar(b, warm, black_marble, gold)
	_screens(b, glow, warm, lacquer, gold)
	_plants(b, lacquer, gold)
	b.node(root, Mats.standard)
	shell.node(root, Mats.standard, false)
	glow.node(root, Mats.emissive, false)
	warm.node(root, Mats.emissive, false)
	company_label = Building.label(root, "", Vector3(-4.6, 2.1, -D / 2 + 0.11), 16, gold, true, false)
	company_label.rotation.y = 0.0
	worth_label = Building.label(root, "", Vector3(4.6, 2.55, -D / 2 + 0.15), 9, Color8(150, 255, 190), true, false)
	worth_label.rotation.y = 0.0
	worth_label.visible = lux >= 2
	var plate := Building.label(root, "CEO", DESK + Vector3(-0.2, 0.9, -0.52), 4, Color8(40, 30, 20), true, false)
	plate.rotation.y = PI
	for x in [-4.0, 4.0]:   # bien iluminada: luces del techo (más cálidas con lujo), la lámpara y una sobre el escritorio
		for z in [-3.5, 0.5, 4.5]:
			_light(root, Vector3(x, ROOM_H - 0.5, z), 10.0, 1.5 if lux >= 3 else 1.3,
					Color(1.0, 0.9, 0.76) if lux >= 3 else Color(1.0, 0.96, 0.9))
	if lux >= 5:
		_light(root, Vector3(0, 2.75, 1.0), 7.0, 1.3, Color(1.0, 0.86, 0.66))
	_light(root, DESK + Vector3(0, 2.4, 0), 6.0, 0.9, Color(1.0, 0.9, 0.75))


func _floor_trim(b: Boxes, black_marble: Color) -> void:
	for i in range(1, 8):
		b.box(Vector3(-W / 2 + i * 2, 0.002, 0), Vector3(0.018, 0.01, D - 1.2), Color8(200, 184, 150))
	for i in range(1, 7):
		b.box(Vector3(0, 0.002, -D / 2 + i * 2), Vector3(W - 1.2, 0.01, 0.018), Color8(200, 184, 150))
	for sx in [-1, 1]:
		b.box(Vector3(sx * (W / 2 - 0.3), 0.004, 0), Vector3(0.6, 0.01, D), black_marble)
	for sz in [-1, 1]:
		b.box(Vector3(0, 0.004, sz * (D / 2 - 0.3)), Vector3(W, 0.01, 0.6), black_marble)


func _rug(b: Boxes, gold: Color) -> void:
	# Alfombra azul noche con doble borde dorado
	b.box(Vector3(0, 0.015, 1.0), Vector3(7.2, 0.02, 6.4), gold)
	b.box(Vector3(0, 0.022, 1.0), Vector3(7.0, 0.02, 6.2), Color8(22, 30, 52))
	b.box(Vector3(0, 0.028, 1.0), Vector3(6.2, 0.02, 5.4), gold)
	b.box(Vector3(0, 0.034, 1.0), Vector3(6.1, 0.02, 5.3), Color8(28, 38, 64))


func _ceiling(shell: Boxes, warm: Boxes, ceiling: Color) -> void:
	# Techo; con lujo, un cajón al medio con luz cálida escondida en la cornisa y focos empotrados alrededor
	shell.box(Vector3(0, ROOM_H + 0.1, 0), Vector3(W + 0.6, 0.2, D + 0.6), ceiling)
	if lux < 3:
		for x in [-4.0, 4.0]:   # paneles de luz sencillos
			for z in [-3.5, 0.5, 4.5]:
				warm.box(Vector3(x, ROOM_H - 0.01, z), Vector3(1.2, 0.02, 0.6), Color8(245, 245, 240))
		return
	for sz in [-1, 1]:
		shell.box(Vector3(0, ROOM_H - 0.2, sz * (D / 2 - 1.2)), Vector3(W, 0.4, 2.4), ceiling)
	for sx in [-1, 1]:
		shell.box(Vector3(sx * (W / 2 - 1.2), ROOM_H - 0.2, 0), Vector3(2.4, 0.4, D), ceiling)
	var cove := Color8(255, 214, 150)
	for sz in [-1, 1]:
		warm.box(Vector3(0, ROOM_H - 0.41, sz * (D / 2 - 2.42)), Vector3(W - 4.8, 0.03, 0.05), cove)
	for sx in [-1, 1]:
		warm.box(Vector3(sx * (W / 2 - 2.42), ROOM_H - 0.41, 0), Vector3(0.05, 0.03, D - 4.8), cove)
	for x in [-6.8, -3.4, 0.0, 3.4, 6.8]:
		for sz in [-1, 1]:
			warm.box(Vector3(x, ROOM_H - 0.41, sz * 5.8), Vector3(0.22, 0.02, 0.22), Color8(255, 240, 210))
	for z in [-3.0, 0.0, 3.0]:
		for sx in [-1, 1]:
			warm.box(Vector3(sx * 6.8, ROOM_H - 0.41, z), Vector3(0.22, 0.02, 0.22), Color8(255, 240, 210))


func _chandelier(b: Boxes, warm: Boxes, gold: Color) -> void:
	# Lámpara colgante: dos aros dorados con luces, sobre la alfombra
	var ch := Vector3(0, 2.75, 1.0)
	b.box(ch + Vector3(0, 0.5, 0), Vector3(0.03, 0.7, 0.03), gold)
	for ring in [[1.2, 0.0], [0.75, -0.28]]:
		var r: float = ring[0]
		for i in 16:
			var a := TAU * i / 16.0
			var p := ch + Vector3(cos(a) * r, ring[1], sin(a) * r)
			b.box_rot(p, Vector3(r * 0.42, 0.05, 0.05), gold, Vector3(0, -rad_to_deg(a) + 90, 0))
			if i % 2 == 0:
				warm.box(p + Vector3(0, -0.07, 0), Vector3(0.09, 0.09, 0.09), Color8(255, 236, 190))


func _walls(b: Boxes, shell: Boxes, walnut: Color, black_marble: Color, lacquer: Color, gold: Color) -> void:
	# Paredes: paneles de nogal con listones y un filete dorado (costados y frente); atrás un ventanal de punta a punta
	for sx in [-1, 1]:
		shell.box(Vector3(sx * (W / 2 + 0.15), ROOM_H / 2, 0), Vector3(0.3, ROOM_H, D), walnut)
		for i in 14:
			b.box(Vector3(sx * (W / 2 - 0.02), ROOM_H / 2 - 0.25, -D / 2 + 0.5 + i * 1.0), Vector3(0.04, ROOM_H - 0.5, 0.05),
					Color8(86, 54, 34))
		if lux >= 3:
			b.box(Vector3(sx * (W / 2 - 0.03), 0.9, 0), Vector3(0.04, 0.03, D), gold)
		b.box(Vector3(sx * (W / 2 - 0.03), 0.12, 0), Vector3(0.05, 0.24, D), black_marble)   # zócalo
	_rect(-W / 2 - 0.3, -W / 2, -D / 2, D / 2, ROOM_H)
	_rect(W / 2, W / 2 + 0.3, -D / 2, D / 2, ROOM_H)
	for sx in [-1, 1]:
		shell.box(Vector3(sx * 4.6, ROOM_H / 2, -D / 2 - 0.15), Vector3(6.8, ROOM_H, 0.3), walnut)
		b.box(Vector3(sx * 4.6, 0.12, -D / 2 + 0.02), Vector3(6.8, 0.24, 0.05), black_marble)
	shell.box(Vector3(0, 3.25, -D / 2 - 0.15), Vector3(2.4, 1.1, 0.3), walnut)
	_rect(-W / 2, W / 2, -D / 2 - 0.3, -D / 2, ROOM_H)   # el frente (con la puerta del ascensor: se baja con E)
	b.box(Vector3(0, 0.12, D / 2 + 0.1), Vector3(W, 0.24, 0.2), black_marble)
	b.box(Vector3(0, ROOM_H - 0.1, D / 2 + 0.15), Vector3(W, 0.2, 0.3), lacquer)
	for i in 9:   # parteluces negros finos con un filo dorado
		b.box(Vector3(-W / 2 + i * 2, ROOM_H / 2, D / 2 + 0.15), Vector3(0.08, ROOM_H, 0.16), lacquer)
		if lux >= 3:
			b.box(Vector3(-W / 2 + i * 2, ROOM_H / 2, D / 2 + 0.06), Vector3(0.02, ROOM_H, 0.02), gold)
	_rect(-W / 2, W / 2, D / 2, D / 2 + 0.3, ROOM_H)
	# Marco y puertas del ascensor (se abren al llegar): de acero, y doradas cuando ya eres un imperio
	var frame := gold if lux >= 5 else Color8(150, 154, 160)
	b.box(Vector3(-1.1, 1.35, -D / 2 + 0.02), Vector3(0.2, 2.7, 0.1), frame)
	b.box(Vector3(1.1, 1.35, -D / 2 + 0.02), Vector3(0.2, 2.7, 0.1), frame)
	b.box(Vector3(0, 2.75, -D / 2 + 0.02), Vector3(2.4, 0.2, 0.1), frame)
	for sx in [-1, 1]:
		var dn := Boxes.new()
		dn.box(Vector3.ZERO, Vector3(1.0, 2.6, 0.06), Color8(196, 160, 92) if lux >= 5 else Color8(170, 174, 180))
		dn.box(Vector3(0, 0, 0.035), Vector3(0.9, 2.5, 0.01), Color8(216, 182, 110) if lux >= 5 else Color8(196, 200, 206))
		var door := dn.node(root, Mats.standard)
		door.position = Vector3(sx * 0.5, 1.3, -D / 2 - 0.05)
		doors.append(door)


func _desk(b: Boxes, glow: Boxes, warm: Boxes, lacquer: Color, gold: Color, leather: Color) -> void:
	# Escritorio del CEO: laca negra con filos dorados, pantalla, placa, lámpara y un sillón alto de cuero
	var dk := DESK
	b.box(dk + Vector3(0, 0.78, 0), Vector3(3.6, 0.08, 1.4), lacquer)
	var trim := gold if lux >= 3 else lacquer   # los filos dorados llegan con el lujo
	b.box(dk + Vector3(0, 0.83, 0), Vector3(3.62, 0.02, 1.42), trim)
	b.box(dk + Vector3(0, 0.4, -0.55), Vector3(3.4, 0.76, 0.1), lacquer)
	b.box(dk + Vector3(0, 0.12, -0.61), Vector3(3.4, 0.03, 0.03), trim)
	for sx in [-1, 1]:
		b.box(dk + Vector3(sx * 1.6, 0.38, 0), Vector3(0.2, 0.76, 1.3), lacquer)
		b.box(dk + Vector3(sx * 1.71, 0.38, 0), Vector3(0.02, 0.76, 1.3), trim)
	b.box(dk + Vector3(0, 0.98, 0.35), Vector3(0.12, 0.26, 0.12), gold)
	b.box(dk + Vector3(0, 1.3, 0.35), Vector3(1.06, 0.68, 0.05), lacquer)
	glow.box(dk + Vector3(0, 1.3, PC_SCREEN_Z), Vector3(0.96, 0.6, 0.01), Color8(40, 110, 200))   # mira al sillón
	b.box(dk + Vector3(-0.2, 0.9, -0.45), Vector3(0.7, 0.12, 0.12), gold)                    # placa
	b.box(dk + Vector3(1.2, 0.95, 0.1), Vector3(0.14, 0.22, 0.14), Color8(250, 250, 250))    # taza
	b.box(dk + Vector3(-1.0, 0.87, 0.0), Vector3(0.5, 0.06, 0.35), Color8(240, 235, 220))    # carpeta
	b.box(dk + Vector3(-1.45, 1.05, 0.35), Vector3(0.05, 0.4, 0.05), gold)                   # lámpara de escritorio
	warm.box(dk + Vector3(-1.45, 1.28, 0.3), Vector3(0.3, 0.1, 0.3), Color8(255, 226, 170))
	b.box(dk + Vector3(0, 0.5, 1.25), Vector3(0.9, 0.16, 0.85), leather)                     # sillón
	b.box(dk + Vector3(0, 1.35, 1.65), Vector3(0.95, 1.6, 0.18), leather)
	b.box(dk + Vector3(0, 0.22, 1.25), Vector3(0.1, 0.44, 0.1), gold)
	b.box(dk + Vector3(0, 0.03, 1.25), Vector3(0.7, 0.04, 0.7), gold)
	_rect(dk.x - 1.8, dk.x + 1.8, dk.z - 0.7, dk.z + 0.7, 0.9)


func _bookcase(b: Boxes, warm: Boxes, lacquer: Color, gold: Color) -> void:
	# Biblioteca empotrada a la derecha al entrar: laca negra, repisas doradas con luz cálida y algún adorno
	var bx := -W / 2 + 0.35
	b.box(Vector3(bx, 1.5, 1.5), Vector3(0.6, 3.0, 4.6), lacquer)
	var books := [Color8(120, 30, 34), Color8(30, 46, 90), Color8(30, 80, 56), Color8(190, 160, 90), Color8(70, 40, 90),
			Color8(230, 225, 210)]
	for row in 4:
		b.box(Vector3(bx + 0.3, 0.55 + row * 0.7, 1.5), Vector3(0.02, 0.05, 4.4), gold)
		warm.box(Vector3(bx + 0.1, 1.2 + row * 0.7, 1.5), Vector3(0.3, 0.02, 4.3), Color8(255, 220, 160))
		var gap := (row * 3 + 4) % 14
		for k in 14:
			if k == gap:
				b.box(Vector3(bx + 0.2, 0.72 + row * 0.7, -0.55 + k * 0.3), Vector3(0.16, 0.24, 0.16), gold)   # adorno
				continue
			var hh := 0.38 + (k * 7 % 5) * 0.04
			b.box(Vector3(bx + 0.2, 0.6 + row * 0.7 + hh / 2, -0.55 + k * 0.3), Vector3(0.36, hh, 0.22), books[(k + row) % books.size()])
	_rect(-W / 2, -W / 2 + 0.7, -0.9, 3.9, 3.0)


func _gold_vitrine(b: Boxes, warm: Boxes, black_marble: Color, gold: Color) -> void:
	var gv := Vector3(-5.6, 0, -4.6)   # vitrina con lingotes de oro sobre mármol negro, con luz arriba
	b.box(gv + Vector3(0, 0.5, 0), Vector3(1.0, 1.0, 1.0), black_marble)
	b.box(gv + Vector3(0, 1.01, 0), Vector3(1.04, 0.03, 1.04), gold)
	for i in 3:
		b.box(gv + Vector3(-0.22 + i * 0.22, 1.1, 0), Vector3(0.2, 0.14, 0.42), gold)
	for i in 2:
		b.box(gv + Vector3(-0.11 + i * 0.22, 1.24, 0), Vector3(0.2, 0.14, 0.42), gold)
	for cx in [-0.48, 0.48]:
		for cz in [-0.48, 0.48]:
			b.box(gv + Vector3(cx, 1.4, cz), Vector3(0.03, 0.8, 0.03), gold)
	b.box(gv + Vector3(0, 1.81, 0), Vector3(1.0, 0.03, 1.0), gold)
	warm.box(gv + Vector3(0, 1.78, 0), Vector3(0.6, 0.02, 0.6), Color8(255, 236, 190))
	_rect(gv.x - 0.5, gv.x + 0.5, gv.z - 0.5, gv.z + 0.5, 1.8)


func _lounge(b: Boxes, black_marble: Color, gold: Color, leather: Color) -> void:
	# Sala chica a la izquierda al entrar: dos sillones de cuero coñac y una mesa de mármol negro con filo dorado
	for sz in [-1, 1]:
		var sv := Vector3(5.2, 0, 0.6 + sz * 1.8)
		b.box(sv + Vector3(0, 0.26, 0), Vector3(2.6, 0.36, 0.9), leather)
		b.box(sv + Vector3(0, 0.62, sz * 0.36), Vector3(2.6, 0.6, 0.18), leather)
		for ax in [-1.25, 1.25]:
			b.box(sv + Vector3(ax, 0.45, 0), Vector3(0.18, 0.5, 0.9), leather)
		b.box(sv + Vector3(0, 0.05, 0), Vector3(2.5, 0.1, 0.8), gold)
		_rect(sv.x - 1.3, sv.x + 1.3, sv.z - 0.45, sv.z + 0.45, 0.7)
	b.box(Vector3(5.2, 0.38, 0.6), Vector3(1.6, 0.06, 1.0), black_marble)
	b.box(Vector3(5.2, 0.35, 0.6), Vector3(1.64, 0.03, 1.04), gold)
	b.box(Vector3(5.2, 0.17, 0.6), Vector3(0.2, 0.34, 0.2), gold)
	b.box(Vector3(5.0, 0.46, 0.5), Vector3(0.12, 0.1, 0.12), Color8(250, 250, 250))


func _bar(b: Boxes, warm: Boxes, black_marble: Color, gold: Color) -> void:
	# Bar de mármol negro con botellas iluminadas al fondo, a la izquierda
	var bar := Vector3(W / 2 - 0.4, 0, 5.2)
	b.box(bar + Vector3(0, 0.55, 0), Vector3(0.7, 1.1, 2.4), black_marble)
	b.box(bar + Vector3(0, 1.12, 0), Vector3(0.75, 0.04, 2.45), gold)
	warm.box(bar + Vector3(0.2, 1.9, 0), Vector3(0.2, 0.02, 2.2), Color8(255, 220, 160))
	var bottles := [Color8(150, 80, 30), Color8(40, 100, 60), Color8(160, 30, 40), Color8(230, 210, 160)]
	for i in 6:
		b.box(bar + Vector3(0, 1.3, -0.9 + i * 0.36), Vector3(0.12, 0.34, 0.12), bottles[i % bottles.size()])
	_rect(bar.x - 0.35, bar.x + 0.35, bar.z - 1.2, bar.z + 1.2, 1.2)


func _screens(b: Boxes, glow: Boxes, warm: Boxes, lacquer: Color, gold: Color) -> void:
	# El logo de tu empresa a la derecha de la puerta; con más lujo, a la izquierda la pantalla grande con lo que vale
	b.box(Vector3(-4.6, 2.1, -D / 2 + 0.05), Vector3(3.6, 1.4, 0.06), gold if lux >= 3 else lacquer)
	b.box(Vector3(-4.6, 2.1, -D / 2 + 0.08), Vector3(3.4, 1.2, 0.04), lacquer)
	if lux >= 3:
		warm.box(Vector3(-4.6, 2.88, -D / 2 + 0.2), Vector3(2.6, 0.03, 0.1), Color8(255, 226, 170))   # luz sobre el logo
	if lux < 2:
		return
	b.box(Vector3(4.6, 2.0, -D / 2 + 0.06), Vector3(3.3, 1.9, 0.08), gold)
	b.box(Vector3(4.6, 2.0, -D / 2 + 0.08), Vector3(3.2, 1.8, 0.08), lacquer)
	glow.box(Vector3(4.6, 2.0, -D / 2 + 0.13), Vector3(3.0, 1.6, 0.01), Color8(16, 40, 34))
	var pts := [0.1, 0.25, 0.2, 0.45, 0.4, 0.62, 0.58, 0.85]
	for i in pts.size() - 1:   # la curva que sube
		var a := Vector2(3.3 + i * 0.37, 1.35 + pts[i] * 1.2)
		var c := Vector2(3.3 + (i + 1) * 0.37, 1.35 + pts[i + 1] * 1.2)
		var mid := (a + c) / 2
		glow.box_rot(Vector3(mid.x, mid.y, -D / 2 + 0.14), Vector3(a.distance_to(c) + 0.03, 0.05, 0.01), Color8(90, 230, 140),
				Vector3(0, 0, rad_to_deg((c - a).angle())))


func _plants(b: Boxes, lacquer: Color, gold: Color) -> void:
	# Maceteros altos de laca negra (con filo dorado cuando hay lujo): dos al principio, cuatro después
	var spots_p := [Vector3(-2.2, 0, -6.2), Vector3(2.2, 0, -6.2)]
	if lux >= 3:
		spots_p += [Vector3(-7.0, 0, 6.2), Vector3(7.0, 0, 2.6)]
	for pv in spots_p:
		b.box(pv + Vector3(0, 0.45, 0), Vector3(0.6, 0.9, 0.6), lacquer)
		b.box(pv + Vector3(0, 0.91, 0), Vector3(0.64, 0.03, 0.64), gold if lux >= 3 else lacquer)
		b.box(pv + Vector3(0, 1.4, 0), Vector3(0.7, 0.9, 0.7), Color8(50, 120, 60))
		b.box(pv + Vector3(0, 2.0, 0), Vector3(0.45, 0.5, 0.45), Color8(66, 140, 74))
		_rect(pv.x - 0.3, pv.x + 0.3, pv.z - 0.3, pv.z + 0.3, 2.2)


func set_company(name: String, worth: String) -> void:
	if company_label:
		company_label.text = name.to_upper()
		worth_label.text = Lang.f("Tu empresa vale %s", worth)


# ---------- pisos de ejecutivos ----------
func _office_floor(k: int) -> void:
	var y0 := -FLOOR_H * k
	var b := Boxes.new()
	var glow := Boxes.new()
	var wall := Color8(214, 218, 224)
	b.box(Vector3(0, y0 - 0.15, 0), Vector3(W, 0.3, D), Color8(78, 86, 102))
	b.box(Vector3(0, y0 + FLOOR_H - 0.3, 0), Vector3(W, 0.3, D), Color8(236, 236, 238))   # el techo (bajo la losa de arriba)
	b.box(Vector3(0, y0 + FLOOR_H - 0.15, -D / 2 - 0.1), Vector3(W + 0.4, 0.3, 0.2), Color8(60, 64, 70))   # borde de la losa
	for x in [-5.0, 0.0, 5.0]:
		glow.box(Vector3(x, y0 + FLOOR_H - 0.46, 1.5), Vector3(2.4, 0.04, 0.6), Color8(250, 250, 240))
	b.box(Vector3(-W / 2 - 0.15, y0 + FLOOR_H / 2, 0), Vector3(0.3, FLOOR_H, D), wall)
	b.box(Vector3(W / 2 + 0.15, y0 + FLOOR_H / 2, 0), Vector3(0.3, FLOOR_H, D), wall)
	b.box(Vector3(0, y0 + 0.45, D / 2 + 0.15), Vector3(W, 0.9, 0.3), wall)
	b.box(Vector3(0, y0 + FLOOR_H - 0.5, D / 2 + 0.15), Vector3(W, 0.6, 0.3), wall)
	for i in 9:
		b.box(Vector3(-W / 2 + i * 2, y0 + FLOOR_H / 2, D / 2 + 0.15), Vector3(0.1, FLOOR_H, 0.2), Color8(40, 44, 50))
	# Número del piso en la pared del costado y una pizarra con gráficos
	var n := floors + 2 - k   # el vestíbulo es el piso 1
	var lbl := Building.label(offices, Lang.f("PISO %d", n), Vector3(W / 2 - 0.02, y0 + 2.6, 4.5), 14, Color8(40, 60, 110), true, false)
	lbl.rotation.y = -PI / 2
	b.box(Vector3(-W / 2 + 0.05, y0 + 1.8, 3.0), Vector3(0.04, 1.2, 2.4), Color8(250, 250, 250))
	for i in 4:
		b.box(Vector3(-W / 2 + 0.08, y0 + 1.35 + i * 0.15, 2.3 + i * 0.4), Vector3(0.02, 0.3 + i * 0.15, 0.25),
				[Color8(70, 140, 220), Color8(90, 200, 120), Color8(240, 170, 60), Color8(220, 80, 80)][i])
	# Islas de escritorios: dos ejecutivos frente a frente con sus pantallas espalda con espalda
	var rng := RandomNumberGenerator.new()
	rng.seed = 77 + k
	for cx in [-4.6, 0.0, 4.6]:
		for cz in [0.2, 3.9]:
			_desk_pair(b, glow, Vector3(cx, y0, cz), rng)
	# Bidón de agua, impresora y plantas
	b.box(Vector3(W / 2 - 0.6, y0 + 0.5, -4.5), Vector3(0.5, 1.0, 0.5), Color8(230, 230, 232))
	glow.box(Vector3(W / 2 - 0.6, y0 + 1.25, -4.5), Vector3(0.36, 0.5, 0.36), Color8(140, 200, 240))
	b.box(Vector3(-W / 2 + 0.7, y0 + 0.45, -4.0), Vector3(0.9, 0.9, 0.7), Color8(200, 200, 205))
	b.box(Vector3(-W / 2 + 0.7, y0 + 0.92, -4.0), Vector3(0.7, 0.06, 0.5), Color8(60, 60, 66))
	for px in [-7.2, 7.2]:
		b.box(Vector3(px, y0 + 0.3, 6.3), Vector3(0.6, 0.6, 0.6), Color8(235, 232, 225))
		b.box(Vector3(px, y0 + 1.1, 6.3), Vector3(0.9, 1.0, 0.9), Color8(60, 140, 70))
	b.node(offices, Mats.standard, false)
	glow.node(offices, Mats.emissive, false)
	lights_office.append(_light(offices, Vector3(0, y0 + FLOOR_H - 0.9, 0.5), 11.0, 1.1, Color(0.95, 0.97, 1.0)))


func _desk_pair(b: Boxes, glow: Boxes, c: Vector3, rng: RandomNumberGenerator) -> void:
	b.box(c + Vector3(0, 0.76, 0), Vector3(1.2, 0.06, 1.6), Color8(235, 235, 232))
	for sx in [-0.55, 0.55]:
		for sz in [-0.72, 0.72]:
			b.box(c + Vector3(sx, 0.37, sz), Vector3(0.06, 0.74, 0.06), Color8(60, 60, 66))
	b.box(c + Vector3(0, 1.0, 0), Vector3(0.04, 0.4, 1.6), Color8(120, 130, 140))   # mampara del medio
	for side in [-1, 1]:
		var sx: float = side * 0.3
		b.box(c + Vector3(sx, 0.86, 0), Vector3(0.12, 0.14, 0.12), Color8(30, 30, 34))
		b.box(c + Vector3(sx, 1.1, 0), Vector3(0.05, 0.4, 0.66), Color8(30, 30, 34))
		glow.box(c + Vector3(sx - side * 0.03, 1.1, 0), Vector3(0.01, 0.34, 0.6),
				[Color8(70, 140, 215), Color8(80, 190, 130), Color8(230, 230, 240)][rng.randi() % 3])
		b.box(c + Vector3(side * -0.1, 0.8, 0), Vector3(0.18, 0.02, 0.5), Color8(40, 40, 46))   # teclado
		var seat := c + Vector3(-side * 1.3, 0, 0)   # la silla del lado contrario a su pantalla
		b.box(seat + Vector3(0, 0.47, 0), Vector3(0.6, 0.08, 0.6), Color8(38, 40, 48))
		b.box(seat + Vector3(-side * 0.33, 0.88, 0), Vector3(0.08, 0.72, 0.58), Color8(38, 40, 48))
		b.box(seat + Vector3(0, 0.24, 0), Vector3(0.08, 0.44, 0.08), Color8(30, 30, 34))
		_executive(seat, side, rng)


## Un ejecutivo de traje sentado, mirando su pantalla (hacia +x si side = 1).
func _executive(seat: Vector3, side: int, rng: RandomNumberGenerator) -> void:
	var look: Dictionary = Wardrobe.DEFAULT_LOOK.duplicate()
	var skins := [[240, 200, 165], [215, 165, 120], [170, 115, 75], [115, 75, 50]]
	look.skin = skins[rng.randi() % skins.size()]
	look.hair = [[30, 25, 20], [90, 60, 35], [200, 160, 80], [60, 60, 60]][rng.randi() % 4]
	look.hair_style = ["corto", "largo", "calvo", "corto"][rng.randi() % 4]
	look.shirt = [[245, 245, 245], [200, 220, 245], [245, 245, 245]][rng.randi() % 3]
	look.jacket = "blazer"
	look.jacket_color = [[40, 40, 45], [40, 60, 110], [80, 84, 92], [30, 30, 34]][rng.randi() % 4]
	look.pants = [[40, 40, 45], [30, 34, 50]][rng.randi() % 2]
	look.pants_style = "vestir"
	look.tie = rng.randf() < 0.7
	look.glasses = rng.randf() < 0.3
	var holder := Node3D.new()
	holder.position = seat
	holder.rotation.y = side * PI / 2
	offices.add_child(holder)
	var p := Person.new(null, null, false, look)
	holder.add_child(p)
	p.sit(1.0)
	typists.append([holder, p, rng.randf() * TAU])


## Las puertas del ascensor del vestíbulo (se abren en el final) y su choque cuando están cerradas.
func _lobby_lift() -> void:
	lobby_doors.clear()
	var hq_root: Node3D = city.hq.root
	for sx in [-1, 1]:
		var dn := Boxes.new()
		dn.box(Vector3.ZERO, Vector3(0.9, 2.7, 0.05), Color8(176, 168, 150))
		dn.box(Vector3(-sx * 0.44, 0, -0.03), Vector3(0.02, 2.6, 0.01), Color8(40, 40, 44))
		var d := dn.node(hq_root, Mats.standard)
		d.position = Vector3(sx * 0.45, 1.35, Blueprints.LIFT_Z)
		lobby_doors.append(d)
	var a := Blueprints.to_world(City.HQ, -1.0, Blueprints.LIFT_Z - 0.05)
	var e := Blueprints.to_world(City.HQ, 1.0, 15.8)
	rects.append([minf(a.x, e.x), maxf(a.x, e.x), minf(a.z, e.z), maxf(a.z, e.z), 2.8])


## Abre (1) o cierra (0) las puertas del ascensor del vestíbulo.
func set_lobby_doors(o: float) -> void:
	for d in lobby_doors:
		if is_instance_valid(d):
			d.position.x = signf(d.position.x) * (0.45 + o * 0.88)


# ---------- cabina y ciudad de mentira ----------
func _cab() -> void:
	cab = Node3D.new()
	root.add_child(cab)
	var b := Boxes.new()
	var gold := Color8(225, 180, 60)
	b.box(Vector3(0, -0.06, 0), Vector3(2.4, 0.12, 1.9), Color8(60, 60, 66))
	b.box(Vector3(0, 2.9, 0), Vector3(2.4, 0.1, 1.9), Color8(60, 60, 66))
	for sx in [-1.15, 1.15]:
		for sz in [-0.9, 0.9]:
			b.box(Vector3(sx, 1.42, sz), Vector3(0.08, 2.9, 0.08), gold)
	b.box(Vector3(0, 0.95, -0.9), Vector3(2.3, 0.05, 0.05), gold)   # pasamanos de atrás
	b.node(cab, Mats.standard, false)
	cab.visible = false


func _skyline() -> void:
	var b := Boxes.new()
	var glow := Boxes.new()
	b.box(Vector3(0, -34.0, 0), Vector3(500, 1.0, 500), Color8(52, 58, 66))
	var rng := RandomNumberGenerator.new()
	rng.seed = 2026
	var tones := [Color8(120, 128, 140), Color8(150, 140, 125), Color8(100, 108, 120), Color8(170, 165, 155)]
	for i in 70:
		var a := rng.randf() * TAU
		var r := rng.randf_range(26.0, 120.0)
		var p := Vector3(cos(a) * r, 0, sin(a) * r)
		if p.z < 12.0 and absf(p.x) < 14.0:
			continue   # nada pegado al edificio
		var sx := rng.randf_range(6, 14)
		var sz := rng.randf_range(6, 14)
		var top := rng.randf_range(-24.0, 14.0) if r > 40 else rng.randf_range(-26.0, -6.0)
		var h := top + 34.0
		b.box(p + Vector3(0, -34.0 + h / 2, 0), Vector3(sx, h, sz), tones[i % tones.size()])
		var rows := int(h / 3.2)
		for row in rows:
			if rng.randf() < 0.45:
				continue
			var y := -32.5 + row * 3.2
			var face := -1.0 if p.z > 0 else 1.0
			glow.box(p + Vector3(0, y, face * (sz / 2 + 0.03)), Vector3(sx - 1.0, 1.2, 0.05), Color8(255, 226, 150))
	b.node(root, Mats.standard, false)
	glow.node(root, Mats.emissive, false)


# ---------- el viaje ----------
func go_up() -> void:
	if phase != "":
		return
	phase = "out"
	t = 0.0
	city.sfx.play("select", 0.5, 1.5)


## La subida del final: arranca ya con la pantalla en negro (Finale la oscureció) y al abrirse las puertas le avisa a
## Finale en vez de recorrer la oficina.
func go_up_finale(marks: Array) -> void:
	milestones = marks
	finale_mode = true
	phase = "ride"
	t = 0.0
	fade = 1.0
	ride_time = 2.5 + floors * 2.2
	offices.visible = true
	cab.visible = true
	for d in doors:
		d.position.x = signf(d.position.x) * 0.5
	for tp in typists:   # de pie y mirando al ascensor (a ti)
		var holder: Node3D = tp[0]
		if not holder.has_meta("yaw"):
			holder.set_meta("yaw", holder.rotation.y)
		holder.rotation.y = atan2(-holder.position.x, CAB_Z - holder.position.z)
		tp[1].sit(0.0)
		tp[1].position.y = 0.0


## Termina el modo del final: los ejecutivos vuelven a su escritorio, se sientan y todo queda como siempre.
func end_finale() -> void:
	finale_mode = false
	phase = ""
	fade = 0.0
	offices.visible = false
	cab.visible = false
	for d in doors:
		d.position.x = signf(d.position.x) * 0.5
	for tp in typists:
		var holder: Node3D = tp[0]
		if holder.has_meta("yaw"):
			holder.rotation.y = holder.get_meta("yaw")
		tp[1].arms[0].rotation = Vector3.ZERO
		tp[1].arms[1].rotation = Vector3.ZERO
		tp[1].position.y = 0.0
		tp[1].sit(1.0)


func go_down() -> void:
	if phase != "":
		return
	phase = "down"
	t = 0.0
	city.sfx.play("select", 0.5, 1.2)


func _bottom_y() -> float:
	return -FLOOR_H * floors + 1.65


func update(dt: float) -> void:
	anim_t += dt
	if offices.visible:
		for tp in typists:
			var p: Person = tp[1]
			var ph: float = anim_t * 16.0 + tp[2]
			if finale_mode:   # celebrando: los brazos arriba moviéndose y saltitos, cada uno a su ritmo
				var cel: float = anim_t * 7.0 + tp[2]
				p.arms[0].rotation = Vector3(deg_to_rad(-165.0 + sin(cel) * 15.0), 0, deg_to_rad(-12.0))
				p.arms[1].rotation = Vector3(deg_to_rad(-165.0 + sin(cel + 1.3) * 15.0), 0, deg_to_rad(12.0))
				p.position.y = absf(sin(cel * 0.8)) * 0.18
			else:   # tecleando: los brazos adelante, subiendo y bajando cada uno a su ritmo
				p.arms[0].rotation.x = deg_to_rad(-64.0 + sin(ph) * 7.0)
				p.arms[1].rotation.x = deg_to_rad(-64.0 + sin(ph + PI) * 7.0)
	if phase == "":
		return
	t += dt
	match phase:
		"out":   # en la partida el ascensor solo te lleva: se oscurece, apareces arriba y se aclara (el viaje
			fade = clampf(t / FADE, 0, 1)   # con los pisos de ejecutivos se ve solo en el final)
			if t >= FADE:
				_arrive()
				phase = "in"
				t = 0.0
		"in":
			fade = 1.0 - clampf(t / FADE, 0, 1)
			if t >= FADE:
				phase = ""
				fade = 0.0
		"ride":
			fade = 1.0 - clampf(t / FADE, 0, 1)
			var k := smoothstep(0.0, 1.0, t / ride_time)
			cab.position = Vector3(0, lerpf(_bottom_y() - 1.65, 0.0, k), CAB_Z)
			if t >= ride_time:
				phase = "doors"
				t = 0.0
				city.sfx.play("fin_campana", 0.5)
				city.sfx.play("fin_puertas", 0.45)
		"doors":
			var o := smoothstep(0.0, 1.0, t / DOORS)
			for d in doors:
				d.position.x = signf(d.position.x) * (0.5 + o * 1.0)
			if t >= DOORS:
				phase = ""
				offices.visible = false
				city.finale.after_ride()
		"down":
			fade = clampf(t / FADE, 0, 1) if t < FADE else 1.0 - clampf((t - FADE) / FADE, 0, 1)
			if t >= FADE and city.player.position.distance_to(_lobby_world()) > 0.5:
				city.teleport(_lobby_world(), 180.0, "")
			if t >= FADE * 2:
				phase = ""
				fade = 0.0


func _lobby_world() -> Vector3:
	return Blueprints.to_world(City.HQ, LOBBY_LIFT.x, LOBBY_LIFT.z)


func _arrive() -> void:
	phase = ""
	cab.visible = false
	for d in doors:
		d.position.x = signf(d.position.x) * 0.5
	var p: Vector3 = w(ARRIVE)
	city.player.position = p
	city.player.rotation.y = 0.0
	city.yaw = 0.0
	city.pitch = 14.0
	city.vy = 0.0


## La cámara durante el viaje: en la cabina mirando los pisos, y al llegar recorre la oficina del CEO.
func place_camera(cam: Camera3D) -> bool:
	match phase:
		"ride", "doors":
			var eye := w(cab.position + Vector3(0, 1.65, -0.55))
			cam.global_position = eye
			cam.look_at(eye + Vector3(0, -0.12, 1.0))
			return true
	return false


## Fundido, franjas de cine, el visor del ascensor y el título al llegar.
func draw(ui: ImUI) -> void:
	if phase in ["ride", "doors"]:
		var bar := 64.0
		ui.rect(Rect2(-3000, -3000, ui.W + 6000, 3000 + bar), Color(0, 0, 0, 0.92))
		ui.rect(Rect2(-3000, ui.H - bar, ui.W + 6000, 3000 + bar), Color(0, 0, 0, 0.92))
	if phase in ["ride", "doors"] and finale_mode and not milestones.is_empty():
		# El visor muestra en qué año llegaste a cada rango (un rango por piso, del primero al último)
		var lvl := clampf((cab.position.y - (_bottom_y() - 1.65)) / (-(_bottom_y() - 1.65)), 0.0, 1.0)
		var mi := roundi(lvl * (milestones.size() - 1))
		var mk: Array = milestones[mi]
		var box := Rect2(ui.W / 2 - 150, 84, 300, 78)
		ui.rect(box, Color(0.04, 0.04, 0.05, 0.9), 10)
		ui.rect(box, Color8(255, 200, 90), 10, 1)
		ui.text(Lang.f("AÑO %d", int(mk[0])), Vector2(ui.W / 2, box.position.y + 26), 26, Color8(255, 200, 90), true, "center")
		ui.text(Lang.t(mk[1]), Vector2(ui.W / 2, box.position.y + 56), 15, Color(1, 1, 1, 0.9), true, "center")
	elif phase in ["ride", "doors"]:
		var cy: float = cab.position.y
		var level := clampi(roundi(cy / FLOOR_H), -floors, 0)
		var n := floors + 2 + level
		var box := Rect2(ui.W / 2 - 70, 84, 140, 64)
		ui.rect(box, Color(0.04, 0.04, 0.05, 0.9), 10)
		ui.rect(box.grow(-3), Color(0, 0, 0, 0), 8)
		ui.text("▲" if phase == "ride" else "●", box.position + Vector2(30, 32), 20, Color8(255, 200, 90), true, "center")
		ui.text(str(n), box.position + Vector2(86, 32), 32, Color8(255, 200, 90), true, "center")
		ui.text("PRESIDENCIA" if level == 0 else Lang.t("Ejecutivos trabajando"), Vector2(ui.W / 2, box.end.y + 18), 13,
				Color(1, 1, 1, 0.8), true, "center")
	if fade > 0.0:
		ui.rect(Rect2(-3000, -3000, ui.W + 6000, ui.H + 6000), Color(0, 0, 0, fade))
