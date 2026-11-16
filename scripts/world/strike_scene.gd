class_name StrikeScene
extends RefCounted
## La huelga (ver Game._strike_day): si les pegas mucho con el bate, tus empleados dejan de trabajar y protestan
## frente a tu oficina con carteles. Mientras dure la huelga la protesta sigue ahí (la arma sync_crowd).
## La cinemática:
## 1) "crowd": la cámara pasa por la calle frente a la oficina; la gente grita con sus carteles;
## 2) "leader": primer plano del delegado del sindicato, con el megáfono;
## 3) "talk": el delegado te habla (cuadro con su foto); Enter, Espacio o clic pasan cada frase;
## 4) "choice": eliges subir sueldos, despedir a todos o ignorarlos;
## 5) "outcome": la gente festeja, se va furiosa o sigue gritando; se funde a negro y vuelve al juego.
## Si los ignoraste, puedes hablar con el delegado frente a la oficina: la escena arranca en "talk".

const CROWD := 4.2
const LEADER := 3.0
const OUTCOME := 4.0
const FADE := 0.45
const BAR := 74.0
const LEADER_NAME := "DELEGADO DEL SINDICATO"
const SIGNS := ["¡HUELGA!", "¡FUERA EL JEFE!", "¡JEFE ABUSADOR!", "¡SUELDO JUSTO!", "¡BASTA DE GOLPES!", "¡TIRANO!",
		"¡NI UN GOLPE MÁS!", "¡EXPLOTADOR!"]
const CHANTS := ["¡Huelga, huelga!", "¡Fuera el abusador!", "¡Sal a dar la cara, cobarde!", "¡Explotador!",
		"¡Somos trabajadores, no tus sacos de boxeo!", "¡Tirano!", "¡Que salga el matón del bate!", "¡No le tenemos miedo!",
		"¡Te vamos a cerrar todo!", "¡Abusador, abusador!", "¡Ladrón de sueldos!", "¡Sin nosotros no eres nada!"]
const ANGRY := ["😠", "😡", "🤬", "✊", "📢", "😤", "🖕"]

var city
var phase := ""
var t := 0.0
var total := 0.0
var fade := 0.0
var was_paused := false
var lines := []
var line_i := 0
var line_t := 0.0
var leaving := -1.0
var choice := ""          # lo que elegiste (para el final de la escena)
var choice_rects := []
var crowd: Node3D         # la protesta frente a la oficina (null si no hay huelga)
var people := []          # [Person, fase del salto, cartel]
var leader: Person
var chant_t := 0.0


func _init(owner_city) -> void:
	city = owner_city


func active() -> bool:
	return phase != ""


## Dónde queda cada cosa: la vereda frente a la oficina central (la puerta queda libre).
static func spot(lx: float, lz: float) -> Vector3:
	return Blueprints.to_world(City.HQ, lx, lz)


static func leader_pos() -> Vector3:
	return spot(0.0, -3.6)


static func leader_look() -> Dictionary:
	var look: Dictionary = Wardrobe.DEFAULT_LOOK.duplicate()
	look.merge({"shirt": [200, 45, 45], "hat": "gorra", "pants": [45, 50, 70], "hair": [40, 30, 22], "bat": false}, true)
	return look


# ---------- la protesta ----------
## Cada cuadro: arma la protesta si hay huelga, la quita cuando termina, y la anima.
func sync_crowd(dt: float) -> void:
	var g: Game = city.game
	var want: bool = g != null and (g.strike or active())
	if want and crowd == null:
		_build_crowd()
	elif not want and crowd != null:
		clear()
	if crowd == null:
		return
	var now := Time.get_ticks_msec() / 1000.0
	for p in people:
		var w: Person = p[0]
		if not is_instance_valid(w):
			continue
		var k := now * 3.2 + float(p[1])
		var leaving_crowd := phase == "outcome" and choice == "despedir"
		if leaving_crowd:   # se van furiosos, caminando hacia la calle
			w.rotation.y = lerp_angle(w.rotation.y, PI, minf(1.0, dt * 3.0))
			w.position.z -= dt * 1.6
			w.animate(1.5, dt)
			p[2].position.y = 2.05
			continue
		var happy := phase == "outcome" and choice == "subir"
		var jump := absf(sin(k)) * (0.22 if happy else 0.08)
		w.position.y = jump
		w.arms[1].rotation.x = deg_to_rad(-165.0 + sin(k) * 12.0)   # el brazo arriba con el cartel
		w.arms[0].rotation.x = deg_to_rad(-150.0 + sin(k + 1.4) * 25.0) if happy else deg_to_rad(sin(k) * 10.0)
		p[2].position.y = 2.05 + sin(k) * 0.08
	if is_instance_valid(leader):
		leader.arms[1].rotation.x = deg_to_rad(-80.0 + sin(now * 5.0) * 6.0)   # apunta con el megáfono a la oficina
	# gritos y emojis de vez en cuando (más seguido en la cinemática)
	chant_t -= dt
	if chant_t <= 0.0 and not people.is_empty():
		chant_t = randf_range(0.5, 1.0) if active() else randf_range(1.6, 3.2)
		var who: Person = people.pick_random()[0]
		if is_instance_valid(who):
			if randf() < 0.55:
				city.say(who, CHANTS.pick_random(), "red", 1.6)
			else:
				city.emote(who, ANGRY.pick_random(), 1.4)


