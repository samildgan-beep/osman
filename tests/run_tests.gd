extends Node
## Otomatik testler. Çalıştırma:
##   godot --headless --path . res://tests/run_tests.tscn
## Çıkış kodu 0 = tüm testler geçti, 1 = hata var. Kayıt dosyanıza dokunmaz.

var _passed := 0
var _failed := 0
var _section := ""


func _ready() -> void:
	GameState.persist = false
	var backup := GameState.to_dict()
	_test_damage_model()
	_test_item_db()
	_test_level_db()
	_test_save_sanitize()
	_test_save_files()
	await _test_level_builds()
	await _test_gameplay_smoke()
	await _test_free_look()
	await _test_stairs_no_phantom_damage()
	await _test_crush()
	await _test_spot_placement()
	await _test_home_speed()
	await _test_first_person()
	await _test_audio()
	GameState.from_dict(backup)
	print("")
	print("==== SONUÇ: %d geçti, %d başarısız ====" % [_passed, _failed])
	get_tree().quit(1 if _failed > 0 else 0)


func section(name: String) -> void:
	_section = name
	print("\n--- %s ---" % name)


func check(cond: bool, msg: String) -> void:
	if cond:
		_passed += 1
	else:
		_failed += 1
		printerr("  BAŞARISIZ [%s]: %s" % [_section, msg])


func near(a: float, b: float, eps: float = 0.001) -> bool:
	return absf(a - b) <= eps


# ---------------------------------------------------------------- birim testleri

func _test_damage_model() -> void:
	section("Hasar modeli")
	check(DamageModel.impact_damage(0.1, 1.0) == 0.0, "eşik altı çarpma hasarsız olmalı")
	check(DamageModel.impact_damage(Config.IMPACT_THRESHOLD, 1.0) == 0.0, "tam eşikte hasar yok")
	var d1 := DamageModel.impact_damage(1.0, 1.0)
	var d2 := DamageModel.impact_damage(2.0, 1.0)
	check(d1 > 0.0 and d2 > d1, "sert çarpma daha çok hasar vermeli")
	check(DamageModel.impact_damage(100.0, 5.0, 5.0) <= Config.IMPACT_MAX_DAMAGE, "tek çarpma üst sınırı")
	check(DamageModel.impact_damage(NAN, 1.0) == 0.0, "NaN hız güvenli")
	check(near(DamageModel.impact_damage(1.0, 1.0, 2.0), d1 * 2.0), "hassas yüz çarpanı")
	var half := Vector3(0.5, 0.3, 0.1)
	check(DamageModel.face_from_local(Vector3(0, 0, -0.1), half) == "front", "-Z ön yüz")
	check(DamageModel.face_from_local(Vector3(0, 0, 0.1), half) == "back", "+Z arka yüz")
	check(DamageModel.face_from_local(Vector3(0.5, 0, 0), half) == "right", "+X sağ")
	check(DamageModel.face_from_local(Vector3(-0.5, 0, 0), half) == "left", "-X sol")
	check(DamageModel.face_from_local(Vector3(0, 0.3, 0), half) == "top", "+Y üst")
	check(DamageModel.face_from_local(Vector3(0, -0.3, 0), half) == "bottom", "-Y alt")
	check(DamageModel.stars(100.0, 10.0, 60.0) == 3, "3 yıldız")
	check(DamageModel.stars(70.0, 10.0, 60.0) == 2, "2 yıldız (sağlamlık)")
	check(DamageModel.stars(95.0, 80.0, 60.0) == 2, "2 yıldız (süre)")
	check(DamageModel.stars(95.0, 200.0, 60.0) == 1, "1 yıldız")
	check(DamageModel.stars(0.0, 10.0, 60.0) == 0, "kırık eşya 0 yıldız")
	var ext := DamageModel.rotated_half_extents(Basis(Vector3.UP, PI * 0.5), Vector3(1, 2, 3))
	check(near(ext.x, 3.0) and near(ext.y, 2.0) and near(ext.z, 1.0), "90° dönmüş kutu uzunlukları")
	check(DamageModel.carry_speed_mult(200.0, true, true) >= Config.MIN_CARRY_SPEED_MULT * Config.BACK_CARRY_SPEED_MULT * Config.STAIR_SPEED_MULT - 0.001, "hız alt sınırı")
	check(DamageModel.stamina_rate(true, 60.0, true, true) < DamageModel.stamina_rate(true, 60.0, true, false), "merdivende daha çok yorulur")
	check(DamageModel.stamina_rate(false, 60.0, false, false) > 0.0, "dinlenince dolar")
	check(DamageModel.format_time(65.25) == "1:05.2", "süre biçimi")


