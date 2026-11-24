extends Node
## Oyun ilerlemesi, ayarlar ve kayıt sistemi.
## - Kayıt önce geçici dosyaya yazılır, sonra asıl dosyanın yerine taşınır (yarım kalmış kayıt olmaz).
## - Önceki sağlam kayıt yedek olarak saklanır.
## - Bozuk/eksik kayıtta oyun çökmez: yedek, o da yoksa varsayılan kullanılır.
## - Okunan her değer tür ve aralık kontrolünden geçer.

signal progress_changed
signal settings_changed

const DEFAULT_SETTINGS := {
	"sfx_volume": 0.9,
	"music_volume": 0.5,
	"vibration": true,
	"sensitivity": 1.0,
	"camera_sensitivity": 1.0,
	"invert_pitch": false,
	"quality": 1,            # 0 düşük, 1 orta, 2 yüksek
	"show_guide": true,
	"left_handed": false,
}

## Kıyafetler: [id, ad, gereken yıldız, gövde rengi, pantolon rengi, kask/şapka rengi]
const OUTFITS := [
	{"id": "klasik", "name": "Klasik Tulum", "stars": 0, "body": Color(0.2, 0.45, 0.85), "legs": Color(0.18, 0.2, 0.28), "hat": Color(0.95, 0.75, 0.15)},
	{"id": "turuncu", "name": "Turuncu Yelek", "stars": 6, "body": Color(1.0, 0.5, 0.1), "legs": Color(0.25, 0.25, 0.3), "hat": Color(0.95, 0.95, 0.95)},
	{"id": "yesil", "name": "Orman Ekibi", "stars": 12, "body": Color(0.2, 0.6, 0.3), "legs": Color(0.3, 0.22, 0.15), "hat": Color(0.15, 0.35, 0.2)},
	{"id": "kirmizi", "name": "Kırmızı Ekspres", "stars": 20, "body": Color(0.85, 0.15, 0.15), "legs": Color(0.1, 0.1, 0.12), "hat": Color(0.1, 0.1, 0.12)},
	{"id": "mor", "name": "Gece Vardiyası", "stars": 30, "body": Color(0.4, 0.2, 0.65), "legs": Color(0.12, 0.1, 0.2), "hat": Color(0.85, 0.8, 1.0)},
	{"id": "altin", "name": "Altın Taşıyıcı", "stars": 42, "body": Color(0.95, 0.75, 0.2), "legs": Color(0.45, 0.33, 0.1), "hat": Color(1.0, 0.9, 0.5)},
]

var settings: Dictionary = DEFAULT_SETTINGS.duplicate(true)
## level_id (String) -> {"stars": int, "best_time": float, "best_durability": float, "perfect": bool}
var levels: Dictionary = {}
var outfit: String = "klasik"
var tutorial_seen: bool = false
var total_play_time: float = 0.0

var persist := true   # testler sırasında false: diske yazılmaz
var _save_queued := false
var _last_load_report := ""


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	load_game()
	apply_settings()


func _process(delta: float) -> void:
	total_play_time += delta
	if _save_queued:
		_save_queued = false
		save_game()


func _notification(what: int) -> void:
	# Uygulama arka plana atılır veya kapanırken kaybolma olmasın.
	if what == NOTIFICATION_APPLICATION_PAUSED or what == NOTIFICATION_WM_CLOSE_REQUEST or what == NOTIFICATION_APPLICATION_FOCUS_OUT:
		save_game()


# ---------------------------------------------------------------- İlerleme

func get_level_record(level_id: int) -> Dictionary:
	var rec = levels.get(str(level_id), null)
	if rec is Dictionary:
		return rec
	return {}


func get_stars(level_id: int) -> int:
	return int(get_level_record(level_id).get("stars", 0))


func total_stars() -> int:
	var t := 0
	for key in levels:
		var rec = levels[key]
		if rec is Dictionary:
			t += clampi(int(rec.get("stars", 0)), 0, 3)
	return t


func is_level_unlocked(level_id: int) -> bool:
	if level_id <= 1:
		return true
	# Bir önceki bölüm tamamlandıysa açıktır.
	return get_level_record(level_id - 1).get("stars", 0) > 0


func highest_unlocked(level_count: int) -> int:
	var h := 1
	for i in range(1, level_count + 1):
		if is_level_unlocked(i):
			h = i
	return h


