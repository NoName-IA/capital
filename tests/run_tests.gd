extends Node
## Pruebas del motor económico (las mismas de tests/test_sim.py en la versión de Python).
## Correr con: Godot --headless --path . res://tests/run_tests.tscn

var failures := 0
var checks := 0


func _ready() -> void:
	for t in ["test_equity_change_equals_net_income", "test_every_dilemma_outcome_is_booked",
			"test_save_and_load_continue", "test_wardrobe", "test_modes", "test_fund_hq_and_sweep",
			"test_strategies", "test_rivals_buy_empty_plots", "test_selling_to_a_rival", "test_beach_plots",
			"test_formats", "test_no_stock_without_stores", "test_loan_interest_accrues",
			"test_weather_moves_demand", "test_stars", "test_city_activities", "test_decor", "test_solar",
			"test_labor", "test_every_micro_is_booked", "test_rivals_alive", "test_buy_that_building", "test_old_saves"]:
		var before := failures
		call(t)
		print(("OK    " if failures == before else "FALLA ") + t)
	print("%d comprobaciones, %d fallas" % [checks, failures])
	get_tree().quit(1 if failures else 0)


func check(cond: bool, msg := "") -> void:
	checks += 1
	if not cond:
		failures += 1
		push_error("  falló: " + msg)
		print("  falló: " + msg)


func near(a: float, b: float, delta := 0.01, msg := "") -> void:
	check(absf(a - b) <= delta, "%s: %f != %f" % [msg, a, b])


func net_income(g: Game) -> float:
	var total := 0.0
	for h in g.history:
		total += Game.statement(h).utilidad_neta
	return total + Game.statement(g.ledger).utilidad_neta


## Hace un poco de todo para tocar todas las cuentas contables.
func busy_player(g: Game, day: int) -> void:
	var cafe: Dictionary = g.products.cafe
	if day % 9 == 0:   # las actividades de la ciudad también tienen que cuadrar en la contabilidad
		for a in D.ACTIVITIES:
			g.do_activity(a[0], 18.0)
	if day == 5:
		g.take_loan(4000, 12)
	if day % 20 == 0:
		for loc in g.locations:
			if loc.demand > loc.capacity:
				g.hire(loc)
	if day == 60:
		cafe.marketing = 300.0
	if day == 200:
		g.upgrade_location(g.locations[0])
	if day == 300:
		g.buy_bonds(2000)
		g.open_location("cafe", 0)
	if day == 420:
		g.unlock("pan")
		g.open_location("pan", 0)
		g.products.pan.manager = true
	if day == 500 and g.locs("cafe").size() > 1:
		g.sell_location(g.locs("cafe")[-1])
	if g.pending_choice != null:
		g.resolve_choice(day % g.pending_choice.options.size())
	if day == 600:
		g.sell_bonds(1000)
		if g.cash >= g.acquire_cost("cafe"):
			g.acquire("cafe")


func test_equity_change_equals_net_income() -> void:
	var g := Game.new(3)
	var start: float = g.balance().patrimonio
	for day in 35 * 30:
		busy_player(g, day)
		g.step_day()
	check(not g.game_over, "no debería quebrar")
	if g.game_over:   # para ver qué pasó
		for n in g.news.slice(-40):
			print("    día %d [%s] %s" % [n.day, n.kind, n.text])
	near(g.balance().patrimonio - start, net_income(g), 1.0, "patrimonio vs utilidad")


func test_every_dilemma_outcome_is_booked() -> void:
	var base := Game.new(11)
	for day in 200:
		if base.pending_choice != null:
			base.resolve_choice(0)
		base.step_day()
	base.cash += 100000
	base.open_location("cafe", 1)
	base.pending_choice = null
	for id in Game.DILEMMAS:
		for seed in 6:
			var g := Game.from_json(base.to_json())
			g.rng.seed = seed
			g.pending_choice = g.build_dilemma(id)
			for opt in g.pending_choice.options.size():
				var h := Game.from_json(g.to_json())
				var eq: float = h.balance().patrimonio
				var ni: float = Game.statement(h.ledger).utilidad_neta
				h.resolve_choice(opt)
				check(h.pending_choice == null, id)
				near(h.balance().patrimonio - eq, Game.statement(h.ledger).utilidad_neta - ni, 0.01, "%s opción %d" % [id, opt])


