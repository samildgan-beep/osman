extends Node
## Eşya veritabanı. data/items.json dosyasını okur ve her alanı doğrular.
## Hatalı alanlar güvenli varsayılanlarla değiştirilir; oyun asla bozuk veriyle çökmez.

const ITEMS_PATH := "res://data/items.json"
const FACES := ["front", "back", "left", "right", "top", "bottom"]

var _items: Dictionary = {}
var errors: PackedStringArray = []


func _ready() -> void:
	reload()


func reload() -> void:
	_items.clear()
	errors.clear()
	var raw := _load_json(ITEMS_PATH)
	var list = raw.get("items", [])
	if not (list is Array):
		errors.append("items dizisi bulunamadı")
		list = []
	for entry in list:
		if not (entry is Dictionary):
			errors.append("eşya kaydı sözlük değil")
			continue
		var item := sanitize_item(entry)
		if item.is_empty():
			continue
		if _items.has(item.id):
			errors.append("aynı id iki kez: %s" % item.id)
			continue
		_items[item.id] = item
	if _items.is_empty():
		# Veri tamamen bozuksa bile oyun oynanabilir kalsın.
		var fallback := sanitize_item({"id": "kutu", "name": "Box", "size": [0.55, 0.42, 0.42], "weight": 7})
		_items[fallback.id] = fallback
	for e in errors:
		push_warning("ItemDB: " + e)


func has_item(id: String) -> bool:
	return _items.has(id)


func get_item(id: String) -> Dictionary:
	if _items.has(id):
		return _items[id]
	push_warning("ItemDB: bilinmeyen eşya '%s', koli kullanılıyor" % id)
	if _items.has("kutu"):
		return _items["kutu"]
	return _items.values()[0]


func all_ids() -> Array:
	return _items.keys()


## Ham sözlüğü doğrulanmış eşya kaydına çevirir. Kurtarılamazsa boş sözlük döner.
func sanitize_item(src: Dictionary) -> Dictionary:
	var id = src.get("id", "")
	if not (id is String) or id.strip_edges() == "":
		errors.append("id eksik")
		return {}
	var size := _vec3(src.get("size"), Vector3(0.5, 0.5, 0.5))
	size = Vector3(clampf(size.x, 0.05, 4.0), clampf(size.y, 0.05, 4.0), clampf(size.z, 0.05, 4.0))
	var faces := {}
	var ff = src.get("fragile_faces", {})
	if ff is Dictionary:
		for k in ff:
			if FACES.has(k) and (ff[k] is float or ff[k] is int):
				faces[k] = clampf(float(ff[k]), 0.1, 10.0)
			else:
				errors.append("%s: geçersiz hassas yüz %s" % [id, str(k)])
	var parts: Array = []
	var pp = src.get("parts", [])
	if pp is Array:
		for p in pp:
			if not (p is Dictionary):
				continue
			var psize := _vec3(p.get("size"), Vector3.ZERO)
			if psize.x <= 0.0 or psize.y <= 0.0 or psize.z <= 0.0:
				continue
			var shape := str(p.get("shape", "box"))
			if not (shape in ["box", "cyl_z", "sphere"]):
				shape = "box"
			parts.append({
				"shape": shape,
				"pos": _vec3(p.get("pos"), Vector3.ZERO),
				"size": psize,
				"color": _color(p.get("color"), Color(0.6, 0.5, 0.4)),
			})
	if parts.is_empty():
		parts.append({"shape": "box", "pos": Vector3.ZERO, "size": size, "color": Color(0.7, 0.55, 0.4)})
	var carry = src.get("carry", "hands")
	if carry != "hands" and carry != "back":
		carry = "hands"
	var weight = src.get("weight", 10)
	var fragility = src.get("fragility", 1.0)
	return {
		"id": id,
		"name": str(src.get("name", id)),
		"description": str(src.get("description", "")),
		"size": size,
		"weight": clampf(float(weight) if (weight is float or weight is int) else 10.0, 0.5, 200.0),
		"fragility": clampf(float(fragility) if (fragility is float or fragility is int) else 1.0, 0.05, 10.0),
		"fragile_faces": faces,
		"carry": carry,
		"parts": parts,
	}


static func _vec3(v, def: Vector3) -> Vector3:
	if v is Array and v.size() == 3:
		var ok := true
		for c in v:
			if not (c is float or c is int):
				ok = false
		if ok:
			var r := Vector3(float(v[0]), float(v[1]), float(v[2]))
			if r.is_finite():
				return r
	return def


static func _color(v, def: Color) -> Color:
	if v is String and Color.html_is_valid(v):
		return Color.html(v)
	return def


static func _load_json(path: String) -> Dictionary:
	if not FileAccess.file_exists(path):
		push_warning("Veri dosyası yok: " + path)
		return {}
	var f := FileAccess.open(path, FileAccess.READ)
	if f == null:
		return {}
	var json := JSON.new()
	var err := json.parse(f.get_as_text())
	f.close()
	if err != OK:
		push_warning("%s satır %d: %s" % [path, json.get_error_line(), json.get_error_message()])
		return {}
	return json.data if json.data is Dictionary else {}