## Bölüm sonucu kaydeder. Daha iyi sonuç eskisinin üzerine yazılır. Yeni rekor varsa true döner.
func record_result(level_id: int, stars: int, time_sec: float, durability: float, perfect: bool) -> bool:
	stars = clampi(stars, 0, 3)
	time_sec = maxf(0.0, time_sec)
	durability = clampf(durability, 0.0, 100.0)
	var key := str(level_id)
	var old := get_level_record(level_id)
	var improved := false
	var rec := {
		"stars": int(old.get("stars", 0)),
		"best_time": float(old.get("best_time", 0.0)),
		"best_durability": float(old.get("best_durability", 0.0)),
		"perfect": bool(old.get("perfect", false)),
	}
	if stars > rec.stars:
		rec.stars = stars
		improved = true
	if rec.best_time <= 0.0 or time_sec < rec.best_time:
		rec.best_time = time_sec
		improved = true
	if durability > rec.best_durability:
		rec.best_durability = durability
	if perfect and not rec.perfect:
		rec.perfect = true
		improved = true
	levels[key] = rec
	save_game()
	progress_changed.emit()
	return improved


func perfect_count() -> int:
	var c := 0
	for key in levels:
		var rec = levels[key]
		if rec is Dictionary and bool(rec.get("perfect", false)):
			c += 1
	return c


# ---------------------------------------------------------------- Kıyafet

func get_outfit_data(outfit_id: String = "") -> Dictionary:
	if outfit_id == "":
		outfit_id = outfit
	for o in OUTFITS:
		if o.id == outfit_id:
			return o
	return OUTFITS[0]


func is_outfit_unlocked(outfit_id: String) -> bool:
	return total_stars() >= int(get_outfit_data(outfit_id).stars)


func set_outfit(outfit_id: String) -> bool:
	if not is_outfit_unlocked(outfit_id):
		return false
	outfit = get_outfit_data(outfit_id).id
	queue_save()
	progress_changed.emit()
	return true


# ---------------------------------------------------------------- Ayarlar

func set_setting(key: String, value) -> void:
	if not DEFAULT_SETTINGS.has(key):
		push_warning("Bilinmeyen ayar: %s" % key)
		return
	settings[key] = _sanitize_setting(key, value)
	apply_settings()
	queue_save()
	settings_changed.emit()


func get_setting(key: String):
	return settings.get(key, DEFAULT_SETTINGS.get(key))


func apply_settings() -> void:
	# Autoload sırası nedeniyle AudioManager henüz hazır olmayabilir; o kendi _ready'sinde ayarları okur.
	var am := get_node_or_null("/root/AudioManager")
	if am != null and am.has_method("set_volumes"):
		am.call("set_volumes", float(settings.sfx_volume), float(settings.music_volume))


func _sanitize_setting(key: String, value):
	var def = DEFAULT_SETTINGS[key]
	match typeof(def):
		TYPE_BOOL:
			return bool(value) if (value is bool or value is int or value is float) else def
		TYPE_INT:
			if value is int or value is float:
				return clampi(int(value), 0, 2)
			return def
		TYPE_FLOAT:
			if value is int or value is float:
				var f := float(value)
				if is_nan(f) or is_inf(f):
					return def
				if key.ends_with("volume"):
					return clampf(f, 0.0, 1.0)
				return clampf(f, 0.25, 3.0)
			return def
	return def


# ---------------------------------------------------------------- Kayıt / yükleme

func queue_save() -> void:
	_save_queued = true


func to_dict() -> Dictionary:
	return {
		"version": Config.SAVE_VERSION,
		"settings": settings.duplicate(true),
		"levels": levels.duplicate(true),
		"outfit": outfit,
		"tutorial_seen": tutorial_seen,
		"total_play_time": total_play_time,
	}


func save_game() -> bool:
	if not persist:
		return true
	var text := JSON.stringify(to_dict(), "\t")
	# 1) geçici dosyaya yaz
	var f := FileAccess.open(Config.SAVE_TMP_PATH, FileAccess.WRITE)
	if f == null:
		push_warning("Kayıt yazılamadı: %s" % error_string(FileAccess.get_open_error()))
		return false
	f.store_string(text)
	f.flush()
	f.close()
	# 2) yazılanı doğrula
	var check := _read_json(Config.SAVE_TMP_PATH)
	if check.is_empty():
		push_warning("Kayıt doğrulanamadı, eski kayıt korunuyor.")
		return false
	# 3) eski sağlam kaydı yedekle, geçiciyi asıl dosya yap
	var save_abs := ProjectSettings.globalize_path(Config.SAVE_PATH)
	var bak_abs := ProjectSettings.globalize_path(Config.SAVE_BACKUP_PATH)
	var tmp_abs := ProjectSettings.globalize_path(Config.SAVE_TMP_PATH)
	if FileAccess.file_exists(Config.SAVE_PATH):
		if FileAccess.file_exists(Config.SAVE_BACKUP_PATH):
			DirAccess.remove_absolute(bak_abs)
		DirAccess.rename_absolute(save_abs, bak_abs)
	var err := DirAccess.rename_absolute(tmp_abs, save_abs)
	if err != OK:
		push_warning("Kayıt taşınamadı: %s" % error_string(err))
		return false
	return true


