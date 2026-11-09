extends RefCounted
## Fotos por dentro de un local de cada negocio (y megatiendas), de día y con clientes, para revisar la decoración
## interior. También la fachada con los artículos comprados (letrero luminoso, plantas, terraza...).
## Godot --path . -- --scenario=res://tests/shot_interior.gd

const OUT := "res://tests/shots/"


func run(m) -> void:
	var c: City = m.city
	m.app.slot = 3
	m.app.new_game("normal")
	await m.frames(5)
	var g: Game = m.app.game
	g.cash += 9000000
	for k in ["pan", "burger", "ropa", "tech"]:
		g.unlock(k)
	var plan := [[1, "cafe", 1], [2, "pan", 1], [3, "burger", 1], [4, "ropa", 1], [5, "tech", 1], [6, "cafe", 2], [10, "ropa", 2], [11, "burger", 2]]
	for p in plan:
		g.open_location(p[1], p[2], p[0])
	for loc in g.locations:
		loc.employees = D.SIZES[loc.size].max_emp
	# Fachada decorada: todos los artículos en el local de hamburguesas
	for u in D.UPGRADES:
		g.buy_decor(g.locations[3], u.key)
	g.build_factory("cafe")
	g.build_solar("cafe")
	g.build_factory("pan")
	g.buy_decor(g.locations[1], "plantas")
	g.buy_decor(g.locations[1], "terraza")
	c.sync(g)
	c.tutorial.active = false
	m.app.speed = 2
	await m.frames(240)   # que lleguen clientes
	m.app.paused = true
	m.ui.set_visible(false)
	c.hud.ui.set_visible(false)
	m.set_process(false)
	c.sky.set_time(0.34)
	for p in plan:
		var i: int = p[0]
		var size: int = p[2]
		var depth := 12.0 if size == 1 else 18.0
		var inside := Blueprints.to_world(City.PLOTS[i], 3.0 if size == 1 else 5.5, 2.8)
		var look := Blueprints.to_world(City.PLOTS[i], -2.5, depth * 0.85)
		c.camera.global_position = inside + Vector3(0, 2.3 if size == 1 else 3.2, 0)
		c.camera.look_at(look + Vector3(0, 1.0, 0))
		c.update_lights()
		await m.frames(4)
		await m.shot(ProjectSettings.globalize_path(OUT + "interior_%s_%d.png" % [p[1], size]))
	for i in [3, 2]:
		var front := Blueprints.to_world(City.PLOTS[i], 4.0, -6.5)
		c.camera.global_position = front + Vector3(0, 2.4, 0)
		c.camera.look_at(Blueprints.to_world(City.PLOTS[i], 0, 3) + Vector3(0, 2.4, 0))
		c.update_lights()
		await m.frames(4)
		await m.shot(ProjectSettings.globalize_path(OUT + "fachada_%d.png" % i))
	c.sky.set_time(0.82)
	c.camera.global_position = Blueprints.to_world(City.PLOTS[3], 5.0, -8.0) + Vector3(0, 2.4, 0)
	c.camera.look_at(Blueprints.to_world(City.PLOTS[3], 0, 3) + Vector3(0, 2.4, 0))
	c.update_lights()
	await m.frames(4)
	await m.shot(ProjectSettings.globalize_path(OUT + "fachada_noche.png"))
	c.sky.set_time(0.34)
	c.camera.global_position = Vector3(-80, 9, -30)
	c.camera.look_at(Vector3(-90, 3, -52))
	c.update_lights()
	await m.frames(4)
	await m.shot(ProjectSettings.globalize_path(OUT + "fabricas.png"))
	c.camera.global_position = Vector3(-96, 14, -38)
	c.camera.look_at(Vector3(-96, 5, -53))
	c.update_lights()
	await m.frames(4)
	await m.shot(ProjectSettings.globalize_path(OUT + "fabrica_solar.png"))
