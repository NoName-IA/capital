class_name Finale
extends RefCounted
## «La última reunión»: el final del juego, al llegar a la meta (City.react "win"; una vez por partida, y se puede
## volver a ver desde la vitrina de trofeos). Una cinemática: franjas negras de cine que entran deslizándose, bordes
## oscurecidos, sin la interfaz del juego, con música y tomas de cámara que se mueven solas. Por partes (Esc o un clic
## saltan a la que sigue):
##  call    · suena el teléfono: «Jefe, lo esperan arriba». La pantalla se oscurece.
##  walk    · título del capítulo sobre negro; entras al vestíbulo y caminas por la alfombra hasta el ascensor (la
##            cámara te sigue por detrás), se abren las puertas, entras, te das la vuelta y se cierran (toma de frente).
##  ride    · la subida (Tower.go_up_finale): más lenta, los ejecutivos de pie celebrando y mirándote, y el visor con el
##            año en que llegaste a cada rango.
##  window  · se abren las puertas arriba y la cámara cruza la presidencia hasta el ventanal: la ciudad desde arriba.
##  photo   · ¡foto para la portada! Tu personaje frente al ventanal (con la ropa del armario) y un flash.
##  paper   · el kiosco ELDIARIO y el diario que llega girando hasta llenar la pantalla: el titular, tu foto en grande
##            y la nota.
##  credits · créditos sobre la ciudad y, al final (card), la tarjeta con tus números para leerla con calma.
##            Con un clic, al menú principal (la partida se guarda antes); si lo estás volviendo a ver desde la
##            vitrina, vuelves al juego.

const CALL := 3.6
const TITLE := 2.6            # el título del capítulo sobre negro, al empezar walk
# La caminata (segundos desde que termina el título): hasta el ascensor, se abren las puertas, entras, te das la
# vuelta y se cierran.
const W_ARRIVE := 3.6
const W_OPEN := 4.5
const W_IN := 5.6
const W_TURN := 6.3
const W_CLOSE := 7.5
const WALK := TITLE + 8.0
const WALK_FROM := 2.6        # z en la oficina (City.HQ): recién entrando por la puerta
const WALK_TO := 14.2         # frente a las puertas del ascensor
const CAB_IN := 15.35         # adentro de la cabina del vestíbulo
const WINDOW := 4.5
const PHOTO := 2.2
const KIOSK_SHOT := 1.6       # la toma del kiosco antes de que llegue el diario
const SPIN := 1.1             # el diario girando
const PAPER := 21.0           # el diario queda en pantalla para leerlo con calma
const CREDITS := 26.0
const ROLES := ["DIRECCIÓN Y DISEÑO DEL JUEGO", "DESARROLLO Y PROGRAMACIÓN", "ESTILO ARTÍSTICO", "DISEÑO DE PERSONAJES",
		"DISEÑO DE LA CIUDAD Y LOS LOCALES", "DISEÑO DE INTERFAZ", "ECONOMÍA Y BALANCE", "GUION Y NARRATIVA",
		"CINEMÁTICAS", "EFECTOS DE SONIDO", "PRUEBAS Y CONTROL DE CALIDAD"]
const CARD_READY := 1.6       # desde cuándo la tarjeta acepta el clic
const OUT := 1.1              # la tarjeta se funde a negro antes del menú
const MENU_IN := 1.4          # y el menú aparece desde el negro
const FADE := 0.6
const BAR := 74.0             # alto de las franjas de cine
const GOLD := Color8(240, 195, 80)
const INK := Color8(24, 22, 20)
const PAPER_COL := Color8(242, 236, 220)
const KIOSK := Vector3(-69.0, 5.6, 11.95)   # el centro de la pantalla del kiosco ELDIARIO (ver WorldBuilder._eldiario)
const HEADLINE := "La fortuna detrás de una mente emprendedora"
const STORY := ["Un empresario visionario convirtió una pequeña idea en una compañía millonaria.",
		"Su éxito nació de la innovación, la disciplina y decisiones estratégicas.",
		"Hoy es un referente de emprendimiento y crecimiento empresarial."]

var city
var phase := ""
var t := 0.0
var total := 0.0              # segundos desde que empezó (para las franjas)
var fade := 0.0
var photo: Texture2D = null
var want_photo := -1          # cuadros que faltan para sacar la foto (-1: nada)
var was_paused := false
var cues := {}                # sonidos que ya sonaron en esta parte
var shake := 0.0              # sacudida de la cámara (el golpe del diario)
var replay := false           # lo estás volviendo a ver (desde la vitrina)
var menu_in_at := -1          # ms en que empezó a aparecer el menú (-1: nada)
var leaving := -1.0           # segundos desde el clic en la tarjeta (-1: todavía no), se funde a negro


func _init(owner_city) -> void:
	city = owner_city


func active() -> bool:
	return phase != ""


