class_name CityMap
extends RefCounted
## El mapa de la ciudad visto desde arriba: el minimapa de abajo a la izquierda y el mapa grande que se abre con la
## tecla M. Cada edificio es una mancha plana con su tamaño real y un ícono redondo: tus locales en dorado, los de la
## competencia con su logo, los terrenos en venta con un «$» y los lugares de la ciudad (oficina, parque, playa...). En el mapa
## grande, al pasar el mouse un edificio se agranda y muestra sus datos; con un clic te lleva hasta él. El mapa grande
## además nombra todo: cada local con su número («Café #1»), los rivales con su logo y su marca, los terrenos «En
## venta», los lugares y las zonas de la ciudad (Distrito Financiero, Parque industrial, el mar...).
##
## El norte del mapa es el lado de la calle con z positivo (donde está tu oficina): y en pantalla = −z.

const WORLD := Rect2(-178, -62, 392, 124)    # lo que muestra el mapa grande (x, z) en metros
const ROAD_HALF := 5.0
const MINI_SIZE := Vector2(270, 168)
const MINI_SCALE := 1.45                     # píxeles por metro en el minimapa

const GOLD := Color8(240, 190, 60)
const RIVAL := Color8(235, 70, 60)
const LOT := Color8(150, 160, 175)
const PLACE := Color8(90, 170, 230)
const FACTORY := Color8(120, 200, 140)
const HOUSE := Color8(90, 200, 190)


## Medidas de cada tamaño de local [ancho, fondo] (ver Blueprints).
static func footprint(size: int) -> Vector2:
	return [Vector2(7, 7), Vector2(14, 12), Vector2(Blueprints.MEGA_W, 18)][clampi(size, 0, 2)]


## Rectángulo (x, z) del edificio de un terreno, en el mundo.
static func plot_rect(plot: Array, size: int) -> Rect2:
	var fp := footprint(size)
	var side: float = plot[1]
	var z0 := side * (Blueprints.FRONT + 2.0)
	var z1 := side * (Blueprints.FRONT + 2.0 + fp.y)
	return Rect2(plot[0] - fp.x / 2, min(z0, z1), fp.x, absf(z1 - z0))


## Dónde quedas parado al viajar a un terreno: en la vereda, frente a la puerta, mirando al edificio.
static func plot_target(plot: Array) -> Array:
	var side: float = plot[1]
	return [Blueprints.to_world(plot, 0, -2.0), 0.0 if side == 1 else 180.0]


