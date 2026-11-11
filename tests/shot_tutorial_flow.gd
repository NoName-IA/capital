extends RefCounted
## Recorre el tutorial nuevo paso a paso (sin avisos mientras dura). Godot --path . -- --scenario=res://tests/shot_tutorial_flow.gd
const OUT := "res://tests/shots/"


func run(m) -> void:
	var c: City = m.city
	m.app.slot = 3
	m.app.new_game("normal", false)
	await m.frames(5)
	var g: Game = m.app.game
	c.tutorial.start()
	g.add_news("Un rival se burla de ti", "rival", "rival", D.RIVALS[0].key)
	c.player.position += Vector3(6, 0, 0)
	await m.frames(30)
	print("avisos en pantalla durante el tutorial: ", c.hud.notes.cards.size() + c.hud.notes.waiting.size())
	g.open_location("cafe", 0, 1)
	c.sync(g)
	await m.frames(30)
	print("paso: ", Tutorial.STEPS[c.tutorial.step])
	c.overlays.show("admin")
	await m.frames(30)
	c.tutorial.understood = true
	c.overlays.hide()
	await m.frames(30)
	print("paso: ", Tutorial.STEPS[c.tutorial.step])
	g.products.cafe.price += 0.5
	await m.frames(30)
	print("paso: ", Tutorial.STEPS[c.tutorial.step])
	c.overlays.show("admin")
	m.app.tab = "negocios"
	await m.frames(20)
	await m.shot(ProjectSettings.globalize_path(OUT + "tutorial_contratar.png"))
	g.hire(g.locations[0])
	await m.frames(30)
	print("paso: ", Tutorial.STEPS[c.tutorial.step], " · velocidad ", m.app.speed, " · pausa ", m.app.paused)
	await m.frames(10)
	await m.shot(ProjectSettings.globalize_path(OUT + "tutorial_velocidad.png"))
	m.app.speed = 1   # solo cambiar la velocidad, con la tablet abierta
	await m.frames(30)
	print("paso después de cambiar la velocidad: ", Tutorial.STEPS[c.tutorial.step])
	c.overlays.hide()
	await m.frames(20)
	await m.shot(ProjectSettings.globalize_path(OUT + "tutorial_oficina.png"))
	# El paso queda en la partida guardada: al volver a cargarla, sigue donde iba
	var saved: Dictionary = g.to_state() if g.has_method("to_state") else {}
	print("paso guardado en la partida: ", g.tutorial_step, " (", Tutorial.STEPS[c.tutorial.step], ")", " · en SAVED: ", "tutorial_step" in Game.SAVED)
	print("dilema: ", g.pending_choice, " · micro: ", g.micro, " · próximo dilema día ", g.next_choice_day, " (hoy ", g.day, ")")
	c.tutorial.stop()
