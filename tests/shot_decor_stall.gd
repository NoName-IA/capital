extends RefCounted
## Decorar un puesto: solo lo que tiene sentido en un puesto (ventilador, menú colgante, QR), en el panel chico.
## Godot --path . -- --scenario=res://tests/shot_decor_stall.gd
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
	g.cash += 100000
	c.tutorial.active = false
	c.sky.set_time(0.45)
	var loc: Dictionary = g.locations[0]
	print("artículos del puesto: ", D.upgrades_for(0).map(func(u): return u.key))
	print("aire en un puesto: ", g.buy_decor(loc, "aire"))
	c.player.position = Blueprints.to_world(City.plot_pos(0), 0, -4)
	c.open_decor(loc.id)
	var keys: Array = D.upgrades_for(0).map(func(u): return u.key)
	for i in keys.size():
		mouse_to(m, m.ui, Vector2(44 + (i % 3) * 122.7 + 57, 86 + (i / 3) * 144 + 50))
		for f in 45:
			await m.frames(1)
		print("mouse ", m.ui.mouse, " · hover ", c.overlays.decor_hover, " · modo ", c.overlays.mode, " · captura ", Input.mouse_mode)
		await m.shot(ProjectSettings.globalize_path(OUT + "decor_puesto_%s.png" % keys[i]))
	m.mouse_clicked = true
	await m.frames(30)
	await m.shot(ProjectSettings.globalize_path(OUT + "decor_puesto_elegido.png"))
	c.close_decor()
	# Comprar el ventilador y ampliar a local: pasa a ser aire acondicionado
	print("ventilador: ", g.buy_decor(loc, "ventilador"))
	print("ampliar: ", g.upgrade_location(loc), " · ahora tiene ", loc.upgrades)
