class_name Hud
extends RefCounted
## Lo que se ve encima de la ciudad mientras juegas: datos de la empresa, botón a la oficina, velocidad, el aviso
## de [E], la ayuda, el nombre de la zona, los avisos, la alarma de quiebra y el confeti.
## Usa una pantalla virtual de 760 px de alto y el ancho de la ventana (pegada a los bordes).

var city
var ui: ImUI
var notes: Notifications
var confetti := Confetti.new()
var help_timer := 30.0
var zone := ["", ""]
var zone_t := 99.0
var danger_phase := 0.0
var danger_level := 0.0
var alarm_t := 0.0         # segundos desde que se pasó el límite de sobregiro
const ALARM_INTRO := 8.0   # segundos de alarma fuerte al pasar el límite
const FINAL_DAYS := 5      # en los últimos días antes de la quiebra la tensión vuelve a subir
var prompt := ""
const PANEL_W := 420.0   # tarjeta de la empresa, arriba a la izquierda (el alto depende de cuántos chips haya)
const SHORT := {"cafe": "Café", "pan": "Pan", "burger": "Burger", "ropa": "Ropa", "tech": "Tech"}
var panel := Rect2(12, 12, PANEL_W, 196)
const SKY_BUTTONS := [["Día", 0.24], ["Tarde", 0.6], ["Noche", 0.81]]   # punto del ciclo que fija cada botón


class Confetti:
	const COLORS := [Color8(255, 196, 60), Color8(80, 200, 120), Color8(90, 170, 255), Color8(255, 110, 110),
			Color8(180, 130, 255), Color8(255, 255, 255)]
	var bits := []

	func burst(n: int, at: Vector2) -> void:
		for i in min(n, 180 - bits.size()):
			bits.append({"p": at + Vector2(randf_range(-200, 200), randf_range(-10, 10)),
					"v": Vector2(randf_range(-600, 600), -randf_range(230, 760)), "r": randf_range(0, TAU),
					"spin": randf_range(-9, 9), "life": randf_range(2.0, 3.2), "c": COLORS.pick_random()})

	func update(dt: float, h: float) -> void:
		for b in bits.duplicate():
			b.v.y += 1060 * dt
			b.v.x *= 1 - 0.9 * dt
			b.p += b.v * dt
			b.r += b.spin * dt
			b.life -= dt
			if b.life <= 0 or b.p.y > h + 20:
				bits.erase(b)

	func draw(ui: ImUI) -> void:
		for b in bits:
			var xf := Transform2D(b.r, b.p)
			var pts := PackedVector2Array([xf * Vector2(-4, -7), xf * Vector2(4, -7), xf * Vector2(4, 7), xf * Vector2(-4, 7)])
			ui.polygon(pts, b.c)


func _init(owner_city, parent_item: RID) -> void:
	city = owner_city
	ui = ImUI.new(parent_item, 1280, 760)
	notes = Notifications.new(city)


func update(dt: float) -> void:
	help_timer -= dt
	zone_t += dt
	confetti.update(dt, ui.H)
	notes.update(dt, city.overlays.open())


func set_zone(z: Array) -> void:
	if z != zone:
		zone = z
		zone_t = 0.0


## Bordes rojos que laten cuando la caja está en negativo, y cuenta regresiva a la quiebra.
func update_danger(g, dt: float) -> void:
	var level := 0.0
	var rate := 1.0
	if g and not g.game_over and g.cash < 0:
		if g.overdraft_days > 0:
			level = 1.0
			rate = 1.0 + 0.9 * g.overdraft_days / 20.0
		else:
			level = 0.4
	danger_level = level
	danger_phase += dt * rate
	# El sonido va por etapas para no cansar: al pasar el límite suena fuerte unos segundos, después queda una mezcla
	# suave sin latido, y en los últimos días antes de la quiebra vuelve a subir cada vez más.
	var music := 0.12 if level > 0 else 0.0   # sobregiro dentro del límite: apenas un toque tenso
	var beat := 0.0
	if level >= 1:
		alarm_t += dt
		var left: int = 20 - g.overdraft_days
		if alarm_t < ALARM_INTRO:
			music = 1.0
			beat = 0.9 * clampf((ALARM_INTRO - alarm_t) / 2.0, 0, 1)   # el latido se apaga al final del aviso
		elif left <= FINAL_DAYS:
			var k := clampf(float(FINAL_DAYS - left) / (FINAL_DAYS - 1), 0, 1)  # 0 con 5 días, 1 con el último
			music = lerpf(0.55, 1.0, k)
			beat = lerpf(0.35, 0.9, k)
		else:
			music = 0.3
	else:
		alarm_t = 0.0
	city.sfx.heartbeat(beat, rate)
	city.sfx.update_music(music, dt)


