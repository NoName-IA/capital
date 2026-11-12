extends RefCounted
## El escritorio de la computadora en la oficina (a la derecha al entrar), en los 4 aspectos.
## Godot --path . -- --scenario=res://tests/shot_pc_desk.gd
const OUT := "res://tests/shots/"


func run(m) -> void:
	var c: City = m.city
	m.app.slot = 3
	m.app.new_game("normal", true)
	await m.frames(5)
	var g: Game = m.app.game
	c.tutorial.stop()
	m.app.paused = true
	for tier in 4:
		g.office_look = tier
		c.set_office_look(tier)
		await m.frames(3)
		# Recién entrando por la puerta, mirando hacia adentro
		c.player.position = Blueprints.to_world(City.HQ, -1.5, 4.2)
		c.yaw = -62.0
		c.pitch = 14.0
		c.player.rotation.y = deg_to_rad(-62.0)
		await m.frames(20)
		await m.shot(ProjectSettings.globalize_path(OUT + "pc_desk_%d.png" % tier))
	print("computadora: ", c.hq_spots.computer, " · asiento: ", c.hq_spots.pc_seat, " · pantalla: ", c.hq_spots.pc_screen, " y ", c.hq_spots.pc_screen_y)
