class_name Game
extends Node3D
## Bir bölümün çalışma zamanı: dünyayı kurar, oyuncu/eşya/kamera/arayüzü bağlar,
## süreyi tutar, kazanma/kaybetme, güvenlik (düşme, takılma) ve eğitimi yönetir.

signal exit_to_levels
signal request_level(level_id: int)

enum Phase { PLAYING, PAUSED, WON, FAILED }

var level_id := 1
var level: Dictionary
var item_data: Dictionary
var info: Dictionary
var input := InputState.new()
var player: Player
var item: CarryItem
var cam: CameraRig
var hud: HUD
var touch: TouchControls
var goal: GoalMarker
var phase := Phase.PLAYING
var elapsed := 0.0
var penalty := 0.0
var timer_running := false

var _ui_layer: CanvasLayer
var _overlay_layer: CanvasLayer
var _overlay: Control
var _sun: DirectionalLight3D
var _env: WorldEnvironment
var _waypoint_idx := 0
var _goal_hold := 0.0
var _tips: Array = []
var _tip_timer := 1.5
var _tutorial: Array = []
var _tut_step := -1
var _tut_timer := 0.0
var _outfits_before: Array = []
var _end_timer := -1.0
var _end_success := false
var _end_data := {}
var _ignore_pause_until := 0
var _kb_move_active := false
var _drop_hint_on := false


func setup(p_level_id: int) -> void:
	level_id = p_level_id


func _ready() -> void:
	level = LevelDB.get_level(level_id)
	level_id = int(level.id)
	item_data = ItemDB.get_item(str(level.item))
	RenderingServer.global_shader_parameter_set("cut_height", 100000.0)
	_build_environment()
	info = LevelBuilder.new().build(level, self)
	_spawn_player()
	_spawn_item()
	_spawn_camera()
	goal = GoalMarker.new()
	goal.setup(info.goal_aabb)
	add_child(goal)
	_build_ui()
	_apply_quality()
	GameState.settings_changed.connect(_apply_quality)
	for o in GameState.OUTFITS:
		if GameState.is_outfit_unlocked(o.id):
			_outfits_before.append(o.id)
	hud.center_message("%d. %s" % [level_id, str(level.name)], 2.2, UITheme.ACCENT)
	hud.hint(str(level.subtitle), 4.0)
	if bool(level.tutorial):
		_setup_tutorial()
	else:
		_tips = level.tips.duplicate()
		_tip_timer = 4.5
	AudioManager.play_music()


# ================================================================ kurulum

func _build_environment() -> void:
	var env := Environment.new()
	env.background_mode = Environment.BG_SKY
	var sky := Sky.new()
	var psm := ProceduralSkyMaterial.new()
	psm.sky_top_color = Color("4f8fd6")
	psm.sky_horizon_color = Color("bcd9ee")
	psm.ground_horizon_color = Color("bcd9ee")
	psm.ground_bottom_color = Color("6a7a5a")
	psm.sun_angle_max = 30.0
	sky.sky_material = psm
	env.sky = sky
	env.ambient_light_source = Environment.AMBIENT_SOURCE_SKY
	env.ambient_light_energy = 0.85
	env.ambient_light_sky_contribution = 0.8
	env.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	env.tonemap_exposure = 1.05
	env.glow_enabled = false
	_env = WorldEnvironment.new()
	_env.environment = env
	add_child(_env)
	_sun = DirectionalLight3D.new()
	_sun.rotation_degrees = Vector3(-52, -38, 0)
	_sun.light_energy = 1.15
	_sun.light_color = Color(1.0, 0.97, 0.9)
	_sun.directional_shadow_max_distance = 28.0
	_sun.shadow_bias = 0.04
	add_child(_sun)


func _spawn_player() -> void:
	player = Player.new()
	player.name = "Player"
	player.input = input
	add_child(player)
	player.spawn_at(info.player_spawn)
	player.goal_check = func() -> bool:
		return item != null and goal.contains(item.global_position)
	player.stamina_changed.connect(func(v: float): hud.set_stamina(v))
	player.prompt_changed.connect(func(t: String, e: bool): touch.set_interact(t, e))
	player.picked_up.connect(_on_holding_changed)
	player.put_down.connect(_on_holding_changed)
	player.exhausted.connect(func():
		hud.center_message("Gücün tükendi!", 1.6, UITheme.BAD)
		hud.hint("Eşyayı düşürdün. Dinlen, sonra tekrar AL.", 4.0))


