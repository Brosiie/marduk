extends Node

# MusicDirector, autoload that picks a procedural ambient music tone for
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

# Combat tension layer: a second pad that crossfades in during boss
# fights. Uses a tritone interval (root + tritone + minor third) for
# dissonance against the smooth region pad. Volume target driven by
# set_combat_intensity (0..1). Smoothly lerped.
var _combat_player: AudioStreamPlayer = null
var _combat_intensity: float = 0.0
var _combat_target_intensity: float = 0.0
const COMBAT_VOLUME_DB_PEAK: float = -14.0
const COMBAT_VOLUME_DB_SILENT: float = -80.0

# Conflict intensity floor: when ANY tracked faction pair is at
# SKIRMISH+, the combat-music layer never drops fully silent. War in
# the world raises the BASELINE so even non-combat moments carry the
# weight of conflict. At OPEN_WAR the floor is higher; the world is
# in active war and the music shouldn't pretend otherwise.
var _conflict_floor: float = 0.0
const CONFLICT_FLOOR_SKIRMISH: float = 0.10
const CONFLICT_FLOOR_OPEN_WAR: float = 0.25

# Tiamat awareness floor: separate from conflict because the threat
# is cosmic, not political. Her dream rising raises the music's
# floor on a DIFFERENT axis. At AWAKE the floor is high enough that
# the combat layer is always partially audible; the world is no
# longer pretending nothing is wrong.
var _tiamat_floor: float = 0.0
const TIAMAT_FLOOR_STIRRING: float = 0.05
const TIAMAT_FLOOR_WAKING:   float = 0.15
const TIAMAT_FLOOR_WAKING_2: float = 0.30
const TIAMAT_FLOOR_AWAKE:    float = 0.50

func _ready() -> void:
	_player = AudioStreamPlayer.new()
	_player.bus = "Music"
	_player.volume_db = PAD_VOLUME_DB
	add_child(_player)
	# Combat tension layer
	_combat_player = AudioStreamPlayer.new()
	_combat_player.bus = "Music"
	_combat_player.volume_db = COMBAT_VOLUME_DB_SILENT
	add_child(_combat_player)
	# Re-evaluate on tree change (scene transitions)
	get_tree().tree_changed.connect(_on_tree_changed)
	call_deferred("_refresh")
	# Subscribe to FactionConflictRegistry.pair_state_changed as the
	# fifth downstream consumer of the conflict system. When any pair
	# crosses into SKIRMISH+, raise the conflict_floor so the music
	# carries the war's weight even between fights.
	call_deferred("_wire_conflict_signal")

func _wire_conflict_signal() -> void:
	var fcr: Node = get_node_or_null("/root/FactionConflictRegistry")
	if fcr == null or not fcr.has_signal("pair_state_changed"):
		return
	var cb := Callable(self, "_on_conflict_changed")
	if not fcr.pair_state_changed.is_connected(cb):
		fcr.pair_state_changed.connect(cb)
	_recompute_conflict_floor()
	# Sixth subscriber to the cosmic-threat publisher set: Tiamat's
	# dream raises the music's floor on its own axis. Wired here so
	# both cosmic floors land alongside one another.
	var tr: Node = get_node_or_null("/root/TiamatRegistry")
	if tr and tr.has_signal("tier_changed"):
		var tcb := Callable(self, "_on_tiamat_tier_changed")
		if not tr.tier_changed.is_connected(tcb):
			tr.tier_changed.connect(tcb)
		_recompute_tiamat_floor()

func _on_tiamat_tier_changed(_new_tier: String, _old_tier: String, _new_value: int) -> void:
	_recompute_tiamat_floor()

# Tiamat floor: read current tier from TiamatRegistry and map to a
# float. Higher tier = louder baseline. Same shape as conflict floor
# but on a cosmic axis (not political). The two floors compound in
# the effective-target lerp; war + cosmic horror both raise music.
func _recompute_tiamat_floor() -> void:
	var tr: Node = get_node_or_null("/root/TiamatRegistry")
	if tr == null or not tr.has_method("current_tier"):
		_tiamat_floor = 0.0
		return
	var tier: String = String(tr.current_tier())
	match tier:
		"STIRRING":  _tiamat_floor = TIAMAT_FLOOR_STIRRING
		"WAKING":    _tiamat_floor = TIAMAT_FLOOR_WAKING
		"WAKING_2":  _tiamat_floor = TIAMAT_FLOOR_WAKING_2
		"AWAKE":     _tiamat_floor = TIAMAT_FLOOR_AWAKE
		_:           _tiamat_floor = 0.0

