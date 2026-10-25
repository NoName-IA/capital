class_name City
extends Node3D
## La ciudad 3D: construye el mundo y lo mantiene sincronizado con la simulación (locales, competencia, clientes,
## autos), mueve al jugador y la cámara, y reacciona a lo que pasa en la empresa.

# (x, lado de la calle). Los índices 8, 9, 12 y 13 están en la playa (D.BEACH_PLOTS); el centro del lado sur
# es el Parque Central.
const PLOTS := [[-55, 1], [-33, 1], [-11, 1], [11, 1], [33, 1], [55, 1], [-55, -1], [-33, -1], [121, 1], [121, -1],
		[33, -1], [55, -1], [143, 1], [143, -1]]
const HQ := [-80, 1]
# Locales de la competencia en los extremos de la calle (no se pueden comprar como terreno).
const COMP_PLOTS := [[77, 1], [77, -1], [-77, -1], [99, 1], [99, -1], [-99, -1], [-99, 1]]
const SIDEWALK := 7.5
const BOUNDS := [-100.0, 200.0, -58.0, 58.0]  # incluye el barrio, el parque, la playa y la orilla del mar
const WADE_DEPTH := 0.75   # hasta dónde se puede entrar al mar (metros bajo el agua)
const MAX_CUSTOMERS := 30
static var config_path := "user://config.json"
const DEFAULT_SETTINGS := {"music": 0.7, "effects": 0.8, "sensitivity": 1.0, "fov": 70.0, "invert_y": false,
		"fullscreen": false, "day_night": true, "comments": true, "help": true, "blur": true,
		"tutorial_seen": false,
		"quality": 1, "g_shadows": 2, "g_ao": false, "g_glow": true, "g_aa": 0, "g_flare": true,  # gráficos: ver Graphics
		"keys": {},   # teclas cambiadas en Controles (ver Keys)
		# Gráficos extra (no cambian el nivel): ver Graphics.apply
		"g_shadow_dist": 1, "g_shadow_soft": 0, "g_glow_amt": 1.0, "g_bright": 1.0, "g_contrast": 1.0, "g_sat": 1.0,
		"g_tonemap": 0, "g_fog": true, "g_rain": true, "g_night_lights": true, "g_fps_limit": 1, "g_vsync": true,
		"g_view": 3, "g_crowd": 1, "g_show_fps": false,
		"window": []}   # posición y tamaño de la ventana (modo ventana): [x, y, ancho, alto]

var main
var app: Admin
var overlays: Overlays
var hud: Hud
var sfx: Sfx
var thumbs: Thumbs
var builder: WorldBuilder
var sky: SkyLight
var camera: Camera3D
var ao: MeshInstance3D
var flare: MeshInstance3D
var static_rects := []
var hq: Building
var hq_spots := {}
var settings := {}
var game = null
var stores := {}     # índice de terreno -> Store
var lots := {}       # índice de terreno -> {root, manage}
var comps := {}      # "c3" (local fijo de los extremos) o "p5" (terreno que compró el rival) -> competidor
var customers := []
var pops := []
var bubbles := []        # globos de diálogo de los NPC (ver say)
var cars_frozen := false  # en pausa los autos se quedan quietos y chocan como obstáculos
var cars := []
var player: Person
var serving = null
var first_person := false
var zoom := 6.0
var zoom_target := 6.0
var yaw := 0.0
var pitch := 18.0
var vy := 0.0
var prompt_action = null
var sync_timer := 0.0
var seen_news = null
var pause_prev := false
var knock = null
var shake := 0.0
var tip_i := 0
var trophy_count := -1
var mouse_delta := Vector2.ZERO
var alt_combo := true
var custom_prev := []
var custom_yaw := 0.0
var custom_pitch := 8.0
var custom_zoom := 5.6
var custom_dist := 5.6
var custom_lift := 0.0
var custom_idle := 0.0
var custom_drag = null     # [última posición del mouse, "left" o "right"]
var weather: Weather
var life: CityLife
var diario_t := 0.0
var tutorial_pending := false
var tutorial_prev := false
var spot_rig: Node3D       # reflectores del armario: alumbran al personaje de abajo hacia arriba, de día y de noche
var assistant: Person
var board_text: Label3D
var ticker_text: Label3D
var trophies_node: Node3D
var cam_target := Vector3.ZERO
const SKY_DAY_SECONDS := 60.0   # segundos reales que dura un día completo (sol y luna) en el cielo
var sky_t := 0.0           # punto del ciclo de 24 horas que se ve (ver SkyLight.set_time): sigue a cualquier velocidad
var sky_lock = null        # hora fija elegida con los botones Día / Tarde / Noche (null = el día corre)
var sky_game = null        # la partida de la que es esta hora (al cambiar de partida vuelve a las 6:00)


func _init(owner_main) -> void:
	main = owner_main


func _ready() -> void:
	Icons.setup(self)
	Mats.setup()
	settings = load_settings()
	builder = WorldBuilder.new(self)
	builder.build()
	static_rects = builder.rects
	hq = builder.hq
	hq_spots = hq.spots
	sky = SkyLight.new(self)
	weather = Weather.new(self)
	life = CityLife.new(self)
	camera = Camera3D.new()
	camera.near = 0.1
	camera.far = 1400
	add_child(camera)
	camera.make_current()
	ao = Graphics.make_overlay(camera, "res://shaders/ao.gdshader")
	flare = Graphics.make_overlay(camera, "res://shaders/lens_flare.gdshader")
	sky.flare_mat = flare.mesh.material
	sfx = Sfx.new()
	add_child(sfx)
	thumbs = Thumbs.new()
	add_child(thumbs)
	player = Person.new(null, null, false, Wardrobe.DEFAULT_LOOK)
	add_child(player)
	player.visible = false
	_build_office()
	for spec in [[-1, -80], [-1, 10], [1, 60], [1, -30], [-1, 70]]:
		cars.append(Actors.car(self, spec[0], spec[1]))


func setup_ui(admin: Admin, ui: ImUI, hud_parent: RID) -> void:
	app = admin
	overlays = Overlays.new(self, ui, admin)
	hud = Hud.new(self, hud_parent)
	apply_settings()
	restore_window()
	if settings.fullscreen and not is_fullscreen():
		toggle_fullscreen()
	overlays.show("admin")


# ---------- ajustes ----------
func load_settings() -> Dictionary:
	var s := DEFAULT_SETTINGS.duplicate()
	var text := FileAccess.get_file_as_string(config_path)
	var data = JSON.parse_string(text) if text else null
	if data is Dictionary:
		for k in data:
			if s.has(k) and typeof(data[k]) in [TYPE_FLOAT, TYPE_INT, TYPE_BOOL]:
				s[k] = data[k]
		if data.get("keys") is Dictionary:
			s.keys = data.keys
		if data.get("window") is Array and data.window.size() == 4:
			s.window = data.window.map(func(v): return int(v))
	# Siempre activos (ya no se pueden apagar): ciclo de día y noche, comentarios de los clientes y ayuda al empezar
	s.day_night = true
	s.comments = true
	s.help = true
	Keys.load_from(s.keys)
	return s


func save_settings() -> void:
	remember_window()
	settings.keys = Keys.map.duplicate()
	Admin.write_file(config_path, JSON.stringify(settings, "  "))


func apply_settings() -> void:
	sfx.music_volume = settings.music
	sfx.effects_volume = settings.effects
	camera.fov = settings.fov
	Graphics.apply(settings, get_viewport(), sky, ao, flare)
	camera.far = Graphics.VIEW_DIST[int(settings.g_view)]
	weather.show_rain = settings.g_rain


## Cuánta gente anda por la ciudad según el ajuste de Rendimiento: [peatones, clientes como máximo].
func crowd() -> Array:
	return [[5, 16], [10, 30], [16, 42]][int(settings.get("g_crowd", 1))]


func is_fullscreen() -> bool:
	return DisplayServer.window_get_mode() in [DisplayServer.WINDOW_MODE_FULLSCREEN, DisplayServer.WINDOW_MODE_EXCLUSIVE_FULLSCREEN]


