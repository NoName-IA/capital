class_name Admin
extends RefCounted
## Pantallas de administración (traducción de main.py): menú, espacios de guardado, modos, las pestañas del celular
## (Resumen, Negocios, Mercado, Finanzas, Crecimiento, Reportes, Noticias, Conceptos) y las ventanas de decisión.
## Se dibuja con ImUI sobre una pantalla virtual de 1280 × 760.

const W := 1280.0
const H := 760.0
const TOP := 60.0
const SIDE := 180.0
const CX := SIDE + 12.0
const CY := TOP + 12.0
const CW := W - SIDE - 24.0
const CH := H - TOP - 12.0 - 44.0
const SLOTS := 3
# Días de juego por segundo real; los nombres dicen cuántas veces más rápido que x1 va cada una (x1: un día dura
# casi 7 segundos; x2: 3,3 segundos; x3: 2,2 segundos). Un buen jugador llega al Imperio en unos 700 días.
const SPEEDS := [[0.15, "x1"], [0.3, "x2"], [0.45, "x3"]]
const TABS := [["resumen", "Resumen"], ["negocios", "Negocios"], ["expansion", "Expansión"], ["mercado", "Mercado"], ["finanzas", "Finanzas"],
		["crecimiento", "Crecimiento"], ["rivales", "Rivales"], ["personal", "Personal"], ["reportes", "Reportes"],
		["noticias", "Noticias"], ["conceptos", "Conceptos"]]
const TAB_STEP := 41.0

var ui: ImUI
var game: Game = null
var view := "menu"
var tab := "resumen"
var speed := 0
var paused := false
var sel := "cafe"
var scroll := {}
var toast = null              # [texto, tipo, hasta (ms)]
var loan_amount := 5000.0
var loan_months := 24
var bond_amount := 1000.0
var fund_amount := 100000.0
var confirm_sell = null
var cache := {}
var acc := 0.0
var in_pc := false          # estás sentado en la computadora de la oficina (City lo marca)
var modal = null
var running := true
var slot := 1
var slot_screen = null        # "new" o "load": pantalla para elegir el espacio de guardado
var slot_confirm = null       # espacio que se va a sobrescribir o borrar
var slot_cache := {}
var pick_mode := false
var naming := false           # escribiendo el nombre de la empresa (después de elegir el modo)
var settings_open := false    # ajustes abiertos desde el menú de inicio (los dibuja Overlays)
var credits_open := false     # créditos abiertos desde el menú de inicio (los dibuja Overlays)
var name_mode := "normal"
var company_name := ""
const NAME_IDEAS := ["Grupo Horizonte", "Inversiones Faro", "Café & Cía.", "Capital Andina", "Empresas del Sur",
		"Comercial Las Lomas", "Holding Aurora", "Grupo Puerto", "Alfa Retail", "Corporación Brisa", "Imperio Dorado",
		"Mercantil del Pacífico"]
var win_shown := false
var just_created := false
var marks := {}               # dónde quedó dibujado cada botón importante este cuadro (el tutorial apunta ahí)    # se acaba de crear una partida (la ciudad lanza el tutorial)
var quit_requested := false
var unread := 0               # avisos que llegaron y todavía no viste en Noticias
var confirm = null            # pregunta de confirmación: {title, detail, yes, action, danger}
var exp_mall := 0             # centro comercial que se ve en la pestaña Expansión (0 avenida, 1 playa)
var decor_loc := -1           # sucursal que se está decorando (ventana "decorar")
var rival_sel := "starbucks"  # rival elegido en la pestaña Rivales
var quiet := false            # durante el tutorial: la franja de abajo no muestra noticias (lo pone la ciudad)
var open_office_decor = null  # Callable() que pone la ciudad: personalizar la oficina
var open_decor = null         # Callable(id) que pone la ciudad: decorar una sucursal mirándola en 3D
var go_to_loc = null          # Callable(loc) que pone la ciudad: viajar a una sucursal desde la tablet


static var save_dir := "user://saves"


func _init(imui: ImUI) -> void:
	ui = imui
	DirAccess.make_dir_recursive_absolute(save_dir)
	import_python_saves()


static func slot_path(n: int) -> String:
	return "%s/partida_%d.json" % [save_dir, n]


## La primera vez trae las partidas de la versión de Python (carpeta «capital» al lado de esta).
func import_python_saves() -> void:
	for n in range(1, SLOTS + 1):
		if FileAccess.file_exists(slot_path(n)):
			return
	var folder := ProjectSettings.globalize_path("res://").path_join("../capital")
	var names := ["partida.json", "partida_2.json", "partida_3.json"]
	for i in names.size():
		var src := folder.path_join(names[i])
		if not FileAccess.file_exists(src):
			continue
		var text := FileAccess.get_file_as_string(src)
		if JSON.parse_string(text) is Dictionary:
			write_file(slot_path(i + 1), text)


static func sc(x: float) -> String:
	return "green" if x >= 0 else "red"


static func moving_avg(vals: Array, n := 7) -> Array:
	var out := []
	var total := 0.0
	for i in vals.size():
		total += vals[i]
		if i >= n:
			total -= vals[i - n]
		out.append(total / min(i + 1, n))
	return out


func now_ms() -> int:
	return Time.get_ticks_msec()


# ---------- partida ----------
const GAP_MS := 60000          # al menos 1 minuto real entre una decisión urgente y el aviso de nuevo rango
var last_rank_ms := -GAP_MS    # cuándo salió el último aviso de rango
var last_dilemma_ms := -GAP_MS # cuándo se cerró la última decisión (mientras está abierta, cuenta como ahora)


func update(dt: float) -> void:
	var g := game
	if modal == "dilema":
		last_dilemma_ms = now_ms()
	# recién subiste de rango, o estás en la computadora: la decisión espera
	g.hold_dilemma = now_ms() - last_rank_ms < GAP_MS or in_pc
	if g.pending_choice != null and modal == null and not g.game_over and not in_pc:
		modal = "dilema"
	if paused or modal != null or g.game_over:
		return
	g.play_seconds += dt
	acc += dt * SPEEDS[speed][0]
	var steps := 0
	while acc >= 1 and steps < 10:
		g.step_day()
		acc -= 1
		steps += 1
		if g.game_over:
			modal = "gameover"
			save(true)  # la quiebra es definitiva: cerrar el juego no devuelve la partida de antes
			break
		if g.won and not win_shown:
			win_shown = true
			modal = "win"
			break
		if g.pending_choice != null:
			modal = "dilema"
			break
	if g.autosave_due:
		g.autosave_due = false
		save(true)


func new_game(mode := "normal", first_stall := true) -> void:
	game = Game.new(null, mode, first_stall)
	view = "game"
	tab = "resumen"
	sel = "cafe"
	paused = false
	speed = 0
	modal = null
	acc = 0.0
	scroll = {}
	win_shown = false


func save(silent := false, to_slot := 0) -> void:
	if game == null:
		return
	if to_slot:
		slot = to_slot
	if not write_file(slot_path(slot), game.to_json()):
		say("No se pudo guardar la partida (¿disco lleno o carpeta bloqueada?).", "bad")
		return
	slot_cache.erase(slot)
	if not silent:
		say(Lang.f("Partida guardada en el espacio %d.", slot), "good")


## Escribe primero un archivo temporal y después lo pone en su lugar: si el juego se corta a la mitad, el archivo
## anterior queda intacto. Devuelve false si no se pudo escribir.
static func write_file(path: String, text: String) -> bool:
	var tmp := path + ".tmp"
	var f := FileAccess.open(tmp, FileAccess.WRITE)
	if f == null:
		return false
	f.store_string(text)
	var ok := f.get_error() == OK
	f.close()
	if not ok:
		DirAccess.remove_absolute(tmp)
		return false
	return DirAccess.rename_absolute(tmp, path) == OK


func load_slot(n: int) -> bool:
	var text := FileAccess.get_file_as_string(slot_path(n))
	if text.is_empty():
		say(Lang.f("No se pudo cargar la partida del espacio %d.", n), "bad")
		return false
	game = Game.from_json(text)
	slot = n
	view = "game"
	tab = "resumen"
	sel = "cafe"
	paused = true
	modal = null
	acc = 0.0
	win_shown = game.won
	say(Lang.f("Partida del espacio %d cargada. Presiona P para continuar.", n), "info")
	return true


func delete_save(n := 0) -> void:
	var path := slot_path(n if n else slot)
	if FileAccess.file_exists(path):
		DirAccess.remove_absolute(path)
	slot_cache.erase(n if n else slot)


## Resumen de lo guardado en un espacio (o null si está vacío). Se recalcula solo si cambió el archivo.
func slot_info(n: int):
	var path := slot_path(n)
	if not FileAccess.file_exists(path):
		return null
	var stamp := FileAccess.get_modified_time(path)
	if slot_cache.has(n) and slot_cache[n][0] == stamp:
		return slot_cache[n][1]
	var saved := Time.get_datetime_string_from_unix_time(stamp + _tz_offset(), true)
	var parts := saved.split(" ")
	var dmy := parts[0].split("-")
	saved = Lang.f("%s/%s/%s %s", [dmy[2], dmy[1], dmy[0], parts[1].substr(0, 5)])
	var info := {}
	var text := FileAccess.get_file_as_string(path)
	var parsed = JSON.parse_string(text)
	if parsed == null or not parsed is Dictionary:
		info = {"broken": true, "saved": saved}
	else:
		var g := Game.from_json(text)
		var dp := g.date_parts()
		var ri := g.rank_info()
		var caja: Array = g.series.caja
		info = {"company": g.company, "mode": D.MODES[g.mode].name, "mode_key": g.mode, "rank": ri[1], "value": g.valuation(),
				"cash": g.cash, "date": Lang.f("Día %d de %s, año %d", dp),
				"date_short": Lang.f("%d %s, año %d", [dp[0], Lang.month_short(str(dp[1])), dp[2]]), "minutes": g.play_seconds / 60.0, "over": g.game_over,
				"saved": saved, "stores": g.locations.size(),
				"rank_lo": rank_lo(ri[0]), "next": ri[2],   # siguiente rango: [valor, nombre] o null si ya es el último
				"spark": caja.slice(maxi(0, caja.size() - 60))}   # caja de los últimos 60 días
	info.stamp = stamp
	slot_cache[n] = [stamp, info]
	return info


func _tz_offset() -> int:
	return Time.get_time_zone_from_system().bias * 60


func latest_slot() -> int:
	var best := 0
	var best_time := -1
	for n in range(1, SLOTS + 1):
		if FileAccess.file_exists(slot_path(n)):
			var t := FileAccess.get_modified_time(slot_path(n))
			if t > best_time:
				best_time = t
				best = n
	return best


func say(text: String, kind := "info") -> void:
	toast = [text, kind, now_ms() + 3500]


func act(result: Array) -> void:
	say(result[1], "good" if result[0] else "bad")


func cached(key: String, compute: Callable):
	if not cache.has(key):
		if cache.size() > 50:
			cache.clear()
		cache[key] = compute.call()
	return cache[key]


func scroll_area(key: String, area: Rect2, content_h: float) -> float:
	var s: float = scroll.get(key, 0.0)
	if ui.hover(area):
		s -= ui.wheel * 40
	s = clampf(s, 0.0, max(0.0, content_h - area.size.y))
	scroll[key] = s
	return s


func rank_lo(idx: int) -> float:
	return D.RANKS[idx][0]


# ---------- menú ----------
func draw_menu() -> void:
	if naming:
		draw_naming()
		return
	if pick_mode:
		draw_mode_picker()
		return
	if slot_screen != null:
		draw_slots()
		return
	# Logo arriba a la izquierda, sobre la ciudad que gira de fondo (como la pantalla de título de un juego)
	var x := 96.0
	ui.text("SIMULADOR DE NEGOCIOS", Vector2(x + 4, 92), 15, "muted", true)
	ui.text("CAPITAL", Vector2(x - 4, 108), 104, "accent", true)
	ui.rect(Rect2(x, 232, 120, 4), "accent", 2)
	ui.text("Vende, invierte y construye tu imperio", Vector2(x, 248), 19, Color8(200, 208, 220))
	var last := latest_slot()
	var info = slot_info(last) if last else null
	var y := 318.0
	if ui.menu_item("continuar", Vector2(x, y), "CONTINUAR", "", last > 0 and not (info != null and info.get("over", false)), 32):
		load_slot(last)
	y += 72
	if ui.menu_item("nuevo", Vector2(x, y), "NUEVA PARTIDA", "", true, 32):
		slot_screen = "new"
		slot_confirm = null
	y += 72
	if ui.menu_item("cargar", Vector2(x, y), "CARGAR PARTIDA", "", last > 0, 32):
		slot_screen = "load"
		slot_confirm = null
	y += 72
	if ui.menu_item("ajustes", Vector2(x, y), "AJUSTES", "", true, 32):
		settings_open = true
	y += 72
	if ui.menu_item("salir", Vector2(x, y), "SALIR", "", true, 32, 400.0, false, "red"):
		quit_requested = true
	var c := ui.text("© 2026 Brandon Alvis (NoName-IA)  ·  ", Vector2(x, H - 34), 12, "muted")
	# Créditos: un texto chico al lado, que solo se ilumina al pasar el mouse
	var cr := Rect2(c.end.x, c.position.y - 4, ui.text_size("Créditos", 12).x, c.size.y + 8)
	ui.text("Créditos", Vector2(cr.position.x, H - 34), 12, "text" if ui.hover(cr) else "muted")
	if ui.hover(cr) and ui.clicked:
		credits_open = true
	draw_toast_line(H - 64)


func draw_toast_line(y: float) -> void:
	if toast != null and now_ms() < toast[2]:
		ui.text(toast[0], Vector2(W / 2, y), 16, ImUI.KIND_COLOR[toast[1]], false, "center")


## Color de cada modo de juego (franja de las tarjetas de partida).
const MODE_COLOR := {"normal": "blue", "inversionista": "purple"}


## Hace cuánto se guardó: "hace 5 min", "ayer", "hace 3 días"... (con más de una semana, la fecha).
func ago(stamp: int, saved: String) -> String:
	var s := int(Time.get_unix_time_from_system()) - stamp
	if s < 60:
		return "hace un momento"
	if s < 3600:
		return Lang.f("hace %d min", (s / 60))
	if s < 86400:
		return Lang.f("hace %d h", (s / 3600))
	if s < 2 * 86400:
		return "ayer"
	if s < 7 * 86400:
		return Lang.f("hace %d días", (s / 86400))
	return saved.split(" ")[0]


## Etiqueta con fondo de color (MODO, ÚLTIMA, QUIEBRA). Devuelve dónde quedó.
func pill(pos: Vector2, label: String, color, solid := false, anchor := "topleft") -> Rect2:
	var c := ui.col(color)
	var r := Rect2(pos, ui.text_size(label, 11, true) + Vector2(16, 6))
	if anchor == "topright":
		r.position.x -= r.size.x
	ui.rect(r, c if solid else Color(c, 0.18), r.size.y / 2)
	ui.text(label, r.get_center(), 11, Color8(20, 20, 20) if solid else c, true, "center")
	return r


## Gráfico chico de la caja: área suave con la línea encima (verde si subió, rojo si bajó).
func spark(r: Rect2, vals: Array, label: String) -> void:
	ui.rect(r, Color(1, 1, 1, 0.03), 8)
	ui.text(label, r.position + Vector2(10, 6), 11, "muted")
	if vals.size() < 2:
		ui.text("Todavía sin datos", r.get_center() + Vector2(0, 6), 12, "muted", false, "center")
		return
	var lo: float = vals.min()
	var hi: float = vals.max()
	if hi - lo < 1.0:
		hi = lo + 1.0
	var c: Color = ImUI.COL.green if vals[-1] >= vals[0] else ImUI.COL.red
	var top := r.position.y + 24
	var bottom := r.end.y - 4
	var pts := PackedVector2Array()
	for i in vals.size():
		var x := r.position.x + 6 + (r.size.x - 12) * i / (vals.size() - 1.0)
		pts.append(Vector2(x, lerpf(bottom, top, (vals[i] - lo) / (hi - lo))))
	for i in pts.size() - 1:   # una franja por tramo: así nunca falla aunque la línea quede plana
		ui.polygon(PackedVector2Array([pts[i], pts[i + 1], Vector2(pts[i + 1].x, bottom), Vector2(pts[i].x, bottom)]),
				Color(c, 0.14))
	ui.polyline(pts, c, 2.0)
	ui.circle(pts[-1], 3.5, c)


## Cuadrito con un dato: etiqueta chica arriba y el valor grande abajo.
func stat_tile(r: Rect2, label: String, value: String, color = "text") -> void:
	ui.rect(r, Color(1, 1, 1, 0.04), 8)
	ui.text(label, r.position + Vector2(10, 7), 11, "muted")
	ui.text(value, r.position + Vector2(10, 23), 16, color, true, "topleft", r.size.x - 16)


## Avance hacia el siguiente rango: barra y "Siguiente: X" debajo. Devuelve la y de lo que sigue.
func rank_progress(x: float, y: float, w: float, info: Dictionary) -> float:
	if info.next == null:
		ui.bar(Rect2(x, y, w, 6), 1.0, "accent")
		ui.text("Rango máximo alcanzado", Vector2(x, y + 12), 12, "accent")
		return y + 30
	var frac: float = (info.value - info.rank_lo) / (info.next[0] - info.rank_lo)
	ui.bar(Rect2(x, y, w, 6), frac, "accent")
	ui.text(Lang.f("Siguiente: %s", info.next[1]), Vector2(x, y + 12), 12, "muted", false, "topleft", w - 90)
	ui.text(Lang.f("%s / %s", [Fmt.short(info.value), Fmt.short(info.next[0])]), Vector2(x + w, y + 12), 12, "text", false,
			"topright")
	return y + 30


