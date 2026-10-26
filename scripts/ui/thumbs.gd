class_name Thumbs
extends Node
## Fotos de las prendas del armario: un maniquí con tu aspecto y esa prenda puesta, fotografiado en un estudio
## aparte (SubViewport con su propio mundo, luz y cámara). Se saca una foto por cuadro y se guardan.

const SIZE := 192
# Encuadres: [punto que mira la cámara, posición de la cámara], relativos al maniquí (que mira hacia +z).
const FRAMES := {
	"cabeza": [Vector3(0, 1.98, 0), Vector3(0.75, 2.2, 1.55)],
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
	model.restyle(item[1])
	var f: Array = FRAMES[item[2]]
	cam.position = f[1]
	cam.look_at(f[0])
	vp.render_target_update_mode = SubViewport.UPDATE_ONCE
	pending = [item[0], 1]  # esperar a que se dibuje antes de leer la imagen
