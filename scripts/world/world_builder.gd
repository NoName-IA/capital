class_name WorldBuilder
extends RefCounted
## Construye la parte fija de la ciudad: terreno, mar, avenida, faroles, árboles, rascacielos, la oficina central,
## el Barrio Las Lomas, el Parque Central y el Paseo de la Playa. Mismas medidas que la versión de Python.

const SIDEWALK := 7.5
const HQ := [-80, 1]

var city: Node3D
var rects := []                 # rectángulos de choque fijos
var props := Boxes.new()        # todo lo de madera, piedra, plantas... en una sola malla
var windows := Boxes.new()      # ventanas de las casas (de noche se prenden)
var lamps := Boxes.new()        # faroles (de noche brillan)
var rng := RandomNumberGenerator.new()
var boats := []
var beacon: MeshInstance3D
var lamp_node: MeshInstance3D
var lamp_spots := []             # dónde cuelga la luz de cada farol
var small_lights := []           # otras luces de noche: [posición, nivel] (focos de las casas, muelle, fuente, faro...)
const VOLLEY := Vector3(146.0, 0.0, -44.0)   # centro de la cancha de vóley de la playa
var activity_spots := {}         # actividad de la ciudad (D.ACTIVITIES) -> dónde se hace (ver _activities)
var park_spots := []             # (x, z) de bancas, faroles y adornos del parque: los árboles no se ponen encima
var diario := {}                 # textos de la pantalla del clima del kiosco ELDIARIO
var diario_seller: Person
const DIARIO_BUY := Vector3(-69.2, 0, 10.9)   # donde se paran los que compran el diario
var hq: Building


func _init(parent: Node3D) -> void:
	city = parent


func build() -> void:
	rng.seed = 9
	_terrain()
	_avenue()
	_skyline()
	_zones()
	props.node(city, Mats.standard)
	windows.node(city, Mats.windows, false)
	lamp_node = lamps.node(city, Mats.emissive, false)
	_lamp_lights()
	hq = Building.new(city, HQ, "hq", Blueprints.PALETTE.gold, "")
	rects += hq.rects
	_eldiario()


## Kiosco de diarios ELDIARIO, al lado de tu oficina: mostrador con diarios y revistas, un vendedor y una pantalla
## grande con el clima de hoy, la hora y el pronóstico de mañana (los textos los actualiza la ciudad).
func _eldiario() -> void:
	var x := -69.0
	var z0 := 11.6
	var w := 4.6
	var d := 3.8
	var navy := Color8(25, 45, 85)
	var red := Color8(200, 45, 45)
	var k := Boxes.new()
	k.box(Vector3(x, 0.03, z0 + d / 2), Vector3(w, 0.06, d), Color8(190, 185, 175))
	k.box(Vector3(x, 1.6, z0 + d - 0.1), Vector3(w, 3.2, 0.2), navy)                  # fondo
	for sx in [-1, 1]:
		k.box(Vector3(x + sx * (w / 2 - 0.1), 1.6, z0 + d / 2), Vector3(0.2, 3.2, d), navy)
	k.box(Vector3(x, 3.3, z0 + d / 2), Vector3(w + 0.3, 0.2, d + 0.3), navy)          # techo
	k.box(Vector3(x, 0.55, z0 + 0.35), Vector3(w - 0.4, 1.1, 0.5), navy)              # mostrador
	k.box(Vector3(x, 1.13, z0 + 0.35), Vector3(w - 0.3, 0.06, 0.6), Color8(170, 120, 75))
	for i in 8:                                                                        # diarios y revistas
		var col: Color = [Color8(235, 232, 220), Color8(240, 200, 60), red, Color8(70, 140, 210)][i % 4]
		k.box(Vector3(x - 1.75 + i * 0.5, 1.2 + (i % 3) * 0.03, z0 + 0.3), Vector3(0.36, 0.08 + (i % 3) * 0.06, 0.45), col)
	for sx in [-1, 1]:                                                                 # estantes con revistas
		for y in [1.6, 2.2]:
			k.box(Vector3(x + sx * 1.7, y, z0 + d - 0.35), Vector3(0.9, 0.05, 0.4), Color8(170, 120, 75))
			for j in 3:
				k.box(Vector3(x + sx * 1.7 - 0.3 + j * 0.3, y + 0.18, z0 + d - 0.35), Vector3(0.22, 0.3, 0.04),
						[red, Color8(240, 200, 60), Color8(70, 140, 210)][(j + int(y)) % 3])
	k.box(Vector3(x, 3.75, z0 + 0.05), Vector3(w + 0.3, 0.7, 0.15), red)               # letrero
	k.box(Vector3(x, 5.6, z0 + 0.5), Vector3(4.4, 2.6, 0.25), Color8(20, 22, 28))      # pantalla del clima
	k.box(Vector3(x, 5.6, z0 + 0.36), Vector3(4.2, 2.4, 0.02), Color8(14, 36, 70))
	for sx in [-1.6, 1.6]:
		k.box(Vector3(x + sx, 4.15, z0 + 0.5), Vector3(0.12, 0.6, 0.12), Color8(60, 60, 65))
	k.node(city, Mats.standard)
	rects.append([x - w / 2, x + w / 2, z0, z0 + d, 3.4])
	Building.label(city, "ELDIARIO", Vector3(x, 3.76, z0 - 0.04), 15, Color.WHITE, true, false).rotation.y = PI
	var screen_z := z0 + 0.33
	var icon := Sprite3D.new()   # ícono del clima (sale del atlas de Icons)
	icon.texture = Icons.atlas.get_texture()
	icon.region_enabled = true
	icon.region_rect = Icons.region("sun")
	icon.pixel_size = 0.013
	icon.shaded = false
	icon.position = Vector3(x - 1.25, 5.85, screen_z)
	city.add_child(icon)
	diario.icon = icon
	diario.temp = Building.label(city, "24°C", Vector3(x + 0.55, 6.15, screen_z), 17, Color.WHITE, true, false)
	diario.kind = Building.label(city, "Soleado", Vector3(x + 0.55, 5.62, screen_z), 7, Color8(200, 220, 245), false, false)
	diario.hour = Building.label(city, "12:00", Vector3(x - 1.25, 4.85, screen_z), 6, Color8(200, 220, 245), false, false)
	diario.tomorrow = Building.label(city, "En 3 días: Nublado", Vector3(x + 0.55, 4.95, screen_z), 6, Color8(255, 210, 80), true, false)
	for l in diario.values():
		l.rotation.y = PI
	var title := Building.label(city, "EL CLIMA HOY", Vector3(x, 6.7, screen_z), 6, Color8(255, 255, 255, 200), true, false)
	title.rotation.y = PI
	var seller := Person.new(Color8(200, 45, 45), null, false)
	diario_seller = seller
	city.add_child(seller)
	seller.position = Vector3(x + 0.4, 0, z0 + 1.4)
	seller.rotation.y = PI
	Mats.add_light(city, Vector3(x, 2.8, z0 + d / 2), 10.0)


