extends Node
## Ses yöneticisi. Tüm efektler ve neşeli arka plan müziği kodla sentezlenir; dışarıdan
## ses dosyası gerekmez. İstenirse res://audio/<ad>.ogg|.wav|.mp3 dosyası konarak herhangi
## bir ses gerçek kayıtla değiştirilebilir (ör. audio/music.ogg, audio/shatter.wav).
## SFX ve Müzik ayrı ses kanallarında (bus) çalar.

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


## Adım sesi: varyasyonlar sırayla ve hafif perde farkıyla çalınır (tekdüze olmasın).
var _step_i := 0
func play_step(on_stairs: bool, heavy: bool) -> void:
	_step_i = (_step_i + 1 + _rng.randi() % 2) % 4
	var vol := -7.0 if heavy else -9.0
	var pitch := (0.85 if heavy else 1.0) * (1.08 if on_stairs else 1.0)
	play("step%d" % _step_i, vol, pitch, 0.08)


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

const SOUND_NAMES := ["thud", "bump", "scrape", "crack", "shatter", "warn", "click", "pickup", "putdown",
	"step0", "step1", "step2", "step3", "meow", "success", "fail", "star", "tired", "music"]

var _task := -1
var _music_ready := false
var _music_wanted := false
var _srng := RandomNumberGenerator.new()   # yalnızca sentez iş parçacığında kullanılır


func _build_sounds() -> void:
	# Önce gerçek ses dosyası var mı bak (audio/ klasörü)
	var missing: Array = []
	for nm in SOUND_NAMES:
		var st := _load_override(nm)
		if st != null:
			if nm == "music":
				_set_loop(st)
				_music_ready = true
			_streams[nm] = st
		else:
			missing.append(nm)
	if missing.is_empty():
		return
	_srng.seed = 777
	# Sentez telefonda zaman alır: açılışı geciktirmesin diye arka plan iş parçacığında yapılır.
	_task = WorkerThreadPool.add_task(_build_all_threaded.bind(missing), false, "audio_synth")


func _load_override(nm: String) -> AudioStream:
	for ext: String in ["ogg", "wav", "mp3"]:
		var path := "res://audio/%s.%s" % [nm, ext]
		if ResourceLoader.exists(path):
			var res = load(path)
			if res is AudioStream:
				return res
	return null


func _set_loop(st: AudioStream) -> void:
	if st is AudioStreamOggVorbis:
		(st as AudioStreamOggVorbis).loop = true
	elif st is AudioStreamMP3:
		(st as AudioStreamMP3).loop = true
	elif st is AudioStreamWAV:
		var w := st as AudioStreamWAV
		w.loop_mode = AudioStreamWAV.LOOP_FORWARD
		w.loop_end = int(w.get_length() * w.mix_rate)


func _build_all_threaded(missing: Array) -> void:
	var sfx := {}
	for nm in missing:
		if nm == "music":
			continue
		var buf := _synth(str(nm))
		if not buf.is_empty():
			sfx[nm] = _to_wav(buf)
	call_deferred("_on_sfx_built", sfx)
	if missing.has("music"):
		var music := _to_wav(_compose_music())
		music.loop_mode = AudioStreamWAV.LOOP_FORWARD
		music.loop_begin = 0
		music.loop_end = int(music.data.size() / 2)
		call_deferred("_on_music_built", music)


func _on_sfx_built(sfx: Dictionary) -> void:
	for k in sfx:
		_streams[k] = sfx[k]


func _on_music_built(music: AudioStreamWAV) -> void:
	_streams["music"] = music
	_music_ready = true
	if _task != -1:
		WorkerThreadPool.wait_for_task_completion(_task)
		_task = -1
	if _music_wanted:
		play_music()


func _exit_tree() -> void:
	if _task != -1:
		WorkerThreadPool.wait_for_task_completion(_task)
		_task = -1


