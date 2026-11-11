extends RefCounted
## La tarjeta «Así se gana» del tutorial. Godot --path . -- --scenario=res://tests/shot_value_card.gd
func run(m) -> void:
	var c: City = m.city
	m.app.slot = 3
	m.app.new_game("normal")
	await m.frames(5)
	c.tutorial.active = false
	c.overlays.show_value_card()
	await m.frames(15)
	await m.shot(ProjectSettings.globalize_path("res://tests/shots/tutorial_valor.png"))
