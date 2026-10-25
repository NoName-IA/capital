// Vidrio de la ciudad, tipo espejo: refleja el cielo con sus nubes, el sol y la silueta de los edificios según el
// ángulo (Fresnel). Cada panel está apenas inclinado distinto, así el reflejo se quiebra entre ventanas como en un
// edificio real. De noche se prenden algunas oficinas. Funciona en el modo Compatibilidad (no necesita sondas).
shader_type spatial;
render_mode specular_schlick_ggx;

uniform float night = 0.0;
uniform vec2 grid = vec2(1.25, 1.4);       // ventanas por unidad de UV (1 unidad = 2 m)
uniform float lit_share = 0.55;            // parte de las ventanas encendidas de noche
uniform vec3 lit_color = vec3(1.0, 0.8, 0.5);  // color de la luz de adentro (las vitrinas, más cálida)
uniform vec3 sky_top = vec3(0.22, 0.43, 0.8);
uniform vec3 horizon = vec3(0.53, 0.72, 0.92);
uniform vec3 sun_dir = vec3(0.3, 0.8, 0.4);  // hacia el sol
uniform float daylight = 1.0;

varying vec3 wpos;
varying vec3 wnorm;

float hash(vec2 p) { return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453); }
float noise(vec2 p) {
	vec2 i = floor(p), f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	return mix(mix(hash(i), hash(i + vec2(1.0, 0.0)), f.x), mix(hash(i + vec2(0.0, 1.0)), hash(i + vec2(1.0, 1.0)), f.x), f.y);
}
float fbm(vec2 p) {
	float v = 0.0, a = 0.5;
	for (int i = 0; i < 3; i++) { v += a * noise(p); p *= 2.07; a *= 0.5; }
	return v;
}

void vertex() {
	wpos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	wnorm = normalize((MODEL_MATRIX * vec4(NORMAL, 0.0)).xyz);
}

// Lo que se ve reflejado en la dirección r
vec3 reflected(vec3 r) {
	vec3 sky = mix(horizon, sky_top, clamp(r.y * 1.4, 0.0, 1.0));
	if (r.y > 0.0) {
		vec2 uv = r.xz / (r.y + 0.08) * 0.9 + vec2(TIME * 0.012, TIME * 0.005);
		float c = fbm(uv * 1.4);
		float cover = smoothstep(0.45, 0.75, c) * smoothstep(0.0, 0.2, r.y);
		vec3 cloud = mix(vec3(0.3, 0.33, 0.42), vec3(1.0, 0.99, 0.97), daylight);
		sky = mix(sky, cloud, cover * 0.85);
	}
	// sol
	float sd = max(dot(r, normalize(sun_dir)), 0.0);
	sky += vec3(1.0, 0.9, 0.7) * (pow(sd, 400.0) * 4.0 + pow(sd, 18.0) * 0.4) * daylight;
	// edificios del horizonte
	float ang = atan(r.z, r.x);
	float col_id = floor(ang * 16.0);
	float tall = 0.03 + 0.22 * hash(vec2(col_id, 3.0));
	float building = step(r.y, tall) * step(-0.12, r.y);
	vec3 bcol = mix(vec3(0.06, 0.07, 0.1), vec3(0.42, 0.45, 0.52), daylight) * (0.75 + 0.5 * hash(vec2(col_id, 9.0)));
	vec2 rw = vec2(ang * 80.0, r.y * 90.0);
	float rlit = step(0.7, hash(floor(rw))) * step(0.3, fract(rw.x)) * step(0.35, fract(rw.y));
	bcol += night * rlit * vec3(1.0, 0.78, 0.45) * 0.7;
	vec3 col = mix(sky, bcol, building);
	return mix(col, mix(vec3(0.04), vec3(0.32, 0.34, 0.3), daylight), step(r.y, -0.12));
}

void fragment() {
	vec2 cell = UV * grid;
	vec2 f = fract(cell);
	vec2 id = floor(cell);
	float frame = 1.0 - step(0.06, f.x) * step(f.x, 0.94) * step(0.06, f.y) * step(f.y, 0.94);
	vec3 n = normalize(wnorm);
	// cada panel apenas inclinado distinto: el reflejo se quiebra entre ventanas
	vec3 tilt = vec3(hash(id + 3.1) - 0.5, hash(id + 7.7) - 0.5, hash(id + 1.3) - 0.5) * 0.07;
	n = normalize(n + tilt * (1.0 - frame));
	vec3 v = normalize(wpos - INV_VIEW_MATRIX[3].xyz);
	vec3 r = reflect(v, n);
	float ndv = clamp(dot(-v, n), 0.0, 1.0);
	float fres = 0.45 + 0.55 * pow(1.0 - ndv, 3.0);
	float lit = step(1.0 - lit_share, hash(id + 17.0));

	ALBEDO = mix(COLOR.rgb * 0.12, vec3(0.05), frame);
	METALLIC = 0.0;
	ROUGHNESS = mix(0.05, 0.6, frame);
	SPECULAR = 0.6;
	vec3 emit = reflected(r) * fres * mix(0.18, 1.0, daylight) * mix(COLOR.rgb * 1.3, vec3(1.0), 0.65);
	emit += night * lit * lit_color * 1.1 * (0.85 + 0.3 * hash(id));
	EMISSION = emit * (1.0 - frame * 0.9);
}
