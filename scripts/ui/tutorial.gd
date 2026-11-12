class_name Tutorial
extends RefCounted
## Tutorial guiado: después de la bienvenida, el mentor (tu personaje ya millonario) te acompaña paso a paso
## (caminar, ir a un terreno y comprar tu primer puesto, abrir la tablet, poner el mejor precio, contratar, acelerar
## el tiempo, salir de la tablet, ir a la oficina y, al final, cómo se gana). El mentor no desaparece en todo el
## tutorial: su última frase de cada paso es lo que tienes que hacer. Una flecha muestra dónde: en la ciudad (con un
## haz de luz y una línea en el suelo desde tu personaje), sobre el botón de la pantalla o en el borde si queda fuera
## de la vista. Al final, una tarjeta corta con tres consejos (Overlays.TUTORIAL_END).

const STEPS := ["caminar", "terreno", "comprar", "tablet", "precio", "contratar", "tiempo", "salir", "oficina", "valor"]
const TABLET_STEPS := ["precio", "contratar"]   # se hacen con la tablet abierta

var city
var active := false
var step := 0
var step_t := 0.0          # segundos en el paso actual
var start_pos := Vector3.ZERO
var start_price := 0.0
var start_staff := 0
var start_speed := 0
var understood := false    # "Entendido" en la tarjeta de cómo se gana
var marker: Node3D
var path: MeshInstance3D   # la línea amarilla en el suelo, desde tu personaje hasta donde tienes que ir
var path_mesh: ImmediateMesh
# El mentor: tu personaje ya millonario, que explica cada paso
var talk: Array = []       # lo que dice en este paso (una frase por globo; la última queda en pantalla)
var talk_i := 0            # la frase que está diciendo (= talk.size(): ya terminó y queda la última)
var talk_t := 0.0          # segundos desde que empezó la frase (las letras salen de a poco)
var talk_in := 0.0         # 0 a 1: el mentor entrando desde abajo
var eat_click := false     # el clic que pasó la frase no debe apretar nada más
var held := false          # el juego está en pausa porque el mentor está explicando
var held_prev := false     # si estaba en pausa antes de que empezara a hablar

const MENTOR_NAME := "TÚ, YA MILLONARIO"
const TYPE_SPEED := 48.0   # letras por segundo


func _init(owner_city) -> void:
	city = owner_city


func start(from := 0) -> void:
	active = true
	step = clampi(from, 0, STEPS.size() - 1)
	understood = false
	if marker == null:
		marker = _make_marker()
		city.add_child(marker)
	if path == null:
		path = _make_path()
		city.add_child(path)
	marker.visible = false
	path.visible = false
	city.hud.notes.clear()   # durante el tutorial no hay avisos (ver City.react)
	_begin_step(true)


## Empieza el paso `step`: guarda cómo estaba todo (para saber cuándo lo hiciste) y el mentor lo explica.
func _begin_step(first := false) -> void:
	city.game.tutorial_step = step
	step_t = 0.0
	start_pos = city.player.position
	start_price = city.game.products[_prod_key()].price
	start_staff = _staff()
	start_speed = city.app.speed
	_say(lines(STEPS[step]), first)


## Flecha grande que apunta hacia abajo, con un haz de luz vertical (se ve a través de las paredes y desde lejos).
func _make_marker() -> Node3D:
	var root := Node3D.new()
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.albedo_color = Color8(255, 200, 50)
	mat.no_depth_test = true
	mat.render_priority = 10
	var head := Node3D.new()
	head.name = "Head"
	root.add_child(head)
	var tip := PrismMesh.new()
	tip.size = Vector3(1.2, 1.0, 0.35)
	var tip_node := MeshInstance3D.new()
	tip_node.mesh = tip
	tip_node.rotation.z = PI   # punta hacia abajo
	tip_node.material_override = mat
	head.add_child(tip_node)
	var shaft := BoxMesh.new()
	shaft.size = Vector3(0.45, 0.9, 0.3)
	var shaft_node := MeshInstance3D.new()
	shaft_node.mesh = shaft
	shaft_node.position.y = 0.95
	shaft_node.material_override = mat
	head.add_child(shaft_node)
	var beam_mat := StandardMaterial3D.new()
	beam_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	beam_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	beam_mat.albedo_color = Color(1.0, 0.8, 0.2, 0.22)
	beam_mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	var cyl := CylinderMesh.new()
	cyl.top_radius = 0.25
	cyl.bottom_radius = 0.6
	cyl.height = 40.0
	var beam := MeshInstance3D.new()
	beam.mesh = cyl
	beam.position.y = 20.0
	beam.material_override = beam_mat
	root.add_child(beam)
	for n in [tip_node, shaft_node, beam]:
		n.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	return root


