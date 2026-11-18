class_name PowerScene
extends RefCounted
## Cinemática de la primera vez que falla la planta eléctrica (cuando tu empresa vale unos $400.000, ver Game._power_day):
## 1) "face": primer plano de la cara del operario de la caseta, que se da vuelta asustado hacia la planta;
## 2) "plant": la cámara pasa por encima de su hombro a la planta: revientan chispas, titilan las ventanas, la baliza
##    gira y se corta la luz de la ciudad;
## 3) "mentor": la cámara gira despacio alrededor de la planta y tu personaje ya millonario (el mentor del tutorial)
##    explica qué pasa y dónde se paga; Enter, Espacio o clic pasan cada frase. Al terminar vuelve al juego.
## Esc salta a la parte del mentor (y en la del mentor la termina).

const FACE := 3.4
const PLANT := 4.6
const FADE := 0.45
const BAR := 74.0

var city
var phase := ""
var t := 0.0
var total := 0.0
var fade := 0.0
var was_paused := false
var lines := []
var line_i := 0
var line_t := 0.0
var leaving := -1.0        # segundos desde que terminó de hablar (se funde a negro y vuelve al juego)
var cues := {}


func _init(owner_city) -> void:
	city = owner_city


func active() -> bool:
	return phase != ""


func start() -> void:
	var g: Game = city.game
	if active() or g == null:
		return
	city.drop_computer()
	if city.overlays.open():
		city.overlays.hide()
	city.stop_serving()
	was_paused = city.app.paused
	city.app.paused = true
	city.app.modal = null
	phase = "face"
	t = 0.0
	total = 0.0
	fade = 1.0
	leaving = -1.0
	cues = {}
	line_i = 0
	line_t = 0.0
	lines = [
		"¿Viste eso? Es la planta eléctrica que le da luz a toda la ciudad. Está vieja y acaba de fallar.",
		"La ciudad se quedó sin luz, y no va a volver sola: sin luz tus locales venden mucho menos y de noche todo queda a oscuras.",
		"Para que vuelva a funcionar hay que pagar el arreglo, y se paga aquí mismo: en la caseta de la planta, junto al túnel.",
		Lang.f("Cuesta el 5 %% de la caja que tengas al pagar (hoy serían %s) y te da luz por unos 3 meses (%d días). Después vuelve a fallar.", [Fmt.money(g.power_cost()), int(D.POWER.days)]),
		"Ven cuando puedas: en el mapa la planta está marcada con un rayo.",
	]
	city.plant.worker.rotation.y = PI
	city.thumbs.get_thumb(city.tutorial.mentor_look(), "busto")   # que la foto del mentor esté lista al hablar


func _cue(id: String, sound: String, vol := 0.6, pitch := 1.0) -> void:
	if not cues.has(id):
		cues[id] = true
		city.sfx.play(sound, vol, pitch)


func update(dt: float) -> void:
	if not active():
		return
	t += dt
	total += dt
	city.app.paused = true
	var pl: PowerPlant = city.plant
	match phase:
		"face":
			fade = 1.0 - clampf(t / FADE, 0, 1)
			if t > 1.3:   # se da vuelta hacia la planta (que queda atrás y a su derecha)
				pl.worker.rotation.y = lerp_angle(pl.worker.rotation.y, deg_to_rad(-40.0), minf(1.0, dt * 4.0))
			if t > 0.9:
				_cue("bang", "fin_golpe", 0.7, 0.8)   # el golpe que se oye desde la planta
			if t >= FACE:
				phase = "plant"
				t = 0.0
		"plant":
			fade = 0.0
			if t > 0.6:
				_cue("burst", "fin_impacto", 0.75, 0.7)
				if not cues.has("sparks"):
					cues["sparks"] = true
					pl.burst()
			if t > 1.0:
				_cue("alarm", "bad", 0.6, 0.85)
			# revienta y la luz de la ciudad se corta de golpe, del todo
			city.sky.blackout = 1.0 if t > 0.6 else 0.0
			if t > 0.6:
				_cue("off", "fin_golpe", 0.7, 0.55)
			if t >= PLANT:
				phase = "mentor"
				t = 0.0
				line_t = 0.0
		"mentor":
			pl.flicker = 0.0
			city.sky.blackout = 1.0
			line_t += dt
			if leaving >= 0.0:
				leaving += dt
				fade = clampf(leaving / FADE, 0, 1)
				if leaving >= FADE:
					_end()
	pl.update(dt, true)


## Enter, Espacio o clic: completa la frase o pasa a la siguiente; Esc salta al mentor o termina.
func advance() -> void:
	match phase:
		"face", "plant":
			phase = "mentor"
			t = 0.0
			line_t = 0.0
			fade = 0.0
			city.plant.flicker = 0.0
			city.plant.worker.rotation.y = deg_to_rad(-40.0)
		"mentor":
			if leaving >= 0.0:
				return
			var full := Lang.t(lines[line_i])
			if line_t * Tutorial.TYPE_SPEED < full.length():
				line_t = full.length() / Tutorial.TYPE_SPEED + 0.01
				return
			city.sfx.play("select", 0.4)
			if line_i < lines.size() - 1:
				line_i += 1
				line_t = 0.0
			else:
				leaving = 0.0