func _spawn_item() -> void:
	item = CarryItem.new()
	item.name = "Item"
	item.setup(item_data)
	add_child(item)
	item.place_on_ground(info.item_spawn, 0.0)
	player.level_item = item
	item.damaged.connect(_on_item_damaged)
	item.destroyed.connect(_on_item_destroyed)
	item.proximity_changed.connect(_on_proximity)


func _spawn_camera() -> void:
	cam = CameraRig.new()
	cam.name = "CameraRig"
	add_child(cam)
	cam.setup(player)
	cam.add_exclude(item.get_rid())


func _build_ui() -> void:
	_ui_layer = CanvasLayer.new()
	_ui_layer.layer = 1
	add_child(_ui_layer)
	hud = HUD.new()
	_ui_layer.add_child(hud)
	hud.setup(level, item_data)
	touch = TouchControls.new()
	touch.state = input
	_ui_layer.add_child(touch)
	touch.set_holding(false)
	touch.set_interact("AL", false)
	_overlay_layer = CanvasLayer.new()
	_overlay_layer.layer = 5
	_overlay_layer.process_mode = Node.PROCESS_MODE_ALWAYS
	add_child(_overlay_layer)


func _apply_quality() -> void:
	var q := int(GameState.get_setting("quality"))
	var vp := get_viewport()
	if _sun != null:
		_sun.shadow_enabled = q >= 1
	if vp != null:
		vp.scaling_3d_scale = 0.7 if q == 0 else (0.85 if q == 1 else 1.0)
		vp.msaa_3d = Viewport.MSAA_2X if q >= 2 else Viewport.MSAA_DISABLED
	if info.has("lights"):
		for l in info.lights:
			if is_instance_valid(l):
				l.visible = q >= 1 or l.omni_range > 5.0
	if touch != null:
		touch.queue_redraw()


# ================================================================ döngü

func _physics_process(delta: float) -> void:
	if phase == Phase.PLAYING:
		_gather_keyboard()
		_handle_ui_actions()
	cam.orbit(input.take_cam_orbit())
	cam.zoom(input.take_cam_zoom())
	player.camera_yaw = cam.yaw
	if phase != Phase.PLAYING:
		_update_end(delta)
		return
	if not timer_running and (player.moving or player.is_holding()):
		timer_running = true
	if timer_running:
		elapsed += delta
	hud.set_time(elapsed + penalty)
	_update_guide()
	_update_drop_hint()
	_check_safety()
	_check_win(delta)
	_update_tutorial(delta)
	_update_tips(delta)


func _gather_keyboard() -> void:
	var kb := Input.get_vector("move_left", "move_right", "move_back", "move_forward")
	# Klavye yalnızca kullanılırken hareketi belirler (bırakılınca bir kez sıfırlar).
	if (touch == null or not touch.joystick_active()) and (kb != Vector2.ZERO or _kb_move_active):
		input.move = kb
	_kb_move_active = kb != Vector2.ZERO
	input.key_rotate = Vector3(
		Input.get_axis("rot_yaw_left", "rot_yaw_right"),
		Input.get_axis("rot_pitch_up", "rot_pitch_down"),
		Input.get_axis("rot_roll_left", "rot_roll_right"))
	var kl := Input.get_axis("lift_down", "lift_up")
	if kl != 0.0:
		input.lift = kl
	if Input.is_action_pressed("precise"):
		input.precise = true
	for a in ["interact", "rest", "reset_rotation", "cam_back", "cam_top", "cam_side", "pause"]:
		if Input.is_action_just_pressed(a):
			if a == "pause" and Time.get_ticks_msec() < _ignore_pause_until:
				continue
			input.press(a)


func _handle_ui_actions() -> void:
	if input.consume("cam_back"):
		cam.preset("back")
	if input.consume("cam_top"):
		cam.preset("top")
	if input.consume("cam_side"):
		cam.preset("side")
	if input.consume("pause"):
		pause_game()


func _unhandled_input(event: InputEvent) -> void:
	if phase != Phase.PLAYING:
		return
	if event is InputEventMouseButton and event.pressed:
		if event.button_index == MOUSE_BUTTON_WHEEL_UP:
			input.cam_zoom += 0.08
		elif event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			input.cam_zoom -= 0.08
	elif event is InputEventMouseMotion:
		if event.button_mask & MOUSE_BUTTON_MASK_RIGHT:
			if player.is_holding():
				input.rotate_px += event.relative
			else:
				input.cam_orbit_px += event.relative
		elif event.button_mask & MOUSE_BUTTON_MASK_MIDDLE:
			input.cam_orbit_px += event.relative


