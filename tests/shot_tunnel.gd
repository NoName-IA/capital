extends RefCounted
## El túnel de la montaña al oeste de la avenida y la vereda que baja al mar (este).

const OUT := "res://tests/shots/"


func run(m) -> void:
	var c: City = m.city
	m.app.new_game("normal")
	await m.frames(5)
	m.app.modal = null
	c.overlays.hide()
	m.app.paused = true
	await m.frames(20)
	m.ui.set_visible(false)
	c.hud.ui.set_visible(false)
	m.set_process(false)
	var walk := []
	for x in [-140.0, -149.0, -152.0, -160.0]:
		walk.append("x=%d calle:%s vereda:%s" % [x, not c.blocked(x, 2.0), not c.blocked(x, 7.5)])
	print("CAMINAR ", walk)
	for t in [[0.34, "dia"], [0.82, "noche"]]:
		c.sky.set_time(t[0])
		for v in [["tunel_lejos", Vector3(-95, 2.2, 4), Vector3(-170, 6, 0)], ["tunel_cerca", Vector3(-147, 1.8, 4), Vector3(-170, 4, -1)],
				["tunel_alto", Vector3(-120, 40, 50), Vector3(-175, 5, 0)], ["tunel_lado", Vector3(-150, 6, 24), Vector3(-168, 6, 0)],
				["vereda_mar", Vector3(150, 2.5, 13), Vector3(178, -1, 4)], ["vereda_mar2", Vector3(185, 5, -16), Vector3(160, 0, 0)]]:
			c.camera.global_position = v[1]
			c.camera.look_at(v[2])
			c.update_lights()
			await m.frames(4)
			await m.shot(ProjectSettings.globalize_path(OUT + "%s_%s.png" % [v[0], t[1]]))