## Cambia según cómo está la ventana de verdad (antes seguía una variable que se podía desfasar, por ejemplo al
## salir con Alt+Tab, y entonces F11 no sacaba la pantalla completa).
func toggle_fullscreen() -> void:
	var go_full := not is_fullscreen()
	if go_full:
		remember_window()
	DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN if go_full else DisplayServer.WINDOW_MODE_WINDOWED)
	if not go_full:
		restore_window()
	settings.fullscreen = go_full


## Guarda dónde estaba la ventana y su tamaño (solo en modo ventana normal, no maximizada).
func remember_window() -> void:
	if DisplayServer.window_get_mode() != DisplayServer.WINDOW_MODE_WINDOWED:
		return
	var pos := DisplayServer.window_get_position()
	var size := DisplayServer.window_get_size()
	settings.window = [pos.x, pos.y, size.x, size.y]


## Pone la ventana como la dejaste la última vez. Si no hay nada guardado, o ya no cabe (por ejemplo, cambiaste de
## monitor), usa el 80 % del espacio libre de la pantalla (sin la barra de tareas) y la centra.
func restore_window() -> void:
	if DisplayServer.window_get_mode() != DisplayServer.WINDOW_MODE_WINDOWED:
		return
	var free := DisplayServer.screen_get_usable_rect(DisplayServer.window_get_current_screen())
	var w: Array = settings.get("window", [])
	var rect := Rect2i()
	if w.size() == 4:
		rect = Rect2i(w[0], w[1], w[2], w[3])
	if rect.size.x < 320 or rect.size.y < 200 or not free.intersects(rect):
		var size := Vector2i(Vector2(free.size) * 0.8)
		size.x = mini(size.x, size.y * 16 / 9)
		rect = Rect2i(free.position + (free.size - size) / 2, size)
	# Que no se salga: el tamaño no pasa del espacio libre (dejando lugar para la barra de título) y el borde superior
	# queda dentro de la pantalla para poder arrastrarla.
	rect.size = rect.size.min(free.size - Vector2i(16, 40))
	rect.position = rect.position.clamp(free.position + Vector2i(0, 32), free.end - rect.size - Vector2i(0, 8))
	DisplayServer.window_set_size(rect.size)
	DisplayServer.window_set_position(rect.position)


# ---------- mouse ----------
func capture_mouse() -> void:
	if not main.testing:
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED


func release_mouse() -> void:
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE


func mouse_captured() -> bool:
	return Input.mouse_mode == Input.MOUSE_MODE_CAPTURED


# ---------- oficina ----------
func _build_office() -> void:
	assistant = Person.new(Color8(40, 60, 110), Color8(40, 40, 45))
	add_child(assistant)
	assistant.position = Blueprints.to_world(HQ, -2.9, 9.0)
	assistant.rotation.y = PI
	board_text = Building.label(hq.root, "", Vector3(-7.64, 2.5, 11), 8, Color8(30, 40, 70), true, false)
	board_text.rotation.y = PI / 2
	ticker_text = Building.label(hq.root, "", Vector3(7.64, 2.6, 11), 9, Color8(120, 255, 120), true, false)
	ticker_text.rotation.y = -PI / 2
	# Pantalla de la computadora del vestíbulo
	var screen := Boxes.new()
	var sp: Vector3 = hq.spots.local_screen
	screen.box(sp + Vector3(0, 0, -0.03), Vector3(1.3, 0.77, 0.02), Color8(40, 70, 120))
	var mi := screen.node(hq.root, Mats.emissive, false)
	mi.name = "Pantalla"
	var screen_brand := Building.label(hq.root, "CAPITAL", sp + Vector3(0, 0.08, -0.05), 7, Blueprints.PALETTE.gold)
	screen_brand.set_meta("size", screen_brand.pixel_size)
	hq.brand.append(screen_brand)
	Building.label(hq.root, "Presiona E", sp + Vector3(0, -0.14, -0.05), 4, Color.WHITE, false)


func sync_office(g: Game) -> void:
	var wait := g.strategy_wait()
	board_text.text = "REUNIÓN DE ESTRATEGIA\n" + ("Lista: acércate y presiona E" if not wait else "Próxima en %d días" % wait)
	var chg := g.market_today * 100
	ticker_text.text = "BOLSA DE VALORES\nHoy %s%s%%\nTu fondo: %s" % ["+" if chg >= 0 else "", Fmt.num(chg, 1), Fmt.short(g.fund)]
	ticker_text.modulate = Color8(120, 255, 120) if chg >= 0 else Color8(255, 90, 90)
	if g.rank != trophy_count:
		build_trophies(g.rank)


## Un trofeo por cada título conseguido: bronce, plata, oro y diamante para los más altos.
func build_trophies(count: int) -> void:
	trophy_count = count
	if trophies_node:
		trophies_node.queue_free()
	trophies_node = Node3D.new()
	hq.root.add_child(trophies_node)
	var tiers := [Color8(176, 112, 60), Color8(176, 112, 60), Color8(200, 200, 210), Color8(200, 200, 210),
			Color8(240, 190, 60), Color8(240, 190, 60), Color8(120, 220, 240), Color8(120, 220, 240),
			Color8(120, 220, 240), Color8(255, 255, 255)]
	var b := Boxes.new()
	for i in min(count, 10):
		var x: float = -6.4 + (i % 5) * 0.5
		var y0: float = [1.15, 1.79][i / 5]
		var c: Color = tiers[i]
		b.box(Vector3(x, y0 + 0.03, 14.5), Vector3(0.2, 0.06, 0.2), Color8(60, 45, 30))
		b.box(Vector3(x, y0 + 0.12, 14.5), Vector3(0.05, 0.12, 0.05), c)
		b.box(Vector3(x, y0 + 0.26, 14.5), Vector3(0.2, 0.17, 0.2), c)
		for hx in [-0.13, 0.13]:
			b.box(Vector3(x + hx, y0 + 0.27, 14.5), Vector3(0.05, 0.1, 0.03), c)
	if not b.is_empty():
		var m := Mats.textured(null, 0.25)
		m.metallic = 0.8
		b.node(trophies_node, m, false)


func open_growth() -> void:
	app.tab = "crecimiento"
	overlays.show("admin")


func show_trophies() -> void:
	overlays.show("trofeos")
	sfx.play("record", 0.5)


## La asistente da el consejo más importante del momento (rota entre los consejos disponibles).
func ask_assistant() -> void:
	var g: Game = game
	var tips: Array = g.advisories().map(func(t): return t[1])
	if not g.strategy_wait():
		tips.push_front("La pizarra está lista: haz la reunión de estrategia del mes.")
	if tips.is_empty():
		tips = ["Todo en orden, jefe. Este mes llevamos %s de utilidad." % Fmt.money(Game.statement(g.ledger).utilidad_neta)]
	var text: String = tips[tip_i % tips.size()]
	tip_i += 1
	hud.notes.push("oficina", "Sofía · tu asistente", text, {"initials": "SO", "sound": "ring"})


func manage_market(key: String) -> void:
	app.tab = "negocios"
	app.sel = key
	overlays.show("admin")


func manage(store: Store) -> void:
	app.tab = "negocios"
	app.sel = store.loc.product
	overlays.show("admin")


## Te lleva al vestíbulo de la oficina central, frente a la computadora.
func go_to_office() -> void:
	if game == null:
		return
	stop_serving()
	knock = null
	player.rotation.x = 0
	player.position = hq_spots.computer + Vector3(0, 0, -1.5)
	player.rotation.y = 0.0
	yaw = 0.0
	pitch = 12.0
	vy = 0.0
	sfx.play("record", 0.5, 1.4)
	toast("Llegaste a la oficina central.", "info")


func start_serving(store: Store) -> void:
	if serving:
		stop_serving()
	serving = store
	store.loc.owner = true
	player.position = store.spots.serve
	player.rotation.y = store.spots.face_yaw
	toast("Estás atendiendo: tu sucursal gana la capacidad de un empleado más sin pagar salario.", "info")


func stop_serving() -> void:
	if serving:
		serving.loc.owner = false
	serving = null


# ---------- armario ----------
func apply_look() -> void:
	player.restyle(game.look)


