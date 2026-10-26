extends RefCounted
## Menú de inicio: la franja se desliza de una opción a otra al mover el mouse (capturas a mitad del viaje).


func run(m) -> void:
	await m.frames(20)
	var ui: ImUI = m.ui
	m.get_viewport().warp_mouse(Vector2(200, 400) * ui._scale + ui._offset)   # NUEVA PARTIDA
	await m.frames(30)
	await m.shot(ProjectSettings.globalize_path("res://tests/shots/menu_hover_1.png"))
	m.get_viewport().warp_mouse(Vector2(200, 628) * ui._scale + ui._offset)   # SALIR
	await m.frames(4)
	await m.shot(ProjectSettings.globalize_path("res://tests/shots/menu_hover_2.png"))
	await m.frames(30)
	await m.shot(ProjectSettings.globalize_path("res://tests/shots/menu_hover_3.png"))
	print("opción con el mouse: ", ui.menu_prev, " · franja en y=", snappedf(ui.menu_band.position.y, 0.1))
