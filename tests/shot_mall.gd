extends RefCounted
## Centro comercial y franquicias: llena la avenida, comprueba que sin centro comercial no se puede abrir otra
## sucursal, compra el centro comercial, abre tiendas en las vitrinas, vende franquicias y saca fotos (terreno en
## obra, fachada de día y de noche, pasillo, vitrina, tablet y mapa). Al final carga una copia de las partidas
## guardadas (sin guardar nada) para ver cómo se acomodan las sucursales que no tenían terreno.
## Godot --path . -- --scenario=res://tests/shot_mall.gd

const OUT := "res://tests/shots/"


func cam(c: City, pos: Vector3, look: Vector3) -> void:
	c.camera.global_position = pos
	c.camera.look_at(look)
	c.update_lights()


func run(m) -> void:
	var c: City = m.city
	m.app.slot = 3
	m.app.new_game("normal")
	await m.frames(5)
	var g: Game = m.app.game
	g.cash += 9000000
	for k in ["pan", "burger", "ropa", "tech"]:
		g.unlock(k)
	c.tutorial.active = false
	c.sync(g)
	m.app.paused = true
	m.ui.set_visible(false)
	c.hud.ui.set_visible(false)
	c.sky.set_time(0.4)
	m.set_process(false)
	# Terreno en obra
	cam(c, Mall.entrance() + Vector3(10, 6, 9), Mall.entrance() + Vector3(0, 2, -14))
	await m.frames(6)
	await m.shot(ProjectSettings.globalize_path(OUT + "mall_obra.png"))
	# Llenar la avenida
	var keys := ["cafe", "pan", "burger", "ropa", "tech"]
	var n := 0
	while g.free_plots():
		var res: Array = g.open_location(keys[n % 5], 1)
		assert(res[0], res[1])
		n += 1
	print("avenida llena con ", g.locations.size(), " sucursales")
	var res: Array = g.open_location("cafe", 1)
	print("sin centro comercial: ", res)
	assert(not res[0])
	res = g.buy_mall()
	print("comprar: ", res)
	assert(res[0])
	res = g.open_location("pan", 2)
	print("megatienda sin terreno: ", res)
	assert(not res[0])
	for i in 11:
		res = g.open_location(keys[i % 5], i % 2)
		assert(res[0], res[1])
	res = g.open_location("burger", 1, null, 14)
	print("vitrina elegida: ", res)
	print("vitrinas libres: ", g.free_mall_slots())
	var in_mall: Array = g.locations.filter(func(l): return Game.mall_of(l) >= 0)
	print("en el centro comercial: ", in_mall.size(), " · upgrade de un local en vitrina: ", g.upgrade_cost(in_mall.filter(func(l): return l.size == 1)[0]))
	# Franquicias
	for k in keys:
		for i in 2:
			var fr: Array = g.open_franchise(k)
			print("franquicia ", k, ": ", fr)
	for loc in g.locations:
		loc.employees = D.SIZES[loc.size].max_emp
	for d in 65:
		g.step_day()
		g.pending_choice = null
		g.micro = null
	for f in g.franchises:
		print("  ", f.city, " · ", f.product, " · calidad ", snappedf(f.quality, 0.01), " · regalías mes pasado ", f.last_royalty, " · esperadas/mes ", snappedf(g.franchise_royalty_monthly(f), 1))
	var mall_contrib := 0.0
	var ave_contrib := 0.0
	for loc in g.locations:
		if loc.last_contrib == null or loc.size != 1:
			continue
		if Game.mall_of(loc) >= 0:
			mall_contrib += loc.last_contrib
		else:
			ave_contrib += loc.last_contrib
	print("contribución locales: vitrinas ", mall_contrib, " · avenida ", ave_contrib)
	c.sync(g)
	m.set_process(true)
	await m.frames(10)
	m.set_process(false)
	print("choques del centro comercial: ", c.mall.collide.size(), " · bloqueado en el pasillo: ", c.blocked(Mall.entrance().x, -20.0),
			" · en la fuente: ", c.blocked(Mall.entrance().x, Blueprints.to_world(Mall.PLOT, 0, 15).z))
	# Fotos: fachada de día y de noche, pasillo y una vitrina
	c.sky.set_time(0.4)
	cam(c, Mall.entrance() + Vector3(12, 5, 12), Mall.entrance() + Vector3(0, 4, -10))
	await m.frames(6)
	await m.shot(ProjectSettings.globalize_path(OUT + "mall_fachada.png"))
	c.sky.set_time(0.85)
	await m.frames(6)
	await m.shot(ProjectSettings.globalize_path(OUT + "mall_noche.png"))
	c.sky.set_time(0.4)
	var door := Blueprints.to_world(Mall.PLOT, 0, 3.0)
	cam(c, door + Vector3(0, 2.6, 0), Blueprints.to_world(Mall.PLOT, 0, 28) + Vector3(0, 1.5, 0))
	await m.frames(6)
	await m.shot(ProjectSettings.globalize_path(OUT + "mall_pasillo.png"))
	cam(c, Blueprints.to_world(Mall.PLOT, 4, 10) + Vector3(0, 2.0, 0), Blueprints.to_world(Mall.PLOT, -13, 13) + Vector3(0, 1.4, 0))
	await m.frames(6)
	await m.shot(ProjectSettings.globalize_path(OUT + "mall_vitrina.png"))
	cam(c, Blueprints.to_world(Mall.PLOT, -4, 12) + Vector3(0, 2.0, 0), Blueprints.to_world(Mall.PLOT, 6, 30) + Vector3(0, 1.4, 0))
	await m.frames(6)
	await m.shot(ProjectSettings.globalize_path(OUT + "mall_fondo.png"))
	# El jugador adentro: aviso de E frente a una vitrina libre
	m.ui.set_visible(true)
	c.hud.ui.set_visible(true)
	var free_slot: int = g.free_mall_slots()[0]
	c.player.position = c.mall.slots[free_slot].front
	m.set_process(true)
	m.app.paused = false
	await m.frames(4)
	print("aviso: ", c.hud.prompt)
	m.app.paused = true
	# Tablet: pestaña Expansión
	m.app.tab = "expansion"
	c.overlays.show("admin")
	await m.frames(6)
	await m.shot(ProjectSettings.globalize_path(OUT + "tab_expansion.png"))
	c.overlays.hide()
	c.overlays.show("vitrina", free_slot)
	await m.frames(6)
	await m.shot(ProjectSettings.globalize_path(OUT + "vitrina_abrir.png"))
	c.overlays.hide()
	c.overlays.show("mapa")
	await m.frames(6)
	await m.shot(ProjectSettings.globalize_path(OUT + "mall_mapa.png"))
	c.overlays.hide()
	# Partidas viejas: se cargan de una copia en memoria (no se guarda nada)
	for slot in [1, 2, 3]:
		var path := "user://saves/partida_%d.json" % slot
		if not FileAccess.file_exists(path):
			continue
		var text := FileAccess.get_file_as_string(path)
		var before = JSON.parse_string(text)
		var old: Game = Game.from_json(text)
		var homeless := 0
		for loc in before.locations:
			if loc.get("plot") == null or int(loc.plot) < 0:
				homeless += 1
		print("partida %d: tenía %d sucursales (%d sin terreno) → ahora %d sucursales, %d franquicias, caja %s → %s" % [slot,
				before.locations.size(), homeless, old.locations.size(), old.franchises.size(), Fmt.short(float(before.cash)), Fmt.short(old.cash)])
		var used := {}
		for loc in old.locations:
			var key := "p%d" % Game.plot_of(loc) if Game.plot_of(loc) >= 0 else "m%d" % Game.mall_of(loc)
			assert(not used.has(key), "lugar repetido " + key)
			assert(Game.plot_of(loc) >= 0 or Game.mall_of(loc) >= 0, "sucursal sin lugar")
			used[key] = true
	print("OK centro comercial")
