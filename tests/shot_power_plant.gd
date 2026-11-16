extends RefCounted
## La planta eléctrica: falla por primera vez (cinemática: cara del operario, la planta, el mentor), el chip del HUD,
## la caseta para pagar, el pago y la ciudad de noche con apagón.
## Godot --path . -- --scenario=res://tests/shot_power_plant.gd
const OUT := "res://tests/shots/"


func run(m) -> void:
	var c: City = m.city
	m.app.slot = 3
	m.app.new_game("normal")
	await m.frames(5)
	var g: Game = m.app.game
	c.tutorial.stop()
	g.tutorial_step = -1
	c.sky_lock = 0.62   # atardecer
	m.app.modal = null
	c.overlays.hide()
	c.teleport(Vector3(-140, 0, 8.5), 0.0, "")
	await m.frames(10)
	# Planta sana desde la calle
	c.power_scene.phase = ""
	await m.frames(5)
	g.cash = 50000.0
	g.best_month = 30000.0
	g.power_fail = true
	g.power_until = g.day
	g.blackout = true
	var shots := [["face", 0.4], ["face2", 2.6], ["plant", 1.0], ["plant2", 3.6], ["mentor", 1.2]]
	await m.frames(2)
	print("cinemática activa: ", c.power_scene.active())
	var last := ""
	for sh in shots:
		var ph: String = sh[0].trim_suffix("2")
		while c.power_scene.phase != ph or c.power_scene.t < sh[1]:
			await m.frames(1)
		await m.shot(ProjectSettings.globalize_path(OUT + "planta_%s.png" % sh[0]))
	# Pasa las frases del mentor
	for i in 12:
		c.power_scene.advance()
		await m.frames(2)
	var t0 := Time.get_ticks_msec()
	while c.power_scene.active() and Time.get_ticks_msec() - t0 < 4000:
		await m.frames(1)
	print("terminó: ", not c.power_scene.active(), " · intro vista: ", g.power_intro, " · pausa: ", m.app.paused)
	m.app.paused = false
	c.teleport(PowerPlant.PAY_SPOT, 0.0, "")
	await m.frames(10)
	print("aviso en la caseta: ", c.hud.prompt)
	await m.shot(ProjectSettings.globalize_path(OUT + "planta_caseta.png"))
	var cash0 := g.cash
	var r := g.pay_power()
	print("pago: ", r, " · costo: ", cash0 - g.cash, " · días: ", g.power_days_left(), " · fallando: ", g.power_failing())
	# Noche con apagón en la avenida
	g.power_until = g.day
	g.blackout = true
	c.sky_lock = 0.85
	c.teleport(Vector3(-20, 0, -8), 0.0, "")
	await m.frames(90)
	await m.shot(ProjectSettings.globalize_path(OUT + "planta_noche_apagon.png"))
	g.blackout = false
	g.power_until = g.day + 30
	await m.frames(90)
	await m.shot(ProjectSettings.globalize_path(OUT + "planta_noche_luz.png"))
	# Vista de la planta fallando desde arriba
	g.power_until = g.day
	c.sky_lock = 0.4
	m.set_process(false)
	c.camera.global_position = Vector3(-138, 14, 2)
	c.camera.look_at(Vector3(-156, 4, 18))
	await m.frames(20)
	await m.shot(ProjectSettings.globalize_path(OUT + "planta_vista.png"))
