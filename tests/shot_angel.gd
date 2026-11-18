extends RefCounted
## Ángel: entra subiendo, habla con gestos, la oferta, aceptar (festeja) y otra partida diciendo que no.
## Godot --path . -- --scenario=res://tests/shot_angel.gd
const OUT := "res://tests/shots/"


func _setup(m) -> Game:
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
	g.cash = 30000.0
	c.sync(g)
	await m.frames(5)
	g.play_seconds = float(D.ANGEL.stuck_min) * 60.0 + 1.0
	g.step_day()
	var t0 := Time.get_ticks_msec()
	while not c.angel_scene.active() and Time.get_ticks_msec() - t0 < 10000:
		await m.frames(1)
	return g


func run(m) -> void:
	var c: City = m.city
	var g: Game = await _setup(m)
	var a = c.angel_scene
	print("oferta: ", g.angel)
	await m.frames(12)
	await m.shot(ProjectSettings.globalize_path(OUT + "angel_entra.png"))
	await m.frames(40)
	await m.shot(ProjectSettings.globalize_path(OUT + "angel_habla.png"))
	a.advance()
	a.advance()
	a.advance()
	a.advance()
	await m.frames(25)
	await m.shot(ProjectSettings.globalize_path(OUT + "angel_habla2.png"))
	while a.phase == "talk":
		a.advance()
		await m.frames(1)
	await m.frames(30)
	await m.shot(ProjectSettings.globalize_path(OUT + "angel_oferta.png"))
	var cash0 := g.cash
	var v0 := g.valuation()
	a._pick(true)
	await m.frames(40)
	await m.shot(ProjectSettings.globalize_path(OUT + "angel_acepta.png"))
	print("caja: +", g.cash - cash0, " · valor: +", g.valuation() - v0, " · meses: ", g.angel_months)
	while a.active():
		await m.frames(1)
	await m.frames(10)
	await m.shot(ProjectSettings.globalize_path(OUT + "angel_despues.png"))
	print("pausa: ", m.app.paused)
	# Otra partida: decir que no
	g = await _setup(m)
	a = c.angel_scene
	while a.phase == "talk":
		a.advance()
		await m.frames(1)
	await m.frames(10)
	a._pick(false)
	await m.frames(40)
	await m.shot(ProjectSettings.globalize_path(OUT + "angel_no.png"))
