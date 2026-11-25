class_name Player
extends CharacterBody3D
## Taşıyıcı karakter: kameraya göre yürüme, ağırlığa göre yavaşlama, merdiven,
## dayanıklılık, eşya alma/bırakma, kapı etkileşimi ve güvenli konum takibi.

signal stamina_changed(value: float)
signal exhausted
signal prompt_changed(text: String, enabled: bool)
signal crushed            # ağır eşyayla güç bitti: altında ezilir
signal picked_up
signal put_down

var input: InputState
var camera_yaw := 0.0
var carry: CarryController
var level_item: CarryItem
var stamina := Config.STAMINA_MAX
var visual: PlayerVisual
var on_stairs := false
var moving := false
var walking_backward := false
var resting := false
var frozen := false
var celebrating := false
var goal_check: Callable          # eşya hedefte mi? (Game sağlar)

var _yaw := 0.0
var _last_safe := Vector3.ZERO
var _safe_timer := 0.0
var _step_timer := 0.0
var _prompt := ""
var _prompt_enabled := false
var _tired_sound_cd := 0.0
var _speed_now := 0.0


func _ready() -> void:
	collision_layer = Config.LAYER_PLAYER
	collision_mask = Config.LAYER_WORLD | Config.LAYER_ITEM | Config.LAYER_OBSTACLE
	floor_max_angle = deg_to_rad(Config.FLOOR_MAX_ANGLE_DEG)
	floor_snap_length = Config.FLOOR_SNAP
	floor_constant_speed = true
	floor_stop_on_slope = true
	floor_block_on_wall = true
	max_slides = 6
	safe_margin = 0.01
	var cs := CollisionShape3D.new()
	var cap := CapsuleShape3D.new()
	cap.radius = Config.PLAYER_RADIUS
	cap.height = Config.PLAYER_HEIGHT
	cs.shape = cap
	cs.position = Vector3(0, Config.PLAYER_HEIGHT * 0.5, 0)
	add_child(cs)
	visual = PlayerVisual.new()
	add_child(visual)
	carry = CarryController.new()
	carry.name = "Carry"
	carry.player = self
	add_child(carry)
	_yaw = global_rotation.y
	_last_safe = global_position


func spawn_at(xf: Transform3D) -> void:
	global_transform = Transform3D(Basis(Vector3.UP, xf.basis.get_euler().y), xf.origin)
	_yaw = xf.basis.get_euler().y
	velocity = Vector3.ZERO
	_last_safe = xf.origin


func get_yaw() -> float:
	return _yaw


func is_holding() -> bool:
	return carry.is_holding()


func _physics_process(delta: float) -> void:
	if input == null:
		return
	_tired_sound_cd = maxf(0.0, _tired_sound_cd - delta)
	if frozen:
		velocity = Vector3.ZERO
		_animate(delta)
		return
	var prev_xf := global_transform
	var prev_yaw := _yaw
	var prev_state := carry.save_state()
	var prev_lag := carry.last_lag

	carry.apply_input(input, delta)
	_locomotion(delta)

	if carry.is_holding():
		var res := carry.follow(delta)
		var lag := float(res.lag)
		if bool(res.rot_blocked):
			# Eşya dönemiyorsa dönüşü geri al (oyuncunun yönü ve tutuş açısı).
			_yaw = prev_yaw
			global_basis = Basis(Vector3.UP, _yaw)
			carry.restore_rotation(prev_state)
		if not carry.in_grace() and lag > Config.ITEM_FOLLOW_MAX_LAG and lag > prev_lag + 0.0005:
			# Eşya takıldı: oyuncu ilerleyemez.
			global_position = prev_xf.origin
			velocity.x = 0.0
			velocity.z = 0.0
			carry.restore_lift(prev_state)
			# Geri alınmış konuma göre yeniden ölç; yoksa bir sonraki karede geri alma atlanır.
			lag = carry.current_lag()
		carry.last_lag = lag
		if lag > Config.ITEM_FORCE_DROP_LAG and not carry.in_grace():
			carry.release(false)
			put_down.emit()
	else:
		carry.last_lag = 0.0

	_update_stamina(delta)
	_update_interaction()
	_handle_actions()
	_track_safe(delta)
	_animate(delta)


