class_name CarryItem
extends CharacterBody3D
## Taşınan eşya. Kinematik olarak hareket eder: elde tutulurken hedef konumu
## çarpışma testleriyle takip eder, bırakılınca yere düşer veya yavaşça iner.
## Çarpma hızı ve çarpan yüze göre hasar alır; yaklaşan yüzleri sarı yakar.

signal damaged(amount: float, durability: float, face: String, hard: bool)
signal destroyed
signal proximity_changed(faces: Array)
signal landed(on_floor: bool)
## Her yüzey teması (çizik, toz, kopan parça efektleri için): nokta, yüzey normali,
## eşyanın hızı, verilen hasar ve sert çarpma mı
signal surface_contact(point: Vector3, normal: Vector3, velocity: Vector3, damage: float, hard: bool)

enum State { FREE, HELD, LOWERING }

const MAX_FOLLOW_SPEED := 5.0
const FLOOR_NORMAL_Y := 0.55

var data: Dictionary = {}
var half := Vector3(0.25, 0.25, 0.25)
var durability := Config.DURABILITY_MAX
var hit_count := 0
var total_damage := 0.0
var state := State.FREE
var resting := false
var grace := 0.0
var exclude_rids: Array = []   # RID listesi (kendisi + elde tutan oyuncu)

var _fall_velocity := Vector3.ZERO
var _shape: BoxShape3D
var _shape_small: BoxShape3D
var _shape_big: BoxShape3D
var _query := PhysicsShapeQueryParameters3D.new()
var _visual: Node3D
var _parts: Array[MeshInstance3D] = []
var _face_meshes := {}
var _face_mat: StandardMaterial3D
var _overlay: StandardMaterial3D
var _flash := 0.0
var _last_contact := -10.0
var _prox_faces: Array = []
var _prox_frame := 0
var _support_timer := 0.0
var _lower_time := 0.0
var _pulse := 0.0


func setup(item_data: Dictionary) -> void:
	data = item_data
	var size: Vector3 = data.size
	half = size * 0.5


func _ready() -> void:
	collision_layer = Config.LAYER_ITEM
	collision_mask = Config.LAYER_WORLD | Config.LAYER_OBSTACLE
	add_to_group("carry_item")
	var size := half * 2.0
	_shape = BoxShape3D.new()
	_shape.size = size
	_shape_small = BoxShape3D.new()
	_shape_small.size = Vector3(maxf(size.x - 0.02, 0.01), maxf(size.y - 0.02, 0.01), maxf(size.z - 0.02, 0.01))
	_shape_big = BoxShape3D.new()
	_shape_big.size = size + Vector3.ONE * Config.PROXIMITY_MARGIN * 2.0
	var cs := CollisionShape3D.new()
	cs.shape = _shape
	add_child(cs)
	_build_visual()
	exclude_rids = [get_rid()]


func _build_visual() -> void:
	_visual = Node3D.new()
	_visual.name = "Visual"
	add_child(_visual)
	for p in data.get("parts", []):
		var mi := MeshInstance3D.new()
		var psize: Vector3 = p.size
		match str(p.get("shape", "box")):
			"cyl_z":
				var cm := CylinderMesh.new()
				cm.top_radius = psize.x * 0.5
				cm.bottom_radius = psize.x * 0.5
				cm.height = psize.z
				cm.radial_segments = 24
				mi.mesh = cm
				mi.rotation = Vector3(PI * 0.5, 0, 0)
			"sphere":
				var sm := SphereMesh.new()
				sm.radius = 0.5
				sm.height = 1.0
				mi.mesh = sm
				mi.scale = psize
			_:
				var bm := BoxMesh.new()
				bm.size = psize
				mi.mesh = bm
		mi.position = p.pos
		var mat := StandardMaterial3D.new()
		mat.albedo_color = p.color
		mat.roughness = 0.45
		var pc: Color = p.color
		# Açık renkli, mavimsi ince parçalar (ekran, cam) parlak olsun
		if psize.z < 0.01 or psize.y < 0.01:
			mat.roughness = 0.12
			mat.metallic = 0.2
		if pc.v > 0.85 and pc.s < 0.1:
			mat.roughness = 0.3
		mi.material_override = mat
		_visual.add_child(mi)
		_parts.append(mi)
	_overlay = StandardMaterial3D.new()
	_overlay.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_overlay.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_overlay.albedo_color = Color(1.0, 0.1, 0.05, 0.0)
	_overlay.no_depth_test = false
	# Yakınlık uyarısı panelleri (her yüz için ince levha)
	_face_mat = StandardMaterial3D.new()
	_face_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_face_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_face_mat.albedo_color = Color(1.0, 0.85, 0.1, 0.55)
	_face_mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	var e := 0.012
	var defs := {
		"right": [Vector3(half.x + e, 0, 0), Vector3(0.004, half.y * 2.0, half.z * 2.0)],
		"left": [Vector3(-half.x - e, 0, 0), Vector3(0.004, half.y * 2.0, half.z * 2.0)],
		"top": [Vector3(0, half.y + e, 0), Vector3(half.x * 2.0, 0.004, half.z * 2.0)],
		"bottom": [Vector3(0, -half.y - e, 0), Vector3(half.x * 2.0, 0.004, half.z * 2.0)],
		"back": [Vector3(0, 0, half.z + e), Vector3(half.x * 2.0, half.y * 2.0, 0.004)],
		"front": [Vector3(0, 0, -half.z - e), Vector3(half.x * 2.0, half.y * 2.0, 0.004)],
	}
	for face in defs:
		var mi := MeshInstance3D.new()
		var bm := BoxMesh.new()
		bm.size = defs[face][1]
		mi.mesh = bm
		mi.position = defs[face][0]
		mi.material_override = _face_mat
		mi.visible = false
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		_visual.add_child(mi)
		_face_meshes[face] = mi


