class_name Cat
extends AnimatableBody3D
## Merdivende/sahanlıkta gidip gelen kedi. Önü kapanınca bekler ve miyavlar,
## eşya çarparsa kaçar. Uzun süre önü kapalı kalırsa yolun diğer ucuna atlar
## (oyuncu asla kilitli kalmaz).

const SPEED := 0.45
const FLEE_SPEED := 1.4
const PAUSE_TIME := 1.4
const BLOCK_TELEPORT_TIME := 3.5

var _points: Array = []
var _target_idx := 1
var _pos := Vector3.ZERO
var _pause := 0.5
var _blocked_time := 0.0
var _flee_time := 0.0
var _meow_cd := 0.0
var _anim_t := 0.0
var _visual: Node3D
var _tail: Node3D
var _facing := Vector3.FORWARD


func setup(points: Array) -> void:
	_points = points.duplicate()
	if _points.size() < 2:
		_points = [Vector3.ZERO, Vector3(0, 0, 1)]
	_pos = _points[0]


func _ready() -> void:
	sync_to_physics = true
	collision_layer = Config.LAYER_OBSTACLE
	collision_mask = Config.LAYER_PLAYER | Config.LAYER_ITEM
	add_to_group("cat")
	var cs := CollisionShape3D.new()
	var bs := BoxShape3D.new()
	bs.size = Vector3(0.24, 0.32, 0.52)
	cs.shape = bs
	cs.position = Vector3(0, 0.17, 0)
	add_child(cs)
	_build_visual()
	_facing = (_points[1] - _points[0]).normalized()
	_apply_transform()


func _build_visual() -> void:
	_visual = Node3D.new()
	add_child(_visual)
	var fur := StandardMaterial3D.new()
	fur.albedo_color = Color("e08a3c")
	fur.roughness = 0.9
	var dark := StandardMaterial3D.new()
	dark.albedo_color = Color("b3622a")
	var white := StandardMaterial3D.new()
	white.albedo_color = Color("f4efe6")
	_part(BoxMesh, Vector3(0.2, 0.17, 0.4), Vector3(0, 0.2, 0), fur)                  # gövde
	_part(BoxMesh, Vector3(0.17, 0.15, 0.15), Vector3(0, 0.33, -0.24), fur)           # kafa
	_part(BoxMesh, Vector3(0.05, 0.06, 0.03), Vector3(-0.055, 0.43, -0.25), dark)     # kulak
	_part(BoxMesh, Vector3(0.05, 0.06, 0.03), Vector3(0.055, 0.43, -0.25), dark)
	_part(BoxMesh, Vector3(0.1, 0.05, 0.02), Vector3(0, 0.3, -0.32), white)           # ağız
	for lx in [-0.07, 0.07]:
		for lz in [-0.14, 0.14]:
			_part(BoxMesh, Vector3(0.05, 0.12, 0.05), Vector3(lx, 0.06, lz), dark)
	_tail = Node3D.new()
	_tail.position = Vector3(0, 0.26, 0.2)
	_visual.add_child(_tail)
	var tail_mesh := MeshInstance3D.new()
	var tm := BoxMesh.new()
	tm.size = Vector3(0.04, 0.04, 0.26)
	tail_mesh.mesh = tm
	tail_mesh.position = Vector3(0, 0.06, 0.12)
	tail_mesh.rotation = Vector3(0.6, 0, 0)
	tail_mesh.material_override = fur
	_tail.add_child(tail_mesh)


func _part(mesh_class, size: Vector3, pos: Vector3, mat: Material) -> void:
	var mi := MeshInstance3D.new()
	var m = mesh_class.new()
	m.size = size
	mi.mesh = m
	mi.position = pos
	mi.material_override = mat
	_visual.add_child(mi)


func _physics_process(delta: float) -> void:
	_meow_cd = maxf(0.0, _meow_cd - delta)
	_anim_t += delta
	if _pause > 0.0:
		_pause -= delta
		_animate(false)
		return
	var target: Vector3 = _points[_target_idx]
	var to := target - _pos
	var dist := to.length()
	if dist < 0.02:
		_target_idx = 1 - _target_idx
		_pause = PAUSE_TIME if _flee_time <= 0.0 else 0.1
		return
	var speed := FLEE_SPEED if _flee_time > 0.0 else SPEED
	_flee_time = maxf(0.0, _flee_time - delta)
	var step := to / dist * minf(speed * delta, dist)
	var flat := Vector3(to.x, 0, to.z)
	if flat.length_squared() > 0.0001:
		_facing = flat.normalized()
	# Önü kapalı mı? (oyuncu veya eşya)
	var xf := _make_transform(_pos)
	if test_move(xf, step + step.normalized() * 0.05):
		_blocked_time += delta
		if _meow_cd <= 0.0:
			meow()
		if _blocked_time > BLOCK_TELEPORT_TIME:
			# Diğer uca atla
			_pos = _points[1 - _target_idx]
			_target_idx = 1 - _target_idx
			_blocked_time = 0.0
			_pause = 1.0
			_apply_transform()
		_animate(false)
		return
	_blocked_time = 0.0
	_pos += step
	_apply_transform()
	_animate(true)


func _make_transform(p: Vector3) -> Transform3D:
	var fwd := _facing
	var right := fwd.cross(Vector3.UP).normalized()
	if right.length_squared() < 0.5:
		right = Vector3.RIGHT
	# Kedinin yerel -Z'si ileri bakar
	return Transform3D(Basis(right, Vector3.UP, -fwd), p)


func _apply_transform() -> void:
	global_transform = _make_transform(_pos)


func _animate(walking: bool) -> void:
	if _visual == null:
		return
	_visual.position.y = absf(sin(_anim_t * 10.0)) * 0.02 if walking else 0.0
	if _tail != null:
		_tail.rotation.y = sin(_anim_t * (6.0 if walking else 2.0)) * 0.5


func meow() -> void:
	_meow_cd = 2.5
	AudioManager.play("meow", -2.0, randf_range(0.9, 1.15), 0.5)


## Eşya veya oyuncu çarptığında çağrılır.
func on_bumped() -> void:
	if _meow_cd <= 0.5:
		meow()
	_flee_time = 2.0
	_pause = 0.0