func use_wardrobe() -> void:
	var g: Game = game
	if not g.wardrobe:
		var res := g.unlock_wardrobe()
		toast(res[1], "good" if res[0] else "bad")
		sfx.play("record" if res[0] else "angry", 0.6)
		if not res[0]:
			return
	open_custom()


func open_custom() -> void:
	if app.view != "game" or app.modal != null or game == null or overlays.open():
		return
	custom_prev = [app.paused, first_person, player.rotation.y]
	app.paused = true
	first_person = false
	custom_yaw = yaw
	custom_drag = null
	reset_custom_view()
	_show_spotlights()
	overlays.show("personaje")


## Dos reflectores en el piso, adelante y a los lados del personaje, apuntándolo de abajo hacia arriba, más una luz
## suave de frente: así se ve bien la ropa a cualquier hora.
func _show_spotlights() -> void:
	if spot_rig == null:
		spot_rig = Node3D.new()
		add_child(spot_rig)
		for side in [-1, 1]:
			var at := Vector3(side * 1.0, 0, 0.95)
			var b := Boxes.new()
			b.box(Vector3(0, 0.08, 0), Vector3(0.5, 0.16, 0.5), Color8(30, 30, 34))          # base
			b.box(Vector3(0, 0.3, 0), Vector3(0.08, 0.3, 0.08), Color8(30, 30, 34))           # pie
			var head := Boxes.new()
			head.box(Vector3(0, 0, 0), Vector3(0.42, 0.42, 0.36), Color8(25, 25, 28))
			var lamp := Node3D.new()
			lamp.position = at
			spot_rig.add_child(lamp)
			b.node(lamp, Mats.smooth)
			var pivot := Node3D.new()
			pivot.position = Vector3(0, 0.55, 0)
			lamp.add_child(pivot)
			head.node(pivot, Mats.smooth)
			var lens := Boxes.new()
			lens.box(Vector3(0, 0, -0.185), Vector3(0.34, 0.34, 0.02), Color8(255, 245, 220))
			lens.node(pivot, Mats.emissive, false)
			var light := SpotLight3D.new()
			light.light_color = Color(1.0, 0.95, 0.85)
			light.light_energy = 2.4
			light.spot_range = 7.0
			light.spot_angle = 32.0
			light.spot_attenuation = 0.6
			pivot.add_child(light)
			pivot.look_at_from_position(at + Vector3(0, 0.55, 0), Vector3(0, 1.5, 0), Vector3.UP)  # a la cara y el pecho
			pivot.position = Vector3(0, 0.55, 0)
		var fill := OmniLight3D.new()
		fill.position = Vector3(0, 2.4, 2.2)
		fill.light_color = Color(0.95, 0.97, 1.0)
		fill.light_energy = 0.9
		fill.omni_range = 6.0
		spot_rig.add_child(fill)
	spot_rig.position = player.position
	spot_rig.rotation.y = player.rotation.y   # de frente al personaje, del lado de la cámara
	spot_rig.visible = true


func reset_custom_view() -> void:
	custom_pitch = 8.0
	custom_zoom = 5.6
	custom_lift = 0.0
	custom_idle = 0.0
	player.rotation.y = deg_to_rad(custom_yaw) + PI  # mirando a la cámara


func turn_custom(degrees: float) -> void:
	player.rotation.y += deg_to_rad(degrees)
	custom_idle = 0.0


func zoom_custom(step: float) -> void:
	custom_zoom = clampf(custom_zoom + step, 1.6, 9.0)
	custom_idle = 0.0


func close_custom() -> void:
	if overlays.mode != "personaje":
		return
	overlays.hide()
	app.paused = custom_prev[0]
	first_person = custom_prev[1]
	player.rotation.y = custom_prev[2]
	if spot_rig:
		spot_rig.visible = false


func open_pause() -> void:
	if app.view != "game" or app.modal != null or overlays.open():
		return
	pause_prev = app.paused
	app.paused = true
	overlays.pause_page = "main"
	overlays.show("pausa")


func close_pause() -> void:
	if overlays.mode == "pausa":
		overlays.hide()
		app.paused = pause_prev
	save_settings()


func quit_game() -> void:
	save_on_exit()
	get_tree().quit()


func save_on_exit() -> void:
	save_settings()
	if app and app.game != null:
		for loc in app.game.locations:
			loc.owner = false
		app.save(true)


func toast(text: String, kind := "info") -> void:
	hud.notes.hint(text, kind)


# ---------- textos que flotan sobre la gente ----------
func pop(pos: Vector3, text: String, kind: String, size := 16.0, life := 1.2) -> void:
	var cols := {"green": Color8(120, 255, 120), "red": Color8(255, 80, 80), "orange": Color8(255, 170, 60), "white": Color.WHITE}
	var l := Label3D.new()
	l.text = text
	l.font = Building.title_font
	l.font_size = 48
	l.pixel_size = size * 0.0011
	l.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	l.outline_size = 8
	l.outline_modulate = Color(0, 0, 0, 0.6)
	l.modulate = cols[kind]
	l.no_depth_test = false
	add_child(l)
	l.position = pos + Vector3(0, 2.5, 0)
	pops.append([l, life])


## Globo de diálogo sobre la cabeza de alguien (lo sigue mientras camina). Uno por persona: el nuevo reemplaza al
## anterior. `kind` es el color: white, green, orange, red o gold.
func say(person: Node3D, text: String, kind := "white", life := 2.4) -> void:
	if not is_instance_valid(person) or not settings.comments:
		return
	if person.camera_far():
		return
	var old = person.get_meta("bubble") if person.has_meta("bubble") else null
	if old != null and is_instance_valid(old):
		old.queue_free()
	var cols := {"green": Color8(150, 255, 150), "red": Color8(255, 120, 110), "orange": Color8(255, 190, 90),
			"gold": Color8(255, 215, 90), "white": Color.WHITE}
	var l := Label3D.new()
	l.text = text
	l.font = Building.title_font
	l.font_size = 40
	l.pixel_size = 0.0068
	l.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	l.outline_size = 12
	l.outline_modulate = Color(0.05, 0.06, 0.09, 0.85)
	l.modulate = cols.get(kind, Color.WHITE)
	l.width = 420
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.position = Vector3(0, 2.3, 0)
	l.no_depth_test = false
	person.add_child(l)
	person.set_meta("bubble", l)
	person.set_meta("bubble_t", life)
	bubbles.append(l)
	l.set_meta("life", life)


## Volumen según la distancia a la cámara: lo que pasa lejos casi no se oye.
func near(pos: Vector3) -> float:
	return clampf(1.0 - pos.distance_to(camera.global_position) / 28.0, 0, 1)


func pay(store: Store, pos: Vector3) -> void:
	var p: Dictionary = game.products[store.loc.product]
	var units: float = max(1.0, roundf(store.loc.sold / 60.0))
	var amount: float = p.price * units
	pop(pos, "+" + Fmt.money(amount, 2 if amount < 100 else 0), "green")
	sfx.play("coin", 0.55 * near(pos), randf_range(0.95, 1.08))
	# Lo que dicen los clientes refleja tus decisiones: precio, calidad, reputación y si atiendes tú.
	var ratio: float = p.price / game.ref_price(p)
	var lines := []
	if ratio > 1.25:
		lines += [["¡Qué caro!", "orange"], ["Uf, carísimo...", "orange"]]
	elif ratio < 0.85:
		lines += [["¡Qué barato!", "white"], ["¡Una ganga!", "white"]]
	if p.quality == 2:
		lines += [["¡Delicioso!", "white"], ["¡Calidad top!", "white"]]
	elif p.quality == 0:
		lines += [["Mmm... meh", "orange"]]
	if p.reputation > 75:
		lines += [["¡Me encanta este lugar!", "white"], ["¡El mejor de la ciudad!", "white"]]
	elif p.reputation < 30:
		lines += [["Dicen que aquí es malo...", "orange"]]
	if serving == store:
		lines += [["¡Gracias, jefe!", "white"], ["¡Qué buena atención!", "white"]]
	if lines and settings.comments and randf() < 0.3:
		var line: Array = lines.pick_random()
		pop(pos + Vector3(0, 0.55, 0), line[0], line[1], 10, 1.8)