## Una luz por farol (ver Mats.add_light). De día están apagadas.
func _lamp_lights() -> void:
	for p in lamp_spots:
		Mats.add_light(city, p, 15.0 if p.z > -9.0 else 12.0)  # faroles de la avenida y del parque
	for l in small_lights:
		Mats.add_light(city, l[0], l[1])
	# Reflectores al pie de la oficina central que alumbran la fachada desde abajo
	for x in [-86.0, -74.0]:
		Mats.add_light(city, Vector3(x, 0.9, 9.6), 12.0)


## La calle sigue por la arena y se mete al mar: tramos cortos que siguen la pendiente (ver Actors.road_y).
func _road_to_sea() -> void:
	var asphalt := Boxes.new()
	var lines := Boxes.new()
	var x := 157.0
	while x < Actors.ROAD_END:
		var y0 := Actors.road_y(x)
		var y1 := Actors.road_y(x + 2.0)
		var tilt := rad_to_deg(atan2(y1 - y0, 2.0))
		var c := Vector3(x + 1.0, (y0 + y1) / 2.0 - 0.02, 0)
		asphalt.box_rot(c, Vector3(2.05, 0.06, 12), Color8(80, 83, 90), Vector3(0, 0, tilt))
		for z in [-0.15, 0.15]:
			lines.box_rot(c + Vector3(0, 0.035, z), Vector3(2.05, 0.01, 0.12), Color8(230, 190, 60), Vector3(0, 0, tilt))
		x += 2.0
	asphalt.node(city, Mats.textured(Mats.asphalt, 0.95, Color.WHITE, Vector3(1, 1, 1)), false)
	lines.node(city, Mats.standard, false)


func _mesh_node(mesh: Mesh, material: Material, pos: Vector3, shadows := false) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	mi.material_override = material
	mi.position = pos
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON if shadows else GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	city.add_child(mi)
	return mi


func _plane(size: Vector2, mat: Material, pos: Vector3) -> MeshInstance3D:
	var pm := PlaneMesh.new()
	pm.size = size
	return _mesh_node(pm, mat, pos)


func _box_node(pos: Vector3, size: Vector3, mat: Material) -> MeshInstance3D:
	var bm := BoxMesh.new()
	bm.size = size
	return _mesh_node(bm, mat, pos)


# ---------- terreno, mar, calle ----------
func _terrain() -> void:
	var ground := _mesh_node(Terrain.build_mesh(), Mats.textured(Mats.grass, 0.95), Vector3.ZERO)
	var sea := _plane(Vector2(800, 1100), Mats.water, Vector3(Terrain.COAST + 400, Terrain.SEA_LEVEL, 0))
	sea.name = "Mar"


func _avenue() -> void:
	# Calle y veredas con textura propia
	# La calle va de x = -250 (en el valle de los cerros) a 158 (donde se mete al mar, ver _road_to_sea)
	var road := _box_node(Vector3(-46, 0.005, 0), Vector3(408, 0.01, 12), Mats.textured(Mats.asphalt, 0.95, Color8(80, 83, 90), Vector3(68, 2, 1)))
	road.name = "Calle"
	for side in [-1, 1]:
		_box_node(Vector3(-46, 0.02, side * SIDEWALK), Vector3(408, 0.04, 3), Mats.textured(Mats.tiles, 0.9, Color8(200, 200, 195), Vector3(136, 1, 1)))
	for z in [-0.15, 0.15]:
		props.box(Vector3(-46, 0.015, z), Vector3(408, 0.01, 0.12), Color8(230, 190, 60))
	for side in [-1, 1]:
		props.box(Vector3(-46, 0.06, side * 6.0), Vector3(408, 0.12, 0.12), Color8(150, 150, 145))
		for x in range(-246, 154, 8):
			props.box(Vector3(x, 0.012, side * 3), Vector3(3, 0.01, 0.15), Color8(220, 220, 220))
	rng.seed = 9
	for side in [-1, 1]:
		for x in [-66, -44, -22, 0, 22, 44, 66, 88, -90]:
			if not (side == -1 and x == 0):  # ahí está la entrada del parque
				tree(Vector3(x, 0, side * 9.6))
		for x in range(-154, 155, 22):   # los faroles siguen un poco por el camino a los cerros
			if side == -1 and x == 0:
				continue  # frente a la entrada del parque
			var pos := Vector3(x, 0, side * 6.4)
			props.box(pos + Vector3(0, 2.2, 0), Vector3(0.15, 4.4, 0.15), Blueprints.PALETTE.dark)
			props.box(pos + Vector3(0, 4.4, -side * 0.25), Vector3(0.12, 0.12, 0.6), Blueprints.PALETTE.dark)
			lamps.box(Vector3(x, 4.3, side * 6.4 - side * 0.4), Vector3(0.5, 0.2, 0.9), Color8(255, 225, 140))
			lamp_spots.append(Vector3(x, 4.1, side * 6.0))
			rects.append([x - 0.15, x + 0.15, pos.z - 0.15, pos.z + 0.15, 4.4])


