class_name GuideArrow
extends Control
## Ekranın üstünde bir sonraki hedefi gösteren yön oku ve mesafe/kat bilgisi.

var angle := 0.0          # 0 = ileri (ekranda yukarı)
var info := ""
var active := true


func _init() -> void:
	custom_minimum_size = Vector2(120, 110)
	mouse_filter = Control.MOUSE_FILTER_IGNORE


func set_data(p_angle: float, p_info: String) -> void:
	angle = p_angle
	info = p_info
	queue_redraw()


func _draw() -> void:
	if not active:
		return
	var c := Vector2(size.x * 0.5, 42)
	draw_circle(c, 38, Color(0.08, 0.1, 0.14, 0.55))
	var pts := PackedVector2Array([Vector2(0, -28), Vector2(18, 10), Vector2(6, 4), Vector2(6, 22), Vector2(-6, 22), Vector2(-6, 4), Vector2(-18, 10)])
	var xf := Transform2D(angle, c)
	var tpts := PackedVector2Array()
	for p in pts:
		tpts.append(xf * p)
	draw_colored_polygon(tpts, Color("4cd07d"))
	var font := ThemeDB.fallback_font
	var w := font.get_string_size(info, HORIZONTAL_ALIGNMENT_CENTER, -1, 18).x
	draw_string(font, Vector2(c.x - w * 0.5, 100), info, HORIZONTAL_ALIGNMENT_LEFT, -1, 18, Color.WHITE)