## Borde punteado (para los espacios vacíos).
func dashed_rect(r: Rect2, color, dash := 8.0, gap := 6.0) -> void:
	var c := ui.col(color)
	var edges := [[r.position, Vector2(r.end.x, r.position.y)], [Vector2(r.end.x, r.position.y), r.end],
			[r.end, Vector2(r.position.x, r.end.y)], [Vector2(r.position.x, r.end.y), r.position]]
	for e in edges:
		var a: Vector2 = e[0]
		var b: Vector2 = e[1]
		var len := a.distance_to(b)
		var d := (b - a) / len
		var t := 0.0
		while t < len:
			ui.line(a + d * t, a + d * minf(t + dash, len), c, 1.5)
			t += dash + gap


## Tres espacios de guardado. "new": elegir dónde empezar la partida nueva; "load": elegir cuál cargar.
func draw_slots() -> void:
	var is_new: bool = slot_screen == "new"
	if is_new:
		draw_steps(0)
	else:
		ui.text("CARGAR PARTIDA", Vector2(W / 2, 34), 13, "muted", true, "center")
	ui.text("¿Dónde la guardamos?" if is_new else "Tus partidas", Vector2(W / 2, 62), 38, "text", true, "center")
	ui.text("Cada espacio guarda una partida distinta. El juego se guarda solo en el espacio que estás usando."
			if is_new else "Elige la partida que quieres seguir jugando.", Vector2(W / 2, 122), 16, "muted", false, "center")
	var last := latest_slot()
	var cw := 360.0
	var gap := 24.0
	var x0 := W / 2 - (SLOTS * cw + (SLOTS - 1) * gap) / 2
	for i in SLOTS:
		var n := i + 1
		var r := Rect2(x0 + i * (cw + gap), 160, cw, 456)
		if draw_slot_card(r, n, slot_info(n), is_new, n == last):
			return
	if ui.button(Rect2(W / 2 - 120, 642, 240, 44), "Volver", true, "normal", 16):
		slot_screen = null
		slot_confirm = null
	draw_toast_line(700)


## Una tarjeta de espacio de guardado. Devuelve true si se salió de la pantalla (se cargó o se empezó una partida).
func draw_slot_card(r: Rect2, n: int, info, is_new: bool, is_last: bool) -> bool:
	var confirming: bool = slot_confirm == n
	var k := ui.tween(Lang.f("slot:%d", n), 1.0 if ui.hover(r) and not confirming else 0.0)
	r.position.y -= 4 * k
	var x := r.position.x + 24
	var w := r.size.x - 48
	var bx := r.position.x + 24
	var by := r.end.y - 64
	var bw := r.size.x - 48
	# Vacío: borde punteado y un "+" en el centro
	if info == null:
		ui.rect(r, Color(ImUI.COL.panel, 0.55 + 0.25 * k), 14)
		dashed_rect(r.grow(-6), Color(ImUI.COL.muted, 0.35 + 0.4 * k))
		var c := Vector2(r.get_center().x, r.position.y + 170)
		ui.ring(c, 34, Color(ImUI.COL.muted, 0.6 + 0.4 * k), 2)
		ui.line(c - Vector2(13, 0), c + Vector2(13, 0), Color(ImUI.COL.muted, 0.8 + 0.2 * k), 3)
		ui.line(c - Vector2(0, 13), c + Vector2(0, 13), Color(ImUI.COL.muted, 0.8 + 0.2 * k), 3)
		ui.text(Lang.f("ESPACIO %d", n), Vector2(c.x, r.position.y + 40), 12, "muted", true, "midtop")
		ui.text("Espacio libre", Vector2(c.x, c.y + 54), 22, "text", true, "midtop")
		if is_new:
			ui.text("Aquí puedes empezar una partida nueva.", Vector2(c.x, c.y + 92), 14, "muted", false, "midtop")
		else:
			ui.text("Para usarlo, elige este espacio", Vector2(c.x, c.y + 92), 14, "muted", false, "midtop")
			ui.text("al empezar una partida nueva.", Vector2(c.x, c.y + 112), 14, "muted", false, "midtop")
		if is_new and ui.button(Rect2(bx, by, bw, 44), "Empezar aquí", true, "primary", 16):
			start_in_slot(n)
			return true
		return false
	var broken: bool = info.get("broken", false)
	var mc: Color = ImUI.COL.red if broken else ui.col(MODE_COLOR.get(info.get("mode_key", ""), "blue"))
	ui.rect(r, ImUI.COL.panel, 14)
	ui.top_strip(Rect2(r.position, Vector2(r.size.x, 106)), Color(mc, 0.16), 14)
	ui.rect(Rect2(r.position.x, r.position.y + 106, r.size.x, 1), Color(mc, 0.35))
	ui.rect(r, Color(ImUI.COL.accent, 0.25 + 0.6 * k) if not broken else Color(mc, 0.6), 14, 1 + k)
	# Número grande de fondo, como marca de agua
	ui.text(str(n), Vector2(r.end.x - 18, r.position.y - 8), 96, Color(mc, 0.22), true, "topright")
	var y := r.position.y + 18
	var t := ui.text(Lang.f("ESPACIO %d", n), Vector2(x, y + 3), 12, "muted", true)
	if is_last and not broken:
		pill(Vector2(t.end.x + 10, y), "ÚLTIMA", "accent", true)
	if broken:
		ui.text("Archivo dañado", Vector2(x, y + 28), 24, "red", true)
		var c := Vector2(r.get_center().x, r.position.y + 230)
		ui.circle(c, 34, Color(mc, 0.15))
		ui.ring(c, 34, mc, 2)
		ui.text("!", c, 36, mc, true, "center")
		ui.wrap_text("No se pudo leer esta partida. Puedes borrarla para usar el espacio otra vez.",
				Rect2(x + 10, c.y + 54, w - 20, 60), 14, "muted")
		ui.text(Lang.f("Guardada el %s", info.saved), Vector2(r.get_center().x, by - 30), 12, "muted", false, "midtop")
	else:
		ui.text(info.company, Vector2(x, y + 26), 24, "text", true, "topleft", w - 60)
		pill(Vector2(x, y + 64), info.mode.to_upper(), mc)
		if info.over:
			pill(Vector2(r.end.x - 24, y + 64), "QUIEBRA", "red", false, "topright")
		y = r.position.y + 122
		ui.text(info.rank, Vector2(x, y), 17, "accent", true, "topleft", w - 90)
		ui.text(Lang.f("%d %s", [info.stores, "local" if info.stores == 1 else "locales"]), Vector2(x + w, y + 3), 13,
				"muted", false, "topright")
		y = rank_progress(x, y + 30, w, info)
		spark(Rect2(x, y, w, 52), info.spark, "Caja · últimos 60 días")
		y += 62
		var tw := (w - 10) / 2.0
		stat_tile(Rect2(x, y, tw, 48), "Valor de la empresa", Fmt.short(info.value), "accent")
		stat_tile(Rect2(x + tw + 10, y, tw, 48), "Caja", Fmt.short(info.cash), sc(info.cash))
		stat_tile(Rect2(x, y + 56, tw, 48), "Fecha del juego", info.date_short)
		stat_tile(Rect2(x + tw + 10, y + 56, tw, 48), "Tiempo jugado", Lang.f("%d min", roundi(info.minutes)))
		var st := ui.text(Lang.f("Guardada %s", ago(info.stamp, info.saved)), Vector2(x, y + 114), 12, "muted")
		ui.tooltip(st, Lang.f("Guardada el %s", info.saved))
	# Botones (o la pregunta de confirmación, encima de la tarjeta)
	if confirming:
		ui.rect(r, Color(0.03, 0.04, 0.06, 0.86), 14)
		var c := r.get_center()
		ui.text("¿Sobrescribir esta partida?" if is_new else "¿Borrar esta partida?", c - Vector2(0, 46), 20, "orange",
				true, "center")
		ui.text("Esto no se puede deshacer.", c - Vector2(0, 16), 14, "muted", false, "center")
		if ui.button(Rect2(bx, c.y + 14, bw / 2 - 6, 44), Lang.t("Sí, sobrescribir" if is_new else "Sí, borrar"), true,
				"danger", 15):
			delete_save(n)
			slot_confirm = null
			if is_new:
				start_in_slot(n)
				return true
		if ui.button(Rect2(bx + bw / 2 + 6, c.y + 14, bw / 2 - 6, 44), "Cancelar", true, "normal", 15):
			slot_confirm = null
	elif is_new:
		if ui.button(Rect2(bx, by, bw, 44), "Sobrescribir", true, "normal", 16):
			slot_confirm = n
	else:
		var ok: bool = not broken and not info.get("over", false)
		if not broken and ui.button(Rect2(bx, by, bw - 120, 44), "Cargar", ok, "primary", 16,
				null if ok else "Esta partida terminó en quiebra: ya no se puede seguir."):
			if load_slot(n):
				slot_screen = null
				return true
		if ui.button(Rect2(bx + bw - 108 if not broken else bx, by, 108 if not broken else bw, 44), "Borrar", true,
				"danger", 15):
			slot_confirm = n
	return false


func start_in_slot(n: int) -> void:
	slot = n
	slot_screen = null
	slot_confirm = null
	pick_mode = true


## Último paso antes de empezar: el nombre de tu empresa (sale en el HUD, el celular, la oficina y tus locales).
func draw_naming() -> void:
	draw_steps(2)
	var x := 96.0
	var mc := ui.col(MODE_COLOR[name_mode])
	pill(Vector2(x, 112), D.MODES[name_mode].name.to_upper(), mc)
	ui.text("¿Cómo se llama tu empresa?", Vector2(x, 140), 44, "text", true)
	ui.rect(Rect2(x, 206, 120, 4), "accent", 2)
	ui.text("Aparece en tus locales, tu oficina y en lo que dicen los clientes y los rivales.", Vector2(x, 224), 16, "muted")
	var field := Rect2(x, 268, 620, 76)
	ui.rect(field, Color(0.04, 0.05, 0.07, 0.9), 14)
	ui.rect(field, ImUI.COL.accent, 14, 2)
	var t := ui.text(company_name, Vector2(field.position.x + 24, field.get_center().y), 34, "accent", true, "midleft")
	if not company_name:
		ui.text("Escribe un nombre…", Vector2(field.position.x + 24, field.get_center().y), 30, Color(1, 1, 1, 0.25), false, "midleft")
	if int(Time.get_ticks_msec() / 500) % 2 == 0:  # cursor que parpadea
		var cx: float = t.end.x + 3 if company_name else field.position.x + 24
		ui.rect(Rect2(cx, field.get_center().y - 20, 3, 40), "accent")
	ui.text(Lang.f("%d / 24", company_name.length()), Vector2(field.end.x - 16, field.end.y + 8), 13, "muted", false, "topright")
	# Ideas de nombre: se eligen con un clic y van cambiando cada pocos segundos
	ui.text("IDEAS", Vector2(x, field.end.y + 14), 11, "muted", true)
	var ix := x
	var first := int(Time.get_ticks_msec() / 6000) * 3
	for j in 3:
		var idea: String = NAME_IDEAS[(first + j) % NAME_IDEAS.size()]
		var ir := Rect2(ix, field.end.y + 34, ui.text_size(idea, 14).x + 28, 34)
		var hot := ui.hover(ir)
		ui.rect(ir, ImUI.COL.button_hot if hot else Color(1, 1, 1, 0.06), 17)
		ui.rect(ir, Color(ImUI.COL.accent, 0.7 if hot else 0.2), 17, 1)
		ui.text(idea, ir.get_center(), 14, "accent" if hot else "text", false, "center")
		if hot and ui.clicked:
			company_name = idea
		ix = ir.end.x + 10
	var ok := company_name.strip_edges().length() >= 2
	if ui.menu_item("empezar", Vector2(x, 470), "EMPEZAR", "Enter", ok, 32, 400.0) :
		start_named_game()
		return
	if ui.menu_item("volver_nombre", Vector2(x, 550), "VOLVER", "Esc", true, 24, 400.0, false, "muted"):
		naming = false
		pick_mode = true
	# Vista previa: el letrero de tu empresa y con qué empiezas
	var r := Rect2(W - 440, 268, 380, 262)
	ui.rect(r, Color(0.05, 0.065, 0.09, 0.9), 16)
	ui.rect(r, Color(mc, 0.5), 16, 1)
	var px := r.position.x + 24
	var pw := r.size.x - 48
	ui.text("ASÍ EMPIEZAS", Vector2(px, r.position.y + 20), 11, "muted", true)
	var sign := Rect2(px, r.position.y + 44, pw, 74)
	ui.rect(sign, Color8(34, 28, 18), 8)
	ui.rect(sign, Color(ImUI.COL.accent, 0.8), 8, 2)
	var named := company_name.strip_edges() != ""
	ui.text(company_name if named else "Tu empresa", sign.get_center(), 26,
			"accent" if named else Color(ImUI.COL.accent, 0.35), true, "center", pw - 24)
	var tw := (pw - 10) / 2.0
	var ty := sign.end.y + 18
	stat_tile(Rect2(px, ty, tw, 50), "Capital inicial", Fmt.short(D.MODES[name_mode].start_cash), "green")
	stat_tile(Rect2(px + tw + 10, ty, tw, 50), "Espacio", str(slot))
	stat_tile(Rect2(px, ty + 58, pw, 50), "Rango inicial", D.RANKS[0][1])
	draw_toast_line(H - 64)


func start_named_game() -> void:
	var name := company_name.strip_edges()
	if name.length() < 2:
		say("Escribe un nombre de al menos 2 letras.", "bad")
		return
	naming = false
	new_game(name_mode, false)
	just_created = true
	game.company = name
	game.news.clear()
	game.add_news(Lang.f("Fundaste %s con %s en caja. Compra tu primer puesto.", [name, Fmt.money(game.cash)]), "good")
	if name_mode == "inversionista":
		game.add_news("Modo inversionista: tienes capital para crecer rápido. No hay final: llega a Mil millonario.", "info")


## Teclas mientras escribes el nombre: letras, borrar, Enter para empezar y Esc para volver.
func type_key(e: InputEventKey) -> void:
	if not e.pressed:
		return
	match e.keycode:
		KEY_BACKSPACE:
			company_name = company_name.left(company_name.length() - 1)
		KEY_ENTER, KEY_KP_ENTER:
			start_named_game()
		KEY_ESCAPE:
			naming = false
			pick_mode = true
		_:
			var ch := char(e.unicode) if e.unicode >= 32 else ""
			if ch and company_name.length() < 24 and not (ch == " " and company_name.ends_with(" ")) and not (ch == " " and company_name.is_empty()):
				company_name += ch


## Pasos para crear una partida (arriba de las tres pantallas): 0 espacio, 1 modo, 2 nombre.
func draw_steps(active: int) -> void:
	var names := ["Espacio", "Modo", "Nombre"]
	var step := 190.0
	var x0 := W / 2 - step - 30
	for i in names.size():
		var c := Vector2(x0 + i * step, 28)
		if i < names.size() - 1:   # la línea empieza después del nombre del paso
			var lx: float = c.x + 30 + ui.text_size(names[i], 13, i == active).x
			ui.rect(Rect2(lx, c.y - 1, c.x + step - 22 - lx, 2), "accent" if i < active else "border")
		var lit := i <= active
		ui.circle(c, 13, ImUI.COL.accent if lit else ImUI.COL.panel2)
		if not lit:
			ui.ring(c, 13, "border", 1.5)
		ui.text(str(i + 1), c, 13, Color8(20, 20, 20) if lit else ImUI.COL.muted, true, "center")
		ui.text(names[i], Vector2(c.x + 20, c.y), 13, "text" if i == active else "muted", i == active, "midleft")


## Antes de cada partida nueva: modo normal (con final) o modo inversionista (sin final).
func draw_mode_picker() -> void:
	draw_steps(1)
	ui.text("¿Cómo quieres jugar?", Vector2(W / 2, 62), 38, "text", true, "center")
	ui.text(Lang.f("Se guardará en el espacio %d.", slot), Vector2(W / 2, 122), 16, "muted", false, "center")
	var cards := [
		["normal", "Empiezas con poca plata y compras tu primer puesto. Sube rango por rango hasta construir tu imperio.",
		 [["Capital inicial", Fmt.short(D.MODES.normal.start_cash), "green"], ["Meta", Lang.f("Imperio · %s", Fmt.short(D.WIN_VALUE)), "accent"],
		  ["Duración", "Unos 40 min", "text"], ["Rangos", str(D.MODES.normal.ranks), "text"]]],
		["inversionista", "Tienes capital para crecer rápido. No hay final: usa la bolsa, la gestión y las adquisiciones para llegar a Mil millonario.",
		 [["Capital inicial", Fmt.short(D.MODES.inversionista.start_cash), "green"], ["Meta", "Sin final", "accent"],
		  ["Duración", "Libre", "text"], ["Rangos", str(D.MODES.inversionista.ranks), "text"]]],
	]
	for i in cards.size():
		var c: Array = cards[i]
		var key: String = c[0]
		var r := Rect2(W / 2 - 512 + i * 536, 150, 488, 470)
		var k := ui.tween("mode:" + key, 1.0 if ui.hover(r) else 0.0)
		r.position.y -= 4 * k
		var mc := ui.col(MODE_COLOR[key])
		ui.rect(r, ImUI.COL.panel, 14)
		ui.top_strip(Rect2(r.position, Vector2(r.size.x, 120)), Color(mc, 0.16 + 0.06 * k), 14)
		ui.rect(Rect2(r.position.x, r.position.y + 120, r.size.x, 1), Color(mc, 0.35))
		ui.rect(r, Color(mc, 0.3 + 0.6 * k), 14, 1 + k)
		var x := r.position.x + 28
		var w := r.size.x - 56
		pill(Vector2(x, r.position.y + 22), "MODO", mc)
		ui.text(D.MODES[key].name.trim_prefix("Modo ").capitalize(), Vector2(x, r.position.y + 50), 36, mc.lightened(0.15), true)
		ui.wrap_text(c[1], Rect2(x, r.position.y + 136, w, 70), 16, "text")
		var tw := (w - 12) / 2.0
		for j in c[2].size():
			var st: Array = c[2][j]
			stat_tile(Rect2(x + (j % 2) * (tw + 12), r.position.y + 206 + (j / 2) * 58, tw, 50), st[0], st[1], st[2])
		# Los rangos del modo, como una escalera de puntos
		var ranks: int = D.MODES[key].ranks
		var ry := r.position.y + 330
		ui.text("Del rango", Vector2(x, ry), 11, "muted")
		ui.text(D.RANKS[0][1], Vector2(x, ry + 14), 13, "text", true)
		ui.text("hasta", Vector2(x + w, ry), 11, "muted", false, "topright")
		ui.text(D.RANKS[ranks - 1][1], Vector2(x + w, ry + 14), 13, "accent", true, "topright")
		for j in ranks:
			var px := x + 6 + (w - 12) * j / (ranks - 1.0)
			if j < ranks - 1:
				ui.rect(Rect2(px, ry + 41, (w - 12) / (ranks - 1.0), 2), Color(mc, 0.4))
			ui.circle(Vector2(px, ry + 42), 4.0 if j < ranks - 1 else 6.0, mc if j < ranks - 1 else ImUI.COL.accent)
		if ui.button(Rect2(x, r.end.y - 66, w, 46), Lang.f("Elegir modo %s", key), true, "primary", 17):
			pick_mode = false
			naming = true
			name_mode = key
			company_name = ""
			return
	if ui.button(Rect2(W / 2 - 120, 642, 240, 44), "Volver", true, "normal", 16):
		pick_mode = false
		slot_screen = "new"


