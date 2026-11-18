extends RefCounted
## Apagón de noche: la gente prende las linternas y alumbra su camino. También el reloj y los botones de velocidad.
## Godot --path . -- --scenario=res://tests/shot_torches.gd
const OUT := "res://tests/shots/"


func run(m) -> void:
	var c: City = m.city
	m.app.slot = 3
	m.app.new_game("normal")
	await m.frames(5)
	var g: Game = m.app.game
	c.tutorial.stop()
	g.tutorial_step = -1
	m.app.modal = null
	c.overlays.hide()
	g.power_intro = true   # sin la cinemática de la planta
	g.play_seconds = 754.0
	g.angel_ranks = [0]   # que no salga Ángel (ya ofreció)
	c.sync(g)
	c.sky_lock = 0.4
	await m.frames(30)
	await m.shot(ProjectSettings.globalize_path(OUT + "velocidad_dia.png"))
	m.app.paused = true
	await m.frames(5)
	await m.shot(ProjectSettings.globalize_path(OUT + "velocidad_pausa.png"))
	m.app.paused = false
	m.app.speed = 2
	c.sky_lock = 0.85   # de noche
	g.power_fail = true
	g.power_until = g.day
	g.blackout = true
	await m.frames(90)
	var lit := 0
	for p in c.get_tree().get_nodes_in_group("people"):
		if p.torch_on:
			lit += 1
	print("noche: ", c.sky.night, " · apagón: ", c.sky.blackout, " · linternas prendidas: ", lit)
	await m.shot(ProjectSettings.globalize_path(OUT + "linternas_1.png"))
	c.first_person = false
	c.zoom_target = 9.0
	c.zoom = 9.0
	await m.frames(60)
	await m.shot(ProjectSettings.globalize_path(OUT + "linternas_2.png"))
	g.blackout = false
	g.power_until = g.day + 30
	await m.frames(30)
	lit = 0
	for p in c.get_tree().get_nodes_in_group("people"):
		if p.torch_on:
			lit += 1
	print("volvió la luz · linternas prendidas: ", lit)
	await m.shot(ProjectSettings.globalize_path(OUT + "linternas_luz.png"))
