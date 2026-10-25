class_name CityLife
extends RefCounted
## Lo que le da vida a la ciudad aparte de los clientes: perritos sueltos en el parque, palomas que picotean en la
## plaza y salen volando si te acercas, gaviotas sobre la playa y gente sentada en las bancas del parque.

# Bancas del parque (las mismas de WorldBuilder._park): [x, z, eje del sendero]
const BENCHES := [[-2.6, -16, "z"], [2.6, -16, "z"], [-2.6, -24, "z"], [2.6, -24, "z"], [-10, -31.6, "x"],
		[10, -31.6, "x"], [-10, -36.4, "x"], [10, -36.4, "x"], [-2.6, -44, "z"], [2.6, -52, "z"]]
const PARK := Rect2(-21, -55, 42, 42)   # donde andan los perros sueltos (x, z)

var city
var dogs := []
var pigeons := []   # {node, wings, home, state, t}
var gulls := []     # {node, wings, center, radius, height, angle, speed}
var sitters := []
var swimmers := []  # {body, base, phase}
var ball_game := {}  # dos personas que se tiran una pelota en la arena


func _init(owner_city) -> void:
	city = owner_city
	for i in 3:
		var d := Dog.new(null, PARK)
		city.add_child(d)
		d.position = Vector3(randf_range(-15, 15), 0, randf_range(-50, -15))
		dogs.append(d)
	for i in 12:
		if i < 8:  # en el sendero de la fuente, nunca dentro del borde (radio 3,2 m)
			var x := randf_range(4.5, 10.0) * (1 if randf() < 0.5 else -1)
			_pigeon(Vector3(x, 0, -34 + randf_range(-1.2, 1.2)))
		else:      # en el sendero de la entrada
			_pigeon(Vector3(randf_range(-1.2, 1.2), 0, randf_range(-28, -14)))
	for i in 5:
		_gull()
	for spec in BENCHES.duplicate():
		if randf() < 0.5:
			_sitter(spec)
	_beach()


func _bird(body: Color, wing: Color, size: float) -> Array:
	var root := Node3D.new()
	var b := Boxes.new()
	b.box(Vector3(0, 0.1, 0), Vector3(0.14, 0.13, 0.26) * size, body)
	b.box(Vector3(0, 0.2, 0.14) * size, Vector3(0.1, 0.1, 0.1) * size, body)
	b.box(Vector3(0, 0.19, 0.21) * size, Vector3(0.03, 0.03, 0.06) * size, Color8(230, 160, 50))
	b.node(root, Mats.smooth, false)
	var wings := []
	for side in [-1, 1]:
		var pivot := Node3D.new()
		pivot.position = Vector3(0.07 * side, 0.15, 0) * size
		root.add_child(pivot)
		var w := Boxes.new()
		w.box(Vector3(0.14 * side, 0, 0) * size, Vector3(0.28, 0.02, 0.18) * size, wing)
		w.node(pivot, Mats.smooth, false)
		wings.append(pivot)
	city.add_child(root)
	return [root, wings]


## Paloma: cuerpo gris con pecho más claro, cuello verde tornasol, cabeza chica, pico, ojos naranjos, cola oscura y
## patitas rosadas. Las alas van pegadas al cuerpo en el suelo y se abren al volar.
func _pigeon(home: Vector3) -> void:
	var gray := Color8(132, 136, 148).lerp(Color8(96, 99, 110), randf())
	var dark := gray.lerp(Color.BLACK, 0.3)
	var root := Node3D.new()
	var b := Boxes.new()
	b.box(Vector3(0, 0.1, 0), Vector3(0.11, 0.1, 0.2), gray)                     # cuerpo
	b.box(Vector3(0, 0.09, 0.07), Vector3(0.1, 0.09, 0.07), gray.lerp(Color.WHITE, 0.15))   # pecho
	b.box(Vector3(0, 0.15, 0.1), Vector3(0.075, 0.06, 0.06), Color8(70, 130, 110))   # cuello tornasol
	b.box(Vector3(0, 0.19, 0.12), Vector3(0.065, 0.06, 0.07), gray.lerp(Color.BLACK, 0.1))   # cabeza
	b.box(Vector3(0, 0.18, 0.165), Vector3(0.02, 0.02, 0.035), Color8(60, 55, 55))   # pico
	for sx in [-0.034, 0.034]:
		b.box(Vector3(sx, 0.2, 0.135), Vector3(0.005, 0.015, 0.015), Color8(230, 120, 40))   # ojos
	b.box(Vector3(0, 0.1, -0.13), Vector3(0.08, 0.025, 0.09), dark)              # cola
	for sx in [-0.058, 0.058]:  # alas plegadas a los costados (las abiertas solo se ven al volar)
		b.box(Vector3(sx, 0.12, -0.03), Vector3(0.012, 0.07, 0.19), gray.lerp(Color.BLACK, 0.12))
		b.box(Vector3(sx, 0.12, -0.11), Vector3(0.013, 0.05, 0.06), dark)
	for sx in [-0.025, 0.025]:
		b.box(Vector3(sx, 0.025, 0.01), Vector3(0.015, 0.05, 0.015), Color8(215, 120, 130))   # patas
	b.node(root, Mats.smooth, false)
	var wings := []
	for side in [-1, 1]:
		var pivot := Node3D.new()
		pivot.position = Vector3(0.055 * side, 0.135, -0.01)
		root.add_child(pivot)
		var w := Boxes.new()
		w.box(Vector3(0.09 * side, 0, 0), Vector3(0.18, 0.012, 0.13), gray)
		w.box(Vector3(0.15 * side, 0, -0.02), Vector3(0.06, 0.013, 0.11), dark)   # puntas oscuras
		w.node(pivot, Mats.smooth, false)
		wings.append(pivot)
	city.add_child(root)
	root.position = home
	root.rotation.y = randf() * TAU
	_fold(wings)
	pigeons.append({"node": root, "wings": wings, "home": home, "state": "ground", "t": randf() * 5.0,
			"vel": Vector3.ZERO})


