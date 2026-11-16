extends RefCounted
## La alfombra roja de la entrada de la oficina (comprada), vista desde la vereda.
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
	c.sky_lock = 0.45
	g.cash += 1000000
	g.buy_office_decor("alfombra")
	c.sync(g)
	c.teleport(Blueprints.to_world(City.HQ, 0, -6.0), 0.0, "")
	c.pitch = 25.0
	await m.frames(30)
	await m.shot(ProjectSettings.globalize_path(OUT + "rug_alfombra.png"))
