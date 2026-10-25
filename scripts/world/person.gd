class_name Person
extends Node3D
## Persona hecha de cajas (como en la versión de Python). Mira hacia +z. Las piernas y los brazos giran desde la
## cadera y el hombro para caminar; la ropa del armario se arma con restyle().

const SKINS := [Color8(240, 200, 165), Color8(215, 165, 120), Color8(170, 115, 75), Color8(115, 75, 50)]
const HAIRS := [Color8(30, 25, 20), Color8(90, 60, 35), Color8(200, 160, 80), Color8(60, 60, 60), Color8(140, 50, 30)]
const SHIRTS := [Color8(70, 120, 200), Color8(200, 80, 80), Color8(80, 160, 100), Color8(230, 190, 70),
		Color8(150, 100, 190), Color8(240, 240, 240), Color8(60, 60, 70), Color8(230, 130, 60)]
const PANTS := [Color8(50, 60, 90), Color8(40, 40, 45), Color8(90, 80, 70), Color8(60, 80, 60)]

var legs: Array[Node3D] = []
var arms: Array[Node3D] = []
var body: MeshInstance3D
var limb_meshes: Array[MeshInstance3D] = []
var phase := 0.0
var shirt: Color
var pants: Color
var skin: Color
var hair: Color
var apron := false
var look = null
var item: MeshInstance3D   # lo que lleva en la mano derecha (null = nada)
var serve_t := 0.0         # > 0 mientras atiende a un cliente


func _init(shirt_color = null, pants_color = null, with_apron := false, person_look = null) -> void:
	shirt = shirt_color if shirt_color != null else SHIRTS.pick_random()
	pants = pants_color if pants_color != null else PANTS.pick_random()
	skin = SKINS.pick_random()
	hair = HAIRS.pick_random()
	apron = with_apron
	for side in [-1, 1]:
		# Pivote arriba: la pierna gira desde la cadera y el brazo desde el hombro.
		var leg := Node3D.new()
		leg.position = Vector3(0.13 * side, 0.9, 0)
		add_child(leg)
		legs.append(leg)
		var arm := Node3D.new()
		arm.position = Vector3(0.37 * side, 1.55, 0)
		add_child(arm)
		arms.append(arm)
	for pivot in legs + arms:
		var mi := MeshInstance3D.new()
		mi.material_override = Mats.smooth
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF  # piernas y brazos: la sombra del cuerpo basta
		pivot.add_child(mi)
		limb_meshes.append(mi)
	body = MeshInstance3D.new()
	body.material_override = Mats.smooth
	add_child(body)
	restyle(person_look)


static func lighten(c: Color, k: float) -> Color:
	return c.lerp(Color.WHITE, k) if k > 0 else c.lerp(Color.BLACK, -k)


static func col(v) -> Color:
	return v if v is Color else Color8(int(v[0]), int(v[1]), int(v[2]))