func test_save_and_load_continue() -> void:
	var a := Game.new(7)
	for day in 130:
		busy_player(a, day)
		a.step_day()
	var b := Game.from_json(a.to_json())
	for i in 90:
		a.step_day()
		b.step_day()
	near(a.cash, b.cash, 0.000001, "caja igual después de cargar")
	check(a.news.size() == b.news.size(), "mismas noticias")


func test_wardrobe() -> void:
	var g := Game.new(2)
	check(not g.unlock_wardrobe()[0], "$1.500 no alcanza")
	g.cash += 10000
	var eq: float = g.balance().patrimonio
	var ni: float = Game.statement(g.ledger).utilidad_neta
	check(g.unlock_wardrobe()[0], "armario")
	check(g.buy_item("hat=copa", 5000)[0], "sombrero")
	check(g.buy_item("hat=copa", 5000)[0], "no se cobra dos veces")
	check(g.owned_items == ["hat=copa"], "prendas")
	var spent := g.wardrobe_cost() + g.item_price(5000)
	near(Game.statement(g.ledger).utilidad_neta - ni, -spent, 0.01, "gasto")
	near(g.balance().patrimonio - eq, -spent, 0.01, "patrimonio")
	check(Game.new(3).owned_items.is_empty(), "partida nueva sin ropa")
	var b := Game.from_json(g.to_json())
	check(b.wardrobe and b.owned_items == ["hat=copa"], "se guarda la ropa")


func test_modes() -> void:
	var normal := Game.new(1)
	var inv := Game.new(1, "inversionista")
	near(normal.cash, D.START_CASH, 0.01, "caja inicial")
	check(inv.cash > 100000, "inversionista")
	check(normal.ranks()[-1][1] == "Imperio", "fin normal")
	check(inv.ranks()[-1][1] == "Mil millonario", "fin inversionista")
	near(normal.win_value(), D.WIN_VALUE, 0.01, "meta")
	check(Game.from_json(inv.to_json()).mode == "inversionista", "modo guardado")


func test_fund_hq_and_sweep() -> void:
	var g := Game.new(4, "inversionista")
	var start: float = g.balance().patrimonio
	check(g.upgrade_hq()[0], "erp")
	check(g.invest_fund(100000)[0], "fondo")
	for i in 200:
		g.step_day()
	near(g.balance().patrimonio - start, net_income(g), 1.0, "fondo y oficina")
	g.cash = -50000.0
	var fund := g.fund
	g.step_day()
	check(g.cash >= 0.0, "barrido cubre la caja")
	check(g.fund < fund, "se vendió parte del fondo")


func test_strategies() -> void:
	var g := Game.new(6)
	g.cash += 50000
	for i in 40:
		g.step_day()
	var eq: float = g.balance().patrimonio
	var ni: float = Game.statement(g.ledger).utilidad_neta
	var rep: float = g.products.cafe.reputation
	check(g.run_strategy("capacitacion")[0], "capacitación")
	near(g.products.cafe.reputation, min(100.0, rep + 6), 0.0001, "reputación")
	check(not g.run_strategy("campana")[0], "hay que esperar 30 días")
	near(g.balance().patrimonio - eq, Game.statement(g.ledger).utilidad_neta - ni, 0.01, "estrategia contable")
	for i in 30:
		g.step_day()
	check(g.run_strategy("proveedores")[0], "proveedores")
	near(g.products.cafe.cost_shock, 0.9, 0.0001, "costo")


