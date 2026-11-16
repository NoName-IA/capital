extends RefCounted
## La huelga: muchos batazos → avisos → huelga; la protesta frente a la oficina, la cinemática y las tres salidas.
## Godot --path . -- --scenario=res://tests/shot_strike.gd
const OUT := "res://tests/shots/"


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
	c.sky_lock = 0.45
	g.cash = 100000.0
	var loc: Dictionary = g.locations[0]
	g.hire(loc)
	c.sync(g)
	await m.frames(5)
	# 90 batazos: avisos, pero todavía no hay huelga
	for i in 45:
		g.bat_hit()
	g.step_day()
	print("rencor: ", g.grudge, " · aviso: ", g.strike_warn, " · huelga: ", g.strike)
	for i in 6:
		g.bat_hit()
	g.step_day()
	print("rencor: ", g.grudge, " · huelga: ", g.strike, " · capacidad: ", g.capacity(loc), " · fuera: ", g.staff_out())
	var shots := [["crowd", 0.5], ["crowd2", 2.6], ["leader", 0.6], ["talk", 1.5]]
	for sh in shots:
		var ph: String = sh[0].trim_suffix("2")
		var t0 := Time.get_ticks_msec()
		while (c.strike_scene.phase != ph or c.strike_scene.t < sh[1]) and Time.get_ticks_msec() - t0 < 15000:
			await m.frames(1)
		await m.shot(ProjectSettings.globalize_path(OUT + "huelga_%s.png" % sh[0]))
	for i in 10:
		if c.strike_scene.phase == "choice":
			break
		c.strike_scene.advance()
		await m.frames(2)
	await m.frames(20)
	await m.shot(ProjectSettings.globalize_path(OUT + "huelga_choice.png"))
	print("empleados en el local: ", c.stores.values()[0].staff.size())
	# Ignorar: sigue la huelga y queda el delegado
	c.strike_scene._pick("ignorar")
	await m.frames(20)
	await m.shot(ProjectSettings.globalize_path(OUT + "huelga_ignorar.png"))
	while c.strike_scene.active():
		await m.frames(1)
	print("después de ignorar: huelga ", g.strike, " · pausa ", m.app.paused)
	m.app.paused = false
	c.teleport(StrikeScene.leader_pos() + Vector3(0, 0, -2.5), 0.0, "")
	await m.frames(10)
	print("aviso: ", c.hud.prompt)
	await m.shot(ProjectSettings.globalize_path(OUT + "huelga_calle.png"))
	# Volver a hablar y subir sueldos
	var w0 := g.wage_daily()
	c.strike_scene.start(true)
	while c.strike_scene.phase != "talk":
		await m.frames(1)
	for i in 6:
		c.strike_scene.advance()
		await m.frames(2)
	c.strike_scene._pick("subir")
	await m.frames(40)
	await m.shot(ProjectSettings.globalize_path(OUT + "huelga_subir.png"))
	while c.strike_scene.active():
		await m.frames(1)
	m.app.paused = false
	c.sync(g)
	await m.frames(5)
	print("subir: huelga ", g.strike, " · sueldo ", w0, " → ", g.wage_daily(), " · empleados ", c.stores.values()[0].staff.size(), " · protesta ", c.strike_scene.crowd != null)
	# Otra huelga y despedir a todos
	for i in 51:
		g.bat_hit()
	g.step_day()
	while c.strike_scene.phase != "crowd":
		await m.frames(1)
	c.strike_scene._to("choice")
	await m.frames(5)
	var cash0 := g.cash
	c.strike_scene._pick("despedir")
	await m.frames(50)
	await m.shot(ProjectSettings.globalize_path(OUT + "huelga_despedir.png"))
	while c.strike_scene.active():
		await m.frames(1)
	print("despedir: costo ", cash0 - g.cash, " · fuera ", g.staff_out(), " · hasta ", g.rehire_until, " (hoy ", g.day, ")")
	for i in 6:
		g.step_day()
	print("después de 6 días: fuera ", g.staff_out())
