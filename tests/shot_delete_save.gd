extends RefCounted
## Borrar desde el menú la partida que estaba abierta: al cerrar el juego no debe volver a guardarse.
## Godot --path . -- --scenario=res://tests/shot_delete_save.gd
func run(m) -> void:
	var c: City = m.city
	m.app.slot = 3
	m.app.new_game("normal", true)
	await m.frames(5)
	m.app.save(true)
	print("guardada: ", FileAccess.file_exists(Admin.slot_path(3)), " en ", Admin.save_dir)
	m.app.view = "menu"   # MENÚ PRINCIPAL
	await m.frames(3)
	m.app.delete_save(3)
	c.save_on_exit()      # lo que pasa al cerrar el juego
	print("después de borrar y cerrar, el archivo existe: ", FileAccess.file_exists(Admin.slot_path(3)), " (debe ser false)")
