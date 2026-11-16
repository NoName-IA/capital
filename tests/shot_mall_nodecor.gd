extends RefCounted
## Los locales del centro comercial no tienen el botón Decorar (los de la avenida sí).
## Godot --path . -- --scenario=res://tests/shot_mall_nodecor.gd
const OUT := "res://tests/shots/"


func run(m) -> void:
	var c: City = m.city
	m.app.slot = 3
	m.app.new_game("normal")
	await m.frames(5)
	var g: Game = m.app.game
	c.tutorial.stop()
	g.tutorial_step = -1
	m.app.modal = null
	g.cash = 5000000.0
	print("centro comercial: ", g.buy_mall())
	print("vitrina: ", g.open_location("cafe", 1, null, 0))
	var mall_loc = null
	for l in g.locations:
		if Game.mall_of(l) >= 0:
			mall_loc = l
	c.sync(g)
	m.app.tab = "negocios"
	c.overlays.show("admin")
	await m.frames(10)
	await m.shot(ProjectSettings.globalize_path(OUT + "mall_sin_decorar.png"))
	c.overlays.hide()
	c.open_decor(int(mall_loc.id))
	print("abrir decorar en la vitrina: ", c.overlays.mode)
