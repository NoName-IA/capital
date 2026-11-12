class_name Ventanas
extends RefCounted
## «Ventanas 98 · Edición Millonario»: el sistema (de broma) de la computadora de tu oficina. Te sientas, la cámara
## entra a la pantalla (City.sit_at_computer) y aparece esto: pantalla de inicio, escritorio con iconos, ventanas que
## se arrastran, barra de tareas con el menú Inicio, y los programas. El importante es Remodelar.exe (decorar cada
## puesto, local o megatienda); el resto son chistes. Se dibuja en el overlay "pc" (Overlays._draw_mode).

const NAME := "Ventanas 98"
const EDITION := "Edición Millonario"
const BOOT := 2.8              # segundos de la pantalla de inicio
const BAR := 40.0              # alto de la barra de tareas
const GRAY := Color8(192, 192, 192)
const SHADE := Color8(128, 128, 128)
const LIGHT := Color8(255, 255, 255)
const NAVY := Color8(0, 0, 128)
const BLUE := Color8(16, 132, 208)
const TEAL := Color8(0, 128, 128)
const INK := Color8(0, 0, 0)
const ICONS := [["remodelar", "Remodelar.exe"], ["empresa", "Mi Empresa"], ["oficina", "Personalizar oficina"],
		["docs", "Mis Documentos"], ["web", "Internet Explorador"], ["papelera", "Papelera"]]
const TRASH := ["plan_vender_hielo_en_el_polo.doc", "cafe_sin_cafe (idea).txt", "NFT_de_panes.ppt",
		"abrir_10_megatiendas_el_dia_1.xls", "contratar_a_mi_primo.doc", "precio_de_todo_a_1_peso.xls"]

var city
var t := 0.0                   # segundos desde que se prendió
var chimed := false
var wins: Array = []           # ventanas abiertas (la última va arriba): {id, title, r, min}
var start_open := false
var drag = null                # {w, off}: la ventana que estás arrastrando
var prev_down := false
var sel_icon := ""
var last_click := ["", 0]      # para el doble clic en los iconos
var loc_sel := -1              # Remodelar: la sucursal elegida
var item_sel := ""             # Remodelar: el artículo elegido
var list_scroll := 0.0
var msg = null                 # cuadro de mensaje encima de todo: {title, text, warn}
var nag_done := false
var web_tries := 0
var leaving := -1.0            # «Apagar»: segundos que quedan del mensaje de cierre
var wallpaper: Texture2D
var vis := Rect2(0, 0, 1280, 760)   # la parte de la pantalla que se ve (en una pantalla más ancha, más que 1280×760)


func _init(owner_city) -> void:
	city = owner_city


## Se prende (cada vez que te sientas).
func start() -> void:
	t = 0.0
	chimed = false
	wins = []
	start_open = false
	drag = null
	msg = null
	leaving = -1.0
	if wallpaper == null and ResourceLoader.exists("res://assets/imagenes/tutorial/meta.png"):
		wallpaper = load("res://assets/imagenes/tutorial/meta.png")


func booted() -> bool:
	return t >= BOOT


## Esc: cierra el mensaje o el menú Inicio; si no hay nada, te levantas de la computadora.
func escape() -> void:
	if msg != null:
		msg = null
	elif start_open:
		start_open = false
	elif leaving < 0:
		city.leave_computer()


func update(dt: float) -> void:
	t += dt
	if leaving >= 0:
		leaving -= dt
		if leaving < 0:
			city.leave_computer()
	if booted() and not chimed:
		chimed = true
		city.sfx.play("record", 0.6, 0.75)   # el sonido de inicio
	# La actualización obligatoria de siempre (una vez cada vez que te sientas)
	if booted() and not nag_done and t > BOOT + 35.0 and msg == null:
		nag_done = true
		_message("Ventanas Update", "Hay 1 actualización obligatoria (4,7 TB). Tu computadora se reiniciará en 10 minutos.", true)


