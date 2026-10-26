class_name Notifications
extends RefCounted
## Los avisos llegan como notificaciones del celular de la empresa: tarjetas apiladas arriba a la derecha, cada una
## con el ícono de su "app" (Banco, Noticias, Mensajes de los rivales...). Se ven hasta 3 a la vez, la más nueva
## arriba, y se van solas; mientras hay peligro de quiebra una alerta roja queda fija encima de todas.
## Los hitos grandes (rango, récord, racha, imperio) salen como un cartel al centro de la pantalla, y las respuestas
## a lo que haces (música, llegaste a la oficina...) como un aviso chico abajo. Todo queda en Noticias del celular.

const LIFE := 6.0          # segundos que dura una tarjeta (el reloj se detiene con un menú abierto)
const MAX_CARDS := 3
const CARD_W := 372.0
const TOP := 92.0          # debajo de la velocidad y los botones Día / Tarde / Noche
const GAP := 8.0
const HERO_LIFE := 3.2
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
			"letters": opts.has("initials"),
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
		icon := "star") -> void:
	city.app.unread += 1
	heroes.append({"kicker": kicker, "title": title, "sub": sub, "col": col, "sound": sound, "confetti": confetti,
			"count": count, "t": 0.0, "icon": icon})


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
	return "Día %d %s" % [dp[0], dp[1].substr(0, 3).to_lower()]


func update(dt: float, frozen: bool) -> void:
	var step := 0.0 if frozen else dt
	# Entran las que esperan, de a una cada tanto para que se alcancen a ver
	if waiting and (cards.is_empty() or cards[0].t > 0.35):
		var d: Dictionary = waiting.pop_front()
		cards.push_front(d)
		if d.sound != null:
			city.sfx.play(d.sound)
		if cards.size() > MAX_CARDS:  # la más vieja se va para dar lugar
			cards[-1].t = max(cards[-1].t, LIFE)
	for c in cards.duplicate():
		c.t += step
		var leaving: bool = c.t >= (LIFE if waiting.is_empty() else LIFE * 0.75)
		c.alpha = clampf(c.alpha + (-dt * 4.0 if leaving else dt * 5.0), 0, 1)
		if leaving and c.alpha <= 0:
			cards.erase(c)
	if hero == null and heroes:
		hero = heroes.pop_front()
		if hero.sound != null:
			city.sfx.play(hero.sound)
		if hero.confetti:
			city.hud.confetti.burst(hero.confetti, Vector2(city.hud.ui.W / 2, 300))
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
	return c.body.format([Fmt.money(c.count * k)], "{}")


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
	app_icon(ui, Rect2(x, y, 20, 20), c.col, c.icon, c.get("letters", false))
	var app := ui.text(c.app, Vector2(x + 28, y + 3), 11, Notifications.light(c.col, 0.25), true)
	if c.repeat > 1:
		var tag := "x%d" % c.repeat
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


func _draw_hero(ui: ImUI) -> void:
	if hero == null:
		return
	var t: float = hero.t
	var a := clampf(min(t / 0.25, (HERO_LIFE - t) / 0.5), 0, 1)
	var pop := 1.0 + 0.18 * (1.0 - ease_out(t / 0.35))   # entra un poco más grande y se asienta
	var cx := ui.W / 2
	var cy := 300.0
	ui.canvas_alpha(a)
	var w := 560.0 * pop
	var h := 150.0 * pop
	var r := Rect2(cx - w / 2, cy - h / 2, w, h)
	ui.rect(r, Color(0.04, 0.05, 0.07, 0.94), 22)
	ui.rect(r, Color(hero.col, 0.8), 22, 2)
	var kw := ui.text_size(hero.kicker, 15, true).x + 72
	var kr := Rect2(cx - kw / 2, r.position.y - 14, kw, 28)
	ui.rect(kr, hero.col, 14)
	ui.text(hero.kicker, kr.get_center(), 15, Color8(16, 20, 30), true, "center")
	for side in [-1, 1]:  # el ícono del hito a cada lado
		Icons.draw(ui, hero.icon, Vector2(cx + side * (kw / 2 - 18), kr.get_center().y), 18, Color8(16, 20, 30))
	var title: String = hero.title
	if hero.count != null:
		title = title.format([Fmt.money(hero.count * ease_out(t / 1.0))], "{}")
	ui.text(title, Vector2(cx, cy - 8), int(44 * pop), light(hero.col, 0.35), true, "center", w - 40)
	ui.text(hero.sub, Vector2(cx, cy + 40 * pop), 16, TEXT, false, "center", w - 40)


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
