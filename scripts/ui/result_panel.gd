class_name ResultPanel
extends Overlay
## Bölüm sonu ekranı (başarı ya da başarısızlık).

signal next_level
signal retry
signal to_levels

var success := false
var data := {}
var _stars: StarRow


func setup(p_success: bool, p_data: Dictionary) -> void:
	success = p_success
	data = p_data


func _ready() -> void:
	build_frame("TESLİM EDİLDİ!" if success else "GÖREV BAŞARISIZ", Vector2(640, 0), 0.55)
	if success:
		_stars = StarRow.new(int(data.get("stars", 1)), 64)
		_stars.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
		_stars.anim = 0.0
		body.add_child(_stars)
		var tw := create_tween()
		tw.tween_interval(0.25)
		tw.tween_method(_set_star_anim, 0.0, 1.0, 1.0)
		var grid := GridContainer.new()
		grid.columns = 2
		grid.add_theme_constant_override("h_separation", 30)
		grid.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
		body.add_child(grid)
		_stat(grid, "Süre", DamageModel.format_time(float(data.get("time", 0.0))))
		_stat(grid, "Hedef süre", DamageModel.format_time(float(data.get("par", 0.0))))
		_stat(grid, "Eşya sağlamlığı", "%d%%" % int(round(float(data.get("durability", 0.0)))))
		_stat(grid, "Çarpma sayısı", str(int(data.get("hits", 0))))
		if bool(data.get("perfect", false)):
			var badge := UITheme.label("KUSURSUZ TAŞIYICI rozeti!", 28, UITheme.GOOD, HORIZONTAL_ALIGNMENT_CENTER)
			body.add_child(badge)
		if bool(data.get("record", false)):
			body.add_child(UITheme.label("Yeni rekor!", 24, UITheme.ACCENT, HORIZONTAL_ALIGNMENT_CENTER))
		var unlocked: Array = data.get("new_outfits", [])
		for o in unlocked:
			body.add_child(UITheme.label("Yeni kıyafet açıldı: %s" % str(o), 22, UITheme.ACCENT, HORIZONTAL_ALIGNMENT_CENTER))
		if bool(data.get("has_next", false)):
			add_button("SONRAKİ BÖLÜM", func(): next_level.emit())
		elif bool(data.get("last_level", false)):
			body.add_child(UITheme.label("Tüm bölümleri bitirdin. Tebrikler, usta taşıyıcı!", 24, UITheme.TEXT, HORIZONTAL_ALIGNMENT_CENTER))
	else:
		body.add_child(UITheme.label(str(data.get("reason", "Eşya kırıldı!")), 30, UITheme.BAD, HORIZONTAL_ALIGNMENT_CENTER))
		body.add_child(UITheme.label(str(data.get("tip", "")), 22, UITheme.MUTED, HORIZONTAL_ALIGNMENT_CENTER))
	add_button("TEKRAR DENE", func(): retry.emit())
	add_button("BÖLÜMLER", func(): to_levels.emit())
	pop_in()


func _set_star_anim(v: float) -> void:
	if _stars == null:
		return
	var prev := int(_stars.anim * 3.0)
	_stars.anim = v
	_stars.queue_redraw()
	var now := int(v * 3.0)
	if now > prev and now <= int(data.get("stars", 0)):
		AudioManager.play("star", -2.0, 1.0 + now * 0.1, 0.0)


func _stat(grid: GridContainer, k: String, v: String) -> void:
	grid.add_child(UITheme.label(k, 24, UITheme.MUTED))
	var l := UITheme.label(v, 24, UITheme.TEXT)
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	grid.add_child(l)