## Empieza el final (también al volver a verlo desde la vitrina).
func start() -> void:
	if active() or city.game == null:
		return
	city.drop_computer()
	if city.overlays.open():
		city.overlays.hide()
	city.stop_serving()
	was_paused = city.app.paused
	city.app.paused = true
	city.app.in_finale = true
	city.app.modal = null
	phase = "call"
	t = 0.0
	total = 0.0
	fade = 0.0
	photo = null
	want_photo = -1
	cues = {}
	replay = city.game.finale_seen
	leaving = -1.0
	city.sfx.play("fin_tono", 0.2)   # el teléfono, bajito
	city.sfx.play_special(Sfx.FINALE_SONG[0])   # la canción del final, desde que empieza


func _go(p: String) -> void:
	phase = p
	t = 0.0
	cues = {}
	match p:
		"walk":
			var pl: Person = city.player
			pl.visible = true
			pl.sit(0.0)
			pl.position = Blueprints.to_world(City.HQ, 0.0, WALK_FROM)
			pl.rotation.y = 0.0
			city.tower.set_lobby_doors(0.0)
			fade = 1.0
		"ride":
			city.tower.set_lobby_doors(0.0)
			city.player.position = Blueprints.to_world(City.HQ, Tower.LOBBY_LIFT.x, Tower.LOBBY_LIFT.z)
			city.player.visible = false
			city.tower.go_up_finale(_milestones())
		"window":
			fade = 0.0
		"photo":
			city.tower.cab.visible = false
			city.player.position = city.tower.w(Vector3(-3.0, 0, 5.6))
			city.player.rotation.y = PI
			city.player.visible = true
			city.player.sit(0.0)
			city.player.animate(0.0, 0.0)
		"paper":
			city.player.visible = false
		"card":
			city.release_mouse()


func _cue(id: String, sound: String, vol := 0.6, pitch := 1.0) -> void:
	if not cues.has(id):
		cues[id] = true
		city.sfx.play(sound, vol, pitch)


## Un clic o Esc: salta a la parte que sigue.
func skip() -> void:
	match phase:
		"call", "walk", "ride", "window", "photo":
			if city.tower.busy():
				city.tower.end_finale()
			city.tower.set_lobby_doors(0.0)
			fade = 0.0
			if photo == null:   # sin foto, la portada usa tu personaje dibujado
				pass
			_go("paper")
		"paper":
			_go("credits")
		"credits":
			_go("card")


## Avisa Tower cuando se abrieron las puertas arriba.
func after_ride() -> void:
	if phase == "ride":
		_go("window")


## [año, título] de cada rango conseguido, en orden (sale de Game.rank_log; el primero es el de partida).
func _milestones() -> Array:
	var g: Game = city.game
	var out := [[1, g.ranks()[0][1]]]
	for r in g.ranks().slice(1):
		if g.rank_log.has(r[1]):
			out.append([int(g.rank_log[r[1]][0]) / 360 + 1, r[1]])
	if out.size() < 2:
		out.append([int(g.day) / 360 + 1, g.ranks()[-1][1]])
	return out


static func _ease(k: float) -> float:
	k = clampf(k, 0, 1)
	return k * k * (3 - 2 * k)


func update(dt: float) -> void:
	if not active():
		return
	t += dt
	total += dt
	shake = maxf(0.0, shake - dt * 2.5)
	city.app.paused = true
	match phase:
		"call":
			fade = clampf((t - (CALL - FADE)) / FADE, 0, 1)
			if t >= CALL:
				_go("walk")
		"walk":
			_update_walk(dt)
		"ride":
			fade = 1.0 - clampf(t / FADE, 0, 1)
		"window":
			fade = clampf((t - (WINDOW - FADE)) / FADE, 0, 1)
			if t >= WINDOW:
				_go("photo")
		"photo":
			fade = 1.0 - clampf(t / 0.3, 0, 1)
			if t >= 0.8 and photo == null and want_photo < 0:
				want_photo = 3
				_cue("click", "fin_obturador", 0.8)   # el obturador de la cámara
			if want_photo > 0:
				want_photo -= 1
				if want_photo == 0:
					_take_photo()
			if t >= PHOTO:
				fade = 1.0
				_go("paper")
		"paper":
			if t < KIOSK_SHOT:
				fade = 1.0 - clampf(t / 0.4, 0, 1)
			else:
				fade = clampf((t - (PAPER - FADE)) / FADE, 0, 1)
			if t >= KIOSK_SHOT:
				_cue("spin", "fin_giro", 0.6)
			if t >= KIOSK_SHOT + SPIN:
				if not cues.has("thump"):
					shake = 1.0
				_cue("thump", "fin_impacto", 0.85)   # el diario cae
			if t >= PAPER:
				_go("credits")
		"credits":
			fade = 1.0 - clampf(t / FADE, 0, 1)
			if t >= CREDITS:
				_go("card")
		"card":
			fade = 0.0
			if leaving >= 0.0:
				leaving += dt
				fade = _ease(leaving / OUT)
				if leaving >= OUT:
					_end()


