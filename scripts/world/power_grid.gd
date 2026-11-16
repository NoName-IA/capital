class_name PowerGrid
extends RefCounted
## La red eléctrica de la ciudad, que sale de la planta (PowerPlant.GANTRY) y llega a todas partes:
## - Alta tensión: torres de reticulado de 22 m. Una línea sube al cerro del norte, corre por detrás del distrito
##   financiero y del barrio y baja a la subestación del este (junto a la playa); otra sale al sur por el cerro,
##   hacia otras ciudades.
## - Distribución: postes de hormigón con cruceta, tres cables y uno de teléfono, a los dos lados de la avenida (en el
##   borde de la vereda, a mitad de camino entre los faroles), con cruces por arriba de la calle y transformadores
##   en algunos postes; postes por los pasajes del barrio con un cable a cada casa; y una línea al parque industrial
##   que pasa entre los locales y bordea las fábricas.
## Los postes chocan (rects); los cables no. Los postes que caerían encima de algo se corren o se saltan (clear).

const POLE_H := 8.6          # alto de los postes de distribución
const ARM := 1.1             # medio largo de la cruceta
const PYLON_H := 22.0        # alto de las torres de alta tensión
const WIRE := Color8(32, 32, 36)
const CONCRETE := Color8(165, 162, 155)
const STEEL := Color8(132, 138, 146)
const SUBSTATION := Vector3(122.0, 0.0, 66.0)

var city
var poles := Boxes.new()
var wires := Boxes.new()
var rects := []
var blocked := []   # zonas donde no va un poste: [Rect2]


func _init(owner_city) -> void:
	city = owner_city


func build() -> void:
	_blocked_zones()
	var plant_out := PowerPlant.outlet_points()   # los tres puntos del pórtico de adelante
	var plant_back := _gantry_points(1)
	# --- avenida: dos filas de postes y cruces por arriba de la calle
	var rows := {}
	for side in [-1, 1]:
		var pts := []
		for x in range(-143, 154, 22):
			pts.append(Vector3(x, 0, side * 6.45))
		rows[side] = _pole_line(pts, side, true)
	for x in [-143.0, 11.0, 153.0]:   # cruces de un lado al otro
		var a = _find(rows[1], x)
		var c = _find(rows[-1], x)
		if a != null and c != null:
			_span3(a.arms, c.arms, 0.35)
	if not rows[1].is_empty():   # de la planta al primer poste de la avenida
		_span3(plant_out, rows[1][0].arms, 0.4)
	# --- barrio norte y sur: postes por el pasaje y un cable a cada casa
	var north := _pole_line(_range_pts(-28, 101, 16, 48.3), 1, false)
	var south := _pole_line(_range_pts(36, 101, 16, -48.3), -1, false)
	_drops(north, 1)
	_drops(south, -1)
	# el barrio sur se alimenta desde la avenida por un poste entre los locales
	var feed_s := _pole_line([Vector3(108.0, 0, -27.0)], -1, false)
	var av_s = _find(rows[-1], 99.0)
	if av_s != null and not feed_s.is_empty() and not south.is_empty():
		_span3(av_s.arms, feed_s[0].arms, 0.4)
		_span3(feed_s[0].arms, south[-1].arms, 0.5)
	# --- parque industrial: entre los locales del sur, bordeando el centro comercial y las fábricas
	var ind := _pole_line([Vector3(-44.0, 0, -25.0), Vector3(-44.0, 0, -43.0), Vector3(-56.0, 0, -43.0),
			Vector3(-68.0, 0, -43.0), Vector3(-80.0, 0, -43.0), Vector3(-92.0, 0, -43.0), Vector3(-104.5, 0, -43.0)], -1, false)
	var av_i = _find(rows[-1], -55.0)
	if av_i != null and not ind.is_empty():
		_span3(av_i.arms, ind[0].arms, 0.4)
	# --- alta tensión al norte: cerro, detrás del barrio, hasta la subestación del este
	_span3(_gantry_points(-1), plant_out, 0.25)   # de la subestación de la planta al poste de salida
	var hv := [Vector3(-146.0, 0, 55.0)]
	for x in [-124.0, -92.0, -60.0, -28.0, 4.0, 36.0, 68.0, 100.0]:
		hv.append(Vector3(x, 0, 71.0))
	var towers := _pylon_line(hv)
	_span3(plant_back, towers[0].arms, 1.2)
	var sub := _substation(SUBSTATION)
	_span3(towers[-1].arms, sub.arms, 1.4)
	if not north.is_empty():
		_span3(sub.low, north[-1].arms, 0.6)
	# --- alta tensión al sur: cruza la calle y se va por el cerro hacia otras ciudades
	var south_hv := _pylon_line([Vector3(-146.5, 0, -31.0), Vector3(-160.0, 0, -58.0), Vector3(-178.0, 0, -86.0)])
	_span3(plant_out, south_hv[0].arms, 1.2)
	poles.node(city, Mats.standard)
	wires.node(city, Mats.standard, false)
	city.static_rects.append_array(rects)


