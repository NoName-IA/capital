extends RefCounted
## El aviso de nuevo rango es una cinta arriba al centro con un gráfico que sube (sin confeti), y los récords
## esperan si acabas de cerrar una decisión urgente.
## Godot --path . -- --scenario=res://tests/shot_rank_banner.gd
const OUT := "res://tests/shots/"


func wait(m, sec: float) -> void:
	await m.get_tree().create_timer(sec).timeout


func run(m) -> void:
	var c: City = m.city
	var app = m.app
	app.slot = 3
	app.new_game("normal", true)
	await m.frames(5)
	c.tutorial.stop()
	c.hud.notes.clear()
	app.last_dilemma_ms = -Admin.GAP_MS
	c.react({"fx": "rank", "value": "Emprendedor", "text": ""})
	await wait(m, 0.8)
	await m.shot(ProjectSettings.globalize_path(OUT + "rank_banner_1.png"))
	await wait(m, 1.4)
	await m.shot(ProjectSettings.globalize_path(OUT + "rank_banner_2.png"))
	await wait(m, 3.0)
	print("rango -> se fue: ", c.hud.notes.hero == null)
	# Un récord justo después de cerrar una decisión: espera
	app.last_dilemma_ms = app.now_ms()
	c.react({"fx": "record", "value": 1234567.0, "text": ""})
	await m.frames(5)
	print("récord con decisión recién cerrada -> en espera: ", c.hud.notes.hero == null and c.hud.notes.heroes.size() == 1)
	app.last_dilemma_ms = app.now_ms() - Admin.GAP_MS - 10
	await wait(m, 2.0)
	print("pasaron 45 s -> en pantalla: ", c.hud.notes.hero != null)
	await m.shot(ProjectSettings.globalize_path(OUT + "rank_banner_record.png"))
	# Un rango más alto: la escalera ya va por la mitad
	await wait(m, 4.5)
	c.react({"fx": "rank", "value": "Magnate", "text": ""})
	await wait(m, 2.0)
	await m.shot(ProjectSettings.globalize_path(OUT + "rank_banner_magnate.png"))
