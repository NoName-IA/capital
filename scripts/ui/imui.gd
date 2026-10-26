class_name ImUI
extends RefCounted
## Interfaz en modo inmediato (como ui.py): cada cuadro se dibuja todo y los botones devuelven true al hacer clic.
## Dibuja con el RenderingServer sobre una "pantalla virtual" de W × H píxeles que se escala a la ventana.
## Cada recorte (set_clip) abre un tramo nuevo para que el orden de dibujo se respete.

const COL := {
	"bg": Color8(13, 17, 23), "panel": Color8(22, 27, 34), "panel2": Color8(30, 36, 46), "border": Color8(48, 54, 61),
	"text": Color8(230, 237, 243), "muted": Color8(139, 148, 158), "accent": Color8(227, 179, 65),
	"green": Color8(63, 185, 80), "red": Color8(248, 81, 73), "blue": Color8(88, 166, 255),
	"orange": Color8(219, 140, 60), "purple": Color8(163, 113, 247), "button": Color8(40, 47, 58),
	"button_hot": Color8(55, 64, 78), "disabled": Color8(30, 34, 40),
}
const KIND_COLOR := {"good": "green", "bad": "red", "info": "blue", "warn": "orange", "rival": "purple"}

var W := 1280.0
var H := 760.0
var root: RID
var segments: Array[RID] = []
var seg := 0
var canvas: RID              # tramo donde se dibuja ahora
var clip = null              # Rect2 activo o null
var mouse := Vector2(-100, -100)
var clicked := false
var down := false
var wheel := 0
var tip = null
var font: Font
var bold: Font
var styles := {}
var anim := {}               # estado de las animaciones de tween()
# Menús (menu_item): una sola franja que se desliza hasta la opción bajo el mouse, como en los juegos grandes.
# Se ubica con lo que quedó bajo el mouse en el cuadro anterior.
static var menu_sound: Callable   # (nombre) -> suena "hover" al pasar a otra opción y "select" al elegir
var menu_hot := ""                # opción bajo el mouse en este cuadro
var menu_prev := ""               # y en el anterior
var menu_target := Rect2()
var menu_target_col := Color.WHITE
var menu_band := Rect2()
var menu_band_col := Color.WHITE
var menu_band_a := 0.0
var menu_band_drawn := false
var menu_idle := 99               # cuadros sin opción bajo el mouse (en el hueco entre dos la franja no se apaga)
# Medir y cortar textos cuesta: se recuerdan los resultados (la interfaz se redibuja entera en cada cuadro)
var _size_cache := {}
var _fit_cache := {}
var _lines_cache := {}


func _width(s: String, size: int, is_bold: bool) -> float:
	var key := "%s|%d|%s" % [s, size, is_bold]
	var w = _size_cache.get(key)
	if w == null:
		if _size_cache.size() > 4000:
			_size_cache.clear()
		w = (bold if is_bold else font).get_string_size(s, HORIZONTAL_ALIGNMENT_LEFT, -1, size).x
		_size_cache[key] = w
	return w


## El texto recortado con "…" para que quepa en `maxw`.
func _fit(s: String, size: int, is_bold: bool, maxw: float) -> String:
	if _width(s, size, is_bold) <= maxw:
		return s
	var key := "%s|%d|%s|%d" % [s, size, is_bold, int(maxw)]
	var out = _fit_cache.get(key)
	if out == null:
		if _fit_cache.size() > 2000:
			_fit_cache.clear()
		var lo := 0
		var hi := s.length()
		while lo < hi:  # búsqueda binaria del largo que cabe
			var mid := (lo + hi + 1) / 2
			if _width(s.substr(0, mid) + "…", size, is_bold) <= maxw:
				lo = mid
			else:
				hi = mid - 1
		out = s.substr(0, lo) + "…"
		_fit_cache[key] = out
	return out


func _init(parent_item: RID, width := 1280.0, height := 760.0) -> void:
	W = width
	H = height
	root = RenderingServer.canvas_item_create()
	RenderingServer.canvas_item_set_parent(root, parent_item)
	var f := SystemFont.new()
	f.font_names = PackedStringArray(["Segoe UI", "Arial", "sans-serif"])
	f.antialiasing = TextServer.FONT_ANTIALIASING_GRAY
	f.subpixel_positioning = TextServer.SUBPIXEL_POSITIONING_DISABLED
	font = f
	var b := SystemFont.new()
	b.font_names = PackedStringArray(["Segoe UI", "Arial", "sans-serif"])
	b.font_weight = 700
	b.antialiasing = TextServer.FONT_ANTIALIASING_GRAY
	b.subpixel_positioning = TextServer.SUBPIXEL_POSITIONING_DISABLED
	bold = b


