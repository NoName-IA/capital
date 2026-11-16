class_name Notifications
extends RefCounted
## Los avisos llegan como notificaciones del celular de la empresa: tarjetas apiladas arriba a la derecha, cada una
## con el ícono de su "app" (Banco, Noticias, Mensajes de los rivales...). Se ven hasta 3 a la vez, la más nueva
## arriba, y se van solas; mientras hay peligro de quiebra una alerta roja queda fija encima de todas.
## Los hitos grandes (rango, récord, racha, imperio) salen como una cinta de bolsa arriba al centro, con un gráfico
## que sube, sin tapar el juego; esperan si hay una decisión urgente cerca (Admin.GAP_MS). Las respuestas
## a lo que haces (música, llegaste a la oficina...) como un aviso chico abajo. Todo queda en Noticias del celular.

const LIFE := 6.0          # segundos que dura una tarjeta (el reloj se detiene con un menú abierto)
const MAX_CARDS := 3
const SOUND_VOL := {"record": 0.45, "coin": 0.45, "fanfare": 0.45}   # los avisos suenan más bajito
const CARD_W := 372.0
const TOP := 92.0          # debajo de la velocidad y los botones Día / Tarde / Noche
const GAP := 8.0
const HERO_LIFE := 4.2
const HERO_W := 450.0
const HERO_H := 84.0
const HINT_LIFE := 3.0
const BG := Color(0.05, 0.067, 0.09, 0.9)
const TEXT := Color8(232, 236, 244)
const MUTED := Color8(140, 150, 170)
# app -> [nombre, color, ícono]
const APPS := {
	"banco": ["BANCO", Color8(46, 170, 90), "bank"],
	"ventas": ["VENTAS", Color8(46, 170, 90), "chart"],
	"noticias": ["NOTICIAS", Color8(70, 140, 230), "news"],
	"mensajes": ["MENSAJES", Color8(160, 120, 230), "chat"],
	"oficina": ["OFICINA", Color8(70, 140, 230), "building"],
	"decision": ["DECISIONES", Color8(240, 140, 50), "question"],
	"alerta": ["ALERTA", Color8(225, 85, 75), "alert"],
	"clima": ["CLIMA", Color8(90, 170, 230), "umbrella"],
	"resenas": ["RESEÑAS", Color8(240, 190, 60), "star"],
	"ciudad": ["CIUDAD", Color8(90, 180, 120), "building"],
}

var city
var cards := []            # tarjetas en pantalla, la más nueva primero
var waiting := []          # tarjetas que esperan lugar
var heroes := []           # carteles del centro en fila
var hero = null
var hint_card = null


func _init(owner_city) -> void:
	city = owner_city


## Notificación del celular. opts: sound, initials, col (color del ícono), count (monto que se anima en "{}"),
## low (poco importante: no se muestra si ya hay varias esperando).
func push(app: String, title: String, body := "", opts := {}) -> void:
	city.app.unread += 1
	var spec: Array = APPS.get(app, APPS.noticias)
	var d := {"app": spec[0], "col": opts.get("col", spec[1]), "icon": opts.get("initials", opts.get("icon", spec[2])),
			"letters": opts.has("initials"), "rival": opts.get("rival"),
			"title": title, "body": body, "count": opts.get("count"), "when": _when(), "repeat": 1,
			"sound": opts.get("sound"), "t": 0.0, "alpha": 0.0, "y": -1.0}
	# Lo mismo otra vez (por ejemplo, varias multas seguidas): se suma a la tarjeta que ya está
	for c in cards + waiting:
		if c.title == d.title and c.body == d.body and c.app == d.app:
			c.repeat += 1
			c.count = d.count
			c.when = d.when
			c.t = min(c.t, 1.0)
			return
	if opts.get("low", false) and waiting.size() >= MAX_CARDS:
		return
	waiting.append(d)
	if waiting.size() > 4:
		waiting.pop_front()