## Todo lo que se dibuja y se puede elegir en el mapa. Cada elemento:
## {id, kind (mine, rival, lot, place, factory), rect (x, z en metros), name, sub, color, icon, target, yaw, clients}
static func items(city) -> Array:
	var g = city.game
	var out := []
	if g == null:
		return out
	# Tus locales
	for i in city.stores:
		var st = city.stores[i]
		var loc: Dictionary = st.loc
		var plot: Array = City.plot_pos(i)
		var t := plot_target(plot)
		var p: Dictionary = g.products[loc.product]
		out.append({"id": "s%d" % i, "kind": "mine", "rect": plot_rect(plot, loc.size),
				"name": Lang.f("Tu %s de %s", [Lang.noun(D.SIZES[loc.size].name), Lang.noun(D.PRODUCTS[loc.product].name)]),
				"sub": Lang.f("%s clientes al día · %s estrellas · demanda %s", [Fmt.num(loc.sold), Fmt.num(Game.stars_of(loc), 1), Fmt.num(loc.demand)]),
				"color": Blueprints.PRODUCT_COLORS[loc.product], "icon": "", "target": t[0], "yaw": t[1],
				"label": Lang.f("%s #%d", [Lang.t(Hud.SHORT[loc.product]), g.locs(loc.product).find(loc) + 1]),
				"clients": float(loc.sold), "lost": max(0.0, float(loc.demand) - float(loc.sold)), "price": p.price})
	# Locales de la competencia
	for slot in city.comps:
		var c: Dictionary = city.comps[slot]
		var idx := int(slot.substr(1)) + (City.PLOTS.size() if slot.begins_with("c") else 0)
		var plot: Array = City.plot_pos(idx)
		var t := plot_target(plot)
		var d: Dictionary = D.PRODUCTS[c.key]
		# Clientes que se lleva cada competidor: su parte del mercado (la misma cuenta de Game.market_share)
		var clients: float = d.demand * D.SIZES[1].traffic * g.econ_index
		out.append({"id": "c" + slot, "kind": "rival", "rect": plot_rect(plot, 1),
				"name": Lang.f("%s · %s", [c.rival.company, d.name]),
				"sub": Lang.f("Competencia · unos %s clientes al día · cómpralo por %s", [Fmt.num(clients), Fmt.short(g.acquire_cost(c.key))]),
				"color": c.rival.color, "icon": "", "target": t[0], "yaw": t[1], "clients": clients, "lost": 0.0,
				"label": c.rival.get("short", c.rival.company), "rival": c.rival})
	# Terrenos en venta
	for i in city.lots:
		var plot: Array = City.plot_pos(i)
		var t := plot_target(plot)
		var beach: bool = i in D.BEACH_PLOTS
		out.append({"id": "l%d" % i, "kind": "lot", "rect": plot_rect(plot, 1),
				"name": Lang.f("Terreno %d en venta%s", [i + 1, " · playa" if beach else ""]),
				"sub": Lang.f("Desde %s. Ve y apreta E para construir.", Fmt.short(g.location_cost(0))),
				"color": LOT, "icon": "", "target": t[0], "yaw": t[1], "clients": 0.0, "lost": 0.0, "label": "En venta"})
	# Centros comerciales (o sus terrenos en obra)
	for mi in D.MALLS.size():
		var mall_t := Mall.entrance(mi)
		var yaw := Mall.entrance_yaw(mi)
		var mname: String = Mall.name_of(mi)
		var id := "mall" if mi == 0 else "mall%d" % mi
		if g.has_mall(mi):
			var n := int(D.MALL.slots)
			var used: int = g.locations.filter(func(l): return Game.mall_of(l) >= mi * n and Game.mall_of(l) < (mi + 1) * n).size()
			var riv := 0
			for k in g.rival_mall:
				if Game.mall_index(int(k)) == mi:
					riv += 1
			out.append({"id": id, "kind": "place", "rect": Mall.world_rect(mi), "name": Lang.f("Tu %s", Lang.noun(mname)),
					"sub": Lang.f("%d vitrinas tuyas · %d de rivales · %d libres", [used, riv, n - used - riv]),
					"color": GOLD, "icon": "box", "target": mall_t, "yaw": yaw, "clients": 0.0, "lost": 0.0, "label": mname})
		else:
			out.append({"id": id, "kind": "lot", "rect": Mall.world_rect(mi), "name": Lang.f("Terreno: %s", Lang.noun(mname)),
					"sub": Lang.f("%d vitrinas · cómpralo por %s", [int(D.MALL.slots), Fmt.short(g.mall_cost(mi))]),
					"color": LOT, "icon": "box", "target": mall_t, "yaw": yaw, "clients": 0.0, "lost": 0.0,
					"label": "Centro comercial · en venta"})   # corto: el nombre completo sale al pasar el mouse
	# Tu oficina central
	var hq_t := Blueprints.to_world(City.HQ, 0, -2.5)
	out.append({"id": "hq", "kind": "place", "rect": Rect2(City.HQ[0] - 9, 11, 18, 16), "name": "Tu oficina central",
			"sub": "Computadora, pizarra de estrategia, bolsa, trofeos y armario." if g.investing() else "Computadora, pizarra de estrategia, trofeos y armario.", "color": GOLD, "icon": "building",
			"target": hq_t, "yaw": 0.0, "clients": 0.0, "lost": 0.0, "label": "Tu oficina"})
	# Fábricas (parque industrial)
	for k in D.PRODUCT_ORDER:
		var p: Dictionary = g.products[k]
		if p.factory:
			var fr: Rect2 = city.builder.factory_rect(k) if city.builder.has_method("factory_rect") else Rect2()
			if fr.size.x > 0:
				out.append({"id": "f" + k, "kind": "factory", "rect": fr,
						"name": Lang.f("Tu fábrica de %s", Lang.noun(D.PRODUCTS[k].name)),
						"sub": "Con paneles solares en el techo." if p.get("solar", false) else "Sin paneles solares (los puedes poner en Negocios).",
						"color": FACTORY, "icon": "bolt" if p.get("solar", false) else "box",
						"target": Vector3(fr.get_center().x, 0, fr.end.y + 3.0), "yaw": 180.0, "clients": 0.0, "lost": 0.0,
						"label": Lang.f("Fábrica de %s", Lang.t(Hud.SHORT[k]).to_lower())})
	# Casas del barrio para alquilar
	for i in city.builder.sale_houses.size():
		var h: Dictionary = city.builder.sale_houses[i]
		var hr := Rect2(h.pos.x - h.w / 2, h.pos.z - h.d / 2, h.w, h.d)
		var owned: bool = g.houses.has(str(i))
		var front: Vector3 = h.pos + Vector3(0, 0, h.face * (h.d / 2 + 3.2))
		out.append({"id": "h%d" % i, "kind": "house", "rect": hr, "owned": owned,
				"name": "Tu casa alquilada" if owned else "Casa en venta para alquilar",
				"sub": Lang.f("Te paga %s al mes", Fmt.money(g.house_rent_of(float(g.houses[str(i)])))) if owned
						else Lang.f("Cuesta %s · te pagaría %s al mes", [Fmt.short(g.house_cost()), Fmt.money(g.house_rent_of(g.house_cost()))]),
				"color": HOUSE, "icon": "", "target": front, "yaw": 0.0 if h.face == -1 else 180.0, "clients": 0.0, "lost": 0.0,
				"label": "Tu casa" if owned else "$"})
	# Lugares de la ciudad
	var places := [
		["park", "Parque Central", "La fuente, la laguna, los juegos y el stand de muestras.", Rect2(-21, -55, 42, 42), Vector3(0, 0, -11), 180.0, "heart"],
		["beach", "Paseo de la Playa", "Terrenos frente al mar y la cancha de vóley.", Rect2(110, -58, 50, 116), Vector3(140, 0, -8), 180.0, "sun"],
		["pier", "Muelle", "Pesca en la punta del muelle.", Rect2(150, 22.8, 55, 2.4), Vector3(153, 0.42, 24), 90.0, "umbrella"],
		["plant", "Planta eléctrica", "Le da luz a la ciudad. Cuando falla, el arreglo se paga en su caseta.", PowerPlant.rects2d()[0], PowerPlant.PAY_SPOT, 0.0, "bolt"],
		["barrio", "Barrio Las Lomas", "Donde viven tus clientes. Casas en venta para alquilar y tablón de vecinos.", Rect2(-40, 30, 148, 28), Vector3(-44, 0, 43), 0.0, "person"],
	]
	for pl in places:
		out.append({"id": pl[0], "kind": "place", "rect": pl[3], "name": pl[1], "sub": pl[2], "color": PLACE, "icon": pl[6],
				"target": pl[4], "yaw": pl[5], "clients": 0.0, "lost": 0.0, "label": pl[1],
				"go": pl[0] != "beach"})   # a la playa se va con sus locales y terrenos, no con la zona entera
	return out