## La línea del suelo: flechitas amarillas que avanzan desde tu personaje hasta el lugar (se rearma cada cuadro).
func _make_path() -> MeshInstance3D:
	path_mesh = ImmediateMesh.new()
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.albedo_color = Color(1.0, 0.8, 0.2, 0.85)
	mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	mat.no_depth_test = true   # se ve aunque pase detrás de una pared
	mat.render_priority = 9
	var n := MeshInstance3D.new()
	n.mesh = path_mesh
	n.material_override = mat
	n.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	n.top_level = true
	return n


func stop() -> void:
	_release()
	active = false
	talk = []
	if marker:
		marker.visible = false
	if path:
		path.visible = false


## El producto de tu primer negocio (el tutorial sugiere café, pero puedes elegir otro).
func _prod_key() -> String:
	if city.game != null and not city.game.locations.is_empty():
		return city.game.locations[0].product
	return "cafe"


## Lo que dice el mentor en cada paso. La última frase es lo que tienes que hacer y queda en pantalla.
func lines(id: String) -> Array:
	var k := func(a: String) -> String: return Keys.label(a)
	match id:
		"caminar":
			return ["¡Hola, socio! Soy tú... pero dentro de unos años. Ya soy millonario.",
					"Vine a enseñarte cómo lo logré. Primero lo básico: camina un poco."]
		"terreno":
			return ["¡Eso! Todo imperio empieza con un negocio pequeño.",
					Lang.f("A la derecha te dejo todos los controles. Con %s los vuelves a ver cuando quieras.", k.call("help")),
					Lang.f("Sigue la flecha amarilla hasta un letrero SE VENDE y aprieta %s.", k.call("interact"))]
		"comprar":
			return ["Aquí empecé yo. Abre un puesto de café: es barato y se vende solo."]
		"tablet":
			return ["¡Tu primer negocio! Felicidades.", Lang.f("Todo se maneja desde la tablet. Ábrela con %s.", k.call("phone"))]
		"precio":
			var best: float = city.game.price_curve(_prod_key())[1][0]
			return ["El precio lo es todo. Muy caro, nadie compra. Muy barato, no ganas nada.",
					Lang.f("Tu mejor precio ahora es %s. En Mercado, aprieta «Usar precio óptimo».", Fmt.money(best, 2))]
		"contratar":
			return ["Solo no puedes con todo. En tu puesto, aprieta + para contratar a alguien."]
		"tiempo":
			return [Lang.f("Los negocios crecen con el tiempo. Acelera el reloj a x2 o x3 (o con %s y %s).", [k.call("speed2"), k.call("speed3")])]
		"salir":
			return [Lang.f("Para salir de la tablet, aprieta Esc o %s.", k.call("phone"))]
		"oficina":
			return ["Ahora, tu oficina. Ahí están tu computadora y tu armario.", Lang.f("Aprieta %s para ir.", k.call("office"))]
		"valor":
			return ["Lo último y más importante: cómo se gana."]
	return []


## Empieza a decir `what`. `first`: el mentor recién aparece (entra desde abajo).
func _say(what: Array, first := false) -> void:
	talk = what
	talk_i = 0
	talk_t = 0.0
	if first:
		talk_in = 0.0


## Todavía le quedan frases por decir.
func talking() -> bool:
	return active and talk_i < talk.size()


## Habla en la ciudad: te quedas quieto escuchando y Enter, Espacio o un clic pasan la frase. Con la tablet (o una
## ventana) abierta no: las frases pasan solas y puedes seguir haciendo cosas.
func blocking() -> bool:
	return talking() and not city.overlays.open()


func _line_len() -> int:
	return Lang.t(talk[talk_i]).length()


