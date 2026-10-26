class_name Blueprints
extends RefCounted
## Planos de los edificios (coordenadas locales: x a lo ancho, z hacia adentro del terreno, y hacia arriba).
## Cada caja: [centro, tamaño, color, choca]. Igual que en la versión de Python.

const FRONT := 9.0        # distancia del centro de la calle al frente de los terrenos
const PALETTE := {
	"wall": Color8(232, 226, 214), "roof": Color8(70, 74, 82), "glass": Color8(150, 200, 230), "floor": Color8(200, 190, 170),
	"wood": Color8(140, 100, 65), "dark": Color8(78, 80, 88), "shelf": Color8(190, 180, 165), "white": Color8(245, 245, 245),
	"gold": Color8(227, 179, 65), "green": Color8(60, 150, 80),
	# Oficina central
	"hq_stone": Color8(128, 134, 146), "hq_trim": Color8(92, 98, 112), "hq_glass": Color8(80, 125, 170), "hq_wood": Color8(138, 96, 66),
	"hq_sofa": Color8(80, 108, 150), "marble": Color8(225, 222, 215), "carpet": Color8(150, 40, 45), "plant": Color8(60, 135, 70),
	"art1": Color8(210, 120, 70), "art2": Color8(80, 150, 190),
	"lamp": Color8(255, 240, 215),   # paneles de luz del techo
	"crate": Color8(176, 132, 82),   # cajas de cartón de la bodega
}
const PRODUCT_COLORS := {"cafe": Color8(150, 95, 55), "pan": Color8(225, 170, 80), "burger": Color8(210, 70, 50),
		"ropa": Color8(150, 95, 195), "tech": Color8(60, 130, 215)}
const GLASS_KEYS := ["glass", "hq_glass"]


## `key`: nombre de color de PALETTE, "product" o directamente un Color. `solid`: true choca hasta lo alto de la caja;
## un número choca hasta esa altura (para muebles con repisas arriba que no son sólidas, como la vitrina de trofeos).
static func B(c: Array, s: Array, key, solid = false) -> Array:
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
		B([-5.4, 0.55, 14.6], [2.6, 1.1, 1.0], "hq_wood", 2.52),         # vitrina de trofeos (choca hasta el techo de la vitrina)
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
			"indoor_lights": [[-4, 4.0, 5, 6.5], [4, 4.0, 5, 6.5], [-4, 4.0, 9.5, 6.5], [4, 4.0, 9.5, 6.5],
					[-4, 4.0, 13.5, 6.5], [4, 4.0, 13.5, 6.5]],   # debajo de cada panel del techo
			"board": [-6.5, 11], "ticker": [6.5, 11], "assistant": [-2.9, 7.6]}
	return [boxes, spots]


## Caja registradora del puesto: en el mostrador, justo frente al cajero (staff[0], en x = −0,9), girada para que la
## pantalla y el cajón miren hacia él, como en la vida real.
const STALL_REGISTER := [Vector3(-0.9, 1.15, 4.8), PI]


## Dónde van los productos sobre el mostrador del puesto: una fila del lado del cajero, sin el lugar de la caja.
static func stall_slots() -> Array:
	var slots := []
	for i in 9:
		var x := -1.6 + i * 0.4
		if absf(x - STALL_REGISTER[0].x) > 0.4:
			slots.append([Vector3(x, 1.15, 4.55), PI])
	return slots


## Devuelve [cajas, lugares] para un puesto (0), local (1), megatienda (2) u oficina ("hq").
## `variant` >= 0 arma un interior propio para ese local (ver _varied); -1 deja el plano clásico.
static func blueprint(kind, variant := -1, product := "") -> Array:
	if typeof(kind) == TYPE_STRING:
		return hq()
	if variant >= 0:
		return _varied(kind, variant, product)
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
			B([0, h - 0.02, zc], [w - 0.3, 0.04, depth - 0.3], Color8(236, 232, 224)),   # cielo raso claro por dentro
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


