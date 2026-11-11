extends RefCounted
## Ajustes: la fila «Silenciar todo» se ve y silencia el bus maestro.

const OUT := "res://tests/shots/"


func run(m) -> void:
	var c: City = m.city
	m.app.slot = 3
	m.app.new_game("normal")
	await m.frames(5)
	c.hud.help_timer = 0
	c.open_pause()
	c.overlays.pause_page = "ajustes"
	c.settings.mute = true
	c.apply_settings()
	await m.frames(30)
	print("mute bus 0: ", AudioServer.is_bus_mute(0))
	await m.shot(ProjectSettings.globalize_path(OUT + "ajustes_silenciar.png"))
	c.settings.mute = false
	c.apply_settings()
	print("mute bus 0 despues: ", AudioServer.is_bus_mute(0))