func _skyline() -> void:
	var sky := Boxes.new()
	var sky_glass := Boxes.new()
	rng.seed = 4
	var tones := [Color8(150, 160, 175), Color8(175, 165, 150), Color8(130, 140, 150), Color8(190, 185, 175)]
	for side in [-1, 1]:
		for x in range(-130, -39, 14):
			var h := rng.randf_range(14, 34)
			var px: float = x + rng.randf_range(-3, 3)
			var pz: float = side * rng.randf_range(48, 60)
			var sx := rng.randf_range(9, 13)
			var sz := rng.randf_range(8, 12)
			sky.box(Vector3(px, h / 2, pz), Vector3(sx, h, sz), tones.pick_random())
			# Fachadas de vidrio en los cuatro lados (dejan ver los pisos)
			for f in 4:
				var floors := int(h / 3.2)
				for i in floors:
					var y := 1.8 + i * 3.2
					if y + 1.2 > h:
						break
					if f < 2:
						sky_glass.box(Vector3(px, y, pz + (sz / 2 + 0.03) * (1 if f == 0 else -1)), Vector3(sx - 1.2, 2.0, 0.06), Color8(90, 120, 150))
					else:
						sky_glass.box(Vector3(px + (sx / 2 + 0.03) * (1 if f == 2 else -1), y, pz), Vector3(0.06, 2.0, sz - 1.2), Color8(90, 120, 150))
			sky.box(Vector3(px, h + 0.25, pz), Vector3(sx + 0.4, 0.5, sz + 0.4), Color8(60, 64, 72))
			rects.append([px - sx / 2, px + sx / 2, pz - sz / 2, pz + sz / 2, h])
	sky.node(city, Mats.standard)
	sky_glass.node(city, Mats.glass_glow, false)


# ---------- árboles ----------
## Árboles de dos tipos: pino (conos apilados) y frondoso (varias copas de distinto verde).
func tree(pos: Vector3) -> void:
	var trunk := Color8(105, 75, 50)
	if rng.randf() < 0.35:
		props.box(pos + Vector3(0, 0.9, 0), Vector3(0.3, 1.8, 0.3), trunk)
		var layers := [[1.6, 1.7, 1.4], [1.2, 1.5, 2.4], [0.8, 1.3, 3.3]]
		for i in 3:
			var cone := CylinderMesh.new()
			cone.top_radius = 0.0
			cone.bottom_radius = layers[i][0]
			cone.height = layers[i][1]
			cone.radial_segments = 8
			cone.rings = 1
			props.mesh(cone, Transform3D(Basis.IDENTITY, pos + Vector3(0, layers[i][2] + layers[i][1] / 2, 0)),
					Color8(40 + i * 10, 100 + i * 12, 58))
	else:
		props.box(pos + Vector3(0, 1.3, 0), Vector3(0.38, 2.6, 0.38), trunk)
		props.box_rot(pos + Vector3(0.35, 2.3, 0), Vector3(0.14, 1.0, 0.14), trunk, Vector3(0, 0, -40))
		var greens := [Color8(70, 140, 70), Color8(85, 155, 75), Color8(60, 125, 65), Color8(95, 165, 80)]
		for b in [[0, 3.4, 0, 2.7], [0.85, 3.0, 0.3, 1.8], [-0.75, 3.1, -0.4, 1.9], [0.1, 4.2, -0.15, 1.7]]:
			var sph := SphereMesh.new()
			sph.radius = 0.5
			sph.height = 1.0
			sph.radial_segments = 10
			sph.rings = 6
			var basis := Basis.from_scale(Vector3(b[3], b[3] * 0.85, b[3]))
			props.mesh(sph, Transform3D(basis, pos + Vector3(b[0], b[1], b[2])), greens[rng.randi_range(0, 3)])
	rects.append([pos.x - 0.25, pos.x + 0.25, pos.z - 0.25, pos.z + 0.25, 2.4])


# ---------- zonas ----------
func _zones() -> void:
	rng.seed = 21
	_barrio()
	_park()
	_beach()
	_activities()


