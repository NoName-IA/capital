extends RefCounted
## Entre una decisión urgente y el aviso de nuevo rango pasa al menos un minuto (en los dos sentidos).
## Godot --path . -- --scenario=res://tests/shot_rank_gap.gd
func run(m) -> void:
	var c: City = m.city
	var app = m.app
	app.slot = 3
	app.new_game("normal", true)
	await m.frames(5)
	var g: Game = app.game
	c.tutorial.stop()
	c.hud.notes.clear()
	# 1) Recién cerraste una decisión: el aviso de rango espera
	app.last_dilemma_ms = app.now_ms()
	c.react({"fx": "rank", "value": "Emprendedor", "text": ""})
	await m.frames(5)
	print("rango con decisión recién cerrada -> en espera: ", c.rank_wait != null, " · en pantalla: ", c.hud.notes.hero != null)
	app.last_dilemma_ms = app.now_ms() - Admin.GAP_MS - 10
	await m.frames(5)
	print("pasó un minuto -> en espera: ", c.rank_wait != null, " · en pantalla: ", c.hud.notes.hero != null or not c.hud.notes.heroes.is_empty())
	# 2) Recién subiste de rango: la decisión no sale
	app.last_rank_ms = app.now_ms()
	await m.frames(3)
	g.next_choice_day = 0
	g._maybe_dilemma()
	print("decisión con rango recién mostrado -> pendiente: ", g.pending_choice != null)
	app.last_rank_ms = app.now_ms() - Admin.GAP_MS - 10
	await m.frames(3)
	g._maybe_dilemma()
	print("pasó un minuto -> pendiente: ", g.pending_choice != null)
	g.pending_choice = null
	app.modal = null