func test_rivals_buy_empty_plots() -> void:
	var g := Game.new(3)
	g.cash += 1e6
	g.locations[0].plot = 2
	for i in 720:
		if g.pending_choice != null:
			g.resolve_choice(g.pending_choice.options.size() - 1)
		g.step_day()
		check(g.rival_plots.size() <= D.RIVAL_PLOT_MAX, "máximo de terrenos")
		check(not g.rival_plots.has("2"), "nunca compran un terreno tuyo")
	check(g.rival_plots.size() > 0, "compran algún terreno")
	check(g.free_plots().size() >= 3, "dejan terrenos libres")
	check(Game.from_json(g.to_json()).rival_plots == g.rival_plots, "se guardan")


func test_selling_to_a_rival() -> void:
	var g := Game.new(5)
	g.cash += 1e6
	g.locations[0].plot = 0
	g.open_location("cafe", 0, 9)
	var comps: int = g.products.cafe.competitors
	g.pending_choice = g.build_dilemma("compra_rival")
	var loc = g.find_location(g.pending_choice.data.loc_id)
	var plot: int = loc.plot
	g.resolve_choice(0)
	check(not (loc in g.locations), "se vendió")
	check(g.rival_plots.get(str(plot)) == "cafe", "el terreno es del rival")
	check(g.products.cafe.competitors == comps + 1, "un competidor más")
	g.acquire("cafe")
	check(g.locations[-1].plot == plot, "recuperas el mismo terreno")
	check(not g.rival_plots.has(str(plot)), "ya no es del rival")


func test_beach_plots() -> void:
	var g := Game.new(1)
	var loc: Dictionary = g.locations[0]
	var p: Dictionary = g.products[loc.product]
	loc.plot = 2
	var city := g.demand_at(p, loc, p.price)
	loc.plot = D.BEACH_PLOTS[0]
	near(g.demand_at(p, loc, p.price), city * D.BEACH_BONUS, 0.0001, "playa +20%")


func test_formats() -> void:
	check(Fmt.money(1234567.0) == "$1,23 M", Fmt.money(1234567.0))
	check(Fmt.money(-1500.0) == "-$1.500", Fmt.money(-1500.0))
	check(Fmt.money(2.5, 2) == "$2,50", Fmt.money(2.5, 2))
	check(Fmt.short(2500.0) == "$2,5 k", Fmt.short(2500.0))
	check(Fmt.short(45000.0) == "$45 k", Fmt.short(45000.0))
	check(Fmt.short(1.5e9) == "$1.500 M", Fmt.short(1.5e9))
	check(Fmt.pct(0.125) == "12,5%", Fmt.pct(0.125))


## Si vendes todas las sucursales de un negocio, no se sigue comprando inventario para él.
func test_no_stock_without_stores() -> void:
	var g := Game.new(1)
	g.cash = 500000.0
	g.unlock("pan")
	g.open_location("pan", 1, 3)
	for i in 40:
		g.step_day()
	g.sell_location(g.locs("pan")[0])
	for i in 5:
		g.step_day()
	var p: Dictionary = g.products.pan
	near(p.ema_sales, 0.0, 0.001, "sin sucursales no hay ventas esperadas")
	var stock: float = p.stock
	g.step_day()
	check(p.stock <= stock, "no compra inventario sin sucursales")


## El interés de un préstamo corre por día: prepagarlo antes del cierre no lo hace gratis.
func test_loan_interest_accrues() -> void:
	var g := Game.new(2)
	g.cash = 100000.0
	check(g.take_loan(4000, 12)[0], "el banco presta")
	var loan: Dictionary = g.loans[0]
	for i in 10:
		g.step_day()
	var expected: float = 4000.0 * loan.rate / 360.0 * 10
	near(g.prepay_amount(loan), 4000.0 + expected, 0.01, "saldo + 10 días de interés")
	var before: float = g.ledger.intereses
	check(g.prepay_loan(loan)[0], "se puede prepagar")
	near(g.ledger.intereses - before, expected, 0.01, "el interés queda en el estado de resultados")
	check(g.loans.is_empty(), "el préstamo se borra")


