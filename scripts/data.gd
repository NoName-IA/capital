extends Node
## Datos fijos del juego: productos, tamaños de sucursal, calidades, ciclo económico y rangos.
## Se registra como autoload "D" (igual que data.py en la versión de Python).

# Precios y costos están en dólares del año 1; el índice de precios los ajusta por inflación.
const PRODUCTS := {
	"cafe": {
		"name": "Café", "unit": "tazas", "ref_price": 3.0, "unit_cost": 0.9, "demand": 120.0, "elasticity": 1.6,
		"productivity": 70.0, "spoil": 0.04, "income_elasticity": 0.6, "season_peak": 6, "season_amp": 0.12,
		"competitors": 6, "unlock_cost": 0.0, "factory_cost": 50000.0,
		"description": "Un puesto de café en la esquina. Margen alto, producto perecedero y mucha competencia.",
	},
	"pan": {
		"name": "Panadería", "unit": "panes", "ref_price": 2.0, "unit_cost": 0.6, "demand": 200.0, "elasticity": 1.4,
		"productivity": 100.0, "spoil": 0.15, "income_elasticity": 0.3, "season_peak": 12, "season_amp": 0.05,
		"competitors": 5, "unlock_cost": 15000.0, "factory_cost": 60000.0,
		"description": "Pan fresco cada mañana. Demanda estable en cualquier economía, pero se pone duro rápido (merma alta).",
	},
	"burger": {
		"name": "Hamburguesas", "unit": "combos", "ref_price": 8.0, "unit_cost": 3.2, "demand": 80.0, "elasticity": 1.8,
		"productivity": 30.0, "spoil": 0.08, "income_elasticity": 1.0, "season_peak": 7, "season_amp": 0.10,
		"competitors": 6, "unlock_cost": 60000.0, "factory_cost": 150000.0,
		"description": "Comida rápida. Más ingreso por cliente, más empleados por venta.",
	},
	"ropa": {
		"name": "Ropa", "unit": "prendas", "ref_price": 30.0, "unit_cost": 12.0, "demand": 30.0, "elasticity": 2.0,
		"productivity": 8.0, "spoil": 0.0, "income_elasticity": 1.5, "season_peak": 12, "season_amp": 0.30,
		"competitors": 5, "unlock_cost": 250000.0, "factory_cost": 600000.0,
		"description": "Moda. Muy estacional (diciembre) y sensible al precio y a la economía. No se pudre.",
	},
	"tech": {
		"name": "Electrónica", "unit": "equipos", "ref_price": 220.0, "unit_cost": 150.0, "demand": 6.4, "elasticity": 2.4,
		"productivity": 1.5, "spoil": 0.003, "income_elasticity": 2.0, "season_peak": 11, "season_amp": 0.25,
		"competitors": 4, "unlock_cost": 1200000.0, "factory_cost": 2500000.0,
		"description": "Tecnología. Margen bajo por unidad pero ventas enormes en tiendas grandes. Se vuelve obsoleta.",
	},
}
const PRODUCT_ORDER := ["cafe", "pan", "burger", "ropa", "tech"]

const SIZES := [
	{"name": "Puesto", "capex": 2500.0, "rent": 300.0, "max_emp": 2, "traffic": 1.0},
	{"name": "Local", "capex": 18000.0, "rent": 1500.0, "max_emp": 6, "traffic": 3.0},
	{"name": "Megatienda", "capex": 150000.0, "rent": 6000.0, "max_emp": 20, "traffic": 9.0},
]

# income: elasticidad ingreso relativa. Negativa = bien inferior (se vende más en recesión).
const QUALITIES := [
	{"name": "Económica", "cost": 0.75, "price": 0.80, "rep": 40.0, "income": -0.5, "elast": 1.15},
	{"name": "Estándar", "cost": 1.00, "price": 1.00, "rep": 60.0, "income": 1.0, "elast": 1.00},
	{"name": "Premium", "cost": 1.45, "price": 1.50, "rep": 85.0, "income": 1.8, "elast": 0.80},
]

