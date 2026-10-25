class_name Blueprints
extends RefCounted
## Planos de los edificios (coordenadas locales: x a lo ancho, z hacia adentro del terreno, y hacia arriba).
## Cada caja: [centro, tamaño, color, choca]. Igual que en la versión de Python.

const FRONT := 9.0        # distancia del centro de la calle al frente de los terrenos
const PALETTE := {
	"wall": Color8(232, 226, 214), "roof": Color8(70, 74, 82), "glass": Color8(150, 200, 230), "floor": Color8(200, 190, 170),
	"wood": Color8(140, 100, 65), "dark": Color8(40, 42, 48), "shelf": Color8(190, 180, 165), "white": Color8(245, 245, 245),
	"gold": Color8(227, 179, 65), "green": Color8(60, 150, 80),
	# Oficina central
	"hq_stone": Color8(70, 78, 92), "hq_trim": Color8(38, 42, 52), "hq_glass": Color8(80, 125, 170), "hq_wood": Color8(95, 60, 40),
	"hq_sofa": Color8(45, 70, 110), "marble": Color8(225, 222, 215), "carpet": Color8(150, 40, 45), "plant": Color8(60, 135, 70),
	"art1": Color8(210, 120, 70), "art2": Color8(80, 150, 190),
	"lamp": Color8(255, 240, 215),   # paneles de luz del techo
	"crate": Color8(176, 132, 82),   # cajas de cartón de la bodega
}
const PRODUCT_COLORS := {"cafe": Color8(150, 95, 55), "pan": Color8(225, 170, 80), "burger": Color8(210, 70, 50),
		"ropa": Color8(150, 95, 195), "tech": Color8(60, 130, 215)}
const GLASS_KEYS := ["glass", "hq_glass"]


static func B(c: Array, s: Array, key: String, solid := false) -> Array:
	return [Vector3(c[0], c[1], c[2]), Vector3(s[0], s[1], s[2]), key, solid]


