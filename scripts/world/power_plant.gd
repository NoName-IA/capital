class_name PowerPlant
extends RefCounted
## La planta eléctrica de la ciudad: una central térmica en el valle junto a la boca del túnel, al norte de la calle
## (el cerro se aplana para ella, ver Terrain.PLANT_FLAT). De la calle hacia el cerro:
## - adelante: el muro con el portón, la caseta de pagos (con su operario) y el edificio de control;
## - al medio: la sala de turbinas (estructura de acero a la vista, ventanales altos, lucernario y extractores) y, al
##   lado, el patio de la subestación con transformadores, pórticos y aisladores, de donde salen las líneas;
## - atrás: la caldera (alta, con pasarelas), el ducto a la chimenea de hormigón con sus anillos y luces rojas, los
##   estanques de combustible y la torre de enfriamiento hiperbólica sobre patas, unida por tuberías.
## Cuando falla: baliza naranja que gira, chispas en los transformadores, humo negro y las ventanas apagadas.
## Las líneas que salen hacia la ciudad las arma PowerGrid (empiezan en GANTRY).

## El patio tiene forma de L para no chocar con una megatienda en el terreno de al lado (llega hasta x -153,3 y
## z 29): adelante una franja angosta entre el túnel y ese terreno; atrás, pasando z BACK_Z, se ensancha hasta BACK_X1.
const X0 := -164.0                               # adelante: x de X0 a X1, z de Z0 a BACK_Z
const X1 := -154.0
const Z0 := 10.6
const BACK_Z := 30.4                             # atrás: x de X0 a BACK_X1, z de BACK_Z a Z1
const BACK_X1 := -139.0
const Z1 := 47.0
const BOOTH := Vector3(-155.3, 0.0, 11.5)        # la caseta de pagos, en la esquina de la reja que da a la calle
const PAY_SPOT := Vector3(-155.3, 0.0, 8.8)      # donde te paras para pagar (en la vereda, frente a la ventanilla)
const WORKER := Vector3(-155.3, 0.0, 11.75)      # el operario, adentro de la caseta, mirando a la calle
const GATE := [-159.2, -156.6]                   # el portón del muro de adelante (x)
const CONTROL := Vector3(-161.7, 0.0, 14.0)      # edificio de control
const HALL := Vector3(-159.0, 0.0, 23.4)         # sala de turbinas (centro)
const HALL_SIZE := Vector3(8.0, 8.0, 10.0)
const OUTLET := Vector3(-154.9, 0.0, 16.4)       # poste de salida: de aquí salen las líneas a la avenida y al sur
const OUTLET_H := 10.6
const BOILER := Vector3(-160.6, 0.0, 34.6)       # caldera
const BOILER_SIZE := Vector3(6.0, 13.5, 6.0)
const STACK := Vector3(-161.4, 0.0, 42.6)        # chimenea
const STACK_H := 30.0
const TOWER := Vector3(-145.0, 0.0, 38.4)        # torre de enfriamiento
const TOWER_H := 13.0
const TANKS := [Vector3(-154.6, 0.0, 33.2), Vector3(-151.6, 0.0, 33.2)]
const YARD := Rect2(-156.8, 39.4, 6.6, 6.6)      # patio de la subestación (x, z, ancho, largo)
const GANTRY := Vector3(-153.5, 9.0, 42.7)       # punto alto del pórtico (de aquí sale la línea al cerro)
const SPARKS := Vector3(-155.2, 2.8, 41.8)       # el transformador grande, donde saltan las chispas
const CENTER := Vector3(-155.0, 6.0, 30.0)       # para la cámara

var root: Node3D
var rects := []               # choques: [x0, x1, z0, z1, alto]
var worker: Person
var lit: MeshInstance3D       # ventanas de la sala, del control y la luz de la caseta (se apagan cuando falla)
var reds: MeshInstance3D      # luces rojas de la chimenea (avisan a los aviones)
var beacon: Node3D            # baliza naranja del techo (gira cuando falla)
var beacon_glow: MeshInstance3D
var sparks: CPUParticles3D
var smoke := []               # [CPUParticles3D] la chimenea y la torre de enfriamiento (vapor)
var failing := false
var flicker := 0.0            # 0 a 1: las ventanas titilan (la cinemática lo usa al fallar)
var _t := 0.0

const CONCRETE := Color8(176, 172, 164)
const STEEL := Color8(120, 128, 138)
const DARK := Color8(50, 54, 62)
const CLAD := Color8(98, 122, 146)      # chapa azul de la sala de turbinas
const CLAD2 := Color8(208, 206, 198)    # chapa clara de la caldera y el control
const WARM := Color8(255, 220, 140)


