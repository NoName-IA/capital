// Agua (mar, laguna y fuente): varias capas de olas que se cruzan, turquesa cerca de la orilla y azul profundo mar
// adentro, espuma en las crestas, reflejo del cielo según el ángulo, destellos del sol y, de noche, el camino de luz
// de la luna que tiembla sobre las olas.
shader_type spatial;
render_mode specular_schlick_ggx;

uniform vec3 sky_top = vec3(0.22, 0.43, 0.8);
uniform vec3 horizon = vec3(0.53, 0.72, 0.92);
uniform float daylight = 1.0;
uniform vec3 moon_dir = vec3(0.0, 0.6, 0.8);  // hacia la luna
uniform float moon_light = 0.0;               // 0 de día; de noche, más con luna llena
uniform float coast = 160.0;                  // x de la orilla del mar: de ahí hacia el este el agua se hace honda

varying vec3 wpos;

float hash(vec2 p) { return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453); }
float noise(vec2 p) {
	vec2 i = floor(p), f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	return mix(mix(hash(i), hash(i + vec2(1.0, 0.0)), f.x), mix(hash(i + vec2(0.0, 1.0)), hash(i + vec2(1.0, 1.0)), f.x), f.y);
}

// Altura de las olas: oleaje largo más ondas chicas que van en otras direcciones
// (las ondas más chicas se saltan de lejos, donde no se verían)
float waves(vec2 p, float t, float detail) {
	float h = sin(p.x * 0.18 + t * 0.9) * 0.5 + sin((p.x * 0.6 + p.y * 0.8) * 0.25 + t * 1.2) * 0.35;
	h += noise(p * 0.35 + vec2(t * 0.25, t * 0.1)) * 0.6;
	h += noise(p * 0.9 - vec2(t * 0.35, -t * 0.2)) * 0.3;
	if (detail > 0.0) {
		h += noise(p * 2.3 + vec2(-t * 0.6, t * 0.5)) * 0.13 * detail;
	}
	return h;
}

void vertex() {
	wpos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

void fragment() {
	vec2 p = wpos.xz;
	float t = TIME;
	float e = 0.12;
	float detail = 1.0 - smoothstep(25.0, 60.0, distance(wpos, INV_VIEW_MATRIX[3].xyz));
	float h = waves(p, t, detail);
	float hx = waves(p + vec2(e, 0.0), t, detail);
	float hz = waves(p + vec2(0.0, e), t, detail);
	vec3 n = normalize(vec3(-(hx - h) / e * 0.22, 1.0, -(hz - h) / e * 0.22));
	NORMAL = normalize((VIEW_MATRIX * vec4(n, 0.0)).xyz);
	vec3 v = normalize(wpos - INV_VIEW_MATRIX[3].xyz);
	vec3 r = reflect(v, n);
	float fres = 0.04 + 0.96 * pow(1.0 - max(dot(-v, n), 0.0), 5.0);
	vec3 sky = mix(horizon, sky_top, clamp(r.y * 1.5, 0.0, 1.0));

	// Color del agua: turquesa en la orilla (y en la laguna y la fuente), azul profundo mar adentro
	float deep = smoothstep(coast + 6.0, coast + 70.0, wpos.x);
	vec3 water = mix(vec3(0.03, 0.32, 0.36), vec3(0.01, 0.08, 0.17), deep);
	// Espuma en las crestas más altas, más cerca de la orilla
	float foam = smoothstep(1.25 - 0.25 * (1.0 - deep), 1.55, h) * (0.5 + 0.5 * noise(p * 3.0 + t));
	water = mix(water, vec3(0.85, 0.9, 0.92), foam * 0.6);
	ALBEDO = water * (0.25 + 0.75 * daylight);
	ROUGHNESS = mix(0.03, 0.4, foam);
	SPECULAR = 0.9;
	EMISSION = sky * fres * 0.9 * (0.2 + 0.8 * daylight) + water * 0.05 * daylight;
	// Reflejo de la luna: olas chicas extra para que el camino de luz se quiebre en destellos
	vec3 nr = normalize(n + vec3(cos(p.x * 3.1 + t * 3.3) + cos(p.y * 2.3 - t * 2.9), 0.0,
			sin(p.y * 3.7 + t * 3.1) + sin((p.x - p.y) * 2.6 + t * 2.4)) * 0.035);
	float g = max(dot(reflect(v, nr), normalize(moon_dir)), 0.0);
	EMISSION += vec3(0.85, 0.9, 1.0) * (pow(g, 900.0) * 9.0 + pow(g, 120.0) * 1.2 + pow(g, 12.0) * 0.06) * moon_light;
}
