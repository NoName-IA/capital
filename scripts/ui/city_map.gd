class_name CityMap
extends RefCounted
## El mapa de la ciudad visto desde arriba: el minimapa de abajo a la izquierda y el mapa grande que se abre con la
## tecla M. Cada edificio es un rectángulo con su tamaño real: tus locales en dorado, los de la competencia en rojo,
## los terrenos en venta punteados y los lugares de la ciudad (oficina, parque, playa...) con su ícono. En el mapa
## grande, al pasar el mouse un edificio se agranda y muestra sus datos; con un clic te lleva hasta él.
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
				"color": c.rival.color, "icon": "", "target": t[0], "yaw": t[1], "clients": clients, "lost": 0.0})
	# Terrenos en venta
	for i in city.lots:
		var plot: Array = City.PLOTS[i]
		var t := plot_target(plot)
		var beach: bool = i in D.BEACH_PLOTS
		out.append({"id": "l%d" % i, "kind": "lot", "rect": plot_rect(plot, 1),
				"name": Lang.f("Terreno %d en venta%s", [i + 1, " · playa" if beach else ""]),
				"sub": Lang.f("Desde %s. Ve y apreta E para construir.", Fmt.short(g.location_cost(0))),
				"color": LOT, "icon": "", "target": t[0], "yaw": t[1], "clients": 0.0, "lost": 0.0})
	# Centro comercial (o su terreno en obra)
	var mall_t := Mall.entrance()
	if g.mall:
		var used: int = g.locations.filter(func(l): return Game.mall_of(l) >= 0).size()
		out.append({"id": "mall", "kind": "place", "rect": Mall.world_rect(), "name": "Tu centro comercial",
				"sub": Lang.f("%d de %d vitrinas ocupadas. Entra y apreta E frente a una vitrina libre.", [used, int(D.MALL.slots)]),
				"color": GOLD, "icon": "box", "target": mall_t, "yaw": 180.0, "clients": 0.0, "lost": 0.0})
	else:
		out.append({"id": "mall", "kind": "lot", "rect": Mall.world_rect(), "name": "Terreno del centro comercial",
				"sub": Lang.f("%d vitrinas para puestos y locales · cómpralo por %s", [int(D.MALL.slots), Fmt.short(g.mall_cost())]),
				"color": LOT, "icon": "", "target": mall_t, "yaw": 180.0, "clients": 0.0, "lost": 0.0})
	# Tu oficina central
	var hq_t := Blueprints.to_world(City.HQ, 0, -2.5)
	out.append({"id": "hq", "kind": "place", "rect": Rect2(City.HQ[0] - 9, 11, 18, 16), "name": "Tu oficina central",
			"sub": "Computadora, pizarra de estrategia, bolsa, trofeos y armario.", "color": GOLD, "icon": "building",
			"target": hq_t, "yaw": 0.0, "clients": 0.0, "lost": 0.0})
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
						"target": Vector3(fr.get_center().x, 0, fr.end.y + 3.0), "yaw": 180.0, "clients": 0.0, "lost": 0.0})
	# Lugares de la ciudad
	var places := [
		["park", "Parque Central", "La fuente, la laguna, los juegos y el stand de muestras.", Rect2(-21, -55, 42, 42), Vector3(0, 0, -11), 180.0, "heart"],
		["beach", "Paseo de la Playa", "Terrenos frente al mar y la cancha de vóley.", Rect2(110, -58, 50, 116), Vector3(140, 0, -8), 180.0, "sun"],
		["pier", "Muelle", "Pesca en la punta del muelle.", Rect2(150, 22.8, 55, 2.4), Vector3(153, 0.42, 24), 90.0, "umbrella"],
		["barrio", "Barrio Las Lomas", "Donde viven tus clientes. Tablón de vecinos para encuestas.", Rect2(-40, 30, 148, 28), Vector3(-44, 0, 43), 0.0, "person"],
	]
	for pl in places:
		out.append({"id": pl[0], "kind": "place", "rect": pl[3], "name": pl[1], "sub": pl[2], "color": PLACE, "icon": pl[6],
				"target": pl[4], "yaw": pl[5], "clients": 0.0, "lost": 0.0})
	return out