func key(e: InputEventKey) -> void:
	if e.keycode == KEY_ESCAPE:
		if phase == "mentor":
			if leaving < 0.0:
				leaving = 0.0
		else:
			advance()
	elif e.keycode in [KEY_ENTER, KEY_KP_ENTER, KEY_SPACE]:
		advance()


func _end() -> void:
	phase = ""
	fade = 0.0
	city.game.power_intro = true
	city.app.paused = was_paused
	city.plant.flicker = 0.0
	city.plant.worker.rotation.y = PI
	city.toast("La planta eléctrica está fallando: paga el arreglo en su caseta, junto al túnel.", "bad")


## La cámara de cada parte.
func place_camera(cam: Camera3D) -> bool:
	if not active():
		return false
	var w: Vector3 = PowerPlant.WORKER
	var head := w + Vector3(0, 1.86, 0)
	match phase:
		"face":   # primer plano de la cara (el operario mira a la calle, hacia −z); se acerca un poco
			var k := _ease(t / FACE)
			cam.global_position = head + Vector3(lerpf(0.45, 0.2, k), lerpf(0.0, -0.03, k), -lerpf(1.7, 1.2, k))
			cam.look_at(head + Vector3(0, -0.02, 0))
		"plant":   # de su hombro hasta la vista de la planta entera
			var k := _ease(t / PLANT)
			var over := head + Vector3(0.5, 0.25, -0.6)
			var wide := Vector3(-143.0, 9.0, 2.0)
			cam.global_position = over.lerp(wide, k)
			var look_a := PowerPlant.SPARKS
			var look_b := PowerPlant.CENTER
			cam.look_at(look_a.lerp(look_b, k))
			if t > 0.6 and t < 1.6:   # sacudida cuando revienta
				cam.global_position += Vector3(randf_range(-1, 1), randf_range(-1, 1), 0) * 0.06
		"mentor":   # gira lento alrededor de la planta
			var a := -0.9 + (t + 0.0) * 0.05
			var c := PowerPlant.CENTER
			cam.global_position = c + Vector3(sin(a) * -21.0, 7.0, -cos(a) * 21.0)
			cam.look_at(c)
	return true


# ---------- dibujo ----------
func draw(ui: ImUI) -> void:
	if not active():
		return
	_vignette(ui)
	_bars(ui)
	if phase == "face" and t > 1.0:
		var a := clampf((t - 1.0) / 0.3, 0, 1) * clampf((FACE - t) / 0.4, 0, 1)
		_subtitle(ui, "—¡¿Qué fue eso?!", a)
	elif phase == "plant" and t > 2.6:
		_subtitle(ui, "APAGÓN EN LA CIUDAD", clampf((t - 2.6) / 0.4, 0, 1), true)
	elif phase == "mentor":
		var full := Lang.t(lines[line_i])
		var n := mini(full.length(), int(line_t * Tutorial.TYPE_SPEED))
		Tutorial.mentor_box(ui, city, full, n, minf(1.0, t * 3.5), leaving < 0.0, lines.size(), line_i)
	if phase != "mentor" and total < 3.5:
		ui.text("Enter o clic: saltar", Vector2(ui.W - 24, ui.H - 22), 12, Color(1, 1, 1, 0.45), false, "bottomright")
	if ui.clicked:
		ui.clicked = false
		advance()
	if fade > 0.0:
		ui.rect(Rect2(-3000, -3000, ui.W + 6000, ui.H + 6000), Color(0, 0, 0, fade))


func _bars(ui: ImUI) -> void:
	var h := BAR * _ease(total / 0.8)
	if phase == "mentor":
		h *= 0.55   # más finas: abajo va el cuadro del mentor
	ui.rect(Rect2(-3000, -3000, ui.W + 6000, 3000 + h), Color(0, 0, 0))
	ui.rect(Rect2(-3000, ui.H - h, ui.W + 6000, 3000 + h), Color(0, 0, 0))


func _vignette(ui: ImUI) -> void:
	var e := 160.0
	var dark := Color(0, 0, 0, 0.42)
	var clear := Color(0, 0, 0, 0)
	ui.gradient(Rect2(0, 0, e, ui.H), dark, clear, true)
	ui.gradient(Rect2(ui.W - e, 0, e, ui.H), clear, dark, true)
	ui.gradient(Rect2(0, 0, ui.W, e * 0.7), dark, clear, false)
	ui.gradient(Rect2(0, ui.H - e * 0.7, ui.W, e * 0.7), clear, dark, false)


func _subtitle(ui: ImUI, text: String, a: float, big := false) -> void:
	var y := ui.H - BAR - 46
	if big:
		ui.text(text, Vector2(ui.W / 2 + 2, y + 2), 34, Color(0, 0, 0, 0.6 * a), true, "center")
		ui.text(text, Vector2(ui.W / 2, y), 34, Color(1.0, 0.62, 0.2, a), true, "center")
	else:
		ui.text(text, Vector2(ui.W / 2 + 1, y + 1), 24, Color(0, 0, 0, 0.6 * a), true, "center")
		ui.text(text, Vector2(ui.W / 2, y), 24, Color(1, 1, 1, a), true, "center")


static func _ease(x: float) -> float:
	x = clampf(x, 0, 1)
	return x * x * (3.0 - 2.0 * x)
