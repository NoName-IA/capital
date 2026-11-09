extends RefCounted
## Minimapa, microdecisión en la HUD, mapa grande (M) con un edificio bajo el mouse, viaje con clic, y las pestañas
## nuevas de la tablet (Rivales, Personal, decorar, confirmación). Correr con:
## Godot --path . -- --scenario=res://tests/shot_map.gd

const OUT := "res://tests/shots/"


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
	g.cash += 3000000
	for k in ["pan", "burger", "ropa"]:
		g.unlock(k)
	g.open_location("cafe", 1, 1)
	g.open_location("pan", 2, 3)
	g.open_location("burger", 1, 9)
	g._rival_takes("burger", 5)
	g.plot_owner["5"] = "trump"
	for i in 70:
		g.step_day()
		g.pending_choice = null
		g.micro = null
	g.micro = g.build_micro("tarde")
	c.sync(g)
	m.app.paused = true
	c.tutorial.active = false
	await m.frames(30)
	await m.shot(ProjectSettings.globalize_path(OUT + "map_hud.png"))
	# Mapa grande con el mouse encima de un local tuyo
	c.overlays.show("mapa")
	await m.frames(3)
	var ui: ImUI = m.ui
	var view := Rect2(20, 86, 1240, 1240 * CityMap.WORLD.size.y / CityMap.WORLD.size.x)
	var scale := view.size.x / CityMap.WORLD.size.x
	var target: Rect2 = CityMap.plot_rect(City.plot_pos(3), 2)
	var at := CityMap.to_screen(view, CityMap.WORLD.get_center(), scale, target.get_center().x, target.get_center().y)
	mouse_to(m, ui, at)
	await m.frames(25)
	print("hover: ", c.overlays.map_hover)
	await m.shot(ProjectSettings.globalize_path(OUT + "map_big.png"))
	# Clic: viajar ahí
	m.mouse_clicked = true
	await m.frames(10)
	print("después del clic: ventana ", c.overlays.mode, " · jugador en ", c.player.position)
	await m.frames(20)
	await m.shot(ProjectSettings.globalize_path(OUT + "map_teleport.png"))
	# Pestañas nuevas
	c.overlays.show("admin")
	for t in ["rivales", "personal", "negocios"]:
		m.app.tab = t
		await m.frames(25)
		await m.shot(ProjectSettings.globalize_path(OUT + "tab_" + t + ".png"))
	m.app.decor_loc = g.locations[0].id
	m.app.modal = "decorar"
	await m.frames(10)
	await m.shot(ProjectSettings.globalize_path(OUT + "decorar.png"))
	m.app.ask("¿Construir una fábrica de café?", "Prueba de la ventana de confirmación.", "Sí, construir", g.build_factory.bind("cafe"))
	await m.frames(10)
	await m.shot(ProjectSettings.globalize_path(OUT + "confirmar.png"))
	m.app.modal = null
	m.app.confirm = null
	c.overlays.hide()
	# Comprar el local de la competencia que tienes enfrente
	c.buy_competitor("burger", 5)
	await m.frames(10)
	await m.shot(ProjectSettings.globalize_path(OUT + "comprar_rival.png"))
