class_name FX
extends Node3D
## Fizik ayrıntı efektleri:
## - Eşya duvara/korkuluğa sürtünce yüzeyde kalıcı çizik izleri
## - Sert çarpmada duvarda çökme izi, toz bulutu, kopan sıva ve eşya parçaları
## - Eşya kırılınca parçalara ayrılması (fizikli parçalar)
## - Kutlama konfetisi
## Telefon performansı için iz ve parça sayısı sınırlıdır (eskiler silinir).

const MAX_MARKS := 160
const MAX_DEBRIS := 70
const LAYER_DEBRIS := 32

var _marks: Array[Node3D] = []
var _debris: Array = []          # {"n": RigidBody3D, "mi": MeshInstance3D, "life": float}
var _quad: QuadMesh
var _mark_shader: Shader
var _scratch_mats: Array[ShaderMaterial] = []
var _dent_mats: Array[ShaderMaterial] = []
var _floor_scuff_mats: Array[ShaderMaterial] = []
var _mat_cache := {}
var _phys_mat: PhysicsMaterial
var _last_mark_pos := Vector3(INF, INF, INF)
var _last_mark_time := -10.0
var _rng := RandomNumberGenerator.new()


func _ready() -> void:
	_rng.randomize()
	_quad = QuadMesh.new()
	_quad.size = Vector2.ONE
	_mark_shader = load("res://shaders/mark.gdshader")
	for i in 6:
		_scratch_mats.append(_make_mark_mat(0.0, float(i) * 7.3 + 1.0, Color(0.16, 0.13, 0.11, 0.7)))
	for i in 3:
		_dent_mats.append(_make_mark_mat(1.0, float(i) * 5.1 + 2.0, Color(0.3, 0.27, 0.24, 0.8)))
	for i in 3:
		_floor_scuff_mats.append(_make_mark_mat(0.0, float(i) * 3.7 + 9.0, Color(0.1, 0.09, 0.08, 0.45)))
	_phys_mat = PhysicsMaterial.new()
	_phys_mat.bounce = 0.3
	_phys_mat.friction = 0.8


func _make_mark_mat(kind: float, seed_v: float, col: Color) -> ShaderMaterial:
	var m := ShaderMaterial.new()
	m.shader = _mark_shader
	m.set_shader_parameter("kind", kind)
	m.set_shader_parameter("seed", seed_v)
	m.set_shader_parameter("mark_color", col)
	return m


# ================================================================ temas olayı

## Eşyanın her yüzey teması için çağrılır.
func on_contact(point: Vector3, normal: Vector3, vel: Vector3, damage: float, hard: bool, item_colors: Array) -> void:
	if not point.is_finite() or normal.length_squared() < 0.5:
		return
	var tang := vel - normal * vel.dot(normal)
	var slide := tang.length()
	var now := Time.get_ticks_msec() / 1000.0
	var moved := point.distance_to(_last_mark_pos)
	# Sürtünme çizikleri: kaydıkça zincir halinde iz bırakır
	if (slide > 0.12 or damage >= 0.8 or hard) and (moved > 0.07 or now - _last_mark_time > 0.35):
		_last_mark_pos = point
		_last_mark_time = now
		var length := clampf(0.12 + slide * 0.08 + damage * 0.01, 0.12, 0.35)
		scratch(point, normal, tang, length)
	if hard:
		dent(point, normal, damage)
		dust(point, normal, damage)
		var plaster := [Color("f2ece0"), Color("e0d6c4"), Color("cfc4b0")]
		chips(point + normal * 0.03, normal, plaster, clampi(int(damage / 4.0), 2, 6), 2.2)
		if not item_colors.is_empty():
			chips(point + normal * 0.06, normal, item_colors, clampi(int(damage / 6.0), 1, 5), 2.8)


# ================================================================ izler

func scratch(point: Vector3, normal: Vector3, dir: Vector3, length: float) -> void:
	var floor_like := normal.y > 0.7
	var mats := _floor_scuff_mats if floor_like else _scratch_mats
	_add_mark(point, normal, dir, Vector2(length, _rng.randf_range(0.03, 0.06)), mats[_rng.randi() % mats.size()])


func dent(point: Vector3, normal: Vector3, damage: float) -> void:
	var s := clampf(0.08 + damage * 0.008, 0.1, 0.32)
	_add_mark(point, normal, Vector3.ZERO, Vector2(s, s), _dent_mats[_rng.randi() % _dent_mats.size()])