func _init(parent: Node3D) -> void:
	root = Node3D.new()
	root.name = "PlantaElectrica"
	parent.add_child(root)
	_build()


func _build() -> void:
	var b := Boxes.new()
	var lights := Boxes.new()
	var red := Boxes.new()
	_ground(b)
	_walls(b)
	_control(b, lights)
	_hall(b, lights)
	_boiler(b)
	_stack(b, red)
	_cooling_tower(b)
	_tanks(b)
	_pipes(b)
	_yard(b)
	_outlet(b)
	_booth(b, lights)
	b.node(root, Mats.standard)
	lit = lights.node(root, Mats.emissive, false)
	reds = red.node(root, Mats.emissive, false)
	Building.label(root, "PLANTA ELÉCTRICA", Vector3(HALL.x, HALL_SIZE.y - 1.0, HALL.z - HALL_SIZE.z / 2 - 0.08), 22, Color.WHITE)
	Building.label(root, "PAGO DEL ARREGLO", BOOTH + Vector3(0, 2.6, -1.12), 9, Color8(30, 26, 10))
	Building.label(root, "CONTROL", CONTROL + Vector3(0, 5.4, -2.58), 10, Color8(240, 240, 240))
	_beacon()
	_worker()
	_effects()


# ---------- partes ----------
func _ground(b: Boxes) -> void:
	b.box(Vector3((X0 + X1) / 2, 0.03, (Z0 + BACK_Z) / 2), Vector3(X1 - X0, 0.06, BACK_Z - Z0), CONCRETE)
	b.box(Vector3((X0 + BACK_X1) / 2, 0.03, (BACK_Z + Z1) / 2), Vector3(BACK_X1 - X0, 0.06, Z1 - BACK_Z), CONCRETE)
	# camino de entrada (del portón a la sala) con líneas amarillas
	var gx: float = (GATE[0] + GATE[1]) / 2
	b.box(Vector3(gx, 0.065, (Z0 + 18.0) / 2), Vector3(3.6, 0.01, 18.0 - Z0), Color8(70, 72, 78))
	for sx in [-1.7, 1.7]:
		b.box(Vector3(gx + sx, 0.075, (Z0 + 18.0) / 2), Vector3(0.12, 0.01, 18.0 - Z0), Color8(240, 190, 40))


## Muro de hormigón con malla arriba y pilares; adelante el portón corredizo con franjas de peligro.
func _walls(b: Boxes) -> void:
	var wall_h := 1.3
	var mesh_h := 1.0
	var segs := [[X0, Z0, GATE[0], Z0], [GATE[1], Z0, BOOTH.x - 1.0, Z0], [X0, Z0, X0, Z1], [X0, Z1, BACK_X1, Z1],
			[BACK_X1, BACK_Z, BACK_X1, Z1], [X1, BACK_Z, BACK_X1, BACK_Z], [X1, Z0 + 1.9, X1, BACK_Z]]
	for seg in segs:
		var a := Vector2(seg[0], seg[1])
		var c := Vector2(seg[2], seg[3])
		var len := a.distance_to(c)
		var mid := (a + c) / 2
		var along_x: bool = absf(c.x - a.x) > absf(c.y - a.y)
		for part in [[0.3, wall_h / 2, wall_h, CLAD2], [0.38, wall_h + 0.05, 0.1, CONCRETE],
				[0.03, wall_h + mesh_h / 2, mesh_h, Color8(150, 158, 166)], [0.06, wall_h + mesh_h, 0.06, DARK]]:
			var w: float = part[0]
			b.box(Vector3(mid.x, part[1], mid.y), Vector3(len if along_x else w, part[2], w if along_x else len), part[3])
		var n := maxi(1, int(len / 3.0))
		for i in n + 1:
			var p := a.lerp(c, float(i) / n)
			b.box(Vector3(p.x, (wall_h + mesh_h) / 2, p.y), Vector3(0.36, wall_h + mesh_h + 0.1, 0.36), CONCRETE)
		rects.append([minf(a.x, c.x) - 0.2, maxf(a.x, c.x) + 0.2, minf(a.y, c.y) - 0.2, maxf(a.y, c.y) + 0.2, wall_h + mesh_h])
	# Portón corredizo (cerrado) con franjas
	var gw: float = GATE[1] - GATE[0]
	var gx: float = (GATE[0] + GATE[1]) / 2
	b.box(Vector3(gx, 1.1, Z0), Vector3(gw, 0.08, 0.1), DARK)
	b.box(Vector3(gx, 2.2, Z0), Vector3(gw, 0.08, 0.1), DARK)
	for i in int(gw / 0.25):
		b.box(Vector3(GATE[0] + 0.12 + i * 0.25, 1.15, Z0), Vector3(0.05, 2.2, 0.05), STEEL)
	for i in 6:
		b.box(Vector3(GATE[0] + 0.35 + i * gw / 6.0, 0.55, Z0 - 0.07), Vector3(gw / 12.0, 0.25, 0.02), Color8(240, 190, 40))
	rects.append([GATE[0], GATE[1], Z0 - 0.2, Z0 + 0.2, 2.3])
	# Carteles de peligro en el muro
	for x in [-163.2, -160.6]:
		b.box(Vector3(x, 1.75, Z0 - 0.2), Vector3(0.8, 0.7, 0.03), Color8(240, 190, 40))
		b.box(Vector3(x, 1.75, Z0 - 0.22), Vector3(0.12, 0.45, 0.02), Color8(30, 30, 30))


