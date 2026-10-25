class_name SkyLight
extends RefCounted
## Cielo, sol, luna, luz ambiental y niebla. set_time(t) mueve un día completo de 24 horas: de 0 a DAY_PART el sol
## sale (6:00), cruza el cielo y se pone en el mar (20:00); de ahí a 1 sale la luna y hace su recorrido hasta el
## amanecer.

var user_exposure := 1.0     # brillo elegido en Gráficos → Imagen
var user_saturation := 1.0   # saturación elegida en Gráficos → Imagen
var night_lights := true     # faroles y locales iluminados de noche
var env: Environment
var sun: DirectionalLight3D
var sky_mat: ShaderMaterial
var night := false
var night_amount := 0.0
const DAY_PART := 0.68   # parte del ciclo con sol (6:00 a 20:00); el resto es la noche con la luna
var celestial := 0.0    # segundos reales: mueven la luna y las estrellas aunque la hora esté fija
var moon_phase := 0.5   # 0 = luna nueva, 0.5 = llena
var moon_dir := Vector3(0, 0.6, 0.8)
var flare_mat: ShaderMaterial   # destello del sol en la cámara (lo pone la ciudad)
var to_sun := Vector3.UP        # hacia el sol (de día)
var clouds := 0.15              # clima (lo pone la ciudad desde Weather): nubes en el cielo
var overcast := 0.0             # y cielo gris: apaga el sol y suaviza las sombras


func _init(parent: Node3D) -> void:
	sky_mat = ShaderMaterial.new()
	sky_mat.shader = load("res://shaders/sky.gdshader")
	var sky := Sky.new()
	sky.sky_material = sky_mat
	sky.radiance_size = Sky.RADIANCE_SIZE_64
	env = Environment.new()
	env.background_mode = Environment.BG_SKY
	env.sky = sky
	# Poca luz de relleno: las caras a la sombra quedan oscuras y el sol marca la escena (como en Eclipse). Es un
	# color fijo y no el cielo, porque con el cielo Godot ignora la energía y todo queda iluminado de más.
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.reflected_light_source = Environment.REFLECTION_SOURCE_SKY
	env.tonemap_mode = Environment.TONE_MAPPER_AGX
	env.tonemap_exposure = 0.72
	env.tonemap_agx_white = 12.0
	env.tonemap_agx_contrast = 1.4
	# Neblina tenue que toma el color del sol cuando se mira hacia él (dispersión de Mie)
	env.fog_enabled = true
	env.fog_mode = Environment.FOG_MODE_EXPONENTIAL
	env.fog_density = 0.0011
	env.fog_sky_affect = 0.0
	env.fog_aerial_perspective = 0.2
	env.fog_sun_scatter = 0.35
	env.glow_enabled = true
	env.glow_intensity = 0.5
	env.glow_strength = 1.1
	env.glow_bloom = 0.04
	env.glow_hdr_threshold = 1.0
	env.glow_blend_mode = Environment.GLOW_BLEND_MODE_SOFTLIGHT
	env.adjustment_enabled = true
	env.adjustment_saturation = 1.3
	env.adjustment_contrast = 1.06
	var we := WorldEnvironment.new()
	we.environment = env
	parent.add_child(we)
	sun = DirectionalLight3D.new()
	sun.shadow_enabled = true
	sun.directional_shadow_mode = DirectionalLight3D.SHADOW_ORTHOGONAL
	sun.directional_shadow_max_distance = 90.0
	sun.shadow_blur = 1.5
	sun.shadow_bias = 0.06   # más alto: sin rayitas de sombra sobre la ropa a pleno sol
	sun.shadow_normal_bias = 2.2
	sun.shadow_opacity = 1.0
	parent.add_child(sun)
	set_time(0.34)


## Las estrellas giran despacio alrededor del polo (con el tiempo real: también con la hora fija).
func tick(dt: float) -> void:
	celestial += dt
	sky_mat.set_shader_parameter("star_rot", celestial * TAU / 420.0)
	sky_mat.set_shader_parameter("moon_phase", moon_phase)


