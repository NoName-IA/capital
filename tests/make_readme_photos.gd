extends RefCounted
## Fotos del README (quedan en tests/shots/readme_*.png; las de docs/fotos se hacen desde estas con Python).
## Una ciudad con varios locales y clientes, de día, al atardecer y de noche, con y sin la interfaz.

const OUT := "res://tests/shots/readme_"


func shot(m, name: String, frames := 6) -> void:
	await m.frames(frames)
	await m.shot(ProjectSettings.globalize_path(OUT + name + ".png"))


func cam(c: City, pos: Vector3, look: Vector3) -> void:
	c.camera.global_position = pos
	c.camera.look_at(look)
	c.update_lights()


func run(m) -> void:
	var c: City = m.city
	m.app.slot = 3
	m.app.new_game("normal")
	await m.frames(5)
	var g: Game = m.app.game
	g.company = "Café Aurora"
	g.next_choice_day = 100000
	g.cash += 3000000
	for k in ["pan", "burger", "ropa"]:
		g.unlock(k)
	g.open_location("cafe", 1, 1)
	g.open_location("pan", 1, 2)
	g.open_location("burger", 2, 3)
	g.open_location("ropa", 1, 4)
	g.open_location("cafe", 1, 8)
	g.open_location("burger", 1, 9)
	g.open_location("pan", 1, 7)
	for i in 60:
		g.step_day()
	g.wardrobe = true
	c.hud.help_timer = 0
	m.app.speed = 0
	m.app.paused = false
	await m.frames(400)   # que lleguen clientes y se armen las filas
	m.app.paused = true
	c.sky_lock = 0.30
	# --- Con la interfaz: jugando en la avenida ---
	c.player.position = Vector3(-14, 0, 6.5)
	c.yaw = 140.0
	c.pitch = 14.0
	c.zoom = 7.0
	await shot(m, "juego_avenida", 40)
	# El celular en Mercado
	m.app.tab = "mercado"
	c.overlays.show("admin")
	await shot(m, "juego_celular", 40)
	c.overlays.hide()
	# La oficina por dentro, con la computadora
	c.go_to_office()
	await shot(m, "juego_oficina", 40)
	# Trofeos
	c.show_trophies()
	await shot(m, "juego_trofeos", 30)
	c.overlays.hide()
	await m.frames(60)   # que se vaya el desenfoque de los menús
	# --- Solo gráficos (sin interfaz) ---
	m.ui.set_visible(false)
	c.hud.ui.set_visible(false)
	m.set_process(false)
	c.player.visible = false
	var views := [
		["portada", 0.60, Vector3(-40, 34, 46), Vector3(60, 0, -6)],
		["avenida_dia", 0.30, Vector3(-30, 3.0, 4.5), Vector3(10, 2.0, 11)],
		["playa_atardecer", 0.63, Vector3(150, 6, -2), Vector3(200, 1, 25)],
		["parque_noche", 0.82, Vector3(9, 4.5, -21), Vector3(0, 1, -34)],
		["avenida_noche", 0.82, Vector3(-30, 3.0, 4.5), Vector3(10, 2.0, 11)],
		["barrio_noche", 0.84, Vector3(14, 3, 45), Vector3(34, 1.5, 37)],
		["oficina_torre", 0.52, Vector3(-70, 1.8, 3.5), Vector3(-80, 15, 18)],
		["muelle_atardecer", 0.645, Vector3(165, 5, 32), Vector3(195, 0.5, 23)],
	]
	for v in views:
		c.sky.set_time(v[1])
		cam(c, v[2], v[3])
		await shot(m, v[0], 8)
	# Un local por dentro de noche
	c.sky.set_time(0.82)
	var p := Blueprints.to_world(City.PLOTS[1], 2.5, 4.5)
	cam(c, p + Vector3(0, 2.2, 0), Blueprints.to_world(City.PLOTS[1], -2, 11) + Vector3(0, 1.2, 0))
	await shot(m, "local_noche", 8)