## Qué tan probable es que un cliente que duda termine comprando en este local: mejor con más estrellas, precio
## bajo, buena calidad y buena reputación (se usa en las conversaciones de los clientes).
func buy_chance(store) -> float:
	var p: Dictionary = game.products[store.loc.product]
	var ratio: float = p.price / game.ref_price(p)
	var chance: float = 0.55 + 0.1 * (Game.stars_of(store.loc) - 3.0) + 0.5 * (1.0 - ratio) + 0.06 * (p.quality - 1)
	chance += 0.15 * (p.reputation - 50.0) / 50.0
	return clampf(chance, 0.08, 0.95)


func complain(pos: Vector3, store) -> void:
	pop(pos, "!", "red")
	sfx.play("angry", 0.45 * near(pos), randf_range(0.9, 1.15))
	if store == null or not settings.comments or randf() > 0.6:
		return
	var p: Dictionary = game.products[store.loc.product]
	var name: String = D.PRODUCTS[p.key].name.to_lower()
	var lines := []
	if p.last_sold < min(p.last_demand, p.last_capacity) * 0.95:
		lines = ["¿No hay %s?" % name, "¡Se les acabó todo!"]
	else:
		lines = ["¡Qué fila!", "¡Nadie atiende!", "Me voy donde %s..." % D.rival_for(p.key).short, "¡Llevo horas esperando!"]
	pop(pos + Vector3(0, 0.55, 0), lines.pick_random(), "orange", 10, 1.8)


# ---------- reacciones a lo que pasa en la empresa ----------
func watch_news(g: Game) -> void:
	var fresh := []
	for i in range(g.news.size() - 1, -1, -1):
		if is_same(g.news[i], seen_news):
			break
		fresh.append(g.news[i])
	seen_news = g.news[-1] if g.news else null
	fresh = fresh.slice(0, 8)
	fresh.reverse()
	for n in fresh:
		react(n)


func react(n: Dictionary) -> void:
	var fx = n.get("fx")
	var v = n.get("value")
	var notes := hud.notes
	var gold := Color8(240, 175, 40)
	var green := Color8(46, 170, 90)
	var red := Color8(225, 85, 75)
	var orange := Color8(240, 140, 50)
	match fx:
		"rank":
			notes.push_hero("NUEVO RANGO", v, "Tu empresa vale %s. ¡Sigue así!" % Fmt.money(game.valuation()), gold, "fanfare", 140)
		"win":
			if game.mode == "normal":
				notes.push_hero("IMPERIO", "¡Construiste un imperio!", "En %d minutos de juego" % roundi(game.win_seconds / 60.0), gold, "fanfare", 180, null, "crown")
			else:
				notes.push_hero("MIL MILLONARIO", "¡Llegaste a la cima!", "El título más alto del juego", gold, "fanfare", 180, null, "crown")
		"record":
			notes.push_hero("RÉCORD DE VENTAS", "{}", "vendidos en un solo día", green, "record", 50, v, "chart")
		"streak":
			notes.push_hero("RACHA", "¡%d meses ganando!" % v, "Tu racha de meses con utilidad sigue viva", orange, "good", 40, null, "heart")
		"streak_lost":
			notes.push("banco", "Se cortó tu racha", "Llevabas %d meses seguidos con utilidad. ¡Puedes empezar otra!" % v, {"col": red, "sound": "bad"})
		"month":
			var title: String = n.text.split(":")[0]
			if v >= 0:
				notes.push("banco", title, "Ganaste {} este mes.", {"count": v, "sound": "month"})
			else:
				notes.push("banco", title, "Este mes perdiste {}.", {"count": v, "col": red, "sound": "bad"})
		"danger":
			notes.push("alerta", "¡Cuidado, peligro de quiebra!", "Tienes 20 días para volver dentro del límite de sobregiro.", {"sound": "bad"})
		"outcome":
			var spec: Array = {"good": ["¡Salió bien!", green, "good"], "bad": ["Salió mal...", red, "bad"]}.get(v, ["Decisión tomada", orange, null])
			notes.push("decision", spec[0], n.text, {"col": spec[1], "sound": spec[2]})
		"dilemma":
			sfx.play("ring", 0.8)
			notes.push("decision", n.text.trim_prefix("Decisión urgente: "), "Decisión urgente: el juego espera tu respuesta.")
		"rival":
			var r := D.rival_by_key(v)
			var initials := ""
			for w in r.name.replace("Dr. ", "").replace("Doña ", "").split(" ").slice(0, 2):
				initials += w[0]
			var said: String = n.text.split(": «", true, 1)[-1].trim_suffix("»")
			notes.push("mensajes", "%s · %s" % [r.name, r.company], "«%s»" % said, {"col": r.color, "initials": initials, "sound": "rival", "low": true})
		"weather":
			var wd: Dictionary = D.WEATHER[v]
			var nxt: Dictionary = D.WEATHER[game.weather_next]
			notes.push("clima", wd.name, "%s Pronóstico: %s en %d días." % [n.text, nxt.name.to_lower(), game.weather_days],
					{"col": Color8(255, 120, 60) if v == 4 else (Color8(225, 85, 75) if v == 5 else Color8(90, 170, 230)), "icon": Icons.weather(v)})
		"stars":  # sin aviso: las estrellas saltan sobre el local (y queda en Noticias)
			var up: bool = v[2]
			for st in stores.values():
				if int(st.loc.id) == int(v[0]):
					st.star_burst(up)
		"quiet":
			pass
		"gameover":
			sfx.play("bad")
			notes.push("alerta", "Quiebra", n.text)
		null:
			var col: Color = {"good": green, "bad": red, "warn": orange}.get(n.kind, Color8(70, 140, 230))
			notes.push("noticias", n.text, "", {"col": col})


# ---------- luz y día ----------
## La hora del día que se ve. Corre a su propio ritmo (un día completo por minuto) aunque el juego vaya más rápido
## (si siguiera a la simulación, en x3 sería de día y de noche varias veces por segundo), y se detiene en pausa.
func day_fraction() -> float:
	if game == null:
		return 0.34
	return sky_lock if sky_lock != null else sky_t


func advance_sky(dt: float) -> void:
	if game != sky_game:
		sky_game = game
		sky_t = 0.0
	if game != null and not app.paused and app.modal == null and not game.game_over:
		# A más velocidad de juego, el día pasa más rápido también en el cielo (x2 = el doble, x4 = cuatro veces)
		var mult: float = Admin.SPEEDS[app.speed][0] / Admin.SPEEDS[0][0]
		sky_t = fmod(sky_t + dt * mult / SKY_DAY_SECONDS, 1.0)


## Botones Día / Tarde / Noche: fijan la luz en esa hora; apretar de nuevo el mismo deja correr el día otra vez.
func set_sky_lock(t: float) -> void:
	sky_lock = null if sky_lock == t else t


# ---------- sincronización con la simulación ----------
func reset_world(g) -> void:
	for s in stores.values():
		s.destroy()
	for l in lots.values():
		l.root.queue_free()
	for c in customers:
		c.destroy()
	stores = {}
	lots = {}
	customers = []
	serving = null
	if hud:
		hud.notes.clear()
	app.unread = 0
	for c in comps.values():
		Actors.free_competitor(c)
	comps = {}
	game = g
	player.visible = g != null
	if g != null:
		for loc in g.locations:
			loc.owner = false
		seen_news = g.news[-1] if g.news else null
		hq.set_brand(g.company)
		g.look = Wardrobe.full_look(g.look)
		player.restyle(g.look)
		knock = null
		player.rotation.x = 0
		player.position = Blueprints.to_world(HQ, 0, -2.5)
		yaw = 0.0
		player.rotation.y = 0.0
		pitch = 15.0
		hud.help_timer = 30.0 if settings.help else 0.0
		sync(g)


