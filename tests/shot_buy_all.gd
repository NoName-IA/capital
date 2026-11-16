extends RefCounted
## «Seleccionar todo» en la ventana de decorar (local y oficina). Godot --path . -- --scenario=res://tests/shot_buy_all.gd
const OUT := "res://tests/shots/"


func run(m) -> void:
	var c: City = m.city
	m.app.slot = 3
	m.app.new_game("normal")
	await m.frames(5)
	var g: Game = m.app.game
	c.tutorial.stop()
	g.cash += 400000
	g.open_location("cafe", 1)
	c.sync(g)
	m.app.modal = null
	c.overlays.hide()
	await m.frames(5)
	c.open_decor(int(g.locations[-1].id))
	await m.frames(40)
	c.overlays.decor_pick = "*"
	await m.frames(40)
	await m.shot(ProjectSettings.globalize_path(OUT + "comprar_todo_local.png"))
	c.close_decor()
	await m.frames(5)
	c.open_office_decor()
	await m.frames(20)
	c.overlays.decor_pick = "*"
	await m.frames(40)
	await m.shot(ProjectSettings.globalize_path(OUT + "comprar_todo_oficina.png"))
