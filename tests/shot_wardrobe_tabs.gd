extends RefCounted
## El armario: pestañas Piernas y Accesorios (fotos de los pantalones y de los audífonos) y la vuelta al frente.


func run(m) -> void:
	var c: City = m.city
	m.app.new_game("normal")
	await m.frames(5)
	m.app.modal = null
	c.overlays.hide()
	c.go_to_office()
	await m.frames(10)
	c.player.position = c.hq_spots.wardrobe
	c.yaw = 0
	c.open_custom()
	for tab in ["piernas", "accesorios"]:
		c.overlays.shop_tab = tab
		for i in 90:
			await m.frames(1)
		await m.shot(ProjectSettings.globalize_path("res://tests/shots/armario_%s.png" % tab))
	# Vuelta al frente: se gira y se suelta
	var front: float = c.player.rotation.y
	c.player.rotation.y += 2.0
	var t0 := Time.get_ticks_msec()
	while absf(wrapf(c.player.rotation.y - front, -PI, PI)) > 0.05 and Time.get_ticks_msec() - t0 < 6000:
		await m.frames(1)
	print("volvió al frente en ", (Time.get_ticks_msec() - t0) / 1000.0, " s")
