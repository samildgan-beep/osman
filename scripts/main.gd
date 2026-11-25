extends Node
## Ekran yönlendirici: ana menü, bölüm seçimi, oyun ve açılır paneller arasında geçiş.
## Android geri tuşunu ve uygulama yaşam döngüsünü de burada ele alır.

var _menu_layer: CanvasLayer
var _screen: Control
var _popup: Control
var _game: Game
var _fade: ColorRect
var _starting := false


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	get_tree().set_auto_accept_quit(false)
	_menu_layer = CanvasLayer.new()
	_menu_layer.layer = 10
	_menu_layer.process_mode = Node.PROCESS_MODE_ALWAYS
	add_child(_menu_layer)
	_fade = ColorRect.new()
	_fade.color = Color(0, 0, 0, 0)
	_fade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_fade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var fade_layer := CanvasLayer.new()
	fade_layer.layer = 100
	fade_layer.process_mode = Node.PROCESS_MODE_ALWAYS
	add_child(fade_layer)
	fade_layer.add_child(_fade)
	if LevelDB.errors.size() > 0 or ItemDB.errors.size() > 0:
		push_warning("Veri uyarıları: %s %s" % [str(LevelDB.errors), str(ItemDB.errors)])
	show_main_menu()


# ---------------------------------------------------------------- ekranlar

func show_main_menu() -> void:
	_end_game()
	var m := MainMenu.new()
	m.play.connect(start_level)
	m.open_levels.connect(show_levels)
	m.open_wardrobe.connect(func(): _open_popup(WardrobePanel.new()))
	m.open_settings.connect(func(): _open_popup(SettingsPanel.new()))
	_set_screen(m)


func show_levels() -> void:
	_end_game()
	var bg := MainMenu.new()
	_set_screen(bg)
	var ls := LevelSelect.new()
	ls.level_chosen.connect(start_level)
	ls.back.connect(show_main_menu)
	_open_popup(ls)


func start_level(level_id: int) -> void:
	level_id = clampi(level_id, 1, LevelDB.count())
	if not GameState.is_level_unlocked(level_id) or _starting:
		return
	_starting = true
	await _fade_to(1.0)
	_end_game()
	_clear_screen()
	get_tree().paused = false
	_game = Game.new()
	# Main her zaman çalışır; oyun ise duraklatılabilir olmalı (devralmasın).
	_game.process_mode = Node.PROCESS_MODE_PAUSABLE
	_game.setup(level_id)
	_game.exit_to_levels.connect(func(): _deferred(show_levels))
	_game.request_level.connect(func(id: int): _deferred(func(): start_level(id)))
	add_child(_game)
	_starting = false
	await _fade_to(0.0)


## Sinyal içinden sahne değiştirmek güvenli olsun diye bir sonraki kareye ertelenir.
func _deferred(cb: Callable) -> void:
	cb.call_deferred()


func _end_game() -> void:
	get_tree().paused = false
	if _game != null and is_instance_valid(_game):
		_game.queue_free()
	_game = null
	RenderingServer.global_shader_parameter_set("cut_height", 100000.0)
	RenderingServer.global_shader_parameter_set("ceil_cut_height", 100000.0)


func _set_screen(c: Control) -> void:
	_clear_screen()
	_screen = c
	_menu_layer.add_child(c)


func _clear_screen() -> void:
	_close_popup()
	if _screen != null and is_instance_valid(_screen):
		_screen.queue_free()
	_screen = null


func _open_popup(p: Control) -> void:
	_close_popup()
	_popup = p
	if p.has_signal("closed"):
		p.connect("closed", func(): _popup = null)
	_menu_layer.add_child(p)


func _close_popup() -> void:
	if _popup != null and is_instance_valid(_popup):
		_popup.queue_free()
	_popup = null


func _fade_to(a: float) -> void:
	var tw := create_tween()
	tw.tween_property(_fade, "color:a", a, 0.22)
	await tw.finished


# ---------------------------------------------------------------- sistem

func _notification(what: int) -> void:
	match what:
		NOTIFICATION_WM_CLOSE_REQUEST:
			GameState.save_game()
			get_tree().quit()
		NOTIFICATION_WM_GO_BACK_REQUEST:
			_on_back()


func _unhandled_input(event: InputEvent) -> void:
	# Menülerde Esc = geri. Oyun sürerken Esc'yi Game ele alır; duraklatılmışken burada devam ettirilir.
	if not event.is_action_pressed("pause"):
		return
	if _game != null and is_instance_valid(_game):
		if get_tree().paused:
			_game.on_back()
			get_viewport().set_input_as_handled()
		return
	_on_back()


func _on_back() -> void:
	if _game != null and is_instance_valid(_game):
		_game.on_back()
		return
	if _popup != null and is_instance_valid(_popup):
		if _popup is LevelSelect:
			show_main_menu()
		else:
			_close_popup()
		return
	GameState.save_game()
	get_tree().quit()