## Enter, Espacio o clic: si la frase todavía se está escribiendo la muestra entera; si no, pasa a la siguiente.
func advance() -> void:
	if not talking():
		return
	eat_click = true
	if talk_t * TYPE_SPEED < _line_len():
		talk_t = _line_len() / TYPE_SPEED + 0.01
		return
	_next_line()


## Apretaste una tecla del juego mientras hablaba: deja de hablar (queda escrita su última frase) y lo haces tú.
func skip_talk() -> void:
	if not talking():
		return
	talk_i = talk.size()
	talk_t = 0.0
	_talk_done()


func _next_line() -> void:
	talk_i += 1
	talk_t = 0.0
	city.sfx.play("select", 0.4)
	if talk_i >= talk.size():
		_talk_done()


## Terminó de hablar: ahora lo haces tú (lo que hiciste en la ciudad mientras hablaba no cuenta).
func _talk_done() -> void:
	_release()   # ahora lo haces tú: la partida sigue
	start_pos = city.player.position
	if STEPS[step] == "valor":
		city.overlays.show_value_card()


## Tu personaje, pero millonario: blazer oscuro, camisa blanca, corbata y reloj de oro.
func mentor_look() -> Dictionary:
	var look: Dictionary = Wardrobe.DEFAULT_LOOK.duplicate()
	if city.game != null and city.game.look is Dictionary:
		look.merge(city.game.look, true)
	look.merge({"jacket": "blazer", "jacket_color": [28, 30, 38], "shirt": [245, 245, 245], "tie": true, "watch": true,
			"headphones": false, "backpack": false}, true)
	return look


## ¿Queda algún negocio donde se pueda contratar? (si todos están llenos, el paso de contratar se da por hecho)
func _can_hire() -> bool:
	for l in city.game.locations:
		if int(l.employees) < int(D.SIZES[l.size].max_emp) and not city.game.products[l.product].manager:
			return true
	return false


func _staff() -> int:
	var n := 0
	for l in city.game.locations:
		n += int(l.employees)
	return n


## A dónde apunta la flecha de la ciudad en este paso (o null si no hay un lugar).
func target():
	var p: Vector3 = city.player.position
	match STEPS[step]:
		"oficina":
			return city.hq_spots.computer
		"terreno", "comprar":
			if not city.game.locations.is_empty():
				return null
			var best = null
			for l in city.lots.values():
				var m: Vector3 = l.manage
				if best == null or m.distance_to(p) < best.distance_to(p):
					best = m
			return best
	return null


func _done(id: String) -> bool:
	var p: Vector3 = city.player.position
	match id:
		"caminar":
			return Vector2(p.x - start_pos.x, p.z - start_pos.z).length() > 4.0
		"comprar":
			return not city.game.locations.is_empty()
		"tablet":
			return city.overlays.mode == "admin" and city.app.view == "game"
		"valor":
			return understood
		"precio":
			return absf(city.game.products[_prod_key()].price - start_price) > 0.001
		"contratar":
			return _staff() > start_staff or not _can_hire()
		"tiempo":   # basta con cambiar la velocidad (en la tablet o con las teclas)
			return city.app.speed != start_speed
		"salir":
			return city.overlays.mode != "admin"
		"oficina":
			var c: Vector3 = city.hq_spots.computer
			return Vector2(p.x - c.x, p.z - c.z).length() < 4.0
		"terreno":
			return city.overlays.mode == "lote" or city.lots.is_empty() or not city.game.locations.is_empty()
	return true


## Mientras el mentor explica, todo queda en pausa (se vuelve a poner cada cuadro por si apretaste la velocidad).
func _hold() -> void:
	if not held:
		held = true
		held_prev = city.app.paused
	city.app.paused = true


## Termina la pausa del mentor y deja la partida como estaba antes de que hablara.
func _release() -> void:
	if held:
		held = false
		city.app.paused = held_prev


