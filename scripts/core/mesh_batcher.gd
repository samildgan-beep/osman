class_name MeshBatcher
extends RefCounted
## Çok sayıda kutu/silindiri tek bir ArrayMesh'te birleştirir (tek çizim çağrısı).
## Telefonda yüzlerce ayrı MeshInstance yerine birkaç tane çizilir.

const MAX_VERTS_PER_MESH := 60000

## Yüzey malzemesi kimlikleri (köşe renginin alfa kanalında taşınır, bina gölgelendiricisi okur)
const M_PLASTER := 0
const M_BRICK := 1
const M_WOOD := 2
const M_TILE := 3
const M_MARBLE := 4
const M_METAL := 5
const M_WALLPAPER := 6
const M_CARPET := 7
const M_GLASS := 8
const M_ASPHALT := 9
const M_GRASS := 10
const M_PAVING := 11
const M_PAINT := 12
const M_FABRIC := 13
const M_TERRAZZO := 14

static var _unit_box: Array = []
static var _unit_cyl: Array = []
static var _unit_sphere: Array = []

var _verts := PackedVector3Array()
var _normals := PackedVector3Array()
var _colors := PackedColorArray()
var _indices := PackedInt32Array()
var _meshes: Array[ArrayMesh] = []


static func _box_arrays() -> Array:
	if _unit_box.is_empty():
		var b := BoxMesh.new()
		b.size = Vector3.ONE
		_unit_box = b.get_mesh_arrays()
	return _unit_box


static func _cyl_arrays() -> Array:
	if _unit_cyl.is_empty():
		var c := CylinderMesh.new()
		c.top_radius = 0.5
		c.bottom_radius = 0.5
		c.height = 1.0
		c.radial_segments = 10
		c.rings = 1
		_unit_cyl = c.get_mesh_arrays()
	return _unit_cyl


static func _sphere_arrays() -> Array:
	if _unit_sphere.is_empty():
		var s := SphereMesh.new()
		s.radius = 0.5
		s.height = 1.0
		s.radial_segments = 10
		s.rings = 6
		_unit_sphere = s.get_mesh_arrays()
	return _unit_sphere


## Eksen hizalı kutu: merkez ve boyut.
func add_box(center: Vector3, size: Vector3, color: Color, mat: int = 0) -> void:
	add_box_xform(Transform3D(Basis(), center), size, color, mat)


## Dönmüş kutu: transform (ölçeksiz) ve boyut.
func add_box_xform(xform: Transform3D, size: Vector3, color: Color, mat: int = 0) -> void:
	if size.x <= 0.0 or size.y <= 0.0 or size.z <= 0.0:
		return
	_append(_box_arrays(), xform, size, color, mat)


## Dikey silindir: tabanın değil merkezin konumu verilir.
func add_cylinder(center: Vector3, radius: float, height: float, color: Color, basis: Basis = Basis(), mat: int = 0) -> void:
	if radius <= 0.0 or height <= 0.0:
		return
	_append(_cyl_arrays(), Transform3D(basis, center), Vector3(radius * 2.0, height, radius * 2.0), color, mat)


## İki nokta arasında silindir (korkuluk, boru vb.)
func add_cylinder_between(a: Vector3, b: Vector3, radius: float, color: Color, mat: int = 0) -> void:
	var d := b - a
	var length := d.length()
	if length < 0.001:
		return
	var y := d / length
	var x := y.cross(Vector3.FORWARD)
	if x.length_squared() < 0.01:
		x = y.cross(Vector3.RIGHT)
	x = x.normalized()
	var z := x.cross(y).normalized()
	add_cylinder((a + b) * 0.5, radius, length, color, Basis(x, y, z), mat)


func add_sphere(center: Vector3, radius: float, color: Color, mat: int = 0, squash: Vector3 = Vector3.ONE) -> void:
	if radius <= 0.0:
		return
	_append(_sphere_arrays(), Transform3D(Basis(), center), Vector3.ONE * radius * 2.0 * squash, color, mat)


func _append(arrays: Array, xform: Transform3D, scale: Vector3, color: Color, mat: int = 0) -> void:
	var src_v: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
	var src_n: PackedVector3Array = arrays[Mesh.ARRAY_NORMAL]
	var src_i: PackedInt32Array = arrays[Mesh.ARRAY_INDEX]
	if _verts.size() + src_v.size() > MAX_VERTS_PER_MESH:
		_flush()
	var base := _verts.size()
	var lin := color.srgb_to_linear()
	lin.a = (float(clampi(mat, 0, 15)) + 0.5) / 16.0
	var inv_scale := Vector3(1.0 / scale.x, 1.0 / scale.y, 1.0 / scale.z)
	for i in src_v.size():
		_verts.append(xform * (src_v[i] * scale))
		# Ölçeklenmiş nesnede normal, ters ölçekle dönüştürülür.
		_normals.append((xform.basis * (src_n[i] * inv_scale)).normalized())
		_colors.append(lin)
	for idx in src_i:
		_indices.append(base + idx)


func _flush() -> void:
	if _verts.is_empty():
		return
	var arr := []
	arr.resize(Mesh.ARRAY_MAX)
	arr[Mesh.ARRAY_VERTEX] = _verts
	arr[Mesh.ARRAY_NORMAL] = _normals
	arr[Mesh.ARRAY_COLOR] = _colors
	arr[Mesh.ARRAY_INDEX] = _indices
	var m := ArrayMesh.new()
	m.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arr)
	_meshes.append(m)
	_verts = PackedVector3Array()
	_normals = PackedVector3Array()
	_colors = PackedColorArray()
	_indices = PackedInt32Array()


func is_empty() -> bool:
	return _verts.is_empty() and _meshes.is_empty()


## Birleştirilmiş ağları MeshInstance3D olarak parent altına ekler.
func build(parent: Node3D, material: Material, node_name: String = "Batch", cast_shadows: bool = true) -> void:
	_flush()
	var i := 0
	for m in _meshes:
		var mi := MeshInstance3D.new()
		mi.name = "%s_%d" % [node_name, i]
		mi.mesh = m
		mi.material_override = material
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON if cast_shadows else GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		parent.add_child(mi)
		i += 1
	_meshes.clear()