func draw(mouse_window: Vector2, clicked: bool, size: Vector2) -> void:
	ui.place_fill(size)
	ui.begin(mouse_window, clicked, 0, false)
	var g = city.game
	var visible: bool = g != null and city.overlays.mode != "personaje"
	if visible:
		if city.weather.flash > 0.01 and not city.camera_indoors():  # relámpago de la tormenta
			ui.rect(Rect2(0, 0, ui.W, ui.H), Color(0.9, 0.93, 1.0, city.weather.flash * 0.35))
		_draw_danger(g)
		_draw_panel(g)
		_draw_panel_buttons(g)
		_draw_center()
		city.tutorial.draw(ui)
		notes.draw(ui)
	confetti.draw(ui)
	ui.end()


## Tarjeta de la empresa (como el panel de estado de los juegos de gestión): fecha y hora, la caja en grande, el
## valor de la empresa, el rango con su barra de progreso y chips con la racha y la reputación de cada negocio.
func _draw_panel(g) -> void:
	# Primero se ubican los chips (racha y reputación) para saber cuántas filas ocupan y qué tan alto es el panel
	var streak: int = g.profit_streak
	var wd: Dictionary = D.WEATHER[g.weather]
	var chips := [[wd.name, "weather"]]
	if g.locations:
		var total := 0.0
		for l in g.locations:
			total += Game.stars_of(l)
		chips.append([Fmt.num(total / g.locations.size(), 1), "stars"])
	chips.append(["%d %s" % [streak, "mes" if streak == 1 else "meses"] if streak else "Sin racha", null])
	for key in D.PRODUCT_ORDER:
		if g.locs(key):
			chips.append([SHORT[key], key])
	var inner := PANEL_W - 36
	var rows := [[]]
	var used := 0.0
	for ch in chips:
		var w := _chip_width(ch)
		if used + w > inner and rows[-1]:
			rows.append([])
			used = 0.0
		rows[-1].append(ch)
		used += w + 6
	panel.size.y = 172 + 30 * rows.size()
	var r := panel
	ui.rect(r, Color(0.04, 0.055, 0.075, 0.86), 16)
	ui.rect(r, Color(1, 1, 1, 0.06), 16, 1)
	var x := r.position.x + 18
	var right := r.end.x - 18
	# Encabezado: logo, fecha y hora con el sol o la luna
	ui.text(String(g.company).to_upper(), Vector2(x, r.position.y + 13), 15, "accent", true, "topleft", 200)
	var hour: float = SkyLight.hour_of(city.day_fraction())
	var dp: Array = g.date_parts()
	var night: bool = hour < 6.5 or hour > 19.5
	var clock := ui.text("%02d:%02d" % [int(hour), int(fmod(hour, 1.0) * 60)], Vector2(right, r.position.y + 12), 16, "text", true, "topright")
	Icons.draw(ui, Icons.weather(g.weather, night), Vector2(clock.position.x - 16, clock.get_center().y), 22)
	ui.text("Día %d %s · Año %d" % [dp[0], dp[1].substr(0, 3).to_lower(), dp[2]], Vector2(clock.position.x - 34, r.position.y + 14), 14,
			"muted", false, "topright")
	ui.line(Vector2(x, r.position.y + 42), Vector2(right, r.position.y + 42), Color(1, 1, 1, 0.08))
	# Caja y valor de la empresa
	var info: Array = g.rank_info()
	var y := r.position.y + 52
	ui.text("CAJA", Vector2(x, y), 11, "muted", true)
	ui.text(Fmt.money(g.cash), Vector2(x, y + 14), 30, "green" if g.cash >= 0 else "red", true)
	ui.text("VALOR DE LA EMPRESA", Vector2(right, y), 11, "muted", true, "topright")
	ui.text(Fmt.money(info[3]), Vector2(right, y + 18), 22, "accent", true, "topright")
	# Rango: medalla, nombre, siguiente rango y barra
	y += 62
	var medal := Vector2(x + 13, y + 13)
	ui.circle(medal, 13, ImUI.COL.accent)
	ui.circle(medal, 9.5, Color8(150, 110, 30))
	Icons.draw(ui, "star", medal, 13, ImUI.COL.accent)
	ui.text(info[1], Vector2(x + 34, y + 3), 17, "text", true, "topleft", 210)
	if info[2] != null:
		var lo: float = D.RANKS[info[0]][0]
		var frac := clampf((info[3] - lo) / (info[2][0] - lo), 0, 1)
		var close := frac >= 0.9
		var blink := close and int(Time.get_ticks_msec() / 333) % 2 == 0
		ui.text("%s hacia %s" % [Fmt.pct(frac, 0), info[2][1]], Vector2(right, y + 6), 13, "accent" if blink else "muted",
				close, "topright", 150)
		var bar := Rect2(x + 34, y + 27, right - x - 34, 6)
		ui.rect(bar, Color(1, 1, 1, 0.08), 3)
		if frac > 0:
			ui.rect(Rect2(bar.position, Vector2(max(6.0, bar.size.x * frac), 6)), Color8(255, 215, 110) if blink else ImUI.COL.accent, 3)
	else:
		ui.text("Rango máximo", Vector2(right, y + 6), 13, "accent", true, "topright")
	# Chips: racha y reputación de cada negocio
	y += 46
	var sc: Color = ImUI.COL.orange if streak >= 3 else (ImUI.COL.text if streak else ImUI.COL.muted)
	for row in rows:
		var cx := x
		for ch in row:
			if ch[1] == "weather":
				cx = _chip(Vector2(cx, y), ch[0], Color8(255, 140, 70) if g.weather == 4 else Color8(120, 185, 240), _weather_tip(g),
						Icons.weather(g.weather, night))
			elif ch[1] == "stars":
				cx = _chip(Vector2(cx, y), ch[0], Color8(240, 190, 60), "Promedio de estrellas de tus locales. Con 5 estrellas un local vende 15% más que con 3.", "star")
			elif ch[1] == null:
				cx = _chip(Vector2(cx, y), ch[0], sc, "Meses seguidos con utilidad", "heart")
			else:
				var rep: float = g.products[ch[1]].reputation
				var c: Color = ImUI.COL.green if rep >= 60 else (ImUI.COL.orange if rep >= 35 else ImUI.COL.red)
				cx = _rep_chip(Vector2(cx, y), ch[0], rep, c, D.PRODUCTS[ch[1]].name)
		y += 30


