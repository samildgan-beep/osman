class_name LevelBuilder
extends RefCounted
## Bölüm verisinden 3D dünyayı kurar: canlı bir sokak, tuğla cepheli apartman,
## mermer basamaklı ve halı yolluklu U dönüşlü merdiven, detaylı korkuluklar,
## sahanlıklar, daire koridoru, hedef oda/kapı/yerleştirme yuvası ve engeller.
##
## Koordinatlar: +Y yukarı, sokak z < 0 tarafında, bina girişi z = 0'da.
## Merdiven boşluğu: sağ şerit (x > 0) A kolu +Z yönünde çıkar, ara sahanlıkta
## U dönüşü yapılır, sol şerit (x < 0) B kolu -Z yönünde kat sahanlığına çıkar.

const WT := 0.2        # duvar kalınlığı
const SLAB := 0.2      # döşeme kalınlığı
const RAIL_H := 1.0    # korkuluk yüksekliği

# Malzeme kimlikleri (MeshBatcher ile aynı)
const MP := MeshBatcher.M_PLASTER
const MBR := MeshBatcher.M_BRICK
const MW := MeshBatcher.M_WOOD
const MT := MeshBatcher.M_TILE
const MM := MeshBatcher.M_MARBLE
const MMET := MeshBatcher.M_METAL
const MWP := MeshBatcher.M_WALLPAPER
const MC := MeshBatcher.M_CARPET
const MG := MeshBatcher.M_GLASS
const MAS := MeshBatcher.M_ASPHALT
const MGR := MeshBatcher.M_GRASS
const MPV := MeshBatcher.M_PAVING
const MPA := MeshBatcher.M_PAINT
const MF := MeshBatcher.M_FABRIC

const MTZ := MeshBatcher.M_TERRAZZO

## Renk temaları: klasik eski Türk apartmanları. Pastel sıvalı cephe, yağlı boyalı
## merdiven duvarı (alt yarı), mozaik basamaklar, ahşap kaplama daire kapıları.
const TURKISH_THEMES := [
	{"facade": "efe1c6", "band": "d9c7a4", "trim": "f6f1e7", "wall": "f3eee3", "dado": "7fae96", "floor": "cfc5b5", "door": "6e4a2e", "awning": "c0392b", "wallpaper": "f4dcc0", "carpet": "a83a32"},
	{"facade": "f2d79b", "band": "d8b66a", "trim": "fbf6ea", "wall": "f6f1e4", "dado": "6f9ec2", "floor": "d3cbbb", "door": "5c3b22", "awning": "2e86c1", "wallpaper": "dfeaf7", "carpet": "1f5fa8"},
	{"facade": "e6c2b4", "band": "c99d8b", "trim": "f7f2ea", "wall": "f4eee6", "dado": "c9a37a", "floor": "cbc3b4", "door": "7a4f2e", "awning": "27ae60", "wallpaper": "e7f3e9", "carpet": "2e8b57"},
	{"facade": "c8dbe1", "band": "9fbcc6", "trim": "f5f5f0", "wall": "f1f2ee", "dado": "8fb7a4", "floor": "d0cbc2", "door": "684331", "awning": "e67e22", "wallpaper": "f3e3f0", "carpet": "6a4c93"},
	{"facade": "d8e3c4", "band": "b4c497", "trim": "f8f6ee", "wall": "f4f2e8", "dado": "b0a3c8", "floor": "cec6b4", "door": "5e3d24", "awning": "8e44ad", "wallpaper": "f2ead2", "carpet": "d1495b"},
	{"facade": "ead2bf", "band": "cfae92", "trim": "f8f3ec", "wall": "f5efe6", "dado": "d4b483", "floor": "d1c8b8", "door": "6b4426", "awning": "16a085", "wallpaper": "e3ebf5", "carpet": "e76f51"},
]
## Modern renkli apartman temaları (tuğla cephe, halı yolluklu mermer merdiven).
const MODERN_THEMES := [
	{"facade": "d9694c", "trim": "fbf3e4", "wall": "f7ead2", "dado": "2f6f68", "carpet": "b5263b", "door": "7b3f22", "floor": "e2d6c0", "awning": "2a9d8f", "wallpaper": "f4dcc0", "iron": false},
	{"facade": "f2c14e", "trim": "ffffff", "wall": "fff4dc", "dado": "2b5ea7", "carpet": "1f5fa8", "door": "2b5ea7", "floor": "e6e0d2", "awning": "e63946", "wallpaper": "dfeaf7", "iron": true},
	{"facade": "7fb7be", "trim": "f6f6f0", "wall": "eef6f2", "dado": "c8553d", "carpet": "2e8b57", "door": "c8553d", "floor": "e5e0d5", "awning": "f4a261", "wallpaper": "e7f3e9", "iron": false},
	{"facade": "e8a0bf", "trim": "fff8f2", "wall": "fbeff2", "dado": "6a4c93", "carpet": "6a4c93", "door": "4d3570", "floor": "eae4e9", "awning": "6a4c93", "wallpaper": "f3e3f0", "iron": true},
	{"facade": "8fbf6a", "trim": "fdfbf2", "wall": "f6f3e6", "dado": "8a5a32", "carpet": "d1495b", "door": "8a5a32", "floor": "e9e1cf", "awning": "edae49", "wallpaper": "f2ead2", "iron": false},
	{"facade": "6c8ebf", "trim": "fdfdfd", "wall": "eef2f8", "dado": "1d3557", "carpet": "e76f51", "door": "1d3557", "floor": "e3e6ea", "awning": "e9c46a", "wallpaper": "e3ebf5", "iron": true},
]
const BUILDING_NAME := "HİCRET APARTMANI"
const MODERN_NAME := "SUNNY APARTMENTS"
const C_IRON_RAIL := Color("33363b")
const C_HANDRAIL_PVC := Color("3b2a20")
const C_ALU := Color("4a3b2c")

const C_ASPHALT := Color("3f4248")
const C_ROAD_LINE := Color("f1ecd8")
const C_SIDEWALK := Color("c9c1b3")
const C_CURB := Color("a49e94")
const C_GRASS := Color("6db35a")
const C_MARBLE := Color("ece7de")
const C_NOSING := Color("cfc6b6")
const C_UNDERSIDE := Color("eee8dc")
const C_CEILING := Color("f7f4ee")
const C_WOOD := Color("8a5a32")
const C_WOOD_LIGHT := Color("c08a55")
const C_IRON := Color("26282d")
const C_BRASS := Color("d6a93a")
const C_WHITE_PAINT := Color("f7f5ef")
const C_TIRE := Color("1e1f22")
const C_TRUNK := Color("6b4a2f")
const C_LEAVES := Color("4e9a43")
const C_POT := Color("c46a3c")
const C_GLASS := Color("9cc9e6")
const FLOWER_COLORS := [Color("ff4d6d"), Color("ffd23f"), Color("f78c6b"), Color("c77dff"), Color("ffffff"), Color("ff8fab")]

var L: Dictionary
var T: Dictionary          # etkin tema (renkler)
var _room_door_pt := Vector3.ZERO   # oda kapısının ortası (detay yerleşimi kapıdan kaçınır)
var turk := true           # true: eski Türk apartmanı, false: modern renkli apartman
var root: Node3D
var body: StaticBody3D
var ramp_body: StaticBody3D    # merdiven rampası (karakter + kamera)
var steps_body: StaticBody3D   # gerçek basamaklar (eşya)
var batch := MeshBatcher.new()
var glow := MeshBatcher.new()
var ceil_batch := MeshBatcher.new()   # tavanlar: kesit görünümünde yarı saydam
var props := MeshBatcher.new()        # engeller: kesitten etkilenmez, hep görünür
var sky_batch := MeshBatcher.new()    # bulutlar
var info := {}
var anchors := {}
var rng := RandomNumberGenerator.new()

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
	turk = str(L.get("building", "turkish")) != "modern"
	var themes: Array = TURKISH_THEMES if turk else MODERN_THEMES
	var theme_idx := clampi(int(L.get("theme", 0)), 0, themes.size() - 1)
	T = {}
	var th: Dictionary = themes[theme_idx]
	for k in th:
		T[k] = Color(th[k]) if th[k] is String else th[k]
	rng.seed = 1000 + int(L.id) * 17
	root = Node3D.new()
	root.name = "Level"
	parent.add_child(root)
	body = StaticBody3D.new()
	body.name = "WorldBody"
	body.collision_layer = Config.LAYER_WORLD
	body.collision_mask = 0
	root.add_child(body)
	ramp_body = StaticBody3D.new()
	ramp_body.name = "StairRamps"
	ramp_body.collision_layer = Config.LAYER_RAMP
	ramp_body.collision_mask = 0
	root.add_child(ramp_body)
	steps_body = StaticBody3D.new()
	steps_body.name = "StairSteps"
	steps_body.collision_layer = Config.LAYER_STEPS
	steps_body.collision_mask = 0
	root.add_child(steps_body)
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
	glow.build(root, _glow_material(), "Glow", false)
	ceil_batch.build(root, _ceiling_material(), "Ceiling", false)
	props.build(root, _props_material(), "Props")
	sky_batch.build(root, _cloud_material(), "Clouds", false)
	info.anchors = anchors
	info.floor_height = H
	info.top_floor_y = F * H
	info.kill_y = -6.0
	info.ceiling = eff_ceil
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

func solid(center: Vector3, size: Vector3, color: Color, collide: bool = true, mat: int = MP) -> void:
	batch.add_box(center, size, color, mat)
	if collide:
		_shape_box(Transform3D(Basis(), center), size)


func solid_xf(xf: Transform3D, size: Vector3, color: Color, collide: bool = true, mat: int = MP) -> void:
	batch.add_box_xform(xf, size, color, mat)
	if collide:
		_shape_box(xf, size)


func box_mm(mn: Vector3, mx: Vector3, color: Color, collide: bool = true, mat: int = MP) -> void:
	var a := Vector3(minf(mn.x, mx.x), minf(mn.y, mx.y), minf(mn.z, mx.z))
	var b := Vector3(maxf(mn.x, mx.x), maxf(mn.y, mx.y), maxf(mn.z, mx.z))
	var size := b - a
	if size.x < 0.001 or size.y < 0.001 or size.z < 0.001:
		return
	solid((a + b) * 0.5, size, color, collide, mat)


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


func _shape_box(xf: Transform3D, size: Vector3, target: StaticBody3D = null) -> void:
	if size.x < 0.001 or size.y < 0.001 or size.z < 0.001:
		return
	var cs := CollisionShape3D.new()
	var bs := BoxShape3D.new()
	bs.size = size
	cs.shape = bs
	cs.transform = xf
	(target if target != null else body).add_child(cs)


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
func wall(p_mn: Vector3, p_mx: Vector3, color: Color, hole: Dictionary = {}, mat: int = MP) -> void:
	var mn := Vector3(minf(p_mn.x, p_mx.x), minf(p_mn.y, p_mx.y), minf(p_mn.z, p_mx.z))
	var mx := Vector3(maxf(p_mn.x, p_mx.x), maxf(p_mn.y, p_mx.y), maxf(p_mn.z, p_mx.z))
	if hole.is_empty():
		box_mm(mn, mx, color, true, mat)
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
	box_mm(mn, _span(mx, h0, along_z), color, true, mat)
	box_mm(_span(mn, h1, along_z), mx, color, true, mat)
	box_mm(_span(mn, h0, along_z), _span(Vector3(mx.x, hy0, mx.z), h1, along_z), color, true, mat)
	box_mm(_span(Vector3(mn.x, hy1, mn.z), h0, along_z), _span(mx, h1, along_z), color, true, mat)
	if bool(hole.get("frame", true)) and hy1 < mx.y - 0.01:
		_door_frame(mn, mx, along_z, h0, h1, hy0, hy1)


func _span(v: Vector3, value: float, along_z: bool) -> Vector3:
	if along_z:
		return Vector3(v.x, v.y, value)
	return Vector3(value, v.y, v.z)


func _door_frame(mn: Vector3, mx: Vector3, along_z: bool, h0: float, h1: float, y0: float, y1: float) -> void:
	# Kasa: duvar kalınlığından biraz taşan pervazlar (sadece görsel).
	var fw := 0.08
	var pad := 0.025
	var col: Color = T.trim
	if along_z:
		var x0 := mn.x - pad
		var x1 := mx.x + pad
		box_mm(Vector3(x0, y0, h0 - fw), Vector3(x1, y1 + fw, h0), col, false, MPA)
		box_mm(Vector3(x0, y0, h1), Vector3(x1, y1 + fw, h1 + fw), col, false, MPA)
		box_mm(Vector3(x0, y1, h0 - fw), Vector3(x1, y1 + fw, h1 + fw), col, false, MPA)
	else:
		var z0_ := mn.z - pad
		var z1_ := mx.z + pad
		box_mm(Vector3(h0 - fw, y0, z0_), Vector3(h0, y1 + fw, z1_), col, false, MPA)
		box_mm(Vector3(h1, y0, z0_), Vector3(h1 + fw, y1 + fw, z1_), col, false, MPA)
		box_mm(Vector3(h0 - fw, y1, z0_), Vector3(h1 + fw, y1 + fw, z1_), col, false, MPA)


func _label(text: String, pos: Vector3, yaw: float, size: int = 48, color: Color = Color(0.2, 0.16, 0.12), hide_in_cut: bool = true) -> Label3D:
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
	return lb


func _add_light(pos: Vector3, energy: float = 1.2, light_range: float = 6.0, color: Color = Color(1.0, 0.9, 0.75)) -> void:
	var l := OmniLight3D.new()
	l.position = pos
	l.light_energy = energy
	l.omni_range = light_range
	l.light_color = color
	l.shadow_enabled = false
	root.add_child(l)
	info.lights.append(l)


func _flower_cluster(center: Vector3, width: float, count: int) -> void:
	for i in count:
		var p := center + Vector3(rng.randf_range(-width * 0.5, width * 0.5), rng.randf_range(0.0, 0.08), rng.randf_range(-0.08, 0.08))
		batch.add_sphere(p, rng.randf_range(0.06, 0.1), C_LEAVES, MGR)
		batch.add_sphere(p + Vector3(0, 0.07, 0), rng.randf_range(0.035, 0.055), FLOWER_COLORS[rng.randi() % FLOWER_COLORS.size()], MPA)


func _tree(p: Vector3, scale: float) -> void:
	batch.add_cylinder(p + Vector3(0, 1.1 * scale, 0), 0.14 * scale, 2.2 * scale, C_TRUNK, Basis(), MW)
	var leaf := C_LEAVES.lerp(Color("8cc63f"), rng.randf())
	batch.add_sphere(p + Vector3(0, 2.7 * scale, 0), 1.0 * scale, leaf, MGR)
	batch.add_sphere(p + Vector3(0.5, 2.4, 0.3) * scale, 0.7 * scale, leaf.darkened(0.1), MGR)
	batch.add_sphere(p + Vector3(-0.45, 2.5, -0.25) * scale, 0.65 * scale, leaf.lightened(0.08), MGR)
	batch.add_sphere(p + Vector3(0, 3.35, 0) * scale, 0.6 * scale, leaf.lightened(0.12), MGR)
	_shape_cyl(p + Vector3(0, 1.1 * scale, 0), 0.18 * scale, 2.2 * scale)


func _car(p: Vector3, color: Color, yaw: float) -> void:
	var b := Basis(Vector3.UP, yaw)
	var xf := Transform3D(b, p)
	solid_xf(xf * Transform3D(Basis(), Vector3(0, 0.55, 0)), Vector3(4.0, 0.65, 1.8), color, true, MPA)
	batch.add_box_xform(xf * Transform3D(Basis(), Vector3(-0.2, 1.12, 0)), Vector3(2.2, 0.55, 1.65), color.lightened(0.05), MPA)
	batch.add_box_xform(xf * Transform3D(Basis(), Vector3(-0.2, 1.13, 0)), Vector3(2.0, 0.45, 1.7), C_GLASS, MG)
	batch.add_box_xform(xf * Transform3D(Basis(), Vector3(2.0, 0.6, 0.6)), Vector3(0.04, 0.14, 0.3), Color("fff7cf"), MPA)
	batch.add_box_xform(xf * Transform3D(Basis(), Vector3(2.0, 0.6, -0.6)), Vector3(0.04, 0.14, 0.3), Color("fff7cf"), MPA)
	batch.add_box_xform(xf * Transform3D(Basis(), Vector3(-2.0, 0.65, 0.6)), Vector3(0.04, 0.12, 0.3), Color("d62828"), MPA)
	batch.add_box_xform(xf * Transform3D(Basis(), Vector3(-2.0, 0.65, -0.6)), Vector3(0.04, 0.12, 0.3), Color("d62828"), MPA)
	for wx: float in [-1.3, 1.3]:
		for wz: float in [-0.85, 0.85]:
			var wp: Vector3 = xf * Vector3(wx, 0.34, wz)
			batch.add_cylinder(wp, 0.34, 0.24, C_TIRE, b * Basis(Vector3.RIGHT, PI * 0.5))
			batch.add_cylinder(wp + b * Vector3(0, 0, signf(wz) * 0.125), 0.18, 0.02, Color("c0c4c8"), b * Basis(Vector3.RIGHT, PI * 0.5), MMET)


## Büyük eşya mı? (ağır ya da çok uzun: koltuk, gardırop, beyaz eşya, büyük TV)
func _is_big_item() -> bool:
	var it := ItemDB.get_item(str(L.get("item", "")))
	if it.is_empty():
		return false
	var sz: Vector3 = it.size
	return float(it.get("weight", 0.0)) >= 18.0 or maxf(sz.x, maxf(sz.y, sz.z)) >= 1.4