func _test_item_db() -> void:
	section("Eşya verisi")
	check(ItemDB.errors.is_empty(), "items.json hatasız olmalı: %s" % str(ItemDB.errors))
	for id: String in ["kutu", "buyuk_kutu", "tv", "buyuk_tv", "sehpa", "koltuk", "gardirop", "camasir", "buzdolabi"]:
		check(ItemDB.has_item(id), "eşya var: " + id)
	check(ItemDB.get_item("buzdolabi").carry == "back", "buzdolabı sırtta")
	check(ItemDB.get_item("yok_boyle_bir_sey").id == "kutu", "bilinmeyen eşya koliye düşer")
	var bad := ItemDB.sanitize_item({"id": "x", "size": ["a", 2, 3], "weight": "çok", "fragile_faces": {"uçan": 2}})
	check(bad.size == Vector3(0.5, 0.5, 0.5), "bozuk boyut varsayılana döner")
	check(bad.weight == 10.0, "bozuk ağırlık varsayılana döner")
	check(bad.fragile_faces.is_empty(), "geçersiz yüz atılır")
	check(ItemDB.sanitize_item({}).is_empty(), "id'siz kayıt reddedilir")


func _test_level_db() -> void:
	section("Bölüm verisi")
	check(LevelDB.errors.is_empty(), "levels.json hatasız olmalı: %s" % str(LevelDB.errors))
	check(LevelDB.count() == 18, "18 bölüm")
	var goals := {}
	for L in LevelDB.all_levels():
		goals[str(L.goal)] = true
	check(goals.has("door") and goals.has("room") and goals.has("spot"), "üç hedef türü de kullanılıyor")
	check(LevelDB.get_level(13).item == "camasir" and LevelDB.get_level(13).goal == "spot", "çamaşır makinesi yerleştirme bölümü")
	check(LevelDB.get_level(1).building == "turkish", "oyun eski Türk apartmanında başlıyor")
	var lb := LevelBuilder.new()
	lb.L = LevelDB.get_level(1)
	check(not lb._is_big_item(), "küçük eşyada kurye motosikleti")
	for big_id in [7, 11, 13, 16]:
		lb.L = LevelDB.get_level(big_id)
		check(lb._is_big_item(), "bölüm %d: büyük eşyada kamyonet" % big_id)
	for L in LevelDB.all_levels():
		if int(L.id) > 5:
			check(str(L.goal) == "spot", "bölüm %d: 5. bölümden sonra eve girip eşya yerine konur" % int(L.id))
	check(LevelDB.get_level(7).building == "modern", "modern apartman da kullanılıyor")
	for L in LevelDB.all_levels():
		var id := int(L.id)
		var item := ItemDB.get_item(str(L.item))
		var dims := [item.size.x, item.size.y, item.size.z]
		dims.sort()
		# Eşyanın en küçük kesiti kapılardan geçebilmeli (en uygun açıyla).
		check(dims[0] < L.apt_door.x - 0.02 and dims[1] < L.apt_door.y, "bölüm %d: eşya daire kapısından geçebilmeli" % id)
		check(dims[0] < L.room.door.x - 0.02 and dims[1] < L.room.door.y, "bölüm %d: eşya oda kapısından geçebilmeli" % id)
		check(dims[0] < L.entrance.x - 0.02, "bölüm %d: eşya girişten geçebilmeli" % id)
		check(dims[0] < L.stair_width - 0.1, "bölüm %d: eşya merdivene sığmalı" % id)
		check(L.ceiling >= 1.95, "bölüm %d: tavan oyuncuya yetmeli" % id)
		check(L.apt_door.x <= L.landing - 0.2 + 0.001, "bölüm %d: kapı sahanlığa sığmalı" % id)
		check(L.par_time > 0.0, "bölüm %d: hedef süre" % id)
	var s := LevelDB.sanitize_level({"floors": 99, "ceiling": 0.5, "item": "uzay_gemisi", "corridor": {"turn": "çapraz"}, "obstacles": [{"type": "ejderha", "at": "hall"}]}, 1)
	check(s.floors == 6, "kat sınırı")
	check(s.ceiling >= 1.95, "tavan alt sınırı")
	check(s.item == "kutu", "bilinmeyen eşya")
	check(s.corridor.turn == "none", "geçersiz dönüş")
	check(s.obstacles.is_empty(), "geçersiz engel atılır")
	LevelDB.errors.clear()


