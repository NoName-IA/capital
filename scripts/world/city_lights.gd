class_name CityLights
extends RefCounted
## La luz de las lámparas como en Minecraft (y en NoName-Shader): se calcula una vez en una grilla de celdas de 2 m que
## cubre la ciudad, y cada píxel lee la celda de enfrente de su cara (ver shaders/world.gdshader). Cada celda guarda
## dos niveles: la luz de afuera (faroles, focos; se prende de noche) y la de adentro de los locales (siempre prendida).
## Las paredes cortan la luz: las lámparas de un local solo llenan las celdas de ese local y las de afuera no entran.
## Lo que se mueve (los focos de los autos) no va en la grilla: el shader lo calcula aparte (MAX_MOVING luces).
## Las luces se registran con Mats.add_light; al abrir o cerrar un local se recalcula solo esa zona.

const ORIGIN := Vector3(-168.0, -2.0, -80.0)
const CELL := 2.0
const NX := 208   # x de -168 a 248
const NY := 12    # y de -2 a 22
const NZ := 84    # z de -80 a 88
const MAX_MOVING := 8
const MAX_ROOMS := 40   # locales, megatiendas, la competencia y la oficina (antes 16: con muchos abiertos, algunos quedaban a oscuras)
const STRENGTH := 3.5   # fuerza de la luz de las lámparas sobre los colores

var grid := PackedByteArray()   # 2 bytes por celda: afuera, adentro (0 a 255 = nivel 0 a 15)
var deep := PackedByteArray()   # 1 = celda bien adentro de un local: ahí no llega la luz de afuera
var grid_tex: ImageTexture3D
var baked := {}                 # id del nodo -> [posición, nivel, adentro] tal como quedó en la grilla
var rooms_now := []
var moving_img := Image.create(MAX_ROOMS, 4, false, Image.FORMAT_RGBAF)
var moving_tex := ImageTexture.create_from_image(moving_img)


func _init() -> void:
	grid.resize(NX * NY * NZ * 2)
	deep.resize(NX * NY * NZ)
	RenderingServer.global_shader_parameter_set("city_lights", moving_tex)
	RenderingServer.global_shader_parameter_set("city_block_light", STRENGTH)
	RenderingServer.global_shader_parameter_set("city_grid_origin", ORIGIN)
	RenderingServer.global_shader_parameter_set("city_grid_size", Vector3(NX, NY, NZ) * CELL)
	_upload()


## Cada cuadro: `rooms` son los techos de los locales y la oficina, [x0, x1, z0, z1, altura] (los de City.ceiling_over).
func update(cam: Vector3, rooms: Array) -> void:
	var dirty := []   # zonas a recalcular: [mínimo, máximo] en el mundo
	if rooms != rooms_now:
		for r in rooms + rooms_now:
			if not (r in rooms and r in rooms_now):   # local nuevo o que ya no está
				dirty.append([Vector3(r[0] - 16, -10, r[2] - 16), Vector3(r[1] + 16, 40, r[3] + 16)])
		rooms_now = rooms.duplicate(true)
		_mark_deep()
	var alive := []
	var seen := {}
	var moving := []
	for l in Mats.lights:
		if not is_instance_valid(l[0]):   # el local o el auto ya no está
			continue
		var n: Node3D = l[0]
		alive.append(l)
		if l[3]:   # se mueve: va aparte
			if Mats.lamps_on > 0.01 and n.is_visible_in_tree():
				var p := n.global_position
				moving.append([p.distance_to(cam) - l[1], p, l[1]])
			continue
		var id := n.get_instance_id()
		seen[id] = true
		if not baked.has(id):
			var p := n.global_position
			baked[id] = [p, l[1], l[2]]
			dirty.append(_reach(p, l[1]))
	for id in baked.keys():
		if not seen.has(id):   # el local se vendió o se reemplazó
			dirty.append(_reach(baked[id][0], baked[id][1]))
			baked.erase(id)
	if alive.size() != Mats.lights.size():
		Mats.lights = alive
	if dirty.size() > 24:   # al empezar: toda la ciudad de una vez
		grid.fill(0)
		for b in baked.values():
			_bake(b, _reach(b[0], b[1]))
		_upload()
	elif not dirty.is_empty():
		for box in dirty:
			_clear(box)
			for b in baked.values():
				var reach := _reach(b[0], b[1])
				if reach[0].x < box[1].x and box[0].x < reach[1].x and reach[0].z < box[1].z and box[0].z < reach[1].z:
					_bake(b, box)
		_upload()
	# Las luces que se mueven: las más cercanas a la cámara
	moving.sort_custom(func(a, b): return a[0] < b[0])
	var count := mini(moving.size(), MAX_MOVING)
	for i in count:
		var p: Vector3 = moving[i][1]
		moving_img.set_pixel(i, 0, Color(p.x, p.y, p.z, moving[i][2]))
	for i in mini(rooms.size(), MAX_ROOMS):
		var r: Array = rooms[i]
		moving_img.set_pixel(i, 2, Color(r[0], r[1], r[2], r[3]))
		moving_img.set_pixel(i, 3, Color(r[4], 0, 0, 0))
	moving_tex.update(moving_img)
	RenderingServer.global_shader_parameter_set("city_light_count", count)
	RenderingServer.global_shader_parameter_set("city_room_count", mini(rooms.size(), MAX_ROOMS))
	RenderingServer.global_shader_parameter_set("city_lamps_on", Mats.lamps_on)


