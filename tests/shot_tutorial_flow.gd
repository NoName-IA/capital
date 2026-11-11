extends RefCounted
## Recorre el tutorial entero con el mentor: bienvenida, teclas, línea en el suelo, tablet sin esperar al mentor,
## puesto resaltado, velocidad, salir de la tablet, oficina, cómo se gana y la tarjeta final (que no vuelve a empezar).
## Godot --path . -- --scenario=res://tests/shot_tutorial_flow.gd
const OUT := "res://tests/shots/"


func _shot(m, name: String) -> void:
	await m.shot(ProjectSettings.globalize_path(OUT + name + ".png"))


## En la ciudad el mentor espera Enter: lo pasamos.
func _listen(m, c: City) -> void:
	var n := 0
	while c.tutorial.blocking() and n < 20:
		c.tutorial.advance()
		c.tutorial.advance()
		n += 1
		await m.frames(2)


func _step(c: City) -> String:
	return Tutorial.STEPS[c.tutorial.step] if c.tutorial.active else "(terminado)"


func run(m) -> void:
	var c: City = m.city
	m.app.slot = 3
	m.app.new_game("normal", false)
	await m.frames(5)
	var g: Game = m.app.game
	c.open_tutorial()
	await m.frames(10)
	await _shot(m, "tut_00_bienvenida")
	c.overlays.tutorial_next()
	await m.frames(80)
	await _shot(m, "tut_01_caminar")
	print("hablando -> pausa: ", m.app.paused)
	await _listen(m, c)
	print("terminó de hablar -> pausa: ", m.app.paused)
	await m.frames(10)
	await _shot(m, "tut_02_caminar_teclas")
	c.player.position += Vector3(6, 0, 0)
	await m.frames(30)
	print("paso: ", _step(c))
	await _listen(m, c)
	await m.frames(20)
	await _shot(m, "tut_03_terreno_linea")
	print("línea en el suelo: ", c.tutorial.path.visible)
	c.overlays.show("lote", 1)
	await m.frames(30)
	print("paso: ", _step(c))
	c.overlays.hide()
	g.open_location("cafe", 0, 1)
	c.sync(g)
	await m.frames(30)
	print("paso: ", _step(c))
	await _listen(m, c)
	c.overlays.show("admin")
	await m.frames(40)
	print("paso: ", _step(c), " · hablando: ", c.tutorial.talking(), " · bloquea: ", c.tutorial.blocking())
	await _shot(m, "tut_04_precio_tablet")
	print("tablet, hablando -> pausa: ", m.app.paused)
	m.app.tab = "mercado"
	await m.frames(20)
	await _shot(m, "tut_05_precio_mercado")
	g.products.cafe.price += 0.5   # mientras el mentor todavía habla: cuenta igual
	await m.frames(40)
	print("paso: ", _step(c))
	m.app.tab = "negocios"
	await m.frames(20)
	await _shot(m, "tut_06_contratar")
	g.hire(g.locations[0])
	await m.frames(40)
	print("paso: ", _step(c))
	await _shot(m, "tut_07_velocidad")
	m.app.speed = 1
	await m.frames(40)
	print("paso: ", _step(c))
	await m.frames(60)
	await _shot(m, "tut_08_salir")
	print("velocidad elegida: ", m.app.speed, " · pausa: ", m.app.paused)
	c.overlays.hide()
	await m.frames(30)
	print("paso: ", _step(c))
	await _listen(m, c)
	await _shot(m, "tut_09_oficina")
	c.player.position = c.hq_spots.computer + Vector3(1, 0, 0)
	await m.frames(30)
	print("paso: ", _step(c))
	await _listen(m, c)
	await m.frames(10)
	print("ventana: ", c.overlays.mode)
	await _shot(m, "tut_10_valor")
	c.overlays.tutorial_next()   # Entendido
	await m.frames(20)
	print("ventana: ", c.overlays.mode, " · tutorial activo: ", c.tutorial.active, " · paso guardado ", g.tutorial_step)
	await _shot(m, "tut_11_final")
	print("tarjeta final: pausa ", m.app.paused)
	c.overlays.tutorial_next()   # ¡A jugar!
	await m.frames(20)
	print("después de «¡A jugar!»: tutorial activo ", c.tutorial.active, " · ventana ", c.overlays.mode, " · visto ", c.settings.tutorial_seen, " · pausa ", m.app.paused)