func _test_save_sanitize() -> void:
	section("Kayıt doğrulama")
	GameState.from_dict({
		"version": 1,
		"settings": {"sfx_volume": 7.0, "sensitivity": "yüksek", "vibration": "evet", "quality": 9, "music_volume": NAN},
		"levels": {"1": {"stars": 99, "best_time": -5, "perfect": "evet"}, "abc": {"stars": 3}, "2": "bozuk", "1000": {"stars": 3}},
		"outfit": "altin",
		"total_play_time": "çok",
	})
	check(near(float(GameState.settings.sfx_volume), 1.0), "ses 0..1 aralığına kırpılır")
	check(near(float(GameState.settings.sensitivity), 1.0), "yanlış tür varsayılana döner")
	check(GameState.settings.vibration == true, "bool olmayan titreşim varsayılan")
	check(int(GameState.settings.quality) == 2, "kalite 0..2")
	check(near(float(GameState.settings.music_volume), 0.5), "NaN müzik varsayılan")
	check(GameState.get_stars(1) == 3, "yıldız 0..3")
	check(float(GameState.get_level_record(1).best_time) == 0.0, "negatif süre 0")
	check(GameState.get_level_record(1).perfect == false, "bool olmayan perfect")
	check(not GameState.levels.has("abc") and not GameState.levels.has("2") and not GameState.levels.has("1000"), "bozuk bölüm kayıtları atılır")
	check(GameState.outfit == "klasik", "kilitli kıyafet seçili olamaz")
	check(GameState.total_play_time == 0.0, "bozuk oyun süresi")
	# İyileştirme mantığı
	GameState.from_dict({"version": 1})
	check(GameState.record_result(1, 1, 100.0, 50.0, false), "ilk sonuç rekordur")
	check(GameState.record_result(1, 2, 120.0, 70.0, false), "daha çok yıldız iyileştirmedir")
	check(GameState.get_stars(1) == 2 and near(float(GameState.get_level_record(1).best_time), 100.0), "en iyi süre korunur")
	check(not GameState.record_result(1, 1, 150.0, 10.0, false), "kötü sonuç rekor değil")
	check(GameState.is_level_unlocked(2) and not GameState.is_level_unlocked(3), "kilit açma")


func _test_save_files() -> void:
	section("Bozuk kayıt dosyası")
	var path := "user://test_corrupt.json"
	for content: String in ["", "{bozuk json", "[1,2,3]", "null", "\"metin\""]:
		var f := FileAccess.open(path, FileAccess.WRITE)
		f.store_string(content)
		f.close()
		check(GameState._read_json(path).is_empty(), "bozuk içerik güvenle reddedilir: '%s'" % content)
	DirAccess.remove_absolute(ProjectSettings.globalize_path(path))
	check(GameState._read_json("user://hic_yok.json").is_empty(), "olmayan dosya")


# ---------------------------------------------------------------- entegrasyon testleri

