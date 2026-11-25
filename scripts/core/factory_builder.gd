class_name FactoryBuilder
extends RefCounted
## Absürt fabrika bölümleri (16–20): adam tek başına, kendi boyunun 5–10 katı dev eşyaları
## kocaman bir fabrika salonunda taşır. Salonun ortasındaki kapıdan geçmek için eşya
## yatırılır ya da çevrilir; hedef, salonun sonundaki dev dekorun (küvet, hediye kutusu,
## mutfak...) içindeki işaretli yerdir.
## Koordinatlar: salon x ∈ [-W/2, W/2], z ∈ [0, D], zemin y = 0. Oyuncu +Z yönüne ilerler.

const MBR := MeshBatcher.M_BRICK
const MMET := MeshBatcher.M_METAL
const MPA := MeshBatcher.M_PAINT
const MPV := MeshBatcher.M_PAVING
const MW := MeshBatcher.M_WOOD
const MG := MeshBatcher.M_GLASS
const MT := MeshBatcher.M_TILE
const MF := MeshBatcher.M_FABRIC
const MP := MeshBatcher.M_PLASTER

const C_CONCRETE := Color("a19e96")
const C_BRICK := Color("9c4a32")
const C_SHEET := Color("7f8d9b")
const C_STEEL := Color("4f5862")
const C_YELLOW := Color("f2c230")
const C_BLACK := Color("23252a")
const C_ORANGE := Color("ff8c1a")
const C_CRATE := Color("b88a52")
const C_GOLD := Color("d6a93a")

var b: LevelBuilder
var W := 26.0
var D := 50.0
var H := 14.0
var gate := Vector2(8, 11)
var decor := "pedestal"
var isize := Vector3.ONE
var clear_half := 6.0      # orta yol: engeller bu genişliğin dışında kalır
var spot_z := 40.0


func build(lb: LevelBuilder) -> void:
	b = lb
	var f: Dictionary = b.L.factory
	W = float(f.width)
	D = float(f.length)
	H = float(f.height)
	gate = f.gate
	decor = str(f.decor)
	isize = ItemDB.get_item(str(b.L.item)).size
	clear_half = maxf(gate.x * 0.5 + 1.5, maxf(isize.x, isize.z) * 0.5 + 2.5)
	spot_z = D - 3.5 - isize.z * 0.5

	_floor()
	_walls()
	_roof()
	_columns_and_crane()
	_gate_wall()
	_side_clutter()
	_goal_and_decor()
	_signs()
	_lights()
	b.batch.build(b.root, b._building_material(), "Factory")
	_info()


# ================================================================ zemin

func _floor() -> void:
	b.box_mm(Vector3(-W * 0.5 - 0.6, -0.4, -0.6), Vector3(W * 0.5 + 0.6, 0.0, D + 0.6), C_CONCRETE, true, MPV)
	# Beton derzleri (6 m'de bir)
	var zz := 6.0
	while zz < D:
		b.batch.add_box(Vector3(0, 0.003, zz), Vector3(W, 0.004, 0.04), C_CONCRETE.darkened(0.18), MPA)
		zz += 6.0
	var xx := -W * 0.5 + 6.0
	while xx < W * 0.5:
		b.batch.add_box(Vector3(xx, 0.003, D * 0.5), Vector3(0.04, 0.004, D), C_CONCRETE.darkened(0.18), MPA)
		xx += 6.0
	# Yürüme yolu çizgileri (sarı) ve yön okları
	for sx: float in [-1.0, 1.0]:
		b.batch.add_box(Vector3(sx * clear_half, 0.006, D * 0.5), Vector3(0.18, 0.006, D - 1.0), C_YELLOW, MPA)
	var az := 8.0
	while az < D - 8.0:
		if absf(az - D * 0.5) > 3.0:
			b.batch.add_box_xform(Transform3D(Basis(Vector3.UP, PI * 0.25), Vector3(-0.45, 0.007, az)), Vector3(1.4, 0.006, 0.3), Color("f7f3e8"), MPA)
			b.batch.add_box_xform(Transform3D(Basis(Vector3.UP, -PI * 0.25), Vector3(0.45, 0.007, az)), Vector3(1.4, 0.006, 0.3), Color("f7f3e8"), MPA)
		az += 7.0
	# Yağ lekeleri (yaşanmışlık)
	for i in 8:
		var p := Vector3(b.rng.randf_range(-W * 0.4, W * 0.4), 0.005, b.rng.randf_range(4.0, D - 4.0))
		b.batch.add_cylinder(p, b.rng.randf_range(0.3, 0.9), 0.004, C_CONCRETE.darkened(0.3), Basis(), MPA)


# ================================================================ duvarlar ve çatı

