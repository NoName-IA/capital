extends RefCounted
## El número de cada sucursal sobre el local (como en la tablet), sin el aviso «Administrar», y la O que funciona
## aunque el mentor esté hablando. Godot --path . -- --scenario=res://tests/shot_store_number.gd
const OUT := "res://tests/shots/"


func _key(c: City, action: String) -> void:
	var e := InputEventKey.new()
	e.physical_keycode = Keys.code(action)
	e.keycode = DisplayServer.keyboard_get_keycode_from_physical(e.physical_keycode)
	e.pressed = true
	c.input_event(e)
	var up := e.duplicate()
	up.pressed = false
	c.input_event(up)


func run(m) -> void:
	var c: City = m.city
	m.app.slot = 3
	m.app.new_game("normal", true)
	await m.frames(5)
	var g: Game = m.app.game
	g.cash += 200000
	print("abrir local: ", g.open_location("cafe", 1))
	print("abrir otro puesto: ", g.open_location("cafe", 0))
	c.sync(g)
	await m.frames(10)
	for i in c.stores:
		print("terreno ", i, ": ", c.stores[i].number.text)
	# Parado frente al primer puesto: ¿sale «Administrar»?
	var s: Store = c.stores[c.stores.keys()[0]]
	c.player.position = s.spots.manage
	await m.frames(20)
	var prompts := []
	for it in c.interactables() if c.has_method("interactables") else []:
		prompts.append(it[1])
	print("avisos con Administrar: ", prompts.filter(func(t): return "Administrar" in str(t)).size())
	c.player.position = s.spots.manage + Vector3(0, 0, 9)
	c.yaw = 180.0
	await m.frames(30)
	await m.shot(ProjectSettings.globalize_path(OUT + "store_number.png"))
	# El mentor dice «Aprieta O para ir»: la O funciona sin apretar Enter antes
	c.tutorial.start(Tutorial.STEPS.find("oficina"))
	await m.frames(10)
	print("hablando: ", c.tutorial.talking(), " · bloquea: ", c.tutorial.blocking())
	_key(c, "office")
	await m.frames(30)
	var comp: Vector3 = c.hq_spots.computer
	print("después de la O: hablando ", c.tutorial.talking(), " · distancia a la computadora ",
			snappedf(Vector2(c.player.position.x - comp.x, c.player.position.z - comp.z).length(), 0.1),
			" · paso ", Tutorial.STEPS[c.tutorial.step] if c.tutorial.active else "-")
	c.tutorial.stop()
