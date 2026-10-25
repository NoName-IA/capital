extends RefCounted
## Saca las imágenes del tutorial (images/tutorial/*.png) desde el juego. Volver a correrlo si cambia la ciudad:
## Godot --path . -- --scenario=res://tests/make_tutorial_images.gd   (y después --import)

const OUT := "res://images/tutorial/"


func save(m, name: String) -> void:
	await m.frames(4)
	await RenderingServer.frame_post_draw
	var img: Image = m.get_viewport().get_texture().get_image()
	img.resize(960, 540, Image.INTERPOLATE_LANCZOS)
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUT))
	img.save_png(ProjectSettings.globalize_path(OUT + name + ".png"))
	print("imagen: ", name)


func cam(c: City, pos: Vector3, at: Vector3) -> void:
	c.camera.global_position = pos
	c.camera.look_at(at)


func run(m) -> void:
	m.app.slot = 3
	m.app.new_game("normal")
	await m.frames(5)
	var c: City = m.city
	var g: Game = m.app.game
	g.next_choice_day = 100000
	g.cash += 2000000
	g.unlock("pan")
	g.unlock("burger")
	g.open_location("cafe", 1, 2)
	g.open_location("burger", 1, 3)
	for l in g.locations:
		l.employees = 3
	c.sync(g)
	c.hud.help_timer = 0
	c.set_sky_lock(0.3)
	await m.frames(10)
	# Celular (con la interfaz)
	m.app.tab = "negocios"
	c.overlays.show("admin")
	await m.frames(20)
	await save(m, "celular")
	c.overlays.hide()
	m.ui.set_visible(false)
	c.hud.ui.set_visible(false)
	# Moverse: el jugador en la avenida
	c.player.position = Vector3(-30, 0, 5)
	c.yaw = 25
	c.pitch = 14
	c.zoom_target = 7
	await m.frames(90)
	await save(m, "moverse")
	# Clientes: fila en el local de hamburguesas
	m.set_process(false)
	for i in 700:
		if i % 80 == 0:
			for st in c.stores.values():
				var cu := Customer.new(c, st)
				cu.body.position = st.spots.front + Vector3(0, 0, -1)
				c.customers.append(cu)
		c.update(1.0 / 60.0)
		cam(c, Vector3(13, 3.0, 13.5), Vector3(11, 1.2, 20))
		await m.frames(1)
	await save(m, "clientes")
	# Terreno en venta
	cam(c, Vector3(-37, 2.0, 4.0), Vector3(-33, 1.4, 11))
	await save(m, "terreno")
	# Meta: la ciudad desde el aire con el sol de la tarde
	c.sky.set_time(0.56)
	cam(c, Vector3(-30, 34, -70), Vector3(25, 0, 25))
	await save(m, "meta")
	c.sky.set_time(0.3)
	# Oficina por dentro
	cam(c, Vector3(-85, 2.2, 12.5), Vector3(-76, 1.6, 22))
	await save(m, "oficina")
	# ELDIARIO
	c.update_diario()
	cam(c, Vector3(-66.5, 2.4, 2.5), Vector3(-69, 4.2, 12))
	await save(m, "eldiario")
