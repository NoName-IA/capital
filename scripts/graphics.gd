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
	sky.sun.directional_shadow_max_distance = spec[2]
	sky.sun.shadow_blur = spec[4]
	sky.sun.directional_shadow_blend_splits = g.g_shadows == 3  # sin corte visible entre un tramo y el siguiente
	# El primer tramo (el más nítido) cubre hasta donde llega la cámara alejada; si no, las sombras cercanas se
	# dibujan con el tramo de lejos y se ven borrosas.
	sky.sun.directional_shadow_split_1 = 0.3 if g.g_shadows == 2 else 0.12
	sky.sun.directional_shadow_split_2 = 0.3
	sky.sun.directional_shadow_split_3 = 0.6
	RenderingServer.directional_shadow_atlas_set_size(spec[0], true)
	RenderingServer.directional_soft_shadow_filter_set_quality(spec[3])
	sky.env.glow_enabled = g.g_glow
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