# ================================================================ durum geçişleri

func place_on_ground(bottom_center: Vector3, yaw: float = 0.0) -> void:
	global_transform = Transform3D(Basis(Vector3.UP, yaw), bottom_center + Vector3(0, half.y + 0.03, 0))
	state = State.FREE
	resting = false
	_fall_velocity = Vector3.ZERO
	grace = 0.5   # yere konarken oturma darbesi hasar vermesin


func pick_up() -> void:
	state = State.HELD
	resting = false
	grace = 0.6
	_fall_velocity = Vector3.ZERO
	AudioManager.play("pickup", -4.0)


func put_down() -> void:
	if state != State.HELD:
		return
	state = State.LOWERING
	_lower_time = 0.0
	_set_prox([])


func drop(initial_velocity: Vector3 = Vector3.ZERO) -> void:
	state = State.FREE
	resting = false
	_fall_velocity = initial_velocity
	_set_prox([])


func is_held() -> bool:
	return state == State.HELD


func is_settled() -> bool:
	return state == State.FREE and resting


# ================================================================ takip (elde)

## Hedef dönüşümü (transform) çarpışma testleriyle takip eder.
## Döner: {"lag": hedefe kalan mesafe, "rot_blocked": dönüş engellendi mi}
func follow(target: Transform3D, delta: float) -> Dictionary:
	var result := {"lag": 0.0, "rot_blocked": false}
	if state != State.HELD:
		return result
	# Eşya şu an bir şeyin içindeyse dönüş testlerini atla (kilitlenmeyi önler).
	var stuck := _overlaps(global_transform, _shape_small)

	# --- Dönüş: küçük adımlarla, her adımda çakışma testi
	var cur_q := global_basis.orthonormalized().get_rotation_quaternion()
	var tgt_q := target.basis.orthonormalized().get_rotation_quaternion()
	var ang := cur_q.angle_to(tgt_q)
	if ang > 0.0005:
		var steps := maxi(1, int(ceil(rad_to_deg(ang) / Config.ROTATION_SUBSTEP_DEG)))
		var reached := cur_q
		for i in range(1, steps + 1):
			var q := cur_q.slerp(tgt_q, float(i) / steps)
			if not stuck and _overlaps(Transform3D(Basis(q), global_position), _shape_small):
				result.rot_blocked = true
				break
			reached = q
		global_basis = Basis(reached)
		if result.rot_blocked:
			_register_contact(0.0, _nearest_contact_face(), delta, false)

	# --- Öteleme: kaydırarak çarpışmalı hareket
	var motion := target.origin - global_position
	var max_step := MAX_FOLLOW_SPEED * delta
	if motion.length() > max_step:
		motion = motion.normalized() * max_step
	var vel := motion / maxf(delta, 0.0001)
	var remaining := motion
	for i in 4:
		if remaining.length_squared() < 1e-8:
			break
		var col := move_and_collide(remaining, false, 0.002)
		if col == null:
			break
		_on_collision(col, vel, delta)
		remaining = col.get_remainder().slide(col.get_normal())
	result.lag = global_position.distance_to(target.origin)
	return result


