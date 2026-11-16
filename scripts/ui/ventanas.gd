class_name Ventanas
extends RefCounted
## «Ventanas 11 · Edición Millonario»: el sistema (de broma) de la computadora de tu escritorio de CEO, en la
## presidencia (Tower), hecho a la manera de los sistemas de hoy: pantalla de inicio con puntitos que giran, pantalla de
## bloqueo con la hora grande, escritorio, barra de tareas centrada (Inicio, buscador, apps ancladas, y a los lados el
## clima, la bandeja y la hora), menú Inicio flotante con «Anclados» y «Recomendado», ventanas redondeadas con
## minimizar, maximizar y cerrar, un explorador de archivos y un navegador con pestañas. Te sientas, la cámara entra a
## la pantalla (City.sit_at_computer) y aparece esto. El programa importante es Remodelar.exe (decorar cada puesto,
## local o megatienda); el resto son chistes. Se dibuja en el overlay "pc" (Overlays._draw_mode).

const NAME := "Ventanas 11"
const EDITION := "Edición Millonario"
const BOOT := 2.8              # segundos de la pantalla de inicio
const LOCK := 2.2              # segundos de la pantalla de bloqueo (o un clic)
const BAR := 48.0              # alto de la barra de tareas
const GRAY := Color8(243, 243, 243)    # fondo de ventanas
const SHADE := Color8(96, 96, 102)     # texto secundario
const LIGHT := Color8(255, 255, 255)
const NAVY := Color8(0, 95, 184)       # el color de acento (selección, botones principales)
const BLUE := Color8(76, 160, 236)
const LINE := Color(0, 0, 0, 0.09)     # bordes finos
const INK := Color8(26, 26, 28)
const ICONS := [["remodelar", "Remodelar.exe"], ["empresa", "Mi Empresa"], ["oficina", "Personalizar oficina"],
		["docs", "Explorador de archivos"], ["web", "Navegador"], ["papelera", "Papelera de reciclaje"]]
const PINNED := ["docs", "web", "remodelar", "empresa"]   # anclados en la barra de tareas
const MORE_APPS := [["config", "Configuración"], ["calc", "Calculadora"], ["fotos", "Fotos"], ["tienda", "Tienda"],
		["correo", "Correo"], ["reloj", "Reloj"]]           # en el menú Inicio, de adorno (abren un chiste)
const RECENT := [["plan_de_expansion_2027.docx", "Hace 12 min"], ["sueldos_ejecutivos.xlsx", "Hace 1 h"],
		["presentacion_inversionistas.pptx", "Ayer a las 18:40"], ["logo_nuevo_FINAL_v7.png", "Hace 3 días"]]
const TRASH := ["plan_vender_hielo_en_el_polo.doc", "cafe_sin_cafe (idea).txt", "NFT_de_panes.ppt",
		"abrir_10_megatiendas_el_dia_1.xls", "contratar_a_mi_primo.doc", "precio_de_todo_a_1_peso.xls"]
const WEEKDAYS := ["lunes", "martes", "miércoles", "jueves", "viernes", "sábado", "domingo"]

var city
var t := 0.0                   # segundos desde que se prendió
var chimed := false
var unlocked := false
var wins: Array = []           # ventanas abiertas (la última va arriba): {id, title, r, min, max, prev}
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
var ui_ref: ImUI
var vis := Rect2(0, 0, 1280, 760)   # la pantalla del monitor (casi toda tu pantalla, con el borde del monitor alrededor)
const FILL := 0.88             # cuánto de tu pantalla ocupa la del monitor (alto o ancho)


func _init(owner_city) -> void:
	city = owner_city


## Se prende (cada vez que te sientas).
func start() -> void:
	t = 0.0
	chimed = false
	unlocked = false
	wins = []
	start_open = false
	drag = null
	msg = null
	leaving = -1.0


func booted() -> bool:
	return t >= BOOT


func locked() -> bool:
	return booted() and not unlocked and t < BOOT + LOCK


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
			leaving = -1.0
			city.leave_computer()
	if booted() and not chimed:
		chimed = true
		city.sfx.play("record", 0.6, 0.9)   # el sonido de inicio
	# La actualización obligatoria de siempre (una vez cada vez que te sientas)
	if booted() and not nag_done and t > BOOT + LOCK + 35.0 and msg == null:
		nag_done = true
		_message("Ventanas Update", "Hay 1 actualización obligatoria (4,7 TB). Tu computadora se reiniciará en 10 minutos.", true)


# ---------- la hora y la fecha del juego ----------
func _clock() -> String:
	var hour: float = SkyLight.hour_of(city.day_fraction())
	return "%02d:%02d" % [int(hour), int(fmod(hour, 1.0) * 60)]


func _date_short() -> String:
	var g = city.game
	if g == null:
		return ""
	var dp: Array = g.date_parts()
	return "%02d/%02d/%d" % [dp[0], D.MONTHS.find(dp[1]) + 1, 2025 + int(dp[2])]


func _date_long() -> String:
	var g = city.game
	if g == null:
		return ""
	var dp: Array = g.date_parts()
	return Lang.f("%s, %d de %s", [Lang.t(WEEKDAYS[int(g.day) % 7]), dp[0], Lang.t(dp[1]).to_lower()])


# ---------- dibujo ----------
func draw(ui: ImUI) -> void:
	# Justo encima de la pantalla del monitor, del mismo tamaño (alrededor se ve el monitor de verdad y tu oficina)
	var sr: Rect2 = city.pc_screen_rect()
	var tl: Vector2 = ui.to_virtual(sr.position)
	vis = Rect2(tl, ui.to_virtual(sr.end) - tl)
	ui_ref = ui
	ui.set_clip(vis)
	ui.rect(vis, Color8(0, 0, 0))
	if not booted():
		_draw_boot(ui)
		prev_down = ui.down
		ui.set_clip(null)
		return
	if locked():
		_draw_lock(ui)
		if ui.clicked and vis.has_point(ui.mouse):
			unlocked = true
			city.sfx.play("select", 0.4)
		prev_down = ui.down
		ui.set_clip(null)
		return
	if leaving >= 0:
		_wallpaper(ui)
		ui.rect(vis, Color(0, 0, 0, 0.55))
		_spinner(ui, vis.get_center() - Vector2(0, 20), 14.0)
		ui.text("Cerrando sesión...", vis.get_center() + Vector2(0, 24), 20, LIGHT, false, "center")
		prev_down = ui.down
		ui.set_clip(null)
		return
	var click := ui.clicked and vis.has_point(ui.mouse)
	var press: bool = ui.down and not prev_down and vis.has_point(ui.mouse)
	_wallpaper(ui)
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
	ui.set_clip(null)


