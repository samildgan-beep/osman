class_name PlayerVisual
extends Node3D
## Basit parçalı karakter modeli ve kodla yapılan animasyonlar
## (yürüme, ellerde taşıma, sırtta taşıma, yorgunluk, mola).
## İleride Mixamo/Quaternius modeliyle değiştirilebilir: aynı update() arayüzünü kullanın.

const SKIN := Color("e7b48f")

var _hips: Node3D
var _torso: Node3D
var _head: Node3D
var _arm_l: Node3D
var _arm_r: Node3D
var _leg_l: Node3D
var _leg_r: Node3D
var _mats := {}
var _phase := 0.0
var _lean := 0.0
var _crouch := 0.0
var _arm_pose := 0.0     # 0 serbest, 1 önde taşıma, 2 sırtta taşıma
var _cap: MeshInstance3D
var _brim: MeshInstance3D
var _t := 0.0


func _ready() -> void:
	_mats.body = _mat(Color.BLUE)
	_mats.legs = _mat(Color.DARK_GRAY)
	_mats.hat = _mat(Color.YELLOW)
	_mats.skin = _mat(SKIN)
	_mats.dark = _mat(Color("222222"))
	_mats.shoe = _mat(Color("3a2a1e"))

	_hips = Node3D.new()
	_hips.position = Vector3(0, 0.92, 0)
	add_child(_hips)
	_torso = Node3D.new()
	_hips.add_child(_torso)
	_box(_torso, Vector3(0.46, 0.62, 0.26), Vector3(0, 0.31, 0), "body")
	_box(_torso, Vector3(0.48, 0.08, 0.28), Vector3(0, 0.02, 0), "legs")      # kemer
	_box(_torso, Vector3(0.2, 0.12, 0.02), Vector3(0, 0.42, -0.135), "hat")   # yaka logosu
	_head = Node3D.new()
	_head.position = Vector3(0, 0.66, 0)
	_torso.add_child(_head)
	var head_mesh := MeshInstance3D.new()
	var sm := SphereMesh.new()
	sm.radius = 0.14
	sm.height = 0.3
	head_mesh.mesh = sm
	head_mesh.position = Vector3(0, 0.14, 0)
	head_mesh.material_override = _mats.skin
	_head.add_child(head_mesh)
	_box(_head, Vector3(0.03, 0.04, 0.02), Vector3(-0.05, 0.17, -0.13), "dark")
	_box(_head, Vector3(0.03, 0.04, 0.02), Vector3(0.05, 0.17, -0.13), "dark")
	var cap := MeshInstance3D.new()
	var cm := CylinderMesh.new()
	cm.top_radius = 0.15
	cm.bottom_radius = 0.155
	cm.height = 0.09
	cap.mesh = cm
	cap.position = Vector3(0, 0.27, 0)
	cap.material_override = _mats.hat
	_head.add_child(cap)
	_cap = cap
	_brim = _box(_head, Vector3(0.24, 0.02, 0.12), Vector3(0, 0.235, -0.15), "hat")    # siper
	# Gülümseme
	_box(_head, Vector3(0.07, 0.015, 0.02), Vector3(0, 0.08, -0.135), "dark")

	_arm_l = _limb(_torso, Vector3(-0.29, 0.56, 0), Vector3(0.11, 0.56, 0.11), "body")
	_arm_r = _limb(_torso, Vector3(0.29, 0.56, 0), Vector3(0.11, 0.56, 0.11), "body")
	for arm in [_arm_l, _arm_r]:
		_box(arm, Vector3(0.1, 0.1, 0.1), Vector3(0, -0.6, 0), "skin")
	_leg_l = _limb(_hips, Vector3(-0.11, 0.0, 0), Vector3(0.16, 0.9, 0.17), "legs")
	_leg_r = _limb(_hips, Vector3(0.11, 0.0, 0), Vector3(0.16, 0.9, 0.17), "legs")
	for leg in [_leg_l, _leg_r]:
		_box(leg, Vector3(0.17, 0.08, 0.26), Vector3(0, -0.88, -0.04), "shoe")
	apply_outfit(GameState.get_outfit_data())


func _mat(c: Color) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = c
	m.roughness = 0.8
	return m


func _box(parent: Node3D, size: Vector3, pos: Vector3, mat_key: String) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = size
	mi.mesh = bm
	mi.position = pos
	mi.material_override = _mats[mat_key]
	parent.add_child(mi)
	return mi


## Omuz/kalça gibi eklem: pivot noktasında Node3D, uzuv aşağı sarkar.
func _limb(parent: Node3D, pivot: Vector3, size: Vector3, mat_key: String) -> Node3D:
	var j := Node3D.new()
	j.position = pivot
	parent.add_child(j)
	_box(j, size, Vector3(0, -size.y * 0.5, 0), mat_key)
	return j


