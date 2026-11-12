class_name Overlays
extends RefCounted
## Ventanas que se abren encima de la ciudad: el celular (administración), la compra de un terreno, el menú de
## pausa con sus ajustes y controles, el armario, la vitrina de trofeos y la reunión de estrategia.

const TIERS := [["Bronce", Color8(205, 127, 50)], ["Bronce", Color8(205, 127, 50)], ["Plata", Color8(205, 210, 222)],
		["Plata", Color8(205, 210, 222)], ["Oro", Color8(245, 192, 60)], ["Oro", Color8(245, 192, 60)],
		["Diamante", Color8(120, 220, 245)], ["Diamante", Color8(120, 220, 245)], ["Diamante", Color8(120, 220, 245)],
		["Leyenda", Color8(255, 120, 200)]]
const W := 1280.0
const H := 760.0

var city
var ui: ImUI
var app: Admin
var mode = null       # null (cerrado), "admin", "lote", "pausa", "personaje", "estrategia", "trofeos"
var lot := -1
var auto := false
var pause_page := "main"
var tutorial_page := 0
var tutorial_tex := {}
# Tutorial de la primera partida: [imagen, título, texto]
## La bienvenida: después siguen los pasos guiados jugando (ver Tutorial).
const TUTORIAL := [
	["meta", "Bienvenido a Capital", ""],
]
## Al terminar el tutorial: tres consejos y a jugar.
const TUTORIAL_END := [
	["ganar", "", ""],
]
const END_TIPS := ["Abre más locales.", "20 días en números negativos provocan bancarrota.", "Cuidado con la competencia."]
## En el tutorial, al abrir la tablet: cómo se gana (cuánto vale tu empresa).
const TUTORIAL_VALOR := [
	["valor", "Así se gana", ""],
]
var tutorial_return := ""      # la ventana que estaba abierta antes de la tarjeta (para volver a ella)
var tutorial_pages: Array = TUTORIAL   # la bienvenida o las claves para ganar
var shop_tab := "cabeza"
var trying = null           # prenda que te estás probando en el armario (sin comprar): {key, value, name, price}
var buy_key := "cafe"
var decor_pick := ""         # artículo elegido con un clic (queda puesto hasta que lo compras o lo quitas)
var decor_hover := ""        # artículo de la decoración bajo el mouse (la cámara va ahí y se ve puesto)
var buy_mall_slot := -1     # vitrina del rival que le quieres comprar (-1: un local de la calle)
var question = null          # confirmación en la ciudad (modo "confirmar"): {title, detail, yes, action}        # negocio del local de la competencia que estás por comprar (modo "compra")
var saved_at := -9999


func _init(owner_city, imui: ImUI, admin: Admin) -> void:
	city = owner_city
	ui = imui
	app = admin


func open() -> bool:
	return mode != null


func show(new_mode: String, lot_index := -1, is_auto := false) -> void:
	mode = new_mode
	lot = lot_index
	lang_pick = -1
	auto = is_auto
	city.release_mouse()


func hide() -> void:
	mode = null
	auto = false
	city.capture_mouse()


func draw() -> void:
	_draw_mode()
	# El mentor no desaparece en todo el tutorial (con la tablet abierta habla sin que tengas que esperar)
	if city.tutorial.active and app.view == "game" and mode in ["admin", "lote", "vitrina"]:
		city.tutorial.draw_mentor(ui)


func _draw_mode() -> void:
	match mode:
		"admin":
			if app.view == "menu" or app.game == null:
				menu_backdrop(app.slot_screen == null and not app.pick_mode and not app.naming and not app.settings_open
						and not app.credits_open)
				if app.settings_open:
					draw_menu_settings()
				elif app.credits_open:
					draw_credits()
				else:
					app.draw_menu()
			else:
				draw_tablet_frame()
				app.draw_game()
				city.tutorial.draw_phone(ui)
				# Un clic fuera de la tablet la guarda
				if ui.clicked and app.modal == null and not Rect2(-30, -30, W + 60, H + 60).has_point(ui.mouse):
					hide()
		"lote", "vitrina":
			ui.rect(Rect2(0, 0, W, H), Color(0, 0, 0, 0.35))
			draw_lot()
		"compra":
			ui.rect(Rect2(0, 0, W, H), Color(0, 0, 0, 0.45))
			draw_buy_competitor()
		"mapa":
			draw_map()
		"confirmar":
			ui.rect(Rect2(-4000, -4000, W + 8000, H + 8000), Color(0, 0, 0, 0.45))
			if question == null:
				hide()
			else:
				match Admin.confirm_box(ui, question.title, question.detail, question.yes, app.game.cash):
					1:
						var action: Callable = question.action
						question = null
						hide()
						action.call()
					2:
						question = null
						hide()
		"pausa":
			draw_pause()
		"personaje":
			draw_custom()
		"decorar":
			draw_decor()
		"pc":
			city.pc_os.draw(ui)
		"estrategia":
			ui.rect(Rect2(0, 0, W, H), Color(0, 0, 0, 0.35))
			draw_strategy()
		"trofeos":
			ui.rect(Rect2(0, 0, W, H), Color(0, 0, 0, 0.35))
			draw_trophies()
		"tutorial":
			ui.rect(Rect2(0, 0, W, H), Color(0, 0, 0, 0.55))
			draw_tutorial()


## Fondo de los menús de pantalla completa: la ciudad se ve a la derecha y la izquierda se oscurece para el texto.
## Cubre toda la ventana aunque sea más ancha que la pantalla virtual. `open` deja ver más la ciudad.
func menu_backdrop(open := true) -> void:
	var dark := Color(0.025, 0.03, 0.045, 0.94)
	var far := 4000.0
	ui.rect(Rect2(-far, -far, far, H + far * 2), dark)
	ui.gradient(Rect2(0, -far, W * 0.62, H + far * 2), dark, Color(dark, 0.55 if open else 0.8))
	ui.rect(Rect2(W * 0.62, -far, W * 0.38 + far, H + far * 2), Color(dark, 0.55 if open else 0.8))
	ui.gradient(Rect2(-far, H - 160, W + far * 2, 160), Color(dark, 0.0), Color(dark, 0.6), false)


## Marco de la tablet: borde negro redondeado con la cámara arriba y un brillo en el canto.
func draw_tablet_frame() -> void:
	ui.rect(Rect2(-34, -34, W + 68, H + 68), Color8(16, 17, 21), 40)
	ui.rect(Rect2(-34, -34, W + 68, H + 68), Color8(70, 74, 84), 40, 2)
	ui.circle(Vector2(W / 2, -17), 5, Color8(40, 44, 54))
	ui.circle(Vector2(W / 2, -17), 2, Color8(70, 90, 130))


func glass_box(r: Rect2) -> void:
	ui.rect(r, Color(COL_PANEL, 0.96), 18)
	ui.rect(r, ImUI.COL.border, 18, 1)


const COL_PANEL := Color8(22, 27, 34)


# ---------- compra de un terreno ----------
## Terreno de la avenida en venta, o vitrina vacía del centro comercial (modo "vitrina": solo puestos y locales).
func draw_lot() -> void:
	var g: Game = app.game
	var tut_rect := Rect2()
	var in_mall: bool = mode == "vitrina"
	var beach: bool = lot in D.BEACH_PLOTS and not in_mall
	ui.panel(Rect2(40, 30, W - 80, H - 60))
	var mi := Game.mall_index(lot) if in_mall else 0
	var mall_d: Dictionary = D.MALLS[mi]
	if in_mall:
		ui.text(Lang.f("Vitrina %d · %s", [lot % int(D.MALL.slots) + 1, mall_d.name]), Vector2(70, 60), 32, "accent", true)
	else:
		ui.text(Lang.f("Terreno %d en venta%s", [lot + 1, " · en la playa" if beach else ""]), Vector2(70, 60), 32, "accent", true)
	var y0 := 110.0
	if beach:
		ui.text(Lang.f("Frente al mar: +%d%% de clientes por los turistas.", roundi((D.BEACH_BONUS - 1) * 100)), Vector2(72, 98), 16, "green", true)
		y0 = 128
	elif in_mall:
		ui.text(Lang.f("+%d%% de clientes, techado y mitad de alquiler.", roundi((mall_d.traffic - 1) * 100)), Vector2(72, 98), 16, "green", true)
		y0 = 128
	ui.wrap_text("Elige qué abrir. Más grande = más clientes, pero más alquiler.", Rect2(70, y0, W - 140, 40), 16, "muted")
	ui.text(Lang.f("Caja disponible: %s", Fmt.money(g.cash)), Vector2(W - 70, 64), 20, Admin.sc(g.cash), true, "topright")
	var y := 200.0
	for key in D.PRODUCT_ORDER:
		var p: Dictionary = g.products[key]
		var d: Dictionary = D.PRODUCTS[key]
		ui.text(d.name, Vector2(70, y + 8), 22, "text" if p.unlocked else "muted", true)
		if not p.unlocked:
			ui.text(Lang.f("Bloqueado: desbloquéalo en la tablet (Negocios) por %s", Fmt.money(g.unlock_cost(key))), Vector2(290, y + 12), 16, "muted")
		else:
			for s in (2 if in_mall else D.SIZES.size()):
				var size: Dictionary = D.SIZES[s]
				var cost := g.location_cost(s)
				var rent: float = size.rent * g.price_index * (mall_d.rent_mult if in_mall else 1.0)
				var tip := Lang.f("%s: cuesta %s, alquiler %s/mes, hasta %d empleados.", [size.name, Fmt.money(cost), Fmt.money(rent), size.max_emp])
				if key == "cafe" and s == 0:
					tut_rect = Rect2(290 + s * 300, y, 285, 44)
				if ui.button(Rect2(290 + s * 300, y, 285, 44), Lang.f("%s · %s", [size.name, Fmt.money(cost)]), g.cash >= cost, "normal", 15, tip):
					var plot := lot
					var k: String = key
					var sz: int = s
					var build := func():
						var res: Array = g.open_location(k, sz, null, plot) if in_mall else g.open_location(k, sz, plot)
						if res[0]:
							city.sfx.play("record", 0.7)
						city.toast(res[1], "good" if res[0] else "bad")
					hide()   # se abre al tiro, sin preguntar (puesto, local o megatienda)
					build.call()
					return
		y += 74
	if ui.button(Rect2(W / 2 - 140, H - 100, 280, 44), "Cancelar (Esc)"):
		hide()
		return
	# Tutorial: la flecha señala el puesto de café
	var tut: Tutorial = city.tutorial
	if tut.active and Tutorial.STEPS[tut.step] == "comprar" and tut_rect.size.x > 0:
		Tutorial.spotlight(ui, tut_rect.grow(8))
		Tutorial.big_arrow(ui, tut_rect)