# ---------- juego ----------
func draw_game() -> void:
	marks.clear()
	var was_clicked := ui.clicked
	var was_mouse := ui.mouse
	if modal != null:
		# Bloquea la interfaz de fondo mientras hay un diálogo abierto.
		ui.clicked = false
		ui.mouse = Vector2(-100, -100)
		ui.wheel = 0
	ui.rect(Rect2(0, 0, W, H), "bg")
	draw_top()
	draw_side()
	call("draw_" + tab, game)
	draw_ticker()
	if modal != null:
		ui.clicked = was_clicked
		ui.mouse = was_mouse
		ui.tip = null
		draw_modal()


func draw_top() -> void:
	var g := game
	ui.rect(Rect2(0, 0, W, TOP), "panel")
	ui.line(Vector2(0, TOP), Vector2(W, TOP), "border")
	ui.text(game.company.to_upper(), Vector2(20, TOP / 2), 22 if game.company.length() <= 12 else 15, "accent", true, "midleft", 165)
	var ph: Dictionary = D.PHASES[g.phase]
	var econ_color := "green" if g.econ_index >= 1.02 else ("red" if g.econ_index < 0.92 else "orange")
	var items := [
		[190, "Fecha", g.date_str(), "text", null],
		[415, "Caja", Fmt.money(g.cash), sc(g.cash), "Dinero disponible. Puede ser negativa (sobregiro), pero pagas un interés muy alto."],
		[560, "Valor empresa", Fmt.money(g.valuation()), "accent",
		 "Valoración: EBITDA anual × múltiplo + caja + bonos + inventario − deuda. Define tu rango." if g.investing() else
		 "Valoración: EBITDA anual × múltiplo + caja + inventario − deuda. Define tu rango."],
		[715, "Economía", Lang.f("%s (%s)", [ph.name, Fmt.num(g.econ_index, 2)]), econ_color,
		 "Índice de actividad económica (1,00 = normal). Afecta la demanda según la elasticidad ingreso de cada producto."],
		[885, "Inflación", Fmt.pct(g.inflation), "text",
		 "Inflación anual. Tus costos, salarios y alquileres suben; el precio de referencia del mercado también."],
		[975, "Tasa BC", Fmt.pct(g.policy_rate), "text",
		 "Tasa del banco central. Sube cuando hay inflación. Define el costo de los préstamos y el rendimiento de los bonos." if g.investing() else
		 "Tasa del banco central. Sube cuando hay inflación. Define el costo de los préstamos."],
	]
	for it in items:
		ui.text(it[1], Vector2(it[0], 9), 12, "muted")
		var r := ui.text(it[2], Vector2(it[0], 26), 16, it[3], true)
		ui.tooltip(Rect2(it[0], 6, max(r.size.x, 70.0), 46), it[4])
	var x := 1074.0
	if ui.button(Rect2(x, 15, 46, 30), "II", true, "normal", 15, "Pausa (P)", paused):
		paused = not paused
	marks.velocidad = Rect2(x + 52, 15, 52 * (SPEEDS.size() - 1) + 46, 30)
	for i in SPEEDS.size():
		if ui.button(Rect2(x + 52 + i * 52, 15, 46, 30), SPEEDS[i][1], true, "normal", 15,
				Lang.f("Velocidad %s (tecla %d)", [SPEEDS[i][1], i + 1]), not paused and speed == i):
			speed = i
			paused = false


func draw_side() -> void:
	var g := game
	ui.rect(Rect2(0, TOP + 1, SIDE, H - TOP), "panel")
	ui.line(Vector2(SIDE, TOP), Vector2(SIDE, H), "border")
	for i in TABS.size():
		var label: String = TABS[i][1]
		if TABS[i][0] == "noticias" and unread and tab != "noticias":
			label = Lang.t(label) + " (%d)" % mini(unread, 99)   # ya traducido: el número no se traduce
		marks["tab_" + TABS[i][0]] = Rect2(12, TOP + 12 + i * TAB_STEP, SIDE - 24, 35)
		if ui.button(Rect2(12, TOP + 12 + i * TAB_STEP, SIDE - 24, 35), label, true, "normal", 16, null, tab == TABS[i][0]):
			tab = TABS[i][0]
			confirm_sell = null
	var info := g.rank_info()
	var y := H - 96
	ui.text("Rango", Vector2(16, y), 13, "muted")
	ui.text(info[1], Vector2(16, y + 18), 17, "accent", true, "topleft", SIDE - 24)
	if info[2] != null:
		var lo := rank_lo(info[0])
		ui.bar(Rect2(16, y + 48, SIDE - 32, 8), (info[3] - lo) / (info[2][0] - lo), "accent")
		ui.text(Lang.f("Siguiente: %s", Fmt.short(info[2][0])), Vector2(16, y + 62), 12, "muted")
		ui.tooltip(Rect2(16, y, SIDE - 32, 80), Lang.f("Llega a un valor de empresa de %s para ser %s.", [Fmt.money(info[2][0]), info[2][1]]))
	# (guardar, partida nueva y menú principal están en el menú de pausa, no en la tablet)


func draw_ticker() -> void:
	var g := game
	var r := Rect2(CX, H - 38, CW, 30)
	if g.micro != null and modal == null:
		draw_micro_bar(r)
		return
	ui.rect(r, "panel", 8)
	var text := ""
	var kind := "info"
	if toast != null and now_ms() < toast[2]:
		text = toast[0]
		kind = toast[1]
		ui.text("»", Vector2(r.position.x + 12, r.get_center().y), 16, ImUI.KIND_COLOR[kind], true, "midleft")
	elif g.news and not quiet:
		text = g.news[-1].text
		kind = g.news[-1].kind
	else:
		return
	ui.text(text, Vector2(r.position.x + 30, r.get_center().y), 15, ImUI.KIND_COLOR[kind], false, "midleft", r.size.x - 40)


func draw_modal() -> void:
	var g := game
	ui.rect(Rect2(0, 0, W, H), Color(0, 0, 0, 0.67))
	if modal == "dilema":
		draw_dilemma()
		return
	if modal == "confirmar":
		draw_confirm()
		return
	if modal == "decorar":
		draw_decor()
		return
	var box := Rect2(W / 2 - 280, H / 2 - 140, 560, 280)
	ui.panel(box)
	var cx := box.get_center().x
	if modal == "gameover":
		ui.text("Quiebra", Vector2(cx, box.position.y + 46), 36, "red", true, "center")
		ui.wrap_text(Lang.f("Tu empresa no pudo pagar al banco y cerró después de %s años. Revisa en Reportes qué costos se comieron tu utilidad: casi siempre es crecer con deuda más rápido que la caja.", Fmt.num(g.day / 360.0, 1)),
				Rect2(box.position.x + 40, box.position.y + 90, box.size.x - 80, 120), 16, "text")
		if ui.button(Rect2(box.position.x + 40, box.end.y - 64, 220, 42), "Nuevo juego", true, "primary"):
			delete_save()
			game = null
			view = "menu"
			modal = null
			slot_screen = "new"
		elif ui.button(Rect2(box.end.x - 260, box.end.y - 64, 220, 42), "Menú principal"):
			delete_save()
			game = null
			view = "menu"
			modal = null
	elif modal == "win":
		var normal := g.mode == "normal"
		var minutes: float = (g.win_seconds if g.win_seconds != null else g.play_seconds) / 60.0
		ui.text("¡Construiste un imperio!" if normal else "¡Eres mil millonario!", Vector2(cx, box.position.y + 46), 32,
				"accent", true, "center")
		ui.wrap_text(Lang.f("Tu empresa vale %s. Lo lograste en %d minutos de juego (%s años dentro del juego). ", [Fmt.money(g.valuation()), roundi(minutes), Fmt.num(g.day / 360.0, 1)])
				+ ("Fin de la partida. ¿Quieres más títulos? Prueba el modo inversionista." if normal
				else "Llegaste a la cima. Puedes seguir jugando todo lo que quieras."),
				Rect2(box.position.x + 40, box.position.y + 90, box.size.x - 80, 120), 16, "text")
		if ui.button(Rect2(box.position.x + 40, box.end.y - 64, 220, 42), "Menú principal", true, "primary"):
			save(true)
			game = null
			view = "menu"
			modal = null
		elif ui.button(Rect2(box.end.x - 260, box.end.y - 64, 220, 42), "Seguir jugando"):
			modal = null
	elif modal == "new":
		ui.text("¿Empezar de nuevo?", Vector2(cx, box.position.y + 46), 30, "text", true, "center")
		ui.wrap_text("Vas a elegir un espacio para la partida nueva. La actual se guarda ahora en su espacio.",
				Rect2(box.position.x + 40, box.position.y + 100, box.size.x - 80, 80), 16, "muted")
		if ui.button(Rect2(box.position.x + 40, box.end.y - 64, 220, 42), "Sí, juego nuevo", true, "danger"):
			save(true)
			game = null
			view = "menu"
			modal = null
			slot_screen = "new"
		elif ui.button(Rect2(box.end.x - 260, box.end.y - 64, 220, 42), "Cancelar"):
			modal = null


## Ícono y color de cada decisión urgente (las de los rivales usan las iniciales y el color del rival).
const DILEMMA_STYLE := {
	"soborno": ["coin", Color8(225, 85, 75)], "influencer": ["star", Color8(163, 113, 247)],
	"aumento": ["person", Color8(88, 166, 255)], "lote": ["box", Color8(219, 140, 60)], "demanda": ["alert", Color8(225, 85, 75)],
	"oferta": ["coin", Color8(63, 185, 80)], "huelga": ["person", Color8(219, 140, 60)], "franquicia": ["building", Color8(63, 185, 80)],
	"ciberataque": ["bolt", Color8(225, 85, 75)], "patrocinio": ["heart", Color8(88, 166, 255)],
	"proveedor": ["box", Color8(219, 140, 60)],
}


static var rival_textures := {}


## Logo de la marca o foto del rival (assets/imagenes/rivales/<clave>.png), o null si no hay.
static func rival_texture(key: String):
	if not rival_textures.has(key):
		var path := "res://assets/imagenes/rivales/%s.png" % key
		rival_textures[key] = load(path) if ResourceLoader.exists(path) else null
	return rival_textures[key]


## El ícono redondo de un rival: su logo o su foto, con un borde de su color (si no hay imagen, sus iniciales).
static func rival_badge(ui: ImUI, r: Dictionary, c: Vector2, radius: float, dim := false) -> void:
	var tex = rival_texture(r.key)
	if tex == null:
		ui.circle(c, radius, r.color if not dim else Color(r.color, 0.35))
		ui.text(initials(r), c + Vector2(0, 1), radius * 0.75, Color8(16, 20, 30), true, "center")
		return
	ui.circle(c, radius + 2.5, r.color if not dim else Color(r.color, 0.35))
	ui.image(tex, Rect2(c - Vector2(radius, radius), Vector2(radius, radius) * 2), Color(1, 1, 1, 0.45 if dim else 1.0))


## Iniciales de un rival para su ícono (sin "Dr." ni "Doña").
static func initials(r: Dictionary) -> String:
	var out := ""
	for w in String(r.name).replace("Dr. ", "").replace("Doña ", "").split(" ").slice(0, 2):
		out += w[0]
	return out


func _dilemma_look(c: Dictionary) -> Array:
	var rival_key = c.data.get("rival")
	if c.id in ["cartel", "compra_rival"] and rival_key != null:
		var r := D.rival_by_key(rival_key)
		var initials := ""
		for w in r.name.replace("Dr. ", "").replace("Doña ", "").split(" ").slice(0, 2):
			initials += w[0]
		return [initials, r.color, true]
	var st: Array = DILEMMA_STYLE.get(c.id, ["alert", ImUI.COL.orange])
	return [st[0], st[1], false]


## Decisión con riesgo, como las cartas de evento de los juegos de estrategia: encabezado de color con el ícono,
## el texto y cada opción como una tarjeta que dice si es segura o tiene riesgo. El juego queda en pausa.
func draw_dilemma() -> void:
	var g := game
	var c = g.pending_choice
	if c == null:
		modal = null
		return
	var look := _dilemma_look(c)
	var accent: Color = look[1]
	var bw := 880.0
	var pad := 44.0
	var text_h := ui.wrap_height(c.text, bw - pad * 2, 17)
	var details := []   # alto de lo bueno y de lo malo de cada opción
	var total := 0.0
	var lw := bw - pad * 2 - 74
	for o in c.options:
		var gh: float = ui.wrap_height(o.get("good", o.detail), lw, 15)
		var bdh: float = ui.wrap_height(o.bad, lw, 15) + 6 if o.get("bad", "") != "" else 0.0
		details.append([gh, bdh])
		total += 50 + gh + bdh + 12
	var head := 124.0
	var bh := head + 24 + text_h + 22 + total + 20
	var box := Rect2(W / 2 - bw / 2, max(16.0, H / 2 - bh / 2), bw, bh)
	ui.rect(box.grow(10), Color(0, 0, 0, 0.35), 26)  # sombra
	ui.rect(box, Color8(18, 22, 30), 20)
	# Encabezado con degradado del color de la decisión
	var hr := Rect2(box.position, Vector2(bw, head))
	ui.top_strip(hr, Color(accent, 0.28), 20)
	ui.gradient(Rect2(hr.position.x, hr.position.y + 20, bw, head - 20), Color(accent, 0.0), Color8(18, 22, 30, 0), false)
	ui.rect(box, Color(accent, 0.55), 20, 1.5)
	var ic := box.position + Vector2(pad + 34, head / 2 + 4)
	ui.circle(ic, 38, Color(accent, 0.25))
	ui.circle(ic, 32, accent)
	if look[2]:  # las iniciales del rival
		ui.text(look[0], ic + Vector2(0, 1), 26, Color8(16, 20, 30), true, "center")
	else:
		Icons.draw(ui, look[0], ic, 40, Color8(16, 20, 30))
	var tx := ic.x + 56
	var dp := g.date_parts()
	ui.text(Lang.f("DECISIÓN IMPORTANTE · PARA SIEMPRE · DÍA %d DE %s" if c.get("key", false) else "DECISIÓN URGENTE · DÍA %d DE %s", [dp[0], String(dp[1]).to_upper()]), Vector2(tx, box.position.y + 30), 13,
			Notifications.light(accent, 0.3), true)
	ui.text(c.title, Vector2(tx, box.position.y + 50), 30, "text", true, "topleft", box.end.x - tx - pad)
	var cash_r := Rect2(box.end.x - pad - 200, box.position.y + 22, 200, 30)
	ui.rect(cash_r, Color(0, 0, 0, 0.3), 15)
	ui.text(Lang.f("Caja: %s", Fmt.money(g.cash)), cash_r.get_center(), 14, sc(g.cash), true, "center")
	# Texto
	var y := box.position.y + head + 24
	y += ui.wrap_text(c.text, Rect2(box.position.x + pad, y, bw - pad * 2, text_h), 17, Color8(215, 222, 232)) + 22
	# Opciones como tarjetas
	for i in c.options.size():
		var o: Dictionary = c.options[i]
		var r := Rect2(box.position.x + pad, y, bw - pad * 2, 50 + details[i][0] + details[i][1])
		var hot := ui.hover(r)
		var k := ui.tween(Lang.f("dilema%d", i), 1.0 if hot else 0.0)
		ui.rect(r, ImUI.COL.panel2.lerp(Color8(44, 52, 66), k), 12)
		ui.rect(r, Color(accent, 0.25 + 0.6 * k), 12, 1.0 + k)
		ui.text(o.label, Vector2(r.position.x + 22, r.position.y + 14), 17, "text", true, "topleft", r.size.x - 44)
		# Lo bueno (verde) y lo malo (rojo), cada uno en su línea
		var ly := r.position.y + 42
		ui.text("+", Vector2(r.position.x + 30, ly + 9), 18, "green", true, "center")
		ui.wrap_text(o.get("good", o.detail), Rect2(r.position.x + 48, ly, lw, details[i][0]), 15, Color8(150, 225, 170))
		if details[i][1] > 0:
			ly += details[i][0] + 6
			ui.text("−", Vector2(r.position.x + 30, ly + 9), 18, "red", true, "center")
			ui.wrap_text(o.bad, Rect2(r.position.x + 48, ly, lw, details[i][1]), 15, Color8(240, 150, 140))
		if hot and ui.clicked:
			var res := g.resolve_choice(i)
			modal = null
			say(res[1], "good" if res[0] else "bad")
			return
		y += r.size.y + 12


