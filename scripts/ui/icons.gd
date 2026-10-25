class_name Icons
extends RefCounted
## Íconos dibujados con formas (círculos y polígonos), en vez de emojis o símbolos de la fuente: se ven igual en
## cualquier computador. Cada ícono es una lista de formas en un cuadrado de -0.5 a 0.5 (y hacia abajo). Sirven para
## la interfaz (draw) y como textura para el mundo 3D (texture), y hay una fila de estrellas en 3D (star_row).

const DARK := Color(0.06, 0.08, 0.12)
const SUN := Color8(255, 196, 60)
const CLOUD := Color8(235, 240, 248)
const GREY_CLOUD := Color8(150, 158, 175)
const RAIN := Color8(110, 175, 255)
const BOLT := Color8(255, 215, 70)

static var _shapes := {}
static var _textures := {}


# ---------- formas básicas ----------
static func _circle(c: Vector2, r: float, col = null) -> Array:
	return ["c", c, r, col]


static func _poly(pts: Array, col = null) -> Array:
	return ["p", PackedVector2Array(pts), col]


static func _box(a: Vector2, b: Vector2, col = null) -> Array:
	return _poly([a, Vector2(b.x, a.y), b, Vector2(a.x, b.y)], col)


## Línea gruesa como polígono.
static func _line(a: Vector2, b: Vector2, w: float, col = null) -> Array:
	var n := (b - a).normalized().orthogonal() * w / 2
	return _poly([a + n, b + n, b - n, a - n], col)


static func _arc(c: Vector2, r: float, w: float, from_deg: float, to_deg: float, col = null) -> Array:
	var outer := []
	var inner := []
	var steps := 14
	for i in steps + 1:
		var a := deg_to_rad(lerpf(from_deg, to_deg, float(i) / steps))
		outer.append(c + Vector2(cos(a), sin(a)) * (r + w / 2))
		inner.push_front(c + Vector2(cos(a), sin(a)) * (r - w / 2))
	return _poly(outer + inner, col)


static func _star_pts(c: Vector2, r_out: float, r_in: float) -> Array:
	var pts := []
	for i in 10:
		var a := -PI / 2 + i * PI / 5
		pts.append(c + Vector2(cos(a), sin(a)) * (r_out if i % 2 == 0 else r_in))
	return pts


static func _sun(c: Vector2, k: float, col: Color) -> Array:
	var out := [_circle(c, 0.19 * k, col)]
	for i in 8:
		var a := i * PI / 4
		var d := Vector2(cos(a), sin(a))
		out.append(_line(c + d * 0.27 * k, c + d * 0.44 * k, 0.075 * k, col))
	return out


static func _cloud(c: Vector2, k: float, col) -> Array:
	return [_circle(c + Vector2(-0.18, 0.06) * k, 0.16 * k, col), _circle(c + Vector2(0.02, -0.05) * k, 0.22 * k, col),
			_circle(c + Vector2(0.2, 0.07) * k, 0.15 * k, col), _box(c + Vector2(-0.18, 0.06) * k, c + Vector2(0.2, 0.22) * k, col)]


## Media luna: el borde de afuera de un círculo y, de vuelta, el borde de un círculo corrido que la "muerde".
static func _moon(col) -> Array:
	var c1 := Vector2(-0.02, 0.0)
	var r1 := 0.36
	var c2 := Vector2(0.16, -0.1)
	var r2 := 0.3
	var outer := []
	for i in 73:
		var a := i * TAU / 72.0
		var p := c1 + Vector2(cos(a), sin(a)) * r1
		if p.distance_to(c2) > r2:
			outer.append([a, p])
	# ordena el arco de afuera para que sea continuo
	var start := 0
	for i in outer.size():
		var prev: float = outer[i - 1][0]
		if absf(outer[i][0] - prev) > 0.2:
			start = i
	var arc := []
	for i in outer.size():
		arc.append(outer[(start + i) % outer.size()][1])
	var a0: Vector2 = arc[-1]
	var a1: Vector2 = arc[0]
	var ang0 := (a0 - c2).angle()
	var ang1 := (a1 - c2).angle()
	if ang1 < ang0:
		ang1 += TAU
	var inner := []
	for i in 21:
		var a := lerpf(ang0, ang1, i / 20.0)
		inner.append(c2 + Vector2(cos(a), sin(a)) * r2)
	return [_poly(arc + inner.slice(1, -1), col)]