func _to_wav(buf: PackedFloat32Array) -> AudioStreamWAV:
	var data := PackedByteArray()
	data.resize(buf.size() * 2)
	for i in buf.size():
		data.encode_s16(i * 2, int(clampf(buf[i], -1.0, 1.0) * 32767.0))
	var w := AudioStreamWAV.new()
	w.format = AudioStreamWAV.FORMAT_16_BITS
	w.mix_rate = MIX_RATE
	w.stereo = false
	w.data = data
	return w


## Sentez tamponu (paylaşılan üye değişken: paketli dizilerin kopyalanma
## davranışından bağımsız olarak yardımcı fonksiyonlar aynı tampona yazar).
var _sb := PackedFloat32Array()


func _buf(seconds: float) -> void:
	_sb = PackedFloat32Array()
	_sb.resize(int(seconds * MIX_RATE))
	_sb.fill(0.0)


func _n() -> float:
	return _srng.randf_range(-1.0, 1.0)


## Sönümlü sinüs (vurmalı/rezonans), başlangıç saniyesi ve süreyle tampona eklenir.
func _add_sine(start: float, dur: float, f0: float, f1: float, amp: float, decay: float) -> void:
	var i0 := int(start * MIX_RATE)
	var n := mini(int(dur * MIX_RATE), _sb.size() - i0)
	var ph := 0.0
	for i in n:
		var t := float(i) / MIX_RATE
		var f := lerpf(f0, f1, minf(t / maxf(dur, 0.001), 1.0))
		ph += TAU * f / MIX_RATE
		var env := exp(-t * decay) * minf(1.0, t * 2000.0)
		_sb[i0 + i] += sin(ph) * amp * env


## Filtreli gürültü patlaması (lp: 0..1 alçak geçiren katsayısı, küçük = boğuk).
func _add_noise(start: float, dur: float, amp: float, decay: float, lp: float) -> void:
	var i0 := int(start * MIX_RATE)
	var n := mini(int(dur * MIX_RATE), _sb.size() - i0)
	var y := 0.0
	for i in n:
		var t := float(i) / MIX_RATE
		y = lerpf(y, _n(), lp)
		_sb[i0 + i] += y * amp * exp(-t * decay) * minf(1.0, t * 3000.0)


## Marimba/pluck benzeri nota (temel + harmonikler).
func _add_pluck(start: float, dur: float, f: float, amp: float) -> void:
	var i0 := int(start * MIX_RATE)
	var n := mini(int(dur * MIX_RATE), _sb.size() - i0)
	for i in n:
		var t := float(i) / MIX_RATE
		var w := TAU * f * t
		var v := sin(w) + 0.35 * sin(w * 4.0) * exp(-t * 18.0) + 0.15 * sin(w * 2.0)
		_sb[i0 + i] += v * amp * exp(-t * 6.0) * minf(1.0, t * 800.0)


