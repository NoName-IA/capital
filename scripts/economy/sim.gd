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
var company := "Mi Empresa"   # nombre que le pone el jugador al empezar
var weather := 1              # clima de hoy (índice de D.WEATHER)
var weather_next := 1         # pronóstico: el clima que viene
var weather_days := 3         # días que faltan para que cambie
var activity_day := {}         # actividad de la ciudad -> día en que se puede volver a hacer (ver do_activity)
var beach_boost_days := 0      # días que le quedan al torneo de vóley (más demanda en la playa)
var weather_noticed := -99    # último día en que el clima salió como aviso (no se guarda)
# Personal: cómo tratas a tus empleados (índice de D.LABOR) y su ánimo (0 a 100)
var labor := 1
var morale := D.START_MORALE
# Microdecisiones: preguntas chicas que NO pausan el juego; si no respondes a tiempo pasa la opción "default"
var micro = null
var next_micro_day := 6
# Rivales: hostilidad, alianzas y a quiénes ya superaste en el ranking (ver _rival_ai)
var rivals := {}          # clave del rival -> {"hostility", "ally_until", "war_until", "last_move"}
var plot_owner := {}      # "índice de terreno" -> clave del rival que lo compró (los de rival_plots)
var passed := []          # rivales que ya superaste en valor
var mall := false         # ¿compraste el centro comercial frente a la oficina? (ver D.MALLS)
var mall2 := false        # ¿y el de la playa?
var office_offered := 0   # hasta qué aspecto ya se ofreció con la ventana «Mejorar oficina»
var office_decor := []    # lo que compraste para la fachada de la oficina (D.OFFICE_DECOR)
var tutorial_step := -1  # paso del tutorial guiado en el que vas (-1: ya terminado); no se puede saltar
var office_look := 0      # aspecto de la oficina (D.OFFICE_LOOKS); las partidas de antes tienen el 2 (el de siempre)
var path := {}            # decisiones importantes tomadas: {"rumbo": "premium"/"masivo", "rivales": "alianza"/"guerra"}
var rival_mall := {}      # "vitrina" -> negocio del rival que la arrienda en tu centro comercial (te paga alquiler)
var franchises := []      # franquicias en otras ciudades: {id, product, city, day, quality, month_royalty, last_royalty}

# Lo que se guarda en el archivo de partida (todo lo anterior menos el generador aleatorio)
const SAVED := ["day", "cash", "bonds", "products", "locations", "loans", "assets", "next_id", "phase",
		"phase_months_left", "econ_index", "inflation", "price_index", "min_wage_mult", "policy_rate", "tax_rate",
		"loss_carry", "overdraft_days", "game_over", "won", "rank", "ledger", "history", "series", "news",
		"pending_choice", "next_choice_day", "profit_streak", "best_day", "last_record_day", "taunted",
		"wardrobe", "owned_items", "look", "hq_level", "fund", "play_seconds", "win_seconds", "mode",
		"strategy_ready_day", "market_today", "rank_log", "rival_plots", "company",
		"weather", "weather_next", "weather_days", "activity_day", "beach_boost_days",
		"labor", "morale", "micro", "next_micro_day", "rivals", "plot_owner", "passed", "mall", "franchises", "mall2", "rival_mall", "path", "office_look", "office_offered", "office_decor", "tutorial_step"]


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
			"last_contrib": null, "month_revenue": 0.0, "plot": null, "mall": null, "owner": false, "stars": 3.0,
			"upgrades": []}


static func make_product(key: String) -> Dictionary:
	var d: Dictionary = D.PRODUCTS[key]
	return {"key": key, "unlocked": false, "price": d.ref_price, "quality": 1, "marketing": 0.0, "stock_days": 2,
			"stock": 0.0, "avg_cost": d.unit_cost, "awareness": 0.1, "reputation": 50.0,
			"competitors": d.competitors, "factory": false, "factory_value": 0.0, "manager": false,
			"ema_sales": 0.0, "cost_shock": 1.0, "cost_shock_days": 0, "demand_shock": 1.0, "demand_shock_days": 0,
			"month_purchases": 0.0, "last_month_purchases": 0.0, "last_demand": 0.0, "last_sold": 0.0,
			"last_capacity": 0.0, "solar": false, "war_days": 0, "cap_boost": 1.0, "cap_boost_days": 0}


## Terreno de la avenida donde está la sucursal; -1 si no tiene.
static func plot_of(loc: Dictionary) -> int:
	return -1 if loc.get("plot") == null else int(loc.plot)


## En el modo normal no existen la bolsa, los bonos ni nada de inversiones financieras: solo el negocio.
func investing() -> bool:
	return mode != "normal"


## Vitrina donde está la sucursal (número global: centro comercial × D.MALL_SLOTS + vitrina); -1 si no está en uno.
static func mall_of(loc: Dictionary) -> int:
	return -1 if loc.get("mall") == null else int(loc.mall)


## En qué centro comercial está una vitrina (0 = frente a la oficina, 1 = la playa).
static func mall_index(slot: int) -> int:
	return slot / int(D.MALL.slots)


## ¿Tienes el centro comercial i?
func has_mall(i: int) -> bool:
	return mall if i == 0 else mall2


## Dónde está una sucursal, para mostrarlo: "T3" (terreno de la avenida), "CC 5" (vitrina del centro comercial).
static func place_label(loc: Dictionary) -> String:
	if mall_of(loc) >= 0:
		var n := int(D.MALL.slots)
		if mall_index(mall_of(loc)) == 1:
			return Lang.f("CC playa %d", mall_of(loc) % n + 1)
		return Lang.f("CC %d", mall_of(loc) + 1)
	if plot_of(loc) >= 0:
		return Lang.f("T%d", plot_of(loc) + 1)
	return ""


## Vitrinas libres del centro comercial (vacías si no lo tienes).
func free_mall_slots() -> Array:
	var used := {}
	for loc in locations:
		used[mall_of(loc)] = true
	var out := []
	var n := int(D.MALL.slots)
	for m in D.MALLS.size():
		if not has_mall(m):
			continue
		for i in range(m * n, (m + 1) * n):
			if not used.has(i) and not rival_mall.has(str(i)):
				out.append(i)
	return out


## ¿Dónde cabe una sucursal nueva de este tamaño? ["plot", i], ["mall", i] o [] si no hay lugar. Primero la avenida
## (las megatiendas solo caben ahí) y después el centro comercial.
func free_place(size: int) -> Array:
	var plots := free_plots()
	if plots:
		return ["plot", plots[0]]
	if size < 2:
		var slots := free_mall_slots()
		if slots:
			return ["mall", slots[0]]
	return []


## Por qué no se puede abrir una sucursal de este tamaño (vacío si sí se puede).
func no_place_reason(size: int) -> String:
	if free_place(size):
		return ""
	if size >= 2:
		return "No quedan terrenos en la avenida: las megatiendas no caben en el centro comercial."
	if not (mall and mall2):
		return "No quedan terrenos en la avenida. Compra un centro comercial (pestaña Expansión) o vende franquicias."
	return "No quedan terrenos ni vitrinas libres. Vende franquicias en otras ciudades (pestaña Expansión)."


## `first_stall`: empieza con el puesto de café ya abierto (las partidas nuevas del jugador empiezan sin nada y con
## la plata para comprarlo: el tutorial lo acompaña a elegir el lugar).
func _init(seed = null, game_mode := "normal", first_stall := true) -> void:
	if seed == null:
		rng.randomize()
	else:
		rng.seed = int(seed)
	for k in D.PRODUCT_ORDER:
		products[k] = make_product(k)
	phase_months_left = rng.randi_range(D.PHASES.expansion.months[0], D.PHASES.expansion.months[1])
	ledger = new_ledger()
	_init_rivals()
	mode = game_mode
	cash = float(D.MODES[mode].start_cash)
	var cafe: Dictionary = products.cafe
	cafe.unlocked = true
	if first_stall:
		var loc := _add_location("cafe", 0, 1, D.SIZES[0].capex, "Puesto de café")
		loc.plot = 0
		cafe.ema_sales = min(demand_at(cafe, loc, cafe.price), capacity(loc))
		add_news(Lang.f("Abriste tu primer puesto de café con %s en caja. ¡A vender!", Fmt.money(cash)), "good")
	else:
		cash += D.SIZES[0].capex
		add_news("Compra tu primer puesto: busca un letrero SE VENDE.", "good")
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
	var vals := {}
	for k in fmt:
		vals[k] = Lang.t(fmt[k]) if fmt[k] is String else fmt[k]
	var line: String = Lang.t(pick(rival[kind])).format(vals)
	add_news(Lang.f("%s (%s): «%s»", [rival.name, rival.company, line]), "rival", "rival", rival.key)


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
	return Lang.f("Día %d · %s · Año %d", dp)


func locs(key: String) -> Array:
	return locations.filter(func(l): return l.product == key)


func wage_daily() -> float:
	return D.BASE_WAGE * price_index * min_wage_mult / 30.0 * D.LABOR[labor].wage


## Cuánto rinde cada empleado por el trato y el ánimo: con ánimo 60 rinde lo normal; muy bajo atiende peor.
func staff_factor() -> float:
	return D.LABOR[labor].prod * clampf(0.85 + 0.15 * morale / 60.0, 0.85, 1.06)


## Suma de un efecto (demand, stars, capacity, weather) de los artículos que compraste para un local.
static func upgrade_bonus(loc: Dictionary, effect: String) -> float:
	var total := 0.0
	for k in loc.get("upgrades", []):
		total += float(D.upgrade_by_key(k).get(effect, 0.0))
	return total


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
	c *= (1.0 - volume_discount(p)) * path_cost()
	if p.factory:
		c *= 1.0 - D.FACTORY_SAVING
		if p.get("solar", false):
			c *= 1.0 - SOLAR_SAVING
	return c


## Alquiler diario de una sucursal (en el centro comercial pagas menos: el edificio es tuyo).
func rent_daily(loc: Dictionary) -> float:
	var rent: float = D.SIZES[loc.size].rent * price_index / 30.0
	return rent * D.MALLS[mall_index(mall_of(loc))].rent_mult if mall_of(loc) >= 0 else rent


func capacity(loc: Dictionary) -> float:
	# `owner` lo activa la ciudad 3D cuando el jugador atiende el mostrador en persona.
	var staff: int = int(loc.employees) + (1 if loc.get("owner", false) else 0)
	var p: Dictionary = products[loc.product]
	return (staff * D.PRODUCTS[loc.product].productivity * staff_factor() * (1.0 + upgrade_bonus(loc, "capacity"))
			* float(p.get("cap_boost", 1.0)))


func season(key: String) -> float:
	var d: Dictionary = D.PRODUCTS[key]
	var month := fmod(day / 30.0, 12.0) + 1.0
	return 1.0 + d.season_amp * cos(TAU * (month - d.season_peak) / 12.0)


## Demanda diaria esperada de una sucursal a un precio dado (sin ruido).
func demand_at(p: Dictionary, loc: Dictionary, price: float, n_locs := -1) -> float:
	var d: Dictionary = D.PRODUCTS[p.key]
	var q: Dictionary = D.QUALITIES[p.quality]
	price = max(0.01, price)
	var price_f := pow(price / ref_price(p), -d.elasticity * q.elast * path_elasticity())
	var econ_f := pow(econ_index, d.income_elasticity * q.income)
	var rep_f: float = 0.7 + 0.6 * p.reputation / 100.0
	var mkt_f: float = 1.0 + 0.6 * p.awareness
	var comp_f: float = (1.0 + 0.1 * d.competitors) / (1.0 + 0.1 * p.competitors)
	var n := n_locs if n_locs >= 0 else locs(p.key).size()
	var cannibal := 1.0 / (1.0 + 0.08 * maxi(0, n - 1))
	var base: float = d.demand * D.SIZES[loc.size].traffic
	if mall_of(loc) >= 0:
		base *= D.MALLS[mall_index(mall_of(loc))].traffic  # la gente pasea por el centro comercial
	if plot_of(loc) in D.BEACH_PLOTS:
		base *= D.BEACH_BONUS  # turistas de la playa
		if beach_boost_days > 0:
			base *= 1.25   # torneo de vóley que patrocinaste
	var stars_f: float = 1.0 + D.STAR_DEMAND * (float(loc.get("stars", 3.0)) - 3.0)
	var extra := 1.0 + upgrade_bonus(loc, "demand")
	var war := 0.88 if int(p.get("war_days", 0)) > 0 else 1.0   # un rival te está atacando en este mercado
	return (base * path_demand() * price_f * econ_f * season(p.key) * rep_f * mkt_f * comp_f * cannibal * p.demand_shock
			* weather_factor(p.key, loc) * stars_f * extra * war)


## Cuánto mueve el clima de hoy la demanda de una sucursal.
func weather_factor(key: String, loc: Dictionary) -> float:
	var fx: Dictionary = D.WEATHER[weather].effects
	var f: float = fx.get(key, 1.0)
	if loc.size < 2 and mall_of(loc) < 0:  # las megatiendas y el centro comercial están techados: la lluvia no espanta
		f *= fx.get("all", 1.0)
	if loc.size == 0 and mall_of(loc) < 0:
		f *= fx.get("stall", 1.0)
	if plot_of(loc) in D.BEACH_PLOTS:
		f *= fx.get("beach", 1.0)
	var shield := upgrade_bonus(loc, "weather")   # aire acondicionado: el mal clima espanta menos
	if f < 1.0 and shield > 0:
		f = lerpf(f, 1.0, minf(1.0, shield))
	return f


## Estrellas de un local (1 a 5).
static func stars_of(loc: Dictionary) -> float:
	return float(loc.get("stars", 3.0))


func _roll_weather() -> int:
	var probs: Array = D.WEATHER_SEASON[(month_index() + 1) % 12]   # el pronóstico es para los próximos días
	var r := rng.randf()
	for i in probs.size():
		r -= probs[i]
		if r <= 0.0:
			return i
	return 0


## Una vez al día: cuenta los días del clima y, cuando toca, entra el que estaba pronosticado.
func _weather_day() -> void:
	weather_days -= 1
	if weather_days > 0:
		return
	weather = weather_next
	weather_next = _roll_weather()
	weather_days = rng.randi_range(2, 5) if weather < 4 else rng.randi_range(2, 3)   # olas de calor y tormentas duran poco
	var w: Dictionary = D.WEATHER[weather]
	# Solo avisan los climas que mueven el negocio (lluvia, calor, tormenta) y no más de uno cada 15 días;
	# el resto queda en Noticias y en el chip del HUD.
	var notice := weather in [3, 4, 5] and day - weather_noticed >= 15
	if notice:
		weather_noticed = day
	add_news(w.news, "bad" if weather in [3, 5] else ("warn" if weather == 4 else "info"), "weather" if notice else "quiet", weather)


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