# ---------- comprar el local de la competencia que tienes enfrente ----------
func draw_buy_competitor() -> void:
	var g: Game = app.game
	var key := buy_key
	var r := D.rival_for(key)
	var owner = g.plot_owner.get(str(lot))
	if owner != null:
		r = D.rival_by_key(owner)
	var p: Dictionary = g.products[key]
	var cost := g.acquire_cost(key)
	var name: String = Lang.noun(D.PRODUCTS[key].name)
	var box := Rect2(W / 2 - 330, H / 2 - 190, 660, 380)
	ui.rect(box.grow(8), Color(0, 0, 0, 0.35), 24)
	ui.rect(box, Color8(18, 22, 30), 20)
	ui.rect(box, Color(r.color, 0.6), 20, 1.5)
	var ic := box.position + Vector2(70, 72)
	Admin.rival_badge(ui, r, ic, 36)
	ui.text("COMPRAR LOCAL DE LA COMPETENCIA", Vector2(box.position.x + 124, box.position.y + 40), 13, Notifications.light(r.color, 0.3), true)
	ui.text(Lang.f("%s de %s", [r.company, name]), Vector2(box.position.x + 124, box.position.y + 60), 28, "text", true, "topleft", box.size.x - 150)
	var text := Lang.f("Pagas %s y este mismo edificio pasa a ser tuyo: un local con 3 empleados que ya tiene clientes. %s pierde un local (te quedas con un competidor menos en %s). Lo que pagas por encima del valor del edificio es plusvalía.", [Fmt.money(cost), r.short, name])
	if not p.unlocked:
		text = Lang.f("Todavía no tienes el negocio de %s. Desbloquéalo primero en la tablet (Negocios) para poder comprar este local.", name)
	ui.wrap_text(text, Rect2(box.position.x + 40, box.position.y + 130, box.size.x - 80, 120), 17, Color8(215, 222, 232))
	ui.text(Lang.f("Caja disponible: %s", Fmt.money(g.cash)), Vector2(box.get_center().x, box.end.y - 104), 16, Admin.sc(g.cash), true, "center")
	var can: bool = p.unlocked and g.cash >= cost and p.competitors > 0
	if ui.button(Rect2(box.position.x + 40, box.end.y - 76, 280, 46), Lang.f("Sí, comprar (%s)", Fmt.short(cost)), can, "primary", 17):
		if randf() < 0.5:   # el rival no siempre quiere vender
			hide()
			city.refuse(lot, buy_mall_slot)
			city.sfx.play("angry", 0.6)
			city.toast(Lang.f("%s no quiso venderte este local.", r.company), "bad")
			return
		var res := g.acquire(key, lot, buy_mall_slot)
		if res[0]:
			hide()
			city.sync(g)
			city.sfx.play("record", 0.7)
		city.toast(res[1], "good" if res[0] else "bad")
		return
	if ui.button(Rect2(box.end.x - 320, box.end.y - 76, 280, 46), "No (Esc)", true, "normal", 17):
		hide()


# ---------- mapa grande de la ciudad (tecla M) ----------
var map_hover := ""


func draw_map() -> void:
	var g: Game = app.game
	var far := 4000.0
	ui.rect(Rect2(-far, -far, W + far * 2, H + far * 2), Color(0.02, 0.03, 0.045, 0.93))
	ui.text("MAPA DE LA CIUDAD", Vector2(28, 22), 26, "accent", true)
	ui.text(Lang.f("Pasa el mouse sobre un edificio para ver sus datos · Clic para ir ahí · %s o Esc para cerrar", Keys.label("map")),
			Vector2(28, 56), 14, "muted")
	var view := Rect2(20, 86, W - 40, (W - 40) * CityMap.WORLD.size.y / CityMap.WORLD.size.x)
	var scale := view.size.x / CityMap.WORLD.size.x
	var center := CityMap.WORLD.get_center()
	ui.set_clip(view)
	CityMap.draw_ground(ui, view, center, scale)
	var its := CityMap.items(city)
	# El que está bajo el mouse: el más chico que lo contiene (los lugares grandes quedan por debajo)
	var hot = null
	var best := INF
	for it in its:
		var r := CityMap.rect_to_screen(view, center, scale, it.rect).grow(3)
		if r.has_point(ui.mouse) and view.has_point(ui.mouse) and r.get_area() < best:
			best = r.get_area()
			hot = it
	map_hover = hot.id if hot != null else ""
	var order := ["place", "lot", "factory", "rival", "mine"]
	for kind in order:
		for it in its:
			if it.kind != kind or (hot != null and it.id == hot.id):
				continue
			var k := ui.tween("map" + it.id, 0.0, 0.3)
			CityMap.draw_item(ui, it, CityMap.rect_to_screen(view, center, scale, it.rect), k, scale)
	var me := CityMap.to_screen(view, center, scale, city.player.position.x, city.player.position.z)
	CityMap.draw_player(ui, me, city.yaw, 10.0)
	if hot != null:   # el elegido va encima de todo y se agranda
		var k := ui.tween("map" + hot.id, 1.0, 0.3)
		CityMap.draw_item(ui, hot, CityMap.rect_to_screen(view, center, scale, hot.rect), k, scale)
	ui.set_clip(null)
	ui.rect(view, Color(1, 1, 1, 0.15), 0, 1.5)
	# Ficha del edificio bajo el mouse
	if hot != null:
		var tw: float = maxf(ui.text_size(hot.name, 17, true).x, ui.text_size(hot.sub, 13).x) + 36
		tw = minf(tw, 520.0)
		var tp := ui.mouse + Vector2(18, 18)
		if tp.x + tw > W - 10:
			tp.x = ui.mouse.x - tw - 18
		var card := Rect2(tp, Vector2(tw, 84))
		ui.rect(card, Color(0.04, 0.05, 0.07, 0.96), 12)
		ui.rect(card, Color(hot.color, 0.8), 12, 1.5)
		ui.text(hot.name, card.position + Vector2(16, 12), 17, "text", true, "topleft", tw - 32)
		ui.text(hot.sub, card.position + Vector2(16, 38), 13, "muted", false, "topleft", tw - 32)
		ui.text("Clic para ir aquí", card.position + Vector2(16, 60), 13, "accent", true)
		if ui.clicked:
			city.teleport(hot.target, hot.yaw, hot.name)
			hide()
			return
	# Abajo: resumen de clientes y leyenda
	var y := view.end.y + 14
	var mine := its.filter(func(it): return it.kind == "mine")
	var rivals := its.filter(func(it): return it.kind == "rival")
	var my_total := 0.0
	for it in mine:
		my_total += it.clients
	var rival_total := 0.0
	for it in rivals:
		rival_total += it.clients
	var lost := 0.0
	for it in mine:
		lost += it.lost
	ui.panel(Rect2(20, y, 560, H - y - 16), "Clientes que compran hoy")
	var ly := y + 46
	ly = ui.row(36, ly, 528, "En tus locales de la avenida", Lang.f("%s al día", Fmt.num(my_total)), "accent")
	ly = ui.row(36, ly, 528, "Se fueron sin comprar (falta personal o stock)", Fmt.num(lost), "orange" if lost > 1 else "text")
	ly = ui.row(36, ly, 528, "En la competencia (aprox.)", Lang.f("%s al día", Fmt.num(rival_total)), "red")
	var share := my_total / (my_total + rival_total) if my_total + rival_total > 0 else 0.0
	ly += 6
	ui.text(Lang.f("Tu parte de los clientes de la avenida: %s", Fmt.pct(share, 0)), Vector2(36, ly), 14, "text", true)
	ui.bar(Rect2(36, ly + 24, 528, 10), share, "accent", "red")
	# Los locales que más venden
	var top := mine.duplicate()
	top.sort_custom(func(a, b): return a.clients > b.clients)
	var rp := ui.panel(Rect2(592, y, 380, H - y - 16), "Tus locales con más clientes")
	var ty := rp.position.y + 44
	var mx := 1.0
	for it in top:
		mx = maxf(mx, it.clients)
	for it in top.slice(0, 4):
		var row := Rect2(rp.position.x + 12, ty - 2, rp.size.x - 24, 24)
		if ui.hover(row):
			ui.rect(row, Color(1, 1, 1, 0.06), 6)
			map_hover = it.id
			if ui.clicked:
				city.teleport(it.target, it.yaw, it.name)
				hide()
				return
		ui.text(it.name.trim_prefix("Tu "), Vector2(rp.position.x + 18, ty), 13, "text", false, "topleft", 200)
		ui.bar(Rect2(rp.position.x + 226, ty + 5, 90, 8), it.clients / mx, "accent")
		ui.text(Fmt.num(it.clients), Vector2(rp.end.x - 16, ty), 13, "accent", true, "topright")
		ty += 26
	if top.is_empty():
		ui.text("Todavía no tienes locales en la avenida.", Vector2(rp.position.x + 18, ty), 14, "muted")
	var lg := ui.panel(Rect2(984, y, W - 1004, H - y - 16), "Leyenda")
	var gy := lg.position.y + 44
	for e in [[CityMap.GOLD, "Tus locales"], [CityMap.RIVAL, "Competencia"], [CityMap.LOT, "Terreno en venta"], [CityMap.FACTORY, "Tus fábricas"], [CityMap.PLACE, "Lugares"]]:
		ui.rect(Rect2(lg.position.x + 16, gy + 2, 14, 14), e[0], 3)
		ui.text(e[1], Vector2(lg.position.x + 40, gy), 13, "text")
		gy += 22
	if ui.clicked and not view.has_point(ui.mouse) and ui.mouse.y < view.position.y - 40:
		pass


# ---------- menú de pausa ----------
const PAUSE_PAGES := [["main", "AJUSTES"], ["graficos", "GRÁFICOS"], ["controles", "CONTROLES"]]
const ROW_H := 46.0
var lang_pick := -1          # idioma elegido en Ajustes que todavía no se aplicó (-1: el actual)
var row_desc = null         # descripción de la fila bajo el mouse (se muestra abajo, como en los juegos grandes)
var binding = null          # acción de Controles que espera una tecla nueva
var settings_scroll := 0.0


