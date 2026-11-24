class_name SettingsPanel
extends Overlay
## Ayarlar: ses, hassasiyet, grafik kalitesi, titreşim, solak modu, ilerleme sıfırlama.

signal closed

var _reset_btn: Button
var _reset_stage := 0


func _ready() -> void:
	build_frame("SETTINGS", Vector2(760, 0))
	var scroll := ScrollContainer.new()
	scroll.custom_minimum_size = Vector2(700, 430)
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	body.add_child(scroll)
	var list := VBoxContainer.new()
	list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	list.add_theme_constant_override("separation", 12)
	scroll.add_child(list)

	_slider(list, "Sound effects", "sfx_volume", 0.0, 1.0)
	_slider(list, "Music", "music_volume", 0.0, 1.0)
	_slider(list, "Rotate sensitivity", "sensitivity", 0.25, 3.0)
	_slider(list, "Camera sensitivity", "camera_sensitivity", 0.25, 3.0)
	_quality(list)
	_toggle(list, "Vibration", "vibration")
	_toggle(list, "Invert vertical rotation", "invert_pitch")
	_toggle(list, "Show guide arrow", "show_guide")
	_toggle(list, "Left-handed mode (swap controls)", "left_handed")

	var help := UITheme.label("Keyboard: WASD walk · J/L I/K U/O rotate · Q/E lower/lift · Shift fine · Space grab/drop · R rest · T reset · 1/2/3 camera · Esc pause", 18, UITheme.MUTED)
	list.add_child(help)

	_reset_btn = UITheme.button("Reset progress", 360, 60)
	_reset_btn.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	_reset_btn.pressed.connect(_on_reset)
	list.add_child(_reset_btn)

	add_button("CLOSE", func():
		GameState.save_game()
		closed.emit()
		queue_free())
	pop_in()


func _row(list: VBoxContainer, text: String) -> HBoxContainer:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 18)
	var l := UITheme.label(text, 24)
	l.custom_minimum_size = Vector2(300, 0)
	l.autowrap_mode = TextServer.AUTOWRAP_OFF
	row.add_child(l)
	list.add_child(row)
	return row


func _slider(list: VBoxContainer, text: String, key: String, mn: float, mx: float) -> void:
	var row := _row(list, text)
	var s := HSlider.new()
	s.min_value = mn
	s.max_value = mx
	s.step = 0.05
	s.value = float(GameState.get_setting(key))
	s.custom_minimum_size = Vector2(300, 48)
	s.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	s.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	var val := UITheme.label("", 22, UITheme.MUTED)
	val.custom_minimum_size = Vector2(70, 0)
	val.autowrap_mode = TextServer.AUTOWRAP_OFF
	var fmt := func(v: float) -> String:
		return "%d%%" % int(round(v * 100.0)) if mx <= 1.0 else "%.2fx" % v
	val.text = fmt.call(s.value)
	s.value_changed.connect(func(v: float):
		GameState.set_setting(key, v)
		val.text = fmt.call(v)
		if key == "sfx_volume":
			AudioManager.play("click", 0.0, 1.0, 0.15))
	row.add_child(s)
	row.add_child(val)


func _toggle(list: VBoxContainer, text: String, key: String) -> void:
	var row := _row(list, text)
	var c := CheckButton.new()
	c.button_pressed = bool(GameState.get_setting(key))
	c.focus_mode = Control.FOCUS_NONE
	c.toggled.connect(func(on: bool):
		GameState.set_setting(key, on)
		AudioManager.play("click", -4.0))
	row.add_child(c)


func _quality(list: VBoxContainer) -> void:
	var row := _row(list, "Graphics quality")
	var o := OptionButton.new()
	o.add_item("Low (battery saver)", 0)
	o.add_item("Medium", 1)
	o.add_item("High", 2)
	o.selected = clampi(int(GameState.get_setting("quality")), 0, 2)
	o.focus_mode = Control.FOCUS_NONE
	o.custom_minimum_size = Vector2(300, 56)
	o.item_selected.connect(func(i: int): GameState.set_setting("quality", i))
	row.add_child(o)


func _on_reset() -> void:
	_reset_stage += 1
	if _reset_stage == 1:
		_reset_btn.text = "Are you sure? Tap again"
	else:
		GameState.reset_to_defaults(true)
		_reset_btn.text = "Progress reset"
		_reset_btn.disabled = true
