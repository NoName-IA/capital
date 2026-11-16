extends RefCounted
## El minimapa muestra el logo de cada rival en su local.
## Godot --path . -- --scenario=res://tests/shot_minimap_logos.gd
const OUT := "res://tests/shots/"


func run(m) -> void:
	var c: City = m.city
	m.app.slot = 3
	m.app.new_game("normal")
	await m.frames(5)
	var g: Game = m.app.game
	c.tutorial.stop()
	g.cash += 3000000
	for k in ["pan", "burger", "ropa"]:
		g.unlock(k)
	g._rival_takes("burger", 5)
	g.plot_owner["5"] = "trump"
	c.sync(g)
	m.app.paused = true
	m.app.modal = null
	c.overlays.hide()
	c.teleport(Vector3(40, 0, -7), 90.0, "")
	await m.frames(40)
	m.app.modal = null
	c.overlays.hide()
	await m.frames(5)
	await m.shot(ProjectSettings.globalize_path(OUT + "minimap_logos.png"))