func _locomotion(delta: float) -> void:
	var mv := input.move.limit_length(1.0)
	var fwd := Vector3(-sin(camera_yaw), 0.0, -cos(camera_yaw))
	var right := Vector3(cos(camera_yaw), 0.0, -sin(camera_yaw))
	var wish := right * mv.x + fwd * mv.y
	var mag := minf(1.0, wish.length())
	var dir := wish.normalized() if mag > 0.05 else Vector3.ZERO
	var holding := carry.is_holding()
	on_stairs = is_on_floor() and get_floor_normal().y < 0.97

	var speed := Config.WALK_SPEED
	if holding:
		speed *= DamageModel.carry_speed_mult(level_item.get_weight(), level_item.is_back_carry(), on_stairs)
		if stamina < Config.STAMINA_WARN:
			speed *= 0.75
		speed *= lerpf(1.0, 0.7, get_fatigue())
	elif on_stairs:
		speed *= 0.85

	walking_backward = false
	if dir != Vector3.ZERO:
		resting = false
		var target_yaw := atan2(-dir.x, -dir.z)
		var diff := wrapf(target_yaw - _yaw, -PI, PI)
		if holding and absf(diff) > deg_to_rad(110.0):
			# Eşyayla geri geri yürü (dönmeden).
			walking_backward = true
			speed *= 0.7
		else:
			var ts := Config.CARRY_TURN_SPEED if holding else Config.TURN_SPEED
			_yaw = wrapf(_yaw + clampf(diff, -ts * delta, ts * delta), -PI, PI)
			if holding:
				speed *= lerpf(1.0, 0.3, clampf(absf(diff) / (PI * 0.5), 0.0, 1.0))
		global_basis = Basis(Vector3.UP, _yaw)

	var target_vel := dir * speed * mag
	var hv := Vector3(velocity.x, 0.0, velocity.z)
	var accel := Config.ACCELERATION if mag > 0.05 else Config.DECELERATION
	hv = hv.move_toward(target_vel, accel * delta)
	velocity.x = hv.x
	velocity.z = hv.z
	if is_on_floor():
		velocity.y = minf(velocity.y, 0.0)
	else:
		velocity.y = maxf(velocity.y - Config.GRAVITY * delta, -20.0)
	move_and_slide()
	_speed_now = Vector3(velocity.x, 0.0, velocity.z).length()
	moving = _speed_now > 0.2

	# Kediye çarpma
	for i in get_slide_collision_count():
		var c := get_slide_collision(i)
		var col := c.get_collider()
		if col != null and col.has_method("on_bumped"):
			col.call("on_bumped")

	# Adım sesi
	if moving and is_on_floor():
		_step_timer -= delta * (_speed_now / 1.6)
		if _step_timer <= 0.0:
			_step_timer = 0.45
			AudioManager.play_step(on_stairs, holding and level_item != null and level_item.get_weight() >= 20.0)


func _update_stamina(delta: float) -> void:
	var holding := carry.is_holding()
	var weight := level_item.get_weight() if level_item != null else 0.0
	var rate := DamageModel.stamina_rate(holding, weight, moving, on_stairs)
	if resting and not holding:
		rate = maxf(rate, Config.STAMINA_REGEN_REST * 1.25)
	var before := stamina
	stamina = clampf(stamina + rate * delta, 0.0, Config.STAMINA_MAX)
	if absf(before - stamina) > 0.001:
		stamina_changed.emit(stamina)
	if holding and stamina < Config.STAMINA_WARN and _tired_sound_cd <= 0.0 and rate < 0.0:
		_tired_sound_cd = 3.0
		AudioManager.play("tired", -8.0)
	if holding and stamina <= 0.0 and level_item.get_weight() >= Config.CRUSH_WEIGHT:
		# Ağır eşya (buzdolabı, çamaşır makinesi, gardırop): taşıyıcı altında ezilir.
		crushed.emit()
		return
	if holding and stamina <= 0.0:
		# Güç bitti: eşya düşer.
		carry.release(false, Vector3(velocity.x, 0.0, velocity.z) * 0.4)
		AudioManager.play("tired", 0.0)
		Haptics.heavy()
		exhausted.emit()
		put_down.emit()