## Alas pegadas al cuerpo (paloma en el suelo).
func _fold(wings: Array) -> void:
	for w in wings:
		w.visible = false
		w.rotation = Vector3.ZERO


func _gull() -> void:
	var parts := _bird(Color8(245, 245, 245), Color8(200, 205, 212), 3.2)
	gulls.append({"node": parts[0], "wings": parts[1], "center": Vector3(randf_range(165, 200), 0, randf_range(-30, 40)),
			"radius": randf_range(8, 18), "height": randf_range(9, 16), "angle": randf() * TAU,
			"speed": randf_range(0.25, 0.45) * (1 if randf() < 0.5 else -1)})


## Persona sentada mirando al sendero, a veces con un café en la mano.
func _sitter(spec: Array) -> void:
	var x: float = spec[0]
	var z: float = spec[1]
	var back := Vector3(0.3 * (1 if x > 0 else -1), 0, 0) if spec[2] == "z" else Vector3(0, 0, 0.3 * (1 if z < -34 else -1))
	var face := -back.normalized()
	var p := Person.new()
	city.add_child(p)
	p.position = Vector3(x, -0.29, z) + back * 0.25
	p.rotation.y = atan2(face.x, face.z)
	for leg in p.legs:
		leg.rotation.x = deg_to_rad(-90)
	if randf() < 0.5:
		p.hold("cafe")
	else:
		p.arms[0].rotation.x = deg_to_rad(-20)
		p.arms[1].rotation.x = deg_to_rad(-20)
	sitters.append(p)


## La playa: gente tomando sol en toallas, bañistas en el mar y dos amigos tirándose una pelota.
func _beach() -> void:
	var towel_colors := [Color8(230, 70, 70), Color8(60, 140, 220), Color8(250, 200, 60), Color8(240, 120, 180),
			Color8(90, 190, 140)]
	var towels := Boxes.new()
	for spot in [Vector3(162.5, 0, -44), Vector3(163.5, 0, -36), Vector3(162.0, 0, 36), Vector3(164.0, 0, 48),
			Vector3(163.0, 0, 42)]:
		var y: float = min(0.0, Terrain.height(spot.x, spot.z))
		towels.box(Vector3(spot.x, y + 0.03, spot.z), Vector3(1.0, 0.03, 2.1), towel_colors.pick_random())
		var p := Person.new(null, null, false)
		city.add_child(p)
		p.rotation = Vector3(-PI / 2, 0, 0)          # acostado de espaldas, tomando sol
		p.position = Vector3(spot.x, y + 0.2, spot.z + 0.9)
		p.position.y = y + 0.17                      # la espalda apoyada en la toalla
		sitters.append(p)
	towels.node(city, Mats.standard, false)
	var zs := [-26.0, -14.0, -4.0, 8.0, 32.0, 40.0]   # repartidos por la orilla (no junto al muelle, en z = 24)
	for i in 6:  # bañistas: solo se les ven los hombros y la cabeza, se mecen con las olas y chapotean
		var p := Person.new()
		city.add_child(p)
		var base := Vector3(randf_range(169.5, 173.0), Terrain.SEA_LEVEL - 1.5, zs[i] + randf_range(-2, 2))
		p.position = base
		p.rotation.y = randf() * TAU
		swimmers.append({"body": p, "base": base, "phase": randf() * TAU})
	var a := Person.new()
	var b := Person.new()
	for q in [[a, Vector3(161.0, 0, 30)], [b, Vector3(164.5, 0, 32)]]:
		city.add_child(q[0])
		q[0].position = Vector3(q[1].x, min(0.0, Terrain.height(q[1].x, q[1].z)), q[1].z)
	a.look_at(b.position * Vector3(1, 0, 1) + Vector3(0, a.position.y, 0), Vector3.UP, true)
	b.look_at(a.position * Vector3(1, 0, 1) + Vector3(0, b.position.y, 0), Vector3.UP, true)
	var ball := MeshInstance3D.new()
	var sm := SphereMesh.new()
	sm.radius = 0.16
	sm.height = 0.32
	ball.mesh = sm
	var bm := StandardMaterial3D.new()
	bm.albedo_color = Color8(250, 90, 70)
	ball.material_override = bm
	city.add_child(ball)
	ball_game = {"a": a, "b": b, "ball": ball, "t": 0.0}


