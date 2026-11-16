class_name OfficeDecor
extends RefCounted
## Lo que se puede comprar para personalizar la oficina central (D.OFFICE_DECOR): la alfombra roja con postes va de la
## puerta hasta justo antes de por donde camina la gente en la vereda; el jardín es un seto con flores que rodea todo el borde de la oficina
## (los costados y atrás); el guardia de seguridad cuida la puerta y el letrero luminoso va en el techo.
## Coordenadas de la oficina (City.HQ): el frente está en z = 2, el edificio va de x = −8 a 8 y hasta z = 16, y el
## bordillo de la vereda está en z = −3. Al lado derecho (x de 8.7 a 13.3, z de 2.6 a 6.4) está el kiosco ELDIARIO.

const CARPET_END := -0.5   # la alfombra termina antes del paso de la gente por la vereda (z de −2.3 a −0.7)
const GUARD := Vector3(2.4, 0, 0.9)   # donde se para el guardia: a la izquierda de la puerta al salir


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
	if "alfombra" in keys:   # alfombra roja de la puerta al bordillo, con postes dorados y cordones
		var z0 := CARPET_END
		var z1 := 1.9
		var zc := (z0 + z1) / 2
		# capas bien separadas (≥ 2 cm): con caras a la misma altura o casi, parpadean (la HD 4600 tiene poca precisión)
		b.box(Vector3(0, 0.175, zc), Vector3(2.0, 0.03, z1 - z0), Color8(170, 25, 35))   # de 0,16 a 0,19 (la del escalón llega a 0,14)
		b.box(Vector3(0, 0.2, zc), Vector3(1.6, 0.02, z1 - z0), Color8(200, 40, 50))     # la franja del medio sobresale: arriba en 0,21
		var posts := [1.3, 0.4, z0 + 0.25]
		for sx in [-1.3, 1.3]:
			for z in posts:
				b.box(Vector3(sx, 0.5, z), Vector3(0.08, 0.9, 0.08), gold)
				b.box(Vector3(sx, 0.98, z), Vector3(0.16, 0.12, 0.16), gold)
				b.box(Vector3(sx, 0.08, z), Vector3(0.3, 0.06, 0.3), gold)
			b.box(Vector3(sx, 0.82, (posts[0] + posts[-1]) / 2), Vector3(0.05, 0.05, posts[0] - posts[-1]), Color8(150, 20, 30))
	if "jardin" in keys:   # seto con flores por todo el borde: costado izquierdo, atrás y costado derecho (tras el kiosco)
		var hedge := Color8(55, 125, 60)
		var e := 8.75
		var runs := [[-e, 0.6, -e, 16.75], [-e, 16.75, e, 16.75], [e, 6.9, e, 16.75]]   # [x0, z0, x1, z1]
		for r in runs:
			var c := Vector3((r[0] + r[2]) / 2, 0, (r[1] + r[3]) / 2)
			var sz := Vector3(maxf(r[2] - r[0], 0.0) + 0.7, 0.9, maxf(r[3] - r[1], 0.0) + 0.7)
			b.box(c + Vector3(0, 0.45, 0), sz, hedge)
			out.append([c.x, c.z, sz.x, sz.z, 0.9])
			var n := int(maxf(sz.x, sz.z) / 0.9)
			for k in n:   # flores asomando arriba del seto
				var t := (k + 0.5) / n
				b.box(Vector3(lerpf(r[0], r[2], t), 0.95, lerpf(r[1], r[3], t)), Vector3(0.22, 0.14, 0.22),
						[Color8(240, 90, 120), Color8(250, 210, 70), Color8(170, 110, 220)][k % 3])
		for t in [Vector2(-e - 1.3, 16.75), Vector2(e + 1.3, 16.75)]:   # árboles redondos en las esquinas de atrás
			b.box(Vector3(t.x, 1.0, t.y), Vector3(0.35, 2.0, 0.35), Color8(110, 80, 55))
			b.box(Vector3(t.x, 2.6, t.y), Vector3(2.2, 1.8, 2.2), Color8(70, 150, 75))
			b.box(Vector3(t.x, 3.6, t.y), Vector3(1.4, 0.8, 1.4), Color8(85, 165, 85))
			out.append([t.x, t.y, 0.5, 0.5, 4.0])
	if "guardia" in keys:   # guardia de seguridad parado al lado de la puerta, mirando a la calle
		var look: Dictionary = Wardrobe.DEFAULT_LOOK.duplicate()
		look.shirt = [32, 58, 128]
		look.pants = [24, 34, 70]
		look.shoes = [20, 20, 24]
		look.hat = "gorra"
		look.hair_style = "corto"
		look.skin = [196, 150, 110]
		var guard := Person.new(null, null, false, look)
		guard.name = "Guardia"
		parent.add_child(guard)
		guard.position = GUARD
		guard.rotation.y = PI
		out.append([GUARD.x, GUARD.z, 0.6, 0.6, 1.9])
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
		"jardin":
			return [Vector3(-16.0, 7.0, -4.0), Vector3(-8.0, 0.8, 9.0)]
		"guardia":
			return [Vector3(4.2, 2.4, -3.2), GUARD + Vector3(0, 1.2, 0)]
		"neon":
			return [Vector3(0, h - 3.0, -16.0), Vector3(0, h + 2.4, 2.6)]
	return [Vector3(7.0, 2.6, -9.0), Vector3(0, 3.0, 2.0)]
	return [Vector3(12.0, 6.0, -17.0), Vector3(-3.0, h * 0.35, 6.0)]