## Qué hace el clima de hoy con la demanda, para el tooltip del chip.
func _weather_tip(g) -> String:
	var names := {"cafe": "café", "pan": "pan", "burger": "hamburguesas", "ropa": "ropa", "tech": "electrónica",
			"all": "gente en la calle", "beach": "playa", "stall": "puestos", "spoil": "mermas"}
	var parts := []
	var fx: Dictionary = D.WEATHER[g.weather].effects
	for k in fx:
		var pct := roundi((fx[k] - 1.0) * 100)
		parts.append("%s %s%d%%" % [names.get(k, k), "+" if pct > 0 else "", pct])
	var text: String = "Hoy: %s. " % D.WEATHER[g.weather].name
	text += ("Efectos: " + ", ".join(parts) + ".") if parts else "Sin efectos en la demanda."
	return text + " Pronóstico: %s en %d días." % [D.WEATHER[g.weather_next].name.to_lower(), g.weather_days]


func _chip_width(ch: Array) -> float:
	if ch[1] in [null, "weather", "stars"]:
		return ui.text_size(ch[0], 12, true).x + 18 + 17
	return ui.text_size(ch[0], 12).x + 48


## Chip redondeado con texto. Devuelve la x donde empieza el siguiente.
func _chip(pos: Vector2, text: String, color: Color, tip = null, icon := "") -> float:
	var iw := 17.0 if icon else 0.0
	var w := ui.text_size(text, 12, true).x + 18 + iw
	var r := Rect2(pos, Vector2(w, 24))
	ui.rect(r, Color(color, 0.14), 12)
	if icon:
		Icons.draw(ui, icon, Vector2(r.position.x + 15, r.get_center().y), 15, color)
	ui.text(text, r.get_center() + Vector2(iw / 2, 0), 12, color, true, "center")
	ui.tooltip(r, tip)
	return r.end.x + 6


## Chip de reputación: nombre del negocio y una barrita del 0 al 100 con su color.
func _rep_chip(pos: Vector2, name: String, rep: float, color: Color, full_name: String) -> float:
	var tw := ui.text_size(name, 12).x
	var r := Rect2(pos, Vector2(tw + 48, 24))
	ui.rect(r, Color(1, 1, 1, 0.06), 12)
	ui.text(name, Vector2(r.position.x + 10, r.get_center().y), 12, "text", false, "midleft")
	var bar := Rect2(r.position.x + tw + 16, r.get_center().y - 2.5, 22, 5)
	ui.rect(bar, Color(1, 1, 1, 0.1), 2.5)
	ui.rect(Rect2(bar.position, Vector2(max(5.0, 22 * rep / 100.0), 5)), color, 2.5)
	ui.tooltip(r, "Reputación de %s: %d de 100" % [full_name, roundi(rep)])
	return r.end.x + 6


