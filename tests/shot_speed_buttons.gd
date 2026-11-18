extends RefCounted
## Los botones de velocidad (pausa, x1, x2, x3): clic en cada uno, que no salgan mensajes al pasar el mouse, que el
## reloj no haga nada al hacerle clic, y la tecla Alt (bloquear/desbloquear) con su aviso al lado del minimapa.
## No usa el cursor de Windows (si estás usando el PC mientras corre, el cursor no llega donde debe): pone la posición
## del mouse en el HUD y le manda el clic a la ciudad, que es lo mismo que pasa al hacer clic de verdad.
## Godot --path . -- --scenario=res://tests/shot_speed_buttons.gd
const OUT := "res://tests/shots/"


## El mouse sobre `p` (en la pantalla virtual del HUD) y un clic ahí.
func _click(m, c: City, p: Vector2) -> void:
	await m.frames(2)
	c.hud.ui.mouse = p
	var ev := InputEventMouseButton.new()
	ev.button_index = MOUSE_BUTTON_LEFT
	ev.pressed = true
	c.input_event(ev)
	await m.frames(3)


func _alt(m) -> void:
	for pressed in [true, false]:
		var ev := InputEventKey.new()
		ev.keycode = KEY_ALT
		ev.physical_keycode = KEY_ALT
		ev.pressed = pressed
		m.get_viewport().push_input(ev)
		await m.frames(2)
	await m.frames(3)


func run(m) -> void:
	var c: City = m.city
	m.app.slot = 3
	m.app.new_game("normal")
	await m.frames(5)
	var g: Game = m.app.game
	c.tutorial.stop()
	g.tutorial_step = -1
	g.angel_ranks = [0]
	m.app.modal = null
	c.overlays.hide()
	c.sky_lock = 0.4
	g.play_seconds = 754.0
	c.sync(g)
	await m.frames(20)
	var ok := true
	await _alt(m)
	print("Alt: mouse suelto = ", not c.mouse_captured())
	var names := ["pausa", "x1", "x2", "x3"]
	for i in [2, 3, 1, 0, 0, 2]:
		var r: Rect2 = c.hud.speed_rects[i]
		var before := [m.app.paused, m.app.speed]
		await _click(m, c, r.get_center())
		var got := [m.app.paused, m.app.speed]
		var good: bool
		if i == 0:
			good = got[0] == not before[0] and got[1] == before[1]   # la pausa se pone o se quita
		else:
			good = got[0] == false and got[1] == i - 1
		print("clic en ", names[i], ": pausa=", got[0], " velocidad=", Admin.SPEEDS[got[1]][1], " · ", "OK" if good else "MAL")
		ok = ok and good
	# Pasar el mouse por encima: ningún mensaje emergente
	for r in c.hud.speed_rects + [c.hud.speed_rect]:
		c.hud.ui.mouse = r.get_center()
		await m.frames(2)
		ok = ok and c.hud.ui.tip == null
	print("mensajes emergentes al pasar el mouse: ", "ninguno" if ok else "SALE ALGUNO")
	# El reloj: clic no cambia nada
	var before := [m.app.paused, m.app.speed]
	await _click(m, c, Vector2(c.hud.speed_rect.position.x + 20, c.hud.speed_rect.get_center().y))
	print("clic en el reloj: no cambia nada = ", [m.app.paused, m.app.speed] == before)
	ok = ok and [m.app.paused, m.app.speed] == before
	await m.shot(ProjectSettings.globalize_path(OUT + "alt_suelto.png"))
	# (en modo de prueba City.capture_mouse no atrapa el mouse: a propósito, para no quitárselo a quien prueba)
	print("RESULTADO: ", "todo bien" if ok else "HAY FALLAS")