## Aplica el aspecto comprado en el armario. Sin `new_look` es una persona común (cliente o empleado).
func restyle(new_look = null) -> void:
	look = new_look
	var L := {}
	if look != null:
		L = Wardrobe.full_look(look)
		shirt = col(L.shirt)
		pants = col(L.pants)
		skin = col(L.skin)
		hair = col(L.hair)
	var jacket: String = L.get("jacket", "ninguna")
	var jcol := Color8(30, 26, 26) if jacket == "cuero" else (col(L.jacket_color) if look != null else shirt)
	var b := Boxes.new()
	var limbs := [Boxes.new(), Boxes.new(), Boxes.new(), Boxes.new()]  # pierna izq, der, brazo izq, der

	# Cuerpo base: torso, cabeza y ojos
	b.box(Vector3(0, 1.27, 0), Vector3(0.56, 0.76, 0.32), jcol if jacket == "sudadera" else shirt)  # llega al cuello
	b.box(Vector3(0, 1.86, 0), Vector3(0.4, 0.42, 0.4), skin)
	b.box(Vector3(0, 1.9, 0.205), Vector3(0.26, 0.07, 0.02), Color8(30, 30, 35))
	if apron:
		b.box(Vector3(0, 1.1, 0.17), Vector3(0.46, 0.8, 0.03), Blueprints.PALETTE.white)
	# Extremidades: en coordenadas del pivote (y de 0 arriba a −largo abajo)
	for i in 2:
		limbs[i].box(Vector3(0, -0.45, 0), Vector3(0.22, 0.9, 0.24), pants)
		limbs[2 + i].box(Vector3(0, -0.34, 0), Vector3(0.16, 0.68, 0.18), shirt if jacket == "ninguna" else jcol)

	if look == null:
		b.box(Vector3(0, 2.1, -0.03), Vector3(0.43, 0.12, 0.45), hair)
		for i in 2:
			limbs[i].box(Vector3(0, -0.87, 0.04), Vector3(0.25, 0.08, 0.34), Color8(30, 30, 35))
		_apply(b, limbs)
		return

	# Las piezas pegadas a una extremidad usan sus coordenadas: x, z de −0,5 a 0,5 y y de 0 a −1 (escala de la pieza).
	var leg_size := Vector3(0.22, 0.9, 0.24)
	var arm_size := Vector3(0.16, 0.68, 0.18)
	var limb := func(i: int, pos: Vector3, scale: Vector3, c: Color) -> void:
		var size := leg_size if i < 2 else arm_size
		limbs[i].box(pos * size, scale * size, c)

	# ---- pantalón con relieve y zapatos ----
	var dark := lighten(pants, -0.28)
	var style: String = L.pants_style
	for i in 2:
		var out := -1 if i == 0 else 1
		if style == "cortos":
			limb.call(i, Vector3(0, -0.79, 0), Vector3(1.02, 0.44, 1.02), skin)
			limb.call(i, Vector3(0, -0.56, 0), Vector3(1.1, 0.06, 1.1), dark)
		else:
			limb.call(i, Vector3(0, -0.91, 0), Vector3(1.12, 0.1, 1.12), dark if style == "jeans" else lighten(pants, -0.12))
		if style in ["jeans", "cortos"]:
			limb.call(i, Vector3(0, -0.13, 0.51), Vector3(0.64, 0.15, 0.05), dark)
			limb.call(i, Vector3(0, -0.15, -0.51), Vector3(0.62, 0.17, 0.05), dark)
			limb.call(i, Vector3(0.51 * out, -0.45, 0), Vector3(0.04, 0.85, 0.14), Color8(205, 150, 80))
		if style == "jeans":
			limb.call(i, Vector3(0, -0.52, 0.51), Vector3(0.72, 0.035, 0.04), dark)
		elif style == "vestir":
			limb.call(i, Vector3(0, -0.48, 0.51), Vector3(0.05, 0.86, 0.03), lighten(pants, 0.14))
		limb.call(i, Vector3(0, -0.965, 0.2), Vector3(1.16, 0.09, 1.5), col(L.shoes))
	b.box(Vector3(0, 0.93, 0), Vector3(0.58, 0.08, 0.34), Color8(60, 40, 25))
	b.box(Vector3(0, 0.93, 0.172), Vector3(0.1, 0.07, 0.02), Blueprints.PALETTE.gold)

	# ---- chaquetas ----
	if jacket == "sudadera":
		b.box(Vector3(0, 1.86, -0.25), Vector3(0.46, 0.36, 0.12), lighten(jcol, -0.1))
		b.box(Vector3(0, 1.05, 0.166), Vector3(0.38, 0.17, 0.02), lighten(jcol, -0.15))
		for sx in [-0.07, 0.07]:
			b.box(Vector3(sx, 1.45, 0.168), Vector3(0.025, 0.2, 0.02), Color8(240, 240, 240))
	elif jacket in ["blazer", "cuero"]:
		for sx in [-1, 1]:
			b.box(Vector3(0.185 * sx, 1.27, 0.168), Vector3(0.2, 0.77, 0.02), jcol)
			b.box(Vector3(0.287 * sx, 1.27, 0), Vector3(0.02, 0.77, 0.34), jcol)
			b.box(Vector3(0.1 * sx, 1.5, 0.176), Vector3(0.06, 0.26, 0.02), lighten(jcol, -0.22))
		b.box(Vector3(0, 1.27, -0.168), Vector3(0.58, 0.77, 0.02), jcol)
		for i in [2, 3]:
			limb.call(i, Vector3(0, -0.94, 0), Vector3(1.1, 0.1, 1.1), shirt)
		if jacket == "cuero":
			b.box(Vector3(0.08, 1.25, 0.178), Vector3(0.02, 0.6, 0.01), Color8(190, 190, 195))

	# ---- pelo ----
	var hs: String = L.hair_style
	if hs in ["corto", "largo"]:
		b.box(Vector3(0, 2.1, -0.03), Vector3(0.43, 0.12, 0.45), hair)
	if hs == "largo":
		b.box(Vector3(0, 1.8, -0.2), Vector3(0.44, 0.62, 0.08), hair)
		for sx in [-0.21, 0.21]:
			b.box(Vector3(sx, 1.92, -0.04), Vector3(0.04, 0.36, 0.34), hair)
	elif hs == "cresta":
		b.box(Vector3(0, 2.18, -0.02), Vector3(0.11, 0.24, 0.44), hair)

	# ---- sombreros ----
	var hat: String = L.hat
	var gold: Color = Blueprints.PALETTE.gold
	if hat == "gorra":
		b.box(Vector3(0, 2.15, -0.02), Vector3(0.45, 0.13, 0.45), lighten(shirt, -0.25))
		b.box(Vector3(0, 2.11, 0.3), Vector3(0.4, 0.04, 0.24), lighten(shirt, -0.25))
	elif hat == "lana":
		b.box(Vector3(0, 2.13, -0.02), Vector3(0.46, 0.2, 0.46), Color8(200, 60, 60))
		b.box(Vector3(0, 2.04, -0.02), Vector3(0.47, 0.06, 0.47), Color8(165, 45, 45))
		b.box(Vector3(0, 2.29, -0.02), Vector3(0.13, 0.11, 0.13), Color8(245, 245, 245))
	elif hat == "vaquero":
		b.box(Vector3(0, 2.1, 0), Vector3(0.82, 0.04, 0.72), Color8(140, 95, 55))
		b.box(Vector3(0, 2.27, 0), Vector3(0.42, 0.3, 0.4), Color8(140, 95, 55))
		b.box(Vector3(0, 2.15, 0), Vector3(0.43, 0.06, 0.41), Color8(60, 40, 25))
	elif hat == "copa":
		b.box(Vector3(0, 2.09, 0), Vector3(0.62, 0.04, 0.62), Color8(25, 25, 30))
		b.box(Vector3(0, 2.37, 0), Vector3(0.38, 0.52, 0.38), Color8(25, 25, 30))
		b.box(Vector3(0, 2.16, 0), Vector3(0.39, 0.08, 0.39), gold)
	elif hat == "corona":
		b.box(Vector3(0, 2.17, 0), Vector3(0.46, 0.14, 0.46), gold)
		for sx in [-0.19, 0.19]:
			for sz in [-0.19, 0.19]:
				b.box(Vector3(sx, 2.31, sz), Vector3(0.08, 0.14, 0.08), gold)
		b.box(Vector3(0, 2.32, 0.21), Vector3(0.08, 0.16, 0.04), gold)
		b.box(Vector3(0, 2.17, 0.235), Vector3(0.09, 0.08, 0.02), Color8(200, 30, 50))

	# ---- accesorios ----
	if L.tie:
		b.box(Vector3(0, 1.3, 0.172), Vector3(0.08, 0.5, 0.02), Color8(170, 30, 40))
		b.box(Vector3(0, 1.57, 0.173), Vector3(0.13, 0.08, 0.03), Color8(170, 30, 40))
	if L.glasses:
		b.box(Vector3(0, 1.9, 0.212), Vector3(0.38, 0.11, 0.02), Color8(12, 12, 15))
	if L.beard:
		b.box(Vector3(0, 1.7, 0.17), Vector3(0.41, 0.18, 0.08), hair)
	if L.watch:
		limb.call(2, Vector3(0, -0.82, 0), Vector3(1.22, 0.12, 1.22), gold)
	if L.chain:
		for sx in [-1, 1]:
			b.box_rot(Vector3(0.075 * sx, 1.5, 0.185), Vector3(0.2, 0.035, 0.02), gold, Vector3(0, 0, -35 * sx))
		b.box(Vector3(0, 1.42, 0.188), Vector3(0.07, 0.07, 0.02), gold)
	if L.backpack:
		b.box(Vector3(0, 1.25, -0.27), Vector3(0.46, 0.56, 0.2), Color8(60, 90, 140))
		b.box(Vector3(0, 1.1, -0.38), Vector3(0.34, 0.2, 0.04), Color8(50, 75, 120))
		for sx in [-0.16, 0.16]:
			b.box(Vector3(sx, 1.38, 0.18), Vector3(0.06, 0.42, 0.02), Color8(40, 60, 100))
	if L.scarf:
		b.box(Vector3(0, 1.64, 0), Vector3(0.48, 0.12, 0.4), Color8(200, 60, 60))
		b.box(Vector3(0.1, 1.43, 0.215), Vector3(0.12, 0.34, 0.04), Color8(200, 60, 60))
	_apply(b, limbs)