# ---------- los íconos ----------
static func shape(name: String) -> Array:
	if _shapes.has(name):
		return _shapes[name]
	var s := []
	match name:
		"sun":
			s = _sun(Vector2.ZERO, 1.0, SUN)
		"heat":
			s = _sun(Vector2.ZERO, 1.05, Color8(255, 120, 50))
		"moon":
			s = _moon(Color8(225, 230, 245))
		"cloud":
			s = _cloud(Vector2(0, 0.02), 1.15, CLOUD)
		"partly":
			s = _sun(Vector2(-0.12, -0.12), 0.75, SUN) + _cloud(Vector2(0.06, 0.1), 0.95, CLOUD)
		"rain":
			s = _cloud(Vector2(0, -0.1), 1.0, CLOUD)
			for x in [-0.18, 0.0, 0.18]:
				s.append(_line(Vector2(x, 0.2), Vector2(x - 0.06, 0.38), 0.06, RAIN))
		"storm":
			s = _cloud(Vector2(0, -0.12), 1.0, GREY_CLOUD)
			s.append(_poly([Vector2(0.02, 0.06), Vector2(-0.14, 0.26), Vector2(-0.02, 0.26), Vector2(-0.1, 0.46),
					Vector2(0.12, 0.2), Vector2(0.0, 0.2), Vector2(0.08, 0.06)], BOLT))
		"star":
			s = [_poly(_star_pts(Vector2(0, 0.03), 0.48, 0.2))]
		"heart":
			s = [_circle(Vector2(-0.13, -0.07), 0.17), _circle(Vector2(0.13, -0.07), 0.17),
					_poly([Vector2(-0.295, -0.02), Vector2(0.295, -0.02), Vector2(0, 0.33)])]
		"chat":
			s = [_box(Vector2(-0.38, -0.3), Vector2(0.38, 0.16)), _circle(Vector2(-0.3, -0.22), 0.08), _circle(Vector2(0.3, -0.22), 0.08),
					_poly([Vector2(-0.18, 0.15), Vector2(0.04, 0.15), Vector2(-0.24, 0.36)])]
		"bank":
			s = [_poly([Vector2(-0.44, -0.12), Vector2(0, -0.42), Vector2(0.44, -0.12)]), _box(Vector2(-0.4, 0.28), Vector2(0.4, 0.38))]
			for x in [-0.27, 0.0, 0.27]:
				s.append(_box(Vector2(x - 0.06, -0.08), Vector2(x + 0.06, 0.25)))
		"news":
			s = [_box(Vector2(-0.36, -0.34), Vector2(0.36, 0.34)), _box(Vector2(-0.26, -0.24), Vector2(0.26, -0.12), DARK)]
			for y in [-0.02, 0.08, 0.18]:
				s.append(_box(Vector2(-0.26, y), Vector2(0.26, y + 0.045), DARK))
		"building":
			s = [_box(Vector2(-0.26, -0.44), Vector2(0.26, 0.44))]
			for y in [-0.32, -0.14, 0.04]:
				for x in [-0.14, 0.04]:
					s.append(_box(Vector2(x, y), Vector2(x + 0.1, y + 0.1), DARK))
			s.append(_box(Vector2(-0.07, 0.22), Vector2(0.07, 0.44), DARK))
		"alert":
			s = [_poly([Vector2(0, -0.42), Vector2(0.44, 0.36), Vector2(-0.44, 0.36)]),
					_box(Vector2(-0.045, -0.16), Vector2(0.045, 0.13), DARK), _circle(Vector2(0, 0.24), 0.055, DARK)]
		"chart":
			s = [_box(Vector2(-0.38, 0.06), Vector2(-0.18, 0.38)), _box(Vector2(-0.1, -0.12), Vector2(0.1, 0.38)),
					_box(Vector2(0.18, -0.36), Vector2(0.38, 0.38))]
		"crown":
			s = [_poly([Vector2(-0.42, 0.28), Vector2(-0.42, -0.22), Vector2(-0.2, 0.0), Vector2(0, -0.34), Vector2(0.2, 0.0),
					Vector2(0.42, -0.22), Vector2(0.42, 0.28)])]
		"coin":
			s = [_circle(Vector2.ZERO, 0.42), _circle(Vector2.ZERO, 0.3, DARK), _circle(Vector2.ZERO, 0.24)]
		"person":
			s = [_circle(Vector2(0, -0.22), 0.16), _circle(Vector2(-0.13, 0.12), 0.14), _circle(Vector2(0.13, 0.12), 0.14),
					_box(Vector2(-0.27, 0.12), Vector2(0.27, 0.42))]
		"box":
			s = [_box(Vector2(-0.36, -0.18), Vector2(0.36, 0.38)), _box(Vector2(-0.4, -0.3), Vector2(0.4, -0.16)),
					_box(Vector2(-0.05, -0.3), Vector2(0.05, 0.38), DARK)]
		"umbrella":
			var pts := []
			for i in 17:
				var a := PI + PI * i / 16.0
				pts.append(Vector2(cos(a), sin(a) * 0.8) * 0.42 + Vector2(0, 0.04))
			s = [_poly(pts), _line(Vector2(0, 0.0), Vector2(0, 0.34), 0.06), _arc(Vector2(-0.08, 0.34), 0.08, 0.06, 0, 180)]
		"bolt":
			s = [_poly([Vector2(0.08, -0.44), Vector2(-0.24, 0.06), Vector2(-0.02, 0.06), Vector2(-0.12, 0.44), Vector2(0.24, -0.06),
					Vector2(0.02, -0.06), Vector2(0.14, -0.44)])]
		"question":
			s = [_arc(Vector2(0, -0.14), 0.18, 0.11, 180, 405), _line(Vector2(0.0, 0.02), Vector2(0.0, 0.16), 0.11),
					_circle(Vector2(0, 0.31), 0.07)]
		"arrow_left":
			s = [_poly([Vector2(0.22, -0.34), Vector2(0.22, 0.34), Vector2(-0.26, 0.0)])]
		"arrow_right":
			s = [_poly([Vector2(-0.22, -0.34), Vector2(-0.22, 0.34), Vector2(0.26, 0.0)])]
		_:
			s = [_circle(Vector2.ZERO, 0.3)]
	_shapes[name] = s
	return s


