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
# Actividades en la ciudad (fuera de tus locales): [clave, nombre, días de espera, qué hace]. Ver Game.do_activity.
const ACTIVITIES := [
	["muestras", "Repartir muestras en el parque", 10,
	 "Regalas productos en la feria del parque: más gente conoce tus marcas (+8 de conocimiento en todos tus negocios)."],
	["encuesta", "Encuesta a los vecinos del barrio", 15,
	 "Los vecinos te dicen qué precio pagarían (el que maximiza tu utilidad) y les gusta que les pregunten (+2 de reputación)."],
	["voley", "Patrocinar el torneo de vóley de la playa", 30,
	 "Tu marca en la cancha: +5 de reputación en todos tus negocios y +25% de demanda en los locales de la playa por 7 días."],
	["pesca", "Pescar en la punta del muelle", 1,
	 "Un rato libre: lo que pescas lo vendes en el mercado del puerto. Mejor de madrugada y al atardecer."],
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

# Los rivales: marcas y personas reales que le ponen cara a la competencia (los diálogos son una parodia).
# Cada uno domina uno o más mercados ("products") y tiene un estilo que decide cómo te ataca (ver Game._rival_ai).
# Los "tiburones" no tienen mercado propio: aparecen a partir del día "from" y se meten en todos.
# {p} = producto, {r} = rango del jugador. "value" = lo que vale su negocio en la ciudad al empezar (año 1).
# Para publicar el juego conviene cambiar estos nombres: todo el juego los toma de aquí.
const RIVALS := [
	{"key": "starbucks", "name": "Howard Schultz", "short": "Starbucks", "company": "Starbucks", "products": ["cafe"],
	 "color": Color8(0, 140, 90), "style": "expansion", "value": 600000.0, "from": 0,
	 "bio": "El hombre que convirtió el café en una experiencia de 6 dólares. Abre locales en cada esquina hasta que no quede esquina.",
	 "entry": ["Gracias por demostrar que el {p} deja plata en esta calle. Abro un Starbucks justo enfrente.",
			"Tu {p} está bien... para un puesto. El mío trae tu nombre mal escrito en el vaso.",
			"Una esquina sin Starbucks es una esquina triste. Ya la arreglé."],
	 "loss": ["Cerré un local de {p}. No te emociones: abro tres en otra ciudad.",
			"Con esos precios de {p} vas a quebrar antes que yo... pero por ahora, tú ganas."],
	 "taunt": ["Escuché que tu banco está nervioso. ¿Quieres un frappuccino para los nervios?",
			"Números rojos, ¿eh? Rojo como nuestros vasos de Navidad."],
	 "rank": ["¿{r}? Disfrútalo. Nosotros tenemos 38 mil locales.",
			"Así que ahora eres {r}. Te invito un café... en mi local."],
	 "acquire": ["¿Compraste uno de mis locales? Le vas a tener que cambiar el logo, ¿eh?"],
	 "war": ["Esta semana el {p} en Starbucks va con descuento. Solo en tu calle. Casualidad.",
			"Abrimos un local nuevo al lado del tuyo. Somos así."],
	 "passed": ["¿Me pasaste en la ciudad? Bien. Igual tengo más sucursales que tú en el resto del planeta."]},
	{"key": "bimbo", "name": "Daniel Servitje", "short": "Bimbo", "company": "Grupo Bimbo", "products": ["pan"],
	 "color": Color8(40, 110, 200), "style": "precios", "value": 450000.0, "from": 0,
	 "bio": "El imperio del pan de molde. Su arma es el precio: vende tan barato que nadie le puede ganar... por un rato.",
	 "entry": ["Tu {p} es lindo y artesanal. El mío dura tres semanas y cuesta la mitad. Abrí al lado.",
			"El osito llegó a tu barrio con {p} más barato."],
	 "loss": ["Cerré un local de {p}. El osito está triste, pero volverá.",
			"Tus precios de {p} nos ganaron esta vez. Respeto."],
	 "taunt": ["¿Sin plata? Te vendo pan barato para que ahorres.",
			"Abrígate, que esos números rojos dan frío."],
	 "rank": ["¡{r}! Qué orgullo. Te mando un pastelito para celebrar.",
			"{r}... nosotros vendemos pan en 30 países, pero felicidades."],
	 "acquire": ["¿Me compraste un local? Cuídalo, ahí estaba nuestro mejor horno."],
	 "war": ["Bajamos el {p} 20%. ¿Y tú qué vas a hacer?",
			"Guerra de precios en {p}: el que aguante más, gana. Nosotros aguantamos mucho."],
	 "passed": ["Nos pasaste. Bueno, el pan no se hizo en un día."]},
	{"key": "mcdonalds", "name": "Ronald McDonald", "short": "McDonald's", "company": "McDonald's", "products": ["burger"],
	 "color": Color8(230, 50, 40), "style": "publicidad", "value": 1200000.0, "from": 0,
	 "bio": "El payaso más rico del mundo. No gana por sabor: gana porque su publicidad está en todas partes y tu marca desaparece.",
	 "entry": ["¡Hola, amiguito! Abrí un McDonald's frente a tu local de {p}. ¡Me encanta!",
			"Tu {p} se ve rico. Lástima que nadie lo vea: mi letrero es más grande.",
			"¡Cajita feliz para todos! Bueno, para tus clientes, que ahora vienen a mi local."],
	 "loss": ["Cerré un local de {p}. Ba da ba ba baaa... no me encanta.",
			"Ok, tus precios de {p} están locos. Me retiro... por ahora."],
	 "taunt": ["Vi tus números rojos. ¿Quieres trabajar conmigo? Buscamos cajeros.",
			"Tranquilo, la quiebra es solo una cajita triste."],
	 "rank": ["¿{r}? ¡Felicidades, amiguito! Igual vendo más hamburguesas por segundo que tú en un año.",
			"{r}. Te voy a dedicar un juguete de la cajita feliz."],
	 "acquire": ["¡NO! ¡Ese local tenía la mejor piscina de pelotas!"],
	 "war": ["Nueva campaña en la tele, en la radio y en tu celular. Nadie se va a acordar de tu {p}.",
			"Puse un letrero gigante al lado de tu local. ¿Lo viste? Todos lo vieron."],
	 "passed": ["¿Me pasaste? En esta ciudad, tal vez. En el mundo, sigo siendo el rey."]},
	{"key": "zara", "name": "Amancio Ortega", "short": "Zara", "company": "Inditex · Zara", "products": ["ropa"],
	 "color": Color8(200, 200, 210), "style": "copia", "value": 2500000.0, "from": 0,
	 "bio": "El hombre que viste al mundo en dos semanas. Si algo tuyo se vende bien, a los 15 días está en su vitrina más barato.",
	 "entry": ["Tu {p} me gustó tanto que la copié. Ya está en mi tienda nueva, al lado.",
			"La moda es rápida. Yo soy más rápido. Nueva tienda de {p} en tu calle."],
	 "loss": ["Cerré una tienda de {p}. Era de la temporada pasada, claramente.",
			"Bajaste tanto tus precios que ya no te puedo copiar. Bien jugado."],
	 "taunt": ["Números rojos: el único rojo que no está de moda.",
			"Si necesitas vender algo, te compro los maniquíes. Baratos, claro."],
	 "rank": ["{r}. Elegante. Casi tanto como yo.",
			"{r}. Te voy a copiar eso también."],
	 "acquire": ["¿Compraste mi tienda? Espero que al menos cambies las vitrinas."],
	 "war": ["Copiamos tu colección de {p}. Misma ropa, 30% más barata, en mi vitrina.",
			"Tu diseño de {p} se vende bien. Ahora también en Zara."],
	 "passed": ["Me pasaste. Interesante. Voy a copiar tu modelo de negocio."]},
	{"key": "apple", "name": "Tim Cook", "short": "Apple", "company": "Apple", "products": ["tech"],
	 "color": Color8(170, 180, 195), "style": "premium", "value": 6000000.0, "from": 0,
	 "bio": "Vende lo mismo que el año pasado con otra cámara y la gente hace fila. Cada lanzamiento te quita clientes.",
	 "entry": ["Abrimos una Apple Store en tu calle. La fila ya llega hasta tu local de {p}.",
			"Tu {p} es bueno. El nuestro es igual, pero en blanco y el doble de caro. Ya abrimos."],
	 "loss": ["Cerramos una tienda de {p}. Lo llamamos «simplificar».",
			"Tus precios en {p} no estaban en nuestro plan. Actualizando."],
	 "taunt": ["Tu flujo de caja es negativo. Te recomendamos AppleCare para tu empresa.",
			"Detectamos pánico en tus decisiones. Respira. Luego cómprate un iPhone."],
	 "rank": ["{r}: lo anunciaremos en nuestro próximo evento. O no.",
			"Felicitaciones por {r}. Este mensaje fue enviado desde mi iPhone."],
	 "acquire": ["¿Compraste una de nuestras tiendas? Los cables siguen siendo nuestros."],
	 "war": ["Lanzamos un modelo nuevo. Es igual al anterior. Todos tus clientes de {p} están en la fila.",
			"Evento de lanzamiento esta semana. Tu {p} acaba de pasar de moda."],
	 "passed": ["Nos superaste en esta ciudad. Lo vamos a llamar «una oportunidad»."]},
	{"key": "trump", "name": "Donald Trump", "short": "Trump", "company": "Trump Organization", "products": [],
	 "color": Color8(235, 165, 50), "style": "terrenos", "value": 3000000.0, "from": 100,
	 "bio": "Tiburón inmobiliario. Compra los mejores terrenos de la avenida, te ofrece comprar tus locales y amenaza con demandarte.",
	 "entry": ["Compré un terreno en tu calle. El mejor terreno. Tremendo. Nadie compra terrenos como yo.",
			"Abrí un local de {p}. Va a ser el mejor {p} de la historia, créeme."],
	 "loss": ["Cerré un local. Fue una decisión brillante, la gente lo dice.",
			"Me ganaste esta vez. Muy injusto. Muy, muy injusto."],
	 "taunt": ["Tus números son un desastre. Un desastre total. Yo te compro todo, barato.",
			"Estás en quiebra. Yo quebré varias veces y mírame."],
	 "rank": ["¿{r}? Muy bien. Pero yo soy más rico. Mucho más.",
			"{r}. Nada mal. Yo lo habría hecho más rápido."],
	 "acquire": ["¿Me compraste un local? Te voy a demandar. Mis abogados son los mejores."],
	 "war": ["Compré el terreno de al lado. Voy a poner mi nombre en letras doradas, gigantes.",
			"Te voy a demandar. Todavía no sé por qué, pero te voy a demandar."],
	 "passed": ["¿Me pasaste? Fake news. Totalmente falso."]},
	{"key": "musk", "name": "Elon Musk", "short": "Musk", "company": "Tesla · X", "products": [],
	 "color": Color8(80, 150, 240), "style": "caos", "value": 5000000.0, "from": 200,
	 "bio": "Impredecible. Un tuit suyo puede hacer explotar tus ventas o hundirlas. Además trata de llevarse a tus empleados.",
	 "entry": ["Acabo de comprar un local de {p} en tu ciudad. No sé por qué. Me pareció gracioso.",
			"{p} en Marte en 2030. Por ahora, en tu calle."],
	 "loss": ["Cerré mi local de {p}. Lo voy a reabrir como red social.",
			"Ok, me ganaste en {p}. Voy a comprar otra empresa para olvidarlo."],
	 "taunt": ["Tu empresa está en rojo. Yo también, pero yo tengo cohetes.",
			"Encuesta: ¿debería comprar tu empresa por 1 dólar? Sí 69%, No 31%."],
	 "rank": ["{r}. No está mal para un humano.",
			"{r}. Te sigo en X. Bueno, te sigue un bot mío."],
	 "acquire": ["Compraste uno de mis locales. Respuesta: jaja."],
	 "war": ["Acabo de tuitear sobre tu {p}. Mira lo que pasa.",
			"Le ofrecí a tu mejor empleado trabajar 80 horas a la semana conmigo. Dijo que lo iba a pensar."],
	 "passed": ["Me pasaste. Interesante. Voy a comprar el juego."]},
	{"key": "bezos", "name": "Jeff Bezos", "short": "Amazon", "company": "Amazon", "products": [],
	 "color": Color8(255, 155, 0), "style": "online", "value": 8000000.0, "from": 0, "needs": ["ropa", "tech"],
	 "bio": "No necesita locales: vende todo por internet y lo entrega mañana. Le quita clientes a la ropa y a la electrónica.",
	 "entry": ["¿Para qué ir a tu tienda de {p} si se lo llevo mañana a su casa?",
			"Ahora vendemos {p} con envío gratis. Tu local es muy bonito, eso sí."],
	 "loss": ["Bajamos la venta de {p} en tu ciudad. Es solo un número en una planilla.",
			"Tus precios de {p} nos ganaron. Ajustando el algoritmo."],
	 "taunt": ["¿Tu empresa en rojo? Podemos llevarte la quiebra a domicilio.",
			"Mis bodegas tienen más inventario que toda tu ciudad."],
	 "rank": ["{r}. Agregado al carrito.",
			"Felicitaciones por {r}. ¿Le gustaría calificar su experiencia?"],
	 "acquire": ["Compraste algo mío. ¿Quieres devolverlo? Tienes 30 días."],
	 "war": ["Cyber Day: {p} con 40% de descuento y envío en un día.",
			"Prime Day en {p}. Tus clientes ni se levantan del sillón."],
	 "passed": ["Me superaste en la ciudad. Mis cohetes siguen siendo más grandes que los de Elon."]},
]
# Nombres de los rivales de versiones anteriores (las partidas viejas los guardaron en sus decisiones pendientes).
const LEGACY_RIVALS := {"victor": "starbucks", "pilar": "bimbo", "kevin": "mcdonalds", "valentina": "zara", "feng": "apple"}
const RIVAL_STYLES := {
	"expansion": ["Expansión agresiva", "Abre locales nuevos en tu mercado y compra terrenos de la avenida."],
	"precios": ["Guerra de precios", "Baja sus precios por semanas: tu demanda cae si no respondes."],
	"publicidad": ["Publicidad masiva", "Sus campañas tapan la tuya: baja lo que la gente conoce de tu marca."],
	"copia": ["Copia todo", "Copia lo que mejor vendes y lo ofrece más barato."],
	"premium": ["Lanzamientos", "Cada lanzamiento hace filas en su tienda y te quita clientes por unas semanas."],
	"terrenos": ["Tiburón inmobiliario", "Compra terrenos, te ofrece comprar tus locales y te amenaza con demandas."],
	"caos": ["Impredecible", "Sus tuits suben o hunden tus ventas, y trata de llevarse a tus empleados."],
	"online": ["Tienda en línea", "Vende por internet: le quita demanda a la ropa y a la electrónica."],
}

# Artículos para personalizar cada local. Se pagan una vez (es inversión: se deprecia con el local) y el costo
# crece con el tamaño (UPGRADE_SIZE). Efectos: demand = demanda extra, stars = estrellas que merece de más,
# capacity = atiende más rápido, weather = cuánto del castigo del clima se evita.
const UPGRADES := [
	{"key": "plantas", "name": "Plantas y decoración", "cost": 500.0, "stars": 0.3, "icon": "heart",
	 "desc": "Maceteros en la entrada. El local se ve más cuidado: merece +0,3 estrellas."},
	{"key": "letrero", "name": "Letrero luminoso", "cost": 900.0, "demand": 0.06, "icon": "star",
	 "desc": "Neón alrededor del letrero: más gente ve tu local, sobre todo de noche (+6% de demanda)."},
	{"key": "musica", "name": "Música ambiente", "cost": 400.0, "stars": 0.15, "demand": 0.02, "icon": "heart",
	 "desc": "Parlantes en la entrada. Los clientes se quedan más contentos (+0,15 estrellas y +2% de demanda)."},
	{"key": "wifi", "name": "Wifi gratis", "cost": 350.0, "demand": 0.04, "stars": 0.1, "icon": "bolt",
	 "desc": "Internet gratis para los clientes: +4% de demanda y +0,1 estrellas."},
	{"key": "terraza", "name": "Terraza con mesas", "cost": 1600.0, "demand": 0.08, "stars": 0.1, "icon": "sun",
	 "desc": "Mesas con quitasol en la vereda: el local llama la atención (+8% de demanda y +0,1 estrellas)."},
	{"key": "aire", "name": "Aire acondicionado", "cost": 1400.0, "stars": 0.15, "weather": 0.5, "icon": "cloud",
	 "desc": "Con calor, lluvia o tormenta pierdes la mitad de los clientes que perderías sin él (+0,15 estrellas)."},
	{"key": "pantallas", "name": "Menú digital", "cost": 1100.0, "capacity": 0.1, "icon": "chart",
	 "desc": "Pantallas con los precios: los clientes deciden más rápido y cada empleado atiende 10% más."},
	{"key": "autopago", "name": "Cajas de autopago", "cost": 2200.0, "capacity": 0.15, "icon": "coin",
	 "desc": "Los clientes se cobran solos: cada empleado atiende 15% más."},
]
const UPGRADE_SIZE := [1.0, 3.0, 8.0]   # el mismo artículo cuesta más en un local y mucho más en una megatienda

# Cómo tratas a tus empleados (vale para toda la empresa). wage = sueldo que pagas (sobre el normal),
# prod = cuánto rinden, morale = hacia dónde va el ánimo del equipo (0 a 100).
const LABOR := [
	{"key": "digno", "name": "Trato digno", "wage": 1.15, "prod": 1.05, "morale": 85.0,
	 "desc": "Sueldo 15% sobre el mínimo, horarios justos y buen ambiente. El equipo rinde más, atiende mejor y casi nunca renuncia."},
	{"key": "normal", "name": "Lo que dice la ley", "wage": 1.0, "prod": 1.0, "morale": 60.0,
	 "desc": "Sueldo mínimo y las horas del contrato. Ni bien ni mal."},
	{"key": "exigente", "name": "Horas extra sin pago", "wage": 1.0, "prod": 1.15, "morale": 32.0,
	 "desc": "Se quedan después de hora sin cobrar. Rinden más, pero el ánimo baja, algunos renuncian y puede llegar una inspección del trabajo."},
	{"key": "explotador", "name": "Explotación", "wage": 0.8, "prod": 1.3, "morale": 8.0,
	 "desc": "Turnos dobles, sin descansos, gritos y sueldos bajo el mínimo. Ahorras en sueldos y rinden más... hasta que renuncian, hacen huelga, te denuncian o sale en las noticias."},
]
const START_MORALE := 60.0


func rival_by_key(key) -> Dictionary:
	key = LEGACY_RIVALS.get(key, key)
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


func upgrade_by_key(key: String) -> Dictionary:
	for u in UPGRADES:
		if u.key == key:
			return u
	return UPGRADES[0]
