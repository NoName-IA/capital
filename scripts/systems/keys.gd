class_name Keys
extends RefCounted
## Teclas configurables (Pausa, Controles). Se guardan por posición en el teclado (physical keycode), así W A S D
## quedan en su lugar en cualquier distribución. Esc, Alt y las flechas del tutorial no se cambian.

# [acción, nombre en pantalla, tecla por defecto, grupo]
const ACTIONS := [
	["forward", "Caminar hacia adelante", KEY_W, "MOVERTE"],
	["back", "Caminar hacia atrás", KEY_S, "MOVERTE"],
	["left", "Caminar a la izquierda", KEY_A, "MOVERTE"],
	["right", "Caminar a la derecha", KEY_D, "MOVERTE"],
	["run", "Correr (mantener)", KEY_SHIFT, "MOVERTE"],
	["jump", "Saltar", KEY_SPACE, "MOVERTE"],
	["camera", "Primera o tercera persona", KEY_V, "MOVERTE"],
	["interact", "Interactuar", KEY_E, "ACCIONES"],
	["phone", "Abrir el celular", KEY_TAB, "ACCIONES"],
	["office", "Ir a la oficina", KEY_O, "ACCIONES"],
	["pause_quick", "Pausa rápida (sin menú)", KEY_P, "JUEGO"],
	["speed1", "Velocidad x1", KEY_1, "JUEGO"],
	["speed2", "Velocidad x2", KEY_2, "JUEGO"],
	["speed3", "Velocidad x4", KEY_3, "JUEGO"],
	["music", "Música sí / no", KEY_M, "JUEGO"],
	["help", "Ayuda en pantalla", KEY_H, "JUEGO"],
	["fullscreen", "Pantalla completa", KEY_F11, "JUEGO"],
]
const FIXED := [KEY_ESCAPE, KEY_ALT]

static var map := {}


static func defaults() -> Dictionary:
	var d := {}
	for a in ACTIONS:
		d[a[0]] = a[2]
	return d


## Toma las teclas guardadas en los ajustes (las que falten quedan por defecto).
static func load_from(saved) -> void:
	map = defaults()
	if saved is Dictionary:
		for k in saved:
			if map.has(k):
				map[k] = int(saved[k])


static func code(action: String) -> int:
	return map.get(action, KEY_NONE)


static func pressed(action: String) -> bool:
	return Input.is_physical_key_pressed(code(action))


static func is_event(e: InputEventKey, action: String) -> bool:
	return e.physical_keycode == code(action)


## Nombre de la tecla para mostrar (según la distribución del teclado).
static func label(action: String) -> String:
	return key_name(code(action))


static func key_name(physical: int) -> String:
	var k := DisplayServer.keyboard_get_keycode_from_physical(physical)
	var names := {KEY_SPACE: "Espacio", KEY_SHIFT: "Shift", KEY_TAB: "Tab", KEY_CTRL: "Ctrl", KEY_ENTER: "Enter",
			KEY_BACKSPACE: "Borrar", KEY_CAPSLOCK: "Bloq Mayús", KEY_UP: "Arriba", KEY_DOWN: "Abajo", KEY_LEFT: "Izquierda", KEY_RIGHT: "Derecha"}
	if names.has(k):
		return names[k]
	return OS.get_keycode_string(k if k != KEY_NONE else physical)


## Asigna una tecla a una acción. Si otra acción la usaba, le pasa la tecla vieja (intercambio). Devuelve la acción
## que cambió de tecla, o "".
static func assign(action: String, physical: int) -> String:
	if physical in FIXED:
		return ""
	var old: int = map[action]
	var swapped := ""
	for k in map:
		if k != action and map[k] == physical:
			map[k] = old
			swapped = k
	map[action] = physical
	return swapped


static func name_of(action: String) -> String:
	for a in ACTIONS:
		if a[0] == action:
			return a[1]
	return action
