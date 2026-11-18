extends RefCounted
## Ángel (ver Game._angel_day y D.ANGEL): a los 10 minutos de juego, un inversionista extranjero te ofrece capital.
## Él aparece de cuerpo entero en la mitad izquierda de la pantalla, de abajo hasta arriba y sin ningún marco: es un
## modelo 3D de verdad (Person) en su propio escenario con fondo transparente, que gesticula mientras habla.
## 1) "talk": entra subiendo desde abajo y te habla (Enter, Espacio o clic pasan cada frase);
## 2) "offer": la oferta a la derecha; eliges con clic o con las teclas 1 o S = sí, 2 o N = no;
## 3) "react": festeja o se encoge de hombros, dice una última frase y se va bajando.
## La ciudad queda detrás, en pausa.

const GOLD := Color(0.94, 0.69, 0.16)
const GREEN := Color(0.18, 0.67, 0.35)
const RED := Color(0.88, 0.33, 0.29)
const RISE := 0.7      # segundos que tarda en subir desde abajo
const REACT := 3.2     # segundos de la reacción antes de irse
const LEAVE := 0.5
const VIEW := Vector2i(560, 900)   # el escenario donde se dibuja (alto: él de pies a cabeza)

var city
var phase := ""        # "", "talk", "offer", "react" o "leave"
var t := 0.0           # segundos en la fase
var total := 0.0       # segundos desde que apareció
var was_paused := false
var accepted := false
var message := ""
var amount := 0.0      # el capital que ofrece (se guarda para que no cambie mientras se va)
var boost := 0.0       # cuánto sube el valor de tu empresa
var lines := []
var line_i := 0
var line_t := 0.0
var talk_k := 0.0      # 0 callada, 1 hablando (suave, para que los gestos no salten)
# El escenario
var vp: SubViewport
var model: Person
var cam: Camera3D


func _init(owner_city) -> void:
	city = owner_city


func active() -> bool:
	return phase != ""


## El inversionista: pelo corto castaño, traje gris oscuro con corbata y reloj.
static func look() -> Dictionary:
	var l: Dictionary = Wardrobe.DEFAULT_LOOK.duplicate()
	l.merge({"skin": [240, 205, 175], "hair": [95, 65, 40], "hair_style": "corto", "shirt": [245, 245, 245],
			"jacket": "blazer", "jacket_color": [55, 58, 66], "pants": [55, 58, 66], "pants_style": "vestir",
			"tie": true, "watch": true, "shoes": [20, 20, 25]}, true)
	return l


func start() -> void:
	var g = city.game
	if active() or g == null or g.angel == null:
		return
	city.drop_computer()
	if city.overlays.open():
		city.overlays.hide()
	city.stop_serving()
	was_paused = city.app.paused
	city.app.paused = true
	city.app.in_finale = true   # que no salga ningún dilema encima
	city.release_mouse()        # para elegir con el mouse
	amount = float(g.angel.amount)
	boost = g.angel_value_boost(amount)
	lines = [
		Lang.f("Hola. Me llamo %s y vengo de %s.", [D.ANGEL.name, Lang.t(D.ANGEL.from)]),
		"Llevo semanas mirando tu empresa. Creo en lo que haces y quiero ayudarte a llegar mucho más lejos.",
		Lang.f("Te ofrezco %s de capital. Y con mi respaldo, tu empresa va a valer %s más.", [Fmt.money(amount), Fmt.money(boost)]),
		Lang.f("A cambio solo pido el %d %% de tus ganancias de cada mes, durante %d meses. ¿Qué me dices?",
				[roundi(float(D.ANGEL.share) * 100), int(D.ANGEL.months)]),
	]
	line_i = 0
	talk_k = 0.0
	_build_stage()
	_to("talk")
	total = 0.0
	city.sfx.play("ring", 0.7)


