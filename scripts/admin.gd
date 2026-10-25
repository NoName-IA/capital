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
# casi 7 segundos; x2: 3,3 segundos; x4: 1,7 segundos). Un buen jugador llega al Imperio en unos 700 días.
const SPEEDS := [[0.15, "x1"], [0.3, "x2"], [0.6, "x4"]]
const TABS := [["resumen", "Resumen"], ["negocios", "Negocios"], ["mercado", "Mercado"], ["finanzas", "Finanzas"],
		["crecimiento", "Crecimiento"], ["reportes", "Reportes"], ["noticias", "Noticias"], ["conceptos", "Conceptos"]]

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
var modal = null
var running := true
var slot := 1
var slot_screen = null        # "new" o "load": pantalla para elegir el espacio de guardado
var slot_confirm = null       # espacio que se va a sobrescribir o borrar
var slot_cache := {}
var pick_mode := false
var naming := false           # escribiendo el nombre de la empresa (después de elegir el modo)
var settings_open := false    # ajustes abiertos desde el menú de inicio (los dibuja Overlays)
var name_mode := "normal"
var company_name := ""
const NAME_IDEAS := ["Grupo Horizonte", "Inversiones Faro", "Café & Cía.", "Capital Andina", "Empresas del Sur",
		"Comercial Las Lomas", "Holding Aurora", "Grupo Puerto", "Alfa Retail", "Corporación Brisa", "Imperio Dorado",
		"Mercantil del Pacífico"]
var win_shown := false
var quit_requested := false
var unread := 0               # avisos que llegaron y todavía no viste en Noticias


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
func update(dt: float) -> void:
	var g := game
	if g.pending_choice != null and modal == null and not g.game_over:
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


func new_game(mode := "normal") -> void:
	game = Game.new(null, mode)
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
		say("Partida guardada en el espacio %d." % slot, "good")


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
		say("No se pudo cargar la partida del espacio %d." % n, "bad")
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
	say("Partida del espacio %d cargada. Presiona P para continuar." % n, "info")
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
	saved = "%s/%s/%s %s" % [dmy[2], dmy[1], dmy[0], parts[1].substr(0, 5)]
	var info := {}
	var text := FileAccess.get_file_as_string(path)
	var parsed = JSON.parse_string(text)
	if parsed == null or not parsed is Dictionary:
		info = {"broken": true, "saved": saved}
	else:
		var g := Game.from_json(text)
		var dp := g.date_parts()
		info = {"company": g.company, "mode": D.MODES[g.mode].name, "rank": g.rank_info()[1], "value": g.valuation(), "cash": g.cash,
				"date": "Día %d de %s, año %d" % dp, "minutes": g.play_seconds / 60.0, "over": g.game_over,
				"saved": saved}
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
	var cont_sub := ""
	if info != null and not info.get("broken", false):
		cont_sub = "%s · %s · %s" % [info.company, info.rank, Fmt.short(info.value)]
	if ui.menu_item("continuar", Vector2(x, y), "CONTINUAR", cont_sub, last > 0 and not (info != null and info.get("over", false)), 32):
		load_slot(last)
	y += 92 if cont_sub else 72
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
	# Tarjeta de la última partida, abajo a la derecha
	if info != null and not info.get("broken", false):
		var r := Rect2(W - 420, H - 250, 360, 190)
		ui.rect(r, Color(0.05, 0.065, 0.09, 0.88), 16)
		ui.rect(r, Color(ImUI.COL.accent, 0.35), 16, 1)
		ui.text("ÚLTIMA PARTIDA · ESPACIO %d" % last, r.position + Vector2(22, 18), 12, "muted", true)
		ui.text(info.company, r.position + Vector2(22, 38), 24, "accent", true, "topleft", r.size.x - 44)
		ui.text(info.rank, Vector2(r.end.x - 22, r.position.y + 18), 12, "text", true, "topright")
		var ry := ui.row(r.position.x + 22, r.position.y + 80, r.size.x - 44, "Valor de la empresa", Fmt.short(info.value), "text")
		ry = ui.row(r.position.x + 22, ry, r.size.x - 44, "Fecha del juego", info.date)
		ry = ui.row(r.position.x + 22, ry, r.size.x - 44, "Tiempo jugado", "%d min" % roundi(info.minutes))
		ui.text("Guardada el %s" % info.saved, Vector2(r.position.x + 22, ry + 2), 12, "muted")
	ui.text("© 2026 Brandon Alvis (NoName-IA)", Vector2(x, H - 34), 12, "muted")
	ui.text("M: música · F11: pantalla completa", Vector2(W - 60, H - 34), 12, "muted", false, "topright")
	draw_toast_line(H - 64)


func draw_toast_line(y: float) -> void:
	if toast != null and now_ms() < toast[2]:
		ui.text(toast[0], Vector2(W / 2, y), 16, ImUI.KIND_COLOR[toast[1]], false, "center")