# ---------- dibujo ----------
func draw(ui: ImUI) -> void:
	var W := ui.W
	var H := ui.H
	var vs: Vector2 = city.get_viewport().get_visible_rect().size
	var tl: Vector2 = ui.to_virtual(Vector2.ZERO)
	vis = Rect2(tl, ui.to_virtual(vs) - tl)
	ui.rect(Rect2(-3000, -3000, W + 6000, H + 6000), INK)
	if not booted():
		_draw_boot(ui)
		prev_down = ui.down
		return
	if leaving >= 0:
		ui.rect(Rect2(-3000, -3000, W + 6000, H + 6000), Color8(0, 0, 0))
		ui.text("Cerrando sesión...", Vector2(W / 2, H / 2), 22, Color8(255, 170, 40), true, "center")
		prev_down = ui.down
		return
	var click := ui.clicked
	var press: bool = ui.down and not prev_down
	# Fondo: la foto de tu ciudad (y verde agua alrededor, como siempre)
	ui.rect(Rect2(-3000, -3000, W + 6000, H + 6000), TEAL)
	if wallpaper:
		ui.image(wallpaper, Rect2(vis.position, Vector2(vis.size.x, vis.size.y - BAR)))
	# Qué recibe el clic: el mensaje, el menú Inicio, la ventana de más arriba bajo el mouse, la barra o el escritorio
	var menu_r := _start_rect(ui)
	var top := -1
	for i in range(wins.size() - 1, -1, -1):
		if not wins[i].min and wins[i].r.has_point(ui.mouse):
			top = i
			break
	var over_bar := ui.mouse.y >= vis.end.y - BAR
	var blocked := msg != null
	var over_menu := start_open and menu_r.has_point(ui.mouse)
	# Escritorio
	ui.clicked = click and not blocked and not over_menu and top < 0 and not over_bar
	_draw_icons(ui, press and not blocked and not over_menu and top < 0 and not over_bar)
	if ui.clicked and start_open:
		start_open = false
	# Ventanas
	for i in wins.size():
		var w: Dictionary = wins[i]
		if w.min:
			continue
		var mine: bool = i == top and not blocked and not over_menu
		ui.clicked = click and mine
		_draw_window(ui, w, i == wins.size() - 1, mine and press)
		if not wins.has(w):   # se cerró mientras se dibujaba
			break
	# Arrastrar
	if drag != null:
		if ui.down and wins.has(drag.w):
			var r: Rect2 = drag.w.r
			r.position = (ui.mouse - drag.off).clamp(Vector2(vis.position.x - r.size.x + 80, vis.position.y),
					Vector2(vis.end.x - 80, vis.end.y - BAR - 30))
			drag.w.r = r
		else:
			drag = null
	# Barra de tareas y menú Inicio
	ui.clicked = click and not blocked and not over_menu
	_draw_taskbar(ui)
	if start_open:
		ui.clicked = click and not blocked
		_draw_start(ui, menu_r)
	if msg != null:
		ui.clicked = click
		_draw_message(ui)
	ui.clicked = click
	prev_down = ui.down


## Pantalla de inicio: el logo, el nombre y la barrita que se mueve.
func _draw_boot(ui: ImUI) -> void:
	var c := Vector2(ui.W / 2, ui.H / 2 - 40)
	var a := clampf(t / 0.5, 0, 1)
	logo(ui, Rect2(c.x - 170, c.y - 60, 92, 120), a)
	ui.text("Ventanas", Vector2(c.x - 60, c.y - 34), 54, Color(1, 1, 1, a), true, "midleft")
	ui.text("98", Vector2(c.x + 190, c.y - 50), 30, Color(1.0, 0.6, 0.15, a), true, "midleft")
	ui.text(EDITION, Vector2(c.x - 56, c.y + 20), 20, Color(0.75, 0.75, 0.8, a), false, "midleft")
	var bar := Rect2(c.x - 140, c.y + 110, 280, 18)
	ui.rect(bar, Color8(30, 30, 30))
	ui.rect(bar, Color8(90, 90, 90), 0, 1)
	var k := fmod(t * 0.9, 1.4) - 0.2
	ui.set_clip(bar.grow(-2))
	for i in 3:
		ui.rect(Rect2(bar.position.x + k * bar.size.x + i * 16, bar.position.y + 3, 12, 12), Color8(40, 90, 230))
	ui.set_clip(null)
	ui.text("Cargando tu imperio...", Vector2(c.x, bar.end.y + 22), 14, Color(0.7, 0.7, 0.75, a), false, "center")
	ui.text("Copyright © 1998 Capital Corp. Todos los derechos reservados (y algunos más).", Vector2(c.x, ui.H - 40), 12,
			Color(0.5, 0.5, 0.55, a), false, "center")


## El logo: un rascacielos de cuadritos de colores.
static func logo(ui: ImUI, r: Rect2, alpha := 1.0) -> void:
	var cols := [Color8(235, 70, 50), Color8(60, 190, 80), Color8(40, 120, 235), Color8(250, 200, 40)]
	var cw := r.size.x / 2.0
	var rows := 4
	var ch := r.size.y / rows
	for row in rows:
		for col in 2:
			if row == 0 and col == 1:
				continue   # el escalón de arriba del edificio
			var cell := Rect2(r.position.x + col * cw + 2, r.position.y + row * ch + 2, cw - 4, ch - 4)
			ui.rect(cell, Color(cols[(row * 2 + col) % 4], alpha), 2)


