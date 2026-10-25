class_name Weather
extends RefCounted
## Clima de la ciudad: soleado, parcialmente nublado, nublado o lluvia. Cambia cada amanecer según la estación (en
## verano casi siempre hay sol; en invierno llueve más), cubre el cielo de nubes, apaga el sol y hace llover. El
## kiosco ELDIARIO lo muestra con la temperatura y el pronóstico de mañana. No cambia la economía.

const KINDS := [
	{"name": "Soleado", "icon": "☀", "clouds": 0.15, "overcast": 0.0},
	{"name": "Parcialmente nublado", "icon": "⛅", "clouds": 0.5, "overcast": 0.15},
	{"name": "Nublado", "icon": "☁", "clouds": 0.85, "overcast": 0.55},
	{"name": "Lluvia", "icon": "☂", "clouds": 1.0, "overcast": 0.85},
]
# Probabilidad de cada clima por mes (enero = verano). [sol, parcial, nublado, lluvia]
const SEASON := [[0.7, 0.2, 0.08, 0.02], [0.65, 0.22, 0.1, 0.03], [0.5, 0.28, 0.14, 0.08], [0.35, 0.3, 0.2, 0.15],
		[0.25, 0.28, 0.25, 0.22], [0.18, 0.22, 0.28, 0.32], [0.18, 0.2, 0.3, 0.32], [0.22, 0.25, 0.28, 0.25],
		[0.3, 0.3, 0.22, 0.18], [0.4, 0.3, 0.18, 0.12], [0.5, 0.28, 0.14, 0.08], [0.62, 0.24, 0.1, 0.04]]
const MAX_TEMP := [29, 28, 25, 21, 17, 14, 13, 15, 18, 21, 24, 27]   # máxima típica de cada mes (°C)

var today := 0
var tomorrow := 0
var clouds := 0.15     # lo que se ve ahora (va cambiando suave hacia el clima de hoy)
var overcast := 0.0
var rain := 0.0
var month := 0
var last_t := -1.0
var rain_fx: CPUParticles3D


func _init(parent: Node3D) -> void:
	today = 0
	tomorrow = _roll()
	rain_fx = CPUParticles3D.new()
	rain_fx.amount = 1400
	rain_fx.lifetime = 0.9
	rain_fx.emitting = false
	rain_fx.local_coords = false
	rain_fx.emission_shape = CPUParticles3D.EMISSION_SHAPE_BOX
	rain_fx.emission_box_extents = Vector3(22, 0.5, 22)
	rain_fx.direction = Vector3(0.08, -1, 0.04)
	rain_fx.spread = 2.0
	rain_fx.gravity = Vector3(0, -20, 0)
	rain_fx.initial_velocity_min = 16.0
	rain_fx.initial_velocity_max = 20.0
	var drop := BoxMesh.new()
	drop.size = Vector3(0.025, 0.55, 0.025)
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.albedo_color = Color(0.75, 0.82, 0.95, 0.35)
	drop.material = mat
	rain_fx.mesh = drop
	rain_fx.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	parent.add_child(rain_fx)


func _roll() -> int:
	var p: Array = SEASON[month % 12]
	var r := randf()
	for i in p.size():
		r -= p[i]
		if r <= 0.0:
			return i
	return 0


## t: punto del ciclo del cielo (0 = amanece). Al pasar el amanecer el pronóstico de ayer se vuelve el clima de hoy.
func update(dt: float, t: float, game_month: int, camera: Camera3D, indoors: bool) -> void:
	month = game_month
	if last_t >= 0.0 and t < last_t - 0.5:
		today = tomorrow
		tomorrow = _roll()
	last_t = t
	var k: Dictionary = KINDS[today]
	clouds = move_toward(clouds, k.clouds, dt * 0.08)
	overcast = move_toward(overcast, k.overcast, dt * 0.08)
	rain = move_toward(rain, 1.0 if today == 3 else 0.0, dt * 0.15)
	rain_fx.emitting = rain > 0.3 and not indoors
	rain_fx.global_position = camera.global_position + Vector3(0, 14, 0)


## Temperatura en °C a cierta hora: más fresco al amanecer, lo más caluroso a las 15:00; las nubes y la lluvia enfrían.
func temperature(hour: float) -> int:
	var top: float = MAX_TEMP[month % 12]
	var curve := 0.5 + 0.5 * cos((hour - 15.0) / 24.0 * TAU)
	return roundi(top - 9.0 + 9.0 * curve - 3.0 * overcast - 2.0 * rain)


func name_of(i: int) -> String:
	return KINDS[i].name


func icon_of(i: int) -> String:
	return KINDS[i].icon