func _test_level_builds() -> void:
	section("Bölüm kurulumu")
	for L in LevelDB.all_levels():
		var holder := Node3D.new()
		add_child(holder)
		var info := LevelBuilder.new().build(L, holder)
		var g: AABB = info.goal_aabb
		var item := ItemDB.get_item(str(L.item))
		var foot := minf(item.size.x, item.size.z)
		check(g.size.x > foot and g.size.z > foot, "bölüm %d: hedef alan eşyadan büyük" % int(L.id))
		check(info.waypoints.size() >= 6, "bölüm %d: yol noktaları" % int(L.id))
		check(absf(g.position.y - int(L.floors) * float(info.floor_height)) < 0.01, "bölüm %d: hedef doğru katta" % int(L.id))
		check(info.has("npc_pos") and info.has("npc_yaw"), "bölüm %d: ev sahibi konumu" % int(L.id))
		if str(L.goal) == "spot":
			var facing: Vector3 = info.goal_facing
			check(absf(facing.length() - 1.0) < 0.01 and absf(facing.y) < 0.01, "bölüm %d: yerleştirme yönü yatay" % int(L.id))
			var sb: Basis = info.spot_basis
			check((-sb.z).dot(facing) > 0.99, "bölüm %d: hayalet görüntü odaya bakıyor" % int(L.id))
		var npc_p: Vector3 = info.npc_pos
		check(not g.grow(0.2).has_point(npc_p + Vector3(0, 0.5, 0)), "bölüm %d: ev sahibi hedef alanın içinde değil" % int(L.id))
		await get_tree().physics_frame
		await get_tree().physics_frame
		# Yol noktalarının üstünde zemin olmalı (ışınla kontrol)
		var space := holder.get_world_3d().direct_space_state
		var ok := true
		for wp in info.waypoints:
			var q := PhysicsRayQueryParameters3D.create(wp + Vector3(0, 1.0, 0), wp + Vector3(0, -0.6, 0), Config.LAYER_WORLD)
			var hit := space.intersect_ray(q)
			if hit.is_empty() or absf(float(hit.position.y) - wp.y) > 0.45:
				ok = false
				printerr("    zemin yok: bölüm %d nokta %s" % [int(L.id), str(wp)])
		check(ok, "bölüm %d: tüm yol noktalarında zemin var" % int(L.id))
		# Yol noktası oyuncu boyunda boş olmalı (tavana/duvara gömülü değil)
		var clear := true
		for wp in info.waypoints:
			var qp := PhysicsShapeQueryParameters3D.new()
			var cap := CapsuleShape3D.new()
			cap.radius = 0.25
			cap.height = 1.6
			qp.shape = cap
			qp.transform = Transform3D(Basis(), wp + Vector3(0, 0.9, 0))
			qp.collision_mask = Config.LAYER_WORLD
			if not space.intersect_shape(qp, 1).is_empty():
				clear = false
				printerr("    dar nokta: bölüm %d nokta %s" % [int(L.id), str(wp)])
		check(clear, "bölüm %d: yol noktaları oyuncuya yetecek kadar boş" % int(L.id))
		holder.queue_free()
		await get_tree().process_frame


## Eşyayı oyuncunun eline verir (yanına ışınlayıp AL'a basar).
func _grab_item(game: Game) -> void:
	var p := game.player
	var to_item := game.item.global_position - p.global_position
	to_item.y = 0
	if to_item.length() < 0.01:
		to_item = Vector3.FORWARD
	p.teleport(game.item.global_position - to_item.normalized() * (1.0 + game.item.half.z) + Vector3(0, 0.05 - game.item.global_position.y, 0), atan2(-to_item.x, -to_item.z))
	for i in 5:
		await get_tree().physics_frame
	game.input.press("interact")
	for i in 30:
		await get_tree().physics_frame


## Koliyle merdiveni düz çıkmak hasar vermemeli (görünmeyen rampaya/korkuluğa çarpma yok).
func _test_stairs_no_phantom_damage() -> void:
	section("Merdivende görünmez çarpma yok")
	var game := Game.new()
	game.setup(1)
	add_child(game)
	for i in 30:
		await get_tree().physics_frame
	await _grab_item(game)
	var p := game.player
	var wps: Array = game.info.waypoints
	var start: Vector3 = wps[1] + Vector3(0, 0.05, -0.7)
	p.teleport(start, PI)
	p.carry.hold_basis = Basis()
	game.item.global_transform = p.carry.target_transform()
	game.item.grace = 0.5
	for i in 40:
		await get_tree().physics_frame
	var dur0 := game.item.durability
	var landing_y := float(game.info.floor_height) * 0.5
	for i in 300:
		# Ara sahanlığa varınca dur (arka duvara yürümesin)
		if p.global_position.y >= landing_y - 0.05:
			break
		game.input.move = Vector2(0, 0.7)
		await get_tree().physics_frame
	game.input.move = Vector2.ZERO
	for i in 20:
		await get_tree().physics_frame
	check(p.global_position.y > start.y + 0.8, "koliyle merdiven çıkılabiliyor (y=%.2f)" % p.global_position.y)
	check(game.item.durability >= dur0 - 1.0, "düz çıkışta hasar yok (%.1f -> %.1f)" % [dur0, game.item.durability])
	game.queue_free()
	await get_tree().process_frame


