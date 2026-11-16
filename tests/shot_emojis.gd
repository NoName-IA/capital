extends RefCounted
## Emojis de los clientes según tu precio: barato, justo, caro y carísimo, sobre la cabeza de clientes de verdad.
## Godot --path . -- --scenario=res://tests/shot_emojis.gd
const OUT := "res://tests/shots/"


func run(m) -> void:
	var c: City = m.city
	m.app.slot = 3
	m.app.new_game("normal")
	await m.frames(5)
	var g: Game = m.app.game
	c.tutorial.stop()
	g.tutorial_step = -1
	c.sky_lock = 0.35
	m.app.modal = null
	c.overlays.hide()
	# Cuatro personas en fila frente a la cámara, cada una con una reacción distinta
	var people := []
	var emojis := [City.price_emoji(0.7), City.price_emoji(1.0), City.price_emoji(1.35), City.price_emoji(2.0), "💸", "😋"]
	for i in emojis.size():
		var p := Person.new()
		c.add_child(p)
		p.position = Vector3(-8 + i * 1.6, 0, -8.5)
		p.rotation.y = PI
		people.append(p)
	m.set_process(false)
	c.camera.global_position = Vector3(-4, 2.6, -15.5)
	c.camera.look_at(Vector3(-4, 2.2, -8.5))
	await m.frames(3)
	for i in people.size():
		c.emote(people[i], emojis[i], 30.0)
	for k in 30:
		c._update_emotes(1.0 / 60.0)
		await m.frames(1)
	await m.shot(ProjectSettings.globalize_path(OUT + "emojis.png"))
	print("emojis: ", emojis)