## Abre una sucursal. `plot`: el terreno de la avenida que elegiste; `mall_slot`: la vitrina del centro comercial. Sin
## ninguno de los dos va al primer lugar libre (ver free_place).
func open_location(key: String, size: int, plot = null, mall_slot = null) -> Array:
	var p: Dictionary = products[key]
	var cost := location_cost(size)
	if not p.unlocked:
		return [false, "Primero desbloquea ese negocio."]
	var place := []
	if plot != null:
		if not int(plot) in free_plots():
			return [false, "Ese terreno ya no está libre."]
		place = ["plot", int(plot)]
	elif mall_slot != null:
		if size >= 2:
			return [false, "Las megatiendas no caben en el centro comercial."]
		if not int(mall_slot) in free_mall_slots():
			return [false, "Esa vitrina ya no está libre."]
		place = ["mall", int(mall_slot)]
	else:
		place = free_place(size)
		if place.is_empty():
			return [false, no_place_reason(size)]
	if cash < cost:
		return [false, Lang.f("Necesitas %s en caja.", Fmt.money(cost))]
	cash -= cost
	var name := Lang.f("%s de %s", [D.SIZES[size].name, Lang.noun(D.PRODUCTS[key].name)])
	var loc := _add_location(key, size, 1, cost, name)
	loc[place[0]] = place[1]
	p.ema_sales += min(demand_at(p, loc, p.price), capacity(loc))
	if place[0] == "mall":
		var where: String = Lang.t("del centro comercial de la playa") if mall_index(place[1]) == 1 else Lang.t("del centro comercial")
		return [true, Lang.f("Abriste un %s en la vitrina %d %s.", [name, place[1] % int(D.MALL.slots) + 1, where])]
	return [true, Lang.f("Abriste un %s.", name)]


func upgrade_cost(loc: Dictionary):
	if loc.size >= D.SIZES.size() - 1 or (loc.size >= 1 and mall_of(loc) >= 0):   # en la vitrina no cabe una megatienda
		return null
	return (D.SIZES[loc.size + 1].capex - D.SIZES[loc.size].capex) * price_index


func upgrade_location(loc: Dictionary) -> Array:
	var cost = upgrade_cost(loc)
	if cost == null:
		return [false, "Ya es del tamaño máximo."]
	if cash < cost:
		return [false, Lang.f("Necesitas %s en caja.", Fmt.money(cost))]
	cash -= cost
	loc.size += 1
	loc["upgrades"] = loc.get("upgrades", []).map(func(k): return D.upgrade_for_size(k, int(loc.size)))
	var a := _add_asset(Lang.f("Ampliación a %s", D.SIZES[loc.size].name), cost)
	loc.asset_ids.append(a.id)
	loc.invested += cost
	return [true, Lang.f("Sucursal ampliada a %s.", D.SIZES[loc.size].name)]


func sell_value(loc: Dictionary) -> float:
	return 0.5 * asset_book(loc.asset_ids)


func sell_location(loc: Dictionary) -> Array:
	var book := asset_book(loc.asset_ids)
	var proceeds := 0.5 * book
	_close_location(loc, proceeds)
	return [true, Lang.f("Vendiste la sucursal por %s (valor en libros %s).", [Fmt.money(proceeds), Fmt.money(book)])]


## Cierra una sucursal vendida por `proceeds`: indemniza a los empleados y deja de comprar inventario para ella.
func _close_location(loc: Dictionary, proceeds: float) -> void:
	var book := asset_book(loc.asset_ids)
	cash += proceeds
	ledger.perdida_activos += book - proceeds
	_spend(loc.employees * D.SEVERANCE_DAYS * wage_daily(), "indemnizaciones", loc.product)
	_drop_assets(loc.asset_ids)
	locations.erase(loc)
	var p: Dictionary = products[loc.product]
	p.ema_sales = max(0.0, p.ema_sales - min(loc.ema_demand, capacity(loc)))


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
		return [false, Lang.f("Necesitas %s en caja.", Fmt.money(cost))]
	cash -= cost
	_add_asset(Lang.f("Licencias y desarrollo: %s", D.PRODUCTS[key].name), cost)
	p.unlocked = true
	p.price = ref_price(p)
	add_news(Lang.f("Nueva línea de negocio: %s. Abre tu primera sucursal.", D.PRODUCTS[key].name), "good")
	return [true, Lang.f("Desbloqueaste %s.", D.PRODUCTS[key].name)]


func factory_cost(key: String) -> float:
	return D.PRODUCTS[key].factory_cost * price_index


func build_factory(key: String) -> Array:
	var p: Dictionary = products[key]
	var cost := factory_cost(key)
	if p.factory:
		return [false, "Ya tienes fábrica."]
	if cash < cost:
		return [false, Lang.f("Necesitas %s en caja.", Fmt.money(cost))]
	cash -= cost
	_add_asset(Lang.f("Fábrica de %s", Lang.noun(D.PRODUCTS[key].name)), cost)
	p.factory = true
	p.factory_value = cost
	add_news(Lang.f("Fábrica propia de %s: tu costo unitario baja 30%%.", Lang.noun(D.PRODUCTS[key].name)), "good")
	return [true, "Fábrica construida."]


func toggle_manager(key: String) -> Array:
	var p: Dictionary = products[key]
	p.manager = not p.manager
	return [true, "Gerente contratado." if p.manager else "Gerente despedido."]


func acquire_cost(key: String) -> float:
	var d: Dictionary = D.PRODUCTS[key]
	var p: Dictionary = products[key]
	var scarcity: float = 1.0 + 0.08 * (d.competitors - p.competitors)
	var war := 0.65 if path.get("rivales", "") == "guerra" else 1.0
	return (35000.0 + 0.25 * d.unlock_cost) * price_index * max(0.5, scarcity) * war


## Compra un competidor. `plot` es el edificio que compras (el que tienes enfrente en la ciudad): un terreno de la
## avenida que el rival compró (0 a 13) o uno de sus locales fijos de los extremos (D.PLOT_COUNT en adelante).
## Sin `plot` se compra el primero que tenga en la avenida, o uno sin edificio en la avenida.
func acquire(key: String, plot := -1, mall_slot := -1) -> Array:
	var p: Dictionary = products[key]
	var cost := acquire_cost(key)
	if p.competitors <= 0:
		return [false, "No quedan competidores."]
	if cash < cost:
		return [false, Lang.f("Necesitas %s en caja.", Fmt.money(cost))]
	# Qué edificio te quedas: el que elegiste, el que el rival tiene en la avenida o, si no tiene, se muda a un
	# terreno o vitrina libre (si no hay ninguno, no se puede comprar)
	var target := []
	if mall_slot >= 0 and rival_mall.get(str(mall_slot)) == key:   # su vitrina en tu centro comercial
		target = ["rmall", str(mall_slot)]
	elif plot >= 0 and rival_plots.get(str(plot)) == key:   # justo el edificio que elegiste
		target = ["rival", str(plot)]
	elif plot >= D.PLOT_COUNT and not plot in D.VALLEY_PLOTS:   # uno de sus locales fijos de los extremos de la calle
		target = ["plot", plot]
	else:
		for i in rival_plots.keys():  # si el rival tiene un local en la avenida, compras ese
			if rival_plots[i] == key:
				target = ["rival", i]
				break
	if target.is_empty():
		target = free_place(1)
		if target.is_empty():
			return [false, "No tienes dónde poner el local que compras: libera un terreno, compra el centro comercial o ve a comprar uno de sus locales de los extremos de la calle."]
	cash -= cost
	var local_value: float = min(cost, location_cost(1))
	var loc := _add_location(key, 1, 3, local_value, Lang.f("Local adquirido de %s", Lang.noun(D.PRODUCTS[key].name)))
	loc.invested = cost
	if target[0] == "rival":
		rival_plots.erase(target[1])
		plot_owner.erase(target[1])
		loc.plot = int(target[1])
	elif target[0] == "rmall":
		rival_mall.erase(target[1])
		loc.mall = int(target[1])
	else:
		loc[target[0]] = target[1]
	if cost > local_value:
		var g := _add_asset(Lang.f("Plusvalía (goodwill): %s", D.PRODUCTS[key].name), cost - local_value)
		loc.asset_ids.append(g.id)
	p.competitors -= 1
	p.ema_sales += min(demand_at(p, loc, p.price), capacity(loc))
	add_news(Lang.f("Adquiriste un competidor de %s: ahora es tu local.", Lang.noun(D.PRODUCTS[key].name)), "good")
	rival_say(D.rival_for(key), "acquire")
	hostility(D.rival_for(key).key, 15)
	return [true, "Adquisición completada."]


# ---------- centro comercial y franquicias ----------
func mall_cost(i := 0) -> float:
	return D.MALLS[i].cost * price_index


func buy_mall(i := 0) -> Array:
	if has_mall(i):
		return [false, "Ya tienes ese centro comercial."]
	var cost := mall_cost(i)
	if cash < cost:
		return [false, Lang.f("Necesitas %s en caja.", Fmt.money(cost))]
	cash -= cost
	_add_asset(D.MALLS[i].name, cost)
	if i == 0:
		mall = true
		add_news(Lang.f("Inauguraste tu centro comercial frente a la oficina: %d vitrinas para puestos y locales.", int(D.MALL.slots)), "good", "record")
	else:
		mall2 = true
		add_news(Lang.f("Inauguraste tu centro comercial de la playa: %d vitrinas frente al mar.", int(D.MALL.slots)), "good", "record")
	return [true, "¡Centro comercial inaugurado!"]


func mall_upkeep_monthly() -> float:
	var total := 0.0
	for i in D.MALLS.size():
		if has_mall(i):
			total += D.MALLS[i].upkeep * price_index
	return total


func franchise_cost(key: String) -> float:
	return (D.FRANCHISE.setup + D.FRANCHISE.setup_share * D.PRODUCTS[key].unlock_cost) * price_index


func franchises_of(key: String) -> Array:
	return franchises.filter(func(f): return f.product == key)


## Por qué no se puede vender otra franquicia de este negocio (vacío si sí se puede).
func franchise_block(key: String) -> String:
	var p: Dictionary = products[key]
	if not p.unlocked:
		return "Primero desbloquea ese negocio."
	if locs(key).size() < int(D.FRANCHISE.min_locs):
		return Lang.f("Necesitas al menos %d sucursales propias de este negocio: nadie compra una marca que no conoce.", int(D.FRANCHISE.min_locs))
	if p.reputation < D.FRANCHISE.min_rep:
		return Lang.f("Tu reputación en este negocio es muy baja (%d de %d).", [roundi(p.reputation), roundi(D.FRANCHISE.min_rep)])
	if franchises_of(key).size() >= int(D.FRANCHISE.max):
		return Lang.f("Ya tienes %d franquicias de este negocio: más y no podrías controlarlas.", int(D.FRANCHISE.max))
	return ""


## Ventas diarias esperadas de una franquicia: un local en otra ciudad con tu marca, tu precio y tu reputación (sin
## tus otras sucursales que le quiten clientes), según qué tan bien la maneja el franquiciado.
func franchise_sales(f: Dictionary) -> float:
	var p: Dictionary = products[f.product]
	var fake := {"size": 1, "stars": 3.0, "upgrades": [], "plot": null, "mall": null}
	return demand_at(p, fake, p.price, 1) * float(f.quality)


## Regalías que deja una franquicia al mes, con las ventas de hoy (para mostrar).
func franchise_royalty_monthly(f: Dictionary) -> float:
	return franchise_sales(f) * products[f.product].price * D.FRANCHISE.royalty * 30.0


func _new_franchise(key: String) -> Dictionary:
	var taken := franchises.map(func(f): return f.city)
	var free: Array = D.FRANCHISE_CITIES.filter(func(c): return not c in taken)
	var city: String = pick(free) if free else Lang.f("Ciudad %d", franchises.size() + 1)
	var f := {"id": _id(), "product": key, "city": city, "day": day, "quality": rng.randf_range(0.7, 1.15),
			"month_royalty": 0.0, "last_royalty": null}
	franchises.append(f)
	return f


## Vende una franquicia: pagas el manual, la capacitación y los abogados; el franquiciado pone el local y te paga
## regalías todos los días. Unos franquiciados atienden mejor que otros.
func open_franchise(key: String) -> Array:
	var block := franchise_block(key)
	if block:
		return [false, block]
	var cost := franchise_cost(key)
	if cash < cost:
		return [false, Lang.f("Necesitas %s en caja.", Fmt.money(cost))]
	cash -= cost
	_add_asset(Lang.f("Contrato de franquicia: %s", D.PRODUCTS[key].name), cost)
	var f := _new_franchise(key)
	var name: String = Lang.noun(D.PRODUCTS[key].name)
	add_news(Lang.f("Tu marca llega a %s: abrió una franquicia de %s.", [f.city, name]), "good")
	return [true, Lang.f("Franquicia de %s en %s.", [name, f.city])]


## Terminar el contrato de una franquicia (deja de pagar regalías; no recuperas lo invertido).
func close_franchise(f: Dictionary) -> Array:
	franchises.erase(f)
	return [true, Lang.f("Terminaste el contrato de la franquicia de %s.", f.city)]


## Todos los días: las franquicias venden y te pagan regalías.
func _franchise_day() -> void:
	for f in franchises:
		var p: Dictionary = products[f.product]
		var royalty: float = franchise_sales(f) * max(0.7, rng.randfn(1.0, 0.07)) * p.price * D.FRANCHISE.royalty
		cash += royalty
		ledger.ingresos += royalty
		_pl(f.product).ingresos += royalty
		_pl(f.product).contribucion += royalty
		f.month_royalty += royalty


## Una vez al mes: cierre de regalías y, si un franquiciado atiende mal, a veces los clientes culpan a tu marca.
func _franchise_month() -> void:
	for f in franchises:
		f.last_royalty = f.month_royalty
		f.month_royalty = 0.0
		if f.quality < 0.85 and rng.randf() < 0.06:
			_rep(f.product, -3)
			add_news(Lang.f("Quejas en %s: el franquiciado de %s atiende mal y tu marca lo paga (−3 de reputación).", [f.city, Lang.noun(D.PRODUCTS[f.product].name)]), "bad")


