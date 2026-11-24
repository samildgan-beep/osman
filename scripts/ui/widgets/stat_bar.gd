class_name StatBar
extends Control
## Yuvarlatılmış durum barı (sağlamlık / dayanıklılık). Değer düşünce renk değişir,
## ani düşüşler kısa süre beyaz "hasar izi" olarak görünür.

var value := 100.0
var max_value := 100.0
var title := ""
var good := Color("4cd07d")
var mid := Color("ffc233")
var low := Color("ef5350")
var _trail := 100.0
var _blink := 0.0


func _init(p_title: String = "", p_good: Color = Color("4cd07d")) -> void:
	title = p_title
	good = p_good
	custom_minimum_size = Vector2(280, 44)
	mouse_filter = Control.MOUSE_FILTER_IGNORE


func set_value(v: float) -> void:
	v = clampf(v, 0.0, max_value)
	if v < value - 0.01:
		_blink = 0.3
	value = v
	queue_redraw()


func _process(delta: float) -> void:
	var changed := false
	if _trail > value:
		_trail = maxf(value, _trail - delta * 40.0)
		changed = true
	elif _trail < value:
		_trail = value
		changed = true
	if _blink > 0.0:
		_blink = maxf(0.0, _blink - delta)
		changed = true
	if changed:
		queue_redraw()


func _draw() -> void:
	var font := ThemeDB.fallback_font
	var fs := 18
	var bar_rect := Rect2(Vector2(0, 20), Vector2(size.x, size.y - 20))
	draw_string(font, Vector2(2, 15), title, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, Color(1, 1, 1, 0.9))
	var pct := "%d%%" % int(round(value / max_value * 100.0))
	var pw := font.get_string_size(pct, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
	draw_string(font, Vector2(size.x - pw - 2, 15), pct, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, Color(1, 1, 1, 0.9))
	_round_rect(bar_rect, Color(0, 0, 0, 0.45))
	var f := value / max_value
	var col := good
	if f < 0.3:
		col = low
	elif f < 0.6:
		col = mid.lerp(good, (f - 0.3) / 0.3)
	if _trail > value:
		_round_rect(Rect2(bar_rect.position, Vector2(bar_rect.size.x * (_trail / max_value), bar_rect.size.y)), Color(1, 1, 1, 0.55))
	if f > 0.0:
		var fill := Rect2(bar_rect.position, Vector2(maxf(bar_rect.size.y, bar_rect.size.x * f), bar_rect.size.y))
		_round_rect(fill, col.lightened(0.3) if _blink > 0.0 else col)


func _round_rect(r: Rect2, col: Color) -> void:
	var sb := StyleBoxFlat.new()
	sb.bg_color = col
	sb.set_corner_radius_all(int(r.size.y * 0.5))
	draw_style_box(sb, r)