## Cartel grande al centro para los hitos: arriba una línea corta en mayúsculas y abajo el título grande.
func push_hero(kicker: String, title: String, sub: String, col: Color, sound = null, confetti := 0, count = null,
		icon := "star", extra := {}) -> void:
	city.app.unread += 1
	for old in heroes.duplicate():   # si ya esperaba uno igual (otro récord), queda solo el más nuevo
		if old.kicker == kicker:
			heroes.erase(old)
	heroes.append({"kicker": kicker, "title": title, "sub": sub, "col": col, "sound": sound, "confetti": confetti,
			"count": count, "t": 0.0, "icon": icon})
	heroes[-1].merge(extra)


## Respuesta inmediata a algo que hiciste: un aviso chico abajo al centro (reemplaza al anterior).
func hint(text: String, kind := "info") -> void:
	var c: Color = {"good": Color8(46, 170, 90), "bad": Color8(225, 85, 75)}.get(kind, Color8(110, 125, 150))
	hint_card = {"text": text, "col": c, "t": 0.0}


func clear() -> void:
	cards.clear()
	waiting.clear()
	heroes.clear()
	hero = null
	hint_card = null


func _when() -> String:
	var g = city.game
	if g == null:
		return ""
	var dp: Array = g.date_parts()
	return Lang.f("Día %d %s", [dp[0], Lang.month_short(dp[1])])


func update(dt: float, frozen: bool) -> void:
	var step := 0.0 if frozen else dt
	# Entran las que esperan, de a una cada tanto para que se alcancen a ver
	if waiting and (cards.is_empty() or cards[0].t > 0.35):
		var d: Dictionary = waiting.pop_front()
		cards.push_front(d)
		if d.sound != null:
			city.sfx.play(d.sound, SOUND_VOL.get(d.sound, 1.0))
		if cards.size() > MAX_CARDS:  # la más vieja se va para dar lugar
			cards[-1].t = max(cards[-1].t, LIFE)
	for c in cards.duplicate():
		c.t += step
		var leaving: bool = c.t >= (LIFE if waiting.is_empty() else LIFE * 0.75)
		c.alpha = clampf(c.alpha + (-dt * 4.0 if leaving else dt * 5.0), 0, 1)
		if leaving and c.alpha <= 0:
			cards.erase(c)
	# Entre una decisión urgente y un hito pasan al menos Admin.GAP_MS: el hito espera su turno
	if hero == null and heroes and not city.rank_must_wait():
		hero = heroes.pop_front()
		hero.seed = randi()
		city.app.last_rank_ms = city.app.now_ms()   # y la próxima decisión espera a este hito
		if hero.sound != null:
			city.sfx.play(hero.sound, SOUND_VOL.get(hero.sound, 1.0))
	if hero != null:
		hero.t += dt  # sigue aunque haya un menú abierto: es una celebración corta
		if hero.t >= HERO_LIFE:
			hero = null
	if hint_card != null:
		hint_card.t += dt
		if hint_card.t >= HINT_LIFE:
			hint_card = null


static func ease_out(k: float) -> float:
	return 1.0 - pow(1.0 - clampf(k, 0, 1), 3)


## Ícono cuadrado redondeado de la app: su dibujo en blanco, o las iniciales de quien escribe.
static func app_icon(ui: ImUI, r: Rect2, col: Color, icon: String, letters := false) -> void:
	ui.rect(r, col, r.size.x * 0.28)
	if letters:
		ui.text(icon, r.get_center() + Vector2(0, 1), int(r.size.y * 0.5), Color8(16, 20, 30), true, "center")
	else:
		Icons.draw(ui, icon, r.get_center(), r.size.x * 0.78, Color.WHITE)


func _card_height(ui: ImUI, c: Dictionary) -> float:
	var h := 34.0 + 21.0 * mini(2, ui._lines(c.title, CARD_W - 28, 15, true).size())
	if c.body:
		h += 17.0 * mini(3, ui._lines(_body(c), CARD_W - 28, 13, false).size()) + 2
	return h + 10


