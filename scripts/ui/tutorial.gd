class_name Tutorial
extends RefCounted
## Tutorial guiado: después de la bienvenida, una lista de pasos que se hacen jugando (caminar, atender tu puesto,
## abrir el celular, cambiar un precio...). Cada paso se marca solo cuando lo haces, y una flecha sobre la ciudad
## (o en el borde de la pantalla, si queda fuera de la vista) te muestra a dónde ir.

const STEPS := ["caminar", "saltar", "puesto", "atender", "celular", "precio", "tiempo", "oficina", "terreno"]

var city
var active := false
var step := 0
var step_t := 0.0          # segundos en el paso actual (para la animación al pasar de un paso a otro)
var start_pos := Vector3.ZERO
var start_price := 0.0
var marker: MeshInstance3D


func _init(owner_city) -> void:
	city = owner_city


func start() -> void:
	active = true
	step = 0
	step_t = 0.0
	start_pos = city.player.position
	start_price = city.game.products.cafe.price
	if marker == null:
		var arrow := PrismMesh.new()   # flecha que apunta hacia abajo
		arrow.size = Vector3(0.7, 0.8, 0.25)
		marker = MeshInstance3D.new()
		marker.mesh = arrow
		marker.rotation.z = PI
		var m := StandardMaterial3D.new()
		m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		m.albedo_color = ImUI.COL.accent
		m.no_depth_test = true   # se ve a través de las paredes
		m.render_priority = 10
		marker.material_override = m
		marker.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		city.add_child(marker)
	marker.visible = false


func stop() -> void:
	active = false
	if marker:
		marker.visible = false


## [título, cómo hacerlo] del paso.
func text(id: String) -> Array:
	var k := func(a: String) -> String: return Keys.label(a)
	match id:
		"caminar":
			return ["Camina por la ciudad", "Usa %s %s %s %s para caminar y el mouse para mirar. %s corre." % [
					k.call("forward"), k.call("left"), k.call("back"), k.call("right"), k.call("run")]]
		"saltar":
			return ["Salta", "Aprieta %s. Puedes subirte a bancas, jardineras y al cerco del parque." % k.call("jump")]
		"puesto":
			return ["Ve a tu puesto de café", "Es tu primer negocio. Sigue la flecha amarilla."]
		"atender":
			return ["Atiende el mostrador", "Párate frente al mostrador y aprieta %s: vendes tú y cuentas como un empleado más." % k.call("interact")]
		"celular":
			return ["Abre tu celular", "Aprieta %s. Ahí manejas todo: precios, empleados, inventario, préstamos." % k.call("phone")]
		"precio":
			return ["Cambia el precio del café", "En el celular, pestaña Mercado: sube o baja el precio y mira cómo cambia tu utilidad."]
		"tiempo":
			return ["Haz correr el tiempo", "Cierra el celular y aprieta %s o %s para ir más rápido (%s = normal, %s = pausa)." % [
					k.call("speed2"), k.call("speed3"), k.call("speed1"), k.call("pause_quick")]]
		"oficina":
			return ["Ve a tu oficina central", "Aprieta %s para ir directo o camina hasta la torre. Ahí están la computadora, la estrategia y los trofeos." % k.call("office")]
		"terreno":
			return ["Mira un terreno en venta", "Acércate a un letrero SE VENDE y aprieta %s. Ahí abres tu próximo local." % k.call("interact")]
	return ["", ""]


func _stall() -> Store:
	for s in city.stores.values():
		if s.loc.size == 0:
			return s
	return null if city.stores.is_empty() else city.stores.values()[0]


## A dónde apunta la flecha en este paso (o null si no hay un lugar).
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
		"celular":
			return city.overlays.mode == "admin" and city.app.view == "game"
		"precio":
			return absf(city.game.products.cafe.price - start_price) > 0.001
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
		if STEPS[step - 1] == "celular":
			start_price = city.game.products.cafe.price
		if step >= STEPS.size():
			finish()
			return
	var t = target()
	marker.visible = t != null and not city.overlays.open()
	if t != null:
		var bob := sin(Time.get_ticks_msec() / 1000.0 * 3.0) * 0.15
		marker.global_position = t + Vector3(0, 2.6 + bob, 0)
		marker.rotation.y += dt * 2.0


func finish() -> void:
	stop()
	city.settings.tutorial_seen = true
	city.save_settings()
	city.hud.notes.push_hero("TUTORIAL COMPLETO", "¡Ya sabes lo básico!",
			"Meta: que tu empresa valga %s. Cuida la caja: si queda en negativo mucho tiempo, quiebras." % Fmt.short(D.WIN_VALUE),
			ImUI.COL.accent, "fanfare", 80)


func skip() -> void:
	stop()
	city.settings.tutorial_seen = true
	city.save_settings()


