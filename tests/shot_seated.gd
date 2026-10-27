extends RefCounted
## Clientes que compran y se sientan a comer en las mesas del local (y los que se van si no hay silla libre).

const OUT := "res://tests/shots/"


func run(m) -> void:
	var c: City = m.city
	m.app.new_game("normal")
	var g: Game = m.app.game
	g.next_choice_day = 100000
	g.cash += 2000000
	g.unlock("burger")
	# Locales y megatiendas de comida hasta que alguno tenga mesas
	for i in 6:
		g.open_location(["cafe", "burger"][i % 2], 1 if i < 4 else 2)
	await m.frames(30)
	var store: Store = null
	for s in c.stores.values():
		if not s.spots.get("chairs", []).is_empty() and (store == null or s.loc.size > store.loc.size):
			store = s
	if store == null:
		print("SIN MESAS en ningún local")
		return
	var chairs: Array = store.spots.chairs
	print("local con mesas: tamaño ", store.loc.size, " · sillas ", chairs.size())
	# Llena todas las sillas con clientes que acaban de pagar, y uno más que ya no encuentra silla
	var ex: Array = store.spots.lines[0].exit
	var sat := 0
	var tries := 0
	while sat < chairs.size() and tries < 200:
		tries += 1
		var cu := Customer.new(c, store)
		c.customers.append(cu)
		cu.body.position = ex[0]
		cu.body.hold(store.loc.product)
		if cu._go_sit(ex):
			sat += 1
		else:
			cu.leave(ex)
	var extra := Customer.new(c, store)
	c.customers.append(extra)
	extra.body.position = ex[0]
	var free_after := store.free_chair()
	print("sentados ", sat, " de ", chairs.size(), " · silla libre para uno más: ", free_after)
	m.app.paused = false
	await m.frames(240)
	var states := {}
	for cu in c.customers:
		if cu.store == store:
			states[cu.state] = states.get(cu.state, 0) + 1
	print("estados: ", states)
	# Cámara adentro, mirando las mesas
	m.ui.set_visible(false)
	c.hud.ui.set_visible(false)
	m.set_process(false)
	var ch: Dictionary = chairs[0]
	var mid: Vector3 = ch.table
	var inside: Vector3 = store.spots.door + (mid - store.spots.door) * 0.35
	c.camera.global_position = inside + Vector3(0, 2.3, 0)
	c.camera.look_at(mid + Vector3(0, 0.6, 0))
	c.update_lights()
	await m.frames(4)
	await m.shot(ProjectSettings.globalize_path(OUT + "sentados_1.png"))
	c.camera.global_position = mid + (ch.near - ch.seat).normalized() * 2.2 + Vector3(0, 1.8, 0)
	c.camera.look_at(mid + Vector3(0, 0.5, 0))
	await m.frames(4)
	await m.shot(ProjectSettings.globalize_path(OUT + "sentados_2.png"))
	m.set_process(true)
	await m.frames(1200)   # al rato se paran, sueltan la silla y se van
	print("sillas ocupadas después: ", store.seated.size())
