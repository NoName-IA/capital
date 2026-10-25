class_name Notifications
extends RefCounted
## Avisos como en los simuladores de gestión: uno a la vez, abajo a la izquierda; los demás esperan en fila
## (como mucho 3). Los repetidos se juntan ("x3") y los de poca importancia (rivales) no se muestran si ya hay
## otros esperando. Las respuestas a lo que haces (música, llegaste a la oficina...) pasan adelante.

const LIFE := 4.5
const MAX_WAIT := 3
const W := 470.0

var city
var queue := []
var cur = null
var t := 0.0
var alpha := 0.0


func _init(owner_city) -> void:
	city = owner_city


func push_top(title: String, sub: String, col: Color, icon: String, sound = null, confetti := 0, count = null) -> void:
	_push({"kind": "top", "title": title, "sub": sub, "body": "", "col": col, "icon": icon, "count": count}, sound, confetti)


func push_side(title: String, sub: String, body: String, col: Color, icon := "!", initials := "", sound = null,
		confetti := 0, low := false) -> void:
	_push({"kind": "side", "title": title, "sub": sub, "body": body, "col": col, "icon": icon, "initials": initials,
			"low": low}, sound, confetti)


## Noticia sin celebración especial: tarjeta corta.
func push_news(text: String, kind: String) -> void:
	var spec: Array = {"good": [Color8(46, 170, 90), "+"], "bad": [Color8(225, 85, 75), "!"],
			"warn": [Color8(240, 140, 50), "!"], "rival": [Color8(160, 120, 230), "☺"]}.get(kind, [Color8(70, 140, 230), "i"])
	_push({"kind": "top", "title": text, "sub": "", "body": "", "col": spec[0], "icon": spec[1], "short": true}, null, 0)


## Respuesta inmediata a algo que hiciste: pasa adelante.
func hint(text: String, kind := "info") -> void:
	var c: Color = {"good": Color8(46, 170, 90), "bad": Color8(225, 85, 75)}.get(kind, Color8(110, 120, 140))
	var d := {"kind": "hint", "title": text, "sub": "", "body": "", "col": c, "icon": "!" if kind == "bad" else "i",
			"short": true, "when": "", "sound": null, "confetti": 0, "repeat": 1}
	if cur != null and cur.kind == "hint":
		cur = d
		alpha = 1.0
		t = 0.0
		return
	queue = queue.filter(func(q): return q.kind != "hint")
	queue.push_front(d)
	if cur != null:
		t = max(t, LIFE * 0.7)  # el aviso actual se va para dar paso a la respuesta


func _push(data: Dictionary, sound, confetti: int) -> void:
	var g = city.game
	data["when"] = ""
	if g:
		var dp: Array = g.date_parts()
		data["when"] = "Día %d de %s, año %d" % dp
	data["sound"] = sound
	data["confetti"] = confetti
	data["repeat"] = 1
	# Lo mismo otra vez (por ejemplo, varios récords seguidos): se suma al aviso que ya está
	for d in [cur] + queue:
		if d != null and d.title == data.title and d.kind == data.kind and d.body == data.body:
			d.repeat += 1
			d.sub = data.sub
			d.count = data.get("count")
			d.when = data.when
			if is_same(d, cur):
				t = min(t, 1.0)
			return
	var busy: bool = cur != null or not queue.is_empty()
	if data.get("low", false) and busy:
		return
	if queue.size() >= MAX_WAIT:
		var drop = queue[0]
		for q in queue:
			if q.kind == "side":
				drop = q
				break
		queue.erase(drop)
	queue.append(data)


func clear() -> void:
	queue.clear()
	cur = null


func update(dt: float, frozen: bool) -> void:
	if cur == null:
		if queue.is_empty():
			return
		cur = queue.pop_front()
		t = 0.0
		alpha = 0.0
		if cur.sound != null:
			city.sfx.play(cur.sound)
		if cur.confetti:
			city.hud.confetti.burst(cur.confetti, Vector2(16 + W / 2, city.hud.ui.H - 70))
	if not frozen:
		t += dt
	var life := LIFE if queue.is_empty() else LIFE * 0.7  # si hay fila, pasan un poco más rápido
	var leaving := t >= life
	alpha = clampf(alpha + (-dt * 4 if leaving else dt * 5), 0, 1)
	if leaving and alpha <= 0:
		cur = null