## Oficina central: torre corporativa de vidrio. Solo el vestíbulo (planta baja) se puede recorrer.
static func hq() -> Array:
	var w := 16.0
	var depth := 14.0
	var h := 21.0
	var lobby := 4.8
	var door := 4.0
	var door_h := 3.4
	var z0 := 2.0
	var z1 := z0 + depth
	var zc := (z0 + z1) / 2
	var side_w := (w - door) / 2
	var sx_door := (door + side_w) / 2
	var boxes := [
		# Estructura: muros de piedra de toda la altura (también frenan la cámara)
		B([0, h / 2, z1], [w, h, 0.4], "hq_stone", true),
		B([-w / 2, h / 2, zc], [0.4, h, depth], "hq_stone", true),
		B([w / 2, h / 2, zc], [0.4, h, depth], "hq_stone", true),
		B([-sx_door, h / 2, z0], [side_w, h, 0.4], "hq_stone", true),
		B([sx_door, h / 2, z0], [side_w, h, 0.4], "hq_stone", true),
		B([0, (h + door_h) / 2, z0], [door, h - door_h, 0.4], "hq_stone"),
		B([0, h + 0.25, zc], [w + 0.8, 0.5, depth + 0.8], "hq_trim"),
		B([0, h + 0.9, zc + 2], [6, 0.8, 5], "hq_stone"),               # sala de máquinas en el techo
		B([0, lobby, zc], [w - 0.4, 0.2, depth - 0.4], "white"),          # cielo del vestíbulo
		B([-4, lobby - 0.13, 5], [2.4, 0.06, 0.7], "lamp"), B([4, lobby - 0.13, 5], [2.4, 0.06, 0.7], "lamp"),
		B([-4, lobby - 0.13, 9.5], [2.4, 0.06, 0.7], "lamp"), B([4, lobby - 0.13, 9.5], [2.4, 0.06, 0.7], "lamp"),
		B([-4, lobby - 0.13, 13.5], [2.4, 0.06, 0.7], "lamp"), B([4, lobby - 0.13, 13.5], [2.4, 0.06, 0.7], "lamp"),
		B([0, 0.03, zc], [w - 0.4, 0.06, depth - 0.4], "marble"),
		# Entrada: marco dorado, marquesina con columnas, escalón y alfombra
		B([-door / 2 - 0.1, door_h / 2, z0 - 0.25], [0.2, door_h, 0.2], "gold"),
		B([door / 2 + 0.1, door_h / 2, z0 - 0.25], [0.2, door_h, 0.2], "gold"),
		B([0, door_h + 0.1, z0 - 0.25], [door + 0.4, 0.2, 0.2], "gold"),
		B([0, 4.0, z0 - 1.5], [7, 0.22, 3.0], "hq_trim"),
		B([0, 3.86, z0 - 1.5], [6.6, 0.06, 2.7], "gold"),
		B([-3.2, 1.95, z0 - 2.8], [0.2, 3.9, 0.2], "gold", true),
		B([3.2, 1.95, z0 - 2.8], [0.2, 3.9, 0.2], "gold", true),
		B([0, 0.06, z0 - 1.4], [7, 0.12, 3.2], "marble"),
		B([0, 0.13, z0 - 1.4], [2.6, 0.02, 3.0], "carpet"),
		# Afuera: maceteros con arbustos y mástiles con banderas
		B([-6, 0.4, z0 - 1.6], [2.2, 0.8, 1.0], "hq_stone", true),
		B([6, 0.4, z0 - 1.6], [2.2, 0.8, 1.0], "hq_stone", true),
		B([-6, 1.05, z0 - 1.6], [1.9, 0.6, 0.8], "plant"),
		B([6, 1.05, z0 - 1.6], [1.9, 0.6, 0.8], "plant"),
		B([-7.6, 4.5, z0 - 3.2], [0.12, 9, 0.12], "white", true),
		B([7.6, 4.5, z0 - 3.2], [0.12, 9, 0.12], "white", true),
		B([-7.0, 8.4, z0 - 3.2], [1.2, 0.8, 0.04], "gold"),
		B([8.2, 8.4, z0 - 3.2], [1.2, 0.8, 0.04], "green"),
		# Vestíbulo: alfombra, mostrador de recepción, escritorio con la computadora, sala de espera
		B([0, 0.07, 6.5], [4, 0.02, 8], "carpet"),
		B([0, 0.4, 9], [3.4, 0.8, 1.4], "hq_wood", true),
		B([0, 0.82, 9], [3.6, 0.06, 1.6], "gold"),
		B([0, 1.35, 9.4], [1.4, 0.85, 0.08], "dark"),
		B([0, 0.55, 10.4], [0.9, 1.1, 0.8], "dark"),
		B([-5.9, 0.35, 6.5], [1.4, 0.7, 3.6], "hq_sofa", true),
		B([-6.5, 0.9, 6.5], [0.3, 0.8, 3.6], "hq_sofa"),
		B([-4.4, 0.25, 6.5], [1.0, 0.5, 1.8], "marble", true),
		B([5.9, 0.35, 6.5], [1.4, 0.7, 3.6], "hq_sofa", true),
		B([6.5, 0.9, 6.5], [0.3, 0.8, 3.6], "hq_sofa"),
		B([4.4, 0.25, 6.5], [1.0, 0.5, 1.8], "marble", true),
		B([5.4, 1.45, 14.6], [2.6, 2.9, 1.0], "hq_wood", true),          # armario (tienda de ropa)
		B([5.4, 1.45, 14.09], [0.05, 2.7, 0.02], "dark"),
		B([5.2, 1.5, 14.07], [0.06, 0.45, 0.04], "gold"),
		B([5.6, 1.5, 14.07], [0.06, 0.45, 0.04], "gold"),
		B([5.4, 2.97, 14.6], [2.8, 0.14, 1.1], "gold"),
		B([-5.4, 0.55, 14.6], [2.6, 1.1, 1.0], "hq_wood", true),         # vitrina de trofeos
		B([-5.4, 1.12, 14.6], [2.7, 0.06, 1.1], "gold"),
		B([-5.4, 1.8, 15.05], [2.6, 1.4, 0.1], "hq_trim"),
		B([-5.4, 1.75, 14.6], [2.6, 0.04, 1.0], "white"),
		B([-5.4, 2.48, 14.6], [2.7, 0.08, 1.1], "hq_wood"),
		B([-6.67, 1.8, 14.6], [0.06, 1.4, 1.0], "hq_wood"),
		B([-4.13, 1.8, 14.6], [0.06, 1.4, 1.0], "hq_wood"),
		# Pared del logo, pizarra de estrategia y pantalla de la bolsa
		B([0, 2.7, z1 - 0.26], [8, 2.6, 0.1], "hq_trim"),
		B([0, 1.3, z1 - 0.3], [8, 0.06, 0.1], "gold"),
		B([-w / 2 + 0.25, 2.4, 11], [0.08, 1.9, 3.4], "hq_trim"),
		B([-w / 2 + 0.3, 2.4, 11], [0.05, 1.7, 3.2], "white"),
		B([-w / 2 + 0.36, 1.48, 11], [0.16, 0.05, 1.2], "dark"),
		B([w / 2 - 0.25, 2.6, 11], [0.08, 1.9, 3.4], "hq_trim"),
		B([w / 2 - 0.3, 2.6, 11], [0.05, 1.7, 3.2], "dark"),
	]
	for pp in [[-7, 3], [7, 3], [-7, 14.8], [7, 14.8]]:
		boxes.append(B([pp[0], 0.4, pp[1]], [0.7, 0.8, 0.7], "hq_trim", true))
		boxes.append(B([pp[0], 1.4, pp[1]], [1.0, 1.3, 1.0], "plant"))
	# Fachada de vidrio: vidrio en planta baja, franjas por piso y parteluces dorados (de noche se prenden)
	for sx in [-1, 1]:
		boxes.append(B([sx * sx_door, 2.2, z0 - 0.24], [side_w - 0.8, 3.4, 0.06], "hq_glass"))
	var floor_h := (h - lobby - 1) / 4
	for i in 4:
		var y := lobby + 0.9 + floor_h * (i + 0.5)
		boxes.append(B([0, y, z0 - 0.24], [w - 1, floor_h * 0.68, 0.06], "hq_glass"))
		for sx in [-1, 1]:
			boxes.append(B([sx * (w / 2 + 0.24), y, zc], [0.06, floor_h * 0.68, depth - 1], "hq_glass"))
		boxes.append(B([0, y, z1 + 0.24], [w - 1, floor_h * 0.68, 0.06], "hq_glass"))
	for mx in [-6, -3, 0, 3, 6]:
		boxes.append(B([mx, (lobby + h) / 2 + 0.4, z0 - 0.3], [0.14, h - lobby - 1.2, 0.1], "gold"))
	boxes.append(B([0, h + 2.4, z0 + 0.6], [11, 2.2, 0.3], "hq_trim"))  # letrero del techo
	var texts := [[Vector3(0, h + 2.45, z0 + 0.43), "CAPITAL", 46, "gold"],
			[Vector3(0, 4.12, z0 - 3.02), "OFICINA CENTRAL", 13, "white"],
			[Vector3(0, 2.95, z1 - 0.33), "CAPITAL", 30, "gold"],
			[Vector3(0, 2.15, z1 - 0.33), "Vende · Invierte · Crece", 9, "white"],
			[Vector3(5.4, 2.55, 14.05), "ARMARIO", 6, "gold"]]
	var spots := {"front": [0, -1.5], "door": [0, 1.8], "texts": texts, "computer": [0, 7.6], "screen": Vector3(0, 1.35, 9.35),
			"ceiling": [-w / 2, w / 2, z0, z1, lobby - 0.1], "wardrobe": [5.4, 12.7], "trophies": [-5.4, 12.8],
			"indoor_lights": [[-4, 4.0, 6, 7.5], [4, 4.0, 6, 7.5], [-4, 4.0, 12.5, 7.5], [4, 4.0, 12.5, 7.5]],
			"board": [-6.5, 11], "ticker": [6.5, 11], "assistant": [-2.9, 7.6]}
	return [boxes, spots]


