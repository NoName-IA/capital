extends RefCounted
## Sonda: ¿empieza el final si al ganar estás en la computadora, con la tablet abierta o en la presidencia?
## Godot --path . -- --scenario=res://tests/probe_finale_state.gd --estado=pc|tablet|arriba|nada


func run(m) -> void:
	var c: City = m.city
	var estado := "nada"
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--estado="):
			estado = a.get_slice("=", 1)
	m.app.load_slot(3)
	var g: Game = m.app.game
	c.sync(g)
	m.app.paused = false
	m.app.modal = null
	c.overlays.hide()
	match estado:
		"pc":
			c.player.position = c.tower.w(Tower.ARRIVE)
			c.sit_at_computer()
			c.pc_phase = "os"
			c.overlays.show("pc")
			var w := 0
			while c.pc_phase != "os" and w < 600:
				await m.frames(1)
				w += 1
			m.app.paused = false
			print("en la computadora: ", c.pc_phase, " · overlay ", c.overlays.mode)
		"tablet":
			c.overlays.show("admin")
		"arriba":
			c.player.position = c.tower.w(Tower.ARRIVE)
	var n := 0
	while not g.won and n < 4000:
		await m.frames(1)
		n += 1
	print(estado, ": ganó ", g.won, " · pc ", c.pc_phase, " · overlay ", c.overlays.mode, " · pausa ", m.app.paused)
	for i in 6:
		await m.get_tree().create_timer(1.0).timeout
		print("  +", i + 1, "s fase '", c.finale.phase, "' t ", snappedf(c.finale.t, 0.1), " · pc '", c.pc_phase, "' · overlay ", c.overlays.mode, " · tutorial ", c.tutorial.active)