## Recorta dentro de la pantalla del monitor (set_clip no se anida).
func _clip(r) -> void:
	ui_ref.set_clip(vis if r == null else (r as Rect2).intersection(vis))


## Fondo de pantalla: tu foto (WALL_IMAGE) o, si no hay, azul profundo con una flor de luz al medio (pétalos que se abren desde el centro, en capas).
func _wallpaper(ui: ImUI) -> void:
	var tex = _image(WALL_IMAGE)
	if tex != null:   # tu foto
		_cover(ui, tex)
		return
	ui.gradient(vis, Color8(8, 26, 74), Color8(56, 120, 210), false)
	var c := vis.get_center() + Vector2(0, vis.size.y * 0.05)
	var s := minf(vis.size.x, vis.size.y)
	for i in 8:   # halo suave
		ui.circle(c, s * (0.62 - i * 0.06), Color(0.5, 0.72, 1.0, 0.035))
	for k in 3:   # tres capas de pétalos curvos, cada una girada y más chica
		var n := 6
		for i in n:
			var a := TAU * (i + 0.5 * (k % 2)) / n - PI / 2 + k * 0.08
			var len := s * (0.36 - k * 0.08)
			var wdt := s * (0.11 - k * 0.025)
			var dir := Vector2(cos(a), sin(a))
			var side := Vector2(-dir.y, dir.x)
			var pts := PackedVector2Array()
			for j in 13:   # borde curvo: ida por un lado, vuelta por el otro
				var u := j / 12.0
				pts.append(c + dir * len * u + side * wdt * sin(u * PI) * (1.0 - u * 0.25))
			for j in range(11, 0, -1):
				var u := j / 12.0
				pts.append(c + dir * len * u - side * wdt * sin(u * PI) * (1.0 - u * 0.25) * 0.55)
			ui.polygon(pts, Color(0.55 + k * 0.12, 0.76 + k * 0.07, 1.0, 0.2 + k * 0.1))
	ui.circle(c, s * 0.025, Color(0.88, 0.95, 1.0, 0.75))


## Los puntitos que giran (cargando).
func _spinner(ui: ImUI, c: Vector2, r: float) -> void:
	for i in 5:
		var a := t * 5.0 - i * 0.45
		ui.circle(c + Vector2(cos(a), sin(a)) * r, 2.6 - i * 0.3, Color(1, 1, 1, 1.0 - i * 0.16))


const BOOT_IMAGE := "res://assets/imagenes/pc/arranque.jpg"   # opcional: tu imagen para la pantalla de carga
const WALL_IMAGE := "res://assets/imagenes/pc/fondo.jpg"       # opcional: tu fondo de pantalla (escritorio y bloqueo)
var images := {}   # ruta -> textura, o false si no está (se busca una sola vez)


## Una imagen tuya de assets/imagenes/pc (null si no está).
func _image(path: String):
	if not images.has(path):
		images[path] = false
		if ResourceLoader.exists(path):
			images[path] = load(path)
		elif FileAccess.file_exists(path):
			var img := Image.load_from_file(ProjectSettings.globalize_path(path))
			if img != null and not img.is_empty():
				images[path] = ImageTexture.create_from_image(img)
	return images[path] if images[path] is Texture2D else null


## Dibuja `tex` llenando la pantalla del monitor sin deformarla (recorta lo que sobra).
func _cover(ui: ImUI, tex: Texture2D, alpha := 1.0) -> void:
	var k := maxf(vis.size.x / tex.get_width(), vis.size.y / tex.get_height())
	var sz := Vector2(tex.get_width(), tex.get_height()) * k
	ui.image(tex, Rect2(vis.get_center() - sz / 2, sz), Color(1, 1, 1, alpha))


## Pantalla de inicio: tu imagen (si pusiste una en BOOT_IMAGE) o el logo al medio, y los puntitos que giran abajo.
func _draw_boot(ui: ImUI) -> void:
	var c := vis.get_center() - Vector2(0, 30)
	var a := clampf(t / 0.5, 0, 1)
	var tex = _image(BOOT_IMAGE)
	if tex != null:
		_cover(ui, tex, a)
		if t > 0.6:   # sobre un círculo oscuro, para que se vea encima de cualquier foto
			var sc := Vector2(vis.get_center().x, vis.end.y - vis.size.y * 0.2)
			ui.circle(sc, 26, Color(0, 0, 0, 0.45))
			_spinner(ui, sc, 14.0)
		return
	logo(ui, Rect2(c.x - 46, c.y - 46, 92, 92), a)
	if t > 0.6:
		_spinner(ui, Vector2(c.x, c.y + 120), 14.0)


## Pantalla de bloqueo: el fondo oscurecido, la hora grande y la fecha; un clic (o un ratito) y entras.
func _draw_lock(ui: ImUI) -> void:
	_wallpaper(ui)
	ui.rect(vis, Color(0, 0, 0, 0.25))
	var k := clampf((t - BOOT) / 0.4, 0, 1)
	var cx := vis.get_center().x
	var y := vis.position.y + vis.size.y * 0.2 + (1.0 - k) * 20
	ui.text(_clock(), Vector2(cx, y), 84, Color(1, 1, 1, k), true, "center")
	ui.text(_date_long(), Vector2(cx, y + 64), 20, Color(1, 1, 1, k * 0.95), false, "center")
	var g = city.game
	var name: String = str(g.company) if g != null else "CEO"
	ui.circle(Vector2(cx, vis.end.y - 120), 26, Color(1, 1, 1, 0.25 * k))
	ui.text(name.substr(0, 1).to_upper(), Vector2(cx, vis.end.y - 120), 22, Color(1, 1, 1, k), true, "center")
	ui.text(name, Vector2(cx, vis.end.y - 80), 15, Color(1, 1, 1, k), true, "center")
	ui.text("Haz clic para entrar", Vector2(cx, vis.end.y - 54), 12, Color(1, 1, 1, 0.7 * k), false, "center")


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
			ui.rect(cell, Color(cols[(row * 2 + col) % 4], alpha), 3)


