extends RefCounted
## El tutorial: la bienvenida y los pasos guiados, haciéndolos uno por uno (con capturas del panel y la flecha).

const OUT := "res://tests/shots/"


func shot(m, name: String) -> void:
	await m.frames(3)
	await m.shot(ProjectSettings.globalize_path(OUT + "tut_" + name + ".png"))


func run(m) -> void:
	var c: City = m.city
	m.app.new_game("normal")
	await m.frames(5)
	c.hud.help_timer = 0
	c.open_tutorial()
	await m.frames(10)
	await shot(m, "0_bienvenida")
	c.overlays.tutorial_next()
	var t: Tutorial = c.tutorial
	print("TUTORIAL activo: ", t.active, " paso ", t.STEPS[t.step])
	await m.frames(30)
	await shot(m, "1_caminar")
	c.player.position += Vector3(5, 0, 0)
	await m.frames(50)
	c.vy = 8.0
	await m.frames(10)
	await m.frames(50)
	print("después de saltar: ", t.STEPS[t.step])
	c.yaw = 180.0
	await m.frames(40)
	await shot(m, "2_puesto_flecha")
	var s: Store = t._stall()
	c.player.position = s.spots.serve
	await m.frames(50)
	await shot(m, "3_atender")
	c.start_serving(s)
	await m.frames(50)
	c.stop_serving()
	c.overlays.show("admin")
	await m.frames(50)
	await shot(m, "4_celular")
	m.app.game.products.cafe.price += 0.5
	await m.frames(50)
	c.overlays.hide()
	m.app.speed = 1
	m.app.paused = false
	await m.frames(50)
	print("antes de la oficina: ", t.STEPS[t.step])
	await shot(m, "5_oficina")
	c.go_to_office()
	await m.frames(50)
	print("terreno: ", t.STEPS[t.step])
	await shot(m, "6_terreno")
	c.overlays.show("lote", c.lots.keys()[0])
	await m.frames(50)
	c.overlays.hide()
	await m.frames(30)
	print("FIN activo=", t.active, " visto=", c.settings.tutorial_seen)
	await shot(m, "7_fin")