## Tres espacios de guardado. "new": elegir dónde empezar la partida nueva; "load": elegir cuál cargar.
func draw_slots() -> void:
	var is_new: bool = slot_screen == "new"
	ui.text("¿Dónde guardar la partida nueva?" if is_new else "Cargar partida", Vector2(W / 2, 110), 38, "text", true, "center")
	ui.text("Cada espacio guarda una partida distinta. El juego se guarda solo en el espacio que estás usando."
			if is_new else "Elige una de tus partidas guardadas.", Vector2(W / 2, 158), 16, "muted", false, "center")
	for i in SLOTS:
		var n := i + 1
		var info = slot_info(n)
		var r := Rect2(W / 2 - 540 + i * 365, 200, 350, 380)
		ui.panel(r)
		ui.top_strip(Rect2(r.position, Vector2(r.size.x, 6)), "accent" if info != null else "border")
		ui.text("Espacio %d" % n, r.position + Vector2(26, 26), 26, "accent" if info != null else "muted", true)
		if info == null:
			ui.text("Vacío", Vector2(r.get_center().x, r.position.y + 170), 22, "muted", false, "center")
		elif info.get("broken", false):
			ui.text("Archivo dañado", r.position + Vector2(26, 80), 17, "red", true)
			ui.text("Guardado el %s" % info.saved, r.position + Vector2(26, 108), 14, "muted")
		else:
			var x := r.position.x + 26
			var w := r.size.x - 52
			var y := r.position.y + 76
			ui.text(info.mode, Vector2(x, y), 15, "blue", true)
			ui.text(info.rank, Vector2(x, y + 26), 21, "text", true, "topleft", w)
			y = ui.row(x, y + 66, w, "Valor de la empresa", Fmt.short(info.value), "accent")
			y = ui.row(x, y, w, "Caja", Fmt.short(info.cash), sc(info.cash))
			y = ui.row(x, y, w, "Fecha del juego", info.date)
			y = ui.row(x, y, w, "Tiempo jugado", "%d min" % roundi(info.minutes))
			ui.text("Guardado el %s" % info.saved, Vector2(x, y + 6), 13, "muted")
			if info.over:
				ui.text("Partida terminada (quiebra)", Vector2(x, y + 28), 13, "red", true)
		var bx := r.position.x + 26
		var by := r.end.y - 66
		var bw := r.size.x - 52
		if slot_confirm == n:
			ui.text("¿Sobrescribir esta partida?" if is_new else "¿Borrar esta partida?", Vector2(r.get_center().x, by - 34),
					15, "orange", true, "midtop")
			if ui.button(Rect2(bx, by, bw / 2 - 6, 44), "Sí", true, "danger", 16):
				delete_save(n)
				slot_confirm = null
				if is_new:
					start_in_slot(n)
					return
			if ui.button(Rect2(bx + bw / 2 + 6, by, bw / 2 - 6, 44), "No", true, "normal", 16):
				slot_confirm = null
		elif is_new:
			if ui.button(Rect2(bx, by, bw, 44), "Empezar aquí" if info == null else "Sobrescribir", true,
					"primary" if info == null else "normal", 16):
				if info == null:
					start_in_slot(n)
					return
				slot_confirm = n
		elif info != null:
			var ok: bool = not info.get("broken", false) and not info.get("over", false)
			if ui.button(Rect2(bx, by, bw - 120, 44), "Cargar", ok, "primary", 16):
				if load_slot(n):
					slot_screen = null
					return
			if ui.button(Rect2(bx + bw - 108, by, 108, 44), "Borrar", true, "danger", 15):
				slot_confirm = n
	if ui.button(Rect2(W / 2 - 120, 620, 240, 44), "Volver", true, "normal", 16):
		slot_screen = null
		slot_confirm = null
	draw_toast_line(690)


func start_in_slot(n: int) -> void:
	slot = n
	slot_screen = null
	slot_confirm = null
	pick_mode = true


## Último paso antes de empezar: el nombre de tu empresa (sale en el HUD, el celular, la oficina y tus locales).
func draw_naming() -> void:
	var x := 96.0
	ui.text("PARTIDA NUEVA · %s" % D.MODES[name_mode].name.to_upper(), Vector2(x + 2, 140), 14, "muted", true)
	ui.text("¿Cómo se llama tu empresa?", Vector2(x, 160), 48, "text", true)
	ui.rect(Rect2(x, 230, 120, 4), "accent", 2)
	ui.text("Aparece en tus locales, tu oficina y en lo que dicen los clientes y los rivales.", Vector2(x, 248), 17, "muted")
	var field := Rect2(x, 300, 640, 76)
	ui.rect(field, Color(0.04, 0.05, 0.07, 0.9), 14)
	ui.rect(field, ImUI.COL.accent, 14, 2)
	var shown := company_name if company_name else ""
	var t := ui.text(shown, Vector2(field.position.x + 24, field.get_center().y), 34, "accent", true, "midleft")
	if not company_name:
		ui.text("Escribe un nombre…", Vector2(field.position.x + 24, field.get_center().y), 30, Color(1, 1, 1, 0.25), false, "midleft")
	if int(Time.get_ticks_msec() / 500) % 2 == 0:  # cursor que parpadea
		var cx: float = t.end.x + 3 if company_name else field.position.x + 24
		ui.rect(Rect2(cx, field.get_center().y - 20, 3, 40), "accent")
	ui.text("%d / 24" % company_name.length(), Vector2(field.end.x - 16, field.end.y + 8), 13, "muted", false, "topright")
	if ui.button(Rect2(x, 410, 200, 42), "Nombre al azar", true, "normal", 15):
		var idea: String = NAME_IDEAS.pick_random()
		while idea == company_name:
			idea = NAME_IDEAS.pick_random()
		company_name = idea
	var ok := company_name.strip_edges().length() >= 2
	if ui.menu_item("empezar", Vector2(x, 500), "EMPEZAR", "Enter", ok, 32, 400.0) :
		start_named_game()
		return
	if ui.menu_item("volver_nombre", Vector2(x, 580), "VOLVER", "Esc", true, 24, 400.0, false, "muted"):
		naming = false
		pick_mode = true
	draw_toast_line(H - 64)