## Panel de los pasos (a la izquierda, debajo de la tarjeta de la empresa) y la flecha en el borde de la pantalla si el
## lugar queda fuera de la vista. Con el celular abierto, el paso se muestra en una franja abajo.
func draw(ui: ImUI) -> void:
	if not active:
		return
	var id: String = STEPS[step]
	var tx := text(id)
	if city.overlays.open():
		return   # con el celular abierto el paso se ve debajo del celular (ver draw_phone)
	var x := 12.0
	var y: float = city.hud.panel.end.y + 56
	var pw := 360.0
	var rows := STEPS.size()
	var hh := ui.wrap_height(tx[1], pw - 36, 13)
	var ly: float = y + 60 + hh + 10
	var box := Rect2(x, y, pw, ly - y + rows * 22 + 8)
	ui.rect(box, Color(0.05, 0.065, 0.09, 0.86), 14)
	ui.rect(box, Color(ImUI.COL.accent, 0.45), 14, 1)
	ui.text("TUTORIAL · %d DE %d" % [step + 1, rows], Vector2(x + 18, y + 14), 11, "accent", true)
	var sk := Rect2(box.end.x - 74, y + 9, 62, 24)
	var hot := ui.hover(sk)
	ui.rect(sk, ImUI.COL.button_hot if hot else Color(1, 1, 1, 0.06), 12)
	ui.text("Saltar", sk.get_center(), 12, Color.WHITE if hot else ImUI.COL.muted, false, "center")
	if hot and ui.clicked:
		skip()
		return
	# El paso actual, grande y con un brillo al aparecer
	var k := clampf(step_t / 0.35, 0.0, 1.0)
	ui.text(tx[0], Vector2(x + 18 + 12 * (1.0 - k), y + 34), 19, Color(1, 1, 1, k), true, "topleft", pw - 36)
	ui.wrap_text(tx[1], Rect2(x + 18, y + 60, pw - 36, hh + 4), 13, Color(ImUI.COL.muted, k))
	ui.rect(Rect2(x + 18, ly - 4, pw - 36, 1), Color(1, 1, 1, 0.08))
	for i in rows:
		var c := Vector2(x + 28, ly + 10 + i * 22)
		var label: String = text(STEPS[i])[0]
		if i < step:
			ui.circle(c, 7, ImUI.COL.green)
			ui.text("✓", c, 10, Color8(15, 30, 20), true, "center")
			ui.text(label, Vector2(c.x + 16, c.y), 13, ImUI.COL.muted, false, "midleft")
		elif i == step:
			ui.ring(c, 7, ImUI.COL.accent, 2)
			ui.circle(c, 3 + sin(Time.get_ticks_msec() / 200.0), ImUI.COL.accent)
			ui.text(label, Vector2(c.x + 16, c.y), 13, Color.WHITE, true, "midleft")
		else:
			ui.ring(c, 6, Color(1, 1, 1, 0.25), 1.5)
			ui.text(label, Vector2(c.x + 16, c.y), 13, Color(1, 1, 1, 0.4), false, "midleft")
	_edge_arrow(ui)


## Con el celular abierto: el paso actual en una franja debajo del celular (en las coordenadas del celular).
func draw_phone(ui: ImUI) -> void:
	if not active:
		return
	var tx := text(STEPS[step])
	var w: float = ui.text_size(tx[1], 15).x + 130
	var r := Rect2(ui.W / 2 - w / 2, ui.H + 14, w, 36)
	ui.rect(r, Color(0.05, 0.067, 0.09, 0.95), 18)
	ui.rect(r, Color(ImUI.COL.accent, 0.8), 18, 1.5)
	ui.text("TUTORIAL", Vector2(r.position.x + 18, r.get_center().y), 12, "accent", true, "midleft")
	ui.text(tx[1], Vector2(r.position.x + 104, r.get_center().y), 15, Color.WHITE, false, "midleft")


## Si el lugar al que hay que ir queda fuera de la pantalla, una flecha en el borde apunta hacia él.
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
		ui.text("%d m" % roundi(dist), sp + Vector2(0, -40), 14, "accent", true, "center")
		return
	var center := Vector2(ui.W / 2, ui.H / 2)
	var dir := (sp - center)
	if behind:
		dir = -dir
	if dir.length() < 1.0:
		dir = Vector2(0, 1)
	dir = dir.normalized()
	var half := Vector2(ui.W / 2 - 60, ui.H / 2 - 60)
	var s: float = min(half.x / max(absf(dir.x), 0.001), half.y / max(absf(dir.y), 0.001))
	var at := center + dir * s
	var n := Vector2(-dir.y, dir.x)
	ui.circle(at, 26, Color(0.05, 0.065, 0.09, 0.85))
	ui.polygon(PackedVector2Array([at + dir * 18, at - dir * 10 + n * 12, at - dir * 10 - n * 12]), ImUI.COL.accent)
	ui.text("%d m" % roundi(dist), at - dir * 44, 13, "accent", true, "center")