## Devuelve [cajas, lugares] para un puesto (0), local (1), megatienda (2) u oficina ("hq").
static func blueprint(kind) -> Array:
	if typeof(kind) == TYPE_STRING:
		return hq()
	var boxes := []
	var spots := {}
	if kind == 0:  # puesto
		boxes += [B([0, 0.02, 4.5], [7, 0.04, 6], "floor"),
				B([0, 0.55, 4], [4, 1.1, 2.4], "product", true),
				B([0, 1.12, 4], [4.2, 0.06, 2.6], "wood"),
				B([0, 2.8, 4], [4.8, 0.15, 3.2], "white"),
				B([0, 2.9, 4], [4.8, 0.06, 1.0], "product"),
				B([0, 3.5, 2.6], [3.6, 0.8, 0.2], "product")]
		for px in [-1.95, 1.95]:
			for pz in [2.9, 5.1]:
				boxes.append(B([px, 1.95, pz], [0.1, 1.7, 0.1], "dark"))
		spots = {"front": [0, -1.5], "door": null, "sign": [Vector3(0, 3.5, 2.48), 18, "white"],
				"lines": [{"slots": [[0, 1.9], [0, 1.0], [0, 0.1], [0, -0.8]], "exit": [[1.9, 1.9], [1.9, 0.0]]}],
				"staff": [[-0.9, 5.9], [0.4, 5.9]], "serve": [1.6, 5.9], "manage": [-3.0, 0.6], "aisles": [],
				"picks": [],
				"lights": [[0, 2.5, 4, 6.5]]}
		return [boxes, spots]

	var dims: Array = [[14.0, 12.0, 4.5, 3.0], [22.0, 18.0, 7.0, 5.0]][kind - 1]
	var w: float = dims[0]
	var depth: float = dims[1]
	var h: float = dims[2]
	var door: float = dims[3]
	var z0 := 2.0
	var z1 := z0 + depth
	var zc := (z0 + z1) / 2
	var side_w := (w - door) / 2
	var door_h := 3.2 if kind != 2 else 3.6
	boxes += [B([0, h / 2, z1], [w, h, 0.3], "wall", true),
			B([-w / 2, h / 2, zc], [0.3, h, depth], "wall", true),
			B([w / 2, h / 2, zc], [0.3, h, depth], "wall", true),
			B([-(door + side_w) / 2, h / 2, z0], [side_w, h, 0.3], "wall", true),
			B([(door + side_w) / 2, h / 2, z0], [side_w, h, 0.3], "wall", true),
			B([0, (h + door_h) / 2, z0], [door, h - door_h, 0.3], "wall"),
			B([0, h + 0.15, zc], [w + 0.6, 0.3, depth + 0.6], "roof"),
			B([0, 0.03, zc], [w - 0.4, 0.06, depth - 0.4], "floor"),
			B([0, door_h + 0.35, z0 - 0.6], [w, 0.15, 1.2], "product")]
	for sx in [-1, 1]:
		boxes.append(B([sx * (door + side_w) / 2, 2.1, z0 - 0.18], [side_w * 0.7, 1.8 if kind != 2 else 2.2, 0.06], "glass"))
	var sign_w := 8.0 if kind != 2 else 12.0
	var sign_h := 1.2 if kind != 2 else 1.8
	boxes.append(B([0, h + 0.3 + sign_h / 2, z0 - 0.05], [sign_w, sign_h, 0.25], "product"))
	var sign := [Vector3(0, h + 0.3 + sign_h / 2, z0 - 0.19), 26 if kind != 2 else 40, "white"]
	# Paneles de luz en el techo, por dentro
	for lx in ([-3.0, 3.0] if kind == 1 else [-6.0, 0.0, 6.0]):
		for lz in [z0 + depth * 0.25, z0 + depth * 0.5, z0 + depth * 0.75]:
			boxes.append(B([lx, h - 0.04, lz], [2.2, 0.06, 0.6], "lamp"))
	var ceiling := [-w / 2, w / 2, z0, z1, h]

	if kind == 1:  # local
		boxes += [B([0, 0.55, 9.5], [6, 1.1, 1], "wood", true),
				B([0, 1.12, 9.5], [6.2, 0.06, 1.1], "dark"),
				B([0, 3.0, z1 - 0.2], [5, 1.5, 0.1], "dark")]
		for sx in [-6.2, 6.2]:
			boxes.append(B([sx, 1.2, 8.5], [1, 2.4, 8], "shelf", true))
			for y in [0.5, 1.2, 1.9]:  # tablas que salen hacia el pasillo, donde van los productos (Store los pone)
				boxes.append(B([sx - signf(sx) * 0.7, y, 8.5], [0.5, 0.05, 7.7], "wood"))
		for sx in [-1, 1]:  # bodega: cajas apiladas en los rincones del fondo
			boxes += [B([sx * 4.8, 0.3, 13.55], [1.6, 0.6, 0.6], "crate"), B([sx * 4.5, 0.85, 13.55], [0.9, 0.5, 0.55], "crate"),
					B([sx * 5.3, 0.75, 13.6], [0.6, 0.3, 0.5], "crate")]
		var slots := []
		for i in 6:
			slots.append([0, 8.4 - i])
		spots = {"front": [0, -1.5], "door": [0, 1.8], "sign": sign, "aisles": [], "ceiling": ceiling,
				"lines": [{"slots": slots, "exit": [[1.9, 8.4], [1.9, 3.0], [0, 1.8]]}],
				"staff": [[-1.6, 10.6], [0, 10.6], [1.6, 10.6]], "serve": [2.7, 10.6], "manage": [-3.0, -1.2],
				"picks": [[-4.75, 5.4], [4.75, 5.4], [-4.75, 7.2], [4.75, 7.2]], "pick_faces": [-1, 1, -1, 1],
				"texts": [[Vector3(-4.8, 2.7, 13.82), "BODEGA", 6, "white"], [Vector3(4.8, 2.7, 13.82), "BODEGA", 6, "white"]],
				"indoor_lights": [[0, 3.6, 4.0, 8.0], [0, 3.6, 10.0, 8.0], [0, 3.6, 16.0, 8.0]]}
		return [boxes, spots]

	# megatienda: góndolas en la mitad de adelante, cajas al fondo (el cajero detrás, mirando a la puerta; la fila
	# hacia adelante) y la bodega detrás de las cajas
	var registers := [-6, -2, 2]
	for rx in registers + [6]:
		boxes += [B([rx, 0.55, 15.5], [2.4, 1.1, 1.2], "wood", true), B([rx, 1.12, 15.5], [2.5, 0.06, 1.3], "dark")]
	for sx in [-6.5, -2, 2, 6.5]:
		boxes.append(B([sx, 1.3, 7.5], [1.2, 2.6, 5], "shelf", true))
		for y in [0.5, 1.3, 2.1]:
			for f in [-1, 1]:
				boxes.append(B([sx + f * 0.82, y, 7.5], [0.45, 0.05, 4.7], "wood"))
	for sx in [-10.2, 10.2]:
		boxes.append(B([sx, 1.3, 9.5], [1, 2.6, 9], "shelf", true))
		for y in [0.5, 1.3, 2.1]:
			boxes.append(B([sx - signf(sx) * 0.73, y, 9.5], [0.45, 0.05, 8.5], "wood"))
	for sx in [-1, 1]:  # bodega al fondo, detrás de las cajas
		boxes += [B([sx * 8.4, 0.35, 19.5], [2.4, 0.7, 0.6], "crate"), B([sx * 8.0, 0.95, 19.5], [1.2, 0.5, 0.55], "crate"),
				B([sx * 9.1, 0.9, 19.55], [0.8, 0.4, 0.5], "crate")]
	var aisle := {-6: -4.25, -2: 0.0, 2: 4.25}   # pasillo por donde sale cada fila (entre las góndolas)
	var lines := []
	for rx in registers:
		var slots := []
		for i in 6:
			slots.append([rx, 14.3 - i * 0.8])
		lines.append({"slots": slots, "exit": [[aisle[rx], 13.0], [aisle[rx], 4.0], [0, 1.8]]})
	var staff := []
	for rx in registers:
		staff.append([rx, 16.7])
	staff += [[-8.4, 12.0], [8.4, 12.0], [0, 18.6]]
	spots = {"front": [0, -1.5], "door": [0, 1.8], "sign": sign, "ceiling": ceiling, "aisles": [],
			"lines": lines, "staff": staff, "serve": [6, 16.7], "manage": [-5.0, -1.2],
			"picks": [[-4.7, 7.5], [4.7, 7.5], [0.35, 8.0], [-0.35, 6.5], [-8.75, 8.0], [8.75, 8.0]],
			"pick_faces": [-1, 1, 1, -1, -1, 1],
			"texts": [[Vector3(-8.4, 2.6, 19.82), "BODEGA", 8, "white"], [Vector3(8.4, 2.6, 19.82), "BODEGA", 8, "white"]],
			"indoor_lights": [[-6, 5.5, 6, 9.0], [6, 5.5, 6, 9.0], [-6, 5.5, 14, 9.0], [6, 5.5, 14, 9.0],
					[0, 5.5, 10, 8.0]]}
	return [boxes, spots]


## Coordenadas locales de un terreno (z crece hacia adentro) a coordenadas del mundo.
static func to_world(plot: Array, lx: float, lz: float, y := 0.0) -> Vector3:
	var side: float = plot[1]
	return Vector3(plot[0] + side * lx, y, side * (FRONT + lz))
