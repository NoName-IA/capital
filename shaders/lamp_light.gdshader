// Luz de un farol o del interior de un local, de noche: un volumen alrededor del farol que lee la profundidad de la escena y suma luz cálida a lo
// que haya adentro (calle, vereda, paredes, personas y autos), más fuerte cerca del farol y en lo que mira hacia él.
// No es una luz de Godot: esas en el modo Compatibilidad se cortan con la distancia y cuestan una pasada por objeto;
// esta se ve igual desde lejos y solo cuesta los píxeles que tapa el volumen.
shader_type spatial;
render_mode unshaded, blend_add, depth_draw_never, depth_test_disabled, cull_front, fog_disabled, shadows_disabled;

uniform sampler2D depth_tex : hint_depth_texture, filter_nearest, repeat_disable;
uniform vec3 light_color = vec3(1.0, 0.82, 0.6);   // blanco cálido: el mismo tono que la luz de adentro de los locales
uniform float energy = 0.0;   // 0 de día, sube al anochecer
uniform float falloff = 2.0;  // 2 = se apaga rápido lejos del centro (faroles); 1 = luz pareja (interiores)

varying vec3 center;
varying float radius;

// La malla es un cubo de lado 2: la escala del nodo es el radio de la luz.
void vertex() {
	center = MODEL_MATRIX[3].xyz;
	radius = length(MODEL_MATRIX[0].xyz);
}

void fragment() {
	float d = texture(depth_tex, SCREEN_UV).r;
	if (d < 0.00001) {  // cielo (en el modo Compatibilidad no escribe profundidad): nada que alumbrar
		discard;
	}
	vec4 v = INV_PROJECTION_MATRIX * vec4(vec3(SCREEN_UV, d) * 2.0 - 1.0, 1.0);
	vec3 view_p = v.xyz / v.w;
	vec3 wp = (INV_VIEW_MATRIX * vec4(view_p, 1.0)).xyz;
	vec3 to_light = center - wp;
	float dist = length(to_light);
	float fall = clamp(1.0 - dist / radius, 0.0, 1.0);
	fall = pow(fall, falloff);
	// Lo que mira hacia el farol recibe más luz (la normal sale de la profundidad)
	vec3 n = normalize(cross(dFdx(wp), dFdy(wp)));
	n = dot(n, CAMERA_POSITION_WORLD - wp) < 0.0 ? -n : n;
	float facing = 0.2 + 0.8 * max(dot(n, to_light / max(dist, 0.001)), 0.0);
	ALBEDO = light_color * fall * facing * energy;
}
