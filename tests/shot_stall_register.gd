extends RefCounted
## La caja registradora del puesto: frente al cajero, mirando hacia él.

const OUT := "res://tests/shots/"


func run(m) -> void:
	var c: City = m.city
	m.app.new_game("normal")
	await m.frames(5)
	m.app.modal = null
	c.overlays.hide()
	m.app.paused = true
	await m.frames(40)
	m.ui.set_visible(false)
	c.hud.ui.set_visible(false)
	m.set_process(false)
	c.sky.set_time(0.45)
	var s: Store = c.tutorial._stall()
	var cashier: Vector3 = s.staff[0].position
	var reg: Vector3 = Blueprints.to_world(s.plot, Blueprints.STALL_REGISTER[0].x, Blueprints.STALL_REGISTER[0].z)
	var toward := (reg - cashier).normalized()   # del cajero hacia la caja (y los clientes)
	toward.y = 0
	for v in [["caja_atras", cashier - toward * 0.6 + toward.cross(Vector3.UP) * 0.8 + Vector3(0, 2.6, 0), reg + Vector3(0, 1.1, 0)],
			["caja_frente", reg + toward * 3.0 + Vector3(0, 2.0, 0), reg + Vector3(0, 1.1, 0)],
			["caja_lado", reg + toward.cross(Vector3.UP) * 1.6 + toward * 0.3 + Vector3(0, 2.2, 0), reg + Vector3(0, 1.1, 0)]]:
		c.camera.global_position = v[1]
		c.camera.look_at(v[2])
		c.update_lights()
		await m.frames(4)
		await m.shot(ProjectSettings.globalize_path(OUT + "%s.png" % v[0]))
