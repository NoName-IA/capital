class_name Dog
extends Node3D
## Perrito hecho de cajas. Pasea con su dueño (con correa) o anda suelto en el parque olfateando y corriendo.
## Mira hacia +z; las patas giran desde la cadera al caminar y la cola se mueve siempre.

const COATS := [Color8(150, 100, 55), Color8(35, 32, 30), Color8(240, 236, 228), Color8(215, 165, 90), Color8(120, 120, 125),
		Color8(190, 120, 70)]

var legs: Array[Node3D] = []
var tail: Node3D
var head: Node3D
var phase := randf() * TAU
var owner_person: Person = null  # con dueño: lo sigue a su lado
var leash: MeshInstance3D
var area := Rect2()              # suelto: se mueve dentro de este rectángulo (x, z)
var target := Vector3.ZERO
var rest := 0.0                  # segundos que se queda quieto olfateando
var speed := 0.0


func _init(with_owner: Person = null, roam_area := Rect2()) -> void:
	owner_person = with_owner
	area = roam_area
	var coat: Color = COATS.pick_random()
	var spots := randf() < 0.35
	var dark := coat.lerp(Color.BLACK, 0.45)
	var b := Boxes.new()
	b.box(Vector3(0, 0.42, 0), Vector3(0.3, 0.28, 0.66), coat)                     # cuerpo
	if spots:
		b.box(Vector3(0.08, 0.5, -0.1), Vector3(0.16, 0.13, 0.22), dark)
	b.box(Vector3(0, 0.55, 0.3), Vector3(0.32, 0.06, 0.06), Color8(200, 40, 40))   # collar
	_part(self, b)
	head = Node3D.new()
	head.position = Vector3(0, 0.62, 0.36)
	add_child(head)
	var h := Boxes.new()
	h.box(Vector3(0, 0.02, 0.06), Vector3(0.26, 0.24, 0.24), coat)
	h.box(Vector3(0, -0.04, 0.22), Vector3(0.14, 0.12, 0.14), coat.lerp(Color.WHITE, 0.15))   # hocico
	h.box(Vector3(0, -0.01, 0.295), Vector3(0.06, 0.05, 0.02), Color8(25, 22, 22))            # nariz
	for sx in [-0.07, 0.07]:
		h.box(Vector3(sx, 0.07, 0.185), Vector3(0.04, 0.04, 0.01), Color8(20, 20, 22))        # ojos
		h.box(Vector3(sx * 1.6, 0.12, 0.0), Vector3(0.07, 0.16, 0.06), dark)                   # orejas
	h.box(Vector3(0, -0.1, 0.24), Vector3(0.07, 0.015, 0.06), Color8(225, 90, 100))          # lengua
	_part(head, h)
	tail = Node3D.new()
	tail.position = Vector3(0, 0.52, -0.32)
	add_child(tail)
	var t := Boxes.new()
	t.box(Vector3(0, 0.1, -0.05), Vector3(0.06, 0.22, 0.06), coat)
	_part(tail, t)
	for p in [[-0.1, 0.24], [0.1, 0.24], [-0.1, -0.24], [0.1, -0.24]]:
		var leg := Node3D.new()
		leg.position = Vector3(p[0], 0.3, p[1])
		add_child(leg)
		var l := Boxes.new()
		l.box(Vector3(0, -0.15, 0), Vector3(0.08, 0.3, 0.08), coat)
		_part(leg, l)
		legs.append(leg)
	scale = Vector3.ONE * randf_range(0.75, 1.2)
	if owner_person:
		leash = MeshInstance3D.new()
		var lm := BoxMesh.new()
		lm.size = Vector3(0.02, 0.02, 1.0)
		leash.mesh = lm
		leash.material_override = Mats.smooth
		leash.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF


func _part(parent: Node3D, b: Boxes) -> void:
	var mi := b.node(parent, Mats.smooth)
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON if parent == self else GeometryInstance3D.SHADOW_CASTING_SETTING_OFF


func _ready() -> void:
	if leash:
		get_parent().add_child(leash)
	if area.size != Vector2.ZERO:
		_pick_target()


func _pick_target() -> void:
	target = Vector3(randf_range(area.position.x, area.end.x), 0, randf_range(area.position.y, area.end.y))


func update(dt: float) -> void:
	var goal := target
	var max_speed := 0.0
	if owner_person and is_instance_valid(owner_person):
		# Al lado del dueño, un poco atrás
		var side := owner_person.global_transform.basis.x * -0.75
		var back := owner_person.global_transform.basis.z * -0.35
		goal = owner_person.position + side + back
		max_speed = 6.0
	elif rest > 0.0:
		rest -= dt
		max_speed = 0.0
	else:
		max_speed = 5.0 if fmod(phase, 16.0) < 8.0 else 2.0   # a ratos corre, a ratos camina
	var d := Vector3(goal.x - position.x, 0, goal.z - position.z)
	var dist := d.length()
	var want := 0.0
	if max_speed > 0.0 and dist > 0.15:
		want = min(max_speed, dist * 2.5)
	elif owner_person == null and rest <= 0.0:
		rest = randf_range(0.6, 2.0)  # llegó: se queda olfateando
		_pick_target()
	speed = move_toward(speed, want, dt * 8.0)
	if speed > 0.05:
		position += d / max(dist, 0.001) * speed * dt
		rotation.y = lerp_angle(rotation.y, atan2(d.x, d.z), dt * 8)
	elif owner_person and is_instance_valid(owner_person):
		rotation.y = lerp_angle(rotation.y, owner_person.rotation.y, dt * 3)
	_animate(dt)
	if leash and owner_person and is_instance_valid(owner_person):
		var hand := owner_person.position + owner_person.global_transform.basis.x * -0.38 + Vector3(0, 0.85, 0)
		var collar := global_position + global_transform.basis.z * 0.3 * scale.x + Vector3(0, 0.55 * scale.x, 0)
		leash.global_position = (hand + collar) / 2.0
		var length := hand.distance_to(collar)
		if length > 0.01:
			leash.look_at(collar, Vector3.UP if absf((collar - hand).normalized().y) < 0.99 else Vector3.RIGHT)
			leash.scale = Vector3(1, 1, length)


func _animate(dt: float) -> void:
	phase += dt * (3.0 + speed * 3.0)
	var a: float = sin(phase * 1.4) * min(45.0, speed * 14.0)
	legs[0].rotation.x = deg_to_rad(a)
	legs[3].rotation.x = deg_to_rad(a)
	legs[1].rotation.x = deg_to_rad(-a)
	legs[2].rotation.x = deg_to_rad(-a)
	tail.rotation.z = sin(phase * 4.0) * 0.6                     # mueve la cola
	position.y = absf(sin(phase * 1.4)) * 0.12 if speed > 3.0 else 0.0   # corriendo da saltitos
	tail.rotation.x = deg_to_rad(-35)
	# Quieto olfatea el suelo; caminando lleva la cabeza alta
	var sniff := rest > 0.0 and speed < 0.1
	head.rotation.x = lerp_angle(head.rotation.x, deg_to_rad(28) if sniff else deg_to_rad(-5), dt * 4)


func destroy() -> void:
	if leash:
		leash.queue_free()
	queue_free()
