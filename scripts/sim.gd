class_name Game
extends RefCounted
## Motor económico de Capital (traducción de sim.py). No depende de la escena, así que se prueba sin ventana.
##
## Un día del juego compra inventario, atiende la demanda de cada sucursal y paga los costos diarios.
## Al cerrar cada mes se deprecian los activos, se pagan préstamos e impuestos y se guarda el estado de resultados.
## Productos, sucursales, préstamos y activos son diccionarios: así se guardan tal cual en el archivo de partida.

const LEDGER_KEYS := [
	"ingresos", "costo_ventas", "salarios", "alquiler", "marketing", "almacenamiento", "mermas",
	"gerentes", "fabricas", "corporativo", "contratacion", "indemnizaciones", "multas", "representacion",
	"depreciacion", "intereses", "ingresos_financieros", "perdida_activos", "impuestos",
]
const OPEX_KEYS := ["salarios", "alquiler", "marketing", "almacenamiento", "mermas", "gerentes", "fabricas",
		"corporativo", "contratacion", "indemnizaciones", "multas", "representacion"]

var rng := RandomNumberGenerator.new()
var day := 0
var cash := float(D.START_CASH)
var bonds := 0.0
var products := {}
var locations := []
var loans := []
var assets := []
var next_id := 1
var phase := "expansion"
var phase_months_left := 0
var econ_index := 1.0
var inflation := 0.03
var price_index := 1.0
var min_wage_mult := 1.0
var policy_rate := 0.055
var tax_rate := D.TAX_RATE
var loss_carry := 0.0
var overdraft_days := 0
var game_over := false
var won := false
var rank := 0
var ledger := {}
var history := []
var series := {"caja": [], "ingresos": [], "utilidad": []}
var news := []
var autosave_due := false
# Dilemas, rachas y récords
var pending_choice = null
var next_choice_day := 25
var profit_streak := 0
var best_day := 0.0
var last_record_day := -99
var taunted := false
# Armario de la oficina: si está comprado, qué prendas tienes y cuáles llevas puestas
var wardrobe := false
var owned_items := []
var look = null
# Crecimiento después de ganar: sistemas de gestión, fondo de inversión y tiempo jugado
var hq_level := 0
var fund := 0.0
var play_seconds := 0.0
var win_seconds = null
var mode := "normal"
var strategy_ready_day := 0
var market_today := 0.0
var rank_log := {}       # título -> [día, segundos de juego] en que se consiguió
var rival_plots := {}    # "índice de terreno" -> negocio del rival que lo compró

# Lo que se guarda en el archivo de partida (todo lo anterior menos el generador aleatorio)
const SAVED := ["day", "cash", "bonds", "products", "locations", "loans", "assets", "next_id", "phase",
		"phase_months_left", "econ_index", "inflation", "price_index", "min_wage_mult", "policy_rate", "tax_rate",
		"loss_carry", "overdraft_days", "game_over", "won", "rank", "ledger", "history", "series", "news",
		"pending_choice", "next_choice_day", "profit_streak", "best_day", "last_record_day", "taunted",
		"wardrobe", "owned_items", "look", "hq_level", "fund", "play_seconds", "win_seconds", "mode",
		"strategy_ready_day", "market_today", "rank_log", "rival_plots"]


static func new_ledger() -> Dictionary:
	var led := {}
	for k in LEDGER_KEYS:
		led[k] = 0.0
	led["productos"] = {}
	return led


## Estado de resultados calculado a partir de un libro mensual.
static func statement(led: Dictionary) -> Dictionary:
	var s := {}
	for k in LEDGER_KEYS:
		s[k] = float(led.get(k, 0.0))
	s["utilidad_bruta"] = s["ingresos"] - s["costo_ventas"]
	var opex := 0.0
	for k in OPEX_KEYS:
		opex += s[k]
	s["gastos_operativos"] = opex
	s["ebitda"] = s["utilidad_bruta"] - opex
	s["ebit"] = s["ebitda"] - s["depreciacion"]
	s["ebt"] = s["ebit"] - s["intereses"] + s["ingresos_financieros"] - s["perdida_activos"]
	s["utilidad_neta"] = s["ebt"] - s["impuestos"]
	return s


static func make_location(id: int, product: String, size: int, employees := 1) -> Dictionary:
	return {"id": id, "product": product, "size": size, "employees": employees, "asset_ids": [], "invested": 0.0,
			"demand": 0.0, "ema_demand": 0.0, "capacity": 0.0, "sold": 0.0, "month_contrib": 0.0,
			"last_contrib": null, "month_revenue": 0.0, "plot": null, "owner": false}


static func make_product(key: String) -> Dictionary:
	var d: Dictionary = D.PRODUCTS[key]
	return {"key": key, "unlocked": false, "price": d.ref_price, "quality": 1, "marketing": 0.0, "stock_days": 2,
			"stock": 0.0, "avg_cost": d.unit_cost, "awareness": 0.1, "reputation": 50.0,
			"competitors": d.competitors, "factory": false, "factory_value": 0.0, "manager": false,
			"ema_sales": 0.0, "cost_shock": 1.0, "cost_shock_days": 0, "demand_shock": 1.0, "demand_shock_days": 0,
			"month_purchases": 0.0, "last_month_purchases": 0.0, "last_demand": 0.0, "last_sold": 0.0,
			"last_capacity": 0.0}


## Terreno de la avenida donde está la sucursal; -1 si no tiene.
static func plot_of(loc: Dictionary) -> int:
	return -1 if loc.get("plot") == null else int(loc.plot)


func _init(seed = null, game_mode := "normal") -> void:
	if seed == null:
		rng.randomize()
	else:
		rng.seed = int(seed)
	for k in D.PRODUCT_ORDER:
		products[k] = make_product(k)
	phase_months_left = rng.randi_range(D.PHASES.expansion.months[0], D.PHASES.expansion.months[1])
	ledger = new_ledger()
	mode = game_mode
	cash = float(D.MODES[mode].start_cash)
	var cafe: Dictionary = products.cafe
	cafe.unlocked = true
	var loc := _add_location("cafe", 0, 1, D.SIZES[0].capex, "Puesto de café")
	cafe.ema_sales = min(demand_at(cafe, loc, cafe.price), capacity(loc))
	add_news("Abriste tu primer puesto de café con %s en caja. ¡A vender!" % Fmt.money(cash), "good")
	if mode == "inversionista":
		add_news("Modo inversionista: tienes capital para crecer rápido. No hay final: llega a Mil millonario.", "info")
	add_news("Consejo: en Mercado puedes ver la curva de precio y el precio que maximiza tu utilidad.", "info")


# ---------- utilidades ----------
func _id() -> int:
	next_id += 1
	return next_id


func pick(arr: Array):
	return arr[rng.randi_range(0, arr.size() - 1)]


## `fx` le dice a la ciudad 3D qué celebración o alarma mostrar.
func add_news(text: String, kind := "info", fx = null, value = null) -> void:
	news.append({"day": day, "text": text, "kind": kind, "fx": fx, "value": value})
	if news.size() > 300:
		news = news.slice(news.size() - 300)


func rival_say(rival: Dictionary, kind: String, fmt := {}) -> void:
	var line: String = pick(rival[kind]).format(fmt)
	add_news("%s (%s): «%s»" % [rival.name, rival.company, line], "rival", "rival", rival.key)


## Un rival de algún mercado donde ya compites (para burlas y felicitaciones).
func _some_rival() -> Dictionary:
	var keys := []
	for k in D.PRODUCT_ORDER:
		if products[k].unlocked:
			keys.append(k)
	return D.rival_for(pick(keys)) if keys else D.RIVALS[0]


func _rep(key: String, delta: float) -> void:
	var p: Dictionary = products[key]
	p.reputation = clampf(p.reputation + delta, 0.0, 100.0)


func month_index() -> int:
	return day / 30


func date_parts() -> Array:
	var m := month_index()
	return [day % 30 + 1, D.MONTHS[m % 12], m / 12 + 1]


func date_str() -> String:
	var dp := date_parts()
	return "Día %d · %s · Año %d" % dp


func locs(key: String) -> Array:
	return locations.filter(func(l): return l.product == key)


func wage_daily() -> float:
	return D.BASE_WAGE * price_index * min_wage_mult / 30.0


func ref_price(p: Dictionary) -> float:
	return D.PRODUCTS[p.key].ref_price * D.QUALITIES[p.quality].price * price_index


