// Material de todo lo sólido de la ciudad (reemplaza al StandardMaterial3D): color de los vértices, textura, y la luz
// de las lámparas calculada como en NoName-Shader (la luz de bloque de Minecraft):
//  - cada luz tiene un nivel (15 = farol) que baja 1 por metro de distancia;
//  - no se suman: en cada punto gana la luz más fuerte;
//  - el nivel pasa por una curva al cuadrado: cerca alumbra fuerte y se apaga rápido;
//  - multiplica el color de lo que alumbra (lo oscuro sigue oscuro);
//  - de día, a cielo abierto, la luz del cielo tapa a las lámparas (nivel - cielo × día × 0,5);
//  - color cálido: naranja en el borde de la luz y blanco cálido cerca de la lámpara;
//  - no atraviesa paredes: las luces de adentro alumbran solo su local y las de afuera solo afuera.
// Como en Minecraft, la luz está guardada en una grilla (celdas de 2 m, ver CityLights) y cada cara lee la celda de
// enfrente: r = luz de afuera, g = luz de adentro de los locales. Lo que se mueve (focos de los autos) llega aparte en
// city_lights: fila 0 posición y nivel; filas 2 y 3 los locales (x0, x1, z0, z1 y altura del techo).
shader_type spatial;
render_mode blend_mix, depth_draw_opaque, cull_back, diffuse_burley, specular_schlick_ggx;

uniform vec4 albedo : source_color = vec4(1.0);
uniform sampler2D texture_albedo : source_color, filter_linear_mipmap_anisotropic, repeat_enable;
uniform bool use_texture = false;
uniform vec3 uv1_scale = vec3(1.0);
uniform float roughness : hint_range(0.0, 1.0) = 0.85;
uniform float metallic : hint_range(0.0, 1.0) = 0.0;
uniform float specular : hint_range(0.0, 1.0) = 0.35;
uniform vec3 emission : source_color = vec3(0.0);
uniform float emission_energy = 0.0;

global uniform sampler3D city_light_grid : filter_linear, repeat_disable;
global uniform vec3 city_grid_origin;
global uniform vec3 city_grid_size;
global uniform float city_lamps_on;   // faroles y focos de afuera: 0 de día, 1 de noche
global uniform sampler2D city_lights : filter_nearest;
global uniform int city_light_count;
global uniform int city_room_count;
global uniform float city_daylight;   // 0 de noche, 1 de día
global uniform float city_block_light; // fuerza de la luz de las lámparas (Gráficos)

varying vec3 world_pos;
varying vec3 world_normal;

void vertex() {
	UV = UV * uv1_scale.xy;
	// Los colores de los vértices están escritos en sRGB (como vertex_color_is_srgb del material estándar)
	COLOR.rgb = mix(pow((COLOR.rgb + vec3(0.055)) * (1.0 / 1.055), vec3(2.4)), COLOR.rgb * (1.0 / 12.92),
			lessThan(COLOR.rgb, vec3(0.04045)));
	world_pos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	world_normal = normalize((MODEL_MATRIX * vec4(NORMAL, 0.0)).xyz);
}

// En qué local está el punto (-1 = afuera, bajo el cielo)
int room_of(vec3 p) {
	for (int i = 0; i < city_room_count; i++) {
		vec4 r = texelFetch(city_lights, ivec2(i, 2), 0);
		float top = texelFetch(city_lights, ivec2(i, 3), 0).x;
		if (p.x > r.x && p.x < r.y && p.z > r.z && p.z < r.w && p.y < top) {
			return i;
		}
	}
	return -1;
}

void fragment() {
	vec4 base = albedo * COLOR;
	if (use_texture) {
		base *= texture(texture_albedo, UV);
	}
	ALBEDO = base.rgb;
	ROUGHNESS = roughness;
	METALLIC = metallic;
	SPECULAR = specular;

	vec3 t = (world_pos + world_normal * 0.6 - city_grid_origin) / city_grid_size;   // la celda de enfrente de la cara
	vec2 cell = texture(city_light_grid, vec3(t.x, t.z, t.y)).rg;
	// ¿Adentro de un local? Solo hace falta saberlo cerca de una luz de adentro. Se mide un poco hacia donde mira la
	// cara: el techo y las paredes de adentro quedan adentro, las de afuera, afuera.
	int room = cell.g > 0.002 ? room_of(world_pos + world_normal * 0.1) : -1;
	float level = room < 0 ? cell.r * city_lamps_on : cell.g;
	if (room < 0 && city_lamps_on > 0.01) {
		for (int i = 0; i < city_light_count; i++) {   // focos de los autos
			vec4 l = texelFetch(city_lights, ivec2(i, 0), 0);
			level = max(level, (l.w - distance(world_pos, l.xyz)) / 15.0 * city_lamps_on);
		}
	}
	level = clamp(level, 0.0, 1.0);
	float sky = room < 0 ? 1.0 : 0.0;
	float block = max(level - sky * city_daylight * 0.5, 0.0);
	block *= block;
	vec3 tint = mix(vec3(1.0, 0.62, 0.32), vec3(1.0, 0.86, 0.72), sqrt(level));   // menos naranja que en Minecraft: la madera y la arena se ponían rojas
	float face = 0.75 + 0.25 * world_normal.y;   // como en Minecraft: arriba más claro, abajo más oscuro
	EMISSION = ALBEDO * tint * block * face * city_block_light + emission * emission_energy;
}
