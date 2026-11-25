extends Node
## Oyunun tüm fizik ve denge ayarları tek yerde.
## Bir değeri değiştirmek için yalnızca bu dosyayı düzenleyin.

# --- Fizik katmanları (project.godot -> layer_names ile aynı) ---
const LAYER_WORLD := 1
const LAYER_PLAYER := 2
const LAYER_ITEM := 4
const LAYER_OBSTACLE := 8
const LAYER_TRIGGER := 16

# --- Oyuncu hareketi ---
const WALK_SPEED := 3.4             # m/s, elinde eşya yokken
const ACCELERATION := 14.0          # m/s²
const DECELERATION := 18.0
const TURN_SPEED := 9.0             # rad/s, karakterin yöne dönmesi
const CARRY_TURN_SPEED := 3.2       # eşya taşırken daha yavaş döner
const STAIR_SPEED_MULT := 0.68      # merdivende ek yavaşlama
const BACK_CARRY_SPEED_MULT := 0.85 # sırtta taşırken
const MIN_CARRY_SPEED_MULT := 0.32  # en ağır eşyada bile en az bu kadar hız
const WEIGHT_SPEED_FACTOR := 0.011  # her kg için hız kaybı oranı
const GRAVITY := 9.8
const FLOOR_MAX_ANGLE_DEG := 50.0
const FLOOR_SNAP := 0.45
const PLAYER_RADIUS := 0.3
const PLAYER_HEIGHT := 1.75

# --- Dayanıklılık ---
const STAMINA_MAX := 100.0
const STAMINA_FREE_WEIGHT := 10.0      # bu kilonun altı yorulmaz
const STAMINA_DRAIN_PER_KG := 0.055    # kg başına saniyede tüketim (yürürken)
const STAMINA_STAIR_MULT := 1.8
const STAMINA_IDLE_MULT := 0.35        # eşya elde, dururken
const STAMINA_REGEN_REST := 22.0       # mola verirken (eşya yerde)
const STAMINA_REGEN_FREE := 12.0       # eşyasız yürürken
const STAMINA_WARN := 25.0
const CRUSH_WEIGHT := 40.0            # bu kilodan ağır eşyada güç biterse taşıyıcı altında ezilir

# --- Eşya tutma ---
const HOLD_GAP := 0.32               # karakter gövdesi ile eşya arası boşluk
const HOLD_HEIGHT := 0.95            # varsayılan eşya merkezi yüksekliği (ayaktan)
const LIFT_MIN := -0.55
const LIFT_MAX := 0.85
const LIFT_SPEED := 0.75             # m/s
const PICKUP_RANGE := 1.9
const BACK_ROT_LIMIT_DEG := 28.0     # sırtta taşırken izin verilen yatırma
const ITEM_FOLLOW_MAX_LAG := 0.22    # eşya bu kadar geride kalırsa karakter ilerleyemez
const ITEM_FORCE_DROP_LAG := 1.3     # takılma çok büyürse eşya bırakılır
const ROTATION_SUBSTEP_DEG := 6.0    # büyük dönüşler küçük adımlarla denenir
const ITEM_GRAVITY := 9.8
const ITEM_MAX_FALL_SPEED := 9.0
const PUT_DOWN_SPEED := 0.9          # m/s, yavaşça yere bırakma

# --- Döndürme kontrolü ---
const ROTATE_DEG_PER_PIXEL := 0.32
const PRECISE_MULT := 0.25
const KEY_ROTATE_DEG_PER_SEC := 90.0

# --- Hasar modeli ---
const DURABILITY_MAX := 100.0
const IMPACT_THRESHOLD := 0.45       # m/s altı çarpma zarar vermez
const IMPACT_DAMAGE_PER_MS := 15.0   # eşiğin üstündeki her m/s için hasar
const IMPACT_MAX_DAMAGE := 45.0      # tek çarpmada en fazla
const SCRAPE_DAMAGE_PER_SEC := 2.2   # sürekli sürtünme
const CONTACT_COOLDOWN := 0.3        # aynı temas tekrar tam hasar vermez
const ROTATION_BLOCK_DAMAGE := 0.5   # dönerken takılma (sürtünme)
const DROP_DAMAGE_MULT := 1.4        # düşmede ek çarpan
const PROXIMITY_MARGIN := 0.10       # yakınlık uyarısı mesafesi (m)
const OBSTACLE_BUMP_DAMAGE := 4.0

# --- Geri bildirim ---
const HAPTIC_LIGHT_MS := 25
const HAPTIC_HEAVY_MS := 70
const FLASH_TIME := 0.25

# --- Kamera ---
const CAM_DIST_DEFAULT := 4.6
const CAM_DIST_MIN := 1.6
const CAM_DIST_MAX := 9.0
const CAM_PITCH_DEFAULT := -28.0
const CAM_PITCH_MIN := -86.0
const CAM_PITCH_MAX := 35.0          # normal modda yukarı bakış sınırı
const CAM_FREE_PITCH_MAX := 70.0     # serbest bakışta yukarı bakış sınırı
const CAM_PAN_SPEED := 4.5           # serbest bakışta kaydırma hızı (m/s)
const CAM_RISE_SPEED := 3.0          # serbest bakışta yükselme hızı (m/s)
const CAM_ORBIT_DEG_PER_PIXEL := 0.28
const CAM_PINCH_FACTOR := 0.012
const CAM_SMOOTH := 10.0
const CAM_COLLISION_MARGIN := 0.22
const CAM_TOP_CUT := 1.85            # üstten görünümde duvar kesme yüksekliği
const CAM_INDOOR_CUT := 1.95         # bina içinde duvar kesme yüksekliği (ayaktan)
const CAM_CEILING_SHOW := 2.95       # bu yüksekliğe kadarki tavanlar yarı saydam görünür

# --- Puanlama ---
const STAR3_DURABILITY := 90.0
const STAR2_DURABILITY := 60.0
const STAR2_TIME_MULT := 1.6

# --- Kayıt ---
const SAVE_PATH := "user://save.json"
const SAVE_BACKUP_PATH := "user://save.backup.json"
const SAVE_TMP_PATH := "user://save.tmp"
const SAVE_VERSION := 1


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_setup_input_map()


## Klavye/fare kısayolları (masaüstünde test için). Dokunmatik kontroller ayrıca çalışır.
func _setup_input_map() -> void:
	var map := {
		"move_forward": [KEY_W, KEY_UP],
		"move_back": [KEY_S, KEY_DOWN],
		"move_left": [KEY_A, KEY_LEFT],
		"move_right": [KEY_D, KEY_RIGHT],
		"rot_yaw_left": [KEY_J],
		"rot_yaw_right": [KEY_L],
		"rot_pitch_up": [KEY_I],
		"rot_pitch_down": [KEY_K],
		"rot_roll_left": [KEY_U],
		"rot_roll_right": [KEY_O],
		"lift_up": [KEY_E],
		"lift_down": [KEY_Q],
		"precise": [KEY_SHIFT],
		"interact": [KEY_SPACE, KEY_F],
		"rest": [KEY_R],
		"reset_rotation": [KEY_T],
		"cam_back": [KEY_1],
		"cam_top": [KEY_2],
		"cam_side": [KEY_3],
		"pause": [KEY_ESCAPE, KEY_P],
		"look_toggle": [KEY_V, KEY_C],
	}
	for action in map:
		if not InputMap.has_action(action):
			InputMap.add_action(action, 0.2)
		for key in map[action]:
			var ev := InputEventKey.new()
			ev.physical_keycode = key
			InputMap.action_add_event(action, ev)
