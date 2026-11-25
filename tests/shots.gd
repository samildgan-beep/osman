extends Node
## Geliştirme aracı: sanal ekranda oyunu açıp ekran görüntüleri kaydeder.
## godot --path . res://tests/shots.tscn -- <çıktı_klasörü>
var out := "user://shots"

func _ready() -> void:
	GameState.persist = false
	var args := OS.get_cmdline_user_args()
	if args.size() > 0:
		out = args[0]
	DirAccess.make_dir_recursive_absolute(out)
	await _menu_shots()
	await _level_shots(1, "l1")
	await _win_shots(1, "w1")
	await _level_shots(16, "l16")
	get_tree().quit()


func _menu_shots() -> void:
	var layer := CanvasLayer.new()
	add_child(layer)
	var mm := MainMenu.new()
	layer.add_child(mm)
	await _wait(30)
	await _snap("menu_main")
	var ls := LevelSelect.new()
	layer.add_child(ls)
	await _wait(30)
	await _snap("menu_levels")
	layer.queue_free()
	await _wait(3)


## Eşyayı hedefe koyup kutlamayı ve sonuç ekranını görüntüle.
func _win_shots(id: int, tag: String) -> void:
	var game := Game.new()
	game.setup(id)
	add_child(game)
	await _wait(30)
	var g: Vector3 = game.info.goal_center
	game.player.teleport(g + Vector3(1.2, 0.05, 0.0), PI * 0.5)
	game.item.place_on_ground(g)
	await _wait_sec(2.2)
	await _snap(tag + "_celebrate")
	await _wait_sec(3.5)
	await _snap(tag + "_result")
	game.queue_free()
	await _wait(5)


func _snap(name: String) -> void:
	await RenderingServer.frame_post_draw
	var img := get_viewport().get_texture().get_image()
	img.save_png(out.path_join(name + ".png"))
	print("saved ", name)


func _wait_sec(s: float) -> void:
	var t0 := Time.get_ticks_msec()
	while Time.get_ticks_msec() - t0 < int(s * 1000.0):
		await get_tree().process_frame


func _wait(n: int) -> void:
	for i in n:
		await get_tree().process_frame


func _level_shots(id: int, tag: String) -> void:
	var game := Game.new()
	game.setup(id)
	add_child(game)
	await _wait(40)
	await _snap(tag + "_start")
	# Eşyayı al
	var p := game.player
	var to_item := game.item.global_position - p.global_position
	to_item.y = 0
	p.teleport(game.item.global_position - to_item.normalized() * (1.0 + game.item.half.z) + Vector3(0, 0.05 - game.item.global_position.y, 0), atan2(-to_item.x, -to_item.z))
	await _wait(5)
	game.input.press("interact")
	await _wait(60)
	# Yandan yakın bakış (eller eşyaya değiyor mu)
	game.cam.yaw = p.get_yaw() + PI * 0.5
	game.cam.pitch = deg_to_rad(-12)
	game.cam.dist = 2.6
	await _wait(40)
	await _snap(tag + "_hold_side")
	game.input.lift = 1.0
	await _wait(25)
	game.input.lift = 0.0
	await _wait(10)
	await _snap(tag + "_hold_lifted")
	# Merdivenin başına götür
	var wps: Array = game.info.waypoints
	p.teleport(wps[1] + Vector3(0, 0.05, -0.6), PI)
	game.cam.yaw = PI + 0.4
	game.cam.pitch = deg_to_rad(-25)
	game.cam.dist = 4.5
	await _wait(60)
	await _snap(tag + "_stairs")
	# Ara sahanlık
	p.teleport(wps[3] + Vector3(0, 0.05, 0), 0.0)
	game.cam.yaw = 0.6
	await _wait(60)
	await _snap(tag + "_landing")
	game.queue_free()
	await _wait(5)