## Como en los videojuegos: la lista de opciones grande a la izquierda y la sección elegida a la derecha, sin
## recuadro: filas a lo ancho con el nombre a la izquierda y el control a la derecha.
func draw_pause() -> void:
	menu_backdrop(true)
	var g: Game = app.game
	var x := 70.0
	ui.text("JUEGO EN PAUSA", Vector2(x + 2, 52), 14, "muted", true)
	ui.text("PAUSA", Vector2(x - 2, 66), 64, "accent", true)
	ui.rect(Rect2(x, 146, 90, 4), "accent", 2)
	if g != null:
		var info := g.rank_info()
		ui.text(g.company, Vector2(x, 162), 18, "text", true, "topleft", 300)
		ui.text(Lang.f("%s · %s", [info[1], Fmt.short(info[3])]), Vector2(x, 188), 14, "muted", false, "topleft", 300)
	var y := 240.0
	if ui.menu_item("p:continuar", Vector2(x, y), "CONTINUAR", "", true, 24, 310.0):
		city.close_pause()
		return
	y += 54
	for page in PAUSE_PAGES:
		if ui.menu_item("p:" + page[0], Vector2(x, y), page[1], "", true, 24, 310.0, pause_page == page[0]):
			pause_page = page[0]
			binding = null
			settings_scroll = 0.0
		y += 54
	var just_saved := Time.get_ticks_msec() - saved_at < 2500
	if ui.menu_item("p:guardar", Vector2(x, y), "GUARDAR PARTIDA", Lang.f("¡Guardada en el espacio %d!", app.slot) if just_saved else "",
			true, 24, 310.0, false, "green" if just_saved else "accent"):
		app.save(true)
		city.toast(Lang.f("Partida guardada en el espacio %d.", app.slot), "good")
		saved_at = Time.get_ticks_msec()
	y += 74 if just_saved else 54
	if ui.menu_item("p:menu", Vector2(x, y), "MENÚ PRINCIPAL", "", true, 24, 310.0):
		city.close_pause()
		app.save(true)
		app.view = "menu"
		show("admin")
		return
	# (para cerrar el juego se va al menú principal: desde la partida no se sale directo)
	ui.text("Esc: volver al juego", Vector2(x, H - 40), 13, "muted")
	# Panel derecho: una línea vertical lo separa del menú, sin recuadro
	ui.gradient(Rect2(420, 40, 1, H - 80), Color(1, 1, 1, 0.0), Color(1, 1, 1, 0.12), false)
	var area := Rect2(470, 40, W - 520, H - 80)
	row_desc = null
	match pause_page:
		"graficos":
			draw_graphics(area)
		"controles":
			draw_controls(area)
		_:
			draw_settings(area)
	_draw_row_desc(area)


## Ajustes desde el menú de inicio: las mismas secciones que en la pausa.
func draw_menu_settings() -> void:
	var x := 70.0
	ui.text("CAPITAL", Vector2(x + 2, 52), 14, "muted", true)
	ui.text("AJUSTES", Vector2(x - 2, 66), 56, "accent", true)
	ui.rect(Rect2(x, 140, 90, 4), "accent", 2)
	var y := 240.0
	for page in PAUSE_PAGES:
		if ui.menu_item("m:" + page[0], Vector2(x, y), page[1], "", true, 24, 310.0, pause_page == page[0]):
			pause_page = page[0]
			binding = null
		y += 54
	if ui.menu_item("m:volver", Vector2(x, y + 20), "VOLVER", "Esc", true, 24, 310.0):
		close_menu_settings()
		return
	ui.gradient(Rect2(420, 40, 1, H - 80), Color(1, 1, 1, 0.0), Color(1, 1, 1, 0.12), false)
	var area := Rect2(470, 40, W - 520, H - 80)
	row_desc = null
	match pause_page:
		"graficos":
			draw_graphics(area)
		"controles":
			draw_controls(area)
		_:
			draw_settings(area)
	_draw_row_desc(area)


func close_menu_settings() -> void:
	app.settings_open = false
	lang_pick = -1
	pause_page = "main"
	binding = null
	city.save_settings()


## Título de la sección arriba del panel derecho.
func section_title(area: Rect2, title: String, sub: String) -> float:
	ui.text(title.to_upper(), area.position + Vector2(0, 12), 34, "text", true)
	ui.text(sub, area.position + Vector2(2, 58), 14, "muted", false, "topleft", area.size.x)
	return area.position.y + 96


func group_title(area: Rect2, y: float, title: String) -> float:
	ui.text(title, Vector2(area.position.x + 16, y + 12), 13, "accent", true)
	ui.rect(Rect2(area.position.x + 16 + ui.text_size(title, 13, true).x + 12, y + 20, area.size.x - 32 - ui.text_size(title, 13, true).x - 12, 1),
			Color(1, 1, 1, 0.08))
	return y + 38


## Fondo de una fila: se ilumina con una barra de color al pasar el mouse. Devuelve si está bajo el mouse.
func row_bg(area: Rect2, y: float, key: String, desc: String) -> bool:
	var r := Rect2(area.position.x, y, area.size.x, ROW_H - 4)
	var hot := ui.hover(r) and binding == null
	var k := ui.tween("row:" + key, 1.0 if hot else 0.0)
	ui.rect(r, Color(1, 1, 1, 0.035 + 0.05 * k), 8)
	if k > 0.01:
		ui.gradient(r, Color(ImUI.COL.accent, 0.12 * k), Color(ImUI.COL.accent, 0.0))
		ui.rect(Rect2(r.position.x, r.position.y + 6, 3, r.size.y - 12), Color(ImUI.COL.accent, k), 2)
	if hot:
		row_desc = desc
	return hot


func row_label(area: Rect2, y: float, label: String) -> void:
	ui.text(label, Vector2(area.position.x + 20, y + (ROW_H - 4) / 2), 17, "text", false, "midleft")


## Fila con barra deslizante.
func row_slider(area: Rect2, y: float, label: String, key: String, lo: float, hi: float, fmt: Callable, desc: String) -> float:
	var s: Dictionary = city.settings
	row_bg(area, y, key, desc)
	row_label(area, y, label)
	var w: float = min(260.0, area.size.x * 0.4)   # en media columna, la barra es más corta
	var x := area.end.x - 80 - w
	var cy := y + (ROW_H - 4) / 2
	var bar := Rect2(x, cy - 3, w, 6)
	if ui.hover(Rect2(x - 10, y, w + 20, ROW_H - 4)) and (ui.clicked or ui.down):
		s[key] = lo + clampf((ui.mouse.x - x) / w, 0, 1) * (hi - lo)
		city.apply_settings()
	var frac: float = (s[key] - lo) / (hi - lo)
	ui.rect(bar, Color(1, 1, 1, 0.12), 3)
	ui.rect(Rect2(x, bar.position.y, max(6.0, w * frac), 6), "accent", 3)
	ui.circle(Vector2(x + w * frac, cy), 9, Color.WHITE)
	ui.text(fmt.call(s[key]), Vector2(area.end.x - 20, cy), 16, "accent", true, "midright")
	return y + ROW_H


## Fila con selector de flechas (izquierda, valor, derecha): un clic en la fila pasa al siguiente.
func row_choice(area: Rect2, y: float, label: String, key: String, labels: Array, current: int, pick: Callable, desc: String) -> float:
	var hot := row_bg(area, y, key, desc)
	row_label(area, y, label)
	var cy := y + (ROW_H - 4) / 2
	var w := 260.0
	var x := area.end.x - 20 - w
	var left := Rect2(x, cy - 15, 30, 30)
	var right := Rect2(x + w - 30, cy - 15, 30, 30)
	var lh := ui.hover(left)
	var rh := ui.hover(right)
	Icons.draw(ui, "arrow_left", left.get_center(), 16, ImUI.COL.accent if lh else ImUI.COL.muted)
	Icons.draw(ui, "arrow_right", right.get_center(), 16, ImUI.COL.accent if rh else ImUI.COL.muted)
	ui.text(labels[current], Vector2(x + w / 2, cy), 17, "text", true, "center")
	# puntitos con la posición del valor
	for i in labels.size():
		ui.circle(Vector2(x + w / 2 + (i - (labels.size() - 1) / 2.0) * 12, cy + 15), 2.5,
				ImUI.COL.accent if i == current else Color(1, 1, 1, 0.2))
	if ui.clicked and hot:
		var n := (current + (labels.size() - 1 if lh else 1)) % labels.size()
		pick.call(n)
		city.apply_settings()
	return y + ROW_H


## Fila con interruptor (Sí / No).
func row_toggle(area: Rect2, y: float, label: String, key: String, desc: String, action = null) -> float:
	var s: Dictionary = city.settings
	var hot := row_bg(area, y, key, desc)
	row_label(area, y, label)
	var cy := y + (ROW_H - 4) / 2
	var on: bool = s[key]
	var r := Rect2(area.end.x - 20 - 52, cy - 13, 52, 26)
	var k := ui.tween("tog:" + key, 1.0 if on else 0.0, 0.3)
	ui.rect(r, Color(1, 1, 1, 0.14).lerp(ImUI.COL.green, k), 13)
	ui.circle(Vector2(lerpf(r.position.x + 13, r.end.x - 13, k), cy), 10, Color.WHITE)
	ui.text("Sí" if on else "No", Vector2(r.position.x - 12, cy), 15, "green" if on else "muted", true, "midright")
	if ui.clicked and hot:
		if action != null:
			action.call()
		else:
			s[key] = not on
		city.apply_settings()
	return y + ROW_H


## Fila del idioma: con las flechas se elige y con «Aplicar cambios» se cambia todo el juego. Cada idioma se
## nombra en el idioma actual y abajo, chiquito, en el suyo (para encontrarlo aunque no entiendas el actual).
func row_lang(area: Rect2, y: float) -> float:
	var n: int = Lang.CODES.size()
	if lang_pick < 0:
		lang_pick = Lang.index()
	var hot := row_bg(area, y, "lang", "El idioma de todo el juego. Elige uno con las flechas y toca «Aplicar cambios». Language · Idioma")
	row_label(area, y, "Idioma")
	var cy := y + (ROW_H - 4) / 2
	var bw := 170.0
	var apply := Rect2(area.end.x - 14 - bw, cy - 15, bw, 30)
	var w := 260.0
	var x := apply.position.x - 10 - w
	var left := Rect2(x, cy - 15, 30, 30)
	var right := Rect2(x + w - 30, cy - 15, 30, 30)
	var lh := ui.hover(left)
	var rh := ui.hover(right)
	Icons.draw(ui, "arrow_left", left.get_center(), 16, ImUI.COL.accent if lh else ImUI.COL.muted)
	Icons.draw(ui, "arrow_right", right.get_center(), 16, ImUI.COL.accent if rh else ImUI.COL.muted)
	var name := Lang.name_in(lang_pick)
	var own: String = Lang.NAMES[lang_pick]
	if name == own:
		ui.text(name, Vector2(x + w / 2, cy), 16, "text", true, "center")
	else:
		ui.text(name, Vector2(x + w / 2, cy - 7), 15, "text", true, "center")
		ui.text(own, Vector2(x + w / 2, cy + 11), 12, "muted", false, "center")
	var changed := lang_pick != Lang.index()
	if ui.button(apply, "Aplicar cambios", changed, "primary", 14):
		city.settings.lang = Lang.CODES[lang_pick]
		Lang.use(Lang.CODES[lang_pick])
		city.save_settings()
	elif ui.clicked and hot and (lh or rh or Rect2(x, cy - 15, w, 30).has_point(ui.mouse)):
		lang_pick = (lang_pick + (n - 1 if lh else 1)) % n
	return y + ROW_H


