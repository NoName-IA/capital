extends RefCounted
## Créditos: un clic en una canción la pone. Godot --path . -- --scenario=res://tests/shot_credits_song.gd
func run(m) -> void:
	var c: City = m.city
	await m.frames(10)
	m.app.view = "menu"
	m.app.credits_open = true
	c.overlays.show("admin")
	await m.frames(10)
	print("sonando: ", c.sfx.now_playing())
	c.sfx.play_song(Sfx.SONGS.size() - 1)
	await m.frames(20)
	print("después del clic: ", c.sfx.now_playing(), " · ", c.sfx.music.playing)
	await m.shot(ProjectSettings.globalize_path("res://tests/shots/creditos_cancion.png"))
