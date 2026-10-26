extends RefCounted
## La luz de noche (y de día adentro): avenida, parque, playa, barrio, oficina y un local por dentro.

const OUT := "res://tests/shots/"


func run(m) -> void:
	var c: City = m.city
	m.app.slot = 3
	m.app.new_game("normal")
	await m.frames(5)
	var g: Game = m.app.game
	g.cash += 500000
	g.open_location("cafe", 1)
	m.app.paused = true
	await m.frames(10)
	c.hud.help_timer = 0
	m.ui.set_visible(false)
	c.hud.ui.set_visible(false)
	m.set_process(false)   # la cámara queda donde la ponemos
	var sp := Blueprints.to_world([-33, 1], 0, 0)
	var hq := Vector3(-80, 0, 9)
	var views := [
		["avenida", Vector3(-6, 3.2, 9), Vector3(-14, 2.2, -12)],
		["parque", Vector3(8, 4, -22), Vector3(0, 1, -34)],
		["playa", Vector3(150, 5, 40), Vector3(186, 0, 22)],
		["barrio", Vector3(14, 3, 45), Vector3(34, 1.5, 37)],
		["oficina_dentro", hq + Vector3(3, 2.4, 3), hq + Vector3(-3, 1.2, 14)],
		["local_dentro", sp + Vector3(1.5, 2.2, 1.5), sp + Vector3(-1, 1.0, 12)],
	]
	for t in [[0.82, "noche"], [0.34, "dia"]]:
		c.sky.set_time(t[0])
		for v in views:
			if t[1] == "dia" and not (v[0].ends_with("dentro") or v[0] == "avenida"):
				continue
			c.player.position = Vector3(v[2].x, 0, v[2].z)   # lejos de la cámara: que no tape la vista
			c.sky.indoors = 1.0 if v[0].ends_with("dentro") else 0.0
			c.sky.set_time(t[0])
			c.camera.global_position = v[1]
			c.camera.look_at(v[2])
			c.update_lights()
			await m.frames(4)
			await m.shot(ProjectSettings.globalize_path(OUT + "luz_%s_%s.png" % [t[1], v[0]]))
