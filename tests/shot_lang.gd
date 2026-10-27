extends RefCounted
## Los idiomas: el menú, la tablet, el tutorial, los ajustes y la ciudad en cada idioma (ver Lang).

const OUT := "res://tests/shots/"


func shot(m, code: String, name: String) -> void:
	await m.frames(4)
	await m.shot(ProjectSettings.globalize_path(OUT + "lang_%s_%s.png" % [code, name]))


func run(m) -> void:
	var c: City = m.city
	m.app.new_game("normal")
	var g: Game = m.app.game
	g.next_choice_day = 100000
	g.cash += 30000
	for i in 35:
		g.step_day()
	c.hud.help_timer = 0
	await m.frames(10)
	for code in Lang.CODES:
		Lang.use(code)
		print("idioma ", code, ": ", Lang.t("Café"), " · ", Fmt.money(12345.5, 2), " · ", Lang.f("En %d día%s: %s", [3, "s", "Lluvia"]))
		# Tablet: resumen y mercado
		c.overlays.show("admin")
		m.app.tab = "resumen"
		await shot(m, code, "2_resumen")
		m.app.tab = "mercado"
		await shot(m, code, "3_mercado")
		m.app.tab = "negocios"
		await shot(m, code, "4_negocios")
		# Ajustes (desde la pausa)
		c.overlays.show("pausa")
		c.overlays.pause_page = "ajustes"
		await shot(m, code, "5_ajustes")
		# Bienvenida del tutorial y la ciudad con el tutorial guiado
		c.overlays.hide()
		c.open_tutorial()
		await shot(m, code, "6_bienvenida")
		c.overlays.tutorial_next()
		c.tutorial.step = 4   # "Abre tu tablet": flecha sobre el botón del HUD
		await m.frames(20)
		await shot(m, code, "7_ciudad")
		c.tutorial.stop()
		# Menú de inicio
		m.app.view = "menu"
		c.overlays.show("admin")
		await shot(m, code, "1_menu")
		m.app.view = "game"
		c.overlays.hide()
		await m.frames(5)   # al volver a la partida la ciudad se rearma (y cierra lo que esté abierto)
	Lang.use("es")
