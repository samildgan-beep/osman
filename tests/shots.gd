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
	await _portrait_shots(1, "p1")
	await _follow_shots(1, "f1")
	await _win_shots(1, "w1")
	get_tree().quit()


## Ana (takip) kamerayla gerçek oynanış: eşyayı al, merdivene yürü, çık, sahanlıkta dön.
func _follow_shots(id: int, tag: String) -> void:
	var game := Game.new()
	game.setup(id)
	add_child(game)
	await _wait_sec(1.0)
	await _snap(tag + "_start")
	var p := game.player
	var to_item := game.item.global_position - p.global_position
	to_item.y = 0
	p.teleport(game.item.global_position - to_item.normalized() * (1.0 + game.item.half.z) + Vector3(0, 0.05 - game.item.global_position.y, 0), atan2(-to_item.x, -to_item.z))
	await _wait_sec(0.3)
	game.input.press("interact")
	await _wait_sec(1.2)
	await _snap(tag + "_holding")
	var wps: Array = game.info.waypoints
	_tp(game, wps[1] + Vector3(0, 0.05, -0.8), PI)
	await _wait_sec(1.5)
	await _snap(tag + "_stair_bottom")
	game.cam.zoom(5.0)   # en yakına yaklaş (fare tekerleği gibi)
	await _wait_sec(1.0)
	await _snap(tag + "_zoomed")
	game.cam.dist = Config.CAM_DIST_DEFAULT
	for i in 120:
		game.input.move = Vector2(0, 0.8)
		await get_tree().physics_frame
	game.input.move = Vector2.ZERO
	await _wait_sec(0.8)
	await _snap(tag + "_climbing")
	_tp(game, wps[2] + Vector3(0, 0.05, 0), PI)
	await _wait_sec(1.0)
	for i in 50:
		game.input.move = Vector2(0.9, 0.0)
		await get_tree().physics_frame
	game.input.move = Vector2.ZERO
	await _wait_sec(0.8)
	await _snap(tag + "_landing_turn")
	game.queue_free()
	await _wait(5)


## Karakterin yakın plan portresi: önden ve yandan, boşta ve eşya taşırken.
func _portrait_shots(id: int, tag: String) -> void:
	var game := Game.new()
	game.setup(id)
	add_child(game)
	await _wait_sec(1.0)
	var p := game.player
	var cam := Camera3D.new()
	cam.fov = 40.0
	add_child(cam)
	var look := func(off: Vector3, h: float) -> void:
		var base := p.global_position + Vector3(0, h, 0)
		cam.global_position = base + p.global_basis * off
		cam.look_at(base)
		cam.make_current()
	look.call(Vector3(0, 0.1, -2.6), 1.0)
	await _wait_sec(0.4)
	await _snap(tag + "_front")
	look.call(Vector3(0, 0.05, -0.9), 1.6)
	await _wait_sec(0.2)
	await _snap(tag + "_face")
	var to_item := game.item.global_position - p.global_position
	to_item.y = 0
	p.teleport(game.item.global_position - to_item.normalized() * (1.0 + game.item.half.z) + Vector3(0, 0.05 - game.item.global_position.y, 0), atan2(-to_item.x, -to_item.z))
	await _wait_sec(0.3)
	game.input.press("interact")
	await _wait_sec(1.2)
	look.call(Vector3(-2.4, 0.3, -1.2), 1.0)
	await _wait_sec(0.3)
	await _snap(tag + "_carry_side")
	for i in 40:
		game.input.move = Vector2(0, 0.8)
		await get_tree().physics_frame
	look.call(Vector3(-2.4, 0.3, -1.2), 1.0)
	await _snap(tag + "_walk_side")
	game.input.move = Vector2.ZERO
	cam.queue_free()
	game.queue_free()
	await _wait(5)


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


## Oyuncuyu eşyasıyla birlikte ışınla (eşya geride kalıp düşmesin).
func _tp(game: Game, pos: Vector3, yaw: float) -> void:
	game.player.teleport(pos, yaw)
	if game.player.is_holding():
		game.player.carry.hold_basis = Basis()
		game.item.global_transform = game.player.carry.target_transform()
		game.item.grace = 1.0