func _add_mark(point: Vector3, normal: Vector3, dir: Vector3, size: Vector2, mat: Material) -> void:
	var z := normal.normalized()
	var x := dir - z * dir.dot(z)
	if x.length_squared() < 0.0001:
		x = z.cross(Vector3.UP)
		if x.length_squared() < 0.0001:
			x = z.cross(Vector3.RIGHT)
	x = x.normalized()
	# Hafif rastgele açı: çizikler birbirinin kopyası gibi durmasın
	x = x.rotated(z, _rng.randf_range(-0.15, 0.15)).normalized()
	var y := z.cross(x).normalized()
	var mi := MeshInstance3D.new()
	mi.mesh = _quad
	mi.material_override = mat
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(mi)
	mi.global_transform = Transform3D(Basis(x * size.x, y * size.y, z), point + z * (0.004 + _marks.size() * 0.00002))
	_marks.append(mi)
	if _marks.size() > MAX_MARKS:
		var old: Node3D = _marks.pop_front()
		if is_instance_valid(old):
			old.queue_free()


# ================================================================ parçacıklar

func dust(point: Vector3, normal: Vector3, damage: float) -> void:
	var p := CPUParticles3D.new()
	p.one_shot = true
	p.emitting = false
	p.amount = clampi(int(8 + damage), 10, 28)
	p.lifetime = 0.9
	p.explosiveness = 0.95
	p.direction = normal
	p.spread = 60.0
	p.initial_velocity_min = 0.4
	p.initial_velocity_max = 1.6
	p.gravity = Vector3(0, -1.2, 0)
	p.damping_min = 1.5
	p.damping_max = 2.5
	# Boyut doğrudan ağda: ölçek çarpanı her işleyicide aynı davranmayabiliyor
	p.scale_amount_min = 0.6
	p.scale_amount_max = 1.5
	var qm := QuadMesh.new()
	qm.size = Vector2(0.11, 0.11)
	var m := StandardMaterial3D.new()
	m.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.vertex_color_use_as_albedo = true
	qm.material = m
	p.mesh = qm
	var g := Gradient.new()
	g.set_color(0, Color(0.92, 0.89, 0.82, 0.8))
	g.set_color(1, Color(0.92, 0.89, 0.82, 0.0))
	p.color_ramp = g
	add_child(p)
	p.global_position = point + normal * 0.05
	p.emitting = true
	_auto_free(p, 1.5)


func confetti(pos: Vector3, amount: int = 90) -> void:
	var p := CPUParticles3D.new()
	p.one_shot = true
	p.emitting = false
	p.amount = amount
	p.lifetime = 2.6
	p.explosiveness = 0.9
	p.direction = Vector3.UP
	p.spread = 70.0
	p.initial_velocity_min = 3.0
	p.initial_velocity_max = 6.0
	p.gravity = Vector3(0, -4.0, 0)
	p.damping_min = 0.8
	p.damping_max = 1.6
	p.angular_velocity_min = -540.0
	p.angular_velocity_max = 540.0
	p.scale_amount_min = 0.7
	p.scale_amount_max = 1.3
	var qm := QuadMesh.new()
	qm.size = Vector2(0.07, 0.045)
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.vertex_color_use_as_albedo = true
	m.cull_mode = BaseMaterial3D.CULL_DISABLED
	m.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
	qm.material = m
	p.mesh = qm
	var g := Gradient.new()
	g.set_color(0, Color("ff4d6d"))
	g.set_color(1, Color("4cc9f0"))
	g.add_point(0.25, Color("ffd23f"))
	g.add_point(0.5, Color("3ddc97"))
	g.add_point(0.75, Color("c77dff"))
	p.color_initial_ramp = g
	add_child(p)
	p.global_position = pos
	p.emitting = true
	_auto_free(p, 3.5)


func _auto_free(n: Node, sec: float) -> void:
	var tm := get_tree().create_timer(sec, false)
	# Doğrudan metoda bağla: nesne silinirse bağlantı kendiliğinden kopar
	tm.timeout.connect(n.queue_free)


# ================================================================ fizikli parçalar

func chips(point: Vector3, normal: Vector3, colors: Array, count: int, speed: float) -> void:
	for i in count:
		var s := _rng.randf_range(0.025, 0.06)
		var size := Vector3(s, s * _rng.randf_range(0.4, 1.0), s * _rng.randf_range(0.6, 1.2))
		var v := (normal + Vector3(_rng.randf_range(-0.7, 0.7), _rng.randf_range(0.2, 1.0), _rng.randf_range(-0.7, 0.7))).normalized() * speed * _rng.randf_range(0.5, 1.0)
		var c: Color = colors[_rng.randi() % colors.size()]
		spawn_piece(point, size, Basis(), c, v, 3.5)