func sync(g: Game) -> void:
	var used := {}
	for loc in g.locations:
		var plot = loc.get("plot")
		if plot != null and int(plot) >= 0 and not used.has(int(plot)):
			used[int(plot)] = true
		else:
			loc.plot = null
	for loc in g.locations:
		if loc.plot == null:
			var free := []
			for i in PLOTS.size():
				if not used.has(i) and not g.rival_plots.has(str(i)):
					free.append(i)
			loc.plot = free[0] if free else -1
			if free:
				used[free[0]] = true
	var by_plot := {}
	for loc in g.locations:
		if int(loc.plot) >= 0:
			by_plot[int(loc.plot)] = loc
	for i in PLOTS.size():
		var loc = by_plot.get(i)
		var store = stores.get(i)
		if store != null and (loc == null or store.sig != [loc.id, loc.size, loc.product]):
			drop_store(i)
			store = null
		if loc != null and store == null:
			if lots.has(i):
				lots[i].root.queue_free()
				lots.erase(i)
			stores[i] = Store.new(self, i, loc)
		var rival := g.rival_plots.has(str(i))
		if rival and lots.has(i):
			lots[i].root.queue_free()
			lots.erase(i)
		if loc == null and not rival and not lots.has(i):
			lots[i] = Actors.lot(self, PLOTS[i], i, Fmt.short(g.location_cost(0)))
	for i in stores:
		var s: Store = stores[i]
		s.loc = by_plot[i]
		s.sync_staff()
		s.sync_stars()
	sync_competitors(g)
	sync_office(g)


## Qué competidores mostrar en los locales fijos de los extremos: hasta 3 por cada negocio que ya tienes y luego
## uno de cada mercado restante. Los que compraron un terreno de la avenida se muestran ahí.
func competitor_plan(g: Game) -> Array:
	var taken := {}
	for k in g.rival_plots.values():
		taken[k] = taken.get(k, 0) + 1
	var plan := []
	var unlocked := D.PRODUCT_ORDER.filter(func(k): return g.products[k].unlocked)
	var others := D.PRODUCT_ORDER.filter(func(k): return not g.products[k].unlocked)
	for spec in [[unlocked, 3], [others, 99]]:
		for r in spec[1]:
			for k in spec[0]:
				if g.products[k].competitors - taken.get(k, 0) > r and plan.size() < COMP_PLOTS.size():
					plan.append(k)
	return plan


## Mantiene los locales rivales en su lugar: solo quita o agrega los que cambiaron.
func sync_competitors(g: Game) -> void:
	for slot in comps.keys():
		if slot.begins_with("p") and g.rival_plots.get(slot.substr(1)) != comps[slot].key:
			Actors.free_competitor(comps[slot])
			comps.erase(slot)
	for i in g.rival_plots:
		if not comps.has("p" + i):
			comps["p" + i] = Actors.competitor(self, g.rival_plots[i], PLOTS[int(i)])
	var need := {}
	for k in competitor_plan(g):
		need[k] = need.get(k, 0) + 1
	for slot in comps.keys():
		if slot.begins_with("p"):
			continue
		var c: Dictionary = comps[slot]
		if need.get(c.key, 0) > 0:
			need[c.key] -= 1
		else:
			Actors.free_competitor(c)
			comps.erase(slot)
	for k in need:
		for n in need[k]:
			for i in COMP_PLOTS.size():
				if not comps.has("c%d" % i):
					comps["c%d" % i] = Actors.competitor(self, k, COMP_PLOTS[i])
					break


func drop_store(i: int) -> void:
	var store: Store = stores[i]
	stores.erase(i)
	if serving == store:
		stop_serving()
	for c in customers:
		if c.store == store:
			c.store = null
			c.line = null
			c.path = c.away.slice(c.away.size() - 1)
			c.state = "leave"
	store.destroy()


func spawn(dt: float) -> void:
	if app.paused or app.modal != null:
		return
	var walkers := 0
	for c in customers:
		if c.store == null:
			walkers += 1
	var limits := crowd()
	if walkers < limits[0] and randf() < dt * 0.7:
		customers.append(Customer.new(self))
	for store in stores.values():
		var loc: Dictionary = store.loc
		store.acc += clampf(loc.sold / 160.0, 0.04, 0.5) * dt
		if store.acc >= 1 and customers.size() < limits[1]:
			store.acc -= 1
			var lost: float = (loc.demand - loc.sold) / loc.demand if loc.demand > 0 else 0.0
			customers.append(Customer.new(self, store, randf() < clampf(lost, 0, 0.8)))


# ---------- choques ----------
func all_rects() -> Array:
	var out := [static_rects]
	for s in stores.values():
		out.append(s.rects)
	for c in comps.values():
		out.append(c.rects)
	if cars_frozen:  # detenidos en pausa no atropellan, pero tampoco se pueden atravesar: son como una pared
		var car_rects := []
		for car in cars:
			var p: Vector3 = car.position
			car_rects.append([p.x - 2.05, p.x + 2.05, p.z - 0.95, p.z + 0.95, 1.6])
		out.append(car_rects)
	return out


## El muelle de madera de la playa: se puede caminar hasta la punta, sobre el mar.
const PIER := [150.0, 205.0, 24.0, 1.1, 0.42]   # [x desde, x hasta, z del centro, medio ancho caminable, altura]


func on_pier(x: float, z: float) -> bool:
	return PIER[0] <= x and x <= PIER[1] and absf(z - PIER[2]) <= PIER[3]


const STEP_MAX := 1.2   # lo que mide menos que esto (setos, bancas, jardineras) se puede pisar subiéndose de un salto


## A qué altura pisa alguien en (x, z) con los pies a la altura `feet`: la tabla del muelle, la arena que baja hacia
## el mar, el suelo o algo bajo a lo que se subió (un seto, una banca).
func floor_at(x: float, z: float, feet := 0.0) -> float:
	if on_pier(x, z) and x >= Terrain.COAST - 1.0:
		return PIER[4]
	var h: float = min(0.0, Terrain.height(x, z)) if x > Terrain.COAST - 2.0 else 0.0
	for rects in all_rects():
		for q in rects:
			if q[4] <= STEP_MAX and q[4] <= feet + 0.3 and q[0] < x and x < q[1] and q[2] < z and z < q[3]:
				h = max(h, q[4])
	return h


func blocked(x: float, z: float, r := 0.38, feet := 0.0) -> bool:
	if on_pier(x, z):
		return false
	if x > Terrain.COAST and Terrain.height(x, z) < Terrain.SEA_LEVEL - WADE_DEPTH:
		return true  # más adentro el mar ya es hondo
	if not (BOUNDS[0] < x and x < BOUNDS[1] and BOUNDS[2] < z and z < BOUNDS[3]):
		return true
	for rects in all_rects():
		for q in rects:
			if q[0] - r < x and x < q[1] + r and q[2] - r < z and z < q[3] + r:
				if q[4] <= STEP_MAX and feet >= q[4] - 0.05:
					continue  # está arriba: puede caminar encima
				return true
	return false


func inside_wall(pos: Vector3) -> bool:
	for rects in all_rects():
		for q in rects:
			if pos.y < q[4] + 0.3 and q[0] - 0.2 < pos.x and pos.x < q[1] + 0.2 and q[2] - 0.2 < pos.z and pos.z < q[3] + 0.2:
				return true
	return false


## El techo del edificio donde está `pos` (oficina o local), o [] si está al aire libre.
func ceiling_over(pos: Vector3) -> Array:
	var spot_sets := [hq_spots]
	for s in stores.values():
		spot_sets.append(s.spots)
	for c in comps.values():
		spot_sets.append(c.spots)
	for sp in spot_sets:
		var c = sp.get("ceiling")
		if c != null and c[0] < pos.x and pos.x < c[1] and c[2] < pos.z and pos.z < c[3]:
			return c
	return []


