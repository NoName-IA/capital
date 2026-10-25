class_name Mats
extends RefCounted
## Materiales compartidos de la ciudad. Todos usan el color de los vértices, así una sola malla tiene muchos colores.

static var standard: StandardMaterial3D
static var smooth: StandardMaterial3D      # sin textura (personas, autos)
static var glass: ShaderMaterial          # vidrios: reflejan el cielo y la ciudad
static var glass_glow: ShaderMaterial     # vidrios de oficinas: de noche se prenden las ventanas
static var windows: ShaderMaterial        # ventanas de las casas
static var shop_glass: ShaderMaterial     # vitrinas de locales y puestos: de noche brillan cálidas
static var emissive: StandardMaterial3D   # rojo de la competencia, faroles: igual de día y de noche
static var water: ShaderMaterial
static var lamp_light: ShaderMaterial    # la luz que tiran los faroles y los locales de noche
static var indoor_light: ShaderMaterial  # la luz de los paneles del techo adentro: siempre prendida
static var _light_box: BoxMesh
static var light_nodes := []             # de día se ocultan: no alumbran y cuestan igual
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
	lamp_light = ShaderMaterial.new()
	lamp_light.shader = load("res://shaders/lamp_light.gdshader")
	lamp_light.set_shader_parameter("energy", 0.0)
	indoor_light = ShaderMaterial.new()
	indoor_light.shader = lamp_light.shader
	indoor_light.set_shader_parameter("light_color", Vector3(1.0, 0.82, 0.6))
	indoor_light.set_shader_parameter("energy", 1.2)
	indoor_light.set_shader_parameter("falloff", 1.0)


static func _std(tex: Texture2D, roughness: float) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.vertex_color_use_as_albedo = true
	m.vertex_color_is_srgb = true  # los colores están escritos en sRGB; leídos como lineales salen pálidos
	m.roughness = roughness
	m.metallic_specular = 0.35
	if tex:
		m.albedo_texture = tex
		m.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS_ANISOTROPIC
	return m


static func textured(tex: Texture2D, roughness := 0.85, tint := Color.WHITE, uv := Vector3.ONE) -> StandardMaterial3D:
	var m := _std(tex, roughness)
	m.albedo_color = tint
	m.uv1_scale = uv
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


## Una luz cálida de noche con centro en `pos` (local a `parent`) que alumbra `radius` metros a la redonda.
static func light_volume(parent: Node3D, pos: Vector3, radius: float, indoor := false) -> MeshInstance3D:
	if _light_box == null:
		_light_box = BoxMesh.new()
		_light_box.size = Vector3(2, 2, 2)
	var mi := MeshInstance3D.new()
	mi.mesh = _light_box
	mi.material_override = indoor_light if indoor else lamp_light
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	mi.position = pos
	mi.scale = Vector3.ONE * radius
	parent.add_child(mi)
	if indoor:
		return mi
	mi.visible = lamp_light.get_shader_parameter("energy") > 0.01
	light_nodes = light_nodes.filter(func(n): return is_instance_valid(n))
	light_nodes.append(mi)
	return mi


static func set_lights(energy: float) -> void:
	lamp_light.set_shader_parameter("energy", energy)
	for n in light_nodes:
		if is_instance_valid(n):
			n.visible = energy > 0.01


static func set_night(on: float) -> void:
	glass_glow.set_shader_parameter("night", on)
	windows.set_shader_parameter("night", on)
	shop_glass.set_shader_parameter("night", on)