# ---------- dónde no va nada ----------
func _blocked_zones() -> void:
	for i in City.plot_count():   # los terrenos (con lo que tengan encima)
		var p: Array = City.plot_pos(i)
		var z0: float = p[1] * Blueprints.FRONT
		var z1: float = p[1] * (Blueprints.FRONT + 15.0)
		blocked.append(Rect2(p[0] - 7.5, minf(z0, z1), 15.0, absf(z1 - z0)))
	blocked.append(Rect2(City.HQ[0] - 9.0, 9.0, 18.0, 18.0))
	for i in 2:
		blocked.append(Mall.world_rect(i).grow(0.4))
	for k in WorldBuilder.FACTORY_X:
		blocked.append(city.builder.factory_rect(k).grow(0.4))
	blocked.append(Rect2(-21, -55, 42, 42))   # el parque
	for r in PowerPlant.rects2d():
		blocked.append(r)


## ¿Se puede poner un poste en (x, z)? Ni en un terreno, ni encima de algo que choca (faroles, árboles, casas…).
func clear(pos: Vector3, r := 0.35) -> bool:
	var p := Vector2(pos.x, pos.z)
	for z in blocked:
		if z.has_point(p):
			return false
	for q in city.static_rects + rects:
		if q[0] - r < pos.x and pos.x < q[1] + r and q[2] - r < pos.z and pos.z < q[3] + r:
			return false
	return true


## Si (x, z) está ocupado prueba correrlo un poco por el eje de la línea; null si no hay lugar.
func _spot(pos: Vector3, along: Vector3):
	for d in [0.0, 1.0, -1.0, 2.0, -2.0, 3.0, -3.0]:
		var q: Vector3 = pos + along * d
		if clear(q):
			return q
	return null


func _range_pts(x0: int, x1: int, step: int, z: float) -> Array:
	var out := []
	for x in range(x0, x1, step):
		out.append(Vector3(x, 0, z))
	return out


func _find(line: Array, x: float):
	for p in line:
		if absf(p.pos.x - x) < 3.5:
			return p
	return null


# ---------- postes de distribución ----------
## Una fila de postes por `pts` (los que no caben se saltan) unidos por cables. `side` es hacia dónde queda la calle
## (la cruceta se pone de frente a la línea). En la avenida, cada tres postes uno lleva transformador.
func _pole_line(pts: Array, side: int, avenue: bool) -> Array:
	var placed := []
	for i in pts.size():
		var a: Vector3 = pts[i]
		var nxt: Vector3 = pts[i + 1] if i + 1 < pts.size() else pts[maxi(0, i - 1)]
		var along := (nxt - a).normalized() if nxt != a else Vector3.RIGHT
		var at = _spot(a, along)
		if at == null:
			continue
		placed.append(_pole(at, along, side, avenue and i % 3 == 1))
	for i in placed.size() - 1:
		_span3(placed[i].arms, placed[i + 1].arms, 0.35)
		_wire(placed[i].phone, placed[i + 1].phone, 0.45)
	return placed