## Qué tan lejos puede ir la cámara desde `target` en la dirección `back` sin meterse en una pared,
## atravesar el techo del edificio donde estás o bajar del suelo. Se calcula de una vez dónde el rayo choca con cada
## caja (antes se avanzaba de a 20 cm revisando todas las paredes en cada paso, y costaba varios milisegundos).
func camera_distance(target: Vector3, back: Vector3, want: float) -> float:
	var hit := want + 0.35
	if back.y < -0.0001:  # el suelo (la cámara no baja de 20 cm)
		hit = min(hit, (0.2 - target.y) / back.y)
	var roof := ceiling_over(target)
	if not roof.is_empty() and back.y > 0.0001:
		var t: float = (roof[4] - 0.3 - target.y) / back.y
		var px := target.x + back.x * t
		var pz := target.z + back.z * t
		if t >= 0 and roof[0] - 0.6 < px and px < roof[1] + 0.6 and roof[2] - 0.6 < pz and pz < roof[3] + 0.6:
			hit = min(hit, t)
	var reach := want + 1.0
	for rects in all_rects():
		for q in rects:
			# solo las cajas cerca del camino de la cámara
			if q[1] + 0.2 < min(target.x, target.x + back.x * reach) or q[0] - 0.2 > max(target.x, target.x + back.x * reach):
				continue
			if q[3] + 0.2 < min(target.z, target.z + back.z * reach) or q[2] - 0.2 > max(target.z, target.z + back.z * reach):
				continue
			var t := _ray_box(target, back, Vector3(q[0] - 0.2, -1.0, q[2] - 0.2), Vector3(q[1] + 0.2, q[4] + 0.3, q[3] + 0.2))
			if t < hit:
				hit = t
	return max(0.3, min(want, hit - 0.35))


## Distancia a la que un rayo entra a una caja (0 si ya está adentro, INF si no la toca).
static func _ray_box(o: Vector3, d: Vector3, lo: Vector3, hi: Vector3) -> float:
	var t0 := -INF
	var t1 := INF
	for i in 3:
		if absf(d[i]) < 0.000001:
			if o[i] < lo[i] or o[i] > hi[i]:
				return INF
		else:
			var a := (lo[i] - o[i]) / d[i]
			var b := (hi[i] - o[i]) / d[i]
			t0 = max(t0, min(a, b))
			t1 = min(t1, max(a, b))
	if t1 < max(t0, 0.0):
		return INF
	return max(t0, 0.0)


# ---------- atropello ----------
## Te atropella un auto: sales volando, rebotas, quedas tirado y te levantas.
func hit_by_car(car: Node3D) -> void:
	stop_serving()
	var away := 1.0 if player.position.z > car.position.z else -1.0
	knock = {"t": 0.0, "vel": Vector3(car.get_meta("dir") * car.get_meta("speed") * 0.9, 7.5, away * randf_range(2.5, 4.5)),
			"spin": (1 if randf() < 0.5 else -1) * randf_range(420, 620), "down": false, "lie": 0.0}
	car.set_meta("brake", 1.6)
	shake = 0.45
	pop(player.position, "¡Auch!", "red")
	sfx.play("angry", 0.9, 0.6)
	sfx.play("bad", 0.5, 1.3)
	toast("¡Te atropelló un auto! Cruza con cuidado.", "bad")


## Física simple del atropello: vuelo con gravedad, rebotes con fricción y levantarse.
func knocked(dt: float) -> void:
	var p := player
	var k: Dictionary = knock
	k.t += dt
	var v: Vector3 = k.vel
	if not k.down:
		v.y -= 22 * dt
		var nx := p.position.x + v.x * dt
		var nz := p.position.z + v.z * dt
		if blocked(nx, p.position.z):
			v.x *= -0.35
		else:
			p.position.x = nx
		if blocked(p.position.x, nz):
			v.z *= -0.35
		else:
			p.position.z = nz
		p.position.y = max(0.0, p.position.y + v.y * dt)
		p.rotation.x += deg_to_rad(k.spin) * dt
		if p.position.y <= 0 and v.y < 0:
			if v.y < -5:  # rebote
				v.y *= -0.3
				v.x *= 0.5
				v.z *= 0.5
				k.spin *= 0.4
			else:
				k.down = true
				k.t = 0.0
				k.lie = -PI / 2 if fposmod(p.rotation.x, TAU) > PI else PI / 2
	elif k.t < 1.6:  # tirado en el suelo, se desliza un poco
		p.rotation.x = lerp_angle(p.rotation.x, k.lie, dt * 12)
		p.position.x += v.x * dt * max(0.0, 1 - k.t * 2)
		p.position.z += v.z * dt * max(0.0, 1 - k.t * 2)
	else:  # se levanta
		p.rotation.x = lerp_angle(p.rotation.x, 0.0, dt * 6)
		if absf(wrapf(p.rotation.x, -PI, PI)) < 0.03:
			p.rotation.x = 0
			knock = null
	k.vel = v
	p.animate(0, dt)


# ---------- jugador y cámara ----------
func move_player(dt: float) -> void:
	var p := player
	if knock != null:
		knocked(dt)
		return
	var fwd := Vector3(sin(deg_to_rad(yaw)), 0, cos(deg_to_rad(yaw)))
	var right := Vector3(-fwd.z, 0, fwd.x)
	var f := float(Keys.pressed("forward")) - float(Keys.pressed("back"))
	var s := float(Keys.pressed("right")) - float(Keys.pressed("left"))
	var move := fwd * f + right * s
	if serving:
		if move.length() > 0:
			stop_serving()
		else:
			p.animate(0, dt)
			return
	var speed := 0.0
	if move.length() > 0:
		move = move.normalized()
		speed = 12.0 if Keys.pressed("run") else 5.0
		var nx := p.position.x + move.x * speed * dt
		var nz := p.position.z + move.z * speed * dt
		if not blocked(nx, p.position.z, 0.38, p.position.y):
			p.position.x = nx
		if not blocked(p.position.x, nz, 0.38, p.position.y):
			p.position.z = nz
		if not first_person:
			p.rotation.y = lerp_angle(p.rotation.y, atan2(move.x, move.z), dt * 12)
	if first_person:
		p.rotation.y = deg_to_rad(yaw)
	vy -= 22 * dt
	var ground := floor_at(p.position.x, p.position.z, p.position.y)
	p.position.y = max(ground, p.position.y + vy * dt)
	if p.position.y <= ground + 0.001:  # (la posición guarda menos decimales que 0.42: no comparar exacto)
		vy = 0.0
	p.animate(speed if p.position.y < ground + 0.05 else 0.0, dt)


func look_dir(yaw_deg: float, pitch_deg: float) -> Vector3:
	var cp := deg_to_rad(pitch_deg)
	var cy := deg_to_rad(yaw_deg)
	return Vector3(sin(cy) * cos(cp), -sin(cp), cos(cy) * cos(cp))


func update_camera(dt: float) -> void:
	if overlays.mode == "personaje":
		_custom_camera(dt)
		return
	if game == null or app.view == "menu":
		var t := Time.get_ticks_msec() / 1000.0 * 0.04
		camera.global_position = Vector3(cos(t) * 75, 38, sin(t) * 55)
		camera.look_at(Vector3(0, 0, 0))
		return
	if mouse_captured() and not overlays.open():
		var sens: float = 0.13 * settings.sensitivity
		yaw -= mouse_delta.x * sens
		pitch += mouse_delta.y * sens * (-1 if settings.invert_y else 1)
	mouse_delta = Vector2.ZERO
	pitch = clampf(pitch, -80 if first_person else -35, 80 if first_person else 70)
	var p := player
	var look := look_dir(yaw, pitch)
	if first_person:
		p.set_visible_parts(false)
		camera.global_position = p.position + Vector3(0, 1.75, 0) + Vector3(look.x, 0, look.z) * 0.25
	else:
		p.set_visible_parts(true)
		# Al mirar hacia arriba el punto que sigue la cámara sube: así no baja al suelo ni queda pegada a la espalda.
		var target := p.position + Vector3(0, 1.6 + 1.0 * clampf(-pitch / 35.0, 0, 1), 0)
		var roof := ceiling_over(p.position)
		if not roof.is_empty():  # bajo techo el punto que sigue la cámara no puede quedar pegado al cielo
			target.y = min(target.y, roof[4] - 0.6)
		zoom += (zoom_target - zoom) * min(1.0, dt * 10)
		camera.global_position = target - look * camera_distance(target, -look, zoom)
	camera.look_at(camera.global_position + look)
	if shake > 0:  # sacudón de cámara al chocar
		shake -= dt
		camera.global_position += Vector3(randf_range(-1, 1), randf_range(-1, 1), randf_range(-1, 1)) * shake * 0.35