func _body(c: Dictionary) -> String:
	if c.count == null:
		return c.body
	var k: float = ease_out(c.t / 1.2)
	return Lang.t(c.body).format([Fmt.money(c.count * k)], "{}")


func _lines_max(ui: ImUI, text: String, w: float, size: int, is_bold: bool, n: int) -> Array:
	var lines: Array = ui._lines(text, w, size, is_bold)
	if lines.size() > n:
		lines = lines.slice(0, n)
		lines[-1] = lines[-1] + "…"
	return lines


func _draw_card(ui: ImUI, c: Dictionary, r: Rect2, alert := false) -> void:
	ui.rect(r, Color(0.32, 0.06, 0.06, 0.93) if alert else BG, 14)
	ui.rect(r, Color(c.col, 0.55), 14, 1.0)
	var x := r.position.x + 14
	var y := r.position.y + 11
	if c.get("rival") != null and Admin.rival_texture(c.rival) != null:   # el logo o la foto del rival
		Admin.rival_badge(ui, D.rival_by_key(c.rival), Vector2(x + 10, y + 10), 9)
	else:
		app_icon(ui, Rect2(x, y, 20, 20), c.col, c.icon, c.get("letters", false))
	var app := ui.text(c.app, Vector2(x + 28, y + 3), 11, Notifications.light(c.col, 0.25), true)
	if c.repeat > 1:
		var tag := Lang.f("x%d", c.repeat)
		var tw := ui.text_size(tag, 11, true).x + 10
		var tr := Rect2(app.end.x + 8, y + 2, tw, 16)
		ui.rect(tr, c.col, 8)
		ui.text(tag, tr.get_center(), 11, Color8(16, 20, 30), true, "center")
	ui.text(c.when, Vector2(r.end.x - 14, y + 3), 11, MUTED, false, "topright")
	y += 28
	for ln in _lines_max(ui, c.title, r.size.x - 28, 15, true, 2):
		ui.text(ln, Vector2(x, y), 15, Color.WHITE if alert else TEXT, true)
		y += 21
	if c.body:
		y += 2
		for ln in _lines_max(ui, _body(c), r.size.x - 28, 13, false, 3):
			ui.text(ln, Vector2(x, y), 13, Color8(255, 225, 220) if alert else MUTED.lerp(TEXT, 0.45))
			y += 17


static func light(c: Color, k := 0.45) -> Color:
	return c.lerp(Color.WHITE, k)


func draw(ui: ImUI) -> void:
	var x := ui.W - 12 - CARD_W
	var y := TOP
	# Alerta fija de quiebra: no se va mientras dure el peligro
	var danger: Array = city.hud.danger_text()
	if danger:
		var d := {"app": "ALERTA DEL BANCO", "col": APPS.alerta[1], "icon": "alert", "title": danger[0], "body": danger[1],
				"count": null, "when": "", "repeat": 1, "t": 0.0}
		var h := _card_height(ui, d)
		var pulse: float = city.hud.danger_pulse()
		ui.canvas_alpha(1.0)
		var grow := 3.0 * pulse
		_draw_card(ui, d, Rect2(x - grow, y - grow, CARD_W + grow * 2, h + grow * 2), true)
		y += h + GAP
	for c in cards:
		var h := _card_height(ui, c)
		c.y = y if c.y < 0 else lerpf(c.y, y, 0.25)  # las de abajo se corren suave cuando entra una nueva
		var slide := (1.0 - ease_out(c.alpha)) * (CARD_W * 0.6)
		ui.canvas_alpha(c.alpha)
		_draw_card(ui, c, Rect2(x + slide, c.y, CARD_W, h))
		y += h + GAP
	ui.canvas_alpha(1.0)
	_draw_hero(ui)
	_draw_hint(ui)
	ui.canvas_alpha(1.0)