# ================================================================ yön oku ve kontrol noktaları

func _update_guide() -> void:
	var show_arrow := bool(GameState.get_setting("show_guide"))
	var target: Vector3
	var label := ""
	var item_in_goal := goal.contains(item.global_position)
	goal.active = player.is_holding() or item_in_goal
	if not player.is_holding():
		if item_in_goal and item.is_settled():
			hud.set_guide(0.0, "", false)
			return
		target = item.global_position
		label = "Eşya"
	else:
		var wps: Array = info.waypoints
		for look in range(_waypoint_idx, mini(_waypoint_idx + 3, wps.size() - 1)):
			if _reached(wps[look]):
				_waypoint_idx = look + 1
		target = wps[_waypoint_idx]
	var d := target - player.global_position
	var fwd := Vector3(-sin(cam.yaw), 0, -cos(cam.yaw))
	var right := Vector3(cos(cam.yaw), 0, -sin(cam.yaw))
	var ang := atan2(d.dot(right), d.dot(fwd))
	var floors := int(round(d.y / float(info.floor_height)))
	var hd := Vector2(d.x, d.z).length()
	if label == "":
		label = "%d m" % int(round(hd))
	if floors > 0:
		label += " · %d kat yukarı" % floors
	elif floors < 0:
		label += " · %d kat aşağı" % -floors
	hud.set_guide(ang, label, show_arrow)


## Eşya hedef alanın üstündeyken BIRAK düğmesi yanıp söner.
func _update_drop_hint() -> void:
	var on := player.is_holding() and goal.contains(item.global_position)
	if on != _drop_hint_on:
		_drop_hint_on = on
		if _tut_step < 0 or _tut_step >= _tutorial.size() or str(_tutorial[_tut_step].hl) != "interact":
			touch.highlight("interact", on)
		if on:
			hud.hint("Hedefe geldin: BIRAK!", 2.5)


func _reached(wp: Vector3) -> bool:
	var d := wp - player.global_position
	return Vector2(d.x, d.z).length() < 1.4 and absf(d.y) < 1.1


func _nearest_waypoint() -> int:
	var wps: Array = info.waypoints
	var best := 0
	var best_d := INF
	for i in wps.size():
		var d: Vector3 = wps[i] - player.global_position
		var dist := Vector2(d.x, d.z).length() + absf(d.y) * 3.0
		if dist < best_d:
			best_d = dist
			best = i
	return best


func _check_safety() -> void:
	var kill_y := float(info.kill_y)
	if player.global_position.y < kill_y:
		player.teleport(player.get_last_safe())
		hud.hint("Güvenli noktaya döndün.", 2.5)
	if item.global_position.y < kill_y or item.global_position.length() > 120.0:
		if player.is_holding():
			player.carry.release(false)
		var p := player.global_position + player.global_basis * Vector3(0, 0, -1.2)
		item.place_on_ground(p)
		item.grace = 1.0
		hud.hint("Eşya geri getirildi.", 2.5)


func _check_win(delta: float) -> void:
	if item.is_settled() and goal.contains(item.global_position) and item.durability > 0.0:
		_goal_hold += delta
		if _goal_hold > 0.35:
			_win()
	else:
		_goal_hold = 0.0


# ================================================================ olaylar

func _on_holding_changed() -> void:
	var holding := player.is_holding()
	touch.set_holding(holding)
	var back := holding and item.is_back_carry()
	cam.narrow_view = back
	hud.set_narrow_view(back)
	if holding:
		_waypoint_idx = mini(_nearest_waypoint(), info.waypoints.size() - 1)
		if back:
			hud.hint("Sırtında taşıyorsun: görüş alanın daraldı.", 3.0)
	else:
		hud.show_proximity([])


func _on_item_damaged(amount: float, durability: float, face: String, hard: bool) -> void:
	hud.set_durability(durability)
	if amount >= 0.5:
		hud.damage_flash(amount, face, hard)
	if hard:
		Haptics.heavy()
		cam.shake(clampf(amount / 25.0, 0.3, 1.0))
	elif amount >= 0.5:
		Haptics.light()