func spawn_piece(pos: Vector3, size: Vector3, basis: Basis, color: Color, vel: Vector3, life: float, glossy: bool = false) -> void:
	size = Vector3(maxf(size.x, 0.012), maxf(size.y, 0.012), maxf(size.z, 0.012))
	var rb := RigidBody3D.new()
	rb.collision_layer = LAYER_DEBRIS
	rb.collision_mask = Config.LAYER_WORLD | Config.LAYER_STEPS
	rb.mass = clampf(size.x * size.y * size.z * 600.0, 0.05, 8.0)
	rb.physics_material_override = _phys_mat
	rb.continuous_cd = false
	var cs := CollisionShape3D.new()
	var bs := BoxShape3D.new()
	bs.size = size
	cs.shape = bs
	rb.add_child(cs)
	var mi := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = size
	mi.mesh = bm
	mi.material_override = _material_for(color, glossy)
	rb.add_child(mi)
	add_child(rb)
	rb.global_transform = Transform3D(basis.orthonormalized(), pos)
	rb.linear_velocity = vel
	rb.angular_velocity = Vector3(_rng.randf_range(-8, 8), _rng.randf_range(-8, 8), _rng.randf_range(-8, 8))
	_debris.append({"n": rb, "mi": mi, "life": life + _rng.randf_range(0.0, 1.0)})
	while _debris.size() > MAX_DEBRIS:
		var old: Dictionary = _debris.pop_front()
		if is_instance_valid(old.n):
			old.n.queue_free()


func _material_for(color: Color, glossy: bool) -> StandardMaterial3D:
	var key := color.to_html() + ("g" if glossy else "")
	if _mat_cache.has(key):
		return _mat_cache[key]
	var m := StandardMaterial3D.new()
	m.albedo_color = color
	m.roughness = 0.15 if glossy else 0.6
	m.metallic = 0.2 if glossy else 0.0
	_mat_cache[key] = m
	return m


## Eşyayı parçalara ayırır: her görünüm parçası birkaç fizikli parçaya bölünür.
func shatter(parts: Array, center: Vector3, base_vel: Vector3) -> void:
	var budget := 46
	for p in parts:
		if budget <= 0:
			break
		var psize: Vector3 = p.size
		var ppos: Vector3 = p.pos
		var pbasis: Basis = p.basis
		var col: Color = p.color
		var thin := minf(psize.x, minf(psize.y, psize.z)) < 0.012
		var vol := psize.x * psize.y * psize.z
		var count := clampi(int(vol / 0.012) + 2, 2, 9)
		if thin:
			count = clampi(int(psize.x * psize.y * 30.0) + 3, 3, 10)
		count = mini(count, budget)
		budget -= count
		var k := pow(float(count), 1.0 / 3.0)
		for i in count:
			var local := Vector3(_rng.randf_range(-0.4, 0.4) * psize.x, _rng.randf_range(-0.4, 0.4) * psize.y, _rng.randf_range(-0.4, 0.4) * psize.z)
			var wp := ppos + pbasis * local
			var s := psize / k * _rng.randf_range(0.7, 1.1)
			if thin:
				s = Vector3(psize.x * _rng.randf_range(0.12, 0.3), psize.y * _rng.randf_range(0.12, 0.3), maxf(psize.z, 0.01))
			var out := (wp - center)
			out = out.normalized() if out.length_squared() > 0.0001 else Vector3.UP
			var v := base_vel * 0.5 + out * _rng.randf_range(1.5, 3.5) + Vector3.UP * _rng.randf_range(1.0, 3.0)
			spawn_piece(wp, s, pbasis, col, v, 6.0, thin)
	dust(center, Vector3.UP, 25.0)


func _process(delta: float) -> void:
	var i := 0
	while i < _debris.size():
		var d: Dictionary = _debris[i]
		d.life = float(d.life) - delta
		if not is_instance_valid(d.n):
			_debris.remove_at(i)
			continue
		if float(d.life) < 0.6:
			var sc := clampf(float(d.life) / 0.6, 0.01, 1.0)
			d.mi.scale = Vector3.ONE * sc
		if float(d.life) <= 0.0:
			d.n.queue_free()
			_debris.remove_at(i)
			continue
		i += 1