# ---------- interiores distintos para cada local ----------
# Cada local recibe una semilla (`variant`) y con ella se eligen la distribución (dónde van repisas, mostrador,
# mesas y vitrinas), los colores de paredes, piso y muebles, el piso con o sin baldosas, la decoración (plantas,
# cuadros, reloj, alfombra, maniquíes, pantallas) y las lámparas. A veces todo va en espejo. Los lugares por donde
# caminan los clientes y los empleados se calculan con la misma distribución, así que siempre calzan.
const MEGA_W := 20.6   # ancho de la megatienda: los terrenos están cada 22 m, así queda un pasillo entre vecinos
const WALLS := [Color8(232, 226, 214), Color8(236, 232, 226), Color8(214, 226, 232), Color8(226, 236, 222),
		Color8(240, 222, 206), Color8(222, 218, 236), Color8(244, 238, 220), Color8(210, 214, 220)]
const FLOORS := [Color8(200, 190, 170), Color8(170, 120, 80), Color8(130, 135, 145), Color8(225, 222, 215),
		Color8(150, 105, 70), Color8(140, 145, 155), Color8(205, 175, 140), Color8(185, 200, 195)]
const TILES := [Color8(235, 232, 225), Color8(120, 122, 130), Color8(160, 110, 75), Color8(200, 205, 210)]
const SHELVES := [Color8(190, 180, 165), Color8(240, 240, 240), Color8(125, 128, 136), Color8(150, 105, 70), Color8(120, 150, 160)]
const WOODS := [Color8(140, 100, 65), Color8(135, 98, 70), Color8(200, 165, 120), Color8(115, 115, 122), Color8(235, 235, 235)]
const RUGS := [Color8(150, 40, 45), Color8(40, 70, 120), Color8(60, 120, 80), Color8(120, 80, 140), Color8(200, 150, 60)]
const ART := [Color8(210, 120, 70), Color8(80, 150, 190), Color8(220, 190, 80), Color8(150, 90, 160), Color8(90, 170, 120)]


static func _mirror_x(v, m: float):
	if v is Vector3:
		return Vector3(v.x * m, v.y, v.z)
	return v


## Pone todo el plano en espejo (izquierda ↔ derecha). Las paredes son simétricas, así que por fuera no cambia.
static func _mirror(boxes: Array, spots: Dictionary) -> void:
	for b in boxes:
		b[0] = Vector3(-b[0].x, b[0].y, b[0].z)
	for k in spots:
		var v = spots[k]
		match k:
			"lines":
				for ln in v:
					ln.slots = ln.slots.map(func(s): return [-s[0], s[1]])
					ln.exit = ln.exit.map(func(s): return [-s[0], s[1]])
			"pick_faces":
				spots[k] = v.map(func(f): return -f)
			"shelf_rows":
				spots[k] = v.map(func(r): return [-r[0], r[1], r[2], -r[3]])
			"registers", "stall_slots":
				spots[k] = v.map(func(r): return [Vector3(-r[0].x, r[0].y, r[0].z), r[1]])
			"texts":
				spots[k] = v.map(func(t): return [Vector3(-t[0].x, t[0].y, t[0].z), t[1], t[2], t[3]])
			"lights", "indoor_lights":
				spots[k] = v.map(func(l): return [-l[0], l[1], l[2], l[3]])
			"restock":
				v.sides = v.sides.map(func(s): return -s)
			"sign", "ceiling", "front", "door", "manage":
				pass
			_:
				if v is Array and v.size() > 0 and v[0] is Array:
					spots[k] = v.map(func(s): return [-s[0], s[1]])
				elif v is Array and v.size() == 2 and not (v[0] is Array):
					spots[k] = [-v[0], v[1]]


static func _plant(boxes: Array, x: float, z: float, big := false) -> void:
	var s := 1.3 if big else 1.0
	boxes.append(B([x, 0.22 * s, z], [0.5 * s, 0.44 * s, 0.5 * s], Color8(170, 95, 60), true))
	boxes.append(B([x, 0.8 * s, z], [0.8 * s, 0.7 * s, 0.8 * s], Color8(60, 135, 70)))
	boxes.append(B([x, 1.25 * s, z], [0.5 * s, 0.35 * s, 0.5 * s], Color8(80, 160, 85)))


