class_name Thumbs
extends Node
## Fotos de las prendas del armario: un maniquí con tu aspecto y esa prenda puesta, fotografiado en un estudio
## aparte (SubViewport con su propio mundo, luz y cámara). Se saca una foto por cuadro y se guardan.
## También las de la ventana de decorar: el mismo local, con ese artículo puesto, desde donde mejor se ve.

const SIZE := 192
# Encuadres: [punto que mira la cámara, posición de la cámara], relativos al maniquí (que mira hacia +z).
const FRAMES := {
	"cabeza": [Vector3(0, 1.98, 0), Vector3(0.75, 2.2, 1.55)],
	"busto": [Vector3(0, 1.7, 0), Vector3(0.7, 1.9, 3.0)],   # de la cintura para arriba (el mentor del tutorial)
	"cuello": [Vector3(0, 1.62, 0), Vector3(0.7, 1.85, 1.75)],
	"torso": [Vector3(0, 1.32, 0), Vector3(1.05, 1.65, 2.6)],
	"espalda": [Vector3(0, 1.35, 0), Vector3(-1.1, 1.7, -2.5)],
	"mano": [Vector3(-0.4, 1.0, 0.05), Vector3(-1.35, 1.3, 1.25)],
	"piernas": [Vector3(0, 0.55, 0), Vector3(0.95, 0.95, 2.75)],
}
const ITEM_FRAME := {"hair_style": "cabeza", "hat": "cabeza", "jacket": "torso", "pants_style": "piernas", "tie": "cuello",
		"glasses": "cabeza", "beard": "cabeza", "watch": "mano", "headphones": "cabeza", "backpack": "espalda",
		"scarf": "cuello"}

var cache := {}
var queue := []
var pending = null      # [clave, cuadros que faltan para leer la foto]
var vp: SubViewport
var cam: Camera3D
var model: Person
var shop_decor: Node3D = null   # el artículo de decoración que se está fotografiando


func _ready() -> void:
	vp = SubViewport.new()
	vp.size = Vector2i(SIZE, SIZE)
	vp.own_world_3d = true
	vp.transparent_bg = false
	vp.render_target_update_mode = SubViewport.UPDATE_DISABLED
	vp.msaa_3d = Viewport.MSAA_4X
	add_child(vp)
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color(0.17, 0.2, 0.26)
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.6, 0.62, 0.7)
	env.ambient_light_energy = 0.8
	env.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	var we := WorldEnvironment.new()
	we.environment = env
	vp.add_child(we)
	var light := DirectionalLight3D.new()
	light.rotation_degrees = Vector3(-40, 35, 0)
	light.light_energy = 1.1
	vp.add_child(light)
	model = Person.new(null, null, false, Wardrobe.DEFAULT_LOOK)
	vp.add_child(model)
	cam = Camera3D.new()
	cam.fov = 30
	vp.add_child(cam)


## La foto de `look` con ese encuadre, o null si todavía se está sacando (se pone en la fila).
func get_thumb(look: Dictionary, frame: String):
	var k := JSON.stringify(look, "", true) + frame
	if cache.has(k):
		return cache[k]
	var queued := false
	for q in queue:
		if q[0] == k:
			queued = true
	if not queued and (pending == null or pending[0] != k):
		queue.append([k, look.duplicate(), frame])
	return null


## La foto del local `loc` con el artículo `key` puesto, o null si todavía se está sacando.
func get_decor_thumb(loc: Dictionary, variant: int, key: String):
	var k := "decor:%d:%d:%s:%s" % [int(loc.id), int(loc.size), loc.product, key]
	if cache.has(k):
		return cache[k]
	var queued := false
	for q in queue:
		if q[0] == k:
			queued = true
	if not queued and (pending == null or pending[0] != k):
		queue.append([k, {"size": int(loc.size), "product": loc.product, "variant": variant, "key": key}, "decor"])
	return null


## La foto de un artículo de la oficina, o null si todavía se está sacando.
func get_office_thumb(tier: int, key: String):
	var k := "office:%d:%s" % [tier, key]
	if cache.has(k):
		return cache[k]
	var queued := false
	for q in queue:
		if q[0] == k:
			queued = true
	if not queued and (pending == null or pending[0] != k):
		queue.append([k, {"office": tier, "key": key}, "decor"])
	return null