## Partidas de antes del centro comercial: las sucursales que no tenían lugar en la ciudad (en una partida tenías 31
## y solo 14 terrenos) se acomodan en un terreno libre o en una vitrina; las que no caben pasan a ser franquicias y
## te pagan su valor en libros completo (no pierdes nada).
func _place_homeless() -> void:
	var used := {}
	for loc in locations:   # dos en el mismo lugar: la segunda busca otro
		var key = ["plot", plot_of(loc)] if plot_of(loc) >= 0 else (["mall", mall_of(loc)] if mall_of(loc) >= 0 else null)
		if key != null and used.has(key):
			loc.plot = null
			loc.mall = null
		elif key != null:
			used[key] = true
	var homeless := locations.filter(func(l): return plot_of(l) < 0 and mall_of(l) < 0)
	if homeless.is_empty():
		return
	homeless.sort_custom(func(a, b): return a.size > b.size)   # las megatiendas primero: solo caben en la avenida
	var converted := 0
	var refund := 0.0
	for loc in homeless:
		loc.plot = null
		var place := free_place(loc.size)
		if place:
			loc[place[0]] = place[1]
			continue
		var book := asset_book(loc.asset_ids)
		cash += book
		refund += book
		_drop_assets(loc.asset_ids)
		locations.erase(loc)
		var p: Dictionary = products[loc.product]
		p.ema_sales = max(0.0, p.ema_sales - min(loc.ema_demand, capacity(loc)))
		_new_franchise(loc.product)
		converted += 1
	if converted:
		add_news(Lang.f("Ahora cada sucursal necesita un lugar en la ciudad. Tus %d sucursales sin terreno pasaron a ser franquicias en otras ciudades y recibiste %s, su valor en libros.", [converted, Fmt.money(refund)]), "info")


func wardrobe_cost() -> float:
	return D.WARDROBE_COST * price_index


## Gasto de representación: la imagen del dueño también es un gasto de la empresa.
func unlock_wardrobe() -> Array:
	var cost := wardrobe_cost()
	if wardrobe:
		return [true, "Ya tienes el armario."]
	if cash < cost:
		return [false, Lang.f("Necesitas %s en caja para comprar el armario.", Fmt.money(cost))]
	_spend(cost, "representacion")
	wardrobe = true
	add_news(Lang.f("Compraste el armario de la oficina por %s: ya puedes renovar tu imagen.", Fmt.money(cost)), "good")
	return [true, "Armario comprado. ¡Elige tu ropa!"]


func item_price(base: float) -> float:
	return base * price_index


func buy_item(item: String, base_price: float) -> Array:
	if item in owned_items:
		return [true, ""]
	var price := item_price(base_price)
	if cash < price:
		return [false, Lang.f("Necesitas %s en caja.", Fmt.money(price))]
	_spend(price, "representacion")
	owned_items.append(item)
	return [true, Lang.f("Compraste %s por %s.", [item.split(":")[-1], Fmt.money(price)])]


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
			"payment": loan_payment(amount, months, rate), "accrued": 0.0})
	cash += amount
	return [true, Lang.f("Préstamo de %s al %s anual.", [Fmt.money(amount), Fmt.pct(rate)])]


## Lo que cuesta pagar el préstamo hoy: el capital más el interés de los días que van del mes.
func prepay_amount(loan: Dictionary) -> float:
	return loan.principal + _accrued(loan)


## Interés acumulado desde el último cierre de mes (las partidas viejas no lo guardaban: se estima por la fecha).
func _accrued(loan: Dictionary) -> float:
	return float(loan.get("accrued", loan.principal * loan.rate / 360.0 * (day % 30)))


func prepay_loan(loan: Dictionary) -> Array:
	var interest := _accrued(loan)
	var total: float = loan.principal + interest
	if cash < total:
		return [false, Lang.f("Necesitas %s en caja.", Fmt.money(total))]
	cash -= total
	ledger.intereses += interest
	loans.erase(loan)
	return [true, Lang.f("Préstamo pagado por completo (%s de intereses del mes).", Fmt.money(interest))]


func buy_bonds(amount: float) -> Array:
	amount = min(amount, cash)
	if amount <= 0:
		return [false, "No tienes caja disponible."]
	cash -= amount
	bonds += amount
	return [true, Lang.f("Invertiste %s en bonos.", Fmt.money(amount))]


func sell_bonds(amount: float) -> Array:
	amount = min(amount, bonds)
	if amount <= 0:
		return [false, "No tienes bonos."]
	bonds -= amount
	cash += amount
	return [true, Lang.f("Retiraste %s de bonos.", Fmt.money(amount))]


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
		cost += l.employees * wage_daily() + rent_daily(l)
	cost += p.marketing / 30.0
	if p.manager:
		cost += D.MANAGER_WAGE * price_index * min_wage_mult / 30.0
	if p.factory:
		cost += factory_upkeep_monthly(p) / 30.0
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
		return [false, Lang.f("Necesitas %s en caja.", Fmt.money(cost))]
	cash -= cost
	hq_level += 1
	var name: String = D.HQ_LEVELS[hq_level][0]
	_add_asset(Lang.f("Sistemas de gestión: %s", name), cost)
	add_news(Lang.f("Oficina central: %s. Tus gastos corporativos bajan.", name), "good")
	return [true, Lang.f("Instalaste %s.", name)]


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
		return [false, Lang.f("La próxima reunión de estrategia es en %d días.", strategy_wait())]
	var cost := strategy_cost(key)
	if cash < cost:
		return [false, Lang.f("Necesitas %s en caja.", Fmt.money(cost))]
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
	add_news(Lang.f("Reunión de estrategia: %s (%s).", [name, Fmt.money(cost)]), "good")
	return [true, Lang.f("%s: en marcha.", name)]


# ---------- actividades en la ciudad (parque, barrio, playa, muelle) ----------
func _activity(key: String) -> Array:
	for a in D.ACTIVITIES:
		if a[0] == key:
			return a
	return D.ACTIVITIES[0]


func activity_wait(key: String) -> int:
	return max(0, int(activity_day.get(key, 0)) - day)


func activity_cost(key: String) -> float:
	match key:
		"muestras":
			return max(600.0 * price_index, 0.02 * _scale())
		"voley":
			return max(2500.0 * price_index, 0.05 * _scale())
	return 0.0


## Lo que se pesca, en plata: más de madrugada y al atardecer (`hour` = hora del reloj que se ve en la ciudad).
func fish_value(hour: float) -> float:
	var good := hour < 8.0 or (hour >= 17.0 and hour < 21.0)
	return roundf(rng.randf_range(60.0, 220.0) * (1.8 if good else 1.0) * price_index)


func do_activity(key: String, hour := 12.0) -> Array:
	var wait := activity_wait(key)
	if wait:
		return [false, Lang.f("Podrás volver a hacerlo en %d día%s.", [wait, "" if wait == 1 else "s"])]
	var active := []
	for p in products.values():
		if p.unlocked and locs(p.key):
			active.append(p)
	if active.is_empty() and key != "pesca":
		return [false, "Primero necesitas un negocio abierto."]
	var cost := activity_cost(key)
	if cash < cost:
		return [false, Lang.f("Necesitas %s en caja.", Fmt.money(cost))]
	var msg := ""
	match key:
		"muestras":
			_spend(cost, "marketing")
			for p in active:
				p.awareness = min(1.0, p.awareness + 0.08)
			msg = Lang.f("Repartiste muestras en el parque (%s): más gente conoce tus marcas.", Fmt.money(cost))
		"encuesta":
			var worst = null
			var gap := 0.0
			for p in active:
				var best: Array = price_curve(p.key, 40)[1]
				var g: float = absf(best[0] / max(p.price, 0.01) - 1.0)
				_rep(p.key, 2)
				if worst == null or g > gap:
					worst = [p.key, best[0]]
					gap = g
			var name: String = D.PRODUCTS[worst[0]].name
			if gap < 0.08:
				msg = "Encuesta: a los vecinos les parecen justos tus precios. Sigue así."
			else:
				msg = Lang.f("Encuesta: por %s los vecinos pagarían alrededor de %s (cobras %s).", [name.to_lower(),
						Fmt.money(worst[1], 2), Fmt.money(products[worst[0]].price, 2)])
		"voley":
			_spend(cost, "marketing")
			for p in active:
				_rep(p.key, 5)
			beach_boost_days = 7
			msg = Lang.f("Patrocinaste el torneo de vóley (%s): +5 de reputación y más clientes en la playa por 7 días.", Fmt.money(cost))
		"pesca":
			var v := fish_value(hour)
			cash += v
			ledger.ingresos += v
			msg = Lang.f("Pescaste y lo vendiste en el puerto: +%s.", Fmt.money(v))
	activity_day[key] = day + int(_activity(key)[2])
	return [true, msg]


func invest_fund(amount: float) -> Array:
	amount = min(amount, cash)
	if amount <= 0:
		return [false, "No tienes caja disponible."]
	cash -= amount
	fund += amount
	return [true, Lang.f("Invertiste %s en el fondo.", Fmt.money(amount))]


func withdraw_fund(amount: float) -> Array:
	amount = min(amount, fund)
	if amount <= 0:
		return [false, "No tienes dinero en el fondo."]
	fund -= amount
	cash += amount
	return [true, Lang.f("Retiraste %s del fondo.", Fmt.money(amount))]


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
			tips.append(["warn", Lang.f("%s: pierdes %s de la demanda por falta de personal o espacio.", [name, Fmt.pct(cap_lost / dem, 0)])])
		if potential > 0 and p.last_sold < potential * 0.95:
			tips.append(["warn", Lang.f("%s: te quedaste sin inventario. Sube los días de inventario.", name)])
		if idle:
			tips.append(["info", Lang.f("%s: hay personal ocioso en %d sucursal(es). Cuesta salario sin vender.", [name, idle])])
		var best: Array = price_curve(key, 40)[1]
		if p.price > 0 and abs(best[0] / p.price - 1.0) > 0.15:
			tips.append(["info", Lang.f("%s: el precio que maximiza tu utilidad ronda %s.", [name, Fmt.money(best[0], 2)])])
		if p.price / ref_price(p) < 0.8:
			tips.append(["info", Lang.f("%s: la inflación dejó tu precio muy por debajo del mercado.", name)])
	if cash < 0:
		tips.append(["bad", Lang.f("Estás en sobregiro: pagas %s anual sobre el saldo negativo.", Fmt.pct(policy_rate + 0.18, 0))])
	if investing() and cash > 30000 * price_index and bonds == 0:
		tips.append(["info", "Tienes mucha caja quieta. Invertirla o ponerla en bonos evita el costo de oportunidad."])
	for key in D.PRODUCT_ORDER:
		if not products[key].unlocked:
			if cash >= unlock_cost(key):
				tips.append(["good", Lang.f("Ya puedes desbloquear %s en Negocios.", D.PRODUCTS[key].name)])
			break
	return tips.slice(0, 7)


# ---------- simulación ----------
func step_day() -> void:
	if game_over:
		return
	var before: float = statement(ledger).ebitda
	var rev_before: float = ledger.ingresos
	_macro()
	_weather_day()
	beach_boost_days = max(0, beach_boost_days - 1)
	_events()
	_maybe_dilemma()
	_maybe_micro()
	_staff_day()
	_rival_ai()
	for key in D.PRODUCT_ORDER:
		if products[key].unlocked:
			_run_product(products[key])
	_franchise_day()
	if mall or mall2:
		_spend(mall_upkeep_monthly() / 30.0, "alquiler")
		_rival_mall_rent()

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
		add_news(Lang.f("Caja negativa: se vendieron %s en inversiones para cubrirla.", Fmt.money(from_bonds + from_fund)), "warn")
	if cash < 0:
		var interest := -cash * (policy_rate + 0.18) / 365.0
		cash -= interest
		ledger.intereses += interest
	# Los préstamos acumulan interés cada día (30 días = la cuota de interés del mes); se paga al cerrar el mes.
	for loan in loans:
		loan.accrued = _accrued(loan) + loan.principal * loan.rate / 360.0

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
	_alliance_share(rev)
	if rev > best_day + 0.01:  # un centavo: que el redondeo no invente récords
		if best_day > 0 and day >= 20 and day - last_record_day >= 15:
			last_record_day = day
			add_news(Lang.f("¡Récord de ventas en un día: %s!", Fmt.money(rev)), "good", "record", rev)
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

	# Compra de inventario al inicio del día para cubrir los días objetivo (sin sucursales no se compra nada).
	if ls.is_empty():
		p.ema_sales = 0.0
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
		var rent: float = rent_daily(loc)
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

	var spoiled: float = p.stock * d.spoil * float(D.WEATHER[weather].effects.get("spoil", 1.0))
	p.stock -= spoiled
	ledger.mermas += spoiled * p.avg_cost
	pl.contribucion -= spoiled * p.avg_cost
	_spend(p.stock * p.avg_cost * D.HOLDING_RATE, "almacenamiento", p.key)
	if p.marketing > 0:
		_spend(p.marketing / 30.0, "marketing", p.key)
	if p.manager:
		_spend(D.MANAGER_WAGE * price_index * min_wage_mult / 30.0, "gerentes", p.key)
	if p.factory:
		_spend(factory_upkeep_monthly(p) / 30.0, "fabricas", p.key)

	if ls:
		p.ema_sales = 0.8 * p.ema_sales + 0.2 * potential
	var cap_total := 0.0
	for l in ls:
		cap_total += l.capacity
	p.last_demand = total_demand
	p.last_sold = sold_total
	p.last_capacity = cap_total

	for loc in ls:
		_update_stars(p, loc)

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
			add_news(Lang.f("El costo de %s volvió a la normalidad.", Lang.noun(d.name)), "info")
	if p.demand_shock_days > 0:
		p.demand_shock_days -= 1
		if p.demand_shock_days == 0:
			p.demand_shock = 1.0
	if int(p.get("cap_boost_days", 0)) > 0:
		p.cap_boost_days = int(p.cap_boost_days) - 1
		if p.cap_boost_days == 0:
			p.cap_boost = 1.0


