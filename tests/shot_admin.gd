extends RefCounted
## Recorre el menú y las pestañas del celular y saca una captura de cada una.

const OUT := "res://tests/shots/"


func run(m) -> void:
	await m.frames(3)
	await m.shot(ProjectSettings.globalize_path(OUT + "menu.png"))
	m.app.new_game("normal")
	var g: Game = m.app.game
	g.cash += 400000
	g.unlock("pan")
	g.open_location("cafe", 1)
	g.open_location("pan", 0)
	g.take_loan(5000, 24)
	for i in 95:
		g.step_day()
		if g.pending_choice != null:
			g.resolve_choice(0)
	m.app.paused = true
	for t in Admin.TABS:
		m.app.tab = t[0]
		await m.frames(2)
		await m.shot(ProjectSettings.globalize_path(OUT + "tab_" + t[0] + ".png"))
	g.pending_choice = g.build_dilemma("compra_rival")
	m.app.modal = "dilema"
	await m.frames(2)
	await m.shot(ProjectSettings.globalize_path(OUT + "dilema.png"))
	m.app.modal = null
	m.app.view = "menu"
	m.app.slot_screen = "load"
	m.app.save(true, 2)
	await m.frames(2)
	await m.shot(ProjectSettings.globalize_path(OUT + "slots.png"))