func _on_item_destroyed() -> void:
	if phase != Phase.PLAYING:
		return
	_fail("%s kırıldı!" % str(item_data.name), "İpucu: yakınlık uyarısı (sarı kenar) görünce yavaşla ve açıyı değiştir.")


func _on_proximity(faces: Array) -> void:
	hud.show_proximity(faces)
	if not faces.is_empty():
		AudioManager.play("warn", -16.0, 1.0, 0.6)
		Haptics.vibrate(10, 400)


# ================================================================ eğitim ve ipuçları

func _setup_tutorial() -> void:
	_tutorial = [
		{"t": "Sol tarafta parmağını basılı tutup kaydır: joystick ile koliye doğru yürü.", "hl": "", "done": func() -> bool: return player._can_pick() or player.is_holding()},
		{"t": "AL düğmesine basarak koliyi kaldır.", "hl": "interact", "done": func() -> bool: return player.is_holding()},
		{"t": "Sağ tarafta tek parmağını kaydırarak koliyi döndür. YATIR düğmesi üçüncü ekseni açar.", "hl": "", "done": func() -> bool: return player.carry.rotated_total_deg > 60.0, "timeout": 12.0},
		{"t": "KALDIR / İNDİR ile koliyi yükselt veya alçalt. HASSAS basılıyken döndürme yavaşlar.", "hl": "lift_up", "done": func() -> bool: return player.carry.lift_used, "timeout": 10.0},
		{"t": "Üstteki yeşil oku takip et: binaya gir ve merdivenleri çık. Kenar sarı yanarsa çarpmak üzeresin!", "hl": "", "done": func() -> bool: return player.global_position.y > float(info.top_floor_y) - 0.4},
		{"t": "Daireye gir. Yeşil HEDEF alanına gelince BIRAK.", "hl": "interact", "done": func() -> bool: return false},
	]
	_tut_step = -1
	_next_tutorial_step()


func _next_tutorial_step() -> void:
	if _tut_step >= 0 and _tut_step < _tutorial.size():
		var prev: Dictionary = _tutorial[_tut_step]
		if str(prev.hl) != "":
			touch.highlight(str(prev.hl), false)
	_tut_step += 1
	_tut_timer = 0.0
	if _tut_step >= _tutorial.size():
		hud.hint("")
		return
	var st: Dictionary = _tutorial[_tut_step]
	hud.hint_persistent(str(st.t))
	if str(st.hl) != "":
		touch.highlight(str(st.hl), true)


func _update_tutorial(delta: float) -> void:
	if _tut_step < 0 or _tut_step >= _tutorial.size():
		return
	_tut_timer += delta
	var st: Dictionary = _tutorial[_tut_step]
	var done: bool = st.done.call()
	if done or (st.has("timeout") and _tut_timer > float(st.timeout)):
		AudioManager.play("star", -10.0, 1.4)
		_next_tutorial_step()


func _update_tips(delta: float) -> void:
	if _tips.is_empty():
		return
	_tip_timer -= delta
	if _tip_timer <= 0.0:
		hud.hint(str(_tips.pop_front()), 5.0)
		_tip_timer = 6.5


# ================================================================ duraklatma ve kurtarma

func pause_game() -> void:
	if phase != Phase.PLAYING:
		return
	phase = Phase.PAUSED
	touch.release_all()
	input.clear()
	get_tree().paused = true
	var pm := PauseMenu.new()
	pm.resume.connect(resume_game)
	pm.rescue.connect(func():
		resume_game()
		rescue())
	pm.restart.connect(func():
		get_tree().paused = false
		request_level.emit(level_id))
	pm.settings.connect(func():
		_close_overlay()
		var sp := SettingsPanel.new()
		sp.closed.connect(func():
			_overlay = null
			phase = Phase.PLAYING
			pause_game())
		_show_overlay(sp, false))
	pm.quit_to_levels.connect(func():
		get_tree().paused = false
		exit_to_levels.emit())
	_show_overlay(pm)


func resume_game() -> void:
	_ignore_pause_until = Time.get_ticks_msec() + 300
	_close_overlay()
	get_tree().paused = false
	if phase == Phase.PAUSED:
		phase = Phase.PLAYING


func _show_overlay(c: Control, close_prev: bool = true) -> void:
	if close_prev:
		_close_overlay()
	_overlay = c
	_overlay_layer.add_child(c)


