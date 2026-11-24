extends Node
## Ses yöneticisi. Tüm efektler ve arka plan müziği kodla sentezlenir;
## dışarıdan ses dosyası gerekmez. SFX ve Müzik ayrı ses kanallarında (bus) çalar.

const MIX_RATE := 22050
const POOL_SIZE := 10

var _streams: Dictionary = {}
var _pool: Array[AudioStreamPlayer] = []
var _pool_idx := 0
var _music: AudioStreamPlayer
var _last_play: Dictionary = {}
var _rng := RandomNumberGenerator.new()


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_rng.seed = 12345
	_ensure_bus("SFX")
	_ensure_bus("Music")
	for i in POOL_SIZE:
		var p := AudioStreamPlayer.new()
		p.bus = "SFX"
		add_child(p)
		_pool.append(p)
	_music = AudioStreamPlayer.new()
	_music.bus = "Music"
	add_child(_music)
	_build_sounds()
	var gs := get_node_or_null("/root/GameState")
	if gs != null:
		var st = gs.get("settings")
		if st is Dictionary:
			set_volumes(float(st.get("sfx_volume", 0.9)), float(st.get("music_volume", 0.5)))


func _ensure_bus(bus_name: String) -> void:
	if AudioServer.get_bus_index(bus_name) != -1:
		return
	AudioServer.add_bus()
	var idx := AudioServer.bus_count - 1
	AudioServer.set_bus_name(idx, bus_name)
	AudioServer.set_bus_send(idx, "Master")


func set_volumes(sfx: float, music: float) -> void:
	_set_bus_linear("SFX", sfx)
	_set_bus_linear("Music", music)


func _set_bus_linear(bus_name: String, v: float) -> void:
	var idx := AudioServer.get_bus_index(bus_name)
	if idx == -1:
		return
	v = clampf(v, 0.0, 1.0)
	AudioServer.set_bus_mute(idx, v <= 0.001)
	AudioServer.set_bus_volume_db(idx, linear_to_db(maxf(v, 0.001)))


## Efekt çalar. min_interval: aynı ses bu süreden sık çalmaz (ses kirliliğini önler).
func play(sound: String, volume_db: float = 0.0, pitch: float = 1.0, min_interval: float = 0.05) -> void:
	if not _streams.has(sound):
		return
	var now := Time.get_ticks_msec() / 1000.0
	if now - float(_last_play.get(sound, -10.0)) < min_interval:
		return
	_last_play[sound] = now
	var p := _pool[_pool_idx]
	_pool_idx = (_pool_idx + 1) % _pool.size()
	p.stream = _streams[sound]
	p.volume_db = volume_db
	p.pitch_scale = clampf(pitch * _rng.randf_range(0.95, 1.05), 0.3, 3.0)
	p.play()


func play_music() -> void:
	_music_wanted = true
	if _music.playing or not _music_ready:
		return
	_music.stream = _streams.get("music")
	_music.volume_db = -6.0
	_music.play()


func stop_music() -> void:
	_music_wanted = false
	_music.stop()


# ---------------------------------------------------------------- Sentez

func _build_sounds() -> void:
	_streams["thud"] = _make(0.35, _thud)
	_streams["bump"] = _make(0.18, _bump)
	_streams["scrape"] = _make(0.25, _scrape)
	_streams["crack"] = _make(0.45, _crack)
	_streams["warn"] = _make(0.12, func(t): return _sine(t, 880.0) * _env(t, 0.005, 0.1) * 0.35)
	_streams["click"] = _make(0.05, func(t): return _sine(t, 1400.0) * _env(t, 0.001, 0.045) * 0.4)
	_streams["pickup"] = _make(0.22, func(t): return _sine(t, 300.0 + t * 900.0) * _env(t, 0.01, 0.2) * 0.45)
	_streams["putdown"] = _make(0.25, func(t): return _sine(t, 500.0 - t * 800.0) * _env(t, 0.01, 0.22) * 0.45)
	_streams["step"] = _make(0.07, func(t): return _noise() * _env(t, 0.002, 0.06) * 0.18)
	_streams["meow"] = _make(0.6, _meow)
	_streams["success"] = _make(1.2, _success)
	_streams["fail"] = _make(1.0, _fail)
	_streams["star"] = _make(0.4, func(t): return (_sine(t, 1320.0) + 0.5 * _sine(t, 1980.0)) * _env(t, 0.005, 0.38) * 0.3)
	_streams["tired"] = _make(0.5, func(t): return _noise() * _env(t, 0.1, 0.35) * 0.25 * (0.6 + 0.4 * sin(t * 40.0)))
	# Müzik uzun olduğu için açılışı geciktirmesin diye arka planda üretilir.
	_music_task = WorkerThreadPool.add_task(_build_music_threaded, false, "music_synth")


var _music_task := -1
var _music_ready := false
var _music_wanted := false


func _build_music_threaded() -> void:
	var music := _make(16.0, _music_fn)
	music.loop_mode = AudioStreamWAV.LOOP_FORWARD
	music.loop_begin = 0
	music.loop_end = int(16.0 * MIX_RATE)
	call_deferred("_on_music_built", music)