## Şirin teslimat kamyoneti: iki renkli yuvarlak hatlı gövde, kocaman yuvarlak farlar,
## açık arka kapılar, içinde birkaç koli. Yerel eksenler: +X burun, -X arka, ±Z yanlar.
func _van(p: Vector3, yaw: float) -> void:
	var b := Basis(Vector3.UP, yaw)
	var xf := Transform3D(b, p)
	var orange := Color("ff8c1a")
	var cream := Color("fff3dc")
	var dark := Color("2b2d42")
	var metal := Color("c0c4c8")
	var axle := b * Basis(Vector3.RIGHT, PI * 0.5)
	var along_x := b * Basis(Vector3.FORWARD, PI * 0.5)   # silindir ekseni yerel X
	var L_ := 3.7
	var W := 1.72
	# Tekerlekler + jant + çamurluk kemerleri
	for wx: float in [-1.15, 1.2]:
		for wz: float in [-W * 0.5 + 0.08, W * 0.5 - 0.08]:
			var wc: Vector3 = xf * Vector3(wx, 0.36, wz)
			batch.add_cylinder(wc, 0.36, 0.24, C_TIRE, axle)
			batch.add_cylinder(wc + b * Vector3(0, 0, signf(wz) * 0.125), 0.2, 0.02, metal, axle, MMET)
			batch.add_cylinder(wc + b * Vector3(0, 0, signf(wz) * 0.135), 0.07, 0.02, orange, axle, MPA)
			batch.add_cylinder(xf * Vector3(wx, 0.5, signf(wz) * (W * 0.5 + 0.005)), 0.44, 0.02, dark, axle, MPA)
	# Alt gövde (turuncu) ve üst kasa (krem), yuvarlatılmış tavan kenarları
	batch.add_box_xform(xf * Transform3D(Basis(), Vector3(0, 0.82, 0)), Vector3(L_, 0.9, W), orange, MPA)
	batch.add_box_xform(xf * Transform3D(Basis(), Vector3(-0.5, 1.68, 0)), Vector3(2.7, 0.82, W - 0.02), cream, MPA)
	batch.add_box_xform(xf * Transform3D(Basis(), Vector3(-0.5, 2.1, 0)), Vector3(2.7, 0.06, W - 0.3), cream, MPA)
	for sz: float in [-1.0, 1.0]:
		batch.add_cylinder(xf * Vector3(-0.5, 1.98, sz * (W * 0.5 - 0.16)), 0.15, 2.7, cream, along_x, MPA)
	# Kabin: eğimli ön cam, yan camlar, tavan
	batch.add_box_xform(xf * Transform3D(Basis(), Vector3(1.08, 1.5, 0)), Vector3(0.5, 0.46, W - 0.04), cream, MPA)
	batch.add_box_xform(xf * Transform3D(Basis(Vector3.BACK, 0.5), Vector3(1.47, 1.55, 0)), Vector3(0.05, 0.62, W - 0.2), C_GLASS, MG)
	batch.add_box_xform(xf * Transform3D(Basis(Vector3.BACK, 0.5), Vector3(1.44, 1.55, 0)), Vector3(0.04, 0.68, W - 0.06), cream, MPA)
	for sz: float in [-1.0, 1.0]:
		batch.add_box_xform(xf * Transform3D(Basis(), Vector3(1.08, 1.55, sz * (W * 0.5 - 0.005))), Vector3(0.45, 0.36, 0.02), C_GLASS, MG)
		# Kapı çizgisi ve kolu
		batch.add_box_xform(xf * Transform3D(Basis(), Vector3(0.78, 1.05, sz * (W * 0.5 + 0.004))), Vector3(0.02, 0.85, 0.01), dark, MPA)
		batch.add_box_xform(xf * Transform3D(Basis(), Vector3(0.95, 1.15, sz * (W * 0.5 + 0.012))), Vector3(0.14, 0.03, 0.02), metal, MMET)
		# Yan ayna
		batch.add_box_xform(xf * Transform3D(Basis(), Vector3(1.42, 1.42, sz * (W * 0.5 + 0.1))), Vector3(0.06, 0.16, 0.12), dark, MPA)
		# Kasada yuvarlak "lombar" pencere
		batch.add_cylinder(xf * Vector3(0.1, 1.68, sz * (W * 0.5 - 0.005)), 0.18, 0.02, Color("ffffff"), axle, MPA)
		batch.add_cylinder(xf * Vector3(0.1, 1.68, sz * (W * 0.5 + 0.002)), 0.14, 0.02, C_GLASS, axle, MG)
		# Yazılar
		var side_yaw := yaw if sz > 0.0 else yaw + PI
		_label("EXPRESS", xf * Vector3(-0.85, 1.78, sz * (W * 0.5 + 0.015)), side_yaw, 72, orange, false)
		_label("DELIVERY", xf * Vector3(-0.85, 1.55, sz * (W * 0.5 + 0.015)), side_yaw, 48, dark, false)
		_label("We carry, you smile!", xf * Vector3(-0.3, 0.95, sz * (W * 0.5 + 0.015)), side_yaw, 30, Color("ffffff"), false)
	# Ön yüz: ızgara, gülen tampon, kocaman yuvarlak farlar
	batch.add_box_xform(xf * Transform3D(Basis(), Vector3(L_ * 0.5 + 0.01, 0.85, 0)), Vector3(0.02, 0.22, 0.7), dark, MPA)
	batch.add_box_xform(xf * Transform3D(Basis(), Vector3(L_ * 0.5 + 0.06, 0.45, 0)), Vector3(0.14, 0.16, W + 0.04), metal, MMET)
	batch.add_box_xform(xf * Transform3D(Basis(), Vector3(-L_ * 0.5 - 0.06, 0.45, 0)), Vector3(0.14, 0.16, W + 0.04), metal, MMET)
	for sz: float in [-1.0, 1.0]:
		batch.add_cylinder(xf * Vector3(L_ * 0.5 + 0.005, 0.95, sz * 0.6), 0.16, 0.03, metal, along_x, MMET)
		glow.add_sphere(xf * Vector3(L_ * 0.5 + 0.02, 0.95, sz * 0.6), 0.13, Color("fff6d0"))
		glow.add_box(xf * Vector3(-L_ * 0.5 - 0.005, 1.0, sz * 0.7), Vector3(0.02, 0.2, 0.12), Color("ff3b30"))
	_label(":)", xf * Vector3(L_ * 0.5 + 0.03, 0.72, 0.0), yaw + PI * 0.5, 64, dark, false)
	# Arka: açık kasa (koyu iç), menteşesinden yana açılmış arka kapılar, içeride koliler
	var rear := -L_ * 0.5
	batch.add_box_xform(xf * Transform3D(Basis(), Vector3(rear - 0.006, 1.32, 0)), Vector3(0.01, 1.2, W - 0.24), Color("34343a"), MPA)
	batch.add_box_xform(xf * Transform3D(Basis(), Vector3(rear - 0.004, 0.68, 0)), Vector3(0.012, 0.06, W - 0.2), metal, MMET)
	for sz: float in [-1.0, 1.0]:
		var hinge: Vector3 = xf * Vector3(rear, 1.32, sz * (W * 0.5 - 0.02))
		var bd := b * Basis(Vector3.UP, sz * deg_to_rad(105.0))
		var door_c: Vector3 = hinge + bd * Vector3(0, 0, -sz * W * 0.25)
		batch.add_box_xform(Transform3D(bd, door_c), Vector3(0.04, 1.24, W * 0.5 - 0.02), cream, MPA)
		batch.add_box_xform(Transform3D(bd, door_c + Vector3(0, -0.38, 0)), Vector3(0.045, 0.44, W * 0.5 - 0.01), orange, MPA)
		batch.add_box_xform(Transform3D(bd, door_c + Vector3(0, 0.25, 0)), Vector3(0.05, 0.4, W * 0.5 - 0.16), C_GLASS, MG)
	for i in 3:
		var bc: Vector3 = xf * Vector3(rear + 0.12, 0.9 + (0.36 if i == 2 else 0.0), -0.45 + i * 0.42 - (0.2 if i == 2 else 0.0))
		batch.add_box_xform(Transform3D(b, bc), Vector3(0.45, 0.34, 0.4), Color("c48a55").darkened(i * 0.08), MPA)
		batch.add_box_xform(Transform3D(b, bc + Vector3(0, 0.171, 0)), Vector3(0.46, 0.004, 0.08), Color("e8d9a8"), MPA)
	batch.add_box_xform(xf * Transform3D(Basis(Vector3.BACK, 0.38), Vector3(rear - 0.55, 0.3, 0.0)), Vector3(1.2, 0.04, 0.8), metal, MMET)
	# Turuncu tepe lambası
	glow.add_sphere(xf * Vector3(1.0, 1.82, 0.0), 0.07, Color("ffb347"))
	# Çarpışma: gövde
	_shape_box(Transform3D(b, p + Vector3(0, 1.1, 0)), Vector3(L_ + 0.2, 2.2, W + 0.1))


## Kurye motosikleti (scooter): kırmızı gövde, teslimat kutusu, kask, yanan far.
## Yerel eksenler: +X ileri (motorun burnu), +Z yan. Yan ayağa hafif yaslanmış durur.
func _motorbike(p: Vector3, yaw: float) -> void:
	var b := Basis(Vector3.UP, yaw) * Basis(Vector3.RIGHT, 0.09)
	var xf := Transform3D(b, p)
	var red := Color("d62828")
	var dark := Color("1e1f22")
	var metal := Color("c0c4c8")
	var axle := b * Basis(Vector3.RIGHT, PI * 0.5)
	# Tekerlekler (lastik + jant + göbek)
	for wx: float in [-0.65, 0.7]:
		var wc: Vector3 = xf * Vector3(wx, 0.3, 0.0)
		batch.add_cylinder(wc, 0.3, 0.12, dark, axle)
		batch.add_cylinder(wc, 0.19, 0.13, metal, axle, MMET)
		batch.add_cylinder(wc, 0.06, 0.15, Color("555a60"), axle, MMET)
	# Gövde, ayak basma yeri, arka kaporta, ön kalkan
	batch.add_box_xform(xf * Transform3D(Basis(), Vector3(0.0, 0.34, 0.0)), Vector3(0.95, 0.1, 0.32), dark, MPA)
	batch.add_box_xform(xf * Transform3D(Basis(), Vector3(-0.42, 0.6, 0.0)), Vector3(0.75, 0.38, 0.38), red, MPA)
	batch.add_box_xform(xf * Transform3D(Basis(Vector3.FORWARD, 0.25), Vector3(0.46, 0.68, 0.0)), Vector3(0.12, 0.62, 0.42), red, MPA)
	batch.add_box_xform(xf * Transform3D(Basis(), Vector3(0.62, 0.42, 0.0)), Vector3(0.28, 0.12, 0.2), red, MPA)
	batch.add_box_xform(xf * Transform3D(Basis(), Vector3(-0.42, 0.62, 0.195)), Vector3(0.6, 0.06, 0.01), Color("ffffff"), MPA)
	batch.add_box_xform(xf * Transform3D(Basis(), Vector3(-0.42, 0.62, -0.195)), Vector3(0.6, 0.06, 0.01), Color("ffffff"), MPA)
	# Sele
	batch.add_box_xform(xf * Transform3D(Basis(), Vector3(-0.35, 0.83, 0.0)), Vector3(0.62, 0.1, 0.3), dark, MF)
	# Ön çatal, gidon, elcikler, aynalar
	for side: float in [-0.07, 0.07]:
		batch.add_cylinder_between(xf * Vector3(0.7, 0.3, side), xf * Vector3(0.54, 1.02, side), 0.022, metal, MMET)
	batch.add_cylinder_between(xf * Vector3(0.52, 1.1, -0.36), xf * Vector3(0.52, 1.1, 0.36), 0.018, dark, MMET)
	for side: float in [-0.36, 0.36]:
		batch.add_cylinder_between(xf * Vector3(0.52, 1.1, side), xf * Vector3(0.52, 1.1, side * 1.25), 0.026, dark, MF)
		batch.add_cylinder_between(xf * Vector3(0.52, 1.1, side * 0.8), xf * Vector3(0.48, 1.32, side * 0.95), 0.008, dark, MMET)
		batch.add_box_xform(xf * Transform3D(Basis(), Vector3(0.48, 1.34, side * 0.95)), Vector3(0.02, 0.07, 0.1), metal, MMET)
	batch.add_box_xform(xf * Transform3D(Basis(), Vector3(0.55, 1.04, 0.0)), Vector3(0.16, 0.12, 0.26), red, MPA)
	glow.add_sphere(xf * Vector3(0.64, 1.0, 0.0), 0.07, Color("fff6d0"))
	glow.add_box(xf * Vector3(-0.8, 0.72, 0.0), Vector3(0.03, 0.05, 0.14), Color("ff3b30"))
	# Egzoz
	batch.add_cylinder_between(xf * Vector3(-0.25, 0.3, 0.2), xf * Vector3(-0.85, 0.42, 0.2), 0.04, metal, MMET)
	# Yan ayak (motosiklet +Z tarafına yaslandığı için ayak o tarafta)
	batch.add_cylinder_between(xf * Vector3(-0.05, 0.3, 0.16), Vector3(p.x, 0.0, p.z) + Basis(Vector3.UP, yaw) * Vector3(-0.15, 0.0, 0.36), 0.015, metal, MMET)
	# Teslimat kutusu (arka): turuncu, beyaz şerit, logo
	var box_c: Vector3 = xf * Vector3(-0.72, 1.12, 0.0)
	batch.add_box_xform(Transform3D(b, box_c), Vector3(0.46, 0.44, 0.46), Color("ff8c1a"), MPA)
	batch.add_box_xform(Transform3D(b, box_c + b * Vector3(0, 0.12, 0)), Vector3(0.47, 0.05, 0.47), Color("ffffff"), MPA)
	batch.add_box_xform(Transform3D(b, box_c + b * Vector3(0, 0.235, 0)), Vector3(0.48, 0.03, 0.48), Color("2b2d42"), MPA)
	var lb_side := _label("EXPRESS", box_c + b * Vector3(0.0, -0.05, -0.236), yaw + PI, 34, Color("ffffff"), false)
	lb_side.rotation.z = -0.09
	var lb_side2 := _label("DELIVERY", box_c + b * Vector3(0.0, -0.13, -0.236), yaw + PI, 26, Color("2b2d42"), false)
	lb_side2.rotation.z = -0.09
	_label("EXPRESS", box_c + b * Vector3(-0.236, -0.05, 0.0), yaw - PI * 0.5, 34, Color("ffffff"), false)
	# Selede kask
	var hc: Vector3 = xf * Vector3(-0.22, 1.0, 0.0)
	batch.add_sphere(hc, 0.16, Color("f4f4f4"), MPA, Vector3(1.0, 0.85, 0.95))
	batch.add_box_xform(Transform3D(b, hc + b * Vector3(0.1, -0.02, 0.0)), Vector3(0.06, 0.12, 0.24), Color("2b2d42"), MG)
	batch.add_sphere(hc + b * Vector3(0.0, 0.04, 0.0), 0.162, Color("d62828"), MPA, Vector3(0.35, 0.7, 1.0))
	# Çarpışma: motosikletin içinden geçilmesin (eşya çarparsa hasar alır)
	_shape_box(Transform3D(Basis(Vector3.UP, yaw), p + Vector3(0, 0.65, 0)), Vector3(1.95, 1.3, 0.55))


# ================================================================ sokak