func volume_discount(p: Dictionary) -> float:
	var disc := 0.0
	for tier in D.VOLUME_TIERS:
		if p.last_month_purchases >= tier[0] * price_index:
			disc = tier[1]
	return disc


func unit_cost(p: Dictionary) -> float:
	var d: Dictionary = D.PRODUCTS[p.key]
	var c: float = d.unit_cost * D.QUALITIES[p.quality].cost * price_index * p.cost_shock
	c *= 1.0 - volume_discount(p)
	if p.factory:
		c *= 1.0 - D.FACTORY_SAVING
	return c


func capacity(loc: Dictionary) -> float:
	# `owner` lo activa la ciudad 3D cuando el jugador atiende el mostrador en persona.
	var staff: int = int(loc.employees) + (1 if loc.get("owner", false) else 0)
	return staff * D.PRODUCTS[loc.product].productivity


func season(key: String) -> float:
	var d: Dictionary = D.PRODUCTS[key]
	var month := fmod(day / 30.0, 12.0) + 1.0
	return 1.0 + d.season_amp * cos(TAU * (month - d.season_peak) / 12.0)


## Demanda diaria esperada de una sucursal a un precio dado (sin ruido).
func demand_at(p: Dictionary, loc: Dictionary, price: float, n_locs := -1) -> float:
	var d: Dictionary = D.PRODUCTS[p.key]
	var q: Dictionary = D.QUALITIES[p.quality]
	price = max(0.01, price)
	var price_f := pow(price / ref_price(p), -d.elasticity * q.elast)
	var econ_f := pow(econ_index, d.income_elasticity * q.income)
	var rep_f: float = 0.7 + 0.6 * p.reputation / 100.0
	var mkt_f: float = 1.0 + 0.6 * p.awareness
	var comp_f: float = (1.0 + 0.1 * d.competitors) / (1.0 + 0.1 * p.competitors)
	var n := n_locs if n_locs >= 0 else locs(p.key).size()
	var cannibal := 1.0 / (1.0 + 0.08 * maxi(0, n - 1))
	var base: float = d.demand * D.SIZES[loc.size].traffic
	if plot_of(loc) in D.BEACH_PLOTS:
		base *= D.BEACH_BONUS  # turistas de la playa
	return base * price_f * econ_f * season(p.key) * rep_f * mkt_f * comp_f * cannibal * p.demand_shock


func asset_book(ids: Array) -> float:
	var total := 0.0
	for a in assets:
		if a.id in ids:
			total += a.book
	return total


func _add_asset(name: String, cost: float) -> Dictionary:
	var a := {"id": _id(), "name": name, "cost": cost, "book": cost}
	assets.append(a)
	return a


func _add_location(key: String, size: int, employees: int, cost: float, label: String) -> Dictionary:
	var loc := make_location(_id(), key, size, employees)
	var a := _add_asset(label, cost)
	loc.asset_ids.append(a.id)
	loc.invested = cost
	locations.append(loc)
	return loc


func _spend(amount: float, ledger_key: String, product = null) -> void:
	cash -= amount
	ledger[ledger_key] = float(ledger.get(ledger_key, 0.0)) + amount
	if product != null:
		_pl(product).contribucion -= amount


func _pl(key: String) -> Dictionary:
	if not ledger.productos.has(key):
		ledger.productos[key] = {"ingresos": 0.0, "contribucion": 0.0, "unidades": 0.0}
	return ledger.productos[key]


func _drop_assets(ids: Array) -> void:
	assets = assets.filter(func(a): return not (a.id in ids))


# ---------- balance y finanzas ----------
func inventory_value() -> float:
	var v := 0.0
	for p in products.values():
		v += p.stock * p.avg_cost
	return v


func fixed_assets() -> float:
	var v := 0.0
	for a in assets:
		v += a.book
	return v


func debt() -> float:
	var v := 0.0
	for l in loans:
		v += l.principal
	return v


func balance() -> Dictionary:
	var c: float = max(0.0, cash)
	var overdraft: float = max(0.0, -cash)
	var inv := inventory_value()
	var fixed := fixed_assets()
	var total := c + bonds + fund + inv + fixed
	var liabilities := debt() + overdraft
	return {"caja": c, "bonos": bonds, "fondo": fund, "inventario": inv, "activos_fijos": fixed, "activos": total,
			"deuda": debt(), "sobregiro": overdraft, "pasivos": liabilities, "patrimonio": total - liabilities}


## EBITDA mensual promedio de los últimos 3 meses cerrados.
func recent_ebitda() -> float:
	if history.is_empty():
		var elapsed := day % 30 + 1
		return statement(ledger).ebitda * 30.0 / elapsed
	var last := history.slice(maxi(0, history.size() - 3))
	var total := 0.0
	for h in last:
		total += statement(h).ebitda
	return total / last.size()


func valuation_multiple() -> float:
	return 2.0 + 2.5 * clampf((econ_index - 0.8) / 0.35, 0.0, 1.0)


func valuation() -> float:
	var b := balance()
	var ev: float = max(0.0, recent_ebitda() * 12.0 * valuation_multiple())
	var market: float = ev + cash + bonds + fund + b.inventario - b.deuda
	return max(b.patrimonio, market)


func credit_limit() -> float:
	var b := balance()
	var lim: float = max(5000.0 * price_index,
			0.6 * b.activos_fijos + 0.5 * b.inventario + 6.0 * max(0.0, recent_ebitda()))
	return max(0.0, lim - b.deuda)


func loan_rate(amount := 0.0) -> float:
	var equity: float = max(1000.0, balance().patrimonio)
	var leverage := (debt() + amount) / equity
	return min(0.35, policy_rate + 0.03 + 0.04 * min(3.0, leverage))


func overdraft_limit() -> float:
	return max(2000.0 * price_index, 0.15 * (fixed_assets() + inventory_value()))


# ---------- acciones del jugador (devuelven [ok, mensaje]) ----------
func location_cost(size: int) -> float:
	return D.SIZES[size].capex * price_index


func open_location(key: String, size: int, plot = null) -> Array:
	var p: Dictionary = products[key]
	var cost := location_cost(size)
	if not p.unlocked:
		return [false, "Primero desbloquea ese negocio."]
	if cash < cost:
		return [false, "Necesitas %s en caja." % Fmt.money(cost)]
	cash -= cost
	var name := "%s de %s" % [D.SIZES[size].name, D.PRODUCTS[key].name.to_lower()]
	var loc := _add_location(key, size, 1, cost, name)
	if plot != null:
		loc.plot = int(plot)
	p.ema_sales += min(demand_at(p, loc, p.price), capacity(loc))
	return [true, "Abriste un %s." % name]


func upgrade_cost(loc: Dictionary):
	if loc.size >= D.SIZES.size() - 1:
		return null
	return (D.SIZES[loc.size + 1].capex - D.SIZES[loc.size].capex) * price_index


func upgrade_location(loc: Dictionary) -> Array:
	var cost = upgrade_cost(loc)
	if cost == null:
		return [false, "Ya es del tamaño máximo."]
	if cash < cost:
		return [false, "Necesitas %s en caja." % Fmt.money(cost)]
	cash -= cost
	loc.size += 1
	var a := _add_asset("Ampliación a %s" % D.SIZES[loc.size].name, cost)
	loc.asset_ids.append(a.id)
	loc.invested += cost
	return [true, "Sucursal ampliada a %s." % D.SIZES[loc.size].name]


func sell_value(loc: Dictionary) -> float:
	return 0.5 * asset_book(loc.asset_ids)


func sell_location(loc: Dictionary) -> Array:
	var book := asset_book(loc.asset_ids)
	var proceeds := 0.5 * book
	var severance: float = loc.employees * D.SEVERANCE_DAYS * wage_daily()
	cash += proceeds
	ledger.perdida_activos += book - proceeds
	_spend(severance, "indemnizaciones", loc.product)
	_drop_assets(loc.asset_ids)
	locations.erase(loc)
	return [true, "Vendiste la sucursal por %s (valor en libros %s)." % [Fmt.money(proceeds), Fmt.money(book)]]


func hire(loc: Dictionary) -> Array:
	if loc.employees >= D.SIZES[loc.size].max_emp:
		return [false, "No caben más empleados. Amplía la sucursal."]
	loc.employees += 1
	_spend(D.HIRING_COST * price_index, "contratacion", loc.product)
	return [true, "Empleado contratado."]