## Lugares de la ciudad donde se hace algo útil para el negocio (ver Game.do_activity): el stand de muestras del
## parque, el tablón de vecinos del barrio, la cancha de vóley de la playa y la punta del muelle para pescar.
func _activities() -> void:
	var wood := Color8(150, 110, 70)
	var white := Color8(245, 245, 240)
	# Parque: stand de muestras gratis, al lado de la fuente
	var sp := Vector3(6.5, 0, -27.5)
	props.box(sp + Vector3(0, 0.45, 0), Vector3(2.4, 0.9, 0.9), Color8(220, 80, 60))
	props.box(sp + Vector3(0, 0.93, 0), Vector3(2.6, 0.06, 1.0), white)
	for dx in [-1.2, 1.2]:
		props.box(sp + Vector3(dx, 1.5, -0.4), Vector3(0.08, 2.2, 0.08), white)
	props.box(sp + Vector3(0, 2.62, -0.1), Vector3(2.8, 0.08, 1.4), Color8(240, 200, 70))
	for k in 5:   # vasitos y bolsitas de muestra
		props.box(sp + Vector3(-0.9 + k * 0.45, 1.03, 0.1), Vector3(0.14, 0.14, 0.14), [white, Color8(230, 180, 90)][k % 2])
	var l := Building.label(city, "MUESTRAS GRATIS", sp + Vector3(0, 2.3, -0.42), 9, Color8(40, 40, 44), true, false)
	l.rotation.y = 0.0
	rects.append([sp.x - 1.3, sp.x + 1.3, sp.z - 0.5, sp.z + 0.5, 0.95])
	activity_spots["muestras"] = sp + Vector3(0, 0, 1.2)
	park_spots.append(Vector2(sp.x, sp.z))
	# Barrio: tablón de anuncios de los vecinos, a la entrada del pasaje
	var bp := Vector3(-44, 0, 45)
	for dx in [-1.0, 1.0]:
		props.box(bp + Vector3(dx, 1.0, 0), Vector3(0.12, 2.0, 0.12), wood)
	props.box(bp + Vector3(0, 1.45, 0), Vector3(2.3, 1.1, 0.1), Color8(170, 125, 80))
	props.box(bp + Vector3(0, 2.05, 0), Vector3(2.5, 0.1, 0.3), Color8(110, 80, 55))
	for k in 6:   # papelitos clavados
		props.box(bp + Vector3(-0.8 + (k % 3) * 0.75, 1.65 - (k / 3) * 0.45, -0.07), Vector3(0.45, 0.32, 0.01),
				[white, Color8(250, 230, 120), Color8(170, 210, 240)][k % 3])
	l = Building.label(city, "VECINOS", bp + Vector3(0, 1.88, -0.07), 8, Color8(40, 40, 44), true, false)
	l.rotation.y = PI
	rects.append([bp.x - 1.15, bp.x + 1.15, bp.z - 0.1, bp.z + 0.1, 2.1])
	activity_spots["encuesta"] = bp + Vector3(0, 0, -1.2)
	# Playa: cancha de vóley con la red y el letrero del torneo, en la arena plana antes de la orilla (más cerca del mar
	# el suelo baja y la cancha quedaba flotando)
	var vp := VOLLEY
	for dz in [-3.0, 3.0]:
		props.box(vp + Vector3(0, 1.2, dz), Vector3(0.1, 2.4, 0.1), white)
	props.box(vp + Vector3(0, 2.15, 0), Vector3(0.03, 0.7, 6.0), Color8(235, 235, 235))
	props.box(vp + Vector3(0, 2.48, 0), Vector3(0.05, 0.06, 6.0), Color8(40, 90, 200))
	for dx in [-4.0, 4.0]:   # líneas de la cancha
		props.box(vp + Vector3(dx, 0.02, 0), Vector3(0.08, 0.02, 6.0), Color8(40, 90, 200))
	for dz in [-3.0, 3.0]:
		props.box(vp + Vector3(0, 0.02, dz), Vector3(8.0, 0.02, 0.08), Color8(40, 90, 200))
	# Letrero mirando hacia la calle, al lado de la cancha
	var sg := vp + Vector3(-2.5, 0, 4.6)
	props.box(sg + Vector3(0, 0.75, 0), Vector3(0.1, 1.5, 0.1), wood)
	props.box(sg + Vector3(0, 1.75, 0), Vector3(2.4, 0.8, 0.1), Color8(40, 90, 200))
	Building.label(city, "TORNEO DE VÓLEY", sg + Vector3(0, 1.75, 0.06), 7, Color.WHITE, true, false)
	rects.append([vp.x - 0.1, vp.x + 0.1, vp.z - 3.1, vp.z + 3.1, 2.5])
	rects.append([sg.x - 1.2, sg.x + 1.2, sg.z - 0.1, sg.z + 0.1, 2.15])
	activity_spots["voley"] = sg + Vector3(0, 0, 1.2)
	# Muelle: balde y caña en la punta, para pescar
	var fp := Vector3(202.0, 0.42, 24.0)
	props.box(fp + Vector3(0.6, 0.18, 0.7), Vector3(0.3, 0.36, 0.3), Color8(60, 110, 170))
	props.box_rot(fp + Vector3(0.9, 0.9, -0.6), Vector3(0.04, 2.2, 0.04), Color8(70, 50, 35), Vector3(0, 0, -35))
	activity_spots["pesca"] = fp


## Barrio Las Lomas: casas detrás de los locales, a ambos lados de la avenida.
func _barrio() -> void:
	var pastel := [Color8(236, 214, 178), Color8(198, 222, 236), Color8(240, 200, 196), Color8(210, 232, 200),
			Color8(244, 236, 205), Color8(225, 210, 235), Color8(250, 250, 245)]
	var roofs := [Color8(160, 70, 55), Color8(90, 95, 110), Color8(120, 80, 60), Color8(70, 110, 90), Color8(150, 110, 70)]
	var asphalt := Mats.textured(Mats.asphalt, 0.95, Color8(85, 88, 95), Vector3(25, 1, 1))
	for spec in [[1, -40, 108], [-1, 28, 108]]:
		var side: int = spec[0]
		var x0: float = spec[1]
		var x1: float = spec[2]
		var lane := side * 45.0
		_box_node(Vector3((x0 + x1) / 2, 0.006, lane), Vector3(x1 - x0, 0.01, 5), asphalt)
		for dz in [-2.8, 2.8]:
			props.box(Vector3((x0 + x1) / 2, 0.03, lane + dz), Vector3(x1 - x0, 0.06, 0.6), Color8(200, 200, 195))
		for row in [[side * 35.5, side], [side * 54.5, -side]]:
			var row_z: float = row[0]
			var face: int = row[1]
			for x in range(int(x0) + 8, int(x1) - 4, 13):
				if rng.randf() < 0.12:  # un terreno con jardín y árboles
					tree(Vector3(x + rng.randf_range(-2, 2), 0, row_z + rng.randf_range(-2, 2)))
					continue
				house(Vector3(x + rng.randf_range(-1, 1), 0, row_z), face, pastel, roofs)
			for x in range(int(x0) + 14, int(x1) - 4, 26):
				tree(Vector3(x + 6.5, 0, row_z - face * 6.2))
	for k in 6:  # bosquecito entre el distrito financiero y el parque (lado sur)
		tree(Vector3(rng.randf_range(-38, -28), 0, rng.randf_range(-56, -30)))


