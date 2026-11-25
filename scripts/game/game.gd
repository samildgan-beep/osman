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
var fx: FX
var npc: Homeowner
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
var _orient_hint_cd := 0.0
var _item_colors: Array = []


func setup(p_level_id: int) -> void:
	level_id = p_level_id


func _ready() -> void:
	level = LevelDB.get_level(level_id)
	level_id = int(level.id)
	item_data = ItemDB.get_item(str(level.item))
	RenderingServer.global_shader_parameter_set("cut_height", 100000.0)
	RenderingServer.global_shader_parameter_set("ceil_cut_height", 100000.0)
	_build_environment()
	info = LevelBuilder.new().build(level, self)
	_spawn_player()
	_spawn_item()
	_spawn_camera()
	fx = FX.new()
	fx.name = "FX"
	add_child(fx)
	goal = GoalMarker.new()
	if str(info.goal_type) == "spot":
		goal.setup(info.goal_aabb, info.spot_size, info.spot_basis, "PLACE HERE")
	else:
		goal.setup(info.goal_aabb, Vector3.ZERO, Basis(), "DROP HERE")
	add_child(goal)
	_spawn_npc()
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
	psm.sky_top_color = Color("2f7fe0")
	psm.sky_horizon_color = Color("a8d8f5")
	psm.ground_horizon_color = Color("a8d8f5")
	psm.ground_bottom_color = Color("5d7a4a")
	psm.sun_angle_max = 25.0
	psm.sky_energy_multiplier = 1.1
	sky.sky_material = psm
	env.sky = sky
	# Ortam ışığı nötr ve hafif sıcak: gökyüzü ışığı her şeyi maviye boyamasın
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.93, 0.9, 0.86)
	env.ambient_light_energy = 0.72
	env.reflected_light_source = Environment.REFLECTION_SOURCE_SKY
	env.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	env.tonemap_exposure = 1.1
	env.tonemap_white = 6.0
	# Canlı renkler: hafif doygunluk ve kontrast artışı, yumuşak parlama
	env.adjustment_enabled = true
	env.adjustment_saturation = 1.2
	env.adjustment_contrast = 1.06
	env.adjustment_brightness = 1.02
	env.glow_enabled = true
	env.glow_intensity = 0.55
	env.glow_bloom = 0.06
	env.glow_hdr_threshold = 1.1
	env.fog_enabled = true
	env.fog_light_color = Color("e4ecf2")
	env.fog_density = 0.0035
	env.fog_sky_affect = 0.0
	_env = WorldEnvironment.new()
	_env.environment = env
	add_child(_env)
	_sun = DirectionalLight3D.new()
	_sun.rotation_degrees = Vector3(-52, -38, 0)
	_sun.light_energy = 1.3
	_sun.light_color = Color(1.0, 0.94, 0.82)
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
	player.crushed.connect(_on_player_crushed)
	player.put_down.connect(_on_holding_changed)
	player.exhausted.connect(func():
		hud.center_message("Out of stamina!", 1.6, UITheme.BAD)
		hud.hint("You dropped it! Rest a moment, then GRAB it again.", 4.0))


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
	item.surface_contact.connect(func(pt: Vector3, nrm: Vector3, vel: Vector3, dmg: float, hard: bool):
		fx.on_contact(pt, nrm, vel, dmg, hard, _item_colors))
	for p in item_data.get("parts", []):
		_item_colors.append(p.color)


func _spawn_npc() -> void:
	npc = Homeowner.new()
	npc.name = "Homeowner"
	npc.setup(info.npc_pos, float(info.npc_yaw), player, str(item_data.name), level_id * 31)
	add_child(npc)


