class_name Graphics
extends RefCounted
## Calidad gráfica: niveles Bajo, Medio y Alto, y Personalizado (cada opción por separado). Alto imita el aspecto del
## shader Eclipse de Minecraft: sombras nítidas y lejanas, oclusión ambiental y resplandor. Los bordes suaves (MSAA)
## quedan solo en Personalizado: en una Intel HD 4600 cuestan casi tanto como todo lo demás junto. No hay opción
## de resolución: en el modo Compatibilidad dibujar a menos resolución resulta más lento, no más rápido.

const LEVELS := ["Bajo", "Medio", "Alto", "Personalizado"]
const CUSTOM := 3
# Lo que activa cada nivel. Personalizado usa las claves g_* guardadas en los ajustes.
const PRESETS := [
	{"g_shadows": 1, "g_ao": false, "g_glow": false, "g_aa": 0, "g_flare": false},
	{"g_shadows": 2, "g_ao": false, "g_glow": true, "g_aa": 0, "g_flare": true},
	{"g_shadows": 3, "g_ao": true, "g_glow": true, "g_aa": 0, "g_flare": true},
]
const SHADOWS := ["Apagadas", "Bajas", "Medias", "Altas"]
# Opciones extra: no cambian el nivel elegido, se aplican encima
const SHADOW_DIST := ["Cerca", "Normal", "Lejos"]
const SHADOW_DIST_K := [0.6, 1.0, 1.6]
const SHADOW_SOFT := ["Según nivel", "Duras", "Suaves", "Muy suaves"]
const TONEMAPS := ["AgX", "Fílmico", "ACES", "Reinhard", "Lineal"]
const TONEMAP_MODES := [Environment.TONE_MAPPER_AGX, Environment.TONE_MAPPER_FILMIC, Environment.TONE_MAPPER_ACES,
		Environment.TONE_MAPPER_REINHARDT, Environment.TONE_MAPPER_LINEAR]
const FPS_LIMITS := ["30", "60", "90", "120", "Sin límite"]
const FPS_VALUES := [30, 60, 90, 120, 0]
const VIEWS := ["Corta", "Media", "Larga", "Máxima"]
const VIEW_DIST := [300.0, 600.0, 1000.0, 1400.0]
const CROWDS := ["Poca", "Normal", "Mucha"]
const AA := ["Apagados", "MSAA 2x", "MSAA 4x"]
# Por nivel de sombras: [resolución, divisiones, distancia en metros, filtro suave (0-5), desenfoque]. Poca resolución
# repartida en mucha distancia hace sombras cuadradas: cada nivel junta resolución y distancia para que no pase.
const SHADOW_SPECS := [
	[1024, DirectionalLight3D.SHADOW_ORTHOGONAL, 0.0, 0, 0.0],
	[2048, DirectionalLight3D.SHADOW_ORTHOGONAL, 45.0, 2, 1.5],
	[4096, DirectionalLight3D.SHADOW_PARALLEL_2_SPLITS, 80.0, 2, 1.0],
	[4096, DirectionalLight3D.SHADOW_PARALLEL_4_SPLITS, 140.0, 4, 1.1],
]

## Los valores que valen ahora: los del nivel elegido o, en Personalizado, los del jugador.
static func current(settings: Dictionary) -> Dictionary:
	var q: int = settings.quality
	return settings if q == CUSTOM else PRESETS[q]


## Copia los valores del nivel elegido a las opciones, así la página de gráficos muestra lo que hay activo y
## Personalizado parte de ahí.
static func show_preset(settings: Dictionary) -> void:
	var q: int = settings.quality
	if q != CUSTOM:
		for k in PRESETS[q]:
			settings[k] = PRESETS[q][k]


static func apply(settings: Dictionary, viewport: Viewport, sky: SkyLight, ao: MeshInstance3D,
		flare: MeshInstance3D) -> void:
	var g := current(settings)
	var spec: Array = SHADOW_SPECS[int(g.g_shadows)]
	sky.sun.shadow_enabled = g.g_shadows > 0
	sky.sun.directional_shadow_mode = spec[1]
	sky.sun.directional_shadow_max_distance = spec[2] * SHADOW_DIST_K[int(settings.get("g_shadow_dist", 1))]
	sky.sun.shadow_blur = spec[4]
	sky.sun.directional_shadow_blend_splits = g.g_shadows == 3  # sin corte visible entre un tramo y el siguiente
	# El primer tramo (el más nítido) cubre hasta donde llega la cámara alejada; si no, las sombras cercanas se
	# dibujan con el tramo de lejos y se ven borrosas.
	sky.sun.directional_shadow_split_1 = 0.3 if g.g_shadows == 2 else 0.12
	sky.sun.directional_shadow_split_2 = 0.3
	sky.sun.directional_shadow_split_3 = 0.6
	RenderingServer.directional_shadow_atlas_set_size(spec[0], true)
	var soft := int(settings.get("g_shadow_soft", 0))
	RenderingServer.directional_soft_shadow_filter_set_quality(spec[3] if soft == 0 else [0, 2, 5][soft - 1])
	sky.env.glow_enabled = g.g_glow
	# Imagen
	sky.env.glow_intensity = 0.5 * float(settings.get("g_glow_amt", 1.0))
	sky.user_exposure = float(settings.get("g_bright", 1.0))
	sky.user_saturation = float(settings.get("g_sat", 1.0))
	sky.env.adjustment_contrast = 1.06 * float(settings.get("g_contrast", 1.0))
	sky.env.tonemap_mode = TONEMAP_MODES[int(settings.get("g_tonemap", 0))]
	sky.env.fog_enabled = settings.get("g_fog", true)
	sky.night_lights = settings.get("g_night_lights", true)
	# Rendimiento
	Engine.max_fps = FPS_VALUES[int(settings.get("g_fps_limit", 1))]
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_ENABLED if settings.get("g_vsync", true) else DisplayServer.VSYNC_DISABLED)
	ao.visible = g.g_ao
	flare.visible = false  # la ciudad lo muestra cuando el sol está a la vista (City.update)
	viewport.msaa_3d = [Viewport.MSAA_DISABLED, Viewport.MSAA_2X, Viewport.MSAA_4X][int(g.g_aa)]


## Un cuadro que tapa la pantalla con un efecto (oclusión ambiental, destello del sol): va pegado a la cámara y
## nunca se recorta.
static func make_overlay(camera: Camera3D, shader_path: String) -> MeshInstance3D:
	var quad := QuadMesh.new()
	var mat := ShaderMaterial.new()
	mat.shader = load(shader_path)
	quad.material = mat
	var mi := MeshInstance3D.new()
	mi.mesh = quad
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	mi.extra_cull_margin = 16384.0
	mi.position = Vector3(0, 0, -1)
	mi.visible = false
	camera.add_child(mi)
	return mi
