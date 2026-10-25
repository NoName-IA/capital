class_name Wardrobe
extends RefCounted
## Catálogo del armario de la oficina: colores, peinados, sombreros, chaquetas, pantalones y accesorios con sus precios.

const LOOK_COLORS := {
	"skin": [[255, 224, 189], [240, 200, 165], [215, 165, 120], [170, 115, 75], [115, 75, 50], [80, 52, 35]],
	"hair": [[30, 25, 20], [90, 60, 35], [200, 160, 80], [235, 220, 175], [140, 50, 30], [110, 110, 115],
			[230, 110, 160], [70, 110, 210]],
	"shirt": [[227, 179, 65], [245, 245, 245], [40, 40, 45], [40, 60, 110], [200, 60, 60], [60, 150, 80],
			[150, 100, 190], [230, 130, 60], [110, 170, 230], [230, 130, 170]],
	"pants": [[40, 50, 80], [70, 100, 150], [40, 40, 45], [90, 80, 70], [60, 80, 60], [170, 155, 125], [110, 40, 40]],
	"jacket_color": [[40, 40, 45], [40, 60, 110], [110, 30, 40], [60, 90, 60], [150, 150, 155], [200, 170, 120],
			[230, 130, 60], [245, 245, 245]],
	"shoes": [[30, 30, 35], [90, 60, 40], [245, 245, 245], [200, 50, 50], [60, 110, 200], [227, 179, 65]],
}
const HAIR_STYLES := [["corto", "Corto"], ["largo", "Largo"], ["cresta", "Cresta"], ["calvo", "Calvo"]]
const HATS := [["ninguno", "Ninguno"], ["gorra", "Gorra"], ["lana", "Gorro de lana"], ["vaquero", "Vaquero"],
		["copa", "Sombrero de copa"], ["corona", "Corona"]]
const JACKETS := [["ninguna", "Ninguna"], ["sudadera", "Sudadera"], ["blazer", "Blazer"], ["cuero", "Cuero"]]
const PANTS_STYLES := [["jeans", "Jeans"], ["vestir", "De vestir"], ["cortos", "Cortos"]]
const TOGGLES := [["tie", "Corbata"], ["glasses", "Lentes de sol"], ["beard", "Barba"], ["watch", "Reloj de oro"],
		["chain", "Cadena de oro"], ["backpack", "Mochila"], ["scarf", "Bufanda"]]
const TOGGLE_KEYS := ["tie", "glasses", "beard", "watch", "chain", "backpack", "scarf"]
const SHOP_TABS := [["cabeza", "Cabeza"], ["sombreros", "Sombreros"], ["ropa", "Ropa"], ["piernas", "Piernas"],
		["accesorios", "Accesorios"]]
const DEFAULT_LOOK := {"skin": [240, 200, 165], "hair": [30, 25, 20], "hair_style": "corto", "hat": "ninguno",
		"shirt": [227, 179, 65], "pants": [40, 50, 80], "pants_style": "jeans", "jacket": "ninguna",
		"jacket_color": [40, 40, 45], "shoes": [30, 30, 35], "tie": false, "glasses": false, "beard": false,
		"watch": false, "chain": false, "backpack": false, "scarf": false}
# Lo que viene gratis; todo lo demás se compra en el armario de la oficina (precios base, suben con la inflación).
const FREE_ITEMS := {"hair": [[30, 25, 20], [90, 60, 35]], "hair_style": ["corto", "calvo"], "hat": ["ninguno"],
		"shirt": [[227, 179, 65], [245, 245, 245]], "pants": [[40, 50, 80], [40, 40, 45]],
		"jacket": ["ninguna"], "jacket_color": [[40, 40, 45], [40, 60, 110]], "pants_style": ["jeans"],
		"shoes": [[30, 30, 35], [90, 60, 40]]}
const ITEM_PRICES := {"hair": 150, "shirt": 200, "pants": 150, "jacket_color": 200, "shoes": 300,
		"hair_style": {"largo": 300, "cresta": 500},
		"hat": {"gorra": 600, "lana": 250, "vaquero": 900, "copa": 5000, "corona": 25000},
		"jacket": {"sudadera": 700, "blazer": 1500, "cuero": 2500}, "pants_style": {"vestir": 400, "cortos": 250},
		"tie": 800, "glasses": 1200, "beard": 250, "watch": 3000, "chain": 4000, "backpack": 600, "scarf": 350}
const SPECIAL_PRICES := {"hair=[230, 110, 160]": 400, "hair=[70, 110, 210]": 400, "shoes=[227, 179, 65]": 2000}


static func ints(v):
	if v is Array:
		return v.map(func(x): return int(x))
	return v


## Aspecto completo: lo que falta en el guardado se completa con el aspecto inicial.
static func full_look(look) -> Dictionary:
	var out := DEFAULT_LOOK.duplicate(true)
	if look is Dictionary:
		for k in look:
			out[k] = ints(look[k])
	return out


static func item_id(key: String, value) -> String:
	return key if key in TOGGLE_KEYS else "%s=%s" % [key, str(ints(value))]


## Precio base de una prenda (0 si viene gratis). La piel siempre es gratis.
static func item_price(key: String, value) -> float:
	if key == "skin":
		return 0.0
	if key in TOGGLE_KEYS:
		return ITEM_PRICES[key]
	value = ints(value)
	if value in FREE_ITEMS.get(key, []):
		return 0.0
	var id := item_id(key, value)
	if SPECIAL_PRICES.has(id):
		return SPECIAL_PRICES[id]
	var price = ITEM_PRICES[key]
	return float(price.get(value, 0)) if price is Dictionary else float(price)


static func owns(g: Game, key: String, value) -> bool:
	return item_price(key, value) == 0 or item_id(key, value) in g.owned_items