func fire(loc: Dictionary) -> Array:
	if loc.employees <= 0:
		return [false, "No hay empleados."]
	loc.employees -= 1
	_spend(D.SEVERANCE_DAYS * wage_daily(), "indemnizaciones", loc.product)
	return [true, "Empleado despedido (se pagó indemnización)."]


func unlock_cost(key: String) -> float:
	return D.PRODUCTS[key].unlock_cost * price_index


func unlock(key: String) -> Array:
	var p: Dictionary = products[key]
	var cost := unlock_cost(key)
	if p.unlocked:
		return [false, "Ya está desbloqueado."]
	if cash < cost:
		return [false, "Necesitas %s en caja." % Fmt.money(cost)]
	cash -= cost
	_add_asset("Licencias y desarrollo: %s" % D.PRODUCTS[key].name, cost)
	p.unlocked = true
	p.price = ref_price(p)
	add_news("Nueva línea de negocio: %s. Abre tu primera sucursal." % D.PRODUCTS[key].name, "good")
	return [true, "Desbloqueaste %s." % D.PRODUCTS[key].name]


func factory_cost(key: String) -> float:
	return D.PRODUCTS[key].factory_cost * price_index


func build_factory(key: String) -> Array:
	var p: Dictionary = products[key]
	var cost := factory_cost(key)
	if p.factory:
		return [false, "Ya tienes fábrica."]
	if cash < cost:
		return [false, "Necesitas %s en caja." % Fmt.money(cost)]
	cash -= cost
	_add_asset("Fábrica de %s" % D.PRODUCTS[key].name.to_lower(), cost)
	p.factory = true
	p.factory_value = cost
	add_news("Fábrica propia de %s: tu costo unitario baja 30%%." % D.PRODUCTS[key].name.to_lower(), "good")
	return [true, "Fábrica construida."]


func toggle_manager(key: String) -> Array:
	var p: Dictionary = products[key]
	p.manager = not p.manager
	return [true, "Gerente contratado." if p.manager else "Gerente despedido."]


func acquire_cost(key: String) -> float:
	var d: Dictionary = D.PRODUCTS[key]
	var p: Dictionary = products[key]
	var scarcity: float = 1.0 + 0.08 * (d.competitors - p.competitors)
	return (35000.0 + 0.25 * d.unlock_cost) * price_index * max(0.5, scarcity)


func acquire(key: String) -> Array:
	var p: Dictionary = products[key]
	var cost := acquire_cost(key)
	if p.competitors <= 0:
		return [false, "No quedan competidores."]
	if cash < cost:
		return [false, "Necesitas %s en caja." % Fmt.money(cost)]
	cash -= cost
	var local_value: float = min(cost, location_cost(1))
	var loc := _add_location(key, 1, 3, local_value, "Local adquirido de %s" % D.PRODUCTS[key].name.to_lower())
	loc.invested = cost
	for i in rival_plots.keys():  # si el rival tiene un local en la avenida, compras ese
		if rival_plots[i] == key:
			rival_plots.erase(i)
			loc.plot = int(i)
			break
	if cost > local_value:
		var g := _add_asset("Plusvalía (goodwill): %s" % D.PRODUCTS[key].name, cost - local_value)
		loc.asset_ids.append(g.id)
	p.competitors -= 1
	p.ema_sales += min(demand_at(p, loc, p.price), capacity(loc))
	add_news("Adquiriste un competidor de %s: ahora es tu local." % D.PRODUCTS[key].name.to_lower(), "good")
	rival_say(D.rival_for(key), "acquire")
	return [true, "Adquisición completada."]


func wardrobe_cost() -> float:
	return D.WARDROBE_COST * price_index


## Gasto de representación: la imagen del dueño también es un gasto de la empresa.
func unlock_wardrobe() -> Array:
	var cost := wardrobe_cost()
	if wardrobe:
		return [true, "Ya tienes el armario."]
	if cash < cost:
		return [false, "Necesitas %s en caja para comprar el armario." % Fmt.money(cost)]
	_spend(cost, "representacion")
	wardrobe = true
	add_news("Compraste el armario de la oficina por %s: ya puedes renovar tu imagen." % Fmt.money(cost), "good")
	return [true, "Armario comprado. ¡Elige tu ropa!"]


func item_price(base: float) -> float:
	return base * price_index


func buy_item(item: String, base_price: float) -> Array:
	if item in owned_items:
		return [true, ""]
	var price := item_price(base_price)
	if cash < price:
		return [false, "Necesitas %s en caja." % Fmt.money(price)]
	_spend(price, "representacion")
	owned_items.append(item)
	return [true, "Compraste %s por %s." % [item.split(":")[-1], Fmt.money(price)]]


func loan_payment(amount: float, months: int, rate: float) -> float:
	var r := rate / 12.0
	return amount * r / (1.0 - pow(1.0 + r, -months))


func take_loan(amount: float, months: int) -> Array:
	if amount <= 0:
		return [false, "Elige un monto."]
	if amount > credit_limit() + 0.01:
		return [false, "El banco no te presta tanto."]
	var rate := loan_rate(amount)
	loans.append({"id": _id(), "principal": amount, "original": amount, "rate": rate, "months_left": months,
			"payment": loan_payment(amount, months, rate)})
	cash += amount
	return [true, "Préstamo de %s al %s anual." % [Fmt.money(amount), Fmt.pct(rate)]]


func prepay_loan(loan: Dictionary) -> Array:
	if cash < loan.principal:
		return [false, "Necesitas %s en caja." % Fmt.money(loan.principal)]
	cash -= loan.principal
	loans.erase(loan)
	return [true, "Préstamo pagado por completo."]


func buy_bonds(amount: float) -> Array:
	amount = min(amount, cash)
	if amount <= 0:
		return [false, "No tienes caja disponible."]
	cash -= amount
	bonds += amount
	return [true, "Invertiste %s en bonos." % Fmt.money(amount)]


func sell_bonds(amount: float) -> Array:
	amount = min(amount, bonds)
	if amount <= 0:
		return [false, "No tienes bonos."]
	bonds -= amount
	cash += amount
	return [true, "Retiraste %s de bonos." % Fmt.money(amount)]


# ---------- análisis ----------
## Utilidad diaria estimada (ventas × margen de contribución) para distintos precios. Devuelve [curva, mejor].
func price_curve(key: String, points := 60) -> Array:
	var p: Dictionary = products[key]
	var ls := locs(key)
	var ref := ref_price(p)
	var cost := unit_cost(p)
	var curve := []
	var best := [ref, 0.0]
	for i in points:
		var price := ref * (0.3 + 2.2 * i / float(points - 1))
		var sales := 0.0
		for l in ls:
			sales += min(demand_at(p, l, price, ls.size()), capacity(l))
		var point := [price, sales * (price - cost)]
		curve.append(point)
		if ls and (i == 0 or point[1] > best[1]):
			best = point
	return [curve, best]


func fixed_costs_daily(key: String) -> float:
	var p: Dictionary = products[key]
	var cost := 0.0
	for l in locs(key):
		cost += l.employees * wage_daily() + D.SIZES[l.size].rent * price_index / 30.0
	cost += p.marketing / 30.0
	if p.manager:
		cost += D.MANAGER_WAGE * price_index * min_wage_mult / 30.0
	if p.factory:
		cost += p.factory_value * D.FACTORY_UPKEEP / 30.0
	return cost


## Gastos de oficina central: crecen más rápido que el número de sucursales (los sistemas de gestión los bajan).
func corporate_cost_monthly() -> float:
	var n := locations.size()
	return 150.0 * price_index * pow(max(0, n - 5), 1.35) * D.HQ_LEVELS[hq_level][2]


func hq_upgrade_cost():
	if hq_level + 1 >= D.HQ_LEVELS.size():
		return null
	return D.HQ_LEVELS[hq_level + 1][1] * price_index


func upgrade_hq() -> Array:
	var cost = hq_upgrade_cost()
	if cost == null:
		return [false, "Ya tienes el mejor sistema de gestión."]
	if cash < cost:
		return [false, "Necesitas %s en caja." % Fmt.money(cost)]
	cash -= cost
	hq_level += 1
	var name: String = D.HQ_LEVELS[hq_level][0]
	_add_asset("Sistemas de gestión: %s" % name, cost)
	add_news("Oficina central: %s. Tus gastos corporativos bajan." % name, "good")
	return [true, "Instalaste %s." % name]


func _strategy(key: String) -> Array:
	for s in D.STRATEGIES:
		if s[0] == key:
			return s
	return D.STRATEGIES[0]