## Poste de hormigón (más angosto arriba) con cruceta, tres aisladores, el cable de teléfono más abajo y, a veces,
## un transformador redondo. `along` es hacia dónde siguen los cables. Devuelve {pos, arms (3 puntos), phone}.
func _pole(pos: Vector3, along: Vector3, side: int, transformer: bool) -> Dictionary:
	var across := Vector3(-along.z, 0, along.x)
	var yaw := atan2(-along.z, along.x)
	var xf := Transform3D(Basis(Vector3.UP, yaw), pos)
	poles.box(Vector3(0, 2.0, 0), Vector3(0.3, 4.0, 0.3), CONCRETE, xf)
	poles.box(Vector3(0, 4.0 + (POLE_H - 4.0) / 2, 0), Vector3(0.22, POLE_H - 4.0, 0.22), CONCRETE, xf)
	poles.box(Vector3(0, 0.1, 0), Vector3(0.5, 0.2, 0.5), Color8(120, 118, 112), xf)
	poles.box(Vector3(0, POLE_H - 0.35, 0), Vector3(0.12, 0.12, ARM * 2), Color8(110, 86, 60), xf)   # cruceta (madera)
	for k in 2:   # tirantes de la cruceta
		poles.box_rot(pos + across * (k * 2 - 1) * 0.35 + Vector3(0, POLE_H - 0.7, 0), Vector3(0.04, 0.7, 0.04), STEEL,
				Vector3(0, rad_to_deg(yaw), 0) + Vector3((k * 2 - 1) * 40.0, 0, 0))
	var arms := []
	for k in [-1, 0, 1]:
		var p: Vector3 = pos + across * k * ARM * 0.85 + Vector3(0, POLE_H - 0.15, 0)
		if k == 0:
			p = pos + Vector3(0, POLE_H + 0.25, 0)   # la del medio va en la punta del poste
		poles.box(p + Vector3(0, -0.06, 0), Vector3(0.1, 0.22, 0.1), Color8(140, 170, 160))   # aislador
		arms.append(p)
	var phone := pos + Vector3(0, POLE_H - 2.0, 0) - across * 0.18
	poles.box(Vector3(0, POLE_H - 2.0, -0.12), Vector3(0.1, 0.12, 0.25), STEEL, xf)
	if transformer:
		var tr := CylinderMesh.new()
		tr.top_radius = 0.32
		tr.bottom_radius = 0.32
		tr.height = 0.9
		tr.radial_segments = 10
		var tp := pos + Vector3(0, 0, side * 0.42) + Vector3(0, POLE_H - 2.9, 0)   # hacia los locales, no la calle
		poles.mesh(tr, Transform3D(Basis.IDENTITY, tp), Color8(110, 118, 116))
		poles.box(tp + Vector3(0, 0.5, 0), Vector3(0.5, 0.06, 0.5), Color8(90, 96, 94))
		_wire(tp + Vector3(0, 0.5, 0), arms[1], 0.05)
	rects.append([pos.x - 0.22, pos.x + 0.22, pos.z - 0.22, pos.z + 0.22, POLE_H])
	return {"pos": pos, "arms": arms, "phone": phone}


## Un cable de cada poste del pasaje a cada casa: de la cruceta al alero de la casa (por el lado sin puerta).
func _drops(line: Array, lane_side: int) -> void:
	if line.is_empty():
		return
	for h in city.builder.houses:
		if signf(h.pos.z) != lane_side:
			continue
		var best = null
		var bd := 999.0
		for p in line:
			var d: float = absf(p.pos.x - h.pos.x)
			if d < bd:
				bd = d
				best = p
		if best == null or bd > 14.0:
			continue
		var front: float = h.pos.z + h.face * (h.d / 2 + 0.05)
		var at := Vector3(h.pos.x - h.door * 0.8, float(h.get("h", 3.6)) - 0.25, front)
		poles.box(at + Vector3(0, 0.12, h.face * 0.08), Vector3(0.1, 0.25, 0.16), STEEL)   # el soporte en la casa
		_wire(best.arms[0 if (h.pos.z - best.pos.z) * lane_side < 0 else 2] - Vector3(0, 0.6, 0), at + Vector3(0, 0.12, 0), 0.35)


# ---------- alta tensión ----------
## Torres de reticulado unidas por tres cables y un cable de guardia en la punta.
func _pylon_line(pts: Array) -> Array:
	var out := []
	for i in pts.size():
		var a: Vector3 = pts[i]
		var prev: Vector3 = pts[maxi(0, i - 1)]
		var nxt: Vector3 = pts[mini(pts.size() - 1, i + 1)]
		var dir := (nxt - prev)
		dir.y = 0
		dir = dir.normalized() if dir.length() > 0.01 else Vector3.RIGHT
		a.y = Terrain.height(a.x, a.z) - 0.2
		out.append(_pylon(a, dir))
	for i in out.size() - 1:
		_span3(out[i].arms, out[i + 1].arms, 1.6)
		_wire(out[i].top, out[i + 1].top, 1.0)
	return out