func _spawn_camera() -> void:
	cam = CameraRig.new()
	cam.name = "CameraRig"
	add_child(cam)
	cam.setup(player)
	cam.add_exclude(item.get_rid())
	# Serbest bakışta kameranın gezebileceği alan: sokak + bina + çatının biraz üstü
	var b: AABB = info.block_aabb
	cam.bounds = AABB(Vector3(-38.0, -0.3, -38.0), Vector3(76.0, b.end.y + 8.0, 66.0))
	if info.has("cam_scale"):
		# Fabrika: dev salon, dev eşya: kamera uzaktan bakar, serbest bakış salonla sınırlı
		cam.set_view_scale(float(info.cam_scale))
		cam.bounds = b.grow(1.0)


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
	touch.set_interact("GRAB", false)
	_overlay_layer = CanvasLayer.new()
	_overlay_layer.layer = 5
	_overlay_layer.process_mode = Node.PROCESS_MODE_ALWAYS
	add_child(_overlay_layer)


func _apply_quality() -> void:
	var q := int(GameState.get_setting("quality"))
	var vp := get_viewport()
	if _sun != null:
		_sun.shadow_enabled = q >= 1
	if _env != null and _env.environment != null:
		_env.environment.glow_enabled = q >= 1
		_env.environment.fog_enabled = q >= 1
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
		_update_free_look(delta)
	cam.indoor = _is_indoor(cam.focus_point())
	_update_home()
	_update_strain(delta)
	_update_labels()
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
	for a: String in ["interact", "rest", "reset_rotation", "cam_back", "cam_top", "cam_side", "cam_first", "pause", "look_toggle"]:
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
	if input.consume("cam_first"):
		set_first_person(not cam.first_person)
	touch.set_first_person(cam.first_person)
	if input.consume("pause"):
		pause_game()


## Serbest bakış: karakter yerinde durur; joystick/WASD kamerayı gezdirir,
## LIFT/LOWER (Q/E) veya iki parmak yukarı/aşağı kamerayı yükseltir.
func _update_free_look(delta: float) -> void:
	if input.consume("look_toggle"):
		input.look_mode = not input.look_mode
		touch.set_look(input.look_mode)
	if input.look_mode and cam.first_person:
		cam.set_first_person(false)
	if input.look_mode != cam.free_look:
		cam.set_free_look(input.look_mode)
		touch.set_look(input.look_mode)
		if input.look_mode:
			hud.hint("Free camera: move with the joystick, swipe to look around, two fingers up/down (or LIFT/LOWER) to rise. Tap LOOK to return.", 5.0)
		elif _tut_step >= 0 and _tut_step < _tutorial.size():
			hud.hint_persistent(str(_tutorial[_tut_step].t))
		else:
			hud.hint("")
	if not cam.free_look:
		return
	cam.pan(input.move, input.lift, delta)
	cam.raise(input.take_cam_rise())
	# Karakter bu sırada hareket etmez, eşya dönmez
	input.move = Vector2.ZERO
	input.lift = 0.0
	input.key_rotate = Vector3.ZERO
	input.rotate_px = Vector2.ZERO


## Bölüm bitince eğitim ve ipuçlarını kapat.
func _end_hints() -> void:
	if _tut_step >= 0 and _tut_step < _tutorial.size():
		touch.highlight(str(_tutorial[_tut_step].hl), false)
	_tut_step = _tutorial.size()
	_tips.clear()
	hud.hint("")
	hud.show_proximity([])


## Birinci şahıs (göz) kamerası. Serbest bakış açıksa önce kapanır.
func set_first_person(on: bool) -> void:
	if on and cam.free_look:
		_exit_free_look()
	cam.set_first_person(on)
	if touch != null:
		touch.set_first_person(on)
	if on and not _fp_hint_shown:
		_fp_hint_shown = true
		hud.hint("First person: drag with two fingers (or right mouse) to turn your head. BACK centers your view.", 4.0)


var _fp_hint_shown := false


func _exit_free_look() -> void:
	if cam != null and cam.first_person:
		cam.set_first_person(false)
	input.look_mode = false
	if touch != null:
		touch.set_look(false)
	if cam != null:
		cam.set_free_look(false)