func strategy_cost(key: String) -> float:
	return max(1500.0 * price_index, _strategy(key)[2] * _scale())


func strategy_wait() -> int:
	return max(0, strategy_ready_day - day)


## Reunión de estrategia: una decisión por mes que se paga como gasto operativo.
func run_strategy(key: String) -> Array:
	if strategy_wait():
		return [false, "La próxima reunión de estrategia es en %d días." % strategy_wait()]
	var cost := strategy_cost(key)
	if cash < cost:
		return [false, "Necesitas %s en caja." % Fmt.money(cost)]
	var active := []
	for p in products.values():
		if p.unlocked and locs(p.key):
			active.append(p)
	var name: String = _strategy(key)[1]
	if key == "campana":
		_spend(cost, "marketing")
		for p in active:
			p.demand_shock = max(p.demand_shock, 1.2)
			p.demand_shock_days = max(p.demand_shock_days, 15)
	elif key == "capacitacion":
		_spend(cost, "salarios")
		for p in active:
			_rep(p.key, 6)
	else:
		_spend(cost, "corporativo")
		for p in active:
			if p.cost_shock_days == 0:
				p.cost_shock = 0.9
				p.cost_shock_days = 30
	strategy_ready_day = day + 30
	add_news("Reunión de estrategia: %s (%s)." % [name, Fmt.money(cost)], "good")
	return [true, "%s: en marcha." % name]


func invest_fund(amount: float) -> Array:
	amount = min(amount, cash)
	if amount <= 0:
		return [false, "No tienes caja disponible."]
	cash -= amount
	fund += amount
	return [true, "Invertiste %s en el fondo." % Fmt.money(amount)]


func withdraw_fund(amount: float) -> Array:
	amount = min(amount, fund)
	if amount <= 0:
		return [false, "No tienes dinero en el fondo."]
	fund -= amount
	cash += amount
	return [true, "Retiraste %s del fondo." % Fmt.money(amount)]


func break_even(key: String):
	var p: Dictionary = products[key]
	var margin: float = p.price - unit_cost(p)
	if margin <= 0:
		return null
	return fixed_costs_daily(key) / margin


func market_share(key: String) -> float:
	var p: Dictionary = products[key]
	var d: Dictionary = D.PRODUCTS[key]
	var rival: float = p.competitors * d.demand * 3.0 * econ_index
	return p.last_sold / (p.last_sold + rival) if p.last_sold + rival > 0 else 0.0


## El modo normal termina en Imperio; el inversionista sigue hasta Mil millonario.
func ranks() -> Array:
	return D.RANKS.slice(0, D.MODES[mode].ranks)


func win_value() -> float:
	return ranks()[-1][0]


## [índice, título, siguiente rango o null, valor de la empresa]
func rank_info() -> Array:
	var v := valuation()
	var idx := 0
	var rs := ranks()
	for i in rs.size():
		if v >= rs[i][0]:
			idx = i
	var nxt = rs[idx + 1] if idx + 1 < rs.size() else null
	return [idx, rs[idx][1], nxt, v]


func advisories() -> Array:
	var tips := []
	for key in D.PRODUCT_ORDER:
		var p: Dictionary = products[key]
		var ls := locs(key)
		if not p.unlocked or ls.is_empty():
			continue
		var name: String = D.PRODUCTS[key].name
		var dem := 0.0
		var cap_lost := 0.0
		var potential := 0.0
		var idle := 0
		for l in ls:
			dem += l.demand
			cap_lost += max(0.0, l.demand - l.capacity)
			potential += min(l.demand, l.capacity)
			if l.employees > 1 and l.capacity > l.demand * 1.6:
				idle += 1
		if dem > 0 and cap_lost / dem > 0.12:
			tips.append(["warn", "%s: pierdes %s de la demanda por falta de personal o espacio." % [name, Fmt.pct(cap_lost / dem, 0)]])
		if potential > 0 and p.last_sold < potential * 0.95:
			tips.append(["warn", "%s: te quedaste sin inventario. Sube los días de inventario." % name])
		if idle:
			tips.append(["info", "%s: hay personal ocioso en %d sucursal(es). Cuesta salario sin vender." % [name, idle]])
		var best: Array = price_curve(key, 40)[1]
		if p.price > 0 and abs(best[0] / p.price - 1.0) > 0.15:
			tips.append(["info", "%s: el precio que maximiza tu utilidad ronda %s." % [name, Fmt.money(best[0], 2)]])
		if p.price / ref_price(p) < 0.8:
			tips.append(["info", "%s: la inflación dejó tu precio muy por debajo del mercado." % name])
	if cash < 0:
		tips.append(["bad", "Estás en sobregiro: pagas %s anual sobre el saldo negativo." % Fmt.pct(policy_rate + 0.18, 0)])
	if cash > 30000 * price_index and bonds == 0:
		tips.append(["info", "Tienes mucha caja quieta. Invertirla o ponerla en bonos evita el costo de oportunidad."])
	for key in D.PRODUCT_ORDER:
		if not products[key].unlocked:
			if cash >= unlock_cost(key):
				tips.append(["good", "Ya puedes desbloquear %s en Negocios." % D.PRODUCTS[key].name])
			break
	return tips.slice(0, 7)


# ---------- simulación ----------
func step_day() -> void:
	if game_over:
		return
	var before: float = statement(ledger).ebitda
	var rev_before: float = ledger.ingresos
	_macro()
	_events()
	_maybe_dilemma()
	for key in D.PRODUCT_ORDER:
		if products[key].unlocked:
			_run_product(products[key])

	if locations.size() > 5:
		_spend(corporate_cost_monthly() / 30.0, "corporativo")
	# La bolsa se mueve todos los días (la pantalla de la oficina lo muestra aunque no tengas fondo).
	var r: float = D.FUND_RETURN[phase] / 365.0 + rng.randfn(0.0, D.FUND_VOLATILITY)
	market_today = r
	if fund > 0:
		# Valor de mercado: la ganancia o pérdida del día va al estado de resultados.
		var change := fund * r
		fund += change
		ledger.ingresos_financieros += change
	if bonds > 0:
		var income := bonds * policy_rate / 365.0
		cash += income
		ledger.ingresos_financieros += income
	if cash < 0 and bonds + fund > 0:
		# Cuenta de barrido: antes de caer en sobregiro se venden bonos y luego parte del fondo.
		var need := -cash + 1000.0 * price_index
		var from_bonds: float = min(need, bonds)
		var from_fund: float = min(need - from_bonds, fund)
		bonds -= from_bonds
		fund -= from_fund
		cash += from_bonds + from_fund
		add_news("Caja negativa: se vendieron %s en inversiones para cubrirla." % Fmt.money(from_bonds + from_fund), "warn")
	if cash < 0:
		var interest := -cash * (policy_rate + 0.18) / 365.0
		cash -= interest
		ledger.intereses += interest

	if cash < -overdraft_limit():
		overdraft_days += 1
		if overdraft_days == 1:
			add_news("¡Superaste el límite de sobregiro! Si sigues así 20 días, el banco te declara en quiebra.", "bad", "danger")
			if not taunted:
				taunted = true
				rival_say(_some_rival(), "taunt")
		if overdraft_days >= 20:
			game_over = true
			add_news("Quiebra: el banco cerró tus cuentas.", "bad", "gameover")
	else:
		overdraft_days = 0

	var rev: float = ledger.ingresos - rev_before
	if rev > best_day:
		if best_day > 0 and day >= 20 and day - last_record_day >= 15:
			last_record_day = day
			add_news("¡Récord de ventas en un día: %s!" % Fmt.money(rev), "good", "record", rev)
		best_day = rev

	series.caja.append(cash)
	series.ingresos.append(rev)
	series.utilidad.append(statement(ledger).ebitda - before)
	for k in series:
		if series[k].size() > 365:
			series[k] = series[k].slice(series[k].size() - 365)

	day += 1
	if day % 30 == 0:
		_end_month()


func _macro() -> void:
	var ph: Dictionary = D.PHASES[phase]
	econ_index += (ph.target - econ_index) * 0.02 + rng.randfn(0.0, 0.002)
	inflation += (ph.inflation - inflation) * 0.01 + rng.randfn(0.0, 0.0003)
	price_index *= 1.0 + inflation / 365.0
	var target: float = max(0.005, 0.01 + 1.5 * inflation + 0.5 * (econ_index - 1.0))
	policy_rate += (target - policy_rate) * 0.01


