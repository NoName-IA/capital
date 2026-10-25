// Desenfoque del juego detrás de los menús (como un vidrio esmerilado). amount = 0 no hace nada.
shader_type canvas_item;

uniform sampler2D screen_tex : hint_screen_texture, filter_linear;
uniform float amount = 0.0;

void fragment() {
	if (amount < 0.01) {
		discard;
	}
	vec2 px = amount * 3.2 * SCREEN_PIXEL_SIZE;
	vec3 acc = vec3(0.0);
	float total = 0.0;
	for (int x = -2; x <= 2; x++) {
		for (int y = -2; y <= 2; y++) {
			float w = exp(-float(x * x + y * y) / 4.5);
			acc += texture(screen_tex, SCREEN_UV + vec2(float(x), float(y)) * px).rgb * w;
			total += w;
		}
	}
	COLOR = vec4(acc / total, 1.0);
}