func start_named_game() -> void:
	var name := company_name.strip_edges()
	if name.length() < 2:
		say("Escribe un nombre de al menos 2 letras.", "bad")
		return
	naming = false
	new_game(name_mode)
	game.company = name
	game.news.clear()
	game.add_news("Fundaste %s con un puesto de café y %s en caja. ¡A vender!" % [name, Fmt.money(game.cash)], "good")
	if name_mode == "inversionista":
		game.add_news("Modo inversionista: tienes capital para crecer rápido. No hay final: llega a Mil millonario.", "info")
	game.add_news("Consejo: en Mercado puedes ver la curva de precio y el precio que maximiza tu utilidad.", "info")


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


## Antes de cada partida nueva: modo normal (con final) o modo inversionista (sin final).
func draw_mode_picker() -> void:
	ui.text("¿Cómo quieres jugar?", Vector2(W / 2, 120), 40, "text", true, "center")
	var cards := [
		["normal", "Modo normal", "accent",
		 "Empiezas desde abajo: un puesto de café y $1.500.\n\nSube de Vendedor ambulante a Imperio ($10 millones). Una partida dura unos 40 minutos y termina cuando construyes tu imperio."],
		["inversionista", "Modo inversionista", "green",
		 "Empiezas con $250.000 de capital para crecer rápido.\n\nNo hay final: después del Imperio vienen Conglomerado, Multinacional, Titán de la industria, Leyenda de los negocios y Mil millonario. Usa la bolsa, los sistemas de gestión y las adquisiciones para multiplicar tu fortuna."],
	]
	for i in cards.size():
		var c: Array = cards[i]
		var r := Rect2(W / 2 - 520 + i * 540, 190, 500, 400)
		ui.panel(r)
		ui.top_strip(Rect2(r.position, Vector2(r.size.x, 6)), c[2])
		ui.text(c[1], r.position + Vector2(30, 30), 30, c[2], true)
		ui.wrap_text(c[3], Rect2(r.position.x + 30, r.position.y + 90, r.size.x - 60, 220), 17, "text")
		if ui.button(Rect2(r.position.x + 30, r.end.y - 80, r.size.x - 60, 50), "Jugar en %s" % c[1].to_lower(), true, "primary", 18):
			pick_mode = false
			naming = true
			name_mode = c[0]
			company_name = ""
			return
	ui.text("Se guardará en el espacio %d" % slot, Vector2(W / 2, 610), 15, "muted", false, "center")
	if ui.button(Rect2(W / 2 - 120, 640, 240, 44), "Volver", true, "normal", 16):
		pick_mode = false
		slot_screen = "new"


# ---------- juego ----------
func draw_game() -> void:
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
		 "Valoración: EBITDA anual × múltiplo + caja + bonos + inventario − deuda. Define tu rango."],
		[715, "Economía", "%s (%s)" % [ph.name, Fmt.num(g.econ_index, 2)], econ_color,
		 "Índice de actividad económica (1,00 = normal). Afecta la demanda según la elasticidad ingreso de cada producto."],
		[885, "Inflación", Fmt.pct(g.inflation), "text",
		 "Inflación anual. Tus costos, salarios y alquileres suben; el precio de referencia del mercado también."],
		[975, "Tasa BC", Fmt.pct(g.policy_rate), "text",
		 "Tasa del banco central. Sube cuando hay inflación. Define el costo de los préstamos y el rendimiento de los bonos."],
	]
	for it in items:
		ui.text(it[1], Vector2(it[0], 9), 12, "muted")
		var r := ui.text(it[2], Vector2(it[0], 26), 16, it[3], true)
		ui.tooltip(Rect2(it[0], 6, max(r.size.x, 70.0), 46), it[4])
	var x := 1074.0
	if ui.button(Rect2(x, 15, 46, 30), "II", true, "normal", 15, "Pausa (P)", paused):
		paused = not paused
	for i in SPEEDS.size():
		if ui.button(Rect2(x + 52 + i * 52, 15, 46, 30), SPEEDS[i][1], true, "normal", 15,
				"Velocidad %s (tecla %d)" % [SPEEDS[i][1], i + 1], not paused and speed == i):
			speed = i
			paused = false


func draw_side() -> void:
	var g := game
	ui.rect(Rect2(0, TOP + 1, SIDE, H - TOP), "panel")
	ui.line(Vector2(SIDE, TOP), Vector2(SIDE, H), "border")
	for i in TABS.size():
		var label: String = TABS[i][1]
		if TABS[i][0] == "noticias" and unread and tab != "noticias":
			label += " (%d)" % mini(unread, 99)
		if ui.button(Rect2(12, TOP + 16 + i * 46, SIDE - 24, 38), label, true, "normal", 16, null, tab == TABS[i][0]):
			tab = TABS[i][0]
			confirm_sell = null
	var info := g.rank_info()
	var y := H - 210
	ui.text("Rango", Vector2(16, y), 13, "muted")
	ui.text(info[1], Vector2(16, y + 18), 17, "accent", true, "topleft", SIDE - 24)
	if info[2] != null:
		var lo := rank_lo(info[0])
		ui.bar(Rect2(16, y + 48, SIDE - 32, 8), (info[3] - lo) / (info[2][0] - lo), "accent")
		ui.text("Siguiente: %s" % Fmt.short(info[2][0]), Vector2(16, y + 62), 12, "muted")
		ui.tooltip(Rect2(16, y, SIDE - 32, 80), "Llega a un valor de empresa de %s para ser %s." % [Fmt.money(info[2][0]), info[2][1]])
	if ui.button(Rect2(12, H - 118, SIDE - 24, 32), "Guardar", true, "normal", 14):
		save()
	if ui.button(Rect2(12, H - 80, SIDE - 24, 32), "Nuevo juego", true, "normal", 14):
		modal = "new"
	if ui.button(Rect2(12, H - 42, SIDE - 24, 32), "Menú principal", true, "normal", 14):
		save(true)
		view = "menu"