func update(dt: float) -> void:
	if not active or city.game == null:
		return
	if talking():
		_hold()
	step_t += dt
	talk_t += dt
	talk_in = minf(1.0, talk_in + dt * 3.5)
	# Con una ventana abierta las frases pasan solas (después de un rato para leerlas)
	if talking() and not blocking() and talk_t > _line_len() / TYPE_SPEED + 1.6 + _line_len() / 40.0:
		_next_line()
	# Caminar cuenta recién cuando termina de hablar (mientras habla te quedas quieto); lo demás cuenta siempre
	if (not blocking() or STEPS[step] != "caminar") and step_t > 0.6 and _done(STEPS[step]):
		city.sfx.play("good", 0.7)
		if step + 1 >= STEPS.size():
			finish()
			return
		step += 1
		if STEPS[step] == "salir" and city.overlays.mode != "admin":
			step += 1   # ya saliste de la tablet: no hace falta explicarlo
		_begin_step()
	var t = target()
	marker.visible = t != null and not city.overlays.open()
	_update_path(t)
	if t != null:
		var time := Time.get_ticks_msec() / 1000.0
		marker.global_position = t
		var head: Node3D = marker.get_node("Head")
		head.position.y = 3.0 + absf(sin(time * 3.5)) * 0.6   # rebota
		head.rotation.y += dt * 2.5
		var s := 1.0 + 0.15 * sin(time * 7.0)
		head.scale = Vector3(s, s, s)


## Flechitas en el suelo desde tu personaje hasta `t`, que avanzan hacia allá.
func _update_path(t) -> void:
	path_mesh.clear_surfaces()
	path.visible = false
	if t == null or city.overlays.open():
		return
	var a: Vector3 = city.player.position
	var b: Vector3 = t
	var flat := Vector3(b.x - a.x, 0, b.z - a.z)
	var length := flat.length()
	if length < 3.0:
		return
	var dir := flat / length
	var side := Vector3(-dir.z, 0, dir.x)
	var gap := 2.2
	var off := fmod(Time.get_ticks_msec() / 1000.0 * 3.0, gap)
	var at := func(d: float) -> Vector3:
		var q := a + dir * d
		q.y = maxf(Terrain.height(q.x, q.z), lerpf(a.y, b.y, d / length)) + 0.12
		return q
	var started := false
	var d := 1.2 + off
	while d < length - 1.5:
		# Una flechita: cuerpo angosto y punta ancha, apuntando al destino
		var c0: Vector3 = at.call(d)
		var c1: Vector3 = at.call(d + 0.7)
		var c2: Vector3 = at.call(d + 1.2)
		if not started:
			path_mesh.surface_begin(Mesh.PRIMITIVE_TRIANGLES)
			started = true
		var w := side * 0.16
		var wt := side * 0.42
		for v in [c0 - w, c0 + w, c1 + w, c0 - w, c1 + w, c1 - w, c1 - wt, c1 + wt, c2]:
			path_mesh.surface_add_vertex(v)
		d += gap
	if started:
		path_mesh.surface_end()
		path.visible = true


func finish() -> void:
	stop()
	city.game.tutorial_step = -1
	city.settings.tutorial_seen = true
	city.save_settings()
	city.app.save(true)   # que no se repita al cargar la partida
	city.sfx.play("fanfare", 0.8)
	city.overlays.show_win_guide()


func skip() -> void:
	stop()
	if city.game != null:
		city.game.tutorial_step = -1
	city.settings.tutorial_seen = true
	city.save_settings()


# ---------- dibujo ----------
## Flecha grande que rebota sobre un botón de la pantalla (o debajo, si el botón está arriba de todo) y un borde que
## titila alrededor, para que se note mucho qué hay que apretar.
static func big_arrow(ui: ImUI, r: Rect2) -> void:
	if r.size.x <= 0:
		return
	var t := Time.get_ticks_msec() / 1000.0
	var glow := 0.5 + 0.5 * sin(t * 6.0)
	ui.rect(r.grow(6 + 3 * glow), Color(1.0, 0.78, 0.2, 0.25 + 0.35 * glow), 10, 3)
	var up := r.position.y < 56   # el botón está arriba de todo: la flecha queda abajo y apunta hacia arriba
	var bounce := absf(sin(t * 4.0)) * 14.0
	var d := -1.0 if up else 1.0   # 1 = apunta hacia abajo
	var tip := Vector2(r.get_center().x, r.end.y + 12 + bounce) if up else Vector2(r.get_center().x, r.position.y - 12 - bounce)
	var base_y := tip.y - d * 30   # donde termina la punta y empieza el palo
	for pass_ in 2:   # contorno oscuro y la flecha amarilla encima
		var g := 4.0 if pass_ == 0 else 0.0
		var c: Color = Color(0.05, 0.05, 0.07, 0.9) if pass_ == 0 else Color8(255, 200, 50)
		ui.polygon(PackedVector2Array([tip + Vector2(0, d * g), Vector2(tip.x - 26 - g, base_y - d * g),
				Vector2(tip.x + 26 + g, base_y - d * g)]), c)
		var y0 := minf(base_y, base_y - d * 32)
		ui.rect(Rect2(tip.x - 10 - g, y0 - g, 20 + g * 2, 32 + g * 2), c)