## Convierte (x, z) del mundo a la pantalla: `view` es el rectángulo del mapa, `center` el punto del mundo en su
## centro y `scale` los píxeles por metro.
static func to_screen(view: Rect2, center: Vector2, scale: float, x: float, z: float) -> Vector2:
	return view.get_center() + Vector2(x - center.x, -(z - center.y)) * scale


static func rect_to_screen(view: Rect2, center: Vector2, scale: float, r: Rect2) -> Rect2:
	var a := to_screen(view, center, scale, r.position.x, r.end.y)
	return Rect2(a, r.size * scale)


## Estilo (como los mapas de los juegos de ciudad más jugados y el modo noche de los mapas del teléfono): una base
## plana y apagada, calles con jerarquía (la avenida clara y ancha, los pasajes finos), edificios como manchas planas sin
## contorno claro, cada cosa importante con un ícono redondo de un solo color por categoría (borde fino oscuro, sin
## brillo ni halo) y el texto con contorno oscuro en vez de cajitas: zonas grandes y tenues, calles medianas y lugares
## chicos.
const C_LAND := Color8(36, 42, 39)
const C_HILLS := Color8(44, 46, 44)
const C_PARK := Color8(42, 70, 50)
const C_SAND := Color8(104, 95, 74)
const C_SEA := Color8(26, 48, 70)
const C_POND := Color8(42, 78, 108)
const C_BLOCK := Color8(56, 61, 70)      # edificios del fondo
const C_HOME := Color8(80, 74, 70)       # casas del barrio
const C_LANE := Color8(70, 74, 82)       # pasajes
const C_WALK := Color8(78, 82, 89)       # veredas
const C_ROAD := Color8(98, 102, 110)     # la avenida (la calle más importante, la más clara)
const C_PIER := Color8(96, 80, 60)
const C_INK := Color(0.05, 0.06, 0.08)   # bordes y contornos


