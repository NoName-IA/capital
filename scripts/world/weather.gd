class_name Weather
extends RefCounted
## Cómo se ve el clima en la ciudad: nubes, cielo cubierto, lluvia y relámpagos. El clima en sí lo decide la
## simulación (Game.weather, que mueve la demanda de cada negocio); aquí solo se dibuja y se cambia suave.
## El kiosco ELDIARIO lo muestra con la temperatura y el pronóstico.

# Cómo se ve cada clima de D.WEATHER (mismo orden)
const LOOKS := [
	{"clouds": 0.15, "overcast": 0.0, "rain": 0.0},
	{"clouds": 0.5, "overcast": 0.15, "rain": 0.0},
	{"clouds": 0.85, "overcast": 0.55, "rain": 0.0},
	{"clouds": 1.0, "overcast": 0.85, "rain": 1.0},
	{"clouds": 0.02, "overcast": 0.0, "rain": 0.0},
	{"clouds": 1.0, "overcast": 1.0, "rain": 1.6},
]

var today := 0
var tomorrow := 0
var clouds := 0.15     # lo que se ve ahora (va cambiando suave hacia el clima de hoy)
var overcast := 0.0
var rain := 0.0
var month := 0
var last_t := -1.0
var rain_fx: CPUParticles3D


var flash := 0.0       # relámpago de la tormenta (0 a 1)
var show_rain := true  # Gráficos → Imagen: gotas y relámpagos (el clima igual cuenta para la economía)


func _init(parent: Node3D) -> void:
	today = 0
	tomorrow = 0
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


## Sigue el clima de la partida (o queda despejado en el menú) y lo cambia suave.
func update(dt: float, game, camera: Camera3D, indoors: bool) -> void:
	if game != null:
		today = game.weather
		tomorrow = game.weather_next
		month = game.month_index()
	else:
		today = 0
		tomorrow = 0
	var k: Dictionary = LOOKS[today]
	clouds = move_toward(clouds, k.clouds, dt * 0.08)
	overcast = move_toward(overcast, k.overcast, dt * 0.08)
	rain = move_toward(rain, k.rain, dt * 0.15)
	rain_fx.emitting = rain > 0.3 and not indoors and show_rain
	rain_fx.global_position = camera.global_position + Vector3(0, 14, 0)
	# Relámpagos en la tormenta: un destello de vez en cuando
	flash = max(0.0, flash - dt * 3.0)
	if today == 5 and show_rain and randf() < dt * 0.12:
		flash = 1.0


## Temperatura en °C a cierta hora: más fresco al amanecer, lo más caluroso a las 15:00; las nubes y la lluvia enfrían.
func temperature(hour: float) -> int:
	var top: float = D.MAX_TEMP[month % 12] + (6.0 if today == 4 else 0.0)
	var curve := 0.5 + 0.5 * cos((hour - 15.0) / 24.0 * TAU)
	return roundi(top - 9.0 + 9.0 * curve - 3.0 * overcast - 2.0 * rain)


func name_of(i: int) -> String:
	return D.WEATHER[i].name


func icon_of(i: int) -> String:
	return D.WEATHER[i].icon