## Edificio de control: dos pisos con ventanal corrido, antenas y una parabólica en el techo.
func _control(b: Boxes, lights: Boxes) -> void:
	var s := Vector3(4.2, 5.6, 4.6)
	var c := CONTROL
	b.box(c + Vector3(0, s.y / 2, 0), s, CLAD2)
	b.box(c + Vector3(0, s.y + 0.15, 0), Vector3(s.x + 0.3, 0.3, s.z + 0.3), DARK)
	b.box(c + Vector3(0, 2.8, 0), Vector3(s.x + 0.05, 0.25, s.z + 0.05), CONCRETE)   # losa
	for fy in [1.5, 4.2]:
		b.box(c + Vector3(0, fy, -s.z / 2 - 0.02), Vector3(s.x - 0.6, 1.3, 0.04), Color8(40, 50, 62))
		lights.box(c + Vector3(-0.4, fy, -s.z / 2 - 0.04), Vector3(s.x - 1.8, 1.1, 0.02), WARM)
	b.box(c + Vector3(1.8, 1.1, -s.z / 2 - 0.05), Vector3(1.0, 2.2, 0.05), Color8(70, 76, 86))   # puerta
	for k in 2:   # antenas
		b.box(c + Vector3(-1.4 + k * 2.4, s.y + 1.2, 0.8), Vector3(0.08, 2.2, 0.08), STEEL)
	var dish := CylinderMesh.new()
	dish.top_radius = 0.6
	dish.bottom_radius = 0.1
	dish.height = 0.35
	dish.radial_segments = 10
	b.mesh(dish, Transform3D(Basis.from_euler(Vector3(deg_to_rad(-60), 0, 0)), c + Vector3(1.2, s.y + 0.8, -1.0)), Color8(225, 225, 220))
	rects.append([c.x - s.x / 2, c.x + s.x / 2, c.z - s.z / 2, c.z + s.z / 2, s.y])


## Sala de turbinas: estructura de acero a la vista (columnas y vigas), chapa azul, ventanales altos a los costados,
## lucernario en el techo, extractores y una escalera de emergencia por fuera.
func _hall(b: Boxes, lights: Boxes) -> void:
	var s := HALL_SIZE
	var c := HALL
	b.box(c + Vector3(0, s.y / 2, 0), s, CLAD)
	b.box(c + Vector3(0, 0.4, 0), Vector3(s.x + 0.12, 0.8, s.z + 0.12), CONCRETE)   # zócalo
	var bays := 4
	for i in bays + 1:   # columnas y vigas de acero por fuera
		var z := c.z - s.z / 2 + i * s.z / bays
		for sx in [-1, 1]:
			b.box(Vector3(c.x + sx * (s.x / 2 + 0.12), s.y / 2, z), Vector3(0.24, s.y, 0.3), STEEL)
		b.box(Vector3(c.x, s.y + 0.25, z), Vector3(s.x + 0.5, 0.3, 0.3), STEEL)
	for sx in [-1, 1]:
		b.box(Vector3(c.x + sx * (s.x / 2 + 0.12), s.y - 0.2, c.z), Vector3(0.26, 0.3, s.z + 0.3), STEEL)
		for i in bays:   # ventanales altos entre columnas
			var z := c.z - s.z / 2 + (i + 0.5) * s.z / bays
			b.box(Vector3(c.x + sx * (s.x / 2 + 0.02), 5.4, z), Vector3(0.04, 2.6, s.z / bays - 0.8), Color8(36, 46, 58))
			lights.box(Vector3(c.x + sx * (s.x / 2 + 0.04), 5.4, z), Vector3(0.02, 2.3, s.z / bays - 1.0), WARM)
	# frente: portón grande y ventanas
	b.box(c + Vector3(1.4, 2.2, -s.z / 2 - 0.03), Vector3(3.0, 4.4, 0.06), Color8(70, 76, 86))
	for k in 6:
		b.box(c + Vector3(1.4, 0.4 + k * 0.7, -s.z / 2 - 0.07), Vector3(3.0, 0.05, 0.02), DARK)
	for i in 2:
		lights.box(c + Vector3(-2.6 + i * 1.5, 2.6, -s.z / 2 - 0.04), Vector3(1.1, 1.4, 0.03), WARM)
	# techo con lucernario y extractores
	b.box(c + Vector3(0, s.y + 0.5, 0), Vector3(s.x + 0.6, 0.2, s.z + 0.6), DARK)
	b.box(c + Vector3(0, s.y + 1.0, 0), Vector3(1.6, 0.8, s.z - 1.0), Color8(80, 96, 112))
	lights.box(c + Vector3(0, s.y + 1.0, 0), Vector3(1.66, 0.4, s.z - 1.2), Color8(200, 220, 255))
	for i in 3:
		var fan := CylinderMesh.new()
		fan.top_radius = 0.35
		fan.bottom_radius = 0.45
		fan.height = 0.6
		fan.radial_segments = 10
		b.mesh(fan, Transform3D(Basis.IDENTITY, c + Vector3(-2.4, s.y + 0.9, -3.0 + i * 3.0)), STEEL)
	rects.append([c.x - s.x / 2 - 0.3, c.x + s.x / 2 + 0.3, c.z - s.z / 2, c.z + s.z / 2, s.y])