func _test_free_look() -> void:
	section("Serbest kamera")
	var game := Game.new()
	game.setup(1)
	add_child(game)
	for i in 30:
		await get_tree().physics_frame
	var start := game.player.global_position
	var cam_before := game.cam.focus_point()
	game.input.look_mode = true
	for i in 40:
		game.input.move = Vector2(0, 1)
		await get_tree().physics_frame
	game.input.move = Vector2.ZERO
	check(game.cam.free_look, "serbest bakış açılıyor")
	check(game.player.global_position.distance_to(start) < 0.2, "serbest bakışta karakter yerinde duruyor")
	check(game.cam.focus_point().distance_to(cam_before) > 1.0, "serbest bakışta kamera geziyor")
	game.cam.orbit(Vector2(0, -400))
	check(game.cam.pitch > 0.0, "kamera yukarı da bakabiliyor")
	game.input.look_mode = false
	for i in 5:
		await get_tree().physics_frame
	check(not game.cam.free_look, "serbest bakış kapanıyor")
	# SIDE: kamera yan açıda kalır, birkaç saniye sonra arkaya dönmez
	game.cam.preset("side")
	for i in 300:
		await get_tree().physics_frame
	var off := absf(wrapf(game.cam.yaw - game.player.get_yaw(), -PI, PI))
	check(absf(off - PI * 0.5) < 0.2, "SIDE açısı kendiliğinden geri dönmüyor (%.2f)" % off)
	game.cam.preset("back")
	for i in 120:
		await get_tree().physics_frame
	off = absf(wrapf(game.cam.yaw - game.player.get_yaw(), -PI, PI))
	check(off < 0.2, "BACK ile kamera arkaya dönüyor")
	game.queue_free()
	await get_tree().process_frame


## Birinci şahıs: kamera gözde, kafa dönerken gövde/eller/eşya sabit; LOOK ile üçüncü şahsa dönülür.
func _test_first_person() -> void:
	section("Birinci şahıs")
	var game := Game.new()
	game.setup(1)
	add_child(game)
	for i in 20:
		await get_tree().physics_frame
	await _grab_item(game)
	check(game.player.is_holding(), "koli elde")
	game.input.press("cam_first")
	for i in 5:
		await get_tree().physics_frame
	check(game.cam.first_person, "1P ile birinci şahıs açılıyor")
	check(game.touch.buttons.fpv.toggled, "1P butonu açık görünüyor")
	var eye := game.player.visual.eye_position()
	check(game.cam.camera.global_position.distance_to(eye) < 0.05, "kamera gözde")
	check(not game.player.visual._head.visible, "birinci şahısta kafa görüşü kapatmıyor")
	var body_yaw := game.player.get_yaw()
	var item_xf := game.item.global_transform
	game.cam.orbit(Vector2(-260, 0))
	for i in 10:
		await get_tree().physics_frame
	check(game.cam.fp_yaw > 0.5, "kafa yana dönüyor")
	check(absf(game.player.get_yaw() - body_yaw) < 0.001, "kafa dönerken gövde dönmüyor")
	check(game.item.global_transform.origin.distance_to(item_xf.origin) < 0.02, "kafa dönerken eşya yerinde")
	var fwd := -game.cam.camera.global_basis.z
	var body_fwd := Vector3(-sin(body_yaw), 0, -cos(body_yaw))
	check(fwd.dot(body_fwd) < 0.85, "bakış gövdeden farklı yöne")
	game.cam.orbit(Vector2(0, -2000))
	check(absf(game.cam.fp_pitch - deg_to_rad(Config.FP_PITCH_UP_DEG)) < 0.01, "yukarı bakış sınırlı")
	game.cam.orbit(Vector2(5000, 0))
	check(absf(game.cam.fp_yaw + deg_to_rad(Config.FP_YAW_LIMIT_DEG)) < 0.01, "yana bakış sınırlı (boyun)")
	game.cam.preset("back")
	check(game.cam.first_person and absf(game.cam.fp_yaw) < 0.001, "BACK bakışı ortalar")
	game.input.look_mode = true
	for i in 3:
		await get_tree().physics_frame
	check(not game.cam.first_person and game.cam.free_look, "LOOK birinci şahısı kapatır")
	check(game.player.visual._head.visible, "üçüncü şahısta kafa yine görünür")
	game.input.look_mode = false
	for i in 3:
		await get_tree().physics_frame
	game.queue_free()
	await get_tree().process_frame


