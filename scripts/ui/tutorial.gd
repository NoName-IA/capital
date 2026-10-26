class_name Tutorial
extends RefCounted
## Tutorial guiado: después de la bienvenida, una lista de pasos que se hacen jugando (caminar, atender tu puesto,
## abrir la tablet, mirar cuánto vale tu empresa, poner el mejor precio, contratar...). Cada paso explica cómo hacerlo
## y para qué sirve para ganar, y se marca solo cuando lo haces. Una flecha grande muestra qué hacer: en la ciudad
## (con un haz de luz, visible a través de las paredes), sobre el botón de la pantalla o en el borde si queda fuera de
## la vista. Al final, una tarjeta con las claves para ganar (Overlays.TUTORIAL_END).

const STEPS := ["caminar", "saltar", "puesto", "atender", "tablet", "valor", "precio", "contratar", "tiempo", "oficina",
		"terreno"]
const TABLET_STEPS := ["precio", "contratar"]   # se hacen con la tablet abierta

var city
var active := false
var step := 0
var step_t := 0.0          # segundos en el paso actual (para la animación al pasar de un paso a otro)
var start_pos := Vector3.ZERO
var start_price := 0.0
var start_staff := 0
var understood := false    # "Entendido" en los pasos que solo hay que leer
var marker: Node3D


func _init(owner_city) -> void:
	city = owner_city


func start() -> void:
	active = true
	step = 0
	step_t = 0.0
	understood = false
	start_pos = city.player.position
	start_price = city.game.products.cafe.price
	start_staff = _staff()
	if marker == null:
		marker = _make_marker()
		city.add_child(marker)
	marker.visible = false


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


func stop() -> void:
	active = false
	if marker:
		marker.visible = false


## [título, cómo hacerlo, para qué sirve] de cada paso.
func text(id: String) -> Array:
	var k := func(a: String) -> String: return Keys.label(a)
	match id:
		"caminar":
			return ["Camina por la ciudad", "Muévete con %s %s %s %s y mira con el mouse. Mantén %s para correr." % [
					k.call("forward"), k.call("left"), k.call("back"), k.call("right"), k.call("run")],
					"Esta ciudad es tuya para conquistar: tus tiendas, tu oficina y los terrenos que vas a comprar."]
		"saltar":
			return ["¡Salta!", "Aprieta %s. Puedes subirte a bancas, jardineras y a los cercos del parque." % k.call("jump"), ""]
		"puesto":
			return ["Ve a tu puesto de café", "Sigue la flecha amarilla. Ahí empieza tu imperio.",
					"Empiezas con un puestito de café y $1.500. De aquí sale todo lo demás."]
		"atender":
			return ["Atiende a tus clientes", "Ponte detrás del mostrador y aprieta %s." % k.call("interact"),
					"Si atiendes tú, es como tener un ayudante gratis: atiendes a más gente y ganas más."]
		"tablet":
			return ["Abre tu tablet", "Aprieta %s o haz clic en el botón Tablet." % k.call("phone"),
					"Desde la tablet controlas todo: precios, empleados, mercadería y préstamos."]
		"valor":
			return ["Así se gana", "Lee la tarjeta y aprieta Entendido.",
					"Haz que tu empresa valga %s y ganas. Mientras más ganes cada mes, más vale." % Fmt.short(D.WIN_VALUE)]
		"precio":
			return ["Ponle precio al café", "Entra a Mercado y toca «Usar precio óptimo». También puedes subirlo o bajarlo tú.",
					"Muy barato: vendes mucho pero no ganas nada. Muy caro: nadie compra. El precio óptimo te deja más plata."]
		"contratar":
			return ["Contrata a alguien", "Entra a Negocios y toca el + de tu puesto.",
					"Si llega más gente de la que puedes atender, se van sin comprar. Con más empleados no se te escapa nadie."]
		"tiempo":
			return ["Haz correr el tiempo", "Cierra la tablet y aprieta %s o %s para adelantar el tiempo. %s vuelve a la normalidad y %s pausa." % [
					k.call("speed2"), k.call("speed3"), k.call("speed1"), k.call("pause_quick")],
					"Cada día vendes y pagas tus gastos. Mira cómo crece tu plata arriba a la izquierda."]
		"oficina":
			return ["Visita tu oficina", "Aprieta %s para ir directo o camina hasta la torre." % k.call("office"),
					"Ahí eliges la jugada del mes, inviertes en la bolsa y guardas tus trofeos."]
		"terreno":
			return ["Busca dónde abrir otra tienda", "Acércate a un letrero SE VENDE y aprieta %s." % k.call("interact"),
					"Cada tienda nueva te trae más plata y hace que tu empresa valga más."]
	return ["", "", ""]


