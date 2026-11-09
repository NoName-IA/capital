extends RefCounted
## Juega en tiempo real a x4 con la ciudad, la HUD y la tablet: resuelve dilemas y microdecisiones como un jugador,
## abre el mapa, compra cosas y cuenta lo que pasó. Sirve para ver errores que solo salen jugando.
## Godot --path . -- --scenario=res://tests/play_long.gd


func run(m) -> void:
	var c: City = m.city
	m.app.slot = 3
	m.app.new_game("normal")
	await m.frames(5)
	var g: Game = m.app.game
	c.tutorial.active = false
	g.cash += 400000
	g.unlock("pan")
	g.unlock("burger")
	g.open_location("pan", 1)
	g.open_location("burger", 1)
	m.app.speed = 2
	var micros := 0
	var dilemmas := 0
	var seen_micro = null
	var frames := 0
	while g.day < 400 and frames < 9000:
		await m.frames(1)
		frames += 1
		if m.app.modal == "dilema" and g.pending_choice != null:
			dilemmas += 1
			g.resolve_choice(frames % g.pending_choice.options.size())
			m.app.modal = null
			c.overlays.hide()
		elif c.overlays.open() and c.overlays.mode != "mapa":
			c.overlays.hide()
		if g.micro != null and not is_same(g.micro, seen_micro):
			seen_micro = g.micro
			micros += 1
			if micros % 2 == 0:
				c.answer_micro(frames % g.micro.options.size())
		if frames % 900 == 0:
			c.overlays.show("mapa")
			await m.frames(5)
			c.overlays.hide()
			for loc in g.locations:
				for u in D.UPGRADES:
					if g.cash > 50000 and g.buy_decor(loc, u.key)[0]:
						break
		if g.game_over:
			break
	var rival_news := g.news.filter(func(n): return n.kind == "rival").size()
	print("días jugados: %d en %d cuadros · dilemas %d · microdecisiones %d (una cada %.1f días) · mensajes de rivales %d · ánimo %d" % [
			g.day, frames, dilemmas, micros, g.day / maxf(1, micros), rival_news, roundi(g.morale)])
	print("ranking: ", g.ranking().map(func(r): return "%s %s" % [r[2], Fmt.short(r[3])]))
	print("quiebra: ", g.game_over)
