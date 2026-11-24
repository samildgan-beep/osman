class_name StarRow
extends Control
## Yıldızları yazı tipine bağlı olmadan çizer (her cihazda aynı görünür).

var count := 3
var filled := 0
var star_size := 28.0
var fill_color := Color("ffc233")
var empty_color := Color(1, 1, 1, 0.25)
var anim := 1.0          # 0..1 arası, sonuç ekranında yıldızların sırayla dolması için


func _init(p_filled: int = 0, p_size: float = 28.0, p_count: int = 3) -> void:
	filled = p_filled
	star_size = p_size
	count = p_count
	custom_minimum_size = Vector2(p_size * p_count * 1.15, p_size * 1.1)
	mouse_filter = Control.MOUSE_FILTER_IGNORE


func set_filled(n: int) -> void:
	filled = clampi(n, 0, count)
	queue_redraw()


func _draw() -> void:
	var step := star_size * 1.15
	var start_x := (size.x - step * count) * 0.5 + step * 0.5
	for i in count:
		var c := Vector2(start_x + i * step, size.y * 0.5)
		var fill_amount := clampf(anim * count - i, 0.0, 1.0) if i < filled else 0.0
		_draw_star(c, star_size * 0.5, empty_color)
		if fill_amount > 0.0:
			_draw_star(c, star_size * 0.5 * (0.6 + 0.4 * fill_amount), fill_color)


func _draw_star(c: Vector2, r: float, col: Color) -> void:
	var pts := PackedVector2Array()
	for k in 10:
		var a := -PI * 0.5 + k * PI / 5.0
		var rr := r if k % 2 == 0 else r * 0.45
		pts.append(c + Vector2(cos(a), sin(a)) * rr)
	draw_colored_polygon(pts, col)
