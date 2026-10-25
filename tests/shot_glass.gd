extends RefCounted
## Primeros planos de los vidrios para revisar los reflejos.

const OUT := "res://tests/shots/"


func cam(m, pos: Vector3, target: Vector3, name: String) -> void:
	m.city.camera.global_position = pos
	m.city.camera.look_at(target)
	await m.frames(4)
	await m.shot(ProjectSettings.globalize_path(OUT + name + ".png"))


func run(m) -> void:
	m.ui.set_visible(false)
	m.city.hud.ui.set_visible(false)
	m.set_process(false)
	m.city.set_process(false)
	await m.frames(5)
	await cam(m, Vector3(-72, 2, -6), Vector3(-80, 14, 11), "v1_torre")
	await cam(m, Vector3(-95, 3, 30), Vector3(-105, 15, 52), "v2_rascacielos")
	m.city.sky.set_time(0.07)
	await cam(m, Vector3(-72, 2, -6), Vector3(-80, 14, 11), "v3_torre_amanecer")
	m.city.sky.set_time(0.81)
	await cam(m, Vector3(-72, 2, -6), Vector3(-80, 14, 11), "v4_torre_noche")