## Hora del reloj (0 a 24) que corresponde a un punto t del ciclo.
static func hour_of(t: float) -> float:
	if t < DAY_PART:
		return 6.0 + 14.0 * t / DAY_PART
	return fmod(20.0 + 10.0 * (t - DAY_PART) / (1.0 - DAY_PART), 24.0)


func set_time(t: float) -> void:
	t = fposmod(t, 1.0)
	# El sol sale tierra adentro, cruza el cielo y se pone en el mar; al irse, la luna sale por el mismo lado y hace
	# su recorrido durante la noche.
	var s := t / DAY_PART if t < DAY_PART else 1.0          # avance del sol (1 = ya se puso)
	var u := (t - DAY_PART) / (1.0 - DAY_PART) if t >= DAY_PART else 0.0   # avance de la luna
	# Altura real del sol (negativa = bajo el horizonte): de noche sigue bajando y vuelve a subir para el amanecer
	var sun_h := sin(PI * s) if t < DAY_PART else -sin(PI * u)
	var elev: float = max(0.1, sun_h)
	var sun_vis := Vector3(-cos(PI * s) * 0.75, sun_h * 0.7, -0.5).normalized()   # donde se dibuja el disco
	moon_dir = Vector3(-cos(PI * u) * 0.85, 0.02 + sin(PI * u) * 0.5, 0.45).normalized() if t >= DAY_PART \
			else Vector3(0.6, -0.4, 0.45).normalized()
	sky_mat.set_shader_parameter("sun_vis", sun_vis)
	sky_mat.set_shader_parameter("moon_dir", moon_dir)
	Mats.water.set_shader_parameter("moon_dir", moon_dir)
	# El sol nunca pasa justo encima: así siempre hay sombras largas que dibujan la ciudad.
	var dir := Vector3(cos(PI * s) * 0.7, -max(0.2, elev * 0.7), 0.5).normalized()   # hacia donde apunta la luz
	var day := min(1.0, elev * 2.2)
	night_amount = clampf((0.14 - sun_h) / 0.24, 0.0, 1.0)   # oscurece cuando el sol toca el mar
	to_sun = sun_vis
	if flare_mat:
		flare_mat.set_shader_parameter("sun_dir", to_sun)
		flare_mat.set_shader_parameter("strength", (1.0 - night_amount) * smoothstep(0.12, 0.3, elev) * (1.0 - overcast))
	# De noche la luz viene de la luna (nunca tan baja que las sombras se estiren de más)
	var to_moon := Vector3(moon_dir.x, max(moon_dir.y, 0.4), moon_dir.z).normalized()
	dir = dir.lerp(-to_moon, night_amount).normalized()
	sun.look_at_from_position(Vector3.ZERO, dir, Vector3(0, 0, 1) if absf(dir.y) > 0.99 else Vector3.UP)
	var full := 1.0 - absf(moon_phase * 2.0 - 1.0)
	var golden := (1.0 - smoothstep(0.3, 0.55, elev)) * (1.0 - night_amount)   # la hora dorada antes de anochecer
	# Color del sol por temperatura: 6300 K arriba, rojizo (2200 K) cuando está bajo. De noche alumbra la luna:
	# fría (8000 K), más fuerte con luna llena, y alcanza para ver todo y marcar sombras.
	var sun_col := kelvin(lerpf(2200.0, 6300.0, smoothstep(0.15, 0.6, elev)))
	sun.light_color = sun_col.lerp(kelvin(8000.0), night_amount)
	sun.light_energy = lerpf(0.3 + 1.05 * smoothstep(0.08, 0.5, elev), 0.32 + 0.28 * full, night_amount)
	var horizon := Color8(20, 26, 50).lerp(Color8(135, 185, 235), day).lerp(Color8(235, 160, 115), golden * 0.6)
	var top := Color8(6, 8, 22).lerp(Color8(55, 110, 205), day)
	# Nublado o lluvia: cielo gris, sol tapado (luz más débil y difusa, sombras suaves)
	var gray: Color = Color(0.5, 0.53, 0.58) * (0.15 + 0.85 * day)
	horizon = horizon.lerp(gray, overcast * 0.8)
	top = top.lerp(gray * 0.85, overcast * 0.8)
	sun.light_energy *= 1.0 - 0.7 * overcast
	sun.shadow_opacity = 1.0 - 0.75 * overcast
	sky_mat.set_shader_parameter("clouds", clouds)
	sky_mat.set_shader_parameter("overcast", overcast)
	env.fog_density = 0.0011 + 0.005 * overcast * overcast
	var glow := Vector3(sun_col.r, sun_col.g, sun_col.b) * (0.3 + 0.7 * elev) * (1.0 - night_amount)
	sky_mat.set_shader_parameter("sky_top", Vector3(top.r, top.g, top.b))
	sky_mat.set_shader_parameter("horizon", Vector3(horizon.r, horizon.g, horizon.b))
	sky_mat.set_shader_parameter("sun_glow", glow)
	sky_mat.set_shader_parameter("daylight", day)
	env.ambient_light_color = top.lerp(horizon, 0.6).lerp(Color(0.6, 0.62, 0.66) * day, 0.35)  # cielo, no tan azul
	env.ambient_light_energy = 0.2 + 0.4 * day + 0.25 * overcast * day
	# Noche: luz de cielo azulada y el ojo que se acostumbra a la oscuridad (más exposición), como en Eclipse
	env.ambient_light_color = env.ambient_light_color.lerp(Color(0.24, 0.3, 0.48), night_amount)
	env.ambient_light_energy = lerpf(env.ambient_light_energy, 0.75, night_amount)
	env.tonemap_exposure = lerpf(0.72, 1.2, night_amount) * user_exposure
	Mats.water.set_shader_parameter("moon_light", night_amount * (0.35 + 0.65 * full))
	# Visión nocturna (efecto Purkinje): de noche los colores se apagan y todo tira a azul
	env.adjustment_saturation = lerpf(1.3, 0.65, night_amount) * user_saturation
	env.fog_light_color = horizon.lerp(Color(0.25, 0.32, 0.55), night_amount * 0.5)
	for m in [Mats.glass, Mats.glass_glow, Mats.windows, Mats.shop_glass]:
		m.set_shader_parameter("sun_dir", -dir)  # hacia el sol
	for m in [Mats.glass, Mats.glass_glow, Mats.windows, Mats.shop_glass, Mats.water]:
		m.set_shader_parameter("sky_top", Vector3(top.r, top.g, top.b))
		m.set_shader_parameter("horizon", Vector3(horizon.r, horizon.g, horizon.b))
		m.set_shader_parameter("daylight", day)
	night = elev < 0.3
	Mats.set_night(night_amount)
	Mats.emissive.albedo_color = Color(1, 1, 1) * (0.7 + 0.8 * night_amount)
	Mats.set_lights(1.7 * smoothstep(0.0, 1.0, (0.42 - elev) / 0.2) * (1.0 if night_lights else 0.0))  # se prenden al atardecer
	# Adentro: de día más fuerte (el ojo está acostumbrado a la luz de afuera), de noche un poco menos
	Mats.indoor_light.set_shader_parameter("energy", lerpf(1.5, 1.2, night_amount))


## Color de una luz a cierta temperatura en kelvin (aproximación de Tanner Helland).
static func kelvin(k: float) -> Color:
	var t := k / 100.0
	var r := 1.0 if t <= 66.0 else clampf(1.292936 * pow(t - 60.0, -0.1332047592), 0.0, 1.0)
	var g := clampf(0.3900816 * log(t) - 0.6318414, 0.0, 1.0) if t <= 66.0 else clampf(1.1298909 * pow(t - 60.0, -0.0755148492), 0.0, 1.0)
	var b := 1.0 if t >= 66.0 else (0.0 if t <= 19.0 else clampf(0.5432068 * log(t - 10.0) - 1.1962541, 0.0, 1.0))
	return Color(r, g, b)