## Casa con techo a dos aguas, puerta hacia el pasaje, ventanas, chimenea y cerco con jardín.
func house(pos: Vector3, face: int, pastel: Array, roofs: Array) -> void:
	var w := rng.randf_range(7, 8.5)
	var d := 6.5
	var h := rng.randf_range(3.2, 4.4)
	var wall: Color = pastel[rng.randi_range(0, pastel.size() - 1)]
	var roof: Color = roofs[rng.randi_range(0, roofs.size() - 1)]
	props.box(pos + Vector3(0, h / 2, 0), Vector3(w, h, d), wall)
	var s := d / 1.414 + 0.45
	props.box_rot(pos + Vector3(0, h, 0), Vector3(w + 0.7, s, s), roof, Vector3(45, 0, 0))
	props.box(pos + Vector3(w * 0.25, h + d * 0.35, 0.8), Vector3(0.7, 1.6, 0.7), Color8(150, 80, 60))
	var front := pos.z + face * (d / 2 + 0.02)
	var dx := (1 if rng.randf() < 0.5 else -1) * w * 0.22
	props.box(Vector3(pos.x + dx, 1.05, front), Vector3(1.1, 2.1, 0.08), Color8(120, 75, 45))
	props.box(Vector3(pos.x + dx, 0.1, front + face * 0.6), Vector3(1.6, 0.2, 1.2), Color8(185, 180, 170))
	# Foco de la entrada: de noche alumbra la puerta y el antejardín
	var lx := pos.x + dx + 0.95
	props.box(Vector3(lx, 2.35, front + face * 0.06), Vector3(0.14, 0.14, 0.12), Color8(40, 40, 44))
	lamps.box(Vector3(lx, 2.2, front + face * 0.14), Vector3(0.2, 0.26, 0.2), Color8(255, 225, 160))
	small_lights.append([Vector3(lx, 2.2, front + face * 0.4), 10.0])
	windows.box(Vector3(pos.x - dx, h * 0.55, front), Vector3(1.6, 1.1, 0.06), Color8(170, 205, 230))
	var back := pos.z - face * (d / 2 + 0.02)
	for wx in [-w * 0.25, w * 0.25]:
		windows.box(Vector3(pos.x + wx, h * 0.55, back), Vector3(1.3, 1.0, 0.06), Color8(170, 205, 230))
	# Cerco blanco del antejardín (con hueco frente a la puerta)
	var fz := pos.z + face * (d / 2 + 2.6)
	for k in range(-5, 6):
		var x: float = pos.x + k * (w + 1) / 10
		if absf(x - (pos.x + dx)) < 1.0:
			continue
		props.box(Vector3(x, 0.45, fz), Vector3(0.1, 0.9, 0.1), Color8(245, 245, 245))
	props.box(Vector3(pos.x, 0.7, fz), Vector3(w + 1, 0.08, 0.06), Color8(245, 245, 245))
	rects.append([pos.x - w / 2, pos.x + w / 2, pos.z - d / 2, pos.z + d / 2, h + d / 2])


func _disc(radius: float, pos: Vector3, mat: Material) -> MeshInstance3D:
	var cm := CylinderMesh.new()
	cm.top_radius = radius
	cm.bottom_radius = radius
	cm.height = 0.02
	cm.radial_segments = 32
	return _mesh_node(cm, mat, pos)