func apply_outfit(o: Dictionary) -> void:
	if _mats.is_empty():
		return
	_mats.body.albedo_color = o.get("body", Color.BLUE)
	_mats.legs.albedo_color = o.get("legs", Color.DARK_GRAY)
	_mats.hat.albedo_color = o.get("hat", Color.YELLOW)
	var hair := bool(o.get("hair", false))
	if _brim != null:
		_brim.visible = not hair
	if _cap != null:
		_cap.scale = Vector3(1.08, 1.7, 1.12) if hair else Vector3.ONE
		_cap.position = Vector3(0, 0.25, 0.015) if hair else Vector3(0, 0.27, 0)


## st: {"speed", "holding", "back", "resting", "tired", "backward", "on_stairs"}
func update_anim(delta: float, st: Dictionary) -> void:
	var speed := float(st.get("speed", 0.0))
	var holding := bool(st.get("holding", false))
	var back := bool(st.get("back", false))
	var resting := bool(st.get("resting", false))
	var tired := bool(st.get("tired", false))
	var backward := bool(st.get("backward", false))
	var dir := -1.0 if backward else 1.0
	_phase += delta * (2.0 + speed * 3.4) * dir
	var amp := clampf(speed / 2.5, 0.0, 1.0)
	var swing := sin(_phase) * 0.65 * amp
	var k := 1.0 - exp(-10.0 * delta)

	var target_pose := 0.0
	if holding:
		target_pose = 2.0 if back else 1.0
	_arm_pose = lerpf(_arm_pose, target_pose, k)

	# Gövde eğilmesi
	var lean_target := 0.0
	if back and holding:
		lean_target = -0.38
	elif holding:
		lean_target = 0.08
	if tired:
		lean_target -= 0.12
	if resting:
		lean_target = -0.55
	_lean = lerpf(_lean, lean_target, k)
	_torso.rotation.x = _lean
	_crouch = lerpf(_crouch, 0.22 if resting else 0.0, k)
	_hips.position.y = 0.92 - _crouch + absf(sin(_phase)) * 0.035 * amp

	# Bacaklar
	if resting:
		_leg_l.rotation.x = lerpf(_leg_l.rotation.x, -0.5, k)
		_leg_r.rotation.x = lerpf(_leg_r.rotation.x, 0.25, k)
	else:
		_leg_l.rotation.x = swing
		_leg_r.rotation.x = -swing

	# Kollar
	var free_l := -swing * 0.8
	var free_r := swing * 0.8
	# +X ekseni etrafında pozitif dönüş sarkan kolu ileri (-Z) kaldırır.
	var carry_front := 1.35 + sin(_phase * 2.0) * 0.04 * amp
	var carry_back := -2.4
	var arm_l: float
	var arm_r: float
	if _arm_pose <= 1.0:
		arm_l = lerpf(free_l, carry_front, _arm_pose)
		arm_r = lerpf(free_r, carry_front, _arm_pose)
	else:
		arm_l = lerpf(carry_front, carry_back, _arm_pose - 1.0)
		arm_r = arm_l
	if resting:
		arm_l = 0.6
		arm_r = 0.6
	_arm_l.rotation.x = arm_l
	_arm_r.rotation.x = arm_r
	_arm_l.rotation.z = lerpf(0.08, -0.12, clampf(_arm_pose, 0.0, 1.0))
	_arm_r.rotation.z = -_arm_l.rotation.z
	_head.rotation.x = -0.25 if tired else (-0.12 if back and holding else 0.0)

	# Duygu pozları (ev sahibi ve bölüm sonu): sevinç, el sallama, endişe, üzüntü
	_t += delta
	if bool(st.get("cheer", false)):
		var w := sin(_t * 9.0)
		_arm_l.rotation = Vector3(2.85 + w * 0.15, 0.0, -0.35)
		_arm_r.rotation = Vector3(2.85 - w * 0.15, 0.0, 0.35)
		_hips.position.y = 0.92 + absf(sin(_t * 7.0)) * 0.22
		_leg_l.rotation.x = -absf(sin(_t * 7.0)) * 0.5
		_leg_r.rotation.x = -absf(sin(_t * 7.0)) * 0.5
		_head.rotation.x = 0.2
		_torso.rotation.x = 0.05
	elif bool(st.get("wave", false)):
		_arm_r.rotation = Vector3(2.7, 0.0, 0.25 + sin(_t * 11.0) * 0.45)
	elif bool(st.get("worried", false)):
		_arm_l.rotation = Vector3(2.0, 0.0, 0.55)
		_arm_r.rotation = Vector3(2.0, 0.0, -0.55)
		_hips.position.y = 0.92 + absf(sin(_t * 14.0)) * 0.03
	elif bool(st.get("sad", false)):
		_arm_l.rotation = Vector3(2.6, 0.0, 0.75)
		_arm_r.rotation = Vector3(2.6, 0.0, -0.75)
		_head.rotation.x = -0.35
		_torso.rotation.x = -0.2


func set_head_visible(v: bool) -> void:
	if _head != null:
		_head.visible = v
