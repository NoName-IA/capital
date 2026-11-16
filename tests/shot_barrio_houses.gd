extends RefCounted
## Casas del Barrio Las Lomas para alquilar: letrero SE VENDE, comprar una (letrero ALQUILADA) y el mapa.
## Godot --path . -- --scenario=res://tests/shot_barrio_houses.gd
const OUT := "res://tests/shots/"


func run(m) -> void:
	var c: City = m.city
	m.app.slot = 3
	m.app.new_game("normal", true)
	await m.frames(5)
	var g: Game = m.app.game
	c.tutorial.stop()
	g.cash += 500000
	c.sync(g)
	m.app.paused = true
	c.sky_lock = 0.45
	print("casas en venta: ", c.builder.sale_houses.size(), " · letreros: ", c.house_signs.size())
	var sign: Dictionary = c.house_signs[1]
	var h: Dictionary = c.builder.sale_houses[1]
	c.teleport(sign.manage + Vector3(2.5, 0, h.face * 1.5), 0.0 if h.face == -1 else 180.0, "")
	await m.frames(40)
	m.app.modal = null
	c.overlays.hide()
	await m.frames(5)
	print("aviso: ", c.hud.prompt)
	await m.shot(ProjectSettings.globalize_path(OUT + "barrio_casa_venta.png"))
	c.teleport(sign.manage, 0.0 if h.face == -1 else 180.0, "")
	await m.frames(20)
	print("aviso junto al letrero: ", c.hud.prompt)
	c.buy_house(1, true)
	await m.frames(20)
	print("casa comprada: ", g.houses.has("1"), " · renta al mes: ", g.house_rent_monthly())
	await m.shot(ProjectSettings.globalize_path(OUT + "barrio_casa_alquilada.png"))
	c.overlays.show("mapa")
	await m.frames(10)
	await m.shot(ProjectSettings.globalize_path(OUT + "barrio_mapa.png"))