func _build_street() -> void:
	# Zemin (çim + kaldırım + yol)
	box_mm(Vector3(-40, -0.5, -40), Vector3(40, -0.09, 30), C_GRASS, true, MGR)
	box_mm(Vector3(-14, -0.4, -4.0), Vector3(14, 0.0, -WT), C_SIDEWALK, true, MPV)
	box_mm(Vector3(-14, -0.4, -13.5), Vector3(14, -0.06, -4.0), C_ASPHALT, true, MAS)
	box_mm(Vector3(-14, -0.4, -4.15), Vector3(14, 0.0, -4.0), C_CURB, true, MPV)
	box_mm(Vector3(-14, -0.4, -13.65), Vector3(14, 0.0, -13.5), C_CURB, true, MPV)
	for i in range(-6, 7):
		batch.add_box(Vector3(i * 2.2, -0.055, -9.0), Vector3(1.1, 0.01, 0.12), C_ROAD_LINE, MPA)
	# Yaya geçidi
	for i in 7:
		batch.add_box(Vector3(6.0, -0.054, -5.0 - i * 1.15), Vector3(2.2, 0.01, 0.55), C_ROAD_LINE, MPA)
	# Kaldırım rampası (yoldan kaldırıma yumuşak geçiş, takılmasın)
	var ramp_len := 0.6
	var a := atan2(0.06, ramp_len)
	var xf := Transform3D(Basis(Vector3.RIGHT, -a), Vector3(0, -0.13, -4.15 - ramp_len * 0.5))
	_shape_box(xf, Vector3(28, 0.2, ramp_len + 0.05))

	# Oyun alanı sınırı: görünen çim alanın kenarı (karakter görünen her yere gidebilir)
	collider_mm(Vector3(-39.5, -1, -39.5), Vector3(-38.5, 8, 29.5))
	collider_mm(Vector3(38.5, -1, -39.5), Vector3(39.5, 8, 29.5))
	collider_mm(Vector3(-39.5, -1, -39.5), Vector3(39.5, 8, -38.5))
	collider_mm(Vector3(-39.5, -1, 28.5), Vector3(39.5, 8, 29.5))
	# Sınırda alçak çit (sınırın nerede olduğu görünsün)
	for i in range(-38, 39, 2):
		batch.add_box(Vector3(i, 0.4, -38.6), Vector3(0.08, 0.8, 0.08), Color("8a6a4a"), MW)
		batch.add_box(Vector3(i, 0.4, 28.6), Vector3(0.08, 0.8, 0.08), Color("8a6a4a"), MW)
	for zz in range(-38, 29, 2):
		batch.add_box(Vector3(-38.6, 0.4, zz), Vector3(0.08, 0.8, 0.08), Color("8a6a4a"), MW)
		batch.add_box(Vector3(38.6, 0.4, zz), Vector3(0.08, 0.8, 0.08), Color("8a6a4a"), MW)
	batch.add_box(Vector3(0, 0.65, -38.6), Vector3(77.2, 0.06, 0.05), Color("8a6a4a"), MW)
	batch.add_box(Vector3(0, 0.65, 28.6), Vector3(77.2, 0.06, 0.05), Color("8a6a4a"), MW)
	batch.add_box(Vector3(-38.6, 0.65, -5.0), Vector3(0.05, 0.06, 67.2), Color("8a6a4a"), MW)
	batch.add_box(Vector3(38.6, 0.65, -5.0), Vector3(0.05, 0.06, 67.2), Color("8a6a4a"), MW)
	# Karşı kaldırımda çalılar ve çiçekler
	for i in range(-13, 14, 2):
		batch.add_sphere(Vector3(i, 0.35, -13.9), 0.55, C_LEAVES.darkened(0.12), MGR, Vector3(1.6, 1.0, 0.8))
		_flower_cluster(Vector3(i + 0.4, 0.55, -13.75), 0.8, 3)

	# Taşınma kamyonu — oyuncunun ve kameranın arkasında kalmasın diye solda
	var tz := -8.6
	var tx := -4.8
	box_mm(Vector3(tx - 5.6, 0.55, tz - 1.2), Vector3(tx - 1.2, 3.1, tz + 1.2), Color("fdfdfd"), true, MPA)
	box_mm(Vector3(tx - 1.2, 0.55, tz - 1.15), Vector3(tx + 0.6, 2.35, tz + 1.15), Color("ff8c1a"), true, MPA)
	batch.add_box(Vector3(tx + 0.62, 1.8, tz), Vector3(0.04, 0.7, 2.0), C_GLASS, MG)
	batch.add_box(Vector3(tx - 3.4, 1.9, tz + 1.21), Vector3(4.2, 0.55, 0.02), Color("ff8c1a"), MPA)
	batch.add_box(Vector3(tx - 3.4, 1.35, tz + 1.21), Vector3(4.2, 0.12, 0.02), Color("2b2d42"), MPA)
	batch.add_box(Vector3(tx + 0.4, 2.15, tz), Vector3(0.3, 0.2, 2.1), Color("2b2d42"), MPA)
	for wx: float in [-4.6, -2.0, -0.2]:
		for wz: float in [tz - 1.1, tz + 1.1]:
			batch.add_cylinder(Vector3(tx + wx, 0.45, wz), 0.45, 0.32, C_TIRE, Basis(Vector3.RIGHT, PI * 0.5))
			batch.add_cylinder(Vector3(tx + wx, 0.45, wz + signf(wz - tz) * 0.17), 0.22, 0.02, Color("c0c4c8"), Basis(Vector3.RIGHT, PI * 0.5), MMET)
	batch.add_box_xform(Transform3D(Basis(Vector3.FORWARD, -0.32), Vector3(tx - 6.4, 0.3, tz)), Vector3(1.7, 0.06, 1.4), Color("9aa0a6"), MMET)
	_label("EASY MOVERS", Vector3(tx - 3.4, 2.5, tz + 1.23), 0.0, 96, Color("2b2d42"))
	_label("We carry, you smile!", Vector3(tx - 3.4, 1.62, tz + 1.23), 0.0, 44, Color("2b2d42"))

	# Kurye aracı: küçük eşyalarda giriş yanında motosiklet; büyük eşyalarda
	# yol kenarında arka kapıları açık şirin bir kamyonet (eşya oradan indirildi).
	if _is_big_item():
		_van(Vector3(-4.6, -0.06, -5.15), PI)
	else:
		_motorbike(Vector3(-2.45, 0.0, -2.75), 0.0)

	# Park etmiş arabalar
	var car_colors := [Color("e63946"), Color("2a9d8f"), Color("ffb703"), Color("4361ee"), Color("8338ec")]
	_car(Vector3(9.0, -0.06, -6.0), car_colors[rng.randi() % car_colors.size()], 0.0)
	_car(Vector3(-11.5, -0.06, -11.6), car_colors[rng.randi() % car_colors.size()], PI)
	_car(Vector3(10.5, -0.06, -11.6), car_colors[rng.randi() % car_colors.size()], PI)

	# Ağaçlar, lambalar, banklar, çiçeklikler
	for p: Vector3 in [Vector3(-11, 0, -2.2), Vector3(11, 0, -2.2), Vector3(-7.5, 0, -2.2), Vector3(7.5, 0, -2.2)]:
		batch.add_cylinder(p + Vector3(0, 0.08, 0), 0.6, 0.16, Color("7a5a3a"), Basis(), MW)
		_tree(p, rng.randf_range(0.9, 1.15))
	for p: Vector3 in [Vector3(-4.0, 0, -3.6), Vector3(4.0, 0, -3.6), Vector3(12.5, 0, -3.6)]:
		batch.add_cylinder(p + Vector3(0, 1.9, 0), 0.06, 3.8, C_IRON, Basis(), MMET)
		batch.add_cylinder(p + Vector3(0, 0.2, 0), 0.12, 0.4, C_IRON, Basis(), MMET)
		batch.add_box(p + Vector3(0, 3.85, 0.15), Vector3(0.1, 0.06, 0.4), C_IRON, MMET)
		glow.add_sphere(p + Vector3(0, 3.7, 0.32), 0.15, Color("fff2c0"))
		_shape_cyl(p + Vector3(0, 1.8, 0), 0.1, 3.6)
	for p: Vector3 in [Vector3(-9.3, 0, -1.2), Vector3(9.3, 0, -1.2)]:
		# Bank
		box_mm(p + Vector3(-0.8, 0.42, -0.2), p + Vector3(0.8, 0.48, 0.2), C_WOOD_LIGHT, true, MW)
		box_mm(p + Vector3(-0.8, 0.5, 0.14), p + Vector3(0.8, 0.85, 0.2), C_WOOD_LIGHT, false, MW)
		for lx: float in [-0.7, 0.7]:
			batch.add_box(p + Vector3(lx, 0.21, 0), Vector3(0.06, 0.42, 0.38), C_IRON, MMET)
	for p: Vector3 in [Vector3(-2.6, 0, -0.9), Vector3(2.6, 0, -0.9)]:
		# Giriş yanında çiçeklik (çarpışmalı)
		box_mm(p + Vector3(-0.55, 0, -0.35), p + Vector3(0.55, 0.42, 0.35), Color("b5b0a5"), true, MPV)
		batch.add_box(p + Vector3(0, 0.43, 0), Vector3(1.0, 0.04, 0.6), Color("5a3d28"), MGR)
		_flower_cluster(p + Vector3(0, 0.5, 0), 0.9, 9)
	# Yangın musluğu ve çöp kutusu
	batch.add_cylinder(Vector3(5.5, 0.35, -3.7), 0.12, 0.7, Color("d62828"), Basis(), MPA)
	batch.add_sphere(Vector3(5.5, 0.72, -3.7), 0.12, Color("d62828"), MPA)
	_shape_cyl(Vector3(5.5, 0.4, -3.7), 0.15, 0.8)
	batch.add_cylinder(Vector3(-5.4, 0.45, -3.7), 0.25, 0.9, Color("2a9d8f"), Basis(), MPA)
	_shape_cyl(Vector3(-5.4, 0.45, -3.7), 0.27, 0.9)

	# Arka plan binaları (renkli, pencereli)
	for i in 9:
		var bx := -24.0 + i * 6.0
		var bh := rng.randf_range(7.0, 17.0)
		var bcol := Color(MODERN_THEMES[(i + int(L.id)) % MODERN_THEMES.size()].facade).lightened(0.1)
		solid(Vector3(bx, bh * 0.5, -22.0), Vector3(5.4, bh, 5.0), bcol, true, MP)
		batch.add_box(Vector3(bx, bh + 0.15, -22.0), Vector3(5.7, 0.3, 5.3), Color("fdfbf5"), MPA)
		var wy := 1.6
		while wy < bh - 1.0:
			for wx: float in [-1.6, 0.0, 1.6]:
				batch.add_box(Vector3(bx + wx, wy, -19.49), Vector3(0.9, 1.1, 0.04), C_GLASS, MG)
			wy += 2.8
	# Bulutlar
	for i in 8:
		var cp := Vector3(rng.randf_range(-60, 60), rng.randf_range(28, 42), rng.randf_range(-70, 40))
		for j in 4:
			sky_batch.add_sphere(cp + Vector3(j * 3.0 - 4.5, rng.randf_range(-0.5, 1.2), rng.randf_range(-1.5, 1.5)), rng.randf_range(2.5, 4.2), Color.WHITE, 0, Vector3(1.4, 0.6, 1.0))

	anchors["street"] = {"pos": Vector3(3, 0, -6), "along": Vector3.RIGHT, "side": Vector3.BACK, "width": 6.0, "length": 6.0, "ceil": 50.0}
	# Oyun apartmanın giriş kapısının önünde başlar; eşya kapının yanında bekler.
	info.player_spawn = Transform3D(Basis(Vector3.UP, PI), Vector3(-0.7, 0.05, -2.4))
	info.item_spawn = Vector3(0.85, 0.0, -2.15)


# ================================================================ merdiven boşluğu

func _build_stairwell() -> void:
	var floor_col: Color = T.floor
	var fm := MTZ if turk else MT   # Türk apartmanında mozaik zemin
	# Giriş holü zemini (fayans)
	box_mm(Vector3(-X_out, -SLAB, -WT), Vector3(X_out, 0.0, z0), floor_col, true, fm)
	# Zemin katta B kolunun altı ve ara sahanlığın altı dolu (merdiven altı)
	box_mm(Vector3(-X_out, -SLAB, z0), Vector3(gap * 0.5, Hh, z0 + Lf), T.wall)
	box_mm(Vector3(-X_out, Hh, z0), Vector3(-gap * 0.5, H - 0.32, z0 + WT), T.wall)
	batch.add_box(Vector3((-X_out + gap * 0.5) * 0.5, 0.5, z0 - 0.008), Vector3(X_out + gap * 0.5, 1.0, 0.016), T.dado, MPA)
	box_mm(Vector3(-X_out, -SLAB, z0 + Lf), Vector3(X_out, Hh, zb), floor_col, true, fm)
	# Hol: posta kutuları, paspas, saksı
	var mb_x := X_out - 0.02
	var mb_col := Color("9aa3a8") if turk else Color("b08d57")
	for row in 2:
		for col in 3:
			batch.add_box(Vector3(mb_x, 1.25 + row * 0.26, 0.45 + col * 0.36), Vector3(0.03, 0.22, 0.32), mb_col, MMET)
			batch.add_box(Vector3(mb_x - 0.02, 1.3 + row * 0.26, 0.45 + col * 0.36), Vector3(0.01, 0.03, 0.18), Color("3a2c1a"), MMET)
	batch.add_box(Vector3(0, 0.006, 0.55), Vector3(1.2, 0.012, 0.7), Color("7a2e2e"), MC)
	if turk:
		_hall_turkish()
	# Hol saksısı: yalnızca girişi daraltmayacak kadar yer varsa
	if X_out - 0.6 > float(L.entrance.x) * 0.5 + 0.1:
		props.add_cylinder(Vector3(-X_out + 0.3, 0.25, 0.3), 0.22, 0.5, C_POT)
		props.add_sphere(Vector3(-X_out + 0.3, 0.85, 0.3), 0.35, C_LEAVES)
		props.add_sphere(Vector3(-X_out + 0.25, 1.15, 0.32), 0.22, C_LEAVES.lightened(0.1))
		_shape_cyl(Vector3(-X_out + 0.3, 0.55, 0.3), 0.25, 1.1)

	for k in F:
		var yk := k * H
		# A kolu (sağ şerit, +Z)
		_flight(Vector3(xA, yk, z0), 1.0, gap * 0.5, k)
		# Ara sahanlık
		if k > 0:
			box_mm(Vector3(-X_out, yk + Hh - SLAB, z0 + Lf), Vector3(X_out, yk + Hh, zb), floor_col, true, fm)
		collider_mm(Vector3(gap * 0.5, yk + Hh - SLAB, z0 + Lf - t * 0.5), Vector3(X_out, yk + Hh, z0 + Lf))
		# B kolu (sol şerit, -Z)
		_flight(Vector3(xB, yk + Hh, z0 + Lf), -1.0, -gap * 0.5, k)
		# Kat sahanlığı (k+1)
		var yl := (k + 1) * H
		box_mm(Vector3(-X_out, yl - SLAB, -WT), Vector3(X_out, yl, z0), floor_col, true, fm)
		collider_mm(Vector3(-X_out, yl - SLAB, z0), Vector3(-gap * 0.5, yl, z0 + t * 0.5))
		# Boşluk korkulukları
		_rail_straight(Vector3(-gap * 0.5, yk + Hh, z0 + Lf + 0.03), Vector3(gap * 0.5, yk + Hh, z0 + Lf + 0.03))
		var rail_end := X_out if k + 1 == F else gap * 0.5
		_rail_straight(Vector3(-gap * 0.5, yl, z0 - 0.03), Vector3(rail_end, yl, z0 - 0.03))
		# Tavanlar
		if slabs or k == F - 1:
			ceiling_mm(Vector3(-X_out, yk + Hh + C, z0 + Lf), Vector3(X_out, yk + Hh + C + 0.1, zb))
		# Ara sahanlıkta pencere, tablolar ve lambri
		var wy := yk + Hh
		batch.add_box(Vector3(0, wy + 1.35, zb - 0.012), Vector3(1.1, 0.95, 0.02), C_GLASS, MG)
		batch.add_box(Vector3(0, wy + 1.35, zb - 0.02), Vector3(0.05, 0.95, 0.03), T.trim, MPA)
		batch.add_box(Vector3(0, wy + 1.35, zb - 0.02), Vector3(1.1, 0.05, 0.03), T.trim, MPA)
		batch.add_box(Vector3(0, wy + 0.85, zb - 0.06), Vector3(1.3, 0.05, 0.12), T.trim, MPA)
		batch.add_box(Vector3(0, wy + 1.85, zb - 0.03), Vector3(1.3, 0.08, 0.06), T.trim, MPA)
		if turk:
			# Pencere önünde sardunya saksısı
			batch.add_box(Vector3(0.25, wy + 0.95, zb - 0.1), Vector3(0.22, 0.17, 0.17), C_POT, MPA)
			_flower_cluster(Vector3(0.25, wy + 1.06, zb - 0.1), 0.2, 4)
			batch.add_cylinder(Vector3(-0.3, wy + 0.95, zb - 0.1), 0.08, 0.16, Color("e8e2d0"), Basis(), MPA)
			batch.add_sphere(Vector3(-0.3, wy + 1.12, zb - 0.1), 0.12, C_LEAVES, MGR)
		else:
			_flower_cluster(Vector3(0, wy + 0.9, zb - 0.08), 0.9, 6)
			_picture(Vector3(-X_out + 0.45, wy + 1.4, zb - 0.02), 0.0)
			_picture(Vector3(X_out - 0.45, wy + 1.4, zb - 0.02), 0.0)
		_dado_z(zb - 0.01, -X_out, X_out, wy, -1.0)
		_dado_x(-X_out + 0.01, z0 + Lf, zb, wy, 1.0)
		_dado_x(X_out - 0.01, z0 + Lf, zb, wy, -1.0)
		_sconce(Vector3(-X_out + 0.02, wy + 1.75, zb - 0.5), 1.0)
		# Kat sahanlığı: lambri (kapısız ön duvarda), kat yazısı, aplikler, ışık
		_dado_z(0.01, -X_out, X_out, yl, 1.0)
		_label("FLOOR %d" % (k + 1), Vector3(0, yl + 1.62, 0.03), 0.0, 60, T.dado)
		var sc_x := minf(0.95, X_out - 0.3)
		if turk:
			_timer_switch(Vector3(-sc_x, yl + 1.25, 0.012))
			glow.add_sphere(Vector3(sc_x, yl + 1.8, 0.1), 0.11, Color("fff3d6"))
			batch.add_box(Vector3(sc_x, yl + 1.8, 0.015), Vector3(0.16, 0.16, 0.03), Color("e8e4da"), MPA)
		else:
			_sconce(Vector3(-sc_x, yl + 1.7, 0.02), 0.0, true)
			_sconce(Vector3(sc_x, yl + 1.7, 0.02), 0.0, true)
		_add_light(Vector3(0, yl + minf(C, H - 0.3) - 0.3, z0 * 0.5), 1.0, 5.5)

		# Ara katlardaki kapalı daire kapıları (dekor)
		if k + 1 < F:
			_deco_door(-1.0, yl, "%d%s" % [k + 1, "A"])
			_deco_door(1.0, yl, "%d%s" % [k + 1, "B"])

	# Zemin kat lambrisi (giriş boşluğunun iki yanında)
	var ewh := float(L.entrance.x) * 0.5 + 0.1
	if X_out > ewh + 0.05:
		_dado_z(0.01, -X_out, -ewh, 0.0, 1.0)
		_dado_z(0.01, ewh, X_out, 0.0, 1.0)
	_dado_x(X_out - 0.01, 0.0, z0, 0.0, -1.0)
	_dado_x(-X_out + 0.01, 0.0, z0, 0.0, 1.0)
	# Kat sahanlığı tavanları
	for k in range(0, F + 1):
		if slabs or k == F:
			var yc := k * H + C
			ceiling_mm(Vector3(-X_out, yc, -WT), Vector3(X_out, yc + 0.1, z0))
	_add_light(Vector3(0, minf(C, H - 0.3) - 0.3, z0 * 0.5), 1.0, 5.5)

	# Dış duvarlar
	var apt_side := -1.0 if str(L.corridor.turn) != "right" else 1.0
	var dw := float(L.apt_door.x)
	var dh := float(L.apt_door.y)
	var zc := z0 * 0.5
	var door_hole := {"c": zc, "w": dw, "y0": F * H, "y1": F * H + dh}
	for side: float in [-1.0, 1.0]:
		var x0 := side * X_out
		var x1 := side * (X_out + WT)
		if side == apt_side:
			wall(Vector3(x0, -SLAB, -WT), Vector3(x1, F * H, zb + WT), T.wall)
			wall(Vector3(x0, F * H, -WT), Vector3(x1, top_y, zb + WT), T.wall, door_hole)
		else:
			wall(Vector3(x0, -SLAB, -WT), Vector3(x1, top_y, zb + WT), T.wall)
	wall(Vector3(-X_out - WT, -SLAB, zb), Vector3(X_out + WT, top_y, zb + WT), T.wall)
	var ew := float(L.entrance.x)
	var eh := float(L.entrance.y)
	wall(Vector3(-X_out - WT, -SLAB, -WT), Vector3(X_out + WT, top_y, 0.0), T.wall, {"c": 0.0, "w": ew, "y0": 0.0, "y1": eh})
	# Çatı
	box_mm(Vector3(-X_out - WT, top_y - SLAB, -WT), Vector3(X_out + WT, top_y, zb + WT), C_CEILING)

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


## Otomatik merdiven ışığı düğmesi (turuncu yanan küçük düğme).
## face: düğmenin baktığı yön (ön duvarda +Z, yan duvarlarda ±X)
func _timer_switch(p: Vector3, face: Vector3 = Vector3.BACK) -> void:
	var on_x := absf(face.x) > 0.5
	batch.add_box(p, Vector3(0.02, 0.08, 0.08) if on_x else Vector3(0.08, 0.08, 0.02), Color("f3efe6"), MPA)
	glow.add_box(p + face * 0.012, Vector3(0.006, 0.035, 0.035) if on_x else Vector3(0.035, 0.035, 0.006), Color("ff9f1c"))


## Eski Türk apartmanı giriş holü ayrıntıları: elektrik sayacı dolabı, ilan panosu,
## otomatik ışık düğmesi, tavan glob lambası.
func _hall_turkish() -> void:
	var lx := -X_out + 0.015
	# Elektrik sayacı dolabı (sol duvarda): gri kapak ve küçük camlar
	batch.add_box(Vector3(lx, 1.55, z0 - 0.55), Vector3(0.03, 0.75, 0.7), Color("b8bcbf"), MMET)
	for i in 3:
		batch.add_box(Vector3(lx + 0.018, 1.62, z0 - 0.78 + i * 0.23), Vector3(0.005, 0.12, 0.14), C_GLASS, MG)
	# İlan panosu: mantar pano ve renkli kâğıtlar
	batch.add_box(Vector3(lx, 1.45, 0.65), Vector3(0.02, 0.5, 0.7), Color("b5835a"), MW)
	var paper := [Color("fffbe6"), Color("ffe066"), Color("a8e6cf"), Color("ffffff")]
	for i in 4:
		batch.add_box(Vector3(lx + 0.012, 1.4 + (i % 2) * 0.17, 0.42 + i * 0.15), Vector3(0.004, 0.18, 0.13), paper[i], MPA)
	_timer_switch(Vector3(X_out - 0.012, 1.25, 0.25), Vector3.LEFT)
	glow.add_sphere(Vector3(0, minf(C, H - 0.3) - 0.12, z0 * 0.5), 0.13, Color("fff3d6"))


## Lambri (alt duvar paneli) + bel çıtası: z sabit duvar boyunca. face: duvarın baktığı yön (+1/-1 z)
func _dado_z(z: float, x0: float, x1: float, y: float, face: float) -> void:
	var w := absf(x1 - x0)
	var cx := (x0 + x1) * 0.5
	if turk:
		# Yağlı boya (1.2 m), üstünde koyu şerit, altta mozaik süpürgelik
		batch.add_box(Vector3(cx, y + 0.6, z + face * 0.006), Vector3(w, 1.2, 0.012), T.dado, MPA)
		batch.add_box(Vector3(cx, y + 1.21, z + face * 0.008), Vector3(w, 0.025, 0.014), T.dado.darkened(0.35), MPA)
		batch.add_box(Vector3(cx, y + 0.08, z + face * 0.012), Vector3(w, 0.16, 0.02), T.floor.darkened(0.08), MTZ)
		return
	batch.add_box(Vector3(cx, y + 0.4, z + face * 0.006), Vector3(w, 0.8, 0.012), T.dado, MPA)
	batch.add_box(Vector3(cx, y + 0.82, z + face * 0.018), Vector3(w, 0.05, 0.03), T.trim, MPA)
	batch.add_box(Vector3(cx, y + 0.06, z + face * 0.02), Vector3(w, 0.12, 0.025), T.trim, MPA)


