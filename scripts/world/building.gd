class_name Building
extends RefCounted
## Arma un edificio a partir de su plano: una malla para las paredes y muebles, otra para los vidrios
## (que reflejan) y los letreros como textos 3D nítidos.

static var title_font: SystemFont
static var body_font: SystemFont

var root: Node3D
var rects := []          # [x0, x1, z0, z1, alto] en el mundo: chocan con el jugador y con la cámara
var spots := {}          # lugares en coordenadas del mundo (fila, mostrador, etc.)
var glow: MeshInstance3D # vidrios que se iluminan de noche
var brand := []          # letreros que dicen el nombre de la empresa (ver set_brand)
var local := {}          # lugares del plano en coordenadas del local (repisas, cajas, reponedor)
var blueprint_boxes := []  # las cajas del plano (coordenadas del local): con ellas se arma el camino de los empleados


static func fonts() -> void:
	if title_font:
		return
	title_font = SystemFont.new()
	title_font.font_names = PackedStringArray(["Segoe UI", "Arial"])
	title_font.font_weight = 700
	body_font = SystemFont.new()
	body_font.font_names = PackedStringArray(["Segoe UI", "Arial"])


## Texto 3D. `ursina_scale` es la escala que tenía en la versión de Python. Por defecto mira hacia la calle (−z local).
static func label(parent: Node, text: String, pos: Vector3, ursina_scale: float, color: Color, bold := true,
		face_street := true) -> Label3D:
	fonts()
	var l := Label3D.new()
	l.text = Lang.t(text)
	l.set_meta("src", text)   # para volver a traducirlo si cambias el idioma (Lang.use)
	l.add_to_group("i18n")
	l.font = title_font if bold else body_font
	l.font_size = 64
	l.outline_size = 0
	l.pixel_size = ursina_scale * 0.0118 / 64.0 * 2.2
	l.modulate = color
	l.position = pos
	l.shaded = false
	l.double_sided = false
	l.alpha_cut = Label3D.ALPHA_CUT_DISABLED
	if face_street:
		l.rotation.y = PI
	parent.add_child(l)
	return l