static func _table(boxes: Array, x: float, z: float, top: Color, seats := true) -> void:
	boxes.append(B([x, 0.75, z], [1.0, 0.06, 1.0], top, true))
	boxes.append(B([x, 0.37, z], [0.1, 0.72, 0.1], Color8(50, 50, 55)))
	if seats:
		for sz in [-0.8, 0.8]:
			boxes.append(B([x, 0.45, z + sz], [0.45, 0.06, 0.45], top.darkened(0.25)))
			boxes.append(B([x, 0.22, z + sz], [0.06, 0.44, 0.06], Color8(50, 50, 55)))
			boxes.append(B([x, 0.72, z + sz * 1.25], [0.45, 0.5, 0.06], top.darkened(0.25)))


## Mesa baja de exhibición con productos de su color encima.
static func _display(boxes: Array, x: float, z: float, wood: Color, item: Color, rng: RandomNumberGenerator) -> void:
	boxes.append(B([x, 0.4, z], [1.6, 0.8, 1.0], wood, true))
	for i in 4:
		var w := rng.randf_range(0.18, 0.3)
		boxes.append(B([x - 0.55 + i * 0.37, 0.8 + w / 2, z + rng.randf_range(-0.25, 0.25)], [w, w, w], item.lightened(rng.randf_range(0.0, 0.3))))


static func _mannequin(boxes: Array, x: float, z: float, cloth: Color) -> void:
	boxes.append(B([x, 0.05, z], [0.5, 0.1, 0.5], Color8(40, 40, 45), true))
	boxes.append(B([x, 0.55, z], [0.06, 0.9, 0.06], Color8(40, 40, 45)))
	boxes.append(B([x, 1.3, z], [0.5, 0.65, 0.28], cloth))
	boxes.append(B([x, 1.8, z], [0.24, 0.3, 0.24], Color8(235, 230, 225)))


## Cuadros, reloj o pizarra en una pared (x en el muro, mirando hacia `face`: +1 hacia +z).
static func _wall_art(boxes: Array, x: float, y: float, z: float, kind: int, rng: RandomNumberGenerator) -> void:
	match kind:
		0:  # dos cuadros
			for dx in [-0.9, 0.9]:
				boxes.append(B([x + dx, y, z], [1.2, 0.9, 0.06], Color8(40, 35, 30)))
				boxes.append(B([x + dx, y, z - 0.04], [1.0, 0.7, 0.04], ART[rng.randi() % ART.size()]))
		1:  # reloj
			boxes.append(B([x, y, z], [0.8, 0.8, 0.06], Color8(245, 245, 245)))
			boxes.append(B([x, y + 0.12, z - 0.04], [0.05, 0.3, 0.02], Color8(30, 30, 35)))
			boxes.append(B([x + 0.1, y, z - 0.04], [0.22, 0.05, 0.02], Color8(30, 30, 35)))
		_:  # pizarra de menú
			boxes.append(B([x, y, z], [3.0, 1.3, 0.08], Color8(35, 45, 40)))
			for i in 4:
				boxes.append(B([x - 0.6 + rng.randf_range(-0.2, 0.2), y + 0.4 - i * 0.26, z - 0.05], [rng.randf_range(1.0, 1.8), 0.06, 0.02], Color8(230, 230, 220)))


## Banca baja contra la pared del fondo: los empleados se sientan a descansar mirando hacia el local.
static func _bench(boxes: Array, x: float, z: float, w: float, wood: Color) -> void:
	boxes.append(B([x, 0.42, z], [w, 0.08, 0.42], wood))
	for sx in [-1, 1]:
		boxes.append(B([x + sx * (w / 2 - 0.12), 0.2, z], [0.08, 0.4, 0.36], Color8(50, 50, 55)))


static func _floor_tiles(boxes: Array, x0: float, x1: float, z0: float, z1: float, cell: float, col: Color) -> void:
	var nx := int((x1 - x0) / cell)
	var nz := int((z1 - z0) / cell)
	for i in nx:
		for j in nz:
			if (i + j) % 2 == 0:
				boxes.append(B([x0 + (i + 0.5) * cell, 0.065, z0 + (j + 0.5) * cell], [cell, 0.01, cell], col))