## Dibuja (invisible) todas las letras en los tamaños que usa la interfaz, para que Godot las prepare de una vez y no
## a la mitad de una animación (la tablet se trababa el primer cuadro que mostraba textos nuevos).
func prewarm() -> void:
	var chars := "ABCDEFGHIJKLMNÑOPQRSTUVWXYZÁÉÍÓÚabcdefghijklmnñopqrstuvwxyzáéíóúü0123456789$%.,:;·()+-−×=/?¡!¿«»"
	for size in [11, 12, 13, 14, 15, 16, 17, 18, 20, 22, 24, 26, 28, 30, 32, 34, 36, 40]:
		for f in [font, bold]:
			f.draw_string(canvas, Vector2(0, 40), chars, HORIZONTAL_ALIGNMENT_LEFT, -1, size, Color(1, 1, 1, 0.004))


func free_items() -> void:
	for s in segments:
		RenderingServer.free_rid(s)
	RenderingServer.free_rid(root)


## Ubica la pantalla virtual dentro de un rectángulo de la ventana (escala uniforme y centrada).
func place(screen_rect: Rect2) -> float:
	var k: float = min(screen_rect.size.x / W, screen_rect.size.y / H)
	var off := screen_rect.position + (screen_rect.size - Vector2(W, H) * k) / 2.0
	RenderingServer.canvas_item_set_transform(root, Transform2D(0.0, Vector2(k, k), 0.0, off))
	_scale = k
	_offset = off
	return k


var _scale := 1.0
var _offset := Vector2.ZERO


## Para el HUD: la altura virtual queda fija (H) y el ancho se adapta a la ventana, pegado a los bordes.
func place_fill(size: Vector2, height := 760.0) -> float:
	H = height
	_scale = size.y / H
	W = size.x / _scale
	_offset = Vector2.ZERO
	RenderingServer.canvas_item_set_transform(root, Transform2D(0.0, Vector2(_scale, _scale), 0.0, Vector2.ZERO))
	return _scale


## Todo lo que se dibuje después se ve con esta transparencia (abre un tramo nuevo).
func canvas_alpha(a: float) -> void:
	_next_segment(clip)
	RenderingServer.canvas_item_set_modulate(canvas, Color(1, 1, 1, a))


func to_virtual(p: Vector2) -> Vector2:
	return (p - _offset) / _scale


func set_visible(v: bool) -> void:
	RenderingServer.canvas_item_set_visible(root, v)


func begin(mouse_window: Vector2, was_clicked: bool, wheel_steps: int, is_down: bool) -> void:
	mouse = to_virtual(mouse_window)
	clicked = was_clicked
	wheel = wheel_steps
	down = is_down
	tip = null
	seg = -1
	clip = null
	menu_prev = menu_hot
	menu_idle = 0 if menu_hot != "" else menu_idle + 1
	menu_hot = ""
	menu_band_drawn = false
	_next_segment(null)


func _next_segment(rect) -> void:
	seg += 1
	if seg >= segments.size():
		var item := RenderingServer.canvas_item_create()
		RenderingServer.canvas_item_set_parent(item, root)
		segments.append(item)
	canvas = segments[seg]
	RenderingServer.canvas_item_clear(canvas)
	RenderingServer.canvas_item_set_visible(canvas, true)
	RenderingServer.canvas_item_set_modulate(canvas, Color.WHITE)
	RenderingServer.canvas_item_set_draw_index(canvas, seg)
	if rect == null:
		RenderingServer.canvas_item_set_clip(canvas, false)
	else:
		RenderingServer.canvas_item_set_clip(canvas, true)
		RenderingServer.canvas_item_set_custom_rect(canvas, true, rect)


func set_clip(rect) -> void:
	clip = rect
	_next_segment(rect)


func end() -> void:
	set_clip(null)
	if tip != null:
		var w := 340.0
		var h := wrap_height(tip, w - 20, 14) + 14
		var x: float = min(mouse.x + 16, W - w - 6)
		var y: float = min(mouse.y + 18, H - h - 6)
		var r := Rect2(x, y, w, h)
		rect(r, Color8(40, 46, 58), 8)
		rect(r, COL.blue, 8, 1)
		wrap_text(tip, Rect2(x + 10, y + 7, w - 20, h), 14, "text")
	for i in range(seg + 1, segments.size()):
		RenderingServer.canvas_item_clear(segments[i])


