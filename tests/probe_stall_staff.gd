extends RefCounted
## Carga en memoria una copia de la partida 1 del jugador (no guarda nada) y revisa los empleados de los puestos.
func run(m) -> void:
	var c: City = m.city
	var text := FileAccess.get_file_as_string("user://saves/partida_1.json")
	var g := Game.from_json(text)
	m.app.slot = 3
	m.app.game = g
	m.app.view = "game"
	c.tutorial.active = false
	await m.frames(20)
	m.app.paused = true
	print("sucursales: ", g.locations.map(func(l): return [l.product, l.size, l.employees, Game.plot_of(l), Game.mall_of(l)]))
	for s in c.stores.values():
		var st: Store = s
		print("tienda ", st.loc.product, " tamaño ", st.loc.size, " empleados ", st.loc.employees, " · personas ", st.staff.size(),
				" · lugares ", st.spots.staff.size(), " · visibles ", st.staff.map(func(p): return p.is_visible_in_tree()),
				" · pos ", st.staff.map(func(p): return p.position), " · casa ", st.staff.map(func(p): return p.get_meta("home")))
	var stall: Store = null
	for s in c.stores.values():
		if s.loc.size == 0:
			stall = s
	if stall:
		m.set_process(false)
		c.sky.set_time(0.45)
		c.camera.global_position = Blueprints.to_world(stall.plot, 2.5, -5.0, 2.6)
		c.camera.look_at(Blueprints.to_world(stall.plot, 0, 4.5, 1.2))
		c.update_lights()
		await m.frames(6)
		await m.shot(ProjectSettings.globalize_path("res://tests/shots/puesto_empleados.png"))
