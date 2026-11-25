class_name PlayerVisual
extends Node3D
## Gerçekçi oranlı, eklemli insan modeli (kodla üretilir, dış dosya gerekmez).
## - Gövde: kalça, karın, göğüs, boyun, kafa; omuz-dirsek-el ve kalça-diz-ayak eklemleri
## - Yüz: göz akı + göz bebeği, kaş, burun, kulak, ağız, (isteğe bağlı) bıyık
## - Kıyafet: yakalı iş gömleği + logo, kemer, iş pantolonu, iş eldiveni, bot, kasket veya saç
## - Animasyon: yürüme (diz bükülmesi), eşyaya iki kemikli IK ile uzanan kollar,
##   sırtta taşıma, yorgunluk, mola, sevinç, el sallama, endişe, üzüntü, ezilme.
## Dış arayüz: update_anim(), set_grips(), play_crushed(), apply_outfit(), set_head_visible().

const SKIN := Color("e0ac86")
const HIP_Y := 0.93          # kalça ekleminin yerden yüksekliği
const L_UPPER := 0.29        # omuz → dirsek
const L_LOWER := 0.33        # dirsek → el merkezi
const L_THIGH := 0.43
const L_SHIN := 0.42

var crushed := false

var _hips: Node3D
var _torso: Node3D
var _head: Node3D
var _sh_l: Node3D
var _sh_r: Node3D
var _el_l: Node3D
var _el_r: Node3D
var _hip_l: Node3D
var _hip_r: Node3D
var _knee_l: Node3D
var _knee_r: Node3D
var _ankle_l: Node3D
var _ankle_r: Node3D
var _cap_parts: Array[MeshInstance3D] = []
var _hair_parts: Array[MeshInstance3D] = []
var _mustache: MeshInstance3D
var _glove_parts: Array[MeshInstance3D] = []
var _hand_parts: Array[MeshInstance3D] = []
var _mats := {}
var _phase := 0.0
var _lean := 0.0
var _crouch := 0.0
var _arm_pose := 0.0     # 0 serbest, 1 önde taşıma, 2 sırtta taşıma
var _t := 0.0
var _fatigue := 0.0
var _grip_l := Vector3.ZERO
var _grip_r := Vector3.ZERO
var _grip_on := false