func _on_collision(col: KinematicCollision3D, vel: Vector3, delta: float, floor_exempt: bool = false) -> void:
	var nrm := col.get_normal()
	var collider := col.get_collider()
	var is_obstacle := false
	if collider != null and collider.has_method("on_bumped"):
		collider.call("on_bumped")
		is_obstacle = true
	if floor_exempt and nrm.y > FLOOR_NORMAL_Y:
		return
	var impact := maxf(0.0, -vel.dot(nrm))
	var point := col.get_position()
	var face := _face_at(point)
	var dmg := _register_contact(impact, face, delta, is_obstacle)
	if not is_obstacle and grace <= 0.0:
		surface_contact.emit(point, nrm, vel, dmg, dmg >= 6.0)


## Temas kaydı ve hasar. Yeni temas tam hasar, süren temas sürtünme hasarı verir.
func _register_contact(impact: float, face: String, delta: float, is_obstacle: bool) -> float:
	if grace > 0.0 or durability <= 0.0:
		return 0.0
	var now := Time.get_ticks_msec() / 1000.0
	var fresh := now - _last_contact > Config.CONTACT_COOLDOWN
	_last_contact = now
	var fragility := float(data.get("fragility", 1.0))
	var mult := DamageModel.face_multiplier(data, face)
	var dmg := 0.0
	var hard := false
	if fresh:
		dmg = DamageModel.impact_damage(impact, fragility, mult)
		if is_obstacle:
			dmg = maxf(dmg, Config.OBSTACLE_BUMP_DAMAGE * fragility)
		hard = dmg >= 6.0
		if dmg <= 0.0:
			dmg = DamageModel.scrape_damage(delta, fragility, mult)
	else:
		dmg = DamageModel.scrape_damage(delta, fragility, mult)
	apply_damage(dmg, face, hard, fresh and dmg >= 0.5)
	return dmg


func apply_damage(amount: float, face: String, hard: bool, counts_as_hit: bool) -> void:
	if amount <= 0.0 or durability <= 0.0:
		return
	durability = maxf(0.0, durability - amount)
	total_damage += amount
	if counts_as_hit:
		hit_count += 1
		_flash = Config.FLASH_TIME
		if hard:
			AudioManager.play("crack" if amount > 15.0 else "thud", 0.0)
		else:
			AudioManager.play("bump", -3.0)
	else:
		AudioManager.play("scrape", -10.0, 1.0, 0.3)
	damaged.emit(amount, durability, face, hard)
	if durability <= 0.0:
		destroyed.emit()


func _face_at(world_point: Vector3) -> String:
	var local := global_transform.affine_inverse() * world_point
	return DamageModel.face_from_local(local, half)


func _nearest_contact_face() -> String:
	if not _prox_faces.is_empty():
		return str(_prox_faces[0])
	return "front"

func _physics_process(delta: float) -> void:
	grace = maxf(0.0, grace - delta)
	_update_flash(delta)
	match state:
		State.HELD:
			_prox_frame += 1
			if _prox_frame % 2 == 0:
				_update_proximity()
			_pulse += delta
			_face_mat.albedo_color.a = 0.4 + 0.25 * sin(_pulse * 12.0)
		State.LOWERING:
			_process_lowering(delta)
		State.FREE:
			_process_free(delta)


func _process_lowering(delta: float) -> void:
	_lower_time += delta
	_try_upright(delta)
	var motion := Vector3.DOWN * Config.PUT_DOWN_SPEED * delta
	var vel := Vector3.DOWN * Config.PUT_DOWN_SPEED
	for i in 3:
		if motion.length_squared() < 1e-9:
			break
		var col := move_and_collide(motion, false, 0.002)
		if col == null:
			break
		if col.get_normal().y > FLOOR_NORMAL_Y:
			state = State.FREE
			resting = true
			AudioManager.play("putdown", -4.0)
			landed.emit(true)
			return
		_on_collision(col, vel, delta, true)
		motion = col.get_remainder().slide(col.get_normal())
	if _lower_time > 4.0:
		# Uzun süre yere ulaşamadıysa normal düşmeye geç.
		state = State.FREE
		resting = false


## Hafif eğik eşyayı iniş sırasında düzeltir (yalnızca yer varsa).
func _try_upright(delta: float) -> void:
	var b := global_basis.orthonormalized()
	var tilt := b.y.angle_to(Vector3.UP)
	if tilt < 0.01 or tilt > deg_to_rad(30.0):
		return
	var fwd := -b.z
	fwd.y = 0.0
	if fwd.length_squared() < 0.01:
		return
	var upright := Basis.looking_at(fwd.normalized(), Vector3.UP)
	var q := b.get_rotation_quaternion().slerp(upright.get_rotation_quaternion(), clampf(delta * 4.0, 0.0, 1.0))
	var xf := Transform3D(Basis(q), global_position)
	if not _overlaps(xf, _shape_small):
		global_basis = Basis(q)