func update(dt: float) -> void:
	for d in dogs:
		d.update(dt)
	var player_pos: Vector3 = city.player.position
	var t := Time.get_ticks_msec() / 1000.0
	for pg in pigeons:
		var n: Node3D = pg.node
		pg.t += dt
		match pg.state:
			"ground":
				# Camina a pasitos cerca de su lugar y picotea suave; si te acercas, se espanta
				var peck := fmod(pg.t, 1.6)
				n.rotation.x = sin(clampf(peck / 0.35, 0.0, 1.0) * PI) * deg_to_rad(30)
				if fmod(pg.t, 4.0) < dt:
					var to_home: Vector3 = pg.home - n.position
					if to_home.length() > 1.2:  # se alejó: vuelve hacia su lugar
						n.rotation.y = atan2(to_home.x, to_home.z)
					else:
						n.rotation.y += randf_range(-1.5, 1.5)
				if fmod(pg.t, 4.0) < 1.0:
					n.position += n.global_transform.basis.z * 0.25 * dt
					n.position.y = absf(sin(pg.t * 18.0)) * 0.015   # saltitos al caminar
				if n.position.distance_to(player_pos) < 3.0:
					pg.state = "fly"
					pg.t = 0.0
					var away: Vector3 = (n.position - player_pos)
					away.y = 0
					pg.vel = away.normalized() * 5.0 + Vector3(0, 4.5, 0)
					n.rotation.x = 0.0
					n.rotation.y = atan2(pg.vel.x, pg.vel.z)
			"fly":
				n.position += pg.vel * dt
				for i in 2:  # alas abiertas, aleteando
					pg.wings[i].visible = true
					pg.wings[i].rotation = Vector3(0, 0, sin(pg.t * 28.0) * 0.9 * (1 if i == 0 else -1))
				if pg.t > 5.0:  # se fue lejos: vuelve más tarde a su lugar
					pg.state = "away"
					n.visible = false
					pg.t = 0.0
			"away":
				if pg.t > 12.0 and pg.home.distance_to(player_pos) > 8.0:
					n.position = pg.home
					n.visible = true
					pg.state = "ground"
					_fold(pg.wings)
	for s in swimmers:
		var p: Person = s.body
		s.phase += dt
		p.position = s.base + Vector3(sin(s.phase * 0.4) * 0.6, sin(s.phase * 1.7) * 0.06, cos(s.phase * 0.3) * 0.6)
		p.rotation.y = -PI / 2 + sin(s.phase * 0.2) * 0.8   # mirando hacia la playa, girando de a poco
		p.arms[0].rotation.x = -1.6 + sin(s.phase * 3.0) * 0.6   # chapotean con los brazos al ras del agua
		p.arms[1].rotation.x = -1.6 - sin(s.phase * 3.0) * 0.6
	if ball_game:
		# La pelota va y vuelve en arco; el que la recibe levanta los brazos
		ball_game.t += dt
		var k := fmod(ball_game.t, 3.0) / 1.5
		var from: Person = ball_game.a if k < 1.0 else ball_game.b
		var to: Person = ball_game.b if k < 1.0 else ball_game.a
		var f := fmod(k, 1.0)
		var p0 := from.position + Vector3(0, 1.9, 0)
		var p1 := to.position + Vector3(0, 1.9, 0)
		ball_game.ball.position = p0.lerp(p1, f) + Vector3(0, sin(f * PI) * 2.5, 0)
		for who in [ball_game.a, ball_game.b]:
			var up: float = smoothstep(0.6, 0.95, f) if who == to else (1.0 - smoothstep(0.0, 0.2, f))
			who.arms[0].rotation.x = -2.8 * up
			who.arms[1].rotation.x = -2.8 * up
	for g in gulls:
		g.angle += g.speed * dt
		var n: Node3D = g.node
		n.position = g.center + Vector3(cos(g.angle) * g.radius, g.height + sin(t * 0.7 + g.radius) * 0.8, sin(g.angle) * g.radius)
		var tangent := Vector3(-sin(g.angle), 0, cos(g.angle)) * signf(g.speed)
		n.rotation.y = atan2(tangent.x, tangent.z)
		n.rotation.z = -0.35 * signf(g.speed)  # inclinada en la curva
		var flap := sin(t * 6.0 + g.radius) * 0.5 if fmod(t + g.radius, 6.0) < 2.5 else 0.12   # aletea y planea
		g.wings[0].rotation.z = flap
		g.wings[1].rotation.z = -flap