# ---------- piezas al estilo de los 90 ----------
## Borde en relieve: claro arriba a la izquierda y oscuro abajo a la derecha (`sunken` al revés).
static func bevel(ui: ImUI, r: Rect2, sunken := false, fill = null) -> void:
	if fill != null:
		ui.rect(r, fill)
	var hi := LIGHT if not sunken else SHADE
	var lo := SHADE if not sunken else LIGHT
	ui.rect(Rect2(r.position.x, r.position.y, r.size.x, 2), hi)
	ui.rect(Rect2(r.position.x, r.position.y, 2, r.size.y), hi)
	ui.rect(Rect2(r.position.x, r.end.y - 2, r.size.x, 2), lo)
	ui.rect(Rect2(r.end.x - 2, r.position.y, 2, r.size.y), lo)


## Botón gris de los de antes. Devuelve true con el clic.
static func btn(ui: ImUI, r: Rect2, label: String, enabled := true, size := 14) -> bool:
	var hot := enabled and ui.hover(r)
	var pressed: bool = hot and ui.down
	bevel(ui, r, pressed, GRAY)
	ui.text(label, r.get_center() + (Vector2(1, 1) if pressed else Vector2.ZERO), size,
			INK if enabled else SHADE, false, "center", r.size.x - 8)
	return hot and ui.clicked


func _open(id: String) -> void:
	city.sfx.play("select", 0.4)
	start_open = false
	match id:
		"empresa":
			city.overlays.show("admin")   # la tablet de siempre; al cerrarla vuelves aquí
			return
		"oficina":
			city.open_office_decor()
			return
	for w in wins:
		if w.id == id:   # ya estaba abierta: al frente
			w.min = false
			wins.erase(w)
			wins.append(w)
			return
	var sizes := {"remodelar": Vector2(860, 540), "docs": Vector2(520, 320), "web": Vector2(660, 420), "papelera": Vector2(540, 380)}
	var titles := {"remodelar": "Remodelar.exe", "docs": "Mis Documentos", "web": "Internet Explorador", "papelera": "Papelera"}
	var sz: Vector2 = sizes[id]
	var n := wins.size()
	var r := Rect2(Vector2((1280 - sz.x) / 2 + n * 24, max(12.0, (760 - BAR - sz.y) / 2 + n * 24)), sz)
	wins.append({"id": id, "title": titles[id], "r": r, "min": false})


func _close(w: Dictionary) -> void:
	wins.erase(w)
	if drag != null and drag.w == w:
		drag = null


func _message(title: String, text: String, warn := false) -> void:
	msg = {"title": title, "text": text, "warn": warn}
	city.sfx.play("bad", 0.5, 1.3)


func _draw_icons(ui: ImUI, press: bool) -> void:
	for i in ICONS.size():
		var id: String = ICONS[i][0]
		var r := Rect2(vis.position.x + 18, vis.position.y + 18 + i * 96, 92, 86)
		var ir := Rect2(r.get_center().x - 22, r.position.y + 4, 44, 44)
		var sel := sel_icon == id
		draw_icon(ui, id, ir)
		if sel:
			ui.rect(ir, Color(0, 0, 0.5, 0.35))
		var label: String = Lang.t(ICONS[i][1])
		var lr := Rect2(r.position.x, r.position.y + 54, r.size.x, 30)
		if sel:
			ui.rect(Rect2(lr.get_center().x - ui.text_size(label, 13).x / 2 - 3, lr.position.y, ui.text_size(label, 13).x + 6, 18), NAVY)
		else:
			ui.text(label, lr.position + Vector2(r.size.x / 2 + 1, 1), 13, Color(0, 0, 0, 0.7), false, "midtop", r.size.x)
		ui.text(label, lr.position + Vector2(r.size.x / 2, 0), 13, LIGHT, false, "midtop", r.size.x)
		if press and r.has_point(ui.mouse):
			var now := Time.get_ticks_msec()
			if last_click[0] == id and now - int(last_click[1]) < 450:   # doble clic: se abre
				_open(id)
				last_click = ["", 0]
			else:
				last_click = [id, now]
			sel_icon = id
	if press and not Rect2(vis.position + Vector2(18, 18), Vector2(92, ICONS.size() * 96)).has_point(ui.mouse):
		sel_icon = ""