func _run_product(p: Dictionary) -> void:
	var d: Dictionary = D.PRODUCTS[p.key]
	var q: Dictionary = D.QUALITIES[p.quality]
	var ls := locs(p.key)
	var pl := _pl(p.key)
	var wage := wage_daily()

	if p.manager and ls:
		# Con margen de tolerancia para no contratar y despedir por el ruido diario.
		for loc in ls:
			var max_emp: int = D.SIZES[loc.size].max_emp
			if loc.ema_demand * 1.05 > capacity(loc) and loc.employees < max_emp:
				hire(loc)
			elif loc.employees > 1 and capacity(loc) - d.productivity > loc.ema_demand * 1.15:
				fire(loc)
		p.stock_days = 1 if d.spoil >= 0.1 else (2 if d.spoil >= 0.03 else 4)

	# Compra de inventario al inicio del día para cubrir los días objetivo.
	var cost := unit_cost(p)
	var buy: float = max(0.0, p.stock_days * p.ema_sales - p.stock)
	if buy > 0:
		var value := buy * cost
		cash -= value
		p.avg_cost = (p.stock * p.avg_cost + value) / (p.stock + buy)
		p.stock += buy
		p.month_purchases += value

	var potential := 0.0
	var total_demand := 0.0
	for loc in ls:
		var noise: float = max(0.7, rng.randfn(1.0, 0.07))
		loc.demand = demand_at(p, loc, p.price, ls.size()) * noise
		loc.capacity = capacity(loc)
		loc.ema_demand = 0.9 * loc.ema_demand + 0.1 * loc.demand if loc.ema_demand else loc.demand
		total_demand += loc.demand
		potential += min(loc.demand, loc.capacity)
	var ratio: float = min(1.0, p.stock / potential) if potential > 0 else 0.0

	var sold_total := 0.0
	for loc in ls:
		loc.sold = min(loc.demand, loc.capacity) * ratio
		var revenue: float = loc.sold * p.price
		var cogs: float = loc.sold * p.avg_cost
		var wages: float = loc.employees * wage
		var rent: float = D.SIZES[loc.size].rent * price_index / 30.0
		cash += revenue - wages - rent
		ledger.ingresos += revenue
		ledger.costo_ventas += cogs
		ledger.salarios += wages
		ledger.alquiler += rent
		var contrib := revenue - cogs - wages - rent
		loc.month_contrib += contrib
		loc.month_revenue += revenue
		pl.ingresos += revenue
		pl.contribucion += contrib
		pl.unidades += loc.sold
		sold_total += loc.sold
	p.stock = max(0.0, p.stock - sold_total)

	var spoiled: float = p.stock * d.spoil
	p.stock -= spoiled
	ledger.mermas += spoiled * p.avg_cost
	pl.contribucion -= spoiled * p.avg_cost
	_spend(p.stock * p.avg_cost * D.HOLDING_RATE, "almacenamiento", p.key)
	if p.marketing > 0:
		_spend(p.marketing / 30.0, "marketing", p.key)
	if p.manager:
		_spend(D.MANAGER_WAGE * price_index * min_wage_mult / 30.0, "gerentes", p.key)
	if p.factory:
		_spend(p.factory_value * D.FACTORY_UPKEEP / 30.0, "fabricas", p.key)

	if ls:
		p.ema_sales = 0.8 * p.ema_sales + 0.2 * potential
	var cap_total := 0.0
	for l in ls:
		cap_total += l.capacity
	p.last_demand = total_demand
	p.last_sold = sold_total
	p.last_capacity = cap_total

	# Reputación: calidad, nivel de servicio y precio justo.
	if ls:
		var service: float = sold_total / total_demand if total_demand > 0 else 1.0
		var ratio_price: float = p.price / ref_price(p)
		var target: float = q.rep
		if service < 0.95:
			target -= (0.95 - service) * 60.0
		if ratio_price > 1.25:
			target -= (ratio_price - 1.25) * 40.0
		elif ratio_price < 0.85:
			target += (0.85 - ratio_price) * 20.0
		target = clampf(target, 0.0, 100.0)
		p.reputation += (target - p.reputation) * 0.015

	var traffic := 0.0
	for l in ls:
		traffic += D.SIZES[l.size].traffic
	traffic = max(1.0, traffic)
	var half: float = 500.0 * traffic * (d.ref_price * d.demand / 180.0) * price_index
	var aw_target: float = p.marketing / (p.marketing + half) if p.marketing > 0 else 0.0
	p.awareness += (aw_target - p.awareness) * 0.03

	if p.cost_shock_days > 0:
		p.cost_shock_days -= 1
		if p.cost_shock_days == 0:
			p.cost_shock = 1.0
			add_news("El costo de %s volvió a la normalidad." % d.name.to_lower(), "info")
	if p.demand_shock_days > 0:
		p.demand_shock_days -= 1
		if p.demand_shock_days == 0:
			p.demand_shock = 1.0


func _events() -> void:
	var unlocked := products.values().filter(func(p): return p.unlocked)
	var with_locs := unlocked.filter(func(p): return not locs(p.key).is_empty())
	var P := products
	if P.cafe.unlocked and P.cafe.cost_shock_days == 0 and rng.randf() < 1.0 / 400:
		P.cafe.cost_shock = 1.3
		P.cafe.cost_shock_days = 45
		add_news("Helada en Brasil: el café en grano sube 30% durante 45 días.", "bad")
	elif P.tech.unlocked and P.tech.cost_shock_days == 0 and rng.randf() < 1.0 / 400:
		P.tech.cost_shock = 1.25
		P.tech.cost_shock_days = 60
		add_news("Escasez mundial de chips: la electrónica cuesta 25% más por 60 días.", "bad")
	elif with_locs and rng.randf() < 1.0 / 300:
		var food := with_locs.filter(func(p): return p.key in ["cafe", "pan", "burger"])
		if food:
			for p in food:
				p.demand_shock = 1.25
				p.demand_shock_days = 10
			add_news("Festival gastronómico en la ciudad: +25% de demanda de comida por 10 días.", "good")
	elif with_locs and rng.randf() < 1.0 / 350:
		var p: Dictionary = pick(with_locs)
		p.reputation = min(100.0, p.reputation + 15)
		add_news("¡Viral en redes! Tu marca de %s gana reputación." % D.PRODUCTS[p.key].name.to_lower(), "good")
	elif locations and rng.randf() < 1.0 / 300:
		var cheap := with_locs.any(func(p): return p.quality == 0)
		if cheap or rng.randf() < 0.5:
			var fine := 600.0 * price_index * (1 + 0.1 * locations.size())
			_spend(fine, "multas")
			add_news("Inspección sanitaria: multa de %s" % Fmt.money(fine)
					+ (" (la calidad económica aumenta el riesgo)." if cheap else "."), "bad")
	elif rng.randf() < 1.0 / 900:
		min_wage_mult *= 1.08
		add_news("El gobierno sube el salario mínimo 8%. Tus costos laborales aumentan.", "bad")
	elif with_locs and rng.randf() < 1.0 / 400:
		var p: Dictionary = pick(with_locs)
		var lost: float = p.stock * 0.25
		p.stock -= lost
		ledger.mermas += lost * p.avg_cost
		_pl(p.key).contribucion -= lost * p.avg_cost
		add_news("Robo en una bodega de %s: perdiste 25%% del inventario." % D.PRODUCTS[p.key].name.to_lower(), "bad")
	elif phase in ["expansion", "auge"] and rng.randf() < 1.0 / 1500:
		_set_phase("recesion")
		add_news("Crisis financiera internacional: la economía entra en recesión.", "bad")
	elif rng.randf() < 1.0 / 1200:
		if rng.randf() < 0.5:
			tax_rate = min(0.35, tax_rate + 0.03)
			add_news("Reforma tributaria: el impuesto a las utilidades sube a %s." % Fmt.pct(tax_rate, 0), "bad")
		else:
			tax_rate = max(0.15, tax_rate - 0.03)
			add_news("Reforma tributaria: el impuesto a las utilidades baja a %s." % Fmt.pct(tax_rate, 0), "good")
	elif unlocked and rng.randf() < 1.0 / 500:
		var p: Dictionary = pick(unlocked)
		p.competitors += 1
		add_news("Una cadena nueva de %s llega a la ciudad." % D.PRODUCTS[p.key].name.to_lower(), "bad")
		rival_say(D.rival_for(p.key), "entry", {"p": D.PRODUCTS[p.key].name.to_lower()})


