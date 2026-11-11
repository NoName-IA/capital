extends RefCounted
## El puesto de noche con la luz cálida de su guirnalda. Godot --path . -- --scenario=res://tests/shot_stall_night.gd
func run(m) -> void:
	var c: City = m.city
	m.app.slot = 3
	m.app.new_game("normal")
	await m.frames(5)
	c.tutorial.active = false
	m.app.paused = true
	m.ui.set_visible(false)
	c.hud.ui.set_visible(false)
	m.set_process(false)
	var plot: Array = City.plot_pos(0)
	for t in [[0.9, "noche"], [0.78, "atardecer"], [0.9, "cerca"]]:
		c.sky.set_time(t[0])
		c.camera.global_position = Blueprints.to_world(plot, 3.5, -6.0, 2.4) if t[1] != "cerca" else Blueprints.to_world(plot, 1.5, -2.5, 1.9)
		c.camera.look_at(Blueprints.to_world(plot, 0, 3.0, 1.4))
		c.update_lights()
		await m.frames(8)
		await m.shot(ProjectSettings.globalize_path("res://tests/shots/puesto_%s.png" % t[1]))
