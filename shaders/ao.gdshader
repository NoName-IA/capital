// Oclusión ambiental en pantalla: oscurece rincones, la base de las paredes, debajo de los árboles y entre objetos
// cercanos, como hace la luz de verdad. Es un cuadro que tapa la pantalla, lee la profundidad de la escena y pinta
// negro semitransparente donde hay oclusión (el modo Compatibilidad no trae SSAO propio, y como ahí cada objeto pasa
// por el tonemap, multiplicar por blanco no daría blanco: el negro sí sigue negro). Solo en gráficos altos.
shader_type spatial;
render_mode unshaded, blend_mix, depth_draw_never, depth_test_disabled, cull_disabled, fog_disabled, shadows_disabled;

uniform sampler2D depth_tex : hint_depth_texture, filter_nearest, repeat_disable;
uniform float radius = 1.1;       // metros alrededor de cada punto que se revisan
uniform float strength = 2.2;
uniform float max_distance = 90.0;
const int SAMPLES = 8;

void vertex() {
	POSITION = vec4(VERTEX.xy * 2.0, 0.0, 1.0);  // tapa toda la pantalla, sin importar la cámara
}

vec3 view_pos(vec2 uv, mat4 inv_proj) {
	float d = texture(depth_tex, uv).r;
	vec4 v = inv_proj * vec4(vec3(uv, d) * 2.0 - 1.0, 1.0);
	return v.xyz / v.w;
}

void fragment() {
	vec3 p = view_pos(SCREEN_UV, INV_PROJECTION_MATRIX);
	vec3 n = normalize(cross(dFdx(p), dFdy(p)));
	n = dot(n, p) > 0.0 ? -n : n;  // que mire hacia la cámara
	// Cada píxel de un cuadro de 2×2 gira las muestras distinto; al final se promedian los 4 (sin ruido visible)
	vec2 q = mod(floor(FRAGCOORD.xy), 2.0);
	float k = (q.x + 2.0 * q.y) * 0.25;
	float occ = 0.0;
	bool sky = texture(depth_tex, SCREEN_UV).r < 0.00001;  // el cielo no escribe profundidad
	if (!sky && -p.z < max_distance) {
		float r = radius * PROJECTION_MATRIX[1][1] * 0.5 / -p.z;  // radio en pantalla según la distancia
		for (int i = 0; i < SAMPLES; i++) {
			float t = (float(i) + 0.5 + k) / float(SAMPLES);
			float a = (float(i) + k) * 2.3999632;  // ángulo dorado
			vec2 off = vec2(cos(a) * VIEWPORT_SIZE.y / VIEWPORT_SIZE.x, sin(a)) * r * sqrt(t);
			vec3 s = view_pos(SCREEN_UV + off, INV_PROJECTION_MATRIX) - p;
			float len = length(s);
			float fall = 1.0 - smoothstep(radius * 0.6, radius * 1.6, len);
			occ += max(dot(n, s / max(len, 0.0001)) - 0.32, 0.0) * fall;  // el margen evita ruido en superficies planas
		}
		occ = occ / float(SAMPLES) * strength * (1.0 - smoothstep(max_distance * 0.6, max_distance, -p.z));
	}
	// Promedio del cuadro de 2×2 con las derivadas (dFdx da la diferencia con el vecino de al lado)
	vec2 side = 1.0 - 2.0 * q;
	occ += 0.5 * dFdx(occ) * side.x + 0.5 * dFdy(occ) * side.y;
	ALBEDO = vec3(0.0);
	ALPHA = clamp(occ, 0.0, 0.65);
}