## Caldera: bloque alto con pasarelas en tres pisos, columnas de acero, cañerías rojas y el ducto a la chimenea.
func _boiler(b: Boxes) -> void:
	var s := BOILER_SIZE
	var c := BOILER
	b.box(c + Vector3(0, s.y / 2, 0), s, CLAD2)
	b.box(c + Vector3(0, s.y + 0.15, 0), Vector3(s.x + 0.3, 0.3, s.z + 0.3), DARK)
	for y in [4.0, 7.5, 11.0]:   # pasarelas con baranda alrededor
		b.box(c + Vector3(0, y, 0), Vector3(s.x + 1.4, 0.12, s.z + 1.4), STEEL)
		for sx in [-1, 1]:
			b.box(c + Vector3(sx * (s.x / 2 + 0.68), y + 0.5, 0), Vector3(0.05, 0.05, s.z + 1.4), DARK)
			b.box(c + Vector3(0, y + 0.5, sx * (s.z / 2 + 0.68)), Vector3(s.x + 1.4, 0.05, 0.05), DARK)
	for k in 4:   # columnas de acero de las pasarelas
		var px := c.x + (-1 if k % 2 == 0 else 1) * (s.x / 2 + 0.68)
		var pz := c.z + (-1 if k < 2 else 1) * (s.z / 2 + 0.68)
		b.box(Vector3(px, s.y / 2, pz), Vector3(0.18, s.y, 0.18), STEEL)
	for i in 3:   # cañerías verticales en la cara de la calle
		var pipe := CylinderMesh.new()
		pipe.top_radius = 0.16
		pipe.bottom_radius = 0.16
		pipe.height = s.y - 1.0
		pipe.radial_segments = 8
		b.mesh(pipe, Transform3D(Basis.IDENTITY, c + Vector3(-2.2 + i * 0.6, (s.y - 1.0) / 2, -s.z / 2 - 0.3)), Color8(200, 80, 50))
	# ducto de gases a la chimenea
	var duct_from := c + Vector3(-1.2, s.y - 2.5, s.z / 2)
	var duct_to := Vector3(STACK.x, s.y - 2.5, STACK.z)
	b.box((duct_from + duct_to) / 2, Vector3(1.4, 1.6, duct_to.z - duct_from.z + 0.6), Color8(150, 146, 140))
	rects.append([c.x - s.x / 2 - 0.8, c.x + s.x / 2 + 0.8, c.z - s.z / 2 - 0.8, c.z + s.z / 2 + 0.8, s.y])


