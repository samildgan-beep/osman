class_name LevelBuilder
extends RefCounted
## Bölüm verisinden 3D dünyayı kurar: sokak, kamyon, U dönüşlü merdiven boşluğu,
## sahanlıklar, korkuluklar, tavanlar, daire koridoru, hedef oda ve engeller.
##
## Koordinatlar: +Y yukarı, sokak z < 0 tarafında, bina girişi z = 0'da.
## Merdiven boşluğu: sağ şerit (x > 0) A kolu +Z yönünde çıkar, ara sahanlıkta
## U dönüşü yapılır, sol şerit (x < 0) B kolu -Z yönünde kat sahanlığına çıkar.

const WT := 0.2        # duvar kalınlığı
const SLAB := 0.2      # döşeme kalınlığı
const RAIL_H := 1.0    # korkuluk yüksekliği

const C_ASPHALT := Color("4a4d52")
const C_ROAD_LINE := Color("e8e2c8")
const C_SIDEWALK := Color("bdb6aa")
const C_CURB := Color("8f8a82")
const C_GRASS := Color("6fa35a")
const C_FACADE := Color("dcc9a6")
const C_FACADE_2 := Color("c98d64")
const C_TRIM := Color("8a6a4e")
const C_WALL := Color("efe6d6")
const C_WALL_2 := Color("e3d6bf")
const C_STEP := Color("cfc6b8")
const C_NOSING := Color("9c9285")
const C_LANDING := Color("bcb2a2")
const C_UNDERSIDE := Color("e6dfd2")
const C_CEILING := Color("f4f1ea")
const C_RAIL := Color("3b3e44")
const C_HANDRAIL := Color("7a4f2e")
const C_WOOD_FLOOR := Color("b98a5a")
const C_APT_WALL := Color("f3eee4")
const C_DOOR := Color("8b5a3c")
const C_DOOR_FRAME := Color("5e3d29")
const C_TRUCK := Color("f2f2f2")
const C_TRUCK_2 := Color("2f6db5")
const C_TIRE := Color("1e1f22")
const C_TRUNK := Color("6b4a2f")
const C_LEAVES := Color("4f8f45")
const C_POT := Color("b5643c")

var L: Dictionary
var root: Node3D
var body: StaticBody3D
var batch := MeshBatcher.new()
var glass := MeshBatcher.new()
var glow := MeshBatcher.new()
var ceil_batch := MeshBatcher.new()   # tavanlar: kesit görünümünde yarı saydam
var props := MeshBatcher.new()        # engeller: kesitten etkilenmez, hep görünür
var info := {}
var anchors := {}

# Türetilmiş ölçüler
var F := 1
var sw := 1.3
var gap := 0.3
var H := 2.8
var Hh := 1.4
var n := 8
var r := 0.175
var t := 0.29
var Lf := 2.32
var LD := 1.7
var z0 := 2.0
var zb := 6.0
var X_out := 1.45
var xA := 0.8
var xB := -0.8
var C := 2.5
var slabs := false
var eff_ceil := 2.5
var top_y := 5.6
var apt := {}


func build(level: Dictionary, parent: Node3D) -> Dictionary:
	L = level
	root = Node3D.new()
	root.name = "Level"
	parent.add_child(root)
	body = StaticBody3D.new()
	body.name = "WorldBody"
	body.collision_layer = Config.LAYER_WORLD
	body.collision_mask = 0
	root.add_child(body)
	info = {"obstacles": [], "lights": [], "waypoints": [], "labels": []}

	_derive()
	var mat := _building_material()
	# Her bölge ayrı ağ: mobil işleyicide nesne başına ışık sınırı (8) aşılmasın.
	_build_street()
	batch.build(root, mat, "Street")
	_build_stairwell()
	batch.build(root, mat, "Stairwell")
	_build_apartment()
	_place_obstacles()
	batch.build(root, mat, "Apartment")
	_build_block()
	batch.build(root, mat, "Block")
	_build_waypoints()
	glass.build(root, _glass_material(), "Glass", false)
	glow.build(root, _glow_material(), "Glow", false)
	ceil_batch.build(root, _ceiling_material(), "Ceiling", false)
	props.build(root, _props_material(), "Props")
	info.anchors = anchors
	info.floor_height = H
	info.top_floor_y = F * H
	info.kill_y = -6.0
	return info


func _derive() -> void:
	F = int(L.floors)
	sw = float(L.stair_width)
	gap = float(L.gap)
	n = int(L.steps)
	r = float(L.rise)
	t = float(L.tread)
	H = n * r * 2.0
	Hh = H * 0.5
	Lf = n * t
	LD = float(L.landing)
	z0 = maxf(LD, 2.0)
	zb = z0 + Lf + LD
	X_out = gap * 0.5 + sw
	xA = gap * 0.5 + sw * 0.5
	xB = -xA
	C = float(L.ceiling)
	slabs = C < H - 0.4
	eff_ceil = C if slabs else H - 0.3
	top_y = (F + 1) * H


# ================================================================ yardımcılar

func solid(center: Vector3, size: Vector3, color: Color, collide: bool = true) -> void:
	batch.add_box(center, size, color)
	if collide:
		_shape_box(Transform3D(Basis(), center), size)


func solid_xf(xf: Transform3D, size: Vector3, color: Color, collide: bool = true) -> void:
	batch.add_box_xform(xf, size, color)
	if collide:
		_shape_box(xf, size)


func box_mm(mn: Vector3, mx: Vector3, color: Color, collide: bool = true) -> void:
	var a := Vector3(minf(mn.x, mx.x), minf(mn.y, mx.y), minf(mn.z, mx.z))
	var b := Vector3(maxf(mn.x, mx.x), maxf(mn.y, mx.y), maxf(mn.z, mx.z))
	var size := b - a
	if size.x < 0.001 or size.y < 0.001 or size.z < 0.001:
		return
	solid((a + b) * 0.5, size, color, collide)


## Tavan levhası: çarpışmalı, görseli tavan ağında.
func ceiling_mm(mn: Vector3, mx: Vector3) -> void:
	var a := Vector3(minf(mn.x, mx.x), minf(mn.y, mx.y), minf(mn.z, mx.z))
	var b := Vector3(maxf(mn.x, mx.x), maxf(mn.y, mx.y), maxf(mn.z, mx.z))
	var size := b - a
	if size.x < 0.001 or size.y < 0.001 or size.z < 0.001:
		return
	ceil_batch.add_box((a + b) * 0.5, size, C_CEILING)
	_shape_box(Transform3D(Basis(), (a + b) * 0.5), size)