## Las estrellas de un local se mueven despacio hacia lo que merece: si atiende a todos (y si atiendes tú), la
## reputación de la marca, la calidad y si el precio es justo. Cruzar una estrella entera sale en las noticias.
func _update_stars(p: Dictionary, loc: Dictionary) -> void:
	var service: float = loc.sold / loc.demand if loc.demand > 0 else 1.0
	var ratio: float = p.price / ref_price(p)
	var score := 0.4 * clampf((service - 0.55) / 0.4, 0.0, 1.0)
	score += 0.3 * p.reputation / 100.0
	score += 0.15 * p.quality / 2.0
	score += 0.15 * clampf(1.6 - ratio, 0.0, 1.0)
	if loc.get("owner", false):
		score += 0.1   # el dueño atendiendo en persona
	if morale < 30:
		score -= 0.12 * (30.0 - morale) / 30.0   # empleados maltratados atienden de mala gana
	elif morale > 75:
		score += 0.05
	var target := clampf(1.0 + 4.0 * clampf(score, 0.0, 1.0) + upgrade_bonus(loc, "stars"), 1.0, 5.0)
	var before := stars_of(loc)
	var now := before + (target - before) * 0.04
	loc.stars = now
	var name := Lang.f("%s de %s", [Lang.noun(D.SIZES[loc.size].name), Lang.noun(D.PRODUCTS[loc.product].name)])
	if floori(now) > floori(before) and floori(now) >= 2:
		add_news(Lang.f("Tu %s subió a %d estrellas.", [name, floori(now)]), "good", "stars", [loc.id, floori(now), true])
		if floori(now) == 5:
			p.awareness = min(1.0, p.awareness + 0.1)
			add_news(Lang.f("¡La guía de la ciudad recomienda tu %s! Más gente conoce tu marca.", name), "good", "quiet")
	elif floori(now) < floori(before):
		add_news(Lang.f("Tu %s bajó a %d %s: revisa la atención, el precio o la calidad.", [name, max(1, floori(now)), "estrella" if floori(now) <= 1 else "estrellas"]),
				"bad", "stars", [loc.id, max(1, floori(now)), false])


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
		add_news(Lang.f("¡Viral en redes! Tu marca de %s gana reputación.", Lang.noun(D.PRODUCTS[p.key].name)), "good")
	elif locations and rng.randf() < 1.0 / 300:
		var cheap := with_locs.any(func(p): return p.quality == 0)
		if cheap or rng.randf() < 0.5:
			var fine := 600.0 * price_index * (1 + 0.1 * locations.size())
			_spend(fine, "multas")
			add_news(Lang.f("Inspección sanitaria: multa de %s", Fmt.money(fine))
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
		add_news(Lang.f("Robo en una bodega de %s: perdiste 25%% del inventario.", Lang.noun(D.PRODUCTS[p.key].name)), "bad")
	elif phase in ["expansion", "auge"] and rng.randf() < 1.0 / 1500:
		_set_phase("recesion")
		add_news("Crisis financiera internacional: la economía entra en recesión.", "bad")
	elif rng.randf() < 1.0 / 1200:
		if rng.randf() < 0.5:
			tax_rate = min(0.35, tax_rate + 0.03)
			add_news(Lang.f("Reforma tributaria: el impuesto a las utilidades sube a %s.", Fmt.pct(tax_rate, 0)), "bad")
		else:
			tax_rate = max(0.15, tax_rate - 0.03)
			add_news(Lang.f("Reforma tributaria: el impuesto a las utilidades baja a %s.", Fmt.pct(tax_rate, 0)), "good")
	elif unlocked and rng.randf() < 1.0 / 500:
		var p: Dictionary = pick(unlocked)
		p.competitors += 1
		add_news(Lang.f("Una cadena nueva de %s llega a la ciudad.", Lang.noun(D.PRODUCTS[p.key].name)), "bad")
		rival_say(D.rival_for(p.key), "entry", {"p": Lang.noun(D.PRODUCTS[p.key].name)})


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
		var interest := _accrued(loan)
		loan.accrued = 0.0
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
	_staff_month()
	_franchise_month()
	_rival_ranks()

	phase_months_left -= 1
	if phase_months_left <= 0:
		_set_phase(D.PHASES[phase].next)
		var kind := "bad" if phase == "recesion" else ("good" if phase in ["recuperacion", "auge"] else "info")
		add_news(Lang.f("Ciclo económico: la economía entra en %s.", Lang.noun(D.PHASES[phase].name)), kind)

	var net: float = statement(L).utilidad_neta
	add_news(Lang.f("Cierre de %s: utilidad neta %s.", [D.MONTHS[(month_index() - 1) % 12], Fmt.money(net)]),
			"good" if net >= 0 else "bad", "month", net)
	if net >= 0:
		profit_streak += 1
		if profit_streak in [3, 6, 12, 24, 36, 60]:
			add_news(Lang.f("¡Racha de %d meses seguidos con utilidad!", profit_streak), "good", "streak", profit_streak)
	else:
		if profit_streak >= 3:
			add_news(Lang.f("Se rompió tu racha de %d meses con utilidad.", profit_streak), "bad", "streak_lost", profit_streak)
		profit_streak = 0
	if cash >= 0:
		taunted = false

	var info := rank_info()
	var idx: int = info[0]
	if idx > rank:
		for r in ranks().slice(rank + 1, idx + 1):
			rank_log[r[1]] = [day, play_seconds]
		rank = idx
		add_news(Lang.f("¡Nuevo rango: %s! Tu empresa vale %s.", [info[1], Fmt.money(info[3])]), "good", "rank", info[1])
		for i in D.OFFICE_LOOKS.size():
			if int(D.OFFICE_LOOKS[i][1]) == idx and i > office_look:
				add_news(Lang.f("Ya puedes remodelar tu oficina: %s.", D.OFFICE_LOOKS[i][0]), "good")
		rival_say(_some_rival(), "rank", {"r": info[1]})
	if info[3] >= win_value() and not won:
		won = true
		win_seconds = play_seconds
		var goal := "un imperio de más de $10 millones" if mode == "normal" else "una fortuna de mil millones"
		add_news(Lang.f("¡Construiste %s en %d minutos de juego!", [goal, roundi(play_seconds / 60.0)]), "good", "win")

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
	var name: String = Lang.noun(d.name)
	if margin > 0.25 and econ_index >= 1.0 and r < 0.3 and p.competitors < 12:
		p.competitors += 1
		add_news(Lang.f("Atraído por las ganancias del mercado de %s, abre un nuevo competidor.", name), "bad")
		rival_say(D.rival_for(p.key), "entry", {"p": name})
	elif econ_index < 0.9 and p.competitors > 1 and r < 0.3:
		p.competitors -= 1
		add_news(Lang.f("La recesión hace cerrar a un competidor de %s.", name), "good")
	elif p.price / ref_price(p) < 0.8 and p.competitors > 1 and r < 0.2:
		p.competitors -= 1
		add_news(Lang.f("Tus precios bajos sacaron del mercado a un competidor de %s.", name), "good")
		rival_say(D.rival_for(p.key), "loss", {"p": name})


# ---------- terrenos de la avenida en manos de los rivales ----------
func free_plots() -> Array:
	var used := {}
	for loc in locations:
		used[plot_of(loc)] = true
	var out := []
	for i in D.LOT_PLOTS:
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
			plot_owner.erase(i)
			add_news(Lang.f("%s cerró su local del terreno %d: vuelve a estar en venta.", [D.rival_for(key).company, int(i) + 1]), "good")
		var in_mall := []
		for i in rival_mall:
			if rival_mall[i] == key:
				in_mall.append(i)
		while in_mall.size() + mine.size() > products[key].competitors and in_mall:
			var i: String = in_mall.pop_back()
			rival_mall.erase(i)
			add_news(Lang.f("%s dejó su vitrina en tu centro comercial: quedó libre.", D.rival_for(key).company), "good")
	_rival_rents_vitrina()
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
	var name: String = Lang.noun(D.PRODUCTS[key].name)
	var where := " en la playa" if plot in D.BEACH_PLOTS else ""
	add_news(Lang.f("%s compró el terreno %d%s y abrió un local de %s.", [r.company, plot + 1, where, name]), "bad")
	rival_say(r, "entry", {"p": name})


## De vez en cuando un rival arrienda una vitrina libre de tu centro comercial: compite contigo ahí adentro, pero te
## paga alquiler (ver _rival_mall_rent). Nunca se quedan con más de 5 por centro comercial.
func _rival_rents_vitrina() -> void:
	var free := free_mall_slots()
	var owned := (1 if mall else 0) + (1 if mall2 else 0)
	if free.size() <= 3 or rival_mall.size() >= 5 * owned or rng.randf() > 0.45:
		return
	var keys := []
	for k in products:
		if products[k].unlocked:
			keys.append(k)
	var key: String = pick(keys if keys else ["cafe"])
	var slot: int = pick(free)
	rival_mall[str(slot)] = key
	products[key].competitors += 1
	var r := D.rival_for(key)
	add_news(Lang.f("%s arrendó una vitrina de tu centro comercial y abrió un local de %s. Te paga alquiler.", [r.company, Lang.noun(D.PRODUCTS[key].name)]), "rival")


## Alquiler diario que te pagan los rivales por sus vitrinas.
func _rival_mall_rent() -> void:
	if rival_mall.is_empty():
		return
	var rent := 0.0
	for i in rival_mall:
		rent += D.SIZES[1].rent * price_index * D.MALLS[mall_index(int(i))].rent_mult / 30.0
	cash += rent
	ledger.ingresos += rent


# ---------- dilemas: decisiones con riesgo que pausan el juego ----------
## Tamaño del negocio (ventas del último mes) para que los montos de los dilemas importen.
func _scale() -> float:
	var total := 0.0
	var arr: Array = series.ingresos
	for v in arr.slice(max(0, arr.size() - 30)):
		total += v
	return max(800.0 * price_index, total)


const DILEMMAS := ["soborno", "influencer", "aumento", "lote", "demanda", "cartel", "oferta", "compra_rival",
		"huelga", "franquicia", "ciberataque", "patrocinio", "proveedor", "fabrica"]


func _maybe_dilemma() -> void:
	var due := key_decision_due()
	if pending_choice == null and due != "":   # las decisiones importantes van primero
		pending_choice = build_dilemma(due)
		add_news(Lang.f("Decisión importante: %s", pending_choice.title), "warn", "dilemma")
		return
	if pending_choice != null or day < next_choice_day or locations.is_empty():
		return
	next_choice_day = day + rng.randi_range(35, 70)
	var builders := ["soborno", "influencer", "aumento", "lote", "demanda", "huelga", "ciberataque", "patrocinio",
			"proveedor"]
	if day >= 90:
		builders.append("franquicia")  # tu marca ya es conocida
	if day >= 120 and _factory_offer_keys().size() > 0:
		builders.append("fabrica")
	if morale < 30:
		builders += ["huelga", "huelga"]   # un equipo maltratado se organiza
	if products.values().any(func(p): return p.unlocked and p.competitors > 0):
		builders.append("cartel")
	if locations.size() > 1:
		builders.append("oferta")
		if day >= 60:
			builders += ["compra_rival", "compra_rival"]  # los rivales intentan comprarte locales
	pending_choice = build_dilemma(pick(builders))
	add_news(Lang.f("Decisión urgente: %s", pending_choice.title), "warn", "dilemma")


func build_dilemma(id: String) -> Dictionary:
	return call("_d_" + id)


func _pick_loc() -> Array:
	var loc: Dictionary = pick(locations)
	var name := Lang.f("%s de %s", [Lang.noun(D.SIZES[loc.size].name), Lang.noun(D.PRODUCTS[loc.product].name)])
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
			"text": Lang.f("Un inspector sanitario revisó tu %s y dice haber encontrado «irregularidades». Te ofrece olvidarlo todo por %s en efectivo, sin factura. Te mira esperando.", [pl[1], Fmt.money(bribe)]),
			"options": [_opt(Lang.f("Pagar el soborno (%s)", Fmt.money(bribe)),
					Lang.f("75%%: nadie se entera. 25%%: sale en las noticias, multa de %s y tu reputación se desploma (−25).", Fmt.money(big))),
					_opt("Rechazarlo y aceptar la inspección",
					Lang.f("Multa segura de %s, pero ganas reputación por ser honesto (+5).", Fmt.money(fine)))],
			"data": {"product": pl[0].product, "bribe": bribe, "fine": fine, "big": big}}


func _r_soborno(opt: int, d: Dictionary) -> Array:
	if opt == 0:
		_spend(d.bribe, "multas", d.product)
		if rng.randf() < 0.25:
			_spend(d.big, "multas", d.product)
			_rep(d.product, -25)
			return [Lang.f("¡Escándalo! Un periodista grabó el soborno: multa de %s y tu reputación se hunde.", Fmt.money(d.big)), "bad"]
		return ["Pagaste y el inspector desapareció. Nadie se enteró... por ahora.", "warn"]
	_spend(d.fine, "multas", d.product)
	_rep(d.product, 5)
	return [Lang.f("Pagaste la multa de %s. Los clientes valoran tu transparencia (+5 reputación).", Fmt.money(d.fine)), "info"]


