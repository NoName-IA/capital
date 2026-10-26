extends RefCounted
## Los fondos de la pantalla de inicio: cada lugar a una hora distinta.

const OUT := "res://tests/shots/"


func run(m) -> void:
	var c: City = m.city
	for i in City.MENU_PLACES.size():
		c.pick_menu_backdrop()
		c.menu_place = City.MENU_PLACES[i]
		c.menu_hour = City.MENU_HOURS[i % City.MENU_HOURS.size()]
		c.menu_t = 0.0
		await m.frames(30)
		await m.shot(ProjectSettings.globalize_path(OUT + "fondo_%d_%s.png" % [i, c.menu_place]))