## Cuando hay una flecha: oscurece todo menos lo que señala (que además brilla un poco).
static func spotlight(ui: ImUI, hole: Rect2, dim := 0.62) -> void:
	var far := 4000.0
	var c := Color(0.01, 0.012, 0.02, dim)
	ui.rect(Rect2(-far, -far, far * 2 + ui.W, hole.position.y + far), c)                        # arriba
	ui.rect(Rect2(-far, hole.end.y, far * 2 + ui.W, far + ui.H - hole.end.y), c)                # abajo
	ui.rect(Rect2(-far, hole.position.y, hole.position.x + far, hole.size.y), c)                # izquierda
	ui.rect(Rect2(hole.end.x, hole.position.y, far + ui.W - hole.end.x, hole.size.y), c)        # derecha
	ui.rect(hole, Color(1, 1, 1, 0.07), 8)


## En la ciudad: la flecha sobre el botón de la tablet o de la velocidad, las teclas para caminar, el mentor y la
## flecha en el borde de la pantalla si el lugar queda fuera de la vista.
func draw(ui: ImUI) -> void:
	if not active or city.overlays.open():
		return   # con la tablet abierta se dibuja en draw_phone y el mentor encima (Overlays.draw)
	var id: String = STEPS[step]
	if not talking():
		var goal = null   # el botón del HUD que señala la flecha
		if id == "tablet" or id in TABLET_STEPS:
			goal = city.hud.phone_rect
		elif id == "tiempo":
			goal = city.hud.speed_rect
		if goal != null and goal.size.x > 0:
			spotlight(ui, goal.grow(8))
			big_arrow(ui, goal)
		if id == "valor" and not understood:
			city.overlays.show_value_card()   # se cerró sin leerla: vuelve a salir
	if id == "caminar":
		draw_keys(ui)
	draw_mentor(ui)
	_edge_arrow(ui)


## Con la tablet abierta: todo se oscurece menos lo que hay que tocar y una flecha grande lo señala (la pestaña, el
## precio óptimo, el puesto y su +, la velocidad). Lo que hay que hacer lo dice el mentor. En coordenadas de la tablet.
func draw_phone(ui: ImUI) -> void:
	if not active or city.app.modal != null:
		return
	var m: Dictionary = city.app.marks
	var app = city.app
	var goal = null
	var hole = null   # lo que queda iluminado (si no, el mismo botón)
	match STEPS[step]:
		"precio":
			goal = m.get("precio_optimo") if app.tab == "mercado" else m.get("tab_mercado")
		"contratar":
			if app.tab == "negocios":
				goal = m.get("contratar")
				hole = m.get("puesto1")
			else:
				goal = m.get("tab_negocios")
		"tiempo":
			goal = m.get("velocidad")
	if goal == null:
		return
	spotlight(ui, (hole if hole != null else goal).grow(8))
	big_arrow(ui, goal)