func _draw_window(ui: ImUI, w: Dictionary, active: bool, press: bool) -> void:
	var r: Rect2 = w.r
	bevel(ui, r, false, GRAY)
	ui.rect(Rect2(r.position.x + 1, r.position.y + 1, r.size.x - 2, r.size.y - 2), INK, 0, 1)
	bevel(ui, r.grow(-1), false)
	var tb := Rect2(r.position.x + 4, r.position.y + 4, r.size.x - 8, 26)
	ui.gradient(tb, NAVY if active else SHADE, BLUE if active else Color8(180, 180, 180))
	draw_icon(ui, w.id, Rect2(tb.position.x + 4, tb.position.y + 4, 18, 18))
	ui.text(Lang.t(w.title), Vector2(tb.position.x + 28, tb.get_center().y), 14, LIGHT if active else GRAY.lightened(0.4), true, "midleft", tb.size.x - 90)
	var xr := Rect2(tb.end.x - 24, tb.position.y + 3, 21, 19)
	var mr := Rect2(xr.position.x - 25, xr.position.y, 21, 19)
	if btn(ui, xr, "×", true, 16):
		_close(w)
		city.sfx.play("select", 0.3)
		return
	if btn(ui, mr, "_", true, 14):
		w.min = true
		return
	if press:
		wins.erase(w)   # al frente
		wins.append(w)
		if tb.has_point(ui.mouse) and not xr.has_point(ui.mouse) and not mr.has_point(ui.mouse):
			drag = {"w": w, "off": ui.mouse - r.position}
	var body := Rect2(r.position.x + 8, tb.end.y + 6, r.size.x - 16, r.end.y - tb.end.y - 14)
	match w.id:
		"remodelar":
			_app_remodel(ui, body)
		"docs":
			_app_docs(ui, body)
		"web":
			_app_web(ui, body)
		"papelera":
			_app_trash(ui, body)


func _start_rect(ui: ImUI) -> Rect2:
	var h := 6 * 40 + 14 + 46
	return Rect2(vis.position.x + 2, vis.end.y - BAR - h, 270, h)


func _draw_taskbar(ui: ImUI) -> void:
	var W := ui.W
	var H := vis.end.y
	var bar := Rect2(-3000, H - BAR, W + 6000, BAR + 3000)
	ui.rect(bar, GRAY)
	ui.rect(Rect2(-3000, H - BAR, W + 6000, 2), LIGHT)
	# Inicio
	var sr := Rect2(vis.position.x + 4, H - BAR + 5, 96, 30)
	var hot := ui.hover(sr)
	bevel(ui, sr, start_open or (hot and ui.down), GRAY)
	logo(ui, Rect2(sr.position.x + 8, sr.position.y + 5, 16, 20))
	ui.text("Inicio", Vector2(sr.position.x + 32, sr.get_center().y), 15, INK, true, "midleft")
	if hot and ui.clicked:
		start_open = not start_open
		city.sfx.play("select", 0.3)
	# Una pestaña por ventana abierta
	var x := vis.position.x + 110.0
	for w in wins.duplicate():
		var r := Rect2(x, H - BAR + 5, 170, 30)
		var on: bool = not w.min and w == wins[-1]
		var h2 := ui.hover(r)
		bevel(ui, r, on, Color8(210, 210, 210) if on else GRAY)
		draw_icon(ui, w.id, Rect2(r.position.x + 6, r.position.y + 6, 18, 18))
		ui.text(Lang.t(w.title), Vector2(r.position.x + 30, r.get_center().y), 13, INK, on, "midleft", r.size.x - 36)
		if h2 and ui.clicked:
			if w.min:
				w.min = false
				wins.erase(w)
				wins.append(w)
			elif on:
				w.min = true
			else:
				wins.erase(w)
				wins.append(w)
		x += 176
	# Bandeja: tu plata y la hora del juego
	var g = city.game
	var tr := Rect2(vis.end.x - 230, H - BAR + 5, 226, 30)
	bevel(ui, tr, true, GRAY)
	if g != null:
		var hour: float = SkyLight.hour_of(city.day_fraction())
		ui.text(Fmt.money(g.cash), Vector2(tr.position.x + 12, tr.get_center().y), 14, Color8(0, 110, 0) if g.cash >= 0 else Color8(170, 0, 0), true, "midleft")
		ui.text("%02d:%02d" % [int(hour), int(fmod(hour, 1.0) * 60)], Vector2(tr.end.x - 12, tr.get_center().y), 14, INK, false, "midright")