## Lambri: x sabit duvar boyunca. face: duvarın baktığı yön (+1/-1 x)
func _dado_x(x: float, z0_: float, z1_: float, y: float, face: float) -> void:
	var w := absf(z1_ - z0_)
	var cz := (z0_ + z1_) * 0.5
	if turk:
		batch.add_box(Vector3(x + face * 0.006, y + 0.6, cz), Vector3(0.012, 1.2, w), T.dado, MPA)
		batch.add_box(Vector3(x + face * 0.008, y + 1.21, cz), Vector3(0.014, 0.025, w), T.dado.darkened(0.35), MPA)
		batch.add_box(Vector3(x + face * 0.012, y + 0.08, cz), Vector3(0.02, 0.16, w), T.floor.darkened(0.08), MTZ)
		return
	batch.add_box(Vector3(x + face * 0.006, y + 0.4, cz), Vector3(0.012, 0.8, w), T.dado, MPA)
	batch.add_box(Vector3(x + face * 0.018, y + 0.82, cz), Vector3(0.03, 0.05, w), T.trim, MPA)
	batch.add_box(Vector3(x + face * 0.02, y + 0.06, cz), Vector3(0.025, 0.12, w), T.trim, MPA)


func _picture(p: Vector3, _yaw: float) -> void:
	batch.add_box(p, Vector3(0.5, 0.4, 0.025), C_WOOD, MW)
	var c1: Color = FLOWER_COLORS[rng.randi() % FLOWER_COLORS.size()]
	batch.add_box(p + Vector3(0, 0.05, -0.014), Vector3(0.42, 0.2, 0.004), Color("87ceeb"), MPA)
	batch.add_box(p + Vector3(0, -0.09, -0.014), Vector3(0.42, 0.12, 0.004), Color("6db35a"), MPA)
	batch.add_sphere(p + Vector3(0.1, 0.08, -0.016), 0.04, c1, MPA)


## Duvar apliği: yan duvarda (side ±1 → x duvarı) veya ön duvarda (front=true)
func _sconce(p: Vector3, side: float, front: bool = false) -> void:
	if front:
		batch.add_box(p, Vector3(0.12, 0.16, 0.04), C_BRASS, MMET)
		glow.add_sphere(p + Vector3(0, 0.08, 0.06), 0.06, Color("ffe8b0"))
	else:
		batch.add_box(p, Vector3(0.04, 0.16, 0.12), C_BRASS, MMET)
		glow.add_sphere(p + Vector3(side * 0.06, 0.08, 0), 0.06, Color("ffe8b0"))


## Tek merdiven kolu. Çarpışma (rampa, korkuluk, tavan) her iki bina tipinde aynıdır;
## görsel ayrıntı bina tipine göre çizilir.
## start: ilk basamak hizasında şerit ortası (taban yüksekliği), dz: +1 / -1
func _flight(start: Vector3, dz: float, rail_x: float, k: int) -> void:
	var dir := Vector3(0, 0, dz)
	# Eğim hesapları
	var ell := sqrt(Lf * Lf + Hh * Hh)
	var a := atan2(Hh, Lf)
	var u := (dir * Lf + Vector3.UP * Hh) / ell
	var nrm := Vector3.UP * cos(a) - dir * sin(a)
	var bas := Basis(nrm.cross(u), nrm, u)
	# Rampa çarpışması (yalnızca karakter ve kamera): basamak burunları çizgisinin
	# yarım basamak gerisinden geçer, karakter takılmadan çıkar.
	var thick := 0.3
	var mid := start + dir * ((Lf - t) * 0.5) + Vector3.UP * (Hh * 0.5)
	_shape_box(Transform3D(bas, mid - nrm * (thick * 0.5)), Vector3(sw, thick, ell), ramp_body)
	# Gerçek basamaklar (yalnızca eşya): görünen basamaklarla birebir aynı
	for i in n:
		var top := (i + 1) * r
		_shape_box(Transform3D(Basis(), start + dir * (i * t + t * 0.5) + Vector3.UP * (top - (r + 0.12) * 0.5)), Vector3(sw, r + 0.12, t + 0.01), steps_body)
	# İç korkuluk çarpışması (boşluk tarafı): görünen trabzanla aynı yükseklikte.
	# Eğik kutunun eğime dik kalınlığı = dikey yükseklik × cos(eğim)
	var side_off := Vector3(signf(-rail_x) * 0.04, 0, 0)
	var rail_start := Vector3(rail_x, start.y, start.z) + side_off
	var rail_mid := rail_start + dir * (Lf * 0.5) + Vector3.UP * (Hh * 0.5)
	var rail_th := (RAIL_H + 0.03) * cos(a)
	_shape_box(Transform3D(bas, rail_mid + nrm * (rail_th * 0.5)), Vector3(0.06, rail_th, ell))
	var g := {"start": start, "dir": dir, "dz": dz, "ell": ell, "a": a, "nrm": nrm, "bas": bas,
		"slope": Hh / Lf, "rail_start": rail_start, "rail_mid": rail_mid}
	if turk:
		_flight_visual_turkish(g)
	else:
		_flight_visual_modern(g)
	# Kol tavanı (alçak tavan veya en üst kat)
	if slabs or k == F - 1:
		var cc := start + dir * (Lf * 0.5) + Vector3.UP * (Hh * 0.5 + C) + nrm * 0.05
		ceil_batch.add_box_xform(Transform3D(bas, cc), Vector3(sw, 0.1, ell + 0.35), C_CEILING)
		_shape_box(Transform3D(bas, cc), Vector3(sw, 0.1, ell + 0.35))


## Modern apartman: mermer basamak, halı yolluk, pirinç çubuklar, tornalı dikmeler,
## başlık babaları, ahşap trabzan, duvar tutamağı ve eğimli lambri.
func _flight_visual_modern(g: Dictionary) -> void:
	var start: Vector3 = g.start
	var dir: Vector3 = g.dir
	var dz := float(g.dz)
	var ell := float(g.ell)
	var a := float(g.a)
	var nrm: Vector3 = g.nrm
	var bas: Basis = g.bas
	var slope := float(g.slope)
	var rail_start: Vector3 = g.rail_start
	var rail_mid: Vector3 = g.rail_mid
	var runner_w := sw * 0.62
	var carpet: Color = T.carpet
	for i in n:
		var top := (i + 1) * r
		var hgt := r + 0.12
		var c := start + dir * (i * t + t * 0.5) + Vector3.UP * (top - hgt * 0.5)
		batch.add_box(c, Vector3(sw, hgt, t + 0.01), C_MARBLE, MM)
		batch.add_box(start + dir * (i * t - 0.005) + Vector3.UP * (top - 0.018), Vector3(sw, 0.036, 0.05), C_NOSING, MM)
		batch.add_box(start + dir * (i * t + t * 0.5) + Vector3.UP * (top + 0.006), Vector3(runner_w, 0.012, t + 0.02), carpet, MC)
		batch.add_box(start + dir * (i * t - 0.012) + Vector3.UP * (top - r * 0.5), Vector3(runner_w, r, 0.012), carpet.darkened(0.08), MC)
		batch.add_cylinder_between(start + dir * ((i + 1) * t - 0.02) + Vector3(-runner_w * 0.5 - 0.03, top + 0.014, 0), start + dir * ((i + 1) * t - 0.02) + Vector3(runner_w * 0.5 + 0.03, top + 0.014, 0), 0.009, C_BRASS, MMET)
	var under_c := start + dir * (Lf * 0.5) + Vector3.UP * (Hh * 0.5) - nrm * 0.2
	batch.add_box_xform(Transform3D(bas, under_c), Vector3(sw, 0.16, ell), C_UNDERSIDE)
	var iron := bool(T.get("iron", false))
	var post_col := C_IRON if iron else C_WHITE_PAINT
	var post_mat := MMET if iron else MPA
	batch.add_box_xform(Transform3D(bas, rail_mid - nrm * 0.02), Vector3(0.07, 0.34, ell + 0.05), T.trim, MPA)
	var hr0 := rail_start + Vector3.UP * RAIL_H
	var hr1 := rail_start + dir * Lf + Vector3.UP * (Hh + RAIL_H)
	batch.add_cylinder_between(hr0 - dir * 0.12 - Vector3.UP * 0.12 * slope, hr1 + dir * 0.12 + Vector3.UP * 0.12 * slope, 0.036, C_WOOD, MW)
	batch.add_cylinder_between(rail_start + Vector3.UP * (r + 0.1), rail_start + dir * Lf + Vector3.UP * (Hh + r + 0.1), 0.016, post_col, post_mat)
	for i in n:
		for j in 2:
			var s := i * t + t * (0.28 + j * 0.44)
			var base_y := (i + 1) * r + 0.012
			var bp := rail_start + dir * s + Vector3.UP * base_y
			var top_h := RAIL_H + s * slope - base_y
			batch.add_cylinder(bp + Vector3.UP * (top_h * 0.5), 0.014, top_h, post_col, Basis(), post_mat)
			batch.add_sphere(bp + Vector3.UP * (top_h * 0.32), 0.026, C_BRASS if iron else post_col, MMET if iron else post_mat)
			batch.add_box(bp + Vector3.UP * 0.03, Vector3(0.04, 0.06, 0.04), post_col, post_mat)
	for e in 2:
		var pp := rail_start + dir * (Lf * e) + Vector3.UP * (Hh * e)
		var ph := RAIL_H + 0.12
		batch.add_box(pp + Vector3.UP * (ph * 0.5), Vector3(0.11, ph, 0.11), C_WOOD, MW)
		batch.add_box(pp + Vector3.UP * (ph + 0.02), Vector3(0.14, 0.04, 0.14), C_WOOD.darkened(0.1), MW)
		batch.add_sphere(pp + Vector3.UP * (ph + 0.09), 0.065, C_BRASS, MMET)
	var wsign := signf(start.x)
	var wall_x := wsign * (X_out - 0.07)
	var w0 := Vector3(wall_x, start.y, start.z) + Vector3.UP * 0.92
	var w1 := w0 + dir * Lf + Vector3.UP * Hh
	batch.add_cylinder_between(w0, w1, 0.025, C_WOOD, MW)
	for bi in 3:
		var bp2 := w0.lerp(w1, 0.15 + bi * 0.35)
		batch.add_cylinder_between(bp2, bp2 + Vector3(wsign * 0.07, 0, 0), 0.01, C_BRASS, MMET)
	var dado_c := Vector3(wsign * (X_out - 0.006), start.y, start.z) + dir * (Lf * 0.5) + Vector3.UP * (Hh * 0.5 + 0.42)
	batch.add_box_xform(Transform3D(Basis(Vector3.RIGHT, -dz * a), dado_c), Vector3(0.012, 0.8, ell), T.dado, MPA)
	batch.add_box_xform(Transform3D(Basis(Vector3.RIGHT, -dz * a), dado_c + Vector3(-wsign * 0.012, 0.42, 0)), Vector3(0.03, 0.05, ell), T.trim, MPA)


## Eski Türk apartmanı: mozaik basamak ve rıht, koyu mermer basamak burnu, mozaik
## süpürgelik, düz demir parmaklıklı korkuluk, koyu plastik küpeşte, yağlı boyalı duvar.
func _flight_visual_turkish(g: Dictionary) -> void:
	var start: Vector3 = g.start
	var dir: Vector3 = g.dir
	var dz := float(g.dz)
	var ell := float(g.ell)
	var a := float(g.a)
	var nrm: Vector3 = g.nrm
	var bas: Basis = g.bas
	var slope := float(g.slope)
	var rail_start: Vector3 = g.rail_start
	var rail_mid: Vector3 = g.rail_mid
	var step_col: Color = T.floor
	for i in n:
		var top := (i + 1) * r
		var hgt := r + 0.12
		var c := start + dir * (i * t + t * 0.5) + Vector3.UP * (top - hgt * 0.5)
		batch.add_box(c, Vector3(sw, hgt, t + 0.01), step_col, MTZ)
		# Koyu mermer basamak burnu ve kaymaz şerit
		batch.add_box(start + dir * (i * t - 0.008) + Vector3.UP * (top - 0.02), Vector3(sw, 0.04, 0.06), Color("8d8a86"), MM)
		batch.add_box(start + dir * (i * t + 0.05) + Vector3.UP * (top + 0.002), Vector3(sw - 0.1, 0.004, 0.03), Color("5c5955"), MM)
		# Rıht (dikey yüz) biraz daha koyu mozaik
		batch.add_box(start + dir * (i * t - 0.004) + Vector3.UP * (top - r * 0.5 - 0.02), Vector3(sw, r - 0.04, 0.008), step_col.darkened(0.12), MTZ)
	# Alt yüz: badanalı sıva
	var under_c := start + dir * (Lf * 0.5) + Vector3.UP * (Hh * 0.5) - nrm * 0.2
	batch.add_box_xform(Transform3D(bas, under_c), Vector3(sw, 0.16, ell), Color("f1ece2"))
	# Boşluk tarafı: mozaik kaplı yan kiriş
	batch.add_box_xform(Transform3D(bas, rail_mid - nrm * 0.03), Vector3(0.09, 0.3, ell + 0.05), step_col.darkened(0.05), MTZ)
	# Demir korkuluk: alt ve üst lama, düz dikey parmaklıklar, her 4'te bir kıvrımlı süs
	var bot0 := rail_start + Vector3.UP * (r + 0.08)
	var bot1 := rail_start + dir * Lf + Vector3.UP * (Hh + r + 0.08)
	var top0 := rail_start + Vector3.UP * (RAIL_H - 0.05)
	var top1 := rail_start + dir * Lf + Vector3.UP * (Hh + RAIL_H - 0.05)
	var lama_len := bot0.distance_to(bot1)
	batch.add_box_xform(Transform3D(bas, (bot0 + bot1) * 0.5), Vector3(0.03, 0.012, lama_len), C_IRON_RAIL, MMET)
	batch.add_box_xform(Transform3D(bas, (top0 + top1) * 0.5), Vector3(0.035, 0.014, lama_len + 0.06), C_IRON_RAIL, MMET)
	var count := int(Lf / 0.12)
	for i in count + 1:
		var s := float(i) / count * Lf
		var y0 := r + 0.08 + s * slope
		var y1 := RAIL_H - 0.05 + s * slope
		var bp := rail_start + dir * s
		batch.add_box(bp + Vector3.UP * ((y0 + y1) * 0.5), Vector3(0.016, y1 - y0, 0.016), C_IRON_RAIL, MMET)
		if i % 4 == 2:
			batch.add_cylinder(bp + Vector3.UP * ((y0 + y1) * 0.5) + dir * 0.06, 0.045, 0.012, C_IRON_RAIL, Basis(Vector3.FORWARD, PI * 0.5), MMET)
	# Plastik küpeşte (koyu kahve, yuvarlak)
	batch.add_cylinder_between(top0 + Vector3.UP * 0.05 - dir * 0.08 - Vector3.UP * 0.08 * slope, top1 + Vector3.UP * 0.05 + dir * 0.08 + Vector3.UP * 0.08 * slope, 0.03, C_HANDRAIL_PVC, MPA)
	# Uçlarda kare demir dikme
	for e in 2:
		var pp := rail_start + dir * (Lf * e) + Vector3.UP * (Hh * e)
		batch.add_box(pp + Vector3.UP * (RAIL_H * 0.5), Vector3(0.035, RAIL_H, 0.035), C_IRON_RAIL, MMET)
	# Duvar tarafı: mozaik süpürgelik ve yağlı boya (eğimli)
	var wsign := signf(start.x)
	var rot := Basis(Vector3.RIGHT, -dz * a)
	var base_c := Vector3(wsign * (X_out - 0.01), start.y, start.z) + dir * (Lf * 0.5) + Vector3.UP * (Hh * 0.5 + 0.1)
	batch.add_box_xform(Transform3D(rot, base_c), Vector3(0.02, 0.16, ell), step_col.darkened(0.08), MTZ)
	var paint_c := Vector3(wsign * (X_out - 0.006), start.y, start.z) + dir * (Lf * 0.5) + Vector3.UP * (Hh * 0.5 + 0.65)
	batch.add_box_xform(Transform3D(rot, paint_c), Vector3(0.012, 1.2, ell), T.dado, MPA)
	batch.add_box_xform(Transform3D(rot, paint_c + Vector3(-wsign * 0.004, 0.61, 0)), Vector3(0.014, 0.025, ell), T.dado.darkened(0.35), MPA)


## Düz korkuluk (sahanlık kenarı)
func _rail_straight(p0: Vector3, p1: Vector3) -> void:
	var length := p0.distance_to(p1)
	if length < 0.05:
		return
	var mid := (p0 + p1) * 0.5
	var along_x := absf(p1.x - p0.x) > absf(p1.z - p0.z)
	var size := Vector3(length, RAIL_H, 0.06) if along_x else Vector3(0.06, RAIL_H, length)
	_shape_box(Transform3D(Basis(), mid + Vector3.UP * (RAIL_H * 0.5)), size)
	if turk:
		_rail_straight_turkish(p0, p1, length, along_x)
		return
	var iron := bool(T.get("iron", false))
	var post_col := C_IRON if iron else C_WHITE_PAINT
	var post_mat := MMET if iron else MPA
	batch.add_cylinder_between(p0 + Vector3.UP * RAIL_H, p1 + Vector3.UP * RAIL_H, 0.036, C_WOOD, MW)
	batch.add_cylinder_between(p0 + Vector3.UP * 0.1, p1 + Vector3.UP * 0.1, 0.016, post_col, post_mat)
	var count := maxi(2, int(length / 0.13))
	for i in count + 1:
		var p := p0.lerp(p1, float(i) / count)
		batch.add_cylinder(p + Vector3.UP * (RAIL_H * 0.5), 0.014, RAIL_H, post_col, Basis(), post_mat)
		batch.add_sphere(p + Vector3.UP * (RAIL_H * 0.32), 0.026, C_BRASS if iron else post_col, MMET if iron else post_mat)
	for e: Vector3 in [p0, p1]:
		batch.add_box(e + Vector3.UP * 0.56, Vector3(0.1, 1.12, 0.1), C_WOOD, MW)
		batch.add_sphere(e + Vector3.UP * 1.17, 0.06, C_BRASS, MMET)


## Türk apartmanı sahanlık korkuluğu: lama + düz demir parmaklık + plastik küpeşte.
func _rail_straight_turkish(p0: Vector3, p1: Vector3, length: float, along_x: bool) -> void:
	var mid := (p0 + p1) * 0.5
	var lama := Vector3(length, 0.012, 0.03) if along_x else Vector3(0.03, 0.012, length)
	batch.add_box(mid + Vector3.UP * 0.08, lama, C_IRON_RAIL, MMET)
	batch.add_box(mid + Vector3.UP * (RAIL_H - 0.05), lama, C_IRON_RAIL, MMET)
	batch.add_cylinder_between(p0 + Vector3.UP * RAIL_H, p1 + Vector3.UP * RAIL_H, 0.03, C_HANDRAIL_PVC, MPA)
	var count := maxi(2, int(length / 0.12))
	for i in count + 1:
		var p := p0.lerp(p1, float(i) / count)
		batch.add_box(p + Vector3.UP * (RAIL_H * 0.5 + 0.015), Vector3(0.016, RAIL_H - 0.13, 0.016), C_IRON_RAIL, MMET)
	for e: Vector3 in [p0, p1]:
		batch.add_box(e + Vector3.UP * (RAIL_H * 0.5), Vector3(0.035, RAIL_H, 0.035), C_IRON_RAIL, MMET)


