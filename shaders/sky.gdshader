// Cielo: degradado, sol con resplandor, nubes que se mueven con el viento y, de noche, estrellas en una bóveda que
// gira despacio alrededor del polo y una luna con cráteres y fases que cruza el cielo.
shader_type sky;

uniform vec3 sky_top = vec3(0.22, 0.43, 0.8);
uniform vec3 horizon = vec3(0.53, 0.72, 0.92);
uniform vec3 sun_glow = vec3(1.0, 0.82, 0.55);
uniform float daylight = 1.0;
uniform vec3 sun_vis = vec3(0.0, 0.6, -0.8);   // hacia el sol (llega al horizonte al salir y al ponerse)
uniform float star_rot = 0.0;                 // giro de la bóveda de estrellas (radianes)
uniform vec3 moon_dir = vec3(0.0, 0.6, 0.8);  // hacia la luna
uniform float moon_phase = 0.5;               // 0 = luna nueva, 0.5 = llena
uniform float clouds = 0.15;                  // cuánto cielo cubren las nubes (clima)
uniform float overcast = 0.0;                 // cielo gris de nublado o lluvia: tapa el sol, la luna y las estrellas

const vec3 POLE = vec3(0.0, 0.8, 0.6);  // eje de giro del cielo (el polo, inclinado como en una latitud media)

float hash(vec2 p) { return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453); }
float noise(vec2 p) {
	vec2 i = floor(p), f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	return mix(mix(hash(i), hash(i + vec2(1.0, 0.0)), f.x), mix(hash(i + vec2(0.0, 1.0)), hash(i + vec2(1.0, 1.0)), f.x), f.y);
}
float fbm(vec2 p) {
	float v = 0.0, a = 0.5;
	for (int i = 0; i < 4; i++) { v += a * noise(p); p *= 2.07; a *= 0.5; }
	return v;
}

float hash3(vec3 p) { return fract(sin(dot(p, vec3(127.1, 311.7, 74.7))) * 43758.5453); }

vec3 rotate_axis(vec3 v, vec3 axis, float a) {
	return v * cos(a) + cross(axis, v) * sin(a) + axis * dot(axis, v) * (1.0 - cos(a));
}

// Estrellas puntuales repartidas por la esfera, con brillos y colores distintos y un leve titileo
vec3 stars(vec3 d) {
	vec3 p = rotate_axis(d, normalize(POLE), star_rot) * 170.0;
	vec3 cell = floor(p);
	float h = hash3(cell);
	if (h < 0.982) {
		return vec3(0.0);
	}
	vec3 off = vec3(hash3(cell + 1.7), hash3(cell + 4.1), hash3(cell + 9.3)) * 0.6 + 0.2;
	float dist = length(fract(p) - off);
	float bright = (h - 0.982) / 0.018;
	float b = smoothstep(0.16 + 0.1 * bright, 0.0, dist) * (0.35 + 1.4 * bright * bright);
	b *= 0.8 + 0.2 * sin(TIME * (2.0 + 3.0 * hash3(cell + 2.2)) + h * 80.0);
	vec3 tint = mix(vec3(0.75, 0.85, 1.0), vec3(1.0, 0.88, 0.7), hash3(cell + 5.5));
	return tint * b;
}

// La luna: disco con cráteres y mares, iluminada según la fase. Devuelve color (rgb) y cobertura (a).
vec4 moon(vec3 d) {
	vec3 m = normalize(moon_dir);
	float size = 0.06;  // radio aparente (mucho más grande que la real, como una luna saliendo)
	float md = dot(d, m);
	vec3 u = normalize(cross(m, vec3(0.0, 1.0, 0.0)));
	vec3 v = cross(u, m);
	vec2 q = vec2(dot(d, u), dot(d, v)) / size;
	float r2 = dot(q, q);
	float halo = pow(max(md, 0.0), 900.0) * 0.25 + pow(max(md, 0.0), 60.0) * 0.05;
	float full = 1.0 - abs(moon_phase * 2.0 - 1.0);
	vec3 glow = vec3(0.55, 0.65, 0.85) * halo * (0.3 + 0.7 * full);
	if (md < 0.0 || r2 > 1.0) {
		return vec4(glow, 0.0);
	}
	vec3 n = normalize(q.x * u + q.y * v - sqrt(1.0 - r2) * m);
	float a = moon_phase * 6.2831853;
	vec3 l = normalize(cos(a) * m + sin(a) * u);  // de dónde le llega el sol a la luna
	float lit = smoothstep(-0.04, 0.12, dot(n, l));
	float maria = smoothstep(0.42, 0.62, fbm(q * 1.6 + 3.0));
	float craters = fbm(q * 6.0 + 11.0);
	float albedo = (0.85 - 0.4 * maria) * (0.7 + 0.45 * craters);
	vec3 col = vec3(1.0, 0.97, 0.9) * albedo * (lit * 0.8 + 0.03) + glow;
	return vec4(col, smoothstep(1.0, 0.92, r2));
}

void sky() {
	vec3 d = EYEDIR;
	float h = max(d.y, 0.0);
	vec3 col = mix(horizon, sky_top, pow(h, 0.55));
	float sd = max(dot(d, normalize(sun_vis)), 0.0);
	// Sol: disco grande y nítido, un halo brillante y un resplandor ancho
	float disk = smoothstep(0.99935, 0.99955, sd);
	col += sun_glow * (disk * 6.0 + pow(sd, 900.0) * 2.0 + pow(sd, 60.0) * 0.4 + pow(sd, 8.0) * 0.3)
			* step(-0.05, sun_vis.y) * (1.0 - overcast);
	float night_vis = (1.0 - smoothstep(0.25, 0.55, daylight)) * (1.0 - overcast);
	if (night_vis > 0.0 && d.y > 0.0) {
		float above = smoothstep(0.0, 0.08, d.y);
		col += stars(d) * night_vis * above * 2.4;
		vec4 mn = moon(d);
		col = mix(col + mn.rgb * (1.0 - mn.a) * night_vis, mn.rgb, mn.a * night_vis * above);
	}
	if (d.y > 0.01) {
		vec2 uv = d.xz / (d.y + 0.08) * 0.9 + vec2(TIME * 0.012, TIME * 0.005);
		float c = fbm(uv * 1.4);
		float lo = mix(0.62, 0.22, clouds);
		float cover = smoothstep(lo, lo + 0.3, c) * smoothstep(0.01, 0.18, d.y);
		float shade = 0.7 + 0.3 * smoothstep(0.55, 0.95, c);
		vec3 cloud = mix(vec3(0.35, 0.38, 0.48), vec3(1.0, 0.98, 0.96), daylight) * shade + sun_glow * 0.15 * (1.0 - overcast);
		cloud = mix(cloud, vec3(0.42, 0.44, 0.48) * (0.3 + 0.7 * daylight) * shade, overcast);   // nubes grises de lluvia
		col = mix(col, cloud, cover * 0.9);
	}
	if (d.y < 0.0) {
		col = mix(horizon, horizon * 0.55, clamp(-d.y * 4.0, 0.0, 1.0));
	}
	COLOR = col;
}