# ---------- Resumen ----------
func draw_resumen(g: Game) -> void:
	var last = Game.statement(g.history[-1]) if g.history else null
	var cur := Game.statement(g.ledger)
	var net_margin: float = last.utilidad_neta / last.ingresos if last != null and last.ingresos else 0.0
	var cards := [
		["Caja", Fmt.money(g.cash), sc(g.cash), Lang.f("Bonos: %s", Fmt.money(g.bonds)) if g.investing() else "Para crecer y pagar", "Dinero disponible para crecer y pagar costos."],
		["Ingresos del mes", Fmt.money(cur.ingresos), "text",
		 Lang.f("Mes pasado: %s", Fmt.money(last.ingresos)) if last != null else "Tu primer mes",
		 "Precio × unidades vendidas en lo que va del mes."],
		["Utilidad neta (mes pasado)", Fmt.money(last.utilidad_neta) if last != null else "—",
		 sc(last.utilidad_neta) if last != null else "muted", Lang.f("Margen neto: %s", Fmt.pct(net_margin)),
		 "Lo que quedó después de TODOS los costos, intereses, depreciación e impuestos."],
		["Valor de la empresa", Fmt.money(g.valuation()), "accent",
		 Lang.f("Múltiplo: %s × EBITDA", Fmt.num(g.valuation_multiple(), 1)),
		 "Cuánto pagaría un inversionista por tu empresa. El múltiplo sube en auge y baja en recesión."],
	]
	var cw := (CW - 36) / 4
	for i in cards.size():
		var c: Array = cards[i]
		var r := Rect2(CX + i * (cw + 12), CY, cw, 86)
		if i == 3:
			marks.valor = r
		ui.panel(r)
		ui.text(c[0], r.position + Vector2(16, 10), 14, "muted")
		ui.text(c[1], r.position + Vector2(16, 30), 25, c[2], true, "topleft", r.size.x - 24)
		ui.text(c[3], r.position + Vector2(16, 62), 13, "muted", false, "topleft", r.size.x - 24)
		ui.tooltip(r, c[4])

	var info := g.rank_info()
	var r := ui.panel(Rect2(CX, CY + 98, CW, 62))
	ui.text("Rango:", r.position + Vector2(16, 19), 17, "muted")
	ui.text(info[1], r.position + Vector2(80, 17), 20, "accent", true)
	if info[2] != null:
		var lo := rank_lo(info[0])
		ui.bar(Rect2(r.position.x + 330, r.position.y + 26, 460, 12), (info[3] - lo) / (info[2][0] - lo), "accent")
		ui.text(Lang.f("Siguiente rango: %s al valer %s", [info[2][1], Fmt.money(info[2][0])]), Vector2(r.end.x - 16, r.position.y + 21),
				15, "muted", false, "topright")
	else:
		ui.text("¡Llegaste al rango máximo!", r.position + Vector2(330, 19), 17, "green", true)

	var y := CY + 172
	ui.line_chart(Rect2(CX, y, 640, 236), [[g.series.caja, "accent", "Caja"]], "Caja (últimos 365 días)", Fmt.short)
	ui.line_chart(Rect2(CX, y + 248, 640, 232),
			[[moving_avg(g.series.ingresos), "blue", "Ingresos"], [moving_avg(g.series.utilidad), "green", "EBITDA"]],
			"Ingresos y EBITDA por día (promedio de 7 días)", Fmt.short)

	var rx := CX + 652
	var rw := CW - 652
	r = ui.panel(Rect2(rx, y, rw, 236), "Alertas y consejos")
	var ty := r.position.y + 44
	var tips: Array = cached(Lang.f("tips%d", g.day), g.advisories)
	if tips.is_empty():
		tips = [["good", "Todo en orden. Busca la siguiente inversión con mejor retorno."]]
	for t in tips:
		if ty > r.end.y - 30:
			break
		ui.circle(Vector2(r.position.x + 22, ty + 9), 4, ImUI.KIND_COLOR[t[0]])
		ty += ui.wrap_text(t[1], Rect2(r.position.x + 34, ty, rw - 50, 60), 14, "text") + 2
	r = ui.panel(Rect2(rx, y + 248, rw, 232), "Últimas noticias")
	ty = r.position.y + 44
	for i in range(g.news.size() - 1, max(-1, g.news.size() - 9), -1):
		var n: Dictionary = g.news[i]
		if ty > r.end.y - 30:
			break
		ui.circle(Vector2(r.position.x + 22, ty + 9), 4, ImUI.KIND_COLOR[n.kind])
		ty += ui.wrap_text(n.text, Rect2(r.position.x + 34, ty, rw - 50, 60), 14, "text") + 2


# ---------- Negocios ----------
func draw_negocios(g: Game) -> void:
	for i in D.PRODUCT_ORDER.size():
		var key: String = D.PRODUCT_ORDER[i]
		var p: Dictionary = g.products[key]
		var d: Dictionary = D.PRODUCTS[key]
		var r := Rect2(CX, CY + i * 130, 250, 118)
		ui.panel(r)
		if sel == key:
			ui.rect(r, "blue", 10, 2)
		elif ui.hover(r):
			ui.rect(r, "muted", 10, 1)
		if ui.hover(r) and ui.clicked:
			sel = key
			confirm_sell = null
		ui.text(d.name, r.position + Vector2(16, 12), 19, "text" if p.unlocked else "muted", true)
		if not p.unlocked:
			ui.text("Bloqueado", r.position + Vector2(16, 44), 14, "muted")
			ui.text(Lang.f("Desbloquear: %s", Fmt.money(g.unlock_cost(key))), r.position + Vector2(16, 66), 14,
					"green" if g.cash >= g.unlock_cost(key) else "muted")
			continue
		var ls := g.locs(key)
		var contrib = null
		if g.history and g.history[-1].productos.has(key):
			contrib = g.history[-1].productos[key].contribucion
		ui.text(Lang.f("%d sucursal(es)%s", [ls.size(), " · fábrica" if p.factory else ""]), r.position + Vector2(16, 42), 14, "text")
		ui.text(Lang.f("Ventas ayer: %s %s", [Fmt.num(p.last_sold), d.unit]), r.position + Vector2(16, 62), 14, "muted")
		if contrib != null:
			ui.text(Lang.f("Contribución mes: %s", Fmt.money(contrib)), r.position + Vector2(16, 82), 14, sc(contrib))

	var key := sel
	var p: Dictionary = g.products[key]
	var d: Dictionary = D.PRODUCTS[key]
	var rx := CX + 262
	var rw := CW - 262
	ui.panel(Rect2(rx, CY, rw, CH))
	ui.text(d.name, Vector2(rx + 20, CY + 14), 24, "text", true)
	ui.wrap_text(d.description, Rect2(rx + 20, CY + 50, rw - 40, 40), 14, "muted")
	if not p.unlocked:
		draw_locked(g, key, rx, rw)
		return

	var y := CY + 88
	var bw := (rw - 40 - 24) / 3
	for s in D.SIZES.size():
		var size: Dictionary = D.SIZES[s]
		var cost := g.location_cost(s)
		var tip := Lang.f("Inversión (CAPEX): %s, se deprecia en 5 años. Alquiler: %s/mes. Tráfico de clientes ×%s y hasta %d empleados. Cada sucursal nueva del mismo producto canibaliza un poco a las demás.", [Fmt.money(cost), Fmt.money(size.rent * g.price_index), Fmt.num(size.traffic), size.max_emp])
		var place := g.free_place(s)
		if place.is_empty():
			tip = g.no_place_reason(s)
		elif place[0] == "mall":
			tip = Lang.f("Va a la vitrina %d de %s (la avenida está llena). ", [place[1] % int(D.MALL.slots) + 1, Lang.noun(D.MALLS[Game.mall_index(place[1])].name)]) + tip
		if ui.button(Rect2(rx + 20 + s * (bw + 12), y, bw, 34), Lang.f("Abrir %s (%s)", [size.name, Fmt.short(cost)]), g.cash >= cost and not place.is_empty(), "normal", 15, tip):
			act(g.open_location(key, s))   # se abre sin preguntar
	y += 44
	var units_month: float = p.ema_sales * 30
	var no_factory_cost: float = g.unit_cost(p) / (1 - D.FACTORY_SAVING) if p.factory else g.unit_cost(p)
	var saving: float = units_month * no_factory_cost * D.FACTORY_SAVING
	var upkeep := g.factory_cost(key) * D.FACTORY_UPKEEP
	var f_tip := Lang.f("Integración vertical: fabricar tú mismo baja el costo unitario 30%%. Costo fijo de mantenimiento: %s/mes. Con tus ventas actuales ahorrarías ~%s/mes. Solo conviene si el ahorro supera el mantenimiento y la depreciación (%s/mes).", [Fmt.money(upkeep), Fmt.money(saving), Fmt.money(g.factory_cost(key) / 60)])
	if p.factory and p.get("solar", false):
		ui.button(Rect2(rx + 20, y, bw, 34), "Fábrica solar activa", false, "normal", 15, f_tip)
	elif p.factory:
		var sc_cost := g.solar_cost(key)
		var s_tip := Lang.f("Paneles solares en el techo de la fábrica: el mantenimiento baja a %d%% (la luz es gratis), el costo unitario baja otro %d%% y ganas +4 de reputación por ser verde. Ahorro estimado: %s/mes.", [roundi(Game.SOLAR_UPKEEP * 100), roundi(Game.SOLAR_SAVING * 100), Fmt.money(g.factory_upkeep_monthly(p) * (1 - Game.SOLAR_UPKEEP) + units_month * g.unit_cost(p) * Game.SOLAR_SAVING)])
		if ui.button(Rect2(rx + 20, y, bw, 34), Lang.f("Paneles solares (%s)", Fmt.short(sc_cost)), g.cash >= sc_cost, "normal", 15, s_tip):
			ask(Lang.f("¿Poner paneles solares en la fábrica de %s?", Lang.noun(d.name)), s_tip, Lang.f("Sí, instalar (%s)", Fmt.short(sc_cost)), g.build_solar.bind(key))
	elif ui.button(Rect2(rx + 20, y, bw, 34), Lang.f("Construir fábrica (%s)", Fmt.short(g.factory_cost(key))), g.cash >= g.factory_cost(key), "normal", 15, f_tip):
		ask(Lang.f("¿Construir una fábrica de %s?", Lang.noun(d.name)), f_tip, Lang.f("Sí, construir (%s)", Fmt.short(g.factory_cost(key))), g.build_factory.bind(key))
	var wage: float = D.MANAGER_WAGE * g.price_index * g.min_wage_mult
	var m_tip := Lang.f("Delegación: un gerente cuesta %s/mes y ajusta solo el personal de cada sucursal y los días de inventario de esta línea.", Fmt.money(wage))
	if ui.button(Rect2(rx + 32 + bw, y, bw, 34), "Despedir gerente" if p.manager else Lang.f("Contratar gerente (%s/mes)", Fmt.short(wage)),
			true, "normal", 15, m_tip, p.manager):
		ask("¿Despedir al gerente?" if p.manager else "¿Contratar un gerente?", m_tip, "Sí, despedirlo" if p.manager else "Sí, contratar",
				g.toggle_manager.bind(key))
	var acq := g.acquire_cost(key)
	var a_tip := Lang.f("Fusiones y adquisiciones: compras un competidor (%d en el mercado). Recibes su local con 3 empleados y hay un rival menos. Lo que pagas por encima del valor del local es plusvalía (goodwill). Cada competidor que queda es más caro.", p.competitors)
	if ui.button(Rect2(rx + 44 + 2 * bw, y, bw, 34), Lang.f("Adquirir competidor (%s)", Fmt.short(acq)), p.competitors > 0 and g.cash >= acq, "normal", 15, a_tip):
		ask(Lang.f("¿Comprar un local de %s?", D.rival_for(key).company), a_tip, Lang.f("Sí, comprar (%s)", Fmt.short(acq)), g.acquire.bind(key))

	y += 50
	var ls := g.locs(key)
	var service: float = p.last_sold / p.last_demand if p.last_demand else 1.0
	ui.text(Lang.f("Ayer: demanda %s · capacidad %s · vendido %s %s · nivel de servicio %s", [Fmt.num(p.last_demand), Fmt.num(p.last_capacity), Fmt.num(p.last_sold), d.unit, Fmt.pct(service, 0)]),
			Vector2(rx + 20, y), 14, "muted")
	y += 28
	var x0 := rx + 20
	var heads := [["Sucursal", x0, "topleft"], ["Empleados", x0 + 201, "midtop"], ["Demanda", x0 + 300, "topright"],
			["Capacidad", x0 + 362, "topright"], ["Vendido", x0 + 420, "topright"], ["Contrib.", x0 + 476, "topright"],
			["ROI", x0 + 544, "topright"]]
	for h in heads:
		ui.text(h[0], Vector2(h[1], y), 13, "muted", true, h[2])
	ui.tooltip(Rect2(x0 + 430, y, 115, 18), "Contribución = ingresos − mercancía − salarios − alquiler de la sucursal (último mes cerrado). ROI anual = contribución × 12 ÷ inversión total en la sucursal.")
	y += 24
	var area := Rect2(rx + 10, y, rw - 20, CY + CH - y - 10)
	var rows := 40.0
	var s := scroll_area("neg" + key, area, ls.size() * rows)
	ui.set_clip(area)
	var prod: float = d.productivity
	for i in ls.size():
		var loc: Dictionary = ls[i]
		var ry := area.position.y + i * rows - s
		if ry + rows < area.position.y or ry > area.end.y:
			continue
		if i % 2 == 0:
			ui.rect(Rect2(area.position.x, ry, area.size.x, rows - 4), "panel2", 6)
		var cy := ry + (rows - 4) / 2
		var size: Dictionary = D.SIZES[loc.size]
		var where := ""
		if Game.place_label(loc) != "":
			where = " · " + Game.place_label(loc)
		# El nombre es un enlace: con un clic viajas a esa sucursal
		var name_r := Rect2(x0 - 4, ry, 139, rows - 4)
		var link_hot := go_to_loc != null and ui.hover(name_r)
		var nr := ui.text(Lang.f("%s #%d%s", [size.name, i + 1, where]), Vector2(x0, cy - 8), 14, "accent" if link_hot else "text", true, "midleft", 135)
		if link_hot:
			ui.rect(Rect2(nr.position.x, nr.end.y, nr.size.x, 1), "accent")
			if ui.clicked:
				go_to_loc.call(loc)
		var st := Game.stars_of(loc)
		for k in 5:
			Icons.draw(ui, "star", Vector2(x0 + 6 + k * 13, cy + 9), 12, Color8(240, 190, 60) if k < floori(st + 0.25) else Color8(70, 75, 85))
		ui.text(Fmt.num(st, 1), Vector2(x0 + 72, cy + 9), 12, "muted", false, "midleft")
		ui.tooltip(Rect2(x0, ry, 135, rows), Lang.f("Estrellas: %s de 5 (con 5 vende 15%% más que con 3; suben atendiendo a todos, con buena reputación, calidad y precio justo). Inversión total: %s. Valor en libros: %s. Productividad: %s %s por empleado al día.", [Fmt.num(st, 1), Fmt.money(loc.invested), Fmt.money(g.asset_book(loc.asset_ids)), Fmt.num(prod, 1), d.unit]))
		if ui.button(Rect2(x0 + 140, cy - 13, 26, 26), "−", loc.employees > 0 and not p.manager, "normal", 15,
				Lang.f("Despedir: pagas %d días de salario de indemnización.", int(D.SEVERANCE_DAYS))):
			act(g.fire(loc))
		ui.text("%d/%d" % [loc.employees, size.max_emp], Vector2(x0 + 201, cy), 15, "text", false, "center")
		if not marks.has("contratar"):
			marks.contratar = Rect2(x0 + 236, cy - 13, 26, 26)
			marks.puesto1 = Rect2(area.position.x, ry, area.size.x, rows - 4)   # la fila entera (tutorial)
		if ui.button(Rect2(x0 + 236, cy - 13, 26, 26), "+", loc.employees < size.max_emp and not p.manager, "normal", 15,
				Lang.f("Contratar: %s de reclutamiento y %s/mes de salario.", [Fmt.money(D.HIRING_COST * g.price_index), Fmt.money(g.wage_daily() * 30)])):
			act(g.hire(loc))
		var lost: bool = loc.demand > loc.capacity * 1.02
		ui.text(Fmt.num(loc.demand), Vector2(x0 + 300, cy), 15, "orange" if lost else "text", false, "midright")
		ui.text(Fmt.num(loc.capacity), Vector2(x0 + 362, cy), 15, "text", false, "midright")
		ui.text(Fmt.num(loc.sold), Vector2(x0 + 420, cy), 15, "text", false, "midright")
		if loc.last_contrib != null:
			ui.text(Fmt.short(loc.last_contrib), Vector2(x0 + 476, cy), 15, sc(loc.last_contrib), false, "midright")
			var roi: float = loc.last_contrib * 12 / loc.invested if loc.invested else 0.0
			ui.text(Fmt.pct(roi, 0), Vector2(x0 + 544, cy), 15, sc(roi), true, "midright")
		else:
			ui.text(Fmt.short(loc.month_contrib), Vector2(x0 + 476, cy), 15, "muted", false, "midright")
			ui.text("—", Vector2(x0 + 544, cy), 15, "muted", false, "midright")
		var n_dec: int = loc.get("upgrades", []).size()
		if ui.button(Rect2(x0 + 552, cy - 14, 76, 28), Lang.f("Decorar %d/%d", [n_dec, D.upgrades_for(int(loc.size)).size()]) if n_dec else "Decorar", true, "normal", 13,
				"Compra artículos para este local: plantas, letrero luminoso, terraza, aire acondicionado..."):
			decor_loc = loc.id
			if open_decor != null:
				open_decor.call(loc.id)
			else:
				modal = "decorar"
		var up = g.upgrade_cost(loc)
		var up_tip := Lang.f("Ampliar a %s por %s: más tráfico y más empleados posibles.", [D.SIZES[loc.size + 1].name, Fmt.money(up)]) if up != null else ("Ya es una megatienda." if loc.size >= 2 else "En una vitrina del centro comercial no cabe una megatienda.")
		if ui.button(Rect2(x0 + 633, cy - 14, 68, 28), "Ampliar", up != null and g.cash >= up, "normal", 13, up_tip):
			ask(Lang.f("¿Ampliar a %s?", Lang.noun(D.SIZES[loc.size + 1].name)), up_tip, Lang.f("Sí, ampliar (%s)", Fmt.short(up)), g.upgrade_location.bind(loc))
		var sell_tip := Lang.f("Recibes %s: la mitad de su valor en libros. La otra mitad es un costo hundido y se registra como pérdida. También pagas indemnizaciones.", Fmt.money(g.sell_value(loc)))
		if ui.button(Rect2(x0 + 706, cy - 14, rw - 40 - 706, 28), "Vender", true, "danger", 13, sell_tip):
			ask(Lang.f("¿Vender tu %s?", Lang.noun(size.name)), sell_tip, Lang.f("Sí, vender (%s)", Fmt.short(g.sell_value(loc))), g.sell_location.bind(loc), true)
	ui.set_clip(null)
	if ls.is_empty():
		ui.text("Todavía no tienes sucursales de esta línea. Abre una arriba.", area.get_center(), 16, "muted", false, "center")


