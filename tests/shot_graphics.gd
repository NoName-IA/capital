extends RefCounted
## Capturas y cuadros por segundo en cada nivel de gráficos (Bajo, Medio, Alto), de día, al atardecer y de noche.

const OUT := "res://tests/shots/"
const VIEWS := [["avenida", Vector3(-6, 3.2, 9), Vector3(-14, 2.2, -12)], ["aereo", Vector3(-20, 30, -60), Vector3(20, 0, 30)],
		["oficina", Vector3(-60, 6, -4), Vector3(-80, 8, 18)]]


func run(m) -> void:
	var c: City = m.city
	# La página de gráficos del menú de pausa
	m.app.slot = 3
	m.app.new_game("normal")
	await m.frames(5)
	c.hud.help_timer = 0
	c.open_pause()
	c.overlays.pause_page = "graficos"
	await m.frames(30)
	await m.shot(ProjectSettings.globalize_path(OUT + "q_menu_graficos.png"))
	c.close_pause()
	m.ui.set_visible(false)
	m.set_process(false)
	for q in 3:
		c.settings.quality = q
		c.apply_settings()
		for t in [[0.3, "dia"], [0.6, "tarde"], [0.81, "noche"]]:
			c.sky.set_time(t[0])
			for v in VIEWS:
				if t[1] != "dia" and v[0] == "aereo":
					continue
				c.camera.global_position = v[1]
				c.camera.look_at(v[2])
				await m.frames(4)
				await m.shot(ProjectSettings.globalize_path(OUT + "q%d_%s_%s.png" % [q, t[1], v[0]]))
		c.sky.set_time(0.3)
		c.camera.global_position = VIEWS[0][1]
		c.camera.look_at(VIEWS[0][2])
		await m.frames(60)
		var t0 := Time.get_ticks_usec()
		await m.frames(120)
		var ms := (Time.get_ticks_usec() - t0) / 120000.0
		print("%s: %.1f ms por cuadro (%.0f FPS)" % [Graphics.LEVELS[q], ms, 1000.0 / ms])
