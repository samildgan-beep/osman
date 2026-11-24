class_name GoalMarker
extends Node3D
## Hedef alan görseli: yarı saydam yeşil zemin, parlayan kenarlar ve zıplayan ok.

var _area: AABB
var _arrow: Node3D
var _floor_mat: StandardMaterial3D
var _t := 0.0
var active := true
var _ghost_size := Vector3.ZERO
var _ghost_basis := Basis()
var _ghost_mat: StandardMaterial3D
var _label_text := "DROP HERE"


## ghost_size verilirse (yerleştirme bölümü) eşyanın hayalet görüntüsü ve ön yön oku çizilir.
func setup(area: AABB, ghost_size: Vector3 = Vector3.ZERO, ghost_basis: Basis = Basis(), label_text: String = "DROP HERE") -> void:
	_area = area
	_ghost_size = ghost_size
	_ghost_basis = ghost_basis
	_label_text = label_text


func _ready() -> void:
	var size := _area.size
	var center := _area.get_center()
	position = Vector3(center.x, _area.position.y, center.z)
	_floor_mat = StandardMaterial3D.new()
	_floor_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_floor_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_floor_mat.albedo_color = Color(0.3, 1.0, 0.45, 0.28)
	var floor_mi := MeshInstance3D.new()
	var pm := BoxMesh.new()
	pm.size = Vector3(size.x, 0.01, size.z)
	floor_mi.mesh = pm
	floor_mi.position = Vector3(0, 0.012, 0)
	floor_mi.material_override = _floor_mat
	floor_mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(floor_mi)
	var edge_mat := StandardMaterial3D.new()
	edge_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	edge_mat.albedo_color = Color(0.35, 1.0, 0.5)
	var w := 0.06
	for e in [
		[Vector3(0, 0.02, -size.z * 0.5), Vector3(size.x, 0.02, w)],
		[Vector3(0, 0.02, size.z * 0.5), Vector3(size.x, 0.02, w)],
		[Vector3(-size.x * 0.5, 0.02, 0), Vector3(w, 0.02, size.z)],
		[Vector3(size.x * 0.5, 0.02, 0), Vector3(w, 0.02, size.z)],
	]:
		var mi := MeshInstance3D.new()
		var bm := BoxMesh.new()
		bm.size = e[1]
		mi.mesh = bm
		mi.position = e[0]
		mi.material_override = edge_mat
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		add_child(mi)
	# Ok
	_arrow = Node3D.new()
	add_child(_arrow)
	var cone := MeshInstance3D.new()
	var cm := CylinderMesh.new()
	cm.top_radius = 0.0
	cm.bottom_radius = 0.22
	cm.height = 0.4
	cone.mesh = cm
	cone.rotation = Vector3(PI, 0, 0)
	cone.material_override = edge_mat
	_arrow.add_child(cone)
	var stem := MeshInstance3D.new()
	var sm := CylinderMesh.new()
	sm.top_radius = 0.07
	sm.bottom_radius = 0.07
	sm.height = 0.35
	stem.mesh = sm
	stem.position = Vector3(0, 0.37, 0)
	stem.material_override = edge_mat
	_arrow.add_child(stem)
	var label := Label3D.new()
	label.text = _label_text
	label.font_size = 64
	label.pixel_size = 0.005
	label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	label.modulate = Color(0.35, 1.0, 0.5)
	label.outline_size = 10
	label.position = Vector3(0, 0.85, 0)
	_arrow.add_child(label)
	if _ghost_size != Vector3.ZERO:
		_build_ghost(edge_mat)


func _build_ghost(edge_mat: Material) -> void:
	_ghost_mat = StandardMaterial3D.new()
	_ghost_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_ghost_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_ghost_mat.albedo_color = Color(0.4, 1.0, 0.55, 0.18)
	_ghost_mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	var ghost := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = _ghost_size
	ghost.mesh = bm
	ghost.material_override = _ghost_mat
	ghost.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	ghost.transform = Transform3D(_ghost_basis, Vector3(0, _ghost_size.y * 0.5 + 0.01, 0))
	add_child(ghost)
	# Ön yüz oku (yerde, eşyanın önüne doğru)
	var fwd := -_ghost_basis.z
	fwd.y = 0.0
	fwd = fwd.normalized()
	var arrow := MeshInstance3D.new()
	var cm := CylinderMesh.new()
	cm.top_radius = 0.0
	cm.bottom_radius = 0.12
	cm.height = 0.28
	arrow.mesh = cm
	arrow.material_override = edge_mat
	var side := fwd.cross(Vector3.UP).normalized()
	# Koninin ucu (+Y) ileri baksın
	arrow.transform = Transform3D(Basis(side, fwd, side.cross(fwd)), fwd * (_ghost_size.z * 0.5 + 0.25) + Vector3(0, 0.03, 0))
	add_child(arrow)
	var front := Label3D.new()
	front.text = "FRONT"
	front.font_size = 40
	front.pixel_size = 0.004
	front.modulate = Color(0.35, 1.0, 0.5)
	front.outline_size = 8
	front.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	front.position = fwd * (_ghost_size.z * 0.5 + 0.55) + Vector3(0, 0.15, 0)
	add_child(front)


func _process(delta: float) -> void:
	_t += delta
	if _arrow != null:
		_arrow.visible = active
		_arrow.position.y = 1.4 + sin(_t * 3.0) * 0.12
		_arrow.rotation.y = _t * 1.5
	if _floor_mat != null:
		_floor_mat.albedo_color.a = 0.2 + 0.12 * (0.5 + 0.5 * sin(_t * 4.0))
	if _ghost_mat != null:
		_ghost_mat.albedo_color.a = 0.12 + 0.1 * (0.5 + 0.5 * sin(_t * 3.0))


func contains(p: Vector3) -> bool:
	return _area.has_point(p)