func load_game() -> void:
	var data := _read_json(Config.SAVE_PATH)
	_last_load_report = "ana kayıt"
	if data.is_empty() or not _looks_valid(data):
		data = _read_json(Config.SAVE_BACKUP_PATH)
		_last_load_report = "yedek kayıt"
		if data.is_empty() or not _looks_valid(data):
			_last_load_report = "varsayılan"
			reset_to_defaults(false)
			return
	from_dict(data)


func get_load_report() -> String:
	return _last_load_report


func reset_to_defaults(save_now: bool = true) -> void:
	settings = DEFAULT_SETTINGS.duplicate(true)
	levels = {}
	outfit = "klasik"
	tutorial_seen = false
	total_play_time = 0.0
	if save_now:
		save_game()
	progress_changed.emit()
	settings_changed.emit()


## Sözlükten durumu yükler. Her alan ayrı ayrı doğrulanır; hatalı alan varsayılana döner.
func from_dict(data: Dictionary) -> void:
	data = _migrate(data)
	# Ayarlar
	settings = DEFAULT_SETTINGS.duplicate(true)
	var s = data.get("settings", {})
	if s is Dictionary:
		for key in DEFAULT_SETTINGS:
			if s.has(key):
				settings[key] = _sanitize_setting(key, s[key])
	# Bölümler
	levels = {}
	var lv = data.get("levels", {})
	if lv is Dictionary:
		for key in lv:
			var rec = lv[key]
			if not (rec is Dictionary):
				continue
			if not str(key).is_valid_int():
				continue
			var id := int(str(key))
			if id < 1 or id > 999:
				continue
			var t := float(rec.get("best_time", 0.0)) if (rec.get("best_time", 0.0) is float or rec.get("best_time", 0.0) is int) else 0.0
			var d := float(rec.get("best_durability", 0.0)) if (rec.get("best_durability", 0.0) is float or rec.get("best_durability", 0.0) is int) else 0.0
			var st = rec.get("stars", 0)
			levels[str(id)] = {
				"stars": clampi(int(st) if (st is int or st is float) else 0, 0, 3),
				"best_time": 0.0 if (is_nan(t) or is_inf(t)) else maxf(0.0, t),
				"best_durability": 0.0 if (is_nan(d) or is_inf(d)) else clampf(d, 0.0, 100.0),
				"perfect": bool(rec.get("perfect", false)) if rec.get("perfect", false) is bool else false,
			}
	# Diğer
	var o = data.get("outfit", "klasik")
	outfit = o if (o is String and o != "") else "klasik"
	if get_outfit_data(outfit).id != outfit or not is_outfit_unlocked(outfit):
		outfit = "klasik"
	var ts = data.get("tutorial_seen", false)
	tutorial_seen = ts if ts is bool else false
	var pt = data.get("total_play_time", 0.0)
	total_play_time = maxf(0.0, float(pt)) if (pt is float or pt is int) else 0.0
	progress_changed.emit()
	settings_changed.emit()


func _migrate(data: Dictionary) -> Dictionary:
	var v = data.get("version", 0)
	if not (v is int or v is float):
		v = 0
	# Gelecekteki sürümler için yer: if int(v) < 2: ...
	data["version"] = Config.SAVE_VERSION
	return data


func _looks_valid(data: Dictionary) -> bool:
	return data.has("version") and (data.get("levels", {}) is Dictionary)


func _read_json(path: String) -> Dictionary:
	if not FileAccess.file_exists(path):
		return {}
	var f := FileAccess.open(path, FileAccess.READ)
	if f == null:
		return {}
	var text := f.get_as_text()
	f.close()
	if text.strip_edges() == "" or text.length() > 2_000_000:
		return {}
	var json := JSON.new()
	if json.parse(text) != OK:
		push_warning("Kayıt dosyası bozuk (%s): %s" % [path, json.get_error_message()])
		return {}
	var result = json.data
	if result is Dictionary:
		return result
	return {}
