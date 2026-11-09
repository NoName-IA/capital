extends RefCounted
## Las pantallas nuevas en inglés (Expansión, Rivales, Personal, vitrina, mapa) para revisar las traducciones.
## Godot --path . -- --scenario=res://tests/shot_en_new.gd

const OUT := "res://tests/shots/"


func run(m) -> void:
	var c: City = m.city
	m.app.slot = 3
	m.app.new_game("normal")
	await m.frames(5)
	Lang.use("en")
	var g: Game = m.app.game
	g.cash += 9000000
	for k in ["pan", "burger"]:
		g.unlock(k)
	c.tutorial.active = false
	g.buy_mall()
	for i in 4:
		g.open_location(["cafe", "pan", "burger"][i % 3], 1, null, i)
	for i in 3:
		g.open_location("cafe", 1)
	g.open_franchise("cafe")
	for i in 40:
		g.step_day()
		g.pending_choice = null
		g.micro = null
	g.micro = g.build_micro("tarde")
	c.sync(g)
	m.app.paused = true
	for tab in ["expansion", "rivales", "personal"]:
		m.app.tab = tab
		c.overlays.show("admin")
		await m.frames(5)
		await m.shot(ProjectSettings.globalize_path(OUT + "en_%s.png" % tab))
	c.overlays.hide()
	c.overlays.show("vitrina", 8)
	await m.frames(5)
	await m.shot(ProjectSettings.globalize_path(OUT + "en_vitrina.png"))
	c.overlays.hide()
	await m.frames(5)
	await m.shot(ProjectSettings.globalize_path(OUT + "en_hud.png"))
	Lang.use("es")