## Yakındaki etkileşimi bulur ve düğme yazısını günceller.
func _update_interaction() -> void:
	var text := ""
	var enabled := false
	if carry.is_holding():
		text = "DROP"
		enabled = true
	else:
		if _can_pick():
			text = "GRAB"
			enabled = true
		else:
			var door := _nearest_door()
			if door != null:
				text = door.prompt_text(false)
				enabled = door.can_interact(false)
	if text != _prompt or enabled != _prompt_enabled:
		_prompt = text
		_prompt_enabled = enabled
		prompt_changed.emit(text, enabled)


func _can_pick() -> bool:
	if level_item == null or not is_instance_valid(level_item):
		return false
	if level_item.state == CarryItem.State.HELD or level_item.durability <= 0.0:
		return false
	var d := level_item.global_position - global_position
	var reach := Config.PICKUP_RANGE + maxf(level_item.half.x, level_item.half.z)
	return Vector2(d.x, d.z).length() < reach and d.y > -1.0 and d.y < 2.2


func _nearest_door() -> SwingDoor:
	var best: SwingDoor = null
	var best_d := 1.8
	for n in get_tree().get_nodes_in_group("interactable"):
		var door := n as SwingDoor
		if door == null:
			continue
		var d := door.interact_position().distance_to(global_position + Vector3(0, 1.0, 0))
		if d < best_d and door.prompt_text(false) != "":
			best_d = d
			best = door
	return best


func _handle_actions() -> void:
	if input.consume("interact"):
		if carry.is_holding():
			carry.release(true)
			put_down.emit()
		elif _can_pick():
			resting = false
			carry.grab(level_item)
			picked_up.emit()
		else:
			var door := _nearest_door()
			if door != null and door.can_interact(false):
				door.interact()
	if input.consume("rest"):
		if carry.is_holding():
			carry.release(true)
			put_down.emit()
		resting = true
		AudioManager.play("putdown", -10.0, 0.7)


func _track_safe(delta: float) -> void:
	_safe_timer += delta
	if is_on_floor() and _safe_timer > 0.5:
		_safe_timer = 0.0
		_last_safe = global_position


func get_last_safe() -> Vector3:
	return _last_safe


func teleport(pos: Vector3, yaw: float = NAN) -> void:
	global_position = pos
	if not is_nan(yaw):
		_yaw = yaw
		global_basis = Basis(Vector3.UP, _yaw)
	velocity = Vector3.ZERO
	_last_safe = pos


func _animate(delta: float) -> void:
	if visual == null:
		return
	var holding := carry.is_holding()
	visual.update_anim(delta, {
		"speed": _speed_now if not frozen else 0.0,
		"holding": holding,
		"back": holding and level_item != null and level_item.is_back_carry(),
		"resting": resting and not holding,
		"tired": stamina < Config.STAMINA_WARN,
		"backward": walking_backward,
		"cheer": celebrating,
		"fatigue": get_fatigue(),
	})


## Eşyayla geçen yorgunluk (0..1). Hafif eşyalar yormadığı için onlarda hep 0'a yakındır.
func get_fatigue() -> float:
	if not carry.is_holding():
		return 0.0
	return clampf(1.0 - stamina / Config.STAMINA_MAX, 0.0, 1.0)


## Bir noktaya dön (kutlama vb.)
func face_towards(p: Vector3) -> void:
	var d := p - global_position
	if Vector2(d.x, d.z).length() < 0.05:
		return
	_yaw = atan2(-d.x, -d.z)
	global_basis = Basis(Vector3.UP, _yaw)
