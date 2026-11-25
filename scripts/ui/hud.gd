class_name HUD
extends Control
## Oyun ekranı: bölüm bilgisi, süre, sağlamlık ve dayanıklılık barları, yön oku,
## ipuçları, hasar yazıları, kırmızı çarpma parlaması ve sırt taşıma görüş daralması.

var _title: Label
var _timer: Label
var _dur_bar: StatBar
var _sta_bar: StatBar
var _hint_panel: PanelContainer
var _hint_label: Label
var _center: Label
var _prox_label: Label
var _flash: ColorRect
var _vignette: TextureRect
var _danger: TextureRect
var _arrow: GuideArrow
var _popups: Control
var _hint_time := 0.0
var _center_time := 0.0
var _flash_a := 0.0
var _vignette_target := 0.0


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	theme = UITheme.get_theme()

	_flash = ColorRect.new()
	_flash.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_flash.color = Color(1, 0.1, 0.05, 0.0)
	_flash.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_flash)

	_vignette = _make_vignette(Color(0, 0, 0, 0.85))
	_vignette.modulate.a = 0.0
	add_child(_vignette)
	_danger = _make_vignette(Color(0.9, 0.05, 0.0, 0.6))
	_danger.modulate.a = 0.0
	add_child(_danger)

	# Sol üst bilgi paneli
	var panel := PanelContainer.new()
	panel.position = Vector2(16, 12)
	panel.add_theme_stylebox_override("panel", UITheme._box(Color(0.08, 0.1, 0.14, 0.6), 16, Color(0, 0, 0, 0), 0, 10))
	add_child(panel)
	var vb := VBoxContainer.new()
	vb.add_theme_constant_override("separation", 6)
	panel.add_child(vb)
	var top := HBoxContainer.new()
	top.add_theme_constant_override("separation", 16)
	vb.add_child(top)
	_title = UITheme.label("", 22, UITheme.ACCENT)
	_title.autowrap_mode = TextServer.AUTOWRAP_OFF
	top.add_child(_title)
	_timer = UITheme.label("0:00.0", 22, UITheme.TEXT)
	_timer.autowrap_mode = TextServer.AUTOWRAP_OFF
	top.add_child(_timer)
	_dur_bar = StatBar.new("Item", Color("4cd07d"))
	vb.add_child(_dur_bar)
	_sta_bar = StatBar.new("Stamina", Color("4fa3ff"))
	vb.add_child(_sta_bar)

	_arrow = GuideArrow.new()
	place(_arrow, Control.PRESET_CENTER_TOP, Rect2(-60, 6, 120, 110))
	add_child(_arrow)

	_prox_label = UITheme.label("", 22, Color("ffd54f"), HORIZONTAL_ALIGNMENT_CENTER)
	place(_prox_label, Control.PRESET_CENTER_TOP, Rect2(-250, 118, 500, 32))
	_prox_label.add_theme_constant_override("outline_size", 6)
	add_child(_prox_label)

	_hint_panel = PanelContainer.new()
	_hint_panel.add_theme_stylebox_override("panel", UITheme._box(Color(0.08, 0.1, 0.14, 0.82), 18, UITheme.ACCENT, 2, 12))
	_hint_panel.custom_minimum_size = Vector2(600, 0)
	place(_hint_panel, Control.PRESET_CENTER_TOP, Rect2(-300, 156, 600, 0))
	_hint_panel.grow_horizontal = Control.GROW_DIRECTION_BOTH
	_hint_panel.visible = false
	add_child(_hint_panel)
	_hint_label = UITheme.label("", 24, UITheme.TEXT, HORIZONTAL_ALIGNMENT_CENTER)
	_hint_panel.add_child(_hint_label)

	_center = UITheme.label("", 56, UITheme.TEXT, HORIZONTAL_ALIGNMENT_CENTER)
	place(_center, Control.PRESET_CENTER, Rect2(-400, -140, 800, 120))
	_center.add_theme_constant_override("outline_size", 12)
	_center.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	add_child(_center)

	_popups = Control.new()
	_popups.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_popups.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_popups)


## Kontrolü bir bağlantı noktasına (anchor) göre yerleştirir; r = bağlantıya göre ofset dikdörtgeni.
static func place(c: Control, preset: Control.LayoutPreset, r: Rect2) -> void:
	c.set_anchors_and_offsets_preset(preset)
	c.offset_left = r.position.x
	c.offset_top = r.position.y
	c.offset_right = r.position.x + r.size.x
	c.offset_bottom = r.position.y + r.size.y