## Las teclas para moverte, ubicadas como en el teclado (W A S D, Shift y Espacio resaltadas) y el mouse. Se iluminan
## más cuando las aprietas.
func draw_keys(ui: ImUI) -> void:
	var u := 50.0   # una tecla
	var gap := 6.0
	var rows := [
		# [columna, fila, ancho, acción o letra fija]
		[0, 0, 1.5, "·Tab"], [1.5, 0, 1, "·Q"], [2.5, 0, 1, "forward"], [3.5, 0, 1, "·E"], [4.5, 0, 1, "·R"],
		[0, 1, 1.75, "·Bloq"], [1.75, 1, 1, "left"], [2.75, 1, 1, "back"], [3.75, 1, 1, "right"], [4.75, 1, 1, "·F"],
		[0, 2, 2.25, "run"], [2.25, 2, 1, "·Z"], [3.25, 2, 1, "·X"], [4.25, 2, 1, "·C"],
		[0, 3, 1.25, "·Ctrl"], [1.25, 3, 1.25, "·Alt"], [2.5, 3, 4.5, "jump"],
	]
	var kw := 7.0 * u
	var mouse_w := 70.0
	var total := Vector2(kw + 40 + mouse_w, 4 * u + 3 * gap + 26)
	var e := 1.0 - pow(1.0 - talk_in, 3)
	var o := Vector2(ui.W / 2 - total.x / 2 + 40, ui.H - 190 - total.y - 30 + (1.0 - e) * 300)
	var panel := Rect2(o - Vector2(22, 40), total + Vector2(44, 52))
	ui.rect(panel, Color(0.04, 0.05, 0.075, 0.82), 16)
	var t := Time.get_ticks_msec() / 1000.0
	var glow := 0.5 + 0.5 * sin(t * 5.0)
	var labels := {"forward": "", "run": "Correr", "jump": "Saltar"}
	for k in rows:
		var r := Rect2(o.x + k[0] * u, o.y + k[1] * (u + gap), k[2] * u - gap, u)
		var act: String = k[3]
		if act.begins_with("·"):   # tecla de adorno: apagada
			ui.rect(r, Color(1, 1, 1, 0.05), 7)
			ui.rect(r, Color(1, 1, 1, 0.1), 7, 1)
			ui.text(act.substr(1), r.get_center(), 13, Color(1, 1, 1, 0.22), false, "center")
			continue
		var down: bool = Keys.pressed(act)
		ui.rect(r.grow(3 + 2 * glow), Color(1.0, 0.78, 0.2, 0.2 + 0.25 * glow), 9)
		ui.rect(r, Color8(255, 214, 90) if down else Color8(255, 196, 50), 7)
		ui.rect(Rect2(r.position.x, r.end.y - 6, r.size.x, 6), Color(0, 0, 0, 0.18 if not down else 0.0), 7)
		var what: String = labels.get(act, "")
		ui.text(Keys.label(act), r.get_center() + Vector2(0, -9 if what != "" else -2), 18 if r.size.x < u * 1.5 else 15, Color8(20, 22, 30), true, "center")
		if what != "":   # para qué sirve, chiquito dentro de la tecla
			ui.text(what, r.get_center() + Vector2(0, 11), 11, Color8(70, 52, 10), true, "center")
	ui.text("Caminar", Vector2(o.x + 3.0 * u, o.y - 20), 13, "accent", true, "center")
	# El mouse: para mirar alrededor
	var mr := Rect2(o.x + kw + 40, o.y + 20, mouse_w, 104)
	ui.rect(mr.grow(3 + 2 * glow), Color(1.0, 0.78, 0.2, 0.2 + 0.25 * glow), 36)
	ui.rect(mr, Color8(255, 196, 50), 34)
	ui.line(Vector2(mr.get_center().x, mr.position.y + 4), Vector2(mr.get_center().x, mr.position.y + 44), Color8(20, 22, 30), 2)
	ui.line(Vector2(mr.position.x + 6, mr.position.y + 44), Vector2(mr.end.x - 6, mr.position.y + 44), Color8(20, 22, 30), 2)
	ui.rect(Rect2(mr.get_center().x - 4, mr.position.y + 14, 8, 18), Color8(20, 22, 30), 4)
	ui.text("Mirar", Vector2(mr.get_center().x, mr.end.y + 8), 12, "accent", true, "midtop")