func _ready() -> void:
	_mats.body = _mat(Color.BLUE, 0.85)
	_mats.legs = _mat(Color.DARK_GRAY, 0.9)
	_mats.hat = _mat(Color.YELLOW, 0.7)
	_mats.skin = _mat(SKIN, 0.55)
	_mats.skin.rim_enabled = true
	_mats.skin.rim = 0.08
	_mats.skin.rim_tint = 0.8
	_mats.dark = _mat(Color("2a1d14"), 0.8)
	_mats.white = _mat(Color("f7f4ee"), 0.4)
	_mats.pupil = _mat(Color("1b1b1b"), 0.2)
	_mats.iris = _mat(Color("5a3a22"), 0.3)
	_mats.lip = _mat(Color("a8635a"), 0.6)
	_mats.boot = _mat(Color("4a3324"), 0.55)
	_mats.sole = _mat(Color("1e1e1e"), 0.9)
	_mats.glove = _mat(Color("3d4248"), 0.9)
	_mats.belt = _mat(Color("2b2420"), 0.5)
	_mats.buckle = _mat(Color("c9b26b"), 0.3)
	_mats.buckle.metallic = 0.8
	_mats.logo = _mat(Color("ff8c1a"), 0.7)

	# --- Kalça (pelvis) ve bacaklar
	_hips = _node(self, Vector3(0, HIP_Y, 0))
	_capsule(_hips, 0.14, 0.38, Vector3(0, 0.02, 0), "legs", Vector3(0, 0, PI * 0.5), Vector3(1.0, 1.0, 0.8))
	_capsule(_hips, 0.135, 0.36, Vector3(0, 0.09, 0), "belt", Vector3(0, 0, PI * 0.5), Vector3(0.35, 1.0, 0.85))
	_box(_hips, Vector3(0.07, 0.05, 0.02), Vector3(0, 0.09, -0.118), "buckle")
	_hip_l = _node(_hips, Vector3(-0.095, -0.01, 0))
	_hip_r = _node(_hips, Vector3(0.095, -0.01, 0))
	for hip: Node3D in [_hip_l, _hip_r]:
		_capsule(hip, 0.078, L_THIGH + 0.08, Vector3(0, -L_THIGH * 0.5, 0), "legs")
		var knee := _node(hip, Vector3(0, -L_THIGH, 0))
		_capsule(knee, 0.064, L_SHIN + 0.06, Vector3(0, -L_SHIN * 0.5, 0.005), "legs")
		# Ayak bileği + bot: konç + burun + taban (bilek, ayağı yere paralel tutar)
		var ankle := _node(knee, Vector3(0, -L_SHIN, 0))
		_capsule(ankle, 0.062, 0.16, Vector3(0, 0.02, 0.0), "boot")
		_capsule(ankle, 0.058, 0.24, Vector3(0, -0.025, -0.06), "boot", Vector3(PI * 0.5, 0, 0), Vector3(1.05, 1.0, 0.75))
		_box(ankle, Vector3(0.115, 0.025, 0.27), Vector3(0, -0.07, -0.055), "sole")
		if hip == _hip_l:
			_knee_l = knee
			_ankle_l = ankle
		else:
			_knee_r = knee
			_ankle_r = ankle

	# --- Gövde: karın, göğüs (daralan), yaka, logo, cep
	_torso = _node(_hips, Vector3(0, 0.0, 0))
	_capsule(_torso, 0.135, 0.34, Vector3(0, 0.2, 0), "body", Vector3.ZERO, Vector3(1.15, 1.0, 0.82))
	_capsule(_torso, 0.165, 0.38, Vector3(0, 0.38, 0), "body", Vector3.ZERO, Vector3(1.28, 1.0, 0.8))
	_capsule(_torso, 0.06, 0.38, Vector3(0, 0.5, 0.0), "body", Vector3(0, 0, PI * 0.5), Vector3(1.0, 1.0, 1.3))
	for side: float in [-1.0, 1.0]:
		# Yaka uçları
		_box(_torso, Vector3(0.07, 0.05, 0.015), Vector3(side * 0.04, 0.53, -0.115), "body", Vector3(0.3, 0, side * 0.5))
	_box(_torso, Vector3(0.1, 0.07, 0.01), Vector3(-0.1, 0.42, -0.134), "logo")
	_box(_torso, Vector3(0.09, 0.08, 0.008), Vector3(0.1, 0.4, -0.132), "body")

	# --- Boyun ve kafa
	_capsule(_torso, 0.052, 0.14, Vector3(0, 0.6, 0.005), "skin")
	_head = _node(_torso, Vector3(0, 0.63, 0))
	var skull := _sphere(_head, 0.11, Vector3(0, 0.12, 0.0), "skin", Vector3(0.92, 1.08, 1.0))
	skull.name = "Skull"
	_sphere(_head, 0.075, Vector3(0, 0.05, -0.035), "skin", Vector3(1.0, 0.85, 1.0))      # çene
	for side: float in [-1.0, 1.0]:
		_sphere(_head, 0.026, Vector3(side * 0.1, 0.115, 0.01), "skin", Vector3(0.45, 1.0, 0.8))   # kulak
		_sphere(_head, 0.013, Vector3(side * 0.037, 0.135, -0.094), "white", Vector3(1.25, 0.8, 1.0))   # göz akı
		_sphere(_head, 0.0075, Vector3(side * 0.037, 0.135, -0.104), "iris")                             # iris
		_sphere(_head, 0.004, Vector3(side * 0.037, 0.135, -0.1105), "pupil")                            # göz bebeği
		_box(_head, Vector3(0.034, 0.008, 0.012), Vector3(side * 0.037, 0.147, -0.098), "skin")         # göz kapağı
		_box(_head, Vector3(0.045, 0.011, 0.012), Vector3(side * 0.039, 0.165, -0.1), "dark", Vector3(0, 0, side * -0.12))   # kaş
	_capsule(_head, 0.016, 0.06, Vector3(0, 0.1, -0.108), "skin", Vector3(-0.35, 0, 0))       # burun
	_box(_head, Vector3(0.045, 0.01, 0.01), Vector3(0, 0.052, -0.099), "lip")                 # ağız
	_mustache = _capsule(_head, 0.012, 0.075, Vector3(0, 0.072, -0.102), "dark", Vector3(0, 0, PI * 0.5))
	# Kasket: kubbe + siper + düğme
	_cap_parts.append(_sphere(_head, 0.118, Vector3(0, 0.17, 0.005), "hat", Vector3(1.0, 0.62, 1.05)))
	_cap_parts.append(_box(_head, Vector3(0.18, 0.012, 0.1), Vector3(0, 0.155, -0.14), "hat", Vector3(0.12, 0, 0)))
	_cap_parts.append(_sphere(_head, 0.012, Vector3(0, 0.244, 0.005), "hat"))
	# Kasket altından görünen kısa saç (ense ve favoriler)
	_cap_parts.append(_sphere(_head, 0.1, Vector3(0, 0.12, 0.03), "dark", Vector3(1.02, 0.75, 0.95)))
	# Saç (kasketsiz karakterler için)
	_hair_parts.append(_sphere(_head, 0.117, Vector3(0, 0.155, 0.012), "hat", Vector3(0.98, 0.78, 1.06)))
	_hair_parts.append(_sphere(_head, 0.09, Vector3(0, 0.12, 0.05), "hat", Vector3(1.15, 0.9, 0.85)))

	# --- Kollar: omuz → üst kol (kısa kollu gömlek) → dirsek → ön kol → el
	_sh_l = _node(_torso, Vector3(-0.2, 0.5, 0.0))
	_sh_r = _node(_torso, Vector3(0.2, 0.5, 0.0))
	for sh: Node3D in [_sh_l, _sh_r]:
		_sphere(sh, 0.068, Vector3(0, -0.01, 0), "body")                                   # omuz başı
		_capsule(sh, 0.056, L_UPPER + 0.06, Vector3(0, -L_UPPER * 0.5, 0), "body")
		var el := _node(sh, Vector3(0, -L_UPPER, 0))
		_capsule(el, 0.045, 0.27, Vector3(0, -0.12, 0), "skin")
		# El (eldiven/çıplak): avuç + başparmak
		var palm := _capsule(el, 0.034, 0.11, Vector3(0, -L_LOWER + 0.03, 0), "glove", Vector3.ZERO, Vector3(1.1, 1.0, 0.62))
		var thumb := _capsule(el, 0.014, 0.055, Vector3(0.0, -L_LOWER + 0.06, -0.03), "glove", Vector3(0.6, 0, 0))
		_glove_parts.append(palm)
		_glove_parts.append(thumb)
		if sh == _sh_l:
			_el_l = el
		else:
			_el_r = el
	apply_outfit(GameState.get_outfit_data())


