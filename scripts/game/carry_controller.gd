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
var _pending_rot := Vector3.ZERO   # dev eşyada henüz uygulanmamış çevirme (yaw, pitch, roll derece)
const GIANT_HALF_DIAG := 1.5
var fine_mult := 1.0     # Player ayarlar: evin içinde eşya çevirme daha hassas


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
	_pending_rot = Vector3.ZERO
	it.pick_up()


func release(gentle: bool, velocity: Vector3 = Vector3.ZERO) -> void:
	if item == null or not is_instance_valid(item):
		return
	_pending_rot = Vector3.ZERO
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
	_pending_rot = Vector3.ZERO   # takılan dönüş birikmesin (oyuncunun dönüşünü kilitlemesin)
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
		_pending_rot = Vector3.ZERO
		AudioManager.play("click", -6.0)
	var sens := float(GameState.get_setting("sensitivity"))
	var mult := (Config.PRECISE_MULT if input.precise else 1.0) * fine_mult
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
	# Dev eşya yavaş döner: ucunun hızı ITEM_MAX_TIP_SPEED'i geçmez (yoksa eşya geride kalıp düşer).
	# Kaydırmanın fazlası atılmaz, sonraki karelerde tamamlanır. Normal eşyalar etkilenmez.
	if is_giant():
		_pending_rot += Vector3(yaw, pitch, roll)
		var lim := max_rotation_deg(delta)
		var total := absf(_pending_rot.x) + absf(_pending_rot.y) + absf(_pending_rot.z)
		var f := minf(1.0, lim / maxf(total, 0.0001))
		yaw = _pending_rot.x * f
		pitch = _pending_rot.y * f
		roll = _pending_rot.z * f
		_pending_rot -= Vector3(yaw, pitch, roll)
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


## Dev eşya mı (fabrika bölümleri): çevirme hızı sınırlanır.
func is_giant() -> bool:
	return item != null and item.half.length() > GIANT_HALF_DIAG


## Bu karede eşyanın en fazla kaç derece dönebileceği (boyuna göre).
func max_rotation_deg(delta: float) -> float:
	if item == null:
		return 360.0
	return rad_to_deg(Config.ITEM_MAX_TIP_SPEED * delta / maxf(0.3, item.half.length()))


## Kaldıraç çarpanı: eşyanın ağırlık merkezi gövdeden ne kadar uzaksa taşımak o kadar yorar.
## Sırttaki eşya ve fabrikanın dev eşyaları (hep ucundan tutulur) için 1.
func leverage() -> float:
	if not is_holding() or item.is_back_carry() or is_giant():
		return 1.0
	var h := _local_hold()
	var local: Vector3 = h.local
	var dist := Vector2(local.x, local.z).length()
	var f := 1.0 + Config.LEVER_PER_M * maxf(0.0, dist - Config.LEVER_FREE_DIST) + Config.LEVER_LIFT_PER_M * maxf(0.0, lift)
	return clampf(f, 1.0, Config.LEVER_MAX)


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
		# İleriye bakış: eşyanın altında basamak varsa (oyuncu henüz düz zemindeyken bile)
		# eşya önceden yükselir; alt kenarı basamağa takılmaz.
		if not item.is_back_carry():
			target = maxf(target, _ground_lift())
	slope_comp = lerpf(slope_comp, target, 1.0 - exp(-6.0 * delta))


## Eşyanın altındaki en yüksek zemin (basamak) için gereken yükselme; yoksa 0.
func _ground_lift() -> float:
	if item == null:
		return 0.0
	var h := _local_hold()
	var local: Vector3 = h.local
	var ext := DamageModel.rotated_half_extents(h.basis, item.half)
	var pb := player.global_basis.orthonormalized()
	var center: Vector3 = player.global_position + pb * Vector3(local.x, 0.0, local.z)
	var feet: float = player.global_position.y
	var bottom: float = feet + local.y - ext.y
	var space := player.get_world_3d().direct_space_state
	var along := pb.z
	var across := pb.x
	var ground := -INF
	# Eşyanın boyunca ve iki ucunun 35 cm ötesinde (bir sonraki basamağın rıhtına takılmasın)
	for k: float in [-1.0, -0.5, 0.0, 0.5, 1.0, 1.5, -1.5]:
		for s: float in [-0.8, 0.0, 0.8]:
			var reach := k * ext.z if absf(k) <= 1.0 else signf(k) * (ext.z + 0.35)
			var p := center + along * reach + across * (s * ext.x)
			var q := PhysicsRayQueryParameters3D.create(Vector3(p.x, bottom + 0.6, p.z), Vector3(p.x, feet - 0.3, p.z), Config.LAYER_STEPS | Config.LAYER_WORLD, [item.get_rid(), player.get_rid()])
			var hit := space.intersect_ray(q)
			if not hit.is_empty():
				ground = maxf(ground, float(hit.position.y))
	if ground < feet + 0.05:
		return 0.0
	return clampf(ground + 0.1 - bottom, 0.0, 0.9)


## Eşyayı hedefe doğru hareket ettirir. Sonuç: {"lag", "rot_blocked"}
func follow(delta: float) -> Dictionary:
	if not is_holding():
		return {"lag": 0.0, "rot_blocked": false}
	_update_slope_comp(delta)
	var res := item.follow(target_transform(), delta)
	return res


## Ellerin eşyayı tuttuğu iki nokta (dünya koordinatı): [sol, sağ].
## Dar eşya yanlardan, geniş eşya (koltuk, TV) yakın kenarının altından, sırttaki eşya
## omuz üstünden kavranır. Eşyanın gerçek konumu kullanılır: eller eşyayla birlikte hareket eder.
func grip_points() -> Array:
	var c := item.global_position
	var pb := player.global_basis.orthonormalized()
	var right := pb.x
	var fwd := -pb.z
	var ext := DamageModel.rotated_half_extents((pb.inverse() * item.global_basis).orthonormalized(), item.half)
	if item.is_back_carry():
		# Sırttaki eşya oyuncunun arkasında: yakın yüz oyuncuya (ileri) bakar
		var near := c + fwd * ext.z
		var y := player.global_position.y + 1.55
		var p := Vector3(near.x, y, near.z)
		return [p - right * 0.2, p + right * 0.2]
	var w := ext.x
	if w <= 0.34:
		# Yanlardan kavra (oyuncuya biraz yakın)
		var mid := c - fwd * (ext.z * 0.25)
		return [mid - right * (w + 0.015), mid + right * (w + 0.015)]
	# Geniş eşya: yakın kenarın altından tut
	var base := c - fwd * (ext.z - 0.05) - Vector3.UP * (ext.y * 0.7)
	# Dev eşya: eller insan boyunda kalır (eşya yukarı doğru uzanır)
	base.y = minf(base.y, player.global_position.y + 1.45)
	return [base - right * 0.28, base + right * 0.28]


## Eşyanın şu anki hedefe uzaklığı.
func current_lag() -> float:
	if not is_holding():
		return 0.0
	return item.global_position.distance_to(target_transform().origin)


func in_grace() -> bool:
	return is_holding() and item.grace > 0.0
