extends RefCounted
## La tablet sin Guardar, Nuevo juego ni Menú principal. Godot --path . -- --scenario=res://tests/shot_tablet_side.gd
func run(m) -> void:
	var c: City = m.city
	m.app.slot = 3
	m.app.new_game("normal")
	await m.frames(5)
	c.tutorial.active = false
	c.overlays.show("admin")
	await m.frames(15)
	await m.shot(ProjectSettings.globalize_path("res://tests/shots/tablet_lateral.png"))