func _init(parent: Node, plot: Array, kind, product_color: Color, sign_label: String, title := "",
		label_scale := 0.0, variant := -1, product := "") -> void:
	var bp := Blueprints.blueprint(kind, variant, product)
	var boxes: Array = bp[0]
	var local_spots: Dictionary = bp[1]
	local = local_spots
	blueprint_boxes = boxes
	var side: float = plot[1]
	root = Node3D.new()
	root.position = Vector3(plot[0], 0, side * Blueprints.FRONT)
	root.rotation.y = 0.0 if side == 1 else PI
	parent.add_child(root)
	var parts := Boxes.new()
	var glass := Boxes.new()
	var glass_glow := Boxes.new()
	var lamps := Boxes.new()
	for b in boxes:
		var key = b[2]
		var col: Color = key if key is Color else (product_color if key == "product" else Blueprints.PALETTE[key])
		var target := parts
		if key is Color:
			pass
		elif key == "glass":
			target = glass
		elif key == "hq_glass":
			target = glass_glow
		elif key == "lamp":
			target = lamps
		target.box(b[0], b[1], col)
		if b[3]:
			var c: Vector3 = b[0]
			var s: Vector3 = b[1]
			var a := Blueprints.to_world(plot, c.x - s.x / 2, c.z - s.z / 2)
			var e := Blueprints.to_world(plot, c.x + s.x / 2, c.z + s.z / 2)
			var top: float = b[3] if b[3] is float else c.y + s.y / 2
			rects.append([min(a.x, e.x), max(a.x, e.x), min(a.z, e.z), max(a.z, e.z), top])
	parts.node(root, Mats.standard)
	if not glass.is_empty():
		glass.node(root, Mats.shop_glass, false)
	if not glass_glow.is_empty():
		glow = glass_glow.node(root, Mats.glass_glow, false)
	if not lamps.is_empty():
		lamps.node(root, Mats.emissive, false)
	if local_spots.has("sign"):
		var sg: Array = local_spots.sign
		var size: float = label_scale if label_scale > 0 else sg[1]
		var p: Vector3 = sg[0]
		label(root, sign_label, p + Vector3(0, 0.18 if title else 0.0, 0), size, Color.WHITE)
		if title:
			label(root, title, p + Vector3(0, -0.32 * size / 26.0, 0), size * 0.55, Color.WHITE, false)
	# Luz cálida adentro, que de noche sale por la puerta y las vitrinas: [x, y, z, radio] locales
	for l in local_spots.get("lights", []):
		Mats.add_light(root, Vector3(l[0], l[1], l[2]), 11.0)
	if local_spots.has("indoor_lights") and not local_spots.has("lights"):
		Mats.add_light(root, Vector3(0, 2.8, 1.2), 11.0)   # la luz de adentro que sale por la puerta a la vereda
	# Luz de los paneles del techo: adentro siempre está prendida, de día y de noche
	for l in local_spots.get("indoor_lights", []):
		Mats.add_light(root, Vector3(l[0], l[1], l[2]), 15.0, true)
	for t in local_spots.get("texts", []):
		var l := label(root, t[1], t[0], t[2], Blueprints.PALETTE[t[3]])
		if t[1] == "CAPITAL":
			l.set_meta("size", l.pixel_size)
			brand.append(l)
	for k in local_spots:
		var v = local_spots[k]
		if k in ["sign", "texts", "screen", "lights", "indoor_lights", "pick_faces", "shelf_rows", "levels", "registers",
				"stall_slots", "restock"]:
			continue
		if k == "ceiling":  # [x0, x1, z0, z1, altura] en el mundo
			var a := Blueprints.to_world(plot, v[0], v[2])
			var e := Blueprints.to_world(plot, v[1], v[3])
			spots[k] = [min(a.x, e.x), max(a.x, e.x), min(a.z, e.z), max(a.z, e.z), v[4]]
		elif k == "chairs":  # sillas de los clientes: dónde se sientan, la mesa que miran y por dónde llegan
			spots[k] = v.map(func(c): return {"seat": Blueprints.to_world(plot, c[0], c[1]),
					"table": Blueprints.to_world(plot, c[2], c[3]), "near": Blueprints.to_world(plot, c[4], c[5])})
		elif k == "lines":
			var lines := []
			for ln in v:
				lines.append({"slots": ln.slots.map(func(s): return Blueprints.to_world(plot, s[0], s[1])),
						"exit": ln.exit.map(func(s): return Blueprints.to_world(plot, s[0], s[1])), "members": []})
			spots[k] = lines
		elif v == null:
			spots[k] = null
		elif v is Array and v.size() > 0 and v[0] is Array:
			spots[k] = v.map(func(s): return Blueprints.to_world(plot, s[0], s[1]))
		elif v is Array and v.is_empty():
			spots[k] = []
		elif v is Array:
			spots[k] = Blueprints.to_world(plot, v[0], v[1])
	# Hacia dónde mira el personal (de frente a la calle)
	spots["face_yaw"] = PI if side == 1 else 0.0
	spots["local_screen"] = local_spots.get("screen")
	spots["pick_faces"] = local_spots.get("pick_faces", [])


## Cambia el nombre de la empresa en los letreros (los nombres largos se achican para que quepan).
static func set_brand_text(l: Label3D, name: String) -> void:
	l.text = Lang.t(name).to_upper()
	l.pixel_size = float(l.get_meta("size", l.pixel_size)) * minf(1.0, 9.0 / max(1, name.length()))


func set_brand(name: String) -> void:
	for l in brand:
		set_brand_text(l, name)


func destroy() -> void:
	if is_instance_valid(root):
		root.queue_free()