func _deco_door(side: float, y: float, text: String) -> void:
	if turk:
		_deco_door_turkish(side, y, text)
		return
	var x := side * (X_out - 0.02)
	var zc := z0 * 0.5
	var dcol: Color = T.door
	batch.add_box(Vector3(x, y + 1.06, zc), Vector3(0.05, 2.14, 1.08), T.trim, MPA)
	batch.add_box(Vector3(x - side * 0.01, y + 1.02, zc), Vector3(0.04, 2.04, 0.92), dcol, MW)
	# Kapı panelleri
	for pz: float in [-0.2, 0.2]:
		batch.add_box(Vector3(x - side * 0.03, y + 1.45, zc + pz), Vector3(0.01, 0.7, 0.3), dcol.lightened(0.12), MW)
		batch.add_box(Vector3(x - side * 0.03, y + 0.55, zc + pz), Vector3(0.01, 0.6, 0.3), dcol.lightened(0.12), MW)
	batch.add_sphere(Vector3(x - side * 0.05, y + 1.0, zc + 0.36), 0.035, C_BRASS, MMET)
	batch.add_box(Vector3(x - side * 0.035, y + 1.62, zc), Vector3(0.01, 0.1, 0.18), C_BRASS, MMET)
	batch.add_box(Vector3(x - side * 0.4, y + 0.006, zc), Vector3(0.5, 0.012, 0.8), Color("6b4f3a"), MC)
	_label(text, Vector3(x - side * 0.042, y + 1.62, zc), -side * PI * 0.5, 36, Color("3a2a10"))


## Eski Türk apartmanı daire kapısı: ahşap kaplama kapı, koyu pervaz, kapı dürbünü, pirinç
## kol ve isimlik, yanında zil, önünde paspas ve çıkarılmış ayakkabılar.
func _deco_door_turkish(side: float, y: float, text: String) -> void:
	var x := side * (X_out - 0.02)
	var zc := z0 * 0.5
	var dcol: Color = T.door
	var face := -side   # sahanlığa bakan yön (x)
	batch.add_box(Vector3(x, y + 1.06, zc), Vector3(0.05, 2.14, 1.08), dcol.darkened(0.25), MW)
	batch.add_box(Vector3(x + face * 0.01, y + 1.02, zc), Vector3(0.04, 2.04, 0.92), dcol, MW)
	for i in 5:
		batch.add_box(Vector3(x + face * 0.032, y + 0.35 + i * 0.36, zc), Vector3(0.004, 0.012, 0.86), dcol.darkened(0.2), MW)
	batch.add_cylinder(Vector3(x + face * 0.035, y + 1.55, zc), 0.016, 0.01, Color("2a2a2a"), Basis(Vector3.FORWARD, PI * 0.5), MMET)
	batch.add_box(Vector3(x + face * 0.05, y + 1.0, zc + 0.33), Vector3(0.03, 0.025, 0.14), C_BRASS, MMET)
	batch.add_box(Vector3(x + face * 0.035, y + 1.0, zc + 0.36), Vector3(0.012, 0.18, 0.05), C_BRASS, MMET)
	batch.add_box(Vector3(x + face * 0.034, y + 1.3, zc), Vector3(0.008, 0.08, 0.22), C_BRASS, MMET)
	_label(text, Vector3(x + face * 0.04, y + 1.3, zc), -side * PI * 0.5, 30, Color("3a2a10"))
	# Zil (kapının yanında)
	batch.add_box(Vector3(side * (X_out - 0.005), y + 1.35, zc - 0.62), Vector3(0.01, 0.09, 0.07), Color("f2f0ea"), MPA)
	glow.add_sphere(Vector3(side * (X_out - 0.012), y + 1.35, zc - 0.62), 0.014, Color("ffb347"))
	# Paspas ve çıkarılmış ayakkabılar
	batch.add_box(Vector3(x + face * 0.4, y + 0.007, zc), Vector3(0.45, 0.014, 0.75), Color("7a5a3a"), MC)
	var shoe_cols := [Color("2b2b2b"), Color("8b4513"), Color("e8e8e8"), Color("c0392b")]
	for i in 2:
		var sc: Color = shoe_cols[rng.randi() % shoe_cols.size()]
		for j in 2:
			batch.add_box(Vector3(x + face * 0.3, y + 0.04, zc - 0.25 + i * 0.32 + j * 0.11), Vector3(0.24, 0.07, 0.09), sc, MPA)


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
	var goal := str(L.goal)
	var item := ItemDB.get_item(str(L.item))
	var style := _room_style(str(L.item))

	# Koridor 1: merdivenden dışarı doğru (x ekseni)
	var c1 := _rect(minf(xw, x_end), maxf(xw, x_end), zc - cw * 0.5, zc + cw * 0.5)
	var near1 := "xp" if sx < 0 else "xn"
	var far1 := "xn" if sx < 0 else "xp"
	var walls1 := {"zn": {}, "zp": {}}
	walls1[near1] = null
	walls1[far1] = null
	_room_box(c1, y, cc, walls1, C_WOOD_LIGHT, MW, Color.WHITE, MWP, true)
	# Eşik (merdiven duvarı kalınlığı) ve "Welcome" paspası
	box_mm(Vector3(sx * X_out, y - SLAB, zc - float(L.apt_door.x) * 0.5), Vector3(xw, y, zc + float(L.apt_door.x) * 0.5), C_WOOD.darkened(0.1), true, MW)
	batch.add_box(Vector3(sx * (X_out - 0.45), y + 0.007, zc), Vector3(0.55, 0.014, 0.85), Color("7a4a2a"), MC)
	var mat_lb := _label("WELCOME", Vector3(sx * (X_out - 0.45), y + 0.016, zc), 0.0, 30, Color("f2d49b"), false)
	mat_lb.rotation = Vector3(-PI * 0.5, -sx * PI * 0.5, 0.0)   # yere yatık, merdivenden okunur
	# Açık daire kapısı (koridor içinde duvara yaslı)
	var door_w := float(L.apt_door.x)
	var dcol: Color = T.door
	var dp := Vector3(xw + sx * (door_w * 0.5 + 0.02), y + 1.02, zc + cw * 0.5 - 0.03)
	batch.add_box(dp, Vector3(door_w - 0.06, 2.04, 0.045), dcol, MW)
	batch.add_sphere(dp + Vector3(sx * (door_w * 0.5 - 0.12), 0.0, -0.04), 0.035, C_BRASS, MMET)
	anchors["corridor"] = {"pos": Vector3((xw + x_end) * 0.5, y, zc), "along": Vector3.RIGHT, "side": Vector3.BACK, "width": cw, "length": cl, "ceil": y + cc}
	# Hedef dairenin tabelası kesit görünümünde de görünür kalır (yol gösterir).
	_label("APT %d" % (F * 10 + 1), Vector3(sx * (X_out - 0.02), y + float(L.apt_door.y) + 0.25, zc), -sx * PI * 0.5, 48, T.dado, false)
	_add_light(Vector3((xw + x_end) * 0.5, y + cc - 0.3, zc), 0.9, 5.0)
	# Koridor duvarında tablo ve askılık (dekor)
	_picture(Vector3((xw + x_end) * 0.5, y + 1.45, zc + cw * 0.5 - 0.015), 0.0)
	_corridor_decor(y, cc, sx, xw, x_end, zc, cw, door_w)

	var room: Dictionary
	var door_side: String
	var far_side: String
	if turn == "none":
		var rz0 := maxf(zc - rw * 0.5, 0.2)
		room = _rect(minf(x_end, x_end + sx * rd), maxf(x_end, x_end + sx * rd), rz0, rz0 + rw)
		door_side = near1
		far_side = far1
		var walls_r := {"xn": {}, "xp": {}, "zn": {}, "zp": {}}
		walls_r[door_side] = {"c": zc, "w": rdw, "y0": y, "y1": y + rdh}
		_room_box(room, y, room_h, walls_r, _style_floor(style), _style_floor_mat(style), _style_wall(style), _style_wall_mat(style))
		anchors["corridor2"] = anchors["corridor"]
	else:
		# Koridor 2: +Z yönüne döner
		var c2x0 := x_end
		var c2x1 := x_end + sx * cw
		var c2 := _rect(minf(c2x0, c2x1), maxf(c2x0, c2x1), zc - cw * 0.5, zc + cw * 0.5 + tl)
		var walls2 := {"zn": {}, "zp": null}
		walls2[far1] = {}
		walls2[near1] = {"c": zc, "w": cw, "y0": y, "y1": y + cc, "frame": false}
		_room_box(c2, y, cc, walls2, C_WOOD_LIGHT, MW, Color.WHITE, MWP, true)
		_corridor2_decor(c2, y, cc, sx, cw)
		var c2_center := Vector3((c2x0 + c2x1) * 0.5, y, (float(c2.z0) + float(c2.z1)) * 0.5)
		anchors["corridor2"] = {"pos": c2_center, "along": Vector3.BACK, "side": Vector3.RIGHT, "width": cw, "length": tl, "ceil": y + cc}
		_add_light(c2_center + Vector3(0, cc - 0.3, 0), 0.9, 5.0)
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
		room = _rect(rx0, rx1, float(c2.z1), float(c2.z1) + rd)
		door_side = "zn"
		far_side = "zp"
		_room_box(room, y, room_h, {"xn": {}, "xp": {}, "zp": {}, "zn": {"c": xm, "w": rdw, "y0": y, "y1": y + rdh}}, _style_floor(style), _style_floor_mat(style), _style_wall(style), _style_wall_mat(style))

	var rx0f := float(room.x0)
	var rx1f := float(room.x1)
	var rz0f := float(room.z0)
	var rz1f := float(room.z1)
	var rc := Vector3((rx0f + rx1f) * 0.5, y, (rz0f + rz1f) * 0.5)
	anchors["room"] = {"pos": rc, "along": Vector3.RIGHT, "side": Vector3.BACK, "width": rz1f - rz0f, "length": rx1f - rx0f, "ceil": y + room_h}
	_add_light(rc + Vector3(0, room_h - 0.4, 0), 1.4, 7.0)
	glow.add_sphere(rc + Vector3(0, room_h - 0.12, 0), 0.16, Color("fff1c8"))

	# Uzak duvar: içe bakan normal ve duvar üstündeki merkez nokta
	var inward := Vector3.ZERO
	var far_center := rc
	var along_wall := Vector3.ZERO
	var half_span := 0.0
	match far_side:
		"xn":
			inward = Vector3.RIGHT
			far_center = Vector3(rx0f, y, rc.z)
			along_wall = Vector3.BACK
			half_span = (rz1f - rz0f) * 0.5
		"xp":
			inward = Vector3.LEFT
			far_center = Vector3(rx1f, y, rc.z)
			along_wall = Vector3.BACK
			half_span = (rz1f - rz0f) * 0.5
		_:
			inward = Vector3.FORWARD
			far_center = Vector3(rc.x, y, rz1f)
			along_wall = Vector3.RIGHT
			half_span = (rx1f - rx0f) * 0.5

	# Pencere ve perdeler: normalde uzak duvarda; yerleştirme yuvalı odada yan duvarda
	var room_depth := (rx1f - rx0f) if absf(inward.x) > 0.5 else (rz1f - rz0f)
	var win_n := inward
	var win_c := far_center + along_wall * (half_span * 0.55) + inward * 0.012 + Vector3.UP * 1.5
	if goal == "spot":
		win_n = -along_wall
		win_c = far_center + inward * (room_depth * 0.5) + along_wall * (half_span - 0.012) + Vector3.UP * 1.5
	var win_along := win_n.cross(Vector3.UP).normalized()
	var win_size := Vector3(0.02, 1.0, 1.1) if absf(win_n.x) > 0.5 else Vector3(1.1, 1.0, 0.02)
	batch.add_box(win_c, win_size, C_GLASS, MG)
	batch.add_box(win_c + win_n * 0.03 + Vector3.UP * -0.52, Vector3(0.14, 0.05, 1.25) if absf(win_n.x) > 0.5 else Vector3(1.25, 0.05, 0.14), T.trim, MPA)
	for sgn: float in [-1.0, 1.0]:
		var cp := win_c + win_along * (0.68 * sgn) + win_n * 0.05 + Vector3.UP * (-0.15)
		var cs := Vector3(0.06, 1.5, 0.3) if absf(win_n.x) > 0.5 else Vector3(0.3, 1.5, 0.06)
		batch.add_box(cp, cs, T.awning, MF)
	_room_door_pt = Vector3(x_end, y, zc) if turn == "none" else Vector3((x_end + x_end + sx * cw) * 0.5, y, float(room.z0))
	_furnish(style, room, y, room_h, inward, far_center, along_wall, half_span, door_side, goal)
	_room_details(style, room, y, room_h, inward, far_center, along_wall, half_span, goal)
	# Pencere altında kalorifer peteği, üstünde korniş
	_radiator(win_c + win_n * 0.045 + Vector3.UP * (-1.05), win_along, win_n)
	batch.add_cylinder_between(win_c + win_n * 0.09 + Vector3.UP * 0.62 - win_along * 0.85, win_c + win_n * 0.09 + Vector3.UP * 0.62 + win_along * 0.85, 0.016, C_BRASS, MMET)

	# ---------------- Hedef bölge ve ev sahibi
	info.style = style
	info.goal_type = goal
	info.apt_door_pos = Vector3(sx * X_out, y, zc)
	info.corridor_end = Vector3((xw + x_end) * 0.5, y, zc) if turn == "none" else Vector3(anchors["corridor2"].pos)
	# Oda kapısının gerçek yeri (oda ortası değil): yol noktası ve yön oku için
	if turn == "none":
		info.room_door_pos = Vector3(x_end, y, zc)
	else:
		info.room_door_pos = Vector3((x_end + x_end + sx * cw) * 0.5, y, float(room.z0))
	var isize: Vector3 = item.size
	if goal == "door":
		# Daire kapısının önündeki sahanlık
		var xa := sx * X_out
		var xb := sx * (X_out - minf(1.5, X_out * 2.0 - 0.2))
		var zmin := maxf(0.05, zc - door_w * 0.5 - 0.4)
		var zmax := minf(z0 - 0.05, zc + door_w * 0.5 + 0.4)
		var gmin := Vector3(minf(xa, xb), y, zmin)
		var gmax := Vector3(maxf(xa, xb), y + 2.2, zmax)
		info.goal_aabb = AABB(gmin, gmax - gmin)
		info.goal_center = Vector3((gmin.x + gmax.x) * 0.5, y, (gmin.z + gmax.z) * 0.5)
		info.npc_pos = Vector3(xw + sx * 0.55, y, zc)
		info.npc_yaw = atan2(sx, 0.0)   # merdivene (−sx yönüne) bakar
	elif goal == "spot":
		var spot := far_center + inward * (isize.z * 0.5 + 0.06)
		var gsize := Vector3(isize.x + 0.24, 0.0, isize.z + 0.3)
		var gmin: Vector3
		var gmax: Vector3
		if absf(inward.x) > 0.5:
			gmin = Vector3(spot.x - gsize.z * 0.5, y, spot.z - gsize.x * 0.5)
			gmax = Vector3(spot.x + gsize.z * 0.5, y + 2.4, spot.z + gsize.x * 0.5)
		else:
			gmin = Vector3(spot.x - gsize.x * 0.5, y, spot.z - gsize.z * 0.5)
			gmax = Vector3(spot.x + gsize.x * 0.5, y + 2.4, spot.z + gsize.z * 0.5)
		info.goal_aabb = AABB(gmin, gmax - gmin)
		info.goal_center = Vector3(spot.x, y, spot.z)
		info.goal_facing = inward
		# Hayalet görüntü: eşyanın ön yüzü (-Z) odaya bakar
		info.spot_basis = Basis.looking_at(inward, Vector3.UP)
		info.spot_size = isize
		_spot_niche(far_center, inward, along_wall, isize, y, style)
		var npc := far_center + along_wall * (isize.x * 0.5 + 0.95) + inward * 1.1
		info.npc_pos = npc
		info.npc_yaw = atan2(-inward.x, -inward.z)   # odanın içine bakar
	else:
		var margin := 0.9
		var gmin := Vector3(rx0f + margin, y, rz0f + margin)
		var gmax := Vector3(rx1f - margin, y + 2.2, rz1f - margin)
		info.goal_aabb = AABB(gmin, gmax - gmin)
		info.goal_center = (gmin + gmax) * 0.5
		info.goal_center.y = y
		# Ev sahibi uzak duvar önünde, kitaplık ile TV ünitesi arasında (teslim alanının dışında)
		var npc2 := far_center + inward * 0.55 - along_wall * (half_span - 0.95)
		info.npc_pos = npc2
		info.npc_yaw = atan2(-inward.x, -inward.z)
	info.apt_aabb = AABB(Vector3(minf(rx0f, minf(xw, x_end)), y, minf(rz0f, zc - cw)), Vector3.ZERO).expand(Vector3(maxf(rx1f, maxf(xw, x_end)), y + room_h, maxf(rz1f, zc + cw)))
	apt = {"room": room, "y": y}


func _room_style(item_id: String) -> String:
	match item_id:
		"camasir":
			return "laundry"
		"buzdolabi":
			return "kitchen"
		"gardirop":
			return "bedroom"
	return "living"


func _style_floor(style: String) -> Color:
	match style:
		"laundry":
			return Color("dfe7ea")
		"kitchen":
			return Color("e8e2d4")
	return C_WOOD_LIGHT


func _style_floor_mat(style: String) -> int:
	return MT if style in ["laundry", "kitchen"] else MW


func _style_wall(style: String) -> Color:
	match style:
		"laundry":
			return Color("cfe8ef")
		"kitchen":
			return Color("fbf1dd")
		"bedroom":
			return Color("e9def3")
	return T.wallpaper


func _style_wall_mat(style: String) -> int:
	return MT if style == "laundry" else MWP