## La caminata hasta el ascensor del vestíbulo: llegas, se abren las puertas, entras, te das la vuelta y se cierran.
func _update_walk(dt: float) -> void:
	var p: Person = city.player
	var w := t - TITLE
	if w < 0:   # el título del capítulo, sobre negro
		fade = 1.0
		if t > 0.3:
			_cue("title", "fin_golpe", 0.7)
		return
	fade = 1.0 - clampf(w / FADE, 0, 1) if w < W_CLOSE else clampf((w - W_CLOSE - 0.1) / 0.4, 0, 1)
	var z := WALK_FROM
	var walking := false
	var yaw := 0.0
	if w < W_ARRIVE:
		z = lerpf(WALK_FROM, WALK_TO, _ease(w / W_ARRIVE) * 0.85 + clampf(w / W_ARRIVE, 0, 1) * 0.15)
		walking = true
	elif w < W_OPEN:
		z = WALK_TO
		city.tower.set_lobby_doors(_ease((w - W_ARRIVE) / (W_OPEN - W_ARRIVE)))
		_cue("ding", "fin_campana", 0.5)
		_cue("open", "fin_puertas", 0.45)
	elif w < W_IN:
		z = lerpf(WALK_TO, CAB_IN, _ease((w - W_OPEN) / (W_IN - W_OPEN)))
		walking = true
	elif w < W_TURN:   # se da la vuelta, de frente a la cámara
		z = CAB_IN
		yaw = PI * _ease((w - W_IN) / (W_TURN - W_IN))
	else:
		z = CAB_IN
		yaw = PI
		var k := _ease((w - (W_TURN + 0.25)) / (W_CLOSE - W_TURN - 0.25))
		city.tower.set_lobby_doors(1.0 - k)
		if k > 0.0:
			_cue("close", "fin_puertas", 0.4, 0.9)
	p.position = Blueprints.to_world(City.HQ, 0.0, z)
	p.rotation.y = yaw
	p.animate(2.0 if walking else 0.0, dt)
	if t >= WALK:
		_go("ride")


## La foto de la portada: lo que se ve ahora (tu personaje frente al ventanal), recortada vertical al centro.
func _take_photo() -> void:
	var img: Image = city.get_viewport().get_texture().get_image()
	if img == null or img.is_empty():
		return
	var h := int(img.get_height() * 0.86)
	var w := int(h * 0.66)
	var crop := img.get_region(Rect2i((img.get_width() - w) / 2, (img.get_height() - h) / 2, w, h))
	photo = ImageTexture.create_from_image(crop)


## La cámara de cada parte (la del viaje la pone Tower).
func place_camera(cam: Camera3D) -> bool:
	if not active():
		return false
	var tw: Tower = city.tower
	var hq := func(x: float, z: float, y: float) -> Vector3: return Blueprints.to_world(City.HQ, x, z, y)
	match phase:
		"call":   # se acerca despacio a tu personaje mientras suena el teléfono
			var pp: Vector3 = city.player.position
			var k := _ease(t / CALL)
			var back := Vector3(sin(city.player.rotation.y), 0, cos(city.player.rotation.y))
			cam.global_position = pp - back * lerpf(5.0, 3.2, k) + Vector3(0.9, lerpf(2.6, 2.0, k), 0)
			cam.look_at(pp + Vector3(0, 1.5, 0))
		"walk":
			var w := t - TITLE
			if w < W_ARRIVE - 0.5:   # detrás de ti, siguiéndote por la alfombra
				var pp: Vector3 = city.player.position
				cam.global_position = pp + Vector3(0.7 - w * 0.12, 2.2, -3.3)
				cam.look_at(pp + Vector3(0, 1.3, 3.2))
			else:   # de frente al ascensor: te ve entrar, darte vuelta y las puertas se cierran
				var k := _ease((w - (W_ARRIVE - 0.5)) / (W_CLOSE - W_ARRIVE + 0.5))
				cam.global_position = hq.call(lerpf(1.6, 0.5, k), lerpf(9.6, 11.2, k), lerpf(1.9, 1.7, k))
				cam.look_at(hq.call(0.0, 15.2, 1.35))
		"ride":
			tw.place_camera(cam)
		"window":   # de la cabina, cruzando la oficina hasta el ventanal; al final mira la ciudad
			var k := _ease(t / WINDOW)
			var eye := tw.w(Vector3(0, 1.65, Tower.CAB_Z - 0.55)).lerp(tw.w(Vector3(3.2, 2.1, 6.3)), k)
			var look := tw.w(Vector3(0, 1.4, 2.0)).lerp(tw.w(Vector3(3.2, -6.0, 60.0)), k)
			cam.global_position = eye
			cam.look_at(look)
		"photo":
			cam.global_position = tw.w(Vector3(-3.0, 1.55, 3.5))
			cam.look_at(tw.w(Vector3(-3.0, 1.2, 5.6)))
		"paper":   # frente al kiosco, acercándose despacio (atrás llega el diario)
			var k2 := _ease(t / PAPER)
			cam.global_position = KIOSK + Vector3(lerpf(1.5, 0.3, k2), lerpf(-2.6, -0.4, k2), -lerpf(9.0, 5.5, k2))
			cam.look_at(KIOSK + Vector3(0, -0.8, 0))
		"credits", "card":   # vuela lento por encima de la ciudad
			var a := 0.6 + (t if phase == "credits" else CREDITS + t) * 0.035
			cam.global_position = Vector3(20.0 + cos(a) * 120.0, 55.0, sin(a) * 90.0)
			cam.look_at(Vector3(10.0, 0.0, 0.0))
	if shake > 0.0:
		cam.global_position += Vector3(randf_range(-1, 1), randf_range(-1, 1), 0) * 0.05 * shake
	return true