func _unhandled_input(event: InputEvent) -> void:
	if phase != Phase.PLAYING:
		return
	var mb := event as InputEventMouseButton
	if mb != null and mb.pressed:
		if mb.button_index == MOUSE_BUTTON_WHEEL_UP:
			input.cam_zoom += 0.08
		elif mb.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			input.cam_zoom -= 0.08
		return
	var mm := event as InputEventMouseMotion
	if mm != null:
		if mm.button_mask & MOUSE_BUTTON_MASK_RIGHT:
			if player.is_holding():
				input.rotate_px += mm.relative
			else:
				input.cam_orbit_px += mm.relative
		elif mm.button_mask & MOUSE_BUTTON_MASK_MIDDLE:
			input.cam_orbit_px += mm.relative


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
		label = "Item"
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
	if floors != 0:
		var nf := absi(floors)
		label += " · %d floor%s %s" % [nf, "" if nf == 1 else "s", "up" if floors > 0 else "down"]
	hud.set_guide(ang, label, show_arrow)


## Eşya hedef alanın üstündeyken BIRAK düğmesi yanıp söner.
func _update_drop_hint() -> void:
	var on := player.is_holding() and goal.contains(item.global_position)
	if on != _drop_hint_on:
		_drop_hint_on = on
		if _tut_step < 0 or _tut_step >= _tutorial.size() or str(_tutorial[_tut_step].hl) != "interact":
			touch.highlight("interact", on)
		if on:
			if str(info.goal_type) == "spot":
				hud.hint("Line it up, FRONT facing the room, then DROP!", 3.0)
			else:
				hud.hint("You made it: DROP it here!", 2.5)


## Kesit görünümünde kesitin üstünde kalan bina yazılarını gizle.
func _update_labels() -> void:
	var cut := cam.current_cut
	for lb in info.labels:
		if is_instance_valid(lb):
			lb.visible = lb.global_position.y < cut - 0.1


## Kaldıraç zorlanması: eşya gövdeden uzakta (ucundan) tutulunca dayanıklılık daha hızlı biter;
## çubuk turuncu-kırmızı nabız atar. Bir süre sürerse bir kez ipucu verilir.
var _strain_time := 0.0
var _strain_hint_shown := false
func _update_strain(delta: float) -> void:
	var f := player.carry.leverage() if player.is_holding() else 1.0
	hud.set_stamina_strain(f)
	if f >= Config.LEVER_WARN and phase == Phase.PLAYING:
		_strain_time += delta
		if _strain_time > 1.2 and not _strain_hint_shown:
			_strain_hint_shown = true
			hud.hint("Holding it by the end wears you out ×%.1f faster! Carry it close to your body." % f, 4.0)
	else:
		_strain_time = 0.0


## Daire içi (koridor + odalar): taşırken yarı hız ve hassas kontrol. İlk girişte ipucu.
var _home_hint_shown := false
func _update_home() -> void:
	var a: AABB = info.get("apt_aabb", AABB())
	var p := player.global_position
	var was := player.in_home
	player.in_home = a.size != Vector3.ZERO and a.grow(0.05).has_point(p + Vector3(0, 0.3, 0))
	if player.in_home and not was and player.is_holding() and not _home_hint_shown:
		_home_hint_shown = true
		hud.hint("Inside the home: half speed. Move carefully!", 3.0)


## Eşyanın bulunabileceği alan: oyun alanı (sokak + bina) ya da fabrika salonu, payıyla.
func _item_area() -> AABB:
	var area := AABB(Vector3(-120, -50, -120), Vector3(240, 200, 240))
	if info.has("block_aabb"):
		area = area.merge(AABB(info.block_aabb).grow(30.0))
	return area


func _is_indoor(p: Vector3) -> bool:
	var b: AABB = info.block_aabb
	return p.z > 0.05 and p.x > b.position.x and p.x < b.end.x and p.z < b.end.z and p.y > -1.0


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
		hud.hint("Back to a safe spot.", 2.5)
	if item.global_position.y < kill_y or not _item_area().has_point(item.global_position):
		if player.is_holding():
			player.carry.release(false)
		# Eşya oyuncunun önüne, içine girmeyecek uzaklıkta konur (dev eşyalar dahil)
		var p := player.global_position + player.global_basis * Vector3(0, 0, -(item.half.z + Config.PLAYER_RADIUS + 0.5))
		item.place_on_ground(p)
		item.grace = 1.0
		hud.hint("The item was brought back.", 2.5)


