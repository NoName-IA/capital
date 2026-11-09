extends RefCounted
## Viajar a una sucursal desde la tablet: clic en el nombre de la sucursal en Negocios (un local de la avenida y otro
## del centro comercial) y clic en una vitrina ocupada de la pestaña Expansión.
## Godot --path . -- --scenario=res://tests/shot_goto.gd

const OUT := "res://tests/shots/"


## Lleva el mouse a un punto de la pantalla virtual de 1280 × 760 (la que usan las interfaces).
func mouse_to(m, ui: ImUI, v: Vector2) -> void:
	var o := ui.to_virtual(Vector2.ZERO)
	var one := ui.to_virtual(Vector2(1000, 1000))
	var k := (one - o) / 1000.0
	m.get_viewport().warp_mouse((v - o) / k)


## Fila `i` de la lista de sucursales de Negocios (ver Admin.draw_negocios): sobre el nombre.
func row_name(i: int) -> Vector2:
	return Vector2(Admin.CX + 262 + 20 + 30, Admin.CY + 88 + 44 + 50 + 28 + 24 + i * 40 + 18)


func run(m) -> void:
	var c: City = m.city
	m.app.slot = 3
	m.app.new_game("normal")
	await m.frames(5)
	var g: Game = m.app.game
	g.cash += 9000000
	g.unlock("pan")
	c.tutorial.active = false
	g.open_location("pan", 2, 5)       # megatienda en el terreno 6
	g.open_location("pan", 1, 11)      # local en el terreno 12
	g.buy_mall()
	g.open_location("pan", 1, null, 3) # local en la vitrina 4
	c.sync(g)
	await m.frames(5)
	var ui: ImUI = m.ui
	var ok := true
	var ls := g.locs("pan")
	for i in ls.size():
		m.app.tab = "negocios"
		m.app.sel = "pan"
		c.overlays.show("admin")
		mouse_to(m, ui, row_name(i))
		await m.frames(4)
		if i == 0:
			await m.shot(ProjectSettings.globalize_path(OUT + "goto_hover.png"))
		m.mouse_clicked = true
		await m.frames(6)
		var loc: Dictionary = ls[i]
		var want: Vector3
		if Game.mall_of(loc) >= 0:
			want = c.mall.slots[Game.mall_of(loc)].front
		else:
			want = CityMap.plot_target(City.plot_pos(Game.plot_of(loc)))[0]
		var d := Vector2(c.player.position.x - want.x, c.player.position.z - want.z).length()
		print("fila %d (%s): tablet %s · jugador a %.1f m del destino" % [i, Game.place_label(loc), "abierta" if c.overlays.open() else "cerrada", d])
		ok = ok and d < 1.0 and not c.overlays.open()
		await m.frames(20)
		await m.shot(ProjectSettings.globalize_path(OUT + "goto_%d.png" % i))
	# Expansión: clic en la vitrina 4 (fila 0, columna 3 de la grilla)
	c.teleport(Blueprints.to_world(City.HQ, 0, -2.5), 0.0)
	m.app.tab = "expansion"
	c.overlays.show("admin")
	var tw := (520.0 - 40 - 3 * 8) / 4
	mouse_to(m, ui, Vector2(Admin.CX + 20 + 3 * (tw + 8) + 30, 340))
	await m.frames(4)
	await m.shot(ProjectSettings.globalize_path(OUT + "goto_vitrina_hover.png"))
	m.mouse_clicked = true
	await m.frames(6)
	var front: Vector3 = c.mall.slots[3].front
	var dv := Vector2(c.player.position.x - front.x, c.player.position.z - front.z).length()
	print("vitrina 4 desde Expansión: jugador a %.1f m" % dv)
	ok = ok and dv < 1.0
	print("OK viajar" if ok else "FALLA viajar")
