extends RefCounted
## El guardia del terreno en obra del centro comercial: entras por el portón, te pega con la tonfa y sales volando.
## Godot --path . -- --scenario=res://tests/shot_guard.gd
const OUT := "res://tests/shots/"


func run(m) -> void:
	var c: City = m.city
	m.app.slot = 3
	m.app.new_game("normal")
	await m.frames(5)
	var g: Game = m.app.game
	c.tutorial.active = false
	c.sky.set_time(0.45)
	m.app.paused = false
	var mall: Mall = c.malls[1]
	print("guardia: ", mall.guard != null, " · en el portón bloqueado: ", c.blocked(Blueprints.to_world(mall.plot, 8, 2.0).x, Blueprints.to_world(mall.plot, 8, 2.0).z))
	# El guardia de cerca, de día, en su puesto junto al portón
	m.set_process(false)
	c.sky.set_time(0.45)
	var gp: Vector3 = mall.guard.position
	c.camera.global_position = gp + Vector3(1.6, 1.7, -2.6) if mall.plot[1] > 0 else gp + Vector3(1.6, 1.7, 2.6)
	c.camera.look_at(gp + Vector3(0, 1.1, 0))
	c.update_lights()
	await m.frames(6)
	await m.shot(ProjectSettings.globalize_path(OUT + "guardia_puesto.png"))
	m.set_process(true)
	# Entra por el portón hasta el medio del terreno
	c.player.position = Blueprints.to_world(mall.plot, -4, 14)
	c.yaw = Mall.entrance_yaw(1)
	c.pitch = 20
	var shots := {10: "guardia_corre", 40: "guardia_cerca"}
	var hit_at := -1
	for f in 220:
		await m.frames(1)
		if shots.has(f):
			await m.shot(ProjectSettings.globalize_path(OUT + shots[f] + ".png"))
		if c.knock != null and hit_at < 0:
			hit_at = f
			print("golpe en el cuadro ", f, " · estado ", mall.guard_state)
		if hit_at >= 0 and f == hit_at + 8:
			await m.shot(ProjectSettings.globalize_path(OUT + "guardia_vuelo.png"))
	var local: Vector3 = mall.root.transform.affine_inverse() * c.player.position
	print("después: z local ", snappedf(local.z, 0.1), " (afuera si < ", Mall.Z0, ") · adentro ", mall._inside(c.player.position), " · guardia ", mall.guard_state)
	await m.shot(ProjectSettings.globalize_path(OUT + "guardia_afuera.png"))
	print("comprado: ", g.buy_mall(1)[0] if g.cash > 2000000 else "sin plata (ok)")
