class_name CarryController
extends Node
## Oyuncunun elindeki eşyanın tutuş açısını, yüksekliğini ve hedef konumunu yönetir.
## Eşya bir yere takılırsa oyuncunun hareketi geri alınır (Player tarafından).

var player: CharacterBody3D
var item: CarryItem
var hold_basis := Basis()
var lift := 0.0
var slope_comp := 0.0
var last_lag := 0.0
var rotated_total_deg := 0.0
var lift_used := false


func is_holding() -> bool:
	return item != null and is_instance_valid(item) and item.is_held()


func grab(it: CarryItem) -> void:
	if it == null or not is_instance_valid(it):
		return
	item = it
	player.add_collision_exception_with(it)
	it.exclude_rids = [it.get_rid(), player.get_rid()]
	if it.is_back_carry():
		hold_basis = Basis()
	else:
		# Mevcut duruşu koru (en yakın 90°'ye yuvarlanmış yaw ile), böylece eşya alınırken savrulmaz.
		var rel := (player.global_basis.inverse() * it.global_basis).orthonormalized()
		hold_basis = _snap_basis(rel)
	lift = 0.0
	slope_comp = 0.0
	last_lag = 0.0
	it.pick_up()


func release(gentle: bool, velocity: Vector3 = Vector3.ZERO) -> void:
	if item == null or not is_instance_valid(item):
		return
	if gentle:
		item.put_down()
	else:
		item.drop(velocity)
	player.remove_collision_exception_with(item)
	item.exclude_rids = [item.get_rid()]


## Dönüşü 90°'lik eksenlere yaklaştırır (eşya alındığında düzgün tutulsun).
func _snap_basis(b: Basis) -> Basis:
	var axes := [Vector3.RIGHT, Vector3.LEFT, Vector3.UP, Vector3.DOWN, Vector3.BACK, Vector3.FORWARD]
	var x := _closest_axis(b.x, axes)
	var y := _closest_axis(b.y, axes)
	if absf(x.dot(y)) > 0.5:
		return Basis()
	return Basis(x, y, x.cross(y))


func _closest_axis(v: Vector3, axes: Array) -> Vector3:
	var best: Vector3 = axes[0]
	var best_d := -2.0
	for a in axes:
		var d: float = v.dot(a)
		if d > best_d:
			best_d = d
			best = a
	return best


func save_state() -> Dictionary:
	return {"basis": hold_basis, "lift": lift}


func restore_rotation(st: Dictionary) -> void:
	hold_basis = st.basis


func restore_lift(st: Dictionary) -> void:
	lift = st.lift


## Girdiden döndürme ve kaldırma uygular.
func apply_input(input: InputState, delta: float) -> void:
	var px := input.take_rotate_px()
	if not is_holding():
		return
	if input.consume("reset_rotation"):
		hold_basis = Basis()
		AudioManager.play("click", -6.0)
	var sens := float(GameState.get_setting("sensitivity"))
	var mult := Config.PRECISE_MULT if input.precise else 1.0
	var deg := px * Config.ROTATE_DEG_PER_PIXEL * sens * mult
	var yaw := 0.0
	var pitch := 0.0
	var roll := 0.0
	if input.roll_mode:
		roll = deg.x
		pitch = deg.y
	else:
		yaw = deg.x
		pitch = deg.y
	var k := Config.KEY_ROTATE_DEG_PER_SEC * delta * mult
	yaw += input.key_rotate.x * k
	pitch += input.key_rotate.y * k
	roll += input.key_rotate.z * k
	if bool(GameState.get_setting("invert_pitch")):
		pitch = -pitch
	var before := hold_basis
	if yaw != 0.0:
		hold_basis = Basis(Vector3.UP, deg_to_rad(-yaw)) * hold_basis
	if pitch != 0.0:
		hold_basis = Basis(Vector3.RIGHT, deg_to_rad(pitch)) * hold_basis
	if roll != 0.0:
		hold_basis = Basis(Vector3.FORWARD, deg_to_rad(roll)) * hold_basis
	hold_basis = hold_basis.orthonormalized()
	if item.is_back_carry() and hold_basis.y.angle_to(Vector3.UP) > deg_to_rad(Config.BACK_ROT_LIMIT_DEG):
		hold_basis = before
	rotated_total_deg += absf(yaw) + absf(pitch) + absf(roll)
	if input.lift != 0.0:
		lift_used = true
		lift = clampf(lift + input.lift * Config.LIFT_SPEED * (0.4 if input.precise else 1.0) * delta, Config.LIFT_MIN, Config.LIFT_MAX)


func _local_hold() -> Dictionary:
	var hb := hold_basis.orthonormalized()
	var ext := DamageModel.rotated_half_extents(hb, item.half)
	var local := Vector3.ZERO
	if item.is_back_carry():
		local.z = ext.z + Config.PLAYER_RADIUS + 0.06
		local.y = maxf(1.05, ext.y + 0.25) + lift
	else:
		local.z = -(ext.z + Config.PLAYER_RADIUS + Config.HOLD_GAP)
		local.y = maxf(Config.HOLD_HEIGHT + lift, ext.y + 0.04)
	return {"basis": hb, "local": local}


func target_transform() -> Transform3D:
	var h := _local_hold()
	var pb := player.global_basis.orthonormalized()
	var local: Vector3 = h.local
	local.y += slope_comp
	return Transform3D(pb * h.basis, player.global_position + pb * local)


## Merdivende eşya eğime göre otomatik yükselir/alçalır.
func _update_slope_comp(delta: float) -> void:
	var target := 0.0
	if player.is_on_floor():
		var nrm: Vector3 = player.get_floor_normal()
		if nrm.y > 0.3 and nrm.y < 0.995:
			var h := _local_hold()
			var local: Vector3 = h.local
			var dir := player.global_basis * Vector3(0, 0, signf(local.z))
			dir.y = 0.0
			if dir.length_squared() > 0.0001:
				dir = dir.normalized()
				var rise := -nrm.dot(dir) / nrm.y
				target = clampf(rise * absf(local.z), -0.7, 0.9)
	slope_comp = lerpf(slope_comp, target, 1.0 - exp(-6.0 * delta))


## Eşyayı hedefe doğru hareket ettirir. Sonuç: {"lag", "rot_blocked"}
func follow(delta: float) -> Dictionary:
	if not is_holding():
		return {"lag": 0.0, "rot_blocked": false}
	_update_slope_comp(delta)
	var res := item.follow(target_transform(), delta)
	return res


func in_grace() -> bool:
	return is_holding() and item.grace > 0.0