## El clima mueve la demanda: la lluvia vacía la playa y dispara el café; la megatienda techada no pierde gente.
func test_weather_moves_demand() -> void:
	var g := Game.new(5)
	var cafe: Dictionary = g.products.cafe
	var beach := Game.make_location(90, "cafe", 1)
	beach.plot = D.BEACH_PLOTS[0]
	var street := Game.make_location(91, "cafe", 1)
	street.plot = 2
	var mega := Game.make_location(92, "cafe", 2)
	mega.plot = 3
	g.weather = 0
	var sun_beach := g.demand_at(cafe, beach, cafe.price)
	g.weather = 3
	check(g.demand_at(cafe, beach, cafe.price) < sun_beach * 0.7, "con lluvia la playa vende menos")
	near(g.weather_factor("cafe", street), 0.88 * 1.18, 0.0001, "café en la calle con lluvia")
	near(g.weather_factor("cafe", mega), 1.18, 0.0001, "la megatienda no pierde gente con lluvia")
	g.weather = 4
	check(g.weather_factor("burger", beach) > 1.5, "ola de calor: hamburguesas en la playa")
	# El pronóstico se cumple y el clima cambia solo
	var h := Game.new(6)
	var seen := {}
	for i in 400:
		var before := h.weather_next
		var days := h.weather_days
		h.step_day()
		if days == 1:
			check(h.weather == before, "entra el clima pronosticado")
		seen[h.weather] = true
	check(seen.size() >= 3, "a lo largo del año hay varios climas")


## Las estrellas de un local suben con buena atención y mueven su demanda.
func test_stars() -> void:
	var g := Game.new(8)
	g.cash = 200000
	var loc: Dictionary = g.locations[0]
	g.products.cafe.quality = 2
	g.products.cafe.price = g.ref_price(g.products.cafe)   # precio justo: la demanda cabe en el puesto
	loc.employees = 2
	for i in 120:
		g.step_day()
	check(Game.stars_of(loc) > 3.3, "atendiendo bien y con calidad premium suben las estrellas (%.2f)" % Game.stars_of(loc))
	var p: Dictionary = g.products.cafe
	loc.stars = 5.0
	var five := g.demand_at(p, loc, p.price)
	loc.stars = 1.0
	var one := g.demand_at(p, loc, p.price)
	near(five / one, (1.0 + 2 * D.STAR_DEMAND) / (1.0 - 2 * D.STAR_DEMAND), 0.0001, "5 estrellas venden más que 1")
	var b := Game.from_json(g.to_json())
	near(Game.stars_of(b.locations[0]), 1.0, 0.0001, "las estrellas se guardan")


func test_city_activities() -> void:
	var g := Game.new(4)
	g.cash += 100000
	g.open_location("cafe", 1)
	for i in 3:
		g.step_day()
	var aw: float = g.products.cafe.awareness
	var cash0 := g.cash
	check(g.do_activity("muestras")[0], "muestras")
	check(g.products.cafe.awareness > aw, "muestras suben el conocimiento")
	near(g.cash, cash0 - g.activity_cost("muestras"), 0.01, "muestras cuestan")
	check(not g.do_activity("muestras")[0], "muestras: hay que esperar")
	var rep: float = g.products.cafe.reputation
	check(g.do_activity("encuesta")[0], "encuesta")
	near(g.products.cafe.reputation, rep + 2, 0.001, "encuesta +2 reputación")
	check(g.do_activity("voley")[0], "vóley")
	check(g.beach_boost_days == 7, "vóley: 7 días en la playa")
	var c1 := g.cash
	check(g.do_activity("pesca", 6.0)[0], "pesca")
	check(g.cash > c1, "la pesca da plata")
	check(not g.do_activity("pesca")[0], "una pesca por día")
	g.step_day()
	check(g.do_activity("pesca")[0], "al otro día se puede pescar")
	check(g.beach_boost_days == 6, "el torneo se acaba solo")
	var b := Game.from_json(g.to_json())
	check(b.activity_wait("voley") == g.activity_wait("voley") and b.beach_boost_days == 6, "se guarda")


