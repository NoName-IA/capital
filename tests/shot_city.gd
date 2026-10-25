extends RefCounted
## Capturas de la ciudad desde varios puntos (sin interfaz).

const OUT := "res://tests/shots/"


func cam(m, pos: Vector3, target: Vector3, name: String) -> void:
	m.city.camera.global_position = pos
	m.city.camera.look_at(target)
	await m.frames(4)
	await m.shot(ProjectSettings.globalize_path(OUT + name + ".png"))


func run(m) -> void:
	m.ui.set_visible(false)
	m.set_process(false)
	await m.frames(5)
	await cam(m, Vector3(-60, 6, -4), Vector3(-80, 8, 18), "c1_oficina")
	await cam(m, Vector3(0, 12, 6), Vector3(0, 0, -40), "c2_parque")
	await cam(m, Vector3(120, 5, 0), Vector3(170, 2, 10), "c3_playa")
	await cam(m, Vector3(-20, 30, -60), Vector3(20, 0, 30), "c4_aereo")
	m.city.sky.set_time(0.81)
	await cam(m, Vector3(-60, 6, -4), Vector3(-80, 8, 18), "c5_noche")
	await cam(m, Vector3(20, 4, 40), Vector3(60, 3, 45), "c6_barrio_noche")