func _synth(nm: String) -> PackedFloat32Array:
	_sb = PackedFloat32Array()
	match nm:
		"step0", "step1", "step2", "step3":
			# Taş/mozaik zeminde ayakkabı: topuk vuruşu + taban sürtmesi
			var k := int(nm.substr(4))
			_buf(0.16)
			_add_sine(0.0, 0.08, 95.0 + k * 9.0, 55.0, 0.55, 45.0)
			_add_noise(0.0, 0.05, 0.45, 70.0, 0.55 + k * 0.08)
			_add_noise(0.045 + k * 0.006, 0.08, 0.18, 40.0, 0.25)
		"thud":
			# Ağır darbe: alçak süpürme + gövde rezonansı + boğuk gürültü
			_buf(0.6)
			_add_sine(0.0, 0.5, 120.0, 45.0, 0.9, 9.0)
			_add_sine(0.0, 0.35, 190.0, 180.0, 0.35, 14.0)
			_add_sine(0.0, 0.3, 275.0, 270.0, 0.2, 18.0)
			_add_noise(0.0, 0.25, 0.55, 22.0, 0.18)
		"bump":
			# Tahta/plastik tıkırtı: iki mod + tık
			_buf(0.25)
			_add_sine(0.0, 0.2, 420.0, 400.0, 0.45, 28.0)
			_add_sine(0.0, 0.15, 760.0, 740.0, 0.25, 40.0)
			_add_sine(0.0, 0.2, 140.0, 90.0, 0.4, 20.0)
			_add_noise(0.0, 0.03, 0.4, 120.0, 0.7)
		"scrape":
			_buf(0.35)
			var y := 0.0
			for i in _sb.size():
				var t := float(i) / MIX_RATE
				y = lerpf(y, _n(), 0.35)
				_sb[i] = y * 0.55 * sin(PI * t / 0.35) * (0.7 + 0.3 * sin(t * 120.0 + sin(t * 37.0) * 3.0))
		"crack":
			# Ahşap çatırtısı: rastgele kırılma darbeleri + gövde sesi
			_buf(0.7)
			_add_sine(0.0, 0.4, 100.0, 50.0, 0.6, 10.0)
			for j in 14:
				var st := _srng.randf_range(0.0, 0.35) * _srng.randf()
				_add_noise(st, 0.04, _srng.randf_range(0.3, 0.8), 90.0, _srng.randf_range(0.4, 0.9))
				_add_sine(st, 0.05, _srng.randf_range(900.0, 2400.0), 600.0, 0.12, 70.0)
		"shatter":
			# Cam kırılması: patlama + çok sayıda tıngırdayan cam parçası
			_buf(1.3)
			_add_noise(0.0, 0.3, 0.9, 14.0, 0.85)
			_add_sine(0.0, 0.25, 140.0, 60.0, 0.5, 14.0)
			for j in 46:
				var st := pow(_srng.randf(), 2.2) * 1.0
				var f := _srng.randf_range(2300.0, 7500.0)
				_add_sine(st, 0.18, f, f * 0.98, _srng.randf_range(0.05, 0.16), _srng.randf_range(25.0, 60.0))
			for j in 10:
				_add_noise(_srng.randf_range(0.05, 0.9), 0.05, 0.25, 60.0, 0.9)
		"warn":
			_buf(0.12)
			_add_sine(0.0, 0.12, 880.0, 880.0, 0.3, 25.0)
		"click":
			_buf(0.05)
			_add_sine(0.0, 0.05, 1500.0, 1300.0, 0.35, 70.0)
		"pickup":
			_buf(0.25)
			_add_sine(0.0, 0.22, 300.0, 600.0, 0.35, 10.0)
			_add_noise(0.0, 0.08, 0.15, 30.0, 0.3)
		"putdown":
			_buf(0.3)
			_add_sine(0.0, 0.25, 160.0, 80.0, 0.5, 14.0)
			_add_noise(0.0, 0.08, 0.3, 40.0, 0.3)
		"meow":
			_buf(0.65)
			var ph := 0.0
			for i in _sb.size():
				var t := float(i) / MIX_RATE
				var f := 600.0 + 320.0 * sin(PI * clampf(t / 0.6, 0.0, 1.0)) - t * 180.0
				ph += TAU * f * (1.0 + 0.03 * sin(t * 38.0)) / MIX_RATE
				var env := sin(PI * clampf(t / 0.62, 0.0, 1.0))
				_sb[i] = (sin(ph) + 0.45 * sin(ph * 2.0) + 0.2 * sin(ph * 3.0)) * env * 0.22
		"success":
			_buf(1.6)
			var notes := [523.25, 659.25, 783.99, 1046.5, 1318.5]
			for j in notes.size():
				_add_pluck(j * 0.11, 1.2, notes[j], 0.22)
				_add_pluck(j * 0.11, 1.2, notes[j] * 0.5, 0.1)
		"fail":
			_buf(1.4)
			var fnotes := [392.0, 369.99, 349.23, 311.13]
			for j in fnotes.size():
				_add_sine(j * 0.28, 0.6, fnotes[j], fnotes[j] * (0.97 if j == 3 else 1.0), 0.3, 3.0)
		"star":
			_buf(0.5)
			_add_pluck(0.0, 0.5, 1318.5, 0.25)
			_add_pluck(0.06, 0.45, 1975.5, 0.15)
		"tired":
			# Nefes nefese "of" sesi: iki nefes
			_buf(0.9)
			for j in 2:
				var st := j * 0.42
				var y2 := 0.0
				var i0 := int(st * MIX_RATE)
				var nn := mini(int(0.35 * MIX_RATE), _sb.size() - i0)
				for i in nn:
					var t := float(i) / MIX_RATE
					y2 = lerpf(y2, _n(), 0.12)
					_sb[i0 + i] += y2 * 0.5 * sin(PI * t / 0.35)
	return _sb