func _draw_panel_buttons(g) -> void:
	# Botón para ir a la oficina
	var b := hq_button_rect()
	var hot: bool = not city.mouse_captured() and not city.overlays.open() and ui.hover(b)
	ui.rect(b, Color8(250, 205, 90) if hot else Color8(227, 179, 65), 14)
	ui.text("Ir a la oficina  [%s]" % Keys.label("office"), b.get_center(), 16, Color8(25, 25, 30), true, "center")
	# Celular con los avisos que no has leído (se ven en Noticias)
	var label := "Celular  [%s]" % Keys.label("phone")
	var n := str(mini(city.app.unread, 99))
	var cr := maxf(10.0, ui.text_size(n, 12, true).x / 2 + 5)
	var pr := Rect2(b.end.x + 8, b.position.y, ui.text_size(label, 15).x + 24 + (cr * 2 + 6 if city.app.unread else 0.0), b.size.y)
	ui.rect(pr, Color(0.05, 0.067, 0.09, 0.72), 16)
	var lt := ui.text(label, Vector2(pr.position.x + 12, pr.get_center().y), 15, "text", false, "midleft")
	if city.app.unread:
		var c := Vector2(lt.end.x + 6 + cr, pr.get_center().y)
		ui.circle(c, cr, Color8(225, 85, 75))
		ui.text(n, c, 12, Color.WHITE, true, "center")
	# Velocidad arriba a la derecha
	var app = city.app
	var speed: String = "PAUSA" if app.paused else "Velocidad %s" % Admin.SPEEDS[app.speed][1]
	if city.settings.get("g_show_fps", false):
		speed = "%d FPS  ·  " % Engine.get_frames_per_second() + speed
	speed += "  ·  %d min de juego" % int(g.play_seconds / 60)
	var sw := ui.text_size(speed, 18).x + 28
	ui.rect(Rect2(ui.W - 12 - sw, 12, sw, 34), Color(0.05, 0.067, 0.09, 0.72), 17)
	ui.text(speed, Vector2(ui.W - 26, 17), 18, "text", false, "topright")
	# Luz fija para ver la ciudad de día, al atardecer o de noche (se suelta el mouse con Alt para apretarlos)
	var free: bool = not city.mouse_captured() and not city.overlays.open()
	for i in SKY_BUTTONS.size():
		var sb := sky_button_rect(i)
		var on: bool = city.sky_lock == SKY_BUTTONS[i][1]
		var sb_hot := free and ui.hover(sb)
		ui.rect(sb, Color8(227, 179, 65) if on else Color(0.05, 0.067, 0.09, 0.85 if sb_hot else 0.72), 14)
		ui.text(SKY_BUTTONS[i][0], sb.get_center(), 15, Color8(25, 25, 30) if on else Color.WHITE, on, "center")
	var extra := 0
	for l in g.locations:
		if Game.plot_of(l) == -1 and l.get("plot") != null:
			extra += 1
	if extra:
		ui.text("+%d sucursales fuera del centro" % extra, Vector2(ui.W - 26, 90), 14, "text", false, "topright")


func sky_button_rect(i: int) -> Rect2:
	return Rect2(ui.W - 12 - (SKY_BUTTONS.size() - i) * 80, 52, 74, 28)


## La hora del botón Día / Tarde / Noche que está bajo el mouse, o null.
func sky_button_at():
	if city.game == null:
		return null
	for i in SKY_BUTTONS.size():
		if ui.hover(sky_button_rect(i)):
			return SKY_BUTTONS[i][1]
	return null


func hq_button_rect() -> Rect2:
	return Rect2(12, panel.end.y + 8, 206, 32)