func _close_overlay() -> void:
	if _overlay != null and is_instance_valid(_overlay):
		_overlay.queue_free()
	_overlay = null


## Android geri tuşu / Esc: duraklat veya devam et.
func on_back() -> void:
	if phase == Phase.PLAYING:
		pause_game()
	elif phase == Phase.PAUSED:
		resume_game()


func _notification(what: int) -> void:
	if what == NOTIFICATION_APPLICATION_PAUSED or what == NOTIFICATION_APPLICATION_FOCUS_OUT:
		if phase == Phase.PLAYING and is_inside_tree():
			pause_game()


## Takılınca: son kontrol noktasına dön, eşya eline verilir.
func rescue() -> void:
	if phase != Phase.PLAYING or item.durability <= 0.0:
		return
	var wps: Array = info.waypoints
	var idx := clampi(_waypoint_idx - 1, 0, wps.size() - 1)
	var pos: Vector3 = wps[idx] if player.is_holding() or item.is_held() else player.get_last_safe()
	var next: Vector3 = wps[mini(idx + 1, wps.size() - 1)]
	var dir := next - pos
	var yaw := atan2(-dir.x, -dir.z) if Vector2(dir.x, dir.z).length() > 0.1 else player.get_yaw()
	player.teleport(pos + Vector3(0, 0.05, 0), yaw)
	if not player.is_holding():
		player.carry.grab(item)
		_on_holding_changed()
	player.carry.hold_basis = Basis()
	player.carry.lift = 0.0
	item.global_transform = player.carry.target_transform()
	var ok := not item.is_overlapping()
	var tries := 0
	while not ok and tries < 10:
		item.global_position += Vector3.UP * 0.1
		ok = not item.is_overlapping()
		tries += 1
	if not ok:
		player.carry.release(false)
		_on_holding_changed()
		item.place_on_ground(pos + player.global_basis * Vector3(0, 0, -1.0))
	item.grace = 1.2
	penalty += 15.0
	cam.preset("back")
	hud.hint("Kurtarıldın (+15 sn).", 2.5)


# ================================================================ bitiş

func _win() -> void:
	phase = Phase.WON
	player.frozen = true
	touch.release_all()
	touch.visible = false
	var total := elapsed + penalty
	var stars := DamageModel.stars(item.durability, total, float(level.par_time))
	var perfect := item.durability >= 99.5
	var record := GameState.record_result(level_id, stars, total, item.durability, perfect)
	if bool(level.tutorial):
		GameState.tutorial_seen = true
		GameState.queue_save()
	var new_outfits: Array = []
	for o in GameState.OUTFITS:
		if GameState.is_outfit_unlocked(o.id) and not _outfits_before.has(o.id):
			new_outfits.append(o.name)
	AudioManager.play("success", 0.0)
	Haptics.vibrate(40)
	hud.center_message("TESLİM EDİLDİ!", 1.6, UITheme.GOOD)
	_end_success = true
	_end_data = {
		"stars": stars, "time": total, "par": float(level.par_time), "durability": item.durability,
		"hits": item.hit_count, "perfect": perfect, "record": record, "new_outfits": new_outfits,
		"has_next": level_id < LevelDB.count(), "last_level": level_id >= LevelDB.count(),
	}
	_end_timer = 1.4


func _fail(reason: String, tip: String) -> void:
	phase = Phase.FAILED
	player.frozen = true
	if player.is_holding():
		player.carry.release(false)
	touch.release_all()
	touch.visible = false
	AudioManager.play("fail", 0.0)
	Haptics.heavy()
	cam.shake(1.0)
	hud.center_message(reason, 1.6, UITheme.BAD)
	_end_success = false
	_end_data = {"reason": reason, "tip": tip}
	_end_timer = 1.6


func _update_end(delta: float) -> void:
	if _end_timer < 0.0:
		return
	_end_timer -= delta
	if _end_timer > 0.0:
		return
	_end_timer = -1.0
	var rp := ResultPanel.new()
	rp.setup(_end_success, _end_data)
	rp.next_level.connect(func(): request_level.emit(level_id + 1))
	rp.retry.connect(func(): request_level.emit(level_id))
	rp.to_levels.connect(func(): exit_to_levels.emit())
	_show_overlay(rp)


func _exit_tree() -> void:
	RenderingServer.global_shader_parameter_set("cut_height", 100000.0)
	if get_tree() != null:
		get_tree().paused = false