## Chimenea de hormigón, más angosta arriba, con franjas rojas y blancas en la punta, anillos de servicio y luces
## rojas para los aviones.
func _stack(b: Boxes, red: Boxes) -> void:
	var seg := 2.0
	var n := int(STACK_H / seg)
	for k in n:
		var cyl := CylinderMesh.new()
		var r0 := 1.25 - 0.4 * k / n
		cyl.bottom_radius = r0
		cyl.top_radius = r0 - 0.4 / n
		cyl.height = seg
		cyl.radial_segments = 14
		cyl.rings = 1
		var col: Color = CONCRETE
		if k >= n - 4:
			col = Color8(220, 60, 50) if k % 2 == 0 else Color8(240, 240, 240)
		b.mesh(cyl, Transform3D(Basis.IDENTITY, STACK + Vector3(0, seg / 2 + k * seg, 0)), col)
	for y in [STACK_H * 0.45, STACK_H - 0.4]:
		var r: float = 1.25 - 0.4 * y / STACK_H + 0.35
		var ring := CylinderMesh.new()
		ring.top_radius = r
		ring.bottom_radius = r
		ring.height = 0.15
		ring.radial_segments = 14
		b.mesh(ring, Transform3D(Basis.IDENTITY, STACK + Vector3(0, y, 0)), STEEL)
		for a in 4:
			var ang := a * PI / 2 + PI / 4
			red.box(STACK + Vector3(cos(ang) * (r - 0.3), y + 0.25, sin(ang) * (r - 0.3)), Vector3(0.22, 0.22, 0.22), Color8(255, 40, 30))
	for k in int(STACK_H * 0.45 / 0.5):   # escalera de gato hasta el primer anillo
		b.box(STACK + Vector3(0, 0.4 + k * 0.5, -1.3 + 0.4 * k * 0.5 / STACK_H), Vector3(0.5, 0.04, 0.04), STEEL)
	rects.append([STACK.x - 1.3, STACK.x + 1.3, STACK.z - 1.3, STACK.z + 1.3, STACK_H])


## Torre de enfriamiento hiperbólica: anillos que se angostan hasta la cintura y después se abren; abajo las patas
## en V que dejan pasar el aire y el estanque.
func _cooling_tower(b: Boxes) -> void:
	var legs := 1.6
	var n := 10
	var r_base := 3.4
	var r_waist := 2.35
	var r_top := 2.6
	var hh := TOWER_H - legs
	var rad := func(t: float) -> float:
		if t < 0.72:
			return lerpf(r_base, r_waist, sin(t / 0.72 * PI / 2))
		return lerpf(r_waist, r_top, pow((t - 0.72) / 0.28, 2))
	for k in n:
		var t0 := float(k) / n
		var t1 := float(k + 1) / n
		var cyl := CylinderMesh.new()
		cyl.bottom_radius = rad.call(t0)
		cyl.top_radius = rad.call(t1)
		cyl.height = hh / n
		cyl.radial_segments = 22
		cyl.rings = 1
		var col := Color8(212, 209, 200) if k % 2 == 0 else Color8(203, 200, 191)
		b.mesh(cyl, Transform3D(Basis.IDENTITY, TOWER + Vector3(0, legs + (t0 + t1) / 2 * hh, 0)), col)
	for i in 12:   # patas en V
		var ang := i * TAU / 12.0
		var base := TOWER + Vector3(cos(ang), 0, sin(ang)) * (r_base - 0.1)
		b.box_rot(base + Vector3(0, legs / 2, 0), Vector3(0.22, legs + 0.2, 0.22), Color8(170, 166, 158),
				Vector3(0, -rad_to_deg(ang), 14.0 if i % 2 == 0 else -14.0))
	var pool := CylinderMesh.new()
	pool.top_radius = r_base + 0.4
	pool.bottom_radius = r_base + 0.4
	pool.height = 0.5
	pool.radial_segments = 22
	b.mesh(pool, Transform3D(Basis.IDENTITY, TOWER + Vector3(0, 0.25, 0)), CONCRETE)
	rects.append([TOWER.x - r_base, TOWER.x + r_base, TOWER.z - r_base, TOWER.z + r_base, TOWER_H])


## Estanques de combustible con techo, franja azul y escalera.
func _tanks(b: Boxes) -> void:
	for tp in TANKS:
		var cyl := CylinderMesh.new()
		cyl.top_radius = 1.15
		cyl.bottom_radius = 1.15
		cyl.height = 3.6
		cyl.radial_segments = 16
		b.mesh(cyl, Transform3D(Basis.IDENTITY, tp + Vector3(0, 1.8, 0)), Color8(232, 232, 228))
		var cap := CylinderMesh.new()
		cap.top_radius = 0.4
		cap.bottom_radius = 1.18
		cap.height = 0.5
		cap.radial_segments = 16
		b.mesh(cap, Transform3D(Basis.IDENTITY, tp + Vector3(0, 3.85, 0)), Color8(200, 200, 196))
		b.box(tp + Vector3(0, 1.4, -1.16), Vector3(1.6, 0.35, 0.02), Color8(60, 120, 190))
		for k in 9:
			b.box(tp + Vector3(1.2, 0.3 + k * 0.42, 0), Vector3(0.05, 0.04, 0.45), STEEL)
		rects.append([tp.x - 1.2, tp.x + 1.2, tp.z - 1.2, tp.z + 1.2, 4.1])


