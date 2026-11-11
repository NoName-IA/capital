extends RefCounted
## Terrenos del valle camino al túnel: letreros SE VENDE, comprar uno, un rival que compra otro y caminar adentro.
## Godot --path . -- --scenario=res://tests/shot_valley.gd
const OUT := "res://tests/shots/"


func run(m) -> void:
	var c: City = m.city
	m.app.slot = 3
	m.app.new_game("normal")
	await m.frames(5)
	var g: Game = m.app.game
	g.cash += 3000000
	c.tutorial.active = false
	m.app.paused = true
	c.sync(g)
	await m.frames(3)
	print("terrenos libres: ", g.free_plots(), " · letreros en el valle: ", D.VALLEY_PLOTS.filter(func(i): return c.lots.has(i)))
	m.set_process(false)
	c.sky.set_time(0.45)
	c.camera.global_position = Vector3(-104, 14, -26)
	c.camera.look_at(Vector3(-135, 0, 0))
	c.update_lights()
	await m.frames(6)
	await m.shot(ProjectSettings.globalize_path(OUT + "valle_letreros.png"))
	m.set_process(true)
	g.unlock("pan")
	print("comprar en el valle: ", g.open_location("pan", 1, 19), " · ", g.open_location("cafe", 2, 14))
	g._rival_takes("burger", 20)
	c.sync(g)
	await m.frames(10)
	m.set_process(false)
	c.camera.global_position = Vector3(-104, 14, -26)
	c.camera.look_at(Vector3(-135, 0, 0))
	c.update_lights()
	await m.frames(6)
	await m.shot(ProjectSettings.globalize_path(OUT + "valle_locales.png"))
	c.camera.global_position = Vector3(-118, 4, 4)
	c.camera.look_at(Vector3(-121, 2, 20))
	c.update_lights()
	await m.frames(6)
	await m.shot(ProjectSettings.globalize_path(OUT + "valle_local_cerca.png"))
	m.set_process(true)
	var door: Vector3 = Blueprints.to_world(City.plot_pos(19), 0, 3.0)
	print("bloqueado en la puerta del local del valle: ", c.blocked(door.x, door.z), " · tienda ", c.stores.has(19))
	c.overlays.show("mapa")
	await m.frames(8)
	await m.shot(ProjectSettings.globalize_path(OUT + "valle_mapa.png"))
	c.overlays.hide()
