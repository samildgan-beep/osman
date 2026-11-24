class_name SwingDoor
extends Node3D
## Koridorda açık kalmış kapı. Oyuncu eli boşken yaklaşıp "KAPAT" ile duvara yaslar.
## Eşya elindeyken kapatamaz: önce eşyayı bırakmak gerekir (küçük bir bulmaca).

const OPEN_DEG := 38.0
const CLOSED_DEG := 3.0
const SWING_TIME := 0.7

var _body: AnimatableBody3D
var _hinge := Vector3.ZERO
var _along := Vector3.RIGHT
var _into := Vector3.BACK
var _width := 0.85
var _height := 2.0
var _angle := OPEN_DEG
var _target := OPEN_DEG
var _closed := false


func setup(hinge: Vector3, along: Vector3, into_dir: Vector3, width: float, height: float) -> void:
	_hinge = hinge
	_along = along.normalized()
	_into = into_dir.normalized()
	_width = clampf(width, 0.4, 1.2)
	_height = clampf(height, 1.0, 2.4)


func _ready() -> void:
	add_to_group("interactable")
	_body = AnimatableBody3D.new()
	_body.sync_to_physics = true
	_body.collision_layer = Config.LAYER_WORLD
	_body.collision_mask = 0
	add_child(_body)
	var size := Vector3(_width, _height, 0.05)
	var cs := CollisionShape3D.new()
	var bs := BoxShape3D.new()
	bs.size = size
	cs.shape = bs
	cs.position = Vector3(_width * 0.5, _height * 0.5, 0)
	_body.add_child(cs)
	var mi := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = size
	mi.mesh = bm
	mi.position = cs.position
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color("8b5a3c")
	mat.roughness = 0.7
	mi.material_override = mat
	_body.add_child(mi)
	# Kapı kolu
	var handle := MeshInstance3D.new()
	var hm := BoxMesh.new()
	hm.size = Vector3(0.12, 0.03, 0.12)
	handle.mesh = hm
	handle.position = Vector3(_width - 0.1, 1.0, 0)
	var hmat := StandardMaterial3D.new()
	hmat.albedo_color = Color("d4af37")
	hmat.metallic = 0.8
	hmat.roughness = 0.3
	handle.material_override = hmat
	_body.add_child(handle)
	_apply_angle()


func _physics_process(delta: float) -> void:
	if is_equal_approx(_angle, _target):
		return
	var speed := (OPEN_DEG - CLOSED_DEG) / SWING_TIME
	_angle = move_toward(_angle, _target, speed * delta)
	_apply_angle()


func _apply_angle() -> void:
	var a := deg_to_rad(_angle)
	var x := (_along * cos(a) + _into * sin(a)).normalized()
	var y := Vector3.UP
	_body.global_transform = Transform3D(Basis(x, y, x.cross(y)), _hinge)


# ---- Etkileşim arayüzü (oyuncu tarafından kullanılır)

func interact_position() -> Vector3:
	var a := deg_to_rad(_angle)
	return _hinge + (_along * cos(a) + _into * sin(a)) * (_width * 0.5)


func can_interact(player_holding: bool) -> bool:
	return not _closed and not player_holding


func prompt_text(player_holding: bool) -> String:
	if _closed:
		return ""
	return "Put it down first" if player_holding else "CLOSE"


func interact() -> void:
	if _closed:
		return
	_closed = true
	_target = CLOSED_DEG
	AudioManager.play("putdown", -4.0, 0.6)