## Descripción de la fila bajo el mouse, abajo del panel (como en los juegos de consola).
func _draw_row_desc(area: Rect2) -> void:
	var r := Rect2(area.position.x, area.end.y - 54, area.size.x, 54)
	ui.rect(Rect2(r.position.x, r.position.y, r.size.x, 1), Color(1, 1, 1, 0.08))
	if row_desc == null:
		return
	ui.circle(Vector2(r.position.x + 26, r.get_center().y + 2), 11, ImUI.COL.accent)
	ui.text("i", Vector2(r.position.x + 26, r.get_center().y + 3), 14, Color8(16, 20, 30), true, "center")
	ui.wrap_text(row_desc, Rect2(r.position.x + 48, r.position.y + 10, r.size.x - 60, 44), 14, "text")


## Sonido, cámara y pantalla.
func draw_settings(area: Rect2) -> void:
	var y := section_title(area, "Ajustes", "Los cambios se guardan solos.")
	var pct := func(v): return "%d%%" % roundi(v * 100)
	y = group_title(area, y, "SONIDO")
	y = row_slider(area, y, "Música", "music", 0, 1, pct, "Volumen de la música. La música se pone tensa cuando estás cerca de la quiebra.")
	y = row_slider(area, y, "Efectos de sonido", "effects", 0, 1, pct, "Monedas, clientes enojados, avisos y el latido del peligro.")
	y = row_toggle(area, y, "Silenciar todo", "mute", "Apaga la música y los efectos sin perder el volumen que elegiste.")
	y = group_title(area, y, "CÁMARA Y MOUSE")
	y = row_slider(area, y, "Sensibilidad del mouse", "sensitivity", 0.3, 2.5, func(v): return Fmt.num(v, 1) + "x",
			"Qué tan rápido gira la cámara al mover el mouse.")
	y = row_slider(area, y, "Campo de visión", "fov", 55, 100, func(v): return "%d°" % roundi(v),
			"Cuánto se ve a los lados. Más alto se ve más ciudad, pero las cosas se ven más chicas.")
	y = row_toggle(area, y, "Invertir el mouse vertical", "invert_y", "Mover el mouse hacia arriba mira hacia abajo, como en los simuladores de vuelo.")
	y = group_title(area, y, "PANTALLA Y JUEGO")
	var half := Rect2(area.position.x, y, area.size.x / 2 - 8, 0)
	var half2 := Rect2(area.position.x + area.size.x / 2 + 8, y, area.size.x / 2 - 8, 0)
	city.settings.fullscreen = city.is_fullscreen()   # lo que muestra el interruptor es lo que hay de verdad
	row_toggle(half, y, "Pantalla completa", "fullscreen", Lang.f("Ocupa toda la pantalla (también con %s).", Keys.label("fullscreen")), city.toggle_fullscreen)
	row_toggle(half2, y, "Desenfocar menús", "blur", "La ciudad se ve borrosa detrás de los menús.")
	var speed_labels: Array = Admin.SPEEDS.map(func(sp): return sp[1])
	row_lang(area, y + ROW_H)
	if app.view == "game":
		row_choice(half, y + 2 * ROW_H, "Velocidad", "speed", speed_labels, app.speed, func(i): app.speed = i,
			Lang.f("Qué tan rápido pasan los días. También con %s, %s y %s.", [Keys.label("speed1"), Keys.label("speed2"), Keys.label("speed3")]))


# ---------- tutorial ----------
func tutorial_next() -> void:
	if tutorial_pages == TUTORIAL_VALOR:
		city.tutorial.understood = true
		app.paused = city.tutorial_prev
		if tutorial_return == "admin":
			show("admin")
		else:
			hide()
		return
	if tutorial_page >= tutorial_pages.size() - 1:
		city.close_tutorial(tutorial_pages == TUTORIAL)
	else:
		tutorial_page += 1


## Una página por vez: imagen del juego, título y unas líneas. Se pasa con los botones, las flechas o Enter.
## Al terminar los pasos guiados: la tarjeta con las claves para ganar.
## Autores del juego: [nombre, qué hizo] (se ven en los créditos del menú de inicio)
const AUTHORS := [["Brandon Alvis (NoName-IA)", "Idea, diseño y desarrollo"]]


## Créditos (desde «Créditos», abajo en el menú de inicio), centrados como los del final de un juego: los autores,
## las canciones con sus artistas (la que suena lleva un ecualizador) y el motor.
func draw_credits() -> void:
	var songs: Array = Sfx.SONGS
	var cx := W / 2
	var y := H / 2 - (250 + AUTHORS.size() * 52 + songs.size() * 34) / 2.0
	ui.text("CAPITAL", Vector2(cx, y), 52, "accent", true, "midtop")
	ui.rect(Rect2(cx - 40, y + 70, 80, 3), "accent", 2)
	y += 104
	y = _credits_section("AUTORES", y)
	for a in AUTHORS:
		ui.text(a[0], Vector2(cx, y), 22, "text", true, "midtop")
		ui.text(a[1], Vector2(cx, y + 28), 14, "muted", false, "midtop")
		y += 52
	y = _credits_section("MÚSICA", y + 18)
	var playing: Array = city.sfx.now_playing()
	for si in songs.size():
		var sg: Array = songs[si]
		var on: bool = sg == playing
		var title_w := ui.text_size(sg[1], 17, true).x
		var by: String = "  ·  " + sg[2]
		var x := cx - (title_w + ui.text_size(by, 15).x) / 2
		# Un clic en la canción la pone
		var row := Rect2(x - 30, y, title_w + ui.text_size(by, 15).x + 40, 28)
		var hot := ui.hover(row)
		if hot:
			ui.rect(row, Color(1, 1, 1, 0.06), 8)
			if ui.clicked and not on:
				city.sfx.play_song(si)
		ui.text(sg[1], Vector2(x, y + 13), 17, "accent" if on or hot else "text", true, "midleft")
		ui.text(by, Vector2(x + title_w, y + 13), 15, "muted", false, "midleft")
		if on:   # ecualizador chiquito a la izquierda de la que suena
			var t := Time.get_ticks_msec() / 1000.0
			for i in 3:
				var bh := 4.0 + 9.0 * absf(sin(t * (5.0 + i * 1.7) + i))
				ui.rect(Rect2(x - 24 + i * 6, y + 20 - bh, 4, bh), "accent", 1)
		y += 34
	ui.text("Hecho con Godot Engine", Vector2(cx, y + 26), 13, "muted", false, "midtop")
	if ui.button(Rect2(cx - 80, y + 64, 160, 40), "Volver (Esc)", true, "normal", 15):
		app.credits_open = false


## Título chico de una sección de los créditos, entre dos líneas finas. Devuelve dónde sigue.
func _credits_section(title: String, y: float) -> float:
	var cx := W / 2
	var tw := ui.text_size(title, 12, true).x
	ui.line(Vector2(cx - tw / 2 - 70, y + 8), Vector2(cx - tw / 2 - 14, y + 8), Color(1, 1, 1, 0.18))
	ui.line(Vector2(cx + tw / 2 + 14, y + 8), Vector2(cx + tw / 2 + 70, y + 8), Color(1, 1, 1, 0.18))
	ui.text(title, Vector2(cx, y), 12, "accent", true, "midtop")
	return y + 32


func show_win_guide() -> void:
	city.tutorial_prev = app.paused
	app.paused = true
	tutorial_pages = TUTORIAL_END
	tutorial_page = 0
	show("tutorial")


## Tarjeta del tutorial que explica cómo se gana: se pone encima de todo (también de la tablet).
func show_value_card() -> void:
	tutorial_return = mode if mode != null else ""
	city.tutorial_prev = app.paused
	app.paused = true
	tutorial_pages = TUTORIAL_VALOR
	tutorial_page = 0
	show("tutorial")


func draw_tutorial() -> void:
	var page: Array = tutorial_pages[tutorial_page]
	if page[0] == "ganar":
		_draw_win_guide()
		return
	if page[0] == "valor":
		_draw_value_card()
		return
	# La bienvenida: solo el nombre del juego y el botón para empezar
	var box := Rect2(W / 2 - 330, H / 2 - 120, 660, 240)
	glass_box(box)
	ui.text(page[1], Vector2(box.get_center().x, box.position.y + 46), 40, "accent", true, "midtop")
	if ui.button(Rect2(box.get_center().x - 140, box.end.y - 84, 280, 50), "Empezar tutorial", true, "primary", 18):
		tutorial_next()


func _draw_value_card() -> void:
	var g: Game = app.game
	var box := Rect2(W / 2 - 400, H / 2 - 160, 800, 320)
	glass_box(box)
	var cx := box.get_center().x
	ui.text("TUTORIAL", Vector2(cx, box.position.y + 28), 13, "accent", true, "center")
	ui.text("Así se gana", Vector2(cx, box.position.y + 50), 40, "accent", true, "midtop")
	ui.text(Lang.f("Haz que tu empresa valga %s.", Fmt.short(D.WIN_VALUE)), Vector2(cx, box.position.y + 108), 20, "text", false, "midtop")
	var v := g.valuation()
	ui.text(Lang.f("Hoy vale %s", Fmt.money(v)), Vector2(cx, box.position.y + 160), 24, "accent", true, "midtop")
	var bar := Rect2(box.position.x + 80, box.position.y + 202, box.size.x - 160, 12)
	ui.bar(bar, v / D.WIN_VALUE, "accent")
	ui.text("$0", Vector2(bar.position.x, bar.end.y + 6), 12, "muted")
	ui.text(Lang.f("Imperio · %s", Fmt.short(D.WIN_VALUE)), Vector2(bar.end.x, bar.end.y + 6), 12, "muted", false, "topright")
	if ui.button(Rect2(cx - 120, box.end.y - 66, 240, 48), "Entendido", true, "primary", 18):
		tutorial_next()


func _draw_win_guide() -> void:
	var box := Rect2(W / 2 - 360, H / 2 - 170, 720, 340)
	glass_box(box)
	var y := box.position.y + 44
	for i in END_TIPS.size():
		var c := Vector2(box.position.x + 70, y + 20)
		ui.circle(c, 18, ImUI.COL.accent)
		ui.text(str(i + 1), c, 18, Color8(20, 20, 24), true, "center")
		ui.text(END_TIPS[i], Vector2(c.x + 34, c.y), 21, "text", true, "midleft", box.size.x - 140)
		y += 62
	if ui.button(Rect2(box.get_center().x - 120, box.end.y - 80, 240, 50), "¡A jugar!", true, "primary", 20):
		tutorial_next()


