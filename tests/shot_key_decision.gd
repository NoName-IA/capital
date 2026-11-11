extends RefCounted
## La decisión importante del rumbo de la marca, como la ve el jugador. Godot --path . -- --scenario=res://tests/shot_key_decision.gd

func run(m) -> void:
	var c: City = m.city
	m.app.slot = 3
	m.app.new_game("normal")
	await m.frames(5)
	var g: Game = m.app.game
	c.tutorial.active = false
	g.rank = 2
	g._maybe_dilemma()
	m.app.modal = "dilema"
	await m.frames(20)
	await m.shot(ProjectSettings.globalize_path("res://tests/shots/decision_rumbo.png"))
	g.resolve_choice(0)
	g.rank = 3
	g._maybe_dilemma()
	await m.frames(20)
	await m.shot(ProjectSettings.globalize_path("res://tests/shots/decision_rivales.png"))