## Paredes, techo, piso, toldo, vitrinas y letrero de un local o megatienda, con los colores elegidos.
static func _shell(kind: int, wall: Color, floor_col: Color, awning, boxes: Array) -> Dictionary:
	var dims: Array = [[14.0, 12.0, 4.5, 3.0], [MEGA_W, 18.0, 7.0, 5.0]][kind - 1]
	var w: float = dims[0]
	var depth: float = dims[1]
	var h: float = dims[2]
	var door: float = dims[3]
	var z0 := 2.0
	var z1 := z0 + depth
	var zc := (z0 + z1) / 2
	var side_w := (w - door) / 2
	var door_h := 3.2 if kind != 2 else 3.6
	boxes.append_array([B([0, h / 2, z1], [w, h, 0.3], wall, true),
			B([-w / 2, h / 2, zc], [0.3, h, depth], wall, true),
			B([w / 2, h / 2, zc], [0.3, h, depth], wall, true),
			B([-(door + side_w) / 2, h / 2, z0], [side_w, h, 0.3], wall, true),
			B([(door + side_w) / 2, h / 2, z0], [side_w, h, 0.3], wall, true),
			B([0, (h + door_h) / 2, z0], [door, h - door_h, 0.3], wall),
			B([0, h + 0.15, zc], [w + 0.6, 0.3, depth + 0.6], "roof"),
			B([0, h - 0.02, zc], [w - 0.3, 0.04, depth - 0.3], Color8(236, 232, 224)),   # cielo raso claro por dentro
			B([0, 0.03, zc], [w - 0.4, 0.06, depth - 0.4], floor_col),
			B([0, door_h + 0.35, z0 - 0.6], [w, 0.15, 1.2], awning)])
	for sx in [-1, 1]:
		boxes.append(B([sx * (door + side_w) / 2, 2.1, z0 - 0.18], [side_w * 0.7, 1.8 if kind != 2 else 2.2, 0.06], "glass"))
	var sign_w := 8.0 if kind != 2 else 12.0
	var sign_h := 1.2 if kind != 2 else 1.8
	boxes.append(B([0, h + 0.3 + sign_h / 2, z0 - 0.05], [sign_w, sign_h, 0.25], "product"))
	return {"w": w, "depth": depth, "h": h, "z0": z0, "z1": z1, "zc": zc,
			"sign": [Vector3(0, h + 0.3 + sign_h / 2, z0 - 0.19), 26 if kind != 2 else 40, "white"],
			"ceiling": [-w / 2, w / 2, z0, z1, h]}


## Lámparas del techo: paneles o lámparas colgantes.
static func _lamps(boxes: Array, xs: Array, zs: Array, h: float, pendant: bool) -> void:
	for lx in xs:
		for lz in zs:
			if pendant:
				boxes.append(B([lx, h - 0.45, lz], [0.03, 0.9, 0.03], Color8(30, 30, 35)))
				boxes.append(B([lx, h - 0.95, lz], [0.6, 0.3, 0.6], "lamp"))
			else:
				boxes.append(B([lx, h - 0.04, lz], [2.2, 0.06, 0.6], "lamp"))


static func _varied(kind: int, variant: int, product: String) -> Array:
	var rng := RandomNumberGenerator.new()
	rng.seed = variant * 7919 + kind * 104729 + product.hash()
	var boxes := []
	var spots := {}
	var food := product in ["cafe", "pan", "burger"]
	var pcol: Color = PRODUCT_COLORS.get(product, Color8(150, 150, 150))
	var wood: Color = WOODS[rng.randi() % WOODS.size()]
	var shelf_col: Color = SHELVES[rng.randi() % SHELVES.size()]
	var rug: Color = RUGS[rng.randi() % RUGS.size()]
	if kind == 0:
		_varied_stall(boxes, spots, rng, pcol, wood)
	elif kind == 1:
		_varied_local(boxes, spots, rng, pcol, wood, shelf_col, rug, food, product)
	else:
		_varied_mega(boxes, spots, rng, pcol, wood, shelf_col, rug, food, product)
	if rng.randf() < 0.5:
		_mirror(boxes, spots)
	return [boxes, spots]