func _on_conflict_changed(_pair_key: StringName, _new_state: String, _old_state: String) -> void:
	_recompute_conflict_floor()

# The conflict floor is the MAX of every tracked pair's floor. If
# ANY pair is at OPEN_WAR the floor goes to 0.25; if no pair is
# OPEN_WAR but at least one is at SKIRMISH, 0.10. Otherwise 0.
# Using max keeps a single hot pair from being drowned out by quieter
# ones; war anywhere raises the baseline.
func _recompute_conflict_floor() -> void:
	var fcr: Node = get_node_or_null("/root/FactionConflictRegistry")
	if fcr == null or not fcr.has_method("all_active_conflicts"):
		_conflict_floor = 0.0
		return
	var max_floor: float = 0.0
	for entry in fcr.all_active_conflicts():
		var state: String = String(entry.get("state", "COLD"))
		var f: float = 0.0
		match state:
			"SKIRMISH": f = CONFLICT_FLOOR_SKIRMISH
			"OPEN_WAR": f = CONFLICT_FLOOR_OPEN_WAR
		if f > max_floor:
			max_floor = f
	_conflict_floor = max_floor

func _process(delta: float) -> void:
	# Smooth combat volume toward target; below 0.05 we let the player
	# stop entirely so we don't spend cycles on silence.
	if _combat_player == null:
		return
	# Effective target = max(per-fight target, conflict_floor, tiamat_floor).
	# War in the world OR Tiamat dreaming OR both means the combat
	# layer never falls below the floor. Boss fights still drive it
	# higher; the floors are just the new minimum. The two cosmic
	# floors compound via max so the SCARIER axis always wins.
	var effective_target: float = max(_combat_target_intensity, max(_conflict_floor, _tiamat_floor))
	_combat_intensity = lerp(_combat_intensity, effective_target, clamp(delta * 0.6, 0.0, 1.0))
	if _combat_intensity < 0.02 and _combat_player.playing:
		_combat_player.stop()
	elif _combat_intensity >= 0.05 and not _combat_player.playing:
		_play_combat_pad()
	_combat_player.volume_db = lerp(COMBAT_VOLUME_DB_SILENT, COMBAT_VOLUME_DB_PEAK, _combat_intensity)

# Public API. BossArena calls this on engagement (1.0) and release
# (0.0). Phase transitions can bump it higher (1.2 = saturated push).
func set_combat_intensity(target: float) -> void:
	_combat_target_intensity = clamp(target, 0.0, 1.5)

func _play_combat_pad() -> void:
	var stream := AudioStreamGenerator.new()
	stream.mix_rate = SAMPLE_RATE
	stream.buffer_length = PAD_DURATION
	_combat_player.stream = stream
	_combat_player.play()
	var pb: AudioStreamGeneratorPlayback = _combat_player.get_stream_playback()
	if pb == null:
		return
	# Tritone-rich ostinato: root + tritone + minor third + fifth, low
	# octave so it sits under the region pad without fighting for
	# attention. Same loop length so it phases smoothly.
	var freqs := [55.0, 77.78, 65.41, 82.41]
	_fill_combat_pad(pb, freqs)

func _fill_combat_pad(pb: AudioStreamGeneratorPlayback, freqs: Array) -> void:
	var total_samples: int = int(PAD_DURATION * SAMPLE_RATE)
	var phases: Array[float] = []
	for _f in freqs:
		phases.append(0.0)
	# Square-ish wave for grain instead of pure sine
	for i in range(total_samples):
		var t: float = float(i) / SAMPLE_RATE
		# Faster heartbeat amplitude than the region pad (0.8 Hz)
		var amp_env: float = 0.55 + 0.45 * abs(sin(t * TAU * 0.8))
		var loop_env: float = 0.5 - 0.5 * cos(float(i) / float(total_samples) * TAU)
		var sample: float = 0.0
		for j in range(freqs.size()):
			var freq: float = float(freqs[j])
			phases[j] += freq / SAMPLE_RATE
			# Soft square: sin clipped to give a faint grit
			var raw: float = sin(phases[j] * TAU)
			var voice: float = (1.0 if raw > 0.0 else -1.0) * 0.3 + raw * 0.7
			sample += voice / float(freqs.size())
		sample *= amp_env * loop_env * 0.50
		pb.push_frame(Vector2(sample, sample))

func _on_tree_changed() -> void:
	# Debounce, only check once per frame
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