# ================================================================ yapım yardımcıları

func _mat(c: Color, rough: float) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = c
	m.roughness = rough
	return m


func _node(parent: Node3D, pos: Vector3) -> Node3D:
	var n := Node3D.new()
	n.position = pos
	parent.add_child(n)
	return n


func _mesh_inst(parent: Node3D, mesh: Mesh, pos: Vector3, mat_key: String, rot: Vector3, scl: Vector3) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	mi.position = pos
	mi.rotation = rot
	mi.scale = scl
	mi.material_override = _mats[mat_key]
	parent.add_child(mi)
	return mi


func _capsule(parent: Node3D, radius: float, height: float, pos: Vector3, mat_key: String, rot: Vector3 = Vector3.ZERO, scl: Vector3 = Vector3.ONE) -> MeshInstance3D:
	var cm := CapsuleMesh.new()
	cm.radius = radius
	cm.height = maxf(height, radius * 2.0 + 0.001)
	cm.radial_segments = 14
	cm.rings = 4
	return _mesh_inst(parent, cm, pos, mat_key, rot, scl)


func _sphere(parent: Node3D, radius: float, pos: Vector3, mat_key: String, scl: Vector3 = Vector3.ONE) -> MeshInstance3D:
	var sm := SphereMesh.new()
	sm.radius = radius
	sm.height = radius * 2.0
	sm.radial_segments = 16
	sm.rings = 8
	return _mesh_inst(parent, sm, pos, mat_key, Vector3.ZERO, scl)


