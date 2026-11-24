class_name LevelSelect
extends Overlay
## Bölüm seçimi: 15 bölüm kartı, yıldızlar, kilit durumu ve en iyi süre.

signal level_chosen(level_id: int)
signal back


func _ready() -> void:
	build_frame("BÖLÜMLER", Vector2(1100, 0), 0.0)
	var info := UITheme.label("Toplam yıldız: %d / %d   ·   Kusursuz: %d" % [GameState.total_stars(), LevelDB.count() * 3, GameState.perfect_count()], 22, UITheme.MUTED, HORIZONTAL_ALIGNMENT_CENTER)
	body.add_child(info)
	var scroll := ScrollContainer.new()
	scroll.custom_minimum_size = Vector2(1060, 470)
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	body.add_child(scroll)
	var grid := GridContainer.new()
	grid.columns = 5
	grid.add_theme_constant_override("h_separation", 14)
	grid.add_theme_constant_override("v_separation", 14)
	grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(grid)
	for L in LevelDB.all_levels():
		grid.add_child(_card(L))
	add_button("GERİ", func(): back.emit(), 300)
	pop_in()


func _card(L: Dictionary) -> Control:
	var id := int(L.id)
	var unlocked := GameState.is_level_unlocked(id)
	var rec := GameState.get_level_record(id)
	var b := Button.new()
	b.custom_minimum_size = Vector2(196, 150)
	b.focus_mode = Control.FOCUS_NONE
	b.disabled = not unlocked
	b.clip_contents = true
	var vb := VBoxContainer.new()
	vb.set_anchors_preset(Control.PRESET_FULL_RECT)
	vb.mouse_filter = Control.MOUSE_FILTER_IGNORE
	vb.alignment = BoxContainer.ALIGNMENT_CENTER
	vb.add_theme_constant_override("separation", 2)
	b.add_child(vb)
	var num := UITheme.label(str(id), 34, UITheme.ACCENT if unlocked else UITheme.MUTED, HORIZONTAL_ALIGNMENT_CENTER)
	num.mouse_filter = Control.MOUSE_FILTER_IGNORE
	vb.add_child(num)
	var nm := UITheme.label(str(L.name) if unlocked else "Kilitli", 18, UITheme.TEXT if unlocked else UITheme.MUTED, HORIZONTAL_ALIGNMENT_CENTER)
	nm.mouse_filter = Control.MOUSE_FILTER_IGNORE
	vb.add_child(nm)
	var stars := StarRow.new(int(rec.get("stars", 0)), 24)
	stars.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	vb.add_child(stars)
	var extra := ""
	if unlocked:
		var item := ItemDB.get_item(str(L.item))
		extra = "%s · %d. kat" % [str(item.name), int(L.floors)]
		if float(rec.get("best_time", 0.0)) > 0.0:
			extra += "\n" + DamageModel.format_time(float(rec.best_time))
	var ex := UITheme.label(extra, 15, UITheme.MUTED, HORIZONTAL_ALIGNMENT_CENTER)
	ex.mouse_filter = Control.MOUSE_FILTER_IGNORE
	vb.add_child(ex)
	if bool(rec.get("perfect", false)):
		var badge := UITheme.label("KUSURSUZ", 13, UITheme.GOOD, HORIZONTAL_ALIGNMENT_CENTER)
		badge.mouse_filter = Control.MOUSE_FILTER_IGNORE
		vb.add_child(badge)
	b.pressed.connect(func():
		AudioManager.play("click", -4.0)
		level_chosen.emit(id))
	return b