## Página «Controles»: cada acción con su tecla; un clic en la tecla la cambia.
func draw_controls(area: Rect2) -> void:
	var y := section_title(area, "Controles", "Haz clic en una tecla y aprieta la nueva. Si otra acción la usaba, se intercambian.")
	if ui.button(Rect2(area.end.x - 380, area.position.y + 14, 170, 36), "Restablecer teclas", true, "normal", 14):
		Keys.map = Keys.defaults()
		city.save_settings()
	if app.view == "game" and not city.tutorial.active and ui.button(Rect2(area.end.x - 200, area.position.y + 14, 200, 36), "Ver el tutorial", true, "normal", 14):
		pause_page = "main"
		city.close_pause()
		city.open_tutorial()
		return
	var col_w := area.size.x / 2 - 8
	var cols := {"MOVERTE": 0, "ACCIONES": 1, "JUEGO": 1}
	var ys := [y, y]
	var last_group := ["", ""]
	for a in Keys.ACTIONS:
		var c: int = cols[a[3]]
		var sub := Rect2(area.position.x + c * (col_w + 16), 0, col_w, 0)
		if last_group[c] != a[3]:
			ys[c] = group_title(sub, ys[c], a[3])
			last_group[c] = a[3]
		var ry: float = ys[c]
		var waiting: bool = binding == a[0]
		var hot := row_bg(sub, ry, "key:" + a[0], Lang.f("Clic para cambiar la tecla de «%s».", a[1]))
		ui.text(a[1], Vector2(sub.position.x + 20, ry + (ROW_H - 4) / 2), 15, "text", false, "midleft", col_w - 140)
		var label := "Aprieta una tecla…" if waiting else Keys.label(a[0])
		var kw: float = max(54.0, ui.text_size(label, 14, true).x + 22)
		var chip := Rect2(sub.end.x - 16 - kw, ry + (ROW_H - 4) / 2 - 15, kw, 30)
		ui.rect(chip, ImUI.COL.accent if waiting else Color(1, 1, 1, 0.1), 7)
		ui.rect(chip, Color(1, 1, 1, 0.25) if hot else Color(1, 1, 1, 0.12), 7, 1)
		ui.text(label, chip.get_center(), 14, Color8(16, 20, 30) if waiting else Color.WHITE, true, "center")
		if hot and ui.clicked:
			binding = a[0]
		ys[c] = ry + ROW_H
	# Lo que no se cambia: el mouse y las teclas fijas
	var sub := Rect2(area.position.x, 0, col_w, 0)
	var fy := group_title(sub, ys[0], "FIJAS")
	for row in [["Esc", "Menú de pausa"], ["Alt", "Soltar o capturar el mouse"], ["Mouse", "Mirar · rueda: acercar la cámara"]]:
		ui.text(row[1], Vector2(sub.position.x + 20, fy + 12), 14, "muted")
		ui.text(row[0], Vector2(sub.end.x - 20, fy + 12), 14, "muted", true, "topright")
		fy += 30
	if binding != null:
		row_desc = Lang.f("Aprieta la tecla nueva para «%s». Esc cancela.", Keys.name_of(binding))


## Termina de cambiar una tecla (la llama la ciudad con la tecla apretada).
func finish_binding(e: InputEventKey) -> void:
	if e.keycode == KEY_ESCAPE or e.physical_keycode == KEY_NONE:
		binding = null
		return
	var action: String = binding
	binding = null
	var swapped := Keys.assign(action, e.physical_keycode)
	if e.physical_keycode in Keys.FIXED:
		city.toast("Esa tecla no se puede usar.", "bad")
		return
	city.save_settings()
	if swapped:
		city.toast(Lang.f("«%s» ahora usa %s.", [Keys.name_of(swapped), Keys.label(swapped)]), "info")


## Página «Gráficos», con pestañas como en los juegos grandes: Calidad (el nivel y cada efecto), Imagen (brillo,
## contraste, color, niebla, lluvia, luces) y Rendimiento (FPS, sincronía vertical, distancia de visión, gente).
var gfx_tab := "calidad"
const GFX_TABS := [["calidad", "Calidad"], ["imagen", "Imagen"], ["rendimiento", "Rendimiento"]]


func draw_graphics(area: Rect2) -> void:
	var s: Dictionary = city.settings
	Graphics.show_preset(s)
	var y := section_title(area, "Gráficos", "Alto imita el shader Eclipse: sombras nítidas hasta lejos y rincones oscurecidos.")
	var fps := Engine.get_frames_per_second()
	var fr := Rect2(area.end.x - 110, area.position.y + 16, 110, 34)
	ui.rect(fr, Color(1, 1, 1, 0.06), 17)
	ui.text(Lang.f("%d FPS", fps), fr.get_center(), 16, "green" if fps >= 40 else ("orange" if fps >= 25 else "red"), true, "center")
	# pestañas
	var tx := area.position.x
	for t in GFX_TABS:
		var tw: float = ui.text_size(t[1], 15, true).x + 36
		var tr := Rect2(tx, y - 2, tw, 34)
		var on: bool = gfx_tab == t[0]
		var hot := ui.hover(tr)
		ui.rect(tr, ImUI.COL.accent if on else Color(1, 1, 1, 0.1 if hot else 0.05), 17)
		ui.text(t[1], tr.get_center(), 15, Color8(16, 20, 30) if on else ImUI.COL.text, true, "center")
		if hot and ui.clicked:
			gfx_tab = t[0]
		tx += tw + 10
	y += 46
	var half := Rect2(area.position.x, 0, area.size.x / 2 - 8, 0)
	var half2 := Rect2(area.position.x + area.size.x / 2 + 8, 0, area.size.x / 2 - 8, 0)
	match gfx_tab:
		"calidad":
			y = row_choice(area, y, "Nivel de gráficos", "quality", Graphics.LEVELS, s.quality, func(i): s.quality = i,
					"Bajo va más rápido; Alto se ve mejor. Si cambias Sombras, Bordes, Oclusión, Resplandor o Destello pasa a Personalizado.")
			y = group_title(area, y, "SOMBRAS")
			y = row_choice(area, y, "Calidad de sombras", "g_shadows", Graphics.SHADOWS, s.g_shadows, func(i): set_custom("g_shadows", i),
					"Las sombras altas se dibujan más nítidas y en más tramos, pero cuestan más.")
			y = row_choice(area, y, "Distancia de sombras", "g_shadow_dist", Graphics.SHADOW_DIST, int(s.g_shadow_dist), func(i): s.g_shadow_dist = i,
					"Hasta dónde se ven sombras. Más cerca se ven más nítidas y van más rápido.")
			y = row_choice(area, y, "Borde de las sombras", "g_shadow_soft", Graphics.SHADOW_SOFT, int(s.g_shadow_soft), func(i): s.g_shadow_soft = i,
					"Sombras duras o difuminadas. Las muy suaves cuestan un poco más.")
			y = group_title(area, y, "EFECTOS")
			y = row_choice(area, y, "Bordes suaves (MSAA)", "g_aa", Graphics.AA, s.g_aa, func(i): set_custom("g_aa", i),
					"Quita los dientes de sierra de los bordes. Es lo que más cuesta en tarjetas sencillas.")
			row_toggle(half, y, "Oclusión ambiental", "g_ao", "Oscurece rincones y bases de los objetos. Se ve más real, pero cuesta bastante.",
					func(): set_custom("g_ao", not s.g_ao))
			y = row_toggle(half2, y, "Destello del sol", "g_flare", "Reflejo en la cámara al mirar el sol.",
					func(): set_custom("g_flare", not s.g_flare))
			row_toggle(half, y, "Resplandor", "g_glow", "Brillo suave alrededor de las luces y el sol.",
					func(): set_custom("g_glow", not s.g_glow))
			row_slider(half2, y, "Intensidad", "g_glow_amt", 0.2, 2.0, func(v): return "%d%%" % roundi(v * 100),
					"Cuánto brillan las luces y el sol cuando el resplandor está prendido.")
		"imagen":
			y = group_title(area, y, "COLOR Y LUZ")
			var pct := func(v): return "%d%%" % roundi(v * 100)
			y = row_slider(area, y, "Brillo", "g_bright", 0.6, 1.6, pct, "Más claro o más oscuro (de día y de noche).")
			y = row_slider(area, y, "Contraste", "g_contrast", 0.8, 1.3, pct, "Diferencia entre las zonas claras y las oscuras.")
			y = row_slider(area, y, "Saturación", "g_sat", 0.4, 1.6, pct, "Qué tan vivos son los colores.")
			y = row_choice(area, y, "Tono de color", "g_tonemap", Graphics.TONEMAPS, int(s.g_tonemap), func(i): s.g_tonemap = i,
					"Cómo se convierte la luz en colores de pantalla. AgX es el del juego; Fílmico y ACES se ven más de cine.")
			y = group_title(area, y, "AMBIENTE")
			row_toggle(half, y, "Niebla a lo lejos", "g_fog", "Neblina suave en la distancia, más espesa con lluvia.")
			y = row_toggle(half2, y, "Lluvia y relámpagos", "g_rain", "Las gotas y los destellos de la tormenta. El clima igual cuenta para tus ventas.")
			row_toggle(half, y, "Luces de noche", "g_night_lights", "Faroles, vitrinas y locales que iluminan la calle de noche.")
		"rendimiento":
			y = group_title(area, y, "CUADROS POR SEGUNDO")
			y = row_choice(area, y, "Límite de FPS", "g_fps_limit", Graphics.FPS_LIMITS, int(s.g_fps_limit), func(i): s.g_fps_limit = i,
					"Cuántos cuadros por segundo dibuja como máximo. Un límite más bajo calienta menos la tarjeta.")
			y = row_toggle(area, y, "Sincronía vertical (VSync)", "g_vsync", "Evita que la imagen se corte en dos al moverse. Puede sumar un poco de retraso.")
			y = group_title(area, y, "MUNDO")
			y = row_choice(area, y, "Distancia de visión", "g_view", Graphics.VIEWS, int(s.g_view), func(i): s.g_view = i,
					"Hasta dónde se dibuja la ciudad. Más corta va más rápido.")
			y = row_choice(area, y, "Gente en la ciudad", "g_crowd", Graphics.CROWDS, int(s.g_crowd), func(i): s.g_crowd = i,
					"Cuántos peatones y clientes hay a la vez. No cambia tus ventas: solo lo que se ve.")
			y = row_toggle(area, y, "Mostrar FPS en pantalla", "g_show_fps", "Un contador de cuadros por segundo arriba a la derecha.")


func set_custom(key: String, value) -> void:
	city.settings[key] = value
	city.settings.quality = Graphics.CUSTOM