func _build_crowd() -> void:
	crowd = Node3D.new()
	crowd.name = "Huelga"
	city.add_child(crowd)
	people = []
	var n := 0
	# dos grupos a los lados de la puerta, en tres filas, mirando a la oficina
	for side in [-1, 1]:
		for row in 3:
			for col in 3:
				var lx: float = side * (3.4 + col * 1.15 + (0.55 if row == 1 else 0.0))
				var lz: float = -1.3 - row * 1.0
				var shirt = Blueprints.PRODUCT_COLORS.values()[(n * 3) % Blueprints.PRODUCT_COLORS.size()]
				var w := Person.new(shirt, null, true)
				crowd.add_child(w)
				w.position = spot(lx + randf_range(-0.15, 0.15), lz + randf_range(-0.15, 0.15))
				w.rotation.y = randf_range(-0.25, 0.25)   # mirando a la oficina (+z)
				people.append([w, randf() * TAU, _sign(w, SIGNS[n % SIGNS.size()])])
				n += 1
	leader = Person.new(null, null, false, leader_look())
	leader.name = "Delegado"
	crowd.add_child(leader)
	leader.position = leader_pos()
	leader.rotation.y = 0.0
	_megaphone(leader)


## Un cartel de cartón en un palo, con el texto por los dos lados (cada lado se lee derecho).
func _sign(w: Person, text: String) -> Node3D:
	var s := Node3D.new()
	w.add_child(s)
	s.position = Vector3(-0.28, 2.05, 0.05)
	var b := Boxes.new()
	b.box(Vector3(0, -0.45, 0), Vector3(0.04, 0.9, 0.04), Color8(150, 110, 70))
	b.box(Vector3(0, 0.2, 0), Vector3(0.95, 0.5, 0.03), Color8(236, 226, 200))
	var m := MeshInstance3D.new()
	m.mesh = b.build()
	m.material_override = Mats.smooth
	m.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	s.add_child(m)
	for face in [0.0, PI]:
		var l := Label3D.new()
		l.text = Lang.t(text)
		l.set_meta("src", text)
		l.font = Building.title_font
		l.font_size = 40
		l.pixel_size = 0.0042
		l.modulate = Color8(190, 30, 30)
		l.outline_size = 0
		l.double_sided = false
		l.width = 210
		l.autowrap_mode = TextServer.AUTOWRAP_WORD
		l.position = Vector3(0, 0.2, 0.02 if face == 0.0 else -0.02)
		l.rotation.y = face
		s.add_child(l)
	return s


func _megaphone(w: Person) -> void:
	# con el brazo estirado hacia adelante, el megáfono sigue el brazo (hacia −y del brazo)
	var b := Boxes.new()
	b.box(Vector3(0, -0.66, 0), Vector3(0.11, 0.1, 0.11), Color8(40, 40, 44))      # mango
	b.box(Vector3(0, -0.8, 0), Vector3(0.15, 0.2, 0.15), Color8(235, 235, 235))    # cuerpo
	b.box(Vector3(0, -0.95, 0), Vector3(0.3, 0.12, 0.3), Color8(240, 200, 40))     # bocina
	var m := MeshInstance3D.new()
	m.mesh = b.build()
	m.material_override = Mats.smooth
	m.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	w.arms[1].add_child(m)


func clear() -> void:
	if crowd != null and is_instance_valid(crowd):
		crowd.queue_free()
	crowd = null
	people = []
	leader = null


## Para el aviso de "hablar con el delegado" (solo si hay huelga y no se está viendo la escena).
func interactables(g: Game) -> Array:
	if g == null or not g.strike or active():
		return []
	return [[leader_pos() + Vector3(0, 0, -1.0), "Hablar con el delegado de la huelga", func(): start(true)]]


