extends RefCounted
## La fila del idioma en Ajustes: nombres en el idioma actual (y en el suyo, chiquito) y el botón «Aplicar cambios».

const OUT := "res://tests/shots/"


func run(m) -> void:
	var c: City = m.city
	m.app.new_game("normal")
	await m.frames(10)
	for code in ["es", "en", "zh"]:
		Lang.use(code)
		c.overlays.show("pausa")
		c.overlays.pause_page = "ajustes"
		await m.frames(4)
		await m.shot(ProjectSettings.globalize_path(OUT + "langrow_%s_actual.png" % code))
		c.overlays.lang_pick = (Lang.index() + 3) % Lang.CODES.size()   # elegido pero sin aplicar
		await m.frames(4)
		await m.shot(ProjectSettings.globalize_path(OUT + "langrow_%s_elegido.png" % code))
	Lang.use("es")
