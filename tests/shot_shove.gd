extends RefCounted
## El jugador se para delante de un peatón y no lo deja pasar: pide permiso, grita y, si es de los que empujan
## (45 %), lo saca de su camino hacia el costado. Los demás solo protestan.


func run(m) -> void:
	m.app.new_game("normal")
	await m.frames(5)
	m.app.modal = null
	m.city.overlays.hide()
	var pushers := 0
	for i in 2000:
		if Customer.new(m.city).pusher:
			pushers += 1
	print("empujan: ", pushers / 20.0, " %")
	for c in m.city.customers.duplicate():
		c.destroy()
	m.city.customers.clear()
	for push in [true, false]:
		var c := Customer.new(m.city)
		c.pusher = push
		m.city.customers.append(c)
		c.body.position = Vector3(20, 0, Customer.SIDEWALK)
		c.path = [Vector3(60, 0, Customer.SIDEWALK)]
		c.state = "leave"
		var hit_at := -1
		var t0 := Time.get_ticks_msec()
		var secs := 0.0
		while secs < 9.0:
			secs = (Time.get_ticks_msec() - t0) / 1000.0
			if m.city.knock == null and hit_at < 0:   # le tapa el paso: siempre medio metro delante
				m.city.player.position = c.body.position + Vector3(0.55, 0, 0)
			if m.city.knock != null and hit_at < 0:
				hit_at = 1
				print("empujón a los ", secs, " s")
			if push and hit_at > 0 and m.city.knock != null and m.city.knock.t > 0.15 and hit_at == 1:
				hit_at = 2
				await m.shot(ProjectSettings.globalize_path("res://tests/shots/empujon.png"))
			if hit_at > 0 and m.city.knock == null:
				break
			await m.frames(1)
		var off: Vector3 = m.city.player.position - c.body.position
		print("pusher=", push, " · empujó: ", hit_at > 0, " · quedó a ", snappedf(absf(off.z), 0.01),
				" m del camino (de costado) y ", snappedf(off.x, 0.01), " m adelante")
		c.destroy()
		m.city.customers.erase(c)
