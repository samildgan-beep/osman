class_name UITheme
extends RefCounted
## Tüm arayüz için ortak tema: büyük, okunaklı, parmakla kolay basılır düğmeler.

const BG := Color("1d2230")
const PANEL := Color(0.11, 0.13, 0.18, 0.94)
const ACCENT := Color("ffc233")
const GOOD := Color("4cd07d")
const BAD := Color("ef5350")
const TEXT := Color("f4f1ea")
const MUTED := Color("a9b0bf")

static var _theme: Theme


static func get_theme() -> Theme:
	if _theme == null:
		_theme = _make()
	return _theme


static func _make() -> Theme:
	var t := Theme.new()
	t.default_font_size = 26
	# Düğmeler
	t.set_stylebox("normal", "Button", _box(Color("2c3446"), 16, Color("3d4760")))
	t.set_stylebox("hover", "Button", _box(Color("36405a"), 16, ACCENT))
	t.set_stylebox("pressed", "Button", _box(ACCENT.darkened(0.1), 16, ACCENT))
	t.set_stylebox("disabled", "Button", _box(Color("23293a"), 16, Color("2c3446")))
	t.set_stylebox("focus", "Button", _box(Color(0, 0, 0, 0), 16, ACCENT, 3))
	t.set_color("font_color", "Button", TEXT)
	t.set_color("font_hover_color", "Button", Color.WHITE)
	t.set_color("font_pressed_color", "Button", Color("1d2230"))
	t.set_color("font_disabled_color", "Button", Color("6c7486"))
	t.set_font_size("font_size", "Button", 28)
	# Paneller
	t.set_stylebox("panel", "PanelContainer", _box(PANEL, 22, Color("3d4760")))
	t.set_stylebox("panel", "Panel", _box(PANEL, 22, Color("3d4760")))
	# Etiketler
	t.set_color("font_color", "Label", TEXT)
	t.set_color("font_outline_color", "Label", Color(0, 0, 0, 0.6))
	t.set_constant("outline_size", "Label", 0)
	# Kaydırıcı
	t.set_stylebox("slider", "HSlider", _box(Color("3d4760"), 6, Color("3d4760"), 0, 8))
	t.set_stylebox("grabber_area", "HSlider", _box(ACCENT, 6, ACCENT, 0, 8))
	t.set_stylebox("grabber_area_highlight", "HSlider", _box(ACCENT.lightened(0.1), 6, ACCENT, 0, 8))
	# Onay kutusu
	t.set_color("font_color", "CheckButton", TEXT)
	t.set_font_size("font_size", "CheckButton", 26)
	t.set_color("font_color", "OptionButton", TEXT)
	t.set_stylebox("normal", "OptionButton", _box(Color("2c3446"), 12, Color("3d4760")))
	t.set_stylebox("hover", "OptionButton", _box(Color("36405a"), 12, ACCENT))
	t.set_stylebox("pressed", "OptionButton", _box(Color("36405a"), 12, ACCENT))
	# Kaydırma kabı
	t.set_stylebox("panel", "ScrollContainer", StyleBoxEmpty.new())
	t.set_stylebox("panel", "PopupMenu", _box(PANEL, 12, Color("3d4760")))
	t.set_font_size("font_size", "PopupMenu", 26)
	return t


static func _box(bg: Color, radius: int, border: Color, border_w: int = 2, pad: int = 14) -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color = bg
	s.set_corner_radius_all(radius)
	s.border_color = border
	s.set_border_width_all(border_w)
	s.content_margin_left = pad + 6
	s.content_margin_right = pad + 6
	s.content_margin_top = pad
	s.content_margin_bottom = pad
	s.anti_aliasing = true
	return s


## Yardımcı: ortalanmış başlık etiketi
static func label(text: String, size: int = 26, color: Color = TEXT, align: HorizontalAlignment = HORIZONTAL_ALIGNMENT_LEFT) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", color)
	l.horizontal_alignment = align
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	return l


static func button(text: String, min_w: float = 280.0, min_h: float = 72.0) -> Button:
	var b := Button.new()
	b.text = text
	b.custom_minimum_size = Vector2(min_w, min_h)
	b.focus_mode = Control.FOCUS_NONE
	b.pressed.connect(func(): AudioManager.play("click", -4.0))
	return b

