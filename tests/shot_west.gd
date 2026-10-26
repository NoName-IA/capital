extends RefCounted
## La calle hacia los cerros (oeste) y de noche con muchos locales abiertos (todos deben verse por dentro).

const OUT := "res://tests/shots/"


func run(m) -> void:
	var c: City = m.city
	m.app.slot = 3
	m.app.new_game("normal")
	await m.frames(5)
	var g: Game = m.app.game
	g.cash += 5000000
	for k in ["pan", "burger", "ropa", "tech"]:
		g.unlock(k)
	var keys := ["cafe", "pan", "burger", "ropa", "tech"]
	for i in City.PLOTS.size():
		g.open_location(keys[i % keys.size()], 1 + (i % 3 == 0 as int), i)
	m.app.paused = true
	await m.frames(20)
	m.ui.set_visible(false)
	c.hud.ui.set_visible(false)
	m.set_process(false)
	var walk := []
	for x in [-100.0, -120.0, -140.0, -149.0, -152.0]:
		walk.append("x=%d calle:%s vereda:%s pasto:%s" % [x, not c.blocked(x, 2.0), not c.blocked(x, 7.5), not c.blocked(x, 15.0)])
	print("CAMINAR ", walk)
	var rooms := 0
	for s in c.stores.values():
		if s.spots.get("ceiling") != null:
			rooms += 1
	print("LOCALES con techo: %d + competencia %d" % [rooms, c.comps.size()])
	for t in [[0.34, "dia"], [0.82, "noche"]]:
		c.sky.set_time(t[0])
		for v in [["oeste", Vector3(-95, 2.2, 4), Vector3(-160, 3, 0)], ["oeste_vuelta", Vector3(-148, 2, -4), Vector3(-90, 2, 2)]]:
			c.camera.global_position = v[1]
			c.camera.look_at(v[2])
			c.update_lights()
			await m.frames(4)
			await m.shot(ProjectSettings.globalize_path(OUT + "%s_%s.png" % [v[0], t[1]]))
	c.sky.set_time(0.82)
	for i in [3, 5, 6, 8, 11, 13]:   # (el terreno 0 tiene el puesto de café del comienzo)
		var p := Blueprints.to_world(City.PLOTS[i], 0, 0)
		var inside := Blueprints.to_world(City.PLOTS[i], 2.5, 4.5)
		var look := Blueprints.to_world(City.PLOTS[i], -2, 11)
		c.camera.global_position = inside + Vector3(0, 2.2, 0)
		c.camera.look_at(look + Vector3(0, 1.2, 0))
		c.update_lights()
		await m.frames(4)
		await m.shot(ProjectSettings.globalize_path(OUT + "local_noche_%d.png" % i))
	c.camera.global_position = Vector3(-30, 3, 0)
	c.camera.look_at(Vector3(-10, 2, 14))
	c.update_lights()
	await m.frames(4)
	await m.shot(ProjectSettings.globalize_path(OUT + "locales_noche_calle.png"))