## El fondo: pasto, cerros, barrio, parque, arena, mar, la avenida y el túnel.
static func draw_ground(ui: ImUI, view: Rect2, center: Vector2, scale: float) -> void:
	var f := func(r: Rect2) -> Rect2: return rect_to_screen(view, center, scale, r)
	ui.rect(view, C_LAND)
	ui.rect(f.call(Rect2(-400, -200, 282, 400)), C_HILLS)        # cerros del oeste
	ui.rect(f.call(Rect2(110, -200, 50, 400)), C_SAND)           # arena
	ui.rect(f.call(Rect2(160, -200, 300, 400)), C_SEA)           # mar
	ui.rect(f.call(Rect2(-21, -55, 42, 42)), C_PARK)             # parque
	ui.circle(to_screen(view, center, scale, 0, -34), 4.5 * scale, C_POND)   # fuente
	for lane in [[45.0, -40.0, 108.0], [-45.0, 28.0, 108.0]]:   # pasajes del barrio con sus casas
		ui.rect(f.call(Rect2(lane[1], lane[0] - 2.5, lane[2] - lane[1], 5)), C_LANE)
		for row in [9.5, -9.5]:
			var zc: float = lane[0] + row
			for x in range(int(lane[1]) + 8, int(lane[2]) - 4, 13):
				ui.rect(f.call(Rect2(x - 4, zc - 3.5, 8, 7)), C_HOME)
	for side in [-1, 1]:   # edificios altos del centro
		for x in range(-130, -39, 14):
			if side == -1 and x >= -102 and x <= -40:
				continue
			ui.rect(f.call(Rect2(x - 5, side * 54 - 5, 10, 10)), C_BLOCK)
	ui.rect(f.call(Rect2(150, 22.8, 55, 2.4)), C_PIER)          # muelle
	ui.rect(f.call(Rect2(-400, -7.5, 600, 15)), C_WALK)          # veredas
	ui.rect(f.call(Rect2(-400, -ROAD_HALF, 578, ROAD_HALF * 2)), C_ROAD)   # avenida
	var y := to_screen(view, center, scale, 0, 0).y
	var x := floorf((center.x - view.size.x / scale) / 8.0) * 8.0
	while x < center.x + view.size.x / scale:   # línea discontinua del medio (tenue)
		var a := to_screen(view, center, scale, x, 0)
		ui.line(Vector2(a.x, y), Vector2(a.x + 4 * scale, y), Color(0.85, 0.75, 0.4, 0.45), max(1.0, 0.2 * scale))
		x += 8.0
	var tun := to_screen(view, center, scale, Terrain.TUNNEL_X, 0)
	ui.rect(Rect2(tun.x - 3 * scale, tun.y - 9 * scale, 6 * scale, 18 * scale), Color8(24, 25, 28))


## Un ícono redondo (como los de los mapas de juegos): relleno de un solo color, borde fino oscuro, sin brillo.
## Con `icon` dibuja el ícono adentro; sin ícono, un punto del color `inner` (si hay).
static func blip(ui: ImUI, at: Vector2, radius: float, fill: Color, icon := "", inner = null) -> void:
	ui.circle(at, radius + 1.5, C_INK)
	ui.circle(at, radius, fill)
	if icon != "":
		Icons.draw(ui, icon, at, radius * 1.15, C_INK)
	elif inner != null:
		ui.circle(at, radius * 0.45, inner)