func _apply(b: Boxes, limbs: Array) -> void:
	body.mesh = b.build()
	for i in 4:
		limb_meshes[i].mesh = limbs[i].build()


## speed > 0 camina (más rápido = pasos más largos); 0 se queda quieto.
func animate(speed: float, dt: float) -> void:
	var a: float
	if speed > 0.1:
		phase += dt * (3.0 + speed * 1.6)
		a = sin(phase) * min(40.0, 14.0 + speed * 5.0)
	else:
		phase = 0.0
		a = rad_to_deg(legs[0].rotation.x) * 0.8
	legs[0].rotation.x = deg_to_rad(a)
	legs[1].rotation.x = deg_to_rad(-a)
	arms[0].rotation.x = deg_to_rad(-a * 0.8)
	arms[1].rotation.x = deg_to_rad(a * 0.8)
	if item:  # con algo en la mano, el brazo va doblado hacia adelante
		set_reach(0.45)


## Pone `key` (un producto de Actors.product_item) en la mano derecha, o la deja vacía con "". Sin `variant`
## elige uno de los modelos al azar.
func hold(key: String, variant := -1) -> void:
	if key == "":
		if item:
			item.queue_free()
			item = null
		return
	if item == null:
		item = MeshInstance3D.new()
		item.material_override = Mats.smooth
		item.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		item.position = Vector3(0, -0.72, 0.06)
		item.scale = Vector3.ONE * 1.6  # un poco más grande que en la vida real, para que se note
		arms[1].add_child(item)
	item.mesh = Actors.product_item(key, variant if variant >= 0 else randi() % Actors.variants(key))


## Brazo derecho estirado hacia adelante: 0 colgando, 1 casi horizontal. Lo que lleva en la mano queda derecho.
func set_reach(amount: float) -> void:
	arms[1].rotation.x = deg_to_rad(-80.0 * amount)
	if item:
		item.rotation.x = -arms[1].rotation.x


func set_visible_parts(v: bool) -> void:
	for c in get_children():
		if c is Node3D:
			c.visible = v
