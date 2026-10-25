class_name Boxes
extends RefCounted
## Junta muchas cajas en una sola malla (como combine() en Ursina): pocas llamadas de dibujo aunque haya cientos de piezas.
## Cada caja lleva su color en los vértices y coordenadas de textura en metros (la textura se repite cada 2 m).

var verts := PackedVector3Array()
var normals := PackedVector3Array()
var colors := PackedColorArray()
var uvs := PackedVector2Array()
var indices := PackedInt32Array()

const FACES := [
	# normal, eje u, eje v (de cada cara de un cubo unitario)
	[Vector3(1, 0, 0), Vector3(0, 0, -1), Vector3(0, 1, 0)],
	[Vector3(-1, 0, 0), Vector3(0, 0, 1), Vector3(0, 1, 0)],
	[Vector3(0, 1, 0), Vector3(1, 0, 0), Vector3(0, 0, -1)],
	[Vector3(0, -1, 0), Vector3(1, 0, 0), Vector3(0, 0, 1)],
	[Vector3(0, 0, 1), Vector3(1, 0, 0), Vector3(0, 1, 0)],
	[Vector3(0, 0, -1), Vector3(-1, 0, 0), Vector3(0, 1, 0)],
]


func is_empty() -> bool:
	return verts.is_empty()


## Caja con centro, tamaño y color; `xf` transforma la caja (por ejemplo, para girarla). `uv_scale` en metros.
func box(center: Vector3, size: Vector3, color: Color, xf := Transform3D.IDENTITY, uv_scale := 2.0) -> void:
	var basis := xf.basis
	for f in FACES:
		var n: Vector3 = f[0]
		var u: Vector3 = f[1]
		var v: Vector3 = f[2]
		var base := verts.size()
		var face_center := n * 0.5
		var su: float = absf(u.dot(size))
		var sv: float = absf(v.dot(size))
		for c in [[-1, -1], [1, -1], [1, 1], [-1, 1]]:
			var local: Vector3 = (face_center + u * 0.5 * c[0] + v * 0.5 * c[1]) * size
			verts.append(xf * (center + local) if xf != Transform3D.IDENTITY else center + local)
			normals.append((basis * n).normalized())
			colors.append(color)
			uvs.append(Vector2((c[0] * 0.5 + 0.5) * su, (0.5 - c[1] * 0.5) * sv) / uv_scale)
		indices.append_array([base, base + 2, base + 1, base, base + 3, base + 2])  # Godot: caras de frente en sentido horario


## Caja girada sobre sí misma (grados, en orden Y-X-Z como en Ursina).
func box_rot(center: Vector3, size: Vector3, color: Color, rot_deg: Vector3) -> void:
	var b := Basis.from_euler(Vector3(deg_to_rad(rot_deg.x), deg_to_rad(rot_deg.y), deg_to_rad(rot_deg.z)), EULER_ORDER_YXZ)
	var xf := Transform3D(b, center) * Transform3D(Basis.IDENTITY, -center)
	box(center, size, color, xf)


## Agrega una malla cualquiera (cilindro, cono...) ya transformada, con un solo color.
func mesh(m: Mesh, xf: Transform3D, color: Color) -> void:
	for s in m.get_surface_count():
		var arr := m.surface_get_arrays(s)
		var mv: PackedVector3Array = arr[Mesh.ARRAY_VERTEX]
		var mn: PackedVector3Array = arr[Mesh.ARRAY_NORMAL]
		var mi = arr[Mesh.ARRAY_INDEX]
		var base := verts.size()
		for i in mv.size():
			verts.append(xf * mv[i])
			normals.append((xf.basis * mn[i]).normalized())
			colors.append(color)
			uvs.append(Vector2(mv[i].x + mv[i].z, mv[i].y) * 0.5)
		if mi == null or mi.is_empty():
			for i in mv.size():
				indices.append(base + i)
		else:
			for i in mi:
				indices.append(base + i)


func build() -> ArrayMesh:
	var arr := []
	arr.resize(Mesh.ARRAY_MAX)
	arr[Mesh.ARRAY_VERTEX] = verts
	arr[Mesh.ARRAY_NORMAL] = normals
	arr[Mesh.ARRAY_COLOR] = colors
	arr[Mesh.ARRAY_TEX_UV] = uvs
	arr[Mesh.ARRAY_INDEX] = indices
	var m := ArrayMesh.new()
	if not verts.is_empty():
		m.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arr)
	return m


## Crea el nodo con la malla y el material.
func node(parent: Node, material: Material, shadows := true) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.mesh = build()
	mi.material_override = material
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON if shadows else GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	parent.add_child(mi)
	return mi