# ---------- la escena ----------
func start(again := false) -> void:
	var g: Game = city.game
	if active() or g == null or not g.strike:
		return
	city.drop_computer()
	if city.overlays.open():
		city.overlays.hide()
	city.stop_serving()
	was_paused = city.app.paused
	city.app.paused = true
	city.app.modal = null
	city.app.in_finale = true   # que no salga ningún dilema encima
	total = 0.0
	t = 0.0
	fade = 1.0
	leaving = -1.0
	choice = ""
	line_i = 0
	line_t = 0.0
	if crowd == null:
		_build_crowd()
	# tú sales a la puerta a escucharlo
	city.player.position = spot(0.0, -1.6)
	city.player.rotation.y = PI
	city.release_mouse()   # para elegir con el mouse
	if again:
		phase = "talk"
		lines = ["¿Otra vez tú? Seguimos aquí, abusador. Ningún local abre hasta que nos des una respuesta de verdad."]
	else:
		phase = "crowd"
		lines = [
			"¡Por fin sales! ¿Creíste que nos íbamos a dejar pegar para siempre?",
			"Nos tienes hartos. Nos pegas como a animales y encima pagas una miseria. ¡Se acabó!",
			"Desde hoy estamos en huelga. Tus locales se quedan cerrados, y si sacas el bate, vamos a la prensa y a la policía.",
			"Así que decide de una vez: ¿qué vas a hacer con nosotros?",
		]
	city.thumbs.get_thumb(leader_look(), "busto")
	city.sfx.play("bad", 0.6, 0.8)


func update(dt: float) -> void:
	sync_crowd(dt)
	if not active():
		return
	t += dt
	total += dt
	city.app.paused = true
	match phase:
		"crowd":
			fade = 1.0 - clampf(t / FADE, 0, 1)
			if t >= CROWD:
				phase = "leader"
				t = 0.0
		"leader":
			fade = 0.0
			if t >= LEADER:
				_to("talk")
		"talk":
			fade = 1.0 - clampf(total / FADE, 0, 1) if total < FADE else 0.0
			line_t += dt
		"choice":
			pass
		"outcome":
			if t >= OUTCOME - FADE:
				fade = clampf((t - (OUTCOME - FADE)) / FADE, 0, 1)
			if t >= OUTCOME:
				_end()


func _to(p: String) -> void:
	phase = p
	t = 0.0
	line_t = 0.0


## Enter, Espacio o clic: completa la frase o pasa a la siguiente.
func advance() -> void:
	match phase:
		"crowd", "leader":
			_to("talk")
			fade = 0.0
		"talk":
			var full := Lang.t(lines[line_i])
			if line_t * Tutorial.TYPE_SPEED < full.length():
				line_t = full.length() / Tutorial.TYPE_SPEED + 0.01
				return
			city.sfx.play("select", 0.4)
			if line_i < lines.size() - 1:
				line_i += 1
				line_t = 0.0
			else:
				_to("choice")
		"outcome":
			t = maxf(t, OUTCOME - FADE)


func key(e: InputEventKey) -> void:
	if e.keycode == KEY_ESCAPE:
		if phase in ["crowd", "leader", "talk"]:
			_to("choice")
			fade = 0.0
		elif phase == "outcome":
			advance()
	elif e.keycode in [KEY_ENTER, KEY_KP_ENTER, KEY_SPACE]:
		advance()
	elif phase == "choice" and e.keycode in [KEY_1, KEY_2, KEY_3]:
		_pick(["subir", "despedir", "ignorar"][e.keycode - KEY_1])


func _pick(c: String) -> void:
	var g: Game = city.game
	if c == "despedir" and g.cash < g.strike_fire_cost():
		city.sfx.play("bad", 0.5)
		return
	var res: Array = g.strike_resolve(c)
	if not res[0]:
		return
	choice = c
	city.sfx.play({"subir": "fanfare", "despedir": "bad", "ignorar": "bad"}[c], 0.6, 1.0 if c != "ignorar" else 0.8)
	_to("outcome")
	for p in people:   # cómo reacciona la gente
		var w: Person = p[0]
		match c:
			"subir":
				city.emote(w, ["🎉", "👏", "😄", "🥳"].pick_random(), 2.6)
			"despedir":
				city.emote(w, ["😡", "🤬", "😤"].pick_random(), 2.6)
			"ignorar":
				city.emote(w, ["😠", "✊", "📢"].pick_random(), 2.6)
	if is_instance_valid(leader):
		city.say(leader, {"subir": "¡Por fin entendiste! Pero si vuelves a sacar el bate, paramos otra vez.",
				"despedir": "¡Maldito! ¡Te vas a arrepentir de esto!",
				"ignorar": "¿Nos ignoras? ¡De aquí no nos mueve nadie, sinvergüenza!"}[c], {"subir": "green", "despedir": "red", "ignorar": "orange"}[c], 3.0)