# ---------- colores y formas ----------
func col(c) -> Color:
	if c is Color:
		return c
	if c is String:
		return COL.get(c, COL.text)
	return COL.text


func _style(color: Color, radius: float, border: float) -> StyleBoxFlat:
	var key := "%s|%d|%d" % [color.to_html(), int(radius), int(border)]
	if not styles.has(key):
		var s := StyleBoxFlat.new()
		s.set_corner_radius_all(int(radius))
		s.corner_detail = 6
		s.anti_aliasing = true
		if border > 0:
			s.draw_center = false
			s.set_border_width_all(int(border))
			s.border_color = color
		else:
			s.bg_color = color
		styles[key] = s
	return styles[key]


## Rectángulo relleno (border = 0) o solo el borde, con esquinas redondeadas. Se dibuja como "nine-patch": una
## textura chica con la esquina suavizada que se estira; es mucho más barato que dibujar la forma en cada cuadro.
func rect(r: Rect2, color, radius := 0.0, border := 0.0) -> void:
	var c := col(color)
	if radius <= 0 and border <= 0:
		RenderingServer.canvas_item_add_rect(canvas, r, c)
		return
	var rad := int(floorf(min(radius, r.size.x / 2 - 2, r.size.y / 2 - 2)))   # las esquinas siempre caben
	if rad < 1:
		if border <= 0:
			RenderingServer.canvas_item_add_rect(canvas, r, c)
		return
	var tex := _corner_tex(rad, int(roundf(border)))
	var m := Vector2(rad + 2, rad + 2)
	RenderingServer.canvas_item_add_nine_patch(canvas, r, Rect2(Vector2.ZERO, tex.get_size()), tex.get_rid(), m, m,
			RenderingServer.NINE_PATCH_STRETCH, RenderingServer.NINE_PATCH_STRETCH, true, c)


var _corners := {}


## Textura blanca de un rectángulo redondeado (relleno o solo el borde) con el canto suavizado, para el nine-patch.
func _corner_tex(radius: int, border: int) -> Texture2D:
	var key := Vector2i(radius, border)
	if _corners.has(key):
		return _corners[key]
	var n := radius * 2 + 6
	var img := Image.create(n, n, false, Image.FORMAT_RGBA8)
	var half := n / 2.0
	for y in n:
		for x in n:
			var p := Vector2(x + 0.5, y + 0.5) - Vector2(half, half)
			var q := Vector2(absf(p.x), absf(p.y)) - Vector2(half - 1.0 - radius, half - 1.0 - radius)
			var d: float = Vector2(max(q.x, 0.0), max(q.y, 0.0)).length() + min(max(q.x, q.y), 0.0) - radius
			var a := clampf(0.5 - d, 0.0, 1.0)
			if border > 0:
				a *= clampf(d + border + 0.5, 0.0, 1.0)
			img.set_pixel(x, y, Color(1, 1, 1, a))
	var tex := ImageTexture.create_from_image(img)
	_corners[key] = tex
	return tex


## Solo las esquinas de arriba redondeadas (franja de color en el borde superior de un panel).
func top_strip(r: Rect2, color, radius := 10.0) -> void:
	var s := StyleBoxFlat.new()
	s.bg_color = col(color)
	s.corner_radius_top_left = int(radius)
	s.corner_radius_top_right = int(radius)
	s.anti_aliasing = true
	s.draw(canvas, r)


## Rectángulo con degradado: de `a` a `b` de izquierda a derecha (o de arriba hacia abajo).
func gradient(r: Rect2, a, b, horizontal := true) -> void:
	var ca := col(a)
	var cb := col(b)
	var cols := PackedColorArray([ca, cb, cb, ca]) if horizontal else PackedColorArray([ca, ca, cb, cb])
	RenderingServer.canvas_item_add_polygon(canvas, PackedVector2Array([r.position, Vector2(r.end.x, r.position.y),
			r.end, Vector2(r.position.x, r.end.y)]), cols)


