extends RefCounted
## Las decisiones urgentes con poco texto: qué pasa y, en cada opción, lo bueno (verde) y lo malo (rojo).
## Godot --path . -- --scenario=res://tests/shot_dilemmas.gd
const OUT := "res://tests/shots/"


func run(m) -> void:
	var c: City = m.city
	m.app.slot = 3
	m.app.new_game("normal", true)
	await m.frames(5)
	var g: Game = m.app.game
	g.open_location("cafe", 1)
	c.sync(g)
	for id in ["soborno", "influencer", "cartel", "patrocinio", "compra_rival", "rumbo"]:
		g.pending_choice = g.build_dilemma(id)
		m.app.modal = "dilema"
		c.overlays.show("admin")
		await m.frames(8)
		await m.shot(ProjectSettings.globalize_path(OUT + "dilema_" + id + ".png"))
	for id in Game.DILEMMAS + ["rumbo", "rivales"]:   # todas se arman bien y tienen lo bueno de cada opción
		var d: Dictionary = g.build_dilemma(id)
		var ok: bool = d.options.all(func(o): return o.good != "")
		print(id, ": ", d.text.length(), " letras · opciones ok ", ok)
	g.pending_choice = null
	m.app.modal = null
