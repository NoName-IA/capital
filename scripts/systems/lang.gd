class_name Lang
extends RefCounted
## Idiomas del juego. Los textos se escriben en español en el código y se traducen al dibujarlos: ImUI, los globos
## de diálogo y los letreros 3D pasan todo por Lang.t (busca la frase exacta en assets/idiomas/<código>.json). Las
## frases con valores adentro usan Lang.f("Caja: %s", [x]): se traduce la plantilla y también los valores que sean
## textos del juego (nombres de productos, meses, climas...).
##
## En las traducciones los valores van en el mismo orden que en español, salvo que se numeren: %2$s es el segundo
## valor. %_ usa un valor sin escribir nada (para los plurales hechos con "s" en español, que en otros idiomas no van).

const CODES := ["es", "en", "zh", "ru", "pt", "de"]
const NAMES := ["Español", "English", "简体中文", "Русский", "Português (Brasil)", "Deutsch"]
## El nombre de cada idioma (en el orden de CODES) escrito en el idioma que se está usando
const NAMES_IN := {
	"es": ["Español", "Inglés", "Chino simplificado", "Ruso", "Portugués (Brasil)", "Alemán"],
	"en": ["Spanish", "English", "Simplified Chinese", "Russian", "Portuguese (Brazil)", "German"],
	"zh": ["西班牙语", "英语", "简体中文", "俄语", "葡萄牙语（巴西）", "德语"],
	"ru": ["Испанский", "Английский", "Китайский (упр.)", "Русский", "Португальский (Бразилия)", "Немецкий"],
	"pt": ["Espanhol", "Inglês", "Chinês simplificado", "Russo", "Português (Brasil)", "Alemão"],
	"de": ["Spanisch", "Englisch", "Chinesisch (vereinf.)", "Russisch", "Portugiesisch (Brasilien)", "Deutsch"],
}
## Cómo se escriben los números: [separador de miles, separador decimal]
const SEPARATORS := {"es": [".", ","], "en": [",", "."], "zh": [",", "."], "ru": [" ", ","], "pt": [".", ","],
		"de": [".", ","]}

static var code := "es"
static var _dict := {}       # frase en español -> traducción
static var _upper := {}      # FRASE EN MAYÚSCULAS -> traducción en mayúsculas (letreros armados con to_upper)
static var _spec := RegEx.create_from_string("%(?:(\\d+)\\$)?([-+0 #]*\\d*(?:\\.\\d+)?)([sdifxXc_%])")


## Cambia el idioma. Un código desconocido vuelve al español.
static func use(new_code: String) -> void:
	code = new_code if new_code in CODES else "es"
	_dict = {}
	_upper = {}
	if code != "es":
		var path := "res://assets/idiomas/%s.json" % code
		var data = null
		if ResourceLoader.exists(path):
			var res = load(path)
			data = res.data if res is JSON else null
		if data == null and FileAccess.file_exists(path):
			data = JSON.parse_string(FileAccess.get_file_as_string(path))
		if data is Dictionary:
			for k in data:
				if typeof(data[k]) == TYPE_STRING and data[k] != "":
					_dict[k] = data[k]
					_upper[String(k).to_upper()] = String(data[k]).to_upper()
	# Los letreros 3D que ya están en la ciudad se vuelven a escribir
	var tree := Engine.get_main_loop() as SceneTree
	if tree:
		for n in tree.get_nodes_in_group("i18n"):
			if n is Label3D and n.has_meta("src"):
				n.text = t(n.get_meta("src"))


## El idioma del sistema, si el juego lo tiene (para la primera vez que se abre).
static func system_code() -> String:
	var c := OS.get_locale_language()
	return c if c in CODES else "en"


static func index() -> int:
	return CODES.find(code)


## Nombre del idioma `i` (de CODES) en el idioma actual: "Inglés" si estás en español, "English" en inglés.
static func name_in(i: int) -> String:
	return NAMES_IN.get(code, NAMES_IN.es)[i]


## Mes abreviado ("feb", "Feb", "二月"...) a partir del nombre en español.
static func month_short(name: String) -> String:
	var m := t(name)
	if code == "zh":
		return m
	m = m.substr(0, 3)
	return m if code in ["en", "de"] else m.to_lower()


## Un nombre del juego traducido para ir en medio de una frase: en minúscula, salvo en alemán (los sustantivos van
## con mayúscula) y en chino (no tiene).
static func noun(name: String) -> String:
	var n := t(name)
	return n if code in ["de", "zh"] else n.to_lower()


## La frase traducida (o la misma, si no hay traducción).
static func t(s) -> String:
	var str_s := str(s)
	if _dict.is_empty():
		return str_s
	var out = _dict.get(str_s)
	if out != null:
		return out
	out = _upper.get(str_s)
	return str_s if out == null else out


## Plantilla con valores: traduce la plantilla y los valores que sean textos del juego, y los pone en su lugar.
static func f(tpl: String, args = []) -> String:
	var list: Array = args if args is Array else [args]
	if _dict.is_empty():
		return tpl % list
	var tr_tpl := t(tpl)
	var vals := list.map(func(v): return t(v) if v is String or v is StringName else v)
	if tr_tpl == tpl:
		return tpl % vals
	return _format(tr_tpl, vals, tpl, list)


## Formatea a mano para que la traducción pueda reordenar valores (%2$s) o saltarse uno (%_).
static func _format(tpl: String, vals: Array, fallback: String, raw: Array) -> String:
	var out := ""
	var pos := 0
	var next := 0
	for m in _spec.search_all(tpl):
		out += tpl.substr(pos, m.get_start() - pos)
		pos = m.get_end()
		var kind := m.get_string(3)
		if kind == "%":
			out += "%"
			continue
		var i := next
		if m.get_string(1) != "":
			i = int(m.get_string(1)) - 1
		else:
			next += 1
		if i < 0 or i >= vals.size():
			return fallback % raw   # traducción mal hecha: mejor en español que un error
		if kind == "_":
			continue
		out += ("%" + m.get_string(2) + kind) % vals[i]
	return out + tpl.substr(pos)
