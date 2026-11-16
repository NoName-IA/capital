extends RefCounted
## La planta eléctrica rediseñada, la red eléctrica por la ciudad (avenida, barrio, alta tensión, subestación) y
## caminar adentro del túnel.
## Godot --path . -- --scenario=res://tests/shot_grid.gd
const OUT := "res://tests/shots/"
const VIEWS := [
	["planta_calle", Vector3(-140, 2.2, 3.0), Vector3(-157, 7, 24)],
	["planta_aire", Vector3(-128, 32, -2), Vector3(-157, 4, 26)],
	["planta_atras", Vector3(-136, 16, 52), Vector3(-157, 8, 26)],
	["avenida", Vector3(-30, 2.0, -2.5), Vector3(20, 5, 2)],
	["avenida_aire", Vector3(-10, 30, -38), Vector3(20, 0, 5)],
	["barrio", Vector3(20, 3.0, 45), Vector3(50, 3, 45)],
	["alta_tension", Vector3(-20, 14, 30), Vector3(10, 14, 71)],
	["subestacion", Vector3(110, 8, 50), Vector3(118, 4, 64)],
	["industrial", Vector3(-30, 9, -30), Vector3(-75, 3, -44)],
]


func run(m) -> void:
	var c: City = m.city
	m.app.slot = 3
	m.app.new_game("normal")
	await m.frames(5)
	var g: Game = m.app.game
	c.tutorial.stop()
	g.tutorial_step = -1
	m.app.modal = null
	c.overlays.hide()
	c.sky_lock = 0.32
	# Caminar adentro del túnel
	c.teleport(Vector3(-170, 0, 7.5), -90.0, "")
	await m.frames(10)
	var p0 := c.player.position
	print("bloqueado en el túnel x -185: ", c.blocked(-185, 7.5), " · x -201: ", c.blocked(-201, 7.5), " · x -204: ", c.blocked(-204, 7.5), " · pared z 9.6: ", c.blocked(-185, 9.6))
	c.teleport(Vector3(-190, 0, 7.5), -90.0, "")
	await m.frames(20)
	await m.shot(ProjectSettings.globalize_path(OUT + "red_tunel_adentro.png"))
	m.ui.set_visible(false)
	m.set_process(false)
	for v in VIEWS:
		c.camera.global_position = v[1]
		c.camera.look_at(v[2])
		await m.frames(5)
		await m.shot(ProjectSettings.globalize_path(OUT + "red_%s.png" % v[0]))