func _stall() -> Store:
	for s in city.stores.values():
		if s.loc.size == 0:
			return s
	return null if city.stores.is_empty() else city.stores.values()[0]


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
		"puesto", "atender":
			var s := _stall()
			return s.spots.serve if s else null
		"oficina":
			return city.hq_spots.computer
		"terreno":
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
		"saltar":
			return p.y > city.floor_at(p.x, p.z, p.y) + 0.5
		"puesto":
			var t = target()
			return t == null or Vector2(p.x - t.x, p.z - t.z).length() < 3.0
		"atender":
			return city.serving != null or _stall() == null
		"tablet":
			return city.overlays.mode == "admin" and city.app.view == "game"
		"valor":
			return understood
		"precio":
			return absf(city.game.products.cafe.price - start_price) > 0.001
		"contratar":
			return _staff() > start_staff or not _can_hire()
		"tiempo":
			return city.app.speed > 0 and not city.app.paused and not city.overlays.open()
		"oficina":
			var c: Vector3 = city.hq_spots.computer
			return Vector2(p.x - c.x, p.z - c.z).length() < 4.0
		"terreno":
			return city.overlays.mode == "lote" or city.lots.is_empty()
	return true


func update(dt: float) -> void:
	if not active or city.game == null:
		return
	step_t += dt
	if step_t > 0.6 and _done(STEPS[step]):
		city.sfx.play("good", 0.7)
		step += 1
		step_t = 0.0
		understood = false
		start_price = city.game.products.cafe.price
		start_staff = _staff()
		if step >= STEPS.size():
			finish()
			return
		if STEPS[step] == "valor":
			city.overlays.show_value_card()
	var t = target()
	marker.visible = t != null and not city.overlays.open()
	if t != null:
		var time := Time.get_ticks_msec() / 1000.0
		marker.global_position = t
		var head: Node3D = marker.get_node("Head")
		head.position.y = 3.0 + absf(sin(time * 3.5)) * 0.6   # rebota
		head.rotation.y += dt * 2.5
		var s := 1.0 + 0.15 * sin(time * 7.0)
		head.scale = Vector3(s, s, s)


func finish() -> void:
	stop()
	city.settings.tutorial_seen = true
	city.save_settings()
	city.sfx.play("fanfare", 0.8)
	city.overlays.show_win_guide()


func skip() -> void:
	stop()
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


## Cuando hay una flecha: oscurece todo menos el botón que señala (que además brilla un poco). Lo que se dibuje
## después (el texto del tutorial y la flecha) queda encima, con su brillo normal.
static func spotlight(ui: ImUI, hole: Rect2, dim := 0.62) -> void:
	var far := 4000.0
	var c := Color(0.01, 0.012, 0.02, dim)
	ui.rect(Rect2(-far, -far, far * 2 + ui.W, hole.position.y + far), c)                        # arriba
	ui.rect(Rect2(-far, hole.end.y, far * 2 + ui.W, far + ui.H - hole.end.y), c)                # abajo
	ui.rect(Rect2(-far, hole.position.y, hole.position.x + far, hole.size.y), c)                # izquierda
	ui.rect(Rect2(hole.end.x, hole.position.y, far + ui.W - hole.end.x, hole.size.y), c)        # derecha
	ui.rect(hole, Color(1, 1, 1, 0.07), 8)


## Panel de los pasos (a la izquierda, debajo de la tarjeta de la empresa), la flecha sobre el botón de la tablet o de
## la velocidad, y la flecha en el borde de la pantalla si el lugar queda fuera de la vista.
func draw(ui: ImUI) -> void:
	if not active or city.overlays.open():
		return   # con la tablet abierta el paso se ve debajo de la tablet (ver draw_phone)
	var id: String = STEPS[step]
	var tx := text(id)
	var goal = null   # el botón del HUD que señala la flecha
	if id == "tablet" or id in TABLET_STEPS:
		goal = city.hud.phone_rect
	elif id == "tiempo":
		goal = city.hud.speed_rect
	if goal != null and goal.size.x > 0:
		spotlight(ui, goal.grow(8))
	var pw := 380.0
	var rows := STEPS.size()
	var how_h := ui.wrap_height(tx[1], pw - 36, 14)
	var box := Rect2(12, city.hud.panel.end.y + 56, pw, 62 + how_h + 30)
	if goal != null and goal.size.x > 0:   # pegado a la flecha
		box.position = _by_arrow(ui, goal, box.size)
	var x := box.position.x
	var y := box.position.y
	ui.rect(box, Color(0.05, 0.065, 0.09, 0.9), 14)
	ui.rect(box, Color(ImUI.COL.accent, 0.6), 14, 1.5)
	ui.text("TUTORIAL · PASO %d DE %d" % [step + 1, rows], Vector2(x + 18, y + 14), 11, "accent", true)
	var sk := Rect2(box.end.x - 74, y + 9, 62, 24)
	var hot := ui.hover(sk)
	ui.rect(sk, ImUI.COL.button_hot if hot else Color(1, 1, 1, 0.06), 12)
	ui.text("Saltar", sk.get_center(), 12, Color.WHITE if hot else ImUI.COL.muted, false, "center")
	if hot and ui.clicked:
		skip()
		return
	# El paso actual, grande y con un brillo al aparecer
	var k := clampf(step_t / 0.35, 0.0, 1.0)
	ui.text(tx[0], Vector2(x + 18 + 12 * (1.0 - k), y + 34), 20, Color(1, 1, 1, k), true, "topleft", pw - 36)
	ui.wrap_text(tx[1], Rect2(x + 18, y + 62, pw - 36, how_h + 4), 14, Color(0.92, 0.94, 0.97, k))
	# Progreso: un segmento por paso (verdes los hechos, amarillo el actual)
	var by := box.end.y - 18
	var seg := (pw - 36 - (rows - 1) * 4) / rows
	for i in rows:
		var col: Color = ImUI.COL.green if i < step else (ImUI.COL.accent if i == step else Color(1, 1, 1, 0.15))
		ui.rect(Rect2(x + 18 + i * (seg + 4), by, seg, 6), col, 3)
	# Flechas sobre la pantalla: abrir la tablet (también para los pasos que se hacen en ella) y la velocidad
	if id == "valor" and not city.overlays.open():
		city.overlays.show_value_card()   # se cerró sin leerla: vuelve a salir
	if goal != null:
		big_arrow(ui, goal)
	_edge_arrow(ui)


