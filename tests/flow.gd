extends RefCounted
## Flujo real: partida nueva a velocidad x3 hasta que aparece una decisión urgente; se elige y el juego sigue.


func run(m) -> void:
	m.app.new_game("normal")
	await m.frames(5)
	var g: Game = m.app.game
	g.next_choice_day = 3
	m.app.speed = 2
	var waited := 0
	while m.app.modal == null and waited < 900:
		await m.frames(1)
		waited += 1
	print("decisión: ", m.app.modal, " tras ", waited, " cuadros · ventana: ", m.city.overlays.mode, " auto: ", m.city.overlays.auto)
	await m.frames(10)
	await m.shot(ProjectSettings.globalize_path("res://tests/shots/flujo_dilema.png"))
	var res: Array = g.resolve_choice(1)
	m.app.modal = null
	await m.frames(10)
	print("después de elegir: ventana ", m.city.overlays.mode, " · día ", g.day, " · ", res[1])
	var day0 := g.day
	await m.frames(120)
	print("el juego sigue: ", g.day > day0, " (día ", g.day, ")")
