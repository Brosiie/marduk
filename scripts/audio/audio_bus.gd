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