## Su escenario: un mundo aparte con luz, cámara y fondo transparente (él solo, sin marco).
func _build_stage() -> void:
	if vp != null:
		return
	vp = SubViewport.new()
	vp.size = VIEW
	vp.own_world_3d = true
	vp.transparent_bg = true
	vp.msaa_3d = Viewport.MSAA_4X
	vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	city.add_child(vp)
	var env := Environment.new()
	env.background_mode = Environment.BG_CLEAR_COLOR
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.62, 0.64, 0.72)
	env.ambient_light_energy = 0.85
	env.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	var we := WorldEnvironment.new()
	we.environment = env
	vp.add_child(we)
	var key := DirectionalLight3D.new()
	key.rotation_degrees = Vector3(-35, 30, 0)
	key.light_energy = 1.15
	vp.add_child(key)
	var rim := DirectionalLight3D.new()   # una luz de atrás dorada que la recorta del fondo
	rim.rotation_degrees = Vector3(-20, 160, 0)
	rim.light_color = Color(1.0, 0.85, 0.55)
	rim.light_energy = 0.6
	vp.add_child(rim)
	model = Person.new(null, null, false, look())
	model.remove_from_group("people")   # no es de la ciudad: nada de linternas
	model.rotation.y = deg_to_rad(18)   # mirando un poco hacia la derecha, donde está la oferta
	vp.add_child(model)
	cam = Camera3D.new()
	cam.fov = 30
	cam.position = Vector3(0.38, 1.3, 5.3)   # con aire arriba para cuando levanta los brazos
	vp.add_child(cam)
	cam.look_at(Vector3(0, 1.25, 0))


func _free_stage() -> void:
	if vp != null:
		vp.queue_free()
	vp = null
	model = null
	cam = null


func _to(p: String) -> void:
	phase = p
	t = 0.0
	line_t = 0.0


func update(dt: float) -> void:
	if not active():
		return
	t += dt
	total += dt
	line_t += dt
	city.app.paused = true
	_animate(dt)
	match phase:
		"react":
			if t >= REACT:
				_to("leave")
		"leave":
			if t >= LEAVE:
				_end()


## ¿Está diciendo algo ahora (la frase todavía se escribe)?
func talking() -> bool:
	if phase == "talk":
		return line_t * Tutorial.TYPE_SPEED < Lang.t(lines[line_i]).length()
	return phase == "react" and t < 1.6


## Los gestos: mientras habla mueve las manos, se balancea y asiente; callada, respira tranquila.
func _animate(dt: float) -> void:
	if model == null:
		return
	var s := total
	var arm_r: Node3D = model.arms[1]
	var arm_l: Node3D = model.arms[0]
	talk_k = lerpf(talk_k, 1.0 if talking() else 0.0, clampf(dt * 6.0, 0, 1))
	if phase in ["react", "leave"] and accepted:   # festeja: los dos brazos arriba
		var up := clampf(t / 0.3, 0, 1) if phase == "react" else 1.0
		arm_r.rotation = Vector3(deg_to_rad(-160 * up), 0, deg_to_rad(-12 * up))
		arm_l.rotation = Vector3(deg_to_rad(-160 * up + 10 * sin(s * 12) * up), 0, deg_to_rad(12 * up))
		model.position.y = 0.08 * absf(sin(s * 7.0)) * up
		return
	if phase in ["react", "leave"]:   # se encoge de hombros: palmas afuera
		var sh := clampf(t / 0.3, 0, 1) if phase == "react" else 1.0
		arm_r.rotation = Vector3(deg_to_rad(-35 * sh), 0, deg_to_rad(40 * sh))
		arm_l.rotation = Vector3(deg_to_rad(-35 * sh), 0, deg_to_rad(-40 * sh))
		model.position.y = 0.04 * sh
		return
	# Hablando: la mano derecha explica (sube, baja, se abre) y la izquierda acompaña; el cuerpo gira un poco
	var g1 := sin(s * 3.3)
	var g2 := sin(s * 2.1 + 1.0)
	arm_r.rotation = Vector3(deg_to_rad(lerpf(-4.0, -55.0 + 22.0 * g1, talk_k)), 0, deg_to_rad(lerpf(0.0, -14.0 + 12.0 * g2, talk_k)))
	arm_l.rotation = Vector3(deg_to_rad(lerpf(-2.0, -25.0 + 14.0 * g2, talk_k)), 0, deg_to_rad(lerpf(0.0, 10.0 + 6.0 * g1, talk_k)))
	model.rotation.y = deg_to_rad(18.0 + 6.0 * sin(s * 1.3) * talk_k + 2.0 * sin(s * 0.7))
	model.rotation.x = deg_to_rad(2.5 * sin(s * 4.0) * talk_k)   # asiente al hablar
	model.position.y = 0.012 * sin(s * 1.8)   # respira