# ---------- dibujo ----------
func draw(ui: ImUI) -> void:
	if not active():
		return
	if want_photo > 0:   # el cuadro de la foto va limpio
		return
	match phase:
		"call":
			_draw_call(ui)
		"walk":
			if t < TITLE + 0.2:
				_draw_title(ui)
		"window":
			_subtitle(ui, "Desde aquí se ve todo lo que construiste", clampf(t / 0.8, 0, 1) * clampf((WINDOW - 0.6 - t) / 0.6, 0, 1))
		"photo":
			var fl := clampf(1.0 - absf(t - 0.85) / 0.25, 0, 1)   # el flash
			ui.rect(Rect2(-3000, -3000, ui.W + 6000, ui.H + 6000), Color(1, 1, 1, fl * 0.9))
			_subtitle(ui, "¡Foto para la portada!", clampf(t / 0.4, 0, 1))
		"paper":
			_draw_newspaper(ui)
		"credits":
			_draw_credits(ui)
		"card":
			_draw_card(ui)
	if phase == "card":
		if ui.clicked and t >= CARD_READY and leaving < 0.0:   # solo un clic deja la tarjeta (Esc no: sirve para salir de pantalla completa)
			leaving = 0.0
		ui.clicked = false
	else:
		_vignette(ui)
		_bars(ui)
		var hint := clampf((3.0 - t) / 0.6, 0, 1) if phase in ["call", "paper"] else 0.0
		if hint > 0:
			ui.text("Esc o clic: saltar", Vector2(ui.W - 24, ui.H - 22), 12, Color(1, 1, 1, 0.45 * hint), false, "bottomright")
		if ui.clicked:
			ui.clicked = false
			skip()
	if fade > 0.0 and not (phase == "walk" and t < TITLE):
		ui.rect(Rect2(-3000, -3000, ui.W + 6000, ui.H + 6000), Color(0, 0, 0, fade))


## Las franjas negras de cine: entran deslizándose al empezar y se quedan hasta la tarjeta final.
func _bars(ui: ImUI) -> void:
	var h := BAR * _ease(total / 1.2)
	ui.rect(Rect2(-3000, -3000, ui.W + 6000, 3000 + h), Color(0, 0, 0))
	ui.rect(Rect2(-3000, ui.H - h, ui.W + 6000, 3000 + h), Color(0, 0, 0))


## Bordes oscurecidos (viñeta), como una película.
func _vignette(ui: ImUI) -> void:
	var e := 160.0
	var dark := Color(0, 0, 0, 0.42)
	var clear := Color(0, 0, 0, 0)
	ui.gradient(Rect2(0, 0, e, ui.H), dark, clear, true)
	ui.gradient(Rect2(ui.W - e, 0, e, ui.H), clear, dark, true)
	ui.gradient(Rect2(0, 0, ui.W, e * 0.7), dark, clear, false)
	ui.gradient(Rect2(0, ui.H - e * 0.7, ui.W, e * 0.7), clear, dark, false)


## Un subtítulo abajo, entre las franjas.
func _subtitle(ui: ImUI, text: String, a: float) -> void:
	if a <= 0:
		return
	ui.text(text, Vector2(ui.W / 2 + 1, ui.H - BAR - 34 + 1), 21, Color(0, 0, 0, 0.7 * a), true, "center")
	ui.text(text, Vector2(ui.W / 2, ui.H - BAR - 34), 21, Color(1, 1, 1, a), true, "center")


## El título del capítulo sobre negro.
func _draw_title(ui: ImUI) -> void:
	ui.rect(Rect2(-3000, -3000, ui.W + 6000, ui.H + 6000), Color(0, 0, 0))
	var a := clampf(t / 0.6, 0, 1) * clampf((TITLE - t) / 0.5, 0, 1)
	var cy := ui.H / 2
	ui.text("CAPITAL", Vector2(ui.W / 2, cy - 54), 14, Color(GOLD, a * 0.9), true, "center")
	ui.text("Capítulo final", Vector2(ui.W / 2, cy - 26), 16, Color(1, 1, 1, a * 0.7), false, "center")
	var lw := 280.0 * _ease(t / 1.2)
	ui.rect(Rect2(ui.W / 2 - lw / 2, cy - 8, lw, 1.5), Color(GOLD, a))
	ui.text("LA ÚLTIMA REUNIÓN", Vector2(ui.W / 2, cy + 26), 40, Color(1, 1, 1, a), true, "center")