func _walls() -> void:
	var t := 0.5
	# Çarpışma: dört duvar (tam yükseklik)
	b.collider_mm(Vector3(-W * 0.5 - t, 0, -t), Vector3(-W * 0.5, H + 0.5, D + t))
	b.collider_mm(Vector3(W * 0.5, 0, -t), Vector3(W * 0.5 + t, H + 0.5, D + t))
	b.collider_mm(Vector3(-W * 0.5, 0, -t), Vector3(W * 0.5, H + 0.5, 0))
	b.collider_mm(Vector3(-W * 0.5, 0, D), Vector3(W * 0.5, H + 0.5, D + t))
	# Görsel: alt 3 m tuğla, üstü oluklu sac; üst bantta yüksek pencereler
	var brick_h := 3.0
	for sx: float in [-1.0, 1.0]:
		var x := sx * (W * 0.5 + t * 0.5)
		b.batch.add_box(Vector3(x, brick_h * 0.5, D * 0.5), Vector3(t, brick_h, D + t * 2.0), C_BRICK, MBR)
		b.batch.add_box(Vector3(x, (brick_h + H) * 0.5, D * 0.5), Vector3(t, H - brick_h, D + t * 2.0), C_SHEET, MMET)
		b.batch.add_box(Vector3(sx * (W * 0.5 - 0.03), brick_h, D * 0.5), Vector3(0.08, 0.14, D), Color("d8d2c4"), MPA)
		var rz := 0.5
		while rz < D:
			b.batch.add_box(Vector3(sx * (W * 0.5 - 0.02), (brick_h + H) * 0.5, rz), Vector3(0.05, H - brick_h - 0.2, 0.08), C_SHEET.darkened(0.15), MMET)
			rz += 1.0
		# Yüksek pencere şeridi
		var wz := 4.0
		while wz < D - 3.0:
			var wc := Vector3(sx * (W * 0.5 - 0.06), H - 2.6, wz)
			b.batch.add_box(wc, Vector3(0.06, 1.8, 3.2), Color("bfe3f5"), MG)
			b.batch.add_box(wc + Vector3(-sx * 0.03, 0, 0), Vector3(0.05, 0.08, 3.3), C_STEEL, MMET)
			for k in 3:
				b.batch.add_box(wc + Vector3(-sx * 0.03, 0, -1.6 + k * 1.6), Vector3(0.05, 1.9, 0.08), C_STEEL, MMET)
			wz += 5.0
	for zf: float in [0.0, D]:
		var z := zf - t * 0.5 if zf == 0.0 else zf + t * 0.5
		b.batch.add_box(Vector3(0, brick_h * 0.5, z), Vector3(W + t * 2.0, brick_h, t), C_BRICK, MBR)
		b.batch.add_box(Vector3(0, (brick_h + H) * 0.5, z), Vector3(W + t * 2.0, H - brick_h, t), C_SHEET, MMET)
	# Arka (giriş) duvarında kapalı dev kepenk
	var sw := minf(W - 6.0, 12.0)
	var sh := minf(H - 2.0, 9.0)
	for i in int(sh / 0.35):
		b.batch.add_box(Vector3(0, 0.2 + i * 0.35, 0.03), Vector3(sw, 0.28, 0.05), Color("c9ced4") if i % 2 == 0 else Color("b5bcc4"), MMET)
	b.batch.add_box(Vector3(0, sh + 0.5, 0.25), Vector3(sw + 0.6, 0.9, 0.5), C_STEEL, MMET)
	for sx: float in [-1.0, 1.0]:
		b.batch.add_box(Vector3(sx * (sw * 0.5 + 0.15), sh * 0.5, 0.1), Vector3(0.3, sh, 0.2), C_YELLOW, MPA)
	var lb := b._label("LOADING DOCK A", Vector3(0, sh + 1.6, 0.06), PI, 64, C_BLACK, false)
	lb.pixel_size = 0.012
	lb.rotation.y = 0.0


func _roof() -> void:
	# Çatı: gölge düşürmez (güneş ışığı içeri dolar), üstten görünümde kesilir
	b.ceiling_mm(Vector3(-W * 0.5 - 0.6, H, -0.6), Vector3(W * 0.5 + 0.6, H + 0.4, D + 0.6))
	# Çatı makasları: kafes kirişler (6 m'de bir)
	var z := 3.0
	while z < D:
		var y := H - 0.35
		b.batch.add_box(Vector3(0, y, z), Vector3(W, 0.3, 0.25), C_STEEL, MMET)
		b.batch.add_box(Vector3(0, y - 0.9, z), Vector3(W, 0.18, 0.18), C_STEEL, MMET)
		var x := -W * 0.5
		var up := true
		while x < W * 0.5 - 0.5:
			var a := Vector3(x, y - 0.9 if up else y, z)
			var c := Vector3(x + 1.5, y if up else y - 0.9, z)
			b.batch.add_cylinder_between(a, c, 0.05, C_STEEL, MMET)
			x += 1.5
			up = not up
		z += 6.0
	# Asma tavan lambaları (yüksek tavan armatürü)
	var lz := 6.0
	while lz < D - 2.0:
		for lx: float in [-W * 0.25, W * 0.25]:
			var p := Vector3(lx, H - 1.6, lz)
			b.batch.add_cylinder_between(p + Vector3(0, 0.8, 0), p, 0.02, C_BLACK, MMET)
			b.batch.add_cylinder(p, 0.45, 0.35, Color("5f6b78"), Basis(), MMET)
			b.glow.add_sphere(p - Vector3(0, 0.15, 0), 0.32, Color("fff6dc"))
		lz += 9.0


