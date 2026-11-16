extends RefCounted
## El ascensor del vestíbulo, el viaje a la presidencia (pisos de ejecutivos tecleando) y la oficina del CEO.
## Godot --path . -- --scenario=res://tests/shot_tower.gd
const OUT := "res://tests/shots/"


func run(m) -> void:
	var c: City = m.city
	m.app.slot = 3
	m.app.new_game("normal")
	await m.frames(5)
	var g: Game = m.app.game
	c.tutorial.stop()
	g.office_look = 2
	c.sync(g)
	c.sky_lock = 0.45
	m.app.modal = null
	c.overlays.hide()
	c.teleport(Blueprints.to_world(City.HQ, 0.0, 9.0), 0.0, "")
	await m.frames(30)
	m.app.modal = null
	c.overlays.hide()
	await m.frames(3)
	print("aviso: ", c.hud.prompt)
	await m.shot(ProjectSettings.globalize_path(OUT + "torre_ascensor.png"))
	c.teleport(Blueprints.to_world(City.HQ, Tower.LOBBY_LIFT.x, Tower.LOBBY_LIFT.z), 0.0, "")
	await m.frames(5)
	print("aviso junto al ascensor: ", c.hud.prompt)
	c.tower.go_up()
	await m.get_tree().create_timer(1.6).timeout
	await m.shot(ProjectSettings.globalize_path(OUT + "torre_viaje1.png"))
	await m.get_tree().create_timer(1.6).timeout
	await m.shot(ProjectSettings.globalize_path(OUT + "torre_viaje2.png"))
	while c.tower.phase != "reveal":
		await m.frames(1)
	await m.get_tree().create_timer(1.2).timeout
	await m.shot(ProjectSettings.globalize_path(OUT + "torre_llegada.png"))
	while c.tower.busy():
		await m.frames(1)
	await m.frames(30)
	print("en la presidencia: ", c.tower.inside(c.player.position), " · aviso: ", c.hud.prompt)
	await m.shot(ProjectSettings.globalize_path(OUT + "torre_presidencia.png"))
	c.camera.global_position = c.tower.w(Vector3(-6, 3.2, -6))
	m.set_process(false)
	c.camera.look_at(c.tower.w(Vector3(2, 0.8, 3)))
	await m.frames(5)
	await m.shot(ProjectSettings.globalize_path(OUT + "torre_presidencia2.png"))
	m.set_process(true)
	c.tower.go_down()
	while c.tower.busy():
		await m.frames(1)
	await m.frames(10)
	print("de vuelta en el vestíbulo: ", not c.tower.inside(c.player.position), " ", c.player.position)
