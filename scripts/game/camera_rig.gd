class_name CameraRig
extends Node3D
## Karakteri takip eden yörünge kamerası.
## - İki parmak kaydırma: döndürme, sıkıştırma: yakınlaştırma
## - Hazır görünümler: arka, üst (duvarlar kesitli), yan
## - Duvarlara girmez (ışın testi); üst görünümde kesilmiş geometriyi yok sayar.
## - Serbest bakış (LOOK): karakter yerinde durur, kamera sahnede her yere götürülür,
##   yukarı/aşağı yükseltilir ve her yöne döndürülür.

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

# Serbest bakış
var free_look := false
var bounds := AABB(Vector3(-16, -0.5, -16), Vector3(32, 30, 40))   # Game sahneye göre ayarlar
var _free_pivot := Vector3.ZERO
var _return_time := 0.0
# Karaktere bağlı takip: kamera karakterin arkasında kalır; elle çevrilince bir süre sonra geri döner
var yaw_offset := 0.0
var _orbit_hold := 0.0
## SIDE / TOP seçilince kamera o açıda kalır; kendiliğinden arkaya dönmez (BACK ile çözülür).
var view_locked := false
# Birinci şahıs: kamera gözde; kafa (fp_yaw/fp_pitch) gövdeden bağımsız döner
var first_person := false
var fp_yaw := 0.0
var fp_pitch := 0.0


func setup(player: Player) -> void:
	target = player
	camera = Camera3D.new()
	camera.fov = 70.0
	camera.near = 0.05
	camera.far = 200.0
	add_child(camera)
	camera.make_current()
	yaw = player.get_yaw()
	_pivot = player.global_position + Vector3(0, Config.CAM_PIVOT_HEIGHT, 0)
	_excluded = [player.get_rid()]


func add_exclude(rid: RID) -> void:
	if not _excluded.has(rid):
		_excluded.append(rid)


func orbit(px: Vector2) -> void:
	if px == Vector2.ZERO:
		return
	var sens := float(GameState.get_setting("camera_sensitivity")) * Config.CAM_ORBIT_DEG_PER_PIXEL
	if first_person:
		# Yalnızca kafa döner: gövde, eller ve eşya yerinde kalır
		var ylim := deg_to_rad(Config.FP_YAW_LIMIT_DEG)
		fp_yaw = clampf(fp_yaw - deg_to_rad(px.x * sens), -ylim, ylim)
		fp_pitch = clampf(fp_pitch - deg_to_rad(px.y * sens), -deg_to_rad(Config.FP_PITCH_DOWN_DEG), deg_to_rad(Config.FP_PITCH_UP_DEG))
		return
	yaw -= deg_to_rad(px.x * sens)
	yaw_offset = wrapf(yaw_offset - deg_to_rad(px.x * sens), -PI, PI)
	_orbit_hold = Config.CAM_RECENTER_DELAY
	var max_p := Config.CAM_FREE_PITCH_MAX if free_look else Config.CAM_PITCH_MAX
	pitch = clampf(pitch - deg_to_rad(px.y * sens), deg_to_rad(Config.CAM_PITCH_MIN), deg_to_rad(max_p))
	_anim_active = false


func zoom(amount: float) -> void:
	if amount == 0.0 or first_person:
		return
	dist = clampf(dist * (1.0 - amount), Config.CAM_DIST_MIN, Config.CAM_DIST_MAX)
	_anim_active = false


func preset(view: String) -> void:
	if target == null:
		return
	if first_person:
		if view == "back":
			# Birinci şahısta BACK: bakışı ortala
			fp_yaw = 0.0
			fp_pitch = deg_to_rad(-10.0)
			AudioManager.play("click", -8.0)
			return
		set_first_person(false)
	var py := target.get_yaw()
	view_locked = view != "back"
	match view:
		"back":
			_start_anim(py, deg_to_rad(Config.CAM_PITCH_DEFAULT), Config.CAM_DIST_DEFAULT)
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


## Birinci şahıs modunu aç/kapat. Açıkken kafa gizlenir (görüşü kapatmasın), bakış ortalanır.
func set_first_person(on: bool) -> void:
	if on == first_person or target == null:
		return
	first_person = on
	fp_yaw = 0.0
	fp_pitch = deg_to_rad(-10.0)
	_anim_active = false
	if target.visual != null:
		target.visual.set_head_visible(not on)
	if on:
		camera.fov = Config.FP_FOV
	else:
		camera.fov = fov_target
		yaw = target.get_yaw()
		yaw_offset = 0.0
		_cur_dist = 0.6   # gözden arkaya doğru yumuşakça açılsın
		_pivot = target.global_position + Vector3(0, Config.CAM_PIVOT_HEIGHT, 0)
	AudioManager.play("click", -6.0)


## Birinci şahısta kafanın gövdeye göre açısı (görsel kafa da bu yöne döner).
func head_look() -> Vector2:
	return Vector2(fp_yaw, fp_pitch) if first_person else Vector2.ZERO


## Belirli bir açıya yumuşakça dön (kutlama sahnesi vb.)
func focus(p_yaw: float, p_pitch_deg: float, p_dist: float) -> void:
	_start_anim(p_yaw, deg_to_rad(p_pitch_deg), p_dist)


