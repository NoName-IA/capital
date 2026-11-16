extends RefCounted
## Megatienda en el terreno de al lado de la planta eléctrica (no deben chocar).
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
	g.cash = 5000000.0
	var plot := City.PLOTS.size() + City.COMP_PLOTS.find([-143, 1])
	g.plot_owner.erase(str(plot))
	g.rival_plots.erase(str(plot))
	print("abrir megatienda: ", g.open_location("cafe", 2, plot))
	c.sync(g)
	await m.frames(20)
	m.ui.set_visible(false)
	m.set_process(false)
	for v in [["calle", Vector3(-132, 3, 1), Vector3(-152, 5, 22)], ["aire", Vector3(-120, 40, -8), Vector3(-150, 2, 28)]]:
		c.camera.global_position = v[1]
		c.camera.look_at(v[2])
		await m.frames(5)
		await m.shot(ProjectSettings.globalize_path(OUT + "planta_mega_%s.png" % v[0]))