## Valor que se acerca suave a `target` cuadro a cuadro (para animar el hover de menús). Se recuerda por `key`.
func tween(key: String, target: float, speed := 0.22) -> float:
	var v: float = anim.get(key, target)
	v = lerpf(v, target, speed)
	if absf(v - target) < 0.002:
		v = target
	anim[key] = v
	return v


func circle(center: Vector2, radius: float, color) -> void:
	RenderingServer.canvas_item_add_circle(canvas, center, radius, col(color))


func ring(center: Vector2, radius: float, color, width := 2.0) -> void:
	var pts := PackedVector2Array()
	for i in 33:
		var a := TAU * i / 32.0
		pts.append(center + Vector2(cos(a), sin(a)) * radius)
	RenderingServer.canvas_item_add_polyline(canvas, pts, PackedColorArray([col(color)]), width, true)


func line(a: Vector2, b: Vector2, color, width := 1.0) -> void:
	RenderingServer.canvas_item_add_line(canvas, a, b, col(color), width, true)


func polyline(pts: PackedVector2Array, color, width := 2.0) -> void:
	if pts.size() >= 2:
		RenderingServer.canvas_item_add_polyline(canvas, pts, PackedColorArray([col(color)]), width, true)


func polygon(pts: PackedVector2Array, color) -> void:
	RenderingServer.canvas_item_add_polygon(canvas, pts, PackedColorArray([col(color)]))


func image(tex: Texture2D, r: Rect2, modulate := Color.WHITE) -> void:
	RenderingServer.canvas_item_add_texture_rect(canvas, r, tex.get_rid(), false, modulate)


func hover(r: Rect2) -> bool:
	if clip != null and not clip.has_point(mouse):
		return false
	return r.has_point(mouse)


# ---------- texto ----------
func text_size(s: String, size := 16, is_bold := false) -> Vector2:
	var f := bold if is_bold else font
	return Vector2(_width(s, size, is_bold), f.get_height(size))


## Dibuja un texto. `anchor` como en pygame: topleft, topright, midtop, center, midleft, midright, midbottom...
## Devuelve el rectángulo que ocupa.
func text(s, pos: Vector2, size := 16, color = "text", is_bold := false, anchor := "topleft", maxw := -1.0) -> Rect2:
	var f := bold if is_bold else font
	s = str(s)
	if maxw > 0:
		s = _fit(s, size, is_bold, maxw)
	var w := _width(s, size, is_bold)
	var h := f.get_height(size)
	var x := pos.x
	var y := pos.y
	if anchor.ends_with("right"):
		x -= w
	elif anchor in ["center", "midtop", "midbottom"]:
		x -= w / 2.0
	if anchor.begins_with("mid") and anchor in ["midleft", "midright"] or anchor == "center":
		y -= h / 2.0
	elif anchor.begins_with("bottom") or anchor == "midbottom":
		y -= h
	f.draw_string(canvas, Vector2(x, y + f.get_ascent(size)), s, HORIZONTAL_ALIGNMENT_LEFT, -1, size, col(color))
	return Rect2(x, y, w, h)


func _lines(s: String, w: float, size: int, is_bold: bool) -> Array:
	var key := "%s|%d|%d|%s" % [s, int(w), size, is_bold]
	var cached = _lines_cache.get(key)
	if cached != null:
		return cached
	if _lines_cache.size() > 1500:
		_lines_cache.clear()
	var out := []
	for para in s.split("\n"):
		var cur := ""
		for word in para.split(" "):
			var test := (cur + " " + word).strip_edges()
			if _width(test, size, is_bold) <= w:
				cur = test
			else:
				out.append(cur)
				cur = word
		out.append(cur)
	_lines_cache[key] = out
	return out


## Texto con saltos de línea automáticos. Devuelve la altura usada.
func wrap_text(s, r: Rect2, size := 15, color = "text", is_bold := false, line_gap := 3.0) -> float:
	var f := bold if is_bold else font
	var y := r.position.y
	for ln in _lines(str(s), r.size.x, size, is_bold):
		text(ln, Vector2(r.position.x, y), size, color, is_bold)
		y += f.get_height(size) + line_gap
	return y - r.position.y


func wrap_height(s, w: float, size := 15, line_gap := 3.0) -> float:
	return _lines(str(s), w, size, false).size() * (font.get_height(size) + line_gap)


