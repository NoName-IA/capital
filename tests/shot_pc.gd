extends RefCounted
## La computadora de la oficina: sentarte, la cámara entra a la pantalla, «Ventanas 98», Remodelar.exe, los chistes y
## levantarte. Godot --path . -- --scenario=res://tests/shot_pc.gd
const OUT := "res://tests/shots/"


func _shot(m, name: String) -> void:
	await m.shot(ProjectSettings.globalize_path(OUT + "pc_" + name + ".png"))


func _wait_phase(m, c: City, phase: String, limit := 400) -> void:
	var n := 0
	while c.pc_phase != phase and n < limit:
		await m.frames(1)
		n += 1


func run(m) -> void:
	var c: City = m.city
	m.app.slot = 3
	m.app.new_game("normal", true)
	await m.frames(5)
	var g: Game = m.app.game
	c.tutorial.stop()
	g.cash += 50000
	g.open_location("cafe", 1)
	g.open_location("pan", 0) if g.products.pan.unlocked else null
	c.sync(g)
	c.go_to_office()
	c.player.position = c.hq_spots.computer + Vector3(1.0, 0, -1.2)
	c.yaw = -70.0
	await m.frames(20)
	var prompts := c.interactables().filter(func(it): return "computadora" in str(it[1]))
	print("aviso de la computadora: ", prompts.map(func(it): return it[1]))
	await _shot(m, "0_antes")
	c.sit_at_computer()
	await m.frames(25)
	await _shot(m, "1_caminando")
	await _wait_phase(m, c, "zoom")
	await m.frames(30)
	await _shot(m, "2_entrando")
	await _wait_phase(m, c, "os")
	await m.frames(30)
	print("fase: ", c.pc_phase, " · ventana: ", c.overlays.mode)
	await _shot(m, "3_arranque")
	c.pc_os.t = Ventanas.BOOT + 0.1
	await m.frames(10)
	await _shot(m, "4_escritorio")
	c.pc_os._open("remodelar")
	await m.frames(60)   # que se armen las fotos de los artículos
	var items: Array = D.upgrades_for(int(g.locations[0].size))
	c.pc_os.item_sel = items[0].key
	await m.frames(10)
	await _shot(m, "5_remodelar")
	var before: int = g.locations[0].get("upgrades", []).size()
	var res: Array = g.buy_decor(g.locations[0], items[0].key)
	print("comprar desde la compu: ", res, " · decoraciones ", before, " -> ", g.locations[0].get("upgrades", []).size())
	c.pc_os._open("web")
	c.pc_os._open("papelera")
	c.pc_os._open("docs")
	c.pc_os.start_open = true
	await m.frames(10)
	await _shot(m, "6_ventanas_inicio")
	c.pc_os.start_open = false
	c.pc_os._message("Ventanas Update", "Hay 1 actualización obligatoria (4,7 TB). Tu computadora se reiniciará en 10 minutos.", true)
	await m.frames(5)
	await _shot(m, "7_actualizacion")
	c.pc_os.msg = null
	# La tablet desde la compu: al cerrarla vuelves al escritorio
	c.pc_os._open("empresa")
	await m.frames(10)
	print("Mi Empresa -> ventana: ", c.overlays.mode)
	c.overlays.hide()
	await m.frames(5)
	print("al cerrar la tablet -> ventana: ", c.overlays.mode, " · fase ", c.pc_phase)
	# Una decisión urgente mientras estás en la compu: espera a que te levantes
	g.pending_choice = g.build_dilemma("soborno")
	await m.frames(10)
	print("decisión en la compu: pendiente ", g.pending_choice != null, " · modal ", m.app.modal, " · ventana ", c.overlays.mode)
	# Apagar desde el menú Inicio: te levantas solo
	c.pc_os.leaving = 0.6
	await m.frames(60)
	print("después de Apagar: fase '", c.pc_phase, "'")
	await m.frames(10)
	await _shot(m, "8_saliendo")
	await _wait_phase(m, c, "")
	await m.frames(10)
	print("decisión al levantarte -> modal ", m.app.modal)
	print("después de levantarte: fase '", c.pc_phase, "' · altura ", snappedf(c.player.position.y, 0.01), " · ventana ", c.overlays.mode)
	await _shot(m, "9_de_pie")
