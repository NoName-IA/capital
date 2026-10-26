extends RefCounted
## La vitrina de trofeos en los dos modos, con algunos títulos ganados.

const OUT := "res://tests/shots/"


func run(m) -> void:
	for mode in ["normal", "inversionista"]:
		m.app.new_game(mode)
		await m.frames(5)
		var g: Game = m.app.game
		g.cash += 2000000.0 if mode == "normal" else 30000000.0
		for i in 3:
			g.step_day()
			if g.pending_choice != null:
				g.resolve_choice(0)
		g.rank = 3 if mode == "normal" else 7
		for j in g.rank:
			g.rank_log[g.ranks()[j + 1][1]] = [40 + j * 75, 300 + j * 420]
		m.app.paused = true
		m.city.show_trophies()
		await m.frames(20)
		await m.shot(ProjectSettings.globalize_path(OUT + "trofeos_%s.png" % mode))
		m.city.overlays.hide()