## El botón de Inicio: un cuadrado azul redondeado con el rascacielos blanco adentro.
static func start_glyph(ui: ImUI, r: Rect2) -> void:
	ui.gradient(r, Color8(0, 120, 215), Color8(0, 84, 166), false)
	ui.rect(r, Color(0, 0, 0, 0), 4)
	var u := r.size.x / 22.0
	ui.rect(Rect2(r.position + Vector2(6, 8) * u, Vector2(5, 10) * u), LIGHT, 1)
	ui.rect(Rect2(r.position + Vector2(11, 4) * u, Vector2(5, 14) * u), LIGHT, 1)
	for k in 3:
		ui.rect(Rect2(r.position + Vector2(12.5, 6 + k * 3.5) * u, Vector2(2, 1.5) * u), Color8(0, 100, 190))


# ---------- piezas modernas ----------
## Panel plano con esquinas redondeadas y un borde finito (`sunken`: un campo blanco, como una lista o un buscador).
static func bevel(ui: ImUI, r: Rect2, sunken := false, fill = null) -> void:
	var f = fill if fill != null else (LIGHT if sunken else GRAY)
	ui.rect(r, f, 6)
	ui.rect(r, LINE if not sunken else Color(0, 0, 0, 0.14), 6, 1)


## Botón redondeado. Devuelve true con el clic.
static func btn(ui: ImUI, r: Rect2, label: String, enabled := true, size := 14) -> bool:
	var hot := enabled and ui.hover(r)
	var pressed: bool = hot and ui.down
	ui.rect(r, Color8(234, 234, 236) if pressed else (Color8(246, 246, 248) if hot else Color8(253, 253, 253)), 5)
	ui.rect(r, Color(0, 0, 0, 0.13), 5, 1)
	ui.rect(Rect2(r.position.x + 3, r.end.y - 1, r.size.x - 6, 1), Color(0, 0, 0, 0.1))
	ui.text(label, r.get_center(), size, INK if enabled else Color(0, 0, 0, 0.35), false, "center", r.size.x - 8)
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
		"config":
			_message("Configuración", "Para cambiar esta configuración necesitas permisos de administrador. Eres el CEO, pero igual no.")
			return
		"calc":
			_message("Calculadora", "Resultado: mucha plata. Para más detalle, abre Mi Empresa.")
			return
		"fotos":
			_message("Fotos", "No hay fotos: estuviste trabajando todo el año.")
			return
		"tienda":
			_message("Tienda", "Todo está agotado. Bueno, todo menos tus productos, ojalá.")
			return
		"correo":
			_message("Correo", "Tienes 4.812 correos sin leer. Mejor no.", true)
			return
		"reloj":
			_message("Reloj", Lang.f("Son las %s. Hora de vender.", _clock()))
			return
	for w in wins:
		if w.id == id:   # ya estaba abierta: al frente
			w.min = false
			wins.erase(w)
			wins.append(w)
			return
	var sizes := {"remodelar": Vector2(860, 540), "docs": Vector2(700, 420), "web": Vector2(720, 440), "papelera": Vector2(640, 400)}
	var titles := {"remodelar": "Remodelar.exe", "docs": "Documentos", "web": "Navegador", "papelera": "Papelera de reciclaje"}
	var sz: Vector2 = sizes[id]
	var n := wins.size()
	sz = sz.min(vis.size - Vector2(40, BAR + 30))
	var r := Rect2(vis.position + Vector2((vis.size.x - sz.x) / 2 + n * 24, max(12.0, (vis.size.y - BAR - sz.y) / 2 + n * 24)), sz)
	wins.append({"id": id, "title": titles[id], "r": r, "min": false, "max": false, "prev": r})


func _close(w: Dictionary) -> void:
	wins.erase(w)
	if drag != null and drag.w == w:
		drag = null


func _message(title: String, text: String, warn := false) -> void:
	msg = {"title": title, "text": text, "warn": warn}
	city.sfx.play("bad" if warn else "select", 0.5, 1.3)


func _draw_icons(ui: ImUI, press: bool) -> void:
	for i in ICONS.size():
		var id: String = ICONS[i][0]
		var r := Rect2(vis.position.x + 10, vis.position.y + 10 + i * 92, 84, 86)
		var ir := Rect2(r.get_center().x - 20, r.position.y + 6, 40, 40)
		var sel := sel_icon == id
		if sel or ui.hover(r):
			ui.rect(r, Color(1, 1, 1, 0.24 if sel else 0.12), 4)
			if sel:
				ui.rect(r, Color(1, 1, 1, 0.3), 4, 1)
		draw_icon(ui, id, ir)
		var label: String = Lang.t(ICONS[i][1])
		var lr := Rect2(r.position.x, r.position.y + 52, r.size.x, 30)
		ui.text(label, lr.position + Vector2(r.size.x / 2 + 1, 1), 12, Color(0, 0, 0, 0.6), false, "midtop", r.size.x - 4)
		ui.text(label, lr.position + Vector2(r.size.x / 2, 0), 12, LIGHT, false, "midtop", r.size.x - 4)
		if press and r.has_point(ui.mouse):
			var now := Time.get_ticks_msec()
			if last_click[0] == id and now - int(last_click[1]) < 450:   # doble clic: se abre
				_open(id)
				last_click = ["", 0]
			else:
				last_click = [id, now]
			sel_icon = id
	if press and not Rect2(vis.position + Vector2(10, 10), Vector2(84, ICONS.size() * 92)).has_point(ui.mouse):
		sel_icon = ""