func _columns_and_crane() -> void:
	# Duvar dibinde çelik I kolonlar (8 m'de bir) ve vinç rayı
	var z := 4.0
	while z < D - 1.0:
		for sx: float in [-1.0, 1.0]:
			var x := sx * (W * 0.5 - 0.35)
			b.solid(Vector3(x, H * 0.5, z), Vector3(0.12, H, 0.5), C_STEEL, true, MMET)
			b.batch.add_box(Vector3(x - sx * 0.2, H * 0.5, z), Vector3(0.4, H, 0.06), C_STEEL, MMET)
			b.batch.add_box(Vector3(x + sx * 0.2, H * 0.5, z), Vector3(0.4, H, 0.06), C_STEEL, MMET)
			# Kolon dibinde sarı-siyah koruma
			for k in 4:
				b.batch.add_box(Vector3(x, 0.15 + k * 0.3, z), Vector3(0.6, 0.3, 0.6), C_YELLOW if k % 2 == 0 else C_BLACK, MPA)
		z += 8.0
	var rail_y := H - 2.4
	for sx: float in [-1.0, 1.0]:
		b.batch.add_box(Vector3(sx * (W * 0.5 - 0.7), rail_y, D * 0.5), Vector3(0.5, 0.6, D), C_YELLOW.darkened(0.1), MMET)
	# Köprülü vinç: salonun ilk çeyreğinde, eşyanın tepesinin üstünde
	var cz := D * 0.2
	var by := H - 2.4
	b.batch.add_box(Vector3(0, by, cz), Vector3(W - 1.4, 0.8, 0.7), C_YELLOW, MPA)
	b.batch.add_box(Vector3(0, by, cz + 1.2), Vector3(W - 1.4, 0.8, 0.7), C_YELLOW, MPA)
	for k in int((W - 2.0) / 1.2):
		var x := -W * 0.5 + 1.2 + k * 1.2
		b.batch.add_box_xform(Transform3D(Basis(Vector3.RIGHT, 0.6), Vector3(x, by - 0.42, cz + 0.6)), Vector3(0.06, 0.06, 1.5), C_BLACK, MPA)
	b.batch.add_box(Vector3(0, by - 0.1, cz + 0.6), Vector3(1.4, 1.1, 1.8), Color("e0aa1f"), MPA)
	var _l := b._label("50 000 t", Vector3(0, by - 0.1, cz - 0.31), PI, 64, C_BLACK, false)
	_l.pixel_size = 0.008
	_l.rotation.y = PI
	# Kanca: yolun dışında, yan tarafta sarkıyor (yalnızca görsel)
	var hx := clear_half + 2.0
	var hook := Vector3(hx, maxf(4.0, H * 0.45), cz + 0.6)
	b.batch.add_box(Vector3(hx, by - 0.3, cz + 0.6), Vector3(0.8, 0.6, 0.8), Color("e0aa1f"), MPA)
	b.batch.add_cylinder_between(Vector3(hx, by - 0.6, cz + 0.6), hook + Vector3(0, 0.8, 0), 0.05, C_BLACK, MMET)
	b.batch.add_box(hook + Vector3(0, 0.6, 0), Vector3(0.5, 0.5, 0.35), C_ORANGE, MPA)
	b.batch.add_cylinder(hook, 0.35, 0.12, C_STEEL, Basis(Vector3.RIGHT, PI * 0.5), MMET)


# ================================================================ orta kapı