const PHASES := {
	"expansion": {"name": "Expansión", "target": 1.05, "inflation": 0.035, "months": [8, 18], "next": "auge"},
	"auge": {"name": "Auge", "target": 1.15, "inflation": 0.06, "months": [4, 10], "next": "recesion"},
	"recesion": {"name": "Recesión", "target": 0.82, "inflation": 0.005, "months": [4, 10], "next": "recuperacion"},
	"recuperacion": {"name": "Recuperación", "target": 0.95, "inflation": 0.02, "months": [5, 12], "next": "expansion"},
}

# Descuento del proveedor según el valor comprado el mes anterior (economías de escala).
const VOLUME_TIERS := [[0.0, 0.0], [5000.0, 0.04], [20000.0, 0.08], [80000.0, 0.12], [300000.0, 0.16]]

const RANKS := [
	[0.0, "Vendedor ambulante"],
	[50000.0, "Emprendedor"],
	[250000.0, "Pequeño empresario"],
	[1000000.0, "Empresario"],
	[3500000.0, "Magnate"],
	[10000000.0, "Imperio"],
	# Después de ganar la fortuna sigue creciendo: títulos para los que quieren más.
	[25000000.0, "Conglomerado"],
	[60000000.0, "Multinacional"],
	[150000000.0, "Titán de la industria"],
	[400000000.0, "Leyenda de los negocios"],
	[1000000000.0, "Mil millonario"],
]

# Sistemas de gestión de la oficina central: bajan los gastos corporativos (deseconomías de escala).
const HQ_LEVELS := [
	["Oficina básica", 0.0, 1.0],
	["Software de gestión (ERP)", 150000.0, 0.65],
	["Centro de servicios compartidos", 600000.0, 0.4],
	["Gestión con inteligencia artificial", 2500000.0, 0.22],
	["Holding corporativo", 10000000.0, 0.12],
]
# Reunión de estrategia en la pizarra de la oficina (una vez cada 30 días). Costo = % de las ventas del último mes.
const STRATEGIES := [
	["campana", "Campaña relámpago", 0.08, "Publicidad intensiva: +20% de demanda en todos tus negocios durante 15 días."],
	["capacitacion", "Capacitar al personal", 0.05, "Mejor atención: +6 de reputación en todos tus negocios."],
	["proveedores", "Negociar con proveedores", 0.04, "Poder de negociación: el costo unitario baja 10% durante 30 días."],
]
# Fondo de inversión en bolsa: rendimiento anual esperado según la fase del ciclo (con mucha volatilidad diaria).
const FUND_RETURN := {"expansion": 0.10, "auge": 0.18, "recesion": -0.20, "recuperacion": 0.22}
const FUND_VOLATILITY := 0.011

const MONTHS := ["Enero", "Febrero", "Marzo", "Abril", "Mayo", "Junio", "Julio", "Agosto",
		"Septiembre", "Octubre", "Noviembre", "Diciembre"]

const BASE_WAGE := 1200.0          # salario mensual por empleado
const MANAGER_WAGE := 2500.0       # salario mensual de un gerente de línea
const HIRING_COST := 100.0         # costo de reclutar a un empleado
const SEVERANCE_DAYS := 15.0       # días de salario que se pagan al despedir
const HOLDING_RATE := 0.0008       # costo diario de almacenar inventario (sobre su valor)
const FACTORY_SAVING := 0.30       # la fábrica propia reduce 30% el costo unitario
const FACTORY_UPKEEP := 0.015      # mantenimiento mensual de la fábrica (sobre su costo)
const DEPRECIATION_MONTHS := 60.0  # vida útil de los activos (5 años, línea recta)
const TAX_RATE := 0.25
const START_CASH := 1500.0
# Modos de juego: el normal termina en Imperio (unos 40 minutos); el inversionista no tiene final.
const MODES := {
	"normal": {"name": "Modo normal", "start_cash": START_CASH, "ranks": 6},
	"inversionista": {"name": "Modo inversionista", "start_cash": 250000.0, "ranks": 11},
}
const WIN_VALUE := 10000000.0
const WARDROBE_COST := 3000.0      # armario de la oficina (tienda de ropa del personaje)
# Terrenos de la avenida. Los de la playa venden más por los turistas.
const PLOT_COUNT := 14
const BEACH_PLOTS := [8, 9, 12, 13]
const BEACH_BONUS := 1.2
const RIVAL_PLOT_MAX := 4          # los rivales nunca se quedan con más de 4 terrenos
const RIVAL_LAND_CHANCE := 0.25    # probabilidad mensual de que un rival compre un terreno vacío