## Engel parçası: çarpışmalı, görseli hep görünen ağda.
func prop_box(center: Vector3, size: Vector3, color: Color, collide: bool = true) -> void:
	props.add_box(center, size, color)
	if collide:
		_shape_box(Transform3D(Basis(), center), size)


func collider_mm(mn: Vector3, mx: Vector3) -> void:
	var a := Vector3(minf(mn.x, mx.x), minf(mn.y, mx.y), minf(mn.z, mx.z))
	var b := Vector3(maxf(mn.x, mx.x), maxf(mn.y, mx.y), maxf(mn.z, mx.z))
	_shape_box(Transform3D(Basis(), (a + b) * 0.5), b - a)


func _shape_box(xf: Transform3D, size: Vector3) -> void:
	if size.x < 0.001 or size.y < 0.001 or size.z < 0.001:
		return
	var cs := CollisionShape3D.new()
	var bs := BoxShape3D.new()
	bs.size = size
	cs.shape = bs
	cs.transform = xf
	body.add_child(cs)


func _shape_cyl(center: Vector3, radius: float, height: float) -> void:
	var cs := CollisionShape3D.new()
	var shape := CylinderShape3D.new()
	shape.radius = radius
	shape.height = height
	cs.shape = shape
	cs.position = center
	body.add_child(cs)


## Duvar (eksen hizalı kutu), isteğe bağlı kapı/boşluk ile.
## hole: {"c": boşluk merkezi (duvar boyunca), "w": genişlik, "y0": alt, "y1": üst, "frame": bool}
func wall(p_mn: Vector3, p_mx: Vector3, color: Color, hole: Dictionary = {}) -> void:
	var mn := Vector3(minf(p_mn.x, p_mx.x), minf(p_mn.y, p_mx.y), minf(p_mn.z, p_mx.z))
	var mx := Vector3(maxf(p_mn.x, p_mx.x), maxf(p_mn.y, p_mx.y), maxf(p_mn.z, p_mx.z))
	if hole.is_empty():
		box_mm(mn, mx, color)
		return
	var along_z := (mx.z - mn.z) >= (mx.x - mn.x)
	var a0 := mn.z if along_z else mn.x
	var a1 := mx.z if along_z else mx.x
	var hc := float(hole.c)
	var hw := float(hole.w)
	var h0 := clampf(hc - hw * 0.5, a0, a1)
	var h1 := clampf(hc + hw * 0.5, a0, a1)
	var hy0 := maxf(float(hole.get("y0", mn.y)), mn.y)
	var hy1 := minf(float(hole.get("y1", mx.y)), mx.y)
	box_mm(mn, _span(mx, h0, along_z), color)
	box_mm(_span(mn, h1, along_z), mx, color)
	box_mm(_span(mn, h0, along_z), _span(Vector3(mx.x, hy0, mx.z), h1, along_z), color)
	box_mm(_span(Vector3(mn.x, hy1, mn.z), h0, along_z), _span(mx, h1, along_z), color)
	if bool(hole.get("frame", true)) and hy1 < mx.y - 0.01:
		_door_frame(mn, mx, along_z, h0, h1, hy0, hy1)


func _span(v: Vector3, value: float, along_z: bool) -> Vector3:
	if along_z:
		return Vector3(v.x, v.y, value)
	return Vector3(value, v.y, v.z)


func _door_frame(mn: Vector3, mx: Vector3, along_z: bool, h0: float, h1: float, y0: float, y1: float) -> void:
	# Kasa: duvar kalınlığından biraz taşan ince çıtalar (sadece görsel).
	var fw := 0.07
	var pad := 0.03
	if along_z:
		var x0 := mn.x - pad
		var x1 := mx.x + pad
		box_mm(Vector3(x0, y0, h0 - fw), Vector3(x1, y1 + fw, h0), C_DOOR_FRAME, false)
		box_mm(Vector3(x0, y0, h1), Vector3(x1, y1 + fw, h1 + fw), C_DOOR_FRAME, false)
		box_mm(Vector3(x0, y1, h0 - fw), Vector3(x1, y1 + fw, h1 + fw), C_DOOR_FRAME, false)
	else:
		var z0_ := mn.z - pad
		var z1_ := mx.z + pad
		box_mm(Vector3(h0 - fw, y0, z0_), Vector3(h0, y1 + fw, z1_), C_DOOR_FRAME, false)
		box_mm(Vector3(h1, y0, z0_), Vector3(h1 + fw, y1 + fw, z1_), C_DOOR_FRAME, false)
		box_mm(Vector3(h0 - fw, y1, z0_), Vector3(h1 + fw, y1 + fw, z1_), C_DOOR_FRAME, false)


func _label(text: String, pos: Vector3, yaw: float, size: int = 48, color: Color = Color(0.25, 0.2, 0.15), hide_in_cut: bool = true) -> void:
	var lb := Label3D.new()
	lb.text = text
	lb.font_size = size
	lb.pixel_size = 0.004
	lb.modulate = color
	lb.outline_size = 0
	lb.position = pos
	lb.rotation = Vector3(0, yaw, 0)
	lb.double_sided = false
	root.add_child(lb)
	if hide_in_cut:
		info.labels.append(lb)


func _add_light(pos: Vector3, energy: float = 1.2, light_range: float = 6.0, color: Color = Color(1.0, 0.93, 0.8)) -> void:
	var l := OmniLight3D.new()
	l.position = pos
	l.light_energy = energy
	l.omni_range = light_range
	l.light_color = color
	l.shadow_enabled = false
	root.add_child(l)
	info.lights.append(l)


# ================================================================ sokak