# ---------- piezas ----------
func panel(r: Rect2, title = null, tip_text = null) -> Rect2:
	rect(r, COL.panel, 10)
	rect(r, COL.border, 10, 1)
	if title != null:
		var t := text(title, r.position + Vector2(16, 12), 17, "text", true)
		if tip_text != null:
			info_dot(Vector2(t.end.x + 10, t.get_center().y), tip_text)
	return r


func info_dot(center: Vector2, tip_text: String) -> void:
	var r := Rect2(center - Vector2(8, 8), Vector2(16, 16))
	var hot := hover(r)
	circle(center, 8, COL.blue if hot else COL.border)
	text("?", center, 12, "text", true, "center")
	if hot:
		tip = tip_text


func tooltip(r: Rect2, tip_text) -> void:
	if tip_text != null and hover(r):
		tip = tip_text


func button(r: Rect2, label: String, enabled := true, kind := "normal", size := 15, tip_text = null, selected := false) -> bool:
	var hot := enabled and hover(r)
	var bg: Color
	var fg: Color
	if not enabled:
		bg = COL.disabled
		fg = COL.muted
	elif kind == "primary":
		bg = Color8(240, 196, 90) if hot else COL.accent
		fg = Color8(20, 20, 20)
	elif kind == "danger":
		bg = Color8(150, 50, 50) if hot else Color8(120, 40, 40)
		fg = COL.text
	elif selected:
		bg = Color8(35, 60, 95)
		fg = COL.text
	else:
		bg = COL.button_hot if hot else COL.button
		fg = COL.text
	rect(r, bg, 7)
	if selected:
		rect(r, COL.blue, 7, 2)
	text(label, r.get_center(), size, fg, kind == "primary", "center", r.size.x - 8)
	if tip_text != null and hover(r):
		tip = tip_text
	return hot and clicked


## Opción de menú como en los videojuegos: texto grande que se corre a la derecha y se ilumina con una barra de
## color al pasar el mouse. Devuelve true al hacer clic.
func menu_item(key: String, pos: Vector2, label: String, sub := "", enabled := true, size := 30, w := 400.0,
		selected := false, color = "accent") -> bool:
	var h := size + 18.0 + (20.0 if sub else 0.0)
	var r := Rect2(pos.x - 22, pos.y, w, h)
	var hot := enabled and hover(r)
	var c := col(color)
	if hot:
		menu_hot = key
		menu_target = r
		menu_target_col = c
		if key != menu_prev and menu_sound.is_valid():
			menu_sound.call("hover")
	if not menu_band_drawn:
		_menu_band()
	var k := tween("menu:" + key, 1.0 if hot else 0.0, 0.2)
	var dim := tween("menudim:" + key, 1.0 if menu_idle < 10 and not hot and menu_target != r else 0.0, 0.18)
	if selected and k < 0.99:   # la opción elegida (p. ej. la página abierta) queda marcada aunque no tenga el mouse
		gradient(r, Color(c, 0.16 * (1 - k)), Color(c, 0.0))
		rect(Rect2(r.position.x, r.position.y + 5, 3, h - 10), Color(c, 0.8 * (1 - k)), 2)
	var e := 1.0 - pow(1.0 - k, 3)   # sale rápido y frena al final
	var x := pos.x + 18 * e
	var fg: Color = COL.muted.darkened(0.25)
	if enabled:   # con el mouse encima el texto se pone blanco (o del color de la opción, como el rojo de Salir)
		fg = COL.text.lerp(Color.WHITE if color is String and color == "accent" else c, k)
		if selected:
			fg = fg.lerp(c, 1.0 - k)
		fg.a = 1.0 - 0.5 * dim
	text(label, Vector2(x, pos.y + 8), size, fg, true)
	if sub:
		text(sub, Vector2(x + 2, pos.y + 12 + size), 14, Color(COL.muted if enabled else COL.muted.darkened(0.35), 1.0 - 0.5 * dim),
				false, "topleft", w - 40)
	# Línea fina que se estira bajo el texto
	if k > 0.01 and not sub:
		rect(Rect2(x, pos.y + 12 + size * 1.08, text_size(label, size, true).x * e, 2), Color(c, 0.9 * k), 1)
	if hot and clicked and menu_sound.is_valid():
		menu_sound.call("select")
	return hot and clicked


