class_name Homeowner
extends StaticBody3D
## Ev sahibi: dairede bekler, taşıyıcıya döner, el sallar, eşya çarpınca endişelenir,
## teslimde zıplayıp sevinir ve teşekkür eder. Tüm konuşmalar İngilizce.

const OUTFITS := [
	{"body": Color("ff6b6b"), "legs": Color("3a5a99"), "hat": Color("5a3825"), "hair": true},
	{"body": Color("4ecdc4"), "legs": Color("2d2d44"), "hat": Color("e8c170"), "hair": true},
	{"body": Color("ffd166"), "legs": Color("6d597a"), "hat": Color("1b1b1b"), "hair": true},
	{"body": Color("a29bfe"), "legs": Color("2f3e46"), "hat": Color("b5651d"), "hair": true},
	{"body": Color("06d6a0"), "legs": Color("264653"), "hat": Color("8d5524"), "hair": true},
]

var player: Node3D
var item_name := "stuff"
var _visual: PlayerVisual
var _bubble: Label3D
var _bubble_time := 0.0
var _yaw := 0.0
var _home_yaw := 0.0
var _state := "idle"         # idle, wave, worried, cheer, sad
var _state_time := 0.0
var _greeted := false
var _talk_cd := 0.0
var _spin := 0.0
var _rng := RandomNumberGenerator.new()


func setup(pos: Vector3, yaw: float, p_player: Node3D, p_item_name: String, seed_v: int) -> void:
	position = pos
	_yaw = yaw
	_home_yaw = yaw
	player = p_player
	item_name = p_item_name.to_lower()
	_rng.seed = seed_v


func _ready() -> void:
	collision_layer = Config.LAYER_OBSTACLE
	collision_mask = 0
	add_to_group("homeowner")
	var cs := CollisionShape3D.new()
	var cap := CapsuleShape3D.new()
	cap.radius = 0.28
	cap.height = 1.7
	cs.shape = cap
	cs.position = Vector3(0, 0.85, 0)
	add_child(cs)
	_visual = PlayerVisual.new()
	add_child(_visual)
	_visual.apply_outfit(OUTFITS[_rng.randi() % OUTFITS.size()])
	_bubble = Label3D.new()
	_bubble.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	_bubble.font_size = 60
	_bubble.pixel_size = 0.004
	_bubble.outline_size = 14
	_bubble.outline_modulate = Color(0.1, 0.1, 0.15)
	_bubble.modulate = Color(1, 1, 1)
	_bubble.no_depth_test = true
	_bubble.position = Vector3(0, 2.25, 0)
	_bubble.visible = false
	_bubble.width = 900.0
	_bubble.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	add_child(_bubble)
	rotation.y = _yaw


func say(text: String, duration: float = 2.8) -> void:
	_bubble.text = text
	_bubble.visible = true
	_bubble_time = duration
	_bubble.scale = Vector3.ONE * 0.6
	var tw := create_tween()
	tw.tween_property(_bubble, "scale", Vector3.ONE, 0.18).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)


func _pick(lines: Array) -> String:
	return str(lines[_rng.randi() % lines.size()]).replace("{item}", item_name)


func _physics_process(delta: float) -> void:
	_talk_cd = maxf(0.0, _talk_cd - delta)
	_state_time += delta
	if _bubble_time > 0.0:
		_bubble_time -= delta
		if _bubble_time <= 0.0:
			_bubble.visible = false
	var to_player := Vector3.ZERO
	var dist := 999.0
	if player != null and is_instance_valid(player):
		to_player = player.global_position - global_position
		to_player.y = 0.0
		dist = to_player.length()
		# Aynı katta ve yakındaysa selamla
		if not _greeted and dist < 7.0 and absf(player.global_position.y - global_position.y) < 1.2 and _state == "idle":
			_greeted = true
			set_state("wave", 2.6)
			say(_pick(["Hi! Over here, please!", "Oh, my new {item}! This way!", "Hello! Right here, thank you!"]))
	match _state:
		"cheer":
			_spin += delta * 5.0
			rotation.y = _yaw + sin(_spin) * 0.6 + (_spin if _state_time > 1.6 and _state_time < 2.8 else 0.0)
		_:
			if dist < 10.0:
				var target := atan2(-to_player.x, -to_player.z)
				_yaw = lerp_angle(_yaw, target, 1.0 - exp(-4.0 * delta))
			else:
				_yaw = lerp_angle(_yaw, _home_yaw, 1.0 - exp(-2.0 * delta))
			rotation.y = _yaw
			if (_state == "wave" or _state == "worried") and _state_time > _state_dur:
				_state = "idle"
	_visual.update_anim(delta, {
		"speed": 0.0,
		"wave": _state == "wave",
		"cheer": _state == "cheer",
		"worried": _state == "worried",
		"sad": _state == "sad",
	})


var _state_dur := 0.0


func set_state(s: String, dur: float = 0.0) -> void:
	_state = s
	_state_time = 0.0
	_state_dur = dur


## Eşya sert çarptığında (taşıyıcı yakındaysa) endişelenir.
func react_damage(amount: float, near: bool) -> void:
	if _state == "cheer" or _state == "sad" or not near or _talk_cd > 0.0:
		return
	_talk_cd = 4.0
	set_state("worried", 1.6)
	if amount >= 15.0:
		say(_pick(["NOOO! My {item}!", "Oh no, that was loud!", "Please, be careful!!"]))
	else:
		say(_pick(["Careful!", "Easy, easy!", "Watch it!", "Gently, please!"]))


## Eşya ev sahibine çarptığında.
func on_bumped() -> void:
	if _talk_cd > 0.0 or _state == "cheer":
		return
	_talk_cd = 3.0
	set_state("worried", 1.0)
	say(_pick(["Hey! Watch it!", "Ouch! My toes!", "Careful, I'm right here!"]), 2.0)


func hint_orientation() -> void:
	if _talk_cd > 0.0:
		return
	_talk_cd = 4.5
	say("Almost! Turn it so the front faces the room.", 3.0)


func celebrate(perfect: bool) -> void:
	set_state("cheer")
	_spin = 0.0
	if player != null and is_instance_valid(player):
		var d := player.global_position - global_position
		_yaw = atan2(-d.x, -d.z)
	say("Thank you so much! I'm so happy!", 3.0)
	var follow := "Not a single scratch! You're the best mover ever!" if perfect else _pick(["It looks perfect here!", "Wonderful job, thank you!", "I love it! Thank you!"])
	var tm := get_tree().create_timer(3.0, false)
	tm.timeout.connect(func():
		if is_instance_valid(self):
			say(follow, 3.0))


func sad() -> void:
	set_state("sad")
	say(_pick(["Oh no... my {item}...", "It's... broken...", "Noooo..."]), 4.0)
