extends Node
## Görünmeyen engel denetimi (geliştirici aracı). Gerçek görüntü motoru gerekir (headless değil):
##   xvfb-run godot --rendering-driver opengl3 --fixed-fps 60 --path . res://tests/collision_audit.tscn
## Her bölümde tüm çarpışma şekillerini görünür modellerle karşılaştırır: yüzeylerinde görünür bir
## yüzey olmayan çarpışma "görünmeyen engel"dir. Ayrıca oyuncuyu ve eşyayı yol boyunca 25 cm adımlarla
## ilerletip çarptıkları görünmez şekilleri raporlar. Bulgu sayısıyla çıkar (0 = temiz).
## Bilerek görünmez olanlar: merdiven rampası (yalnızca yürüyüş için, ayrı katman) ve harita sınırı.

const VIS := 1 << 20
var total := 0


func _ready() -> void:
	GameState.persist = false
	# Doğrulama: bilerek konan görünmez kutu bulunmalı
	var self_test := await _scan(1, true)
	if self_test < 1:
		printerr("DENETİM ARACI ÇALIŞMIYOR: bilerek konan görünmez kutu bulunamadı")
		get_tree().quit(99)
		return
	for id in range(1, LevelDB.count() + 1):
		total += await _scan(id, false)
	print("==== GÖRÜNMEYEN ENGEL: %d ====" % total)
	get_tree().quit(total)


func _scan(id: int, inject: bool) -> int:
	var game := Game.new()
	game.setup(id)
	add_child(game)
	for i in 10:
		await get_tree().physics_frame
	var vis := StaticBody3D.new()
	vis.collision_layer = VIS
	vis.collision_mask = 0
	game.add_child(vis)
	for mi in game.find_children("*", "MeshInstance3D", true, false):
		var m := mi as MeshInstance3D
		if m.mesh == null or game.player.is_ancestor_of(m) or game.item.is_ancestor_of(m):
			continue
		var sh := m.mesh.create_trimesh_shape()
		if sh == null:
			continue
		var cs := CollisionShape3D.new()
		cs.shape = sh
		vis.add_child(cs)
		cs.global_transform = m.global_transform
	var wb := game.find_child("WorldBody", true, false) as StaticBody3D
	if inject:
		var fake := CollisionShape3D.new()
		var fb := BoxShape3D.new()
		fb.size = Vector3(0.4, 0.4, 0.4)
		fake.shape = fb
		wb.add_child(fake)
		fake.global_position = Vector3(game.info.waypoints[0]) + Vector3(0, 0.2, 0)
	await get_tree().physics_frame
	await get_tree().physics_frame
	var space := game.get_world_3d().direct_space_state
	var bad := {}
	# 1) Tüm şekiller
	for body_name in ["WorldBody", "StairSteps"]:
		var body := game.find_child(body_name, true, false) as StaticBody3D
		if body == null:
			continue
		for c in body.get_children():
			var cs2 := c as CollisionShape3D
			if cs2 == null or cs2.shape == null or _allowed(cs2):
				continue
			if not _surface_visible(space, cs2):
				bad[_desc(body_name, cs2)] = true
	# 2) Yol boyunca oyuncu ve eşya
	var p := game.player
	p.carry.grab(game.item)
	var it := game.item
	p.carry.hold_basis = Basis(Vector3.UP, PI * 0.5) if it.half.x > it.half.z + 0.01 else Basis()
	var wps: Array = game.info.waypoints
	for k in range(wps.size() - 1):
		var a: Vector3 = wps[k]
		var b: Vector3 = wps[k + 1]
		var seg := b - a
		seg.y = 0
		if seg.length() < 0.05:
			continue
		var yaw := atan2(-seg.x, -seg.z)
		var steps := int(seg.length() / 0.25) + 1
		for s in steps + 1:
			var pos := a.lerp(b, float(s) / steps)
			var hit := space.intersect_ray(PhysicsRayQueryParameters3D.create(pos + Vector3(0, 1.6, 0), pos + Vector3(0, -1.6, 0), Config.LAYER_WORLD | Config.LAYER_RAMP))
			if hit.is_empty():
				continue
			p.global_position = Vector3(pos.x, float(hit.position.y) + 0.02, pos.z)
			p.global_basis = Basis(Vector3.UP, yaw)
			p.carry.slope_comp = p.carry._ground_lift()
			var bs := BoxShape3D.new()
			bs.size = it.half * 2.0
			_touch(space, bs, p.carry.target_transform(), it.collision_mask, [it.get_rid(), p.get_rid()], "eşya", bad)
			var cap := CapsuleShape3D.new()
			cap.radius = Config.PLAYER_RADIUS
			cap.height = 1.7
			_touch(space, cap, Transform3D(Basis(), p.global_position + Vector3(0, 0.9, 0)), Config.LAYER_WORLD | Config.LAYER_OBSTACLE, [it.get_rid(), p.get_rid()], "oyuncu", bad)
	if not inject:
		print("bölüm %d: %d" % [id, bad.size()])
		for kk in bad.keys():
			printerr("   GÖRÜNMEZ: ", kk)
	game.queue_free()
	await get_tree().process_frame
	return bad.size()