## La franja del menú: se desliza (con freno) hasta la opción que tenía el mouse y se apaga cuando no hay ninguna.
func _menu_band() -> void:
	menu_band_drawn = true
	var on := menu_idle < 10
	if on and menu_band_a < 0.05:   # al aparecer no viaja desde lejos: nace donde está el mouse
		menu_band = menu_target
		menu_band_col = menu_target_col
	if on:
		var t := 0.28
		menu_band.position = menu_band.position.lerp(menu_target.position, t)
		menu_band.size = menu_band.size.lerp(menu_target.size, t)
		menu_band_col = menu_band_col.lerp(menu_target_col, t)
	menu_band_a = lerpf(menu_band_a, 1.0 if on else 0.0, 0.25)
	if menu_band_a < 0.01:
		return
	var r := menu_band
	var a := menu_band_a
	gradient(r, Color(menu_band_col, 0.28 * a), Color(menu_band_col, 0.0))
	rect(Rect2(r.position.x, r.position.y + 4, 4, r.size.y - 8), Color(menu_band_col, a), 2)
	# Brillo suave a la izquierda, junto a la barra
	gradient(Rect2(r.position.x + 4, r.position.y, 60, r.size.y), Color(1, 1, 1, 0.06 * a), Color(1, 1, 1, 0.0))


func bar(r: Rect2, frac: float, color = "green", bg = "panel2") -> void:
	rect(r, bg, 4)
	var w: float = r.size.x * clampf(frac, 0.0, 1.0)
	if w > 0:
		rect(Rect2(r.position, Vector2(max(w, 8.0), r.size.y)), color, 4)


## Fila etiqueta ··· valor alineado a la derecha. Devuelve la y de la fila siguiente.
func row(x: float, y: float, w: float, label: String, value: String, color = "text", tip_text = null, size := 15) -> float:
	text(label, Vector2(x, y), size, "muted")
	text(value, Vector2(x + w, y), size, color, true, "topright")
	if tip_text != null:
		tooltip(Rect2(x, y, w, size + 6), tip_text)
	return y + size + 9


## series: [[valores, color, etiqueta], ...]. markers: [[fracción x 0-1, valor y, color, texto, debajo], ...]
func line_chart(r: Rect2, series: Array, title: String, fmt: Callable, markers := []) -> Rect2:
	panel(r, title)
	var area := Rect2(r.position.x + 70, r.position.y + 44, r.size.x - 90, r.size.y - 70)
	var values := [0.0]
	for s in series:
		values.append_array(s[0])
	if values.size() <= 1:
		text("Sin datos todavía", area.get_center(), 15, "muted", false, "center")
		return area
	var lo: float = values.min()
	var hi: float = values.max()
	if hi - lo < 1e-9:
		hi = lo + 1
	var pad := (hi - lo) * 0.08
	lo -= pad
	hi += pad
	var ypos := func(v: float) -> float: return area.end.y - (v - lo) / (hi - lo) * area.size.y
	for i in 5:
		var v := lo + (hi - lo) * i / 4.0
		var y: float = ypos.call(v)
		line(Vector2(area.position.x, y), Vector2(area.end.x, y), "panel2")
		text(fmt.call(v), Vector2(area.position.x - 8, y), 12, "muted", false, "midright")
	if lo < 0 and 0 < hi:
		line(Vector2(area.position.x, ypos.call(0.0)), Vector2(area.end.x, ypos.call(0.0)), "border", 2)
	var lx := r.end.x - 16
	for k in range(series.size() - 1, -1, -1):
		var vals: Array = series[k][0]
		var c = series[k][1]
		if vals.size() >= 2:
			var n := vals.size()
			var step: int = max(1, n / int(area.size.x))
			var pts := PackedVector2Array()
			for i in range(0, n, step):
				pts.append(Vector2(area.position.x + i / float(n - 1) * area.size.x, ypos.call(vals[i])))
			pts.append(Vector2(area.end.x, ypos.call(vals[-1])))
			polyline(pts, c, 2)
		var t := text(series[k][2], Vector2(lx, r.position.y + 14), 13, c, false, "topright")
		circle(Vector2(t.position.x - 8, t.get_center().y), 4, c)
		lx = t.position.x - 22
	for m in markers:
		var mx: float = area.position.x + clampf(m[0], 0.0, 1.0) * area.size.x
		var my: float = ypos.call(m[1])
		circle(Vector2(mx, my), 6, m[2])
		if m[4]:
			text(m[3], Vector2(mx, my + 10), 13, m[2], true, "midtop")
		else:
			text(m[3], Vector2(mx, my - 10), 13, m[2], true, "midbottom")
	return area