func _make_vignette(edge: Color) -> TextureRect:
	var g := Gradient.new()
	g.set_color(0, Color(edge, 0.0))
	g.set_color(1, edge)
	g.add_point(0.55, Color(edge, 0.0))
	var gt := GradientTexture2D.new()
	gt.gradient = g
	gt.fill = GradientTexture2D.FILL_RADIAL
	gt.fill_from = Vector2(0.5, 0.5)
	gt.fill_to = Vector2(1.05, 1.05)
	gt.width = 256
	gt.height = 256
	var tr := TextureRect.new()
	tr.texture = gt
	tr.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	tr.stretch_mode = TextureRect.STRETCH_SCALE
	tr.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	tr.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return tr


func setup(level: Dictionary, item: Dictionary) -> void:
	_title.text = "%d. %s" % [int(level.id), str(level.name)]
	_dur_bar.title = "%s condition" % str(item.name)
	_dur_bar.set_value(100.0)
	_sta_bar.set_value(100.0)


func set_time(t: float) -> void:
	_timer.text = DamageModel.format_time(t)


func set_durability(v: float) -> void:
	_dur_bar.set_value(v)
	_danger.modulate.a = clampf((30.0 - v) / 30.0, 0.0, 1.0) * 0.8 if v > 0.0 else 0.0


func set_stamina(v: float) -> void:
	_sta_bar.set_value(v)


func set_guide(angle: float, text: String, visible_now: bool) -> void:
	_arrow.active = visible_now
	_arrow.set_data(angle, text)


func set_narrow_view(on: bool) -> void:
	_vignette_target = 0.75 if on else 0.0


func show_proximity(faces: Array) -> void:
	if faces.is_empty():
		_prox_label.text = ""
		return
	var names: Array = []
	for f in faces:
		names.append(DamageModel.FACE_NAMES.get(f, f))
	_prox_label.text = "Careful: " + ", ".join(names)


func hint(text: String, duration: float = 4.5) -> void:
	if text == "":
		_hint_panel.visible = false
		_hint_time = 0.0
		return
	_hint_label.text = text
	_hint_panel.visible = true
	_hint_time = duration


## Kalıcı ipucu (eğitim adımları); duration < 0 -> kapatılana kadar
func hint_persistent(text: String) -> void:
	hint(text, -1.0)


func center_message(text: String, duration: float = 1.6, color: Color = UITheme.TEXT) -> void:
	_center.text = text
	_center.add_theme_color_override("font_color", color)
	_center.modulate.a = 1.0
	_center_time = duration


func damage_flash(amount: float, face: String, hard: bool) -> void:
	_flash_a = maxf(_flash_a, clampf(amount / 25.0, 0.12, 0.45) if hard else clampf(amount / 30.0, 0.0, 0.18))
	if amount >= 1.0:
		var txt := "-%d" % int(ceil(amount))
		if hard:
			txt += "  " + str(DamageModel.FACE_NAMES.get(face, ""))
		_popup(txt, UITheme.BAD if hard else Color("ffb74d"))


func _popup(text: String, color: Color) -> void:
	if _popups.get_child_count() > 6:
		_popups.get_child(0).queue_free()
	var l := UITheme.label(text, 30, color, HORIZONTAL_ALIGNMENT_CENTER)
	l.add_theme_constant_override("outline_size", 8)
	l.size = Vector2(400, 40)
	l.position = Vector2(size.x * 0.5 - 200 + randf_range(-40, 40), size.y * 0.38)
	l.autowrap_mode = TextServer.AUTOWRAP_OFF
	_popups.add_child(l)
	var tw := l.create_tween()
	tw.set_parallel(true)
	tw.tween_property(l, "position:y", l.position.y - 90.0, 1.1).set_ease(Tween.EASE_OUT)
	tw.tween_property(l, "modulate:a", 0.0, 1.1).set_delay(0.3)
	tw.chain().tween_callback(l.queue_free)


func _process(delta: float) -> void:
	if _hint_time > 0.0:
		_hint_time -= delta
		if _hint_time <= 0.0:
			_hint_panel.visible = false
	if _center_time > 0.0:
		_center_time -= delta
		if _center_time < 0.4:
			_center.modulate.a = maxf(0.0, _center_time / 0.4)
	if _flash_a > 0.0:
		_flash_a = maxf(0.0, _flash_a - delta * 1.6)
	_flash.color.a = _flash_a
	_vignette.modulate.a = lerpf(_vignette.modulate.a, _vignette_target, 1.0 - exp(-3.0 * delta))