## Torre de alta tensión: cuatro patas que se juntan hacia arriba, travesaños y diagonales en cada cara, dos
## crucetas con cadenas de aisladores colgando y la punta para el cable de guardia.
func _pylon(base: Vector3, along: Vector3) -> Dictionary:
	var across := Vector3(-along.z, 0, along.x)
	var h := PYLON_H
	var w0 := 2.4
	var w1 := 0.7
	var leg := func(t: float, sa: int, sb: int) -> Vector3:
		var w := lerpf(w0, w1, t) / 2
		return base + across * sa * w + along * sb * w + Vector3(0, t * h, 0)
	for sa in [-1, 1]:
		for sb in [-1, 1]:
			_beam(poles, leg.call(0.0, sa, sb), leg.call(1.0, sa, sb), 0.12, STEEL)
	var n := 7
	for k in n:
		var t0 := float(k) / n
		var t1 := float(k + 1) / n
		for face in [[1, -1, 1, 1], [-1, -1, -1, 1], [-1, 1, 1, 1], [-1, -1, 1, -1]]:   # las cuatro caras
			var p0: Vector3 = leg.call(t0, face[0], face[1])
			var p1: Vector3 = leg.call(t0, face[2], face[3])
			var q0: Vector3 = leg.call(t1, face[0], face[1])
			var q1: Vector3 = leg.call(t1, face[2], face[3])
			_beam(poles, p0, p1, 0.06, STEEL)
			_beam(poles, p0, q1, 0.05, STEEL)
			_beam(poles, p1, q0, 0.05, STEEL)
	# crucetas: la de abajo más ancha (dos fases) y la de arriba (una fase), con aisladores colgando
	var arms := []
	for spec in [[0.72, 4.2, [-1, 1]], [0.86, 2.8, [1]]]:
		var y: float = h * spec[0]
		var reach: float = spec[1]
		var c := base + Vector3(0, y, 0)
		_beam(poles, c - across * reach, c + across * reach, 0.16, STEEL)
		_beam(poles, c - across * reach, c + Vector3(0, 1.4, 0), 0.07, STEEL)
		_beam(poles, c + across * reach, c + Vector3(0, 1.4, 0), 0.07, STEEL)
		for s in spec[2]:
			var tip: Vector3 = c + across * s * (reach - 0.3)
			for k in 5:   # cadena de discos
				_beam(poles, tip - Vector3(0, 0.25 + k * 0.28, 0), tip - Vector3(0, 0.25 + k * 0.28 + 0.1, 0), 0.24, Color8(140, 175, 165))
			_beam(poles, tip, tip - Vector3(0, 1.7, 0), 0.04, STEEL)
			arms.append(tip - Vector3(0, 1.75, 0))
	if arms.size() == 3:   # que la de arriba quede al medio: izquierda, arriba, derecha
		arms = [arms[0], arms[2], arms[1]]
	var top := base + Vector3(0, h + 1.2, 0)
	_beam(poles, base + Vector3(0, h, 0), top, 0.1, STEEL)
	rects.append([base.x - w0 / 2, base.x + w0 / 2, base.z - w0 / 2, base.z + w0 / 2, h])
	return {"pos": base, "arms": arms, "top": top}


