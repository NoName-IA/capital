extends RefCounted
## El tutorial: la bienvenida, los pasos guiados haciéndolos uno por uno y la tarjeta final de cómo ganar.

const OUT := "res://tests/shots/"


func shot(m, name: String) -> void:
	await m.frames(3)
	await m.shot(ProjectSettings.globalize_path(OUT + "tut_" + name + ".png"))


func run(m) -> void:
	var c: City = m.city
	m.app.new_game("normal")
	await m.frames(5)
	var g: Game = m.app.game
	g.next_choice_day = 100000
	c.hud.help_timer = 0
	c.open_tutorial()
	await m.frames(10)
	await shot(m, "0_bienvenida")
	c.overlays.tutorial_next()
	var t: Tutorial = c.tutorial
	await m.frames(30)
	await shot(m, "1_caminar")
	c.player.position += Vector3(5, 0, 0)
	await m.frames(50)
	c.vy = 8.0
	await m.frames(60)
	c.yaw = 180.0
	await m.frames(40)
	await shot(m, "2_puesto_flecha")
	var s: Store = t._stall()
	c.player.position = s.spots.serve + Vector3(0, 0, -3)
	c.yaw = 0.0
	await m.frames(50)
	await shot(m, "3_puesto_cerca")
	c.player.position = s.spots.serve
	await m.frames(10)
	c.start_serving(s)
	await m.frames(50)
	c.stop_serving()
	await m.frames(10)
	await shot(m, "4_tablet")
	c.overlays.show("admin")
	m.app.tab = "negocios"
	await m.frames(50)
	await shot(m, "5_valor")
	print("tarjeta: ", c.overlays.mode, " pausa=", m.app.paused)
	c.overlays.tutorial_next()
	await m.frames(50)
	print("después de Entendido: ", c.overlays.mode, " paso ", t.STEPS[t.step], " pausa=", m.app.paused)
	await shot(m, "6_precio")
	m.app.tab = "mercado"
	await m.frames(10)
	await shot(m, "6b_precio_boton")
	g.products.cafe.price += 0.5
	await m.frames(50)
	m.app.tab = "negocios"
	await m.frames(10)
	await shot(m, "7_contratar")
	g.hire(g.locations[0])
	await m.frames(50)
	c.overlays.hide()
	await m.frames(10)
	await shot(m, "8_tiempo")
	m.app.speed = 1
	m.app.paused = false
	await m.frames(50)
	c.go_to_office()
	await m.frames(50)
	print("paso: ", t.STEPS[t.step])
	c.overlays.show("lote", c.lots.keys()[0])
	await m.frames(50)
	if c.overlays.mode == "lote":
		c.overlays.hide()
	await m.frames(30)
	print("FIN activo=", t.active, " overlay=", c.overlays.mode)
	await shot(m, "9_como_ganar")