## Pone en el estudio solo el artículo (sin el local), y para el letrero luminoso también el letrero que rodea.
## Devuelve [centro, radio] de lo que hay que encuadrar.
func _stage_shop(spec: Dictionary) -> Array:
	if shop_decor != null:
		shop_decor.free()
	shop_decor = Node3D.new()
	vp.add_child(shop_decor)
	var kind: int = spec.get("size", 0)
	if spec.has("office"):   # lo de la oficina: solo el artículo (el neón con su letrero detrás)
		if spec.key == "neon":
			var nb := Boxes.new()
			nb.box(Vector3(0, OfficeDecor.height(spec.office) + 2.4, 2.6), Vector3(11, 2.2, 0.3), Color8(60, 64, 80))
			nb.node(shop_decor, Mats.standard)
		OfficeDecor.build(shop_decor, spec.office, [spec.key], false)
	elif spec.key == "letrero":   # el letrero de la tienda, para que se vea el neón alrededor
		var sw: float = [3.6, 8.0, 12.0][kind]
		var sh: float = [0.8, 1.2, 1.8][kind]
		var sy: float = 3.5 if kind == 0 else [2.8, 4.5, 7.0][kind] + 0.3 + sh / 2
		var sz: float = 2.38 if kind == 0 else 1.78
		var b := Boxes.new()
		b.box(Vector3(0, sy, sz + 0.1), Vector3(sw, sh, 0.15), Blueprints.PRODUCT_COLORS[spec.product].darkened(0.3))
		b.node(shop_decor, Mats.standard)
		Building.label(shop_decor, D.PRODUCTS[spec.product].name.to_upper(), Vector3(0, sy, sz - 0.01), sh * 20.0, Color.WHITE)
	if not spec.has("office"):
		Store.build_decor(shop_decor, kind, spec.product, [spec.key], false)
	# Qué encuadrar: si el artículo va a los dos lados de la puerta, solo uno (se ve más grande)
	var pts := PackedVector3Array()
	for n in shop_decor.get_children():
		if n is MeshInstance3D and n.mesh != null:
			for i in n.mesh.get_surface_count():
				pts.append_array(n.mesh.surface_get_arrays(i)[Mesh.ARRAY_VERTEX])
	if spec.key == "reflectores" and spec.has("office"):   # uno solo, de cerca
		var one := PackedVector3Array()
		for v in pts:
			if v.x > 5.5:
				one.append(v)
		if not one.is_empty():
			pts = one
	elif spec.key in ["plantas", "pantallas", "autopago", "terraza"]:
		var right := PackedVector3Array()
		for v in pts:
			if v.x > 0.05:
				right.append(v)
		if not right.is_empty():
			pts = right
	elif spec.key == "aire":   # el equipo del techo
		var top := PackedVector3Array()
		for v in pts:
			if v.y > 2.5 and v.z > 3.0:
				top.append(v)
		if not top.is_empty():
			pts = top
	if pts.is_empty():
		return [Vector3(0, 1.5, 0), 2.0]
	var lo := pts[0]
	var hi := pts[0]
	for v in pts:
		lo = lo.min(v)
		hi = hi.max(v)
	return [(lo + hi) / 2, maxf(0.4, (hi - lo).length() / 2)]


## Llamar una vez por cuadro mientras el armario está abierto.
func step() -> void:
	if pending != null:
		if pending[1] > 0:
			pending[1] -= 1
			return
		var img := vp.get_texture().get_image()
		cache[pending[0]] = ImageTexture.create_from_image(img)
		pending = null
	if queue.is_empty():
		return
	var item: Array = queue.pop_front()
	if item[2] == "decor":
		model.visible = false
		var fit := _stage_shop(item[1])
		shop_decor.visible = true
		cam.fov = 35
		var dir := Vector3(0.55, 0.45, -1.0).normalized()   # de frente (desde la calle), un poco de lado y de arriba
		cam.position = fit[0] + dir * (fit[1] / tan(deg_to_rad(cam.fov / 2)) * 1.05)
		cam.look_at(fit[0])
	else:
		model.visible = true
		if shop_decor != null:
			shop_decor.visible = false
		model.restyle(item[1])
		var f: Array = FRAMES[item[2]]
		cam.fov = 30
		cam.position = f[1]
		cam.look_at(f[0])
	vp.render_target_update_mode = SubViewport.UPDATE_ONCE
	pending = [item[0], 1]  # esperar a que se dibuje antes de leer la imagen