static func light(c: Color, k := 0.45) -> Color:
	return c.lerp(Color.WHITE, k)


## Círculo de color con el ícono o las iniciales en oscuro.
static func badge(ui: ImUI, d: Dictionary, center: Vector2, radius: float) -> void:
	ui.circle(center, radius, d.col)
	var label: String = d.get("initials", "")
	if label == "":
		label = d.icon
	ui.text(label, center + Vector2(0, 1), int(radius * (0.85 if d.get("initials", "") else 1.05)), Color8(16, 20, 30), true, "center")


func draw(ui: ImUI) -> void:
	if cur == null or alpha <= 0:
		return
	var d: Dictionary = cur
	var col: Color = d.col
	var slide := (1 - alpha) * (1 - alpha) * 30
	var bottom := ui.H - 14 + slide
	var x := 16.0
	ui.canvas_alpha(alpha)
	if d.get("short", false):
		var lines := ui._lines(d.title, W - 70, 15, false)
		if lines.size() > 2:
			lines = [lines[0], " ".join(lines.slice(1))]
		var h: float = 16 + 20 * lines.size()
		var r := Rect2(x, bottom - h, W, h)
		ui.rect(r, Color(0.063, 0.078, 0.118, 0.93), 10)
		ui.rect(r, Color(col, 0.6), 10, 1.5)
		badge(ui, d, Vector2(r.position.x + 22, r.get_center().y), 12)
		for i in lines.size():
			ui.text(lines[i], Vector2(r.position.x + 42, r.position.y + 8 + i * 20), 15, Color8(228, 233, 242), false, "topleft", W - 70)
		if d.repeat > 1:
			ui.text("x%d" % d.repeat, Vector2(r.end.x - 10, r.end.y - 5), 12, col, true, "bottomright")
		ui.canvas_alpha(1.0)
		return
	var body: String = d.body
	var h := 80.0 if body else 56.0
	var r := Rect2(x, bottom - h, W, h)
	ui.rect(r, Color(0.063, 0.078, 0.118, 0.93), 12)
	ui.rect(r, Color(col, 0.6), 12, 1.5)
	ui.rect(Rect2(r.position.x + 7, r.position.y + 10, 3, h - 20), col, 2)
	badge(ui, d, Vector2(r.position.x + 32, r.position.y + 28), 16)
	var tx := r.position.x + 58
	var right := r.end.x - 12
	var when := ui.text(d.when, Vector2(right, r.position.y + 9), 11, Color8(125, 135, 155), false, "topright")
	var right_title := when.position.x - 8
	if d.repeat > 1:
		var tag_w := ui.text_size("x%d" % d.repeat, 12, true).x + 12
		var tr := Rect2(when.position.x - tag_w - 6, r.position.y + 7, tag_w, 17)
		ui.rect(tr, col, 8)
		ui.text("x%d" % d.repeat, tr.get_center(), 12, Color8(16, 20, 30), true, "center")
		right_title = tr.position.x - 6
	ui.text(d.title, Vector2(tx, r.position.y + 5), 18, light(col), true, "topleft", right_title - tx)
	var sub: String = d.sub
	if d.get("count") != null:
		var k: float = min(1.0, t / 1.2)
		sub = sub.format([Fmt.money(d.count * (1 - pow(1 - k, 3)))], "{}")
	if body:
		ui.text(sub, Vector2(tx, r.position.y + 29), 11, Color8(150, 160, 180), false, "topleft", right - tx)
		var lines := ui._lines(body, right - tx, 13, false)
		if lines.size() > 2:
			lines = [lines[0], " ".join(lines.slice(1))]
		for i in lines.size():
			ui.text(lines[i], Vector2(tx, r.position.y + 44 + i * 16), 13, Color8(228, 233, 242), false, "topleft", right - tx)
	else:
		ui.text(sub, Vector2(tx, r.position.y + 31), 14, Color8(228, 233, 242), false, "topleft", right - tx)
	ui.canvas_alpha(1.0)