## La llamada: una tarjeta arriba con tu asistente, que vibra mientras suena; lo que dice va como subtítulo.
func _draw_call(ui: ImUI) -> void:
	var a := clampf((t - 0.4) / 0.3, 0, 1)
	var shk := sin(t * 40.0) * 2.0 if t < 1.4 else 0.0
	var r := Rect2(ui.W / 2 - 170 + shk, BAR + 18, 340, 64)
	ui.rect(r, Color(0.06, 0.07, 0.09, 0.9 * a), 32)
	ui.rect(r, Color(GOLD, 0.7 * a), 32, 1.5)
	var c := r.position + Vector2(34, 32)
	ui.circle(c, 22, Color(0.16, 0.24, 0.44, a))
	ui.ring(c, 22 + fmod(t * 26.0, 12.0), Color(GOLD, (1.0 - fmod(t * 26.0, 12.0) / 12.0) * a), 2)
	ui.text("A", c, 18, Color(1, 1, 1, a), true, "center")
	ui.text("TU ASISTENTE", r.position + Vector2(68, 22), 11, Color(GOLD, a), true, "midleft")
	ui.text("Llamando...", r.position + Vector2(68, 42), 15, Color(1, 1, 1, a), false, "midleft")
	var line := Lang.t("Jefe, lo esperan arriba.")
	var n := clampi(int((t - 1.0) * 28.0), 0, line.length())
	_subtitle(ui, line.substr(0, n), 1.0 if n > 0 else 0.0)


## El diario: llega girando desde el kiosco hasta llenar la pantalla, cae con un golpe y se queda para leerlo.
func _draw_newspaper(ui: ImUI) -> void:
	if t < KIOSK_SHOT:
		_subtitle(ui, "Al día siguiente...", clampf(t / 0.4, 0, 1) * clampf((KIOSK_SHOT - t) / 0.3, 0, 1))
		return
	ui.rect(Rect2(-3000, -3000, ui.W + 6000, ui.H + 6000), Color(0, 0, 0, 0.55 * clampf((t - KIOSK_SHOT) / 0.4, 0, 1)))
	var ph := minf(ui.H - BAR * 2 - 24, (ui.W - 80) / 1.35)
	var full := Rect2(ui.W / 2 - ph * 1.35 / 2, ui.H / 2 - ph / 2, ph * 1.35, ph)
	var k := clampf((t - KIOSK_SHOT) / SPIN, 0, 1)
	if k < 1.0:   # girando y agrandándose (solo la hoja, con líneas de texto borrosas)
		var e := 1.0 - pow(1.0 - k, 3.0)
		var ang := (1.0 - e) * TAU * 2.0
		var sz := full.size * lerpf(0.06, 1.0, e)
		var c := full.get_center()
		var pts := PackedVector2Array()
		for v in [Vector2(-1, -1), Vector2(1, -1), Vector2(1, 1), Vector2(-1, 1)]:
			pts.append(c + (v * sz / 2).rotated(ang))
		ui.polygon(pts, PAPER_COL)
		for i in 7:
			var y := -0.35 + i * 0.1
			ui.line(c + (Vector2(-0.4, y) * sz).rotated(ang), c + (Vector2(0.4, y) * sz).rotated(ang), Color(0, 0, 0, 0.25), maxf(1.0, sz.y * 0.012))
		return
	_page(ui, full)


## La portada completa: el nombre del diario, el titular, tu foto en grande (vertical) y la nota.
func _page(ui: ImUI, r: Rect2) -> void:
	var g: Game = city.game
	var s := r.size.y / 600.0
	ui.rect(r.grow(4 * s), Color(0, 0, 0, 0.35))
	ui.rect(r, PAPER_COL)
	var x0 := r.position.x + 28 * s
	var w := r.size.x - 56 * s
	var y := r.position.y + 16 * s
	ui.text("ELDIARIO", Vector2(r.get_center().x, y), int(54 * s), INK, true, "midtop")
	y += 66 * s
	ui.rect(Rect2(x0, y, w, 3 * s), INK)
	var dp: Array = g.date_parts()
	ui.text(Lang.f("%s · Año %d", [Lang.t(dp[1]), dp[2]]), Vector2(x0, y + 6 * s), int(12 * s), Color8(90, 86, 80))
	ui.text("EDICIÓN ESPECIAL", Vector2(x0 + w, y + 6 * s), int(12 * s), Color8(170, 30, 30), true, "topright")
	y += 26 * s
	ui.rect(Rect2(x0, y, w, 1 * s), INK)
	y += 16 * s
	# Tu foto en grande, vertical, a la izquierda
	var pw := (r.end.y - 40 * s - y) * 0.66
	var pr := Rect2(x0, y, pw, pw / 0.66)
	ui.rect(pr.grow(3 * s), INK)
	if photo != null:
		ui.image(photo, pr)
	else:
		ui.rect(pr, Color8(70, 74, 82))
		ui.circle(pr.get_center() - Vector2(0, pr.size.y * 0.18), pr.size.x * 0.2, Color8(210, 205, 195))
		ui.rect(Rect2(pr.get_center().x - pr.size.x * 0.3, pr.get_center().y + pr.size.y * 0.02, pr.size.x * 0.6, pr.size.y * 0.5), Color8(30, 30, 34), 10 * s)
	ui.text(Lang.f("%s, en su oficina del último piso.", str(g.company)), Vector2(pr.position.x, pr.end.y + 8 * s), int(11 * s),
			Color8(90, 86, 80), false, "topleft", pr.size.x)
	# A la derecha: el titular y la nota
	var tx := pr.end.x + 26 * s
	var tw := r.end.x - 28 * s - tx
	var th := ui.wrap_text(Lang.t(HEADLINE), Rect2(tx, y - 4 * s, tw, 200 * s), int(40 * s), INK, true, 2.0)
	y += th + 12 * s
	ui.rect(Rect2(tx, y, tw * 0.3, 3 * s), Color8(170, 30, 30))
	y += 18 * s
	for para in STORY:
		var hh := ui.wrap_text(Lang.t(para), Rect2(tx, y, tw, 120 * s), int(19 * s), Color8(40, 38, 34), false, 4.0)
		y += hh + 12 * s
	y += 6 * s
	var i := 0
	while y < r.end.y - 34 * s:   # columnas de texto de relleno
		var lw := tw * (0.62 + 0.38 * fmod(i * 0.37, 1.0))
		ui.rect(Rect2(tx, y, lw, 5 * s), Color(0.55, 0.53, 0.5, 0.75))
		y += 13 * s
		i += 1