## Serbest bakışı aç/kapat. Kapanınca kamera yumuşakça karaktere döner.
func set_free_look(on: bool) -> void:
	if on == free_look:
		return
	free_look = on
	if on:
		_free_pivot = _pivot
		_anim_active = false
	else:
		_return_time = 1.2
		pitch = clampf(pitch, deg_to_rad(Config.CAM_PITCH_MIN), deg_to_rad(Config.CAM_PITCH_MAX))
	AudioManager.play("click", -6.0)


## Serbest bakışta kamerayı kaydır: move.x sağ/sol, move.y ileri/geri (kameranın baktığı yöne göre),
## rise yukarı/aşağı. Hız uzaklığa göre ölçeklenir.
func pan(move: Vector2, rise: float, delta: float) -> void:
	if not free_look or (move == Vector2.ZERO and rise == 0.0):
		return
	var fwd := Vector3(-sin(yaw), 0.0, -cos(yaw))
	var right := Vector3(cos(yaw), 0.0, -sin(yaw))
	var spd := Config.CAM_PAN_SPEED * (0.6 + dist / 6.0)
	_free_pivot += (right * move.x + fwd * move.y) * spd * delta
	_free_pivot.y += rise * Config.CAM_RISE_SPEED * delta
	_free_pivot = _free_pivot.clamp(bounds.position, bounds.end)


## Serbest bakışta kamerayı doğrudan yükselt/alçalt (dokunmatik iki parmak).
func raise(amount: float) -> void:
	if not free_look or amount == 0.0:
		return
	_free_pivot.y = clampf(_free_pivot.y + amount, bounds.position.y, bounds.end.y)


## Kameranın odaklandığı nokta (serbest bakışta kaydırılan nokta, değilse karakter).
func focus_point() -> Vector3:
	if free_look:
		return _free_pivot - Vector3(0, Config.CAM_PIVOT_HEIGHT, 0)
	return target.global_position


func is_top_view() -> bool:
	return pitch < deg_to_rad(-60.0)