func _box(parent: Node3D, size: Vector3, pos: Vector3, mat_key: String, rot: Vector3 = Vector3.ZERO) -> MeshInstance3D:
	var bm := BoxMesh.new()
	bm.size = size
	return _mesh_inst(parent, bm, pos, mat_key, rot, Vector3.ONE)


## Kıyafet: body (gömlek), legs (pantolon), hat (kasket ya da saç rengi).
## hair=true: kasket yerine saç, eldiven yok. mustache: bıyık (varsayılan: taşıyıcıda var).
func apply_outfit(o: Dictionary) -> void:
	if _mats.is_empty():
		return
	_mats.body.albedo_color = o.get("body", Color.BLUE)
	_mats.legs.albedo_color = o.get("legs", Color.DARK_GRAY)
	_mats.hat.albedo_color = o.get("hat", Color.YELLOW)
	var hair := bool(o.get("hair", false))
	for p in _cap_parts:
		p.visible = not hair
	for p in _hair_parts:
		p.visible = hair
	for p in _glove_parts:
		p.material_override = _mats.skin if hair else _mats.glove
	if _mustache != null:
		_mustache.visible = bool(o.get("mustache", not hair))


# ================================================================ animasyon

## st: {"speed", "holding", "back", "resting", "tired", "backward", "fatigue",
##      "cheer", "wave", "worried", "sad"}
func update_anim(delta: float, st: Dictionary) -> void:
	if crushed:
		return
	_fatigue = lerpf(_fatigue, clampf(float(st.get("fatigue", 0.0)), 0.0, 1.0), 1.0 - exp(-2.0 * delta))
	var speed := float(st.get("speed", 0.0))
	var holding := bool(st.get("holding", false))
	var back := bool(st.get("back", false))
	var resting := bool(st.get("resting", false))
	var tired := bool(st.get("tired", false))
	var backward := bool(st.get("backward", false))
	var dir := -1.0 if backward else 1.0
	_t += delta
	_phase += delta * (2.0 + speed * 3.2) * dir
	var amp := clampf(speed / 2.4, 0.0, 1.0)
	var k := 1.0 - exp(-10.0 * delta)
	_arm_pose = lerpf(_arm_pose, (2.0 if back else 1.0) if holding else 0.0, k)

	# --- Gövde eğilmesi ve çömelme
	var lean_target := 0.04 * amp
	if back and holding:
		lean_target = -0.36
	elif holding:
		lean_target = -0.08
	if tired:
		lean_target -= 0.1
	if holding:
		lean_target -= 0.5 * _fatigue
	if resting:
		lean_target = -0.5
	_lean = lerpf(_lean, lean_target, k)
	_crouch = lerpf(_crouch, 0.2 if resting else (0.12 * _fatigue if holding else 0.0), k)
	_torso.rotation = Vector3(_lean, sin(_phase) * 0.06 * amp, 0.0)
	_hips.position = Vector3(0.0, HIP_Y - _crouch + absf(sin(_phase)) * 0.03 * amp, 0.0)
	_hips.rotation.y = -sin(_phase) * 0.08 * amp

	# --- Bacaklar: kalça salınımı + diz bükülmesi (öne giden bacakta diz kıvrılır)
	var swing := sin(_phase) * 0.55 * amp
	var bend_l := 0.06 + 0.85 * amp * maxf(0.0, cos(_phase))
	var bend_r := 0.06 + 0.85 * amp * maxf(0.0, -cos(_phase))
	var crouch_bend := _crouch * 3.2 + 0.4 * _fatigue * float(holding)
	if resting:
		_hip_l.rotation = Vector3(lerpf(_hip_l.rotation.x, 0.9, k), 0, -0.08)
		_hip_r.rotation = Vector3(lerpf(_hip_r.rotation.x, 0.9, k), 0, 0.08)
		_knee_l.rotation = Vector3(-1.2, 0, 0)
		_knee_r.rotation = Vector3(-1.2, 0, 0)
	else:
		_hip_l.rotation = Vector3(swing + crouch_bend * 0.5, 0, -0.03)
		_hip_r.rotation = Vector3(-swing + crouch_bend * 0.5, 0, 0.03)
		_knee_l.rotation = Vector3(-(bend_l + crouch_bend), 0, 0)
		_knee_r.rotation = Vector3(-(bend_r + crouch_bend), 0, 0)

	_level_feet()

	# --- Kollar
	if _grip_on and holding and not resting:
		# Eller eşyanın tutma noktalarına iki kemikli IK ile uzanır
		_ik(_sh_l, _el_l, _to_torso(_grip_l), -1.0)
		_ik(_sh_r, _el_r, _to_torso(_grip_r), 1.0)
	elif resting:
		_set_arm(_sh_l, _el_l, Vector3(0.55, 0, 0.1), 0.5)
		_set_arm(_sh_r, _el_r, Vector3(0.55, 0, -0.1), 0.5)
	else:
		var arm_sw := swing * 0.9
		_set_arm(_sh_l, _el_l, Vector3(-arm_sw, 0, 0.06), 0.15 + 0.3 * amp + maxf(0.0, -arm_sw) * 0.4)
		_set_arm(_sh_r, _el_r, Vector3(arm_sw, 0, -0.06), 0.15 + 0.3 * amp + maxf(0.0, arm_sw) * 0.4)

	# --- Baş
	var head_x := -0.25 if tired else (-0.12 if back and holding else 0.0)
	if holding:
		head_x -= 0.28 * _fatigue
	_head.rotation = Vector3(head_x, 0, 0)

	# --- Yorgunluk titremesi
	if holding and _fatigue > 0.6 and not resting:
		var tr := (_fatigue - 0.6) * 2.5
		_hips.position.x = sin(_t * 47.0) * 0.01 * tr
		_torso.rotation.z = sin(_t * 31.0) * 0.03 * tr

	# --- Duygu pozları (ev sahibi ve bölüm sonu)
	if bool(st.get("cheer", false)):
		var w := sin(_t * 9.0)
		var jump := absf(sin(_t * 7.0))
		_set_arm(_sh_l, _el_l, Vector3(2.9 + w * 0.12, 0, 0.35), 0.35)
		_set_arm(_sh_r, _el_r, Vector3(2.9 - w * 0.12, 0, -0.35), 0.35)
		_hips.position.y = HIP_Y + jump * 0.2
		_hip_l.rotation = Vector3(jump * 0.5, 0, -0.05)
		_hip_r.rotation = Vector3(jump * 0.5, 0, 0.05)
		_knee_l.rotation = Vector3(-jump * 0.9, 0, 0)
		_knee_r.rotation = Vector3(-jump * 0.9, 0, 0)
		_head.rotation = Vector3(0.2, 0, 0)
		_torso.rotation = Vector3(0.05, 0, 0)
		_level_feet()
	elif bool(st.get("wave", false)):
		_set_arm(_sh_r, _el_r, Vector3(2.5, 0, -0.35), 0.9 + sin(_t * 11.0) * 0.5)
	elif bool(st.get("worried", false)):
		# Eller yanaklara
		var hp := _head.position + Vector3(0, 0.08, -0.06)
		_ik(_sh_l, _el_l, hp + Vector3(-0.1, 0, 0), -1.0)
		_ik(_sh_r, _el_r, hp + Vector3(0.1, 0, 0), 1.0)
		_hips.position.y = HIP_Y + absf(sin(_t * 14.0)) * 0.025
	elif bool(st.get("sad", false)):
		# Eller başın üstünde
		var top := _head.position + Vector3(0, 0.26, -0.02)
		_ik(_sh_l, _el_l, top + Vector3(-0.07, 0, 0), -1.0)
		_ik(_sh_r, _el_r, top + Vector3(0.07, 0, 0), 1.0)
		_head.rotation = Vector3(-0.35, 0, 0)
		_torso.rotation = Vector3(-0.2, 0, 0)