func _draw_start(ui: ImUI, r: Rect2) -> void:
	bevel(ui, r, false, GRAY)
	var band := Rect2(r.position.x + 3, r.position.y + 3, 30, r.size.y - 6)
	ui.gradient(band, NAVY, BLUE, false)
	ui.text("98", Vector2(band.get_center().x, band.end.y - 14), 16, LIGHT, true, "center")
	var items := [["remodelar", "Remodelar.exe"], ["empresa", "Mi Empresa"], ["oficina", "Personalizar oficina"],
			["docs", "Mis Documentos"], ["web", "Internet Explorador"], ["papelera", "Papelera"]]
	var y := r.position.y + 6
	for it in items:
		var ir := Rect2(band.end.x + 3, y, r.end.x - band.end.x - 8, 38)
		var hot := ui.hover(ir)
		if hot:
			ui.rect(ir, NAVY)
		draw_icon(ui, it[0], Rect2(ir.position.x + 6, ir.position.y + 5, 28, 28))
		ui.text(Lang.t(it[1]), Vector2(ir.position.x + 44, ir.get_center().y), 15, LIGHT if hot else INK, false, "midleft")
		if hot and ui.clicked:
			_open(it[0])
		y += 40
	ui.rect(Rect2(band.end.x + 6, y + 4, r.end.x - band.end.x - 14, 1), SHADE)
	ui.rect(Rect2(band.end.x + 6, y + 5, r.end.x - band.end.x - 14, 1), LIGHT)
	var off := Rect2(band.end.x + 3, y + 10, r.end.x - band.end.x - 8, 38)
	var hot2 := ui.hover(off)
	if hot2:
		ui.rect(off, NAVY)
	draw_icon(ui, "apagar", Rect2(off.position.x + 6, off.position.y + 5, 28, 28))
	ui.text("Apagar...", Vector2(off.position.x + 44, off.get_center().y), 15, LIGHT if hot2 else INK, false, "midleft")
	if hot2 and ui.clicked:
		start_open = false
		leaving = 1.0


func _draw_message(ui: ImUI) -> void:
	var r := Rect2(ui.W / 2 - 230, ui.H / 2 - 100, 460, 170)
	ui.rect(Rect2(-3000, -3000, ui.W + 6000, ui.H + 6000), Color(0, 0, 0, 0.15))
	bevel(ui, r, false, GRAY)
	var tb := Rect2(r.position.x + 4, r.position.y + 4, r.size.x - 8, 26)
	ui.gradient(tb, NAVY, BLUE)
	ui.text(Lang.t(msg.title), Vector2(tb.position.x + 8, tb.get_center().y), 14, LIGHT, true, "midleft")
	var ic := Vector2(r.position.x + 44, r.position.y + 72)
	if msg.warn:
		ui.polygon(PackedVector2Array([ic + Vector2(0, -20), ic + Vector2(20, 16), ic + Vector2(-20, 16)]), Color8(250, 210, 40))
		ui.text("!", ic + Vector2(0, 3), 22, INK, true, "center")
	else:
		ui.circle(ic, 18, Color8(30, 60, 200))
		ui.text("i", ic, 22, LIGHT, true, "center")
	ui.wrap_text(Lang.t(msg.text), Rect2(r.position.x + 80, r.position.y + 46, r.size.x - 100, 70), 14, INK)
	var label := "Recordarme en 10 años" if msg.warn else "Aceptar"
	var bw := ui.text_size(label, 14).x + 40
	if btn(ui, Rect2(r.get_center().x - bw / 2, r.end.y - 44, bw, 30), label):
		msg = null
		city.sfx.play("select", 0.3)


