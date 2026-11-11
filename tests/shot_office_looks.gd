extends RefCounted
## Los cuatro aspectos de la oficina, de afuera. Godot --path . -- --scenario=res://tests/shot_office_looks.gd
func run(m) -> void:
	var c: City = m.city
	m.app.slot = 3
	m.app.new_game("normal")
	await m.frames(5)
	var g: Game = m.app.game
	c.tutorial.active = false
	m.app.paused = true
	m.ui.set_visible(false)
	c.hud.ui.set_visible(false)
	print("partida nueva: oficina ", g.office_look, " · comprar la 3 sin rango: ", g.buy_office_look(3))
	g.cash += 5000000
	g.rank = 4
	for t in 4:
		if t > 0:
			print("remodelar ", t, ": ", g.buy_office_look(t))
		c.sync(g)
		await m.frames(3)
		m.set_process(false)
		c.sky.set_time(0.45)
		c.camera.global_position = Blueprints.to_world(City.HQ, 14, -16, 6)
		c.camera.look_at(Blueprints.to_world(City.HQ, 0, 8, 11))
		c.update_lights()
		await m.frames(6)
		await m.shot(ProjectSettings.globalize_path("res://tests/shots/oficina_%d.png" % t))
		m.set_process(true)
	print("choques de la oficina: ", c.hq.rects.size(), " · computadora ", c.hq_spots.computer)
	var old := Game.from_json(g.to_json().replace('"office_look":3', '"x":3'))
	print("partida vieja sin el dato: oficina ", old.office_look)
	m.ui.set_visible(true)
	m.app.tab = "crecimiento"
	g.office_look = 1
	g.rank = 2
	c.overlays.show("admin")
	await m.frames(10)
	await m.shot(ProjectSettings.globalize_path("res://tests/shots/oficina_tablet.png"))
