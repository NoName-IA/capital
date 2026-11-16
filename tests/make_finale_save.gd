extends RefCounted
## Crea en el espacio 3 de tus partidas (no en las de prueba) una partida a punto de ganar: la empresa ya vale más de
## $10 millones y faltan 2 días para el cierre de mes (unos 13 s a velocidad x1), que es cuando se cumple la meta y
## sale el final. Si el espacio 3 tenía algo, lo respalda antes.
## Godot --path . -- --scenario=res://tests/make_finale_save.gd
const SLOT := 3


func run(m) -> void:
	var c: City = m.city
	var test_dir: String = Admin.save_dir
	var to_tests := "--para-pruebas" in OS.get_cmdline_user_args()   # una copia en las partidas de prueba, sin tocar las tuyas
	Admin.save_dir = test_dir if to_tests else "user://saves"
	var path := Admin.slot_path(SLOT)
	if FileAccess.file_exists(path) and not to_tests:
		var bak := path + ".respaldo"
		DirAccess.copy_absolute(path, bak)
		print("respaldo del espacio ", SLOT, ": ", ProjectSettings.globalize_path(bak))
	m.app.slot = SLOT
	m.app.new_game("normal")
	await m.frames(5)
	var g: Game = m.app.game
	c.tutorial.stop()
	g.tutorial_step = -1
	g.cash = 50000000.0
	for k in D.PRODUCT_ORDER:
		g.unlock(k)
	for k in D.PRODUCT_ORDER:   # locales de todo por la avenida y el centro comercial
		for size in [1, 2, 1]:
			g.open_location(k, size)
	for k in ["cafe", "pan", "burger"]:
		g.build_factory(k)
	g.unlock_wardrobe()
	g.owned_items = []
	g.look = Wardrobe.DEFAULT_LOOK.duplicate(true)
	g.look.jacket = "blazer"
	g.look.jacket_color = [30, 30, 34]
	g.look.shirt = [245, 245, 245]
	g.look.pants_style = "vestir"
	g.look.pants = [30, 30, 34]
	g.look.tie = true
	g.look.watch = true
	g.office_look = 3
	for k in D.OFFICE_DECOR.map(func(u): return u.key):
		g.buy_office_decor(k)
	for i in 3:
		g.buy_house(i)
	# Seis años de historia: cuándo llegaste a cada rango y tu mejor mes
	g.day = 30 * 70 + 28          # año 6; faltan 2 días para el cierre de mes
	g.play_seconds = 9600.0
	g.rank = 4                    # Magnate: al cierre de mes pasa a Imperio y ganas
	g.rank_log = {"Emprendedor": [210, 1100.0], "Pequeño empresario": [640, 3000.0], "Empresario": [1190, 5200.0],
			"Magnate": [1760, 7600.0]}
	g.best_month = 1840000.0
	g.worst_choice = {"title": "Un inspector quiere «colaboración»", "loss": 85000.0}
	g.won = false
	g.finale_seen = false
	g.pending_choice = null
	g.next_choice_day = g.day + 60      # que ninguna decisión urgente tape el final
	g.next_micro_day = g.day + 60
	g.path = {"rumbo": "premium", "rivales": "alianza"}   # las decisiones de rumbo ya tomadas
	g.cash = 10600000.0
	c.sync(g)
	await m.frames(5)
	print("valor de la empresa: ", Fmt.money(g.valuation()), " · locales ", g.locations.size(), " · día ", g.day,
			" · rango ", g.ranks()[g.rank][1])
	m.app.save(true, SLOT)
	print("guardada en: ", ProjectSettings.globalize_path(path))
	Admin.save_dir = test_dir