func _check_win(delta: float) -> void:
	_orient_hint_cd = maxf(0.0, _orient_hint_cd - delta)
	if item.is_settled() and goal.contains(item.global_position) and item.durability > 0.0:
		if not _placement_ok():
			_goal_hold = 0.0
			if _orient_hint_cd <= 0.0:
				_orient_hint_cd = 5.0
				hud.hint("Almost! Stand it upright with the FRONT facing the room.", 3.5)
				npc.hint_orientation()
			return
		_goal_hold += delta
		if _goal_hold > 0.35:
			_win()
	else:
		_goal_hold = 0.0


## Yerleştirme bölümlerinde eşya dik durmalı ve ön yüzü odaya bakmalı.
func _placement_ok() -> bool:
	if str(info.goal_type) != "spot":
		return true
	var b := item.global_basis.orthonormalized()
	if b.y.dot(Vector3.UP) < cos(deg_to_rad(22.0)):
		return false
	var front := -b.z
	front.y = 0.0
	if front.length() < 0.3:
		return false
	var facing: Vector3 = info.goal_facing
	return front.normalized().dot(facing) > cos(deg_to_rad(40.0))


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
			hud.hint("Carrying on your back: your view is narrower.", 3.0)
	else:
		hud.show_proximity([])


func _on_item_damaged(amount: float, durability: float, face: String, hard: bool) -> void:
	hud.set_durability(durability)
	if amount >= 0.5:
		hud.damage_flash(amount, face, hard)
	if hard:
		Haptics.heavy()
		cam.shake(clampf(amount / 25.0, 0.3, 1.0))
		if npc != null:
			var d := npc.global_position - player.global_position
			npc.react_damage(amount, Vector2(d.x, d.z).length() < 14.0 and absf(d.y) < 3.5)
	elif amount >= 0.5:
		Haptics.light()


func _on_item_destroyed() -> void:
	if phase != Phase.PLAYING:
		return
	_fail("The %s broke!" % str(item_data.name).to_lower(), "Tip: when an edge glows yellow, slow down and change the angle.")
	# Eşya parçalara ayrılır: camlı eşyalarda cam kırılma sesi, diğerlerinde çatırtı
	var glassy := not (item_data.get("fragile_faces", {}) as Dictionary).is_empty()
	AudioManager.play("shatter" if glassy else "crack", 2.0)
	AudioManager.play("thud", 0.0, 0.8)
	fx.shatter(item.get_debris_parts(), item.global_position, Vector3.ZERO)
	item.hide_visual()
	item.collision_layer = 0
	item.collision_mask = 0
	item.set_physics_process(false)
	if npc != null:
		npc.sad()


## Ağır eşyayla güç bitti: taşıyıcı sırtüstü düşer, eşya üstüne yığılır (komik başarısızlık).
func _on_player_crushed() -> void:
	if phase != Phase.PLAYING:
		return
	var pp := player.global_position
	var pb := Basis(Vector3.UP, player.get_yaw())
	player.carry.release(false)
	_on_holding_changed()
	# Eşyayı taşıyıcının vücudunun üstüne, yatık şekilde konumla ve düşür
	var body_center := pp + pb * Vector3(0, 0, 0.85)
	var lying := pb * Basis(Vector3.RIGHT, PI * 0.5)
	item.global_transform = Transform3D(lying, body_center + Vector3.UP * (item.half.z + 0.45))
	if item.is_overlapping():
		# Dar yerde yatık sığmıyorsa dik olarak üstüne düşsün
		item.global_transform = Transform3D(pb, body_center + Vector3.UP * (item.half.y + 0.3))
	item.grace = 0.0
	item.drop(Vector3(0, -2.5, 0))
	cam.set_first_person(false)
	player.visual.play_crushed()
	AudioManager.play("thud", 2.0, 0.7)
	AudioManager.play("crack", 0.0, 0.6)
	cam.shake(1.0)
	cam.focus(player.get_yaw() + 0.7, -38.0, 4.0)
	if npc != null:
		npc.set_state("worried", 3.0)
		npc.say("Oh no! Are you okay?!", 3.0)
	_fail("Crushed under the %s!" % str(item_data.name).to_lower(), "Tip: take a REST before your stamina runs out. Heavy items will flatten you!")