func _process_free(delta: float) -> void:
	if resting:
		_support_timer += delta
		if _support_timer > 0.25:
			_support_timer = 0.0
			# Altı boşaldıysa (ör. kedi çekildi) tekrar düş.
			if not test_move(global_transform, Vector3.DOWN * 0.06):
				resting = false
		return
	_fall_velocity.y = maxf(_fall_velocity.y - Config.ITEM_GRAVITY * delta, -Config.ITEM_MAX_FALL_SPEED)
	_fall_velocity.x = move_toward(_fall_velocity.x, 0.0, 2.0 * delta)
	_fall_velocity.z = move_toward(_fall_velocity.z, 0.0, 2.0 * delta)
	var motion := _fall_velocity * delta
	for i in 3:
		if motion.length_squared() < 1e-9:
			break
		var col := move_and_collide(motion, false, 0.002)
		if col == null:
			break
		var nrm := col.get_normal()
		var impact := maxf(0.0, -_fall_velocity.dot(nrm))
		var collider := col.get_collider()
		if collider != null and collider.has_method("on_bumped"):
			collider.call("on_bumped")
		if impact > Config.IMPACT_THRESHOLD and grace <= 0.0:
			var face := _face_at(col.get_position())
			var dmg := DamageModel.impact_damage(impact, float(data.get("fragility", 1.0)), DamageModel.face_multiplier(data, face)) * Config.DROP_DAMAGE_MULT
			apply_damage(dmg, face, dmg >= 6.0, true)
			surface_contact.emit(col.get_position(), nrm, _fall_velocity, dmg, dmg >= 6.0)
		if nrm.y > FLOOR_NORMAL_Y:
			resting = true
			_fall_velocity = Vector3.ZERO
			landed.emit(true)
			return
		_fall_velocity = _fall_velocity.slide(nrm) * 0.6
		motion = col.get_remainder().slide(nrm)


# ================================================================ yakınlık ve görsel

func _update_proximity() -> void:
	var space := get_world_3d().direct_space_state
	_query.shape = _shape_big
	_query.transform = global_transform
	_query.collision_mask = collision_mask
	_query.exclude = exclude_rids
	var pts := space.collide_shape(_query, 12)
	var faces: Array = []
	var inv := global_transform.affine_inverse()
	var big_half := half + Vector3.ONE * Config.PROXIMITY_MARGIN
	for i in range(0, pts.size(), 2):
		var f := DamageModel.face_from_local(inv * pts[i], big_half)
		if not faces.has(f):
			faces.append(f)
	_set_prox(faces)


func _set_prox(faces: Array) -> void:
	for f in _face_meshes:
		_face_meshes[f].visible = faces.has(f)
	var changed := faces.size() != _prox_faces.size()
	if not changed:
		for f in faces:
			if not _prox_faces.has(f):
				changed = true
	_prox_faces = faces
	if changed:
		proximity_changed.emit(faces)


func get_proximity_faces() -> Array:
	return _prox_faces


func _update_flash(delta: float) -> void:
	if _flash <= 0.0:
		return
	_flash = maxf(0.0, _flash - delta)
	_overlay.albedo_color.a = (_flash / Config.FLASH_TIME) * 0.55
	var mat: Material = _overlay if _flash > 0.0 else null
	for p in _parts:
		p.material_overlay = mat


func _overlaps(xf: Transform3D, shape: Shape3D) -> bool:
	var space := get_world_3d().direct_space_state
	_query.shape = shape
	_query.transform = xf
	_query.collision_mask = collision_mask
	_query.exclude = exclude_rids
	return not space.intersect_shape(_query, 1).is_empty()


## Eşya şu an bir yere gömülü mü? (kurtarma için)
func is_overlapping() -> bool:
	return _overlaps(global_transform, _shape_small)


## Parçalanma efekti için görünüm parçalarının dünya konumu, boyutu ve rengi.
func get_debris_parts() -> Array:
	var out: Array = []
	for p in data.get("parts", []):
		var psize: Vector3 = p.size
		var ppos: Vector3 = p.pos
		out.append({"pos": global_transform * ppos, "size": psize, "color": p.color, "basis": global_basis})
	return out


## Kırılınca görüntüyü gizle (parçalar efekt olarak saçılır).
func hide_visual() -> void:
	if _visual != null:
		_visual.visible = false
	_set_prox([])


func get_weight() -> float:
	return float(data.get("weight", 10.0))


func is_back_carry() -> bool:
	return str(data.get("carry", "hands")) == "back"
