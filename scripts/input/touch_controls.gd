class_name TouchControls
extends Control
## Ekran üstü dokunmatik kontroller.
## Sol alan: dinamik sanal joystick (parmağın değdiği yerde belirir).
## Sağ alan: tek parmak = eşyayı döndür (eşya yoksa kamera), iki parmak = kamera döndür + sıkıştır.
## Düğmeler: AL/BIRAK, MOLA, KALDIR, İNDİR, HASSAS, YATIR (3. eksen), DÜZELT, kamera ve duraklat.

const JOY_RADIUS := 72.0
const JOY_ZONE := 0.45   # ekranın sol %45'i joystick alanı

var state: InputState
var holding := false

var buttons: Dictionary = {}
var _joy_index := -1
var _joy_base := Vector2.ZERO
var _joy_knob := Vector2.ZERO
var _right_touches: Dictionary = {}     # index -> pozisyon
var _pinch_prev := -1.0
var _centroid_prev := Vector2.ZERO
var _left_handed := false


func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_make_button("interact", "AL", "tap", 62.0)
	_make_button("rest", "MOLA", "tap", 38.0)
	_make_button("lift_up", "KALDIR", "hold", 38.0)
	_make_button("lift_down", "İNDİR", "hold", 38.0)
	_make_button("precise", "HASSAS", "hold", 40.0)
	_make_button("mode", "YATIR", "toggle", 36.0)
	_make_button("reset", "DÜZELT", "tap", 34.0)
	_make_button("cam_back", "ARKA", "tap", 30.0)
	_make_button("cam_top", "ÜST", "tap", 30.0)
	_make_button("cam_side", "YAN", "tap", 30.0)
	_make_button("pause", "II", "tap", 30.0)
	buttons.interact.accent = Color(0.35, 0.85, 0.45)
	buttons.mode.sublabel = "3. eksen"
	buttons.interact.tapped.connect(func(): state.press("interact"))
	buttons.rest.tapped.connect(func(): state.press("rest"))
	buttons.reset.tapped.connect(func(): state.press("reset_rotation"))
	buttons.cam_back.tapped.connect(func(): state.press("cam_back"))
	buttons.cam_top.tapped.connect(func(): state.press("cam_top"))
	buttons.cam_side.tapped.connect(func(): state.press("cam_side"))
	buttons.pause.tapped.connect(func(): state.press("pause"))
	buttons.mode.toggled_state.connect(func(on: bool): state.roll_mode = on)
	_left_handed = bool(GameState.get_setting("left_handed"))
	GameState.settings_changed.connect(_on_settings_changed)
	resized.connect(_layout)
	_layout()


func _on_settings_changed() -> void:
	var lh := bool(GameState.get_setting("left_handed"))
	if lh != _left_handed:
		_left_handed = lh
		_layout()


func _make_button(id: String, text: String, mode: String, r: float) -> void:
	var b := TouchButton.new(text, mode, r)
	b.name = "Btn_" + id
	add_child(b)
	buttons[id] = b


func _layout() -> void:
	var W := size.x
	var H := size.y
	if W <= 0.0 or H <= 0.0:
		return
	var pos := {
		"interact": Vector2(W - 125, H - 125),
		"precise": Vector2(W - 125, H - 268),
		"lift_up": Vector2(W - 262, H - 262),
		"lift_down": Vector2(W - 262, H - 168),
		"rest": Vector2(W - 262, H - 72),
		"reset": Vector2(W - 370, H - 160),
		"mode": Vector2(W - 370, H - 66),
		"cam_back": Vector2(W - 205, 62),
		"cam_top": Vector2(W - 135, 62),
		"cam_side": Vector2(W - 65, 62),
		"pause": Vector2(W - 290, 62),
	}
	for id in buttons:
		var b: TouchButton = buttons[id]
		var p: Vector2 = pos[id]
		if _left_handed and not id.begins_with("cam_") and id != "pause":
			p.x = W - p.x
		b.position = p - b.size * 0.5


func set_holding(v: bool) -> void:
	holding = v
	for id in ["lift_up", "lift_down", "precise", "mode", "reset"]:
		buttons[id].set_enabled(v)


func set_interact(text: String, enabled: bool) -> void:
	var b: TouchButton = buttons.interact
	b.set_label(text if text != "" else "AL")
	b.set_enabled(enabled)


func highlight(id: String, on: bool) -> void:
	if buttons.has(id):
		buttons[id].highlight = on
		buttons[id].queue_redraw()


func _process(_delta: float) -> void:
	if state == null:
		return
	# Basılı tutulan düğmeler
	var lift := 0.0
	if buttons.lift_up.is_down:
		lift += 1.0
	if buttons.lift_down.is_down:
		lift -= 1.0
	state.lift = lift
	state.precise = buttons.precise.is_down
	if _joy_index >= 0:
		var d := (_joy_knob - _joy_base) / JOY_RADIUS
		state.move = Vector2(d.x, -d.y).limit_length(1.0)


