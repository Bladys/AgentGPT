extends Node
## Routage : Master <- Music, Ambience, SFX, UI. Le volume utilisateur est
## appliqué au bus ; musique et effets ont des réglages séparés.
## Tant que les WAV/OGG du pack ne sont pas intégrés, les effets utilisent de
## courtes tonalités synthétisées (maquettes) et la musique reste silencieuse.

const BUSES := ["Music", "Ambience", "SFX", "UI"]
const TRACE_MILESTONE := 4      # un son tous les N segments
const TRACE_MAX_PER_GESTURE := 4
const SFX_VOICES := 6

var _music: AudioStreamPlayer
var _ambience: AudioStreamPlayer
var _sfx: Array[AudioStreamPlayer] = []
var _ui: AudioStreamPlayer
var _next_voice := 0
var _cache: Dictionary = {}
var _suspended: Dictionary = {}
var _trace_count := 0
var current_music := ""
var played_log: Array = []   # tests / diagnostic


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	for b in BUSES:
		if AudioServer.get_bus_index(b) == -1:
			AudioServer.add_bus()
			var i := AudioServer.bus_count - 1
			AudioServer.set_bus_name(i, b)
			AudioServer.set_bus_send(i, "Master")
	_music = _player("Music")
	_ambience = _player("Ambience")
	_ui = _player("UI")
	for i in SFX_VOICES:
		_sfx.append(_player("SFX"))
	apply_settings()
	Settings.changed.connect(func(_k): apply_settings())
	Ads.audio_takeover.connect(func(active): suspend("ad") if active else resume("ad"))


func _player(bus: String) -> AudioStreamPlayer:
	var p := AudioStreamPlayer.new()
	p.bus = bus
	add_child(p)
	return p


func apply_settings() -> void:
	var mv: float = Settings.get_value("music_volume")
	var sv: float = Settings.get_value("sfx_volume")
	for b in ["Music", "Ambience"]:
		var i := AudioServer.get_bus_index(b)
		AudioServer.set_bus_volume_db(i, linear_to_db(maxf(mv * (0.7 if b == "Ambience" else 1.0), 0.0001)))
		AudioServer.set_bus_mute(i, not Settings.get_value("music_on"))
	for b in ["SFX", "UI"]:
		var i := AudioServer.get_bus_index(b)
		AudioServer.set_bus_volume_db(i, linear_to_db(maxf(sv, 0.0001)))
		AudioServer.set_bus_mute(i, not Settings.get_value("sfx_on"))


# ---------------------------------------------------------------- lecture

func play_music(id: String) -> void:
	if id == current_music:
		return
	current_music = id
	_music.stop()
	var s := AssetRegistry.load_or_null(id)
	if s is AudioStream:
		_music.stream = s
		_music.play()


func play_ambience(id: String) -> void:
	_ambience.stop()
	var s := AssetRegistry.load_or_null(id)
	if s is AudioStream:
		_ambience.stream = s
		_ambience.play()


func play_sfx(id: String) -> void:
	played_log.append(id)
	if played_log.size() > 64:
		played_log.pop_front()
	var p := _sfx[_next_voice]
	_next_voice = (_next_voice + 1) % SFX_VOICES
	p.stream = _stream(id)
	p.play()


func play_ui(id: String) -> void:
	_ui.stream = _stream(id)
	_ui.play()


func trace_begin() -> void:
	_trace_count = 0
	play_sfx("sfx_channel_start")


func trace_segment(length: int) -> void:
	## Sons de tracé limités à quelques jalons par geste.
	if length % TRACE_MILESTONE == 0 and _trace_count < TRACE_MAX_PER_GESTURE:
		_trace_count += 1
		play_sfx("sfx_trace_step")


# ---------------------------------------------------------------- suspension

func suspend(reason: String) -> void:
	_suspended[reason] = true
	AudioServer.set_bus_mute(0, true)
	_music.stream_paused = true
	_ambience.stream_paused = true


func resume(reason: String) -> void:
	_suspended.erase(reason)
	if _suspended.is_empty():
		AudioServer.set_bus_mute(0, false)
		_music.stream_paused = false
		_ambience.stream_paused = false
		apply_settings()  # restaure les préférences


func is_suspended() -> bool:
	return not _suspended.is_empty()


func _notification(what: int) -> void:
	if what == NOTIFICATION_APPLICATION_PAUSED or what == NOTIFICATION_APPLICATION_FOCUS_OUT:
		suspend("background")
	elif what == NOTIFICATION_APPLICATION_RESUMED or what == NOTIFICATION_APPLICATION_FOCUS_IN:
		resume("background")


# ---------------------------------------------------------------- maquettes

const _TONES := {
	"sfx_channel_start": [523.0, 0.09, 0.0], "sfx_trace_step": [659.0, 0.05, 0.0],
	"sfx_connect": [784.0, 0.22, 1.5], "sfx_soft_error": [196.0, 0.12, 0.0],
	"sfx_bridge": [392.0, 0.4, 1.25], "sfx_melt": [440.0, 0.4, 0.75], "sfx_freeze": [988.0, 0.4, 1.33],
	"sfx_hatch": [659.0, 0.5, 1.5], "sfx_restore": [523.0, 0.6, 1.5], "sfx_seed": [880.0, 0.15, 1.25],
	"sfx_win": [523.0, 0.7, 2.0], "ui_tap": [440.0, 0.04, 0.0], "ui_back": [330.0, 0.05, 0.0], "ui_toggle": [554.0, 0.05, 0.0],
}


func _stream(id: String) -> AudioStream:
	if _cache.has(id):
		return _cache[id]
	var s: AudioStream = AssetRegistry.load_or_null(id)
	if s == null:
		s = _tone(_TONES.get(id, [440.0, 0.05, 0.0]))
	_cache[id] = s
	return s


func _tone(spec: Array) -> AudioStreamWAV:
	## Célesta de maquette : sinus + harmonique, enveloppe douce, 2e note optionnelle.
	var rate := 22050
	var n := int(rate * float(spec[1]))
	var data := PackedByteArray()
	data.resize(n * 2)
	for i in n:
		var t := float(i) / rate
		var f: float = spec[0] * (spec[2] if spec[2] > 0.0 and i > n / 2 else 1.0)
		var local := t if i <= n / 2 or spec[2] == 0.0 else t - float(n / 2) / rate
		var env := minf(local * 200.0, 1.0) * exp(-local * 9.0)
		var v := (sin(TAU * f * t) * 0.6 + sin(TAU * f * 2.0 * t) * 0.2) * env * 0.5
		data.encode_s16(i * 2, int(clampf(v, -1.0, 1.0) * 32767.0))
	var w := AudioStreamWAV.new()
	w.format = AudioStreamWAV.FORMAT_16_BITS
	w.mix_rate = rate
	w.data = data
	return w