## Bilerek görünmez: harita sınırı (oyun alanının kenarı, çitle gösterilir).
func _allowed(cs: CollisionShape3D) -> bool:
	var p := cs.global_position
	return absf(p.x) > 38.0 or p.z < -38.0 or p.z > 28.0


func _touch(space: PhysicsDirectSpaceState3D, shape: Shape3D, xf: Transform3D, mask: int, ex: Array, tag: String, bad: Dictionary) -> void:
	var qp := PhysicsShapeQueryParameters3D.new()
	qp.shape = shape
	qp.transform = xf
	qp.collision_mask = mask
	qp.exclude = ex
	for r in space.intersect_shape(qp, 8):
		var col := r.collider as CollisionObject3D
		var cs := col.shape_owner_get_owner(col.shape_find_owner(int(r.shape))) as CollisionShape3D
		if cs != null and not _allowed(cs) and not _surface_visible(space, cs):
			bad["%s çarpıyor: %s" % [tag, _desc(col.name, cs)]] = true


## Şeklin üst ve dört yan yüzünde (her biri 3×3 noktada) görünür yüzey var mı?
func _surface_visible(space: PhysicsDirectSpaceState3D, cs: CollisionShape3D) -> bool:
	var he := Vector3.ONE * 0.1
	if cs.shape is BoxShape3D:
		he = (cs.shape as BoxShape3D).size * 0.5
	elif cs.shape is CylinderShape3D:
		var c := cs.shape as CylinderShape3D
		he = Vector3(c.radius, c.height * 0.5, c.radius)
	else:
		return true
	var xf := cs.global_transform
	for n: Vector3 in [Vector3.UP, Vector3.RIGHT, Vector3.LEFT, Vector3.FORWARD, Vector3.BACK]:
		var t1 := Vector3(n.y, n.z, n.x).abs()     # yüzey üzerindeki iki eksen
		var t2 := n.cross(t1).abs()
		for i: float in [-0.6, 0.0, 0.6]:
			for j: float in [-0.6, 0.0, 0.6]:
				var face := xf * (n * he + t1 * he * i + t2 * he * j)
				var wn := (xf.basis * n).normalized()
				var q := PhysicsRayQueryParameters3D.create(face + wn * 0.06, face - wn * 0.06, VIS)
				q.hit_from_inside = true
				q.hit_back_faces = true
				if not space.intersect_ray(q).is_empty():
					return true
	return false


func _desc(body_name: String, cs: CollisionShape3D) -> String:
	var sz := ""
	if cs.shape is BoxShape3D:
		sz = "kutu %s" % str((cs.shape as BoxShape3D).size.snapped(Vector3.ONE * 0.01))
	elif cs.shape is CylinderShape3D:
		sz = "silindir r%.2f h%.2f" % [(cs.shape as CylinderShape3D).radius, (cs.shape as CylinderShape3D).height]
	return "%s %s @ %s" % [body_name, sz, str(cs.global_position.snapped(Vector3.ONE * 0.01))]