# ---------- programas ----------
## Remodelar.exe: a la izquierda tus sucursales, a la derecha lo que le puedes poner a la elegida (con la foto de cada
## artículo, como en la ventana de decorar). «Ver en vivo» te lleva al local con la cámara.
func _app_remodel(ui: ImUI, body: Rect2) -> void:
	var g: Game = city.game
	if g == null:
		return
	var locs := []
	for k in D.PRODUCT_ORDER:
		var ls: Array = g.locs(k)
		for i in ls.size():
			locs.append([ls[i], i + 1])
	# Lista de sucursales
	var lr := Rect2(body.position.x, body.position.y, 250, body.size.y)
	bevel(ui, lr, true, LIGHT)
	if locs.is_empty():
		ui.wrap_text("Todavía no tienes locales. Compra un terreno SE VENDE.", lr.grow(-12), 14, INK)
		return
	var found := false
	for e in locs:
		found = found or int(e[0].id) == loc_sel
	if not found:
		loc_sel = int(locs[0][0].id)
		item_sel = ""
	var row_h := 34.0
	var inner := lr.grow(-3)
	if ui.hover(inner) and ui.wheel != 0:
		list_scroll -= ui.wheel * row_h
	list_scroll = clampf(list_scroll, 0, maxf(0, locs.size() * row_h - inner.size.y))
	ui.set_clip(inner)
	var sel_loc = null
	var sel_n := 1
	for i in locs.size():
		var loc: Dictionary = locs[i][0]
		var rr := Rect2(inner.position.x, inner.position.y + i * row_h - list_scroll, inner.size.x, row_h)
		var on := int(loc.id) == loc_sel
		if on:
			ui.rect(rr, NAVY)
			sel_loc = loc
			sel_n = locs[i][1]
		var n_dec: int = loc.get("upgrades", []).size()
		var total: int = D.upgrades_for(int(loc.size)).size()
		ui.text(Lang.f("%s #%d", [D.SIZES[loc.size].name, locs[i][1]]), Vector2(rr.position.x + 10, rr.position.y + 5), 14, LIGHT if on else INK, true)
		ui.text(Lang.noun(D.PRODUCTS[loc.product].name), Vector2(rr.position.x + 10, rr.position.y + 20), 11, LIGHT if on else SHADE)
		ui.text("%d/%d" % [n_dec, total], Vector2(rr.end.x - 10, rr.get_center().y), 13, LIGHT if on else INK, false, "midright")
		if ui.hover(rr) and ui.clicked and inner.has_point(ui.mouse):
			loc_sel = int(loc.id)
			item_sel = ""
			city.sfx.play("select", 0.3)
	ui.set_clip(null)
	if sel_loc == null:
		return
	# Artículos de la sucursal elegida
	var rx := lr.end.x + 10
	var rw := body.end.x - rx
	ui.text(Lang.f("%s #%d · %s", [D.SIZES[sel_loc.size].name, sel_n, Lang.noun(D.PRODUCTS[sel_loc.product].name)]),
			Vector2(rx, body.position.y + 4), 18, INK, true)
	ui.text(Lang.f("Caja: %s", Fmt.money(g.cash)), Vector2(rx, body.position.y + 28), 13, SHADE)
	if btn(ui, Rect2(body.end.x - 130, body.position.y + 2, 130, 30), "Ver en vivo"):
		city.open_decor(int(sel_loc.id))
		return
	var items: Array = D.upgrades_for(int(sel_loc.size))
	var owned: Array = sel_loc.get("upgrades", [])
	var store = null
	for s in city.stores.values():
		if s.loc.id == sel_loc.id:
			store = s
	var variant: int = store.plot_index + int(sel_loc.id) * 31 if store != null else -1
	var cols := 4
	var gap := 8.0
	var tw := (rw - gap * (cols - 1)) / cols
	var th := 150.0
	var gy := body.position.y + 52
	for i in items.size():
		var u: Dictionary = items[i]
		var r := Rect2(rx + (i % cols) * (tw + gap), gy + (i / cols) * (th + gap), tw, th)
		var has: bool = u.key in owned
		var hot := ui.hover(r)
		bevel(ui, r, item_sel == u.key, Color8(225, 225, 225) if hot or item_sel == u.key else GRAY)
		var img = city.thumbs.get_decor_thumb(sel_loc, variant, u.key)
		var ir := Rect2(r.get_center().x - 46, r.position.y + 8, 92, 92)
		if img != null:
			ui.image(img, ir)
		else:
			ui.rect(ir, Color8(160, 160, 160))
		ui.text(u.name, Vector2(r.get_center().x, r.position.y + 106), 12, INK, true, "midtop", r.size.x - 10)
		if has:
			ui.text("✓ Ya lo tienes", Vector2(r.get_center().x, r.end.y - 18), 12, Color8(0, 120, 0), true, "center")
		else:
			var cost := g.decor_cost(sel_loc, u.key)
			ui.text(Fmt.short(cost), Vector2(r.get_center().x, r.end.y - 18), 13, INK if g.cash >= cost else Color8(170, 0, 0), true, "center")
		if hot and ui.clicked:
			item_sel = u.key
			city.sfx.play("select", 0.3)
	# Abajo: lo elegido, para qué sirve y comprar
	var br := Rect2(rx, body.end.y - 70, rw, 70)
	bevel(ui, br, true, Color8(235, 235, 225))
	if item_sel == "":
		ui.text("Elige un artículo para ver qué hace.", Vector2(br.position.x + 12, br.get_center().y), 14, SHADE, false, "midleft")
		return
	var sel_u: Dictionary = {}
	for u in items:
		if u.key == item_sel:
			sel_u = u
	if sel_u.is_empty():
		item_sel = ""
		return
	ui.text(sel_u.name, br.position + Vector2(12, 8), 15, INK, true)
	ui.wrap_text(Overlays.decor_effect(sel_u), Rect2(br.position.x + 12, br.position.y + 30, rw - 200, 36), 12, INK)
	if item_sel in owned:
		ui.text("✓ Ya lo tienes", Vector2(br.end.x - 16, br.get_center().y), 14, Color8(0, 120, 0), true, "midright")
		return
	var cost2 := g.decor_cost(sel_loc, item_sel)
	if btn(ui, Rect2(br.end.x - 170, br.position.y + 18, 156, 34), Lang.f("Comprar (%s)", Fmt.short(cost2)), g.cash >= cost2):
		var res: Array = g.buy_decor(sel_loc, item_sel)
		if res[0]:
			city.sfx.play("coin", 0.6)
			if store != null:
				store.sync_decor()
			item_sel = ""
		else:
			_message("Remodelar.exe", res[1], true)


