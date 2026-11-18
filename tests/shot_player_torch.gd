extends RefCounted
## Tu linterna: en un apagón la F la prende y la apaga (aviso casi transparente abajo); sin apagón la F no la prende,
## y se apaga sola cuando vuelve la luz.
## Godot --path . -- --scenario=res://tests/shot_player_torch.gd
const OUT := "res://tests/shots/"


func _f(m) -> void:
	for pressed in [true, false]:
		var ev := InputEventKey.new()
		ev.keycode = KEY_F
		ev.physical_keycode = KEY_F
		ev.pressed = pressed
		m.get_viewport().push_input(ev)
		await m.frames(2)
	await m.frames(15)


func run(m) -> void:
	var c: City = m.city
	m.app.slot = 3
	m.app.new_game("normal")
	await m.frames(5)
	var g: Game = m.app.game
	c.tutorial.stop()
	g.tutorial_step = -1
	g.angel_ranks = [0]
	g.power_intro = true
	m.app.modal = null
	c.overlays.hide()
	c.sync(g)
	c.sky_lock = 0.85
	await m.frames(20)
	await _f(m)
	print("sin apagón, F: linterna = ", c.player_torch)
	var ok: bool = not c.player_torch
	g.power_fail = true
	g.power_until = g.day
	g.blackout = true
	await m.frames(40)
	await m.shot(ProjectSettings.globalize_path(OUT + "linterna_mia_apagada.png"))
	await _f(m)
	print("apagón, F: linterna = ", c.player_torch, " · en el cuerpo: ", c.player.torch_on)
	ok = ok and c.player_torch and c.player.torch_on
	await m.frames(20)
	await m.shot(ProjectSettings.globalize_path(OUT + "linterna_mia_prendida.png"))
	await _f(m)
	print("F otra vez: linterna = ", c.player_torch)
	ok = ok and not c.player_torch
	await _f(m)
	g.blackout = false
	g.power_until = g.day + 30
	await m.frames(30)
	print("volvió la luz: linterna = ", c.player_torch, " · en el cuerpo: ", c.player.torch_on)
	ok = ok and not c.player_torch and not c.player.torch_on
	print("RESULTADO: ", "todo bien" if ok else "HAY FALLAS")