func _draw_window(ui: ImUI, w: Dictionary, active: bool, press: bool) -> void:
	var r: Rect2 = w.r
	var rad := 0.0 if w.max else 8.0
	if not w.max:
		ui.rect(r.grow(8), Color(0, 0, 0, 0.06), 16)   # sombra suave
		ui.rect(r.grow(3), Color(0, 0, 0, 0.1), 11)
	ui.rect(r, GRAY if active else Color8(236, 236, 238), rad)
	ui.rect(r, Color(0, 0, 0, 0.2) if active else LINE, rad, 1)
	var tb := Rect2(r.position.x, r.position.y, r.size.x, 32)
	draw_icon(ui, w.id, Rect2(tb.position.x + 12, tb.position.y + 8, 16, 16))
	ui.text(Lang.t(w.title), Vector2(tb.position.x + 38, tb.get_center().y), 12, INK if active else SHADE, false, "midleft", tb.size.x - 180)
	# Minimizar, maximizar y cerrar (46 de ancho cada uno, la X roja al pasar el mouse)
	var xr := Rect2(tb.end.x - 46, tb.position.y, 46, 32)
	var xr2 := Rect2(xr.position.x - 46, xr.position.y, 46, 32)
	var mr := Rect2(xr2.position.x - 46, xr.position.y, 46, 32)
	var hx := ui.hover(xr)
	if hx:
		ui.rect(xr, Color8(196, 43, 28), rad)
		ui.rect(Rect2(xr.position.x, xr.position.y + 8, 30, 24), Color8(196, 43, 28))
		ui.rect(Rect2(xr.position.x, xr.end.y - 8, 46, 8), Color8(196, 43, 28))
	var xc := xr.get_center()
	var xcol := LIGHT if hx else INK
	ui.line(xc + Vector2(-5, -5), xc + Vector2(5, 5), xcol, 1.2)
	ui.line(xc + Vector2(-5, 5), xc + Vector2(5, -5), xcol, 1.2)
	for b in [xr2, mr]:
		if ui.hover(b):
			ui.rect(b, Color(0, 0, 0, 0.06))
	var c2 := xr2.get_center()
	if w.max:   # restaurar: dos cuadritos
		ui.rect(Rect2(c2 + Vector2(-3, -6), Vector2(8, 8)), INK, 1.5, 1)
		ui.rect(Rect2(c2 + Vector2(-6, -3), Vector2(8, 8)), GRAY, 1.5)
		ui.rect(Rect2(c2 + Vector2(-6, -3), Vector2(8, 8)), INK, 1.5, 1)
	else:
		ui.rect(Rect2(c2 - Vector2(5, 5), Vector2(10, 10)), INK, 1.5, 1)
	ui.rect(Rect2(mr.get_center().x - 5, mr.get_center().y, 10, 1), INK)
	if hx and ui.clicked:
		_close(w)
		city.sfx.play("select", 0.3)
		return
	if ui.hover(mr) and ui.clicked:
		w.min = true
		return
	if ui.hover(xr2) and ui.clicked:
		w.max = not w.max
		if w.max:
			w.prev = w.r
			w.r = Rect2(vis.position, Vector2(vis.size.x, vis.size.y - BAR))
		else:
			w.r = w.prev
		return
	if press:
		wins.erase(w)   # al frente
		wins.append(w)
		if tb.has_point(ui.mouse) and not xr.has_point(ui.mouse) and not xr2.has_point(ui.mouse) and not mr.has_point(ui.mouse) and not w.max:
			drag = {"w": w, "off": ui.mouse - r.position}
	var body := Rect2(r.position.x + 12, tb.end.y + 4, r.size.x - 24, r.end.y - tb.end.y - 16)
	match w.id:
		"remodelar":
			_app_remodel(ui, body)
		"docs":
			_app_docs(ui, Rect2(r.position.x + 1, tb.end.y, r.size.x - 2, r.end.y - tb.end.y - 1))
		"web":
			_app_web(ui, Rect2(r.position.x + 1, tb.position.y + 1, r.size.x - 2, r.size.y - 2))
		"papelera":
			_app_trash(ui, Rect2(r.position.x + 1, tb.end.y, r.size.x - 2, r.end.y - tb.end.y - 1))


## El menú Inicio: flotante y centrado encima de la barra.
func _start_rect(ui: ImUI) -> Rect2:
	var sz := Vector2(minf(600.0, vis.size.x - 40), minf(560.0, vis.size.y - BAR - 24))
	return Rect2(vis.get_center().x - sz.x / 2, vis.end.y - BAR - 12 - sz.y, sz.x, sz.y)


## Un icono de la barra de tareas (cuadrado redondeado que se aclara al pasar el mouse). Devuelve true con el clic.
func _bar_button(ui: ImUI, r: Rect2, on := false) -> bool:
	var hot := ui.hover(r)
	if hot or on:
		ui.rect(r, Color(1, 1, 1, 0.8 if on else 0.55), 5)
		ui.rect(r, LINE, 5, 1)
	return hot and ui.clicked


