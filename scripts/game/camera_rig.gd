class_name CameraRig
extends Node3D
## Karakteri takip eden yörünge kamerası.
## - İki parmak kaydırma: döndürme, sıkıştırma: yakınlaştırma
## - Hazır görünümler: arka, üst (duvarlar kesitli), yan
## - Duvarlara girmez (ışın testi); üst görünümde kesilmiş geometriyi yok sayar.

var target: Player
var camera: Camera3D
var yaw := 0.0
var pitch := deg_to_rad(Config.CAM_PITCH_DEFAULT)
var dist := Config.CAM_DIST_DEFAULT
var fov_target := 70.0
var narrow_view := false
var indoor := false          # bina içindeyken duvarlar baş hizasından kesilir (Game ayarlar)
var current_cut := INF       # etkin kesit yüksekliği (kesit yoksa INF)

var _cur_dist := Config.CAM_DIST_DEFAULT
var _pivot := Vector3.ZERO
var _anim_active := false
var _anim_yaw := 0.0
var _anim_pitch := 0.0
var _anim_dist := 0.0
var _cut_active := false
var _excluded: Array[RID] = []
var _shake := 0.0


func setup(player: Player) -> void:
	target = player
	camera = Camera3D.new()
	camera.fov = 70.0
	camera.near = 0.05
	camera.far = 200.0
	add_child(camera)
	camera.make_current()
	yaw = player.get_yaw()
	_pivot = player.global_position + Vector3(0, 1.55, 0)
	_excluded = [player.get_rid()]


func add_exclude(rid: RID) -> void:
	if not _excluded.has(rid):
		_excluded.append(rid)


func orbit(px: Vector2) -> void:
	if px == Vector2.ZERO:
		return
	var sens := float(GameState.get_setting("camera_sensitivity")) * Config.CAM_ORBIT_DEG_PER_PIXEL
	yaw -= deg_to_rad(px.x * sens)
	pitch = clampf(pitch - deg_to_rad(px.y * sens), deg_to_rad(Config.CAM_PITCH_MIN), deg_to_rad(Config.CAM_PITCH_MAX))
	_anim_active = false


func zoom(amount: float) -> void:
	if amount == 0.0:
		return
	dist = clampf(dist * (1.0 - amount), Config.CAM_DIST_MIN, Config.CAM_DIST_MAX)
	_anim_active = false


func preset(view: String) -> void:
	if target == null:
		return
	var py := target.get_yaw()
	match view:
		"back":
			_start_anim(py, deg_to_rad(-24.0), Config.CAM_DIST_DEFAULT)
		"top":
			_start_anim(py, deg_to_rad(-82.0), 7.5)
		"side":
			_start_anim(py + PI * 0.5, deg_to_rad(-14.0), 5.0)
	AudioManager.play("click", -8.0)


func _start_anim(y: float, p: float, d: float) -> void:
	_anim_active = true
	# En kısa yoldan dön
	_anim_yaw = yaw + wrapf(y - yaw, -PI, PI)
	_anim_pitch = p
	_anim_dist = d


## Belirli bir açıya yumuşakça dön (kutlama sahnesi vb.)
func focus(p_yaw: float, p_pitch_deg: float, p_dist: float) -> void:
	_start_anim(p_yaw, deg_to_rad(p_pitch_deg), p_dist)


func is_top_view() -> bool:
	return pitch < deg_to_rad(-60.0)


func _physics_process(delta: float) -> void:
	if target == null or camera == null:
		return
	if _anim_active:
		var k := 1.0 - exp(-8.0 * delta)
		yaw = lerpf(yaw, _anim_yaw, k)
		pitch = lerpf(pitch, _anim_pitch, k)
		dist = lerpf(dist, _anim_dist, k)
		if absf(yaw - _anim_yaw) < 0.002 and absf(pitch - _anim_pitch) < 0.002 and absf(dist - _anim_dist) < 0.01:
			_anim_active = false
	var desired_pivot := target.global_position + Vector3(0, 1.55, 0)
	_pivot = _pivot.lerp(desired_pivot, 1.0 - exp(-Config.CAM_SMOOTH * delta))
	if _pivot.distance_to(desired_pivot) > 4.0:
		_pivot = desired_pivot

	# Kesit: bina içinde veya üstten görünümde, oyuncunun başının üstündeki her şey gizlenir.
	# Tavanlar ayrı (yarı saydam) çizilir; yalnızca bulunulan katınki görünür.
	var top := is_top_view()
	var cut := top or indoor
	var feet := target.global_position.y
	var cut_h := feet + (Config.CAM_TOP_CUT if top else Config.CAM_INDOOR_CUT)
	if cut:
		RenderingServer.global_shader_parameter_set("cut_height", cut_h)
		RenderingServer.global_shader_parameter_set("ceil_cut_height", feet + Config.CAM_CEILING_SHOW)
	elif _cut_active:
		RenderingServer.global_shader_parameter_set("cut_height", 100000.0)
		RenderingServer.global_shader_parameter_set("ceil_cut_height", 100000.0)
	_cut_active = cut
	current_cut = cut_h if cut else INF

	var rot := Basis.from_euler(Vector3(pitch, yaw, 0.0))
	var dir := rot * Vector3(0, 0, 1)
	var allowed := _ray_distance(_pivot, dir, dist, cut, cut_h)
	# Yaklaşırken hızlı, uzaklaşırken yumuşak
	if allowed < _cur_dist:
		_cur_dist = lerpf(_cur_dist, allowed, 1.0 - exp(-25.0 * delta))
	else:
		_cur_dist = lerpf(_cur_dist, allowed, 1.0 - exp(-4.0 * delta))
	camera.global_position = _pivot + dir * _cur_dist
	if _shake > 0.0:
		_shake = maxf(0.0, _shake - delta * 2.5)
		var s := _shake * _shake * 0.12
		camera.global_position += Vector3(randf_range(-s, s), randf_range(-s, s), randf_range(-s, s))
	if absf(dir.y) > 0.999:
		camera.look_at(_pivot, Vector3(sin(yaw), 0, cos(yaw)) * -1.0)
	else:
		camera.look_at(_pivot, Vector3.UP)
	camera.fov = lerpf(camera.fov, 58.0 if narrow_view else fov_target, 1.0 - exp(-3.0 * delta))
	if target.visual != null:
		target.visual.set_head_visible(_cur_dist > 0.9)


## Pivottan kamera yönüne en fazla ne kadar gidilebilir (duvar çarpışması).
func _ray_distance(from: Vector3, dir: Vector3, max_d: float, cut: bool, cut_h: float) -> float:
	var space := get_world_3d().direct_space_state
	var start := from
	var travelled := 0.0
	for i in 8:
		var remaining := max_d - travelled
		if remaining <= 0.01:
			return max_d
		var q := PhysicsRayQueryParameters3D.create(start, start + dir * remaining, Config.LAYER_WORLD, _excluded)
		var hit := space.intersect_ray(q)
		if hit.is_empty():
			return max_d
		var p: Vector3 = hit.position
		var d := from.distance_to(p)
		if cut and p.y > cut_h - 0.02:
			# Kesitle gizlenmiş geometri: içinden geç.
			travelled = d + 0.02
			start = from + dir * travelled
			continue
		return maxf(0.3, d - Config.CAM_COLLISION_MARGIN)
	return max_d


## Sert çarpmada kısa kamera sarsıntısı (0..1)
func shake(amount: float) -> void:
	_shake = clampf(maxf(_shake, amount), 0.0, 1.0)


func get_forward_yaw() -> float:
	return yaw