# ---------- armario ----------
## Panel a la izquierda con pestañas y una foto de cada prenda; el personaje queda a la derecha y se gira,
## se acerca o se aleja con el mouse.
func draw_custom() -> void:
	var g: Game = app.game
	var look: Dictionary = g.look
	var box := Rect2(30, 26, 600, H - 52)
	glass_box(box)
	ui.text("Armario", box.position + Vector2(32, 22), 32, "accent", true)
	ui.text(Lang.f("Caja: %s", Fmt.money(g.cash)), Vector2(box.end.x - 32, box.position.y + 30), 18, Admin.sc(g.cash), true, "topright")
	ui.text("Lo que tiene precio se compra con la caja de la empresa (gasto de representación).",
			box.position + Vector2(34, 66), 14, "muted")
	var x := box.position.x + 32
	var tw := (536 - 4 * 6) / 5.0
	for i in Wardrobe.SHOP_TABS.size():
		var t: Array = Wardrobe.SHOP_TABS[i]
		if ui.button(Rect2(x + i * (tw + 6), box.position.y + 96, tw, 38), t[1], true, "normal", 14, null, shop_tab == t[0]):
			shop_tab = t[0]
	var y := box.position.y + 150
	match shop_tab:
		"cabeza":
			y = swatches(x, y, "Piel", "skin")
			y = cards(x, y, "Peinado", "hair_style", Wardrobe.HAIR_STYLES, 4, 150)
			y = swatches(x, y, "Color de pelo", "hair")
		"sombreros":
			y = cards(x, y, "Sombrero", "hat", Wardrobe.HATS, 3, 190)
		"ropa":
			y = swatches(x, y, "Camisa", "shirt")
			y = cards(x, y, "Chaqueta", "jacket", Wardrobe.JACKETS, 4, 150)
			y = swatches(x, y, "Color de la chaqueta (el cuero siempre es negro)", "jacket_color")
		"piernas":
			y = cards(x, y, "Pantalón", "pants_style", Wardrobe.PANTS_STYLES, 3, 160)
			y = swatches(x, y, "Color del pantalón", "pants")
			y = swatches(x, y, "Zapatos", "shoes")
		_:
			y = cards(x, y, "Haz clic para ponerte o quitarte cada accesorio", "", Wardrobe.TOGGLES, 4, 150)
	var by := box.end.y - 64
	if ui.button(Rect2(x, by, 250, 44), "Al azar (con lo que tienes)", true, "normal", 15):
		trying = null
		for key in Wardrobe.LOOK_COLORS:
			var opts: Array = Wardrobe.LOOK_COLORS[key].filter(func(o): return Wardrobe.owns(g, key, o))
			look[key] = opts.pick_random()
		for spec in [["hair_style", Wardrobe.HAIR_STYLES], ["hat", Wardrobe.HATS], ["jacket", Wardrobe.JACKETS], ["pants_style", Wardrobe.PANTS_STYLES]]:
			var opts: Array = spec[1].filter(func(o): return Wardrobe.owns(g, spec[0], o[0]))
			look[spec[0]] = opts.pick_random()[0]
		for key in Wardrobe.TOGGLE_KEYS:
			look[key] = Wardrobe.owns(g, key, true) and randf() < 0.4
		city.apply_look()
	if ui.button(Rect2(x + 270, by, 266, 44), "Listo (Esc)", true, "primary", 17):
		city.close_custom()
	if trying != null:
		draw_try_bar(x, by - 118, 536)
	draw_view_controls()


## Botones para mover la vista del personaje (también se puede arrastrar con el mouse).
func draw_view_controls() -> void:
	var bx := W - 470
	var by := H - 70
	ui.rect(Rect2(bx - 14, by - 40, 454, 98), Color(COL_PANEL, 0.85), 14)
	ui.text("Arrastra para girar · Rueda: acercar · Clic derecho: subir o bajar", Vector2(bx + 213, by - 30), 13, "muted", false, "midtop")
	var actions := [["< Girar", func(): city.turn_custom(-45)], ["Girar >", func(): city.turn_custom(45)],
			["+ Cerca", func(): city.zoom_custom(-1.2)], ["- Lejos", func(): city.zoom_custom(1.2)],
			["Centrar (R)", func(): city.reset_custom_view()]]
	for i in actions.size():
		var rect := Rect2(bx + i * 86, by - 4, 80, 40) if i < 4 else Rect2(bx + 344, by - 4, 96, 40)
		if ui.button(rect, actions[i][0], true, "normal", 13):
			actions[i][1].call()


func over_custom_ui() -> bool:
	return ui.mouse.x < 640 or (ui.mouse.x > W - 490 and ui.mouse.y > H - 115)


## Elegir una prenda: si ya es tuya te la pones; si no, te la pruebas gratis y abajo se pregunta si la compras.
func pick(key: String, value, label := "") -> void:
	var g: Game = app.game
	if not Wardrobe.owns(g, key, value):
		trying = {"key": key, "value": value, "name": label if label else Lang.t("este color"),
				"price": g.item_price(Wardrobe.item_price(key, value))}
		var preview: Dictionary = Wardrobe.full_look(g.look)
		preview[key] = value
		city.player.restyle(preview)
		return
	trying = null
	g.look[key] = value
	city.apply_look()


## Lo que te estás probando: ¿lo compras o te lo sacas?
func draw_try_bar(x: float, y: float, w: float) -> void:
	var g: Game = app.game
	var r := Rect2(x, y, w, 104)
	ui.rect(r, Color8(36, 30, 14), 12)
	ui.rect(r, ImUI.COL.accent, 12, 2)
	ui.text(Lang.f("Te estás probando: %s", trying.name), r.position + Vector2(16, 12), 16, "text", true, "topleft", w - 32)
	ui.text(Lang.f("Cuesta %s. ¿Te gusta cómo se ve?", Fmt.money(trying.price)), r.position + Vector2(16, 36), 14, "muted")
	var bw := (w - 44) / 2
	if ui.button(Rect2(x + 16, y + 58, bw, 36), Lang.f("Sí, comprar (%s)", Fmt.short(trying.price)), g.cash >= trying.price, "primary", 14):
		var t: Dictionary = trying
		trying = null
		var res := g.buy_item(Wardrobe.item_id(t.key, t.value), Wardrobe.item_price(t.key, t.value))
		if res[0]:
			g.look[t.key] = t.value
			city.sfx.play("coin", 0.7)
			city.toast(Lang.f("Compraste %s por %s.", [t.name, Fmt.money(t.price)]), "good")
		else:
			city.toast(res[1], "bad")
		city.apply_look()
	if ui.button(Rect2(x + 28 + bw, y + 58, bw, 36), "No, quitármelo", true, "normal", 14):
		trying = null
		city.apply_look()


func swatches(x: float, y: float, label: String, key: String) -> float:
	var g: Game = app.game
	ui.text(label, Vector2(x, y), 15, "text")
	var options: Array = Wardrobe.LOOK_COLORS[key]
	for i in options.size():
		var rgb: Array = options[i]
		var center := Vector2(x + 18 + i * 46, y + 40)
		var chosen: bool = Wardrobe.ints(g.look[key]) == rgb
		var hot := ui.hover(Rect2(center - Vector2(18, 18), Vector2(36, 36)))
		if chosen or hot:
			ui.ring(center, 21, "accent" if chosen else "text", 3)
		ui.circle(center, 16, Person.col(rgb))
		if not Wardrobe.owns(g, key, rgb):
			var price := g.item_price(Wardrobe.item_price(key, rgb))
			ui.text(Fmt.short(price), center + Vector2(0, 20), 11, "muted" if g.cash >= price else "red", false, "midtop")
		if trying != null and trying.key == key and Wardrobe.ints(trying.value) == rgb:
			ui.ring(center, 21, "blue", 3)
		if hot and ui.clicked:
			pick(key, rgb, Lang.f("%s de otro color", Lang.noun(label.split(" (")[0])))
	return y + 76


## Tarjetas con la foto de cada prenda puesta en un maniquí con tu aspecto. `key` vacío = accesorios.
func cards(x: float, y: float, label: String, key: String, options: Array, cols: int, h: float) -> float:
	var g: Game = app.game
	ui.text(label, Vector2(x, y), 15, "text")
	var gap := 10.0
	var w := (536 - gap * (cols - 1)) / cols
	for i in options.size():
		var value = options[i][0]
		var name: String = options[i][1]
		var field: String = value if key == "" else key
		var val = true if key == "" else value
		var r := Rect2(x + (i % cols) * (w + gap), y + 26 + (i / cols) * (h + gap), w, h)
		var worn: bool = g.look.get(field) == true if key == "" else g.look.get(field) == value
		var on_trial: bool = trying != null and trying.key == field and trying.value == val
		var owned := Wardrobe.owns(g, field, val)
		var hot := ui.hover(r)
		ui.rect(r, Color8(44, 52, 68) if hot else ImUI.COL.panel2, 12)
		var preview: Dictionary = Wardrobe.full_look(g.look)
		if key == "":
			preview[field] = true
			if field in ["glasses", "beard"]:
				preview["hat"] = "ninguno"
		else:
			preview[field] = value
			if field == "hair_style":
				preview["hat"] = "ninguno"  # para ver el peinado
		var img = city.thumbs.get_thumb(preview, Thumbs.ITEM_FRAME.get(field, "torso"))
		var side: float = min(w - 10, h - 34)
		var ir := Rect2(r.get_center().x - side / 2, r.position.y + 6, side, side)
		if img != null:
			ui.image(img, ir)
		else:
			ui.rect(ir, Color8(28, 33, 43), 8)
			ui.text("…", ir.get_center(), 22, "muted", false, "center")
		if on_trial:
			ui.rect(r, "blue", 12, 3)
			var tag := Rect2(r.position.x + 8, r.position.y + 10, 78, 22)
			ui.rect(tag, "blue", 11)
			ui.text("Probando", tag.get_center(), 12, Color8(16, 20, 30), true, "center")
		elif worn:
			ui.rect(r, "accent", 12, 3)
			var tag := Rect2(r.position.x + 8, r.position.y + 10, 62, 22)
			ui.rect(tag, "accent", 11)
			ui.text("Puesto", tag.get_center(), 12, Color8(25, 25, 30), true, "center")
		elif hot:
			ui.rect(r, "text", 12, 1)
		ui.text(name, Vector2(r.get_center().x, r.end.y - 36), 14, "text", true, "midtop", w - 10)
		if owned:
			ui.text("Tuyo" if Wardrobe.item_price(field, val) else "Gratis", Vector2(r.get_center().x, r.end.y - 18), 12, "muted", false, "midtop")
		else:
			var price := g.item_price(Wardrobe.item_price(field, val))
			ui.text(Fmt.short(price), Vector2(r.get_center().x, r.end.y - 18), 13, "green" if g.cash >= price else "red", true, "midtop")
		if hot and ui.clicked:
			if key == "" and g.look.get(field) == true:
				g.look[field] = false
				city.apply_look()
			else:
				pick(field, val, name)
	var rows := (options.size() + cols - 1) / cols
	return y + 26 + rows * (h + gap) + 8


