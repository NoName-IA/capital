extends RefCounted
## La calle donde baja por la arena y se mete al mar (este).

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
	c.sky.set_time(0.34)
	for v in [["mar_1", Vector3(140, 3, 5), Vector3(175, -1, 0)], ["mar_2", Vector3(165, 6, 14), Vector3(165, -1, 0)],
			["mar_3", Vector3(190, 4, -10), Vector3(160, 0, 0)], ["mar_4", Vector3(150, 1.8, 0.5), Vector3(180, -2, 0)]]:
		c.camera.global_position = v[1]
		c.camera.look_at(v[2])
		c.update_lights()
		await m.frames(4)
		await m.shot(ProjectSettings.globalize_path(OUT + "%s.png" % v[0]))
	var ys := []
	for x in [150.0, 156.0, 158.0, 160.0, 164.0, 170.0, 176.0, 180.0]:
		ys.append("x=%d terreno %.2f calle %.2f" % [x, Terrain.height(x, 0), Actors.road_y(x)])
	print("ALTURAS ", ys)