## Ayak bileği: bacak ne kadar dönerse dönsün ayak tabanı yere yakın paralel kalır.
func _level_feet() -> void:
	_ankle_l.rotation.x = -(_hip_l.rotation.x + _knee_l.rotation.x) * 0.8
	_ankle_r.rotation.x = -(_hip_r.rotation.x + _knee_r.rotation.x) * 0.8


## Kolu doğrudan açılarla ayarla: omuz (x: öne kaldır, z: yana aç), dirsek bükülmesi.
func _set_arm(sh: Node3D, el: Node3D, sh_rot: Vector3, elbow: float) -> void:
	sh.rotation = sh_rot
	el.rotation = Vector3(maxf(elbow, 0.0), 0, 0)


func _to_torso(world: Vector3) -> Vector3:
	return _torso.global_transform.affine_inverse() * world


## İki kemikli IK: omuzdan hedef noktaya (gövde uzayında). Dirsek aşağı-dışa doğru bükülür.
## Hedefe yetişemiyorsa kol tam uzanır ve hedefe doğru bakar.
func _ik(sh: Node3D, el: Node3D, target: Vector3, side: float) -> void:
	var s := sh.position
	var to := target - s
	var dist := to.length()
	if dist < 0.01:
		return
	var dir := to / dist
	var d := clampf(dist, 0.12, L_UPPER + L_LOWER - 0.002)
	var cos_a := clampf((L_UPPER * L_UPPER + d * d - L_LOWER * L_LOWER) / (2.0 * L_UPPER * d), -1.0, 1.0)
	var a := acos(cos_a)
	var pole := Vector3(side * 0.6, -1.0, 0.2).normalized()
	var perp := pole - dir * pole.dot(dir)
	if perp.length_squared() < 0.00001:
		perp = Vector3(side, 0, 0)
	perp = perp.normalized()
	var upper := (dir * cos(a) + perp * sin(a)).normalized()
	var elbow_pos := s + upper * L_UPPER
	var fore := (s + dir * d - elbow_pos).normalized()
	var q_sh := _arc(upper)
	sh.quaternion = q_sh
	el.quaternion = q_sh.inverse() * _arc(fore)