## Yerleştirme yuvası: eşyanın iki yanında dolap/tezgâh, ortası boş.
func _spot_niche(far_center: Vector3, inward: Vector3, along: Vector3, isize: Vector3, y: float, style: String) -> void:
	var gap_half := isize.x * 0.5 + 0.12
	var depth := maxf(0.55, isize.z + 0.05)
	var h := 0.9
	var side_w := 0.6
	var col := Color("f7f7f2")
	var top_col := Color("4a4e57")
	match style:
		"living":
			# Oturma odası: iki yanda alçak sehpa + abajur (koltuk/TV köşesi)
			col = Color("6b4630")
			top_col = Color("8a5a32")
			h = 0.55
			side_w = 0.45
			depth = minf(depth, 0.5)
		"bedroom":
			col = Color("a8774f")
			top_col = Color("8a5a32")
			h = 0.75
		"laundry":
			col = Color("ffffff")
			top_col = Color("9ab0bd")
		"kitchen":
			col = Color("3d7c98")
			top_col = Color("dcd6cc")
	for sgn: float in [-1.0, 1.0]:
		var c := far_center + inward * (depth * 0.5) + along * (sgn * (gap_half + side_w * 0.5)) + Vector3.UP * (h * 0.5)
		var size := Vector3(depth, h, side_w) if absf(inward.x) > 0.5 else Vector3(side_w, h, depth)
		solid(c, size, col, true, MW if style == "living" else MPA)
		var top_size := Vector3(depth + 0.03, 0.04, side_w + 0.02) if absf(inward.x) > 0.5 else Vector3(side_w + 0.02, 0.04, depth + 0.03)
		batch.add_box(c + Vector3.UP * (h * 0.5 + 0.02), top_size, top_col, MM)
		# Kapak tutamağı
		batch.add_box(c + inward * (depth * 0.5 + 0.01) + Vector3.UP * (h * 0.25), Vector3(0.02, 0.02, 0.14) if absf(inward.x) > 0.5 else Vector3(0.14, 0.02, 0.02), C_BRASS, MMET)
		if style == "living":
			# Abajur: ayak + kumaş şapka
			var lp := c + Vector3.UP * (h * 0.5 + 0.04)
			batch.add_cylinder_between(lp, lp + Vector3.UP * 0.32, 0.025, C_BRASS, MMET)
			props.add_cylinder(lp + Vector3.UP * 0.4, 0.15, 0.2, Color("f3e3c3"))
		# Üst dolap (mutfak/çamaşır)
		if style in ["kitchen", "laundry"]:
			var uc := far_center + inward * 0.18 + along * (sgn * (gap_half + 0.3)) + Vector3.UP * 1.75
			var us := Vector3(0.36, 0.6, 0.6) if absf(inward.x) > 0.5 else Vector3(0.6, 0.6, 0.36)
			batch.add_box(uc, us, col, MPA)
	# Yuva zemininde işaret çizgileri
	var mark := far_center + inward * (isize.z * 0.5 + 0.06) + Vector3.UP * 0.008
	var ms := Vector3(isize.z + 0.1, 0.004, isize.x + 0.1) if absf(inward.x) > 0.5 else Vector3(isize.x + 0.1, 0.004, isize.z + 0.1)
	batch.add_box(mark, ms, Color("ffd23f"), MPA)
	batch.add_box(mark + Vector3.UP * 0.002, ms - Vector3(0.06, 0, 0.06), _style_floor(style), _style_floor_mat(style))
	# Duvarda boru ve priz (çamaşır makinesi/buzdolabı için)
	if style in ["kitchen", "laundry"]:
		batch.add_box(far_center + inward * 0.012 + Vector3.UP * 0.45, Vector3(0.02, 0.1, 0.07) if absf(inward.x) > 0.5 else Vector3(0.07, 0.1, 0.02), Color("ffffff"), MPA)
		batch.add_cylinder_between(far_center + inward * 0.03 + along * 0.15 + Vector3.UP * 0.2, far_center + inward * 0.03 + along * 0.15 + Vector3.UP * 0.9, 0.02, Color("c0c4c8"), MMET)


## Odayı stile göre döşer (eşyalar duvar kenarlarında, ortası boş kalır).
func _furnish(style: String, room: Dictionary, y: float, room_h: float, inward: Vector3, far_center: Vector3, along: Vector3, half_span: float, door_side: String, goal: String) -> void:
	var rx0 := float(room.x0)
	var rx1 := float(room.x1)
	var rz0 := float(room.z0)
	var rz1 := float(room.z1)
	var rc := Vector3((rx0 + rx1) * 0.5, y, (rz0 + rz1) * 0.5)
	# Halı
	var rug_col: Color = T.carpet if style == "living" else Color("e8c07d")
	if style != "laundry":
		batch.add_box(rc + Vector3(0, 0.006, 0), Vector3((rx1 - rx0) * 0.5, 0.012, (rz1 - rz0) * 0.5), rug_col, MC)
	# Yan duvar boyunca kitaplık (uzak duvara yakın köşede)
	var shelf_c := far_center + inward * 0.75 - along * (half_span - 0.2)
	var shelf_size := Vector3(0.9, 1.6, 0.34) if absf(inward.x) > 0.5 else Vector3(0.34, 1.6, 0.9)
	if style == "living" or style == "bedroom":
		solid(shelf_c + Vector3.UP * 0.8, shelf_size, Color("8a5a32"), true, MW)
		for sh in 4:
			for bk in 5:
				var bp := shelf_c + Vector3.UP * (0.25 + sh * 0.38) + inward * ((bk - 2) * 0.15) + along * 0.1
				batch.add_box(bp, Vector3(0.08, 0.26, 0.2) if absf(inward.x) > 0.5 else Vector3(0.2, 0.26, 0.08), FLOWER_COLORS[(sh * 5 + bk) % FLOWER_COLORS.size()].darkened(0.15), MPA)
	# Köşede saksı bitkisi
	var plant_p := far_center + inward * 0.45 + along * (half_span - 0.45)
	props.add_cylinder(plant_p + Vector3.UP * 0.22, 0.2, 0.44, C_POT)
	props.add_sphere(plant_p + Vector3.UP * 0.75, 0.34, C_LEAVES)
	props.add_sphere(plant_p + Vector3(0.1, 1.0, 0.05), 0.22, C_LEAVES.lightened(0.1))
	_shape_cyl(plant_p + Vector3.UP * 0.55, 0.24, 1.1)
	if goal != "spot":
		# Yuvasız odalarda uzak duvar önüne alçak dolap (TV ünitesi vb.)
		var unit_c := far_center + inward * 0.22 + Vector3.UP * 0.25
		var unit_s := Vector3(0.4, 0.5, 1.4) if absf(inward.x) > 0.5 else Vector3(1.4, 0.5, 0.4)
		solid(unit_c, unit_s, Color("5b3a29"), true, MW)
		batch.add_sphere(unit_c + Vector3.UP * 0.35, 0.12, FLOWER_COLORS[0], MPA)
	if style == "laundry":
		# Çamaşır sepeti ve deterjan rafı
		var basket := far_center + inward * 0.9 - along * (half_span - 0.35)
		props.add_cylinder(basket + Vector3.UP * 0.25, 0.24, 0.5, Color("e9c46a"))
		_shape_cyl(basket + Vector3.UP * 0.25, 0.26, 0.5)
		for i in 4:
			batch.add_box(far_center + inward * 0.12 - along * (half_span - 0.6 - i * 0.16) + Vector3.UP * 1.62, Vector3(0.12, 0.22, 0.12), FLOWER_COLORS[i], MPA)
	if style == "kitchen":
		batch.add_box(far_center + inward * 0.12 - along * (half_span - 0.6) + Vector3.UP * 1.5, Vector3(0.18, 0.18, 0.18) if absf(inward.x) > 0.5 else Vector3(0.18, 0.18, 0.18), Color("ffffff"), MPA)
	if style == "bedroom":
		# Yatak (yan duvara yaslı)
		var bed_c := rc - inward * (absf(rz1 - rz0) * 0.0) + along * (half_span - 0.85) - inward * 0.6
		var bed_s := Vector3(2.0, 0.45, 1.3) if absf(inward.x) > 0.5 else Vector3(1.3, 0.45, 2.0)
		solid(bed_c + Vector3.UP * 0.225, bed_s, Color("f4f1ea"), true, MF)
		batch.add_box(bed_c + Vector3.UP * 0.47, bed_s * Vector3(0.98, 0.1, 0.98), T.awning, MF)


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


## Daire koridoru (x ekseni boyunca): kilim yolluk, portmanto ve montlar, ayna, diafon,
## sigorta kutusu, ışık anahtarı, kapı üstünde nazar boncuğu, tavan lambası. Hepsi duvara yapışık.
func _corridor_decor(y: float, cc: float, sx: float, xw: float, x_end: float, zc: float, cw: float, door_w: float) -> void:
	var cl := absf(x_end - xw)
	var mid := (xw + x_end) * 0.5
	var zw := zc - cw * 0.5          # karşı duvar (montlar, ayna) iç yüzü
	# Kilim yolluk: kenar şeridi, zemin, baklava desenleri, uçlarda püsküller
	var rl := maxf(0.6, cl - 0.5)
	var rwid := cw * 0.55
	batch.add_box(Vector3(mid, y + 0.005, zc), Vector3(rl, 0.01, rwid), Color("e3c07a"), MC)
	batch.add_box(Vector3(mid, y + 0.009, zc), Vector3(rl - 0.1, 0.01, rwid - 0.1), Color("8e2b2b"), MC)
	var nd := int(rl / 0.45)
	for i in nd:
		var px := mid - rl * 0.5 + (i + 0.5) * rl / nd
		var c: Color = Color("1f4e79") if i % 2 == 0 else Color("f2e6c9")
		batch.add_box_xform(Transform3D(Basis(Vector3.UP, PI * 0.25), Vector3(px, y + 0.013, zc)), Vector3(0.16, 0.01, 0.16), c, MC)
		batch.add_box_xform(Transform3D(Basis(Vector3.UP, PI * 0.25), Vector3(px, y + 0.016, zc)), Vector3(0.06, 0.01, 0.06), Color("e3c07a"), MC)
	for e: float in [-1.0, 1.0]:
		for t in 7:
			batch.add_box(Vector3(mid + e * (rl * 0.5 + 0.025), y + 0.004, zc - rwid * 0.4 + t * rwid * 0.8 / 6.0), Vector3(0.05, 0.008, 0.012), Color("f2e6c9"), MC)
	# Portmanto: ahşap tahta, pirinç askılar, iki mont ve bir şapka (kapıya yakın)
	var hx := xw + sx * minf(0.75, cl * 0.3)
	batch.add_box(Vector3(hx, y + 1.72, zw + 0.012), Vector3(0.75, 0.1, 0.024), C_WOOD, MW)
	for i in 4:
		var kx := hx + (i - 1.5) * 0.18
		batch.add_cylinder_between(Vector3(kx, y + 1.72, zw + 0.024), Vector3(kx, y + 1.75, zw + 0.08), 0.008, C_BRASS, MMET)
	var coat_cols := [Color("2f3e55"), Color("7a2e2e"), Color("5b6b3a"), Color("3b3b3b")]
	for i in 2:
		var cx := hx + (i * 2 - 1) * 0.18
		var ccol: Color = coat_cols[(rng.randi() + i) % coat_cols.size()]
		batch.add_box(Vector3(cx, y + 1.35, zw + 0.06), Vector3(0.36, 0.72, 0.07), ccol, MF)
		batch.add_box(Vector3(cx, y + 1.68, zw + 0.07), Vector3(0.2, 0.06, 0.06), ccol.darkened(0.15), MF)
		batch.add_box(Vector3(cx - 0.12, y + 1.25, zw + 0.06), Vector3(0.09, 0.6, 0.06), ccol.darkened(0.08), MF)
		batch.add_box(Vector3(cx + 0.12, y + 1.25, zw + 0.06), Vector3(0.09, 0.6, 0.06), ccol.darkened(0.08), MF)
	batch.add_sphere(Vector3(hx + 0.27, y + 1.76, zw + 0.08), 0.09, Color("c9a77c"), MF, Vector3(1.0, 0.6, 1.0))
	# Diafon (ahize) ve ışık anahtarı: kapının hemen yanında
	var ix := xw + sx * 0.2
	batch.add_box(Vector3(ix, y + 1.45, zw + 0.02), Vector3(0.11, 0.22, 0.04), Color("efeae0"), MPA)
	batch.add_box(Vector3(ix, y + 1.47, zw + 0.05), Vector3(0.05, 0.18, 0.025), Color("e2ddd2"), MPA)
	batch.add_box(Vector3(ix, y + 1.37, zw + 0.042), Vector3(0.04, 0.02, 0.01), Color("3a3a3a"), MPA)
	batch.add_box(Vector3(ix, y + 1.08, zw + 0.008), Vector3(0.08, 0.11, 0.016), Color("f7f6f2"), MPA)
	batch.add_box(Vector3(ix, y + 1.08, zw + 0.018), Vector3(0.025, 0.04, 0.01), Color("dcd8cf"), MPA)
	# Sigorta kutusu (kapının üst tarafında)
	if cc > 2.1:
		var fy := y + minf(cc - 0.32, 1.95)
		var fx := xw + sx * minf(1.35, cl * 0.55)
		batch.add_box(Vector3(fx, fy, zw + 0.03), Vector3(0.32, 0.36, 0.06), Color("ece6d8"), MPA)
		batch.add_box(Vector3(fx, fy, zw + 0.062), Vector3(0.26, 0.3, 0.006), Color("dcd5c4"), MPA)
		batch.add_box(Vector3(fx + 0.1, fy, zw + 0.068), Vector3(0.02, 0.06, 0.01), Color("8a8f96"), MMET)
	# Ayna (yaldızlı çerçeve) koridorun ortasında
	if cl > 2.2:
		var mx := mid + sx * 0.55
		batch.add_box(Vector3(mx, y + 1.45, zw + 0.012), Vector3(0.5, 0.8, 0.024), Color("c9a23a"), MMET)
		batch.add_box(Vector3(mx, y + 1.45, zw + 0.026), Vector3(0.42, 0.72, 0.006), Color("dfe9ee"), MMET)
		batch.add_box(Vector3(mx - 0.08, y + 1.6, zw + 0.03), Vector3(0.05, 0.3, 0.002), Color("ffffff"), MG)
	# Nazar boncuğu: kapının iç üstünde
	var dtop := float(L.apt_door.y)
	if cc - dtop > 0.3:
		var nb := Vector3(xw + sx * 0.012, y + dtop + 0.17, zc)
		var ax := Basis(Vector3.FORWARD, PI * 0.5)
		batch.add_cylinder(nb, 0.075, 0.012, Color("1f4fa8"), ax, MG)
		batch.add_cylinder(nb + Vector3(sx * 0.004, 0, 0), 0.052, 0.012, Color("ffffff"), ax, MPA)
		batch.add_cylinder(nb + Vector3(sx * 0.008, 0, 0), 0.035, 0.012, Color("6fb7ea"), ax, MG)
		batch.add_cylinder(nb + Vector3(sx * 0.012, 0, 0), 0.016, 0.012, Color("111111"), ax, MPA)
		batch.add_cylinder_between(nb + Vector3(0, 0.075, 0), nb + Vector3(0, 0.16, 0), 0.004, Color("c0392b"), MF)
	# Tavan lambası (yassı opal kubbe + pirinç halka)
	batch.add_cylinder(Vector3(mid, y + cc - 0.012, zc), 0.17, 0.024, C_BRASS, Basis(), MMET)
	glow.add_sphere(Vector3(mid, y + cc - 0.04, zc), 0.15, Color("fff3d6"))


## Dönen koridor (z ekseni boyunca): yolluk, tablo, duvar rafı.
func _corridor2_decor(c2: Dictionary, y: float, cc: float, sx: float, cw: float) -> void:
	var xm := (float(c2.x0) + float(c2.x1)) * 0.5
	var zs := float(c2.z0) + cw
	var ze := float(c2.z1)
	var rl := ze - zs - 0.3
	if rl < 0.6:
		return
	var zm := (zs + ze) * 0.5
	batch.add_box(Vector3(xm, y + 0.005, zm), Vector3(cw * 0.55, 0.01, rl), Color("e3c07a"), MC)
	batch.add_box(Vector3(xm, y + 0.009, zm), Vector3(cw * 0.55 - 0.1, 0.01, rl - 0.1), Color("1f4e79"), MC)
	var nd := int(rl / 0.45)
	for i in nd:
		var pz := zm - rl * 0.5 + (i + 0.5) * rl / nd
		batch.add_box_xform(Transform3D(Basis(Vector3.UP, PI * 0.25), Vector3(xm, y + 0.013, pz)), Vector3(0.15, 0.01, 0.15), Color("c0392b") if i % 2 == 0 else Color("f2e6c9"), MC)
	# Dış (uzak) duvar: tablo ve küçük duvar rafı (biblolar)
	var xf := float(c2.x1) if sx > 0 else float(c2.x0)
	var nrm := -sx
	_picture_x(Vector3(xf + nrm * 0.015, y + 1.5, zm - 0.3), nrm)
	var sp := Vector3(xf + nrm * 0.08, y + 1.15, zm + 0.45)
	batch.add_box(sp, Vector3(0.16, 0.03, 0.5), C_WOOD, MW)
	batch.add_cylinder(sp + Vector3(0, 0.08, -0.15), 0.035, 0.13, Color("1f4fa8"), Basis(), MG)
	batch.add_sphere(sp + Vector3(0, 0.06, 0.05), 0.045, Color("c0392b"), MPA)
	batch.add_box(sp + Vector3(0, 0.07, 0.17), Vector3(0.04, 0.12, 0.1), Color("d6a93a"), MMET)
	batch.add_cylinder(Vector3(xm, y + cc - 0.012, zm), 0.17, 0.024, C_BRASS, Basis(), MMET)
	glow.add_sphere(Vector3(xm, y + cc - 0.04, zm), 0.15, Color("fff3d6"))


## X duvarına (yan duvar) asılı tablo; n = odaya bakan x yönü (±1).
func _picture_x(p: Vector3, n: float, w: float = 0.5, h: float = 0.4) -> void:
	batch.add_box(p, Vector3(0.025, h, w), C_WOOD, MW)
	var c1: Color = FLOWER_COLORS[rng.randi() % FLOWER_COLORS.size()]
	batch.add_box(p + Vector3(n * 0.014, h * 0.12, 0), Vector3(0.004, h * 0.5, w - 0.08), Color("87ceeb"), MPA)
	batch.add_box(p + Vector3(n * 0.014, -h * 0.22, 0), Vector3(0.004, h * 0.3, w - 0.08), Color("6db35a"), MPA)
	batch.add_sphere(p + Vector3(n * 0.016, h * 0.2, w * 0.2), 0.04, c1, MPA)


## Duvara (normal n) asılı tablo, herhangi bir yönde; manzara + güneş.
func _picture_n(p: Vector3, n: Vector3, w: float, h: float) -> void:
	var b := Basis.looking_at(n, Vector3.UP)   # yerel -Z odaya bakar
	var xf := Transform3D(b, p)
	batch.add_box_xform(xf, Vector3(w, h, 0.03), Color("6b4630"), MW)
	batch.add_box_xform(xf * Transform3D(Basis(), Vector3(0, h * 0.12, -0.017)), Vector3(w - 0.1, h * 0.5, 0.004), Color("f4b183"), MPA)
	batch.add_box_xform(xf * Transform3D(Basis(), Vector3(0, -h * 0.22, -0.017)), Vector3(w - 0.1, h * 0.3, 0.004), Color("4f8a8b"), MPA)
	batch.add_sphere(xf * Vector3(w * 0.22, h * 0.2, -0.02), h * 0.09, Color("ffd23f"), MPA)


## Kalorifer peteği: dilimli panel, alt ve üst borular, vana. c = merkez, a = duvar boyunca, n = odaya bakan normal.
func _radiator(c: Vector3, a: Vector3, n: Vector3) -> void:
	var b := Basis(a, Vector3.UP, n)
	var xf := Transform3D(b, c)
	solid_xf(xf, Vector3(0.9, 0.5, 0.06), Color("f2f1ec"), true, MPA)
	for i in 13:
		batch.add_box_xform(xf * Transform3D(Basis(), Vector3(-0.42 + i * 0.07, 0, 0.035)), Vector3(0.04, 0.5, 0.02), Color("fbfaf6"), MPA)
	batch.add_cylinder_between(xf * Vector3(-0.5, -0.22, 0.0), xf * Vector3(0.5, -0.22, 0.0), 0.016, Color("e8e6df"), MMET)
	batch.add_cylinder_between(xf * Vector3(0.5, -0.22, 0.0), xf * Vector3(0.5, -0.45, 0.0), 0.012, Color("c9c7bf"), MMET)
	batch.add_sphere(xf * Vector3(0.5, -0.15, 0.03), 0.03, Color("e9e7e0"), MPA)


