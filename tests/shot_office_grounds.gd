extends RefCounted
## Vista de la oficina desde arriba con toda la decoración. Godot --path . -- --scenario=res://tests/shot_office_grounds.gd
const OUT := "res://tests/shots/"


func run(m) -> void:
	var c: City = m.city
	m.app.slot = 3
	m.app.new_game("normal")
	await m.frames(5)
	var g: Game = m.app.game
	c.tutorial.stop()
	c.sky_lock = 0.45
	g.cash += 400000
	for k in D.OFFICE_DECOR.map(func(u): return u.key):
		g.buy_office_decor(k)
	c.sync(g)
	m.app.modal = null
	c.overlays.hide()
	m.set_process(false)
	c.camera.global_position = Blueprints.to_world(City.HQ, -4, -14, 22)
	c.camera.look_at(Blueprints.to_world(City.HQ, -4, 6, 0))
	await m.frames(8)
	await m.shot(ProjectSettings.globalize_path(OUT + "oficina_terreno.png"))
	c.camera.global_position = Blueprints.to_world(City.HQ, -20, -8, 9)
	c.camera.look_at(Blueprints.to_world(City.HQ, -2, 8, 0))
	await m.frames(8)
	await m.shot(ProjectSettings.globalize_path(OUT + "oficina_terreno2.png"))