func _gate_wall() -> void:
	var z := D * 0.5
	var t := 0.8
	var gw := gate.x
	var gh := gate.y
	var side_w := (W - gw) * 0.5
	for sx: float in [-1.0, 1.0]:
		var cx := sx * (gw * 0.5 + side_w * 0.5)
		b.collider_mm(Vector3(cx - side_w * 0.5, 0, z - t * 0.5), Vector3(cx + side_w * 0.5, H, z + t * 0.5))
		b.batch.add_box(Vector3(cx, 1.5, z), Vector3(side_w, 3.0, t), C_BRICK, MBR)
		b.batch.add_box(Vector3(cx, (3.0 + H) * 0.5, z), Vector3(side_w, H - 3.0, t), C_SHEET, MMET)
		# Kapı kenarında sarı-siyah tehlike şeridi
		var ex := sx * (gw * 0.5 + 0.15)
		var n := int(gh / 0.6)
		for k in n:
			var c: Color = C_YELLOW if k % 2 == 0 else C_BLACK
			b.batch.add_box(Vector3(ex, 0.3 + k * 0.6, z), Vector3(0.32, 0.6, t + 0.06), c, MPA)
	b.collider_mm(Vector3(-gw * 0.5, gh, z - t * 0.5), Vector3(gw * 0.5, H, z + t * 0.5))
	b.batch.add_box(Vector3(0, (gh + H) * 0.5, z), Vector3(gw, H - gh, t), C_SHEET, MMET)
	var k2 := 0
	var x := -gw * 0.5
	while x < gw * 0.5:
		b.batch.add_box(Vector3(x + 0.3, gh + 0.18, z), Vector3(0.6, 0.36, t + 0.06), C_YELLOW if k2 % 2 == 0 else C_BLACK, MPA)
		x += 0.6
		k2 += 1
	# Sarılmış kepenk kutusu ve uyarı tabelaları (iki yüzde)
	b.batch.add_box(Vector3(0, gh + 0.75, z - t * 0.5 - 0.35), Vector3(gw + 0.4, 0.8, 0.7), C_STEEL, MMET)
	for face: float in [-1.0, 1.0]:
		var zf := z + face * (t * 0.5 + 0.02)
		var yaw := 0.0 if face > 0.0 else PI
		var sign_y := gh + 1.7 if face > 0.0 else gh + 1.9
		if sign_y < H - 0.8:
			var l1 := b._label("MAX HEIGHT %.0f m" % gh, Vector3(0, sign_y, zf), yaw, 64, Color("c0392b"), false)
			l1.pixel_size = 0.014
		var l2 := b._label("WIDTH %.0f m" % gw, Vector3(-gw * 0.5 - 1.6, 4.0, zf), yaw, 64, C_BLACK, false)
		l2.pixel_size = 0.01
		b.batch.add_box(Vector3(-gw * 0.5 - 1.6, 4.0, zf), Vector3(2.6, 0.9, 0.02), Color("fff8e1"), MPA)
	# Zeminde tehlike şeritleri (kapının iki yanında)
	for face2: float in [-1.0, 1.0]:
		var zz := z + face2 * 1.4
		var cnt := int(gw / 0.5)
		for i in cnt:
			b.batch.add_box_xform(Transform3D(Basis(Vector3.UP, 0.6), Vector3(-gw * 0.5 + 0.25 + i * 0.5, 0.008, zz)), Vector3(0.2, 0.006, 0.9), C_YELLOW if i % 2 == 0 else C_BLACK, MPA)


# ================================================================ yan dağınıklık (engeller)

func _side_clutter() -> void:
	var lx := -(clear_half + 1.6)
	var rx := clear_half + 1.6
	# Sol: konveyör bantları (kapı öncesi ve sonrası)
	for seg: Vector2 in [Vector2(5.0, D * 0.5 - 3.0), Vector2(D * 0.5 + 3.0, D - 9.0)]:
		if seg.y - seg.x < 4.0 or lx - 0.8 < -W * 0.5 + 0.9:
			continue
		_conveyor(Vector3(lx, 0, (seg.x + seg.y) * 0.5), seg.y - seg.x)
	# Sağ: kasa yığınları, paletler, variller, forklift
	if rx + 1.2 < W * 0.5 - 0.9:
		var zs := [6.0, D * 0.5 - 6.0, D * 0.5 + 5.0]
		for z: float in zs:
			_crate_stack(Vector3(rx + 0.4, 0, z))
		_barrels(Vector3(rx + 0.5, 0, D * 0.5 - 2.6))
		_barrels(Vector3(rx + 0.5, 0, D * 0.5 + 9.5))
		_forklift(Vector3(rx + 0.6, 0, D * 0.32))
	# Duvar dibinde yangın tüpleri ve elektrik panoları (görsel)
	for i in 4:
		var z2 := 7.0 + i * (D - 14.0) / 3.0
		var p := Vector3(-W * 0.5 + 0.12, 1.2, z2)
		b.batch.add_cylinder(p, 0.12, 0.55, Color("d62828"), Basis(), MPA)
		b.batch.add_box(p + Vector3(0.0, 0.8, 0.0), Vector3(0.05, 0.4, 0.3), Color("ffffff"), MPA)
		b.batch.add_box(Vector3(W * 0.5 - 0.12, 1.6, z2 + 1.5), Vector3(0.2, 1.2, 0.9), Color("9aa3ab"), MMET)
		b.batch.add_box(Vector3(W * 0.5 - 0.23, 1.8, z2 + 1.5), Vector3(0.02, 0.18, 0.18), C_YELLOW, MPA)