func _on_music_built(music: AudioStreamWAV) -> void:
	_streams["music"] = music
	_music_ready = true
	if _music_task != -1:
		WorkerThreadPool.wait_for_task_completion(_music_task)
		_music_task = -1
	if _music_wanted:
		play_music()


func _exit_tree() -> void:
	if _music_task != -1:
		WorkerThreadPool.wait_for_task_completion(_music_task)
		_music_task = -1


func _make(duration: float, fn: Callable) -> AudioStreamWAV:
	var n := int(duration * MIX_RATE)
	var data := PackedByteArray()
	data.resize(n * 2)
	for i in n:
		var t := float(i) / MIX_RATE
		var s := clampf(float(fn.call(t)), -1.0, 1.0)
		data.encode_s16(i * 2, int(s * 32767.0))
	var w := AudioStreamWAV.new()
	w.format = AudioStreamWAV.FORMAT_16_BITS
	w.mix_rate = MIX_RATE
	w.stereo = false
	w.data = data
	return w


func _sine(t: float, f: float) -> float:
	return sin(TAU * f * t)


func _noise() -> float:
	return _rng.randf_range(-1.0, 1.0)


func _env(t: float, attack: float, decay: float) -> float:
	if t < attack:
		return t / attack
	return exp(-(t - attack) / maxf(decay, 0.001) * 3.0)


func _thud(t: float) -> float:
	var f := 90.0 * exp(-t * 6.0) + 45.0
	return (_sine(t, f) * 0.9 + _noise() * 0.25 * exp(-t * 30.0)) * _env(t, 0.003, 0.25)


func _bump(t: float) -> float:
	return (_sine(t, 180.0 - t * 300.0) * 0.6 + _noise() * 0.3 * exp(-t * 40.0)) * _env(t, 0.002, 0.12)


var _scrape_lp := 0.0
func _scrape(t: float) -> float:
	_scrape_lp = lerpf(_scrape_lp, _noise(), 0.25)
	return _scrape_lp * _env(t, 0.02, 0.2) * 0.8 * (0.7 + 0.3 * sin(t * 90.0))


func _crack(t: float) -> float:
	var crackle := _noise() * (1.0 if _rng.randf() < 0.3 else 0.2)
	return (crackle * 0.6 + _sine(t, 120.0) * 0.4) * _env(t, 0.002, 0.3)


func _meow(t: float) -> float:
	var f := 650.0 + 250.0 * sin(t * PI / 0.6) - t * 200.0
	var vib := 1.0 + 0.03 * sin(t * 40.0)
	var tone := _sine(t, f * vib) + 0.4 * _sine(t, f * 2.0 * vib) + 0.15 * _sine(t, f * 3.0)
	var env := sin(clampf(t / 0.6, 0.0, 1.0) * PI)
	return tone * env * 0.25


func _success(t: float) -> float:
	var notes := [523.25, 659.25, 783.99, 1046.5]
	var idx := mini(int(t / 0.15), notes.size() - 1)
	var lt := t - idx * 0.15
	var s := _sine(t, notes[idx]) * _env(lt, 0.005, 0.5)
	return s * 0.35


func _fail(t: float) -> float:
	var notes := [392.0, 349.23, 311.13, 261.63]
	var idx := mini(int(t / 0.2), notes.size() - 1)
	var lt := t - idx * 0.2
	return (_sine(t, notes[idx]) + 0.3 * _sine(t, notes[idx] * 0.5)) * _env(lt, 0.01, 0.4) * 0.3


## Sakin, döngüsel arka plan müziği: 4 akorluk yumuşak bir dizi + hafif bas.
func _music_fn(t: float) -> float:
	var chords := [
		[261.63, 329.63, 392.0],   # C
		[220.0, 261.63, 329.63],   # Am
		[174.61, 220.0, 261.63],   # F
		[196.0, 246.94, 293.66],   # G
	]
	var bar := 4.0
	var idx := int(t / bar) % 4
	var lt := fmod(t, bar)
	var chord: Array = chords[idx]
	var pad := 0.0
	for f in chord:
		pad += sin(TAU * f * t) * 0.5 + sin(TAU * f * 2.0 * t) * 0.08
	var swell := 0.55 + 0.45 * sin(lt / bar * PI)
	var bass := sin(TAU * chord[0] * 0.5 * t) * 0.6 * _env(fmod(lt, 1.0), 0.01, 0.6)
	# Akor geçişlerinde tıklama olmasın diye kenar yumuşatma.
	var edge := clampf(minf(lt, bar - lt) / 0.08, 0.0, 1.0)
	# Arpej
	var step := int(lt / 0.5) % 3
	var arp := sin(TAU * chord[step] * 2.0 * t) * _env(fmod(lt, 0.5), 0.005, 0.25) * 0.25
	return (pad * 0.12 * swell + bass * 0.18 + arp * 0.5) * edge