func _physics_process(delta: float) -> void:
	if target == null or camera == null:
		return
	if first_person:
		_first_person_update(delta)
		return
	if _anim_active:
		var k := 1.0 - exp(-8.0 * delta)
		yaw = lerpf(yaw, _anim_yaw, k)
		pitch = lerpf(pitch, _anim_pitch, k)
		dist = lerpf(dist, _anim_dist, k)
		if absf(yaw - _anim_yaw) < 0.002 and absf(pitch - _anim_pitch) < 0.002 and absf(dist - _anim_dist) < 0.01:
			_anim_active = false
		# Animasyon bitince takip bu açıyla sürsün
		yaw_offset = wrapf(yaw - target.get_yaw(), -PI, PI)
		_orbit_hold = Config.CAM_RECENTER_DELAY
	elif not free_look:
		# Takip: kamera karakterin arkasında (+ elle verilen sapma). Sapma bir süre sonra sıfırlanır.
		if _orbit_hold > 0.0:
			_orbit_hold -= delta
		elif not view_locked:
			yaw_offset = lerpf(yaw_offset, 0.0, 1.0 - exp(-1.6 * delta))
		var want := target.get_yaw() + yaw_offset
		yaw = lerp_angle(yaw, want, 1.0 - exp(-Config.CAM_FOLLOW_RATE * delta))
	var desired_pivot := _free_pivot if free_look else target.global_position + Vector3(0, Config.CAM_PIVOT_HEIGHT, 0)
	if not free_look:
		# Omuz üstü: bakış noktası karakterin biraz sağında, böylece önü görünür.
		# Sağda duvar varsa kaydırma kısalır (kamera duvara girmesin).
		var head := desired_pivot
		var right := Vector3(cos(yaw), 0.0, -sin(yaw))
		var off := right * Config.CAM_SHOULDER_OFFSET
		var space0 := get_world_3d().direct_space_state
		var q0 := PhysicsRayQueryParameters3D.create(head, head + off * 1.3, Config.LAYER_WORLD, _excluded)
		var hit0 := space0.intersect_ray(q0)
		if not hit0.is_empty():
			off = off * clampf((head.distance_to(hit0.position) - 0.15) / (Config.CAM_SHOULDER_OFFSET * 1.3), 0.0, 1.0)
		desired_pivot = head + off
	var smooth := Config.CAM_SMOOTH
	if free_look:
		smooth = 14.0
	elif _return_time > 0.0:
		_return_time -= delta
		smooth = 5.0
	_pivot = _pivot.lerp(desired_pivot, 1.0 - exp(-smooth * delta))
	if not free_look and _return_time <= 0.0 and _pivot.distance_to(desired_pivot) > 4.0:
		_pivot = desired_pivot

	# Kesit: bina içinde veya üstten görünümde, oyuncunun başının üstündeki her şey gizlenir.
	# Tavanlar ayrı (yarı saydam) çizilir; yalnızca bulunulan katınki görünür.
	# Duvar kesme yalnızca üstten görünümde ve serbest kamerada; normal kamera duvarlarla sınırlıdır.
	var top := is_top_view()
	var cut := top or (indoor and free_look)
	var feet := _pivot.y - Config.CAM_PIVOT_HEIGHT if (free_look or _return_time > 0.0) else target.global_position.y
	var cut_h := feet + (Config.CAM_TOP_CUT if top else Config.CAM_INDOOR_CUT)
	if cut:
		RenderingServer.global_shader_parameter_set("cut_height", cut_h)
		RenderingServer.global_shader_parameter_set("ceil_cut_height", feet + Config.CAM_CEILING_SHOW)
	elif _cut_active:
		RenderingServer.global_shader_parameter_set("cut_height", 100000.0)
		RenderingServer.global_shader_parameter_set("ceil_cut_height", 100000.0)
	_cut_active = cut
	current_cut = cut_h if cut else INF

	# Sırtta büyük eşya varken kamera biraz yükselip üstünden bakar
	var p_eff := pitch
	var d_eff := dist
	if narrow_view and not free_look and not top:
		p_eff = minf(pitch, deg_to_rad(-34.0))
		d_eff = dist + 0.5
	var rot := Basis.from_euler(Vector3(p_eff, yaw, 0.0))
	var dir := rot * Vector3(0, 0, 1)
	# Serbest bakışta kamera duvarlara takılmaz (her yere gidebilir)
	var allowed := d_eff if free_look else _ray_distance(_pivot, dir, d_eff, cut, cut_h)
	if not free_look and allowed < Config.CAM_CLOSE_LIMIT:
		# Arkada duvar var: karakteri saydamlaştırmak yerine kamera yükselip başın üstünden bakar
		var t := clampf((Config.CAM_CLOSE_LIMIT - allowed) / Config.CAM_CLOSE_LIMIT, 0.0, 1.0)
		var steep := Basis.from_euler(Vector3(lerpf(p_eff, deg_to_rad(-62.0), t), yaw, 0.0)) * Vector3(0, 0, 1)
		var allowed2 := _ray_distance(_pivot, steep, d_eff, cut, cut_h)
		if allowed2 > allowed:
			dir = steep
			allowed = allowed2
	# Yaklaşırken hızlı, uzaklaşırken yumuşak
	if allowed < _cur_dist:
		_cur_dist = lerpf(_cur_dist, allowed, 1.0 - exp(-25.0 * delta))
	else:
		_cur_dist = lerpf(_cur_dist, allowed, 1.0 - exp(-4.0 * delta))
	camera.global_position = _pivot + dir * _cur_dist
	if free_look:
		# Bulunulan zeminin altına inmesin
		camera.global_position.y = maxf(camera.global_position.y, _pivot.y - 1.4)
	if _shake > 0.0:
		_shake = maxf(0.0, _shake - delta * 2.5)
		var s := _shake * _shake * 0.12
		camera.global_position += Vector3(randf_range(-s, s), randf_range(-s, s), randf_range(-s, s))
	if absf(dir.y) > 0.999:
		camera.look_at(_pivot, Vector3(sin(yaw), 0, cos(yaw)) * -1.0)
	else:
		camera.look_at(_pivot, Vector3.UP)
	camera.fov = lerpf(camera.fov, 58.0 if narrow_view else fov_target, 1.0 - exp(-3.0 * delta))
	# Karakter hiçbir zaman saydam/görünmez yapılmaz.


## Pivottan kamera yönüne en fazla ne kadar gidilebilir (duvar çarpışması).
func _ray_distance(from: Vector3, dir: Vector3, max_d: float, cut: bool, cut_h: float) -> float:
	var space := get_world_3d().direct_space_state
	var start := from
	var travelled := 0.0
	for i in 8:
		var remaining := max_d - travelled
		if remaining <= 0.01:
			return max_d
		var q := PhysicsRayQueryParameters3D.create(start, start + dir * remaining, Config.LAYER_WORLD | Config.LAYER_RAMP, _excluded)
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


## Birinci şahıs kamerası: göz noktasında, gövde yönü + kafa açısı. Kesit kapalı.
func _first_person_update(delta: float) -> void:
	if _cut_active:
		RenderingServer.global_shader_parameter_set("cut_height", 100000.0)
		RenderingServer.global_shader_parameter_set("ceil_cut_height", 100000.0)
		_cut_active = false
	current_cut = INF
	var eye: Vector3 = target.visual.eye_position() if target.visual != null else target.global_position + Vector3(0, 1.65, 0)
	var total_yaw := target.get_yaw() + fp_yaw
	camera.global_transform = Transform3D(Basis.from_euler(Vector3(fp_pitch, total_yaw, 0.0)), eye)
	if _shake > 0.0:
		_shake = maxf(0.0, _shake - delta * 2.5)
		var s := _shake * _shake * 0.05
		camera.global_position += Vector3(randf_range(-s, s), randf_range(-s, s), randf_range(-s, s))
	# Üçüncü şahsa dönüşte kamera buradan başlasın
	yaw = total_yaw
	_pivot = target.global_position + Vector3(0, Config.CAM_PIVOT_HEIGHT, 0)
