class_name Terrain
extends RefCounted
## Terreno alrededor de la ciudad (como terreno.py). La calle y los barrios donde caminas quedan planos (altura 0);
## afuera hay cerros con nieve al norte y al oeste, lomas al sur y la playa con el mar al este.

const SEA_LEVEL := -0.6
const FLAT_WEST := -118.0   # al oeste de esto empiezan los cerros
const COAST := 160.0        # al este de esto el suelo baja hacia el mar
const BEACH_START := 110.0  # desde aquí el suelo es arena (terrenos de la playa)
const FLAT_Z := 64.0        # más allá de |z| empiezan las lomas

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
	var sea := sstep(COAST, COAST + 46, x)
	return h * (1 - sea) - 9.0 * sea


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
	_setup()
	var nx := int(half_x * 2 / step) + 1
	var nz := int(half_z * 2 / step) + 1
	var hs := PackedFloat32Array()
	hs.resize(nx * nz)
	for j in nz:
		for i in nx:
			hs[j * nx + i] = height(-half_x + i * step, -half_z + j * step)
	var verts := PackedVector3Array()
	var normals := PackedVector3Array()
	var colors := PackedColorArray()
	var uvs := PackedVector2Array()
	for j in nz:
		for i in nx:
			var x := -half_x + i * step
			var z := -half_z + j * step
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
