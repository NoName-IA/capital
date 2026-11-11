extends RefCounted
## Los dos terrenos de los centros comerciales, cercados, antes de comprarlos. Godot --path . -- --scenario=res://tests/shot_mall_fence.gd
func run(m) -> void:
	var c: City = m.city
	m.app.slot = 3
	m.app.new_game("normal")
	await m.frames(5)
	c.tutorial.active = false
	m.app.paused = true
	m.ui.set_visible(false)
	c.hud.ui.set_visible(false)
	c.sky.set_time(0.42)
	m.set_process(false)
	for i in 2:
		var e := Mall.entrance(i)
		var out := (e - Blueprints.to_world(Mall.PLOTS[i], 0, 10)).normalized()
		c.camera.global_position = e + out * 12 + Vector3(0, 22, 0) + Vector3(out.z, 0, -out.x) * 18
		c.camera.look_at(Blueprints.to_world(Mall.PLOTS[i], 0, 17))
		c.update_lights()
		await m.frames(6)
		await m.shot(ProjectSettings.globalize_path("res://tests/shots/cerco_cc_%d.png" % i))
	print("bloqueado al entrar por el frente: ", c.blocked(Mall.entrance(1).x, Blueprints.to_world(Mall.PLOTS[1], 0, 2).z))
