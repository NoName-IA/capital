extends RefCounted
## El bate: se compra en el armario, se ve en la mano, el batazo apura al local 3 segundos y cada golpe lo renueva.
## Godot --path . -- --scenario=res://tests/shot_bat.gd
const OUT := "res://tests/shots/"


func run(m) -> void:
	var c: City = m.city
	m.app.slot = 3
	m.app.new_game("normal")
	await m.frames(5)
	var g: Game = m.app.game
	c.tutorial.stop()
	g.tutorial_step = -1
	m.app.modal = null
	c.overlays.hide()
	g.cash = 100000.0
	var res := g.buy_item(Wardrobe.item_id("bat", true), Wardrobe.item_price("bat", true))
	print("compra del bate: ", res)
	g.look["bat"] = true
	c.apply_look()
	var loc: Dictionary = g.locations[0]
	g.hire(loc)
	c.sync(g)
	await m.frames(10)
	c.set_hand(0)
	print("manos libres: ", c.hand(), " · bate en la mano: ", c.player.bat != null)
	await m.frames(3)
	await m.shot(ProjectSettings.globalize_path(OUT + "bate_barra_manos.png"))
	c.set_hand(1)
	print("con el bate: ", c.hand(), " · bate en la mano: ", c.player.bat != null)
	await m.frames(3)
	await m.shot(ProjectSettings.globalize_path(OUT + "bate_barra.png"))
	var st: Store = c.stores.values()[0]
	print("empleados: ", st.staff.size(), " · tiempo de atención normal: ", st.service_time())
	var w: Person = st.staff[0]
	var dir := Vector3(0, 0, -1) * float(st.plot[1])
	c.teleport(w.global_position + Vector3(0.0, 0, 1.2 * -dir.z), 0.0, "")
	await m.frames(3)
	c.player.rotation.y = atan2(w.global_position.x - c.player.position.x, w.global_position.z - c.player.position.z)
	await m.frames(1)
	c.swing_bat()
	print("después del batazo: apuro ", st.rush, " · tiempo de atención ", st.service_time())
	await m.frames(6)
	m.set_process(false)
	c.camera.global_position = c.player.position + Vector3(2.4, 2.0, 1.5 * dir.z * -1.0)
	c.camera.look_at(c.player.position.lerp(w.global_position, 0.5) + Vector3(0, 1.3, 0))
	await m.frames(2)
	await m.shot(ProjectSettings.globalize_path(OUT + "bate_golpe.png"))
	m.set_process(true)
	var t0 := Time.get_ticks_msec()
	while st.rush > 0.0 and Time.get_ticks_msec() - t0 < 6000:
		await m.frames(1)
	print("el apuro se terminó solo en ", (Time.get_ticks_msec() - t0) / 1000.0, " s · tiempo de atención ", st.service_time())