func draw_locked(g: Game, key: String, rx: float, rw: float) -> void:
	var d: Dictionary = D.PRODUCTS[key]
	var y := CY + 100
	var w := 420.0
	var x := rx + 20
	var rows := [
		["Precio de referencia", Fmt.money(d.ref_price * g.price_index, 2), null],
		["Costo unitario", Fmt.money(d.unit_cost * g.price_index, 2), null],
		["Margen bruto típico", Fmt.pct(1 - d.unit_cost / d.ref_price, 0), null],
		["Elasticidad precio", Fmt.num(d.elasticity, 1), "Con 2,0, subir el precio 10% baja la demanda cerca de 20%."],
		["Elasticidad ingreso", Fmt.num(d.income_elasticity, 1), "Cuánto sube o baja la demanda con la economía."],
		["Ventas por empleado al día", Lang.f("%s %s", [Fmt.num(d.productivity, 1), d.unit]), null],
		["Merma diaria del inventario", Fmt.pct(d.spoil, 1), "Parte del inventario que se pierde cada día."],
		["Temporada alta", D.MONTHS[d.season_peak - 1], null],
		["Competidores", str(g.products[key].competitors), null],
	]
	for r in rows:
		y = ui.row(x, y, w, r[0], r[1], "text", r[2])
	var cost := g.unlock_cost(key)
	y += 16
	if ui.button(Rect2(x, y, 320, 44), Lang.f("Desbloquear por %s", Fmt.money(cost)), g.cash >= cost, "primary", 15,
			"Licencias, recetas y desarrollo. Se registra como activo intangible y se amortiza en 5 años."):
		ask(Lang.f("¿Desbloquear %s?", d.name), "Licencias, recetas y desarrollo. Se registra como activo intangible y se amortiza en 5 años.",
				Lang.f("Sí, desbloquear (%s)", Fmt.short(cost)), g.unlock.bind(key))
	if g.cash < cost:
		ui.text(Lang.f("Te faltan %s. Ahorra o pide un préstamo en Finanzas.", Fmt.money(cost - g.cash)), Vector2(x, y + 56), 14, "muted")


# ---------- Mercado ----------
func draw_mercado(g: Game) -> void:
	var unlocked := []
	for k in D.PRODUCT_ORDER:
		if g.products[k].unlocked:
			unlocked.append(k)
	if not (sel in unlocked):
		sel = unlocked[0]
	for i in unlocked.size():
		if ui.button(Rect2(CX + i * 152, CY, 142, 32), D.PRODUCTS[unlocked[i]].name, true, "normal", 15, null, sel == unlocked[i]):
			sel = unlocked[i]
	var key := sel
	var p: Dictionary = g.products[key]
	var d: Dictionary = D.PRODUCTS[key]
	var q: Dictionary = D.QUALITIES[p.quality]
	var y0 := CY + 44
	var h0 := CH - 44
	var lw := 530.0

	var r := ui.panel(Rect2(CX, y0, lw, h0), "Precio y demanda",
			"La demanda baja cuando subes el precio (elasticidad). El mejor precio no es el más alto ni el más bajo: es el que maximiza ventas × margen.")
	ui.text(Fmt.money(p.price, 2), Vector2(CX + 20, y0 + 44), 32, "accent", true)
	var steps := [["−5%", 0.95], ["−1%", 0.99], ["+1%", 1.01], ["+5%", 1.05]]
	for i in steps.size():
		if ui.button(Rect2(CX + 190 + i * 62, y0 + 48, 56, 32), steps[i][0]):
			p.price = max(0.01, p.price * steps[i][1])
	var ls := g.locs(key)
	var emp := 0
	for l in ls:
		emp += l.employees
	var cv: Array = cached(Lang.f("curve%d|%s|%f|%d|%d|%d", [g.day, key, p.price, p.quality, ls.size(), emp]), func(): return g.price_curve(key))
	var curve: Array = cv[0]
	var best: Array = cv[1]
	marks.precio_optimo = Rect2(CX + 190, y0 + 88, 242, 30)
	if ui.button(Rect2(CX + 190, y0 + 88, 242, 30), Lang.f("Usar precio óptimo (%s)", Fmt.money(best[0], 2)), not ls.is_empty(), "normal", 15,
			"Precio que maximiza la utilidad diaria con tu personal y sucursales actuales. Ojo: precios muy altos también bajan la reputación."):
		p.price = best[0]

	var ref := g.ref_price(p)
	var cost := g.unit_cost(p)
	var margin: float = p.price - cost
	var be = g.break_even(key)
	var service: float = p.last_sold / p.last_demand if p.last_demand else 1.0
	var y := y0 + 130
	var x := CX + 20
	var w := lw - 40
	var rows := [
		["Precio de referencia del mercado", Fmt.money(ref, 2), "text", "Lo que cobra la competencia por esta calidad. Sube con la inflación."],
		["Tu precio frente al mercado", ("+" if p.price >= ref else "") + Fmt.pct(p.price / ref - 1), "text",
		 "Más del 25% por encima daña tu reputación. Mucho más barato la mejora un poco, pero sacrificas margen."],
		["Elasticidad precio", Fmt.num(d.elasticity * q.elast, 2), "text", "Si es 2, subir el precio 1% baja la demanda cerca de 2%."],
		["Costo unitario", Fmt.money(cost, 2), "text",
		 Lang.f("Costo base × calidad × inflación. Descuento por volumen: %s%s", [Fmt.pct(g.volume_discount(p), 0), " · fábrica propia −30%." if p.factory else "."])],
		["Margen de contribución por unidad", Lang.f("%s (%s)", [Fmt.money(margin, 2), Fmt.pct(margin / p.price if p.price else 0.0, 0)]), sc(margin),
		 "Precio − costo variable. Lo que cada venta aporta para pagar los costos fijos."],
		["Demanda / capacidad (ayer)", Lang.f("%s / %s", [Fmt.num(p.last_demand), Fmt.num(p.last_capacity)]), "text",
		 "Capacidad = empleados × productividad. Si la demanda la supera, pierdes ventas."],
		["Ventas ayer · nivel de servicio", Lang.f("%s · %s", [Fmt.num(p.last_sold), Fmt.pct(service, 0)]), "green" if service > 0.95 else "orange",
		 "Porcentaje de la demanda que lograste atender. Si es bajo, baja tu reputación."],
		["Punto de equilibrio", Lang.f("%s %s/día", [Fmt.num(be), d.unit]) if be != null else "precio bajo el costo",
		 "green" if be != null and p.last_sold >= be else "red",
		 Lang.f("Costos fijos diarios de la línea (%s) ÷ margen de contribución.", Fmt.money(g.fixed_costs_daily(key)))],
	]
	for row in rows:
		y = ui.row(x, y, w, row[0], row[1], row[2], row[3])

	var chart := Rect2(CX + 10, y + 6, lw - 20, r.end.y - y - 16)
	if not ls.is_empty():
		var lo_p: float = curve[0][0]
		var hi_p: float = curve[-1][0]
		var current := 0.0
		for l in ls:
			current += min(g.demand_at(p, l, p.price, ls.size()), g.capacity(l))
		current *= margin
		var util := curve.map(func(c): return c[1])
		ui.line_chart(chart, [[util, "green", "Utilidad diaria"]],
				Lang.f("Utilidad diaria según precio (%s a %s)", [Fmt.money(lo_p, 2), Fmt.money(hi_p, 2)]), Fmt.short,
				[[(best[0] - lo_p) / (hi_p - lo_p), best[1], "green", "óptimo", true],
				 [(p.price - lo_p) / (hi_p - lo_p), current, "accent", "tu precio", false]])
	else:
		ui.panel(chart, "Utilidad diaria según precio")
		ui.text("Abre una sucursal para ver la curva.", chart.get_center(), 15, "muted", false, "center")

	var rx := CX + lw + 12
	var rw := CW - lw - 12
	ui.panel(Rect2(rx, y0, rw, h0), "Estrategia comercial")
	x = rx + 20
	w = rw - 40
	y = y0 + 46
	ui.text("Calidad", Vector2(x, y), 15, "muted", true)
	y += 24
	var notes := ["Bien inferior: se vende MÁS en recesión, pero más riesgo de multas.", "El punto medio.",
			"Clientes menos sensibles al precio, pero cae fuerte en recesión."]
	for i in D.QUALITIES.size():
		var qual: Dictionary = D.QUALITIES[i]
		var tip := Lang.f("Costo ×%s · precio de referencia ×%s · reputación objetivo %d. %s", [Fmt.num(qual.cost, 2), Fmt.num(qual.price, 2), int(qual.rep), notes[i]])
		var qw := (w - 16) / 3
		if ui.button(Rect2(x + i * (qw + 8), y, qw, 32), qual.name, true, "normal", 15, tip, p.quality == i):
			if p.quality != i:
				var ratio: float = p.price / g.ref_price(p)
				p.quality = i
				p.price = g.ref_price(p) * ratio
	y += 46

	var mk := ui.text("Marketing", Vector2(x, y), 15, "muted", true)
	ui.info_dot(Vector2(maxf(x + 84, mk.end.x + 12), y + 10), "Rendimientos decrecientes: el reconocimiento de marca sube con el presupuesto, pero cada dólar extra rinde menos. Si dejas de invertir, la gente se olvida de ti poco a poco.")
	ui.text(Lang.f("%s/mes", Fmt.money(p.marketing)), Vector2(x + w, y), 16, "text", true, "topright")
	y += 26
	var bw := (w - 25) / 6
	var msteps := [-10000.0, -1000.0, -100.0, 100.0, 1000.0, 10000.0]
	for i in msteps.size():
		var step: float = msteps[i]
		var label := ("+" if step > 0 else "−") + Fmt.short(absf(step)).replace("$", "")
		if ui.button(Rect2(x + i * (bw + 5), y, bw, 28), label, true, "normal", 13):
			p.marketing = max(0.0, p.marketing + step)
	y += 38
	ui.text(Lang.f("Reconocimiento de marca: %s (demanda +%s)", [Fmt.pct(p.awareness, 0), Fmt.pct(0.6 * p.awareness, 0)]), Vector2(x, y), 14, "text")
	y += 22
	ui.bar(Rect2(x, y, w, 8), p.awareness, "purple")
	y += 18
	ui.text(Lang.f("Reputación: %s/100 (demanda ×%s)", [Fmt.num(p.reputation), Fmt.num(0.7 + 0.6 * p.reputation / 100, 2)]), Vector2(x, y), 14, "text")
	ui.tooltip(Rect2(x, y, w, 20), "Depende de la calidad, de atender toda la demanda y de no cobrar mucho más que el mercado.")
	y += 22
	ui.bar(Rect2(x, y, w, 8), p.reputation / 100.0, "green" if p.reputation >= 50 else "orange")
	y += 26

	var inv := ui.text("Inventario", Vector2(x, y), 15, "muted", true)
	ui.info_dot(Vector2(maxf(x + 84, inv.end.x + 12), y + 10), "Compras cada mañana lo necesario para cubrir N días de ventas. Poco inventario = te quedas sin producto si sube la demanda. Mucho = más merma y costo de almacenamiento.")
	if ui.button(Rect2(x + w - 150, y - 4, 30, 26), "−", p.stock_days > 1 and not p.manager):
		p.stock_days -= 1
	ui.text(Lang.f("%d día%s", [p.stock_days, "s" if p.stock_days > 1 else ""]), Vector2(x + w - 75, y + 9), 15, "text", true, "center")
	if ui.button(Rect2(x + w - 30, y - 4, 30, 26), "+", p.stock_days < 30 and not p.manager):
		p.stock_days += 1
	y += 30
	y = ui.row(x, y, w, "En bodega", Lang.f("%s %s (%s)", [Fmt.num(p.stock), d.unit, Fmt.money(p.stock * p.avg_cost)]))
	y = ui.row(x, y, w, "Merma diaria", Fmt.pct(d.spoil, 1), "text", "Inventario que se pierde cada día (se pudre o se vuelve obsoleto).")
	if p.manager:
		ui.text("El gerente administra el inventario de esta línea.", Vector2(x, y), 13, "blue")
		y += 20
	y += 6
	ui.text("Proveedores y competencia", Vector2(x, y), 15, "muted", true)
	y += 26
	var disc := g.volume_discount(p)
	var nxt = null
	for t in D.VOLUME_TIERS:
		if t[1] > disc:
			nxt = t
			break
	y = ui.row(x, y, w, "Descuento por volumen", Fmt.pct(disc, 0), "text",
			"Economías de escala: el proveedor te da mejor precio si el mes pasado le compraste más.")
	if nxt != null:
		y = ui.row(x, y, w, Lang.f("Siguiente: %s al comprar", Fmt.pct(nxt[1], 0)), Lang.f("%s/mes", Fmt.money(nxt[0] * g.price_index)), "muted")
	y = ui.row(x, y, w, "Compras del mes pasado", Fmt.money(p.last_month_purchases))
	y = ui.row(x, y, w, "Competidores", str(p.competitors), "text",
			"Más competidores = menos clientes para ti. Llegan cuando el mercado deja mucho margen.")
	ui.row(x, y, w, "Cuota de mercado estimada", Fmt.pct(g.market_share(key), 0))


func _step_label(step: float) -> String:
	return ("+" if step > 0 else "−") + Fmt.short(absf(step)).replace("$", "")