# ---------- vitrina de trofeos ----------
## Cada título es un trofeo; los que faltan se ven como siluetas.
func draw_trophies() -> void:
	var g: Game = app.game
	var ranks: Array = g.ranks().slice(1)
	var rows := (ranks.size() + 4) / 5
	var bh := 180.0 + rows * 262
	var box := Rect2(W / 2 - 570, H / 2 - bh / 2, 1140, bh)
	glass_box(box)
	var got: int = g.rank
	ui.text("TU OFICINA", box.position + Vector2(42, 26), 12, "muted", true)
	ui.text("Vitrina de trofeos", box.position + Vector2(40, 42), 32, "accent", true)
	ui.text(Lang.f("Un trofeo por cada título que consigues · %s", D.MODES[g.mode].name), box.position + Vector2(42, 86), 14, "muted")
	# Contador circular: cuántos títulos tienes
	var cc := Vector2(box.end.x - 76, box.position.y + 66)
	ui.ring(cc, 34, Color(1, 1, 1, 0.08), 7)
	arc(cc, 34, float(got) / ranks.size(), ImUI.COL.accent, 7)
	ui.text("%d/%d" % [got, ranks.size()], cc, 18, "text", true, "center")
	# Lo que falta para el siguiente
	var info := g.rank_info()
	var nx := cc.x - 70
	if info[2] != null:
		var lo: float = g.ranks()[got][0]
		ui.text(Lang.f("Siguiente: %s", info[2][1]), Vector2(nx, box.position.y + 40), 15, "text", true, "topright")
		ui.text(Lang.f("Te faltan %s", Fmt.money(max(0.0, info[2][0] - info[3]))), Vector2(nx, box.position.y + 62), 13, "muted",
				false, "topright")
		ui.bar(Rect2(nx - 260, box.position.y + 84, 260, 6), (info[3] - lo) / (info[2][0] - lo), "accent")
	else:
		ui.text("¡Los tienes todos!", Vector2(nx, box.position.y + 52), 18, "green", true, "topright")
	for i in ranks.size():
		var r := Rect2(box.position.x + 40 + (i % 5) * 214, box.position.y + 122 + (i / 5) * 262, 200, 248)
		draw_trophy_card(r, i, ranks[i], i < got, i == got, info)
	if ui.button(Rect2(box.get_center().x - 130, box.end.y - 54, 260, 40), "Cerrar (E)", true, "normal", 16):
		hide()


## Arco de progreso (de arriba, en el sentido del reloj) para el contador de la vitrina.
func arc(c: Vector2, radius: float, frac: float, color, width := 4.0) -> void:
	var n := int(48 * clampf(frac, 0.0, 1.0))
	if n < 1:
		return
	var pts := PackedVector2Array()
	for j in n + 1:
		var a := -PI / 2 + TAU * frac * j / n
		pts.append(c + Vector2(cos(a), sin(a)) * radius)
	ui.polyline(pts, color, width)


## Una tarjeta de la vitrina: ganada (con el color de su nivel y brillo), la siguiente (con su avance) o bloqueada.
func draw_trophy_card(r: Rect2, i: int, rank: Array, earned: bool, is_next: bool, info: Array) -> void:
	var tier: Array = TIERS[min(i, TIERS.size() - 1)]
	var tc: Color = tier[1]
	var hot := ui.hover(r)
	var k := ui.tween(Lang.f("trophy:%d", i), 1.0 if hot else 0.0)
	r.position.y -= 3 * k
	var cup := Vector2(r.get_center().x, r.position.y + 100)
	ui.rect(r, Color8(27, 32, 41), 14)
	if earned:
		ui.rect(r, Color(tc, 0.1 + 0.05 * k), 14)
		for g in [[66, 0.05], [50, 0.07], [36, 0.09]]:   # brillo detrás de la copa
			ui.circle(cup + Vector2(0, -8), g[0], Color(tc, g[1] + 0.03 * k))
		ui.rect(r, Color(tc, 0.75 + 0.25 * k), 14, 1.5 + k)
	elif is_next:
		ui.rect(r, Color(ImUI.COL.accent, 0.45 + 0.4 * k), 14, 1.5)
	else:
		ui.rect(r, Color(1, 1, 1, 0.06 + 0.08 * k), 14, 1)
	# Arriba: el nivel (bronce, plata...) y el número del título
	if earned:
		app.pill(r.position + Vector2(12, 12), tier[0].to_upper(), tc)
	elif is_next:
		app.pill(r.position + Vector2(12, 12), "SIGUIENTE", "accent", true)
	else:
		app.pill(r.position + Vector2(12, 12), tier[0].to_upper(), Color8(110, 116, 130))
	ui.text(Lang.f("#%d", (i + 1)), Vector2(r.end.x - 14, r.position.y + 15), 12, Color(1, 1, 1, 0.35), true, "topright")
	draw_cup(cup, tc if earned else Color8(52, 57, 68), earned, i)
	var title: String = rank[1]
	var cx := r.get_center().x
	ui.text(title, Vector2(cx, r.position.y + 162), 16, "text" if earned or is_next else "muted", true, "midtop", r.size.x - 16)
	ui.text(Fmt.short(rank[0]), Vector2(cx, r.position.y + 184), 13, tc if earned else ("accent" if is_next else "muted"),
			true, "midtop")
	if earned:
		var logged = app.game.rank_log.get(title)
		if logged != null:
			var day := int(logged[0])
			ui.text(Lang.f("%d de %s, año %d", [day % 30 + 1, D.MONTHS[(day / 30) % 12], day / 360 + 1]),
					Vector2(cx, r.position.y + 206), 12, "muted", false, "midtop")
			ui.text(Lang.f("a los %d min de juego", roundi(logged[1] / 60.0)), Vector2(cx, r.position.y + 222), 11,
					Color(ImUI.COL.muted, 0.8), false, "midtop")
		else:
			ui.text("Conseguido", Vector2(cx, r.position.y + 212), 12, "muted", false, "midtop")
	elif is_next and info[2] != null:
		var lo: float = app.game.ranks()[i][0]   # el título anterior
		var frac: float = (info[3] - lo) / (rank[0] - lo) if rank[0] > lo else 0.0
		ui.bar(Rect2(r.position.x + 20, r.position.y + 210, r.size.x - 40, 6), frac, "accent")
		ui.text(Lang.f("%d %%", roundi(clampf(frac, 0, 1) * 100)), Vector2(cx, r.position.y + 222), 11, "muted", false, "midtop")
	else:
		ui.text("Bloqueado", Vector2(cx, r.position.y + 212), 12, Color(ImUI.COL.muted, 0.7), false, "midtop")


## Una copa dibujada con figuras: asas, copa, tallo y base. Ganada brilla (y las de diamante en adelante destellan);
## bloqueada es gris con un candado.
func draw_cup(c: Vector2, rgb: Color, earned: bool, i := 0) -> void:
	var dark := rgb * 0.65
	dark.a = 1
	var light := rgb.lightened(0.35)
	for sx in [-1, 1]:
		ui.ring(c + Vector2(sx * 34, -14), 12, dark, 6)
	ui.polygon(PackedVector2Array([c + Vector2(-36, -40), c + Vector2(36, -40), c + Vector2(22, 8), c + Vector2(-22, 8)]), rgb)
	ui.circle(c + Vector2(0, 7), 22, rgb)
	ui.rect(Rect2(c.x - 38, c.y - 44, 76, 7), light if earned else rgb.lightened(0.08), 3)   # borde de la copa
	ui.rect(Rect2(c.x - 6, c.y + 14, 12, 22), dark)
	ui.rect(Rect2(c.x - 22, c.y + 34, 44, 10), rgb, 3)
	ui.rect(Rect2(c.x - 30, c.y + 44, 60, 12), dark, 3)
	if earned:
		ui.polygon(PackedVector2Array([c + Vector2(-26, -34), c + Vector2(-16, -34), c + Vector2(-8, 4), c + Vector2(-14, 4)]),
				Color(1, 1, 1, 0.45))   # reflejo
		ui.text("★", c + Vector2(0, -12), 22, dark, true, "center")
		if i >= 6:   # diamante y leyenda: destellos que laten
			var t := Time.get_ticks_msec() / 1000.0
			for s in [[Vector2(30, -46), 0.0], [Vector2(-40, 18), 1.3], [Vector2(38, 26), 2.6]]:
				var a := 0.5 + 0.5 * sin(t * 2.4 + s[1])
				var p: Vector2 = c + s[0]
				ui.line(p - Vector2(7 * a, 0), p + Vector2(7 * a, 0), Color(1, 1, 1, a), 2)
				ui.line(p - Vector2(0, 7 * a), p + Vector2(0, 7 * a), Color(1, 1, 1, a), 2)
	else:   # candado
		var lc := Color8(120, 126, 140)
		ui.ring(c + Vector2(0, -22), 9, lc, 3.5)
		ui.rect(Rect2(c.x - 13, c.y - 20, 26, 20), lc, 4)
		ui.circle(c + Vector2(0, -12), 3, rgb)


# ---------- reunión de estrategia ----------
## Una decisión al mes. Cada opción es un concepto distinto (demanda, calidad, costos).
func draw_strategy() -> void:
	var g: Game = app.game
	var box := Rect2(W / 2 - 500, H / 2 - 250, 1000, 500)
	glass_box(box)
	ui.text("Reunión de estrategia", box.position + Vector2(40, 28), 32, "accent", true)
	var wait := g.strategy_wait()
	ui.text("Elige una estrategia para este mes." if not wait else Lang.f("Ya hubo reunión este mes: la próxima es en %d días.", wait),
			box.position + Vector2(42, 74), 15, "muted" if not wait else "orange")
	ui.text(Lang.f("Caja: %s", Fmt.money(g.cash)), Vector2(box.end.x - 40, box.position.y + 36), 18, Admin.sc(g.cash), true, "topright")
	for i in D.STRATEGIES.size():
		var st: Array = D.STRATEGIES[i]
		var r := Rect2(box.position.x + 40 + i * 315, box.position.y + 116, 295, 290)
		ui.rect(r, "panel2", 12)
		ui.text(st[1], r.position + Vector2(18, 18), 19, "text", true)
		ui.wrap_text(st[3], Rect2(r.position.x + 18, r.position.y + 56, r.size.x - 36, 120), 15, "muted")
		var cost := g.strategy_cost(st[0])
		ui.text(Lang.f("Costo: %s", Fmt.money(cost)), Vector2(r.position.x + 18, r.end.y - 96), 16, "accent", true)
		if ui.button(Rect2(r.position.x + 18, r.end.y - 62, r.size.x - 36, 44), "Elegir", not wait and g.cash >= cost, "primary", 16):
			var key: String = st[0]
			city.confirm(Lang.f("¿%s?", st[1]), st[3], Lang.f("Sí (%s)", Fmt.short(cost)), func():
				var res := g.run_strategy(key)
				city.sfx.play("good" if res[0] else "angry")  # la noticia de la reunión llega como aviso de la oficina
				if not res[0]:
					city.toast(res[1], "bad"))
			return
	if ui.button(Rect2(box.get_center().x - 130, box.end.y - 70, 260, 44), "Cerrar (E)", true, "normal", 16):
		hide()