func _set_phase(new_phase: String) -> void:
	phase = new_phase
	var m: Array = D.PHASES[new_phase].months
	phase_months_left = rng.randi_range(m[0], m[1])


func _end_month() -> void:
	var L := ledger
	for a in assets:
		var dep: float = min(a.book, a.cost / D.DEPRECIATION_MONTHS)
		a.book -= dep
		L.depreciacion += dep
	assets = assets.filter(func(a): return a.book > 0.01)

	for loan in loans.duplicate():
		var interest: float = loan.principal * loan.rate / 12.0
		var principal: float = loan.principal if loan.months_left <= 1 else min(loan.principal, loan.payment - interest)
		cash -= interest + principal
		L.intereses += interest
		loan.principal -= principal
		loan.months_left -= 1
		if loan.months_left <= 0 or loan.principal <= 0.01:
			loans.erase(loan)
			add_news("Terminaste de pagar un préstamo.", "good")

	var ebt: float = statement(L).ebt
	if ebt > 0:
		var taxable: float = max(0.0, ebt - loss_carry)
		loss_carry = max(0.0, loss_carry - ebt)
		L.impuestos = taxable * tax_rate
		cash -= L.impuestos
	else:
		loss_carry += -ebt

	L["mes"] = month_index() - 1
	history.append(L)
	if history.size() > 36:
		history = history.slice(history.size() - 36)
	for loc in locations:
		loc.last_contrib = loc.month_contrib
		loc.month_contrib = 0.0
		loc.month_revenue = 0.0

	for p in products.values():
		p.last_month_purchases = p.month_purchases
		p.month_purchases = 0.0
		_competition(p, L.productos.get(p.key))
	_rival_land()

	phase_months_left -= 1
	if phase_months_left <= 0:
		_set_phase(D.PHASES[phase].next)
		var kind := "bad" if phase == "recesion" else ("good" if phase in ["recuperacion", "auge"] else "info")
		add_news("Ciclo económico: la economía entra en %s." % D.PHASES[phase].name.to_lower(), kind)

	var net: float = statement(L).utilidad_neta
	add_news("Cierre de %s: utilidad neta %s." % [D.MONTHS[(month_index() - 1) % 12], Fmt.money(net)],
			"good" if net >= 0 else "bad", "month", net)
	if net >= 0:
		profit_streak += 1
		if profit_streak in [3, 6, 12, 24, 36, 60]:
			add_news("¡Racha de %d meses seguidos con utilidad!" % profit_streak, "good", "streak", profit_streak)
	else:
		if profit_streak >= 3:
			add_news("Se rompió tu racha de %d meses con utilidad." % profit_streak, "bad", "streak_lost", profit_streak)
		profit_streak = 0
	if cash >= 0:
		taunted = false

	var info := rank_info()
	var idx: int = info[0]
	if idx > rank:
		for r in ranks().slice(rank + 1, idx + 1):
			rank_log[r[1]] = [day, play_seconds]
		rank = idx
		add_news("¡Nuevo rango: %s! Tu empresa vale %s." % [info[1], Fmt.money(info[3])], "good", "rank", info[1])
		rival_say(_some_rival(), "rank", {"r": info[1]})
	if info[3] >= win_value() and not won:
		won = true
		win_seconds = play_seconds
		var goal := "un imperio de más de $10 millones" if mode == "normal" else "una fortuna de mil millones"
		add_news("¡Construiste %s en %d minutos de juego!" % [goal, roundi(play_seconds / 60.0)], "good", "win")

	ledger = new_ledger()
	autosave_due = true


func _competition(p: Dictionary, pl) -> void:
	var d: Dictionary = D.PRODUCTS[p.key]
	var r := rng.randf()
	if not p.unlocked or pl == null or pl.ingresos <= 0:
		if r < 0.05:
			p.competitors = clampi(p.competitors + pick([-1, 1]), 1, d.competitors + 3)
		return
	var margin: float = pl.contribucion / pl.ingresos
	var name: String = d.name.to_lower()
	if margin > 0.25 and econ_index >= 1.0 and r < 0.3 and p.competitors < 12:
		p.competitors += 1
		add_news("Atraído por las ganancias del mercado de %s, abre un nuevo competidor." % name, "bad")
		rival_say(D.rival_for(p.key), "entry", {"p": name})
	elif econ_index < 0.9 and p.competitors > 1 and r < 0.3:
		p.competitors -= 1
		add_news("La recesión hace cerrar a un competidor de %s." % name, "good")
	elif p.price / ref_price(p) < 0.8 and p.competitors > 1 and r < 0.2:
		p.competitors -= 1
		add_news("Tus precios bajos sacaron del mercado a un competidor de %s." % name, "good")
		rival_say(D.rival_for(p.key), "loss", {"p": name})


# ---------- terrenos de la avenida en manos de los rivales ----------
func free_plots() -> Array:
	var used := {}
	for loc in locations:
		used[plot_of(loc)] = true
	var out := []
	for i in D.PLOT_COUNT:
		if not used.has(i) and not rival_plots.has(str(i)):
			out.append(i)
	return out


func _rival_takes(key: String, plot: int) -> void:
	rival_plots[str(plot)] = key
	products[key].competitors += 1


## Una vez al mes: si un mercado perdió competidores, el rival deja su terreno; y de vez en cuando
## un rival compra un terreno vacío. Nunca se quedan con todos: siempre quedan terrenos para ti.
func _rival_land() -> void:
	for key in products:
		var mine := []
		for i in rival_plots:
			if rival_plots[i] == key:
				mine.append(i)
		while mine.size() > products[key].competitors:
			var i: String = mine.pop_back()
			rival_plots.erase(i)
			add_news("%s cerró su local del terreno %d: vuelve a estar en venta." % [D.rival_for(key).company, int(i) + 1], "good")
	var free := free_plots()
	if day < 75 or free.size() <= 3 or rival_plots.size() >= D.RIVAL_PLOT_MAX or rng.randf() > D.RIVAL_LAND_CHANCE:
		return
	var keys := []
	for k in products:
		if products[k].unlocked:
			keys.append(k)
	var key: String = pick(keys if keys else ["cafe"])
	var plot: int = pick(free)
	_rival_takes(key, plot)
	var r := D.rival_for(key)
	var name: String = D.PRODUCTS[key].name.to_lower()
	var where := " en la playa" if plot in D.BEACH_PLOTS else ""
	add_news("%s compró el terreno %d%s y abrió un local de %s." % [r.company, plot + 1, where, name], "bad")
	rival_say(r, "entry", {"p": name})


# ---------- dilemas: decisiones con riesgo que pausan el juego ----------
## Tamaño del negocio (ventas del último mes) para que los montos de los dilemas importen.
func _scale() -> float:
	var total := 0.0
	var arr: Array = series.ingresos
	for v in arr.slice(max(0, arr.size() - 30)):
		total += v
	return max(800.0 * price_index, total)


const DILEMMAS := ["soborno", "influencer", "aumento", "lote", "demanda", "cartel", "oferta", "compra_rival"]


func _maybe_dilemma() -> void:
	if pending_choice != null or day < next_choice_day or locations.is_empty():
		return
	next_choice_day = day + rng.randi_range(35, 70)
	var builders := ["soborno", "influencer", "aumento", "lote", "demanda"]
	if products.values().any(func(p): return p.unlocked and p.competitors > 0):
		builders.append("cartel")
	if locations.size() > 1:
		builders.append("oferta")
		if day >= 60:
			builders += ["compra_rival", "compra_rival"]  # los rivales intentan comprarte locales
	pending_choice = build_dilemma(pick(builders))
	add_news("Decisión urgente: %s" % pending_choice.title, "warn", "dilemma")


func build_dilemma(id: String) -> Dictionary:
	return call("_d_" + id)


func _pick_loc() -> Array:
	var loc: Dictionary = pick(locations)
	var name := "%s de %s" % [D.SIZES[loc.size].name.to_lower(), D.PRODUCTS[loc.product].name.to_lower()]
	return [loc, name]


func _opt(label: String, detail: String) -> Dictionary:
	return {"label": label, "detail": detail}