## Nombre del ícono de cada clima de D.WEATHER (de noche despejado: la luna).
static func weather(kind: int, night := false) -> String:
	if night and kind in [0, 4]:
		return "moon"
	return ["sun", "partly", "cloud", "rain", "heat", "storm"][kind]


# ---------- atlas: todos los íconos dibujados una vez en una textura ----------
const NAMES := ["sun", "heat", "moon", "cloud", "partly", "rain", "storm", "star", "heart", "chat", "bank", "news",
		"building", "alert", "chart", "crown", "coin", "person", "box", "umbrella", "bolt", "question", "arrow_left",
		"arrow_right"]
const CELL := 64
const COLS := 6
static var atlas: SubViewport


class _Painter extends Node2D:
	func _draw() -> void:
		for i in Icons.NAMES.size():
			var c := Vector2((i % Icons.COLS + 0.5) * Icons.CELL, (i / Icons.COLS + 0.5) * Icons.CELL)
			for sh in Icons.shape(Icons.NAMES[i]):
				var col: Color = Color.WHITE if sh[-1] == null else sh[-1]
				# Este modo gráfico no suaviza bordes en 2D: cada forma lleva un contorno suavizado del mismo color
				if sh[0] == "c":
					draw_circle(c + sh[1] * Icons.CELL * 0.92, sh[2] * Icons.CELL * 0.92, col)
					draw_arc(c + sh[1] * Icons.CELL * 0.92, sh[2] * Icons.CELL * 0.92, 0, TAU, 32, col, 1.2, true)
				else:
					var pts := PackedVector2Array()
					for p in sh[1]:
						pts.append(c + p * Icons.CELL * 0.92)
					draw_colored_polygon(pts, col)
					var ring := pts.duplicate()
					ring.append(pts[0])
					draw_polyline(ring, col, 1.2, true)


## Dibuja todos los íconos en una textura (una sola vez, en la tarjeta gráfica). Las partes sin color propio quedan
## blancas y se tiñen al dibujar.
static func setup(parent: Node) -> void:
	if atlas != null:
		return
	atlas = SubViewport.new()
	atlas.size = Vector2i(CELL * COLS, CELL * ceili(NAMES.size() / float(COLS)))
	atlas.transparent_bg = true
	atlas.render_target_update_mode = SubViewport.UPDATE_ONCE
	atlas.add_child(_Painter.new())
	parent.add_child(atlas)


static func region(name: String) -> Rect2:
	var i := NAMES.find(name)
	if i < 0:
		i = NAMES.find("question")
	return Rect2((i % COLS) * CELL, (i / COLS) * CELL, CELL, CELL)


## Dibuja un ícono en la interfaz, teñido con `color` (los climas traen sus propios colores: van con blanco).
static func draw(ui: ImUI, name: String, center: Vector2, size: float, color = Color.WHITE) -> void:
	if atlas == null:
		return
	var tint: Color = Color.WHITE if name in ["sun", "heat", "moon", "cloud", "partly", "rain", "storm"] else ui.col(color)
	RenderingServer.canvas_item_add_texture_rect_region(ui.canvas, Rect2(center - Vector2(size, size) / 2, Vector2(size, size)),
			atlas.get_texture().get_rid(), region(name), tint)


## Fila de cinco estrellas en 3D (llenas hasta `filled`, el resto oscuras), siempre de frente a la cámara.
static func star_row(filled: int, size := 0.55) -> MeshInstance3D:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	for i in 5:
		var cx := (i - 2) * size * 1.1
		for layer in 2:  # contorno oscuro detrás y la estrella encima
			var k := 1.18 if layer == 0 else 1.0
			var col: Color = Color(0.05, 0.05, 0.07, 0.85) if layer == 0 else (Color8(255, 200, 50) if i < filled else Color8(90, 90, 100))
			var z := -0.01 if layer == 0 else 0.0
			var pts := _star_pts(Vector2(cx, 0), size * 0.5 * k, size * 0.21 * k)
			for j in 10:
				var a: Vector2 = pts[j]
				var b: Vector2 = pts[(j + 1) % 10]
				for v in [Vector3(cx, 0, z), Vector3(a.x, -a.y, z), Vector3(b.x, -b.y, z)]:
					st.set_color(col)
					st.add_vertex(v)
	var mi := MeshInstance3D.new()
	mi.mesh = st.commit()
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.vertex_color_use_as_albedo = true
	mat.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
	mat.billboard_keep_scale = true   # para que salten cuando cambian
	mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mi.material_override = mat
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	mi.visibility_range_end = 120.0
	return mi