func _d_influencer() -> Dictionary:
	var loc: Dictionary = _pick_loc()[0]
	var fee := 0.25 * _scale()
	var pname: String = Lang.noun(D.PRODUCTS[loc.product].name)
	return {"id": "influencer", "title": "Una influencer quiere promocionarte",
			"text": Lang.f("Una influencer con 2 millones de seguidores quiere hacer un video de tu %s. Cobra %s por adelantado. «Mis videos o explotan o no los ve nadie», admite.", [pname, Fmt.money(fee)]),
			"options": [_opt(Lang.f("Contratarla (%s)", Fmt.money(fee)),
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
	return [Lang.f("El video pasó sin pena ni gloria. Perdiste %s.", Fmt.money(d.fee)), "bad"]


func _d_aumento() -> Dictionary:
	var loc: Dictionary = locations[0]
	for l in locations:
		if l.employees > loc.employees:
			loc = l
	var pname: String = Lang.noun(D.PRODUCTS[loc.product].name)
	var bonus := 0.1 * _scale()
	var rival: String = D.rival_for(loc.product).company
	return {"id": "aumento", "title": "Tu mejor empleada pide un bono",
			"text": Lang.f("Camila, tu mejor empleada de %s, lleva meses haciendo doble turno. Pide un bono de %s. «Si no, me voy con %s: ya me ofrecieron trabajo.»", [pname, Fmt.money(bonus), rival]),
			"options": [_opt(Lang.f("Darle el bono (%s)", Fmt.money(bonus)), "El equipo se motiva y se nota en la atención: +8 de reputación."),
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
	return [Lang.f("Camila renunció y ahora trabaja para %s. Se llevó a varios clientes (−10 reputación).", d.get("rival", "la competencia")), "bad"]


func _d_lote() -> Dictionary:
	var loc: Dictionary = _pick_loc()[0]
	var p: Dictionary = products[loc.product]
	var units: float = max(20.0, p.ema_sales * 5.0)
	var value := units * unit_cost(p)
	var pname: String = Lang.noun(D.PRODUCTS[loc.product].name)
	return {"id": "lote", "title": "Una ganga sospechosa",
			"text": Lang.f("Un proveedor que nadie conoce ofrece un lote de %s: %d unidades por %s. Valen %s. No da factura ni dirección.", [pname, roundi(units), Fmt.money(value * 0.5), Fmt.money(value)]),
			"options": [_opt(Lang.f("Comprar el lote (%s)", Fmt.money(value * 0.5)),
					Lang.f("65%%: ahorras %s. 35%%: estaba en mal estado, lo botas y algunos clientes se enferman (−15 reputación).", Fmt.money(value * 0.5))),
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
		return [Lang.f("¡Era bueno! Tu inventario creció y tu costo promedio bajó. Ahorraste %s.", Fmt.money(d.cost)), "good"]
	ledger.mermas += d.cost
	_pl(d.product).contribucion -= d.cost
	_rep(d.product, -15)
	return ["El lote estaba podrido. Lo botaste, pero algunos clientes ya se habían enfermado (−15 reputación).", "bad"]


func _d_demanda() -> Dictionary:
	var pl := _pick_loc()
	var k := _scale()
	return {"id": "demanda", "title": "Te demandan",
			"text": Lang.f("Un cliente asegura que se enfermó en tu %s y te demanda. Su abogado te llama: «Firmamos un acuerdo por %s y aquí no pasó nada».", [pl[1], Fmt.money(0.15 * k)]),
			"options": [_opt(Lang.f("Pagar el acuerdo (%s)", Fmt.money(0.15 * k)), "El caso se cierra en silencio."),
					_opt("Ir a juicio", Lang.f("50%%: ganas y no pagas nada (+5 reputación). 50%%: pierdes, pagas %s y sale en las noticias (−20 reputación).", Fmt.money(0.45 * k)))],
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
	return [Lang.f("Perdiste el juicio: pagas %s y tu marca aparece en todos los noticieros.", Fmt.money(d.lose)), "bad"]


func _d_cartel() -> Dictionary:
	var keys := []
	for p in products.values():
		if p.unlocked and p.competitors > 0:
			keys.append(p.key)
	var key: String = pick(keys if keys else ["cafe"])
	var pname: String = Lang.noun(D.PRODUCTS[key].name)
	var fine := 1.2 * _scale()
	var r := D.rival_for(key)
	return {"id": "cartel", "title": Lang.f("%s te propone un pacto", r.name),
			"text": Lang.f("%s, de %s, te invita a cenar. «Subamos los precios de %s los dos y dejemos de pelear. Ganamos todos... menos los clientes.» Es ilegal.", [r.name, r.company, pname]),
			"options": [_opt("Aceptar el pacto",
					Lang.f("Tu demanda de %s sube 30%% por 60 días. 30%%: la autoridad descubre el cartel: multa de %s y −30 de reputación.", [pname, Fmt.money(fine)])),
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
			return [Lang.f("¡La fiscalía allanó tus oficinas! El cartel quedó al descubierto: multa de %s.", Fmt.money(d.fine)), "bad"]
		p.demand_shock = max(p.demand_shock, 1.3)
		p.demand_shock_days = 60
		return ["Pacto sellado. Los precios suben en toda la ciudad y tus ventas también... por ahora.", "warn"]
	if opt == 1:
		hostility(r.key, 10)
		if rng.randf() < 0.5:
			p.competitors += 1
			return [Lang.f("%s: «Te vas a arrepentir.» Abrió otro local en tu mercado.", r.name), "bad"]
		return [Lang.f("%s se fue de la cena sin pagar. Por ahora no pasó nada más.", r.name), "info"]
	hostility(r.key, 25)
	if rng.randf() < 0.5:
		p.competitors = max(0, p.competitors - 1)
		return [Lang.f("¡La autoridad multó a %s y le cerró un local! Un competidor menos.", r.company), "good"]
	p.competitors += 2
	return [Lang.f("No hubo pruebas y, como venganza, %s abrió dos locales nuevos.", r.name), "bad"]


func _last_contrib(loc: Dictionary) -> float:
	return 0.0 if loc.last_contrib == null else float(loc.last_contrib)


func _d_oferta() -> Dictionary:
	var pl := _pick_loc()
	var loc: Dictionary = pl[0]
	var book := asset_book(loc.asset_ids)
	var offer: float = max(book * 1.3, max(0.0, _last_contrib(loc)) * 18.0) * rng.randf_range(0.9, 1.2)
	return {"id": "oferta", "title": "Quieren comprarte una sucursal",
			"text": Lang.f("Un empresario quiere comprar tu %s por %s al contado. En libros vale %s y el mes pasado aportó %s. La oferta vence hoy.", [pl[1], Fmt.money(offer), Fmt.money(book), Fmt.money(_last_contrib(loc))]),
			"options": [_opt(Lang.f("Vender (%s)", Fmt.money(offer)),
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
	_close_location(loc, d.offer)
	return [Lang.f("Vendiste la sucursal por %s: %s más que su valor en libros.", [Fmt.money(d.offer), Fmt.money(d.offer - book)]), "good"]


func _d_compra_rival() -> Dictionary:
	var plotted := locations.filter(func(l): return plot_of(l) >= 0)
	var loc: Dictionary = pick(plotted if plotted else locations)
	var key: String = loc.product
	var r := D.rival_for(key)
	var book := asset_book(loc.asset_ids)
	var offer: float = max(book * 1.4, max(0.0, _last_contrib(loc)) * 16.0) * rng.randf_range(0.95, 1.25)
	var name := Lang.f("%s de %s", [Lang.noun(D.SIZES[loc.size].name), Lang.noun(D.PRODUCTS[key].name)])
	var where := Lang.f(" del terreno %d", (plot_of(loc) + 1)) if plot_of(loc) >= 0 else ""
	return {"id": "compra_rival", "title": Lang.f("%s quiere comprarte un local", r.name),
			"text": Lang.f("%s, de %s, te ofrece %s por tu %s%s. «Véndemelo y nos ahorramos la pelea.» En libros vale %s y el mes pasado aportó %s. Si aceptas, ese local pasa a ser de la competencia.", [r.name, r.company, Fmt.money(offer), name, where, Fmt.money(book), Fmt.money(_last_contrib(loc))]),
			"options": [_opt(Lang.f("Vender (%s)", Fmt.money(offer)),
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
			return [Lang.f("%s: «Como quieras.» Compró el terreno %d para abrir cerca de ti.", [r.name, plot + 1]), "bad"]
		return [Lang.f("%s: «Ya cambiarás de opinión.» El local sigue siendo tuyo.", r.name), "info"]
	var plot := plot_of(loc)
	_close_location(loc, d.offer)
	if plot >= 0:
		_rival_takes(d.product, plot)
	else:
		products[d.product].competitors += 1
	return [Lang.f("Vendiste el local a %s por %s. Ahora es de la competencia.", [r.company, Fmt.money(d.offer)]), "good"]


func _active_products() -> Array:
	return products.values().filter(func(p): return p.unlocked and not locs(p.key).is_empty())


func _d_huelga() -> Dictionary:
	var loc: Dictionary = locations[0]
	for l in locations:
		if l.employees > loc.employees:
			loc = l
	var pname: String = Lang.noun(D.PRODUCTS[loc.product].name)
	var raise := 0.12 * _scale()
	return {"id": "huelga", "title": "Tus empleados amenazan con una huelga",
			"text": Lang.f("El sindicato de tus locales de %s dice que los sueldos no alcanzan con la inflación. Piden un bono de %s para todos. «Si no, mañana nadie abre la cortina.»", [pname, Fmt.money(raise)]),
			"options": [_opt(Lang.f("Pagar el bono (%s)", Fmt.money(raise)), "Se acaba el conflicto y el equipo queda contento: +4 de reputación."),
					_opt("Negarte", Lang.f("50%%: se echan para atrás. 50%%: huelga de 7 días: la demanda de %s cae a la mitad y −8 de reputación.", pname))],
			"data": {"product": loc.product, "raise": raise}}


func _r_huelga(opt: int, d: Dictionary) -> Array:
	if opt == 0:
		_spend(d.raise, "salarios", d.product)
		_rep(d.product, 4)
		morale = min(100.0, morale + 10)
		return ["Firmaron el acuerdo. Tus empleados vuelven a trabajar con ganas (+4 reputación).", "good"]
	if rng.randf() < 0.5:
		return ["El sindicato se echó para atrás. Por ahora no hay huelga.", "info"]
	var p: Dictionary = products[d.product]
	p.demand_shock = 0.5
	p.demand_shock_days = 7
	_rep(d.product, -8)
	return [Lang.f("¡HUELGA! Tus locales de %s atienden a medias por 7 días (−8 reputación).", Lang.noun(D.PRODUCTS[d.product].name)), "bad"]


func _d_franquicia() -> Dictionary:
	var loc: Dictionary = _pick_loc()[0]
	var pname: String = Lang.noun(D.PRODUCTS[loc.product].name)
	var fee := 0.5 * _scale()
	return {"id": "franquicia", "title": "Quieren comprar una franquicia",
			"text": Lang.f("Un empresario de otra ciudad quiere abrir locales de %s con tu marca. Te paga %s por la franquicia y él pone todo lo demás. Nadie sabe qué tan bien los va a manejar.", [pname, Fmt.money(fee)]),
			"options": [_opt(Lang.f("Vender la franquicia (+%s)", Fmt.money(fee)), "Recibes el dinero hoy. 35%: atiende mal y tu marca sufre (−12 de reputación)."),
					_opt("No, la marca es solo mía", "Nada cambia.")],
			"data": {"product": loc.product, "fee": fee}}


func _r_franquicia(opt: int, d: Dictionary) -> Array:
	if opt == 1:
		return ["Rechazaste la franquicia. Tu marca sigue siendo solo tuya.", "info"]
	cash += d.fee
	ledger.ingresos += d.fee
	_pl(d.product).ingresos += d.fee
	_pl(d.product).contribucion += d.fee
	var bad := rng.randf() < 0.35
	if franchises_of(d.product).size() < int(D.FRANCHISE.max):   # queda en tu lista de franquicias y paga regalías
		var f := _new_franchise(d.product)
		if bad:
			f.quality = rng.randf_range(0.6, 0.75)
	if bad:
		_rep(d.product, -12)
		return [Lang.f("Cobraste %s, pero el franquiciado atiende pésimo y los clientes lo confunden contigo (−12 reputación).", Fmt.money(d.fee)), "bad"]
	return [Lang.f("¡Franquicia vendida por %s! Tu marca llega a otra ciudad y te paga regalías.", Fmt.money(d.fee)), "good"]


func _d_ciberataque() -> Dictionary:
	var ransom := 0.2 * _scale()
	return {"id": "ciberataque", "title": "Hackearon tus computadoras",
			"text": Lang.f("Un virus bloqueó las cajas y el sistema de inventario de todos tus locales. En la pantalla aparece un mensaje: pagas %s o borran todo.", Fmt.money(ransom)) if not investing() else Lang.f("Un virus bloqueó las cajas y el sistema de inventario de todos tus locales. En la pantalla aparece un mensaje: pagas %s en criptomonedas o borran todo.", Fmt.money(ransom)),
			"options": [_opt(Lang.f("Pagar el rescate (%s)", Fmt.money(ransom)), "Recuperas el sistema. 20%: igual filtran los datos de tus clientes (−10 de reputación en todo)."),
					_opt("No pagar y llamar a un técnico", Lang.f("50%%: el técnico lo arregla por %s. 50%%: pierdes 40%% del inventario y 3 días de ventas lentas.", Fmt.money(0.05 * _scale())))],
			"data": {"ransom": ransom, "tech": 0.05 * _scale()}}


func _r_ciberataque(opt: int, d: Dictionary) -> Array:
	if opt == 0:
		_spend(d.ransom, "corporativo")
		if rng.randf() < 0.2:
			for p in _active_products():
				_rep(p.key, -10)
			return ["Pagaste, pero los hackers igual publicaron los datos de tus clientes (−10 reputación).", "bad"]
		return ["Pagaste el rescate y el sistema volvió. Mejor no contarle a nadie.", "warn"]
	if rng.randf() < 0.5:
		_spend(d.tech, "corporativo")
		return [Lang.f("¡El técnico era un genio! Limpió el virus por %s y no perdiste nada.", Fmt.money(d.tech)), "good"]
	for p in _active_products():
		var lost: float = p.stock * 0.4
		p.stock -= lost
		ledger.mermas += lost * p.avg_cost
		_pl(p.key).contribucion -= lost * p.avg_cost
		p.demand_shock = min(p.demand_shock, 0.8)
		p.demand_shock_days = max(p.demand_shock_days, 3)
	return ["El virus borró todo: perdiste 40% del inventario y las cajas andan lentas por 3 días.", "bad"]


func _d_patrocinio() -> Dictionary:
	var k := _scale()
	return {"id": "patrocinio", "title": "El club del barrio busca auspiciador",
			"text": "Deportivo Las Lomas, el equipo de fútbol del barrio, está por jugar la final del campeonato regional y no tiene plata para camisetas. El presidente del club te pide ayuda.",
			"options": [_opt(Lang.f("Auspicio chico (%s)", Fmt.money(0.12 * k)), "Tu logo en la manga: +5 de reputación en todos tus negocios."),
					_opt(Lang.f("Auspicio grande (%s)", Fmt.money(0.3 * k)), "Tu logo en el pecho. 55%: ganan la final: +12 de reputación y +15% de demanda por 10 días. 45%: pierden: +3 de reputación."),
					_opt("No auspiciar", "No gastas nada. Algunos vecinos lo notan (−2 de reputación).")],
			"data": {"small": 0.12 * k, "big": 0.3 * k}}


func _r_patrocinio(opt: int, d: Dictionary) -> Array:
	var active := _active_products()
	if opt == 0:
		_spend(d.small, "marketing")
		for p in active:
			_rep(p.key, 5)
		return ["El equipo salió a la cancha con tu logo. El barrio te quiere un poco más (+5 reputación).", "good"]
	if opt == 2:
		for p in active:
			_rep(p.key, -2)
		return ["El club consiguió otro auspiciador. En el barrio comentan que no ayudaste (−2 reputación).", "warn"]
	_spend(d.big, "marketing")
	if rng.randf() < 0.55:
		for p in active:
			_rep(p.key, 12)
			p.demand_shock = max(p.demand_shock, 1.15)
			p.demand_shock_days = max(p.demand_shock_days, 10)
		return ["¡CAMPEONES! Tu logo salió en todas las fotos de la celebración: +12 reputación y +15% de demanda por 10 días.", "good"]
	for p in active:
		_rep(p.key, 3)
	return ["Perdieron la final por penales. Al menos el barrio agradece el apoyo (+3 reputación).", "warn"]


func _d_proveedor() -> Dictionary:
	var loc: Dictionary = _pick_loc()[0]
	var pname: String = Lang.noun(D.PRODUCTS[loc.product].name)
	return {"id": "proveedor", "title": "Un proveedor ofrece exclusividad",
			"text": Lang.f("Un distribuidor nuevo te ofrece la mercadería de %s 15%% más barata durante 60 días si le compras solo a él. Es una empresa chica y no tiene mucha experiencia.", pname),
			"options": [_opt("Firmar la exclusividad", "Tu costo unitario baja 15% por 60 días. 25%: no cumple una entrega: pierdes la mitad del inventario y −8 de reputación."),
					_opt("Seguir con tus proveedores de siempre", "Nada cambia.")],
			"data": {"product": loc.product}}


func _r_proveedor(opt: int, d: Dictionary) -> Array:
	if opt == 1:
		return ["Seguiste con tus proveedores de siempre.", "info"]
	var p: Dictionary = products[d.product]
	p.cost_shock = min(p.cost_shock, 0.85)
	p.cost_shock_days = max(p.cost_shock_days, 60)
	if rng.randf() < 0.25:
		var lost: float = p.stock * 0.5
		p.stock -= lost
		ledger.mermas += lost * p.avg_cost
		_pl(d.product).contribucion -= lost * p.avg_cost
		_rep(d.product, -8)
		return ["El proveedor nuevo falló la primera entrega: perdiste la mitad del inventario y hubo quejas (−8 reputación). Al menos el precio bajó 15%.", "bad"]
	return [Lang.f("Contrato firmado: tu mercadería de %s cuesta 15%% menos por 60 días.", Lang.noun(D.PRODUCTS[d.product].name)), "good"]


# ---------- personalizar los locales ----------
func decor_cost(loc: Dictionary, key: String) -> float:
	return D.upgrade_by_key(key).cost * D.UPGRADE_SIZE[loc.size] * price_index


func buy_decor(loc: Dictionary, key: String) -> Array:
	if key in loc.get("upgrades", []):
		return [false, "Ese local ya lo tiene."]
	var u := D.upgrade_by_key(key)
	if not int(loc.size) in u.get("sizes", [0, 1, 2]):
		return [false, "Eso no se puede poner en esta sucursal."]
	var cost := decor_cost(loc, key)
	if cash < cost:
		return [false, Lang.f("Necesitas %s en caja.", Fmt.money(cost))]
	cash -= cost
	var a := _add_asset(Lang.f("%s (sucursal #%d)", [u.name, int(loc.id)]), cost)
	loc.asset_ids.append(a.id)
	loc.invested += cost
	if not loc.has("upgrades"):
		loc["upgrades"] = []
	loc.upgrades.append(key)
	return [true, Lang.f("Instalaste %s.", Lang.noun(u.name))]


# ---------- paneles solares de la fábrica ----------
const SOLAR_COST := 0.3      # sobre el costo de la fábrica
const SOLAR_UPKEEP := 0.4    # el mantenimiento de la fábrica queda en 40% (la luz es gratis)
const SOLAR_SAVING := 0.05   # y el costo unitario baja otro 5%


func solar_cost(key: String) -> float:
	return factory_cost(key) * SOLAR_COST


func build_solar(key: String) -> Array:
	var p: Dictionary = products[key]
	if not p.factory:
		return [false, "Primero necesitas la fábrica."]
	if p.get("solar", false):
		return [false, "La fábrica ya tiene paneles solares."]
	var cost := solar_cost(key)
	if cash < cost:
		return [false, Lang.f("Necesitas %s en caja.", Fmt.money(cost))]
	cash -= cost
	_add_asset(Lang.f("Paneles solares: fábrica de %s", Lang.noun(D.PRODUCTS[key].name)), cost)
	p.solar = true
	_rep(key, 4)
	add_news(Lang.f("Tu fábrica de %s ahora funciona con paneles solares: menos gastos y +4 de reputación por ser verde.", Lang.noun(D.PRODUCTS[key].name)), "good")
	return [true, "Paneles solares instalados."]


func factory_upkeep_monthly(p: Dictionary) -> float:
	return p.factory_value * D.FACTORY_UPKEEP * (SOLAR_UPKEEP if p.get("solar", false) else 1.0)


# ---------- trato al personal ----------
func set_labor(i: int) -> Array:
	i = clampi(i, 0, D.LABOR.size() - 1)
	if i == labor:
		return [true, ""]
	var worse := i > labor
	labor = i
	var l: Dictionary = D.LABOR[i]
	add_news(Lang.f("Nueva política con tus empleados: %s.", Lang.noun(l.name)), "warn" if worse else "info")
	return [true, Lang.f("Política de personal: %s.", l.name)]


func staff_count() -> int:
	var n := 0
	for l in locations:
		n += int(l.employees)
	return n


## Una vez al día: el ánimo va hacia lo que merece tu trato; con ánimo bajo la gente renuncia.
func _staff_day() -> void:
	var target: float = D.LABOR[labor].morale
	morale = clampf(morale + (target - morale) * 0.03, 0.0, 100.0)
	if locations.is_empty() or morale >= 35:
		return
	var chance := (35.0 - morale) / 35.0 * 0.05
	if rng.randf() < chance:
		var with := locations.filter(func(l): return l.employees > 1 or (l.employees == 1 and not products[l.product].manager))
		if with:
			var loc: Dictionary = pick(with)
			loc.employees -= 1
			var lines := ["«No aguanto más, me voy.»", "«Aquí nadie me respeta. Renuncio.»", "«Con este sueldo prefiero vender en la calle.»",
					"«Me voy con la competencia: allá por lo menos me pagan las horas extra.»"]
			add_news(Lang.f("Renunció un empleado de tu %s de %s: %s", [Lang.noun(D.SIZES[loc.size].name), Lang.noun(D.PRODUCTS[loc.product].name), Lang.t(pick(lines))]),
					"bad", "staff_quit", loc.id)


## Una vez al mes: lo que pasa por cómo tratas a la gente (inspecciones, videos virales, premios).
func _staff_month() -> void:
	if locations.is_empty():
		return
	var active := _active_products()
	var k := _scale()
	var key: String = D.LABOR[labor].key
	if key in ["exigente", "explotador"] and rng.randf() < (0.3 if key == "explotador" else 0.1):
		var fine := (0.35 if key == "explotador" else 0.15) * k
		_spend(fine, "multas")
		for p in active:
			_rep(p.key, -6 if key == "explotador" else -3)
		add_news(Lang.f("Inspección del trabajo: encontraron horas extra sin pagar%s. Multa de %s.", [" y sueldos bajo el mínimo" if key == "explotador" else "", Fmt.money(fine)]), "bad", "danger_soft")
	elif key == "explotador" and rng.randf() < 0.2:
		for p in active:
			_rep(p.key, -12)
			p.awareness = min(1.0, p.awareness + 0.04)
		add_news("¡Video viral! Un empleado grabó a un supervisor gritándole a una cajera. Todos hablan de tu marca... y no bien (−12 reputación).", "bad")
	elif morale > 75 and rng.randf() < 0.12:
		for p in active:
			_rep(p.key, 5)
			p.awareness = min(1.0, p.awareness + 0.03)
		add_news("Premio «Mejor lugar para trabajar» de la ciudad: tu marca gana prestigio (+5 reputación).", "good")


# ---------- rivales con vida propia ----------
func _init_rivals() -> void:
	for r in D.RIVALS:
		if not rivals.has(r.key):
			rivals[r.key] = {"hostility": 25.0, "ally_until": 0, "war_until": 0, "last_move": 0}


## El rival está en juego: sus mercados están desbloqueados (los tiburones aparecen desde su día "from").
func rival_active(r: Dictionary) -> bool:
	if day < int(r.get("from", 0)):
		return false
	var markets: Array = r.products if r.products else r.get("needs", D.PRODUCT_ORDER)
	for k in markets:
		if products[k].unlocked:
			return true
	return false


## Mercados donde ese rival te ataca (los tuyos que están abiertos).
func rival_markets(r: Dictionary) -> Array:
	var markets: Array = r.products if r.products else r.get("needs", D.PRODUCT_ORDER)
	return markets.filter(func(k): return products[k].unlocked and not locs(k).is_empty())


func rival_state(key: String) -> Dictionary:
	_init_rivals()
	return rivals[key]


func hostility(key: String, delta: float) -> void:
	var st := rival_state(key)
	st.hostility = clampf(float(st.hostility) + delta, 0.0, 100.0)


func allied(key: String) -> bool:
	return int(rival_state(key).ally_until) > day


## Lo que vale el negocio del rival en la ciudad: crece con los años, la economía y los locales que tiene.
func rival_value(r: Dictionary) -> float:
	var n := 0
	for k in (r.products if r.products else []):
		n += int(products[k].competitors)
	for i in plot_owner:
		if plot_owner[i] == r.key:
			n += 2
	var years := day / 360.0
	return float(r.value) * price_index * econ_index * (1.0 + 0.12 * years) * (0.8 + 0.05 * n)


## Ranking de la ciudad: tú y los rivales que ya están en juego, del que vale más al que vale menos.
## Cada fila: [clave ("" = tú), nombre, empresa, valor, color].
func ranking() -> Array:
	var rows := [["", company, company, valuation(), ImUI.COL.accent]]
	for r in D.RIVALS:
		if rival_active(r):
			rows.append([r.key, r.name, r.company, rival_value(r), r.color])
	rows.sort_custom(func(a, b): return a[3] > b[3])
	return rows


func _rival_ranks() -> void:
	var v := valuation()
	for r in D.RIVALS:
		if rival_active(r) and not (r.key in passed) and v > rival_value(r):
			passed.append(r.key)
			add_news(Lang.f("¡Superaste a %s en el ranking de la ciudad!", r.company), "good", "passed", r.key)
			rival_say(r, "passed")


## Una vez al día: los rivales hacen sus jugadas según su estilo y cuánto te odian (las alianzas los calman).
func _rival_ai() -> void:
	for k in D.PRODUCT_ORDER:
		var p: Dictionary = products[k]
		if int(p.get("war_days", 0)) > 0:
			p.war_days = int(p.war_days) - 1
	if locations.is_empty() or day < 60:
		return
	for r in D.RIVALS:
		var st := rival_state(r.key)
		st.hostility = float(st.hostility) + (25.0 - float(st.hostility)) * 0.004   # el enojo se pasa con el tiempo
		if not rival_active(r) or allied(r.key) or day - int(st.last_move) < 25:
			continue
		var markets := rival_markets(r)
		if markets.is_empty():
			continue
		if rng.randf() > (0.02 + 0.05 * float(st.hostility) / 100.0):
			continue
		st.last_move = day
		_rival_move(r, pick(markets))
		return   # una jugada por día como máximo


func _rival_move(r: Dictionary, key: String) -> void:
	var p: Dictionary = products[key]
	var name: String = Lang.noun(D.PRODUCTS[key].name)
	match r.style:
		"expansion":
			var last = history[-1].productos.get(key) if history else null
			if last != null and last.contribucion > 0 and p.competitors < D.PRODUCTS[key].competitors + 3:
				p.competitors += 1
				add_news(Lang.f("%s abrió otro local de %s en la ciudad.", [r.company, name]), "bad")
			else:   # si tu negocio no deja plata no vale la pena abrir: te pelea con promociones
				p.war_days = 10
				add_news(Lang.f("%s lanzó promociones de %s: tu demanda baja 12%% por 10 días.", [r.company, name]), "bad")
			rival_say(r, "war", {"p": name})
		"precios", "copia", "premium", "online":
			p.war_days = 20
			var what := {"precios": "bajó sus precios de %s", "copia": "copió tus productos de %s y los vende más baratos",
					"premium": "lanzó un modelo nuevo y le quita clientes a tu %s", "online": "vende %s por internet con envío gratis"}
			add_news(Lang.f("%s %s: tu demanda baja 12%% por 20 días.", [r.company, Lang.f(what[r.style], name)]), "bad")
			rival_say(r, "war", {"p": name})
			if micro == null:
				micro = _micro_rival_war(r, key)
		"publicidad":
			p.awareness = max(0.0, p.awareness - 0.08)
			p.war_days = 10
			add_news(Lang.f("Campaña gigante de %s: la gente se olvida un poco de tu marca de %s.", [r.company, name]), "bad")
			rival_say(r, "war", {"p": name})
		"terrenos":
			var free := free_plots()
			if rng.randf() < 0.5 and free.size() > 3 and rival_plots.size() < D.RIVAL_PLOT_MAX:
				var plot: int = pick(free)
				_rival_takes(key, plot)
				plot_owner[str(plot)] = r.key
				add_news(Lang.f("%s compró el terreno %d y abrió un local de %s.", [r.company, plot + 1, name]), "bad")
				rival_say(r, "entry", {"p": name})
			elif micro == null:
				micro = _micro_lawsuit(r)
		"caos":
			if rng.randf() < 0.5:
				var up := rng.randf() < 0.5
				p.demand_shock = 1.3 if up else 0.75
				p.demand_shock_days = 5
				add_news(Lang.f("%s tuiteó sobre tu %s: %s", [r.name, name, "¡las ventas se disparan 30% por 5 días!" if up else "tus ventas caen 25% por 5 días."]), "good" if up else "bad")
				rival_say(r, "war", {"p": name})
			elif micro == null:
				micro = _micro_poach(r, key)


## Acciones del jugador con un rival (catálogo de rivales).
func alliance_cost(key: String) -> float:
	return max(3000.0 * price_index, 0.15 * _scale()) * (1.0 + float(rival_state(key).hostility) / 100.0)


func alliance_chance(key: String) -> float:
	return clampf(0.85 - float(rival_state(key).hostility) / 110.0, 0.05, 0.85)


## Cena de negocios: si acepta, no te ataca por 90 días y termina su guerra contigo. Si no, se ríe en tu cara.
func propose_alliance(key: String) -> Array:
	var r := D.rival_by_key(key)
	if allied(key):
		return [false, Lang.f("Ya tienes una alianza con %s.", r.company)]
	var cost := alliance_cost(key)
	if cash < cost:
		return [false, Lang.f("Necesitas %s en caja.", Fmt.money(cost))]
	_spend(cost, "corporativo")
	if rng.randf() < alliance_chance(key):
		var st := rival_state(key)
		st.ally_until = day + 90
		hostility(key, -30)
		for k in (r.products if r.products else D.PRODUCT_ORDER):
			products[k].war_days = 0
		add_news(Lang.f("Alianza con %s: no se atacan durante 90 días.", r.company), "good")
		return [true, Lang.f("%s aceptó la alianza por 90 días.", r.company)]
	hostility(key, 8)
	add_news(Lang.f("%s rechazó tu propuesta de alianza (y la cena la pagaste tú).", r.company), "bad")
	return [false, Lang.f("%s dijo que no. Perdiste %s en la cena.", [r.company, Fmt.money(cost)])]


func provoke_cost() -> float:
	return max(2000.0 * price_index, 0.08 * _scale())


## Publicidad comparativa contra un rival: +20% de demanda por 15 días en sus mercados, pero se enoja mucho.
func provoke(key: String) -> Array:
	var r := D.rival_by_key(key)
	var markets := rival_markets(r)
	if markets.is_empty():
		return [false, "No compites con ese rival todavía."]
	var cost := provoke_cost()
	if cash < cost:
		return [false, Lang.f("Necesitas %s en caja.", Fmt.money(cost))]
	_spend(cost, "marketing")
	for k in markets:
		var p: Dictionary = products[k]
		p.demand_shock = max(p.demand_shock, 1.2)
		p.demand_shock_days = max(p.demand_shock_days, 15)
	hostility(key, 25)
	rival_state(key).ally_until = 0
	add_news(Lang.f("Campaña comparativa contra %s: «Lo mismo, pero mejor». +20%% de demanda por 15 días.", r.company), "good")
	rival_say(r, "taunt")
	return [true, Lang.f("Lanzaste la campaña contra %s.", r.company)]


# ---------- microdecisiones: preguntas chicas que no pausan el juego ----------
const MICRO_DAYS := 4   # días para responder; después pasa sola la opción por defecto
const MICROS := ["descuento", "tarde", "donar", "resena", "proveedor_nuevo", "vecino", "cumple", "paraguas", "fila"]


func _maybe_micro() -> void:
	if micro != null:
		if day >= int(micro.expires):
			var d: int = int(micro.get("default", micro.options.size() - 1))
			var res := resolve_micro(d, true)
			add_news(Lang.f("No respondiste a tiempo: %s", res[1]), "info", "quiet")
		return
	if pending_choice != null or day < next_micro_day or locations.is_empty():
		return
	next_micro_day = day + rng.randi_range(5, 10)
	var options := MICROS.duplicate()
	if not (weather in [3, 5]):
		options.erase("paraguas")
	var perishable := _active_products().filter(func(p): return D.PRODUCTS[p.key].spoil >= 0.04 and p.stock > 5)
	if perishable.is_empty():
		options.erase("donar")
	micro = build_micro(pick(options))


func build_micro(id: String) -> Dictionary:
	var m: Dictionary = call("_m_" + id)
	m["id"] = id
	m["expires"] = day + MICRO_DAYS
	if not m.has("default"):
		m["default"] = m.options.size() - 1
	return m


func resolve_micro(option: int, timed_out := false) -> Array:
	var m = micro
	if m == null:
		return [false, ""]
	micro = null
	option = clampi(option, 0, m.options.size() - 1)
	var res: Array = call("_mr_" + m.id, option, m.data)
	if not timed_out:
		add_news(res[0], res[1], "quiet")
	return [res[1] in ["good", "info"], res[0]]


func _loc_name(loc: Dictionary) -> String:
	return Lang.f("%s de %s", [Lang.noun(D.SIZES[loc.size].name), Lang.noun(D.PRODUCTS[loc.product].name)])


func _m_descuento() -> Dictionary:
	var loc: Dictionary = pick(locations)
	var cost := 0.004 * _scale()
	return {"title": "Un cliente fiel pide descuento",
			"text": Lang.f("Don Raúl compra en tu %s todos los días. Hoy te pide un descuento «por fidelidad».", _loc_name(loc)),
			"options": [_opt(Lang.f("Darle 10%% (−%s)", Fmt.money(cost)), "Se va feliz y lo cuenta en el barrio (+1 reputación)."),
					_opt("No, el precio es el precio", "No pasa nada. Quizás compre un poco menos.")],
			"data": {"product": loc.product, "cost": cost}}


func _mr_descuento(opt: int, d: Dictionary) -> Array:
	if opt == 0:
		_spend(d.cost, "marketing", d.product)
		_rep(d.product, 1)
		return ["Don Raúl se fue feliz con su descuento (+1 reputación).", "good"]
	return ["Don Raúl pagó el precio completo, con cara de pocos amigos.", "info"]


func _m_tarde() -> Dictionary:
	var loc: Dictionary = pick(locations)
	return {"title": "Un empleado llegó tarde",
			"text": Lang.f("Matías, de tu %s, llegó una hora tarde: el bus se quedó en pana. Te mira esperando el reto.", _loc_name(loc)),
			"options": [_opt("Dejarlo pasar", "Le das las gracias por avisar (+2 de ánimo del equipo)."),
					_opt("Gritarle delante de todos", "Que aprendan todos. El equipo lo nota (−6 de ánimo)."),
					_opt("Descontarle el día completo", "Ahorras un día de sueldo, aunque trabajó 7 horas (−4 de ánimo).")],
			"data": {"product": loc.product}, "default": 0}


func _mr_tarde(opt: int, d: Dictionary) -> Array:
	if opt == 0:
		morale = min(100.0, morale + 2)
		return ["Matías te agradece y se queda una hora más por su cuenta (+2 ánimo).", "good"]
	if opt == 1:
		morale = max(0.0, morale - 6)
		return ["Le gritaste a Matías frente a todos. Nadie dice nada, pero el ambiente se enfría (−6 ánimo).", "warn"]
	var saved := wage_daily()
	cash += saved
	ledger.salarios -= saved
	morale = max(0.0, morale - 4)
	return [Lang.f("Le descontaste el día a Matías (ahorras %s). Él ya está buscando otro trabajo (−4 ánimo).", Fmt.money(saved)), "warn"]


func _m_donar() -> Dictionary:
	var ps := _active_products().filter(func(p): return D.PRODUCTS[p.key].spoil >= 0.04 and p.stock > 5)
	var p: Dictionary = pick(ps) if ps else pick(_active_products())
	var name: String = Lang.noun(D.PRODUCTS[p.key].name)
	return {"title": "Sobró mercadería",
			"text": Lang.f("Al cierre sobró %s que mañana ya no se puede vender. El comedor del barrio pregunta si se lo puedes donar.", name),
			"options": [_opt("Donarlo al comedor", "Pierdes 10% del inventario, pero el barrio te quiere más (+3 reputación)."),
					_opt("Botarlo", "Va a la basura igual. Nadie se entera.")],
			"data": {"product": p.key}}


func _mr_donar(opt: int, d: Dictionary) -> Array:
	if opt == 1:
		return ["La mercadería que sobró terminó en la basura.", "info"]
	var p: Dictionary = products[d.product]
	var lost: float = p.stock * 0.1
	p.stock -= lost
	ledger.mermas += lost * p.avg_cost
	_pl(d.product).contribucion -= lost * p.avg_cost
	_rep(d.product, 3)
	return ["El comedor del barrio te agradeció en redes sociales (+3 reputación).", "good"]


func _m_resena() -> Dictionary:
	var loc: Dictionary = pick(locations)
	return {"title": "Una reseña de 1 estrella",
			"text": Lang.f("«Pésimo. Me atendieron con cara de sueño.» Alguien calificó tu %s con 1 estrella en internet.", _loc_name(loc)),
			"options": [_opt("Responder con amabilidad", "Pides disculpas y lo invitas a volver (+0,15 estrellas al local)."),
					_opt("Responder furioso", "50%: tu respuesta se hace viral y queda mal (−4 reputación). 50%: a la gente le da risa (+conocimiento de marca)."),
					_opt("Ignorarla", "La reseña queda ahí (−0,1 estrellas al local).")],
			"data": {"loc_id": loc.id, "product": loc.product}}


func _mr_resena(opt: int, d: Dictionary) -> Array:
	var loc = find_location(d.loc_id)
	if opt == 0:
		if loc != null:
			loc.stars = min(5.0, stars_of(loc) + 0.15)
		return ["Respondiste con amabilidad. El cliente cambió su reseña a 4 estrellas.", "good"]
	if opt == 1:
		if rng.randf() < 0.5:
			_rep(d.product, -4)
			return ["Tu respuesta furiosa salió en todas las redes. Quedaste como un gruñón (−4 reputación).", "bad"]
		var p: Dictionary = products[d.product]
		p.awareness = min(1.0, p.awareness + 0.05)
		return ["¡Tu respuesta furiosa se hizo meme! Más gente conoce tu marca.", "good"]
	if loc != null:
		loc.stars = max(1.0, stars_of(loc) - 0.1)
	return ["La reseña de 1 estrella sigue ahí, a la vista de todos.", "warn"]


func _m_proveedor_nuevo() -> Dictionary:
	var p: Dictionary = pick(_active_products())
	var cost := 0.01 * _scale()
	var name: String = Lang.noun(D.PRODUCTS[p.key].name)
	return {"title": "Una receta nueva",
			"text": Lang.f("Tu proveedor trajo una versión nueva de %s para probar. La prueba en tus locales cuesta %s.", [name, Fmt.money(cost)]),
			"options": [_opt(Lang.f("Probarla (%s)", Fmt.money(cost)), "60%: a los clientes les encanta (+10% de demanda por 10 días). 40%: no cambia nada."),
					_opt("No, gracias", "Sigues con lo de siempre.")],
			"data": {"product": p.key, "cost": cost}}


func _mr_proveedor_nuevo(opt: int, d: Dictionary) -> Array:
	if opt == 1:
		return ["Seguiste con la receta de siempre.", "info"]
	_spend(d.cost, "marketing", d.product)
	if rng.randf() < 0.6:
		var p: Dictionary = products[d.product]
		p.demand_shock = max(p.demand_shock, 1.1)
		p.demand_shock_days = max(p.demand_shock_days, 10)
		return ["¡La receta nueva fue un éxito! +10% de demanda por 10 días.", "good"]
	return ["La receta nueva pasó sin pena ni gloria.", "warn"]


func _m_vecino() -> Dictionary:
	var loc: Dictionary = pick(locations)
	var cost := 0.006 * _scale()
	return {"title": "Un vecino reclama",
			"text": Lang.f("La señora del frente dice que tu %s hace mucho ruido en la mañana y que va a llamar a la municipalidad.", _loc_name(loc)),
			"options": [_opt(Lang.f("Regalarle una canasta (%s)", Fmt.money(cost)), "Se le pasa el enojo."),
					_opt("Ignorarla", "30%: llega un inspector municipal con una multa.")],
			"data": {"product": loc.product, "cost": cost, "fine": 0.04 * _scale()}}


func _mr_vecino(opt: int, d: Dictionary) -> Array:
	if opt == 0:
		_spend(d.cost, "marketing", d.product)
		return ["La vecina aceptó la canasta y ahora te saluda.", "good"]
	if rng.randf() < 0.3:
		_spend(d.fine, "multas", d.product)
		return [Lang.f("La vecina cumplió: llegó un inspector con una multa de %s.", Fmt.money(d.fine)), "bad"]
	return ["La vecina siguió reclamando, pero no pasó nada.", "info"]


func _m_cumple() -> Dictionary:
	var cost := 0.003 * _scale()
	return {"title": "Cumpleaños en el equipo",
			"text": "Hoy cumple años Rosa, la cajera más antigua. El resto del equipo pregunta si la empresa pone la torta.",
			"options": [_opt(Lang.f("Comprar la torta (%s)", Fmt.money(cost)), "El equipo celebra (+5 de ánimo)."),
					_opt("Que la paguen ellos", "Se nota (−2 de ánimo).")],
			"data": {"cost": cost}}


func _mr_cumple(opt: int, d: Dictionary) -> Array:
	if opt == 0:
		_spend(d.cost, "salarios")
		morale = min(100.0, morale + 5)
		return ["¡Cantaron el cumpleaños y Rosa se emocionó! (+5 ánimo)", "good"]
	morale = max(0.0, morale - 2)
	return ["El equipo juntó plata para la torta. Nadie te invitó (−2 ánimo).", "warn"]


func _m_paraguas() -> Dictionary:
	var cost := 0.015 * _scale()
	return {"title": "Llueve a cántaros",
			"text": "La gente corre bajo la lluvia frente a tus locales. ¿Regalas paraguas con tu logo?",
			"options": [_opt(Lang.f("Regalar paraguas (%s)", Fmt.money(cost)), "Tu logo pasea por toda la ciudad (+5% de conocimiento de marca)."),
					_opt("No", "Cada uno se moja como puede.")],
			"data": {"cost": cost}}


func _mr_paraguas(opt: int, d: Dictionary) -> Array:
	if opt == 1:
		return ["No regalaste paraguas.", "info"]
	_spend(d.cost, "marketing")
	for p in _active_products():
		p.awareness = min(1.0, p.awareness + 0.05)
	return ["Tu logo se ve en paraguas por toda la ciudad.", "good"]


func _m_fila() -> Dictionary:
	var loc: Dictionary = locations[0]
	for l in locations:
		if l.demand - l.capacity > loc.demand - loc.capacity:
			loc = l
	var cost := 0.02 * _scale()
	return {"title": "Fila larguísima",
			"text": Lang.f("Tu %s está lleno y la gente se aburre de esperar. Faltan manos.", _loc_name(loc)),
			"options": [_opt(Lang.f("Horas extra pagadas (%s)", Fmt.money(cost)), "Tus locales de ese negocio atienden 20% más por 5 días."),
					_opt("Obligarlos a quedarse sin pagarles", "Atienden 20% más por 5 días, gratis... y el equipo lo recuerda (−8 de ánimo)."),
					_opt("Que esperen", "Algunos clientes se van.")],
			"data": {"product": loc.product, "cost": cost}}


func _mr_fila(opt: int, d: Dictionary) -> Array:
	if opt == 2:
		return ["La fila siguió larga y algunos clientes se fueron.", "info"]
	var p: Dictionary = products[d.product]
	p.cap_boost = 1.2
	p.cap_boost_days = 5
	if opt == 0:
		_spend(d.cost, "salarios", d.product)
		return ["Pagaste horas extra: la fila avanza más rápido por 5 días.", "good"]
	morale = max(0.0, morale - 8)
	return ["Los obligaste a quedarse sin pagarles. La fila avanza, pero el equipo está furioso (−8 ánimo).", "warn"]


## Microdecisiones que lanzan los rivales (ver _rival_move).
func _micro_rival_war(r: Dictionary, key: String) -> Dictionary:
	var name: String = Lang.noun(D.PRODUCTS[key].name)
	return {"id": "guerra", "expires": day + MICRO_DAYS, "default": 1, "rival": r.key,
			"title": Lang.f("%s te declaró la guerra", r.company),
			"text": Lang.f("%s le quita clientes a tu %s. ¿Respondes?", [r.short, name]),
			"options": [_opt("Bajar tu precio 8%", "La guerra termina en 5 días, pero ganas menos por unidad."),
					_opt("Aguantar", "Tu demanda sigue 12% más baja los 20 días.")],
			"data": {"product": key, "rival": r.key}}


func _mr_guerra(opt: int, d: Dictionary) -> Array:
	var p: Dictionary = products[d.product]
	if opt == 0:
		p.price *= 0.92
		p.war_days = min(int(p.war_days), 5)
		hostility(d.rival, 5)
		return [Lang.f("Bajaste el precio de %s 8%%: %s se rinde pronto.", [Lang.noun(D.PRODUCTS[d.product].name), D.rival_by_key(d.rival).short]), "good"]
	return ["Aguantaste el ataque sin bajar precios.", "info"]


func _micro_poach(r: Dictionary, key: String) -> Dictionary:
	var cost := 0.03 * _scale()
	return {"id": "robo", "expires": day + MICRO_DAYS, "default": 1, "rival": r.key,
			"title": Lang.f("%s quiere llevarse a tu mejor empleado", r.short),
			"text": Lang.f("%s le ofreció el doble de sueldo a tu encargado de %s.", [r.name, Lang.noun(D.PRODUCTS[key].name)]),
			"options": [_opt(Lang.f("Contraoferta (%s)", Fmt.money(cost)), "Se queda y el equipo ve que lo valoras (+3 de ánimo)."),
					_opt("Dejarlo ir", "Pierdes un empleado en ese negocio.")],
			"data": {"product": key, "cost": cost, "rival": r.key}}


func _mr_robo(opt: int, d: Dictionary) -> Array:
	if opt == 0:
		_spend(d.cost, "salarios", d.product)
		morale = min(100.0, morale + 3)
		return ["Tu encargado se quedó contigo (+3 ánimo).", "good"]
	var ls := locs(d.product).filter(func(l): return l.employees > 0)
	if ls:
		var loc: Dictionary = pick(ls)
		loc.employees -= 1
	return [Lang.f("Tu encargado se fue con %s.", D.rival_by_key(d.rival).company), "bad"]


func _micro_lawsuit(r: Dictionary) -> Dictionary:
	var k := _scale()
	return {"id": "demanda_rival", "expires": day + MICRO_DAYS, "default": 1, "rival": r.key,
			"title": Lang.f("%s te amenaza con una demanda", r.short),
			"text": Lang.f("«Tu letrero se parece al mío. Es un robo. Te voy a demandar», dice %s.", r.name),
			"options": [_opt(Lang.f("Pagarle para que se calle (%s)", Fmt.money(0.06 * k)), "Se olvida del tema."),
					_opt("Que demande", Lang.f("60%%: el juez te da la razón. 40%%: pierdes y pagas %s.", Fmt.money(0.2 * k)))],
			"data": {"pay": 0.06 * k, "lose": 0.2 * k, "rival": r.key}}


func _mr_demanda_rival(opt: int, d: Dictionary) -> Array:
	var r := D.rival_by_key(d.rival)
	if opt == 0:
		_spend(d.pay, "multas")
		hostility(d.rival, -5)
		return [Lang.f("Le pagaste a %s y retiró la demanda.", r.short), "info"]
	if rng.randf() < 0.6:
		hostility(d.rival, 5)
		return [Lang.f("¡Ganaste! El juez dijo que la demanda de %s no tenía sentido.", r.short), "good"]
	_spend(d.lose, "multas")
	return [Lang.f("Perdiste el juicio contra %s: pagas %s.", [r.short, Fmt.money(d.lose)]), "bad"]


# ---------- dilema: una fábrica en venta ----------
## Negocios sin fábrica cuya fábrica usada (55% del precio) puedes pagar con lo que tienes en caja.
func _factory_offer_keys() -> Array:
	return _active_products().filter(func(p): return not p.factory and cash >= factory_cost(p.key) * 0.75).map(func(p): return p.key)


func _d_fabrica() -> Dictionary:
	var keys := _factory_offer_keys()
	if keys.is_empty():
		keys = _active_products().filter(func(p): return not p.factory).map(func(p): return p.key)
	var key: String = pick(keys) if keys else "cafe"
	var price := factory_cost(key) * 0.55
	var name: String = Lang.noun(D.PRODUCTS[key].name)
	return {"id": "fabrica", "title": Lang.f("Se vende una fábrica de %s", name),
			"text": Lang.f("Una empresa que cierra vende su fábrica de %s por %s, casi la mitad de lo que cuesta construir una (%s). Con fábrica propia tu costo unitario baja 30%%. Dicen que las máquinas están bien... dicen.", [name, Fmt.money(price), Fmt.money(factory_cost(key))]),
			"options": [_opt(Lang.f("Sí, comprarla (%s)", Fmt.money(price)), Lang.f("Fábrica propia desde hoy. 25%%: hay que reparar las máquinas (%s más).", Fmt.money(factory_cost(key) * 0.15))),
					_opt("No", "Puedes construir una nueva cuando quieras en Negocios.")],
			"data": {"product": key, "price": price, "repair": factory_cost(key) * 0.15}}


func _r_fabrica(opt: int, d: Dictionary) -> Array:
	var p: Dictionary = products[d.product]
	if opt == 1 or p.factory:
		return ["No compraste la fábrica.", "info"]
	cash -= d.price
	_add_asset(Lang.f("Fábrica de %s (usada)", Lang.noun(D.PRODUCTS[d.product].name)), d.price)
	p.factory = true
	p.factory_value = d.price
	if rng.randf() < 0.25:
		_spend(d.repair, "fabricas", d.product)
		return [Lang.f("Compraste la fábrica, pero las máquinas venían malas: reparación de %s.", Fmt.money(d.repair)), "warn"]
	return ["¡Fábrica comprada a mitad de precio! Tu costo unitario baja 30%.", "good"]


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
	if not state.has("office_look"):   # partidas de antes: la oficina que ya tenían
		g.office_look = 2
	g.office_look = int(g.office_look)
	g.rng.seed = String(state.get("rng_seed", "0")).to_int()
	g.rng.state = String(state.get("rng_state", "0")).to_int()
	g._fix_types()
	return g


const INT_KEYS := ["day", "next_id", "phase_months_left", "overdraft_days", "rank", "next_choice_day",
		"profit_streak", "last_record_day", "hq_level", "strategy_ready_day", "weather", "weather_next", "weather_days",
		"beach_boost_days", "labor", "next_micro_day"]


## JSON guarda todos los números como decimales: los que son índices o contadores vuelven a ser enteros.
func _fix_types() -> void:
	for p in products.values():
		for k in ["solar", "war_days", "cap_boost", "cap_boost_days"]:   # partidas de antes de estos campos
			if not p.has(k):
				p[k] = make_product(p.key)[k]
		for k in ["quality", "stock_days", "competitors", "cost_shock_days", "demand_shock_days", "war_days", "cap_boost_days"]:
			p[k] = int(p[k])
	for loc in locations:
		if not loc.has("upgrades"):
			loc["upgrades"] = []
		# La música y el wifi ya no se venden: se quitan de las partidas viejas
		loc.upgrades = loc.upgrades.filter(func(k): return D.UPGRADES.any(func(u): return u.key == k))
		var sz := int(loc.size)
		loc.upgrades = loc.upgrades.map(func(k): return D.upgrade_for_size(k, sz))   # aire de un puesto -> ventilador
		for k in ["id", "size", "employees"]:
			loc[k] = int(loc[k])
		loc["stars"] = float(loc.get("stars", 3.0))
		if loc.get("plot") != null:
			loc.plot = int(loc.plot)
		loc["mall"] = null if loc.get("mall") == null else int(loc.mall)
		if loc.mall != null:
			rival_mall.erase(str(loc.mall))
		loc.asset_ids = loc.asset_ids.map(func(i): return int(i))
	for l in loans:
		l.id = int(l.id)
		l.months_left = int(l.months_left)
	for a in assets:
		a.id = int(a.id)
	if micro != null:
		micro.expires = int(micro.expires)
	for f in franchises:
		f.id = int(f.id)
		f.day = int(f.day)
	_place_homeless()
	if not investing() and bonds + fund > 0:   # partidas normales de antes: lo que había en bonos y en la bolsa vuelve a la caja
		cash += bonds + fund
		bonds = 0.0
		fund = 0.0
	_init_rivals()
	for k in rivals:
		for f in ["ally_until", "war_until", "last_move"]:
			rivals[k][f] = int(rivals[k][f])


# ---------- decisiones importantes: dos veces por partida, cambian el resto del juego ----------
# 1) Al llegar a Pequeño empresario: el rumbo de la marca (premium o precios bajos).
# 2) Al llegar a Empresario: qué hacer con la competencia (aliarse o guerra).
# Se guardan en `path` y no se pueden cambiar después.
const KEY_DECISIONS := [["rumbo", 2], ["rivales", 3]]   # [id, rango desde el que se pide]


## La decisión importante que toca y todavía no tomaste ("" si ninguna).
func key_decision_due() -> String:
	for kd in KEY_DECISIONS:
		if rank >= int(kd[1]) and not path.has(kd[0]):
			return kd[0]
	return ""


## Multiplicadores del rumbo elegido: demanda, sensibilidad al precio y costo unitario.
func path_demand() -> float:
	match path.get("rumbo", ""):
		"premium":
			return 0.88
		"masivo":
			return 1.22
	return 1.0


func path_elasticity() -> float:
	return 0.72 if path.get("rumbo", "") == "premium" else 1.0


func path_cost() -> float:
	return 0.9 if path.get("rumbo", "") == "masivo" else 1.0


func _d_rumbo() -> Dictionary:
	return {"id": "rumbo", "title": "El rumbo de tu marca", "key": true,
			"text": "Tu empresa creció. Elige qué marca quieres ser.",
			"options": [_opt("Marca premium", "12% menos clientes, pero aguantan precios mucho más altos sin irse. +15 de reputación."),
					_opt("Precios bajos para todos", "22% más clientes y 10% más barato comprarle al proveedor, pero −8 de reputación.")],
			"data": {}}


func _r_rumbo(opt: int, _d: Dictionary) -> Array:
	path["rumbo"] = "premium" if opt == 0 else "masivo"
	for k in products:
		_rep(k, 15.0 if opt == 0 else -8.0)
	if opt == 0:
		return ["Tu marca ahora es premium: menos clientes, pero pagan más.", "good"]
	return ["Tu marca ahora es de precios bajos: llega mucha más gente.", "good"]


func _d_rivales() -> Dictionary:
	return {"id": "rivales", "title": "Qué hacer con la competencia", "key": true,
			"text": "Los grandes rivales te tomaron en serio. Te proponen una alianza... o puedes declararles la guerra.",
			"options": [_opt("Aliarte con ellos", "Nunca más te atacan y hay un competidor menos en cada negocio, pero le das 6% de tus ventas a la alianza."),
					_opt("Guerra total", "Comprar sus locales cuesta 35% menos, pero se enojan mucho y te atacan más seguido.")],
			"data": {}}


func _r_rivales(opt: int, _d: Dictionary) -> Array:
	path["rivales"] = "alianza" if opt == 0 else "guerra"
	for r in D.RIVALS:
		var st := rival_state(r.key)
		if opt == 0:
			st.ally_until = 1 << 30
			st.hostility = 0.0
		else:
			st.ally_until = 0
			hostility(r.key, 45.0)
	if opt == 0:
		for k in products:
			products[k].competitors = maxi(0, int(products[k].competitors) - 1)
		return ["Firmaste la alianza: la competencia ya no te ataca.", "good"]
	return ["Declaraste la guerra: sus locales están más baratos, pero cuidado.", "warn"]


## La parte de las ventas que se lleva la alianza (cada día).
func _alliance_share(revenue: float) -> void:
	if path.get("rivales", "") == "alianza" and revenue > 0:
		_spend(revenue * 0.06, "corporativo")


# ---------- aspecto de la oficina ----------
func office_look_cost(i: int) -> float:
	return float(D.OFFICE_LOOKS[i][2]) * price_index


## El siguiente aspecto de la oficina (-1 si ya tienes el mejor).
func next_office_look() -> int:
	return office_look + 1 if office_look + 1 < D.OFFICE_LOOKS.size() else -1


func buy_office_look(i: int) -> Array:
	if i <= office_look or i >= D.OFFICE_LOOKS.size():
		return [false, "Ya tienes esa oficina."]
	if rank < int(D.OFFICE_LOOKS[i][1]):
		return [false, Lang.f("Se desbloquea con el rango %s.", D.RANKS[int(D.OFFICE_LOOKS[i][1])][1])]
	var cost := office_look_cost(i)
	if cash < cost:
		return [false, Lang.f("Necesitas %s en caja.", Fmt.money(cost))]
	cash -= cost
	if cost > 0:
		_add_asset(Lang.f("Remodelación: %s", D.OFFICE_LOOKS[i][0]), cost)
	office_look = i
	add_news(Lang.f("¡Remodelaste tu oficina! Ahora es: %s.", D.OFFICE_LOOKS[i][0]), "good", "record")
	return [true, Lang.f("¡Tu oficina ahora es: %s!", D.OFFICE_LOOKS[i][0])]


# ---------- personalizar la oficina ----------
func office_decor_cost(key: String) -> float:
	for u in D.OFFICE_DECOR:
		if u.key == key:
			return float(u.cost) * price_index
	return 0.0


func buy_office_decor(key: String) -> Array:
	if key in office_decor:
		return [false, "Tu oficina ya lo tiene."]
	var u := {}
	for it in D.OFFICE_DECOR:
		if it.key == key:
			u = it
	if u.is_empty():
		return [false, ""]
	var cost := office_decor_cost(key)
	if cash < cost:
		return [false, Lang.f("Necesitas %s en caja.", Fmt.money(cost))]
	cash -= cost
	_add_asset(Lang.f("Oficina: %s", u.name), cost)
	office_decor.append(key)
	for k in products:
		_rep(k, float(u.rep))
	return [true, Lang.f("Instalaste %s en tu oficina.", Lang.noun(u.name))]
