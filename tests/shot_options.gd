extends RefCounted
## Capturas de cada página de Opciones del menú de pausa (y de cada pestaña de Gráficos).

const OUT := "res://tests/shots/"


func run(m) -> void:
	var c: City = m.city
	m.app.slot = 3
	m.app.new_game("normal")
	await m.frames(5)
	c.hud.help_timer = 0
	c.open_pause()
	for p in c.overlays.PAUSE_PAGES:
		c.overlays.settings_scroll = 0.0
		c.overlays.pause_page = p[0]
		if p[0] == "graficos":
			for t in c.overlays.GFX_TABS:
				c.overlays.gfx_tab = t[0]
				await m.frames(20)
				await m.shot(ProjectSettings.globalize_path(OUT + "opt_%s_%s.png" % [p[0], t[0]]))
		else:
			await m.frames(20)
			await m.shot(ProjectSettings.globalize_path(OUT + "opt_%s.png" % p[0]))
	c.close_pause()