## Neşeli döngüsel müzik: 120 BPM, 8 ölçü (16 sn). Davul (bas davul, trampet, zil),
## sekizlik bas, akor vuruşları ve marimba benzeri pentatonik melodi.
func _compose_music() -> PackedFloat32Array:
	var beat := 0.5
	var bars := 8
	var total := beat * 4.0 * bars
	_buf(total + 0.6)
	# Akor dizisi: C - Am - F - G (iki kez)
	var chords := [[261.63, 329.63, 392.0], [220.0, 261.63, 329.63], [174.61, 220.0, 261.63], [196.0, 246.94, 293.66]]
	var roots := [130.81, 110.0, 87.31, 98.0]
	for bar in bars:
		var ci := bar % 4
		var t0 := bar * 4.0 * beat
		var ch: Array = chords[ci]
		for q in 4:
			var tq := t0 + q * beat
			# Bas davul 1 ve 3'te, trampet 2 ve 4'te
			if q % 2 == 0:
				_add_sine(tq, 0.2, 150.0, 48.0, 0.75, 16.0)
			else:
				_add_noise(tq, 0.16, 0.38, 22.0, 0.6)
				_add_sine(tq, 0.1, 210.0, 180.0, 0.25, 30.0)
			# Zil sekizlik
			_add_noise(tq, 0.04, 0.12, 120.0, 0.95)
			_add_noise(tq + beat * 0.5, 0.04, 0.09, 120.0, 0.95)
			# Sekizlik bas: kök - kök - oktav - kök
			var rf: float = roots[ci]
			_add_pluck(tq, 0.24, rf, 0.32)
			_add_pluck(tq + beat * 0.5, 0.22, rf * (2.0 if q == 2 else 1.0), 0.26)
			# Akor vuruşu (ara vuruşta)
			for f in ch:
				_add_pluck(tq + beat * 0.5, 0.3, float(f) * 2.0, 0.045)
	# Melodi: C majör pentatonik, sıçrayan ve neşeli
	var scale := [523.25, 587.33, 659.25, 783.99, 880.0, 1046.5]
	var melody := [
		[0, 0.0], [2, 0.5], [3, 1.0], [2, 1.5], [4, 2.0], [3, 3.0],
		[2, 4.0], [1, 4.5], [0, 5.0], [1, 5.5], [2, 6.0],
		[3, 8.0], [4, 8.5], [5, 9.0], [4, 9.5], [3, 10.0], [2, 11.0],
		[1, 12.0], [2, 12.5], [3, 13.0], [1, 14.0], [0, 14.5],
	]
	for rep in 2:
		for m in melody:
			var st := (float(m[1]) + rep * 16.0) * beat
			if st < total:
				var f: float = scale[int(m[0])]
				_add_pluck(st, 0.45, f, 0.13)
	# Döngü sınırında tıklama olmasın: kuyruğu başa ekle ve kes
	var tail := _sb.size() - int(total * MIX_RATE)
	var loop_n := int(total * MIX_RATE)
	for i in tail:
		_sb[i] += _sb[loop_n + i]
	_sb.resize(loop_n)
	# Hafif sıkıştırma / sınırlama
	var peak := 0.0
	for i in _sb.size():
		peak = maxf(peak, absf(_sb[i]))
	var g := 0.85 / maxf(peak, 0.001)
	for i in _sb.size():
		_sb[i] = tanh(_sb[i] * g * 1.2) * 0.8
	return _sb