func _draw_taskbar(ui: ImUI) -> void:
	var H := vis.end.y
	var bar := Rect2(vis.position.x, H - BAR, vis.size.x, BAR)
	ui.rect(bar, Color(0.93, 0.94, 0.965, 0.94))
	ui.rect(Rect2(bar.position, Vector2(bar.size.x, 1)), Color(0, 0, 0, 0.08))
	var cy := bar.get_center().y
	# Izquierda: el clima (y tu plata, que para eso es la compu del CEO)
	var w = city.weather
	var hour: float = SkyLight.hour_of(city.day_fraction())
	var wr := Rect2(bar.position.x + 8, bar.position.y + 4, 150, 40)
	_bar_button(ui, wr)
	var sun := Vector2(wr.position.x + 20, cy)
	ui.circle(sun, 9, Color8(255, 196, 40))
	ui.circle(sun + Vector2(6, 5), 7, Color(1, 1, 1, 0.95))
	ui.circle(sun + Vector2(11, 5), 5, Color(1, 1, 1, 0.95))
	ui.text("%d °C" % w.temperature(hour), Vector2(wr.position.x + 40, cy - 7), 12, INK, false, "midleft")
	ui.text(Lang.t(w.name_of(w.today)), Vector2(wr.position.x + 40, cy + 8), 11, SHADE, false, "midleft", 105)
	var g = city.game
	if g != null:
		ui.text(Fmt.money(g.cash), Vector2(wr.end.x + 10, cy), 12, Color8(16, 124, 16) if g.cash >= 0 else Color8(196, 43, 28), true, "midleft")
	# Al medio: Inicio, el buscador, las apps ancladas y las ventanas abiertas (con la rayita si están abiertas)
	var extra := []
	for wn in wins:
		if not wn.id in PINNED:
			extra.append(wn.id)
	var ids: Array = PINNED + extra
	var search_w := 150.0
	var total := 44.0 + 6 + search_w + 6 + ids.size() * 44.0
	var x := vis.get_center().x - total / 2
	var sr := Rect2(x, bar.position.y + 4, 40, 40)
	if _bar_button(ui, sr, start_open):
		start_open = not start_open
		city.sfx.play("select", 0.3)
	start_glyph(ui, Rect2(sr.get_center().x - 11, sr.get_center().y - 11, 22, 22))
	x += 46
	var sb := Rect2(x, bar.position.y + 8, search_w, 32)
	ui.rect(sb, LIGHT if ui.hover(sb) else Color8(248, 248, 250), 16)
	ui.rect(sb, Color(0, 0, 0, 0.1), 16, 1)
	ui.ring(sb.position + Vector2(18, 15), 5, INK, 1.4)
	ui.line(sb.position + Vector2(22, 19), sb.position + Vector2(26, 23), INK, 1.4)
	ui.text("Buscar", sb.position + Vector2(34, 16), 12, SHADE, false, "midleft")
	if ui.hover(sb) and ui.clicked:
		start_open = true
	x += search_w + 6
	for id in ids:
		var r := Rect2(x + 2, bar.position.y + 4, 40, 40)
		var win = null
		for wn in wins:
			if wn.id == id:
				win = wn
		var on: bool = win != null and not win.min and win == wins[-1]
		if _bar_button(ui, r, on):
			if win == null:
				_open(id)
			elif win.min:
				win.min = false
				wins.erase(win)
				wins.append(win)
			elif on:
				win.min = true
			else:
				wins.erase(win)
				wins.append(win)
		draw_icon(ui, id, Rect2(r.get_center().x - 12, r.get_center().y - 13, 24, 24))
		if win != null:
			ui.rect(Rect2(r.get_center().x - (8 if on else 3), r.end.y - 3, 16 if on else 6, 3), NAVY if on else SHADE, 1.5)
		x += 44
	# Derecha: la bandeja (flechita, wifi, volumen, batería), la hora y la fecha, y la campanita
	var tx := vis.end.x - 10
	var dr := Rect2(tx - 108, bar.position.y + 4, 84, 40)
	_bar_button(ui, dr)
	ui.text(_clock(), Vector2(dr.end.x - 8, cy - 8), 12, INK, false, "midright")
	ui.text(_date_short(), Vector2(dr.end.x - 8, cy + 8), 12, INK, false, "midright")
	var bell := Vector2(tx - 12, cy)
	ui.circle(bell + Vector2(0, -1), 5, Color(0, 0, 0, 0))
	ui.ring(bell + Vector2(0, -1), 5, INK, 1.2)
	ui.rect(Rect2(bell.x - 6, bell.y + 3, 12, 1.2), INK)
	var tray := Rect2(dr.position.x - 92, bar.position.y + 4, 88, 40)
	_bar_button(ui, tray)
	var p := Vector2(tray.position.x + 16, cy)
	ui.line(p + Vector2(-4, 2), p + Vector2(0, -2), INK, 1.3)    # la flechita para arriba
	ui.line(p + Vector2(0, -2), p + Vector2(4, 2), INK, 1.3)
	p.x += 22   # wifi: arcos
	for k in 3:
		var rr := 3.0 + k * 3.5
		var pts := PackedVector2Array()
		for j in 9:
			var a := -PI * 0.75 + j / 8.0 * PI * 0.5
			pts.append(p + Vector2(cos(a), sin(a)) * rr + Vector2(0, 5))
		ui.polyline(pts, INK, 1.3)
	ui.circle(p + Vector2(0, 5), 1.4, INK)
	p.x += 22   # volumen
	ui.polygon(PackedVector2Array([p + Vector2(-5, -2), p + Vector2(-2, -2), p + Vector2(2, -6), p + Vector2(2, 6), p + Vector2(-2, 2), p + Vector2(-5, 2)]), INK)
	ui.line(p + Vector2(5, -3), p + Vector2(5, 3), INK, 1.2)
	p.x += 22   # batería
	ui.rect(Rect2(p + Vector2(-8, -4), Vector2(15, 8)), INK, 2, 1.2)
	ui.rect(Rect2(p + Vector2(-6, -2), Vector2(9, 4)), INK, 1)
	ui.rect(Rect2(p + Vector2(7, -2), Vector2(2, 4)), INK)


func _draw_start(ui: ImUI, r: Rect2) -> void:
	ui.rect(r.grow(8), Color(0, 0, 0, 0.08), 16)
	ui.rect(r, Color(0.95, 0.955, 0.97, 0.98), 8)
	ui.rect(r, LINE, 8, 1)
	# Buscador
	var sb := Rect2(r.position.x + 32, r.position.y + 24, r.size.x - 64, 34)
	ui.rect(sb, LIGHT, 17)
	ui.rect(sb, Color(0, 0, 0, 0.1), 17, 1)
	ui.rect(Rect2(sb.position.x + 20, sb.end.y - 2, sb.size.x - 40, 2), NAVY, 1)
	ui.ring(sb.position + Vector2(22, 16), 6, SHADE, 1.5)
	ui.line(sb.position + Vector2(26, 20), sb.position + Vector2(30, 24), SHADE, 1.5)
	ui.text("Escribe aquí para buscar", sb.position + Vector2(40, 17), 13, SHADE, false, "midleft")
	# Anclados: 6 por fila
	var y := r.position.y + 84
	ui.text("Anclados", Vector2(r.position.x + 48, y), 14, INK, true, "midleft")
	var all := Rect2(r.end.x - 196, y - 13, 150, 26)
	ui.rect(all, LIGHT if ui.hover(all) else Color8(250, 250, 250), 5)
	ui.rect(all, Color(0, 0, 0, 0.1), 5, 1)
	ui.text("Todas las aplicaciones  ›", all.get_center(), 12, INK, false, "center")
	var apps: Array = ICONS + MORE_APPS
	var cols := 6
	var cw := (r.size.x - 64) / cols
	for i in apps.size():
		var it: Array = apps[i]
		var cr := Rect2(r.position.x + 32 + (i % cols) * cw, y + 22 + (i / cols) * 84, cw, 80)
		var hot := ui.hover(cr)
		if hot:
			ui.rect(cr.grow(-3), Color(1, 1, 1, 0.9), 5)
			ui.rect(cr.grow(-3), LINE, 5, 1)
		draw_icon(ui, it[0], Rect2(cr.get_center().x - 16, cr.position.y + 12, 32, 32))
		ui.text(Lang.t(it[1]), Vector2(cr.get_center().x, cr.position.y + 52), 11, INK, false, "midtop", cr.size.x - 8)
		if hot and ui.clicked:
			_open(it[0])
	# Recomendado: tus archivos de hace poco
	y += 22 + ((apps.size() + cols - 1) / cols) * 84 + 18
	ui.text("Recomendado", Vector2(r.position.x + 48, y), 14, INK, true, "midleft")
	for i in RECENT.size():
		var fr := Rect2(r.position.x + 32 + (i % 2) * (r.size.x - 64) / 2, y + 18 + (i / 2) * 56, (r.size.x - 64) / 2 - 6, 50)
		var hot := ui.hover(fr)
		if hot:
			ui.rect(fr, Color(1, 1, 1, 0.9), 5)
		_file_icon(ui, RECENT[i][0], Rect2(fr.position.x + 10, fr.position.y + 10, 28, 30))
		ui.text(RECENT[i][0], Vector2(fr.position.x + 48, fr.position.y + 17), 12, INK, false, "midleft", fr.size.x - 56)
		ui.text(Lang.t(RECENT[i][1]), Vector2(fr.position.x + 48, fr.position.y + 34), 11, SHADE, false, "midleft")
		if hot and ui.clicked:
			_message(RECENT[i][0], "Este archivo está bloqueado: lo tiene abierto el piso de ejecutivos.")
	# Abajo: tu empresa y el botón de apagar
	var foot := Rect2(r.position.x, r.end.y - 62, r.size.x, 62)
	ui.rect(foot, Color(0.91, 0.915, 0.93, 1.0), 8)
	ui.rect(Rect2(foot.position.x, foot.position.y, foot.size.x, 10), Color(0.91, 0.915, 0.93, 1.0))
	ui.rect(Rect2(foot.position, Vector2(foot.size.x, 1)), LINE)
	var g = city.game
	var name: String = str(g.company) if g != null else "CEO"
	ui.circle(Vector2(foot.position.x + 62, foot.get_center().y), 15, NAVY)
	ui.text(name.substr(0, 1).to_upper(), Vector2(foot.position.x + 62, foot.get_center().y), 14, LIGHT, true, "center")
	ui.text(name, Vector2(foot.position.x + 86, foot.get_center().y), 13, INK, false, "midleft")
	var off := Rect2(foot.end.x - 84, foot.position.y + 13, 36, 36)
	var hot2 := ui.hover(off)
	if hot2:
		ui.rect(off, Color(1, 1, 1, 0.9), 5)
	var pc := off.get_center()
	var arc := PackedVector2Array()
	for j in 17:
		var a := -PI / 2 + 0.6 + j / 16.0 * (TAU - 1.2)
		arc.append(pc + Vector2(cos(a), sin(a)) * 7)
	ui.polyline(arc, INK, 1.5)
	ui.rect(Rect2(pc.x - 0.75, pc.y - 9, 1.5, 8), INK)
	if hot2:
		ui.text("Apagar", Vector2(off.position.x - 8, off.get_center().y), 12, SHADE, false, "midright")
	if hot2 and ui.clicked:
		start_open = false
		leaving = 0.8