## Odaya yaşanmışlık katan ayrıntılar: avize, klima, saat, tablolar ve odaya göre konsol.
## Hepsi duvar dibinde veya yüksekte; kapı ile hedef arasındaki yol açık kalır.
func _room_details(style: String, room: Dictionary, y: float, room_h: float, inward: Vector3, far_center: Vector3, along: Vector3, half_span: float, goal: String) -> void:
	var rx0 := float(room.x0)
	var rx1 := float(room.x1)
	var rz0 := float(room.z0)
	var rz1 := float(room.z1)
	var rc := Vector3((rx0 + rx1) * 0.5, y, (rz0 + rz1) * 0.5)
	var depth := (rx1 - rx0) if absf(inward.x) > 0.5 else (rz1 - rz0)
	var near_center := far_center + inward * depth
	# Avize: tavan göbeği, zincir, üç kollu, kumaş abajurlar
	var top := rc + Vector3.UP * room_h
	batch.add_cylinder(top - Vector3(0, 0.015, 0), 0.16, 0.03, Color("f6f1e7"), Basis(), MPA)
	batch.add_cylinder_between(top, top - Vector3(0, 0.3, 0), 0.01, C_BRASS, MMET)
	var hub := top - Vector3(0, 0.32, 0)
	batch.add_sphere(hub, 0.045, C_BRASS, MMET)
	for i in 3:
		var ang := TAU * i / 3.0
		var arm := Vector3(cos(ang), 0, sin(ang)) * 0.24
		batch.add_cylinder_between(hub, hub + arm + Vector3(0, 0.04, 0), 0.008, C_BRASS, MMET)
		props.add_cylinder(hub + arm + Vector3(0, 0.1, 0), 0.07, 0.1, Color("f3e3c3"))
		glow.add_sphere(hub + arm + Vector3(0, 0.07, 0), 0.035, Color("fff1c8"))
	# Kapı hangi tarafa yakınsa klima öbür köşede
	var door_off := (_room_door_pt - near_center).dot(along)
	var s_ac := -1.0 if door_off > 0.05 else 1.0
	var ac := near_center - inward * 0.11 + along * (s_ac * (half_span - 0.75)) + Vector3.UP * (room_h - 0.32)
	var acb := Basis.looking_at(-inward, Vector3.UP)   # yakın duvardan odaya bakar
	var acx := Transform3D(acb, ac)
	batch.add_box_xform(acx, Vector3(0.85, 0.27, 0.2), Color("fbfbf8"), MPA)
	batch.add_box_xform(acx * Transform3D(Basis(), Vector3(0, -0.1, -0.095)), Vector3(0.75, 0.05, 0.02), Color("d9dcdf"), MPA)
	batch.add_box_xform(acx * Transform3D(Basis(), Vector3(0, 0.03, -0.101)), Vector3(0.8, 0.004, 0.004), Color("e3e5e8"), MPA)
	glow.add_sphere(acx * Vector3(0.33, -0.05, -0.1), 0.008, Color("6fff8f"))
	batch.add_cylinder_between(acx * Vector3(0.38, -0.13, 0.05), acx * Vector3(0.38, -0.13, 0.05) + Vector3(0, -0.6, 0), 0.02, Color("f2f2ee"), MPA)
	# Yan duvar (-along): saat ve konsol
	var side_wall := far_center - along * half_span
	var wn := along   # yan duvardan odaya bakan normal
	var clock := side_wall + wn * 0.025 + inward * (depth * 0.45) + Vector3.UP * 1.95
	var face_axis := Basis(Vector3.UP, atan2(wn.x, wn.z)) * Basis(Vector3.RIGHT, PI * 0.5)
	batch.add_cylinder(clock, 0.17, 0.04, Color("6b4630"), face_axis, MW)
	batch.add_cylinder(clock + wn * 0.012, 0.145, 0.03, Color("fbf6ea"), face_axis, MPA)
	for h in 12:
		var ang2 := TAU * h / 12.0
		var tick := clock + wn * 0.03 + Vector3.UP * cos(ang2) * 0.12 + wn.cross(Vector3.UP).normalized() * sin(ang2) * 0.12
		batch.add_sphere(tick, 0.008, Color("2b2b2b"), MPA)
	var side_dir := wn.cross(Vector3.UP).normalized()
	batch.add_cylinder_between(clock + wn * 0.032, clock + wn * 0.032 + Vector3.UP * 0.07, 0.006, Color("1b1b1b"), MMET)
	batch.add_cylinder_between(clock + wn * 0.034, clock + wn * 0.034 + side_dir * 0.1 + Vector3.UP * 0.03, 0.005, Color("1b1b1b"), MMET)
	var con := side_wall + wn * 0.19 + inward * (depth - 1.05)
	var con_size := Vector3(0.36, 0.8, 1.0) if absf(wn.x) > 0.5 else Vector3(1.0, 0.8, 0.36)
	match style:
		"living", "bedroom":
			# Konsol / şifonyer: çekmeceler, üstünde dantel örtü, çay tepsisi veya ayna
			var ccol := Color("6b4630") if style == "living" else Color("a8774f")
			solid(con + Vector3.UP * 0.4, con_size, ccol, true, MW)
			for dy: float in [0.2, 0.45, 0.68]:
				var dp := con + wn * 0.185 + Vector3.UP * dy
				batch.add_box(dp, Vector3(0.01, 0.2, 0.9) if absf(wn.x) > 0.5 else Vector3(0.9, 0.2, 0.01), ccol.lightened(0.1), MW)
				batch.add_box(dp + wn * 0.01, Vector3(0.012, 0.025, 0.14) if absf(wn.x) > 0.5 else Vector3(0.14, 0.025, 0.012), C_BRASS, MMET)
			batch.add_box(con + Vector3.UP * 0.805, Vector3(0.3, 0.006, 0.55) if absf(wn.x) > 0.5 else Vector3(0.55, 0.006, 0.3), Color("fbf8f0"), MF)
			if style == "living":
				# Çay tepsisi: ince belli çay bardakları, şekerlik
				var tray := con + Vector3.UP * 0.815
				batch.add_cylinder(tray, 0.16, 0.012, Color("c9a23a"), Basis(), MMET)
				for i in 4:
					var off := side_dir * ((i - 1.5) * 0.07)
					batch.add_cylinder(tray + off + Vector3.UP * 0.045, 0.02, 0.08, Color("b5451b"), Basis(), MG)
					batch.add_cylinder(tray + off + Vector3.UP * 0.012, 0.03, 0.006, Color("f3f3f3"), Basis(), MPA)
				batch.add_sphere(tray - wn * 0.08 + Vector3.UP * 0.05, 0.045, Color("f3f3f3"), MPA)
				# Konsolun üstünde büyük tablo
				_picture_n(side_wall + wn * 0.02 + inward * (depth - 1.05) + Vector3.UP * 1.5, wn, 0.9, 0.6)
			else:
				# Şifonyer aynası
				var mp := side_wall + wn * 0.02 + inward * (depth - 1.05) + Vector3.UP * 1.35
				batch.add_box(mp, Vector3(0.03, 0.7, 0.8) if absf(wn.x) > 0.5 else Vector3(0.8, 0.7, 0.03), Color("a8774f"), MW)
				batch.add_box(mp + wn * 0.017, Vector3(0.004, 0.62, 0.72) if absf(wn.x) > 0.5 else Vector3(0.72, 0.62, 0.004), Color("dfe9ee"), MMET)
		"kitchen":
			# Duvar rafı: kavanozlar, baharatlar; altında havlu askısı
			var sp := side_wall + wn * 0.13 + inward * (depth * 0.55) + Vector3.UP * 1.5
			batch.add_box(sp, Vector3(0.26, 0.03, 0.9) if absf(wn.x) > 0.5 else Vector3(0.9, 0.03, 0.26), C_WOOD, MW)
			var jar_cols := [Color("e9c46a"), Color("c0392b"), Color("6db35a"), Color("f4a261"), Color("8a5a32")]
			for i in 5:
				var jp := sp + side_dir * ((i - 2) * 0.17) + Vector3.UP * 0.09
				batch.add_cylinder(jp, 0.045, 0.15, Color("dceff7"), Basis(), MG)
				batch.add_cylinder(jp + Vector3.UP * -0.02, 0.04, 0.09, jar_cols[i], Basis(), MPA)
				batch.add_cylinder(jp + Vector3.UP * 0.08, 0.047, 0.02, Color("b0392b"), Basis(), MPA)
			batch.add_cylinder_between(sp - Vector3.UP * 0.35 - side_dir * 0.3, sp - Vector3.UP * 0.35 + side_dir * 0.3, 0.01, Color("c0c4c8"), MMET)
			batch.add_box(sp - Vector3.UP * 0.47 + wn * 0.01, Vector3(0.02, 0.26, 0.22) if absf(wn.x) > 0.5 else Vector3(0.22, 0.26, 0.02), Color("e76f51"), MF)
		"laundry":
			# Havlu rafı ve duvara asılı ütü masası
			var sp2 := side_wall + wn * 0.15 + inward * (depth * 0.55) + Vector3.UP * 1.55
			batch.add_box(sp2, Vector3(0.3, 0.03, 0.8) if absf(wn.x) > 0.5 else Vector3(0.8, 0.03, 0.3), Color("ffffff"), MPA)
			var tc := [Color("8ecae6"), Color("ffb4a2"), Color("b5e48c")]
			for i in 3:
				batch.add_box(sp2 + side_dir * ((i - 1) * 0.24) + Vector3.UP * 0.07, Vector3(0.22, 0.1, 0.22), tc[i], MF)
			var ib := side_wall + wn * 0.04 + inward * (depth * 0.3) + Vector3.UP * 0.9
			batch.add_box(ib, Vector3(0.04, 1.3, 0.34) if absf(wn.x) > 0.5 else Vector3(0.34, 1.3, 0.04), Color("6a8caf"), MF)
	# Tablolar: yaşam alanında hedef/yuva üstünde, saat yanında küçük aile fotoğrafları
	if goal == "spot" and style == "living":
		_picture_n(far_center + inward * 0.02 + Vector3.UP * 1.6, inward, 1.0, 0.55)
	elif goal != "spot":
		_picture_n(far_center + inward * 0.02 + Vector3.UP * 1.55, inward, 0.8, 0.5)
	for i in 2:
		var fp := side_wall + wn * 0.02 + inward * (depth * 0.45 + 0.42 + i * 0.28) + Vector3.UP * (1.85 - i * 0.18)
		_picture_n(fp, wn, 0.2, 0.26)


## Dikdörtgen oda: zemin, tavan ve dört duvar (duvarlar dikdörtgenin dışına konur).
## walls[side]: null -> duvar yok, {} -> düz duvar, {"c","w","y0","y1"} -> boşluklu duvar
func _room_box(rc: Dictionary, y: float, height: float, walls: Dictionary, floor_color: Color, floor_mat: int = MW, wall_color: Color = Color.WHITE, wall_mat: int = MWP, corridor: bool = false) -> void:
	var x0 := float(rc.x0)
	var x1 := float(rc.x1)
	var zz0 := float(rc.z0)
	var zz1 := float(rc.z1)
	var wc: Color = T.wallpaper if wall_color == Color.WHITE else wall_color
	box_mm(Vector3(x0 - WT, y - SLAB, zz0 - WT), Vector3(x1 + WT, y, zz1 + WT), floor_color, true, floor_mat)
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
		wall(defs[side][0], defs[side][1], wc, w, wall_mat)
	_wall_trim(rc, y, height, walls, corridor)


## İç duvar ayrıntıları (yalnızca görsel, geçişi daraltmaz): kapı boşluğunda kesilen
## süpürgelik + üst çıta, tavan kornişi, prizler; koridorda ahşap lambri ve sandalye çıtası.
func _wall_trim(rc: Dictionary, y: float, height: float, walls: Dictionary, corridor: bool) -> void:
	var x0 := float(rc.x0)
	var x1 := float(rc.x1)
	var zz0 := float(rc.z0)
	var zz1 := float(rc.z1)
	var sides := {
		"xn": [x0, zz0, zz1, Vector3.RIGHT],
		"xp": [x1, zz0, zz1, Vector3.LEFT],
		"zn": [zz0, x0, x1, Vector3.BACK],
		"zp": [zz1, x0, x1, Vector3.FORWARD],
	}
	var trim: Color = T.trim
	var wains := C_WOOD_LIGHT.lightened(0.12)
	for side: String in sides:
		if not walls.has(side) or walls[side] == null:
			continue
		var w: Dictionary = walls[side]
		var d: Array = sides[side]
		var fixed: float = d[0]
		var a0: float = d[1]
		var a1: float = d[2]
		var n: Vector3 = d[3]
		var along_z := side.begins_with("x")
		var low: Array = [[a0, a1]]
		var high: Array = [[a0, a1]]
		if w.has("c"):
			var hc := float(w.c)
			var hw := float(w.w) * 0.5 + (0.08 if bool(w.get("frame", true)) else 0.0)
			var split := [[a0, hc - hw], [hc + hw, a1]]
			if float(w.get("y0", y)) < y + 0.3:
				low = split
			if float(w.get("y1", y + height)) > y + height - 0.12:
				high = split
		for seg: Array in low:
			var l: float = seg[1] - seg[0]
			if l < 0.05:
				continue
			var m: float = (seg[0] + seg[1]) * 0.5
			_trim_box(fixed, n, along_z, m, l, y + 0.055, 0.11, 0.022, trim, MPA)
			_trim_box(fixed, n, along_z, m, l, y + 0.115, 0.014, 0.03, trim.darkened(0.08), MPA)
			if corridor:
				# Ahşap lambri: panel, dikey çıtalar, sandalye çıtası
				_trim_box(fixed, n, along_z, m, l, y + 0.5, 0.76, 0.012, wains, MW)
				_trim_box(fixed, n, along_z, m, l, y + 0.9, 0.05, 0.032, C_WOOD_LIGHT.darkened(0.1), MW)
				var cnt := int(l / 0.55)
				for i in cnt:
					var a: float = seg[0] + (i + 0.5) * l / cnt
					_trim_box(fixed, n, along_z, a, 0.035, y + 0.5, 0.7, 0.02, wains.darkened(0.08), MW)
			elif l > 1.1:
				# Priz (beyaz kapak + iki delik)
				var sa: float = seg[0] + 0.45
				_trim_box(fixed, n, along_z, sa, 0.08, y + 0.3, 0.08, 0.014, Color("f7f6f2"), MPA)
				_trim_box(fixed, n, along_z, sa - 0.014, 0.008, y + 0.3, 0.012, 0.018, Color("3a3a3a"), MPA)
				_trim_box(fixed, n, along_z, sa + 0.014, 0.008, y + 0.3, 0.012, 0.018, Color("3a3a3a"), MPA)
		for seg: Array in high:
			var l2: float = seg[1] - seg[0]
			if l2 < 0.05:
				continue
			var m2: float = (seg[0] + seg[1]) * 0.5
			_trim_box(fixed, n, along_z, m2, l2, y + height - 0.05, 0.1, 0.05, trim.lightened(0.3), MPA)
			_trim_box(fixed, n, along_z, m2, l2, y + height - 0.115, 0.03, 0.025, trim, MPA)


## Duvar yüzüne yapışık ince kutu: fixed = duvar yüz koordinatı, n = odaya bakan normal.
func _trim_box(fixed: float, n: Vector3, along_z: bool, a: float, length: float, yc: float, h: float, depth: float, color: Color, mat: int) -> void:
	if along_z:
		batch.add_box(Vector3(fixed + n.x * depth * 0.5, yc, a), Vector3(depth, h, length), color, mat)
	else:
		batch.add_box(Vector3(a, yc, fixed + n.z * depth * 0.5), Vector3(length, h, depth), color, mat)


# ================================================================ dış bina kabuğu

func _build_block() -> void:
	var room: Dictionary = apt.room
	var bx := maxf(10.0, maxf(absf(float(room.x0)), absf(float(room.x1))) + 1.0)
	var bz := maxf(zb + WT, float(room.z1) + WT + 0.5)
	var yt := top_y
	var sx0 := -X_out - WT
	var sx1 := X_out + WT
	var fac: Color = T.facade
	var trim: Color = T.trim
	var fm := MP if turk else MBR   # Türk apartmanı: sıvalı cephe; modern: tuğla
	# Ön cephe (merdiven boşluğu dışında kalan kısımlar)
	box_mm(Vector3(-bx, -SLAB, -WT), Vector3(sx0, yt, 0.0), fac, true, fm)
	box_mm(Vector3(sx1, -SLAB, -WT), Vector3(bx, yt, 0.0), fac, true, fm)
	# Merdiven boşluğu önü (giriş üstü) tuğla kaplama (yalnızca görsel, giriş açık kalır)
	var eh := float(L.entrance.y)
	var ew := float(L.entrance.x)
	batch.add_box(Vector3(0, (eh + 0.4 + yt) * 0.5, -WT - 0.01), Vector3(sx1 * 2.0, yt - eh - 0.4, 0.02), fac.darkened(0.05), fm)
	for sgn: float in [-1.0, 1.0]:
		var px := sgn * (ew * 0.5 + (sx1 - ew * 0.5) * 0.5)
		batch.add_box(Vector3(px, eh * 0.5, -WT - 0.01), Vector3(maxf(0.05, sx1 - ew * 0.5), eh, 0.02), fac.darkened(0.05), fm)
	# Yan ve arka cephe, çatı
	box_mm(Vector3(-bx - WT, -SLAB, -WT), Vector3(-bx, yt, bz), fac, true, fm)
	box_mm(Vector3(bx, -SLAB, -WT), Vector3(bx + WT, yt, bz), fac, true, fm)
	box_mm(Vector3(-bx - WT, -SLAB, bz), Vector3(bx + WT, yt, bz + WT), fac, true, fm)
	box_mm(Vector3(-bx - WT - 0.2, yt, -WT - 0.35), Vector3(bx + WT + 0.2, yt + 0.3, bz + WT + 0.2), trim, true, MPA)
	box_mm(Vector3(-bx - WT, yt + 0.3, -WT - 0.2), Vector3(bx + WT, yt + 0.75, -WT), fac.darkened(0.1), false, fm)
	# Kat bantları, pencereler, balkonlar
	for k in range(0, F + 1):
		var y := k * H
		var band_col: Color = T.get("band", trim)
		batch.add_box(Vector3(0, y + 0.02, -WT - 0.06), Vector3(bx * 2.0 + WT * 2.0, 0.22 if turk else 0.16, 0.12), band_col if turk else trim, MPA)
		var wx := -bx + 1.6
		var wi := 0
		while wx < bx - 1.0:
			if absf(wx) > X_out + WT + 0.9:
				if turk:
					if k == 0:
						_window_turkish_ground(Vector3(wx, y + 1.0, -WT))
					else:
						_window_turkish(Vector3(wx, y + 1.0, -WT), (wi + k) % 2 == 0, wi + k * 7)
				elif k == 0:
					_shop_window(Vector3(wx, y, -WT), wi)
				else:
					_window(Vector3(wx, y + 1.0, -WT), (wi + k) % 3 == 0)
			wx += 2.4
			wi += 1
	if turk:
		_roof_turkish(bx, bz, yt)
		_entrance_turkish(ew, eh)
		info.block_aabb = AABB(Vector3(-bx, 0, 0), Vector3(bx * 2.0, yt, bz))
		return
	# Giriş: sütunlar, saçak, lamba, numara, basamak paspası
	for sgn: float in [-1.0, 1.0]:
		batch.add_box(Vector3(sgn * (ew * 0.5 + 0.18), eh * 0.5, -WT - 0.1), Vector3(0.22, eh, 0.2), trim, MPA)
	box_mm(Vector3(-ew * 0.5 - 0.5, eh + 0.35, -1.4), Vector3(ew * 0.5 + 0.5, eh + 0.47, -WT), T.awning, true, MPA)
	batch.add_box(Vector3(0, eh + 0.3, -1.38), Vector3(ew + 1.0, 0.12, 0.04), T.awning.darkened(0.15), MPA)
	_label("No. %d" % (10 + int(L.id)), Vector3(0, eh + 0.15, -WT - 0.03), PI, 52, Color("ffffff"))
	_label("SUNNY APARTMENTS", Vector3(0, eh + 0.8, -WT - 0.025), PI, 72, trim)
	glow.add_sphere(Vector3(-ew * 0.5 - 0.35, eh - 0.1, -WT - 0.15), 0.09, Color("fff2c0"))
	glow.add_sphere(Vector3(ew * 0.5 + 0.35, eh - 0.1, -WT - 0.15), 0.09, Color("fff2c0"))
	batch.add_box(Vector3(0, 0.006, -0.6), Vector3(1.2, 0.012, 0.6), Color("5a4636"), MC)
	info.block_aabb = AABB(Vector3(-bx, 0, 0), Vector3(bx * 2.0, yt, bz))