func _build_street() -> void:
	# Zemin (çim + kaldırım + yol)
	box_mm(Vector3(-40, -0.5, -40), Vector3(40, -0.09, 30), C_GRASS)
	box_mm(Vector3(-14, -0.4, -4.0), Vector3(14, 0.0, -WT), C_SIDEWALK)
	box_mm(Vector3(-14, -0.4, -13.5), Vector3(14, -0.06, -4.0), C_ASPHALT)
	box_mm(Vector3(-14, -0.4, -4.15), Vector3(14, 0.0, -4.0), C_CURB)
	for i in range(-6, 7):
		batch.add_box(Vector3(i * 2.2, -0.055, -9.0), Vector3(1.1, 0.01, 0.12), C_ROAD_LINE)
	# Kaldırım rampası (yoldan kaldırıma yumuşak geçiş, takılmasın)
	var ramp_len := 0.6
	var a := atan2(0.06, ramp_len)
	var xf := Transform3D(Basis(Vector3.RIGHT, -a), Vector3(0, -0.13, -4.15 - ramp_len * 0.5))
	_shape_box(xf, Vector3(28, 0.2, ramp_len + 0.05))

	# Görünmez sınırlar
	collider_mm(Vector3(-14.5, -1, -14), Vector3(-14, 6, 0))
	collider_mm(Vector3(14, -1, -14), Vector3(14.5, 6, 0))
	collider_mm(Vector3(-14.5, -1, -14.5), Vector3(14.5, 6, -14))
	# Çit/çalı görseli
	for i in range(-13, 14, 2):
		batch.add_box(Vector3(i, 0.35, -13.8), Vector3(1.8, 0.7, 0.4), C_LEAVES.darkened(0.15))

	# Kamyon (taşınma kamyonu) — oyuncunun ve kameranın arkasında kalmasın diye solda
	var tz := -8.6
	var tx := -4.8
	box_mm(Vector3(tx - 5.6, 0.55, tz - 1.2), Vector3(tx - 1.2, 3.1, tz + 1.2), C_TRUCK)        # kasa
	box_mm(Vector3(tx - 1.2, 0.55, tz - 1.15), Vector3(tx + 0.6, 2.35, tz + 1.15), C_TRUCK_2)   # kabin
	batch.add_box(Vector3(tx + 0.62, 1.8, tz), Vector3(0.04, 0.7, 2.0), Color("9fc4e0"))        # ön cam
	batch.add_box(Vector3(tx - 3.4, 1.9, tz + 1.21), Vector3(3.6, 0.5, 0.02), C_TRUCK_2)       # şerit
	for wx in [-4.6, -2.0, -0.2]:
		for wz in [tz - 1.1, tz + 1.1]:
			batch.add_cylinder(Vector3(tx + wx, 0.45, wz), 0.45, 0.32, C_TIRE, Basis(Vector3.RIGHT, PI * 0.5))
	# Kamyon rampası (görsel)
	batch.add_box_xform(Transform3D(Basis(Vector3.FORWARD, -0.32), Vector3(tx - 6.4, 0.3, tz)), Vector3(1.7, 0.06, 1.4), Color("9aa0a6"))
	_label("TAŞI BAKALIM NAKLİYAT", Vector3(tx - 3.4, 2.5, tz + 1.22), 0.0, 64, Color("2f6db5"))

	# Ağaçlar ve sokak lambaları
	for p in [Vector3(-11, 0, -2.2), Vector3(11, 0, -2.2), Vector3(-7.5, 0, -2.2), Vector3(7.5, 0, -2.2)]:
		batch.add_cylinder(p + Vector3(0, 1.1, 0), 0.14, 2.2, C_TRUNK)
		batch.add_sphere(p + Vector3(0, 2.7, 0), 1.0, C_LEAVES)
		_shape_cyl(p + Vector3(0, 1.1, 0), 0.18, 2.2)
	for p in [Vector3(-4.0, 0, -3.6), Vector3(4.0, 0, -3.6)]:
		batch.add_cylinder(p + Vector3(0, 1.8, 0), 0.06, 3.6, C_RAIL)
		glow.add_sphere(p + Vector3(0, 3.65, 0), 0.18, Color("fff2c0"))
		_shape_cyl(p + Vector3(0, 1.8, 0), 0.08, 3.6)

	# Arka plan binaları
	var rng := RandomNumberGenerator.new()
	rng.seed = 7 + int(L.id)
	for i in 9:
		var bx := -24.0 + i * 6.0
		var bh := rng.randf_range(6.0, 16.0)
		batch.add_box(Vector3(bx, bh * 0.5, -22.0), Vector3(5.4, bh, 5.0), C_FACADE.lerp(C_FACADE_2, rng.randf()).darkened(0.1))

	anchors["street"] = {"pos": Vector3(3, 0, -6), "along": Vector3.RIGHT, "side": Vector3.BACK, "width": 6.0, "length": 6.0, "ceil": 50.0}
	info.player_spawn = Transform3D(Basis(Vector3.UP, PI), Vector3(-0.8, 0.05, -6.2))
	info.item_spawn = Vector3(2.2, 0.0, -4.7)


# ================================================================ merdiven boşluğu

