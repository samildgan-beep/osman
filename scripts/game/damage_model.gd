class_name DamageModel
extends RefCounted
## Hasar, puanlama ve dayanıklılık formülleri. Saf fonksiyonlar: sahneye bağlı değildir,
## tests/run_tests.gd ile doğrudan test edilir.

const FACE_NAMES := {
	"front": "front", "back": "back", "left": "left side",
	"right": "right side", "top": "top", "bottom": "bottom",
}


## Çarpma hızına göre hasar. speed: yüzeye dik hız (m/s).
static func impact_damage(speed: float, fragility: float, face_mult: float = 1.0) -> float:
	if is_nan(speed) or speed <= Config.IMPACT_THRESHOLD:
		return 0.0
	var dmg := (speed - Config.IMPACT_THRESHOLD) * Config.IMPACT_DAMAGE_PER_MS * fragility * face_mult
	return clampf(dmg, 0.0, Config.IMPACT_MAX_DAMAGE)


## Sürekli sürtünme hasarı (saniye başına oran * delta).
static func scrape_damage(delta: float, fragility: float, face_mult: float = 1.0) -> float:
	return maxf(0.0, Config.SCRAPE_DAMAGE_PER_SEC * delta * fragility * face_mult)


## Eşyanın yerel uzayındaki bir noktanın hangi yüzüne ait olduğunu bulur.
## Godot'da ileri -Z olduğu için -Z yüzü "front" kabul edilir.
static func face_from_local(local: Vector3, half: Vector3) -> String:
	var hx := maxf(half.x, 0.001)
	var hy := maxf(half.y, 0.001)
	var hz := maxf(half.z, 0.001)
	var rx := absf(local.x) / hx
	var ry := absf(local.y) / hy
	var rz := absf(local.z) / hz
	if rx >= ry and rx >= rz:
		return "right" if local.x > 0.0 else "left"
	if ry >= rz:
		return "top" if local.y > 0.0 else "bottom"
	return "back" if local.z > 0.0 else "front"


static func face_multiplier(item: Dictionary, face: String) -> float:
	var faces = item.get("fragile_faces", {})
	if faces is Dictionary and faces.has(face):
		return float(faces[face])
	return 1.0


## Bölüm sonu yıldız hesabı.
static func stars(durability: float, time_sec: float, par_time: float) -> int:
	if durability <= 0.0:
		return 0
	if durability >= Config.STAR3_DURABILITY and time_sec <= par_time:
		return 3
	if durability >= Config.STAR2_DURABILITY and time_sec <= par_time * Config.STAR2_TIME_MULT:
		return 2
	return 1


## Ağırlık, sırtta taşıma ve merdivene göre hız çarpanı.
static func carry_speed_mult(weight: float, back_carry: bool, on_stairs: bool) -> float:
	var m := clampf(1.0 - weight * Config.WEIGHT_SPEED_FACTOR, Config.MIN_CARRY_SPEED_MULT, 0.92)
	if back_carry:
		m *= Config.BACK_CARRY_SPEED_MULT
	if on_stairs:
		m *= Config.STAIR_SPEED_MULT
	return m


## Saniyedeki dayanıklılık değişimi (negatif = azalır).
## leverage: kaldıraç çarpanı (eşya gövdeden uzakta tutulunca etkin ağırlık artar).
static func stamina_rate(holding: bool, weight: float, moving: bool, on_stairs: bool, leverage: float = 1.0) -> float:
	if not holding:
		return Config.STAMINA_REGEN_FREE if moving else Config.STAMINA_REGEN_REST
	var extra := maxf(0.0, weight * maxf(1.0, leverage) - Config.STAMINA_FREE_WEIGHT)
	if extra <= 0.0:
		return Config.STAMINA_REGEN_FREE * 0.5
	var drain := extra * Config.STAMINA_DRAIN_PER_KG
	if not moving:
		drain *= Config.STAMINA_IDLE_MULT
	elif on_stairs:
		drain *= Config.STAMINA_STAIR_MULT
	return -drain


## Dönmüş kutunun, verilen eksen takımındaki yarı uzunlukları.
static func rotated_half_extents(b: Basis, half: Vector3) -> Vector3:
	return Vector3(
		absf(b.x.x) * half.x + absf(b.y.x) * half.y + absf(b.z.x) * half.z,
		absf(b.x.y) * half.x + absf(b.y.y) * half.y + absf(b.z.y) * half.z,
		absf(b.x.z) * half.x + absf(b.y.z) * half.y + absf(b.z.z) * half.z)


static func format_time(sec: float) -> String:
	sec = maxf(0.0, sec)
	var m := int(sec) / 60
	var s := int(sec) % 60
	var d := int((sec - floorf(sec)) * 10.0)
	return "%d:%02d.%d" % [m, s, d]
