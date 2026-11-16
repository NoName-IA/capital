extends RefCounted
## La presidencia en cada rango: el lujo va subiendo (Tower.LUXURY). Una foto por rango, desde la misma esquina.
## Godot --path . -- --scenario=res://tests/shot_tower_luxury.gd
const OUT := "res://tests/shots/"


func run(m) -> void:
	var c: City = m.city
	m.app.slot = 3
	m.app.new_game("normal")
	await m.frames(5)
	var g: Game = m.app.game
	c.tutorial.stop()
	c.sync(g)
	c.sky_lock = 0.45
	m.app.modal = null
	c.overlays.hide()
	c.teleport(c.tower.w(Tower.ARRIVE), 0.0, "")
	for r in Tower.LUXURY.size():
		g.rank = r
		await m.frames(5)
		m.app.modal = null
		c.overlays.hide()
		print("rango ", r, " (", g.ranks()[r][1], ") → lujo ", c.tower.lux)
		m.set_process(false)
		c.camera.global_position = c.tower.w(Vector3(-6.5, 3.3, -6.3))
		c.camera.look_at(c.tower.w(Vector3(2, 0.6, 3)))
		await m.frames(4)
		await m.shot(ProjectSettings.globalize_path(OUT + "lujo_%d.png" % r))
		m.set_process(true)
	print("avisos: ", c.hud.notes.toasts.size() if "toasts" in c.hud.notes else "?")