## Armario: arrastrar con el clic izquierdo gira al personaje (y sube o baja la cámara); con el derecho mueve la
## vista hacia arriba o abajo; la rueda acerca y aleja (de cuerpo entero hasta la cara).
func _custom_camera(dt: float) -> void:
	var p := player
	p.set_visible_parts(true)
	if custom_drag != null:
		var d := mouse_delta
		if custom_drag == "left":
			p.rotation.y += d.x * 0.012
			custom_pitch = clampf(custom_pitch + d.y * 0.25, -25, 40)
		else:
			custom_lift = clampf(custom_lift + d.y * 0.008, -0.9, 0.9)
		custom_idle = 0.0
	else:
		custom_idle += dt
		if custom_idle > 2.0:  # si no lo tocas un rato, vuelve suave a mirar al frente
			var k := min(1.0, dt * 2.5)
			p.rotation.y = lerp_angle(p.rotation.y, deg_to_rad(custom_yaw) + PI, k)
			custom_pitch = lerpf(custom_pitch, 8.0, k)
			custom_lift = lerpf(custom_lift, 0.0, k)
	mouse_delta = Vector2.ZERO
	var turn := float(Keys.pressed("right")) - float(Keys.pressed("left"))
	if turn:
		p.rotation.y += turn * dt * 2.0
		custom_idle = 0.0
	custom_dist = lerpf(custom_dist, custom_zoom, min(1.0, dt * 8))
	var k := clampf((custom_dist - 1.6) / (9.0 - 1.6), 0, 1)  # 0 = la cara de cerca, 1 = cuerpo entero lejos
	var target := p.position + Vector3(0, lerpf(1.75, 1.0, k) + custom_lift, 0)
	var roof := ceiling_over(p.position)
	if not roof.is_empty():
		target.y = min(target.y, roof[4] - 0.5)
	var fwd := look_dir(custom_yaw, custom_pitch)
	var right := Vector3(-cos(deg_to_rad(custom_yaw)), 0, sin(deg_to_rad(custom_yaw)))
	var dist := camera_distance(target, -fwd, custom_dist)  # sin atravesar techo, suelo ni paredes
	camera.global_position = target - fwd * dist
	camera.look_at(target - right * dist * 0.27)  # el personaje queda a la derecha del panel


func update_zone() -> void:
	var p := player.position
	var z := ["Avenida Comercial", "Tus locales y la competencia"]
	if p.x < -66:
		z = ["Distrito Financiero", "Rascacielos y tu oficina central"]
	elif p.x > 110:
		z = ["Paseo de la Playa", "Terrenos frente al mar: +20% de clientes por los turistas"]
	elif absf(p.x) < 22 and p.z < -9:
		z = ["Parque Central", "La fuente, la laguna y los juegos"]
	elif absf(p.z) > 27:
		z = ["Barrio Las Lomas", "Donde viven tus clientes"]
	hud.set_zone(z)


# ---------- interacciones ----------
func interactables() -> Array:
	var items := []
	var g: Game = game
	items.append([hq_spots.computer, "Usar la computadora de la oficina", func(): overlays.show("admin")])
	items.append([hq_spots.board, "Pizarra: reunión de estrategia del mes", func(): overlays.show("estrategia")])
	items.append([hq_spots.ticker, "Pantalla de la bolsa: ver tu fondo de inversión", open_growth])
	items.append([hq_spots.trophies, "Vitrina de trofeos: tus títulos", show_trophies])
	items.append([hq_spots.assistant, "Hablar con tu asistente", ask_assistant])
	if g.wardrobe:
		items.append([hq_spots.wardrobe, "Abrir el armario: comprar ropa y cambiar tu aspecto", use_wardrobe])
	else:
		items.append([hq_spots.wardrobe, "Comprar el armario (%s): tienda de ropa" % Fmt.money(g.wardrobe_cost()), use_wardrobe])
	for i in stores:
		var store: Store = stores[i]
		var name := "%s de %s" % [D.SIZES[store.loc.size].name, D.PRODUCTS[store.loc.product].name.to_lower()]
		if serving == store:
			items.append([store.spots.serve, "Dejar de atender", stop_serving])
		else:
			items.append([store.spots.serve, "Atender el mostrador (+1 empleado gratis: tú)", start_serving.bind(store)])
		items.append([store.spots.manage, "Administrar %s" % name, manage.bind(store)])
	for i in lots:
		items.append([lots[i].manage, "Comprar el terreno %d" % (i + 1), func(): overlays.show("lote", i)])
	for c in comps.values():
		var name: String = D.PRODUCTS[c.key].name.to_lower()
		items.append([c.spots.manage, "Competencia: %s (%s). Ver cómo comprarla" % [c.rival.company, name], manage_market.bind(c.key)])
	return items


# ---------- ciclo ----------
func update(dt: float) -> void:
	dt = min(dt, 0.1)
	if app.view == "game" and app.game != null:
		app.update(dt)
	var g = app.game if app.view == "game" else null
	if g != game:
		reset_world(g)
		if g != null and overlays.open() and app.modal == null:
			overlays.hide()
		# Partida nueva por primera vez: el tutorial
		tutorial_pending = (g != null and g.day == 0 and not settings.tutorial_seen and not main.testing)
	if tutorial_pending and not overlays.open() and app.modal == null:
		tutorial_pending = false
		open_tutorial()
	if (app.view == "menu" or g == null) and not overlays.open():
		overlays.show("admin")
	if app.modal != null and not overlays.open():
		overlays.show("admin", -1, true)
	if overlays.open() and overlays.auto and app.modal == null:
		overlays.hide()

	if g != null:
		watch_news(g)
		sync_timer -= dt
		if sync_timer <= 0:
			sync_timer = 0.2
			sync(g)
		spawn(dt)
		if not overlays.open():
			move_player(dt)
		var best = null
		var best_d := 2.4
		for it in interactables():
			var pos: Vector3 = it[0]
			var dd := Vector2(pos.x - player.position.x, pos.z - player.position.z).length()
			if dd < best_d:
				best = it
				best_d = dd
		prompt_action = best
		hud.prompt = "[%s] %s" % [Keys.label("interact"), best[1]] if best != null else ""
		update_zone()
	for st in stores.values():
		st.update(dt)
	for c in customers.duplicate():
		c.update(dt)
		if c.done:
			c.destroy()
			customers.erase(c)
	var frozen: bool = g != null and (app.paused or app.modal != null)  # en pausa los autos también se detienen
	cars_frozen = frozen
	for car in cars:
		if frozen:
			continue
		Actors.drive(car, dt, cars)
		var p := player.position
		if (g != null and knock == null and not overlays.open() and p.y < 1.4 and absf(p.x - car.position.x) < 2.3
				and absf(p.z - car.position.z) < 1.15):
			hit_by_car(car)
	for b in bubbles.duplicate():
		if not is_instance_valid(b):
			bubbles.erase(b)
			continue
		var left: float = b.get_meta("life") - dt
		b.set_meta("life", left)
		b.modulate.a = clampf(left / 0.4, 0, 1)
		b.outline_modulate.a = clampf(left / 0.4, 0, 1) * 0.85
		if left <= 0:
			b.queue_free()
			bubbles.erase(b)
	for item in pops.duplicate():
		item[1] -= dt
		item[0].position.y += dt * 0.9
		item[0].modulate.a = clampf(item[1], 0, 1)
		item[0].outline_modulate.a = clampf(item[1], 0, 1) * 0.6
		if item[1] <= 0:
			item[0].queue_free()
			pops.erase(item)
	for b in builder.boats:
		var ph: float = b.get_meta("phase")
		var t := Time.get_ticks_msec() / 1000.0
		b.position.y = Terrain.SEA_LEVEL + sin(t * 1.1 + ph) * 0.12
		b.rotation.z = deg_to_rad(sin(t * 0.9 + ph) * 4)
	hud.update(dt)
	hud.update_danger(g, dt)
	if overlays.mode == "personaje":
		thumbs.step()
	advance_sky(dt)
	sky.moon_phase = fmod(game.day + 15.0, 29.5) / 29.5 if game != null else 0.5  # una fase por mes de juego
	sky.tick(dt)
	# El destello solo se dibuja con el sol de día y delante de la cámara: tapa la pantalla y cuesta aunque no se vea
	flare.visible = (Graphics.current(settings).g_flare and sky.night_amount < 0.99
			and -camera.global_transform.basis.z.dot(sky.to_sun) > 0.45)
	weather.update(dt, game, camera, camera_indoors())
	sky.clouds = weather.clouds
	sky.overcast = weather.overcast
	sky.set_time(day_fraction() if settings.day_night or sky_lock != null else 0.34)
	update_camera(dt)
	life.update(dt)
	diario_t -= dt
	if diario_t <= 0.0:
		diario_t = 0.5
		update_diario()


