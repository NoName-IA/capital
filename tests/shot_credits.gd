extends RefCounted
## «Créditos» en el menú de inicio (autores y música) y la lista de canciones (pasa sola a la siguiente).


func run(m) -> void:
	await m.frames(30)
	print("menú: ", m.app.view, " · ventana: ", m.city.overlays.mode)
	await m.shot(ProjectSettings.globalize_path("res://tests/shots/creditos_menu.png"))
	var sfx: Sfx = m.city.sfx
	print("suena: ", sfx.now_playing(), " · reproduciendo: ", sfx.music.playing)
	var seen := [sfx.song]
	for i in 6:   # salta al final de la canción: tiene que empezar otra distinta
		var before := sfx.song
		sfx.music.seek(sfx.music.stream.get_length() - 0.3)
		await m.frames(40)
		print("después: ", sfx.now_playing()[1], " · distinta: ", sfx.song != before, " · reproduciendo: ", sfx.music.playing)
		seen.append(sfx.song)
	var unique := {}
	for s in seen.slice(0, 5):
		unique[s] = true
	print("las primeras 5 fueron todas distintas: ", unique.size() == 5)
	m.app.credits_open = true
	await m.frames(10)
	await m.shot(ProjectSettings.globalize_path("res://tests/shots/creditos.png"))
