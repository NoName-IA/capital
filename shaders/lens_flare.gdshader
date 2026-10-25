// Destello del sol en la cámara: resplandor, una raya horizontal, reflejos de colores en línea hacia el centro de la
// pantalla y un velo de luz cuando se mira directo al sol. Revisa la profundidad alrededor del sol: si un edificio o
// un cerro lo tapa, el destello se apaga. Es un cuadro pegado a la cámara (como la oclusión ambiental) que suma luz.
shader_type spatial;
render_mode unshaded, blend_add, depth_draw_never, depth_test_disabled, cull_disabled, fog_disabled, shadows_disabled;

uniform sampler2D depth_tex : hint_depth_texture, filter_nearest, repeat_disable;
uniform vec3 sun_dir = vec3(0.0, 0.5, 0.8);   // hacia el sol, en el mundo
uniform float strength = 0.0;                 // 0 de noche
uniform vec3 tint = vec3(1.0, 0.9, 0.75);

void vertex() {
	POSITION = vec4(VERTEX.xy * 2.0, 0.0, 1.0);
}

float ghost(vec2 uv, vec2 c, float r, float aspect) {
	vec2 d = (uv - c) * vec2(aspect, 1.0);
	return smoothstep(r, r * 0.6, length(d));
}

void fragment() {
	vec3 vd = (VIEW_MATRIX * vec4(normalize(sun_dir), 0.0)).xyz;
	vec3 col = vec3(0.0);
	if (vd.z < 0.0 && strength > 0.0) {
		vec4 clip = PROJECTION_MATRIX * vec4(vd * 100.0, 1.0);
		vec2 s = clip.xy / clip.w * 0.5 + 0.5;
		float aspect = VIEWPORT_SIZE.x / VIEWPORT_SIZE.y;
		// ¿Se ve el cielo en el sol y alrededor? Donde no hay nada dibujado la profundidad queda en un extremo
		// (en el modo Compatibilidad el cielo no la escribe y queda en 0)
		float vis = 0.0;
		for (int i = 0; i < 9; i++) {
			vec2 o = vec2(float(i % 3) - 1.0, float(i / 3) - 1.0) * vec2(0.006 / aspect, 0.006);
			vec2 p = s + o;
			bool inside = p.x > 0.0 && p.x < 1.0 && p.y > 0.0 && p.y < 1.0;
			float dz = texture(depth_tex, p).r;
			vis += inside && (dz < 0.00001 || dz > 0.99999) ? 1.0 : 0.0;
		}
		vis /= 9.0;
		float edge = smoothstep(-0.25, 0.1, min(min(s.x, 1.0 - s.x), min(s.y, 1.0 - s.y)));
		float k = vis * edge * strength;
		if (k > 0.001) {
			vec2 uv = SCREEN_UV;
			vec2 d = (uv - s) * vec2(aspect, 1.0);
			float dist = length(d);
			col += tint * (exp(-dist * 9.0) * 0.9 + exp(-dist * 2.5) * 0.12);           // resplandor
			col += tint * exp(-abs(d.y) * 140.0) * exp(-abs(d.x) * 2.2) * 0.35;          // raya horizontal
			vec2 axis = vec2(0.5) - s;                                                   // hacia el centro
			col += vec3(0.4, 0.8, 1.0) * ghost(uv, s + axis * 0.55, 0.035, aspect) * 0.16;
			col += vec3(1.0, 0.6, 0.3) * ghost(uv, s + axis * 0.9, 0.06, aspect) * 0.11;
			col += vec3(0.5, 1.0, 0.6) * ghost(uv, s + axis * 1.35, 0.025, aspect) * 0.18;
			col += vec3(0.7, 0.5, 1.0) * ghost(uv, s + axis * 1.7, 0.1, aspect) * 0.08;
			col += vec3(1.0, 0.85, 0.5) * ghost(uv, s + axis * 2.2, 0.045, aspect) * 0.12;
			float ring = abs(length((uv - vec2(0.5) - axis * 0.2) * vec2(aspect, 1.0)) - 0.32);
			col += vec3(0.6, 0.7, 1.0) * smoothstep(0.02, 0.0, ring) * 0.03;           // aro
			float look = clamp(1.0 - length(s - vec2(0.5)) * 1.6, 0.0, 1.0);
			col += tint * look * look * 0.18;                                            // velo al mirar al sol
			col *= k;
		}
	}
	ALBEDO = col;
}
