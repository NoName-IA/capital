class_name OfficeDecor
extends RefCounted
## Lo que se puede comprar para personalizar la oficina central (D.OFFICE_DECOR): fuente, estatua dorada, alfombra roja
## con postes, jardín, letrero luminoso en el techo y reflectores que iluminan la fachada de noche. Todo va afuera,
## en coordenadas de la oficina (City.HQ): el frente está en z = 2 y el edificio va de x = −8 a 8. Al lado izquierdo
## (x < −8) hay espacio libre; al derecho está el kiosco ELDIARIO.

const SIDE_X := -11.5   # el jardín del costado izquierdo


## Altura del edificio según su aspecto (la misma cuenta de Blueprints.hq).
static func height(tier: int) -> float:
	return 4.8 + 1.0 + [1, 2, 4, 6][tier] * [3.0, 3.4, 3.8, 4.2][tier]


## Arma lo comprado (`keys`) dentro de `parent`. Devuelve los choques [x, z, ancho, fondo, alto] en coordenadas locales.
## `lit`: agrega las luces de la ciudad (en las fotos de Thumbs no).
static func build(parent: Node3D, tier: int, keys: Array, lit := true) -> Array:
	var out := []
	var h := height(tier)
	var b := Boxes.new()
	var glow := Boxes.new()
	var gold := Color8(225, 180, 60)
	var stone := Color8(200, 196, 188)
	if "alfombra" in keys:   # alfombra roja hasta la calle, con postes dorados y cordones
		b.box(Vector3(0, 0.16, -1.4), Vector3(2.0, 0.03, 6.6), Color8(170, 25, 35))
		b.box(Vector3(0, 0.17, -1.4), Vector3(1.6, 0.01, 6.6), Color8(200, 40, 50))
		for sx in [-1.3, 1.3]:
			for z in [1.2, -0.4, -2.0, -3.6]:
				b.box(Vector3(sx, 0.5, z), Vector3(0.08, 0.9, 0.08), gold)
				b.box(Vector3(sx, 0.98, z), Vector3(0.16, 0.12, 0.16), gold)
				b.box(Vector3(sx, 0.08, z), Vector3(0.3, 0.06, 0.3), gold)
			b.box(Vector3(sx, 0.82, -1.2), Vector3(0.05, 0.05, 4.8), Color8(150, 20, 30))
	if "fuente" in keys:   # fuente con chorro, en el jardín del costado
		var f := Vector3(SIDE_X, 0, 5.0)
		b.box(f + Vector3(0, 0.3, 0), Vector3(3.2, 0.6, 3.2), stone)
		glow.box(f + Vector3(0, 0.58, 0), Vector3(2.8, 0.04, 2.8), Color8(80, 160, 220))
		b.box(f + Vector3(0, 1.0, 0), Vector3(0.5, 1.2, 0.5), stone)
		b.box(f + Vector3(0, 1.65, 0), Vector3(1.4, 0.12, 1.4), stone)
		glow.box(f + Vector3(0, 1.72, 0), Vector3(1.1, 0.04, 1.1), Color8(110, 190, 235))
		glow.box(f + Vector3(0, 2.15, 0), Vector3(0.12, 0.8, 0.12), Color8(170, 220, 250))
		out.append([f.x, f.z, 3.2, 3.2, 0.6])
		if lit:
			Mats.add_light(parent, f + Vector3(0, 1.0, 0), 8.0)
	if "estatua" in keys:   # estatua dorada del fundador sobre un pedestal de mármol
		var s := Vector3(SIDE_X, 0, 11.0)
		b.box(s + Vector3(0, 0.6, 0), Vector3(1.4, 1.2, 1.4), Color8(235, 232, 225))
		b.box(s + Vector3(0, 1.24, 0), Vector3(1.55, 0.08, 1.55), gold)
		for lx in [-0.14, 0.14]:
			b.box(s + Vector3(lx, 1.75, 0), Vector3(0.2, 0.9, 0.22), gold)
		b.box(s + Vector3(0, 2.6, 0), Vector3(0.62, 0.85, 0.34), gold)
		b.box(s + Vector3(0, 3.22, 0), Vector3(0.38, 0.38, 0.38), gold)
		b.box(s + Vector3(-0.42, 2.6, 0), Vector3(0.18, 0.7, 0.2), gold)
		b.box_rot(s + Vector3(0.45, 3.2, 0), Vector3(0.18, 0.8, 0.2), gold, Vector3(0, 0, -25))   # brazo arriba
		b.box(s + Vector3(0.62, 3.65, 0), Vector3(0.32, 0.32, 0.08), Color8(250, 215, 90))       # la moneda
		out.append([s.x, s.z, 1.4, 1.4, 3.5])
	if "jardin" in keys:   # jardín: seto a lo largo del costado, flores y dos árboles redondos
		b.box(Vector3(-8.9, 0.45, 9.0), Vector3(0.8, 0.9, 13.5), Color8(55, 125, 60))
		for z in [2.5, 7.5, 13.5]:
			for k in 5:
				b.box(Vector3(-10.0 - (k % 2) * 0.3, 0.25, z + k * 0.45), Vector3(0.22, 0.22, 0.22),
						[Color8(240, 90, 120), Color8(250, 210, 70), Color8(170, 110, 220)][k % 3])
		for t in [Vector2(-14.0, 2.5), Vector2(-14.0, 15.0)]:
			b.box(Vector3(t.x, 1.0, t.y), Vector3(0.35, 2.0, 0.35), Color8(110, 80, 55))
			b.box(Vector3(t.x, 2.6, t.y), Vector3(2.2, 1.8, 2.2), Color8(70, 150, 75))
			b.box(Vector3(t.x, 3.6, t.y), Vector3(1.4, 0.8, 1.4), Color8(85, 165, 85))
			out.append([t.x, t.y, 0.5, 0.5, 4.0])
		out.append([-8.9, 9.0, 0.8, 13.5, 0.9])
	if "neon" in keys:   # letrero del techo con marco de neón dorado y ampolletas
		var sy := h + 2.4
		var sz := 2.6 - 0.2
		for k in [[0, 1.25, 11.8, 0.18], [0, -1.25, 11.8, 0.18]]:
			glow.box(Vector3(0, sy + k[1], sz), Vector3(k[2], k[3], 0.1), Color8(255, 210, 90))
		for sx in [-1, 1]:
			glow.box(Vector3(sx * 5.9, sy, sz), Vector3(0.18, 2.6, 0.1), Color8(255, 210, 90))
		for i in 13:
			glow.box(Vector3(-5.6 + i * 0.93, sy - 1.55, sz - 0.05), Vector3(0.16, 0.16, 0.16), Color8(255, 240, 190))
		if lit:
			Mats.add_light(parent, Vector3(0, sy, sz - 1.0), 10.0)
	if "reflectores" in keys:   # reflectores en el piso que alumbran la fachada de noche
		for x in [-6.5, -2.4, 2.4, 6.5]:
			b.box(Vector3(x, 0.15, 0.6), Vector3(0.5, 0.3, 0.5), Color8(40, 40, 46))
			b.box_rot(Vector3(x, 0.42, 0.75), Vector3(0.42, 0.42, 0.25), Color8(40, 40, 46), Vector3(-50, 0, 0))
			glow.box_rot(Vector3(x, 0.5, 0.62), Vector3(0.34, 0.34, 0.03), Color8(255, 245, 215), Vector3(-50, 0, 0))
			if lit:
				Mats.add_light(parent, Vector3(x, h * 0.35, 0.8), 14.0)
	if not b.is_empty():
		b.node(parent, Mats.standard)
	if not glow.is_empty():
		glow.node(parent, Mats.emissive, false)
	return out


## Dónde se pone la cámara para mirar cada artículo (o toda la oficina si `key` es ""): [ojo, punto] locales.
static func frame(tier: int, key: String) -> Array:
	var h := height(tier)
	match key:
		"alfombra":
			return [Vector3(3.8, 3.2, -9.0), Vector3(0, 0.6, -0.5)]
		"fuente":
			return [Vector3(-6.0, 3.4, -2.0), Vector3(SIDE_X, 0.9, 5.0)]
		"estatua":
			return [Vector3(-9.3, 3.4, 1.5), Vector3(SIDE_X, 2.3, 11.0)]   # desde afuera, por el costado
		"jardin":
			return [Vector3(-3.0, 6.0, -6.0), Vector3(-11.0, 1.2, 8.0)]
		"neon":
			return [Vector3(0, h - 3.0, -16.0), Vector3(0, h + 2.4, 2.6)]
		"reflectores":
			return [Vector3(7.0, 2.6, -9.0), Vector3(0, 3.0, 2.0)]
	return [Vector3(12.0, 6.0, -17.0), Vector3(-3.0, h * 0.35, 6.0)]