func _on_proximity(faces: Array) -> void:
	hud.show_proximity(faces)
	if not faces.is_empty():
		AudioManager.play("warn", -16.0, 1.0, 0.6)
		Haptics.vibrate(10, 400)


# ================================================================ eğitim ve ipuçları

func _setup_tutorial() -> void:
	_tutorial = [
		{"t": "Joystick on the left: push up to walk, left/right to turn on the spot. Walk to the box.", "hl": "", "done": func() -> bool: return player._can_pick() or player.is_holding()},
		{"t": "Press GRAB to pick up the box.", "hl": "interact", "done": func() -> bool: return player.is_holding()},
		{"t": "Swipe with one finger on the right side to rotate the box. ROLL unlocks the third axis.", "hl": "", "done": func() -> bool: return player.carry.rotated_total_deg > 60.0, "timeout": 12.0},
		{"t": "Use LIFT / LOWER to raise or lower it. Hold FINE to rotate slowly.", "hl": "lift_up", "done": func() -> bool: return player.carry.lift_used, "timeout": 10.0},
		{"t": "Follow the green arrow: enter the building and climb the stairs. A yellow edge means you're about to hit something!", "hl": "", "done": func() -> bool: return player.global_position.y > float(info.top_floor_y) - 0.4},
		{"t": "The owner is waiting at the door. Step into the green zone and press DROP.", "hl": "interact", "done": func() -> bool: return false},
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
	hud.hint("Rescued (+15 s).", 2.5)


# ================================================================ bitiş

func _win() -> void:
	_exit_free_look()
	_end_hints()
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
	hud.center_message("DELIVERED!", 1.8, UITheme.GOOD)
	_celebrate(perfect)
	_end_success = true
	_end_data = {
		"stars": stars, "time": total, "par": float(level.par_time), "durability": item.durability,
		"hits": item.hit_count, "perfect": perfect, "record": record, "new_outfits": new_outfits,
		"has_next": level_id < LevelDB.count(), "last_level": level_id >= LevelDB.count(),
	}
	_end_timer = 4.4


## Teslim kutlaması: ev sahibi sevinir ve teşekkür eder, konfeti, taşıyıcı da sevinir,
## kamera ikisini birlikte gösterir.
func _celebrate(perfect: bool) -> void:
	goal.active = false
	if npc == null:
		return
	npc.celebrate(perfect)
	player.celebrating = true
	player.face_towards(npc.global_position)
	fx.confetti(npc.global_position + Vector3(0, 2.0, 0))
	var mid := (npc.global_position + player.global_position) * 0.5
	fx.confetti(mid + Vector3(0, 2.4, 0), 60)
	var d := player.global_position - npc.global_position
	d.y = 0.0
	if d.length() > 0.1:
		# Kamera taşıyıcının arkasında, ev sahibine bakar; biraz yandan
		cam.focus(atan2(d.x, d.z) + 0.45, -18.0, 4.2)
	var tm := get_tree().create_timer(1.6, false)
	tm.timeout.connect(_second_confetti)


func _second_confetti() -> void:
	if is_instance_valid(fx) and is_instance_valid(npc):
		fx.confetti(npc.global_position + Vector3(0, 2.2, 0), 70)
		AudioManager.play("star", -4.0, 1.2)


func _fail(reason: String, tip: String) -> void:
	_exit_free_look()
	_end_hints()
	phase = Phase.FAILED
	player.frozen = true
	if player.is_holding():
		player.carry.release(false)
	touch.release_all()
	touch.visible = false
	AudioManager.play("fail", 0.0)
	AudioManager.play("crack", 0.0, 0.8)
	Haptics.heavy()
	cam.shake(1.0)
	hud.center_message(reason, 1.6, UITheme.BAD)
	_end_success = false
	_end_data = {"reason": reason, "tip": tip}
	_end_timer = 2.8


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
	RenderingServer.global_shader_parameter_set("ceil_cut_height", 100000.0)
	if get_tree() != null:
		get_tree().paused = false