## Un edificio del mapa: su mancha plana y su ícono. `k` (0 a 1): el mouse encima (el ícono crece un poco y la mancha
## se aclara apenas; nada de bordes que brillen).
static func draw_item(ui: ImUI, it: Dictionary, r: Rect2, k: float, scale: float, logo := 0.0) -> void:
	var kind: String = it.kind
	var bl: float = (logo if logo > 0 else clampf(min(r.size.x, r.size.y) * 0.32, 6.0, 11.0)) * (1.0 + 0.25 * k)
	var lift := 0.08 * k   # al pasar el mouse la mancha se aclara un poco
	match kind:
		"mine":
			ui.rect(r, Color(it.color).darkened(0.45).lightened(lift), 2)
			blip(ui, r.get_center(), bl, GOLD, "", it.color)
		"rival":
			ui.rect(r, Color(it.color).darkened(0.55).lightened(lift), 2)
			if it.has("rival") and r.size.x > 10:
				ui.circle(r.get_center(), bl + 3.0, C_INK)
				Admin.rival_badge(ui, it.rival, r.get_center(), bl)
			else:
				blip(ui, r.get_center(), bl, RIVAL)
		"lot":
			ui.rect(r, Color(1, 1, 1, 0.04 + lift), 2)
			if str(it.icon) != "":   # el terreno de un centro comercial
				blip(ui, r.get_center(), bl, LOT, it.icon)
		"factory":
			ui.rect(r, Color8(64, 72, 80).lightened(lift), 2)
			blip(ui, r.get_center(), bl, FACTORY, it.icon)
		"house":
			if it.owned:
				ui.rect(r, HOUSE.darkened(0.45).lightened(lift), 1)
				blip(ui, r.get_center(), minf(bl, 7.0), HOUSE, "", C_INK)
			else:
				ui.rect(r, C_HOME.lightened(lift), 1)
		"place":
			if it.id in ["hq", "mall", "mall1"]:   # los que son un edificio: su mancha
				ui.rect(r, Color8(78, 70, 48).lightened(lift), 2)
			if it.icon:
				var c: Color = GOLD if it.id in ["hq", "mall", "mall1"] else PLACE
				var big: float = clampf(min(r.size.x, r.size.y) * 0.3, 8.0, 12.0) * (1.0 + 0.25 * k)
				blip(ui, r.get_center(), big, c, it.icon)


## Zonas de la ciudad sin un edificio que las nombre: [nombre, x, z].
const ZONES := [
	["DISTRITO FINANCIERO", -100.0, 34.0],
	["ENTRADA DE LA CIUDAD", -140.0, -31.0],
	["PARQUE INDUSTRIAL", -72.0, -51.0],
	["MAR", 190.0, -30.0],
	["TÚNEL", -165.0, -14.0],
]


## Texto con contorno oscuro (se lee sobre cualquier fondo sin necesitar una caja).
static func label(ui: ImUI, text: String, at: Vector2, size := 11, color = Color.WHITE, bold := true, anchor := "center") -> Rect2:
	for o in [Vector2(-1, 0), Vector2(1, 0), Vector2(0, -1), Vector2(0, 1), Vector2(1, 1)]:
		ui.text(text, at + o, size, Color(C_INK, 0.9), bold, anchor)
	return ui.text(text, at, size, color, bold, anchor)


## Nombres de las zonas en letras grandes, separadas y tenues, y el nombre de la avenida sobre la calle.
static func draw_zone_names(ui: ImUI, view: Rect2, center: Vector2, scale: float) -> void:
	for z in ZONES:
		var at := to_screen(view, center, scale, z[1], z[2])
		var t: String = " ".join(Lang.t(z[0]).split(""))   # letras separadas, como en los mapas
		label(ui, t, at, 12, Color(1, 1, 1, 0.42), true)
	for x in [-20.0, 85.0]:
		var at := to_screen(view, center, scale, x, 0)
		var t := Lang.t("AVENIDA COMERCIAL")
		var w := ui.text_size(t, 10, true).x + 14
		ui.rect(Rect2(at.x - w / 2, at.y - 7, w, 14), C_ROAD)   # tapa la línea del medio donde va el nombre
		ui.text(t, at, 10, Color(1, 1, 1, 0.75), true, "center")


## Etiqueta de un lugar: texto con contorno, centrado en `at` (con `dot`, un puntito de color adelante).
static func pill(ui: ImUI, text: String, at: Vector2, dot = null, size := 11) -> Rect2:
	var tw := ui.text_size(text, size, true).x
	var w := tw + (12.0 if dot != null else 0.0)
	var x := at.x - w / 2
	if dot != null:
		ui.circle(Vector2(x + 4, at.y), 4.5, C_INK)
		ui.circle(Vector2(x + 4, at.y), 3.2, dot)
		x += 12
	label(ui, text, Vector2(x, at.y), size, Color.WHITE, true, "midleft")
	return Rect2(at.x - w / 2, at.y - 8, w, 16)


