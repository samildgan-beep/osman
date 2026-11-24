class_name TouchButton
extends Control
## Çoklu dokunmayı destekleyen yuvarlak dokunmatik düğme.
## mode: "tap" (bir kez), "hold" (basılı tutma), "toggle" (aç/kapa)

signal pressed_down
signal released
signal tapped
signal toggled_state(on: bool)

var label := ""
var sublabel := ""
var mode := "tap"
var color := Color(0.15, 0.17, 0.22, 0.72)
var accent := Color(1.0, 0.78, 0.2)
var is_down := false
var toggled := false
var enabled := true
var touch_index := -1
var radius := 52.0
var _pulse := 0.0
var highlight := false


func _init(p_label: String = "", p_mode: String = "tap", p_radius: float = 52.0) -> void:
	label = p_label
	mode = p_mode
	radius = p_radius
	custom_minimum_size = Vector2(radius * 2.0, radius * 2.0)
	size = custom_minimum_size
	mouse_filter = Control.MOUSE_FILTER_IGNORE


func _process(delta: float) -> void:
	if highlight:
		_pulse += delta
		queue_redraw()


func contains(global_point: Vector2) -> bool:
	if not is_visible_in_tree():
		return false
	var c := get_global_rect().get_center()
	return global_point.distance_to(c) <= radius * 1.12 * get_global_transform().get_scale().x


func touch_down(index: int) -> void:
	if not enabled:
		return
	touch_index = index
	is_down = true
	match mode:
		"toggle":
			toggled = not toggled
			toggled_state.emit(toggled)
		"tap":
			tapped.emit()
	pressed_down.emit()
	Haptics.vibrate(12, 30)
	queue_redraw()


func touch_up() -> void:
	touch_index = -1
	if is_down:
		is_down = false
		released.emit()
	queue_redraw()


func set_label(text: String) -> void:
	if text != label:
		label = text
		queue_redraw()


func set_enabled(v: bool) -> void:
	if v != enabled:
		enabled = v
		if not v:
			touch_up()
		queue_redraw()


func _draw() -> void:
	var c := size * 0.5
	var bg := color
	if not enabled:
		bg = Color(bg, bg.a * 0.45)
	elif is_down or (mode == "toggle" and toggled):
		bg = accent.darkened(0.15)
	draw_circle(c, radius, bg)
	var ring := accent if enabled else Color(0.6, 0.6, 0.6, 0.5)
	if highlight and enabled:
		var a := 0.5 + 0.5 * sin(_pulse * 6.0)
		draw_arc(c, radius + 5.0, 0, TAU, 48, Color(accent, a), 4.0, true)
	draw_arc(c, radius - 1.5, 0, TAU, 48, Color(ring, 0.9), 3.0, true)
	var font := ThemeDB.fallback_font
	var fs := int(clampf(radius * 0.42, 14, 30))
	if label.length() > 6:
		fs = int(fs * 0.78)
	var txt_col := Color(0.1, 0.1, 0.1) if (is_down or (mode == "toggle" and toggled)) and enabled else Color(1, 1, 1, 1.0 if enabled else 0.5)
	var tw := font.get_string_size(label, HORIZONTAL_ALIGNMENT_CENTER, -1, fs).x
	var y := c.y + fs * 0.35
	if sublabel != "":
		y -= fs * 0.35
	draw_string(font, Vector2(c.x - tw * 0.5, y), label, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, txt_col)
	if sublabel != "":
		var sfs := int(fs * 0.6)
		var sw := font.get_string_size(sublabel, HORIZONTAL_ALIGNMENT_CENTER, -1, sfs).x
		draw_string(font, Vector2(c.x - sw * 0.5, y + fs * 0.8), sublabel, HORIZONTAL_ALIGNMENT_LEFT, -1, sfs, Color(txt_col, 0.8))
