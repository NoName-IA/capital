extends RefCounted
## Mide los cuadros por segundo jugando en la avenida (con clientes y autos).


func run(m) -> void:
	m.app.new_game("normal")
	await m.frames(5)
	var g: Game = m.app.game
	g.cash += 2000000
	g.unlock("pan")
	g.open_location("cafe", 1, 2)
	g.open_location("pan", 2, 3)
	g.open_location("cafe", 1, 4)
	m.city.player.position = Vector3(0, 0, 5)
	m.city.yaw = 60
	m.city.hud.help_timer = 0
	await m.frames(300)
	var t0 := Time.get_ticks_usec()
	await m.frames(300)
	var ms := (Time.get_ticks_usec() - t0) / 300000.0
	print("ms por cuadro: %.1f  (%.0f FPS)  dibujos: %d  clientes: %d" % [ms, 1000.0 / ms,
			RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_TOTAL_DRAW_CALLS_IN_FRAME), m.city.customers.size()])