func _build_stairwell() -> void:
	# Giriş holü zemini
	box_mm(Vector3(-X_out, -SLAB, -WT), Vector3(X_out, 0.0, z0), C_LANDING)
	# Zemin katta B kolunun altı ve ara sahanlığın altı dolu (merdiven altı)
	box_mm(Vector3(-X_out, -SLAB, z0), Vector3(gap * 0.5, Hh, z0 + Lf), C_WALL_2)
	box_mm(Vector3(-X_out, Hh, z0), Vector3(-gap * 0.5, H - 0.32, z0 + WT), C_WALL_2)
	box_mm(Vector3(-X_out, -SLAB, z0 + Lf), Vector3(X_out, Hh, zb), C_LANDING)

	for k in F:
		var yk := k * H
		# A kolu (sağ şerit, +Z)
		_flight(Vector3(xA, yk, z0), 1.0, gap * 0.5, k)
		# Ara sahanlık
		if k > 0:
			box_mm(Vector3(-X_out, yk + Hh - SLAB, z0 + Lf), Vector3(X_out, yk + Hh, zb), C_LANDING)
		collider_mm(Vector3(gap * 0.5, yk + Hh - SLAB, z0 + Lf - t * 0.5), Vector3(X_out, yk + Hh, z0 + Lf))
		# B kolu (sol şerit, -Z)
		_flight(Vector3(xB, yk + Hh, z0 + Lf), -1.0, -gap * 0.5, k)
		# Kat sahanlığı (k+1)
		var yl := (k + 1) * H
		box_mm(Vector3(-X_out, yl - SLAB, -WT), Vector3(X_out, yl, z0), C_LANDING)
		collider_mm(Vector3(-X_out, yl - SLAB, z0), Vector3(-gap * 0.5, yl, z0 + t * 0.5))
		# Boşluk korkulukları
		_rail_straight(Vector3(-gap * 0.5, yk + Hh, z0 + Lf + 0.03), Vector3(gap * 0.5, yk + Hh, z0 + Lf + 0.03))
		var rail_end := X_out if k + 1 == F else gap * 0.5
		_rail_straight(Vector3(-gap * 0.5, yl, z0 - 0.03), Vector3(rail_end, yl, z0 - 0.03))
		# Tavanlar
		if slabs or k == F - 1:
			ceiling_mm(Vector3(-X_out, yk + Hh + C, z0 + Lf), Vector3(X_out, yk + Hh + C + 0.1, zb))
		# Arka duvarda pencere (ara sahanlık)
		glass.add_box(Vector3(0, yk + Hh + 1.35, zb - 0.015), Vector3(1.2, 1.0, 0.02), Color("bfe3f5"))
		batch.add_box(Vector3(0, yk + Hh + 0.83, zb - 0.06), Vector3(1.35, 0.06, 0.12), C_TRIM)
		# Kat yazısı
		_label("%d. KAT" % (k + 1), Vector3(0, yl + 1.75, 0.02), 0.0, 56)
		_add_light(Vector3(0, yl + minf(C, H - 0.3) - 0.3, z0 * 0.5), 0.9, 5.5)

		# Ara katlardaki kapalı daire kapıları (dekor)
		if k + 1 < F:
			_deco_door(-1.0, yl, "D%d" % ((k + 1) * 2 + 1))
			_deco_door(1.0, yl, "D%d" % ((k + 1) * 2 + 2))

	# Kat sahanlığı tavanları
	for k in range(0, F + 1):
		if slabs or k == F:
			var yc := k * H + C
			ceiling_mm(Vector3(-X_out, yc, -WT), Vector3(X_out, yc + 0.1, z0))
	_add_light(Vector3(0, minf(C, H - 0.3) - 0.3, z0 * 0.5), 0.9, 5.5)

	# Dış duvarlar
	var apt_side := -1.0 if str(L.corridor.turn) != "right" else 1.0
	var dw := float(L.apt_door.x)
	var dh := float(L.apt_door.y)
	var zc := z0 * 0.5
	var door_hole := {"c": zc, "w": dw, "y0": F * H, "y1": F * H + dh}
	# Kapı boşluğu yalnızca en üst katta; duvar iki parçada kurulur (alt katlar + üst kat bandı)
	for side in [-1.0, 1.0]:
		var x0 := side * X_out
		var x1 := side * (X_out + WT)
		if side == apt_side:
			wall(Vector3(x0, -SLAB, -WT), Vector3(x1, F * H, zb + WT), C_WALL)
			wall(Vector3(x0, F * H, -WT), Vector3(x1, top_y, zb + WT), C_WALL, door_hole)
		else:
			wall(Vector3(x0, -SLAB, -WT), Vector3(x1, top_y, zb + WT), C_WALL)
	wall(Vector3(-X_out - WT, -SLAB, zb), Vector3(X_out + WT, top_y, zb + WT), C_WALL)
	var ew := float(L.entrance.x)
	var eh := float(L.entrance.y)
	wall(Vector3(-X_out - WT, -SLAB, -WT), Vector3(X_out + WT, top_y, 0.0), C_WALL, {"c": 0.0, "w": ew, "y0": 0.0, "y1": eh})
	# Çatı
	box_mm(Vector3(-X_out - WT, top_y - SLAB, -WT), Vector3(X_out + WT, top_y, zb + WT), C_CEILING)
	# Duvar süpürgelikleri (görsel)
	for k in range(0, F + 1):
		var y := k * H
		batch.add_box(Vector3(0, y + 0.05, 0.015), Vector3(X_out * 2.0, 0.1, 0.03), C_TRIM)

	# Merdiven boşluğu iç sınırları (kesit görünümü ve hedef hesapları için)
	info.stair_aabb = AABB(Vector3(-X_out, 0, 0), Vector3(X_out * 2.0, top_y, zb))
	info.apt_side = apt_side

	# Çapalar (engeller için)
	anchors["hall"] = {"pos": Vector3(0, 0, z0 * 0.5), "along": Vector3.RIGHT, "side": Vector3.BACK, "width": z0, "length": X_out * 2.0, "ceil": eff_ceil}
	for k in F:
		var yk := k * H
		anchors["flightA:%d" % k] = {"pos": Vector3(xA, yk + Hh * 0.5, z0 + Lf * 0.5), "along": Vector3.BACK, "side": Vector3.RIGHT, "width": sw, "length": Lf, "ceil": yk + Hh * 0.5 + eff_ceil, "start": Vector3(xA, yk, z0), "dir": 1.0}
		anchors["flightB:%d" % k] = {"pos": Vector3(xB, yk + Hh * 1.5, z0 + Lf * 0.5), "along": Vector3.FORWARD, "side": Vector3.LEFT, "width": sw, "length": Lf, "ceil": yk + Hh * 1.5 + eff_ceil, "start": Vector3(xB, yk + Hh, z0 + Lf), "dir": -1.0}
		anchors["mid:%d" % k] = {"pos": Vector3(0, yk + Hh, z0 + Lf + LD * 0.5), "along": Vector3.RIGHT, "side": Vector3.BACK, "width": LD, "length": X_out * 2.0, "ceil": yk + Hh + eff_ceil, "back_z": zb}
	for k in range(1, F + 1):
		anchors["landing:%d" % k] = {"pos": Vector3(0, k * H, z0 * 0.5), "along": Vector3.RIGHT, "side": Vector3.BACK, "width": z0, "length": X_out * 2.0, "ceil": k * H + eff_ceil, "front_z": 0.0}


