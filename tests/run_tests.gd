extends Node
## Pruebas del motor económico (las mismas de tests/test_sim.py en la versión de Python).
## Correr con: Godot --headless --path . res://tests/run_tests.tscn

var failures := 0
var checks := 0


func _ready() -> void:
	for t in ["test_equity_change_equals_net_income", "test_every_dilemma_outcome_is_booked",
			"test_save_and_load_continue", "test_wardrobe", "test_modes", "test_fund_hq_and_sweep",
			"test_strategies", "test_rivals_buy_empty_plots", "test_selling_to_a_rival", "test_beach_plots",
			"test_formats"]:
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