func _d_soborno() -> Dictionary:
	var pl := _pick_loc()
	var k := _scale()
	var bribe := 0.08 * k
	var fine := 0.2 * k
	var big := 0.6 * k
	return {"id": "soborno", "title": "Un inspector quiere «colaboración»",
			"text": "Un inspector sanitario revisó tu %s y dice haber encontrado «irregularidades». Te ofrece olvidarlo todo por %s en efectivo, sin factura. Te mira esperando." % [pl[1], Fmt.money(bribe)],
			"options": [_opt("Pagar el soborno (%s)" % Fmt.money(bribe),
					"75%%: nadie se entera. 25%%: sale en las noticias, multa de %s y tu reputación se desploma (−25)." % Fmt.money(big)),
					_opt("Rechazarlo y aceptar la inspección",
					"Multa segura de %s, pero ganas reputación por ser honesto (+5)." % Fmt.money(fine))],
			"data": {"product": pl[0].product, "bribe": bribe, "fine": fine, "big": big}}


func _r_soborno(opt: int, d: Dictionary) -> Array:
	if opt == 0:
		_spend(d.bribe, "multas", d.product)
		if rng.randf() < 0.25:
			_spend(d.big, "multas", d.product)
			_rep(d.product, -25)
			return ["¡Escándalo! Un periodista grabó el soborno: multa de %s y tu reputación se hunde." % Fmt.money(d.big), "bad"]
		return ["Pagaste y el inspector desapareció. Nadie se enteró... por ahora.", "warn"]
	_spend(d.fine, "multas", d.product)
	_rep(d.product, 5)
	return ["Pagaste la multa de %s. Los clientes valoran tu transparencia (+5 reputación)." % Fmt.money(d.fine), "info"]


func _d_influencer() -> Dictionary:
	var loc: Dictionary = _pick_loc()[0]
	var fee := 0.25 * _scale()
	var pname: String = D.PRODUCTS[loc.product].name.to_lower()
	return {"id": "influencer", "title": "Una influencer quiere promocionarte",
			"text": "Una influencer con 2 millones de seguidores quiere hacer un video de tu %s. Cobra %s por adelantado. «Mis videos o explotan o no los ve nadie», admite." % [pname, Fmt.money(fee)],
			"options": [_opt("Contratarla (%s)" % Fmt.money(fee),
					"55%: se vuelve viral: +20 reputación y +40% de demanda por 20 días. 45%: nadie lo ve y pierdes el dinero."),
					_opt("No, gracias", "No gastas nada. Nunca sabrás qué habría pasado.")],
			"data": {"product": loc.product, "fee": fee}}


func _r_influencer(opt: int, d: Dictionary) -> Array:
	if opt == 1:
		return ["Dejaste pasar a la influencer. Tu caja queda igual.", "info"]
	_spend(d.fee, "marketing", d.product)
	if rng.randf() < 0.55:
		var p: Dictionary = products[d.product]
		p.demand_shock = max(p.demand_shock, 1.4)
		p.demand_shock_days = 20
		_rep(d.product, 20)
		return ["¡EL VIDEO EXPLOTÓ! Millones de vistas: +40% de demanda por 20 días y +20 de reputación.", "good"]
	return ["El video pasó sin pena ni gloria. Perdiste %s." % Fmt.money(d.fee), "bad"]


func _d_aumento() -> Dictionary:
	var loc: Dictionary = locations[0]
	for l in locations:
		if l.employees > loc.employees:
			loc = l
	var pname: String = D.PRODUCTS[loc.product].name.to_lower()
	var bonus := 0.1 * _scale()
	var rival: String = D.rival_for(loc.product).company
	return {"id": "aumento", "title": "Tu mejor empleada pide un bono",
			"text": "Camila, tu mejor empleada de %s, lleva meses haciendo doble turno. Pide un bono de %s. «Si no, me voy con %s: ya me ofrecieron trabajo.»" % [pname, Fmt.money(bonus), rival],
			"options": [_opt("Darle el bono (%s)" % Fmt.money(bonus), "El equipo se motiva y se nota en la atención: +8 de reputación."),
					_opt("Decirle que no", "50%: se queda, molesta. 50%: renuncia, pierdes un empleado y se lleva clientes al rival (−10 reputación).")],
			"data": {"product": loc.product, "loc_id": loc.id, "bonus": bonus, "rival": rival}}


func _r_aumento(opt: int, d: Dictionary) -> Array:
	if opt == 0:
		_spend(d.bonus, "salarios", d.product)
		_rep(d.product, 8)
		return ["Camila sonríe: «No te vas a arrepentir». El equipo trabaja con más ganas (+8 reputación).", "good"]
	if rng.randf() < 0.5:
		return ["Camila se quedó, pero ya no saluda igual.", "warn"]
	var loc = find_location(d.loc_id)
	if loc != null and loc.employees > 0:
		loc.employees -= 1
	_rep(d.product, -10)
	return ["Camila renunció y ahora trabaja para %s. Se llevó a varios clientes (−10 reputación)." % d.get("rival", "la competencia"), "bad"]


func _d_lote() -> Dictionary:
	var loc: Dictionary = _pick_loc()[0]
	var p: Dictionary = products[loc.product]
	var units: float = max(20.0, p.ema_sales * 5.0)
	var value := units * unit_cost(p)
	var pname: String = D.PRODUCTS[loc.product].name.to_lower()
	return {"id": "lote", "title": "Una ganga sospechosa",
			"text": "Un proveedor que nadie conoce ofrece un lote de %s: %d unidades por %s. Valen %s. No da factura ni dirección." % [pname, roundi(units), Fmt.money(value * 0.5), Fmt.money(value)],
			"options": [_opt("Comprar el lote (%s)" % Fmt.money(value * 0.5),
					"65%%: ahorras %s. 35%%: estaba en mal estado, lo botas y algunos clientes se enferman (−15 reputación)." % Fmt.money(value * 0.5)),
					_opt("Rechazarlo", "Sigues con tu proveedor de siempre.")],
			"data": {"product": loc.product, "units": units, "cost": value * 0.5}}


func _r_lote(opt: int, d: Dictionary) -> Array:
	if opt == 1:
		return ["Rechazaste el lote. Más vale malo conocido que bueno por conocer.", "info"]
	var p: Dictionary = products[d.product]
	cash -= d.cost
	if rng.randf() < 0.65:
		p.avg_cost = (p.stock * p.avg_cost + d.cost) / (p.stock + d.units)
		p.stock += d.units
		return ["¡Era bueno! Tu inventario creció y tu costo promedio bajó. Ahorraste %s." % Fmt.money(d.cost), "good"]
	ledger.mermas += d.cost
	_pl(d.product).contribucion -= d.cost
	_rep(d.product, -15)
	return ["El lote estaba podrido. Lo botaste, pero algunos clientes ya se habían enfermado (−15 reputación).", "bad"]


func _d_demanda() -> Dictionary:
	var pl := _pick_loc()
	var k := _scale()
	return {"id": "demanda", "title": "Te demandan",
			"text": "Un cliente asegura que se enfermó en tu %s y te demanda. Su abogado te llama: «Firmamos un acuerdo por %s y aquí no pasó nada»." % [pl[1], Fmt.money(0.15 * k)],
			"options": [_opt("Pagar el acuerdo (%s)" % Fmt.money(0.15 * k), "El caso se cierra en silencio."),
					_opt("Ir a juicio", "50%%: ganas y no pagas nada (+5 reputación). 50%%: pierdes, pagas %s y sale en las noticias (−20 reputación)." % Fmt.money(0.45 * k))],
			"data": {"product": pl[0].product, "settle": 0.15 * k, "lose": 0.45 * k}}


func _r_demanda(opt: int, d: Dictionary) -> Array:
	if opt == 0:
		_spend(d.settle, "multas", d.product)
		return ["Pagaste el acuerdo. El caso se cerró sin ruido.", "info"]
	if rng.randf() < 0.5:
		_rep(d.product, 5)
		return ["¡GANASTE EL JUICIO! El juez falló a tu favor. No pagas nada y tu reputación sube.", "good"]
	_spend(d.lose, "multas", d.product)
	_rep(d.product, -20)
	return ["Perdiste el juicio: pagas %s y tu marca aparece en todos los noticieros." % Fmt.money(d.lose), "bad"]