func _end() -> void:
	phase = ""
	fade = 0.0
	var g: Game = city.game
	g.strike_scene = false
	city.app.paused = was_paused
	city.app.in_finale = false
	city.capture_mouse()
	match choice:
		"subir":
			city.toast(Lang.f("Terminó la huelga: el sueldo de tus empleados sube %d %%.", roundi(float(D.STRIKE.raise) * 100)), "good")
		"despedir":
			city.toast(Lang.f("Despediste a todos: el personal nuevo llega en %d días.", int(D.STRIKE.rehire_days)), "bad")
		_:
			city.toast("La huelga sigue: habla con el delegado frente a tu oficina cuando quieras.", "bad")
	if not g.strike:
		clear()


## La cámara de cada parte.
func place_camera(cam: Camera3D) -> bool:
	if not active():
		return false
	var head := leader_pos() + Vector3(0, 1.86, 0)
	var door := spot(0, 0) + Vector3(0, 2.2, 0)
	match phase:
		"crowd":   # por la calle, de un lado al otro, mirando a la protesta y la oficina
			var k := _ease(t / CROWD)
			cam.global_position = spot(lerpf(-9.0, 7.0, k), -10.5) + Vector3(0, lerpf(5.5, 3.6, k), 0)
			cam.look_at(door + Vector3(0, -0.6, 0))
		"leader":   # primer plano del delegado (mira a la oficina, la cámara lo ve desde adelante y un costado)
			var k := _ease(t / LEADER)
			cam.global_position = head + Vector3(lerpf(0.9, 0.45, k), lerpf(0.05, -0.02, k), lerpf(1.9, 1.3, k))
			cam.look_at(head + Vector3(0, -0.04, 0))
		"talk", "choice":   # por encima de tu hombro, desde la puerta: el delegado y la gente detrás
			var a := t * 0.05
			cam.global_position = spot(0.6 + sin(a) * 0.3, 0.4) + Vector3(0, 2.9, 0)
			cam.look_at(head + Vector3(-0.2, -0.7, 0))
		"outcome":   # vista ancha desde la calle
			cam.global_position = spot(0, -11.0) + Vector3(0, 4.2, 0)
			cam.look_at(door + Vector3(0, -0.8, 0))
	return true


# ---------- dibujo ----------
func draw(ui: ImUI) -> void:
	if not active():
		return
	_vignette(ui)
	_bars(ui)
	match phase:
		"crowd":
			if t > 1.2:
				_subtitle(ui, "¡HUELGA!", clampf((t - 1.2) / 0.4, 0, 1), true)
		"leader":
			if t > 0.6:
				_subtitle(ui, "—¡Sal, cobarde! ¡Da la cara!", clampf((t - 0.6) / 0.3, 0, 1) * clampf((LEADER - t) / 0.3, 0, 1))
		"talk":
			var full := Lang.t(lines[line_i])
			var n := mini(full.length(), int(line_t * Tutorial.TYPE_SPEED))
			Tutorial.mentor_box(ui, city, full, n, minf(1.0, t * 3.5 + line_i), true, lines.size(), line_i, LEADER_NAME, leader_look())
		"choice":
			_draw_choice(ui)
		"outcome":
			var txt: String = {"subir": "TERMINÓ LA HUELGA", "despedir": "DESPEDISTE A TODOS", "ignorar": "LA HUELGA SIGUE"}[choice]
			_subtitle(ui, txt, clampf(t / 0.4, 0, 1), true)
	if phase in ["crowd", "leader"] and total < 3.5:
		ui.text("Enter o clic: saltar", Vector2(ui.W - 24, ui.H - 22), 12, Color(1, 1, 1, 0.45), false, "bottomright")
	if ui.clicked and phase != "choice":
		ui.clicked = false
		advance()
	if fade > 0.0:
		ui.rect(Rect2(-3000, -3000, ui.W + 6000, ui.H + 6000), Color(0, 0, 0, fade))