# Clima: cambia cada pocos días según la estación (enero = verano) y mueve la demanda de cada negocio.
# Efectos: multiplicador por negocio, "all" para todos (gente en la calle), "beach" para los terrenos de la playa,
# "stall" para los puestos al aire libre y "spoil" para lo perecedero (con calor se echa a perder más rápido).
const WEATHER := [
	{"name": "Soleado", "icon": "sun", "effects": {"beach": 1.25, "burger": 1.05, "cafe": 0.97},
	 "news": "Día de sol: la playa se llena y las hamburguesas se venden más."},
	{"name": "Parcialmente nublado", "icon": "partly", "effects": {},
	 "news": "Cielo parcialmente nublado: un día normal para vender."},
	{"name": "Nublado", "icon": "cloud", "effects": {"cafe": 1.08, "beach": 0.85},
	 "news": "Día nublado: más gente busca un café caliente y la playa está más vacía."},
	{"name": "Lluvia", "icon": "rain", "effects": {"all": 0.88, "cafe": 1.18, "tech": 1.1, "ropa": 0.85, "beach": 0.5, "stall": 0.75},
	 "news": "Llueve: hay menos gente en la calle, pero el café se dispara y la playa se vacía. Los puestos al aire libre venden menos."},
	{"name": "Ola de calor", "icon": "heat", "effects": {"cafe": 0.8, "pan": 0.92, "burger": 1.1, "beach": 1.5, "spoil": 1.6},
	 "news": "¡Ola de calor! La playa explota de turistas, pero nadie quiere café caliente y lo perecedero se echa a perder más rápido."},
	{"name": "Tormenta", "icon": "storm", "effects": {"all": 0.7, "cafe": 1.12, "beach": 0.3, "stall": 0.5},
	 "news": "¡Tormenta! Casi nadie sale a la calle: los puestos y la playa casi no venden. Las megatiendas techadas aguantan mejor."},
]
# Probabilidad de cada clima por mes. [sol, parcial, nublado, lluvia, ola de calor, tormenta]
const WEATHER_SEASON := [[0.55, 0.2, 0.08, 0.02, 0.15, 0.0], [0.55, 0.22, 0.1, 0.03, 0.1, 0.0],
		[0.5, 0.28, 0.14, 0.06, 0.0, 0.02], [0.35, 0.3, 0.2, 0.12, 0.0, 0.03], [0.25, 0.28, 0.25, 0.17, 0.0, 0.05],
		[0.18, 0.22, 0.28, 0.24, 0.0, 0.08], [0.18, 0.2, 0.3, 0.24, 0.0, 0.08], [0.22, 0.25, 0.28, 0.2, 0.0, 0.05],
		[0.3, 0.3, 0.22, 0.15, 0.0, 0.03], [0.4, 0.3, 0.18, 0.1, 0.0, 0.02], [0.47, 0.28, 0.14, 0.06, 0.05, 0.0],
		[0.5, 0.24, 0.1, 0.04, 0.12, 0.0]]
const MAX_TEMP := [29, 28, 25, 21, 17, 14, 13, 15, 18, 21, 24, 27]   # máxima típica de cada mes (°C)

# Estrellas de cada local (de 1 a 5): dependen de la atención, la reputación, la calidad y el precio, y mueven la
# demanda de ese local: con 5 estrellas vende 15% más que con 3; con 1, 15% menos.
const STAR_DEMAND := 0.075   # demanda extra por cada estrella sobre 3