func _app_docs(ui: ImUI, body: Rect2) -> void:
	ui.text("Archivo   Edición   Ver   Ayuda", body.position + Vector2(4, 2), 13, INK)
	var r := Rect2(body.position.x, body.position.y + 24, body.size.x, body.size.y - 24)
	bevel(ui, r, true, LIGHT)
	draw_icon(ui, "docs", Rect2(r.get_center().x - 32, r.position.y + 40, 64, 64))
	ui.text("Esta carpeta está vacía.", Vector2(r.get_center().x, r.position.y + 124), 16, INK, true, "midtop")
	ui.text("Aquí iban tus impuestos.", Vector2(r.get_center().x, r.position.y + 150), 14, SHADE, false, "midtop")


func _app_web(ui: ImUI, body: Rect2) -> void:
	ui.text("Dirección", Vector2(body.position.x + 2, body.position.y + 13), 13, INK, false, "midleft")
	var ar := Rect2(body.position.x + 72, body.position.y + 1, body.size.x - 72, 24)
	bevel(ui, ar, true, LIGHT)
	ui.text("http://www.comovolverserico.com", Vector2(ar.position.x + 8, ar.get_center().y), 13, INK, false, "midleft")
	var r := Rect2(body.position.x, body.position.y + 32, body.size.x, body.size.y - 32)
	bevel(ui, r, true, LIGHT)
	var x := r.position.x + 24
	var y := r.position.y + 22
	draw_icon(ui, "web", Rect2(x, y, 48, 48))
	ui.text("No se puede mostrar la página", Vector2(x + 64, y + 12), 20, INK, true)
	y += 70
	ui.wrap_text("El módem está ocupado: alguien levantó el teléfono de la casa.", Rect2(x, y, r.size.x - 48, 40), 14, INK)
	y += 40
	ui.text("Pruebe lo siguiente:", Vector2(x, y), 14, INK, true)
	ui.text("•  Desenchufar el módem y volver a enchufarlo.", Vector2(x + 10, y + 24), 14, INK)
	ui.text("•  Gritar «¡CUELGA EL TELÉFONO!».", Vector2(x + 10, y + 46), 14, INK)
	if web_tries > 0:
		ui.text(Lang.f("Intento %d: sigue ocupado.", web_tries), Vector2(x, y + 80), 13, Color8(170, 0, 0))
	if btn(ui, Rect2(r.end.x - 130, r.end.y - 46, 110, 30), "Reintentar"):
		web_tries += 1
		city.sfx.play("bad", 0.4, 1.4)


func _app_trash(ui: ImUI, body: Rect2) -> void:
	var r := Rect2(body.position.x, body.position.y, body.size.x, body.size.y - 44)
	bevel(ui, r, true, LIGHT)
	var y := r.position.y + 10
	for f in TRASH:
		draw_icon(ui, "archivo", Rect2(r.position.x + 12, y, 20, 22))
		ui.text(f, Vector2(r.position.x + 42, y + 11), 14, INK, false, "midleft")
		y += 32
	if btn(ui, Rect2(body.end.x - 170, body.end.y - 36, 170, 32), "Vaciar papelera"):
		_message("Papelera", "No se puede vaciar la papelera: los malos planes siempre vuelven.")