## Tuberías en un rack de acero: de la caldera a la torre de enfriamiento; y de los estanques a la caldera.
func _pipes(b: Boxes) -> void:
	var y := 3.4
	var a := Vector3(BOILER.x + BOILER_SIZE.x / 2, y, BOILER.z + 1.6)
	var c := Vector3(TOWER.x - 3.5, y, BOILER.z + 1.6)
	var len := a.distance_to(c)
	for off in [-0.3, 0.3]:
		var pipe := CylinderMesh.new()
		pipe.top_radius = 0.22
		pipe.bottom_radius = 0.22
		pipe.height = len
		pipe.radial_segments = 8
		b.mesh(pipe, Transform3D(Basis.from_euler(Vector3(0, 0, PI / 2)), (a + c) / 2 + Vector3(0, 0, off)),
				Color8(90, 140, 90) if off < 0 else Color8(200, 200, 196))
	var steps := maxi(1, int(len / 2.5))
	for k in steps + 1:   # soportes del rack
		var p := a.lerp(c, float(k) / steps)
		b.box(Vector3(p.x, y / 2, p.z), Vector3(0.14, y, 0.14), STEEL)
		b.box(Vector3(p.x, y - 0.3, p.z), Vector3(0.14, 0.1, 1.0), STEEL)
	for tp in TANKS:   # combustible: de cada estanque a la caldera, bajito
		var x0: float = BOILER.x + BOILER_SIZE.x / 2 + 0.1
		var x1: float = tp.x - 1.15
		var pipe := CylinderMesh.new()
		pipe.top_radius = 0.1
		pipe.bottom_radius = 0.1
		pipe.height = x1 - x0
		pipe.radial_segments = 6
		var py: float = 0.6 if tp == TANKS[0] else 0.9
		b.mesh(pipe, Transform3D(Basis.from_euler(Vector3(0, 0, PI / 2)), Vector3((x0 + x1) / 2, py, tp.z)), Color8(60, 60, 64))


## Poste de salida (reticulado con cruceta): las líneas a la avenida y al sur salen de aquí; lo alimenta la
## subestación de atrás con tres cables que pasan junto a la sala de turbinas.
func _outlet(b: Boxes) -> void:
	_lattice_post(b, OUTLET, OUTLET_H, 0.6)
	b.box(OUTLET + Vector3(0, OUTLET_H - 0.2, 0), Vector3(2.4, 0.25, 0.25), STEEL)
	for p in outlet_points():
		b.box(p + Vector3(0, 0.35, 0), Vector3(0.12, 0.6, 0.12), Color8(150, 105, 70))
	rects.append([OUTLET.x - 0.4, OUTLET.x + 0.4, OUTLET.z - 0.4, OUTLET.z + 0.4, OUTLET_H])


## Los tres puntos del poste de salida (de donde cuelgan los cables).
static func outlet_points() -> Array:
	return [OUTLET + Vector3(-0.9, OUTLET_H - 0.9, 0), OUTLET + Vector3(0, OUTLET_H - 0.9, 0), OUTLET + Vector3(0.9, OUTLET_H - 0.9, 0)]


## Los rectángulos del patio (adelante y atrás) para el mapa y la red.
static func rects2d() -> Array:
	return [Rect2(X0, Z0, X1 - X0, BACK_Z - Z0), Rect2(X0, BACK_Z, BACK_X1 - X0, Z1 - BACK_Z)]