# ---------- decorar un local (la ciudad se ve a la derecha) ----------
## Como el armario: una foto de cada artículo puesto en tu local y su precio. Pasar el mouse lo muestra puesto en la
## ciudad (la cámara va ahí); un clic lo deja puesto para decidir si comprarlo.
func draw_decor() -> void:
	if city.decor_office:
		_draw_office_decor()
		return
	var g: Game = app.game
	var loc = g.find_location(city.decor_id) if g != null else null
	if loc == null:
		city.close_decor()
		return
	# Panel chico, solo del alto que necesita: se ve más ciudad (el armario sí es grande)
	var items: Array = D.upgrades_for(int(loc.size))
	var cols := 3
	var gap := 8.0
	var pw := 400.0
	var inner := pw - 40
	var w := (inner - gap * (cols - 1)) / cols
	var h := 136.0
	var rows := ceili(items.size() / float(cols))
	var bar_h := 90.0 if decor_pick != "" else 0.0
	var ph := 70 + rows * (h + gap) + bar_h + 62
	var box := Rect2(24, 24, pw, ph)
	glass_box(box)
	ui.text("Decorar", box.position + Vector2(20, 16), 24, "accent", true)
	ui.text(Fmt.money(g.cash), Vector2(box.end.x - 20, box.position.y + 22), 15, Admin.sc(g.cash), true, "topright")
	var owned_list: Array = loc.get("upgrades", [])
	if decor_pick != "" and decor_pick in owned_list:
		decor_pick = ""
	var variant: int = city.decor_store.plot_index + int(loc.id) * 31 if city.decor_store != null else -1
	var x := box.position.x + 20
	var y := box.position.y + 62
	var hover := ""
	for i in items.size():
		var u: Dictionary = items[i]
		var r := Rect2(x + (i % cols) * (w + gap), y + (i / cols) * (h + gap), w, h)
		var owned: bool = u.key in owned_list
		var hot := ui.hover(r)
		if hot:
			hover = u.key
		ui.rect(r, Color8(44, 52, 68) if hot else ImUI.COL.panel2, 12)
		var img = city.thumbs.get_decor_thumb(loc, variant, u.key)
		var side: float = min(w - 12, h - 44)
		var ir := Rect2(r.get_center().x - side / 2, r.position.y + 6, side, side)
		if img != null:
			ui.image(img, ir)
		else:
			ui.rect(ir, Color8(28, 33, 43), 8)
			ui.text("…", ir.get_center(), 22, "muted", false, "center")
		if decor_pick == u.key:
			ui.rect(r, "blue", 12, 3)
		elif owned:
			ui.rect(r, "green", 12, 3)
		elif hot:
			ui.rect(r, "text", 12, 1)
		var cost := g.decor_cost(loc, u.key)
		if owned:
			var c := Vector2(r.get_center().x, r.end.y - 15)   # visto verde: ya lo tienes
			ui.line(c + Vector2(-9, 0), c + Vector2(-3, 6), ImUI.COL.green, 4)
			ui.line(c + Vector2(-3, 6), c + Vector2(9, -7), ImUI.COL.green, 4)
		else:
			ui.text(Fmt.short(cost), Vector2(r.get_center().x, r.end.y - 15), 15, "accent" if g.cash >= cost else "red", true, "center")
		ui.tooltip(r, Lang.f("%s · %s", [u.name, decor_effect(u)]))
		if hot and ui.clicked and not owned:
			decor_pick = u.key
	# Lo que se muestra puesto: lo que tienes bajo el mouse o, si no, lo que elegiste con un clic
	var show := hover if hover != "" else decor_pick
	if show != decor_hover:
		decor_hover = show
		city.set_decor_preview(show if show != "" and not show in owned_list else "")
	var by := box.end.y - 54
	if decor_pick != "":
		_decor_buy_bar(g, loc, x, by - bar_h, inner)
	if ui.button(Rect2(x, by, inner, 38), "Listo (Esc)", true, "primary", 15):
		city.close_decor()


## Barra para comprar lo que elegiste (como «Te estás probando» del armario).
func _decor_buy_bar(g: Game, loc: Dictionary, x: float, y: float, w: float) -> void:
	var u: Dictionary = {}
	for it in D.UPGRADES:
		if it.key == decor_pick:
			u = it
	var cost := g.decor_cost(loc, decor_pick)
	var r := Rect2(x, y, w, 82)
	ui.rect(r, Color8(36, 30, 14), 12)
	ui.rect(r, ImUI.COL.accent, 12, 2)
	ui.text(u.name, r.position + Vector2(12, 8), 15, "text", true, "topleft", w - 24)
	ui.text(decor_effect(u), r.position + Vector2(12, 28), 12, "muted", false, "topleft", w - 24)
	var bw := (w - 34) / 2
	if ui.button(Rect2(x + 12, y + 46, bw, 28), Lang.f("Comprar (%s)", Fmt.short(cost)), g.cash >= cost, "primary", 13):
		var res: Array = g.buy_decor(loc, decor_pick)
		city.sfx.play("coin" if res[0] else "angry", 0.7)
		city.toast(res[1], "good" if res[0] else "bad")
		decor_pick = ""
		decor_hover = "?"   # que se vuelva a armar lo que se ve
	if ui.button(Rect2(x + 22 + bw, y + 46, bw, 28), "Quitar", true, "normal", 13):
		decor_pick = ""


## El efecto de un artículo en pocas palabras (la descripción larga queda en el tooltip del precio).
static func decor_effect(u: Dictionary) -> String:
	var parts := []
	if u.has("demand"):
		parts.append(Lang.f("+%d%% clientes", roundi(u.demand * 100)))
	if u.has("stars"):
		parts.append(Lang.f("+%s estrellas", Fmt.num(u.stars, 2 if u.stars < 0.2 else 1)))
	if u.has("capacity"):
		parts.append(Lang.f("atienden %d%% más", roundi(u.capacity * 100)))
	if u.has("weather"):
		parts.append(Lang.t("el clima espanta menos"))
	return " · ".join(parts)


## Personalizar la oficina: el mismo panel chico que decorar un local, con las fotos de cada cosa.
func _draw_office_decor() -> void:
	var g: Game = app.game
	if g == null:
		city.close_decor()
		return
	var items: Array = D.OFFICE_DECOR
	var cols := 3
	var gap := 8.0
	var pw := 400.0
	var inner := pw - 40
	var w := (inner - gap * (cols - 1)) / cols
	var h := 136.0
	var rows := ceili(items.size() / float(cols))
	var bar_h := 90.0 if decor_pick != "" else 0.0
	var box := Rect2(24, 24, pw, 70 + rows * (h + gap) + bar_h + 62)
	glass_box(box)
	ui.text("Tu oficina", box.position + Vector2(20, 16), 24, "accent", true)
	ui.text(Fmt.money(g.cash), Vector2(box.end.x - 20, box.position.y + 22), 15, Admin.sc(g.cash), true, "topright")
	var owned_list: Array = g.office_decor
	if decor_pick != "" and decor_pick in owned_list:
		decor_pick = ""
	var x := box.position.x + 20
	var y := box.position.y + 62
	var hover := ""
	for i in items.size():
		var u: Dictionary = items[i]
		var r := Rect2(x + (i % cols) * (w + gap), y + (i / cols) * (h + gap), w, h)
		var owned: bool = u.key in owned_list
		var hot := ui.hover(r)
		if hot:
			hover = u.key
		ui.rect(r, Color8(44, 52, 68) if hot else ImUI.COL.panel2, 12)
		var img = city.thumbs.get_office_thumb(city.office_tier, u.key)
		var side: float = min(w - 10, h - 34)
		var ir := Rect2(r.get_center().x - side / 2, r.position.y + 6, side, side)
		if img != null:
			ui.image(img, ir)
		else:
			ui.rect(ir, Color8(28, 33, 43), 8)
			ui.text("…", ir.get_center(), 22, "muted", false, "center")
		if decor_pick == u.key:
			ui.rect(r, "blue", 12, 3)
		elif owned:
			ui.rect(r, "green", 12, 3)
		elif hot:
			ui.rect(r, "text", 12, 1)
		var cost := g.office_decor_cost(u.key)
		if owned:
			var c := Vector2(r.get_center().x, r.end.y - 15)
			ui.line(c + Vector2(-9, 0), c + Vector2(-3, 6), ImUI.COL.green, 4)
			ui.line(c + Vector2(-3, 6), c + Vector2(9, -7), ImUI.COL.green, 4)
		else:
			ui.text(Fmt.short(cost), Vector2(r.get_center().x, r.end.y - 15), 15, "accent" if g.cash >= cost else "red", true, "center")
		ui.tooltip(r, Lang.f("%s · +%d de reputación", [u.name, int(u.rep)]))
		if hot and ui.clicked and not owned:
			decor_pick = u.key
	var show := hover if hover != "" else decor_pick
	if show != decor_hover:
		decor_hover = show
		city.set_decor_preview(show if show != "" and not show in owned_list else "")
	var by := box.end.y - 54
	if decor_pick != "":
		var u: Dictionary = {}
		for it in items:
			if it.key == decor_pick:
				u = it
		var cost := g.office_decor_cost(decor_pick)
		var r := Rect2(x, by - bar_h, inner, 82)
		ui.rect(r, Color8(36, 30, 14), 12)
		ui.rect(r, ImUI.COL.accent, 12, 2)
		ui.text(u.name, r.position + Vector2(12, 8), 15, "text", true, "topleft", inner - 24)
		ui.text(Lang.f("+%d de reputación", int(u.rep)), r.position + Vector2(12, 28), 12, "muted")
		var bw := (inner - 34) / 2
		if ui.button(Rect2(x + 12, r.position.y + 46, bw, 28), Lang.f("Comprar (%s)", Fmt.short(cost)), g.cash >= cost, "primary", 13):
			var res: Array = g.buy_office_decor(decor_pick)
			city.sfx.play("coin" if res[0] else "angry", 0.7)
			city.toast(res[1], "good" if res[0] else "bad")
			decor_pick = ""
			decor_hover = "?"
			city.sync_office_decor(g)
		if ui.button(Rect2(x + 22 + bw, r.position.y + 46, bw, 28), "Quitar", true, "normal", 13):
			decor_pick = ""
	if ui.button(Rect2(x, by, inner, 38), "Listo (Esc)", true, "primary", 15):
		city.close_decor()