## Créditos que suben sobre la ciudad.
func _draw_credits(ui: ImUI) -> void:
	ui.rect(Rect2(-3000, -3000, ui.W + 6000, ui.H + 6000), Color(0, 0, 0, 0.45))
	var lines := [["CAPITAL", 56, GOLD], ["", 20, Color.WHITE], [Lang.t("Gracias por jugar"), 22, Color.WHITE], ["", 40, Color.WHITE]]
	var who: String = Overlays.AUTHORS[0][0]
	for role in ROLES:   # como los créditos de una película: el rol arriba, chico y dorado, y el nombre abajo
		lines.append([Lang.t(role), 13, GOLD])
		lines.append([who, 24, Color.WHITE])
		lines.append(["", 14, Color.WHITE])
	lines.append(["", 16, Color.WHITE])
	lines.append([Lang.t("MÚSICA"), 14, GOLD])
	lines.append([Sfx.FINALE_SONG[1], 17, Color.WHITE])
	for sg in Sfx.SONGS:
		lines.append([Lang.f("%s · %s", [sg[1], sg[2]]), 17, Color.WHITE])
	lines.append(["", 30, Color.WHITE])
	lines.append([Lang.f("Hecho en Godot %s", Engine.get_version_info().string.get_slice("-", 0)), 14, Color(1, 1, 1, 0.7)])
	var sum := 0.0
	for l in lines:
		sum += l[1] + 18
	var y: float = ui.H - (t / (CREDITS - 1.0)) * (ui.H + sum) + ui.H * 0.1
	for l in lines:
		if l[0] != "":
			ui.text(l[0], Vector2(ui.W / 2, y), l[1], l[2], true, "midtop")
		y += l[1] + 18