func draw_ticker() -> void:
	var g := game
	var r := Rect2(CX, H - 38, CW, 30)
	ui.rect(r, "panel", 8)
	var text := ""
	var kind := "info"
	if toast != null and now_ms() < toast[2]:
		text = toast[0]
		kind = toast[1]
		ui.text("»", Vector2(r.position.x + 12, r.get_center().y), 16, ImUI.KIND_COLOR[kind], true, "midleft")
	elif g.news:
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
	var box := Rect2(W / 2 - 280, H / 2 - 140, 560, 280)
	ui.panel(box)
	var cx := box.get_center().x
	if modal == "gameover":
		ui.text("Quiebra", Vector2(cx, box.position.y + 46), 36, "red", true, "center")
		ui.wrap_text("Tu empresa no pudo pagar al banco y cerró después de %s años. Revisa en Reportes qué costos se comieron tu utilidad: casi siempre es crecer con deuda más rápido que la caja." % Fmt.num(g.day / 360.0, 1),
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
		ui.wrap_text("Tu empresa vale %s. Lo lograste en %d minutos de juego (%s años dentro del juego). " % [Fmt.money(g.valuation()), roundi(minutes), Fmt.num(g.day / 360.0, 1)]
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
	var details := []
	var total := 0.0
	for o in c.options:
		var dh := ui.wrap_height(o.detail, bw - pad * 2 - 44, 14)
		details.append(dh)
		total += 52 + dh + 12
	var head := 124.0
	var bh := head + 24 + text_h + 22 + total + 46
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
	ui.text("DECISIÓN URGENTE · DÍA %d DE %s" % [dp[0], String(dp[1]).to_upper()], Vector2(tx, box.position.y + 30), 13,
			Notifications.light(accent, 0.3), true)
	ui.text(c.title, Vector2(tx, box.position.y + 50), 30, "text", true, "topleft", box.end.x - tx - pad)
	var cash_r := Rect2(box.end.x - pad - 200, box.position.y + 22, 200, 30)
	ui.rect(cash_r, Color(0, 0, 0, 0.3), 15)
	ui.text("Caja: %s" % Fmt.money(g.cash), cash_r.get_center(), 14, sc(g.cash), true, "center")
	# Texto
	var y := box.position.y + head + 24
	y += ui.wrap_text(c.text, Rect2(box.position.x + pad, y, bw - pad * 2, text_h), 17, Color8(215, 222, 232)) + 22
	# Opciones como tarjetas
	for i in c.options.size():
		var o: Dictionary = c.options[i]
		var r := Rect2(box.position.x + pad, y, bw - pad * 2, 52 + details[i])
		var hot := ui.hover(r)
		var k := ui.tween("dilema%d" % i, 1.0 if hot else 0.0)
		ui.rect(r, ImUI.COL.panel2.lerp(Color8(44, 52, 66), k), 12)
		ui.rect(r, Color(accent, 0.25 + 0.6 * k), 12, 1.0 + k)
		ui.text(o.label, Vector2(r.position.x + 22, r.position.y + 14), 17, "text", true, "topleft", r.size.x - 44)
		ui.wrap_text(o.detail, Rect2(r.position.x + 22, r.position.y + 40, r.size.x - 44, details[i]), 14, "muted")
		if hot and ui.clicked:
			var res := g.resolve_choice(i)
			modal = null
			say(res[1], "good" if res[0] else "bad")
			return
		y += r.size.y + 12
	ui.text("Lee las probabilidades: el valor esperado y el riesgo no siempre van juntos (ver Conceptos).",
			Vector2(box.get_center().x, box.end.y - 28), 13, "muted", false, "center")


# ---------- Resumen ----------
func draw_resumen(g: Game) -> void:
	var last = Game.statement(g.history[-1]) if g.history else null
	var cur := Game.statement(g.ledger)
	var net_margin: float = last.utilidad_neta / last.ingresos if last != null and last.ingresos else 0.0
	var cards := [
		["Caja", Fmt.money(g.cash), sc(g.cash), "Bonos: %s" % Fmt.money(g.bonds), "Dinero disponible para invertir y pagar costos."],
		["Ingresos del mes", Fmt.money(cur.ingresos), "text",
		 "Mes pasado: %s" % Fmt.money(last.ingresos) if last != null else "Tu primer mes",
		 "Precio × unidades vendidas en lo que va del mes."],
		["Utilidad neta (mes pasado)", Fmt.money(last.utilidad_neta) if last != null else "—",
		 sc(last.utilidad_neta) if last != null else "muted", "Margen neto: %s" % Fmt.pct(net_margin),
		 "Lo que quedó después de TODOS los costos, intereses, depreciación e impuestos."],
		["Valor de la empresa", Fmt.money(g.valuation()), "accent",
		 "Múltiplo: %s × EBITDA" % Fmt.num(g.valuation_multiple(), 1),
		 "Cuánto pagaría un inversionista por tu empresa. El múltiplo sube en auge y baja en recesión."],
	]
	var cw := (CW - 36) / 4
	for i in cards.size():
		var c: Array = cards[i]
		var r := Rect2(CX + i * (cw + 12), CY, cw, 86)
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
		ui.text("Siguiente rango: %s al valer %s" % [info[2][1], Fmt.money(info[2][0])], Vector2(r.end.x - 16, r.position.y + 21),
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
	var tips: Array = cached("tips%d" % g.day, g.advisories)
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
			ui.text("Desbloquear: %s" % Fmt.money(g.unlock_cost(key)), r.position + Vector2(16, 66), 14,
					"green" if g.cash >= g.unlock_cost(key) else "muted")
			continue
		var ls := g.locs(key)
		var contrib = null
		if g.history and g.history[-1].productos.has(key):
			contrib = g.history[-1].productos[key].contribucion
		ui.text("%d sucursal(es)%s" % [ls.size(), " · fábrica" if p.factory else ""], r.position + Vector2(16, 42), 14, "text")
		ui.text("Ventas ayer: %s %s" % [Fmt.num(p.last_sold), d.unit], r.position + Vector2(16, 62), 14, "muted")
		if contrib != null:
			ui.text("Contribución mes: %s" % Fmt.money(contrib), r.position + Vector2(16, 82), 14, sc(contrib))

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
		var tip := "Inversión (CAPEX): %s, se deprecia en 5 años. Alquiler: %s/mes. Tráfico de clientes ×%s y hasta %d empleados. Cada sucursal nueva del mismo producto canibaliza un poco a las demás." % [Fmt.money(cost), Fmt.money(size.rent * g.price_index), Fmt.num(size.traffic), size.max_emp]
		if ui.button(Rect2(rx + 20 + s * (bw + 12), y, bw, 34), "Abrir %s (%s)" % [size.name, Fmt.short(cost)], g.cash >= cost, "normal", 15, tip):
			act(g.open_location(key, s))
	y += 44
	var units_month: float = p.ema_sales * 30
	var no_factory_cost: float = g.unit_cost(p) / (1 - D.FACTORY_SAVING) if p.factory else g.unit_cost(p)
	var saving: float = units_month * no_factory_cost * D.FACTORY_SAVING
	var upkeep := g.factory_cost(key) * D.FACTORY_UPKEEP
	var f_tip := "Integración vertical: fabricar tú mismo baja el costo unitario 30%%. Costo fijo de mantenimiento: %s/mes. Con tus ventas actuales ahorrarías ~%s/mes. Solo conviene si el ahorro supera el mantenimiento y la depreciación (%s/mes)." % [Fmt.money(upkeep), Fmt.money(saving), Fmt.money(g.factory_cost(key) / 60)]
	if p.factory:
		ui.button(Rect2(rx + 20, y, bw, 34), "Fábrica propia activa", false, "normal", 15, f_tip)
	elif ui.button(Rect2(rx + 20, y, bw, 34), "Construir fábrica (%s)" % Fmt.short(g.factory_cost(key)), g.cash >= g.factory_cost(key), "normal", 15, f_tip):
		act(g.build_factory(key))
	var wage: float = D.MANAGER_WAGE * g.price_index * g.min_wage_mult
	var m_tip := "Delegación: un gerente cuesta %s/mes y ajusta solo el personal de cada sucursal y los días de inventario de esta línea." % Fmt.money(wage)
	if ui.button(Rect2(rx + 32 + bw, y, bw, 34), "Despedir gerente" if p.manager else "Contratar gerente (%s/mes)" % Fmt.short(wage),
			true, "normal", 15, m_tip, p.manager):
		act(g.toggle_manager(key))
	var acq := g.acquire_cost(key)
	var a_tip := "Fusiones y adquisiciones: compras un competidor (%d en el mercado). Recibes su local con 3 empleados y hay un rival menos. Lo que pagas por encima del valor del local es plusvalía (goodwill). Cada competidor que queda es más caro." % p.competitors
	if ui.button(Rect2(rx + 44 + 2 * bw, y, bw, 34), "Adquirir competidor (%s)" % Fmt.short(acq), p.competitors > 0 and g.cash >= acq, "normal", 15, a_tip):
		act(g.acquire(key))

	y += 50
	var ls := g.locs(key)
	var service: float = p.last_sold / p.last_demand if p.last_demand else 1.0
	ui.text("Ayer: demanda %s · capacidad %s · vendido %s %s · nivel de servicio %s" % [Fmt.num(p.last_demand), Fmt.num(p.last_capacity), Fmt.num(p.last_sold), d.unit, Fmt.pct(service, 0)],
			Vector2(rx + 20, y), 14, "muted")
	y += 28
	var x0 := rx + 20
	var heads := [["Sucursal", x0, "topleft"], ["Empleados", x0 + 201, "midtop"], ["Demanda", x0 + 315, "topright"],
			["Capacidad", x0 + 385, "topright"], ["Vendido", x0 + 455, "topright"], ["Contrib.", x0 + 545, "topright"],
			["ROI anual", x0 + 605, "topright"]]
	for h in heads:
		ui.text(h[0], Vector2(h[1], y), 13, "muted", true, h[2])
	ui.tooltip(Rect2(x0 + 465, y, 140, 18), "Contribución = ingresos − mercancía − salarios − alquiler de la sucursal (último mes cerrado). ROI anual = contribución × 12 ÷ inversión total en la sucursal.")
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
		if Game.plot_of(loc) >= 0:
			where = " · T%d" % (Game.plot_of(loc) + 1)
		ui.text("%s #%d%s" % [size.name, i + 1, where], Vector2(x0, cy - 8), 14, "text", true, "midleft", 135)
		var st := Game.stars_of(loc)
		for k in 5:
			Icons.draw(ui, "star", Vector2(x0 + 6 + k * 13, cy + 9), 12, Color8(240, 190, 60) if k < floori(st + 0.25) else Color8(70, 75, 85))
		ui.text(Fmt.num(st, 1), Vector2(x0 + 72, cy + 9), 12, "muted", false, "midleft")
		ui.tooltip(Rect2(x0, ry, 135, rows), "Estrellas: %s de 5 (con 5 vende 15%% más que con 3; suben atendiendo a todos, con buena reputación, calidad y precio justo). Inversión total: %s. Valor en libros: %s. Productividad: %s %s por empleado al día." % [Fmt.num(st, 1), Fmt.money(loc.invested), Fmt.money(g.asset_book(loc.asset_ids)), Fmt.num(prod, 1), d.unit])
		if ui.button(Rect2(x0 + 140, cy - 13, 26, 26), "−", loc.employees > 0 and not p.manager, "normal", 15,
				"Despedir: pagas %d días de salario de indemnización." % int(D.SEVERANCE_DAYS)):
			act(g.fire(loc))
		ui.text("%d/%d" % [loc.employees, size.max_emp], Vector2(x0 + 201, cy), 15, "text", false, "center")
		if ui.button(Rect2(x0 + 236, cy - 13, 26, 26), "+", loc.employees < size.max_emp and not p.manager, "normal", 15,
				"Contratar: %s de reclutamiento y %s/mes de salario." % [Fmt.money(D.HIRING_COST * g.price_index), Fmt.money(g.wage_daily() * 30)]):
			act(g.hire(loc))
		var lost: bool = loc.demand > loc.capacity * 1.02
		ui.text(Fmt.num(loc.demand), Vector2(x0 + 315, cy), 15, "orange" if lost else "text", false, "midright")
		ui.text(Fmt.num(loc.capacity), Vector2(x0 + 385, cy), 15, "text", false, "midright")
		ui.text(Fmt.num(loc.sold), Vector2(x0 + 455, cy), 15, "text", false, "midright")
		if loc.last_contrib != null:
			ui.text(Fmt.short(loc.last_contrib), Vector2(x0 + 545, cy), 15, sc(loc.last_contrib), false, "midright")
			var roi: float = loc.last_contrib * 12 / loc.invested if loc.invested else 0.0
			ui.text(Fmt.pct(roi, 0), Vector2(x0 + 605, cy), 15, sc(roi), true, "midright")
		else:
			ui.text(Fmt.short(loc.month_contrib), Vector2(x0 + 545, cy), 15, "muted", false, "midright")
			ui.text("—", Vector2(x0 + 605, cy), 15, "muted", false, "midright")
		var up = g.upgrade_cost(loc)
		var up_tip := "Ampliar a %s por %s: más tráfico y más empleados posibles." % [D.SIZES[loc.size + 1].name, Fmt.money(up)] if up != null else "Ya es una megatienda."
		if ui.button(Rect2(x0 + 618, cy - 14, 72, 28), "Ampliar", up != null and g.cash >= up, "normal", 13, up_tip):
			act(g.upgrade_location(loc))
		var confirming: bool = confirm_sell == loc.id
		var sell_tip := "Recibes %s: la mitad de su valor en libros. La otra mitad es un costo hundido y se registra como pérdida. También pagas indemnizaciones." % Fmt.money(g.sell_value(loc))
		if ui.button(Rect2(x0 + 696, cy - 14, rw - 40 - 696, 28), "¿Seguro?" if confirming else "Vender", true, "danger", 13, sell_tip):
			if confirming:
				confirm_sell = null
				act(g.sell_location(loc))
				break
			confirm_sell = loc.id
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
		["Ventas por empleado al día", "%s %s" % [Fmt.num(d.productivity, 1), d.unit], null],
		["Merma diaria del inventario", Fmt.pct(d.spoil, 1), "Parte del inventario que se pierde cada día."],
		["Temporada alta", D.MONTHS[d.season_peak - 1], null],
		["Competidores", str(g.products[key].competitors), null],
	]
	for r in rows:
		y = ui.row(x, y, w, r[0], r[1], "text", r[2])
	var cost := g.unlock_cost(key)
	y += 16
	if ui.button(Rect2(x, y, 320, 44), "Desbloquear por %s" % Fmt.money(cost), g.cash >= cost, "primary", 15,
			"Licencias, recetas y desarrollo. Se registra como activo intangible y se amortiza en 5 años."):
		act(g.unlock(key))
	if g.cash < cost:
		ui.text("Te faltan %s. Ahorra o pide un préstamo en Finanzas." % Fmt.money(cost - g.cash), Vector2(x, y + 56), 14, "muted")


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
	var cv: Array = cached("curve%d|%s|%f|%d|%d|%d" % [g.day, key, p.price, p.quality, ls.size(), emp], func(): return g.price_curve(key))
	var curve: Array = cv[0]
	var best: Array = cv[1]
	if ui.button(Rect2(CX + 190, y0 + 88, 242, 30), "Usar precio óptimo (%s)" % Fmt.money(best[0], 2), not ls.is_empty(), "normal", 15,
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
		 "Costo base × calidad × inflación. Descuento por volumen: %s%s" % [Fmt.pct(g.volume_discount(p), 0), " · fábrica propia −30%." if p.factory else "."]],
		["Margen de contribución por unidad", "%s (%s)" % [Fmt.money(margin, 2), Fmt.pct(margin / p.price if p.price else 0.0, 0)], sc(margin),
		 "Precio − costo variable. Lo que cada venta aporta para pagar los costos fijos."],
		["Demanda / capacidad (ayer)", "%s / %s" % [Fmt.num(p.last_demand), Fmt.num(p.last_capacity)], "text",
		 "Capacidad = empleados × productividad. Si la demanda la supera, pierdes ventas."],
		["Ventas ayer · nivel de servicio", "%s · %s" % [Fmt.num(p.last_sold), Fmt.pct(service, 0)], "green" if service > 0.95 else "orange",
		 "Porcentaje de la demanda que lograste atender. Si es bajo, baja tu reputación."],
		["Punto de equilibrio", "%s %s/día" % [Fmt.num(be), d.unit] if be != null else "precio bajo el costo",
		 "green" if be != null and p.last_sold >= be else "red",
		 "Costos fijos diarios de la línea (%s) ÷ margen de contribución." % Fmt.money(g.fixed_costs_daily(key))],
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
				"Utilidad diaria según precio (%s a %s)" % [Fmt.money(lo_p, 2), Fmt.money(hi_p, 2)], Fmt.short,
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
		var tip := "Costo ×%s · precio de referencia ×%s · reputación objetivo %d. %s" % [Fmt.num(qual.cost, 2), Fmt.num(qual.price, 2), int(qual.rep), notes[i]]
		var qw := (w - 16) / 3
		if ui.button(Rect2(x + i * (qw + 8), y, qw, 32), qual.name, true, "normal", 15, tip, p.quality == i):
			if p.quality != i:
				var ratio: float = p.price / g.ref_price(p)
				p.quality = i
				p.price = g.ref_price(p) * ratio
	y += 46

	ui.text("Marketing", Vector2(x, y), 15, "muted", true)
	ui.info_dot(Vector2(x + 84, y + 10), "Rendimientos decrecientes: el reconocimiento de marca sube con el presupuesto, pero cada dólar extra rinde menos. Si dejas de invertir, la gente se olvida de ti poco a poco.")
	ui.text("%s/mes" % Fmt.money(p.marketing), Vector2(x + w, y), 16, "text", true, "topright")
	y += 26
	var bw := (w - 25) / 6
	var msteps := [-10000.0, -1000.0, -100.0, 100.0, 1000.0, 10000.0]
	for i in msteps.size():
		var step: float = msteps[i]
		var label := ("+" if step > 0 else "−") + Fmt.short(absf(step)).replace("$", "")
		if ui.button(Rect2(x + i * (bw + 5), y, bw, 28), label, true, "normal", 13):
			p.marketing = max(0.0, p.marketing + step)
	y += 38
	ui.text("Reconocimiento de marca: %s (demanda +%s)" % [Fmt.pct(p.awareness, 0), Fmt.pct(0.6 * p.awareness, 0)], Vector2(x, y), 14, "text")
	y += 22
	ui.bar(Rect2(x, y, w, 8), p.awareness, "purple")
	y += 18
	ui.text("Reputación: %s/100 (demanda ×%s)" % [Fmt.num(p.reputation), Fmt.num(0.7 + 0.6 * p.reputation / 100, 2)], Vector2(x, y), 14, "text")
	ui.tooltip(Rect2(x, y, w, 20), "Depende de la calidad, de atender toda la demanda y de no cobrar mucho más que el mercado.")
	y += 22
	ui.bar(Rect2(x, y, w, 8), p.reputation / 100.0, "green" if p.reputation >= 50 else "orange")
	y += 26

	ui.text("Inventario", Vector2(x, y), 15, "muted", true)
	ui.info_dot(Vector2(x + 84, y + 10), "Compras cada mañana lo necesario para cubrir N días de ventas. Poco inventario = te quedas sin producto si sube la demanda. Mucho = más merma y costo de almacenamiento.")
	if ui.button(Rect2(x + w - 150, y - 4, 30, 26), "−", p.stock_days > 1 and not p.manager):
		p.stock_days -= 1
	ui.text("%d día%s" % [p.stock_days, "s" if p.stock_days > 1 else ""], Vector2(x + w - 75, y + 9), 15, "text", true, "center")
	if ui.button(Rect2(x + w - 30, y - 4, 30, 26), "+", p.stock_days < 30 and not p.manager):
		p.stock_days += 1
	y += 30
	y = ui.row(x, y, w, "En bodega", "%s %s (%s)" % [Fmt.num(p.stock), d.unit, Fmt.money(p.stock * p.avg_cost)])
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
		y = ui.row(x, y, w, "Siguiente: %s al comprar" % Fmt.pct(nxt[1], 0), "%s/mes" % Fmt.money(nxt[0] * g.price_index), "muted")
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
		if ui.button(Rect2(x + 80 + i * 92, y, 86, 28), "%d meses" % terms[i], true, "normal", 13, null, loan_months == terms[i]):
			loan_months = terms[i]
	y += 40
	var pay := g.loan_payment(loan_amount, loan_months, rate)
	y = ui.row(x, y, w, "Cuota mensual (sistema francés)", Fmt.money(pay), "text", "Cuotas iguales. Al principio pagas más interés; al final, más capital.")
	y = ui.row(x, y, w, "Intereses totales", Fmt.money(pay * loan_months - loan_amount), "red")
	if ui.button(Rect2(x, y + 4, w, 38), "Solicitar préstamo", limit >= loan_amount, "primary"):
		act(g.take_loan(loan_amount, loan_months))
	y += 58
	ui.text("Préstamos activos", Vector2(x, y), 15, "muted", true)
	y += 26
	if g.loans.is_empty():
		ui.text("No tienes deudas.", Vector2(x, y), 14, "muted")
	for loan in g.loans.duplicate():
		if y > CY + CH - 40:
			break
		ui.text("%s al %s · %d cuotas de %s" % [Fmt.money(loan.principal), Fmt.pct(loan.rate), loan.months_left, Fmt.money(loan.payment)],
				Vector2(x, y + 4), 14, "text")
		var payoff := g.prepay_amount(loan)
		if ui.button(Rect2(x + w - 90, y, 90, 26), "Prepagar", g.cash >= payoff, "normal", 13,
				"Pagas hoy %s (el saldo más el interés de los días que van del mes) y te ahorras los intereses futuros." % Fmt.money(payoff)):
			act(g.prepay_loan(loan))
		y += 32

	var rx := CX + lw + 12
	var rw := CW - lw - 12
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
		act(g.buy_bonds(bond_amount))
	if ui.button(Rect2(x + bw + 5, y, bw, 34), "Retirar", g.bonds > 0):
		act(g.sell_bonds(bond_amount))
	if ui.button(Rect2(x + 2 * (bw + 5), y, bw, 34), "Retirar todo", g.bonds > 0):
		act(g.sell_bonds(g.bonds))
	ui.wrap_text("Costo de oportunidad: si una sucursal te rinde menos que estos bonos, ese dinero estaría mejor aquí. Si rinde más, conviene invertirlo en el negocio.",
			Rect2(x, y + 50, w, 80), 13, "muted")

	var y0 := CY + 328
	ui.panel(Rect2(rx, y0, rw, CH - 328), "Impuestos y riesgo")
	x = rx + 20
	y = y0 + 46
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
	y = ui.row(x, y, w, "Nivel actual", "%d · %s" % [g.hq_level, lvl[0]], "accent")
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
		y = ui.row(x, y, w, "Siguiente: %s" % nxt[0], "−%d%% de gastos" % roundi((1 - nxt[2] / factor) * 100))
		y = ui.row(x, y, w, "Ahorro mensual hoy", Fmt.money(saving), "green",
				"Con más sucursales el ahorro crece. La inversión se deprecia en 5 años como cualquier activo.")
		var months = cost / saving if saving > 0 else null
		y = ui.row(x, y, w, "Se paga sola en", "%d meses" % roundi(months) if months != null and months < 999 else "aún no conviene")
		if ui.button(Rect2(x, y + 6, w, 40), "Instalar por %s" % Fmt.money(cost), g.cash >= cost, "primary"):
			act(g.upgrade_hq())

	var y0 := CY + 312
	ui.panel(Rect2(CX, y0, lw, CH - 312), "Fondo de inversión (bolsa)",
			"Riesgo y rentabilidad: en promedio rinde más que los bonos, pero sube y baja todos los días y cae fuerte en recesión.")
	x = CX + 20
	y = y0 + 46
	var expected: float = D.FUND_RETURN[g.phase]
	y = ui.row(x, y, w, "Invertido (valor de mercado)", Fmt.money(g.fund), "accent")
	y = ui.row(x, y, w, "Rendimiento esperado en %s" % D.PHASES[g.phase].name.to_lower(), Fmt.pct(expected),
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
		act(g.invest_fund(fund_amount))
	if ui.button(Rect2(x + bw + 5, y, bw, 34), "Retirar", g.fund > 0):
		act(g.withdraw_fund(fund_amount))
	if ui.button(Rect2(x + 2 * (bw + 5), y, bw, 34), "Retirar todo", g.fund > 0):
		act(g.withdraw_fund(g.fund))

	var rx := CX + lw + 12
	var rw := CW - lw - 12
	ui.panel(Rect2(rx, CY, rw, CH), "Títulos")
	x = rx + 20
	w = rw - 40
	y = CY + 46
	var mins := g.play_seconds / 60.0
	y = ui.row(x, y, w, "Tiempo de juego", "%d h %02d min" % [int(mins / 60), int(mins) % 60] if mins >= 60 else "%d min" % roundi(mins))
	y = ui.row(x, y, w, "Modo", D.MODES[g.mode].name, "accent")
	if g.win_seconds != null:
		y = ui.row(x, y, w, "Meta cumplida en", "%d min" % roundi(g.win_seconds / 60.0), "green")
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
	for it in [["Caja", "caja"], ["Bonos", "bonos"], ["Fondo de inversión", "fondo"], ["Inventario", "inventario"],
			["Activos fijos netos", "activos_fijos"]]:
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
		["Costo de oportunidad del capital", "%s/mes" % Fmt.money(max(0.0, eq) * cost_capital / 12),
		 "Lo que tu patrimonio ganaría en otra inversión de riesgo similar (tasa BC + 4%% = %s)." % Fmt.pct(cost_capital)],
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
		ui.text("%s año %d" % [D.MONTHS[m % 12].substr(0, 3), m / 12 + 1], Vector2(area.position.x + 10, y + 4), 13, "muted")
		ui.text(n.text, Vector2(area.position.x + 130, y + 3), 15, ImUI.KIND_COLOR[n.kind], false, "topleft", area.size.x - 140)
	ui.set_clip(null)


# ---------- Conceptos ----------
func draw_conceptos(g: Game) -> void:
	ui.panel(Rect2(CX, CY, CW, CH), "Conceptos de economía y rentabilidad que usa el juego")
	var area := Rect2(CX + 10, CY + 44, CW - 20, CH - 54)
	var colw := (area.size.x - 30) / 2
	var heights: Array = cached("concept_heights", func():
		return D.CONCEPTS.map(func(c): return ui.wrap_height(c[1], colw - 24, 14) + 48))
	var rows := []
	for i in range(0, heights.size(), 2):
		rows.append(heights.slice(i, i + 2).max())
	var total := 0.0
	for h in rows:
		total += h
	var s := scroll_area("concepts", area, total + 10)
	ui.set_clip(area)
	var y := area.position.y - s
	for i in range(0, D.CONCEPTS.size(), 2):
		var h: float = rows[i / 2]
		for j in 2:
			if i + j >= D.CONCEPTS.size():
				break
			var c: Array = D.CONCEPTS[i + j]
			var x := area.position.x + 10 + j * (colw + 10)
			if y + h > area.position.y and y < area.end.y:
				ui.rect(Rect2(x, y, colw, h - 8), "panel2", 8)
				ui.text(c[0], Vector2(x + 12, y + 8), 16, "accent", true)
				ui.wrap_text(c[1], Rect2(x + 12, y + 32, colw - 24, h), 14, "text")
		y += h
	ui.set_clip(null)