func _window(p: Vector3, balcony: bool) -> void:
	var trim: Color = T.trim
	batch.add_box(p + Vector3(0, 0.65, -0.015), Vector3(1.05, 1.3, 0.03), C_GLASS, MG)
	batch.add_box(p + Vector3(0, 0.65, -0.03), Vector3(1.2, 1.45, 0.02), trim, MPA)
	batch.add_box(p + Vector3(0, 0.65, -0.045), Vector3(0.05, 1.3, 0.02), trim, MPA)
	batch.add_box(p + Vector3(0, 0.85, -0.045), Vector3(1.05, 0.05, 0.02), trim, MPA)
	# Panjurlar
	for sgn: float in [-1.0, 1.0]:
		batch.add_box(p + Vector3(sgn * 0.78, 0.65, -0.05), Vector3(0.32, 1.35, 0.04), T.awning, MW)
	batch.add_box(p + Vector3(0, -0.05, -0.1), Vector3(1.35, 0.08, 0.2), trim, MPA)
	if balcony:
		# Balkon: döşeme + demir korkuluk + saksılar
		batch.add_box(p + Vector3(0, -0.12, -0.55), Vector3(1.9, 0.12, 0.9), trim, MPA)
		for i in 9:
			var bx := -0.9 + i * 0.225
			batch.add_cylinder(p + Vector3(bx, 0.35, -0.98), 0.012, 0.85, C_IRON, Basis(), MMET)
		batch.add_box(p + Vector3(0, 0.78, -0.98), Vector3(1.9, 0.05, 0.05), C_IRON, MMET)
		_flower_cluster(p + Vector3(0, 0.05, -0.75), 1.4, 7)
	else:
		# Pencere önü çiçekliği
		batch.add_box(p + Vector3(0, 0.05, -0.2), Vector3(1.0, 0.16, 0.18), C_POT, MPA)
		_flower_cluster(p + Vector3(0, 0.18, -0.2), 0.9, 6)


## Eski Türk apartmanı penceresi: beyaz doğrama, mermer denizlik, panjur kutusu;
## balkonlu olanlarda demir korkuluk, çamaşır ipi, çanak anten, klima, sardunya.
func _window_turkish(p: Vector3, balcony: bool, seed_i: int) -> void:
	var trim: Color = T.trim
	batch.add_box(p + Vector3(0, 0.65, -0.015), Vector3(1.05, 1.3, 0.03), C_GLASS, MG)
	batch.add_box(p + Vector3(0, 0.65, -0.03), Vector3(1.15, 1.4, 0.02), Color("f7f7f2"), MPA)
	batch.add_box(p + Vector3(0, 0.65, -0.045), Vector3(0.05, 1.3, 0.02), Color("f7f7f2"), MPA)
	# Panjur kutusu ve yarı inik panjur
	batch.add_box(p + Vector3(0, 1.45, -0.08), Vector3(1.2, 0.2, 0.16), trim, MPA)
	var drop := 0.15 + float(seed_i % 4) * 0.12
	for i in int(drop / 0.05):
		batch.add_box(p + Vector3(0, 1.32 - i * 0.05, -0.045), Vector3(1.05, 0.04, 0.02), Color("e9e5da") if i % 2 == 0 else Color("d8d3c6"), MPA)
	# Mermer denizlik
	batch.add_box(p + Vector3(0, -0.04, -0.1), Vector3(1.3, 0.05, 0.22), C_MARBLE, MM)
	if balcony:
		# Beton balkon + demir korkuluk
		batch.add_box(p + Vector3(0, -0.12, -0.6), Vector3(2.1, 0.14, 1.0), T.get("band", trim), MPA)
		for i in 15:
			var bx := -1.0 + i * (2.0 / 14.0)
			batch.add_box(p + Vector3(bx, 0.36, -1.08), Vector3(0.016, 0.82, 0.016), C_IRON_RAIL, MMET)
		batch.add_box(p + Vector3(0, 0.78, -1.08), Vector3(2.05, 0.03, 0.04), C_IRON_RAIL, MMET)
		batch.add_box(p + Vector3(0, -0.02, -1.08), Vector3(2.05, 0.03, 0.04), C_IRON_RAIL, MMET)
		# Çamaşır ipi ve asılı çamaşırlar
		batch.add_cylinder_between(p + Vector3(-0.95, 1.25, -0.95), p + Vector3(0.95, 1.25, -0.95), 0.005, Color("dddddd"))
		var cloth := [Color("e74c3c"), Color("3498db"), Color("ffffff"), Color("f1c40f"), Color("2ecc71"), Color("9b59b6")]
		for i in 5:
			var cc: Color = cloth[(seed_i + i) % cloth.size()]
			var h := 0.25 + float((seed_i + i * 3) % 3) * 0.1
			batch.add_box(p + Vector3(-0.75 + i * 0.37, 1.25 - h * 0.5, -0.95), Vector3(0.28, h, 0.02), cc, MF)
		# Sardunya saksıları
		batch.add_box(p + Vector3(-0.6, 0.86, -1.08), Vector3(0.5, 0.14, 0.14), C_POT, MPA)
		_flower_cluster(p + Vector3(-0.6, 0.97, -1.08), 0.45, 4)
		# Çanak anten (her üç balkondan birinde)
		if seed_i % 3 == 0:
			var dp := p + Vector3(0.75, 1.05, -1.05)
			batch.add_sphere(dp, 0.28, Color("d9dcdf"), MMET, Vector3(1.0, 1.0, 0.25))
			batch.add_cylinder_between(dp + Vector3(0, -0.2, -0.05), p + Vector3(0.75, 0.78, -1.08), 0.015, Color("9aa0a6"), MMET)
			batch.add_cylinder_between(dp, dp + Vector3(0, 0, -0.32), 0.01, Color("9aa0a6"), MMET)
	else:
		# Pencere önünde sardunya
		batch.add_box(p + Vector3(0.25, 0.06, -0.12), Vector3(0.45, 0.14, 0.14), C_POT, MPA)
		_flower_cluster(p + Vector3(0.25, 0.17, -0.12), 0.4, 3)
	# Klima dış ünitesi (bazı pencerelerin yanında)
	if seed_i % 4 == 1:
		var ac := p + Vector3(-0.95, 0.15, -0.2)
		batch.add_box(ac, Vector3(0.6, 0.45, 0.28), Color("f2f2f0"), MPA)
		batch.add_cylinder(ac + Vector3(0.08, 0, -0.145), 0.15, 0.01, Color("8a8f94"), Basis(Vector3.RIGHT, PI * 0.5), MMET)


## Zemin kat penceresi: demir parmaklıklı.
func _window_turkish_ground(p: Vector3) -> void:
	batch.add_box(p + Vector3(0, 0.55, -0.015), Vector3(1.0, 1.1, 0.03), C_GLASS, MG)
	batch.add_box(p + Vector3(0, 0.55, -0.03), Vector3(1.1, 1.2, 0.02), Color("f7f7f2"), MPA)
	batch.add_box(p + Vector3(0, -0.06, -0.1), Vector3(1.25, 0.05, 0.2), C_MARBLE, MM)
	for i in 9:
		batch.add_box(p + Vector3(-0.5 + i * 0.125, 0.55, -0.12), Vector3(0.018, 1.2, 0.018), C_IRON_RAIL, MMET)
	for yy: float in [0.0, 0.55, 1.1]:
		batch.add_box(p + Vector3(0, yy, -0.12), Vector3(1.05, 0.03, 0.02), C_IRON_RAIL, MMET)


## Düz çatı: su depoları ve TV antenleri.
func _roof_turkish(bx: float, bz: float, yt: float) -> void:
	for i in 3:
		var tp := Vector3(-bx * 0.5 + i * bx * 0.45, yt + 0.3, bz * 0.6)
		batch.add_cylinder(tp + Vector3(0, 0.6, 0), 0.55, 1.1, Color("e8eaec"), Basis(), MPA)
		batch.add_cylinder(tp + Vector3(0, 1.2, 0), 0.25, 0.1, Color("c9ccce"), Basis(), MPA)
	for i in 4:
		var ap := Vector3(-bx * 0.7 + i * bx * 0.45, yt + 0.3, bz * 0.3 + float(i % 2) * 1.5)
		batch.add_cylinder_between(ap, ap + Vector3(0, 2.2, 0), 0.02, Color("8a8f94"), MMET)
		for j in 3:
			var cy := 1.4 + j * 0.25
			batch.add_cylinder_between(ap + Vector3(-0.45 + j * 0.08, cy, 0), ap + Vector3(0.45 - j * 0.08, cy, 0), 0.01, Color("8a8f94"), MMET)


## Eski Türk apartmanı girişi: bronz çerçeveli telli camlı çift kanat kapı, vasistas,
## beton saçak, mermer "HİCRET APARTMANI" levhası, mavi kapı numarası, diyafon, glob lamba.
func _entrance_turkish(ew: float, eh: float) -> void:
	var half := ew * 0.5
	# Kapı çerçevesi (bronz alüminyum)
	batch.add_box(Vector3(-half - 0.04, eh * 0.5, -WT - 0.02), Vector3(0.08, eh, 0.06), C_ALU, MMET)
	batch.add_box(Vector3(half + 0.04, eh * 0.5, -WT - 0.02), Vector3(0.08, eh, 0.06), C_ALU, MMET)
	batch.add_box(Vector3(0, eh + 0.04, -WT - 0.02), Vector3(ew + 0.16, 0.08, 0.06), C_ALU, MMET)
	# Vasistas (kapı üstü pencere)
	batch.add_box(Vector3(0, eh + 0.24, -WT - 0.015), Vector3(ew, 0.3, 0.02), C_GLASS, MG)
	batch.add_box(Vector3(0, eh + 0.24, -WT - 0.03), Vector3(0.04, 0.3, 0.02), C_ALU, MMET)
	batch.add_box(Vector3(0, eh + 0.41, -WT - 0.02), Vector3(ew + 0.16, 0.05, 0.05), C_ALU, MMET)
	# İçeri açık iki kanat (telli cam). İnce çarpışma: kanat kenarlarına çarpılabilir.
	var leaf_w := half - 0.04
	for sgn: float in [-1.0, 1.0]:
		var lx := sgn * (half - 0.03)
		var lc := Vector3(lx, eh * 0.5 - 0.02, leaf_w * 0.5 + 0.02)
		batch.add_box(lc, Vector3(0.045, eh - 0.06, leaf_w), C_ALU, MMET)
		batch.add_box(lc + Vector3(-sgn * 0.025, 0.15, 0), Vector3(0.006, eh - 0.6, leaf_w - 0.12), Color("bcd6e0"), MG)
		batch.add_box(lc + Vector3(-sgn * 0.05, -0.1, leaf_w * 0.3), Vector3(0.03, 0.03, 0.3), Color("c9ccce"), MMET)
		_shape_box(Transform3D(Basis(), lc), Vector3(0.045, eh - 0.06, leaf_w))
	# Mermer eşik
	batch.add_box(Vector3(0, 0.008, -0.1), Vector3(ew + 0.2, 0.016, 0.24), C_MARBLE, MM)
	# Beton saçak ve altında glob lamba
	box_mm(Vector3(-half - 0.6, eh + 0.5, -1.35), Vector3(half + 0.6, eh + 0.64, -WT), Color("cfc9bd"), true, MP)
	batch.add_box(Vector3(0, eh + 0.66, -1.33), Vector3(ew + 1.2, 0.06, 0.04), Color("b8b1a3"), MP)
	glow.add_sphere(Vector3(0, eh + 0.4, -0.9), 0.12, Color("fff3d6"))
	# "HİCRET APARTMANI" mermer levha
	var plaque_y := eh + 1.05
	batch.add_box(Vector3(0, plaque_y, -WT - 0.03), Vector3(2.5, 0.42, 0.05), Color("ece8e0"), MM)
	batch.add_box(Vector3(0, plaque_y, -WT - 0.025), Vector3(2.58, 0.5, 0.04), Color("b9b3a8"), MM)
	_label(BUILDING_NAME, Vector3(0, plaque_y, -WT - 0.06), PI, 54, Color("2f2f33"), false)
	# Mavi kapı numarası tabelası
	var np := Vector3(half + 0.55, 2.05, -WT - 0.03)
	batch.add_box(np, Vector3(0.36, 0.26, 0.03), Color("1f4e9c"), MPA)
	batch.add_box(np + Vector3(0, 0, 0.004), Vector3(0.4, 0.3, 0.02), Color("ffffff"), MPA)
	_label("%d" % (10 + int(L.id)), np + Vector3(0, 0, -0.02), PI, 64, Color("ffffff"), false)
	# Diyafon paneli (zil düğmeleri)
	var ip := Vector3(-half - 0.42, 1.35, -WT - 0.025)
	batch.add_box(ip, Vector3(0.22, 0.42, 0.03), Color("b8bcbf"), MMET)
	for i in 6:
		batch.add_box(ip + Vector3(0.05, 0.14 - i * 0.055, -0.018), Vector3(0.03, 0.03, 0.01), Color("f2f0ea"), MPA)
		batch.add_box(ip + Vector3(-0.04, 0.14 - i * 0.055, -0.018), Vector3(0.1, 0.03, 0.005), Color("fffbe6"), MPA)
	glow.add_sphere(Vector3(half + 0.25, eh - 0.2, -WT - 0.12), 0.08, Color("fff2c0"))
	# Paspas
	batch.add_box(Vector3(0, 0.006, -0.6), Vector3(1.2, 0.012, 0.6), Color("5a4636"), MC)


func _shop_window(p: Vector3, idx: int) -> void:
	var colors := [Color("e63946"), Color("2a9d8f"), Color("f4a261"), Color("457b9d")]
	var col: Color = colors[idx % colors.size()]
	batch.add_box(p + Vector3(0, 1.15, -0.015), Vector3(1.9, 1.7, 0.03), C_GLASS, MG)
	batch.add_box(p + Vector3(0, 1.15, -0.03), Vector3(2.05, 1.85, 0.02), Color("2b2d42"), MPA)
	batch.add_box(p + Vector3(0, 0.2, -0.05), Vector3(2.05, 0.4, 0.06), col.darkened(0.2), MPA)
	# Çizgili tente
	for i in 6:
		var c: Color = col if i % 2 == 0 else Color("ffffff")
		batch.add_box_xform(Transform3D(Basis(Vector3.RIGHT, -0.45), p + Vector3(-0.85 + i * 0.34, 2.25, -0.45)), Vector3(0.34, 0.03, 0.95), c, MF)


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
	if str(info.goal_type) == "door":
		w.append(info.goal_center)
	else:
		w.append(Vector3(info.apt_door_pos) + Vector3(float(info.apt_side) * 0.4, 0, 0))
		w.append(info.corridor_end)
		w.append(info.room_door_pos)
		if str(info.goal_type) == "spot":
			# Yuvanın hemen önü: ince eşyalarda (TV) yuva duvara çok yakın
			w.append(Vector3(info.goal_center) + Vector3(info.goal_facing) * 0.5)
		else:
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
				_obs_cat(a)


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
	props.add_cylinder(Vector3(p.x, (shade_c.y + ceil_y) * 0.5, p.z), 0.012, ceil_y - shade_c.y, C_IRON)
	props.add_cylinder(shade_c, 0.24, 0.22, Color("f4a261"))
	props.add_cylinder(shade_c + Vector3(0, -0.1, 0), 0.25, 0.02, Color("e76f51"))
	glow.add_sphere(shade_c + Vector3(0, -0.08, 0), 0.07, Color("fff6d0"))
	_shape_box(Transform3D(Basis(), shade_c), Vector3(0.46, 0.22, 0.46))


func _obs_shoe_rack(a: Dictionary, side: int, at: String) -> void:
	var depth := 0.34
	var p := _edge_spot(a, side, at, depth)
	var along: Vector3 = a.along
	var length := 0.9
	var size := Vector3(length, 0.85, depth) if absf(along.x) > 0.5 else Vector3(depth, 0.85, length)
	prop_box(p + Vector3.UP * 0.425, size, Color("9c6b40"))
	for i in 3:
		var off := along * (-0.3 + i * 0.3)
		props.add_box(p + off + Vector3.UP * 0.9, Vector3(0.12, 0.08, 0.26) if absf(along.x) > 0.5 else Vector3(0.26, 0.08, 0.12), [Color("2b2b2b"), Color("e63946"), Color("f1faee")][i])


func _obs_plant(a: Dictionary, side: int, at: String) -> void:
	var p := _edge_spot(a, side, at, 0.5)
	props.add_cylinder(p + Vector3.UP * 0.22, 0.22, 0.44, C_POT)
	props.add_sphere(p + Vector3.UP * 0.8, 0.38, C_LEAVES)
	props.add_sphere(p + Vector3(0.12, 1.05, 0.05), 0.24, C_LEAVES.lightened(0.1))
	props.add_sphere(p + Vector3(-0.1, 1.0, -0.08), 0.06, FLOWER_COLORS[0])
	_shape_cyl(p + Vector3.UP * 0.6, 0.26, 1.2)


func _obs_boxes(a: Dictionary, side: int, at: String) -> void:
	var p := _edge_spot(a, side, at, 0.55)
	prop_box(p + Vector3.UP * 0.25, Vector3(0.6, 0.5, 0.5), Color("c48a55"))
	prop_box(p + Vector3(0.03, 0.72, 0.02), Vector3(0.5, 0.44, 0.44), Color("b97d4f"))
	props.add_box(p + Vector3(0.03, 0.945, 0.02), Vector3(0.08, 0.005, 0.45), Color("e8d9a8"))
	props.add_box(p + Vector3(0, 0.3, -0.252), Vector3(0.25, 0.12, 0.004), Color("e63946"))


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


func _obs_cat(a: Dictionary) -> void:
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
	m.roughness = 0.65
	return m


func _glow_material() -> Material:
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.vertex_color_use_as_albedo = true
	m.albedo_color = Color(1.6, 1.5, 1.2)
	return m


func _cloud_material() -> Material:
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.vertex_color_use_as_albedo = true
	m.albedo_color = Color(1.0, 1.0, 1.0)
	return m
