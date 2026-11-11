extends RefCounted
## Centro comercial de la playa, gente paseando adentro, vitrinas de rivales, el relojito del rival que no quiso
## vender, la vista de decorar y el tutorial nuevo (sin puesto al empezar). Correr con:
## Godot --path . -- --scenario=res://tests/shot_beach_mall.gd

const OUT := "res://tests/shots/"


func cam(c: City, pos: Vector3, look: Vector3) -> void:
	c.camera.global_position = pos
	c.camera.look_at(look)
	c.update_lights()


## Deja correr la ciudad unos cuadros con la cámara quieta donde la puso `cam` (el jugador se queda donde está).
func live(m, c: City, n: int) -> void:
	var p := c.camera.global_position
	var t := c.camera.global_transform
	for i in n:
		for mall in c.malls:
			mall.update(1.0 / 30.0)
		await m.frames(1)
	c.camera.global_transform = t


## Lleva el mouse a un punto de la pantalla virtual de 1280 × 760 (la que usan las interfaces).
func mouse_to(m, ui: ImUI, v: Vector2) -> void:
	var o := ui.to_virtual(Vector2.ZERO)
	var one := ui.to_virtual(Vector2(1000, 1000))
	var k := (one - o) / 1000.0
	m.get_viewport().warp_mouse((v - o) / k)


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
	m.app.paused = true
	print("bolsa en modo normal: ", g.investing())
	# Los dos centros comerciales
	print("comprar avenida: ", g.buy_mall(0), " · playa: ", g.buy_mall(1))
	var keys := ["cafe", "pan", "burger", "ropa", "tech"]
	for i in 9:
		var res: Array = g.open_location(keys[i % 5], i % 2, null, 16 + i)
		assert(res[0], res[1])
		print("  ", res[1])
	for i in 6:
		g.open_location(keys[(i + 2) % 5], 1, null, i * 2)
	g.rival_mall["27"] = "burger"
	g.rival_mall["3"] = "cafe"
	g.products.burger.competitors += 1
	g.products.cafe.competitors += 1
	print("libres: ", g.free_mall_slots().size(), " · etiqueta playa: ", Game.place_label(g.locations[-7]))
	g.open_location("cafe", 1, 1)
	c.sync(g)
	m.ui.set_visible(false)
	c.hud.ui.set_visible(false)
	c.sky.set_time(0.42)
	m.set_process(false)
	var e := Mall.entrance(1)
	print("entrada playa ", e, " yaw ", Mall.entrance_yaw(1), " rect ", Mall.world_rect(1))
	# Fachada desde la arena
	cam(c, e + Vector3(-16, 6, -14), e + Vector3(0, 4, 8))
	await m.frames(6)
	await m.shot(ProjectSettings.globalize_path(OUT + "playa_cc_fachada.png"))
	cam(c, Vector3(60, 32, -20), Vector3(88, 0, 22))
	await m.frames(6)
	await m.shot(ProjectSettings.globalize_path(OUT + "playa_cc_aire.png"))
	# Adentro, con gente paseando
	c.player.position = Blueprints.to_world(Mall.PLOTS[1], 0, 4.0)
	cam(c, Blueprints.to_world(Mall.PLOTS[1], 0, 3.0, 2.6), Blueprints.to_world(Mall.PLOTS[1], 0, 28, 1.5))
	await live(m, c, 240)
	print("gente adentro: ", c.malls[1].shoppers.size())
	await m.shot(ProjectSettings.globalize_path(OUT + "playa_cc_pasillo.png"))
	# El de la avenida (más grande), con su gente
	c.player.position = Blueprints.to_world(Mall.PLOT, 0, 4.0)
	cam(c, Blueprints.to_world(Mall.PLOT, 0, 3.0, 2.6), Blueprints.to_world(Mall.PLOT, 0, 28, 1.5))
	await live(m, c, 240)
	print("gente en el de la avenida: ", c.malls[0].shoppers.size())
	await m.shot(ProjectSettings.globalize_path(OUT + "cc_pasillo_gente.png"))
	# Vitrina del rival, el rechazo y el relojito
	m.ui.set_visible(true)
	c.hud.ui.set_visible(true)
	var rs: Dictionary = c.malls[1].slots[11]
	c.player.position = rs.front
	m.set_process(true)
	m.app.paused = false
	await m.frames(4)
	print("aviso frente al rival: ", c.hud.prompt)
	c.refuse(-1, 27)
	await m.frames(4)
	print("aviso después del no: '", c.hud.prompt, "' · reloj ", c.refuse_near())
	m.app.paused = true
	var spot: Vector3 = c.refuse_near()[1]
	var inward := (Blueprints.to_world(Mall.PLOTS[1], 0, 15) - spot).normalized()
	c.player.position = spot + inward * 3.5
	c.yaw = rad_to_deg(atan2(spot.x - c.player.position.x, spot.z - c.player.position.z))
	await m.frames(8)
	await m.shot(ProjectSettings.globalize_path(OUT + "rival_reloj.png"))
	# Tablet: Expansión con la playa
	m.app.tab = "expansion"
	m.app.exp_mall = 1
	c.overlays.show("admin")
	await m.frames(6)
	await m.shot(ProjectSettings.globalize_path(OUT + "expansion_playa.png"))
	c.overlays.hide()
	c.overlays.show("mapa")
	await m.frames(6)
	await m.shot(ProjectSettings.globalize_path(OUT + "mapa_dos_cc.png"))
	c.overlays.hide()
	# Decorar: local de la avenida (terreno 2)
	var loc = null
	for l in g.locations:
		if Game.plot_of(l) == 1:
			loc = l
	c.player.position = Blueprints.to_world(City.plot_pos(1), 0, -4)
	c.open_decor(loc.id)
	var rows := {"": -1, "plantas": 0, "letrero": 1, "terraza": 2, "aire": 3}
	for key in rows:
		var r: int = rows[key]
		var at := Vector2(62 + (r % 3) * 182.7 + 85, 110 + (r / 3) * 212 + 70)
		mouse_to(m, m.ui, Vector2(900, 700) if r < 0 else at)
		for i in 50:
			await m.frames(1)
		await m.shot(ProjectSettings.globalize_path(OUT + "decorar_%s.png" % (key if key else "fachada")))
	# Clic en el letrero: queda elegido con la barra para comprarlo, aunque el mouse se vaya
	mouse_to(m, m.ui, Vector2(62 + 182.7 + 85, 180))
	await m.frames(2)
	m.mouse_clicked = true
	await m.frames(2)
	mouse_to(m, m.ui, Vector2(900, 700))
	for i in 50:
		await m.frames(1)
	print("elegido: ", c.overlays.decor_pick, " · vista previa: ", c.decor_store.preview)
	await m.shot(ProjectSettings.globalize_path(OUT + "decorar_elegido.png"))
	c.close_decor()
	await m.frames(3)
	print("después de cerrar: ventana ", c.overlays.mode, " · vista previa ", c.decor_store.preview, " · instalados ", loc.upgrades)
	c.overlays.hide()
	# Partida nueva del jugador: sin puesto y con el tutorial
	m.app.new_game("normal", false)
	await m.frames(5)
	g = m.app.game
	print("partida nueva: sucursales ", g.locations.size(), " · caja ", g.cash)
	c.tutorial.start()
	c.player.position += Vector3(6, 0, 0)
	await m.frames(30)
	print("paso: ", Tutorial.STEPS[c.tutorial.step])
	await m.shot(ProjectSettings.globalize_path(OUT + "tutorial_terreno.png"))
	c.overlays.show("lote", 1)
	await m.frames(30)
	print("paso: ", Tutorial.STEPS[c.tutorial.step])
	await m.shot(ProjectSettings.globalize_path(OUT + "tutorial_comprar.png"))
	c.overlays.hide()
	print("abrir puesto: ", g.open_location("cafe", 0, 1))
	await m.frames(30)
	print("paso: ", Tutorial.STEPS[c.tutorial.step])
	c.tutorial.stop()