## Las tres opciones, en tarjetas (clic o 1, 2, 3).
func _draw_choice(ui: ImUI) -> void:
	var g: Game = city.game
	var e := 1.0 - pow(1.0 - clampf(t * 3.0, 0, 1), 3)
	var cw := 300.0
	var ch := 150.0
	var gap := 22.0
	var x0 := ui.W / 2 - (3 * cw + 2 * gap) / 2
	var y := ui.H - ch - 40 + (1.0 - e) * 260
	ui.text("¿Qué haces con los huelguistas?", Vector2(ui.W / 2 + 1, y - 27), 24, Color(0, 0, 0, 0.6), true, "center")
	ui.text("¿Qué haces con los huelguistas?", Vector2(ui.W / 2, y - 28), 24, Color.WHITE, true, "center")
	var fire_cost: float = g.strike_fire_cost()
	var opts := [
		["subir", "Subirles el sueldo", Lang.f("Ganan %d %% más para siempre. Vuelven hoy mismo y con mejor ánimo.", roundi(float(D.STRIKE.raise) * 100)), Color8(46, 170, 90), true],
		["despedir", "Despedirlos a todos", Lang.f("Indemnizar y contratar gente nueva: %s. Tus locales quedan sin nadie %d días y baja tu fama.", [Fmt.money(fire_cost), int(D.STRIKE.rehire_days)]), Color8(225, 85, 75), g.cash >= fire_cost],
		["ignorar", "Ignorarlos", "Siguen en huelga: tus empleados no atienden y no vendes. Puedes volver a hablar con el delegado.", Color8(240, 140, 50), true],
	]
	choice_rects = []
	for i in opts.size():
		var o: Array = opts[i]
		var r := Rect2(x0 + i * (cw + gap), y, cw, ch)
		choice_rects.append(r)
		var ok: bool = o[4]
		var hot := ok and ui.hover(r)
		ui.rect(r, Color(0.04, 0.05, 0.075, 0.96), 16)
		ui.rect(r, Color(o[3], 1.0 if hot else 0.7), 16, 3 if hot else 2)
		ui.rect(Rect2(r.position.x + 18, r.position.y + 18, 30, 30), o[3], 15)
		ui.text(str(i + 1), Vector2(r.position.x + 33, r.position.y + 33), 15, Color8(16, 20, 30), true, "center")
		ui.text(o[1], Vector2(r.position.x + 60, r.position.y + 33), 19, Color.WHITE if ok else Color(1, 1, 1, 0.4), true, "midleft")
		ui.wrap_text(o[2], Rect2(r.position.x + 20, r.position.y + 62, cw - 40, ch - 70), 15, Color(1, 1, 1, 0.85 if ok else 0.4))
		if not ok:
			ui.text("No te alcanza la caja", Vector2(r.get_center().x, r.end.y - 18), 13, Color8(225, 85, 75), true, "center")
		if hot and ui.clicked:
			ui.clicked = false
			_pick(o[0])


func _bars(ui: ImUI) -> void:
	var h := BAR * _ease(total / 0.8)
	if phase in ["talk", "choice"]:
		h *= 0.55
	ui.rect(Rect2(-3000, -3000, ui.W + 6000, 3000 + h), Color(0, 0, 0))
	ui.rect(Rect2(-3000, ui.H - h, ui.W + 6000, 3000 + h), Color(0, 0, 0))


func _vignette(ui: ImUI) -> void:
	var e := 160.0
	var dark := Color(0, 0, 0, 0.42)
	var clear_c := Color(0, 0, 0, 0)
	ui.gradient(Rect2(0, 0, e, ui.H), dark, clear_c, true)
	ui.gradient(Rect2(ui.W - e, 0, e, ui.H), clear_c, dark, true)
	ui.gradient(Rect2(0, 0, ui.W, e * 0.7), dark, clear_c, false)
	ui.gradient(Rect2(0, ui.H - e * 0.7, ui.W, e * 0.7), clear_c, dark, false)


func _subtitle(ui: ImUI, text: String, a: float, big := false) -> void:
	var y := ui.H - BAR - 46
	if big:
		ui.text(text, Vector2(ui.W / 2 + 2, y + 2), 34, Color(0, 0, 0, 0.6 * a), true, "center")
		ui.text(text, Vector2(ui.W / 2, y), 34, Color(1.0, 0.35, 0.3, a), true, "center")
	else:
		ui.text(text, Vector2(ui.W / 2 + 1, y + 1), 24, Color(0, 0, 0, 0.6 * a), true, "center")
		ui.text(text, Vector2(ui.W / 2, y), 24, Color(1, 1, 1, a), true, "center")


static func _ease(x: float) -> float:
	x = clampf(x, 0, 1)
	return x * x * (3.0 - 2.0 * x)
