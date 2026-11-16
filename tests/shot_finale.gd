extends RefCounted
## El final del juego con la copia de prueba de la partida casi ganada (antes: make_finale_save.gd con --para-pruebas).
## Godot --path . -- --scenario=res://tests/shot_finale.gd
const OUT := "res://tests/shots/"


func _shot(m, name: String) -> void:
	await m.shot(ProjectSettings.globalize_path(OUT + "final_" + name + ".png"))


func _wait(m, c: City, phase: String, extra := 0.0) -> void:
	var n := 0
	while c.finale.phase != phase and n < 3000:
		await m.frames(1)
		n += 1
	if extra > 0:
		await m.get_tree().create_timer(extra).timeout


func run(m) -> void:
	var c: City = m.city
	var ok: bool = m.app.load_slot(3)   # la copia de prueba (make_finale_save.gd -- --para-pruebas)
	print("cargada: ", ok)
	var g: Game = m.app.game
	c.sync(g)
	m.app.paused = false
	m.app.modal = null
	c.overlays.hide()
	var t0 := Time.get_ticks_msec()
	await _wait(m, c, "call", 1.2)
	print("el final empezó a los ", (Time.get_ticks_msec() - t0) / 1000.0, " s · ganó: ", g.won, " · fps ", Engine.get_frames_per_second())
	await _shot(m, "1_llamada")
	await _wait(m, c, "walk", 1.4)
	await _shot(m, "1a_titulo")
	await m.get_tree().create_timer(3.0).timeout
	await _shot(m, "1b_caminando")
	await m.get_tree().create_timer(3.2).timeout
	await _shot(m, "1c_entrando")
	await m.get_tree().create_timer(1.8).timeout
	await _shot(m, "1d_vuelta")
	await _wait(m, c, "ride", 4.0)
	await _shot(m, "2_subida")
	await m.get_tree().create_timer(5.0).timeout
	await _shot(m, "2b_subida")
	await _wait(m, c, "window", 2.6)
	await _shot(m, "3_ventanal")
	await _wait(m, c, "photo", 1.3)
	await _shot(m, "4_foto")
	await _wait(m, c, "paper", 0.9)
	await _shot(m, "5a_kiosco")
	await m.get_tree().create_timer(1.3).timeout
	await _shot(m, "5b_girando")
	await m.get_tree().create_timer(2.5).timeout
	await _shot(m, "5_diario")
	await _wait(m, c, "credits", 3.0)
	await _shot(m, "6_creditos")
	await m.get_tree().create_timer(7.0).timeout
	await _shot(m, "6b_creditos")
	await _wait(m, c, "card", 0.6)
	await _shot(m, "7a_tarjeta_entrando")
	await m.get_tree().create_timer(2.2).timeout
	await _shot(m, "7_tarjeta")
	var esc := InputEventKey.new()
	esc.keycode = KEY_ESCAPE
	esc.pressed = true
	c.finale.key(esc)
	print("Esc en la tarjeta: fase '", c.finale.phase, "'")
	c.finale.leaving = 0.0   # un clic en la tarjeta
	await m.get_tree().create_timer(0.6).timeout
	await _shot(m, "8_saliendo")
	await _wait(m, c, "", 0.0)
	await m.get_tree().create_timer(0.5).timeout
	await _shot(m, "8b_menu_apareciendo")
	await m.get_tree().create_timer(1.2).timeout
	print("después: fase '", c.finale.phase, "' · visto ", g.finale_seen, " · vista ", m.app.view, " · partida ", m.app.game != null)
	await _shot(m, "9_menu")