## Cinta arriba al centro, como el aviso de una acción que sube en la bolsa: ícono, el hito y a la derecha un
## gráfico que se dibuja subiendo con su flecha verde. Baja desde arriba y se va sola; no tapa el juego.
func _draw_hero(ui: ImUI) -> void:
	if hero == null:
		return
	if hero.has("rank"):
		_draw_rank_hero(ui)
		return
	var t: float = hero.t
	var a := clampf(min(t / 0.3, (HERO_LIFE - t) / 0.45), 0, 1)
	var slide := (1.0 - ease_out(min(t / 0.45, (HERO_LIFE - t) / 0.45))) * -(HERO_H + 20)
	var col: Color = hero.col
	var r := Rect2(ui.W / 2 - HERO_W / 2, 14 + slide, HERO_W, HERO_H)
	ui.canvas_alpha(a)
	ui.rect(r, Color(0.035, 0.045, 0.065, 0.9), 16)
	ui.rect(r, Color(col, 0.35), 16, 1.0)
	ui.rect(Rect2(r.position.x + 10, r.position.y + 14, 3, HERO_H - 28), col, 2)   # raya del color del hito
	var ic := Rect2(r.position.x + 24, r.get_center().y - 25, 50, 50)
	ui.rect(ic, Color(col, 0.16), 13)
	ui.rect(ic, Color(col, 0.45), 13, 1.0)
	Icons.draw(ui, hero.icon, ic.get_center(), 30, light(col, 0.2))
	var chart := Rect2(r.end.x - 136, r.position.y + 16, 118, HERO_H - 32)
	var tx := ic.end.x + 14
	var tw := chart.position.x - 14 - tx
	ui.text(hero.kicker, Vector2(tx, r.position.y + 13), 11, light(col, 0.15), true)
	var title: String = Lang.t(hero.title)
	if hero.count != null:
		title = title.format([Fmt.money(hero.count * ease_out(t / 1.0))], "{}")
	ui.text(_lines_max(ui, title, tw, 22, true, 1)[0], Vector2(tx, r.position.y + 28), 22, Color.WHITE, true)
	ui.text(_lines_max(ui, Lang.t(hero.sub), tw, 12, false, 1)[0], Vector2(tx, r.position.y + 57), 12, MUTED.lerp(TEXT, 0.3))
	_draw_rise(ui, chart, t, hero.seed)


