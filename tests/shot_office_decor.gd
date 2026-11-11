extends RefCounted
## Personalizar la oficina, la ventana «Mejorar oficina» y el guardia sentado. Godot --path . -- --scenario=res://tests/shot_office_decor.gd
const OUT := "res://tests/shots/"


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
	c.tutorial.active = false
	c.sky.set_time(0.45)
	m.app.paused = false
	# La ventana «Mejorar oficina» sale sola con el rango y la plata
	g.rank = 1
	g.cash += 400000
	await m.frames(10)
	print("ventana: ", c.overlays.mode, " · ", c.overlays.question.title if c.overlays.question else "")
	await m.shot(ProjectSettings.globalize_path(OUT + "mejorar_oficina.png"))
	c.overlays.hide()
	c.overlays.question = null
	# Personalizar
	c.open_office_decor()
	var keys: Array = D.OFFICE_DECOR.map(func(u): return u.key)
	for i in keys.size():
		mouse_to(m, m.ui, Vector2(44 + (i % 3) * 122.7 + 57, 86 + (i / 3) * 144 + 50))
		for f in 45:
			await m.frames(1)
		await m.shot(ProjectSettings.globalize_path(OUT + "oficina_deco_%s.png" % keys[i]))
	c.close_decor()
	for k in keys:
		g.buy_office_decor(k)
	c.sync(g)
	m.set_process(false)
	c.sky.set_time(0.9)
	c.camera.global_position = Blueprints.to_world(City.HQ, 12, -17, 6)
	c.camera.look_at(Blueprints.to_world(City.HQ, -3, 6, 6))
	c.update_lights()
	await m.frames(6)
	await m.shot(ProjectSettings.globalize_path(OUT + "oficina_deco_noche.png"))
	# El guardia sentado en medio de la obra
	c.sky.set_time(0.45)
	var mall: Mall = c.malls[1]
	var gp: Vector3 = mall.guard.position
	c.camera.global_position = gp + Vector3(-4, 3, -6)
	c.camera.look_at(gp + Vector3(0, 0.8, 0))
	c.update_lights()
	await m.frames(6)
	await m.shot(ProjectSettings.globalize_path(OUT + "guardia_sentado.png"))
