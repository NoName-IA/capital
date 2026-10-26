extends RefCounted
## El parque: el cerco de arbustos junto a la vereda, los columpios y los faroles del Barrio Las Lomas.

const OUT := "res://tests/shots/"


func run(m) -> void:
	var c: City = m.city
	m.app.new_game("normal")
	await m.frames(5)
	m.app.modal = null
	c.overlays.hide()
	m.app.paused = true
	await m.frames(40)
	m.ui.set_visible(false)
	c.hud.ui.set_visible(false)
	m.set_process(false)
	var views := [["parque_cerco", Vector3(-12, 2.2, -5.5), Vector3(-16, 0.3, -10)],
			["parque_cerco_2", Vector3(-19, 1.3, -7.0), Vector3(-23, 0.2, -12)],
			["parque_esquina", Vector3(-25, 2.5, -6), Vector3(-21, 0.3, -12)],
			["parque_columpios", Vector3(-8.5, 2.8, -44), Vector3(-14, 1.2, -49)],
			["parque_columpios_2", Vector3(-14, 2.2, -42.5), Vector3(-14, 1.2, -49)],
			["lomas_pasaje", Vector3(20, 6, -45), Vector3(50, 1, -45)],
			["lomas_pasaje_2", Vector3(60, 6, 45), Vector3(30, 1, 45)]]
	for t in [0.45, 0.9]:
		c.sky.set_time(t)
		for v in views:
			if t > 0.5 and not v[0].begins_with("lomas"):
				continue
			c.camera.global_position = v[1]
			c.camera.look_at(v[2])
			c.update_lights()
			await m.frames(4)
			await m.shot(ProjectSettings.globalize_path(OUT + "%s%s.png" % [v[0], "_noche" if t > 0.5 else ""]))
