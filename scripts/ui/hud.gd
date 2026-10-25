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
var prompt := ""
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
	city.sfx.heartbeat(0.9 * level if level >= 1 else 0.3 * level, rate)
	city.sfx.update_music(level, dt)


func draw(mouse_window: Vector2, clicked: bool, size: Vector2) -> void:
	ui.place_fill(size)
	ui.begin(mouse_window, clicked, 0, false)
	var g = city.game
	var visible: bool = g != null and city.overlays.mode != "personaje"
	if visible:
		_draw_danger(g)
		_draw_panel(g)
		_draw_center()
		notes.draw(ui)
	confetti.draw(ui)
	ui.end()


func _draw_panel(g) -> void:
	var r := Rect2(12, 12, 532, 188)
	ui.rect(r, Color(0.05, 0.067, 0.09, 0.78), 14)
	ui.text("CAPITAL", Vector2(26, 18), 26, "accent", true)
	var hour: float = SkyLight.hour_of(city.day_fraction())
	var info: Array = g.rank_info()
	var dp: Array = g.date_parts()
	var lines := []
	lines.append(["Día %d · %s · Año %d · %02d:%02d" % [dp[0], dp[1], dp[2], int(hour), int(fmod(hour, 1.0) * 60)], "text"])
	lines.append(["Caja: %s" % Fmt.money(g.cash), "green" if g.cash >= 0 else "red"])
	lines.append(["Valor de la empresa: %s" % Fmt.money(info[3]), "text"])
	if info[2] != null:
		var lo: float = D.RANKS[info[0]][0]
		var frac := clampf((info[3] - lo) / (info[2][0] - lo), 0, 1)
		var close := frac >= 0.9
		var blink := close and int(Time.get_ticks_msec() / 333) % 2 == 0
		lines.append(["Rango: %s · %s hacia %s%s" % [info[1], Fmt.pct(frac, 0), info[2][1], "  ¡CASI!" if close else ""],
				"accent" if blink else "text"])
	else:
		lines.append(["Rango: %s" % info[1], "accent"])
	var streak: int = g.profit_streak
	lines.append(["Racha: %d %s con utilidad" % [streak, "mes" if streak == 1 else "meses"] if streak
			else "Racha: ningún mes con utilidad todavía", "orange" if streak >= 3 else "muted"])
	for i in lines.size():
		ui.text(lines[i][0], Vector2(26, 56 + i * 24), 17, lines[i][1])
	# Reputación de cada negocio, con su color
	var x := 26.0
	var y := 56 + 5 * 24.0
	x = ui.text("Reputación: ", Vector2(x, y), 17, "text").end.x
	var any := false
	for key in D.PRODUCT_ORDER:
		var p: Dictionary = g.products[key]
		if g.locs(key):
			any = true
			var c := "green" if p.reputation >= 60 else ("orange" if p.reputation >= 35 else "red")
			x = ui.text("%s %d" % [D.PRODUCTS[key].name, roundi(p.reputation)], Vector2(x, y), 17, c).end.x + 12
	if not any:
		ui.text("sin locales", Vector2(x, y), 17, "muted")
	# Botón para ir a la oficina
	var b := hq_button_rect()
	var hot: bool = not city.mouse_captured() and not city.overlays.open() and ui.hover(b)
	ui.rect(b, Color8(250, 205, 90) if hot else Color8(227, 179, 65), 14)
	ui.text("Ir a la oficina  [O]", b.get_center(), 16, Color8(25, 25, 30), true, "center")
	# Velocidad arriba a la derecha
	var app = city.app
	var speed: String = "PAUSA" if app.paused else "Velocidad %s" % Admin.SPEEDS[app.speed][1]
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
	return Rect2(12, 210, 228, 32)


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
		var lines := ["WASD: caminar · Shift: correr · Espacio: saltar · Mouse: mirar · Rueda/V: cámara · M: música",
				"E: interactuar · Tab: celular · P: pausa · 1/2/3: velocidad · F11: pantalla completa · Esc: menú · Alt: mouse libre"]
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
	var label := ""
	var hint := ""
	if g.overdraft_days > 0:
		var left: int = max(1, 20 - g.overdraft_days)
		label = "¡Quiebra en %d día%s!" % [left, "s" if left > 1 else ""]
		hint = "Pasaste el límite de sobregiro: vende algo, pide un préstamo o recorta costos (Tab)"
	else:
		label = "Estás en sobregiro"
		hint = "Caja negativa: pagas %s anual de interés sobre ese saldo" % Fmt.pct(g.policy_rate + 0.18, 0)
	# Arriba al centro: no la tapa nada
	var s := 1 + 0.04 * pulse * level
	var pr := Rect2(ui.W / 2 - 300 * s, 92 - 32 * s, 600 * s, 64 * s)
	ui.rect(pr, Color8(225, 70, 60, 235) if level >= 1 else Color8(240, 150, 60, 230), 32 * s)
	ui.text(label, Vector2(ui.W / 2, 80), 26, Color.WHITE, true, "center")
	ui.text(hint, Vector2(ui.W / 2, 108), 14, Color8(255, 235, 230), false, "center")
