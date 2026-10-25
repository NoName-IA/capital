extends Node3D
## Escena principal de Capital: la ciudad 3D, el jugador y la interfaz (menús, celular, HUD y avisos).

var ui: ImUI          # menús y ventanas (pantalla virtual de 1280 × 760, centrada)
var app: Admin
var city: City
var blur_rect: ColorRect
var blur := 0.0
var mouse_clicked := false
var wheel := 0
var testing := false
var tablet := 0.0     # 0 = guardada, 1 = abierta en la mano (el celular de la empresa durante la partida)
var tablet_warm := false
var warmed_game = null    # partida para la que ya se dibujó la tablet una vez (ver abajo)
var warm_blur := 0       # cuadros que se dibuja el desenfoque casi invisible para prepararlo


func _ready() -> void:
	get_tree().set_auto_accept_quit(false)
	testing = Array(OS.get_cmdline_user_args()).any(func(a): return a.begins_with("--scenario="))
	if testing:  # las pruebas no tocan tus partidas ni tus ajustes
		Admin.save_dir = "user://pruebas"
		City.config_path = "user://pruebas/config.json"
	city = City.new(self)
	add_child(city)
	var hud_layer := _layer(4)
	var blur_layer := CanvasLayer.new()
	blur_layer.layer = 6
	add_child(blur_layer)
	blur_rect = ColorRect.new()
	blur_rect.set_anchors_preset(Control.PRESET_FULL_RECT)
	blur_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var mat := ShaderMaterial.new()
	mat.shader = load("res://shaders/blur.gdshader")
	blur_rect.material = mat
	blur_layer.add_child(blur_rect)
	var ui_layer := _layer(10)
	ui = ImUI.new(ui_layer.get_canvas_item())
	app = Admin.new(ui)
	city.setup_ui(app, ui, hud_layer.get_canvas_item())
	_run_scenario()


func _layer(n: int) -> Control:
	var layer := CanvasLayer.new()
	layer.layer = n
	add_child(layer)
	var host := Control.new()
	host.set_anchors_preset(Control.PRESET_FULL_RECT)
	host.mouse_filter = Control.MOUSE_FILTER_IGNORE
	layer.add_child(host)
	return host


func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_CLOSE_REQUEST:
		city.save_on_exit()
		get_tree().quit()


func _input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_LEFT and not event.pressed:
			mouse_clicked = true
		elif event.button_index == MOUSE_BUTTON_WHEEL_UP and event.pressed:
			wheel += 1
		elif event.button_index == MOUSE_BUTTON_WHEEL_DOWN and event.pressed:
			wheel -= 1
	city.input_event(event)


func _process(dt: float) -> void:
	city.update(dt)
	var size := get_viewport().get_visible_rect().size
	var mouse := get_viewport().get_mouse_position()
	var overlay_open: bool = city.overlays.open()
	city.hud.draw(mouse, mouse_clicked and not overlay_open, size)
	# Desenfoque: con un menú abierto la ciudad de fondo se desenfoca (en el armario no: hay que ver al personaje)
	var goal := 1.0 if city.settings.blur and overlay_open and city.overlays.mode != "personaje" else 0.0
	blur = move_toward(blur, goal, dt * 6)
	blur_rect.material.set_shader_parameter("amount", blur * blur * (3 - 2 * blur) * 1.4 if warm_blur == 0 else 0.02)
	blur_rect.visible = blur > 0.01 or warm_blur > 0
	warm_blur = max(0, warm_blur - 1)
	# La tablet: durante la partida el celular se abre como un aparato en el centro (sube desde abajo) y deja ver la
	# ciudad alrededor; el menú principal sigue ocupando toda la pantalla.
	var on_tablet: bool = overlay_open and city.overlays.mode == "admin" and app.view == "game" and app.game != null
	tablet = move_toward(tablet, 1.0 if on_tablet else 0.0, dt * 5)
	if on_tablet or not tablet_warm:
		# Solo se desliza (sin cambiar de tamaño): en Godot cada tamaño nuevo de texto vuelve a dibujar las letras, y
		# eso trababa la animación.
		var e := 1.0 - pow(1.0 - tablet, 3)
		var s := size * 0.84
		ui.place(Rect2(size / 2 - s / 2 + Vector2(0, roundf((1.0 - e) * size.y * 0.7)), s))
	else:
		ui.place(Rect2(Vector2.ZERO, size))
	ui.begin(mouse, mouse_clicked, wheel, Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT))
	if not tablet_warm:  # primer cuadro: preparar las letras al tamaño de la tablet
		tablet_warm = true
		ui.prewarm()
	mouse_clicked = false
	wheel = 0
	if overlay_open:
		city.overlays.draw()
	elif app.view == "game" and app.game != null and app.game != warmed_game:
		# Al empezar o cargar una partida se dibuja la tablet una vez sin mostrarla: Godot prepara ahí los textos y
		# estilos (60 ms la primera vez), y así abrirla después no se traba.
		warmed_game = app.game
		warm_blur = 2
		app.draw_game()
		ui.end()
		ui.begin(mouse, false, 0, false)
	ui.end()
	if app.quit_requested:
		city.quit_game()


# ---------- pruebas automáticas con capturas: Godot --path . -- --scenario=res://tests/xxx.gd ----------
func _run_scenario() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--scenario="):
			var script: GDScript = load(arg.trim_prefix("--scenario="))
			var runner = script.new()
			await get_tree().process_frame
			await runner.run(self)
			get_tree().quit()


func shot(path: String) -> void:
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png(path)
	print("captura: ", path)


func frames(n: int) -> void:
	for i in n:
		await get_tree().process_frame
