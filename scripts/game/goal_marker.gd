class_name GoalMarker
extends Node3D
## Hedef alan görseli: yarı saydam yeşil zemin, parlayan kenarlar ve zıplayan ok.

var _area: AABB
var _arrow: Node3D
var _floor_mat: StandardMaterial3D
var _t := 0.0
var active := true


func setup(area: AABB) -> void:
	_area = area


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
	label.text = "HEDEF"
	label.font_size = 64
	label.pixel_size = 0.005
	label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	label.modulate = Color(0.35, 1.0, 0.5)
	label.outline_size = 10
	label.position = Vector3(0, 0.85, 0)
	_arrow.add_child(label)


func _process(delta: float) -> void:
	_t += delta
	if _arrow != null:
		_arrow.visible = active
		_arrow.position.y = 1.4 + sin(_t * 3.0) * 0.12
		_arrow.rotation.y = _t * 1.5
	if _floor_mat != null:
		_floor_mat.albedo_color.a = 0.2 + 0.12 * (0.5 + 0.5 * sin(_t * 4.0))


func contains(p: Vector3) -> bool:
	return _area.has_point(p)