func _draw_center() -> void:
	var cx := ui.W / 2
	# Nombre de la zona al entrar (como en los juegos de mundo abierto)
	var k := zone_t
	var za := clampf(min(k / 0.5, (3.2 - k) / 0.8), 0, 1) if k > 0.05 else 0.0
	if za > 0 and not city.overlays.open():
		ui.canvas_alpha(za)
		ui.text(zone[0].to_upper(), Vector2(cx, 236), 40, Color.WHITE, true, "center")
		ui.rect(Rect2(cx - 115 * clampf(k / 0.6, 0, 1), 266, 230 * clampf(k / 0.6, 0, 1), 2), "accent")
		ui.text(zone[1], Vector2(cx, 286), 18, Color8(235, 235, 240), false, "center")
		ui.canvas_alpha(1.0)
	if prompt and not city.overlays.open():
		var w := ui.text_size(prompt, 22, true).x + 36
		ui.rect(Rect2(cx - w / 2, 590, w, 40), Color(0.05, 0.067, 0.09, 0.7), 20)
		ui.text(prompt, Vector2(cx, 610), 22, Color.WHITE, true, "center")
	if help_timer > 0 and not city.overlays.open():
		ui.canvas_alpha(clampf(help_timer, 0, 1))
		var kl := func(a: String) -> String: return Keys.label(a)
		var lines := ["%s%s%s%s: caminar · %s: correr · %s: saltar · Mouse: mirar · Rueda/%s: cámara · %s: música" % [
				kl.call("forward"), kl.call("left"), kl.call("back"), kl.call("right"), kl.call("run"), kl.call("jump"),
				kl.call("camera"), kl.call("music")],
				"%s: interactuar · %s: celular · %s: pausa · %s/%s/%s: velocidad · %s: pantalla completa · Esc: menú · Alt: mouse libre" % [
				kl.call("interact"), kl.call("phone"), kl.call("pause_quick"), kl.call("speed1"), kl.call("speed2"),
				kl.call("speed3"), kl.call("fullscreen")]]
		ui.rect(Rect2(cx - 440, 500, 880, 58), Color(0.05, 0.067, 0.09, 0.6), 12)
		for i in 2:
			ui.text(lines[i], Vector2(cx, 516 + i * 24), 15, Color.WHITE, false, "center")
		ui.canvas_alpha(1.0)
	if city.first_person and not city.overlays.open():
		ui.circle(Vector2(cx, ui.H / 2), 3, Color(1, 1, 1, 0.9))


func _draw_danger(g) -> void:
	var level := danger_level
	if level <= 0:
		return
	var beat := fmod(danger_phase, 1.0)
	var pulse: float = min(1.0, exp(-beat * 8) + (0.7 * exp(-(beat - 0.26) * 8) if beat > 0.26 else 0.0))
	var a := level * (0.3 + 0.55 * pulse)
	# Viñeta roja en los bordes
	var red := Color(1, 0.08, 0.08, a)
	var clear := Color(1, 0.08, 0.08, 0)
	var w := ui.W
	var h := ui.H
	var e := 150.0
	for quad in [[Vector2(0, 0), Vector2(w, 0), Vector2(w, e), Vector2(0, e), true],
			[Vector2(0, h - e), Vector2(w, h - e), Vector2(w, h), Vector2(0, h), false]]:
		var cols := PackedColorArray([red, red, clear, clear]) if quad[4] else PackedColorArray([clear, clear, red, red])
		RenderingServer.canvas_item_add_polygon(ui.canvas, PackedVector2Array([quad[0], quad[1], quad[2], quad[3]]), cols)
	RenderingServer.canvas_item_add_polygon(ui.canvas, PackedVector2Array([Vector2(0, 0), Vector2(e, 0), Vector2(e, h), Vector2(0, h)]),
			PackedColorArray([red, clear, clear, red]))
	RenderingServer.canvas_item_add_polygon(ui.canvas, PackedVector2Array([Vector2(w - e, 0), Vector2(w, 0), Vector2(w, h), Vector2(w - e, h)]),
			PackedColorArray([clear, red, red, clear]))


## [título, detalle] de la alerta fija de quiebra (la dibujan los avisos, encima de todos), o [] si no hay peligro.
func danger_text() -> Array:
	var g = city.game
	if danger_level <= 0 or g == null:
		return []
	if g.overdraft_days > 0:
		var left: int = max(1, 20 - g.overdraft_days)
		return ["¡Quiebra en %d día%s!" % [left, "s" if left > 1 else ""],
				"Pasaste el límite de sobregiro: vende algo, pide un préstamo o recorta costos (Tab)."]
	return ["Estás en sobregiro", "Caja negativa: pagas %s anual de interés sobre ese saldo." % Fmt.pct(g.policy_rate + 0.18, 0)]


## Latido de la alarma (0 a 1), al ritmo del corazón que suena.
func danger_pulse() -> float:
	var beat := fmod(danger_phase, 1.0)
	return min(1.0, exp(-beat * 8) + (0.7 * exp(-(beat - 0.26) * 8) if beat > 0.26 else 0.0)) * danger_level
