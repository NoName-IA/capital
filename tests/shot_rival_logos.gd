extends RefCounted
## Logos y fotos de los rivales: pestaña Rivales, aviso y el local de la competencia. Godot --path . -- --scenario=res://tests/shot_rival_logos.gd
func run(m) -> void:
	var c: City = m.city
	m.app.slot = 3
	m.app.new_game("normal")
	await m.frames(5)
	var g: Game = m.app.game
	c.tutorial.active = false
	g.day = 400
	for k in ["pan", "burger", "ropa", "tech"]:
		g.cash += 2000000
		g.unlock(k)
	g._rival_takes("burger", 5)
	c.sync(g)
	await m.frames(10)
	c.hud.notes.clear()
	g.rival_say(D.rival_by_key("trump"), "taunt")
	await m.frames(30)
	await m.shot(ProjectSettings.globalize_path("res://tests/shots/rival_aviso.png"))
	m.app.paused = true
	m.app.tab = "rivales"
	m.app.rival_sel = "trump"
	c.overlays.show("admin")
	await m.frames(15)
	await m.shot(ProjectSettings.globalize_path("res://tests/shots/rival_tab.png"))
	c.overlays.hide()
	await m.frames(30)
	m.set_process(false)
	c.sky.set_time(0.45)
	var front := Blueprints.to_world(City.plot_pos(5), 0, -12.0, 4.0)
	c.camera.global_position = front
	c.camera.look_at(Blueprints.to_world(City.plot_pos(5), 0, 3.0, 5.0))
	c.update_lights()
	await m.frames(6)
	await m.shot(ProjectSettings.globalize_path("res://tests/shots/rival_local_logo.png"))
