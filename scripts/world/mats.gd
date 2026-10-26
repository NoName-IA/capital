class_name Mats
extends RefCounted
## Materiales compartidos de la ciudad. Todos usan el color de los vértices, así una sola malla tiene muchos colores.

static var world_shader: Shader             # shaders/world.gdshader: color, textura y la luz de las lámparas
static var standard: ShaderMaterial
static var smooth: ShaderMaterial          # sin textura (personas, autos)
static var glass: ShaderMaterial          # vidrios: reflejan el cielo y la ciudad
static var glass_glow: ShaderMaterial     # vidrios de oficinas: de noche se prenden las ventanas
static var windows: ShaderMaterial        # ventanas de las casas
static var shop_glass: ShaderMaterial     # vitrinas de locales y puestos: de noche brillan cálidas
static var emissive: StandardMaterial3D   # rojo de la competencia, faroles: igual de día y de noche
static var water: ShaderMaterial
static var lights := []                  # luces de la ciudad: [nodo, nivel, adentro, se mueve] (ver CityLights)
static var lamps_on := 0.0               # faroles y focos de afuera: 0 de día, 1 de noche
static var grain: Texture2D
static var asphalt: Texture2D
static var tiles: Texture2D
static var grass: Texture2D
static var leaves: Texture2D   # hojas de los setos: manchas claras y oscuras bien marcadas
static var ready := false


static func setup() -> void:
	if ready:
		return
	ready = true
	grain = _noise_texture(7, 0.9, 1.0, 0.06)
	asphalt = _noise_texture(3, 2.2, 1.0, 0.16)
	grass = _noise_texture(11, 1.6, 1.0, 0.18)
	leaves = _noise_texture(21, 5.0, 1.0, 0.9)
	tiles = _tiles_texture()
	world_shader = load("res://shaders/world.gdshader")
	standard = _std(grain, 0.85)
	smooth = _std(null, 0.7)
	emissive = StandardMaterial3D.new()
	emissive.vertex_color_use_as_albedo = true
	emissive.vertex_color_is_srgb = true
	emissive.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	glass = _glass(0.0)
	glass_glow = _glass(0.0)
	windows = _glass(0.0)
	windows.set_shader_parameter("grid", Vector2(1.0, 1.0))
	windows.set_shader_parameter("lit_share", 0.85)
	shop_glass = _glass(0.0)
	shop_glass.set_shader_parameter("grid", Vector2(1.0, 1.0))
	shop_glass.set_shader_parameter("lit_share", 1.0)
	shop_glass.set_shader_parameter("lit_color", Vector3(1.0, 0.82, 0.6) * 0.9)  # el mismo color que la luz de adentro
	water = ShaderMaterial.new()
	water.shader = load("res://shaders/water.gdshader")


static func _std(tex: Texture2D, roughness: float) -> ShaderMaterial:
	var m := ShaderMaterial.new()
	m.shader = world_shader
	m.set_shader_parameter("roughness", roughness)
	if tex:
		m.set_shader_parameter("texture_albedo", tex)
		m.set_shader_parameter("use_texture", true)
	return m


static func textured(tex: Texture2D, roughness := 0.85, tint := Color.WHITE, uv := Vector3.ONE, metallic := 0.0) -> ShaderMaterial:
	var m := _std(tex, roughness)
	m.set_shader_parameter("albedo", tint)
	m.set_shader_parameter("uv1_scale", uv)
	m.set_shader_parameter("metallic", metallic)
	return m


static func _glass(night: float) -> ShaderMaterial:
	var m := ShaderMaterial.new()
	m.shader = load("res://shaders/glass.gdshader")
	m.set_shader_parameter("night", night)
	return m


## Ruido suave casi blanco: el color de cada pieza lo tiñe (como las texturas generadas en la versión de Python).
static func _noise_texture(seed: int, freq: float, base: float, amount: float) -> Texture2D:
	var n := FastNoiseLite.new()
	n.seed = seed
	n.frequency = freq / 64.0
	n.fractal_octaves = 4
	var img := Image.create(256, 256, false, Image.FORMAT_RGB8)
	for y in 256:
		for x in 256:
			var v := clampf(base - amount * 0.5 + amount * (n.get_noise_2d(x, y) * 0.5 + 0.5), 0.0, 1.0)
			img.set_pixel(x, y, Color(v, v, v))
	img.generate_mipmaps()
	return ImageTexture.create_from_image(img)


static func _tiles_texture() -> Texture2D:
	var img := Image.create(128, 128, false, Image.FORMAT_RGB8)
	var n := FastNoiseLite.new()
	n.frequency = 0.08
	for y in 128:
		for x in 128:
			var joint := x % 64 < 2 or y % 64 < 2
			var v := 0.78 if joint else 0.95 + 0.05 * n.get_noise_2d(x, y)
			img.set_pixel(x, y, Color(v, v, v))
	img.generate_mipmaps()
	return ImageTexture.create_from_image(img)


## Una luz en `pos` (local a `parent`: si el padre se mueve, como un auto, la luz va con él). `level` es como el nivel
## de luz de Minecraft: alumbra hasta `level` metros y a 15 está a toda fuerza. Las de adentro (`indoor`) siempre están
## prendidas y alumbran solo el local donde están; las de afuera se prenden al atardecer (ver shaders/world.gdshader).
## `moving`: va con algo que se mueve (los focos de un auto).
static func add_light(parent: Node3D, pos: Vector3, level: float, indoor := false, moving := false) -> Node3D:
	var n := Node3D.new()
	n.position = pos
	parent.add_child(n)
	lights.append([n, level, indoor, moving])
	return n


static func set_night(on: float) -> void:
	glass_glow.set_shader_parameter("night", on)
	windows.set_shader_parameter("night", on)
	shop_glass.set_shader_parameter("night", on)