func _conveyor(c: Vector3, length: float) -> void:
	var h := 1.0
	b.solid(c + Vector3(0, h * 0.5, 0), Vector3(1.4, h, length), Color("3d4652"), true, MMET)
	b.batch.add_box(c + Vector3(0, h + 0.03, 0), Vector3(1.2, 0.06, length), Color("1e1f22"), MF)
	var z := c.z - length * 0.5 + 0.4
	while z < c.z + length * 0.5:
		b.batch.add_cylinder(Vector3(c.x, h - 0.05, z), 0.07, 1.3, Color("9aa3ab"), Basis(Vector3.FORWARD, PI * 0.5), MMET)
		z += 0.45
	# Bant üstünde minicik (!) koliler: dev eşyaların yanında komik dururlar
	for i in int(length / 2.5):
		var bz := c.z - length * 0.5 + 1.2 + i * 2.5
		var s := b.rng.randf_range(0.35, 0.6)
		b.batch.add_box(Vector3(c.x, h + 0.06 + s * 0.5, bz), Vector3(s, s, s), C_CRATE, MPA)
		b.batch.add_box(Vector3(c.x, h + 0.06 + s + 0.002, bz), Vector3(0.08, 0.004, s), Color("e8d9a8"), MPA)
	for k: float in [-1.0, 1.0]:
		b.batch.add_box(Vector3(c.x + k * 0.72, h + 0.12, c.z), Vector3(0.06, 0.2, length), C_YELLOW, MPA)


func _crate_stack(p: Vector3) -> void:
	var s := 1.4
	b.solid(p + Vector3(0, 0.08, 0), Vector3(s + 0.2, 0.16, s + 0.2), Color("8a6a4a"), true, MW)
	var levels := b.rng.randi_range(2, 3)
	for k in levels:
		var c := p + Vector3(b.rng.randf_range(-0.08, 0.08), 0.16 + s * 0.5 + k * s, b.rng.randf_range(-0.08, 0.08))
		b.solid(c, Vector3(s, s, s), C_CRATE.darkened(k * 0.06), true, MW)
		for sx: float in [-1.0, 1.0]:
			b.batch.add_box(c + Vector3(sx * (s * 0.5 + 0.005), 0, 0), Vector3(0.01, s - 0.15, 0.12), C_CRATE.darkened(0.25), MW)
		var lbl := b._label("FRAGILE" if k % 2 == 0 else "THIS SIDE UP", c + Vector3(-s * 0.5 - 0.01, 0, 0), -PI * 0.5, 48, Color("c0392b"), false)
		lbl.pixel_size = 0.006


func _barrels(p: Vector3) -> void:
	var cols := [Color("1f5fa8"), Color("c0392b"), Color("2e8b57")]
	for i in 3:
		var c := p + Vector3((i % 2) * 0.7 - 0.35, 0.45, (i - 1) * 0.75)
		b.batch.add_cylinder(c, 0.32, 0.9, cols[i % cols.size()], Basis(), MMET)
		b.batch.add_cylinder(c + Vector3(0, 0.25, 0), 0.33, 0.05, cols[i % cols.size()].darkened(0.25), Basis(), MMET)
		b.batch.add_cylinder(c - Vector3(0, 0.25, 0), 0.33, 0.05, cols[i % cols.size()].darkened(0.25), Basis(), MMET)
		b._shape_cyl(c, 0.33, 0.9)


func _forklift(p: Vector3) -> void:
	# Küçük forklift: dev eşyaların yanında oyuncak gibi
	b.solid(p + Vector3(0, 0.75, 0), Vector3(1.2, 0.9, 2.0), C_ORANGE, true, MPA)
	b.batch.add_box(p + Vector3(0, 1.25, 0.7), Vector3(1.15, 0.4, 0.6), Color("3a3a3a"), MPA)
	for sx: float in [-1.0, 1.0]:
		b.batch.add_cylinder_between(p + Vector3(sx * 0.5, 1.2, -0.3), p + Vector3(sx * 0.5, 2.3, -0.3), 0.04, C_BLACK, MMET)
		b.batch.add_cylinder_between(p + Vector3(sx * 0.5, 1.2, 0.5), p + Vector3(sx * 0.5, 2.3, 0.5), 0.04, C_BLACK, MMET)
		b.batch.add_cylinder(p + Vector3(sx * 0.62, 0.3, -0.65), 0.3, 0.22, Color("1e1f22"), Basis(Vector3.FORWARD, PI * 0.5), MPA)
		b.batch.add_cylinder(p + Vector3(sx * 0.62, 0.3, 0.65), 0.3, 0.22, Color("1e1f22"), Basis(Vector3.FORWARD, PI * 0.5), MPA)
		b.batch.add_box(p + Vector3(sx * 0.3, 0.1, -1.6), Vector3(0.12, 0.06, 1.2), C_STEEL, MMET)
	b.batch.add_box(p + Vector3(0, 2.3, 0.1), Vector3(1.2, 0.06, 1.0), C_BLACK, MMET)
	b.batch.add_box(p + Vector3(0, 1.3, -1.05), Vector3(1.0, 2.2, 0.1), C_STEEL, MMET)
	b.batch.add_box(p + Vector3(0, 1.05, -0.2), Vector3(0.5, 0.1, 0.5), Color("2b2b2b"), MF)


