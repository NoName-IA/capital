extends RefCounted
## Pantalla de inicio (con la tarjeta de la última partida) y la de cargar partida, con dos partidas guardadas.

const OUT := "res://tests/shots/"


func run(m) -> void:
	for n in [1, 3]:
		m.app.delete_save(n)
	m.app.delete_save(2)
	m.app.new_game("normal")
	var g: Game = m.app.game
	g.company = "Café Aurora"
	g.cash += 90000
	g.open_location("cafe", 1)
	for i in 40:
		g.step_day()
		if g.pending_choice != null:
			g.resolve_choice(0)
	g.play_seconds = 2520
	m.app.save(true, 1)
	m.app.game = null   # que no se autoguarde encima mientras se espera
	await m.get_tree().create_timer(1.1).timeout   # que el espacio 3 quede como el más reciente
	m.app.new_game("inversionista")
	g = m.app.game
	g.company = "Grupo Brandon"
	g.cash += 400000
	g.unlock("pan")
	g.open_location("cafe", 1)
	g.open_location("pan", 0)
	for i in 120:
		g.step_day()
		if g.pending_choice != null:
			g.resolve_choice(0)
	g.play_seconds = 8100
	m.app.save(true, 3)
	m.app.game = null
	m.app.view = "menu"
	m.city.overlays.show("admin")
	await m.frames(4)
	await m.shot(ProjectSettings.globalize_path(OUT + "inicio.png"))
	m.app.slot_screen = "load"
	await m.frames(3)
	await m.shot(ProjectSettings.globalize_path(OUT + "cargar.png"))
	m.app.slot_confirm = 3
	await m.frames(3)
	await m.shot(ProjectSettings.globalize_path(OUT + "cargar_borrar.png"))
	m.app.slot_confirm = null
	m.app.slot_screen = "new"
	await m.frames(3)
	await m.shot(ProjectSettings.globalize_path(OUT + "nueva.png"))
	m.app.slot_screen = null
	m.app.slot = 2
	m.app.pick_mode = true
	await m.frames(3)
	await m.shot(ProjectSettings.globalize_path(OUT + "modo.png"))
	m.app.pick_mode = false
	m.app.naming = true
	m.app.name_mode = "normal"
	m.app.company_name = "Café Aurora"
	await m.frames(3)
	await m.shot(ProjectSettings.globalize_path(OUT + "nombre.png"))
	m.app.naming = false
