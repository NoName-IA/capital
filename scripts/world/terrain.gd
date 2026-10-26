class_name Terrain
extends RefCounted
## Terreno alrededor de la ciudad (como terreno.py). La calle y los barrios donde caminas quedan planos (altura 0);
## afuera hay cerros con nieve al norte y al oeste, lomas al sur y la playa con el mar al este.

const SEA_LEVEL := -0.6
const FLAT_WEST := -118.0   # al oeste de esto empiezan los cerros
const COAST := 160.0        # al este de esto el suelo baja hacia el mar
const BEACH_START := 110.0  # desde aquí el suelo es arena (terrenos de la playa)
const FLAT_Z := 64.0        # más allá de |z| empiezan las lomas
const TUNNEL_X := -165.0    # al oeste la avenida entra a un túnel que atraviesa la montaña

static var soft: FastNoiseLite
static var ridge: FastNoiseLite
static var tint: FastNoiseLite


static func _setup() -> void:
	if soft:
		return
	soft = FastNoiseLite.new()
	soft.seed = 5
	soft.noise_type = FastNoiseLite.TYPE_VALUE_CUBIC
	soft.frequency = 0.011
	soft.fractal_octaves = 5
	ridge = FastNoiseLite.new()
	ridge.seed = 9
	ridge.noise_type = FastNoiseLite.TYPE_PERLIN
	ridge.frequency = 0.006
	ridge.fractal_type = FastNoiseLite.FRACTAL_RIDGED
	ridge.fractal_octaves = 4
	tint = FastNoiseLite.new()
	tint.seed = 3
	tint.frequency = 0.05


static func sstep(a: float, b: float, x: float) -> float:
	var t := clampf((x - a) / (b - a), 0.0, 1.0)
	return t * t * (3.0 - 2.0 * t)


static func height(x: float, z: float) -> float:
	_setup()
	var west: float = max(0.0, FLAT_WEST - x)
	var out_z: float = max(0.0, absf(z) - FLAT_Z)
	var d := sqrt(west * west + out_z * out_z)
	if d <= 0.0 and x < COAST:
		return 0.0
	var amp := (78.0 if z > 0 else 36.0) + 26.0 * sstep(-130, -260, x)   # cordillera al norte y al oeste
	var s := soft.get_noise_2d(x, z) * 0.5 + 0.5
	var r := clampf(ridge.get_noise_2d(x, z) * 0.5 + 0.5, 0.0, 1.0)
	var hills := (0.45 * s + 0.55 * r * r) * amp
	var h := hills * sstep(0, 75, d)
	# La avenida sigue hacia el oeste por un valle entre los cerros (y se pierde de vista detrás de ellos)
	if x < FLAT_WEST:
		h *= lerpf(sstep(26, 46, absf(z)), 1.0, sstep(-230, -280, x))   # ancho para los locales de la entrada
	var sea := sstep(COAST, COAST + 46, x)
	return h * (1 - sea) - 9.0 * sea


## La montaña del túnel: una cumbre redondeada al oeste que cruza el valle de la avenida. Por delante baja hasta
## apoyarse en el muro de la boca (ver WorldBuilder._tunnel): ahí queda a la altura de PORTAL_TOP y no tapa la
## entrada; por encima del túnel nunca baja del techo. A los costados se junta con los cerros.
const PORTAL_TOP := 13.0
const PORTAL_HALF := 9.3   # ancho medio de la entrada
const PORTAL_WING := 19.0  # el muro de la boca llega hasta aquí a cada lado


static func mountain_height(x: float, z: float) -> float:
	_setup()
	var az := absf(z)
	var s := soft.get_noise_2d(x * 1.7, z * 1.7) * 0.5 + 0.5
	var k := clampf(ridge.get_noise_2d(x * 2.0, z * 2.0) * 0.5 + 0.5, 0.0, 1.0)
	# El contorno se deforma con ruido para que no quede como un domo liso
	var r := Vector2((x + 212.0) / 52.0, z / 75.0).length() * (1.0 + 0.16 * soft.get_noise_2d(x * 3.1 + 70.0, z * 3.1))
	var m: float = (30.0 + 14.0 * s + 16.0 * k * k) * max(0.0, 1.0 - r * r) * sstep(1.0, 0.8, r)
	m += 3.5 * soft.get_noise_2d(x * 6.0, z * 6.0) * sstep(1.0, 0.6, r)   # lomitas y quebradas
	m *= 1.0 - (1.0 - sstep(PORTAL_WING, PORTAL_WING + 8.0, az)) * sstep(TUNNEL_X - 2.5, TUNNEL_X - 1.5, x)
	if az < PORTAL_WING + 1.0 and x < TUNNEL_X - 2.5:
		m = min(m, PORTAL_TOP - 0.2) if x > TUNNEL_X - 4.0 else m
		if az < PORTAL_HALF + 1.0:
			m = max(m, 8.2)   # sobre el techo del túnel
	return max(height(x, z), m) - 0.4