func _d_cartel() -> Dictionary:
	var keys := []
	for p in products.values():
		if p.unlocked and p.competitors > 0:
			keys.append(p.key)
	var key: String = pick(keys if keys else ["cafe"])
	var pname: String = D.PRODUCTS[key].name.to_lower()
	var fine := 1.2 * _scale()
	var r := D.rival_for(key)
	return {"id": "cartel", "title": "%s te propone un pacto" % r.name,
			"text": "%s, de %s, te invita a cenar. «Subamos los precios de %s los dos y dejemos de pelear. Ganamos todos... menos los clientes.» Es ilegal." % [r.name, r.company, pname],
			"options": [_opt("Aceptar el pacto",
					"Tu demanda de %s sube 30%% por 60 días. 30%%: la autoridad descubre el cartel: multa de %s y −30 de reputación." % [pname, Fmt.money(fine)]),
					_opt("Rechazarlo", "Se ofende: 50% de que abra otro local en tu mercado."),
					_opt("Denunciarlo a la autoridad",
					"50%: le cierran un local (un competidor menos). 50%: no hay pruebas y abre dos locales para vengarse.")],
			"data": {"product": key, "fine": fine, "rival": r.key}}


func _r_cartel(opt: int, d: Dictionary) -> Array:
	var p: Dictionary = products[d.product]
	var r := D.rival_by_key(d.get("rival"))
	if opt == 0:
		if rng.randf() < 0.3:
			_spend(d.fine, "multas", d.product)
			_rep(d.product, -30)
			return ["¡La fiscalía allanó tus oficinas! El cartel quedó al descubierto: multa de %s." % Fmt.money(d.fine), "bad"]
		p.demand_shock = max(p.demand_shock, 1.3)
		p.demand_shock_days = 60
		return ["Pacto sellado. Los precios suben en toda la ciudad y tus ventas también... por ahora.", "warn"]
	if opt == 1:
		if rng.randf() < 0.5:
			p.competitors += 1
			return ["%s: «Te vas a arrepentir.» Abrió otro local en tu mercado." % r.name, "bad"]
		return ["%s se fue de la cena sin pagar. Por ahora no pasó nada más." % r.name, "info"]
	if rng.randf() < 0.5:
		p.competitors = max(0, p.competitors - 1)
		return ["¡La autoridad multó a %s y le cerró un local! Un competidor menos." % r.company, "good"]
	p.competitors += 2
	return ["No hubo pruebas y, como venganza, %s abrió dos locales nuevos." % r.name, "bad"]


func _last_contrib(loc: Dictionary) -> float:
	return 0.0 if loc.last_contrib == null else float(loc.last_contrib)


func _d_oferta() -> Dictionary:
	var pl := _pick_loc()
	var loc: Dictionary = pl[0]
	var book := asset_book(loc.asset_ids)
	var offer: float = max(book * 1.3, max(0.0, _last_contrib(loc)) * 18.0) * rng.randf_range(0.9, 1.2)
	return {"id": "oferta", "title": "Quieren comprarte una sucursal",
			"text": "Un inversionista quiere comprar tu %s por %s al contado. En libros vale %s y el mes pasado aportó %s. La oferta vence hoy." % [pl[1], Fmt.money(offer), Fmt.money(book), Fmt.money(_last_contrib(loc))],
			"options": [_opt("Vender (%s)" % Fmt.money(offer),
					"Recibes el dinero ahora y pierdes las ganancias futuras de esa sucursal. Compara la oferta con lo que te dejaría en los próximos meses."),
					_opt("No vender", "Te quedas con la sucursal y sus ganancias futuras.")],
			"data": {"loc_id": loc.id, "offer": offer}}


func find_location(id):
	for l in locations:
		if int(l.id) == int(id):
			return l
	return null


func _r_oferta(opt: int, d: Dictionary) -> Array:
	var loc = find_location(d.loc_id)
	if opt == 1 or loc == null:
		return ["Rechazaste la oferta: la sucursal sigue siendo tuya.", "info"]
	var book := asset_book(loc.asset_ids)
	cash += d.offer
	ledger.perdida_activos += book - d.offer
	_drop_assets(loc.asset_ids)
	locations.erase(loc)
	return ["Vendiste la sucursal por %s: %s más que su valor en libros." % [Fmt.money(d.offer), Fmt.money(d.offer - book)], "good"]


func _d_compra_rival() -> Dictionary:
	var plotted := locations.filter(func(l): return plot_of(l) >= 0)
	var loc: Dictionary = pick(plotted if plotted else locations)
	var key: String = loc.product
	var r := D.rival_for(key)
	var book := asset_book(loc.asset_ids)
	var offer: float = max(book * 1.4, max(0.0, _last_contrib(loc)) * 16.0) * rng.randf_range(0.95, 1.25)
	var name := "%s de %s" % [D.SIZES[loc.size].name.to_lower(), D.PRODUCTS[key].name.to_lower()]
	var where := " del terreno %d" % (plot_of(loc) + 1) if plot_of(loc) >= 0 else ""
	return {"id": "compra_rival", "title": "%s quiere comprarte un local" % r.name,
			"text": "%s, de %s, te ofrece %s por tu %s%s. «Véndemelo y nos ahorramos la pelea.» En libros vale %s y el mes pasado aportó %s. Si aceptas, ese local pasa a ser de la competencia." % [r.name, r.company, Fmt.money(offer), name, where, Fmt.money(book), Fmt.money(_last_contrib(loc))],
			"options": [_opt("Vender (%s)" % Fmt.money(offer),
					"Recibes el dinero ahora. El local queda en manos del rival: tienes un competidor más en ese mercado."),
					_opt("No vender", "Te quedas con el local. 30%: el rival se enoja y compra un terreno vacío para abrir cerca.")],
			"data": {"loc_id": loc.id, "offer": offer, "rival": r.key, "product": key}}


func _r_compra_rival(opt: int, d: Dictionary) -> Array:
	var loc = find_location(d.loc_id)
	var r := D.rival_by_key(d.rival)
	if loc == null:
		return ["La oferta ya no corre: ese local ya no es tuyo.", "info"]
	if opt == 1:
		var free := free_plots()
		if free.size() > 3 and rival_plots.size() < D.RIVAL_PLOT_MAX and rng.randf() < 0.3:
			var plot: int = pick(free)
			_rival_takes(d.product, plot)
			return ["%s: «Como quieras.» Compró el terreno %d para abrir cerca de ti." % [r.name, plot + 1], "bad"]
		return ["%s: «Ya cambiarás de opinión.» El local sigue siendo tuyo." % r.name, "info"]
	var plot := plot_of(loc)
	var book := asset_book(loc.asset_ids)
	cash += d.offer
	ledger.perdida_activos += book - d.offer
	_drop_assets(loc.asset_ids)
	locations.erase(loc)
	if plot >= 0:
		_rival_takes(d.product, plot)
	else:
		products[d.product].competitors += 1
	return ["Vendiste el local a %s por %s. Ahora es de la competencia." % [r.company, Fmt.money(d.offer)], "good"]


## Devuelve [ok, mensaje].
func resolve_choice(option: int) -> Array:
	var c = pending_choice
	if c == null:
		return [false, ""]
	pending_choice = null
	var res: Array = call("_r_" + c.id, option, c.data)
	add_news(res[0], res[1], "outcome", res[1])
	return [res[1] in ["good", "info"], res[0]]


# ---------- guardar / cargar ----------
func to_json() -> String:
	var state := {}
	for k in SAVED:
		state[k] = get(k)
	state["rng_seed"] = str(rng.seed)
	state["rng_state"] = str(rng.state)
	return JSON.stringify(state, "", false, true)  # sin reordenar y con todos los decimales


static func from_json(text: String) -> Game:
	var state = JSON.parse_string(text)
	var g := Game.new(0)
	g.news.clear()
	for k in SAVED:
		if state.has(k):
			var v = state[k]
			if k in INT_KEYS:
				v = int(v)
			g.set(k, v)
	g.rng.seed = String(state.get("rng_seed", "0")).to_int()
	g.rng.state = String(state.get("rng_state", "0")).to_int()
	g._fix_types()
	return g


const INT_KEYS := ["day", "next_id", "phase_months_left", "overdraft_days", "rank", "next_choice_day",
		"profit_streak", "last_record_day", "hq_level", "strategy_ready_day"]


## JSON guarda todos los números como decimales: los que son índices o contadores vuelven a ser enteros.
func _fix_types() -> void:
	for p in products.values():
		for k in ["quality", "stock_days", "competitors", "cost_shock_days", "demand_shock_days"]:
			p[k] = int(p[k])
	for loc in locations:
		for k in ["id", "size", "employees"]:
			loc[k] = int(loc[k])
		if loc.get("plot") != null:
			loc.plot = int(loc.plot)
		loc.asset_ids = loc.asset_ids.map(func(i): return int(i))
	for l in loans:
		l.id = int(l.id)
		l.months_left = int(l.months_left)
	for a in assets:
		a.id = int(a.id)