## ¿La cámara está bajo techo? (oficina o un local): ahí no llueve.
func camera_indoors() -> bool:
	var p := camera.global_position
	var roofs := [hq_spots.ceiling]
	for s in stores.values():
		if s.spots.get("ceiling") != null:
			roofs.append(s.spots.ceiling)
	for c in roofs:
		if c[0] < p.x and p.x < c[1] and c[2] < p.z and p.z < c[3] and p.y < c[4]:
			return true
	return false


## La pantalla del kiosco ELDIARIO: clima de hoy, temperatura, hora y pronóstico de mañana.
func update_diario() -> void:
	var dl: Dictionary = builder.diario
	var hour := SkyLight.hour_of(day_fraction())
	var w := weather
	dl.icon.region_rect = Icons.region(Icons.weather(w.today, sky.night_amount > 0.5))
	dl.temp.text = "%d°C" % w.temperature(hour)
	dl.kind.text = w.name_of(w.today)
	dl.hour.text = "%02d:%02d" % [int(hour), int(fmod(hour, 1.0) * 60)]
	var days: int = game.weather_days if game != null else 1
	dl.tomorrow.text = "En %d día%s: %s" % [days, "" if days == 1 else "s", w.name_of(w.tomorrow)]


func open_tutorial() -> void:
	tutorial_prev = app.paused
	app.paused = true
	overlays.tutorial_page = 0
	overlays.show("tutorial")


func close_tutorial() -> void:
	if overlays.mode != "tutorial":
		return
	overlays.hide()
	app.paused = tutorial_prev
	settings.tutorial_seen = true
	save_settings()


# ---------- teclado y mouse ----------
func input_event(event: InputEvent) -> void:
	if event is InputEventMouseMotion:
		mouse_delta += event.relative
		return
	if event is InputEventKey:
		_key(event)
	elif event is InputEventMouseButton:
		_mouse_button(event)


func _key(e: InputEventKey) -> void:
	# Cambiando una tecla en Controles: la próxima tecla que apretes queda asignada (Esc cancela)
	if overlays.binding != null:
		if e.pressed and not e.echo:
			overlays.finish_binding(e)
		return
	if e.keycode == KEY_ALT:
		if e.pressed:
			alt_combo = false
		elif not alt_combo and not overlays.open() and game != null:
			# Alt sola (apretar y soltar) alterna el mouse; si se usó para un atajo (Alt+Tab) no hace nada.
			if mouse_captured():
				release_mouse()
			else:
				capture_mouse()
		return
	if not e.pressed or e.echo:
		return
	if e.ctrl_pressed or e.alt_pressed or e.meta_pressed:
		alt_combo = true
		return
	var key := e.keycode
	if app.naming:  # escribiendo el nombre de la empresa: las teclas van al nombre
		app.type_key(e)
		return
	if app.settings_open and app.view == "menu" and key == KEY_ESCAPE:   # ajustes del menú de inicio
		if overlays.pause_page != "main":
			overlays.pause_page = "main"
		else:
			overlays.close_menu_settings()
		return
	if Keys.is_event(e, "fullscreen"):
		toggle_fullscreen()
		return
	if Keys.is_event(e, "music") and not (overlays.open() and app.view == "menu"):
		sfx.music_on = not sfx.music_on
		toast("Música activada." if sfx.music_on else "Música en silencio (%s para volver)." % Keys.label("music"), "info")
		return
	if overlays.mode == "tutorial":
		if key == KEY_ESCAPE:
			close_tutorial()
		elif key in [KEY_RIGHT, KEY_ENTER, KEY_SPACE]:
			overlays.tutorial_next()
		elif key == KEY_LEFT:
			overlays.tutorial_page = max(0, overlays.tutorial_page - 1)
		return
	if overlays.mode == "personaje":
		if key == KEY_ESCAPE:
			close_custom()
		elif key == KEY_R:
			reset_custom_view()
		return
	if overlays.mode == "pausa":
		if key == KEY_ESCAPE and overlays.pause_page != "main":
			overlays.pause_page = "main"
		elif key == KEY_ESCAPE:
			close_pause()
		return
	if overlays.open():
		if (key == KEY_ESCAPE or Keys.is_event(e, "phone") or Keys.is_event(e, "interact")) and app.view == "game" and app.modal == null:
			overlays.hide()
		return
	if game == null:
		return
	if key == KEY_ESCAPE:
		open_pause()
	elif Keys.is_event(e, "phone"):
		overlays.show("admin")
	elif Keys.is_event(e, "interact"):
		if prompt_action != null:
			prompt_action[2].call()
	elif Keys.is_event(e, "camera"):
		first_person = not first_person
		if not first_person:
			zoom_target = max(zoom_target, 3.0)
			zoom = zoom_target
	elif Keys.is_event(e, "pause_quick"):
		app.paused = not app.paused
	elif Keys.is_event(e, "speed1") or Keys.is_event(e, "speed2") or Keys.is_event(e, "speed3"):
		app.speed = 0 if Keys.is_event(e, "speed1") else (1 if Keys.is_event(e, "speed2") else 2)
		app.paused = false
	elif Keys.is_event(e, "jump"):
		if absf(player.position.y - floor_at(player.position.x, player.position.z, player.position.y)) < 0.02 and serving == null:
			vy = 8.0
	elif Keys.is_event(e, "office"):
		go_to_office()
	elif Keys.is_event(e, "help"):
		hud.help_timer = 0.0 if hud.help_timer > 0 else 30.0


func _mouse_button(e: InputEventMouseButton) -> void:
	if overlays.mode == "personaje":
		if e.button_index in [MOUSE_BUTTON_LEFT, MOUSE_BUTTON_RIGHT]:
			if e.pressed and not overlays.over_custom_ui():
				custom_drag = "left" if e.button_index == MOUSE_BUTTON_LEFT else "right"
			elif not e.pressed:
				custom_drag = null
		elif e.pressed and e.button_index in [MOUSE_BUTTON_WHEEL_UP, MOUSE_BUTTON_WHEEL_DOWN] and not overlays.over_custom_ui():
			zoom_custom(-0.6 if e.button_index == MOUSE_BUTTON_WHEEL_UP else 0.6)
		return
	if overlays.open() or game == null or not e.pressed:
		return
	if e.button_index == MOUSE_BUTTON_WHEEL_UP:  # acercarse; muy cerca pasa a primera persona
		if not first_person:
			zoom_target -= 0.75
			if zoom_target < 1.2:
				first_person = true
				zoom_target = 1.5
				zoom = 1.5
	elif e.button_index == MOUSE_BUTTON_WHEEL_DOWN:  # alejarse; desde primera persona vuelve a tercera
		if first_person:
			first_person = false
			zoom = 0.5
			zoom_target = 1.5
		else:
			zoom_target = min(12.0, zoom_target + 0.75)
	elif e.button_index == MOUSE_BUTTON_LEFT and not mouse_captured():
		if hud.ui.hover(hud.hq_button_rect()):
			go_to_office()
		elif hud.ui.hover(hud.phone_rect):
			if app.unread:
				app.tab = "noticias"
			overlays.show("admin")
		elif hud.sky_button_at() != null:
			set_sky_lock(hud.sky_button_at())
		else:
			capture_mouse()