## El nombre de cada edificio, debajo (o adentro) de su rectángulo. Si dos se pisan, gana el más importante (tus
## locales, después los rivales, los lugares, las fábricas y los terrenos).
static func draw_item_labels(ui: ImUI, view: Rect2, center: Vector2, scale: float, its: Array, skip := "") -> void:
	var taken := []
	for kind in ["mine", "rival", "place", "factory", "house", "lot"]:
		for it in its:
			if it.kind != kind or it.id == skip or str(it.get("label", "")) == "":
				continue
			var r := rect_to_screen(view, center, scale, it.rect)
			var text: String = Lang.t(it.label)
			var at := Vector2(r.get_center().x, r.end.y + 9)
			var inside: bool = kind == "place" or str(it.icon) != ""
			if inside:   # debajo del ícono, adentro del lugar
				at = r.get_center() + Vector2(0, clampf(min(r.size.x, r.size.y) * 0.3, 8.0, 12.0) + 11)
			if kind == "lot" and not inside:
				text = "$"
				at = r.get_center()
			if kind == "house" and not it.owned:
				at = r.get_center()
			var tw := ui.text_size(text, 11, true).x + 6
			var box := Rect2(at.x - tw / 2, at.y - 8, tw, 16)
			if not view.encloses(box):
				continue
			var clash := false
			for b in taken:
				if b.grow(1).intersects(box):
					clash = true
					break
			if clash:
				continue
			taken.append(box)
			match kind:
				"mine":
					label(ui, text, at, 11, Color8(250, 215, 130))
				"rival":
					label(ui, text, at, 11, Color8(255, 160, 150))
				"house":
					label(ui, text, at, 10 if not it.owned else 11, Color(1, 1, 1, 0.5) if not it.owned else Color8(160, 230, 220))
				"lot":
					label(ui, text, at, 10, Color(1, 1, 1, 0.45) if not inside else Color(1, 1, 1, 0.75))
				_:
					label(ui, text, at, 11, Color(1, 1, 1, 0.85))


## La flecha del jugador mirando hacia donde mira la cámara: blanca con borde oscuro, sin halo.
static func draw_player(ui: ImUI, at: Vector2, yaw_deg: float, size := 9.0) -> void:
	var a := deg_to_rad(yaw_deg)
	var fwd := Vector2(sin(a), -cos(a))   # en pantalla: +z del mundo es hacia arriba
	var right := Vector2(-fwd.y, fwd.x)
	var pts := PackedVector2Array([at + fwd * size, at - fwd * size * 0.6 + right * size * 0.65, at - fwd * size * 0.25,
			at - fwd * size * 0.6 - right * size * 0.65])
	ui.polyline(PackedVector2Array([pts[0], pts[1], pts[2], pts[3], pts[0]]), C_INK, 3.5)
	ui.polygon(pts, Color.WHITE)


## Minimapa de la HUD, centrado en el jugador, con el logo de cada rival en su local. Devuelve su rectángulo.
static func draw_mini(ui: ImUI, city, pos: Vector2) -> Rect2:
	var view := Rect2(pos, MINI_SIZE)
	var me := Vector2(city.player.position.x, city.player.position.z)
	ui.rect(view.grow(3), Color(0.03, 0.04, 0.06, 0.85), 14)
	ui.set_clip(view)
	draw_ground(ui, view, me, MINI_SCALE)
	for it in items(city):
		var r := rect_to_screen(view, me, MINI_SCALE, it.rect)
		if r.intersects(view):
			draw_item(ui, it, r, 0.0, MINI_SCALE, 9.0)
	draw_player(ui, view.get_center(), city.yaw, 7.0)
	ui.set_clip(null)
	ui.rect(view.grow(3), Color(0, 0, 0, 0.5), 14, 1.5)
	var tag := Lang.f("Mapa [%s]", Keys.label("map"))
	var tw := ui.text_size(tag, 12, true).x + 16
	var tr := Rect2(view.position.x + 8, view.position.y + 8, tw, 20)
	ui.rect(tr, Color(0.03, 0.04, 0.06, 0.8), 10)
	ui.text(tag, tr.get_center(), 12, Color.WHITE, true, "center")
	return view