## Puesto: toldo a rayas o liso, mostrador de distintos colores y cosas alrededor (taburetes, pizarra, plantas...).
static func _varied_stall(boxes: Array, spots: Dictionary, rng: RandomNumberGenerator, pcol: Color, wood: Color) -> void:
	var floor_col: Color = FLOORS[rng.randi() % FLOORS.size()]
	var counter: Color = [pcol, wood, Color8(240, 240, 240), pcol.darkened(0.1)][rng.randi() % 4]
	boxes.append_array([B([0, 0.02, 4.5], [7, 0.04, 6], floor_col),
			B([0, 0.55, 4], [4, 1.1, 2.4], counter, true),
			B([0, 1.12, 4], [4.2, 0.06, 2.6], wood if counter != wood else Color8(115, 115, 122)),
			B([0, 3.5, 2.6], [3.6, 0.8, 0.2], "product")])
	var stripes := rng.randf() < 0.6
	var stripe_b: Color = [Color8(245, 245, 245), Color8(250, 220, 90), Color8(40, 40, 45)][rng.randi() % 3]
	if stripes:  # toldo a rayas
		for i in 8:
			boxes.append(B([-2.1 + i * 0.6, 2.8, 4], [0.6, 0.15, 3.2], pcol if i % 2 == 0 else stripe_b))
	else:
		boxes.append(B([0, 2.8, 4], [4.8, 0.15, 3.2], "white"))
		boxes.append(B([0, 2.9, 4], [4.8, 0.06, 1.0], "product"))
	for px in [-1.95, 1.95]:
		for pz in [2.9, 5.1]:
			boxes.append(B([px, 1.95, pz], [0.1, 1.7, 0.1], "dark"))
	# Cosas alrededor: siempre del lado izquierdo o atrás (la fila va al centro y la salida por la derecha)
	var props := ["plantas", "pizarra", "taburetes", "mesa", "cajas"]
	props.shuffle()
	for prop in props.slice(0, rng.randi_range(2, 3)):
		match prop:
			"plantas":
				_plant(boxes, -2.9, 6.6)
				_plant(boxes, 2.9, 6.6, true)
			"pizarra":  # pizarra de pie con el menú
				boxes.append(B([-2.9, 0.65, 2.2], [0.9, 1.3, 0.08], Color8(35, 45, 40)))
				boxes.append(B([-2.9, 1.0, 2.15], [0.6, 0.06, 0.02], Color8(230, 230, 220)))
				boxes.append(B([-2.9, 0.75, 2.15], [0.5, 0.06, 0.02], Color8(230, 230, 220)))
			"taburetes":
				for x in [-1.4, -0.5]:
					boxes.append(B([x, 0.75, 2.4], [0.4, 0.06, 0.4], wood))
					boxes.append(B([x, 0.37, 2.4], [0.06, 0.72, 0.06], Color8(50, 50, 55)))
			"mesa":
				_table(boxes, -2.7, 4.6, wood, false)
			"cajas":
				boxes.append(B([2.8, 0.3, 6.8], [0.9, 0.6, 0.7], "crate"))
				boxes.append(B([2.8, 0.85, 6.8], [0.6, 0.5, 0.5], "crate"))
	spots.merge({"front": [0, -1.5], "door": null, "sign": [Vector3(0, 3.5, 2.48), 18, "white"],
			"lines": [{"slots": [[0, 1.9], [0, 1.0], [0, 0.1], [0, -0.8]], "exit": [[1.9, 1.9], [1.9, 0.0]]}],
			"staff": [[-0.9, 5.9], [0.4, 5.9]], "serve": [1.6, 5.9], "manage": [-3.0, 0.6], "aisles": [],
			"picks": [], "lights": [[0, 2.5, 4, 6.5]],
			"stall_slots": stall_slots(), "registers": [STALL_REGISTER], "seats": [[-0.9, 6.95]]})
	boxes.append(B([-0.9, 0.22, 7.05], [0.42, 0.44, 0.42], wood))   # piso para descansar detrás del mostrador