func _reach(p: Vector3, level: float) -> Array:
	return [p - Vector3.ONE * level, p + Vector3.ONE * level]


func _cells(box: Array) -> Array:
	var a: Vector3 = (box[0] - ORIGIN) / CELL
	var b: Vector3 = (box[1] - ORIGIN) / CELL
	return [maxi(0, floori(a.x)), mini(NX - 1, floori(b.x)), maxi(0, floori(a.y)), mini(NY - 1, floori(b.y)),
			maxi(0, floori(a.z)), mini(NZ - 1, floori(b.z))]


func _clear(box: Array) -> void:
	var c := _cells(box)
	for y in range(c[2], c[3] + 1):
		for z in range(c[4], c[5] + 1):
			var i: int = ((y * NZ + z) * NX + c[0]) * 2
			for x in range(c[0], c[1] + 1):
				grid[i] = 0
				grid[i + 1] = 0
				i += 2


## Celdas bien adentro de un local (a más de 1 m de las paredes): ahí no entra la luz de afuera.
func _mark_deep() -> void:
	deep.fill(0)
	for r in rooms_now:
		var c := _cells([Vector3(r[0], -10, r[2]), Vector3(r[1], r[4], r[3])])
		for y in range(c[2], c[3] + 1):
			for z in range(c[4], c[5] + 1):
				for x in range(c[0], c[1] + 1):
					var q := _center(x, y, z)
					if r[0] + 1 < q.x and q.x < r[1] - 1 and r[2] + 1 < q.z and q.z < r[3] - 1 and q.y < r[4] - 1:
						deep[(y * NZ + z) * NX + x] = 1


func _center(x: int, y: int, z: int) -> Vector3:
	return ORIGIN + (Vector3(x, y, z) + Vector3(0.5, 0.5, 0.5)) * CELL


## Llena las celdas de `box` con una luz: nivel - distancia (como la luz de bloque), gana la más fuerte.
func _bake(b: Array, box: Array) -> void:
	var p: Vector3 = b[0]
	var level: float = b[1]
	var indoor: bool = b[2]
	var lo: Vector3 = box[0]
	var hi: Vector3 = box[1]
	if indoor:   # solo dentro de su local (con 1 m de margen, para que las caras junto a la pared lean bien)
		var room = null
		for r in rooms_now:
			if r[0] < p.x and p.x < r[1] and r[2] < p.z and p.z < r[3] and p.y < r[4]:
				room = r
				break
		if room == null:
			return
		lo = Vector3(maxf(lo.x, room[0] - 1), lo.y, maxf(lo.z, room[2] - 1))
		hi = Vector3(minf(hi.x, room[1] + 1), minf(hi.y, room[4] + 1), minf(hi.z, room[3] + 1))
	var reach := _reach(p, level)
	lo = Vector3(maxf(lo.x, reach[0].x), maxf(lo.y, reach[0].y), maxf(lo.z, reach[0].z))
	hi = Vector3(minf(hi.x, reach[1].x), minf(hi.y, reach[1].y), minf(hi.z, reach[1].z))
	if lo.x > hi.x or lo.y > hi.y or lo.z > hi.z:
		return
	var c := _cells([lo, hi])
	var l2 := level * level
	var ch := 1 if indoor else 0
	for y in range(c[2], c[3] + 1):
		var dy := ORIGIN.y + (y + 0.5) * CELL - p.y
		var dy2 := dy * dy
		if dy2 >= l2:
			continue
		for z in range(c[4], c[5] + 1):
			var dz := ORIGIN.z + (z + 0.5) * CELL - p.z
			var dyz := dy2 + dz * dz
			if dyz >= l2:
				continue
			var row := (y * NZ + z) * NX
			for x in range(c[0], c[1] + 1):
				var dx := ORIGIN.x + (x + 0.5) * CELL - p.x
				var d2 := dyz + dx * dx
				if d2 >= l2 or (not indoor and deep[row + x] == 1):
					continue
				var v := mini(255, int((level - sqrt(d2)) * 17.0))
				var k := (row + x) * 2 + ch
				if v > grid[k]:
					grid[k] = v


## Sube la grilla a la textura 3D (una imagen por cada capa de altura).
func _upload() -> void:
	var slices: Array[Image] = []
	var size := NX * NZ * 2
	for y in NY:
		slices.append(Image.create_from_data(NX, NZ, false, Image.FORMAT_RG8, grid.slice(y * size, (y + 1) * size)))
	if grid_tex == null:
		grid_tex = ImageTexture3D.new()
		grid_tex.create(Image.FORMAT_RG8, NX, NZ, NY, false, slices)
		RenderingServer.global_shader_parameter_set("city_light_grid", grid_tex)
	else:
		grid_tex.update(slices)