# ================================================================ hedef ve dev dekor

func _goal_and_decor() -> void:
	var c := Vector3(0, 0, spot_z)
	var hx := isize.x * 0.5
	var hz := isize.z * 0.5
	# Yer işareti: sarı çerçeve
	for sx: float in [-1.0, 1.0]:
		b.batch.add_box(c + Vector3(sx * (hx + 0.3), 0.009, 0), Vector3(0.2, 0.006, isize.z + 0.8), C_YELLOW, MPA)
	for sz: float in [-1.0, 1.0]:
		b.batch.add_box(c + Vector3(0, 0.009, sz * (hz + 0.3)), Vector3(isize.x + 0.8, 0.006, 0.2), C_YELLOW, MPA)
	var rim_in := Vector2(hx + 1.0, hz + 1.0)   # dekor bu sınırın dışında kalır
	match decor:
		"tub":
			# Dev küvet: üç tarafı yüksek kenar, içi açık mavi, musluk ve köpükler
			b.batch.add_box(c + Vector3(0, 0.01, 0.3), Vector3(rim_in.x * 2.0, 0.006, rim_in.y * 2.0 + 0.6), Color("bfe6f5"), MT)
			_rim(c, rim_in, 2.2, 0.9, Color("fbfbf8"), MT, false)
			var tap := c + Vector3(0, 3.2, rim_in.y + 0.45)
			b.batch.add_cylinder_between(tap - Vector3(0, 1.0, 0), tap, 0.25, Color("c0c4c8"), MMET)
			b.batch.add_cylinder_between(tap, tap - Vector3(0, 0.3, 1.4), 0.2, Color("c0c4c8"), MMET)
			for sx2: float in [-1.0, 1.0]:
				b.batch.add_cylinder(tap + Vector3(sx2 * 0.8, -0.2, 0), 0.3, 0.25, Color("e63946") if sx2 < 0 else Color("1f5fa8"), Basis(), MPA)
			for i in 14:
				var bp := c + Vector3(b.rng.randf_range(-rim_in.x - 1.5, rim_in.x + 1.5), b.rng.randf_range(0.3, 1.4), rim_in.y + b.rng.randf_range(-0.2, 1.8))
				if absf(bp.x) < rim_in.x + 0.9 and bp.z < c.z + rim_in.y + 0.9:
					continue
				b.glow.add_sphere(bp, b.rng.randf_range(0.2, 0.55), Color("f2fbff"))
			b.solid(c + Vector3(rim_in.x + 2.2, 0.45, -1.0), Vector3(1.6, 0.9, 1.0), Color("ff8fab"), true, MPA)
			_big_label("BATH TIME!", c + Vector3(0, 4.2, D - c.z - 0.05), PI)
		"pedestal":
			# Sergi standı: alçak platform, kırmızı kadife ipli direkler, müze tabelası
			b.batch.add_cylinder(c + Vector3(0, 0.02, 0), maxf(hx, hz) + 0.9, 0.04, Color("6b2737"), Basis(), MF)
			var r := maxf(rim_in.x, rim_in.y) + 0.8
			var posts := 10
			var prev := Vector3.ZERO
			for i in posts + 1:
				var a := PI * 0.15 + (PI * 1.7) * i / posts
				var pp := c + Vector3(sin(a) * r, 0, cos(a) * r)
				if pp.z < c.z - hz - 0.2 and absf(pp.x) < hx + 1.5:
					prev = Vector3.ZERO
					continue
				b.batch.add_cylinder(pp + Vector3(0, 0.55, 0), 0.06, 1.1, C_GOLD, Basis(), MMET)
				b.batch.add_sphere(pp + Vector3(0, 1.12, 0), 0.1, C_GOLD, MMET)
				b._shape_cyl(pp + Vector3(0, 0.55, 0), 0.1, 1.1)
				if prev != Vector3.ZERO:
					b.batch.add_cylinder_between(prev + Vector3(0, 0.95, 0), pp + Vector3(0, 0.95, 0), 0.04, Color("b0122b"), MF)
				prev = pp
			_big_label("EXHIBIT No. 7", c + Vector3(0, 5.0, D - c.z - 0.05), PI)
		"gift":
			# Dev hediye kutusu: kırmızı duvarlar, sarı kurdele, arkada yaslanmış kapak ve fiyonk
			_rim(c, rim_in, 3.2, 0.7, Color("d62839"), MPA, false)
			for sx3: float in [-1.0, 1.0]:
				b.batch.add_box(c + Vector3(sx3 * (rim_in.x + 0.36), 1.6, 0), Vector3(0.04, 3.2, 1.0), C_YELLOW, MF)
			b.batch.add_box(c + Vector3(0, 1.6, rim_in.y + 0.72), Vector3(1.0, 3.2, 0.04), C_YELLOW, MF)
			var lid := c + Vector3(0, 3.0, D - c.z - 0.8)
			b.batch.add_box_xform(Transform3D(Basis(Vector3.RIGHT, -0.25), lid + Vector3(0, 1.5, 0)), Vector3(rim_in.x * 2.0 + 1.6, 6.0, 0.4), Color("e23b4a"), MPA)
			b.batch.add_sphere(lid + Vector3(-1.3, 4.6, -0.6), 1.2, C_YELLOW, MF, Vector3(1.4, 0.8, 0.5))
			b.batch.add_sphere(lid + Vector3(1.3, 4.6, -0.6), 1.2, C_YELLOW, MF, Vector3(1.4, 0.8, 0.5))
			b.batch.add_sphere(lid + Vector3(0, 4.6, -0.7), 0.6, Color("e0aa1f"), MF)
			_big_label("HAPPY BIRTHDAY!", c + Vector3(0, minf(H - 2.0, 9.5), D - c.z - 0.05), PI)
		"desk":
			# Dev defter yaprağı, silgi ve ataş: kalem defterin üstüne dikilir
			var page := Vector3(rim_in.x * 2.0 + 3.0, 0.03, rim_in.y * 2.0 + 4.0)
			b.batch.add_box(c + Vector3(0, 0.015, 0.5), page, Color("fbfbf6"), MPA)
			var lz := c.z + 0.5 - page.z * 0.5 + 0.6
			while lz < c.z + 0.5 + page.z * 0.5:
				b.batch.add_box(Vector3(0, 0.032, lz), Vector3(page.x, 0.004, 0.06), Color("9cc9e6"), MPA)
				lz += 0.7
			b.batch.add_box(Vector3(-page.x * 0.5 + 1.0, 0.033, c.z + 0.5), Vector3(0.06, 0.004, page.z), Color("f28b82"), MPA)
			b.solid(c + Vector3(page.x * 0.5 + 1.6, 0.9, 1.0), Vector3(2.0, 1.8, 3.6), Color("ff8fab"), true, MPA)
			b.batch.add_box(c + Vector3(page.x * 0.5 + 1.6, 0.9, -0.3), Vector3(2.02, 1.82, 1.0), Color("4361ee"), MPA)
			var clip := c + Vector3(-page.x * 0.5 - 1.6, 0.15, 0.5)
			for k in 2:
				var w := 1.6 - k * 0.5
				b.batch.add_cylinder_between(clip + Vector3(-w * 0.5, 0, -3.0 + k * 0.3), clip + Vector3(-w * 0.5, 0, 3.0 - k * 0.3), 0.08, Color("c0c4c8"), MMET)
				b.batch.add_cylinder_between(clip + Vector3(w * 0.5, 0, -3.0 + k * 0.3), clip + Vector3(w * 0.5, 0, 3.0 - k * 0.3), 0.08, Color("c0c4c8"), MMET)
			_big_label("HOMEWORK", c + Vector3(0, minf(H - 2.0, 8.0), D - c.z - 0.05), PI)
		"kitchen":
			# Dev mutfak: iki yanda 5 m'lik tezgâhlar, kulplar, arkada fayans, tezgâhta dev çay bardağı
			for sx4: float in [-1.0, 1.0]:
				var cx := sx4 * (rim_in.x + 2.6)
				var cc := Vector3(cx, 2.5, c.z + 0.6)
				b.solid(cc, Vector3(4.8, 5.0, isize.z + 2.4), Color("3d7c98"), true, MPA)
				b.batch.add_box(cc + Vector3(0, 2.6, 0), Vector3(5.0, 0.25, isize.z + 2.6), Color("dcd6cc"), MT)
				b.batch.add_box(cc + Vector3(0, 0.8, -(isize.z + 2.4) * 0.5 - 0.06), Vector3(2.2, 0.25, 0.12), Color("c0c4c8"), MMET)
				b.batch.add_box(cc + Vector3(0, -0.6, -(isize.z + 2.4) * 0.5 - 0.01), Vector3(4.6, 0.04, 0.02), Color("2e6177"), MPA)
				var glass := cc + Vector3(0, 4.0, 0)
				b.batch.add_cylinder(glass, 0.8, 2.6, Color("b5451b"), Basis(), MG)
				b.batch.add_cylinder(glass - Vector3(0, 1.25, 0), 1.2, 0.1, Color("f3f3f3"), Basis(), MPA)
			var ty := 0.5
			while ty < minf(H - 1.0, 9.0):
				var tx := -rim_in.x - 5.0
				while tx < rim_in.x + 5.0:
					b.batch.add_box(Vector3(tx + 0.5, ty + 0.5, D - 0.03), Vector3(0.96, 0.96, 0.03), Color("f4efe6") if int(tx + ty) % 2 == 0 else Color("e3eef5"), MT)
					tx += 1.0
				ty += 1.0
			_big_label("GIANT KITCHEN", c + Vector3(0, minf(H - 2.0, 10.5), D - c.z - 0.06), PI)