## Nuevo rango: la misma cinta, pero dorada y con la escalera de rangos a la derecha. Los peldaños que ya subiste
## quedan dorados, el nuevo crece y brilla, y un punto salta del peldaño anterior al nuevo. Un brillo cruza la
## cinta una vez. A la izquierda, galones de rango en vez de un ícono.
func _draw_rank_hero(ui: ImUI) -> void:
	var t: float = hero.t
	var a := clampf(min(t / 0.3, (HERO_LIFE - t) / 0.45), 0, 1)
	var slide := (1.0 - ease_out(min(t / 0.45, (HERO_LIFE - t) / 0.45))) * -(HERO_H + 20)
	var gold: Color = hero.col
	var r := Rect2(ui.W / 2 - HERO_W / 2, 14 + slide, HERO_W, HERO_H)
	ui.canvas_alpha(a)
	ui.gradient(Rect2(r.position.x + 8, r.position.y, r.size.x - 16, r.size.y), Color(0.09, 0.07, 0.03, 0.92), Color(0.035, 0.045, 0.065, 0.92))
	ui.rect(Rect2(r.position.x, r.position.y, 16, r.size.y), Color(0.09, 0.07, 0.03, 0.92), 16)
	ui.rect(Rect2(r.end.x - 16, r.position.y, 16, r.size.y), Color(0.035, 0.045, 0.065, 0.92), 16)
	# brillo que cruza una vez
	var sk := clampf((t - 0.35) / 0.9, 0, 1)
	if sk > 0 and sk < 1:
		var bx := lerpf(r.position.x - 40, r.end.x + 10, ease_out(sk))
		var x0 := clampf(bx, r.position.x + 6, r.end.x - 6)
		var x1 := clampf(bx + 30, r.position.x + 6, r.end.x - 6)
		var x2 := clampf(bx + 30 - 18, r.position.x + 6, r.end.x - 6)
		var x3 := clampf(bx - 18, r.position.x + 6, r.end.x - 6)
		ui.polygon(PackedVector2Array([Vector2(x0, r.position.y + 1), Vector2(x1, r.position.y + 1),
				Vector2(x2, r.end.y - 1), Vector2(x3, r.end.y - 1)]), Color(gold, 0.10 * sin(sk * PI)))
	ui.rect(r, Color(gold, 0.7), 16, 1.5)
	# galones
	var ic := Rect2(r.position.x + 20, r.get_center().y - 26, 52, 52)
	ui.rect(ic, Color(gold, 0.18), 13)
	ui.rect(ic, Color(gold, 0.6), 13, 1.0)
	var idx: int = hero.rank
	var n_chev := clampi(idx, 1, 3)
	for i in n_chev:
		var ck := ease_out(clampf((t - 0.3 - 0.15 * i) / 0.3, 0, 1))
		var cy := ic.get_center().y + (n_chev - 1) * 5.5 - i * 11 + (1.0 - ck) * 6
		var cx := ic.get_center().x
		ui.polyline(PackedVector2Array([Vector2(cx - 13, cy - 1), Vector2(cx, cy - 10), Vector2(cx + 13, cy - 1)]),
				Color(light(gold, 0.25), ck), 4.0)
	# textos
	var chart := Rect2(r.end.x - 134, r.position.y + 14, 116, HERO_H - 28)
	var tx := ic.end.x + 14
	var tw := chart.position.x - 14 - tx
	ui.text(Lang.f("%s · %d/%d", [Lang.t(hero.kicker), idx + 1, D.RANKS.size()]), Vector2(tx, r.position.y + 13), 11, light(gold, 0.2), true)
	ui.text(_lines_max(ui, Lang.t(hero.title), tw, 22, true, 1)[0], Vector2(tx, r.position.y + 28), 22, light(gold, 0.55), true)
	ui.text(_lines_max(ui, Lang.t(hero.sub), tw, 12, false, 1)[0], Vector2(tx, r.position.y + 57), 12, MUTED.lerp(TEXT, 0.3))
	# escalera de rangos (6 peldaños alrededor del actual)
	var steps := 6
	var first := clampi(idx - 3, 0, maxi(0, D.RANKS.size() - steps))
	var gap := 4.0
	var sw := (chart.size.x - gap * (steps - 1)) / steps
	var grow := ease_out(clampf((t - 0.5) / 0.6, 0, 1))
	var tops := []
	for i in steps:
		var ri := first + i
		var h := chart.size.y * (0.3 + 0.7 * float(i) / (steps - 1))
		var x := chart.position.x + i * (sw + gap)
		var full := Rect2(x, chart.end.y - h, sw, h)
		tops.append(Vector2(x + sw / 2, full.position.y))
		if ri < idx:
			ui.rect(full, Color(gold, 0.45), 3)
		elif ri == idx:
			var gh := h * grow
			ui.rect(full, Color(gold, 0.12), 3)
			ui.rect(Rect2(x, chart.end.y - gh, sw, gh), gold, 3)
			if grow >= 1.0:
				var pulse := 0.5 + 0.5 * sin(t * 6.0)
				ui.rect(full.grow(2 + pulse * 2), Color(gold, 0.25 * (1.0 - pulse * 0.5)), 5, 1.5)
		else:
			ui.rect(full, Color(1, 1, 1, 0.12), 3, 1.0)
	# el punto salta del peldaño anterior al nuevo
	var cur := idx - first
	if cur > 0:
		var jk := ease_out(clampf((t - 0.95) / 0.45, 0, 1))
		var p0: Vector2 = tops[cur - 1] + Vector2(0, -6)
		var p1: Vector2 = tops[cur] + Vector2(0, -6)
		var p := p0.lerp(p1, jk) + Vector2(0, -14 * sin(jk * PI))
		ui.circle(p, 4.5, Color.WHITE)
		ui.circle(p, 2.5, gold)