const CONCEPTS := [
	["Ingresos", "Precio × unidades vendidas. Es lo que entra por ventas antes de restar cualquier costo."],
	["Costo de ventas (COGS)", "Lo que te costó la mercancía que vendiste. Se calcula con el costo promedio del inventario."],
	["Utilidad bruta y margen bruto", "Ingresos − costo de ventas. El margen bruto es esa utilidad dividida por los ingresos."],
	["Costos fijos y variables", "Los variables crecen con cada unidad (mercancía). Los fijos se pagan vendas o no (alquiler, salarios, gerentes)."],
	["Margen de contribución", "Precio − costo variable por unidad. Es lo que cada venta aporta para cubrir los costos fijos."],
	["Punto de equilibrio", "Unidades diarias que necesitas vender para cubrir los costos fijos: costos fijos ÷ margen de contribución. Lo ves en Mercado."],
	["Elasticidad precio de la demanda", "Cuánto cae la demanda cuando subes el precio. Con elasticidad 2, subir el precio 10% baja la demanda cerca de 20%. La curva de Mercado muestra el precio que maximiza la utilidad."],
	["Elasticidad ingreso y bienes inferiores", "Cuánto cambia la demanda con la economía. Lo premium cae mucho en recesión; la calidad económica es un bien inferior y vende MÁS en recesión."],
	["Diferenciación por calidad", "Premium cuesta más pero permite cobrar más, mejora la reputación y hace a los clientes menos sensibles al precio."],
	["Rendimientos decrecientes", "El marketing funciona, pero cada dólar extra aporta menos que el anterior. Lo mismo pasa al abrir muchas sucursales de un producto (canibalización)."],
	["Economías de escala", "Cuanto más compras, mejor precio te da el proveedor (descuento por volumen). La fábrica propia baja el costo 30% si vendes suficiente."],
	["Deseconomías de escala", "Con muchas sucursales aparecen gastos corporativos que crecen más rápido que el número de tiendas."],
	["Integración vertical", "Fabricar tú mismo lo que vendes (fábrica propia). Tiene costo fijo alto: solo conviene con mucho volumen."],
	["Inventario y nivel de servicio", "Poco inventario = ventas perdidas. Mucho inventario = costo de almacenamiento y merma. Elige los días de inventario con cuidado."],
	["Competencia y entrada al mercado", "Si un mercado deja mucha ganancia llegan competidores y te quitan clientes. En recesión algunos cierran. Puedes adquirirlos."],
	["Fusiones y adquisiciones", "Comprar un competidor elimina rivalidad y te da su local. El sobreprecio sobre sus activos se llama plusvalía (goodwill)."],
	["Inflación", "Los precios suben con el tiempo: tus costos, salarios y alquileres también. Si no subes tus precios, tu margen real se encoge."],
	["Ciclo económico", "La economía pasa por expansión, auge, recesión y recuperación. Afecta la demanda, la inflación y las tasas de interés."],
	["Tasa de interés y política monetaria", "El banco central sube la tasa cuando hay inflación. Eso encarece tus préstamos y paga más a los bonos."],
	["Apalancamiento y riesgo", "Pedir prestado multiplica el crecimiento, pero los intereses se pagan aunque vendas poco. Más deuda = tasa más alta."],
	["Amortización (sistema francés)", "Los préstamos se pagan en cuotas mensuales iguales que incluyen interés y abono al capital."],
	["Depreciación", "Lo que inviertes en sucursales y fábricas se reparte como gasto durante 5 años. No sale caja, pero reduce la utilidad y los impuestos."],
	["Escudo fiscal", "Los intereses y la depreciación se restan antes de impuestos, así que pagas menos impuestos."],
	["Pérdidas fiscales compensables", "Si un mes pierdes dinero, esa pérdida se descuenta de las utilidades futuras antes de pagar impuestos."],
	["Costos hundidos", "Si vendes una sucursal solo recuperas la mitad de su valor en libros. Lo invertido ya no vuelve: decide mirando el futuro."],
	["Costo de oportunidad", "El dinero quieto podría rendir en bonos. Si tu negocio rinde menos que los bonos, estás perdiendo dinero aunque ganes."],
	["ROI, ROE y ROA", "Retorno sobre la inversión de cada sucursal, sobre tu patrimonio y sobre tus activos totales. Comparan cuánto ganas con cuánto pusiste."],
	["EBITDA", "Utilidad antes de intereses, impuestos, depreciación y amortización. Mide cuánto genera la operación del negocio."],
	["Valor económico agregado (EVA)", "Utilidad neta − (patrimonio × costo del capital). Si es positivo, creas riqueza por encima del costo de oportunidad."],
	["Valoración de empresa", "Tu empresa vale aprox. EBITDA anual × múltiplo + caja − deuda. En auge los múltiplos suben; en recesión bajan."],
	["Liquidez y sobregiro", "Puedes quedar en caja negativa un tiempo (sobregiro) con un interés muy alto. Si pasas el límite muchos días, quiebras."],
	["Delegación", "Un gerente cuesta un salario fijo, pero ajusta solo el personal y el inventario de su línea."],
	["Riesgo y valor esperado", "Valor esperado = suma de (probabilidad × resultado). Dos opciones con el mismo valor esperado pueden tener riesgos muy distintos: los dilemas del juego te muestran las probabilidades para que compares."],
	["Aversión a la pérdida", "Perder $100 duele más de lo que alegra ganar $100. Por eso cuesta cortar un negocio que pierde o romper una racha: reconócelo y decide con números."],
	["Riesgo moral y reputación", "Un atajo poco ético (sobornos, carteles, mercancía dudosa) puede ahorrar dinero hoy, pero si se descubre la multa y la pérdida de reputación cuestan mucho más."],
	["Gastos de representación", "Lo que la empresa gasta en la imagen de su dueño (ropa, accesorios). Es un gasto operativo: baja la utilidad igual que cualquier otro."],
	["Economías de escala en la gestión", "Invertir en sistemas (ERP, servicios compartidos, IA) baja el costo de coordinar muchas sucursales. Es la forma de seguir creciendo sin que los gastos corporativos se coman la utilidad."],
	["Riesgo y rentabilidad", "La bolsa rinde más que los bonos en promedio, pero sube y baja todos los días y cae fuerte en recesión. Más rentabilidad esperada siempre viene con más riesgo."],
	["Colusión", "Acordar precios con la competencia sube los márgenes de ambos a costa del cliente. Es ilegal: las autoridades de libre competencia lo castigan con multas enormes."],
]