## La tarjeta final, como un informe de la bolsa con los colores de la tablet: arriba la cinta de cotizaciones que
## corre, el encabezado con tu empresa y lo que vale; a la izquierda el gráfico de tu camino (el valor de la empresa
## en el tiempo, con cada rango que conseguiste, en escala de 10 en 10); a la derecha el balance; abajo los botones.
func _draw_card(ui: ImUI) -> void:
	var g: Game = city.game
	var col := ImUI.COL
	var a := _ease(t / 0.5)
	ui.rect(Rect2(-3000, -3000, ui.W + 6000, ui.H + 6000), Color(0, 0, 0, 0.66 * a))
	var bw := minf(1120.0, ui.W - 60)
	var bh := 580.0
	var box := Rect2(ui.W / 2 - bw / 2, ui.H / 2 - bh / 2 + (1.0 - a) * 30.0, bw, bh)
	ui.rect(box, Color(col.bg, 0.98 * a), 16)
	ui.rect(box, Color(col.border, a), 16, 1)
	# Cinta de cotizaciones
	var staff := 0
	for l in g.locations:
		staff += int(l.employees)
	var factories := 0
	for k in g.products:
		factories += int(g.products[k].factory)
	var tape := Rect2(box.position.x + 1, box.position.y + 1, bw - 2, 30)
	ui.rect(tape, Color(col.panel, a), 15)
	ui.rect(Rect2(tape.position.x, tape.position.y + 15, tape.size.x, 15), Color(col.panel, a))
	ui.set_clip(tape)
	var items := [["CAPITAL", Fmt.short(g.valuation()), true], [Lang.t("LOCALES"), str(g.locations.size()), true],
			[Lang.t("EMPLEADOS"), str(staff), true], [Lang.t("FÁBRICAS"), str(factories), true],
			[Lang.t("CAJA"), Fmt.short(g.cash), g.cash >= 0], [Lang.t("MEJOR MES"), Fmt.short(g.best_month_sales()), true]]
	var seg := 0.0
	for it in items:
		seg += ui.text_size(it[0] + "  " + it[1], 12, true).x + 70
	var x := tape.position.x - fmod(t * 60.0, seg)
	while x < tape.end.x:
		for it in items:
			var w0 := ui.text(it[0], Vector2(x, tape.get_center().y), 12, Color(col.muted, a), true, "midleft").size.x
			var c: Color = col.green if it[2] else col.red
			var w1 := ui.text(("▲ " if it[2] else "▼ ") + it[1], Vector2(x + w0 + 8, tape.get_center().y), 12, Color(c, a), true, "midleft").size.x
			x += w0 + w1 + 70
	ui.set_clip(null)
	ui.rect(Rect2(tape.position.x, tape.end.y, tape.size.x, 1), Color(col.border, a))
	# Encabezado
	var hx := box.position.x + 32
	var hy := tape.end.y + 22
	var years: int = int(g.day) / 360 + 1
	ui.text(Lang.f("INFORME FINAL · AÑO %d", years), Vector2(hx, hy), 12, Color(col.accent, a), true)
	ui.text(str(g.company), Vector2(hx, hy + 18), 34, Color(col.text, a), true)
	var rank: String = g.ranks()[g.rank][1]
	var rw := ui.text_size(Lang.t(rank), 13, true).x + 40
	var badge := Rect2(hx, hy + 64, rw, 26)
	ui.rect(badge, Color(col.accent, 0.16 * a), 13)
	ui.rect(badge, Color(col.accent, 0.7 * a), 13, 1)
	Icons.draw(ui, "crown", Vector2(badge.position.x + 15, badge.get_center().y), 13, Color(col.accent, a))
	ui.text(Lang.t(rank), Vector2(badge.position.x + 28, badge.get_center().y), 13, Color(col.accent, a), true, "midleft")
	var shown: float = g.valuation() * _ease((t - 0.3) / 1.4)
	ui.text("VALOR DE LA EMPRESA", Vector2(box.end.x - 32, hy), 12, Color(col.muted, a), true, "topright")
	ui.text(Fmt.money(shown), Vector2(box.end.x - 32, hy + 16), 38, Color(col.accent, a), true, "topright")
	var start_value: float = D.MODES[g.mode].start_cash
	var growth: float = g.valuation() / maxf(1.0, start_value)
	ui.text(Lang.f("▲ %sx desde el primer día", Fmt.num(growth, 0)), Vector2(box.end.x - 32, hy + 66), 14, Color(col.green, a), true, "topright")
	# Gráfico: tu camino
	var top := hy + 110
	var gr := Rect2(hx, top, bw * 0.6 - 40, box.end.y - 96 - top)
	_draw_path_chart(ui, g, gr, a)
	# Balance
	var br := Rect2(gr.end.x + 24, top, box.end.x - 32 - gr.end.x - 24, gr.size.y)
	ui.rect(br, Color(col.panel, a), 12)
	ui.text("BALANCE", br.position + Vector2(18, 14), 12, Color(col.muted, a), true)
	var rows := [["Locales", str(g.locations.size()), "text"], ["Empleados", str(staff), "text"],
			["Fábricas", str(factories), "text"], ["Días jugados", str(int(g.day)), "text"],
			["Tiempo de juego", Lang.f("%d min", roundi(g.play_seconds / 60.0)), "text"],
			["Mejor mes de ventas", Fmt.money(g.best_month_sales()), "green"]]
	var ry := br.position.y + 44
	for i in rows.size():
		var kr := _ease((t - 0.5 - i * 0.1) / 0.35)
		if kr <= 0:
			continue
		var rr: Array = rows[i]
		ui.text(Lang.t(rr[0]), Vector2(br.position.x + 18, ry), 14, Color(col.muted, a * kr))
		ui.text(rr[1], Vector2(br.end.x - 18, ry), 15, Color(col[rr[2]], a * kr), true, "topright")
		ui.rect(Rect2(br.position.x + 18, ry + 26, br.size.x - 36, 1), Color(col.border, 0.6 * a * kr))
		ry += 36
	if not g.worst_choice.is_empty():
		var kw := _ease((t - 1.2) / 0.35)
		ui.text("LA DECISIÓN QUE MÁS TE COSTÓ", Vector2(br.position.x + 18, ry + 6), 11, Color(col.muted, a * kw), true)
		ui.wrap_text(Lang.f("%s · %s", [Lang.t(g.worst_choice.title), Fmt.money(-float(g.worst_choice.loss))]),
				Rect2(br.position.x + 18, ry + 24, br.size.x - 36, 44), 13, Color(col.red, a * kw), true)
	# Pie: la fecha y el aviso para seguir
	var kc := _ease((t - CARD_READY) / 0.5)
	if kc <= 0:
		return
	var by := box.end.y - 47
	ui.text(Lang.f("Capital · %s", g.date_str()), Vector2(hx, by), 12, Color(col.muted, a * kc), false, "midleft")
	var pulse := 0.55 + 0.45 * sin(t * 3.0)
	ui.text("Haz clic para continuar", Vector2(box.end.x - 32, by), 14, Color(col.text, a * kc * pulse), true, "midright")