## Gráfico chico que se dibuja de izquierda a derecha y siempre termina arriba: área bajo la línea, cuadrícula de
## fondo, un punto que late al final y una flecha verde.
func _draw_rise(ui: ImUI, r: Rect2, t: float, seed: int) -> void:
	var up := Color8(60, 200, 120)
	for i in 3:   # cuadrícula
		var gy := r.position.y + r.size.y * (0.15 + 0.35 * i)
		ui.line(Vector2(r.position.x, gy), Vector2(r.end.x, gy), Color(1, 1, 1, 0.06), 1.0)
	var rng := RandomNumberGenerator.new()
	rng.seed = seed
	var n := 14
	var vals := []
	var v := 0.0
	for i in n:   # camina al azar, pero con tendencia a subir
		v += rng.randf_range(-0.5, 1.0) + (0.4 if i > n - 4 else 0.0)
		vals.append(v)
	var lo: float = vals.min()
	var hi: float = maxf(vals.max(), lo + 0.01)
	var at := func(i: int) -> Vector2:
		return Vector2(r.position.x + r.size.x * i / (n - 1.0), r.end.y - r.size.y * (vals[i] - lo) / (hi - lo))
	var k := ease_out(clampf((t - 0.25) / 1.3, 0, 1))
	var shown := k * (n - 1)
	var pts := PackedVector2Array()
	var i0 := int(shown)
	for i in i0 + 1:
		pts.append(at.call(i))
	if i0 < n - 1 and shown > i0:   # tramo a medio dibujar
		pts.append(pts[-1].lerp(at.call(i0 + 1), shown - i0))
	if pts.size() < 2:
		return
	var fill := PackedVector2Array(pts)
	fill.append(Vector2(pts[-1].x, r.end.y))
	fill.append(Vector2(pts[0].x, r.end.y))
	var cols := PackedColorArray()
	for p in fill:
		cols.append(Color(up, 0.28 * (1.0 - (p.y - r.position.y) / r.size.y)))
	RenderingServer.canvas_item_add_polygon(ui.canvas, fill, cols)
	ui.polyline(pts, up, 2.2)
	var tip := pts[-1]
	var pulse := 0.5 + 0.5 * sin(t * 7.0)
	ui.circle(tip, 6.0 + 3.0 * pulse, Color(up, 0.18))
	ui.circle(tip, 3.5, light(up, 0.3))
	if k >= 0.999:   # flecha verde al terminar de subir
		var ak := ease_out(clampf((t - 1.55) / 0.3, 0, 1))
		var ac := Vector2(r.end.x - 4, r.position.y + 2 - 4 * ak)
		ui.polygon(PackedVector2Array([ac + Vector2(0, -6), ac + Vector2(6, 3), ac + Vector2(-6, 3)]), Color(up, ak))


func _draw_hint(ui: ImUI) -> void:
	if hint_card == null:
		return
	var t: float = hint_card.t
	var a := clampf(min(t / 0.15, (HINT_LIFE - t) / 0.4), 0, 1)
	var tw := ui.text_size(hint_card.text, 15).x
	var w := tw + 48
	var r := Rect2(ui.W / 2 - w / 2, ui.H - 52 + (1.0 - a) * 12, w, 34)
	ui.canvas_alpha(a)
	ui.rect(r, BG, 17)
	ui.circle(Vector2(r.position.x + 18, r.get_center().y), 5, hint_card.col)
	ui.text(hint_card.text, Vector2(r.position.x + 32, r.get_center().y), 15, TEXT, false, "midleft")