## Convierte (x, z) del mundo a la pantalla: `view` es el rectángulo del mapa, `center` el punto del mundo en su
## centro y `scale` los píxeles por metro.
static func to_screen(view: Rect2, center: Vector2, scale: float, x: float, z: float) -> Vector2:
	return view.get_center() + Vector2(x - center.x, -(z - center.y)) * scale


static func rect_to_screen(view: Rect2, center: Vector2, scale: float, r: Rect2) -> Rect2:
	var a := to_screen(view, center, scale, r.position.x, r.end.y)
	return Rect2(a, r.size * scale)


## El fondo: pasto, cerros, barrio, parque, arena, mar, la avenida y el túnel.
static func draw_ground(ui: ImUI, view: Rect2, center: Vector2, scale: float) -> void:
	var f := func(r: Rect2) -> Rect2: return rect_to_screen(view, center, scale, r)
	ui.rect(view, Color8(52, 78, 58))
	ui.rect(f.call(Rect2(-400, -200, 282, 400)), Color8(70, 74, 66))       # cerros del oeste
	ui.rect(f.call(Rect2(110, -200, 50, 400)), Color8(214, 196, 150))       # arena
	ui.rect(f.call(Rect2(160, -200, 300, 400)), Color8(44, 104, 160))       # mar
	ui.rect(f.call(Rect2(-21, -55, 42, 42)), Color8(64, 120, 70), 4 * scale)   # parque
	ui.circle(to_screen(view, center, scale, 0, -34), 4.5 * scale, Color8(90, 160, 210))   # fuente
	for lane in [[45.0, -40.0, 108.0], [-45.0, 28.0, 108.0]]:   # pasajes del barrio con sus casas
		ui.rect(f.call(Rect2(lane[1], lane[0] - 2.5, lane[2] - lane[1], 5)), Color8(84, 88, 96))
		for row in [9.5, -9.5]:
			var zc: float = lane[0] + row
			for x in range(int(lane[1]) + 8, int(lane[2]) - 4, 13):
				ui.rect(f.call(Rect2(x - 4, zc - 3.5, 8, 7)), Color8(196, 170, 150), 1)
	for side in [-1, 1]:   # edificios altos del centro
		for x in range(-130, -39, 14):
			if side == -1 and x >= -102 and x <= -40:
				continue
			ui.rect(f.call(Rect2(x - 5, side * 54 - 5, 10, 10)), Color8(120, 128, 140), 1)
	ui.rect(f.call(Rect2(150, 22.8, 55, 2.4)), Color8(150, 110, 70))                # muelle
	ui.rect(f.call(Rect2(-400, -7.5, 600, 15)), Color8(150, 150, 146))              # veredas
	ui.rect(f.call(Rect2(-400, -ROAD_HALF, 578, ROAD_HALF * 2)), Color8(62, 64, 70))   # avenida
	var y := to_screen(view, center, scale, 0, 0).y
	var x := floorf((center.x - view.size.x / scale) / 8.0) * 8.0
	while x < center.x + view.size.x / scale:   # línea discontinua del medio
		var a := to_screen(view, center, scale, x, 0)
		ui.line(Vector2(a.x, y), Vector2(a.x + 4 * scale, y), Color8(230, 200, 90), max(1.0, 0.25 * scale))
		x += 8.0
	var tun := to_screen(view, center, scale, Terrain.TUNNEL_X, 0)
	ui.rect(Rect2(tun.x - 3 * scale, tun.y - 9 * scale, 6 * scale, 18 * scale), Color8(40, 40, 44), 2)


