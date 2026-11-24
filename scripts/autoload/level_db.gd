extends Node
## Bölüm veritabanı. data/levels.json dosyasını okur, her bölümü doğrular ve
## geometrinin kurulabilir olmasını garanti eden sınırları uygular.

const LEVELS_PATH := "res://data/levels.json"
const OBSTACLE_TYPES := ["cat", "lamp", "shoe_rack", "plant", "door", "boxes"]
const GOAL_TYPES := ["door", "room", "spot"]
const ANCHORS := ["hall", "flightA", "flightB", "mid", "landing", "corridor", "corridor2", "room", "street"]

var _levels: Array = []
var errors: PackedStringArray = []


func _ready() -> void:
	reload()


func reload() -> void:
	_levels.clear()
	errors.clear()
	var raw := ItemDB._load_json(LEVELS_PATH)
	var list = raw.get("levels", [])
	if not (list is Array):
		list = []
		errors.append("levels dizisi yok")
	for entry in list:
		if entry is Dictionary:
			_levels.append(sanitize_level(entry, _levels.size() + 1))
	if _levels.is_empty():
		_levels.append(sanitize_level({"id": 1, "name": "Backup Level"}, 1))
	for e in errors:
		push_warning("LevelDB: " + e)


func count() -> int:
	return _levels.size()


func get_level(level_id: int) -> Dictionary:
	var idx := clampi(level_id - 1, 0, _levels.size() - 1)
	return _levels[idx]


func all_levels() -> Array:
	return _levels


## Bölüm kaydını doğrular. id sıraya göre yeniden atanır (boşluk olmasın).
func sanitize_level(src: Dictionary, index: int) -> Dictionary:
	var L := {}
	L.id = index
	L.name = str(src.get("name", "Level %d" % index))
	L.subtitle = str(src.get("subtitle", ""))
	var item_id := str(src.get("item", "kutu"))
	if not ItemDB.has_item(item_id):
		errors.append("bölüm %d: bilinmeyen eşya %s" % [index, item_id])
		item_id = "kutu"
	L.item = item_id
	L.floors = clampi(_int(src.get("floors"), 1), 1, 6)
	var goal := str(src.get("goal", "room"))
	if not (goal in GOAL_TYPES):
		errors.append("bölüm %d: geçersiz hedef %s" % [index, goal])
		goal = "room"
	L.goal = goal
	L.theme = clampi(_int(src.get("theme"), (index - 1) % 6), 0, 5)
	L.steps = clampi(_int(src.get("steps"), 8), 4, 12)
	L.rise = clampf(_num(src.get("rise"), 0.175), 0.12, 0.2)
	L.tread = clampf(_num(src.get("tread"), 0.29), 0.24, 0.36)
	L.stair_width = clampf(_num(src.get("stair_width"), 1.3), 0.9, 2.2)
	L.landing = clampf(_num(src.get("landing"), 1.7), 1.2, 3.0)
	L.gap = clampf(_num(src.get("gap"), 0.3), 0.2, 1.0)
	L.floor_height = L.steps * L.rise * 2.0
	# Tavan: oyuncu (1.75 m) her yerde geçebilmeli, kat yüksekliğinden de büyük olamaz.
	L.ceiling = clampf(_num(src.get("ceiling"), 2.5), 1.95, L.floor_height - 0.25)
	var full_width: float = L.stair_width * 2.0 + L.gap
	var ent := _pair(src.get("entrance"), Vector2(1.5, 2.3))
	L.entrance = Vector2(clampf(ent.x, 0.9, full_width - 0.3), clampf(ent.y, 1.95, 3.0))
	var ad := _pair(src.get("apt_door"), Vector2(1.1, 2.1))
	L.apt_door = Vector2(clampf(ad.x, 0.8, L.landing - 0.2), clampf(ad.y, 1.95, L.ceiling))
	var c = src.get("corridor", {})
	if not (c is Dictionary):
		c = {}
	var turn := str(c.get("turn", "none"))
	if turn != "left" and turn != "right":
		turn = "none"
	L.corridor = {
		"length": clampf(_num(c.get("length"), 3.0), 1.5, 8.0),
		"width": clampf(_num(c.get("width"), 1.4), maxf(1.0, L.apt_door.x + 0.1), 3.0),
		"turn": turn,
		"turn_length": clampf(_num(c.get("turn_length"), 3.0), 2.0, 8.0) if turn != "none" else 0.0,
	}
	# Koridor kapı yüksekliğinden alçak olamaz.
	L.corridor.ceiling = clampf(_num(c.get("ceiling"), L.ceiling), L.apt_door.y + 0.05, 3.0)
	var r = src.get("room", {})
	if not (r is Dictionary):
		r = {}
	var rd := _pair(r.get("door"), L.apt_door)
	L.room = {
		"width": clampf(_num(r.get("width"), 4.0), 3.0, 8.0),
		"depth": clampf(_num(r.get("depth"), 4.0), 3.0, 8.0),
		"door": Vector2(clampf(rd.x, 0.8, L.corridor.width - 0.05), clampf(rd.y, 1.95, L.corridor.ceiling)),
	}
	L.obstacles = []
	var obs = src.get("obstacles", [])
	if obs is Array:
		for o in obs:
			if not (o is Dictionary):
				continue
			var t := str(o.get("type", ""))
			var at := str(o.get("at", ""))
			if not OBSTACLE_TYPES.has(t) or not ANCHORS.has(at):
				errors.append("bölüm %d: geçersiz engel %s@%s" % [index, t, at])
				continue
			var fl := clampi(_int(o.get("floor"), 0), 0, L.floors)
			# Kat merdivenleri: floor 0..floors-1, sahanlık 1..floors
			if at in ["flightA", "flightB", "mid"]:
				fl = clampi(fl, 0, L.floors - 1)
			elif at == "landing":
				fl = clampi(fl, 1, L.floors)
			L.obstacles.append({"type": t, "at": at, "floor": fl, "side": 1 if _int(o.get("side"), 1) >= 0 else -1})
	L.par_time = clampf(_num(src.get("par_time"), 120.0), 20.0, 3600.0)
	L.tutorial = bool(src.get("tutorial", false)) if src.get("tutorial", false) is bool else false
	var tips: Array = []
	var tp = src.get("tips", [])
	if tp is Array:
		for t in tp:
			if t is String and t.strip_edges() != "":
				tips.append(t)
	L.tips = tips
	return L


static func _num(v, def: float) -> float:
	if v is float or v is int:
		var f := float(v)
		if not is_nan(f) and not is_inf(f):
			return f
	return def


static func _int(v, def: int) -> int:
	if v is int or v is float:
		return int(v)
	return def


static func _pair(v, def: Vector2) -> Vector2:
	if v is Array and v.size() == 2 and (v[0] is float or v[0] is int) and (v[1] is float or v[1] is int):
		return Vector2(float(v[0]), float(v[1]))
	return def