## Local: tres distribuciones (repisas en las dos paredes; repisa en una pared y mesas o vitrinas en la otra; repisas
## cortas al fondo con exhibición adelante), el mostrador corrido a un lado o al centro y decoración distinta.
static func _varied_local(boxes: Array, spots: Dictionary, rng: RandomNumberGenerator, pcol: Color, wood: Color,
		shelf_col: Color, rug: Color, food: bool, product: String) -> void:
	var sh := _shell(1, WALLS[rng.randi() % WALLS.size()], FLOORS[rng.randi() % FLOORS.size()], "product", boxes)
	var z1: float = sh.z1
	var h: float = sh.h
	if rng.randf() < 0.45:
		_floor_tiles(boxes, -6.8, 6.8, 2.2, 13.8, [1.0, 1.4][rng.randi() % 2], TILES[rng.randi() % TILES.size()])
	var layout := rng.randi() % 3
	var cx: float = [-1.5, 0.0, 1.5][rng.randi() % 3]
	var keep := 1 if rng.randf() < 0.5 else -1   # en la distribución con mesas, de qué lado queda la repisa
	var sides := [-1, 1] if layout != 1 else [keep]
	var zf := 4.65 if layout != 2 else 7.0       # dónde empieza la repisa
	var zt := 12.35
	var levels := [0.5, 1.2, 1.9]
	var rows := []
	var picks := []
	var faces := []
	for s in sides:
		var len_ := zt - zf
		boxes.append(B([s * 6.2, 1.2, (zf + zt) / 2], [1, 2.4, len_], shelf_col, true))
		for y in levels:
			boxes.append(B([s * 5.5, y, (zf + zt) / 2], [0.5, 0.05, len_ - 0.3], wood))
		rows.append([s * 5.5, zf + 0.25, zt - 0.25, -s])
		for z in [zf + 0.75, min((zf + zt) / 2 - 0.4, 8.3)]:   # nunca a la altura del mostrador (z 9 a 10)
			picks.append([s * 4.75, z])
			faces.append(s)
	# Lo que va del otro lado o adelante
	var tables := []
	if layout == 1:
		var o := -keep
		if food:
			_table(boxes, o * 4.6, 4.6, wood)
			_table(boxes, o * 4.6, 7.4, wood)
			tables = [[o * 4.6, 4.6], [o * 4.6, 7.4]]
		else:
			_display(boxes, o * 4.9, 4.8, wood, pcol, rng)
			_display(boxes, o * 4.9, 7.6, wood, pcol, rng)
			if product == "ropa":
				_mannequin(boxes, o * 6.2, 11.4, pcol)
			elif product == "tech":
				boxes.append(B([o * 6.82, 2.4, 8.0], [0.08, 1.2, 2.0], Color8(25, 25, 30)))
				boxes.append(B([o * 6.77, 2.4, 8.0], [0.04, 1.0, 1.8], Color8(70, 140, 220)))
	elif layout == 2:
		for s in [-1, 1]:
			if food:
				_table(boxes, s * 5.0, 4.4, wood)
				tables.append([s * 5.0, 4.4])
			else:
				_display(boxes, s * 5.0, 4.6, wood, pcol, rng)
	else:
		_plant(boxes, -6.2, 3.3)
		_plant(boxes, 6.2, 3.3)
	if product == "ropa" and layout != 1:
		_mannequin(boxes, [-3.6, 3.6][rng.randi() % 2], 3.2, pcol.lightened(0.2))
	# Mostrador con dos cajas: corrido a un lado es más corto, para que no tape la repisa ni choque con las mesas
	var cw := 6.0 if cx == 0.0 else 4.2
	var off := 1.5 if cx == 0.0 else 1.05   # cada caja, a un lado del centro del mostrador
	boxes.append(B([cx, 0.55, 9.5], [cw, 1.1, 1], wood, true))
	boxes.append(B([cx, 1.12, 9.5], [cw + 0.2, 0.06, 1.1], "dark"))
	_wall_art(boxes, cx, 3.0, z1 - 0.2, rng.randi() % 3, rng)
	if rng.randf() < 0.6:  # alfombra en la entrada
		boxes.append(B([0, 0.07, 3.0], [2.6, 0.02, 1.6], rug))
	# Bodega al fondo
	for sx in [-1, 1]:
		boxes.append_array([B([sx * 4.8, 0.3, 13.55], [1.6, 0.6, 0.6], "crate"), B([sx * 4.5, 0.85, 13.55], [0.9, 0.5, 0.55], "crate"),
				B([sx * 5.3, 0.75, 13.6], [0.6, 0.3, 0.5], "crate")])
	_lamps(boxes, [-3.0, 3.0], [2.0 + 12.0 * 0.25, 2.0 + 12.0 * 0.5, 2.0 + 12.0 * 0.75], h, rng.randf() < 0.4)
	_bench(boxes, 0.0, 13.45, 1.7, wood)   # banca de descanso de los empleados, en la bodega
	var lines := []
	for side in [-1, 1]:  # una fila por caja; cada una sale por su lado
		var lx: float = cx + side * off
		var slots := []
		for i in 6:
			slots.append([lx, 8.4 - i])
		lines.append({"slots": slots, "exit": [[lx + side * 1.3, 8.4], [lx + side * 1.3, 3.0], [0, 1.8]]})
	spots.merge({"front": [0, -1.5], "door": [0, 1.8], "sign": sh.sign, "aisles": [], "ceiling": sh.ceiling,
			"lines": lines,
			"staff": [[cx - off, 10.6], [cx + off, 10.6], [cx, 11.8], [cx + off, 12.6]], "serve": [cx, 10.6],
			"manage": [-3.0, -1.2], "picks": picks, "pick_faces": faces,
			"texts": [[Vector3(-4.8, 2.7, 13.82), "BODEGA", 6, "white"], [Vector3(4.8, 2.7, 13.82), "BODEGA", 6, "white"]],
			"indoor_lights": [[0, 3.6, 4.0, 8.0], [0, 3.6, 10.0, 8.0], [0, 3.6, 16.0, 8.0]],
			"shelf_rows": rows, "levels": levels, "registers": [[Vector3(cx - off, 1.15, 9.25), 0.0], [Vector3(cx + off, 1.15, 9.25), 0.0]],
			"restock": {"x": 4.75, "z_to": zf + 1.1, "sides": sides}, "tables": tables, "seats": [[-0.45, 13.4], [0.45, 13.4]]})