## Si cambia la partida (menú, cargar otra) se cierra sin responder: la oferta sigue guardada para la próxima vez.
func clear() -> void:
	if not active():
		return
	phase = ""
	city.app.in_finale = false
	_free_stage()


## Enter, Espacio o clic: completa la frase o pasa a la siguiente.
func advance() -> void:
	match phase:
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
				_to("offer")
		"react":
			t = maxf(t, REACT - 0.01)


func key(e: InputEventKey) -> void:
	if e.keycode in [KEY_ENTER, KEY_KP_ENTER, KEY_SPACE]:
		advance()
	elif e.keycode == KEY_ESCAPE and phase == "talk":
		_to("offer")
	elif phase == "offer":
		if e.keycode in [KEY_1, KEY_KP_1, KEY_S]:
			_pick(true)
		elif e.keycode in [KEY_2, KEY_KP_2, KEY_N]:
			_pick(false)


func _pick(yes: bool) -> void:
	var res: Array = city.game.angel_resolve(yes)
	if not res[0]:
		return
	accepted = yes
	message = res[1]
	city.sfx.play("fanfare" if yes else "select", 0.6)
	_to("react")


func _end() -> void:
	phase = ""
	city.app.paused = was_paused
	city.app.in_finale = false
	city.capture_mouse()
	city.toast(message, "good" if accepted else "info")
	_free_stage()


func draw(ui: ImUI) -> void:
	if not active():
		return
	# La ciudad un poco más oscura detrás, más a la izquierda (donde está él) para que se lea todo
	var fade_in := clampf(total / 0.4, 0, 1)
	var out := clampf(t / LEAVE, 0, 1) if phase == "leave" else 0.0
	var a := fade_in * (1.0 - out)
	ui.rect(Rect2(-3000, -3000, ui.W + 6000, ui.H + 6000), Color(0, 0, 0, 0.35 * a))
	ui.gradient(Rect2(0, 0, ui.W * 0.6, ui.H), Color(0, 0, 0, 0.45 * a), Color(0, 0, 0, 0), true)
	# Ella: de abajo hasta arriba en la mitad izquierda; entra subiendo y se va bajando
	if vp != null:
		var h := ui.H
		var w := h * float(VIEW.x) / float(VIEW.y)
		var rise := 1.0 - pow(1.0 - clampf(total / RISE, 0, 1), 3)
		var y := (1.0 - rise) * h + out * out * h
		ui.image(vp.get_texture(), Rect2(ui.W / 4 - w / 2, y, w, h))
	match phase:
		"talk":
			var full := Lang.t(lines[line_i])
			_speech(ui, full.substr(0, mini(full.length(), int(line_t * Tutorial.TYPE_SPEED))), full.length())
		"offer":
			_offer(ui)
		"react":
			_speech(ui, Lang.t("¡Trato hecho! Vas a ver hasta dónde llegamos juntos." if accepted
					else "Entiendo. Si algún día cambias de idea... bueno, ya será tarde. ¡Suerte!"), -1)
	if ui.clicked and phase in ["talk", "react"]:
		advance()
	ui.clicked = false   # el clic no pasa a la ciudad


## El cuadro de lo que dice, abajo a la derecha de él, con su nombre en una pestaña.
func _speech(ui: ImUI, text: String, full_len: int) -> void:
	var x0 := ui.W * 0.4
	var box := Rect2(x0, ui.H - 190, ui.W - x0 - 40, 150)
	ui.rect(box, Color(0.04, 0.05, 0.075, 0.94), 16)
	ui.rect(box, Color(GOLD, 0.8), 16, 2)
	var who := Lang.f("%s · INVERSIONISTA DE %s", [String(D.ANGEL.name).to_upper(), Lang.t(D.ANGEL.from).to_upper()])
	var nw := ui.text_size(who, 13, true).x + 28
	var tab := Rect2(box.position.x + 30, box.position.y - 15, nw, 28)
	ui.rect(tab, GOLD, 14)
	ui.text(who, tab.get_center(), 13, Color8(16, 20, 30), true, "center")
	ui.wrap_text(text, Rect2(box.position.x + 30, box.position.y + 28, box.size.x - 60, box.size.y - 56), 21, Color.WHITE)
	if phase == "talk":
		var done := text.length() >= full_len
		var blink := 0.55 + 0.45 * sin(Time.get_ticks_msec() / 180.0) if done else 0.35
		ui.text(Lang.t("Enter / clic") + "  ▸", Vector2(box.end.x - 22, box.end.y - 18), 13, Color(GOLD, blink), true, "midright")
		for i in lines.size():
			var c: Color = GOLD if i == line_i else Color(1, 1, 1, 0.25 if i > line_i else 0.5)
			ui.circle(Vector2(box.position.x + 36 + i * 14, box.end.y - 18), 4, c)