## Un edificio del mapa. `k` (0 a 1) es cuánto se agranda (mouse encima).
static func draw_item(ui: ImUI, it: Dictionary, r: Rect2, k: float, scale: float) -> void:
	if k > 0:
		r = r.grow_individual(r.size.x * 0.22 * k, r.size.y * 0.22 * k, r.size.x * 0.22 * k, r.size.y * 0.22 * k)
	var kind: String = it.kind
	match kind:
		"mine":
			ui.rect(r, GOLD.darkened(0.15), 3)
			ui.rect(r, GOLD.lerp(Color.WHITE, 0.3 + k * 0.5), 3, 2.0 + k)
			# franja con el color del negocio
			ui.rect(Rect2(r.position.x + r.size.x * 0.2, r.get_center().y - max(1.5, r.size.y * 0.12), r.size.x * 0.6, max(3.0, r.size.y * 0.24)), it.color, 2)
		"rival":
			ui.rect(r, Color(it.color, 0.85), 3)
			ui.rect(r, RIVAL.lerp(Color.WHITE, k * 0.6), 3, 2.0 + k)
		"lot":
			ui.rect(r, Color(LOT, 0.12 + 0.2 * k), 3)
			ui.rect(r, Color(LOT, 0.7 + 0.3 * k), 3, 1.0 + k)
		"factory":
			ui.rect(r, Color8(110, 120, 130), 3)
			ui.rect(r, FACTORY.lerp(Color.WHITE, k * 0.6), 3, 2.0 + k)
		"place":
			ui.rect(r, Color(it.color, 0.08 + 0.18 * k), 4)
			ui.rect(r, Color(it.color, 0.45 + 0.5 * k), 4, 1.0 + k)
	if it.icon:
		var s: float = clampf(min(r.size.x, r.size.y) * 0.6, 10.0, 26.0) * (1.0 + 0.3 * k)
		ui.circle(r.get_center(), s * 0.62, Color(0.05, 0.07, 0.1, 0.75))
		Icons.draw(ui, it.icon, r.get_center(), s, it.color.lerp(Color.WHITE, 0.3))


## La flecha del jugador mirando hacia donde mira la cámara.
static func draw_player(ui: ImUI, at: Vector2, yaw_deg: float, size := 9.0) -> void:
	var a := deg_to_rad(yaw_deg)
	var fwd := Vector2(sin(a), -cos(a))   # en pantalla: +z del mundo es hacia arriba
	var right := Vector2(-fwd.y, fwd.x)
	var pts := PackedVector2Array([at + fwd * size, at - fwd * size * 0.6 + right * size * 0.65, at - fwd * size * 0.25,
			at - fwd * size * 0.6 - right * size * 0.65])
	ui.circle(at, size * 1.3, Color(1, 1, 1, 0.18))
	ui.polygon(pts, Color.WHITE)
	ui.polyline(PackedVector2Array([pts[0], pts[1], pts[2], pts[3], pts[0]]), Color8(30, 120, 220), 2)


## Minimapa de la HUD, centrado en el jugador. Devuelve su rectángulo.
static func draw_mini(ui: ImUI, city, pos: Vector2) -> Rect2:
	var view := Rect2(pos, MINI_SIZE)
	var me := Vector2(city.player.position.x, city.player.position.z)
	ui.rect(view.grow(3), Color(0.03, 0.04, 0.06, 0.85), 14)
	ui.set_clip(view)
	draw_ground(ui, view, me, MINI_SCALE)
	for it in items(city):
		var r := rect_to_screen(view, me, MINI_SCALE, it.rect)
		if r.intersects(view):
			draw_item(ui, it, r, 0.0, MINI_SCALE)
	draw_player(ui, view.get_center(), city.yaw, 7.0)
	ui.set_clip(null)
	ui.rect(view.grow(3), Color(1, 1, 1, 0.14), 14, 1.5)
	var tag := Lang.f("Mapa [%s]", Keys.label("map"))
	var tw := ui.text_size(tag, 12, true).x + 16
	var tr := Rect2(view.position.x + 8, view.position.y + 8, tw, 20)
	ui.rect(tr, Color(0.03, 0.04, 0.06, 0.8), 10)
	ui.text(tag, tr.get_center(), 12, Color.WHITE, true, "center")
	return view
