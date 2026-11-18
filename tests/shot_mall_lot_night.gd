extends RefCounted
## El terreno en obra del centro comercial de noche: focos de obra que alumbran casi todo, con luz común y algo pobre.
## Godot --path . -- --scenario=res://tests/shot_mall_lot_night.gd
const OUT := "res://tests/shots/"


func run(m) -> void:
	var c: City = m.city
	m.app.slot = 3
	m.app.new_game("normal")
	await m.frames(5)
	var g: Game = m.app.game
	c.tutorial.active = false
	g.tutorial_step = -1
	g.angel_ranks = [0]
	m.app.modal = null
	c.overlays.hide()
	for i in 2:
		var mall: Mall = c.malls[i]
		for when in [[0.85, "noche"], [0.45, "dia"]]:
			m.set_process(true)
			c.sky_lock = when[0]
			await m.frames(30)   # que la ciudad prenda las luces y las registre
			m.set_process(false)
			var mid := Blueprints.to_world(mall.plot, 0, 16)
			var front := Blueprints.to_world(mall.plot, 0, -10)
			c.camera.global_position = front + Vector3(0, 14, 0)
			c.camera.look_at(mid)
			c.update_lights()
			await m.frames(8)
			await m.shot(ProjectSettings.globalize_path(OUT + "obra_%d_%s.png" % [i, when[1]]))
		var gp: Vector3 = mall.guard.position
		m.set_process(true)
		c.sky_lock = 0.85
		await m.frames(30)
		m.set_process(false)
		c.camera.global_position = gp + (Vector3(1.6, 1.7, -2.6) if mall.plot[1] > 0 else Vector3(1.6, 1.7, 2.6))
		c.camera.look_at(gp + Vector3(0, 1.1, 0))
		c.update_lights()
		await m.frames(8)
		await m.shot(ProjectSettings.globalize_path(OUT + "obra_%d_guardia_noche.png" % i))
		m.set_process(true)
