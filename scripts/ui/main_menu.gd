class_name MainMenu
extends Control
## Ana menü: oyna, bölümler, kıyafetler, ayarlar.

signal play(level_id: int)
signal open_levels
signal open_wardrobe
signal open_settings

var _t := 0.0
var _boxes: Array = []
var _stars_label: Label


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	theme = UITheme.get_theme()
	var rng := RandomNumberGenerator.new()
	rng.seed = 42
	for i in 14:
		_boxes.append({
			"x": rng.randf(), "y": rng.randf(), "s": rng.randf_range(30, 90),
			"v": rng.randf_range(0.015, 0.05), "r": rng.randf() * TAU, "w": rng.randf_range(-0.6, 0.6),
			"c": [Color("b5835a"), Color("8a5a3b"), Color("3f6e8c"), Color("e9edf0"), Color("24395e")][i % 5],
		})
	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(center)
	var vb := VBoxContainer.new()
	vb.alignment = BoxContainer.ALIGNMENT_CENTER
	vb.add_theme_constant_override("separation", 10)
	center.add_child(vb)
	var title := UITheme.label("HANDLE WITH CARE", 76, UITheme.ACCENT, HORIZONTAL_ALIGNMENT_CENTER)
	title.autowrap_mode = TextServer.AUTOWRAP_OFF
	title.add_theme_constant_override("outline_size", 18)
	title.add_theme_color_override("font_outline_color", Color("1d2230"))
	vb.add_child(title)
	var sub := UITheme.label("Narrow stairs. Bulky furniture. Zero scratches.", 26, UITheme.TEXT, HORIZONTAL_ALIGNMENT_CENTER)
	sub.autowrap_mode = TextServer.AUTOWRAP_OFF
	vb.add_child(sub)
	_stars_label = UITheme.label("", 24, UITheme.MUTED, HORIZONTAL_ALIGNMENT_CENTER)
	vb.add_child(_stars_label)
	var spacer := Control.new()
	spacer.custom_minimum_size = Vector2(0, 10)
	vb.add_child(spacer)
	var next_id := _next_level()
	var play_btn := _btn(vb, "PLAY  (Level %d)" % next_id, func(): play.emit(_next_level()))
	play_btn.add_theme_font_size_override("font_size", 34)
	play_btn.custom_minimum_size = Vector2(460, 88)
	_btn(vb, "LEVELS", func(): open_levels.emit())
	_btn(vb, "OUTFITS", func(): open_wardrobe.emit())
	_btn(vb, "SETTINGS", func(): open_settings.emit())
	if not (OS.has_feature("android") or OS.has_feature("ios") or OS.has_feature("web")):
		_btn(vb, "QUIT", func(): get_tree().quit())
	var ver := UITheme.label("v%s" % str(ProjectSettings.get_setting("application/config/version", "1.0")), 16, UITheme.MUTED)
	HUD.place(ver, Control.PRESET_BOTTOM_LEFT, Rect2(16, -36, 200, 30))
	add_child(ver)
	GameState.progress_changed.connect(_refresh)
	_refresh()
	AudioManager.play_music()


func _btn(parent: Control, text: String, cb: Callable) -> Button:
	var b := UITheme.button(text, 420, 70)
	b.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	b.pressed.connect(cb)
	parent.add_child(b)
	return b


func _refresh() -> void:
	if _stars_label != null:
		_stars_label.text = "Stars: %d / %d" % [GameState.total_stars(), LevelDB.count() * 3]


## İlk 3 yıldızsız açık bölüm, yoksa en yüksek açık bölüm.
func _next_level() -> int:
	var count := LevelDB.count()
	for i in range(1, count + 1):
		if GameState.is_level_unlocked(i) and GameState.get_stars(i) == 0:
			return i
	return GameState.highest_unlocked(count)


func _process(delta: float) -> void:
	_t += delta
	queue_redraw()


func _draw() -> void:
	var s := size
	draw_rect(Rect2(Vector2.ZERO, s), Color("1d2230"))
	# Arka plan: yavaşça süzülen koliler
	for b in _boxes:
		var y := fmod(float(b.y) + _t * float(b.v), 1.2) - 0.1
		var p := Vector2(float(b.x) * s.x, (1.0 - y) * s.y)
		var sz := float(b.s)
		var ang := float(b.r) + _t * float(b.w)
		var col: Color = b.c
		col.a = 0.22
		draw_set_transform(p, ang, Vector2.ONE)
		draw_rect(Rect2(-sz * 0.5, -sz * 0.5, sz, sz * 0.75), col)
		draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
	# Zemin şeridi (merdiven silueti)
	var step_w := 80.0
	var step_h := 22.0
	var x := 0.0
	var i := 0
	while x < s.x:
		draw_rect(Rect2(x, s.y - 40 - i * step_h * 0.0, step_w, 40), Color(1, 1, 1, 0.04))
		x += step_w + 4
		i += 1