## Hedefin üç tarafında (arka ve yanlar) kenar duvarı; ön taraf açık kalır.
func _rim(c: Vector3, inner: Vector2, h: float, t: float, col: Color, mat: int, front: bool) -> void:
	for sx: float in [-1.0, 1.0]:
		b.solid(c + Vector3(sx * (inner.x + t * 0.5), h * 0.5, 0.0), Vector3(t, h, inner.y * 2.0 + t * 2.0), col, true, mat)
	b.solid(c + Vector3(0, h * 0.5, inner.y + t * 0.5), Vector3(inner.x * 2.0, h, t), col, true, mat)
	if front:
		b.solid(c + Vector3(0, 0.15, -inner.y - t * 0.5), Vector3(inner.x * 2.0, 0.3, t), col, true, mat)


func _big_label(text: String, p: Vector3, yaw: float) -> void:
	var l := b._label(text, p, yaw, 96, C_BLACK, false)
	l.pixel_size = 0.02
	l.rotation.y = yaw


# ================================================================ tabelalar ve ışık

func _signs() -> void:
	var y := minf(H - 2.5, 11.0)
	var l := b._label("GIANT GOODS CO.", Vector3(0, y, D - 0.06), PI, 96, Color("c0392b"), false)
	l.pixel_size = 0.03
	l.outline_size = 12
	for sx: float in [-1.0, 1.0]:
		var x := sx * (W * 0.5 - 0.05)
		var yaw := -sx * PI * 0.5
		var t1 := b._label("CAUTION: ABSURDLY LARGE OBJECTS", Vector3(x, 4.6, D * 0.3), yaw, 64, C_BLACK, false)
		t1.pixel_size = 0.012
		b.batch.add_box(Vector3(x - sx * 0.0, 4.6, D * 0.3), Vector3(0.03, 1.1, 9.5), C_YELLOW, MPA)
		var t2 := b._label("NO SMALL TALK. ONLY BIG THINGS.", Vector3(x, 4.6, D * 0.75), yaw, 64, Color("f7f3e8"), false)
		t2.pixel_size = 0.011
		b.batch.add_box(Vector3(x, 4.6, D * 0.75), Vector3(0.03, 1.0, 9.0), Color("1f4e79"), MPA)
	# Kaç gün kazasız tabelası (absürt)
	var t3 := b._label("DAYS WITHOUT A GIANT ACCIDENT: 0", Vector3(-W * 0.5 + 0.06, 6.4, D * 0.52), PI * 0.5, 48, Color("f7f3e8"), false)
	t3.pixel_size = 0.009
	b.batch.add_box(Vector3(-W * 0.5 + 0.03, 6.4, D * 0.52), Vector3(0.03, 0.7, 5.8), Color("2b2d42"), MPA)