# ---------- Finanzas ----------
func draw_finanzas(g: Game) -> void:
	var lw := 530.0
	ui.panel(Rect2(CX, CY, lw, CH), "Préstamos bancarios",
			"Apalancamiento: el préstamo te permite invertir antes, pero pagas intereses aunque vendas poco. Más deuda frente a tu patrimonio = tasa más alta.")
	var x := CX + 20
	var w := lw - 40
	var y := CY + 46
	var limit := g.credit_limit()
	loan_amount = clampf(loan_amount, 1000.0, max(1000.0, floorf(limit / 1000.0) * 1000.0))
	var rate := g.loan_rate(loan_amount)
	var b := g.balance()
	y = ui.row(x, y, w, "Tasa del banco central", Fmt.pct(g.policy_rate))
	y = ui.row(x, y, w, "Tasa que te ofrece el banco", Fmt.pct(rate), "orange",
			"Tasa del banco central + 3% + prima por riesgo según tu deuda/patrimonio.")
	y = ui.row(x, y, w, "Crédito disponible", Fmt.money(limit), "text", "Depende de tus activos fijos, tu inventario y tu EBITDA reciente.")
	y = ui.row(x, y, w, "Deuda actual", Fmt.money(g.debt()))
	y = ui.row(x, y, w, "Deuda / patrimonio", Fmt.num(g.debt() / b.patrimonio, 2) if b.patrimonio > 0 else "patrimonio negativo")
	y += 10
	ui.text("Monto", Vector2(x, y), 15, "muted", true)
	ui.text(Fmt.money(loan_amount), Vector2(x + w, y - 4), 24, "accent", true, "topright")
	y += 34
	var bw := (w - 20) / 5
	var lsteps := [-10000.0, -1000.0, 1000.0, 10000.0, 100000.0]
	for i in lsteps.size():
		if ui.button(Rect2(x + i * (bw + 5), y, bw, 28), _step_label(lsteps[i]), true, "normal", 13):
			loan_amount += lsteps[i]
	y += 40
	ui.text("Plazo", Vector2(x, y + 5), 15, "muted", true)
	var terms := [12, 24, 36, 60]
	for i in terms.size():
		if ui.button(Rect2(x + 80 + i * 92, y, 86, 28), Lang.f("%d meses", terms[i]), true, "normal", 13, null, loan_months == terms[i]):
			loan_months = terms[i]
	y += 40
	var pay := g.loan_payment(loan_amount, loan_months, rate)
	y = ui.row(x, y, w, "Cuota mensual (sistema francés)", Fmt.money(pay), "text", "Cuotas iguales. Al principio pagas más interés; al final, más capital.")
	y = ui.row(x, y, w, "Intereses totales", Fmt.money(pay * loan_months - loan_amount), "red")
	if ui.button(Rect2(x, y + 4, w, 38), "Solicitar préstamo", limit >= loan_amount, "primary"):
		ask(Lang.f("¿Pedir %s prestados?", Fmt.money(loan_amount)), Lang.f("%d cuotas de %s al %s anual. Intereses totales: %s.", [loan_months, Fmt.money(pay), Fmt.pct(rate), Fmt.money(pay * loan_months - loan_amount)]),
				"Sí, pedir el préstamo", g.take_loan.bind(loan_amount, loan_months))
	y += 58
	ui.text("Préstamos activos", Vector2(x, y), 15, "muted", true)
	y += 26
	if g.loans.is_empty():
		ui.text("No tienes deudas.", Vector2(x, y), 14, "muted")
	for loan in g.loans.duplicate():
		if y > CY + CH - 40:
			break
		ui.text(Lang.f("%s al %s · %d cuotas de %s", [Fmt.money(loan.principal), Fmt.pct(loan.rate), loan.months_left, Fmt.money(loan.payment)]),
				Vector2(x, y + 4), 14, "text")
		var payoff := g.prepay_amount(loan)
		if ui.button(Rect2(x + w - 90, y, 90, 26), "Prepagar", g.cash >= payoff, "normal", 13,
				Lang.f("Pagas hoy %s (el saldo más el interés de los días que van del mes) y te ahorras los intereses futuros.", Fmt.money(payoff))):
			ask("¿Pagar el préstamo completo?", Lang.f("Pagas hoy %s.", Fmt.money(payoff)), "Sí, pagarlo", g.prepay_loan.bind(loan))
		y += 32

	var rx := CX + lw + 12
	var rw := CW - lw - 12
	if not g.investing():
		_draw_taxes(g, rx, CY, rw, CH)
		return
	ui.panel(Rect2(rx, CY, rw, 316), "Bonos del gobierno",
			"Inversión sin riesgo que paga la tasa del banco central. Es el costo de oportunidad de tu dinero: cualquier inversión en el negocio debería rendir más que esto.")
	x = rx + 20
	w = rw - 40
	y = CY + 46
	y = ui.row(x, y, w, "Rendimiento anual", Fmt.pct(g.policy_rate), "green")
	y = ui.row(x, y, w, "Invertido", Fmt.money(g.bonds))
	y = ui.row(x, y, w, "Interés mensual estimado", Fmt.money(g.bonds * g.policy_rate / 12))
	y += 6
	bond_amount = max(1000.0, bond_amount)
	ui.text("Monto", Vector2(x, y + 4), 15, "muted", true)
	ui.text(Fmt.money(bond_amount), Vector2(x + w, y), 22, "accent", true, "topright")
	y += 34
	bw = (w - 15) / 4
	var bsteps := [-10000.0, -1000.0, 1000.0, 10000.0]
	for i in bsteps.size():
		if ui.button(Rect2(x + i * (bw + 5), y, bw, 28), _step_label(bsteps[i]), true, "normal", 13):
			bond_amount = max(1000.0, bond_amount + bsteps[i])
	y += 40
	bw = (w - 10) / 3
	if ui.button(Rect2(x, y, bw, 34), "Invertir", g.cash > 0, "primary"):
		ask(Lang.f("¿Invertir %s en bonos?", Fmt.money(min(bond_amount, g.cash))), Lang.f("Rinden %s al año, sin riesgo. Los puedes retirar cuando quieras.", Fmt.pct(g.policy_rate)),
				"Sí, invertir", g.buy_bonds.bind(bond_amount))
	if ui.button(Rect2(x + bw + 5, y, bw, 34), "Retirar", g.bonds > 0):
		act(g.sell_bonds(bond_amount))
	if ui.button(Rect2(x + 2 * (bw + 5), y, bw, 34), "Retirar todo", g.bonds > 0):
		act(g.sell_bonds(g.bonds))
	ui.wrap_text("Costo de oportunidad: si una sucursal te rinde menos que estos bonos, ese dinero estaría mejor aquí. Si rinde más, conviene invertirlo en el negocio.",
			Rect2(x, y + 50, w, 80), 13, "muted")

	_draw_taxes(g, rx, CY + 328, rw, CH - 328)


func _draw_taxes(g: Game, rx: float, y0: float, rw: float, ph: float) -> void:
	ui.panel(Rect2(rx, y0, rw, ph), "Impuestos y riesgo")
	var x := rx + 20
	var w := rw - 40
	var y := y0 + 46
	var taxes := 0.0
	for h in g.history.slice(max(0, g.history.size() - 12)):
		taxes += h.impuestos
	y = ui.row(x, y, w, "Impuesto a las utilidades", Fmt.pct(g.tax_rate, 0), "text",
			"Se paga cada mes sobre la utilidad antes de impuestos. Intereses y depreciación reducen la base (escudo fiscal).")
	y = ui.row(x, y, w, "Pérdidas por compensar", Fmt.money(g.loss_carry), "text",
			"Las pérdidas de meses anteriores se descuentan de las utilidades futuras antes de pagar impuestos.")
	y = ui.row(x, y, w, "Impuestos pagados (12 meses)", Fmt.money(taxes))
	y = ui.row(x, y, w, "Límite de sobregiro", Fmt.money(-g.overdraft_limit()), "text",
			"Si tu caja baja de este límite durante 20 días seguidos, el banco te declara en quiebra.")
	ui.row(x, y, w, "Días por debajo del límite", "%d/20" % g.overdraft_days, "red" if g.overdraft_days else "green")


# ---------- Crecimiento ----------
# ---------- Expansión: centro comercial y franquicias ----------
func draw_expansion(g: Game) -> void:
	var lw := 520.0
	ui.panel(Rect2(CX, CY, lw, CH), "Lugares en la ciudad",
			"Cada sucursal necesita un lugar: un terreno de la avenida o una vitrina del centro comercial. Las megatiendas solo caben en la avenida.")
	var x := CX + 20
	var w := lw - 40
	var y := CY + 46
	var on_avenue := g.locations.filter(func(l): return Game.plot_of(l) >= 0).size()
	var free_plots := g.free_plots().size()
	y = ui.row(x, y, w, "Terrenos libres", Lang.f("%d de %d", [free_plots, D.LOT_PLOTS.size()]), "green" if free_plots else "orange",
			"Los rivales también compran terrenos vacíos. Los locales de la competencia que compras quedan en su edificio.")
	y = ui.row(x, y, w, "Tus sucursales en la avenida", str(on_avenue))
	y += 6
	# Los dos centros comerciales: una pestañita para cada uno
	var half := (w - 8) / 2
	for mi in D.MALLS.size():
		var lbl: String = "Frente a la oficina" if mi == 0 else "En la playa"
		if ui.button(Rect2(x + mi * (half + 8), y, half, 30), lbl, true, "normal", 14, null, exp_mall == mi):
			exp_mall = mi
	y += 40
	var md: Dictionary = D.MALLS[exp_mall]
	if not g.has_mall(exp_mall):
		ui.wrap_text(Mall.mall_pitch(g, exp_mall), Rect2(x, y, w, 60), 14, "muted")
		y += 66
		var cost := g.mall_cost(exp_mall)
		marks["comprar_cc"] = Rect2(x, y, w, 40)
		if ui.button(Rect2(x, y, w, 40), Lang.f("Construir %s (%s)", [Lang.noun(md.name), Fmt.money(cost)]), g.cash >= cost, "primary", 16, Mall.mall_pitch(g, exp_mall)):
			ask(Lang.f("¿Comprar %s por %s?", [Lang.noun(md.name), Fmt.money(cost)]), Mall.mall_pitch(g, exp_mall), Lang.f("Sí, construir (%s)", Fmt.short(cost)), g.buy_mall.bind(exp_mall))
	else:
		var n := int(D.MALL.slots)
		var base := exp_mall * n
		var by_slot := {}
		for loc in g.locations:
			var m := Game.mall_of(loc)
			if m >= base and m < base + n:
				by_slot[m - base] = loc
		var rivals := 0
		for i in n:
			if g.rival_mall.has(str(base + i)):
				rivals += 1
		y = ui.row(x, y, w, "Vitrinas tuyas / de rivales", Lang.f("%d / %d de %d", [by_slot.size(), rivals, n]), "accent")
		y = ui.row(x, y, w, "Mantenimiento", Lang.f("%s/mes", Fmt.money(md.upkeep * g.price_index)), "red")
		y += 6
		var cols := 4
		var tw := (w - (cols - 1) * 8) / cols
		var th := 50.0
		for i in n:
			var r := Rect2(x + (i % cols) * (tw + 8), y + (i / cols) * (th + 8), tw, th)
			var loc = by_slot.get(i)
			var rk = g.rival_mall.get(str(base + i))
			if rk != null:
				var rv := D.rival_for(rk)
				ui.rect(r, Color(rv.color, 0.25), 8)
				ui.rect(r, Color(rv.color, 0.8), 8, 1)
				ui.text(Lang.f("Vitrina %d", i + 1), r.position + Vector2(10, 6), 13, "muted", true)
				ui.text(rv.company, r.position + Vector2(10, 27), 12, "text", false, "topleft", tw - 16)
				ui.tooltip(r, Lang.f("%s arrienda esta vitrina (%s). Te paga alquiler. Ve y apreta E para comprársela.", [rv.company, Lang.noun(D.PRODUCTS[rk].name)]))
			elif loc == null:
				ui.rect(r, "panel2", 8)
				dashed_rect(r, "border")
				ui.text(Lang.f("Vitrina %d", i + 1), r.position + Vector2(10, 6), 13, "muted", true)
				ui.text("Disponible", r.position + Vector2(10, 27), 13, "green")
				ui.tooltip(r, "Ve al centro comercial y apreta E frente a la vitrina.")
			else:
				var pc: Color = Blueprints.PRODUCT_COLORS[loc.product]
				ui.rect(r, Color(pc, 0.35), 8)
				ui.rect(r, pc, 8, 1)
				ui.text(Lang.f("Vitrina %d", i + 1), r.position + Vector2(10, 6), 13, "text", true)
				ui.text(Lang.f("%s · %s", [D.SIZES[loc.size].name, D.PRODUCTS[loc.product].name]), r.position + Vector2(10, 27), 12, "text", false, "topleft", tw - 16)
				ui.tooltip(r, Lang.f("%s de %s · vendió %s ayer · demanda %s", [D.SIZES[loc.size].name, Lang.noun(D.PRODUCTS[loc.product].name), Fmt.num(loc.sold), Fmt.num(loc.demand)]))
				if go_to_loc != null and ui.hover(r):
					ui.rect(r, "accent", 8, 2)
					if ui.clicked:
						go_to_loc.call(loc)

	# Franquicias
	var rx := CX + lw + 12
	var rw := CW - lw - 12
	ui.panel(Rect2(rx, CY, rw, CH), "Franquicias en otras ciudades",
			Lang.f("Tú pones la marca, el manual y la capacitación (desde %s); el franquiciado pone el local, el personal y el inventario. Te paga %d%% de lo que vende, todos los días. No ocupa lugar en la ciudad, pero unos franquiciados atienden mejor que otros y uno malo te puede bajar la reputación.", [Fmt.money(g.franchise_cost("cafe")), roundi(D.FRANCHISE.royalty * 100)]))
	x = rx + 20
	w = rw - 40
	y = CY + 46
	var total := 0.0
	var last := 0.0
	for f in g.franchises:
		total += g.franchise_royalty_monthly(f)
		if f.last_royalty != null:
			last += float(f.last_royalty)
	y = ui.row(x, y, w, "Franquicias", str(g.franchises.size()), "accent")
	y = ui.row(x, y, w, "Regalías del mes pasado", Fmt.money(last), "green" if last > 0 else "muted")
	y = ui.row(x, y, w, "Regalías esperadas al mes", Fmt.money(total), "green" if total > 0 else "muted",
			"Con tu precio, reputación y conocimiento de marca de hoy. Si subes la reputación o el marketing, venden más.")
	y += 4
	for key in D.PRODUCT_ORDER:
		var fcost := g.franchise_cost(key)
		var p: Dictionary = g.products[key]
		var d: Dictionary = D.PRODUCTS[key]
		var mine := g.franchises_of(key)
		var block := g.franchise_block(key)
		ui.rect(Rect2(x - 6, y - 2, w + 12, 40), "panel2", 6)
		ui.text(d.name, Vector2(x, y + 9), 15, "text" if p.unlocked else "muted", true)
		ui.text(Lang.f("%d/%d", [mine.size(), int(D.FRANCHISE.max)]), Vector2(x + 170, y + 9), 14, "muted")
		var tip := block if block else Lang.f("Vender una franquicia de %s: pagas %s y el franquiciado abre en otra ciudad. Cada una deja unos %s al mes de regalías con tus números de hoy.", [Lang.noun(d.name), Fmt.money(fcost), Fmt.money(g.franchise_royalty_monthly({"product": key, "quality": 0.93}))])
		if ui.button(Rect2(x + w - 230, y + 2, 230, 32), Lang.f("Vender franquicia (%s)", Fmt.short(fcost)), block == "" and g.cash >= fcost, "normal", 14, tip):
			ask(Lang.f("¿Vender una franquicia de %s?", Lang.noun(d.name)), tip, Lang.f("Sí, vender (%s)", Fmt.short(fcost)), g.open_franchise.bind(key))
		y += 46
	y += 4
	ui.text("Tus franquicias", Vector2(x, y), 15, "muted", true)
	y += 24
	var area := Rect2(rx + 10, y, rw - 20, CY + CH - y - 10)
	var rows := 34.0
	var sc_y := scroll_area("franquicias", area, g.franchises.size() * rows)
	ui.set_clip(area)
	for i in g.franchises.size():
		var f: Dictionary = g.franchises[i]
		var ry := area.position.y + i * rows - sc_y
		if ry + rows < area.position.y or ry > area.end.y:
			continue
		var cy := ry + rows / 2 - 2
		ui.circle(Vector2(x + 6, cy), 5, Blueprints.PRODUCT_COLORS[f.product])
		ui.text(f.city, Vector2(x + 18, cy), 14, "text", true, "midleft", 150)
		ui.text(D.PRODUCTS[f.product].name, Vector2(x + 160, cy), 13, "muted", false, "midleft", 95)
		var q: float = f.quality
		var qn := "Excelente" if q >= 1.05 else ("Buena" if q >= 0.9 else ("Regular" if q >= 0.8 else "Mala"))
		ui.text(qn, Vector2(x + 262, cy), 13, "green" if q >= 0.9 else ("orange" if q >= 0.8 else "red"), false, "midleft")
		ui.tooltip(Rect2(x + 262, ry, 75, rows), "Cómo atiende el franquiciado: los que atienden mal venden menos y a veces te bajan la reputación.")
		ui.text(Lang.f("%s/mes", Fmt.short(g.franchise_royalty_monthly(f))), Vector2(x + w - 102, cy), 14, "green", true, "midright")
		if ui.button(Rect2(x + w - 90, cy - 13, 90, 26), "Terminar", true, "danger", 12, "Terminas el contrato: deja de pagarte regalías y no recuperas lo que pagaste."):
			ask(Lang.f("¿Terminar la franquicia de %s?", f.city), "Deja de pagarte regalías. Lo que pagaste por el contrato no se recupera.", "Sí, terminar", g.close_franchise.bind(f), true)
	ui.set_clip(null)
	if g.franchises.is_empty():
		ui.wrap_text(Lang.f("Todavía no tienes franquicias. Necesitas %d sucursales propias del negocio y reputación de %d o más.", [int(D.FRANCHISE.min_locs), roundi(D.FRANCHISE.min_rep)]),
				Rect2(area.position.x + 10, area.position.y + 6, area.size.x - 20, 60), 14, "muted")


func draw_crecimiento(g: Game) -> void:
	var lw := 560.0
	ui.panel(Rect2(CX, CY, lw, 300), "Sistemas de gestión (oficina central)",
			"Deseconomías de escala: coordinar muchas sucursales cuesta cada vez más. Invertir en sistemas baja ese costo y te deja seguir creciendo.")
	var x := CX + 20
	var w := lw - 40
	var y := CY + 46
	var lvl: Array = D.HQ_LEVELS[g.hq_level]
	var factor: float = lvl[2]
	var corp := g.corporate_cost_monthly()
	y = ui.row(x, y, w, "Nivel actual", Lang.f("%d · %s", [g.hq_level, lvl[0]]), "accent")
	y = ui.row(x, y, w, "Sucursales", str(g.locations.size()))
	y = ui.row(x, y, w, "Gastos corporativos al mes", Fmt.money(corp), "red" if corp > 0 else "text",
			"Crecen más rápido que el número de sucursales (a partir de la sexta).")
	var cost = g.hq_upgrade_cost()
	if cost == null:
		ui.wrap_text("Tienes el mejor sistema de gestión. Tus gastos corporativos son 88% más bajos que al empezar.",
				Rect2(x, y + 8, w, 60), 14, "green")
	else:
		var nxt: Array = D.HQ_LEVELS[g.hq_level + 1]
		var saving: float = corp * (1 - nxt[2] / factor)
		y = ui.row(x, y, w, Lang.f("Siguiente: %s", nxt[0]), Lang.f("−%d%% de gastos", roundi((1 - nxt[2] / factor) * 100)))
		y = ui.row(x, y, w, "Ahorro mensual hoy", Fmt.money(saving), "green",
				"Con más sucursales el ahorro crece. La inversión se deprecia en 5 años como cualquier activo.")
		var months = cost / saving if saving > 0 else null
		y = ui.row(x, y, w, "Se paga sola en", Lang.f("%d meses", roundi(months)) if months != null and months < 999 else "aún no conviene")
		if ui.button(Rect2(x, y + 6, w, 40), Lang.f("Instalar por %s", Fmt.money(cost)), g.cash >= cost, "primary"):
			ask(Lang.f("¿Instalar %s?", nxt[0]), "Baja los gastos corporativos de tener muchas sucursales.", Lang.f("Sí, instalar (%s)", Fmt.short(cost)), g.upgrade_hq)

	var y0 := CY + 312
	if g.investing():
		_draw_fund(g, y0, lw, w)
	else:
		_draw_office_looks(g, y0, lw)
	_draw_titles(g, lw)


