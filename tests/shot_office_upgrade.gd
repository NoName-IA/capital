extends RefCounted
## «Mejorar oficina» con el antes y el después (fotos del edificio en el aspecto de ahora y el siguiente).
## Godot --path . -- --scenario=res://tests/shot_office_upgrade.gd
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
	for step in [[0, 1], [1, 2], [2, 3]]:
		g.office_look = step[0]
		c.sync(g)
		g.rank = 4
		g.cash = 2000000.0
		c.overlays.hide()
		await m.frames(3)
		c.remodel_office()
		var t0 := Time.get_ticks_msec()
		while (c.thumbs.get_hq_thumb(step[0], g.company) == null or c.thumbs.get_hq_thumb(step[1], g.company) == null) and Time.get_ticks_msec() - t0 < 8000:
			await m.frames(1)
		await m.frames(3)
		print("ventana: ", c.overlays.mode, " · ", c.overlays.question.get("office"))
		await m.shot(ProjectSettings.globalize_path(OUT + "oficina_mejora_%d.png" % step[1]))
	c.overlays.question = null
	c.overlays.hide()