## Patio de la subestación: grava, transformadores con aletas, pórticos de reticulado con aisladores y barras, y su
## propia reja. De su pórtico alto (GANTRY) salen las líneas hacia la ciudad (PowerGrid).
func _yard(b: Boxes) -> void:
	var r := YARD
	b.box(Vector3(r.get_center().x, 0.07, r.get_center().y), Vector3(r.size.x, 0.02, r.size.y), Color8(140, 136, 128))
	for i in 2:   # transformadores grandes
		var tp := Vector3(r.position.x + 1.6, 0, r.position.y + 2.4 + i * 3.6)
		b.box(tp + Vector3(0, 1.1, 0), Vector3(1.6, 2.2, 1.9), Color8(92, 108, 92))
		for k in 6:   # aletas
			b.box(tp + Vector3(-0.95, 1.0, -0.8 + k * 0.32), Vector3(0.3, 1.6, 0.06), Color8(80, 96, 80))
		for j in 3:
			var ins := CylinderMesh.new()
			ins.top_radius = 0.07
			ins.bottom_radius = 0.12
			ins.height = 0.9
			ins.radial_segments = 6
			b.mesh(ins, Transform3D(Basis.IDENTITY, tp + Vector3(0.3, 2.65, -0.55 + j * 0.55)), Color8(150, 105, 70))
	for gz in [r.position.y + 1.0, r.end.y - 1.0]:   # pórticos con viga, aisladores colgando
		for gx in [r.position.x + 0.4, r.end.x - 0.4]:
			_lattice_post(b, Vector3(gx, 0, gz), GANTRY.y)
		b.box(Vector3(r.get_center().x, GANTRY.y - 0.2, gz), Vector3(r.size.x, 0.35, 0.35), STEEL)
		for j in 3:
			b.box(Vector3(r.position.x + 1.0 + j * 1.2, GANTRY.y - 0.9, gz), Vector3(0.12, 1.1, 0.12), Color8(150, 105, 70))
	for j in 3:   # barras entre los dos pórticos
		b.box(Vector3(r.position.x + 1.0 + j * 1.2, GANTRY.y - 1.45, r.get_center().y), Vector3(0.05, 0.05, r.size.y - 2.0), Color8(60, 60, 64))
	for seg in [[r.position.x, r.position.y, r.end.x, r.position.y], [r.position.x, r.end.y, r.end.x, r.end.y],
			[r.position.x, r.position.y, r.position.x, r.end.y]]:   # reja del patio
		var a := Vector2(seg[0], seg[1])
		var c := Vector2(seg[2], seg[3])
		var along_x: bool = absf(c.x - a.x) > absf(c.y - a.y)
		var len := a.distance_to(c)
		b.box(Vector3((a.x + c.x) / 2, 0.9, (a.y + c.y) / 2), Vector3(len if along_x else 0.03, 1.8, 0.03 if along_x else len), Color8(150, 158, 166))
	rects.append([r.position.x, r.end.x, r.position.y, r.end.y, 2.5])


## Poste de reticulado (cuatro perfiles con travesaños y diagonales), de la base a `h`.
static func _lattice_post(b: Boxes, base: Vector3, h: float, w := 0.5, col := Color8(120, 128, 138)) -> void:
	for dx in [-1, 1]:
		for dz in [-1, 1]:
			b.box(base + Vector3(dx * w / 2, h / 2, dz * w / 2), Vector3(0.08, h, 0.08), col)
	var n := int(h / 1.2)
	for k in n:
		var y := 0.6 + k * 1.2
		for dz in [-1, 1]:
			b.box(base + Vector3(0, y, dz * w / 2), Vector3(w, 0.05, 0.05), col)
			b.box_rot(base + Vector3(0, y + 0.6, dz * w / 2), Vector3(sqrt(w * w + 1.44), 0.04, 0.04), col,
					Vector3(0, 0, rad_to_deg(atan2(1.2, w)) * (1 if k % 2 == 0 else -1)))


## Caseta de pagos: ventanilla con mostrador, techo amarillo y luz.
func _booth(b: Boxes, lights: Boxes) -> void:
	var bw := Vector3(1.8, 2.5, 1.4)
	b.box(BOOTH + Vector3(0, 0.55, 0), Vector3(bw.x, 1.1, bw.z), Color8(235, 235, 230))
	for sx in [-1, 1]:
		b.box(BOOTH + Vector3(sx * (bw.x / 2 - 0.06), bw.y / 2, 0), Vector3(0.12, bw.y, bw.z), Color8(235, 235, 230))
	b.box(BOOTH + Vector3(0, bw.y / 2, bw.z / 2 - 0.06), Vector3(bw.x, bw.y, 0.12), Color8(235, 235, 230))
	b.box(BOOTH + Vector3(0, bw.y + 0.1, -0.1), Vector3(bw.x + 0.5, 0.2, bw.z + 0.6), Color8(240, 190, 40))
	b.box(BOOTH + Vector3(0, 1.12, -bw.z / 2 - 0.12), Vector3(bw.x - 0.1, 0.06, 0.4), Color8(120, 90, 60))
	lights.box(BOOTH + Vector3(0, bw.y - 0.05, 0), Vector3(0.6, 0.04, 0.3), Color8(255, 240, 200))
	rects.append([BOOTH.x - bw.x / 2, BOOTH.x + bw.x / 2, BOOTH.z - bw.z / 2 - 0.3, BOOTH.z + bw.z / 2, bw.y])


func _beacon() -> void:
	beacon = Node3D.new()
	beacon.position = HALL + Vector3(2.4, HALL_SIZE.y + 0.9, -3.8)
	root.add_child(beacon)
	var bb := Boxes.new()
	bb.box(Vector3(0, -0.15, 0), Vector3(0.5, 0.2, 0.5), Color8(40, 40, 44))
	bb.node(beacon, Mats.standard, false)
	var glow := Boxes.new()
	glow.box(Vector3(0, 0.12, 0), Vector3(0.36, 0.36, 0.36), Color8(255, 140, 30))
	glow.box(Vector3(0.0, 0.12, 0.35), Vector3(0.2, 0.2, 0.5), Color8(255, 170, 60))   # el haz que gira
	beacon_glow = glow.node(beacon, Mats.emissive, false)
	beacon_glow.visible = false


