extends RefCounted
## Capturas de la calle donde baja a la arena y se mete al mar (veredas y soleras).

const OUT := "res://tests/shots/"
const VIEWS := [["cerca_s", Vector3(153, 1.6, 9.5), Vector3(163, -0.3, 7.5)], ["cerca_n", Vector3(153, 1.6, -9.5), Vector3(163, -0.3, -7.5)],
		["bajada", Vector3(160, 1.2, 10.5), Vector3(170, -1.0, 7.5)], ["desde_mar", Vector3(172, 1.5, 11), Vector3(158, 0, 7.5)],
		["solera", Vector3(158, 0.8, 4.5), Vector3(164, -0.3, 6.5)]]


func run(m) -> void:
	var c: City = m.city
	m.app.slot = 3
	m.app.new_game("normal")
	await m.frames(5)
	c.hud.help_timer = 0
	m.ui.set_visible(false)
	m.set_process(false)
	c.sky.set_time(0.3)
	for v in VIEWS:
		c.camera.global_position = v[1]
		c.camera.look_at(v[2])
		await m.frames(6)
		await m.shot(ProjectSettings.globalize_path(OUT + "beach_road_%s.png" % v[0]))
