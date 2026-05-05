extends Node

# Music + SFX + ambient layered audio. Autoload as `AudioBus`. Crossfades music
# tracks when zones change (zone.music_track), supports a per-zone ambient layer,
# global SFX channels with priority queuing.

const FADE_TIME := 1.5
const MUSIC_VOL_DB := -8.0
const AMBIENT_VOL_DB := -16.0

var _music_a: AudioStreamPlayer
var _music_b: AudioStreamPlayer
var _ambient: AudioStreamPlayer
var _using_a: bool = true
var _current_music_path: String = ""

var _sfx_pool: Array[AudioStreamPlayer3D] = []
const SFX_POOL_SIZE := 12

func _ready() -> void:
	_music_a = _make_music_player()
	_music_b = _make_music_player()
	_ambient = AudioStreamPlayer.new()
	_ambient.bus = "Ambient"
	_ambient.volume_db = AMBIENT_VOL_DB
	add_child(_ambient)
	for i in range(SFX_POOL_SIZE):
		var p := AudioStreamPlayer3D.new()
		p.bus = "SFX"
		add_child(p)
		_sfx_pool.append(p)

func _make_music_player() -> AudioStreamPlayer:
	var p := AudioStreamPlayer.new()
	p.bus = "Music"
	p.volume_db = -80.0
	add_child(p)
	return p

func play_music(path: String, fade: float = FADE_TIME) -> void:
	if path == _current_music_path:
		return
	_current_music_path = path
	if path == "":
		# fade out current
		var cur := _music_a if _using_a else _music_b
		_fade_to(cur, -80.0, fade)
		return
	var stream := load(path) as AudioStream
	if not stream:
		push_warning("AudioBus: missing music %s" % path)
		return
	var next := _music_b if _using_a else _music_a
	var cur := _music_a if _using_a else _music_b
	next.stream = stream
	next.volume_db = -80.0
	next.play()
	_fade_to(next, MUSIC_VOL_DB, fade)
	_fade_to(cur, -80.0, fade)
	_using_a = not _using_a

func play_ambient(path: String) -> void:
	if path == "":
		_ambient.stop()
		return
	var stream := load(path) as AudioStream
	if not stream:
		return
	_ambient.stream = stream
	_ambient.play()

func play_sfx_3d(path: String, position: Vector3, volume_db: float = 0.0, pitch: float = 1.0) -> void:
	var stream := load(path) as AudioStream
	if not stream:
		return
	var p := _take_sfx_player()
	if not p:
		return
	p.stream = stream
	p.global_position = position
	p.volume_db = volume_db
	p.pitch_scale = pitch
	p.play()

# --- Procedural SFX (no .ogg files yet) ---
# AudioStreamGenerator builds short tones at runtime so combat has SOMETHING
# audible until a sound designer ships real assets. Each named SFX is a
# different tone curve. Cached per-name.

const SFX_SAMPLE_RATE: float = 22050.0

var _sfx_cache: Dictionary = {}  # name -> AudioStreamGenerator (template)

# Public API: AudioBus.play_cue("hit", actor.global_position)
func play_cue(name: StringName, pos: Vector3, volume_db: float = -6.0, pitch: float = 1.0) -> void:
	var p := _take_sfx_player()
	if not p:
		return
	var stream := AudioStreamGenerator.new()
	stream.mix_rate = SFX_SAMPLE_RATE
	stream.buffer_length = 0.4  # max length we'll ever need
	p.stream = stream
	p.global_position = pos
	p.volume_db = volume_db
	p.pitch_scale = pitch
	p.play()
	var pb: AudioStreamGeneratorPlayback = p.get_stream_playback()
	if pb == null:
		return
	_fill_buffer(pb, name)

# Push samples into the playback buffer based on cue name. Each cue picks
# a different waveform shape and decay envelope. Soft and short so they
# don't overlap into mush.
func _fill_buffer(pb: AudioStreamGeneratorPlayback, name: StringName) -> void:
	match name:
		&"hit":           _gen_burst(pb, 220.0, 60.0, 0.10, 0.35)
		&"crit":          _gen_burst(pb, 440.0, 80.0, 0.15, 0.5)
		&"death":         _gen_burst(pb, 110.0, 40.0, 0.30, 0.6)
		&"pickup":        _gen_chirp(pb, 660.0, 1320.0, 0.10)
		&"level_up":      _gen_arp(pb, [330.0, 440.0, 660.0, 880.0], 0.08)
		&"lodestone":     _gen_chirp(pb, 220.0, 880.0, 0.30)
		&"warp":          _gen_chirp(pb, 880.0, 110.0, 0.30)
		&"swing":         _gen_burst(pb, 320.0, 90.0, 0.06, 0.25)
		&"button":        _gen_burst(pb, 880.0, 600.0, 0.04, 0.15)
		&"deny":          _gen_burst(pb, 110.0, 80.0, 0.10, 0.35)
		_:                _gen_burst(pb, 440.0, 100.0, 0.08, 0.3)

# Square-ish burst with exponential decay
func _gen_burst(pb: AudioStreamGeneratorPlayback, freq_start: float, freq_end: float, duration: float, gain: float) -> void:
	var n: int = int(duration * SFX_SAMPLE_RATE)
	var phase: float = 0.0
	for i in range(n):
		var t: float = float(i) / float(max(1, n))
		var freq: float = lerp(freq_start, freq_end, t)
		phase += freq / SFX_SAMPLE_RATE
		# square wave for more crunch than sine
		var wave: float = 1.0 if fmod(phase, 1.0) < 0.5 else -1.0
		var env: float = exp(-3.0 * t)
		var sample: float = wave * env * gain
		pb.push_frame(Vector2(sample, sample))

# Pitch-bend chirp (rising or falling)
func _gen_chirp(pb: AudioStreamGeneratorPlayback, freq_start: float, freq_end: float, duration: float) -> void:
	var n: int = int(duration * SFX_SAMPLE_RATE)
	var phase: float = 0.0
	for i in range(n):
		var t: float = float(i) / float(max(1, n))
		var freq: float = lerp(freq_start, freq_end, t)
		phase += freq / SFX_SAMPLE_RATE
		var wave: float = sin(phase * TAU)
		var env: float = sin(t * PI)  # raised-cosine envelope
		var sample: float = wave * env * 0.4
		pb.push_frame(Vector2(sample, sample))

# Arpeggio across a pitch ladder (used for level_up)
func _gen_arp(pb: AudioStreamGeneratorPlayback, freqs: Array, step_dur: float) -> void:
	for f in freqs:
		_gen_burst(pb, float(f), float(f), step_dur, 0.4)


func _take_sfx_player() -> AudioStreamPlayer3D:
	for p in _sfx_pool:
		if not p.playing:
			return p
	return null  # all busy; soft-drop the request

func _fade_to(player: AudioStreamPlayer, target_db: float, time: float) -> void:
	var t := create_tween()
	t.tween_property(player, "volume_db", target_db, time)
	if target_db <= -78.0:
		t.tween_callback(player.stop)
