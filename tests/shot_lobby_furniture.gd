extends RefCounted
## El vestíbulo: ascensor al fondo, armario a la izquierda, trofeos a la derecha y la recepción.
## Godot --path . -- --scenario=res://tests/shot_lobby_furniture.gd
const OUT := "res://tests/shots/"


func _cam(m, c: City, eye: Vector3, at: Vector3, name: String) -> void:
	c.camera.global_position = Blueprints.to_world(City.HQ, eye.x, eye.z, eye.y)
	c.camera.look_at(Blueprints.to_world(City.HQ, at.x, at.z, at.y))
	await m.frames(6)
	await m.shot(ProjectSettings.globalize_path(OUT + name))


func run(m) -> void:
	var c: City = m.city
	m.app.slot = 3
	m.app.new_game("normal")
	await m.frames(5)
	var g: Game = m.app.game
	c.tutorial.stop()
	g.rank = 7
	g.wardrobe = true
	c.sync(g)
	c.sky_lock = 0.45
	m.app.modal = null
	c.overlays.hide()
	m.set_process(false)
	c.update_lights()
	await _cam(m, c, Vector3(0, 2.2, 2.6), Vector3(0, 1.6, 15.0), "vestibulo_entrada.png")
	await _cam(m, c, Vector3(2.0, 2.0, 5.5), Vector3(7.5, 1.4, 3.9), "vestibulo_armario.png")
	await _cam(m, c, Vector3(-2.0, 2.0, 5.5), Vector3(-7.5, 1.4, 3.9), "vestibulo_trofeos.png")
	await _cam(m, c, Vector3(-1.5, 2.2, 9.0), Vector3(-5.5, 1.0, 13.5), "vestibulo_recepcion.png")