## Tek merdiven kolu. start: ilk basamak hizasında şerit ortası (taban yüksekliği), dz: +1 / -1
func _flight(start: Vector3, dz: float, rail_x: float, k: int) -> void:
	var dir := Vector3(0, 0, dz)
	# Basamaklar (görsel)
	for i in n:
		var top := (i + 1) * r
		var hgt := r + 0.12
		var c := start + dir * (i * t + t * 0.5) + Vector3.UP * (top - hgt * 0.5)
		batch.add_box(c, Vector3(sw, hgt, t + 0.01), C_STEP)
		# Basamak burnu şeridi
		batch.add_box(start + dir * (i * t + 0.03) + Vector3.UP * (top - 0.01), Vector3(sw, 0.025, 0.05), C_NOSING)
	# Eğim hesapları
	var ell := sqrt(Lf * Lf + Hh * Hh)
	var a := atan2(Hh, Lf)
	var u := (dir * Lf + Vector3.UP * Hh) / ell
	var nrm := Vector3.UP * cos(a) - dir * sin(a)
	var bas := Basis(nrm.cross(u), nrm, u)
	# Alt yüz (görsel)
	var under_c := start + dir * (Lf * 0.5) + Vector3.UP * (Hh * 0.5) - nrm * 0.2
	batch.add_box_xform(Transform3D(bas, under_c), Vector3(sw, 0.16, ell), C_UNDERSIDE)
	# Rampa çarpışması: basamak burunları çizgisinin yarım basamak gerisinden geçer
	var thick := 0.3
	var mid := start + dir * ((Lf - t) * 0.5) + Vector3.UP * (Hh * 0.5)
	_shape_box(Transform3D(bas, mid - nrm * (thick * 0.5)), Vector3(sw, thick, ell))
	# İç korkuluk (boşluk tarafı)
	var rail_start := Vector3(rail_x, start.y, start.z)
	var rail_mid := rail_start + dir * (Lf * 0.5) + Vector3.UP * (Hh * 0.5)
	var side_off := Vector3(signf(-rail_x) * 0.03, 0, 0)
	_shape_box(Transform3D(bas, rail_mid + nrm * (RAIL_H * 0.5) + side_off), Vector3(0.06, RAIL_H, ell))
	batch.add_box_xform(Transform3D(bas, rail_mid + nrm * (RAIL_H - 0.02) + side_off), Vector3(0.07, 0.06, ell), C_HANDRAIL)
	batch.add_box_xform(Transform3D(bas, rail_mid + nrm * 0.12 + side_off), Vector3(0.04, 0.04, ell), C_RAIL)
	for i in n:
		var p := rail_start + dir * (i * t + t * 0.5) + Vector3.UP * ((i + 1) * r) + side_off
		batch.add_box(p + Vector3.UP * (RAIL_H * 0.45), Vector3(0.025, RAIL_H * 0.9, 0.025), C_RAIL)
	# Dış duvar tarafında tutamak (görsel)
	var wall_x := signf(start.x) * (X_out - 0.05)
	var wr_mid := Vector3(wall_x, start.y, start.z) + dir * (Lf * 0.5) + Vector3.UP * (Hh * 0.5 + 0.9)
	batch.add_box_xform(Transform3D(bas, wr_mid), Vector3(0.05, 0.05, ell), C_HANDRAIL)
	# Kol tavanı (alçak tavan veya en üst kat)
	if slabs or k == F - 1:
		var cc := start + dir * (Lf * 0.5) + Vector3.UP * (Hh * 0.5 + C) + nrm * 0.05
		ceil_batch.add_box_xform(Transform3D(bas, cc), Vector3(sw, 0.1, ell + 0.35), C_CEILING)
		_shape_box(Transform3D(bas, cc), Vector3(sw, 0.1, ell + 0.35))


## Düz korkuluk (sahanlık kenarı)
func _rail_straight(p0: Vector3, p1: Vector3) -> void:
	var length := p0.distance_to(p1)
	if length < 0.05:
		return
	var mid := (p0 + p1) * 0.5
	var along_x := absf(p1.x - p0.x) > absf(p1.z - p0.z)
	var size := Vector3(length, RAIL_H, 0.06) if along_x else Vector3(0.06, RAIL_H, length)
	_shape_box(Transform3D(Basis(), mid + Vector3.UP * (RAIL_H * 0.5)), size)
	var hr := Vector3(length, 0.06, 0.07) if along_x else Vector3(0.07, 0.06, length)
	batch.add_box(mid + Vector3.UP * (RAIL_H - 0.02), hr, C_HANDRAIL)
	var count := maxi(2, int(length / 0.12))
	for i in count + 1:
		var p := p0.lerp(p1, float(i) / count)
		batch.add_box(p + Vector3.UP * (RAIL_H * 0.45), Vector3(0.025, RAIL_H * 0.9, 0.025), C_RAIL)


func _deco_door(side: float, y: float, text: String) -> void:
	var x := side * (X_out - 0.02)
	var zc := z0 * 0.5
	batch.add_box(Vector3(x, y + 1.02, zc), Vector3(0.04, 2.04, 0.92), C_DOOR)
	batch.add_box(Vector3(x - side * 0.03, y + 1.0, zc + 0.33), Vector3(0.03, 0.04, 0.12), Color("d4af37"))
	batch.add_box(Vector3(x, y + 1.06, zc), Vector3(0.05, 2.12, 1.06), C_DOOR_FRAME)
	_label(text, Vector3(x - side * 0.035, y + 1.65, zc), -side * PI * 0.5, 40, Color("f2e6c8"))


# ================================================================ daire (koridor + oda)