## Evin içinde eşya taşırken hız yarıya iner, eşya çevirme daha hassas olur.
func _test_home_speed() -> void:
	section("Ev içi taşıma hızı")
	var game := Game.new()
	game.setup(3)
	add_child(game)
	for i in 20:
		await get_tree().physics_frame
	await _grab_item(game)
	check(game.player.is_holding(), "TV alınıyor")
	var speeds := []
	for spot: Vector3 in [Vector3(9.0, 0.05, -2.6), Vector3(game.info.goal_center) + Vector3(0.8, 0.05, 0)]:
		game.player.teleport(spot, PI * 0.5)
		game.player.carry.hold_basis = Basis()
		game.item.global_transform = game.player.carry.target_transform()
		game.item.grace = 1.0
		for i in 5:
			await get_tree().physics_frame
		var vmax := 0.0
		for i in 45:
			game.input.move = Vector2(0, 1)
			await get_tree().physics_frame
			vmax = maxf(vmax, game.player._speed_now)
		game.input.move = Vector2.ZERO
		speeds.append(vmax)
		speeds.append(game.player.in_home)
	check(not speeds[1] and speeds[3], "sokakta evin dışı, odada evin içi algılanıyor")
	check(float(speeds[2]) < float(speeds[0]) * 0.6 and float(speeds[2]) > 0.1, "evde taşıma hızı yarıya iniyor (%.2f → %.2f)" % [speeds[0], speeds[2]])
	check(absf(game.player.carry.fine_mult - Config.HOME_ROTATE_MULT) < 0.001, "evde eşya çevirme daha hassas")
	game.queue_free()
	await get_tree().process_frame


## 6. bölümden sonra: eşya evin içindeki yerine doğru konunca bölüm kazanılır, yuva hasar vermez.
func _test_spot_placement() -> void:
	section("Evin içinde yerine koyma")
	for id in range(6, LevelDB.count() + 1):
		var game := Game.new()
		game.setup(id)
		add_child(game)
		for i in 20:
			await get_tree().physics_frame
		var info: Dictionary = game.info
		var sb: Basis = info.spot_basis
		var yaw := atan2(-(-sb.z).x, -(-sb.z).z)
		# Ters yönde: kazanılmamalı
		game.item.place_on_ground(info.goal_center, yaw + PI)
		for i in 60:
			await get_tree().physics_frame
		check(game.phase != Game.Phase.WON, "bölüm %d: ters konunca kazanılmaz" % id)
		game.item.place_on_ground(info.goal_center, yaw)
		for i in 90:
			await get_tree().physics_frame
		check(game.goal.contains(game.item.global_position), "bölüm %d: eşya yuvada kalıyor" % id)
		check(game.item.durability > 99.0, "bölüm %d: yuva eşyaya hasar vermiyor (%.1f)" % [id, game.item.durability])
		check(game.phase == Game.Phase.WON, "bölüm %d: doğru konunca kazanılır" % id)
		game.queue_free()
		await get_tree().process_frame


func _test_crush() -> void:
	section("Yorulma ve ezilme")
	# Ağır eşya (buzdolabı): güç bitince taşıyıcı ezilir
	var game := Game.new()
	game.setup(16)
	add_child(game)
	for i in 30:
		await get_tree().physics_frame
	await _grab_item(game)
	check(game.player.is_holding(), "buzdolabı sırta alınıyor")
	game.player.stamina = 50.0
	check(game.player.get_fatigue() > 0.4, "yorgunluk dayanıklılıkla artıyor")
	game.player.stamina = 0.01
	for i in 20:
		await get_tree().physics_frame
	check(game.phase == Game.Phase.FAILED, "güç bitince bölüm başarısız")
	check(game.player.visual.crushed, "taşıyıcı buzdolabının altında eziliyor")
	game.queue_free()
	await get_tree().process_frame
	# Hafif eşya (koli): ezilme yok, sadece düşer
	var g2 := Game.new()
	g2.setup(1)
	add_child(g2)
	for i in 30:
		await get_tree().physics_frame
	await _grab_item(g2)
	g2.player.stamina = 0.0
	var old_w = g2.player.level_item.data["weight"]
	g2.player.level_item.data["weight"] = 30.0   # yorulsun ama ezilmesin (< CRUSH_WEIGHT)
	for i in 20:
		await get_tree().physics_frame
	g2.player.level_item.data["weight"] = old_w   # paylaşılan eşya verisini geri yükle
	check(g2.phase == Game.Phase.PLAYING, "hafif eşyada bölüm sürüyor")
	check(not g2.player.visual.crushed and not g2.player.is_holding(), "hafif eşya sadece düşüyor")
	g2.queue_free()
	await get_tree().process_frame