## Cuadra la contabilidad: el cambio de patrimonio es igual a la utilidad del libro (en un mismo mes).
func booked(g: Game, action: Callable, msg: String) -> void:
	var eq: float = g.balance().patrimonio
	var ni: float = Game.statement(g.ledger).utilidad_neta
	action.call()
	near(g.balance().patrimonio - eq, Game.statement(g.ledger).utilidad_neta - ni, 0.01, msg)


func test_decor() -> void:
	var g := Game.new(5)
	g.cash += 50000
	var loc: Dictionary = g.locations[0]
	var p: Dictionary = g.products.cafe
	var dem := g.demand_at(p, loc, p.price)
	var cap := g.capacity(loc)
	booked(g, func(): check(g.buy_decor(loc, "letrero")[0], "letrero"), "letrero cuadra")
	check(not g.buy_decor(loc, "letrero")[0], "no se compra dos veces")
	near(g.demand_at(p, loc, p.price) / dem, 1.06, 0.001, "+6% demanda")
	g.buy_decor(loc, "autopago")
	near(g.capacity(loc) / cap, 1.15, 0.001, "+15% capacidad")
	check(loc.asset_ids.size() == 3, "los artículos son activos del local")
	near(g.decor_cost(loc, "plantas") / g.decor_cost(g.make_location(0, "cafe", 2), "plantas"), 1.0 / 8.0, 0.001, "más caro en megatienda")
	# Aire acondicionado: la tormenta espanta la mitad
	g.weather = 5
	var before := g.weather_factor("cafe", loc)
	g.buy_decor(loc, "aire")
	near(g.weather_factor("cafe", loc), lerpf(before, 1.0, 0.5), 0.001, "aire")
	var b := Game.from_json(g.to_json())
	check(b.locations[0].upgrades == ["letrero", "autopago", "aire"], "se guardan")


func test_solar() -> void:
	var g := Game.new(6)
	g.cash += 200000
	check(not g.build_solar("cafe")[0], "sin fábrica no hay paneles")
	g.build_factory("cafe")
	var p: Dictionary = g.products.cafe
	var cost := g.unit_cost(p)
	var upkeep := g.factory_upkeep_monthly(p)
	booked(g, func(): check(g.build_solar("cafe")[0], "paneles"), "paneles cuadran")
	near(g.unit_cost(p) / cost, 0.95, 0.001, "−5% costo")
	near(g.factory_upkeep_monthly(p) / upkeep, 0.4, 0.001, "mantenimiento 40%")


func test_labor() -> void:
	var g := Game.new(8)
	var w := g.wage_daily()
	var loc: Dictionary = g.locations[0]
	var cap := g.capacity(loc)
	g.set_labor(3)
	near(g.wage_daily() / w, 0.8, 0.001, "explotación paga menos")
	check(g.capacity(loc) > cap * 1.2, "y rinden más al principio")
	g.cash += 100000
	for i in 120:
		g.step_day()
		if g.pending_choice != null:
			g.resolve_choice(0)
	check(g.morale < 20, "el ánimo se desploma (%f)" % g.morale)
	check(g.capacity(loc) / maxf(1, loc.employees) < D.PRODUCTS.cafe.productivity * 1.3, "con ánimo bajo rinden menos de lo prometido")
	g.set_labor(0)
	for i in 120:
		g.step_day()
		if g.pending_choice != null:
			g.resolve_choice(0)
	check(g.morale > 70, "con trato digno se recupera (%f)" % g.morale)


