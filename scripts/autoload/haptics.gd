extends Node
## Telefon titreşimi. Ayarlardan kapatılabilir; çok sık titreşimi engeller.

var _last_ms := 0


func vibrate(duration_ms: int, min_gap_ms: int = 60) -> void:
	if not bool(GameState.get_setting("vibration")):
		return
	if not (OS.has_feature("android") or OS.has_feature("ios")):
		return
	var now := Time.get_ticks_msec()
	if now - _last_ms < min_gap_ms:
		return
	_last_ms = now
	Input.vibrate_handheld(clampi(duration_ms, 5, 500))


func light() -> void:
	vibrate(Config.HAPTIC_LIGHT_MS)


func heavy() -> void:
	vibrate(Config.HAPTIC_HEAVY_MS, 20)
