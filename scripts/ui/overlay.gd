class_name Overlay
extends Control
## Menü ekranları için temel sınıf: koyu arka plan + ortalanmış panel.

var panel: PanelContainer
var body: VBoxContainer
var _dim: ColorRect


func _init() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	theme = UITheme.get_theme()
	process_mode = Node.PROCESS_MODE_ALWAYS


func build_frame(title: String, min_size: Vector2 = Vector2(620, 0), dim_alpha: float = 0.6) -> void:
	_dim = ColorRect.new()
	_dim.color = Color(0.02, 0.03, 0.06, dim_alpha)
	_dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	_dim.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(_dim)
	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(center)
	panel = PanelContainer.new()
	panel.custom_minimum_size = min_size
	center.add_child(panel)
	body = VBoxContainer.new()
	body.add_theme_constant_override("separation", 14)
	body.alignment = BoxContainer.ALIGNMENT_CENTER
	panel.add_child(body)
	if title != "":
		body.add_child(UITheme.label(title, 40, UITheme.ACCENT, HORIZONTAL_ALIGNMENT_CENTER))


func add_button(text: String, cb: Callable, min_w: float = 420.0) -> Button:
	var b := UITheme.button(text, min_w)
	b.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	b.pressed.connect(cb)
	body.add_child(b)
	return b


func pop_in() -> void:
	if panel == null:
		return
	panel.pivot_offset = panel.size * 0.5
	panel.scale = Vector2(0.92, 0.92)
	modulate.a = 0.0
	var tw := create_tween()
	tw.set_parallel(true)
	tw.tween_property(self, "modulate:a", 1.0, 0.18)
	tw.tween_property(panel, "scale", Vector2.ONE, 0.22).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