func _test_audio() -> void:
	section("Sesler")
	var t0 := Time.get_ticks_msec()
	while not AudioManager._music_ready and Time.get_ticks_msec() - t0 < 30000:
		await get_tree().process_frame
	for nm: String in ["step0", "thud", "bump", "crack", "shatter", "scrape", "success", "music"]:
		check(AudioManager._streams.has(nm), "ses üretildi: " + nm)
	var m = AudioManager._streams.get("music")
	check(m is AudioStream and m.get_length() > 10.0, "müzik döngüsü 10 saniyeden uzun")


func _test_gameplay_smoke() -> void:
	section("Oynanış (duman testi)")
	var game := Game.new()
	game.setup(1)
	add_child(game)
	for i in 40:
		await get_tree().physics_frame
	var p := game.player
	check(p.is_on_floor(), "oyuncu zemine iniyor")
	check(game.item.is_settled(), "eşya zemine oturuyor")
	check(game.item.durability >= 99.0, "eşya başlangıçta hasarsız")
	check(game.npc != null and is_instance_valid(game.npc), "ev sahibi oluşturuldu")
	# Efektler: sert temas iz + parça üretmeli, parçalanma parça üretmeli
	var marks_before := game.fx.get_child_count()
	game.fx.on_contact(Vector3(0, 1, 0.01), Vector3(0, 0, 1), Vector3(1, 0, -2), 12.0, true, [Color.RED])
	await get_tree().process_frame
	check(game.fx.get_child_count() > marks_before + 3, "sert çarpma iz, toz ve parça üretiyor")
	game.fx.shatter(game.item.get_debris_parts(), game.item.global_position, Vector3.ZERO)
	await get_tree().physics_frame
	check(game.fx.get_child_count() > marks_before + 8, "parçalanma efekti çalışıyor")
	# Eşyanın yanına git ve al
	var to_item := game.item.global_position - p.global_position
	to_item.y = 0
	p.teleport(game.item.global_position - to_item.normalized() * 1.2 + Vector3(0, 0.05 - game.item.global_position.y, 0), atan2(-to_item.x, -to_item.z))
	for i in 5:
		await get_tree().physics_frame
	game.input.press("interact")
	for i in 30:
		await get_tree().physics_frame
	check(p.is_holding(), "eşya alınabiliyor")
	var t := game.player.carry.target_transform()
	check(game.item.global_position.distance_to(t.origin) < 0.3, "eşya ele geliyor")
	# Binaya doğru yürü
	var start := p.global_position
	game.cam.yaw = PI
	game.input.move = Vector2(0, 1)
	for i in 60:
		game.input.move = Vector2(0, 1)
		await get_tree().physics_frame
	game.input.move = Vector2.ZERO
	check(p.global_position.distance_to(start) > 1.0, "eşyayla yürünebiliyor")
	check(game.item.global_position.distance_to(game.player.carry.target_transform().origin) < 0.6, "eşya oyuncuyu takip ediyor")
	# Döndürme
	game.input.rotate_px = Vector2(150, 0)
	for i in 10:
		await get_tree().physics_frame
	check(game.player.carry.rotated_total_deg > 10.0, "döndürme çalışıyor")
	# Bırak
	game.input.press("interact")
	for i in 90:
		await get_tree().physics_frame
	check(not p.is_holding(), "eşya bırakılabiliyor")
	check(game.item.is_settled(), "bırakılan eşya yere oturuyor")
	check(game.item.durability > 90.0, "yavaşça bırakma hasar vermez (%.1f)" % game.item.durability)
	# Kurtarma
	game.rescue()
	for i in 10:
		await get_tree().physics_frame
	check(p.is_holding() or game.item.is_settled(), "kurtarma sonrası durum tutarlı")
	game.queue_free()
	await get_tree().process_frame