func _build_apartment() -> void:
	var y := F * H
	var sx := float(info.apt_side)
	var turn := str(L.corridor.turn)
	var cl := float(L.corridor.length)
	var cw := minf(float(L.corridor.width), z0 - 0.1)
	var cc := float(L.corridor.ceiling)
	var tl := float(L.corridor.turn_length)
	var rw := float(L.room.width)
	var rd := float(L.room.depth)
	var rdw := minf(float(L.room.door.x), cw - 0.05)
	var rdh := minf(float(L.room.door.y), cc)
	var room_h := maxf(cc, 2.6)
	var zc := z0 * 0.5
	var xw := sx * (X_out + WT)   # merdiven duvarının dış yüzü
	var x_end := xw + sx * cl     # koridorun uç noktası

	# Koridor 1: merdivenden dışarı doğru (x ekseni)
	var c1 := _rect(minf(xw, x_end), maxf(xw, x_end), zc - cw * 0.5, zc + cw * 0.5)
	var near1 := "xp" if sx < 0 else "xn"
	var far1 := "xn" if sx < 0 else "xp"
	var walls1 := {"zn": {}, "zp": {}}
	walls1[near1] = null
	walls1[far1] = null
	_room_box(c1, y, cc, walls1, C_WOOD_FLOOR.darkened(0.05))
	# Eşik (merdiven duvarı kalınlığı)
	box_mm(Vector3(sx * X_out, y - SLAB, zc - float(L.apt_door.x) * 0.5), Vector3(xw, y, zc + float(L.apt_door.x) * 0.5), C_WOOD_FLOOR.darkened(0.15))
	anchors["corridor"] = {"pos": Vector3((xw + x_end) * 0.5, y, zc), "along": Vector3.RIGHT, "side": Vector3.BACK, "width": cw, "length": cl, "ceil": y + cc}
	# Hedef dairenin tabelası kesit görünümünde de görünür kalır (yol gösterir).
	_label("DAİRE %d" % (F * 2 + 1), Vector3(sx * (X_out - 0.02), y + float(L.apt_door.y) + 0.25, zc), -sx * PI * 0.5, 44, Color(0.25, 0.2, 0.15), false)
	_add_light(Vector3((xw + x_end) * 0.5, y + cc - 0.3, zc), 0.8, 5.0)
	# Duvar tablosu (dekor)
	batch.add_box(Vector3((xw + x_end) * 0.5, y + 1.5, zc + cw * 0.5 - 0.02), Vector3(0.7, 0.5, 0.03), Color("4a6f8a"))
	batch.add_box(Vector3((xw + x_end) * 0.5, y + 1.5, zc + cw * 0.5 - 0.01), Vector3(0.8, 0.6, 0.02), C_TRIM)

	var room: Dictionary
	var door_side: String
	if turn == "none":
		var rz0 := maxf(zc - rw * 0.5, 0.2)
		room = _rect(minf(x_end, x_end + sx * rd), maxf(x_end, x_end + sx * rd), rz0, rz0 + rw)
		door_side = near1
		var walls_r := {"xn": {}, "xp": {}, "zn": {}, "zp": {}}
		walls_r[door_side] = {"c": zc, "w": rdw, "y0": y, "y1": y + rdh}
		_room_box(room, y, room_h, walls_r, C_WOOD_FLOOR)
		anchors["corridor2"] = anchors["corridor"]
	else:
		# Koridor 2: +Z yönüne döner
		var c2x0 := x_end
		var c2x1 := x_end + sx * cw
		var c2 := _rect(minf(c2x0, c2x1), maxf(c2x0, c2x1), zc - cw * 0.5, zc + cw * 0.5 + tl)
		var near2 := near1
		var far2 := far1
		var walls2 := {"zn": {}, "zp": null}
		walls2[far2] = {}
		walls2[near2] = {"c": zc, "w": cw, "y0": y, "y1": y + cc, "frame": false}
		_room_box(c2, y, cc, walls2, C_WOOD_FLOOR.darkened(0.05))
		var c2_center := Vector3((c2x0 + c2x1) * 0.5, y, (c2.z0 + c2.z1) * 0.5)
		anchors["corridor2"] = {"pos": c2_center, "along": Vector3.BACK, "side": Vector3.RIGHT, "width": cw, "length": tl, "ceil": y + cc}
		_add_light(c2_center + Vector3(0, cc - 0.3, 0), 0.8, 5.0)
		# Oda: koridor 2'nin ucunda
		var xm := (c2x0 + c2x1) * 0.5
		var rx0 := xm - rw * 0.5
		var rx1 := xm + rw * 0.5
		# Oda merdiven boşluğuna taşmasın
		var limit := X_out + WT * 2.0
		if sx < 0 and rx1 > -limit:
			var d := rx1 + limit
			rx1 -= d
			rx0 -= d
		elif sx > 0 and rx0 < limit:
			var d2 := limit - rx0
			rx0 += d2
			rx1 += d2
		room = _rect(rx0, rx1, c2.z1, c2.z1 + rd)
		door_side = "zn"
		_room_box(room, y, room_h, {"xn": {}, "xp": {}, "zp": {}, "zn": {"c": xm, "w": rdw, "y0": y, "y1": y + rdh}}, C_WOOD_FLOOR)

	# Oda içi
	var rc := Vector3((room.x0 + room.x1) * 0.5, y, (room.z0 + room.z1) * 0.5)
	anchors["room"] = {"pos": rc, "along": Vector3.RIGHT, "side": Vector3.BACK, "width": room.z1 - room.z0, "length": room.x1 - room.x0, "ceil": y + room_h}
	_add_light(rc + Vector3(0, room_h - 0.4, 0), 1.3, 7.0)
	# Halı (görsel)
	batch.add_box(rc + Vector3(0, 0.006, 0), Vector3((room.x1 - room.x0) * 0.6, 0.012, (room.z1 - room.z0) * 0.6), Color("c95f4a"))
	# Pencere (uzak duvar)
	var far_wall_side := far1 if turn == "none" else "zp"
	match far_wall_side:
		"xn":
			glass.add_box(Vector3(room.x0 + 0.015, y + 1.5, rc.z), Vector3(0.02, 1.0, 1.4), Color("bfe3f5"))
		"xp":
			glass.add_box(Vector3(room.x1 - 0.015, y + 1.5, rc.z), Vector3(0.02, 1.0, 1.4), Color("bfe3f5"))
		"zp":
			glass.add_box(Vector3(rc.x, y + 1.5, room.z1 - 0.015), Vector3(1.4, 1.0, 0.02), Color("bfe3f5"))
	# Hedef bölge: oda iç alanı (kenarlardan pay bırakılır)
	var margin := 0.45
	var gmin := Vector3(room.x0 + margin, y, room.z0 + margin)
	var gmax := Vector3(room.x1 - margin, y + 2.2, room.z1 - margin)
	info.goal_aabb = AABB(gmin, gmax - gmin)
	info.goal_center = (gmin + gmax) * 0.5
	info.goal_center.y = y
	info.apt_door_pos = Vector3(sx * X_out, y, zc)
	info.corridor_end = Vector3((xw + x_end) * 0.5, y, zc) if turn == "none" else Vector3(anchors["corridor2"].pos)
	info.room_door_pos = _door_world(room, door_side, y)
	info.apt_aabb = AABB(Vector3(minf(room.x0, minf(xw, x_end)), y, minf(room.z0, zc - cw)), Vector3.ZERO).expand(Vector3(maxf(room.x1, maxf(xw, x_end)), y + room_h, maxf(room.z1, zc + cw)))
	apt = {"room": room, "y": y}


func _door_world(room: Dictionary, side: String, y: float) -> Vector3:
	var cx := (float(room.x0) + float(room.x1)) * 0.5
	var cz := (float(room.z0) + float(room.z1)) * 0.5
	match side:
		"xn":
			return Vector3(room.x0, y, cz)
		"xp":
			return Vector3(room.x1, y, cz)
		"zn":
			return Vector3(cx, y, room.z0)
	return Vector3(cx, y, room.z1)


func _rect(x0: float, x1: float, z0_: float, z1_: float) -> Dictionary:
	return {"x0": x0, "x1": x1, "z0": z0_, "z1": z1_}