## Celdas de la montaña que no se dibujan: justo detrás de la entrada, donde el terreno sube de golpe (lo tapa el muro).
static func mountain_hole(x: float, z: float) -> bool:
	return absf(z) < PORTAL_HALF + 1.5 and TUNNEL_X - 3.0 < x and x < TUNNEL_X - 1.0


## Pasto en lo plano, pasto oscuro en los cerros, roca en lo empinado, nieve arriba y arena en la costa.
static func ground_color(x: float, z: float, h: float, slope: float) -> Color:
	var v := tint.get_noise_2d(x, z) * 0.5 + 0.5
	var grass := Color(0.40, 0.58, 0.27) * (0.9 + 0.2 * v)
	var hill := Color(0.29, 0.46, 0.22) * (0.85 + 0.3 * v)
	var rock := Color(0.52, 0.50, 0.46) * (0.9 + 0.2 * v)
	var snow := Color(0.95, 0.96, 0.99)
	var sand := Color(0.88, 0.81, 0.62) * (0.95 + 0.1 * v)
	var wet := Color(0.62, 0.56, 0.42)
	var c := grass.lerp(hill, sstep(0.5, 6.0, h))
	c = c.lerp(rock, max(sstep(0.45, 0.8, slope), sstep(30, 48, h)))
	c = c.lerp(snow, sstep(52, 64, h) * (1 - sstep(0.9, 1.3, slope)))
	c = c.lerp(sand, sstep(BEACH_START - 6, BEACH_START, x) * (1 - sstep(1.0, 2.5, h)))
	c = c.lerp(wet, sstep(SEA_LEVEL + 0.2, SEA_LEVEL - 1.5, h))
	c.a = 1.0
	return c


static func build_mesh(step := 8.0, half_x := 540.0, half_z := 460.0) -> ArrayMesh:
	return build_patch(-half_x, -half_z, half_x * 2, half_z * 2, step, height)


## Malla de terreno de (x0, z0) a (x0 + size_x, z0 + size_z) con la altura que da `fn(x, z)`.
## `hole(x, z)` (opcional) dice qué celdas no se dibujan, según su centro.
static func build_patch(x0: float, z0: float, size_x: float, size_z: float, step: float, fn: Callable,
		hole := Callable()) -> ArrayMesh:
	_setup()
	var nx := int(size_x / step) + 1
	var nz := int(size_z / step) + 1
	var hs := PackedFloat32Array()
	hs.resize(nx * nz)
	for j in nz:
		for i in nx:
			hs[j * nx + i] = fn.call(x0 + i * step, z0 + j * step)
	var verts := PackedVector3Array()
	var normals := PackedVector3Array()
	var colors := PackedColorArray()
	var uvs := PackedVector2Array()
	for j in nz:
		for i in nx:
			var x := x0 + i * step
			var z := z0 + j * step
			var h: float = hs[j * nx + i]
			var hx: float = hs[j * nx + min(i + 1, nx - 1)] - hs[j * nx + max(i - 1, 0)]
			var hz: float = hs[min(j + 1, nz - 1) * nx + i] - hs[max(j - 1, 0) * nx + i]
			var n := Vector3(-hx / (2 * step), 1.0, -hz / (2 * step)).normalized()
			var slope := Vector2(hx, hz).length() / (2 * step)
			verts.append(Vector3(x, h, z))
			normals.append(n)
			colors.append(ground_color(x, z, h, slope))
			uvs.append(Vector2(x, z) / 5.0)
	var idx := PackedInt32Array()
	for j in nz - 1:
		for i in nx - 1:
			if hole.is_valid() and hole.call(x0 + (i + 0.5) * step, z0 + (j + 0.5) * step):
				continue
			var a := j * nx + i
			var b := a + 1
			var c := a + nx
			var d := c + 1
			idx.append_array([a, b, c, b, d, c])
	var arr := []
	arr.resize(Mesh.ARRAY_MAX)
	arr[Mesh.ARRAY_VERTEX] = verts
	arr[Mesh.ARRAY_NORMAL] = normals
	arr[Mesh.ARRAY_COLOR] = colors
	arr[Mesh.ARRAY_TEX_UV] = uvs
	arr[Mesh.ARRAY_INDEX] = idx
	var m := ArrayMesh.new()
	m.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arr)
	return m