## Megatienda: góndolas en distinta cantidad y posición, zona de ofertas adelante, carritos, colgantes con el
## color de la marca y piso con franjas o baldosas.
static func _varied_mega(boxes: Array, spots: Dictionary, rng: RandomNumberGenerator, pcol: Color, wood: Color,
		shelf_col: Color, rug: Color, food: bool, product: String) -> void:
	var sh := _shell(2, WALLS[rng.randi() % WALLS.size()], FLOORS[rng.randi() % FLOORS.size()], "product", boxes)
	var h: float = sh.h
	var half := MEGA_W / 2
	if rng.randf() < 0.5:
		_floor_tiles(boxes, -half + 0.4, half - 0.4, 2.2, 19.8, 1.6, TILES[rng.randi() % TILES.size()])
	else:  # franjas de color en los pasillos de las paredes
		for x in [-7.6, 7.6]:
			boxes.append(B([x, 0.065, 11.0], [0.5, 0.01, 17.0], pcol))
	var registers := [-5, 0, 5]   # tres cajas
	for rx in registers:
		boxes.append_array([B([rx, 0.55, 15.5], [2.4, 1.1, 1.2], wood, true), B([rx, 1.12, 15.5], [2.5, 0.06, 1.3], "dark")])
	var sets := [[-6.0, -2.0, 2.0, 6.0], [-5.0, 0.0, 5.0], [-5.5, -1.0, 3.5], [-4.0, 0.0, 4.0]]
	var gondolas: Array = sets[rng.randi() % sets.size()]
	var gz: float = [7.5, 7.8][rng.randi() % 2]
	var levels := [0.5, 1.3, 2.1]
	var rows := []
	var picks := []
	var faces := []
	for c in gondolas:
		boxes.append(B([c, 1.3, gz], [1.2, 2.6, 5], shelf_col, true))
		for y in levels:
			for f in [-1, 1]:
				boxes.append(B([c + f * 0.82, y, gz], [0.45, 0.05, 4.7], wood))
		rows += [[c - 0.82, gz - 2.1, gz + 2.1, -1], [c + 0.82, gz - 2.1, gz + 2.1, 1]]
		for f in [-1, 1]:
			picks.append([c + f * 1.55, gz + rng.randf_range(-1.2, 0.6)])
			faces.append(-f)
	for sx in [-(half - 0.8), half - 0.8]:
		boxes.append(B([sx, 1.3, 9.5], [1, 2.6, 9], shelf_col, true))
		for y in levels:
			boxes.append(B([sx - signf(sx) * 0.73, y, 9.5], [0.45, 0.05, 8.5], wood))
		rows.append([sx - signf(sx) * 0.73, 5.4, 13.6, -int(signf(sx))])
		picks.append([sx - signf(sx) * 1.45, 8.0])
		faces.append(int(signf(sx)))
	# Pasillo por donde sale cada fila: el hueco entre góndolas más cercano a su caja
	var edges := [-(half - 1.75)]
	for c in gondolas:
		edges += [c - 0.6, c + 0.6]
	edges.append(half - 1.75)
	var gaps := []
	for i in range(0, edges.size(), 2):
		gaps.append((edges[i] + edges[i + 1]) / 2)
	var lines := []
	for rx in registers:
		var best: float = gaps[0]
		for gx in gaps:
			if absf(gx - rx) < absf(best - rx):
				best = gx
		var slots := []
		for i in 6:
			slots.append([rx, 14.3 - i * 0.8])
		lines.append({"slots": slots, "exit": [[best, 13.0], [best, 4.0], [0, 1.8]]})
	# Zona de ofertas y carritos adelante, a los costados de la puerta
	for s in [-1, 1]:
		if rng.randf() < 0.6:
			if food:
				_table(boxes, s * 7.4, 3.6, wood)
				spots["mega_tables"] = spots.get("mega_tables", []) + [[s * 7.4, 3.6]]
			else:
				_display(boxes, s * 7.4, 3.6, wood, pcol, rng)
		else:
			for i in 3:  # carritos de compras en fila
				var z := 3.2 + i * 0.35
				boxes.append(B([s * 7.4, 0.55, z], [0.6, 0.5, 0.9], Color8(170, 175, 185)))
				boxes.append(B([s * 7.4, 0.15, z], [0.5, 0.06, 0.8], Color8(60, 60, 66)))
	if rng.randf() < 0.7:  # colgantes con el color de la marca
		for x in gondolas:
			boxes.append(B([x, h - 1.6, gz], [1.4, 0.8, 0.05], pcol))
	for sx in [-1, 1]:  # bodega al fondo, detrás de las cajas
		boxes.append_array([B([sx * 8.0, 0.35, 19.5], [2.4, 0.7, 0.6], "crate"), B([sx * 7.6, 0.95, 19.5], [1.2, 0.5, 0.55], "crate"),
				B([sx * 8.7, 0.9, 19.55], [0.8, 0.4, 0.5], "crate")])
	_wall_art(boxes, 0.0, 4.5, 19.8, rng.randi() % 2, rng)
	_bench(boxes, 0.0, 19.45, 2.2, wood)   # banca de descanso de los empleados, en la bodega
	_lamps(boxes, [-6.0, 0.0, 6.0], [2.0 + 18.0 * 0.25, 2.0 + 18.0 * 0.5, 2.0 + 18.0 * 0.75], h, rng.randf() < 0.3)
	var staff := []
	for rx in registers:
		staff.append([rx, 16.7])
	staff += [[-7.4, 12.0], [7.4, 12.0], [0, 18.6]]
	var regs := []
	for rx in registers:
		regs.append([Vector3(rx, 1.15, 15.25), 0.0])
	var tables := []
	spots.merge({"front": [0, -1.5], "door": [0, 1.8], "sign": sh.sign, "ceiling": sh.ceiling, "aisles": [],
			"lines": lines, "staff": staff, "serve": [2.5, 16.7], "manage": [-5.0, -1.2], "tables": tables,
			"picks": picks, "pick_faces": faces,
			"texts": [[Vector3(-8.0, 2.6, 19.82), "BODEGA", 8, "white"], [Vector3(8.0, 2.6, 19.82), "BODEGA", 8, "white"]],
			"indoor_lights": [[-6, 5.5, 6, 9.0], [6, 5.5, 6, 9.0], [-6, 5.5, 14, 9.0], [6, 5.5, 14, 9.0], [0, 5.5, 10, 8.0]],
			"shelf_rows": rows, "levels": levels, "registers": regs,
			"restock": {"x": half - 2.25, "z_to": 5.4, "sides": [-1, 1]}, "seats": [[-0.6, 19.4], [0.6, 19.4]]})