## El gráfico de tu camino: el valor de la empresa desde el primer día hasta hoy (escala de 10 en 10), con un punto
## en cada rango que conseguiste. La línea se dibuja de a poco.
func _draw_path_chart(ui: ImUI, g: Game, r: Rect2, a: float) -> void:
	var col := ImUI.COL
	ui.rect(r, Color(col.panel, a), 12)
	ui.text("TU CAMINO", r.position + Vector2(18, 14), 12, Color(col.muted, a), true)
	var area := Rect2(r.position.x + 70, r.position.y + 50, r.size.x - 96, r.size.y - 84)
	var pts := [[0.0, maxf(1000.0, float(D.MODES[g.mode].start_cash)), ""]]
	for rk in g.ranks().slice(1):
		if g.rank_log.has(rk[1]):
			pts.append([float(g.rank_log[rk[1]][0]), float(rk[0]), rk[1]])
	pts.sort_custom(func(p, q): return p[0] < q[0])
	if pts[-1][0] >= float(g.day) - 1.0:   # el último rango es de hoy: ese punto ya es «hoy»
		pts[-1] = [float(g.day), g.valuation(), pts[-1][2]]
	else:
		pts.append([float(g.day), g.valuation(), ""])
	var lo := floorf(log(pts[0][1]) / log(10.0))
	var hi := ceilf(log(g.valuation()) / log(10.0))
	var days := maxf(1.0, float(g.day))
	var at := func(p: Array) -> Vector2:
		return Vector2(area.position.x + p[0] / days * area.size.x,
				area.end.y - (log(maxf(1.0, p[1])) / log(10.0) - lo) / maxf(1.0, hi - lo) * area.size.y)
	for e in range(int(lo), int(hi) + 1):   # líneas de $1 k, $10 k, $100 k...
		var y: float = area.end.y - (e - lo) / maxf(1.0, hi - lo) * area.size.y
		ui.line(Vector2(area.position.x, y), Vector2(area.end.x, y), Color(col.border, 0.7 * a), 1)
		ui.text(Fmt.short(pow(10.0, e)), Vector2(area.position.x - 10, y), 11, Color(col.muted, a), false, "midright")
	ui.text(Lang.t("Día 1"), Vector2(area.position.x, area.end.y + 12), 11, Color(col.muted, a), false, "topleft")
	ui.text(Lang.f("Día %d", int(g.day)), Vector2(area.end.x, area.end.y + 12), 11, Color(col.muted, a), false, "topright")
	# La línea, que avanza de izquierda a derecha
	var k := _ease((t - 0.3) / 1.6)
	var line := PackedVector2Array()
	for i in pts.size():
		var p: Vector2 = at.call(pts[i])
		if (p.x - area.position.x) / area.size.x > k and i > 0:
			var q: Vector2 = at.call(pts[i - 1])
			var f := ((k * area.size.x + area.position.x) - q.x) / maxf(0.001, p.x - q.x)
			line.append(q.lerp(p, clampf(f, 0, 1)))
			break
		line.append(p)
	if line.size() >= 2:
		var fill := PackedVector2Array(line)
		fill.append(Vector2(line[-1].x, area.end.y))
		fill.append(Vector2(line[0].x, area.end.y))
		ui.polygon(fill, Color(col.accent, 0.1 * a))
		ui.polyline(line, Color(col.accent, a), 3)
	# Un punto en cada rango ya dibujado
	for i in range(1, pts.size()):
		var p: Vector2 = at.call(pts[i])
		if (p.x - area.position.x) / area.size.x > k + 0.001:
			continue
		var last := i == pts.size() - 1
		ui.circle(p, 7 if last else 5, Color(col.green if last else col.accent, a))
		ui.circle(p, 3 if last else 2, Color(col.bg, a))
		var label: String = Lang.t(pts[i][2]) if pts[i][2] != "" else Lang.t("Hoy")
		var above := i % 2 == 1
		ui.text(label, p + Vector2(0, -12 if above else 12), 11, Color(col.text, a), true, "midbottom" if above else "midtop")
	if line.size() >= 1 and k < 1.0:   # la punta que avanza
		ui.circle(line[-1], 5, Color(col.accent, a))


## Al terminar la tarjeta: al menú principal (o de vuelta al juego si lo estabas volviendo a ver).
func _end() -> void:
	_finish(not replay)


## El menú aparece desde el negro (lo llama Hud aunque ya no haya partida).
func draw_menu_in(ui: ImUI) -> void:
	if menu_in_at < 0:
		return
	var k := (Time.get_ticks_msec() - menu_in_at) / 1000.0 / MENU_IN
	if k >= 1.0:
		menu_in_at = -1
		return
	ui.rect(Rect2(-3000, -3000, ui.W + 6000, ui.H + 6000), Color(0, 0, 0, 1.0 - _ease(k)))


## Termina el final: sigues en la presidencia, o vuelves al menú principal (la partida se guarda igual).
func _finish(to_menu: bool) -> void:
	var g: Game = city.game
	g.finale_seen = true
	phase = ""
	fade = 0.0
	city.tower.end_finale()
	city.tower.set_lobby_doors(0.0)
	city.app.in_finale = false
	city.sfx.stop_special()
	city.player.visible = true
	city.player.position = city.tower.w(Tower.ARRIVE)
	city.player.rotation.y = 0.0
	city.yaw = 0.0
	city.pitch = 14.0
	city.app.save(true)
	if to_menu:
		city.app.game = null
		city.app.view = "menu"
		city.app.modal = null
		menu_in_at = Time.get_ticks_msec()
		return
	city.app.paused = was_paused
	city.capture_mouse()


## Esc durante el final.
func key(e: InputEventKey) -> void:
	if e.keycode == KEY_ESCAPE and phase != "card":
		skip()