# Los rivales: le ponen cara a la competencia. Cada uno domina uno o más mercados.
# {p} = producto, {r} = rango del jugador.
const RIVALS := [
	{"key": "victor", "name": "Víctor Mardones", "short": "Mardones", "company": "Grupo Monopolio", "products": ["cafe"],
	 "color": Color8(150, 100, 220),
	 "entry": ["Gracias por demostrar que el negocio de {p} deja plata. Abro uno justo enfrente.",
			"Tus márgenes en {p} son demasiado buenos para ser solo tuyos. Ya llegué.",
			"Vi tus números de {p}. Me gustaron. Nos vemos en la calle principal."],
	 "loss": ["Cerré un local de {p}. No te emociones: es solo una retirada táctica.",
			"Con esos precios en {p} vas a quebrar antes que yo... pero por ahora, tú ganas."],
	 "taunt": ["Escuché que tu banco está nervioso. Mi oferta para comprarte barato sigue en pie.",
			"Números rojos, ¿eh? Yo empecé igual... no, mentira, yo nunca estuve tan mal."],
	 "rank": ["¿{r}? Disfrútalo. Cuanto más alto subes, más dura es la caída.",
			"Así que ahora eres {r}. Mis abogados ya saben tu nombre."],
	 "acquire": ["¿Compraste a uno de los míos? Esto no se queda así."]},
	{"key": "pilar", "name": "Doña Pilar Ríos", "short": "la Doña Pilar", "company": "Panaderías La Abuela", "products": ["pan"],
	 "color": Color8(215, 140, 70),
	 "entry": ["Ay, mijo, qué lindo tu negocito de {p}. Abrí uno al lado, para que no te sientas solo.",
			"Cuarenta años vendiendo {p}. Tú llevas cuarenta días. Ya veremos quién se queda.",
			"Les regalé un pancito a tus clientes. Ahora vienen a mi local nuevo, qué cosas."],
	 "loss": ["Cerré un local de {p}. Pero no es por ti, ¿eh? Es la artritis.",
			"Me ganaste esta vez, mijo. Te mando una empanada para que celebres."],
	 "taunt": ["¿Sin plata, mijo? Te puedo prestar para el pan... con intereses de abuela.",
			"Abrígate, que esos números rojos dan frío."],
	 "rank": ["¡{r}! Qué orgullo, mijo. Igual te voy a ganar, pero qué orgullo.",
			"{r}... cuando yo tenía tu edad también me creía mucho."],
	 "acquire": ["¿Me compraste un local? Cuídalo, que ahí horneé mis mejores marraquetas."]},
	{"key": "kevin", "name": "Kevin Soto", "short": "Kevin", "company": "SmashBurger Bros", "products": ["burger"],
	 "color": Color8(235, 100, 60),
	 "entry": ["¡Bro! Abrí un SmashBurger frente a tu local de {p}. Tengo 300 mil seguidores, ¿y tú?",
			"Hice un live probando tu {p}. Spoiler: el mío es mejor. Nuevo local abierto, bro.",
			"Bro, el mercado de {p} es mío. Bueno, todavía no, pero acabo de abrir otro."],
	 "loss": ["Cerré un local de {p}, bro. Es estrategia, lo explico en mi podcast.",
			"Ok bro, tus precios están locos. Me retiro... por ahora."],
	 "taunt": ["Bro, vi tus números rojos. ¿Quieres mi curso de emprendimiento? 50% off.",
			"Tranqui bro, la quiebra es solo un 'pivoteo' con otro nombre."],
	 "rank": ["¿{r}? Respeto, bro. Igual mi Instagram tiene más likes que tu empresa.",
			"{r}, bro. Hagamos un collab... mentira, te voy a destruir."],
	 "acquire": ["¡NO, BRO! ¡Ese local era de mi primo! Esto va directo a mis historias."]},
	{"key": "valentina", "name": "Valentina Cruz", "short": "Valentina", "company": "Maison Cruz", "products": ["ropa"],
	 "color": Color8(210, 80, 150),
	 "entry": ["Querida, tu {p} es... valiente. Abrí una boutique cerca para que la gente compare.",
			"La moda es cruel. Yo también. Nueva tienda de {p} en tu calle."],
	 "loss": ["Cerré una tienda de {p}. Era de la temporada pasada, claramente.",
			"Bajaste tanto tus precios que ya no puedo competir. Qué... vulgar. Pero efectivo."],
	 "taunt": ["Números rojos: el único rojo que no está de moda, querida.",
			"Si necesitas vender algo, yo te compro los muebles. Baratos, claro."],
	 "rank": ["{r}. Qué chic. Casi tanto como yo.",
			"{r}, querida. Ya te puedo invitar a mis fiestas... a la de los empleados."],
	 "acquire": ["¿Compraste mi tienda? Espero que al menos cambies las vitrinas."]},
	{"key": "feng", "name": "Dr. Tomás Feng", "short": "el Dr. Feng", "company": "NeoTech Global", "products": ["tech"],
	 "color": Color8(60, 140, 220),
	 "entry": ["Mi algoritmo detectó margen excesivo en {p}. Corrigiendo con un nuevo local.",
			"Probabilidad de que me superes en {p}: 3,2%. Abro sucursal para bajarla a cero."],
	 "loss": ["Error 404: local de {p} no encontrado. Lo cerré. Recalculando estrategia.",
			"Tus precios en {p} no estaban en mi modelo. Actualizando."],
	 "taunt": ["Tu flujo de caja es negativo. Mi modelo predice tu quiebra. Me encantaría equivocarme. No me equivoco.",
			"Detecto pánico en tus decisiones. Respira. Luego véndeme todo."],
	 "rank": ["{r}: dato registrado. Actualizando mi modelo de amenazas.",
			"Felicitaciones por {r}. Esto es un mensaje automático."],
	 "acquire": ["Adquisición detectada. Respuesta emocional: no disponible. Respuesta comercial: en camino."]},
]


func rival_by_key(key) -> Dictionary:
	for r in RIVALS:
		if r["key"] == key:
			return r
	return RIVALS[0]


## El rival que domina el mercado de ese producto.
func rival_for(product: String) -> Dictionary:
	for r in RIVALS:
		if product in r["products"]:
			return r
	return RIVALS[0]