# ---------- iconos dibujados ----------
static func draw_icon(ui: ImUI, id: String, r: Rect2) -> void:
	var s := r.size.x / 44.0
	var o := r.position
	var p := func(x: float, y: float) -> Vector2: return o + Vector2(x, y) * s
	match id:
		"remodelar":   # rodillo de pintura
			ui.rect(Rect2(p.call(6, 6), Vector2(30, 12) * s), Color8(240, 80, 70), 3 * s)
			ui.rect(Rect2(p.call(6, 6), Vector2(30, 4) * s), Color8(255, 140, 120), 2 * s)
			ui.line(p.call(36, 12), p.call(40, 12), INK, 3 * s)
			ui.line(p.call(40, 12), p.call(40, 24), INK, 3 * s)
			ui.line(p.call(40, 24), p.call(22, 24), INK, 3 * s)
			ui.rect(Rect2(p.call(19, 24), Vector2(6, 16) * s), Color8(90, 60, 40), 2 * s)
		"empresa":   # la tablet
			ui.rect(Rect2(p.call(8, 4), Vector2(28, 36) * s), Color8(30, 34, 44), 4 * s)
			ui.rect(Rect2(p.call(11, 8), Vector2(22, 26) * s), Color8(60, 170, 120), 2 * s)
			ui.rect(Rect2(p.call(14, 24), Vector2(4, 8) * s), Color8(250, 210, 60))
			ui.rect(Rect2(p.call(20, 18), Vector2(4, 14) * s), Color8(250, 210, 60))
			ui.rect(Rect2(p.call(26, 12), Vector2(4, 20) * s), Color8(250, 210, 60))
		"oficina":   # el edificio
			ui.rect(Rect2(p.call(10, 4), Vector2(24, 38) * s), Color8(200, 170, 110))
			for row in 4:
				for col in 3:
					ui.rect(Rect2(p.call(13 + col * 7, 8 + row * 7), Vector2(4, 4) * s), Color8(80, 140, 210))
			ui.rect(Rect2(p.call(19, 34), Vector2(6, 8) * s), Color8(90, 60, 40))
		"docs":   # carpeta amarilla
			ui.rect(Rect2(p.call(4, 10), Vector2(16, 6) * s), Color8(230, 190, 60), 2 * s)
			ui.rect(Rect2(p.call(4, 14), Vector2(36, 24) * s), Color8(250, 215, 90), 2 * s)
			ui.rect(Rect2(p.call(4, 14), Vector2(36, 3) * s), Color8(255, 235, 150))
		"web":   # globo terráqueo
			var c: Vector2 = p.call(22, 22)
			ui.circle(c, 17 * s, Color8(40, 110, 220))
			ui.circle(c + Vector2(-5, -4) * s, 6 * s, Color8(70, 180, 90))
			ui.circle(c + Vector2(6, 6) * s, 5 * s, Color8(70, 180, 90))
			ui.ring(c, 17 * s, Color8(20, 60, 140), 2 * s)
			ui.line(c + Vector2(-17, 0) * s, c + Vector2(17, 0) * s, Color(1, 1, 1, 0.5), 1)
		"papelera":   # tacho con papeles
			ui.rect(Rect2(p.call(10, 12), Vector2(24, 28) * s), Color8(170, 175, 185), 2 * s)
			ui.rect(Rect2(p.call(8, 9), Vector2(28, 4) * s), Color8(130, 135, 145), 1 * s)
			ui.rect(Rect2(p.call(14, 4), Vector2(9, 8) * s), LIGHT)
			ui.rect(Rect2(p.call(22, 3), Vector2(8, 9) * s), Color8(240, 240, 220))
			for x in [16, 22, 28]:
				ui.line(p.call(x, 16), p.call(x, 36), Color8(120, 125, 135), 2 * s)
		"archivo":
			ui.rect(Rect2(o, r.size), LIGHT)
			ui.rect(Rect2(o, r.size), SHADE, 0, 1)
			for k in 3:
				ui.line(o + Vector2(4, 7 + k * 5) * s * 2.2, o + Vector2(16, 7 + k * 5) * s * 2.2, Color8(80, 80, 200), 1)
		"apagar":   # botón rojo
			var c2: Vector2 = p.call(22, 22)
			ui.circle(c2, 16 * s, Color8(200, 40, 40))
			ui.ring(c2, 9 * s, LIGHT, 3 * s)
			ui.rect(Rect2(c2 + Vector2(-1.5, -13) * s, Vector2(3, 12) * s), LIGHT)
