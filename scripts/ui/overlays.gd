class_name Overlays
extends RefCounted
## Ventanas que se abren encima de la ciudad: el celular (administración), la compra de un terreno, el menú de
## pausa con sus ajustes y controles, el armario, la vitrina de trofeos y la reunión de estrategia.

const CONTROLS := [
	["MOVERTE", [["W A S D", "Caminar"], ["Shift", "Correr (mantener apretado)"], ["Espacio", "Saltar"],
			["Mouse", "Mirar alrededor"], ["Rueda", "Acercar o alejar la cámara; muy cerca pasa a primera persona"],
			["V", "Cambiar entre primera y tercera persona"]]],
	["ACCIONES", [["E", "Interactuar: comprar terrenos, atender el mostrador, administrar un local, usar la computadora o el armario. También cierra ventanas"],
			["Tab", "Abrir o cerrar el celular con todas las pantallas de administración"],
			["O", "Ir a la oficina central"],
			["Armario", "Arrastra con el clic para girar al personaje, rueda para acercar o alejar, clic derecho para subir o bajar la vista, A/D para girar y R para centrar"]]],
	["JUEGO", [["Esc", "Menú de pausa (y volver atrás)"], ["P", "Pausa rápida, sin menú"],
			["1  2  3", "Velocidad del tiempo: normal, rápida y muy rápida"],
			["Alt", "Soltar o capturar el mouse (apriétala y suéltala sola)"], ["M", "Música sí / no"],
			["H", "Mostrar u ocultar la ayuda en pantalla"], ["F11", "Pantalla completa"]]],
]
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
const TUTORIAL := [
	["meta", "Bienvenido a Capital", "Empiezas con un poco de plata y tu propia empresa. Vende, invierte y crece.

Tu meta: que tu empresa llegue a valer $1.000.000. Arriba a la izquierda ves cuánto vale y cuánto te falta."],
	["moverse", "Muévete por la ciudad", "W A S D para caminar · Shift para correr · Espacio para saltar.
Mueve el mouse para mirar y usa la rueda para acercar o alejar la cámara.
Alt suelta el mouse para hacer clic en los botones."],
	["terreno", "Compra terrenos", "Acércate a un letrero SE VENDE y aprieta E.
Elige qué vender (café, pan, hamburguesas...) y el tamaño: puesto, local o megatienda. Más grande vende más, pero cuesta más cada mes."],
	["celular", "Tu celular (Tab)", "En el celular manejas todo: precios, calidad, empleados, inventario, publicidad y préstamos.
Revisa Resumen seguido: ahí ves si estás ganando o perdiendo plata."],
	["clientes", "Clientes y empleados", "Los clientes hacen fila y tus empleados les venden lo de tu negocio.
Si ves un ! rojo, alguien se fue enojado: falta personal o producto. Contrata más o repón inventario."],
	["oficina", "Cuida la caja", "Si la caja queda en negativo mucho tiempo, la empresa quiebra. No crezcas con deuda más rápido de lo que vendes.
En tu oficina (tecla O) están la computadora, la estrategia, los trofeos y el armario."],
	["eldiario", "ELDIARIO", "Al lado de tu oficina está el kiosco ELDIARIO: su pantalla muestra el clima de hoy, la temperatura, la hora y el pronóstico de mañana.

¡Listo! Ahora a construir tu imperio."],
]
var shop_tab := "cabeza"
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
	auto = is_auto
	city.release_mouse()


func hide() -> void:
	mode = null
	auto = false
	city.capture_mouse()


func draw() -> void:
	match mode:
		"admin":
			if app.view == "menu" or app.game == null:
				ui.rect(Rect2(0, 0, W, H), Color(0.05, 0.067, 0.09, 0.82))
				app.draw_menu()
			else:
				draw_tablet_frame()
				app.draw_game()
				# Un clic fuera de la tablet la guarda
				if ui.clicked and app.modal == null and not Rect2(-30, -30, W + 60, H + 60).has_point(ui.mouse):
					hide()
		"lote":
			ui.rect(Rect2(0, 0, W, H), Color(0, 0, 0, 0.35))
			draw_lot()
		"pausa":
			ui.rect(Rect2(0, 0, W, H), Color(0, 0, 0, 0.35))
			draw_pause()
		"personaje":
			draw_custom()
		"estrategia":
			ui.rect(Rect2(0, 0, W, H), Color(0, 0, 0, 0.35))
			draw_strategy()
		"trofeos":
			ui.rect(Rect2(0, 0, W, H), Color(0, 0, 0, 0.35))
			draw_trophies()
		"tutorial":
			ui.rect(Rect2(0, 0, W, H), Color(0, 0, 0, 0.55))
			draw_tutorial()


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
func draw_lot() -> void:
	var g: Game = app.game
	var beach: bool = lot in D.BEACH_PLOTS
	ui.panel(Rect2(40, 30, W - 80, H - 60))
	ui.text("Terreno %d en venta%s" % [lot + 1, " · en la playa" if beach else ""], Vector2(70, 60), 32, "accent", true)
	var y0 := 110.0
	if beach:
		ui.text("Frente al mar: +%d%% de clientes por los turistas." % roundi((D.BEACH_BONUS - 1) * 100), Vector2(72, 98), 16, "green", true)
		y0 = 128
	ui.wrap_text("Elige qué negocio construir aquí. La construcción es una inversión (CAPEX) que se deprecia en 5 años; el alquiler es un costo fijo que pagas cada mes vendas o no. Más grande = más clientes y más empleados, pero también más costo fijo.",
			Rect2(70, y0, W - 140, 80), 16, "muted")
	ui.text("Caja disponible: %s" % Fmt.money(g.cash), Vector2(W - 70, 64), 20, Admin.sc(g.cash), true, "topright")
	var y := 200.0
	for key in D.PRODUCT_ORDER:
		var p: Dictionary = g.products[key]
		var d: Dictionary = D.PRODUCTS[key]
		ui.text(d.name, Vector2(70, y + 8), 22, "text" if p.unlocked else "muted", true)
		if not p.unlocked:
			ui.text("Bloqueado: desbloquéalo en el celular (Negocios) por %s" % Fmt.money(g.unlock_cost(key)), Vector2(290, y + 12), 16, "muted")
		else:
			for s in D.SIZES.size():
				var size: Dictionary = D.SIZES[s]
				var cost := g.location_cost(s)
				var tip := "%s: inversión %s, alquiler %s/mes, hasta %d empleados, tráfico ×%d." % [size.name, Fmt.money(cost), Fmt.money(size.rent * g.price_index), size.max_emp, int(size.traffic)]
				if ui.button(Rect2(290 + s * 300, y, 285, 44), "%s · %s" % [size.name, Fmt.money(cost)], g.cash >= cost, "normal", 15, tip):
					var res := g.open_location(key, s, lot)
					if res[0]:
						hide()
						city.sfx.play("record", 0.7)
					city.toast(res[1], "good" if res[0] else "bad")
					return
		y += 74
	if ui.button(Rect2(W / 2 - 140, H - 100, 280, 44), "Cancelar (Esc)"):
		hide()


# ---------- menú de pausa ----------
## Ajustes y opciones. La ciudad se ve (desenfocada) detrás.
func draw_pause() -> void:
	var s: Dictionary = city.settings
	var box := Rect2(W / 2 - 470, H / 2 - 330, 940, 660)
	glass_box(box)
	if pause_page == "controles":
		draw_controls(box)
		return
	if pause_page == "graficos":
		draw_graphics(box)
		return
	ui.text("Pausa", box.position + Vector2(40, 28), 34, "accent", true)
	ui.text("El juego está detenido. Los ajustes se guardan solos.", box.position + Vector2(42, 76), 15, "muted")
	var x := box.position.x + 40
	var w := 470.0
	var y := box.position.y + 120
	ui.text("SONIDO", Vector2(x, y), 13, "muted", true)
	y = slider(x, y + 24, w, "Música", "music", 0, 1, func(v): return "%d%%" % roundi(v * 100))
	y = slider(x, y, w, "Efectos de sonido", "effects", 0, 1, func(v): return "%d%%" % roundi(v * 100))
	ui.text("CÁMARA Y CONTROLES", Vector2(x, y + 6), 13, "muted", true)
	y = slider(x, y + 30, w, "Sensibilidad del mouse", "sensitivity", 0.3, 2.5, func(v): return Fmt.num(v, 1) + "x")
	y = slider(x, y, w, "Campo de visión", "fov", 55, 100, func(v): return "%d°" % roundi(v))
	y = toggle(x, y, w, "Invertir el mouse vertical", "invert_y")
	ui.text("PANTALLA Y JUEGO", Vector2(x, y + 6), 13, "muted", true)
	y = toggle(x, y + 30, w, "Pantalla completa (F11)", "fullscreen", city.toggle_fullscreen)
	y = toggle(x, y, w, "Ciclo de día y noche", "day_night")
	y = toggle(x, y, w, "Comentarios de los clientes", "comments")
	y = toggle(x, y, w, "Mostrar la ayuda de controles al empezar", "help")

	var rx := box.position.x + 580
	var rw := 320.0
	var ry := box.position.y + 120
	if ui.button(Rect2(rx, ry, rw, 50), "Continuar (Esc)", true, "primary", 18):
		city.close_pause()
		return
	if ui.button(Rect2(rx, ry + 60, rw, 44), "Ir a la oficina (O)", true, "normal", 16):
		city.close_pause()
		city.go_to_office()
		return
	if ui.button(Rect2(rx, ry + 112, rw / 2 - 5, 44), "Controles", true, "normal", 16):
		pause_page = "controles"
		return
	if ui.button(Rect2(rx + rw / 2 + 5, ry + 112, rw / 2 - 5, 44), "Gráficos", true, "normal", 16):
		pause_page = "graficos"
		return
	# Guardar en cualquiera de los 3 espacios; el elegido pasa a ser el de esta partida (y del autoguardado)
	ui.text("Guardar en  (ahora: espacio %d)" % app.slot, Vector2(rx, ry + 162), 13, "muted", true)
	for i in Admin.SLOTS:
		var n := i + 1
		if ui.button(Rect2(rx + i * 110, ry + 182, 100, 36), "Espacio %d" % n, true, "normal", 14,
				"Ocupado: se sobrescribe" if n != app.slot and app.slot_info(n) != null else null, app.slot == n):
			app.save(true, n)
			city.toast("Partida guardada en el espacio %d." % n, "good")
			saved_at = Time.get_ticks_msec()
	if Time.get_ticks_msec() - saved_at < 2500:
		ui.text("¡Guardada!", Vector2(rx + rw / 2, ry + 220), 14, "green", true, "midtop")
	if ui.button(Rect2(rx, ry + 236, rw, 44), "Menú principal (guarda)", true, "normal", 16):
		city.close_pause()
		app.save(true)
		app.view = "menu"
		show("admin")
		return
	if ui.button(Rect2(rx, ry + 288, rw, 44), "Salir del juego (guarda)", true, "danger", 16):
		city.close_pause()
		city.quit_game()
		return
	ui.text("Velocidad del juego", Vector2(rx, ry + 352), 15, "text")
	for i in Admin.SPEEDS.size():
		if ui.button(Rect2(rx + i * 110, ry + 376, 100, 36), Admin.SPEEDS[i][1], true, "normal", 15, null, app.speed == i):
			app.speed = i
	toggle(rx, ry + 432, rw, "Desenfocar el fondo en menús", "blur")


# ---------- tutorial ----------
func tutorial_next() -> void:
	if tutorial_page >= TUTORIAL.size() - 1:
		city.close_tutorial()
	else:
		tutorial_page += 1


## Una página por vez: imagen del juego, título y unas líneas. Se pasa con los botones, las flechas o Enter.
func draw_tutorial() -> void:
	var page: Array = TUTORIAL[tutorial_page]
	var box := Rect2(W / 2 - 470, H / 2 - 350, 940, 700)
	glass_box(box)
	ui.text("TUTORIAL · %d de %d" % [tutorial_page + 1, TUTORIAL.size()], box.position + Vector2(40, 24), 13, "muted", true)
	if ui.button(Rect2(box.end.x - 170, box.position.y + 18, 130, 32), "Saltar (Esc)", true, "normal", 13):
		city.close_tutorial()
		return
	var img := Rect2(box.position.x + 150, box.position.y + 60, 640, 360)
	var key: String = page[0]
	if not tutorial_tex.has(key):
		var path := "res://images/tutorial/%s.png" % key
		tutorial_tex[key] = load(path) if ResourceLoader.exists(path) else null
	if tutorial_tex[key]:
		ui.image(tutorial_tex[key], img)
	else:
		ui.rect(img, "panel2", 10)
	ui.rect(img, "border", 4, 1)
	ui.text(page[1], Vector2(box.get_center().x, img.end.y + 18), 28, "accent", true, "midtop")
	ui.wrap_text(page[2], Rect2(box.position.x + 70, img.end.y + 64, box.size.x - 140, 130), 16, "text")
	# Puntos de las páginas
	var n := TUTORIAL.size()
	for i in n:
		ui.circle(Vector2(box.get_center().x + (i - (n - 1) / 2.0) * 22, box.end.y - 86), 5,
				"accent" if i == tutorial_page else "border")
	var last := tutorial_page == n - 1
	if tutorial_page > 0 and ui.button(Rect2(box.position.x + 40, box.end.y - 64, 200, 44), "< Anterior", true, "normal", 16):
		tutorial_page -= 1
	if ui.button(Rect2(box.end.x - 240, box.end.y - 64, 200, 44), "¡A jugar!" if last else "Siguiente >", true, "primary", 17):
		tutorial_next()


## Página «Controles» del menú de pausa: cada tecla con una descripción breve.
func draw_controls(box: Rect2) -> void:
	ui.text("Controles", box.position + Vector2(40, 28), 34, "accent", true)
	ui.text("Las teclas solas: con Ctrl, Alt o Windows apretadas el juego no reacciona (así Alt+Tab no abre nada).",
			box.position + Vector2(42, 76), 14, "muted")
	var cols := [[box.position.x + 40, CONTROLS.slice(0, 2)], [box.position.x + 490, CONTROLS.slice(2)]]
	for c in cols:
		var cx: float = c[0]
		var y := box.position.y + 118
		for section in c[1]:
			ui.text(section[0], Vector2(cx, y), 13, "muted", true)
			y += 26
			for row in section[1]:
				var kw: float = max(56.0, ui.text_size(row[0], 14, true).x + 22)
				var chip := Rect2(cx, y, kw, 28)
				ui.rect(chip, "panel2", 7)
				ui.rect(chip, "border", 7, 1)
				ui.text(row[0], chip.get_center(), 14, "text", true, "center")
				var h := ui.wrap_text(row[1], Rect2(cx + kw + 14, y + 4, 410 - kw - 14, 60), 14, "text", false, 1)
				y += max(36.0, h + 10)
			y += 10
	if ui.button(Rect2(box.position.x + 40, box.end.y - 70, 220, 46), "Ver el tutorial", true, "normal", 16):
		pause_page = "main"
		city.close_pause()
		city.open_tutorial()
		return
	if ui.button(Rect2(box.get_center().x - 140, box.end.y - 70, 280, 46), "Volver (Esc)", true, "primary", 17):
		pause_page = "main"


## Página «Gráficos»: un nivel listo (Bajo, Medio, Alto) o cada opción por separado (Personalizado).
func draw_graphics(box: Rect2) -> void:
	var s: Dictionary = city.settings
	Graphics.show_preset(s)
	ui.text("Gráficos", box.position + Vector2(40, 28), 34, "accent", true)
	ui.text("%d cuadros por segundo" % Engine.get_frames_per_second(), box.position + Vector2(box.size.x - 40, 40), 16,
			"muted", false, "topright")
	ui.text("Alto imita el shader Eclipse: sombras nítidas hasta lejos y rincones oscurecidos por la oclusión ambiental.",
			box.position + Vector2(42, 76), 15, "muted")
	var x := box.position.x + 40
	var w := box.size.x - 80
	var y := box.position.y + 122
	ui.text("CALIDAD", Vector2(x, y), 13, "muted", true)
	y = choice(x, y + 24, w, Graphics.LEVELS, s.quality, func(i): s.quality = i)
	ui.text("PERSONALIZADO  (al cambiar algo pasa a Personalizado)", Vector2(x, y + 10), 13, "muted", true)
	y += 40
	ui.text("Sombras", Vector2(x, y + 3), 16, "text")
	y = choice(x + 260, y - 6, w - 260, Graphics.SHADOWS, s.g_shadows, func(i): set_custom("g_shadows", i))
	ui.text("Bordes suaves (MSAA)", Vector2(x, y + 3), 16, "text")
	y = choice(x + 260, y - 6, w - 260, Graphics.AA, s.g_aa, func(i): set_custom("g_aa", i))
	y = toggle(x, y + 4, w, "Oclusión ambiental (rincones y bases oscurecidas, cuesta bastante)", "g_ao",
			func(): set_custom("g_ao", not s.g_ao))
	y = toggle(x, y, w, "Resplandor alrededor de luces y del sol", "g_glow",
			func(): set_custom("g_glow", not s.g_glow))
	y = toggle(x, y, w, "Destello del sol en la cámara", "g_flare",
			func(): set_custom("g_flare", not s.g_flare))
	ui.wrap_text("Lo que más cuesta en tarjetas sencillas son los bordes suaves y la oclusión ambiental; las sombras " +
			"altas dibujan más lejos y más nítido. Si el juego va lento, prueba Medio.", Rect2(x, y + 8, w, 60), 14, "muted")
	if ui.button(Rect2(box.get_center().x - 140, box.end.y - 70, 280, 46), "Volver (Esc)", true, "primary", 17):
		pause_page = "main"


func set_custom(key: String, value) -> void:
	city.settings[key] = value
	city.settings.quality = Graphics.CUSTOM


## Fila de botones donde uno queda elegido. Devuelve la altura siguiente.
func choice(x: float, y: float, w: float, labels: Array, current: int, pick: Callable) -> float:
	var bw := (w - 10.0 * (labels.size() - 1)) / labels.size()
	for i in labels.size():
		if ui.button(Rect2(x + i * (bw + 10), y, bw, 40), labels[i], true, "normal", 15, null, current == i) and current != i:
			pick.call(i)
			city.apply_settings()
	return y + 54


func slider(x: float, y: float, w: float, label: String, key: String, lo: float, hi: float, fmt: Callable) -> float:
	var s: Dictionary = city.settings
	ui.text(label, Vector2(x, y), 16, "text")
	ui.text(fmt.call(s[key]), Vector2(x + w, y), 16, "accent", true, "topright")
	var bar := Rect2(x, y + 32, w, 8)
	if ui.hover(bar.grow_individual(8, 13, 8, 13)) and (ui.clicked or ui.down):
		s[key] = lo + clampf((ui.mouse.x - x) / w, 0, 1) * (hi - lo)
		city.apply_settings()
	var frac: float = (s[key] - lo) / (hi - lo)
	ui.rect(bar, "panel2", 4)
	ui.rect(Rect2(x, bar.position.y, max(8.0, w * frac), 8), "accent", 4)
	ui.circle(Vector2(x + w * frac, bar.get_center().y), 10, "text")
	ui.circle(Vector2(x + w * frac, bar.get_center().y), 6, "accent")
	return y + 58


func toggle(x: float, y: float, w: float, label: String, key: String, action = null) -> float:
	var s: Dictionary = city.settings
	ui.text(label, Vector2(x, y + 3), 16, "text")
	var r := Rect2(x + w - 54, y, 54, 28)
	var on: bool = s[key]
	ui.rect(r, "green" if on else "border", 14)
	ui.circle(Vector2(r.end.x - 14 if on else r.position.x + 14, r.get_center().y), 11, Color.WHITE)
	if ui.hover(Rect2(x, y - 4, w, 36)) and ui.clicked:
		if action != null:
			action.call()
		else:
			s[key] = not on
		city.apply_settings()
	return y + 40


# ---------- armario ----------
## Panel a la izquierda con pestañas y una foto de cada prenda; el personaje queda a la derecha y se gira,
## se acerca o se aleja con el mouse.
func draw_custom() -> void:
	var g: Game = app.game
	var look: Dictionary = g.look
	var box := Rect2(30, 26, 600, H - 52)
	glass_box(box)
	ui.text("Armario", box.position + Vector2(32, 22), 32, "accent", true)
	ui.text("Caja: %s" % Fmt.money(g.cash), Vector2(box.end.x - 32, box.position.y + 30), 18, Admin.sc(g.cash), true, "topright")
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


func pick(key: String, value) -> void:
	var g: Game = app.game
	if not Wardrobe.owns(g, key, value):
		var res := g.buy_item(Wardrobe.item_id(key, value), Wardrobe.item_price(key, value))
		if not res[0]:
			city.toast(res[1], "bad")
			city.sfx.play("angry", 0.5)
			return
		city.sfx.play("coin", 0.7)
		city.toast("Compra hecha: %s." % Fmt.money(g.item_price(Wardrobe.item_price(key, value))), "good")
	g.look[key] = value
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
		if hot and ui.clicked:
			pick(key, rgb)
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
		var side: float = min(w - 12, h - 44)
		var ir := Rect2(r.get_center().x - side / 2, r.position.y + 6, side, side)
		if img != null:
			ui.image(img, ir)
		else:
			ui.rect(ir, Color8(28, 33, 43), 8)
			ui.text("…", ir.get_center(), 22, "muted", false, "center")
		if worn:
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
				pick(field, val)
	var rows := (options.size() + cols - 1) / cols
	return y + 26 + rows * (h + gap) + 8


# ---------- vitrina de trofeos ----------
## Cada título es un trofeo; los que faltan se ven como siluetas.
func draw_trophies() -> void:
	var g: Game = app.game
	var ranks: Array = g.ranks().slice(1)
	var rows := (ranks.size() + 4) / 5
	var bh := 170.0 + rows * 250
	var box := Rect2(W / 2 - 560, H / 2 - bh / 2, 1120, bh)
	glass_box(box)
	var got: int = g.rank
	ui.text("Vitrina de trofeos", box.position + Vector2(40, 26), 32, "accent", true)
	ui.text("%d de %d títulos · %s" % [got, ranks.size(), D.MODES[g.mode].name], box.position + Vector2(42, 72), 15, "muted")
	var info := g.rank_info()
	if info[2] != null:
		ui.text("Siguiente: %s — te faltan %s" % [info[2][1], Fmt.money(max(0.0, info[2][0] - info[3]))],
				Vector2(box.end.x - 40, box.position.y + 34), 16, "text", false, "topright")
		var lo: float = g.ranks()[got][0]
		ui.bar(Rect2(box.end.x - 340, box.position.y + 62, 300, 8), (info[3] - lo) / (info[2][0] - lo), "accent")
	else:
		ui.text("¡Los tienes todos!", Vector2(box.end.x - 40, box.position.y + 34), 18, "green", true, "topright")
	for i in ranks.size():
		var r := Rect2(box.position.x + 40 + (i % 5) * 210, box.position.y + 110 + (i / 5) * 250, 196, 236)
		var earned := i < got
		var tier: Array = TIERS[min(i, TIERS.size() - 1)]
		ui.rect(r, "panel2", 14)
		if earned:
			ui.rect(r, tier[1], 14, 2)
		draw_cup(Vector2(r.get_center().x, r.position.y + 78), tier[1] if earned else Color8(58, 62, 72), earned)
		var title: String = ranks[i][1]
		ui.text(title, Vector2(r.get_center().x, r.position.y + 150), 16, "text" if earned else "muted", true, "midtop", r.size.x - 16)
		ui.text("%s · %s" % [tier[0], Fmt.short(ranks[i][0])], Vector2(r.get_center().x, r.position.y + 174), 13,
				tier[1] if earned else "muted", false, "midtop")
		if earned:
			var logged = g.rank_log.get(title)
			var when := "Conseguido"
			if logged != null:
				var day := int(logged[0])
				when = "%d de %s, año %d" % [day % 30 + 1, D.MONTHS[(day / 30) % 12], day / 360 + 1]
			ui.text(when, Vector2(r.get_center().x, r.position.y + 196), 12, "muted", false, "midtop")
			if logged != null:
				ui.text("a los %d min de juego" % roundi(logged[1] / 60.0), Vector2(r.get_center().x, r.position.y + 212), 12, "muted", false, "midtop")
		else:
			ui.text("Bloqueado", Vector2(r.get_center().x, r.position.y + 200), 13, "muted", false, "midtop")
	if ui.button(Rect2(box.get_center().x - 130, box.end.y - 58, 260, 42), "Cerrar (E)", true, "normal", 16):
		hide()


## Una copa dibujada con figuras: asas, copa, tallo y base. Brilla si está ganada.
func draw_cup(c: Vector2, rgb: Color, earned: bool) -> void:
	var dark := rgb * 0.65
	dark.a = 1
	for sx in [-1, 1]:
		ui.ring(c + Vector2(sx * 34, -14), 12, dark, 6)
	ui.polygon(PackedVector2Array([c + Vector2(-36, -40), c + Vector2(36, -40), c + Vector2(22, 8), c + Vector2(-22, 8)]), rgb)
	ui.circle(c + Vector2(0, 7), 22, rgb)
	ui.rect(Rect2(c.x - 6, c.y + 14, 12, 22), dark)
	ui.rect(Rect2(c.x - 22, c.y + 34, 44, 10), rgb, 3)
	ui.rect(Rect2(c.x - 30, c.y + 44, 60, 12), dark, 3)
	if earned:
		ui.line(c + Vector2(-22, -32), c + Vector2(-12, 2), Color.WHITE, 4)
		ui.circle(c + Vector2(14, -24), 4, Color.WHITE)
	else:
		ui.text("?", c + Vector2(0, -16), 30, Color8(110, 116, 130), true, "center")


# ---------- reunión de estrategia ----------
## Una decisión al mes. Cada opción es un concepto distinto (demanda, calidad, costos).
func draw_strategy() -> void:
	var g: Game = app.game
	var box := Rect2(W / 2 - 500, H / 2 - 250, 1000, 500)
	glass_box(box)
	ui.text("Reunión de estrategia", box.position + Vector2(40, 28), 32, "accent", true)
	var wait := g.strategy_wait()
	ui.text("Elige una estrategia para este mes." if not wait else "Ya hubo reunión este mes: la próxima es en %d días." % wait,
			box.position + Vector2(42, 74), 15, "muted" if not wait else "orange")
	ui.text("Caja: %s" % Fmt.money(g.cash), Vector2(box.end.x - 40, box.position.y + 36), 18, Admin.sc(g.cash), true, "topright")
	for i in D.STRATEGIES.size():
		var st: Array = D.STRATEGIES[i]
		var r := Rect2(box.position.x + 40 + i * 315, box.position.y + 116, 295, 290)
		ui.rect(r, "panel2", 12)
		ui.text(st[1], r.position + Vector2(18, 18), 19, "text", true)
		ui.wrap_text(st[3], Rect2(r.position.x + 18, r.position.y + 56, r.size.x - 36, 120), 15, "muted")
		var cost := g.strategy_cost(st[0])
		ui.text("Costo: %s" % Fmt.money(cost), Vector2(r.position.x + 18, r.end.y - 96), 16, "accent", true)
		if ui.button(Rect2(r.position.x + 18, r.end.y - 62, r.size.x - 36, 44), "Elegir", not wait and g.cash >= cost, "primary", 16):
			var res := g.run_strategy(st[0])
			city.hud.notes.push_side("Reunión de estrategia", "Pizarra de la oficina", res[1],
					Color8(46, 170, 90) if res[0] else Color8(225, 85, 75), "✓" if res[0] else "!", "",
					"good" if res[0] else "angry")
			hide()
			return
	if ui.button(Rect2(box.get_center().x - 130, box.end.y - 70, 260, 44), "Cerrar (E)", true, "normal", 16):
		hide()
