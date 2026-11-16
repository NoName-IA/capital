extends RefCounted
## Capturas de la entrada de la ciudad junto al túnel (donde va la planta eléctrica).

const OUT := "res://tests/shots/"
const VIEWS := [["aereo", Vector3(-120, 45, 40), Vector3(-158, 0, 0)], ["calle", Vector3(-128, 2.0, 4), Vector3(-160, 3, 14)],
		["aereo_s", Vector3(-120, 45, -40), Vector3(-158, 0, 0)]]


func run(m) -> void:
	var c: City = m.city
	m.app.slot = 3
	m.app.new_game("normal")
	await m.frames(5)
	m.ui.set_visible(false)
	m.set_process(false)
	c.sky.set_time(0.3)
	for v in VIEWS:
		c.camera.global_position = v[1]
		c.camera.look_at(v[2])
		await m.frames(6)
		await m.shot(ProjectSettings.globalize_path(OUT + "tunnel_%s.png" % v[0]))
