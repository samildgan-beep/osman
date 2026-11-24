class_name WardrobePanel
extends Overlay
## Kıyafet dolabı: yıldız toplayarak açılan karakter kıyafetleri.

signal closed

var _list: VBoxContainer


func _ready() -> void:
	build_frame("OUTFITS", Vector2(760, 0))
	body.add_child(UITheme.label("Your stars: %d" % GameState.total_stars(), 24, UITheme.ACCENT, HORIZONTAL_ALIGNMENT_CENTER))
	var scroll := ScrollContainer.new()
	scroll.custom_minimum_size = Vector2(700, 420)
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	body.add_child(scroll)
	_list = VBoxContainer.new()
	_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_list.add_theme_constant_override("separation", 10)
	scroll.add_child(_list)
	_refresh()
	add_button("CLOSE", func():
		closed.emit()
		queue_free())
	pop_in()


func _refresh() -> void:
	for c in _list.get_children():
		c.queue_free()
	for o in GameState.OUTFITS:
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 16)
		var sw := OutfitSwatch.new(o)
		row.add_child(sw)
		var unlocked := GameState.is_outfit_unlocked(o.id)
		var vb := VBoxContainer.new()
		vb.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		vb.add_child(UITheme.label(o.name, 26, UITheme.TEXT if unlocked else UITheme.MUTED))
		vb.add_child(UITheme.label("Unlocked" if unlocked else "Needs %d stars" % int(o.stars), 18, UITheme.GOOD if unlocked else UITheme.MUTED))
		row.add_child(vb)
		var b := UITheme.button("WEAR" if GameState.outfit != o.id else "WEARING", 170, 60)
		b.disabled = not unlocked or GameState.outfit == o.id
		var oid: String = o.id
		b.pressed.connect(func():
			GameState.set_outfit(oid)
			_refresh())
		row.add_child(b)
		_list.add_child(row)


class OutfitSwatch extends Control:
	var o: Dictionary

	func _init(outfit: Dictionary) -> void:
		o = outfit
		custom_minimum_size = Vector2(70, 90)
		mouse_filter = Control.MOUSE_FILTER_IGNORE

	func _draw() -> void:
		var cx := size.x * 0.5
		draw_rect(Rect2(cx - 14, 52, 11, 34), o.legs)
		draw_rect(Rect2(cx + 3, 52, 11, 34), o.legs)
		draw_rect(Rect2(cx - 18, 20, 36, 34), o.body)
		draw_circle(Vector2(cx, 12), 11, Color("e7b48f"))
		draw_rect(Rect2(cx - 12, 0, 24, 7), o.hat)
