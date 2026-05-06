extends Node

# MusicDirector — autoload that picks a procedural ambient music tone for
# the current scene's region_id. Until a sound designer ships .ogg tracks,
# we generate a slow looping pad with a region-specific chord using
# AudioStreamGenerator. Crossfades on scene change.
#
# Hook: _ready scans the current scene for `metadata/region_id`. If found,
# starts the corresponding pad. Re-runs on tree_changed.
#
# Fall back to silence if the AudioBus autoload isn't ready.

const SAMPLE_RATE: float = 22050.0
const PAD_DURATION: float = 8.0   # loop length in seconds
const PAD_VOLUME_DB: float = -22.0

# Per-region chord (root + third + fifth, in Hz). Tuned to mood.
const REGION_CHORDS := {
	&"sword_vow_ruins":    [110.0, 138.6, 164.8, 220.0],   # A minor (mournful)
	&"the_cradle":         [110.0, 138.6, 164.8, 207.7],   # A minor 7
	&"the_reed_wastes":    [98.0, 116.5, 146.8, 196.0],     # G minor
	&"lapis_bay":          [123.5, 155.6, 185.0, 247.0],    # B minor
	&"bone_mountains":     [82.4, 103.8, 123.5, 164.8],     # E minor (heavy)
	&"verdant_wound":      [110.0, 130.8, 174.6, 220.0],    # corrupted A
	&"ember_steppes":      [98.0, 116.5, 146.8, 174.6],     # ash steppe
	&"mist_vale":          [130.8, 164.8, 196.0, 261.6],    # C major (open)
	&"shrieking_highlands":[87.3, 110.0, 130.8, 174.6],     # F minor
	&"sundered_coast":     [98.0, 123.5, 146.8, 196.0],     # G minor
	&"black_citadel":      [82.4, 98.0, 123.5, 164.8],      # E minor (dark)
	&"fire_stair":         [73.4, 92.5, 110.0, 146.8],      # D minor (basalt)
	&"ashurim":            [146.8, 185.0, 220.0, 293.7],    # D major (bright)
	&"babilim":            [196.0, 246.9, 293.7, 392.0],    # G major (holy)
}

var _player: AudioStreamPlayer
var _current_region: StringName = &""

func _ready() -> void:
	_player = AudioStreamPlayer.new()
	_player.bus = "Music"
	_player.volume_db = PAD_VOLUME_DB
	add_child(_player)
	# Re-evaluate on tree change (scene transitions)
	get_tree().tree_changed.connect(_on_tree_changed)
	call_deferred("_refresh")

func _on_tree_changed() -> void:
	# Debounce — only check once per frame
	call_deferred("_refresh")

func _refresh() -> void:
	var region: StringName = _detect_current_region()
	if region == _current_region:
		return
	_current_region = region
	if region == &"" or not REGION_CHORDS.has(region):
		_player.stop()
		return
	_play_pad(region)

func _detect_current_region() -> StringName:
	var scene := get_tree().current_scene if get_tree() else null
	if scene == null:
		return &""
	# Region scenes carry metadata/region_id; intro scenes don't, so we
	# fall back to a name heuristic.
	if scene.has_meta("region_id"):
		return StringName(scene.get_meta("region_id"))
	# Heuristic: scene name to region id (sword_vow_ruins -> &"sword_vow_ruins")
	var name: String = scene.name.to_lower()
	for k in REGION_CHORDS.keys():
		if name == String(k) or name.replace("-", "_") == String(k):
			return k
	return &""

func _play_pad(region: StringName) -> void:
	var stream := AudioStreamGenerator.new()
	stream.mix_rate = SAMPLE_RATE
	stream.buffer_length = PAD_DURATION
	_player.stream = stream
	_player.play()
	var pb: AudioStreamGeneratorPlayback = _player.get_stream_playback()
	if pb == null:
		return
	var freqs: Array = REGION_CHORDS.get(region, [110.0, 138.6, 164.8, 220.0])
	_fill_pad(pb, freqs)

# Generate a sustained pad: sum of sine waves at the chord frequencies,
# with slow tremolo so it feels alive. ~60s of audio buffer; the loop
# wraps naturally because PAD_DURATION matches the period.
func _fill_pad(pb: AudioStreamGeneratorPlayback, freqs: Array) -> void:
	var total_samples: int = int(PAD_DURATION * SAMPLE_RATE)
	var phases: Array[float] = []
	for f in freqs:
		phases.append(0.0)
	for i in range(total_samples):
		var t: float = float(i) / SAMPLE_RATE
		# Slow amplitude modulation (0.3 Hz tremolo)
		var amp_env: float = 0.5 + 0.5 * sin(t * TAU * 0.3)
		# Slow attack/release across the loop so it breathes
		var loop_env: float = 0.5 - 0.5 * cos(float(i) / float(total_samples) * TAU)
		var sample: float = 0.0
		for j in range(freqs.size()):
			var freq: float = float(freqs[j])
			phases[j] += freq / SAMPLE_RATE
			# Light frequency-dependent volume so the chord isn't muddy
			var voice_amp: float = 1.0 / float(freqs.size()) * (1.0 - 0.15 * float(j))
			sample += sin(phases[j] * TAU) * voice_amp
		sample *= amp_env * loop_env * 0.40
		pb.push_frame(Vector2(sample, sample))