## Operario de la caseta: gorra, chaleco naranja.
func _worker() -> void:
	var look: Dictionary = Wardrobe.DEFAULT_LOOK.duplicate()
	look.merge({"shirt": [245, 130, 30], "hat": "gorra", "pants": [50, 60, 90], "hair": [60, 40, 25]}, true)
	worker = Person.new(null, null, false, look)
	worker.name = "Operario"
	root.add_child(worker)
	worker.position = WORKER
	worker.rotation.y = PI   # mirando a la calle


func _effects() -> void:
	sparks = CPUParticles3D.new()
	sparks.position = SPARKS
	sparks.amount = 40
	sparks.lifetime = 0.7
	sparks.explosiveness = 0.6
	sparks.emitting = false
	sparks.direction = Vector3(0, 1, 0)
	sparks.spread = 70.0
	sparks.initial_velocity_min = 2.5
	sparks.initial_velocity_max = 5.5
	sparks.gravity = Vector3(0, -9.8, 0)
	sparks.scale_amount_min = 0.05
	sparks.scale_amount_max = 0.1
	var sm := BoxMesh.new()
	sm.size = Vector3.ONE
	var spark_mat := StandardMaterial3D.new()
	spark_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	spark_mat.albedo_color = Color8(255, 230, 120)
	sm.material = spark_mat
	sparks.mesh = sm
	root.add_child(sparks)
	# humo de la chimenea y vapor de la torre
	for spec in [[STACK + Vector3(0, STACK_H + 0.3, 0), 14, 0.8, 1.4, false], [TOWER + Vector3(0, TOWER_H + 0.2, 0), 10, 1.6, 2.6, true]]:
		var s := CPUParticles3D.new()
		s.position = spec[0]
		s.amount = spec[1]
		s.lifetime = 4.5
		s.direction = Vector3(0.3, 1, 0)
		s.spread = 12.0
		s.initial_velocity_min = 1.0
		s.initial_velocity_max = 1.8
		s.gravity = Vector3(0.3, 0.25, 0)
		s.scale_amount_min = spec[2]
		s.scale_amount_max = spec[3]
		var curve := Curve.new()
		curve.add_point(Vector2(0, 0.6))
		curve.add_point(Vector2(1, 2.4))
		s.scale_amount_curve = curve
		var pm := SphereMesh.new()
		pm.radius = 0.5
		pm.height = 1.0
		pm.radial_segments = 6
		pm.rings = 3
		var smat := StandardMaterial3D.new()
		smat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		smat.albedo_color = Color(0.88, 0.88, 0.88, 0.3)
		smat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		pm.material = smat
		s.mesh = pm
		s.set_meta("mat", smat)
		s.set_meta("steam", spec[4])
		root.add_child(s)
		smoke.append(s)


## Cada cuadro: la baliza gira, las chispas saltan de a ratos y las ventanas se apagan (o titilan) si falla.
func update(dt: float, is_failing: bool) -> void:
	_t += dt
	failing = is_failing
	beacon_glow.visible = failing and (int(_t * 3.0) % 2 == 0 or flicker > 0.0)
	if failing:
		beacon.rotation.y += dt * 6.0
	lit.visible = not failing   # sin luz se apaga de golpe (no titila)
	reds.visible = int(_t * 1.2) % 2 == 0   # las luces de la chimenea parpadean lento (tienen batería)
	if failing and not sparks.emitting and randf() < dt * (3.0 if flicker > 0.0 else 0.35):
		sparks.restart()
		sparks.emitting = true
	for s in smoke:
		if s.get_meta("steam"):   # sin luz la torre no echa vapor
			s.emitting = not failing
		else:
			var m: StandardMaterial3D = s.get_meta("mat")
			m.albedo_color = Color(0.18, 0.17, 0.17, 0.55) if failing else Color(0.88, 0.88, 0.88, 0.3)


## Una ráfaga grande de chispas ahora mismo (la cinemática, cuando revienta).
func burst() -> void:
	sparks.amount = 90
	sparks.restart()
	sparks.emitting = true


func interactables(g: Game, pay: Callable) -> Array:
	if not g.power_fail:
		return [[PAY_SPOT, "Planta eléctrica: funciona bien", func(): pass]]
	if g.power_failing():
		return [[PAY_SPOT, Lang.f("Pagar el arreglo de la planta (%s · luz por %d días)", [Fmt.money(g.power_cost()), int(D.POWER.days)]), pay]]
	return [[PAY_SPOT, Lang.f("Planta eléctrica: luz asegurada por %d días más", g.power_days_left()), pay]]