## Subestación del este: patio cercado con dos transformadores y un pórtico; recibe la alta tensión arriba y
## entrega la de distribución abajo (al barrio).
func _substation(c: Vector3) -> Dictionary:
	var b := poles
	var size := Vector2(10.0, 8.0)
	b.box(c + Vector3(0, 0.05, 0), Vector3(size.x, 0.1, size.y), Color8(150, 146, 138))
	for seg in [[-1, 0], [1, 0], [0, -1], [0, 1]]:   # reja
		var horiz: bool = seg[1] != 0
		var at := c + Vector3(seg[0] * size.x / 2, 0.9, seg[1] * size.y / 2)
		b.box(at, Vector3(size.x if horiz else 0.04, 1.8, 0.04 if horiz else size.y), Color8(150, 158, 166))
	for i in 2:
		var tp := c + Vector3(-2.4 + i * 4.8, 0, 1.2)
		b.box(tp + Vector3(0, 1.1, 0), Vector3(1.8, 2.2, 1.6), Color8(92, 108, 92))
		for k in 6:
			b.box(tp + Vector3(-0.8 + k * 0.32, 1.0, -0.95), Vector3(0.06, 1.6, 0.3), Color8(80, 96, 80))
	var gy := 9.0
	for gx in [-3.8, 3.8]:
		PowerPlant._lattice_post(b, c + Vector3(gx, 0, -2.2), gy, 0.5, STEEL)
	b.box(c + Vector3(0, gy - 0.2, -2.2), Vector3(8.0, 0.35, 0.35), STEEL)
	var arms := []
	var low := []
	for j in 3:
		var x := -1.6 + j * 1.6
		b.box(c + Vector3(x, gy - 0.9, -2.2), Vector3(0.12, 1.1, 0.12), Color8(150, 105, 70))
		arms.append(c + Vector3(x, gy - 1.5, -2.2))
		low.append(c + Vector3(x, 5.2, -3.9))
		b.box(c + Vector3(x, 5.0, -3.9), Vector3(0.1, 0.4, 0.1), Color8(150, 105, 70))
	for gx in [-2.0, 2.0]:
		b.box(c + Vector3(gx, 2.6, -3.9), Vector3(0.2, 5.2, 0.2), STEEL)
	b.box(c + Vector3(0, 5.25, -3.9), Vector3(4.4, 0.18, 0.18), STEEL)
	Building.label(city, "SUBESTACIÓN ESTE", c + Vector3(0, 2.2, -size.y / 2 - 0.05), 9, Color8(240, 200, 60))
	rects.append([c.x - size.x / 2, c.x + size.x / 2, c.z - size.y / 2, c.z + size.y / 2, 2.0])
	return {"arms": arms, "low": low}


## Los tres puntos del pórtico de salida de la planta: el de adelante (−1, hacia la calle) o el de atrás (1).
func _gantry_points(which: int) -> Array:
	var r := PowerPlant.YARD
	var gz := r.position.y + 1.0 if which < 0 else r.end.y - 1.0
	var out := []
	for j in 3:
		out.append(Vector3(r.position.x + 1.0 + j * 1.2, PowerPlant.GANTRY.y - 1.45, gz))
	return out


# ---------- cables ----------
## Tres cables entre dos grupos de tres puntos (se emparejan por cercanía para que no se crucen).
func _span3(a: Array, b: Array, sag: float) -> void:
	var bb := b.duplicate()
	if a.size() == 3 and b.size() == 3 and a[0].distance_to(b[0]) + a[2].distance_to(b[2]) > a[0].distance_to(b[2]) + a[2].distance_to(b[0]):
		bb = [b[2], b[1], b[0]]
	for i in mini(a.size(), bb.size()):
		_wire(a[i], bb[i], sag)


## Un cable que cuelga entre dos puntos (parábola: baja más en el medio, según el largo).
func _wire(a: Vector3, b: Vector3, sag: float) -> void:
	var len := a.distance_to(b)
	var n := clampi(int(len / 2.5), 3, 14)
	var drop := sag * (len / 20.0)
	var prev := a
	for k in range(1, n + 1):
		var t := float(k) / n
		var p := a.lerp(b, t) - Vector3(0, drop * 4.0 * t * (1.0 - t), 0)
		_beam(wires, prev, p, 0.035, WIRE)
		prev = p


## Una barra recta entre dos puntos.
static func _beam(box: Boxes, a: Vector3, c: Vector3, thick: float, col: Color) -> void:
	var d := c - a
	var len := d.length()
	if len < 0.001:
		return
	var x := d / len
	var up := Vector3.UP if absf(x.y) < 0.95 else Vector3.FORWARD
	var z := x.cross(up).normalized()
	var y := z.cross(x)
	box.box(Vector3.ZERO, Vector3(len, thick, thick), col, Transform3D(Basis(x, y, z), (a + c) / 2))