func _draw_message(ui: ImUI) -> void:
	var r := Rect2(vis.get_center() - Vector2(240, 100), Vector2(480, 184))
	ui.rect(vis, Color(0, 0, 0, 0.3))
	ui.rect(r.grow(8), Color(0, 0, 0, 0.1), 16)
	ui.rect(r, LIGHT, 8)
	ui.rect(r, Color(0, 0, 0, 0.18), 8, 1)
	ui.text(Lang.t(msg.title), Vector2(r.position.x + 24, r.position.y + 30), 18, INK, true, "midleft")
	ui.wrap_text(Lang.t(msg.text), Rect2(r.position.x + 24, r.position.y + 52, r.size.x - 48, 70), 14, INK)
	var foot := Rect2(r.position.x, r.end.y - 60, r.size.x, 60)
	ui.rect(foot.grow_side(SIDE_TOP, -8), Color8(243, 243, 243), 8)
	ui.rect(Rect2(foot.position.x + 1, foot.position.y, foot.size.x - 2, 12), Color8(243, 243, 243))
	ui.rect(Rect2(foot.position, Vector2(foot.size.x, 1)), LINE)
	var label := "Recordarme en 10 años" if msg.warn else "Aceptar"
	var bw := (r.size.x - 60) / 2
	var br := Rect2(foot.position.x + 24, foot.position.y + 14, bw, 32)
	var hot := ui.hover(br)
	ui.rect(br, NAVY.lightened(0.1) if hot else NAVY, 5)
	ui.text(label, br.get_center(), 13, LIGHT, false, "center")
	var cr := Rect2(br.end.x + 12, br.position.y, bw, 32)
	var done := (hot and ui.clicked) or btn(ui, cr, "Cerrar", true, 13)
	if done:
		msg = null
		city.sfx.play("select", 0.3)


## Icono chico de un archivo según su extensión (como los de Office: una hoja con una banda de color).
static func _file_icon(ui: ImUI, file: String, r: Rect2) -> void:
	var ext := file.get_extension()
	var col := {"docx": Color8(43, 87, 154), "doc": Color8(43, 87, 154), "xlsx": Color8(33, 115, 70), "xls": Color8(33, 115, 70),
			"pptx": Color8(210, 71, 38), "ppt": Color8(210, 71, 38), "png": Color8(0, 120, 212)}.get(ext, Color8(120, 120, 128))
	ui.rect(Rect2(r.position.x + r.size.x * 0.2, r.position.y, r.size.x * 0.8, r.size.y), LIGHT, 2)
	ui.rect(Rect2(r.position.x + r.size.x * 0.2, r.position.y, r.size.x * 0.8, r.size.y), Color(0, 0, 0, 0.2), 2, 1)
	for k in 3:
		ui.rect(Rect2(r.position.x + r.size.x * 0.55, r.position.y + r.size.y * (0.3 + k * 0.18), r.size.x * 0.35, 1.5), Color(0, 0, 0, 0.25))
	var tag := Rect2(r.position.x, r.position.y + r.size.y * 0.25, r.size.x * 0.55, r.size.y * 0.5)
	ui.rect(tag, col, 2)
	ui.text(ext.substr(0, 1).to_upper(), tag.get_center(), int(r.size.y * 0.32), LIGHT, true, "center")


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
			if Game.mall_of(ls[i]) < 0:   # los del centro comercial no se decoran
				locs.append([ls[i], i + 1])
	# Lista de sucursales
	var lr := Rect2(body.position.x, body.position.y, 250, body.size.y)
	bevel(ui, lr, true, LIGHT)
	if locs.is_empty():
		ui.wrap_text("Los locales del centro comercial no se decoran. Compra un terreno SE VENDE para tener uno propio." if g.locations else "Todavía no tienes locales. Compra un terreno SE VENDE.", lr.grow(-12), 14, INK)
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
	ui_ref = ui
	_clip(inner)
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
	_clip(null)
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
	var missing := g.missing_decor(sel_loc)
	if missing.size() > 1:   # todo lo que falta de una vez
		var total := g.missing_decor_cost(sel_loc)
		if btn(ui, Rect2(body.end.x - 330, body.position.y + 2, 190, 30), Lang.f("Comprar todo (%s)", Fmt.short(total)), g.cash >= total):
			var res: Array = g.buy_all_decor(sel_loc)
			if res[0]:
				city.sfx.play("coin", 0.6)
				for s2 in city.stores.values():
					if s2.loc.id == sel_loc.id:
						s2.sync_decor()
				item_sel = ""
			else:
				_message("Remodelar.exe", res[1], true)
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


