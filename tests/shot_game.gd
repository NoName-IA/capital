extends RefCounted
## Juega un rato: partida nueva, locales, clientes, oficina, armario, pausa, trofeos, estrategia y noche.

const OUT := "res://tests/shots/"


func shot(m, name: String) -> void:
	await m.frames(3)
	await m.shot(ProjectSettings.globalize_path(OUT + name + ".png"))


func run(m) -> void:
	await m.frames(10)
	await shot(m, "g0_menu")
	m.app.slot = 3
	m.app.new_game("normal")
	await m.frames(5)
	var c: City = m.city
	var g: Game = m.app.game
	g.next_choice_day = 100000
	g.cash += 2000000
	g.unlock("pan")
	g.unlock("burger")
	g.open_location("cafe", 1, 2)
	g.open_location("pan", 2, 3)
	g.open_location("burger", 0, 8)
	g.rival_plots["6"] = "cafe"
	g.products.cafe.competitors += 1
	g.wardrobe = true
	g.owned_items.append("hat=copa")
	g.look["hat"] = "copa"
	g.look["jacket"] = "blazer"
	g.look["glasses"] = true
	c.apply_look()
	for i in 40:
		g.step_day()
	m.app.speed = 0
	c.sync(g)
	await m.frames(5)
	await shot(m, "g1_oficina")
	c.player.position = Vector3(-11, 0, 5)
	c.yaw = 20
	c.pitch = 12
	c.zoom_target = 8
	for i in 240:
		await m.frames(1)
	await shot(m, "g2_avenida")
	c.player.position = Vector3(121, 0, -3)
	c.yaw = 0
	c.pitch = 14
	await m.frames(60)
	await shot(m, "g3_playa")
	c.go_to_office()
	await m.frames(10)
	c.player.position = c.hq_spots.wardrobe
	c.yaw = 0
	c.open_custom()
	for i in 60:
		await m.frames(1)
	await shot(m, "g4_armario")
	c.overlays.shop_tab = "sombreros"
	for i in 30:
		await m.frames(1)
	await shot(m, "g5_armario_sombreros")
	c.close_custom()
	c.open_pause()
	await m.frames(20)
	await shot(m, "g6_pausa")
	c.close_pause()
	c.show_trophies()
	await m.frames(20)
	await shot(m, "g7_trofeos")
	c.overlays.hide()
	c.overlays.show("estrategia")
	await m.frames(20)
	await shot(m, "g8_estrategia")
	c.overlays.hide()
	c.overlays.show("admin")
	m.app.tab = "negocios"
	await m.frames(20)
	await shot(m, "g9_celular")
	c.overlays.hide()
	g.add_news("x", "good", "rank", "Emprendedor")
	g.cash = -9000
	g.overdraft_days = 4
	c.player.position = Vector3(30, 0, -4)
	c.settings.day_night = false
	await m.frames(30)
	await shot(m, "g10_avisos_peligro")
	g.cash = 50000
	g.overdraft_days = 0
	c.settings.day_night = true
	m.app.acc = 0.97
	c.player.position = Vector3(-60, 0, -3)
	c.yaw = -30
	await m.frames(30)
	await shot(m, "g11_noche")