## Dikdörtgen oda: zemin, tavan ve dört duvar (duvarlar dikdörtgenin dışına konur).
## walls[side]: null -> duvar yok, {} -> düz duvar, {"c","w","y0","y1"} -> boşluklu duvar
func _room_box(rc: Dictionary, y: float, height: float, walls: Dictionary, floor_color: Color) -> void:
	var x0 := float(rc.x0)
	var x1 := float(rc.x1)
	var zz0 := float(rc.z0)
	var zz1 := float(rc.z1)
	box_mm(Vector3(x0 - WT, y - SLAB, zz0 - WT), Vector3(x1 + WT, y, zz1 + WT), floor_color)
	ceiling_mm(Vector3(x0 - WT, y + height, zz0 - WT), Vector3(x1 + WT, y + height + 0.15, zz1 + WT))
	var yb := y - SLAB
	var yt := y + height + 0.15
	var defs := {
		"xn": [Vector3(x0 - WT, yb, zz0 - WT), Vector3(x0, yt, zz1 + WT)],
		"xp": [Vector3(x1, yb, zz0 - WT), Vector3(x1 + WT, yt, zz1 + WT)],
		"zn": [Vector3(x0, yb, zz0 - WT), Vector3(x1, yt, zz0)],
		"zp": [Vector3(x0, yb, zz1), Vector3(x1, yt, zz1 + WT)],
	}
	for side in defs:
		if not walls.has(side):
			continue
		var w = walls[side]
		if w == null:
			continue
		wall(defs[side][0], defs[side][1], C_APT_WALL, w)
	# Süpürgelik
	batch.add_box(Vector3((x0 + x1) * 0.5, y + 0.04, zz0 + 0.01), Vector3(x1 - x0, 0.08, 0.02), C_TRIM)


# ================================================================ dış bina kabuğu

func _build_block() -> void:
	var room: Dictionary = apt.room
	var bx := maxf(10.0, maxf(absf(float(room.x0)), absf(float(room.x1))) + 1.0)
	var bz := maxf(zb + WT, float(room.z1) + WT + 0.5)
	var yt := top_y
	var sx0 := -X_out - WT
	var sx1 := X_out + WT
	# Ön cephe (merdiven boşluğu dışında kalan kısımlar)
	box_mm(Vector3(-bx, -SLAB, -WT), Vector3(sx0, yt, 0.0), C_FACADE)
	box_mm(Vector3(sx1, -SLAB, -WT), Vector3(bx, yt, 0.0), C_FACADE)
	# Yan ve arka cephe, çatı
	box_mm(Vector3(-bx - WT, -SLAB, -WT), Vector3(-bx, yt, bz), C_FACADE)
	box_mm(Vector3(bx, -SLAB, -WT), Vector3(bx + WT, yt, bz), C_FACADE)
	box_mm(Vector3(-bx - WT, -SLAB, bz), Vector3(bx + WT, yt, bz + WT), C_FACADE)
	box_mm(Vector3(-bx - WT, yt, -WT - 0.3), Vector3(bx + WT, yt + 0.25, bz + WT), C_FACADE_2)
	# Kat bantları ve pencereler (ön cephe)
	for k in range(0, F + 1):
		var y := k * H
		batch.add_box(Vector3(0, y + 0.02, -WT - 0.06), Vector3(bx * 2.0 + WT * 2.0, 0.14, 0.12), C_FACADE_2)
		var wx := -bx + 1.6
		while wx < bx - 1.0:
			if absf(wx) > X_out + WT + 0.9:
				var wy := y + 1.0 if k > 0 else y + 0.9
				var wh := 1.3 if k > 0 else 1.6
				glass.add_box(Vector3(wx, wy + wh * 0.5, -WT - 0.015), Vector3(1.1, wh, 0.03), Color("a9cfe6"))
				batch.add_box(Vector3(wx, wy - 0.05, -WT - 0.08), Vector3(1.3, 0.08, 0.16), C_TRIM)
			wx += 2.4
	# Giriş saçağı ve yazı
	box_mm(Vector3(-1.4, float(L.entrance.y) + 0.35, -1.3), Vector3(1.4, float(L.entrance.y) + 0.45, -WT), C_FACADE_2)
	_label("APARTMAN NO: %d" % (10 + int(L.id)), Vector3(0, float(L.entrance.y) + 0.75, -WT - 0.03), PI, 52, Color("3a2a1c"))
	glow.add_box(Vector3(0, float(L.entrance.y) + 0.3, -0.5), Vector3(0.3, 0.06, 0.3), Color("fff2c0"))
	# Giriş paspası
	batch.add_box(Vector3(0, 0.005, -0.6), Vector3(1.0, 0.01, 0.6), Color("5a4636"))
	info.block_aabb = AABB(Vector3(-bx, 0, 0), Vector3(bx * 2.0, yt, bz))


# ================================================================ yol noktaları

func _build_waypoints() -> void:
	var w: Array = []
	w.append(Vector3(0, 0, -0.8))                    # bina girişi
	w.append(Vector3(xA, 0, z0 - 0.4))               # merdiven başlangıcı
	for k in F:
		var yk := k * H
		w.append(Vector3(xA, yk + Hh, z0 + Lf + LD * 0.5))
		w.append(Vector3(xB, yk + Hh, z0 + Lf + LD * 0.5))
		w.append(Vector3(xB, (k + 1) * H, z0 - 0.5))
		if k + 1 < F:
			w.append(Vector3(xA, (k + 1) * H, z0 - 0.4))
	w.append(Vector3(info.apt_door_pos) + Vector3(float(info.apt_side) * 0.4, 0, 0))
	w.append(info.corridor_end)
	w.append(info.room_door_pos)
	w.append(info.goal_center)
	info.waypoints = w


# ================================================================ engeller

func _place_obstacles() -> void:
	for o in L.obstacles:
		var key := str(o.at)
		if key in ["flightA", "flightB", "mid", "landing"]:
			key = "%s:%d" % [key, int(o.floor)]
		if not anchors.has(key):
			push_warning("Engel çapası yok: " + key)
			continue
		var a: Dictionary = anchors[key]
		var side := int(o.side)
		# En üst kat sahanlığında daire kapısı tarafına engel koyma
		if str(o.at) == "landing" and int(o.floor) == F and float(side) == float(info.apt_side):
			side = -side
		match str(o.type):
			"lamp":
				_obs_lamp(a)
			"shoe_rack":
				_obs_shoe_rack(a, side, str(o.at))
			"plant":
				_obs_plant(a, side, str(o.at))
			"boxes":
				_obs_boxes(a, side, str(o.at))
			"door":
				_obs_door(a, side)
			"cat":
				_obs_cat(a, str(o.at))