## Parque Central: en medio de la avenida, con entrada desde la vereda.
func _park() -> void:
	# ±21 m: deja un pasillo con los locales de los terrenos vecinos (x = ±33), aunque sean megatiendas
	var px0 := -21.0
	var px1 := 21.0
	var pz0 := -9.6
	var pz1 := -58.0
	_plane(Vector2(px1 - px0, pz0 - pz1), Mats.textured(Mats.grass, 0.95, Color8(92, 145, 66), Vector3(10, 10, 1)),
			Vector3(0, 0.008, (pz0 + pz1) / 2))
	var path_mat := Mats.textured(Mats.tiles, 0.9, Color8(215, 200, 170), Vector3(2, 24, 1))
	_box_node(Vector3(0, 0.02, (pz0 + pz1) / 2), Vector3(3.2, 0.02, pz0 - pz1), path_mat)
	_box_node(Vector3(0, 0.021, -34), Vector3(px1 - px0, 0.02, 3), Mats.textured(Mats.tiles, 0.9, Color8(215, 200, 170), Vector3(24, 2, 1)))
	# Cerco de arbustos (con textura de hojas y matas que sobresalen arriba) con la entrada en el centro, y un arco con
	# el nombre. Se puede saltar encima y cruzarlo: el choque llega hasta arriba de las matas (1,05 m), así de costado
	# no se atraviesa y arriba no se hunden los pies.
	var hedges := Boxes.new()
	var segs := []
	for x in range(int(px0), int(px1) + 1, 2):
		if absf(x) > 2.5:
			segs.append([Vector3(x, 0, pz0 - 0.3), Vector3(2.05, 0.9, 0.9)])
		segs.append([Vector3(x, 0, pz1 + 0.3), Vector3(2.05, 0.9, 0.9)])
	for z in range(int(pz1), int(pz0), 2):
		for x in [px0, px1]:
			if absf(z + 34) > 2:
				segs.append([Vector3(x, 0, z + 1), Vector3(0.9, 0.9, 2.05)])
	for sg in segs:
		var p: Vector3 = sg[0]
		var size: Vector3 = sg[1]
		var shade := Color8(62, 128, 58).lerp(Color8(80, 145, 62), rng.randf())
		hedges.box(p + Vector3(0, 0.45, 0), size, shade)
		for k in 3:  # matas redondeadas encima
			var off := Vector3(rng.randf_range(-0.6, 0.6), 0, 0) if size.x > 1 else Vector3(0, 0, rng.randf_range(-0.6, 0.6))
			hedges.box(p + off + Vector3(0, 0.9 + rng.randf_range(0.0, 0.06), 0),
					Vector3(0.7, 0.14, 0.7) * Vector3(rng.randf_range(0.8, 1.2), 1, rng.randf_range(0.8, 1.2)),
					shade.lerp(Color8(110, 165, 75), 0.35))
	hedges.node(city, Mats.textured(Mats.leaves, 0.95, Color.WHITE, Vector3(2.5, 2.5, 1)))
	for x in [-2.6, 2.6]:
		props.box(Vector3(x, 1.7, pz0 - 0.3), Vector3(0.6, 3.4, 0.6), Color8(190, 180, 160))
	props.box(Vector3(0, 3.5, pz0 - 0.3), Vector3(6.4, 0.9, 0.5), Color8(60, 110, 70))
	Building.label(city, "PARQUE CENTRAL", Vector3(0, 3.5, pz0 - 0.02), 13, Color8(250, 245, 225), true, false)
	var hh := 1.05
	rects += [[px0 - 0.5, -2.2, pz0 - 0.8, pz0 + 0.2, hh], [2.2, px1 + 0.5, pz0 - 0.8, pz0 + 0.2, hh],
			[px0 - 0.5, px1 + 0.5, pz1 - 0.2, pz1 + 0.8, hh],
			[px0 - 0.5, px0 + 0.5, pz1, -36, hh], [px0 - 0.5, px0 + 0.5, -32, pz0, hh],
			[px1 - 0.5, px1 + 0.5, pz1, -36, hh], [px1 - 0.5, px1 + 0.5, -32, pz0, hh]]
	# Fuente en el cruce de senderos
	var fx := 0.0
	var fz := -34.0
	for c in [[3.2, 0.6, 0.0], [0.45, 2.2, 0.0], [1.1, 0.25, 2.1]]:
		var cyl := CylinderMesh.new()
		cyl.top_radius = c[0]
		cyl.bottom_radius = c[0]
		cyl.height = c[1]
		cyl.radial_segments = 16
		props.mesh(cyl, Transform3D(Basis.IDENTITY, Vector3(fx, c[2] + c[1] / 2, fz)), Color8(190, 185, 175))
	_disc(2.95, Vector3(fx, 0.58, fz), Mats.water)
	rects.append([fx - 3.2, fx + 3.2, fz - 3.2, fz + 3.2, 0.6])
	for k in 4:   # luces en el borde de la fuente, que la alumbran de noche
		var a := k * TAU / 4 + PI / 4
		lamps.box(Vector3(fx + cos(a) * 3.0, 0.64, fz + sin(a) * 3.0), Vector3(0.22, 0.08, 0.22), Color8(255, 225, 160))
	small_lights.append([Vector3(fx, 1.2, fz), 10.0])
	var flowers := [Color8(230, 70, 80), Color8(250, 200, 60), Color8(240, 240, 245), Color8(180, 90, 200), Color8(250, 140, 60)]
	for k in 28:
		var a := k / 28.0 * TAU
		var r := rng.randf_range(4.6, 6.2)
		if absf(cos(a)) > 0.93 or absf(sin(a)) > 0.93:
			continue  # dejar libres los senderos
		props.box(Vector3(fx + cos(a) * r, 0.18, fz + sin(a) * r), Vector3(0.35, 0.36, 0.35), flowers.pick_random())
	# Laguna con borde de piedras (al fondo, a la derecha)
	var lx := 12.0
	var lz := -48.0
	var lr := 6.0
	_disc(lr + 0.7, Vector3(lx, 0.02, lz), Mats.textured(null, 0.9, Color8(150, 145, 135)))
	_disc(lr, Vector3(lx, 0.045, lz), Mats.water)
	rects.append([lx - lr, lx + lr, lz - lr, lz + lr, 0.3])
	for k in 14:
		var a := k / 14.0 * TAU
		props.box_rot(Vector3(lx + cos(a) * (lr + 0.5), 0.15, lz + sin(a) * (lr + 0.5)), Vector3(0.7, 0.3, 0.6),
				Color8(130, 128, 122), Vector3(0, rng.randf_range(0, 90), 0))
		if k % 3 == 0:
			for j in 3:
				props.box(Vector3(lx + cos(a + j * 0.05) * (lr - 0.2), 0.6, lz + sin(a + j * 0.05) * (lr - 0.2)),
						Vector3(0.06, 1.2, 0.06), Color8(90, 130, 60))
	# Juegos (al fondo, a la izquierda): columpios y tobogán
	var sx := -14.0
	var sz := -49.0
	var red := Color8(220, 70, 60)
	for dx in [-2.2, 2.2]:
		for dz in [-0.8, 0.8]:
			props.box_rot(Vector3(sx + dx, 1.3, sz + dz * 0.6), Vector3(0.12, 2.7, 0.12), red, Vector3(dz * 14, 0, 0))
	props.box(Vector3(sx, 2.6, sz), Vector3(4.6, 0.12, 0.12), red)
	for dx in [-1, 1]:
		props.box(Vector3(sx + dx, 0.6, sz), Vector3(0.7, 0.08, 0.35), Color8(60, 90, 160))
		for k in [-0.3, 0.3]:
			props.box(Vector3(sx + dx + k, 1.6, sz), Vector3(0.03, 2.0, 0.03), Color8(90, 90, 95))
	props.box(Vector3(sx + 1, 1.0, sz + 5), Vector3(1.4, 2.0, 1.4), Color8(250, 200, 60))
	props.box_rot(Vector3(sx + 3, 0.95, sz + 5), Vector3(3.4, 0.12, 1.0), Color8(60, 160, 200), Vector3(0, 0, -38))
	rects += [[sx - 2.5, sx + 2.5, sz - 1, sz + 1, 2.6], [sx, sx + 4.6, sz + 4.2, sz + 5.8, 2]]
	# Bancas a los lados de los senderos
	for bspec in [[-2.6, -16, "z"], [2.6, -16, "z"], [-2.6, -24, "z"], [2.6, -24, "z"], [-10, -31.6, "x"],
			[10, -31.6, "x"], [-10, -36.4, "x"], [10, -36.4, "x"], [-2.6, -44, "z"], [2.6, -52, "z"]]:
		bench(bspec[0], bspec[1], bspec[2])
	_park_decor()
	# Árboles del parque, lejos de los senderos, la laguna, la fuente, los juegos y de todo lo que ya hay (bancas,
	# faroles, basureros, jardineras, el carrito de helados): antes podían quedar encima
	var taken: Array = park_spots.duplicate()
	var placed := 0
	var tries := 0
	while placed < 12 and tries < 400:
		tries += 1
		var x := rng.randf_range(px0 + 2.5, px1 - 2.5)
		var z := rng.randf_range(pz1 + 2.5, pz0 - 3.5)
		if (absf(x) < 3.8 or absf(z + 34) < 3.5 or Vector2(x - lx, z - lz).length() < lr + 3
				or Vector2(x - fx, z - fz).length() < 7.5 or Vector2(x - sx, z - sz - 2).length() < 6.5):
			continue
		var clear := true
		for t in taken:
			if Vector2(x, z).distance_to(t) < 3.2:
				clear = false
				break
		if not clear:
			continue
		taken.append(Vector2(x, z))
		tree(Vector3(x, 0, z))
		placed += 1


