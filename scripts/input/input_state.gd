class_name InputState
extends RefCounted
## Dokunmatik kontroller ve klavyenin yazdığı, oyuncu/kameranın okuduğu ortak girdi durumu.
## Birikimli değerler (döndürme, kamera) okununca sıfırlanır.

var move := Vector2.ZERO            # x: sağ, y: ileri (-1..1)
var rotate_px := Vector2.ZERO       # sağ alan tek parmak kaydırması (piksel)
var key_rotate := Vector3.ZERO      # klavye: (yaw, pitch, roll) -1..1
var roll_mode := false              # açıkken yatay kaydırma kendi etrafında yatırır
var lift := 0.0                     # -1 indir, +1 kaldır
var precise := false
var cam_orbit_px := Vector2.ZERO
var cam_zoom := 0.0                 # + yakınlaş, - uzaklaş
var look_mode := false              # serbest bakış: karakter durur, kamera gezer
var cam_rise := 0.0                 # serbest bakışta yukarı/aşağı (birikimli)
var _pressed: Dictionary = {}       # tek seferlik düğmeler


func press(action: String) -> void:
	_pressed[action] = true


## Düğmeye basıldıysa true döner ve bayrağı temizler.
func consume(action: String) -> bool:
	if _pressed.get(action, false):
		_pressed.erase(action)
		return true
	return false


func take_rotate_px() -> Vector2:
	var v := rotate_px
	rotate_px = Vector2.ZERO
	return v


func take_cam_orbit() -> Vector2:
	var v := cam_orbit_px
	cam_orbit_px = Vector2.ZERO
	return v


func take_cam_rise() -> float:
	var v := cam_rise
	cam_rise = 0.0
	return v


func take_cam_zoom() -> float:
	var v := cam_zoom
	cam_zoom = 0.0
	return v


func clear() -> void:
	move = Vector2.ZERO
	rotate_px = Vector2.ZERO
	key_rotate = Vector3.ZERO
	lift = 0.0
	precise = false
	cam_orbit_px = Vector2.ZERO
	cam_zoom = 0.0
	cam_rise = 0.0
	_pressed.clear()