## Engelin konacağı köşe/kenar noktası.
func _edge_spot(a: Dictionary, side: int, at: String, depth: float) -> Vector3:
	var p: Vector3 = a.pos
	match at:
		"landing", "hall":
			return Vector3(side * (X_out - depth * 0.5 - 0.05), p.y, depth * 0.5 + 0.08)
		"mid":
			return Vector3(side * (X_out - depth * 0.5 - 0.05), p.y, zb - depth * 0.5 - 0.08)
	var sidev: Vector3 = a.side
	return p + sidev * side * (float(a.width) * 0.5 - depth * 0.5 - 0.02)


func _obs_lamp(a: Dictionary) -> void:
	var p: Vector3 = a.pos
	var ceil_y := float(a.ceil)
	var shade_bottom := maxf(p.y + 1.88, minf(p.y + 2.05, ceil_y - 0.3))
	if shade_bottom + 0.22 > ceil_y - 0.02:
		# Tavan çok alçak: tavana gömme lamba (engel değil)
		glow.add_box(Vector3(p.x, ceil_y - 0.02, p.z), Vector3(0.4, 0.03, 0.4), Color("fff2c0"))
		return
	var shade_c := Vector3(p.x, shade_bottom + 0.11, p.z)
	props.add_cylinder(Vector3(p.x, (shade_c.y + ceil_y) * 0.5, p.z), 0.012, ceil_y - shade_c.y, C_RAIL)
	props.add_cylinder(shade_c, 0.24, 0.22, Color("e0a040"))
	glow.add_sphere(shade_c + Vector3(0, -0.08, 0), 0.07, Color("fff6d0"))
	_shape_box(Transform3D(Basis(), shade_c), Vector3(0.46, 0.22, 0.46))


func _obs_shoe_rack(a: Dictionary, side: int, at: String) -> void:
	var depth := 0.34
	var p := _edge_spot(a, side, at, depth)
	var along: Vector3 = a.along
	var length := 0.9
	var size := Vector3(length, 0.85, depth) if absf(along.x) > 0.5 else Vector3(depth, 0.85, length)
	prop_box(p + Vector3.UP * 0.425, size, Color("7b5b3f"))
	# Ayakkabılar (görsel)
	for i in 3:
		var off := along * (-0.3 + i * 0.3)
		props.add_box(p + off + Vector3.UP * 0.9, Vector3(0.12, 0.08, 0.26) if absf(along.x) > 0.5 else Vector3(0.26, 0.08, 0.12), [Color("2b2b2b"), Color("b33a3a"), Color("e5e5e5")][i])


func _obs_plant(a: Dictionary, side: int, at: String) -> void:
	var p := _edge_spot(a, side, at, 0.5)
	props.add_cylinder(p + Vector3.UP * 0.22, 0.22, 0.44, C_POT)
	props.add_sphere(p + Vector3.UP * 0.8, 0.38, C_LEAVES)
	props.add_sphere(p + Vector3(0.12, 1.05, 0.05), 0.24, C_LEAVES.lightened(0.1))
	_shape_cyl(p + Vector3.UP * 0.6, 0.26, 1.2)


func _obs_boxes(a: Dictionary, side: int, at: String) -> void:
	var p := _edge_spot(a, side, at, 0.55)
	prop_box(p + Vector3.UP * 0.25, Vector3(0.6, 0.5, 0.5), Color("b08259"))
	prop_box(p + Vector3(0.03, 0.72, 0.02), Vector3(0.5, 0.44, 0.44), Color("a3774f"))
	props.add_box(p + Vector3(0.03, 0.945, 0.02), Vector3(0.08, 0.005, 0.45), Color("d9c38c"))


func _obs_door(a: Dictionary, side: int) -> void:
	var door := SwingDoor.new()
	var p: Vector3 = a.pos
	var along: Vector3 = a.along
	var sidev: Vector3 = a.side
	var width := float(a.width)
	var hinge := p + sidev * side * (width * 0.5 - 0.02) + along * (float(a.length) * 0.15)
	door.setup(hinge, along, -sidev * side, minf(0.85, width * 0.62), minf(2.0, float(a.ceil) - p.y - 0.05))
	root.add_child(door)
	info.obstacles.append(door)


func _obs_cat(a: Dictionary, at: String) -> void:
	var cat := Cat.new()
	var pts: Array = []
	if a.has("start"):
		var s: Vector3 = a.start
		var dz := float(a.dir)
		var lane_off := Vector3(signf(s.x) * (sw * 0.5 - 0.3), 0, 0)
		for i in 2:
			var d := 0.35 if i == 0 else Lf - 0.35
			# Yürünen yüzey (rampa) basamak burnu çizgisinden yarım basamak öndedir.
			pts.append(s + lane_off + Vector3(0, (d + t * 0.5) / Lf * Hh, dz * d))
	else:
		var p: Vector3 = a.pos
		var along: Vector3 = a.along
		var half := float(a.length) * 0.5 - 0.4
		pts.append(p - along * half)
		pts.append(p + along * half)
	cat.setup(pts)
	root.add_child(cat)
	info.obstacles.append(cat)


# ================================================================ malzemeler

func _building_material() -> Material:
	var m := ShaderMaterial.new()
	m.shader = load("res://shaders/building.gdshader")
	return m


func _ceiling_material() -> Material:
	var m := ShaderMaterial.new()
	m.shader = load("res://shaders/ceiling.gdshader")
	return m


func _props_material() -> Material:
	var m := StandardMaterial3D.new()
	m.vertex_color_use_as_albedo = true
	m.roughness = 0.7
	return m


func _glass_material() -> Material:
	# Cam da bina gölgelendiricisini kullanır: kesit görünümünde üst kat camları gizlenir.
	var m := ShaderMaterial.new()
	m.shader = load("res://shaders/building.gdshader")
	m.set_shader_parameter("roughness_value", 0.12)
	m.set_shader_parameter("grain_amount", 0.0)
	return m


func _glow_material() -> Material:
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.vertex_color_use_as_albedo = true
	m.albedo_color = Color(1.6, 1.5, 1.2)
	return m