## Con la tablet abierta: el paso en una franja debajo de la tablet, para qué sirve arriba, y una flecha grande sobre
## el botón que hay que apretar (la pestaña, el precio óptimo, el + de contratar, la velocidad). En coordenadas de la tablet.
func draw_phone(ui: ImUI) -> void:
	if not active:
		return
	var id: String = STEPS[step]
	var tx := text(id)
	if id == "valor":
		return   # se explica en la tarjeta (Overlays.show_value_card)
	var m: Dictionary = city.app.marks
	var app = city.app
	var goal = null
	match id:
		"precio":
			goal = m.get("precio_optimo") if app.tab == "mercado" else m.get("tab_mercado")
		"contratar":
			goal = m.get("contratar") if app.tab == "negocios" else m.get("tab_negocios")
		"tiempo":
			goal = m.get("velocidad")
	if goal == null or app.modal != null:
		var w: float = ui.text_size(tx[1], 15).x + 130
		var r := Rect2(ui.W / 2 - w / 2, ui.H + 14, w, 40)
		ui.rect(r, Color(0.05, 0.067, 0.09, 0.95), 20)
		ui.rect(r, Color(ImUI.COL.accent, 0.9), 20, 2)
		ui.text("TUTORIAL", Vector2(r.position.x + 18, r.get_center().y), 12, "accent", true, "midleft")
		ui.text(tx[1], Vector2(r.position.x + 104, r.get_center().y), 15, Color.WHITE, false, "midleft")
		return
	# Hay flecha: todo lo demás se oscurece y el texto va pegado a la flecha
	spotlight(ui, goal.grow(8))
	_note_by_arrow(ui, goal, tx[1])
	big_arrow(ui, goal)


## Dónde va un recuadro de `size` pegado al botón que señala big_arrow, centrado sobre él: justo debajo del botón
## (la flecha queda arriba) o, si el botón está arriba de todo, debajo de la flecha. Si no cabe abajo, arriba de la flecha.
static func _by_arrow(ui: ImUI, goal: Rect2, size: Vector2) -> Vector2:
	var y := goal.end.y + (96.0 if goal.position.y < 56 else 16.0)
	if y + size.y > ui.H - 8:
		y = goal.position.y - 96 - size.y
	return Vector2(clampf(goal.get_center().x - size.x / 2, 8, ui.W - size.x - 8), maxf(8, y))


## El texto del paso en una nota pegada a la flecha (ver _by_arrow).
func _note_by_arrow(ui: ImUI, goal: Rect2, how: String) -> void:
	var w: float = minf(ui.text_size(how, 16).x, 440.0) + 36
	var text_h := ui.wrap_height(how, w - 36, 16)
	var h := 40 + text_h + 14
	var k := clampf(step_t / 0.35, 0.0, 1.0)
	var r := Rect2(_by_arrow(ui, goal, Vector2(w, h)) + Vector2(0, 10 * (1.0 - k)), Vector2(w, h))
	ui.rect(r, Color(0.05, 0.067, 0.09, 0.97), 14)
	ui.rect(r, Color(ImUI.COL.accent, 0.95), 14, 2)
	ui.text("TUTORIAL · PASO %d DE %d" % [step + 1, STEPS.size()], r.position + Vector2(18, 14), 11, "accent", true)
	ui.wrap_text(how, Rect2(r.position.x + 18, r.position.y + 36, w - 36, text_h + 4), 16, Color(1, 1, 1, k))


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
	ui.text("%d m" % roundi(dist), at - dir * 58, 15, "accent", true, "center")