## Aşağı (-Y) yönünü verilen yöne çeviren dönüş (tam ters yönde de güvenli).
func _arc(to: Vector3) -> Quaternion:
	if to.dot(Vector3.DOWN) < -0.9995:
		return Quaternion(Vector3.RIGHT, PI)
	return Quaternion(Vector3.DOWN, to)


## Ağır eşyanın altında ezilme: sırtüstü düşer, yassılaşır, kollar ve bacaklar yana açılır.
func play_crushed() -> void:
	if crushed:
		return
	crushed = true
	_set_arm(_sh_l, _el_l, Vector3(0.3, 0, -1.4), 0.2)
	_set_arm(_sh_r, _el_r, Vector3(0.3, 0, 1.4), 0.2)
	_hip_l.rotation = Vector3(0, 0, -0.35)
	_hip_r.rotation = Vector3(0, 0, 0.35)
	_knee_l.rotation = Vector3.ZERO
	_knee_r.rotation = Vector3.ZERO
	_ankle_l.rotation = Vector3.ZERO
	_ankle_r.rotation = Vector3.ZERO
	_torso.rotation = Vector3.ZERO
	_hips.position = Vector3(0, HIP_Y, 0)
	var tw := create_tween()
	tw.set_parallel(true)
	tw.tween_property(self, "rotation:x", PI * 0.5, 0.28).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	tw.tween_property(self, "position:y", 0.14, 0.28)
	tw.chain().tween_property(self, "scale", Vector3(1.3, 1.0, 0.32), 0.12).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)


## Eşyanın tutma noktalarını ver (Player her karede çağırır). active=false: normal kol animasyonu.
func set_grips(left: Vector3, right: Vector3, active: bool) -> void:
	_grip_l = left
	_grip_r = right
	_grip_on = active


func set_head_visible(v: bool) -> void:
	if _head != null:
		_head.visible = v