## Decoración del parque: farolas clásicas en los senderos (de noche alumbran), basureros junto a las bancas,
## jardineras con flores en la entrada y un carrito de helados al lado de la fuente.
func _park_decor() -> void:
	var green := Color8(35, 70, 50)
	var spots := []
	var zs := [-12.5, -20.0, -28.0, -40.0, -48.0, -56.0]
	for i in zs.size():   # sendero principal, alternando lados
		spots.append(Vector3(-2.0 if i % 2 == 0 else 2.0, 0, zs[i]))
	for x in [-17.0, -7.5, 7.5, 17.0]:                       # sendero de la fuente
		spots.append(Vector3(x, 0, -32.0 if x < 0 else -36.0))
	for p in spots:
		props.box(p + Vector3(0, 0.15, 0), Vector3(0.36, 0.3, 0.36), green)           # base
		props.box(p + Vector3(0, 1.7, 0), Vector3(0.12, 3.0, 0.12), green)            # poste
		props.box(p + Vector3(0, 3.25, 0), Vector3(0.5, 0.08, 0.5), green)            # sombrerete
		props.box(p + Vector3(0, 3.45, 0), Vector3(0.12, 0.25, 0.12), green)
		lamps.box(p + Vector3(0, 2.98, 0), Vector3(0.38, 0.46, 0.38), Color8(255, 235, 190))   # farol de vidrio
		props.box(p + Vector3(0, 2.72, 0), Vector3(0.44, 0.06, 0.44), green)
		lamp_spots.append(p + Vector3(0, 2.9, 0))
		park_spots.append(Vector2(p.x, p.z))
		rects.append([p.x - 0.2, p.x + 0.2, p.z - 0.2, p.z + 0.2, 3.4])
	# Basureros al lado de algunas bancas
	for b in [[-2.6, -18.0], [2.6, -26.0], [-10.0, -29.6], [10.0, -38.4], [-2.6, -46.0]]:
		var bp := Vector3(b[0], 0, b[1])
		park_spots.append(Vector2(bp.x, bp.z))
		props.box(bp + Vector3(0, 0.42, 0), Vector3(0.45, 0.84, 0.45), Color8(45, 95, 60))
		props.box(bp + Vector3(0, 0.86, 0), Vector3(0.5, 0.06, 0.5), Color8(30, 30, 34))
		rects.append([bp.x - 0.25, bp.x + 0.25, bp.z - 0.25, bp.z + 0.25, 0.9])
	# Jardineras con flores a los lados de la entrada
	var flowers := [Color8(230, 70, 80), Color8(250, 200, 60), Color8(240, 240, 245), Color8(180, 90, 200)]
	for sx in [-1, 1]:
		var c := Vector3(sx * 4.5, 0, -11.6)
		park_spots.append(Vector2(c.x, c.z))
		props.box(c + Vector3(0, 0.3, 0), Vector3(3.2, 0.6, 1.2), Color8(170, 160, 145))
		props.box(c + Vector3(0, 0.62, 0), Vector3(3.0, 0.06, 1.0), Color8(90, 60, 40))
		for i in 9:
			props.box(c + Vector3(-1.3 + i * 0.32, 0.78 + rng.randf_range(0, 0.08), rng.randf_range(-0.3, 0.3)),
					Vector3(0.22, 0.22, 0.22), flowers[i % flowers.size()])
		rects.append([c.x - 1.6, c.x + 1.6, c.z - 0.6, c.z + 0.6, 0.7])
	# Carrito de helados con quitasol
	var cp := Vector3(5.5, 0, -39.5)
	park_spots.append(Vector2(cp.x, cp.z))
	props.box(cp + Vector3(0, 0.75, 0), Vector3(1.6, 0.9, 0.9), Color8(245, 245, 240))
	props.box(cp + Vector3(0, 0.75, 0.46), Vector3(1.4, 0.3, 0.02), Color8(240, 120, 160))
	for wx in [-0.6, 0.6]:
		props.box(cp + Vector3(wx, 0.22, 0.45), Vector3(0.08, 0.44, 0.44), Color8(40, 40, 45))
	props.box(cp + Vector3(0, 1.9, 0), Vector3(0.06, 1.6, 0.06), Color8(200, 200, 205))
	var umbrella := CylinderMesh.new()
	umbrella.top_radius = 0.0
	umbrella.bottom_radius = 1.3
	umbrella.height = 0.5
	umbrella.radial_segments = 10
	props.mesh(umbrella, Transform3D(Basis.IDENTITY, cp + Vector3(0, 2.75, 0)), Color8(240, 120, 160))
	for i in 4:
		props.box(cp + Vector3(-0.5 + i * 0.33, 1.27, 0), Vector3(0.2, 0.14, 0.2),
				[Color8(250, 220, 120), Color8(240, 150, 170), Color8(140, 90, 60), Color8(170, 230, 190)][i])
	rects.append([cp.x - 0.85, cp.x + 0.85, cp.z - 0.5, cp.z + 0.5, 1.3])


## Banca de madera; `along` es el eje del sendero al que mira.
func bench(x: float, z: float, along: String) -> void:
	var sx := 0.6 if along == "z" else 2.2
	var sz := 2.2 if along == "z" else 0.6
	var back := Vector3(0.3 * (1 if x > 0 else -1), 0, 0) if along == "z" else Vector3(0, 0, 0.3 * (1 if z < -34 else -1))
	var wood := Color8(140, 95, 60)
	park_spots.append(Vector2(x, z))
	props.box(Vector3(x, 0.45, z), Vector3(sx, 0.1, sz), wood)
	props.box(Vector3(x, 0.8, z) + back, Vector3(0.08 if along == "z" else sx, 0.6, sz if along == "z" else 0.08), wood)
	for k in [-0.4, 0.4]:
		var leg := Vector3(0, 0, k * sz) if along == "z" else Vector3(k * sx, 0, 0)
		props.box(Vector3(x, 0.2, z) + leg, Vector3(0.08, 0.4, 0.08), Color8(50, 50, 55))
	rects.append([x - sx / 2, x + sx / 2, z - sz / 2, z + sz / 2, 0.9])


