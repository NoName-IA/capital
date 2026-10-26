extends RefCounted
## Pantalones (jeans, de vestir, bermudas) y audífonos con y sin sombrero, de frente, de costado y de atrás.

const OUT := "res://tests/shots/"


func run(m) -> void:
	var c: City = m.city
	m.app.new_game("normal")
	await m.frames(5)
	m.app.modal = null
	c.overlays.hide()
	m.app.paused = true
	await m.frames(10)
	m.ui.set_visible(false)
	c.hud.ui.set_visible(false)
	m.set_process(false)
	c.sky.set_time(0.45)
	var looks := [{"pants_style": "jeans", "pants": [70, 100, 150], "headphones": true},
			{"pants_style": "vestir", "pants": [40, 40, 45], "jacket": "blazer", "tie": true, "headphones": true, "hat": "gorra"},
			{"pants_style": "cortos", "pants": [170, 155, 125], "shoes": [245, 245, 245], "headphones": true, "hair_style": "largo"},
			{"pants_style": "jeans", "pants": [40, 50, 80], "headphones": true, "hat": "vaquero"}]
	var base := Vector3(30, 0, -12)
	var people := []
	for i in looks.size():
		var p := Person.new(null, null, false, looks[i])
		c.add_child(p)
		p.position = base + Vector3(i * 1.4 - 2.1, 0, 0)
		people.append(p)
	# La cámara del lado del sol (z negativa), mirando las piernas de cerca
	for v in [["frente", PI], ["costado", PI * 1.5], ["atras", 0.0]]:
		for p in people:
			p.rotation.y = v[1]
		c.camera.global_position = base + Vector3(0, 0.55, -2.9)
		c.camera.look_at(base + Vector3(0, 0.5, 0))
		await m.frames(4)
		await m.shot(ProjectSettings.globalize_path(OUT + "ropa_%s.png" % v[0]))
	c.camera.global_position = base + Vector3(-1.4, 1.95, -2.2)
	c.camera.look_at(base + Vector3(-1.4, 1.85, 0))
	for p in people:
		p.rotation.y = PI + 0.6
	await m.frames(4)
	await m.shot(ProjectSettings.globalize_path(OUT + "ropa_audifonos.png"))