## La oferta: a la derecha de él, con lo que te da, lo que pide y los botones.
func _offer(ui: ImUI) -> void:
	var e := 1.0 - pow(1.0 - clampf(t / 0.35, 0, 1), 3)
	var x0 := ui.W * 0.47
	var w := minf(560.0, ui.W - x0 - 40)
	var box := Rect2(x0 + (1.0 - e) * 60, ui.H / 2 - 230, w, 460)
	ui.canvas_alpha(e)
	ui.rect(box, Color(0.04, 0.05, 0.075, 0.95), 18)
	ui.rect(box, Color(GOLD, 0.6), 18, 1.5)
	var x := box.position.x + 32
	var cw := box.size.x - 64
	var y := box.position.y + 26
	ui.text("INVERSIÓN EXTRANJERA", Vector2(x, y), 12, Color(GOLD, 0.85), true)
	ui.text("Ángel", Vector2(x, y + 16), 44, GOLD, true)
	y += 84
	ui.text("TE DA", Vector2(x, y), 12, Color(1, 1, 1, 0.55), true)
	var money := Fmt.money(amount)
	ui.text(money, Vector2(x, y + 16), 34, GREEN, true)
	ui.text("de capital, a tu caja", Vector2(x + ui.text_size(money, 34, true).x + 12, y + 32), 14, Color(1, 1, 1, 0.65))
	y += 62
	var plus := Lang.f("+%s", Fmt.money(boost))
	ui.text(plus, Vector2(x, y), 24, GOLD, true)
	ui.text("al valor de tu empresa, para siempre", Vector2(x + ui.text_size(plus, 24, true).x + 12, y + 8), 14, Color(1, 1, 1, 0.65))
	y += 50
	ui.text("A CAMBIO", Vector2(x, y), 12, Color(1, 1, 1, 0.55), true)
	ui.wrap_text(Lang.f("El %d %% de tus ganancias de cada mes durante %d meses.", [roundi(float(D.ANGEL.share) * 100), int(D.ANGEL.months)]),
			Rect2(x, y + 18, cw, 24), 17, Color.WHITE, true)
	ui.wrap_text("No es un préstamo: no hay que devolverlo. Si un mes pierdes plata, ese mes no le pagas nada.",
			Rect2(x, y + 48, cw, 44), 14, Color(1, 1, 1, 0.65))
	y = box.end.y - 92
	var bw := (cw - 16) / 2
	var opts := [[true, "Sí, acepto", "1", GREEN], [false, "No, gracias", "2", RED]]
	for i in opts.size():
		var o: Array = opts[i]
		var r := Rect2(x + i * (bw + 16), y, bw, 52)
		var hot: bool = ui.hover(r)
		ui.rect(r, Color(o[3], 0.95 if hot else 0.75), 12)
		ui.rect(r, Color(1, 1, 1, 0.5 if hot else 0.0), 12, 2)
		var kr := Rect2(r.position.x + 14, r.get_center().y - 13, 26, 26)
		ui.rect(kr, Color(0, 0, 0, 0.3), 6)
		ui.text(o[2], kr.get_center(), 14, Color.WHITE, true, "center")
		ui.text(o[1], Vector2(r.get_center().x + 14, r.get_center().y), 18, Color.WHITE, true, "center")
		if hot and ui.clicked:
			ui.clicked = false
			_pick(o[0])
	ui.text("Teclas: 1 o S para sí · 2 o N para no", Vector2(x + cw / 2, y + 70), 12, Color(1, 1, 1, 0.4), false, "center")
	ui.canvas_alpha(1.0)