func _lights() -> void:
	var n := 3
	for i in n:
		var z := D * (i + 0.5) / n
		b._add_light(Vector3(0, H - 2.5, z), 2.2, maxf(H * 1.4, D / n * 1.2), Color(1.0, 0.95, 0.85))


# ================================================================ bilgiler

func _info() -> void:
	var info := b.info
	info.style = "factory"
	info.goal_type = "spot"
	var gsize := Vector3(isize.x + 2.4, isize.y + 1.5, isize.z + 2.4)
	info.goal_aabb = AABB(Vector3(-gsize.x * 0.5, 0.0, spot_z - gsize.z * 0.5), gsize)
	info.goal_center = Vector3(0, 0, spot_z)
	info.goal_facing = Vector3.BACK            # ön yüz ilerleme yönüne (salonun sonuna) bakar
	info.spot_basis = Basis.looking_at(Vector3.BACK, Vector3.UP)
	info.spot_size = isize
	info.npc_pos = Vector3(isize.x * 0.5 + 2.9, 0.0, spot_z - isize.z * 0.5 - 1.8)
	info.npc_yaw = 0.0                         # girişe (oyuncuya) bakar
	var start_z := 8.0
	info.player_spawn = Transform3D(Basis(Vector3.UP, PI), Vector3(0, 0.05, start_z))
	info.item_spawn = Vector3(0, 0, start_z + 0.9 + isize.z * 0.5)
	info.waypoints = [
		Vector3(0, 0, start_z),
		Vector3(0, 0, D * 0.3),
		Vector3(0, 0, D * 0.5 - 3.5),
		Vector3(0, 0, D * 0.5 + 3.5),
		Vector3(0, 0, D * 0.72),
		Vector3(0, 0, spot_z - isize.z * 0.5 - 1.2),
	]
	info.block_aabb = AABB(Vector3(-W * 0.5, -0.5, 0.0), Vector3(W, H + 1.0, D))
	info.apt_aabb = AABB()
	info.cam_scale = clampf(isize.y / 4.5, 1.6, 3.2)
	info.factory = {"width": W, "length": D, "height": H, "gate": gate}
