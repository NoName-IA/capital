extends RefCounted
## Importa las partidas de la versión de Python (a la carpeta de pruebas), carga la primera y la juega un rato.


func run(m) -> void:
	for n in range(1, 4):
		if FileAccess.file_exists(Admin.slot_path(n)):
			DirAccess.remove_absolute(Admin.slot_path(n))
	m.app.import_python_saves()
	for n in range(1, 4):
		var info = m.app.slot_info(n)
		print("espacio %d: %s" % [n, info])
	if m.app.latest_slot() == 0:
		print("no hay partidas de Python para importar")
		return
	var ok: bool = m.app.load_slot(m.app.latest_slot())
	var g: Game = m.app.game
	print("cargada: ", ok, " día ", g.day, " caja ", Fmt.money(g.cash), " locales ", g.locations.size(), " ropa ", g.look)
	var cash0 := g.cash
	m.app.paused = false
	for i in 60:
		g.step_day()
		if g.pending_choice != null:
			g.resolve_choice(0)
	print("después de 60 días: día ", g.day, " caja ", Fmt.money(g.cash), " rango ", g.rank_info()[1])
	await m.frames(30)
	await m.shot(ProjectSettings.globalize_path("res://tests/shots/importada.png"))