## Aspecto de la oficina: los cuatro, cuál tienes, cuáles ya se pueden comprar y desde qué rango.
func _draw_office_looks(g: Game, y0: float, lw: float) -> void:
	ui.panel(Rect2(CX, y0, lw, CH - 312), "Aspecto de la oficina")
	var x := CX + 20
	var w := lw - 40
	var y := y0 + 46
	for i in D.OFFICE_LOOKS.size():
		var look: Array = D.OFFICE_LOOKS[i]
		var have: bool = i <= g.office_look
		var open: bool = g.rank >= int(look[1])
		ui.text(look[0], Vector2(x, y + 6), 15, "accent" if i == g.office_look else ("text" if open else "muted"), i == g.office_look)
		var r := Rect2(x + w - 150, y, 150, 30)
		if i == g.office_look:
			ui.text("La tuya", r.get_center(), 14, "green", true, "center")
		elif have:
			ui.text("—", r.get_center(), 14, "muted", false, "center")
		elif not open:
			ui.text(Lang.f("Rango: %s", D.RANKS[int(look[1])][1]), Vector2(r.end.x, r.get_center().y), 13, "muted", false, "midright")
		else:
			var cost := g.office_look_cost(i)
			if ui.button(r, Lang.f("Remodelar (%s)", Fmt.short(cost)), g.cash >= cost and i == g.office_look + 1, "primary", 13):
				act(g.buy_office_look(i))
		y += 38
	if open_office_decor != null and ui.button(Rect2(x, y + 6, w, 36),
			Lang.f("Personalizar la oficina (%d/%d)", [g.office_decor.size(), D.OFFICE_DECOR.size()]), true, "normal", 14):
		open_office_decor.call()


func _draw_fund(g: Game, y0: float, lw: float, w: float) -> void:
	ui.panel(Rect2(CX, y0, lw, CH - 312), "Fondo de inversión (bolsa)",
			"Riesgo y rentabilidad: en promedio rinde más que los bonos, pero sube y baja todos los días y cae fuerte en recesión.")
	var x := CX + 20
	var y := y0 + 46
	var expected: float = D.FUND_RETURN[g.phase]
	y = ui.row(x, y, w, "Invertido (valor de mercado)", Fmt.money(g.fund), "accent")
	y = ui.row(x, y, w, Lang.f("Rendimiento esperado en %s", Lang.noun(D.PHASES[g.phase].name)), Fmt.pct(expected),
			"green" if expected >= 0 else "red", "Cambia con el ciclo económico. Los bonos rinden la tasa del banco central.")
	y = ui.row(x, y, w, "Bonos (sin riesgo)", Fmt.pct(g.policy_rate))
	fund_amount = max(10000.0, fund_amount)
	ui.text("Monto", Vector2(x, y + 6), 15, "muted", true)
	ui.text(Fmt.money(fund_amount), Vector2(x + w, y + 2), 22, "accent", true, "topright")
	y += 36
	var bw := (w - 15) / 4
	var fsteps := [-100000.0, -10000.0, 10000.0, 100000.0]
	for i in fsteps.size():
		if ui.button(Rect2(x + i * (bw + 5), y, bw, 28), _step_label(fsteps[i]), true, "normal", 13):
			fund_amount = max(10000.0, fund_amount + fsteps[i])
	y += 38
	bw = (w - 10) / 3
	if ui.button(Rect2(x, y, bw, 34), "Invertir", g.cash > 0, "primary"):
		ask(Lang.f("¿Invertir %s en el fondo?", Fmt.money(min(fund_amount, g.cash))), "Sube y baja todos los días, y cae fuerte en recesión.", "Sí, invertir", g.invest_fund.bind(fund_amount))
	if ui.button(Rect2(x + bw + 5, y, bw, 34), "Retirar", g.fund > 0):
		act(g.withdraw_fund(fund_amount))
	if ui.button(Rect2(x + 2 * (bw + 5), y, bw, 34), "Retirar todo", g.fund > 0):
		act(g.withdraw_fund(g.fund))


func _draw_titles(g: Game, lw: float) -> void:
	var rx := CX + lw + 12
	var rw := CW - lw - 12
	ui.panel(Rect2(rx, CY, rw, CH), "Títulos")
	var x := rx + 20
	var w := rw - 40
	var y := CY + 46
	var mins := g.play_seconds / 60.0
	y = ui.row(x, y, w, "Tiempo de juego", Lang.f("%d h %02d min", [int(mins / 60), int(mins) % 60]) if mins >= 60 else Lang.f("%d min", roundi(mins)))
	y = ui.row(x, y, w, "Modo", D.MODES[g.mode].name, "accent")
	if g.win_seconds != null:
		y = ui.row(x, y, w, "Meta cumplida en", Lang.f("%d min", roundi(g.win_seconds / 60.0)), "green")
	else:
		y = ui.row(x, y, w, "Meta", "Imperio ($10 M) en unos 40 min" if g.mode == "normal" else "Mil millonario ($1.000 M)", "muted")
	y += 8
	var info := g.rank_info()
	var idx: int = info[0]
	var ranks := g.ranks()
	for i in ranks.size():
		var done := i <= idx
		var c := "accent" if i == idx else ("green" if done else "muted")
		ui.circle(Vector2(x + 6, y + 11), 6 if done else 5, c)
		if not done:
			ui.circle(Vector2(x + 6, y + 11), 3.5, "panel")
		ui.text(ranks[i][1], Vector2(x + 22, y), 16, c, i == idx)
		ui.text(Fmt.short(ranks[i][0]) if ranks[i][0] else "—", Vector2(x + w, y), 15, c, false, "topright")
		if i == idx + 1:
			var lo := rank_lo(idx)
			ui.bar(Rect2(x + 24, y + 24, w - 24, 6), (info[3] - lo) / (ranks[i][0] - lo), "accent")
			y += 12
		y += 32
	var tip := ("En modo normal el juego termina en Imperio. Para seguir con más títulos, empieza una partida en modo inversionista."
			if g.mode == "normal" else
			"Para seguir creciendo: sistemas de gestión para que los gastos corporativos no se coman la utilidad, y la caja trabajando en el fondo o en bonos.")
	ui.wrap_text(tip, Rect2(x, y + 6, w, 120), 13, "muted")


# ---------- Reportes ----------
func draw_reportes(g: Game) -> void:
	var lw := 560.0
	ui.panel(Rect2(CX, CY, lw, CH), "Estado de resultados")
	var cols := [["Mes en curso", Game.statement(g.ledger)]]
	for k in [[1, "Mes pasado"], [2, "Hace 2 meses"]]:
		cols.append([k[1], Game.statement(g.history[-k[0]]) if g.history.size() >= k[0] else null])
	var xs := [CX + 330, CX + 440, CX + lw - 16]
	for i in cols.size():
		ui.text(cols[i][0], Vector2(xs[i], CY + 16), 13, "muted", true, "topright")
	var lines := [
		["Ingresos", ["ingresos"], 1], ["Costo de ventas", ["costo_ventas"], -1], ["Utilidad bruta", ["utilidad_bruta"], 0],
		["Salarios", ["salarios"], -1], ["Alquiler", ["alquiler"], -1], ["Marketing", ["marketing"], -1],
		["Almacenamiento", ["almacenamiento"], -1], ["Mermas", ["mermas"], -1], ["Gerentes", ["gerentes"], -1],
		["Mantenimiento de fábricas", ["fabricas"], -1], ["Gastos corporativos", ["corporativo"], -1],
		["Contratación e indemnizaciones", ["contratacion", "indemnizaciones"], -1],
		["Multas y representación", ["multas", "representacion"], -1],
		["EBITDA", ["ebitda"], 0], ["Depreciación y amortización", ["depreciacion"], -1], ["Utilidad operativa (EBIT)", ["ebit"], 0],
		["Intereses pagados", ["intereses"], -1], ["Ingresos financieros", ["ingresos_financieros"], 1],
		["Pérdida por venta de activos", ["perdida_activos"], -1], ["Utilidad antes de impuestos", ["ebt"], 0],
		["Impuestos", ["impuestos"], -1], ["Utilidad neta", ["utilidad_neta"], 0],
	]
	var tips := {
		"EBITDA": "Lo que genera la operación antes de intereses, impuestos, depreciación y amortización.",
		"Utilidad bruta": "Ingresos − costo de la mercancía vendida.",
		"Depreciación y amortización": "La inversión en sucursales, fábricas y licencias repartida en 5 años. No es salida de caja.",
		"Gastos corporativos": "Deseconomías de escala: la oficina central crece más rápido que el número de sucursales (desde la 6.ª).",
		"Mermas": "Producto que se pudrió, se volvió obsoleto o se perdió.",
		"Utilidad neta": "Lo que realmente ganaste. Esta es la última línea.",
	}
	var y := CY + 42
	for ln in lines:
		var total: bool = ln[2] == 0
		if total:
			ui.line(Vector2(CX + 16, y - 2), Vector2(CX + lw - 16, y - 2), "border")
		ui.text(ln[0], Vector2(CX + 16, y + 2), 14, "text" if total else "muted", total)
		if tips.has(ln[0]):
			ui.tooltip(Rect2(CX + 16, y, 280, 22), tips[ln[0]])
		for i in cols.size():
			var st = cols[i][1]
			if st == null:
				ui.text("—", Vector2(xs[i], y + 2), 14, "muted", false, "topright")
				continue
			var v := 0.0
			for k in ln[1]:
				v += st[k]
			v = v if ln[2] >= 0 else -v
			var c := sc(v) if total else ("muted" if absf(v) < 0.5 else "text")
			ui.text(Fmt.money(v), Vector2(xs[i], y + 2), 14, c, total, "topright")
		y += 26 if total else 24

	var rx := CX + lw + 12
	var rw := CW - lw - 12
	var b := g.balance()
	ui.panel(Rect2(rx, CY, rw, 300), "Balance general",
			"Foto de la empresa hoy: lo que tienes (activos) = lo que debes (pasivos) + lo que es tuyo (patrimonio).")
	var x := rx + 20
	var w := rw - 40
	y = CY + 44
	var b_rows := [["Caja", "caja"], ["Bonos", "bonos"], ["Fondo de inversión", "fondo"], ["Inventario", "inventario"],
			["Activos fijos netos", "activos_fijos"]]
	if not g.investing():
		b_rows = b_rows.filter(func(it): return not it[1] in ["bonos", "fondo"])
	for it in b_rows:
		y = ui.row(x, y, w, it[0], Fmt.money(b[it[1]]), "text", null, 14)
	y = ui.row(x, y, w, "Total activos", Fmt.money(b.activos), "accent", null, 14)
	y += 4
	y = ui.row(x, y, w, "Préstamos", Fmt.money(b.deuda), "text", null, 14)
	y = ui.row(x, y, w, "Sobregiro", Fmt.money(b.sobregiro), "red" if b.sobregiro else "text", null, 14)
	y = ui.row(x, y, w, "Total pasivos", Fmt.money(b.pasivos), "accent", null, 14)
	y += 2
	ui.row(x, y, w, "Patrimonio", Fmt.money(b.patrimonio), sc(b.patrimonio), null, 15)

	var y0 := CY + 312
	ui.panel(Rect2(rx, y0, rw, CH - 312), "Indicadores clave (mes pasado)")
	y = y0 + 44
	if g.history.is_empty():
		ui.text("Disponibles al cerrar el primer mes.", Vector2(x, y), 14, "muted")
		return
	var st := Game.statement(g.history[-1])
	var rev: float = st.ingresos if st.ingresos else 1.0
	var eq: float = b.patrimonio
	var cost_capital := g.policy_rate + 0.04
	var eva: float = st.utilidad_neta - max(0.0, eq) * cost_capital / 12
	var fixed := 0.0
	for k in D.PRODUCT_ORDER:
		if g.products[k].unlocked:
			fixed += g.fixed_costs_daily(k) * 30
	var kpis := [
		["Margen bruto", Fmt.pct(st.utilidad_bruta / rev), null],
		["Margen EBITDA", Fmt.pct(st.ebitda / rev), null],
		["Margen neto", Fmt.pct(st.utilidad_neta / rev), null],
		["ROE anualizado", Fmt.pct(st.utilidad_neta * 12 / eq) if eq > 0 else "—", "Retorno sobre el patrimonio: utilidad neta anual ÷ patrimonio."],
		["ROA anualizado", Fmt.pct(st.utilidad_neta * 12 / b.activos) if b.activos > 0 else "—", "Retorno sobre activos: qué tan bien usas todo lo que tienes."],
		["Meses de caja", Fmt.num(g.cash / fixed, 1) if fixed > 0 and g.cash > 0 else "0",
		 "Cuántos meses podrías pagar los costos fijos con la caja actual si no vendieras nada."],
		["Costo de oportunidad del capital", Lang.f("%s/mes", Fmt.money(max(0.0, eq) * cost_capital / 12)),
		 Lang.f("Lo que tu patrimonio ganaría en otra inversión de riesgo similar (tasa BC + 4%% = %s).", Fmt.pct(cost_capital))],
		["Valor económico agregado (EVA)", Fmt.money(eva), "Utilidad neta − costo de oportunidad. Si es negativo, tu dinero rendiría más en otro lado."],
	]
	for k in kpis:
		y = ui.row(x, y, w, k[0], k[1], sc(eva) if k[0].begins_with("Valor") else "text", k[2], 14)


# ---------- Noticias ----------
func draw_noticias(g: Game) -> void:
	unread = 0
	ui.panel(Rect2(CX, CY, CW, CH), "Noticias y eventos")
	var area := Rect2(CX + 10, CY + 44, CW - 20, CH - 54)
	var rows := 30.0
	var s := scroll_area("news", area, g.news.size() * rows)
	ui.set_clip(area)
	var n_items := g.news.size()
	for i in n_items:
		var n: Dictionary = g.news[n_items - 1 - i]
		var y := area.position.y + i * rows - s
		if y + rows < area.position.y or y > area.end.y:
			continue
		var m := int(n.day) / 30
		ui.text(Lang.f("%s año %d", [Lang.month_short(D.MONTHS[m % 12]), m / 12 + 1]), Vector2(area.position.x + 10, y + 4), 13, "muted")
		ui.text(n.text, Vector2(area.position.x + 130, y + 3), 15, ImUI.KIND_COLOR[n.kind], false, "topleft", area.size.x - 140)
	ui.set_clip(null)


# ---------- Conceptos ----------
## En el modo normal no se habla de bolsa ni de bonos.
static func concepts_for(g: Game) -> Array:
	if g.investing():
		return D.CONCEPTS
	return D.CONCEPTS.filter(func(c): return not ("bonos" in c[1] or "bolsa" in c[1]))


func draw_conceptos(g: Game) -> void:
	ui.panel(Rect2(CX, CY, CW, CH), "Conceptos de economía y rentabilidad que usa el juego")
	var area := Rect2(CX + 10, CY + 44, CW - 20, CH - 54)
	var colw := (area.size.x - 30) / 2
	var concepts := concepts_for(g)
	var heights: Array = cached("concept_heights_%d" % concepts.size(), func():
		return concepts.map(func(c): return ui.wrap_height(c[1], colw - 24, 14) + 48))
	var rows := []
	for i in range(0, heights.size(), 2):
		rows.append(heights.slice(i, i + 2).max())
	var total := 0.0
	for h in rows:
		total += h
	var s := scroll_area("concepts", area, total + 10)
	ui.set_clip(area)
	var y := area.position.y - s
	for i in range(0, concepts.size(), 2):
		var h: float = rows[i / 2]
		for j in 2:
			if i + j >= concepts.size():
				break
			var c: Array = concepts[i + j]
			var x := area.position.x + 10 + j * (colw + 10)
			if y + h > area.position.y and y < area.end.y:
				ui.rect(Rect2(x, y, colw, h - 8), "panel2", 8)
				ui.text(c[0], Vector2(x + 12, y + 8), 16, "accent", true)
				ui.wrap_text(c[1], Rect2(x + 12, y + 32, colw - 24, h), 14, "text")
		y += h
	ui.set_clip(null)


# ---------- confirmación antes de gastar ----------
## Pide confirmar antes de hacer algo importante. `action` devuelve [ok, mensaje] (como las acciones de Game).
func ask(title: String, detail: String, yes: String, action: Callable, danger := false, back = null) -> void:
	confirm = {"title": title, "detail": detail, "yes": yes, "action": action, "danger": danger, "back": back}
	modal = "confirmar"


func draw_confirm() -> void:
	if confirm == null:
		modal = null
		return
	match confirm_box(ui, confirm.title, confirm.detail, confirm.yes, game.cash, confirm.danger):
		1:
			var action: Callable = confirm.action
			modal = confirm.back   # algunas preguntas vuelven a su ventana (decorar)
			confirm = null
			act(action.call())
		2:
			modal = confirm.back
			confirm = null