func test_every_micro_is_booked() -> void:
	var base := Game.new(12)
	base.cash += 100000
	base.unlock("pan")
	base.open_location("pan", 1)
	base.open_location("cafe", 1)
	for i in 40:
		base.step_day()
		base.pending_choice = null
		base.micro = null
	var ids: Array = Game.MICROS.duplicate()
	for id in ids:
		for seed in 4:
			var g := Game.from_json(base.to_json())
			g.rng.seed = seed
			g.micro = g.build_micro(id)
			for opt in g.micro.options.size():
				var h := Game.from_json(g.to_json())
				booked(h, func(): h.resolve_micro(opt), "%s opción %d" % [id, opt])
				check(h.micro == null, id)
	# Las de los rivales
	var r := D.rival_by_key("bimbo")
	for maker in ["_micro_rival_war", "_micro_poach", "_micro_lawsuit"]:
		for opt in 2:
			var h := Game.from_json(base.to_json())
			h.micro = h.call(maker, r, "pan") if maker != "_micro_lawsuit" else h.call(maker, r)
			booked(h, func(): h.resolve_micro(opt), "%s opción %d" % [maker, opt])
	# Si no respondes, pasa sola la opción por defecto
	var g := Game.from_json(base.to_json())
	g.micro = g.build_micro("tarde")
	for i in Game.MICRO_DAYS + 1:
		g.step_day()
	check(g.micro == null or g.micro.id != "tarde", "vence sola")


func test_rivals_alive() -> void:
	var g := Game.new(14)
	g.cash += 5000000
	for k in ["pan", "burger", "ropa", "tech"]:
		g.unlock(k)
		g.open_location(k, 1)
	var moves := 0
	for i in 720:
		var n := g.news.size()
		g.step_day()
		if g.pending_choice != null:
			g.resolve_choice(1)
		if g.micro != null:
			g.resolve_micro(1)
		for item in g.news.slice(n):
			if item.kind == "rival":
				moves += 1
	check(moves >= 8, "los rivales hablan y atacan (%d)" % moves)
	check(g.ranking().size() >= 7, "ranking con los rivales activos")
	check(g.rival_active(D.rival_by_key("musk")), "los tiburones aparecen")
	# Alianza: una vez aceptada no te atacan
	var ok := false
	for s in 10:
		var h := Game.from_json(g.to_json())
		h.rng.seed = s
		h.rival_state("bimbo").hostility = 0.0
		var res: Array = h.propose_alliance("bimbo")
		if res[0]:
			ok = true
			check(h.allied("bimbo"), "aliados")
			break
	check(ok, "alguna alianza sale")
	var h := Game.from_json(g.to_json())
	var before := float(h.rival_state("mcdonalds").hostility)
	booked(h, func(): h.provoke("mcdonalds"), "provocar cuadra")
	check(float(h.rival_state("mcdonalds").hostility) > before, "provocar enoja")


func test_buy_that_building() -> void:
	var g := Game.new(15)
	g.cash += 500000
	g._rival_takes("cafe", 2)
	g._rival_takes("cafe", 5)
	var res := g.acquire("cafe", 5)
	check(res[0], "compra")
	check(Game.plot_of(g.locations[-1]) == 5, "es el edificio que elegiste (terreno 6)")
	check(g.rival_plots.has("2") and not g.rival_plots.has("5"), "el otro sigue siendo del rival")
	g.acquire("cafe", D.PLOT_COUNT + 1)
	check(Game.plot_of(g.locations[-1]) == D.PLOT_COUNT + 1, "local fijo de los extremos")


func test_old_saves() -> void:
	var g := Game.new(16)
	for i in 10:
		g.step_day()
	var state = JSON.parse_string(g.to_json())
	for k in ["labor", "morale", "micro", "next_micro_day", "rivals", "plot_owner", "passed"]:
		state.erase(k)
	for p in state.products.values():
		for k in ["solar", "war_days", "cap_boost", "cap_boost_days"]:
			p.erase(k)
	for l in state.locations:
		l.erase("upgrades")
	state.pending_choice = {"id": "cartel", "title": "x", "text": "x", "options": [], "data": {"product": "cafe", "fine": 10.0, "rival": "victor"}}
	var b := Game.from_json(JSON.stringify(state))
	check(b.locations[0].upgrades == [], "locales sin artículos")
	check(b.rivals.has("trump"), "rivales nuevos")
	check(D.rival_by_key("victor").key == "starbucks", "rivales de antes")
	b.pending_choice = null
	for i in 60:
		b.step_day()
	check(not b.game_over, "sigue")
