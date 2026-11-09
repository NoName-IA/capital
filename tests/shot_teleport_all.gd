extends RefCounted
## Viaja con el mapa a cada cosa que se puede elegir y revisa que quedes parado en un lugar libre, dentro de la
## ciudad y mirando al edificio. Saca una foto de algunos destinos.
## Godot --path . -- --scenario=res://tests/shot_teleport_all.gd

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
	g.open_location("pan", 2, 3)
	g.open_location("tech", 1, 7)
	g.open_location("ropa", 0, 12)
	g._rival_takes("burger", 5)
	g.build_factory("cafe")
	g.build_solar("cafe")
	g.build_factory("tech")
	g.acquire("cafe", City.PLOTS.size())   # el local fijo de la competencia del extremo este
	for i in 40:
		g.step_day()
		g.pending_choice = null
	c.sync(g)
	c.tutorial.active = false
	m.app.paused = true
	await m.frames(10)
	var bad := 0
	var items := CityMap.items(c)
	print("elementos en el mapa: ", items.size())
	for it in items:
		c.teleport(it.target, it.yaw, it.name)
		await m.frames(3)
		var p: Vector3 = c.player.position
		var free := not c.blocked(p.x, p.z, 0.38, p.y)
		var moved := p.distance_to(Vector3(it.target.x, p.y, it.target.z)) < 1.5
		if not free or not moved:
			bad += 1
		print("%-5s %-40s → (%.1f, %.1f, %.1f) libre:%s quedó:%s" % [it.kind, it.name, p.x, p.y, p.z, free, moved])
		if it.id in ["hq", "fcafe", "pier", "c" + "c0", "s%d" % City.PLOTS.size()]:
			await m.frames(20)
			await m.shot(ProjectSettings.globalize_path(OUT + "viaje_%s.png" % it.id))
	print("DESTINOS CON PROBLEMAS: ", bad)