## Caja de confirmación (también la usa la ciudad). Devuelve 0 = nada, 1 = sí, 2 = no.
static func confirm_box(u: ImUI, title: String, detail: String, yes: String, cash: float, danger := false) -> int:
	var bw := 620.0
	var th := u.wrap_height(detail, bw - 80, 16)
	var bh := 190.0 + th
	var box := Rect2(W / 2 - bw / 2, H / 2 - bh / 2, bw, bh)
	var accent: Color = ImUI.COL.red if danger else ImUI.COL.accent
	u.rect(box.grow(8), Color(0, 0, 0, 0.35), 24)
	u.rect(box, Color8(18, 22, 30), 18)
	u.rect(box, Color(accent, 0.6), 18, 1.5)
	u.circle(box.position + Vector2(52, 52), 24, accent)
	Icons.draw(u, "question", box.position + Vector2(52, 52), 30, Color8(16, 20, 30))
	u.text(title, box.position + Vector2(92, 36), 24, "text", true, "topleft", bw - 120)
	u.wrap_text(detail, Rect2(box.position.x + 40, box.position.y + 92, bw - 80, th), 16, Color8(205, 212, 224))
	u.text(Lang.f("Caja: %s", Fmt.money(cash)), Vector2(box.get_center().x, box.end.y - 84), 14, sc(cash), true, "center")
	var res := 0
	if u.button(Rect2(box.position.x + 40, box.end.y - 62, 260, 42), yes, true, "danger" if danger else "primary", 16):
		res = 1
	if u.button(Rect2(box.end.x - 300, box.end.y - 62, 260, 42), "No, cancelar", true, "normal", 16):
		res = 2
	return res


# ---------- decorar una sucursal ----------
func draw_decor() -> void:
	var g := game
	var loc = g.find_location(decor_loc)
	if loc == null:
		modal = null
		return
	var bw := 960.0
	var bh := 660.0
	var box := Rect2(W / 2 - bw / 2, H / 2 - bh / 2, bw, bh)
	ui.rect(box.grow(8), Color(0, 0, 0, 0.35), 24)
	ui.rect(box, Color8(18, 22, 30), 18)
	ui.rect(box, Color(ImUI.COL.accent, 0.5), 18, 1.5)
	var name := Lang.f("%s de %s", [D.SIZES[loc.size].name, Lang.noun(D.PRODUCTS[loc.product].name)])
	ui.text("DECORAR Y EQUIPAR", box.position + Vector2(36, 26), 13, "accent", true)
	ui.text(name, box.position + Vector2(36, 44), 26, "text", true)
	ui.text(Lang.f("Caja: %s · %s estrellas", [Fmt.money(g.cash), Fmt.num(Game.stars_of(loc), 1)]), Vector2(box.end.x - 36, box.position.y + 50), 15, sc(g.cash), true, "topright")
	ui.wrap_text("Cada artículo se compra una vez para este local (es inversión: se deprecia en 5 años y se vende con el local). En una megatienda cuesta más que en un puesto. Lo que compres se ve en la ciudad.",
			Rect2(box.position.x + 36, box.position.y + 84, bw - 72, 40), 14, "muted")
	var cols := 2
	var cw := (bw - 72 - 16) / cols
	var ch := 104.0
	for i in D.UPGRADES.size():
		var u: Dictionary = D.UPGRADES[i]
		var r := Rect2(box.position.x + 36 + (i % cols) * (cw + 16), box.position.y + 134 + (i / cols) * (ch + 10), cw, ch)
		var owned: bool = u.key in loc.get("upgrades", [])
		ui.rect(r, Color8(28, 34, 44) if not owned else Color8(26, 52, 40), 12)
		ui.rect(r, Color(ImUI.COL.green if owned else ImUI.COL.border, 0.7), 12, 1)
		ui.circle(r.position + Vector2(30, 30), 18, ImUI.COL.green if owned else Color8(60, 70, 88))
		Icons.draw(ui, u.icon, r.position + Vector2(30, 30), 22, Color.WHITE)
		ui.text(u.name, r.position + Vector2(58, 14), 16, "text", true, "topleft", cw - 186)
		ui.wrap_text(u.desc, Rect2(r.position.x + 58, r.position.y + 38, cw - 186, 62), 13, "muted", false, 2.0)
		var cost := g.decor_cost(loc, u.key)
		if owned:
			ui.text("Instalado", Vector2(r.end.x - 16, r.get_center().y), 15, "green", true, "midright")
		elif ui.button(Rect2(r.end.x - 124, r.get_center().y - 18, 110, 36), Fmt.short(cost), g.cash >= cost, "primary", 15):
			var id: int = loc.id
			var key: String = u.key
			var buy := func():
				var l = game.find_location(id)
				return game.buy_decor(l, key) if l != null else [false, ""]
			ask(Lang.f("¿Comprar %s?", Lang.noun(u.name)), Lang.f("%s Para tu %s.", [u.desc, Lang.noun(name)]), Lang.f("Sí, comprar (%s)", Fmt.short(cost)),
					buy, false, "decorar")
			return
	if ui.button(Rect2(box.get_center().x - 120, box.end.y - 60, 240, 40), "Cerrar", true, "normal", 16):
		modal = null


# ---------- microdecisiones (en la barra de abajo) ----------
func draw_micro_bar(r: Rect2) -> void:
	var m: Dictionary = game.micro
	var col: Color = ImUI.COL.orange
	ui.rect(r, Color(col, 0.18), 8)
	ui.rect(r, Color(col, 0.7), 8, 1)
	Icons.draw(ui, "question", Vector2(r.position.x + 16, r.get_center().y), 18, col)
	var left := maxi(0, int(m.expires) - game.day)
	var tw := ui.text(Lang.f("%s (%d d)", [m.title, left]), Vector2(r.position.x + 30, r.get_center().y), 14, "text", true, "midleft", 330)
	ui.tooltip(Rect2(r.position.x, r.position.y, tw.end.x - r.position.x, r.size.y), m.text)
	var x := tw.end.x + 12
	var n: int = m.options.size()
	var avail: float = r.end.x - x - 6
	var bw := (avail - 6 * (n - 1)) / n
	for i in n:
		var o: Dictionary = m.options[i]
		if ui.button(Rect2(x + i * (bw + 6), r.position.y + 3, bw, r.size.y - 6), o.label, true, "normal", 12, o.detail):
			var res := game.resolve_micro(i)
			say(res[1], "good" if res[0] else "bad")
			return


# ---------- Rivales: catálogo de personajes y ranking ----------
func draw_rivales(g: Game) -> void:
	var cols := 4
	var cw := (CW - 12 * (cols - 1)) / cols
	var ch := 128.0
	for i in D.RIVALS.size():
		var r: Dictionary = D.RIVALS[i]
		var rect := Rect2(CX + (i % cols) * (cw + 12), CY + (i / cols) * (ch + 10), cw, ch)
		var active := g.rival_active(r)
		var st := g.rival_state(r.key)
		var hot := ui.hover(rect)
		ui.rect(rect, Color8(26, 32, 42) if rival_sel != r.key else Color(r.color, 0.18), 12)
		ui.rect(rect, Color(r.color, 0.9 if rival_sel == r.key else (0.5 if hot else 0.25)), 12, 2 if rival_sel == r.key else 1)
		if hot and ui.clicked:
			rival_sel = r.key
		var c := rect.position + Vector2(38, 40)
		rival_badge(ui, r, c, 26, not active)
		ui.text(r.company, rect.position + Vector2(74, 18), 16, "text" if active else "muted", true, "topleft", cw - 84)
		ui.text(r.name, rect.position + Vector2(74, 40), 13, "muted", false, "topleft", cw - 84)
		ui.text(D.RIVAL_STYLES[r.style][0], rect.position + Vector2(74, 58), 12, Notifications.light(r.color, 0.3), true, "topleft", cw - 84)
		if not active:
			var why := Lang.f("Aparece el día %d", int(r.from)) if g.day < int(r.get("from", 0)) else "Aún no compites con él"
			ui.text(why, rect.position + Vector2(16, ch - 30), 13, "muted")
			continue
		var h: float = st.hostility
		ui.text("Hostilidad", rect.position + Vector2(16, ch - 40), 12, "muted")
		ui.bar(Rect2(rect.position.x + 90, rect.position.y + ch - 36, cw - 106, 7), h / 100.0, "red" if h > 60 else ("orange" if h > 35 else "green"))
		var tag := Lang.f("Aliados (%d d)", int(st.ally_until) - g.day) if g.allied(r.key) else Lang.f("Vale %s", Fmt.short(g.rival_value(r)))
		ui.text(tag, rect.position + Vector2(16, ch - 22), 13, "green" if g.allied(r.key) else "text", g.allied(r.key))

	var y0 := CY + 2 * (ch + 10) + 2
	var lw := 600.0
	var r := D.rival_by_key(rival_sel)
	var p := ui.panel(Rect2(CX, y0, lw, CY + CH - y0))
	var st := g.rival_state(r.key)
	rival_badge(ui, r, p.position + Vector2(48, 48), 30)
	ui.text(r.name, p.position + Vector2(92, 18), 22, "text", true)
	var markets: Array = r.products if r.products else r.get("needs", [])
	var mk := ", ".join(markets.map(func(k): return D.PRODUCTS[k].name)) if markets else Lang.t("todos los mercados")
	ui.text(Lang.f("%s · %s", [r.company, mk]), p.position + Vector2(92, 48), 14, "muted", false, "topleft", lw - 110)
	var y := p.position.y + 92
	y += ui.wrap_text(r.bio, Rect2(p.position.x + 20, y, lw - 40, 60), 15, "text") + 8
	var style: Array = D.RIVAL_STYLES[r.style]
	ui.text(Lang.f("Estilo: %s", style[0]), Vector2(p.position.x + 20, y), 14, Notifications.light(r.color, 0.3), true)
	y += 20
	y += ui.wrap_text(style[1], Rect2(p.position.x + 20, y, lw - 40, 40), 13, "muted") + 10
	if not g.rival_active(r):
		ui.text("Todavía no está en tu ciudad.", Vector2(p.position.x + 20, y + 10), 15, "muted")
		return
	y = ui.row(p.position.x + 20, y, lw - 40, "Hostilidad contigo", Lang.f("%d / 100", roundi(st.hostility)), "red" if st.hostility > 60 else "text",
			"Sube si le compras locales, lo denuncias o lo provocas. Mientras más alta, más seguido te ataca.")
	var bw := (lw - 52) / 2
	var by := p.end.y - 54
	if g.allied(r.key):
		ui.button(Rect2(p.position.x + 20, by, bw, 40), Lang.f("Aliados por %d días", int(st.ally_until) - g.day), false, "normal", 14)
	else:
		var ac := g.alliance_cost(r.key)
		var a_tip := Lang.f("Cena de negocios: pagas %s. %d%% de que acepte (menos si te odia). Si acepta, no te ataca por 90 días.", [Fmt.money(ac), roundi(g.alliance_chance(r.key) * 100)])
		if ui.button(Rect2(p.position.x + 20, by, bw, 40), Lang.f("Proponer alianza (%s)", Fmt.short(ac)), g.cash >= ac, "primary", 14, a_tip):
			ask(Lang.f("¿Proponerle una alianza a %s?", r.short), a_tip, "Sí, invitarlo a cenar", g.propose_alliance.bind(r.key))
	var pc := g.provoke_cost()
	var p_tip := Lang.f("Publicidad comparativa: pagas %s y tu demanda en sus mercados sube 20%% por 15 días. Lo enoja mucho (+25 de hostilidad) y rompe la alianza.", Fmt.money(pc))
	if ui.button(Rect2(p.position.x + 32 + bw, by, bw, 40), Lang.f("Provocarlo (%s)", Fmt.short(pc)), g.cash >= pc and not g.rival_markets(r).is_empty(), "danger", 14, p_tip):
		ask(Lang.f("¿Lanzar una campaña contra %s?", r.short), p_tip, "Sí, provocarlo", g.provoke.bind(r.key), true)

	# Ranking de la ciudad
	var rx := CX + lw + 12
	var rw := CW - lw - 12
	var rp := ui.panel(Rect2(rx, y0, rw, CY + CH - y0), "Ranking de la ciudad", "Lo que vale cada empresa en esta ciudad. Supera a los rivales uno por uno.")
	var ry := rp.position.y + 46
	var rows := g.ranking()
	for i in rows.size():
		var row: Array = rows[i]
		if ry > rp.end.y - 26:
			break
		var me: bool = row[0] == ""
		if me:
			ui.rect(Rect2(rx + 10, ry - 4, rw - 20, 28), Color(ImUI.COL.accent, 0.14), 6)
		ui.text(Lang.f("%d.", i + 1), Vector2(rx + 20, ry), 15, "muted", true)
		ui.circle(Vector2(rx + 56, ry + 10), 7, row[4])
		ui.text(row[2], Vector2(rx + 72, ry), 15, "accent" if me else "text", me, "topleft", rw - 200)
		ui.text(Fmt.short(row[3]), Vector2(rx + rw - 20, ry), 15, "accent" if me else "text", me, "topright")
		ry += 30


# ---------- Personal: cómo tratas a tus empleados ----------
func draw_personal(g: Game) -> void:
	var lw := 600.0
	var p := ui.panel(Rect2(CX, CY, lw, CH), "Cómo tratas a tus empleados",
			"Vale para toda la empresa. Lo que ahorras maltratando a la gente se paga con renuncias, huelgas, multas y mala fama.")
	var y := p.position.y + 48
	for i in D.LABOR.size():
		var l: Dictionary = D.LABOR[i]
		var dh := ui.wrap_height(l.desc, lw - 220, 13)
		var r := Rect2(p.position.x + 16, y, lw - 32, 54 + dh)
		var on: bool = g.labor == i
		var col: Color = [ImUI.COL.green, ImUI.COL.blue, ImUI.COL.orange, ImUI.COL.red][i]
		ui.rect(r, Color(col, 0.16) if on else Color8(28, 34, 44), 12)
		ui.rect(r, Color(col, 0.9 if on else 0.3), 12, 2 if on else 1)
		ui.text(l.name, r.position + Vector2(18, 12), 17, "text", true)
		ui.wrap_text(l.desc, Rect2(r.position.x + 18, r.position.y + 38, lw - 220, dh), 13, "muted")
		ui.text(Lang.f("Sueldo ×%s", Fmt.num(l.wage, 2)), Vector2(r.end.x - 130, r.position.y + 14), 13, "text")
		ui.text(Lang.f("Rinden ×%s", Fmt.num(l.prod, 2)), Vector2(r.end.x - 130, r.position.y + 32), 13, "text")
		if on:
			ui.text("ACTUAL", Vector2(r.end.x - 130, r.position.y + 52), 13, col, true)
		elif ui.button(Rect2(r.end.x - 130, r.position.y + 50, 112, 28), "Elegir", true, "danger" if i >= 2 else "normal", 13):
			var detail: String = l.desc
			ask(Lang.f("¿Cambiar a «%s»?", l.name), detail, "Sí, cambiar", g.set_labor.bind(i), i >= 2)
		y += r.size.y + 10

	var rx := CX + lw + 12
	var rw := CW - lw - 12
	var q := ui.panel(Rect2(rx, CY, rw, CH), "Ánimo del equipo")
	var m := g.morale
	var col: Color = ImUI.COL.green if m >= 60 else (ImUI.COL.orange if m >= 30 else ImUI.COL.red)
	var c := Vector2(rx + rw / 2, CY + 150)
	ui.ring(c, 70, Color8(40, 46, 58), 12)
	var steps := 48
	var pts := PackedVector2Array()
	for k in steps + 1:
		var a := -PI / 2 + TAU * (m / 100.0) * k / steps
		pts.append(c + Vector2(cos(a), sin(a)) * 70)
	if m > 0.5:
		ui.polyline(pts, col, 12)
	ui.text(str(roundi(m)), c + Vector2(0, -6), 40, col, true, "center")
	ui.text("de 100", c + Vector2(0, 26), 13, "muted", false, "center")
	var mood := "Felices" if m >= 75 else ("Tranquilos" if m >= 55 else ("Molestos" if m >= 30 else "Furiosos"))
	ui.text(mood, Vector2(c.x, c.y + 92), 20, col, true, "center")
	var x := rx + 20
	var w := rw - 40
	y = CY + 280
	y = ui.row(x, y, w, "Empleados", str(g.staff_count()))
	y = ui.row(x, y, w, "Sueldo diario por empleado", Fmt.money(g.wage_daily(), 2))
	y = ui.row(x, y, w, "Rendimiento real", Lang.f("×%s", Fmt.num(g.staff_factor(), 2)), "text",
			"Lo que rinde cada empleado: el trato que elegiste por el ánimo. Con ánimo bajo rinden menos de lo prometido.")
	y += 10
	var risks := []
	if m < 35:
		risks.append(["bad", "Con este ánimo la gente renuncia: cada día alguien se puede ir."])
	if m < 30:
		risks.append(["bad", "Atienden de mala gana: las estrellas de tus locales bajan."])
		risks.append(["bad", "El sindicato se organiza: las huelgas son mucho más probables."])
	if D.LABOR[g.labor].key in ["exigente", "explotador"]:
		risks.append(["warn", "Cada mes puede llegar una inspección del trabajo con una multa."])
	if D.LABOR[g.labor].key == "explotador":
		risks.append(["bad", "Si un video del maltrato se hace viral, tu reputación se hunde."])
	if m > 75:
		risks.append(["good", "Atienden con ganas: las estrellas suben y puedes ganar el premio «Mejor lugar para trabajar»."])
	if risks.is_empty():
		risks.append(["info", "Todo tranquilo con tu equipo."])
	for rk in risks:
		ui.circle(Vector2(x + 6, y + 9), 4, ImUI.KIND_COLOR[rk[0]])
		y += ui.wrap_text(rk[1], Rect2(x + 18, y, w - 18, 50), 14, "text") + 6