## La barra de un explorador: flechas, la ruta y el buscador; abajo, el panel de la izquierda con las carpetas.
## Devuelve el rectángulo del contenido (a la derecha del panel).
func _explorer(ui: ImUI, body: Rect2, path: Array, here: String) -> Rect2:
	var top := Rect2(body.position.x, body.position.y, body.size.x, 44)
	var arrows := [[Vector2(4, -5), Vector2(4, 5)], [Vector2(-4, -5), Vector2(-4, 5)], [Vector2(-5, 4), Vector2(5, 4)]]   # atrás, adelante, arriba
	for i in 3:
		var c := Vector2(top.position.x + 22 + i * 30, top.get_center().y)
		ui.line(c + arrows[i][0], c, INK if i == 0 else SHADE, 1.3)
		ui.line(c, c + arrows[i][1], INK if i == 0 else SHADE, 1.3)
	var pr := Rect2(top.position.x + 104, top.position.y + 7, top.size.x - 330, 30)
	ui.rect(pr, LIGHT, 4)
	ui.rect(pr, Color(0, 0, 0, 0.1), 4, 1)
	var px := pr.position.x + 12
	for i in path.size():
		var tw := ui.text(Lang.t(path[i]), Vector2(px, pr.get_center().y), 12, INK, false, "midleft").size.x
		px += tw + 6
		if i < path.size() - 1:
			ui.text("›", Vector2(px, pr.get_center().y), 12, SHADE, false, "midleft")
			px += 12
	var sr := Rect2(pr.end.x + 8, pr.position.y, top.end.x - pr.end.x - 20, 30)
	ui.rect(sr, LIGHT, 4)
	ui.rect(sr, Color(0, 0, 0, 0.1), 4, 1)
	ui.text(Lang.f("Buscar en %s", Lang.t(here)), Vector2(sr.position.x + 10, sr.get_center().y), 12, SHADE, false, "midleft", sr.size.x - 20)
	# Panel de la izquierda
	var nav := Rect2(body.position.x, top.end.y, 170, body.end.y - top.end.y)
	ui.rect(Rect2(nav.position.x, nav.position.y, body.size.x, 1), LINE)
	var items := [["Inicio", "casa"], ["Escritorio", "escritorio"], ["Documentos", "docs"], ["Descargas", "descargas"],
			["Imágenes", "fotos"], ["Papelera de reciclaje", "papelera"], ["Este equipo", "equipo"]]
	var y := nav.position.y + 8
	for it in items:
		var ir := Rect2(nav.position.x + 6, y, nav.size.x - 12, 28)
		if it[0] == here or (here == "Papelera de reciclaje" and it[1] == "papelera"):
			ui.rect(ir, Color(0, 0, 0, 0.06), 4)
			ui.rect(Rect2(ir.position.x, ir.position.y + 8, 3, 12), NAVY, 1.5)
		draw_icon(ui, "docs" if it[1] in ["casa", "escritorio", "descargas", "fotos", "equipo"] else it[1],
				Rect2(ir.position.x + 10, ir.position.y + 6, 16, 16))
		ui.text(Lang.t(it[0]), Vector2(ir.position.x + 34, ir.get_center().y), 12, INK, false, "midleft", ir.size.x - 40)
		y += 30
	ui.rect(Rect2(nav.end.x, nav.position.y, 1, nav.size.y), LINE)
	var content := Rect2(nav.end.x + 1, nav.position.y + 1, body.end.x - nav.end.x - 1, nav.size.y - 1)
	ui.rect(content, LIGHT)
	return content


func _app_docs(ui: ImUI, body: Rect2) -> void:
	var r := _explorer(ui, body, ["Este equipo", "Documentos"], "Documentos")
	draw_icon(ui, "docs", Rect2(r.get_center().x - 32, r.position.y + 50, 64, 64))
	ui.text("Esta carpeta está vacía.", Vector2(r.get_center().x, r.position.y + 132), 15, INK, false, "midtop")
	ui.text("Aquí iban tus impuestos.", Vector2(r.get_center().x, r.position.y + 156), 13, SHADE, false, "midtop")
	ui.text("0 elementos", Vector2(r.position.x + 10, r.end.y - 14), 11, SHADE, false, "midleft")