## El mentor: de la cintura para arriba a la izquierda, saliendo por encima de un cuadro de diálogo abajo al centro.
## Mientras habla, las letras salen de a poco; cuando termina, su última frase (lo que hay que hacer) queda escrita.
func draw_mentor(ui: ImUI) -> void:
	if not active or talk.is_empty():
		return
	var speaking := talking()
	var line_i := talk_i if speaking else talk.size() - 1
	var e := 1.0 - pow(1.0 - talk_in, 3)
	var w := 780.0
	var h := 128.0
	var pw := 200.0    # el retrato
	var sep := 18.0    # aire entre el retrato y el cuadro
	var box := Rect2(ui.W / 2 - (pw + sep + w) / 2 + pw + sep, ui.H - h - 22 + (1.0 - e) * 220, w, h)
	# El retrato: la foto de tu personaje millonario (Thumbs, encuadre "busto"), más alto que el cuadro
	var pr := Rect2(box.position.x - sep - pw, box.end.y - pw, pw, pw)
	ui.rect(pr, Color(ImUI.COL.accent, 0.95), 16)
	ui.rect(pr.grow(-4), Color(0.17, 0.2, 0.26), 12)
	var img = city.thumbs.get_thumb(mentor_look(), "busto")
	if img != null:
		ui.image(img, pr.grow(-4))
	ui.rect(box, Color(0.04, 0.05, 0.075, 0.96), 16)
	ui.rect(box, Color(ImUI.COL.accent, 0.9), 16, 2)
	# Nombre en una pestaña sobre el cuadro
	var nw := ui.text_size(MENTOR_NAME, 13, true).x + 28
	var tab := Rect2(box.position.x + 30, box.position.y - 15, nw, 28)
	ui.rect(tab, ImUI.COL.accent, 14)
	ui.text(MENTOR_NAME, tab.get_center(), 13, Color8(16, 20, 30), true, "center")
	# La frase, escribiéndose (o entera, si ya terminó de hablar)
	var full: String = Lang.t(talk[line_i])
	var n := mini(full.length(), int(talk_t * TYPE_SPEED)) if speaking else full.length()
	ui.wrap_text(full.substr(0, n), Rect2(box.position.x + 30, box.position.y + 26, w - 60, h - 50), 20, Color.WHITE)
	if not speaking or not blocking():
		return
	# En la ciudad: cómo seguir (titila cuando la frase ya terminó) y cuántas frases quedan
	var blink := 0.55 + 0.45 * sin(Time.get_ticks_msec() / 180.0) if n >= full.length() else 0.35
	ui.text(Lang.t("Enter / clic") + "  ▸", Vector2(box.end.x - 22, box.end.y - 18), 13, Color(ImUI.COL.accent, blink), true, "midright")
	for i in talk.size():
		var c: Color = ImUI.COL.accent if i == talk_i else Color(1, 1, 1, 0.25 if i > talk_i else 0.5)
		ui.circle(Vector2(box.position.x + 36 + i * 14, box.end.y - 18), 4, c)


## Si el lugar al que hay que ir queda fuera de la pantalla, una flecha grande en el borde apunta hacia él.
func _edge_arrow(ui: ImUI) -> void:
	var t = target()
	if t == null:
		return
	var cam: Camera3D = city.camera
	var p: Vector3 = t + Vector3(0, 1.5, 0)
	var behind := cam.is_position_behind(p)
	var sp := ui.to_virtual(cam.unproject_position(p))
	var on_screen := not behind and sp.x > 40 and sp.x < ui.W - 40 and sp.y > 40 and sp.y < ui.H - 40
	var dist: float = Vector2(t.x - city.player.position.x, t.z - city.player.position.z).length()
	if on_screen:
		return
	var center := Vector2(ui.W / 2, ui.H / 2)
	var dir := (sp - center)
	if behind:
		dir = -dir
	if dir.length() < 1.0:
		dir = Vector2(0, 1)
	dir = dir.normalized()
	var half := Vector2(ui.W / 2 - 70, ui.H / 2 - 70)
	var s: float = min(half.x / max(absf(dir.x), 0.001), half.y / max(absf(dir.y), 0.001))
	var at := center + dir * s
	var n := Vector2(-dir.y, dir.x)
	var pulse := 1.0 + 0.12 * sin(Time.get_ticks_msec() / 120.0)
	ui.circle(at, 36 * pulse, Color(0.05, 0.065, 0.09, 0.9))
	ui.ring(at, 36 * pulse, ImUI.COL.accent, 3)
	ui.polygon(PackedVector2Array([at + dir * 26, at - dir * 14 + n * 18, at - dir * 14 - n * 18]), ImUI.COL.accent)
	ui.text(Lang.f("%d m", roundi(dist)), at - dir * 58, 15, "accent", true, "center")