func _input(event: InputEvent) -> void:
	if state == null or not is_visible_in_tree():
		return
	if event is InputEventScreenTouch:
		_on_touch(event as InputEventScreenTouch)
	elif event is InputEventScreenDrag:
		_on_drag(event as InputEventScreenDrag)


func _on_touch(e: InputEventScreenTouch) -> void:
	var p := e.position
	if e.pressed:
		# Önce düğmeler
		for id in buttons:
			var b: TouchButton = buttons[id]
			if b.touch_index == -1 and b.enabled and b.contains(p):
				b.touch_down(e.index)
				return
		var in_joy_zone := p.x < size.x * JOY_ZONE if not _left_handed else p.x > size.x * (1.0 - JOY_ZONE)
		if in_joy_zone and _joy_index == -1:
			_joy_index = e.index
			_joy_base = Vector2(clampf(p.x, JOY_RADIUS + 20, size.x - JOY_RADIUS - 20), clampf(p.y, JOY_RADIUS + 20, size.y - JOY_RADIUS - 20))
			_joy_knob = p
			queue_redraw()
			return
		_right_touches[e.index] = p
		_reset_gesture()
	else:
		for id in buttons:
			var b: TouchButton = buttons[id]
			if b.touch_index == e.index:
				b.touch_up()
				return
		if e.index == _joy_index:
			_joy_index = -1
			state.move = Vector2.ZERO
			queue_redraw()
			return
		if _right_touches.has(e.index):
			_right_touches.erase(e.index)
			_reset_gesture()


func _on_drag(e: InputEventScreenDrag) -> void:
	if e.index == _joy_index:
		var off := e.position - _joy_base
		_joy_knob = _joy_base + off.limit_length(JOY_RADIUS)
		# Parmak çok uzağa giderse taban takip eder (rahat kullanım)
		if off.length() > JOY_RADIUS * 1.6:
			_joy_base = e.position - off.normalized() * JOY_RADIUS * 1.6
		queue_redraw()
		return
	if not _right_touches.has(e.index):
		return
	var prev: Vector2 = _right_touches[e.index]
	_right_touches[e.index] = e.position
	if _right_touches.size() == 1:
		var rel := e.position - prev
		if holding:
			state.rotate_px += rel
		else:
			state.cam_orbit_px += rel
	else:
		var keys := _right_touches.keys()
		var a: Vector2 = _right_touches[keys[0]]
		var b: Vector2 = _right_touches[keys[1]]
		var centroid := (a + b) * 0.5
		var d := a.distance_to(b)
		if _pinch_prev > 0.0:
			state.cam_orbit_px += centroid - _centroid_prev
			state.cam_zoom += (d - _pinch_prev) * Config.CAM_PINCH_FACTOR
		_pinch_prev = d
		_centroid_prev = centroid


func _reset_gesture() -> void:
	_pinch_prev = -1.0
	if _right_touches.size() >= 2:
		var keys := _right_touches.keys()
		var a: Vector2 = _right_touches[keys[0]]
		var b: Vector2 = _right_touches[keys[1]]
		_pinch_prev = a.distance_to(b)
		_centroid_prev = (a + b) * 0.5


## Tüm dokunuşları bırak (uygulama arka plana geçince, duraklatınca).
func release_all() -> void:
	_joy_index = -1
	_right_touches.clear()
	for id in buttons:
		buttons[id].touch_up()
	if state != null:
		state.move = Vector2.ZERO
		state.lift = 0.0
		state.precise = false
	queue_redraw()


func _notification(what: int) -> void:
	if what == NOTIFICATION_APPLICATION_FOCUS_OUT or what == NOTIFICATION_APPLICATION_PAUSED:
		release_all()


func _draw() -> void:
	# Joystick
	if _joy_index >= 0:
		draw_circle(_joy_base, JOY_RADIUS, Color(0.1, 0.12, 0.16, 0.35))
		draw_arc(_joy_base, JOY_RADIUS, 0, TAU, 48, Color(1, 1, 1, 0.45), 3.0, true)
		draw_circle(_joy_knob, 34.0, Color(1, 1, 1, 0.6))
	else:
		# Joystick ipucu
		var hint := Vector2(150, size.y - 150)
		if _left_handed:
			hint.x = size.x - 150
		draw_arc(hint, JOY_RADIUS, 0, TAU, 48, Color(1, 1, 1, 0.18), 2.0, true)
		draw_circle(hint, 30.0, Color(1, 1, 1, 0.15))


func joystick_active() -> bool:
	return _joy_index >= 0
