extends RefCounted
## Las actividades de la ciudad: parque, barrio, playa y muelle (captura de cada lugar y su aviso).

const OUT := "res://tests/shots/"


func run(m) -> void:
	var c: City = m.city
	m.app.slot = 3
	m.app.new_game("normal")
	await m.frames(5)
	c.hud.help_timer = 0
	m.app.game.cash += 50000
	m.app.paused = true
	for key in ["muestras", "encuesta", "voley", "pesca"]:
		var p: Vector3 = c.builder.activity_spots[key]
		c.player.position = p
		c.player.position.y = c.floor_at(p.x, p.z, p.y + 0.5)
		c.yaw = 200.0 if key != "voley" else 110.0
		await m.frames(20)
		print("PROMPT ", key, ": ", c.hud.prompt)
		c.do_activity(key)
		await m.frames(30)
		await m.shot(ProjectSettings.globalize_path(OUT + "actividad_%s.png" % key))
	# El cerco del parque: de costado choca, saltando se pasa por encima
	print("SETO suelo bloquea: ", c.blocked(-10.0, -9.9, 0.38, 0.0), " · saltando 1.1 m pasa: ", not c.blocked(-10.0, -9.9, 0.38, 1.1),
			" · arriba pisa a ", c.floor_at(-10.0, -9.9, 1.1))