func _app_web(ui: ImUI, body: Rect2) -> void:
	# Pestañas arriba (en la barra de título), la barra de dirección y la página
	var tab := Rect2(body.position.x + 10, body.position.y + 5, 220, 27)
	ui.rect(tab, LIGHT, 6)
	draw_icon(ui, "web", Rect2(tab.position.x + 10, tab.position.y + 6, 15, 15))
	ui.text("Sin conexión", Vector2(tab.position.x + 32, tab.get_center().y), 12, INK, false, "midleft")
	ui.text("✕", Vector2(tab.end.x - 14, tab.get_center().y), 10, SHADE, false, "center")
	ui.text("+", Vector2(tab.end.x + 18, tab.get_center().y), 18, SHADE, false, "center")
	var nav := Rect2(body.position.x, body.position.y + 32, body.size.x, 40)
	ui.rect(nav, LIGHT)
	for i in 3:
		var c := Vector2(nav.position.x + 22 + i * 32, nav.get_center().y)
		if i < 2:
			ui.line(c + Vector2(4 - i * 8, -5), c, SHADE, 1.3)
			ui.line(c, c + Vector2(4 - i * 8, 5), SHADE, 1.3)
		else:
			ui.ring(c, 6, INK, 1.3)
	var ar := Rect2(nav.position.x + 110, nav.position.y + 6, nav.size.x - 160, 28)
	ui.rect(ar, Color8(240, 240, 242), 14)
	ui.text("https://www.comovolverserico.com", Vector2(ar.position.x + 16, ar.get_center().y), 12, INK, false, "midleft")
	ui.text("…", Vector2(nav.end.x - 24, nav.get_center().y), 16, INK, true, "center")
	ui.rect(Rect2(nav.position.x, nav.end.y, nav.size.x, 1), LINE)
	var r := Rect2(body.position.x, nav.end.y + 1, body.size.x, body.end.y - nav.end.y - 1)
	ui.rect(r, LIGHT)
	var x := r.position.x + 60
	var y := r.position.y + 50
	# Un dibujo de un cable desenchufado
	ui.rect(Rect2(x, y + 18, 30, 12), SHADE, 3)
	ui.rect(Rect2(x + 30, y + 21, 10, 2), SHADE)
	ui.rect(Rect2(x + 30, y + 25, 10, 2), SHADE)
	ui.rect(Rect2(x + 58, y + 18, 22, 12), SHADE, 3)
	ui.line(Vector2(x + 80, y + 24), Vector2(x + 110, y + 34), SHADE, 2)
	ui.text("No estás conectado", Vector2(x, y + 64), 24, INK, true)
	ui.wrap_text("No hay Internet: todo el piso de ejecutivos está viendo videos de gatitos.", Rect2(x, y + 100, r.size.x - 120, 40), 14, INK)
	ui.text("Pruebe lo siguiente:", Vector2(x, y + 146), 14, INK, true)
	ui.text("•  Apagar el router y volver a prenderlo.", Vector2(x + 10, y + 170), 14, INK)
	ui.text("•  Gritar «¡A TRABAJAR!» por el ascensor.", Vector2(x + 10, y + 192), 14, INK)
	if web_tries > 0:
		ui.text(Lang.f("Intento %d: sigue sin conexión.", web_tries), Vector2(x, y + 224), 13, Color8(196, 43, 28))
	var br := Rect2(x, r.end.y - 60, 120, 32)
	var hot := ui.hover(br)
	ui.rect(br, NAVY.lightened(0.1) if hot else NAVY, 5)
	ui.text("Reintentar", br.get_center(), 13, LIGHT, false, "center")
	if hot and ui.clicked:
		web_tries += 1
		city.sfx.play("bad", 0.4, 1.4)


func _app_trash(ui: ImUI, body: Rect2) -> void:
	var r := _explorer(ui, body, ["Papelera de reciclaje"], "Papelera de reciclaje")
	ui.text("Nombre", Vector2(r.position.x + 44, r.position.y + 16), 11, SHADE, false, "midleft")
	ui.text("Eliminado", Vector2(r.end.x - 110, r.position.y + 16), 11, SHADE, false, "midleft")
	ui.rect(Rect2(r.position.x + 8, r.position.y + 30, r.size.x - 16, 1), LINE)
	var y := r.position.y + 36
	for i in TRASH.size():
		var f: String = TRASH[i]
		var row := Rect2(r.position.x + 6, y, r.size.x - 12, 30)
		if ui.hover(row):
			ui.rect(row, Color8(229, 241, 251), 4)
		_file_icon(ui, f, Rect2(row.position.x + 10, row.position.y + 5, 18, 20))
		ui.text(f, Vector2(row.position.x + 38, row.get_center().y), 12, INK, false, "midleft", row.size.x - 170)
		ui.text(Lang.f("Hace %d días", i * 3 + 2), Vector2(r.end.x - 110, row.get_center().y), 12, SHADE, false, "midleft")
		y += 30
	if btn(ui, Rect2(r.end.x - 170, r.end.y - 42, 156, 30), "Vaciar papelera"):
		_message("Papelera de reciclaje", "No se puede vaciar la papelera: los malos planes siempre vuelven.")


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
		"config":   # engranaje
			var c3: Vector2 = p.call(22, 22)
			for k in 8:
				var a := TAU * k / 8.0
				ui.rect(Rect2(c3 + Vector2(cos(a), sin(a)) * 13 * s - Vector2(3.5, 3.5) * s, Vector2(7, 7) * s), Color8(110, 116, 128), 1.5 * s)
			ui.circle(c3, 12 * s, Color8(110, 116, 128))
			ui.circle(c3, 5 * s, LIGHT)
		"calc":
			ui.rect(Rect2(p.call(9, 4), Vector2(26, 36) * s), Color8(60, 64, 72), 4 * s)
			ui.rect(Rect2(p.call(12, 8), Vector2(20, 8) * s), Color8(200, 230, 210), 2 * s)
			for row in 3:
				for col in 3:
					ui.rect(Rect2(p.call(12 + col * 7, 19 + row * 7), Vector2(5, 5) * s), Color8(250, 160, 60) if col == 2 else LIGHT, 1 * s)
		"fotos":
			ui.rect(Rect2(p.call(5, 8), Vector2(34, 28) * s), Color8(0, 120, 212), 4 * s)
			ui.polygon(PackedVector2Array([p.call(8, 33), p.call(18, 20), p.call(26, 30), p.call(30, 25), p.call(36, 33)]), Color8(160, 220, 255))
			ui.circle(p.call(30, 15), 3 * s, Color8(255, 220, 90))
		"tienda":   # bolsa de compras
			ui.rect(Rect2(p.call(8, 14), Vector2(28, 26) * s), Color8(0, 103, 192), 3 * s)
			ui.ring(p.call(22, 14), 7 * s, Color8(0, 103, 192), 2.5 * s)
			ui.rect(Rect2(p.call(15, 22), Vector2(6, 6) * s), Color8(242, 80, 34))
			ui.rect(Rect2(p.call(23, 22), Vector2(6, 6) * s), Color8(127, 186, 0))
			ui.rect(Rect2(p.call(15, 30), Vector2(6, 6) * s), Color8(0, 164, 239))
			ui.rect(Rect2(p.call(23, 30), Vector2(6, 6) * s), Color8(255, 185, 0))
		"correo":   # sobre
			ui.rect(Rect2(p.call(5, 10), Vector2(34, 24) * s), Color8(0, 120, 212), 3 * s)
			ui.line(p.call(6, 11), p.call(22, 24), LIGHT, 2 * s)
			ui.line(p.call(38, 11), p.call(22, 24), LIGHT, 2 * s)
		"reloj":
			var c4: Vector2 = p.call(22, 22)
			ui.circle(c4, 17 * s, Color8(40, 44, 52))
			ui.circle(c4, 14 * s, LIGHT)
			ui.line(c4, c4 + Vector2(0, -10) * s, INK, 2 * s)
			ui.line(c4, c4 + Vector2(7, 3) * s, NAVY, 2 * s)
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