## Paseo de la Playa: terrenos frente al mar, muro, palmeras, sombrillas, muelle, veleros y faro.
func _beach() -> void:
	var coast := Terrain.COAST
	_road_to_sea()
	for x in [110, 132, 154]:  # palmeras en la vereda, entre los terrenos de la playa
		for side in [-1, 1]:
			palm(Vector3(x, 0, side * 9.6))
			rects.append([x - 0.3, x + 0.3, side * 9.6 - 0.3, side * 9.6 + 0.3, 6])
	for side in [-1, 1]:  # y detrás de los terrenos
		for x in range(112, int(coast) + 4, 7):
			var pp := Vector3(x + rng.randf_range(-2, 2), 0, side * rng.randf_range(30, 56))
			if absf(pp.x - VOLLEY.x) < 7.0 and absf(pp.z - VOLLEY.z) < 7.0:
				continue   # ahí está la cancha de vóley
			palm(pp)
	var colors := [Color8(230, 70, 70), Color8(60, 140, 220), Color8(250, 200, 60), Color8(240, 240, 240)]
	for z in [-50, -38, -31, 33, 45, 52]:
		var x := rng.randf_range(coast - 2, coast + 3)
		var y: float = max(0.0, Terrain.height(x, z))
		props.box(Vector3(x, y + 1.1, z), Vector3(0.08, 2.2, 0.08), Color8(235, 235, 235))
		var cone := CylinderMesh.new()
		cone.top_radius = 0.0
		cone.bottom_radius = 1.5
		cone.height = 0.6
		cone.radial_segments = 10
		props.mesh(cone, Transform3D(Basis.IDENTITY, Vector3(x, y + 2.4, z)), colors.pick_random())
		props.box(Vector3(x + 1.2, y + 0.06, z), Vector3(1.8, 0.06, 0.8), colors.pick_random())
	for x in range(int(coast), int(coast) + 44, 3):  # muelle de madera
		props.box(Vector3(x + 1.5, 0.35, 24), Vector3(3, 0.14, 2.6), Color8(150, 110, 70))
		for dz in [-1.2, 1.2]:
			props.box(Vector3(x, -1.5, 24 + dz), Vector3(0.25, 4, 0.25), Color8(110, 80, 55))
	for i in 5:   # faroles del muelle, alternando lados
		var px: float = coast + 4 + i * 9
		var pz := 24.0 + (1.2 if i % 2 == 0 else -1.2)
		props.box(Vector3(px, 1.6, pz), Vector3(0.1, 2.5, 0.1), Color8(40, 40, 44))
		props.box(Vector3(px, 2.9, pz), Vector3(0.34, 0.06, 0.34), Color8(40, 40, 44))
		lamps.box(Vector3(px, 2.7, pz), Vector3(0.28, 0.34, 0.28), Color8(255, 225, 160))
		small_lights.append([Vector3(px, 2.6, pz), 12.0])
	for i in 5:  # veleros que se mecen
		var b := Boxes.new()
		b.box(Vector3(0, 0.3, 0), Vector3(1.6, 0.7, 5), Color8(245, 245, 245))
		b.box(Vector3(0, 3.2, 0), Vector3(0.12, 5.4, 0.12), Color8(120, 100, 80))
		var sail := PrismMesh.new()
		sail.size = Vector3(2.6, 4.4, 0.06)
		sail.left_to_right = 0.0
		b.mesh(sail, Transform3D(Basis(Vector3.UP, PI / 2), Vector3(0, 3.0, 0.9)), colors.pick_random())
		var boat := b.node(city, Mats.smooth)
		boat.position = Vector3(rng.randf_range(coast + 60, coast + 200), Terrain.SEA_LEVEL, rng.randf_range(-120, 120))
		boat.rotation.y = rng.randf_range(0, TAU)
		boat.set_meta("phase", rng.randf_range(0, 6))
		boats.append(boat)
	var hx := coast + 28
	var hz := 78.0
	var hy: float = max(0.0, Terrain.height(hx, hz))
	for k in 6:  # faro en el cerro de la costa norte
		var cyl := CylinderMesh.new()
		cyl.top_radius = 1.6 - (k + 1) * 0.12
		cyl.bottom_radius = 1.6 - k * 0.12
		cyl.height = 1.6
		cyl.radial_segments = 14
		props.mesh(cyl, Transform3D(Basis.IDENTITY, Vector3(hx, hy + k * 1.6 + 0.8, hz)),
				Color8(240, 240, 240) if k % 2 == 0 else Color8(210, 60, 55))
	var top := CylinderMesh.new()
	top.top_radius = 1.5
	top.bottom_radius = 1.5
	top.height = 0.3
	props.mesh(top, Transform3D(Basis.IDENTITY, Vector3(hx, hy + 10.35, hz)), Color8(40, 42, 48))
	var sphere := SphereMesh.new()
	sphere.radius = 0.75
	sphere.height = 1.5
	beacon = _mesh_node(sphere, Mats.emissive, Vector3(hx, hy + 11.2, hz))
	small_lights.append([Vector3(hx, hy + 11.2, hz), 15.0])
	beacon.material_override = Mats.textured(null, 0.3, Color8(255, 235, 160))
	beacon.material_override.set_shader_parameter("emission", Color8(255, 220, 140))
	beacon.material_override.set_shader_parameter("emission_energy", 0.3)


## Palmera: tronco curvo de segmentos y hojas largas inclinadas.
func palm(pos: Vector3) -> void:
	var y0: float = max(0.0, Terrain.height(pos.x, pos.z))
	var lean := rng.randf_range(0.15, 0.3)
	var top := Vector3(pos.x, y0, pos.z)
	for k in 7:
		top = Vector3(pos.x + lean * k * k * 0.12, y0 + 0.4 + k * 0.85, pos.z)
		props.box_rot(top, Vector3(0.32 - k * 0.02, 0.9, 0.32 - k * 0.02), Color8(140, 110, 75), Vector3(0, 0, -lean * k * 6))
	for k in 7:
		var a := deg_to_rad(k / 7.0 * 360 + rng.randf_range(-10, 10))
		var basis := Basis(Vector3.UP, a) * Basis(Vector3.RIGHT, deg_to_rad(22))
		var center := top + Vector3(0, 0.45, 0) + Basis(Vector3.UP, a) * Vector3(0, -0.35, 1.3)
		props.box(Vector3.ZERO, Vector3(0.5, 0.06, 2.8), Color8(60, 140, 60) if k % 2 else Color8(80, 160, 70),
				Transform3D(basis, center))
