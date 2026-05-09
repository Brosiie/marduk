extends Node

# WeatherDirector, autoload that drives the active scene's weather:
# rain / storms / mist / lightning / post-storm rainbows. Auto-discovers
# the scene's camera and parents particle emitters under a follower so
# rain falls around the player wherever they are.
#
# Architecture:
#   WorldClock      drives time_of_day (already an autoload)
#   SkyDirector     drives env colors + sun rotation off time_of_day
#   WeatherDirector drives rain/storm/mist effects + tells SkyDirector
#                    when to darken the sky (storms)
#
# The state machine cycles every MIN_DURATION..MAX_DURATION seconds.
# When STORM ends and we transition to CLEAR/OVERCAST, a rainbow
# appears for RAINBOW_DURATION seconds then fades.

enum Weather { CLEAR, OVERCAST, RAIN, STORM, MIST }

# How long any weather state persists before _pick_next_weather runs.
# Real life: storms are usually shorter than clear stretches; mist hangs
# around longer than rain. _pick_next_weather is the policy knob.
const MIN_DURATION := 90.0
const MAX_DURATION := 240.0

# Rainbow appears AFTER a STORM transitions to CLEAR (or OVERCAST).
# Stays visible for this long, then fades over RAINBOW_FADE seconds.
const RAINBOW_DURATION := 45.0
const RAINBOW_FADE := 6.0

# Lightning during storms: random strike every MIN..MAX seconds, screen
# flash via Juice + brief sky-color brighten.
const LIGHTNING_MIN_INTERVAL := 6.0
const LIGHTNING_MAX_INTERVAL := 18.0

# --- State ---
var current: int = Weather.CLEAR
var previous: int = Weather.CLEAR
var _state_started_at: float = 0.0
var _next_change_at: float = 0.0
var _next_lightning_at: float = 0.0
var _rainbow_started_at: float = -1.0  # -1 = no rainbow

# --- Scene attachments (rebuilt on tree_changed) ---
var _scene_root: Node = null
var _camera: Camera3D = null
var _follower: Node3D = null
var _rain_particles: GPUParticles3D = null
var _storm_particles: GPUParticles3D = null
var _mist_particles: GPUParticles3D = null
var _rainbow: Node3D = null

signal weather_changed(new_weather: int)

func _ready() -> void:
	get_tree().tree_changed.connect(_on_tree_changed)
	call_deferred("_rescan")
	_state_started_at = _now()
	_next_change_at = _state_started_at + randf_range(MIN_DURATION, MAX_DURATION)

func _exit_tree() -> void:
	# Autoloads outlive normal scene tear-down by design, so the
	# tree_changed connection survives past the point where SceneTree
	# itself is being dismantled. Disconnect here so we don't keep
	# firing after our subscriber side is no longer in a usable tree.
	var t := get_tree()
	if t and t.tree_changed.is_connected(_on_tree_changed):
		t.tree_changed.disconnect(_on_tree_changed)

func _process(delta: float) -> void:
	if _scene_root == null or not is_instance_valid(_scene_root):
		return
	_follow_camera()
	_tick_weather()
	_tick_lightning()
	_tick_rainbow(delta)

# --- Public API ---

func set_weather(w: int) -> void:
	if w == current:
		return
	previous = current
	current = w
	_state_started_at = _now()
	_next_change_at = _state_started_at + randf_range(MIN_DURATION, MAX_DURATION)
	_apply_weather_visuals()
	# Rainbow trigger: when a STORM ends and we go CLEAR or OVERCAST
	if (previous == Weather.STORM or previous == Weather.RAIN) and (current == Weather.CLEAR or current == Weather.OVERCAST):
		_spawn_rainbow()
	weather_changed.emit(current)

# Returns 0..1 for how dark the storm is making the sky. SkyDirector
# multiplies its env colors / sun energy by this when applying.
func storm_darkness() -> float:
	match current:
		Weather.STORM:    return 0.55
		Weather.RAIN:     return 0.80
		Weather.OVERCAST: return 0.85
		Weather.MIST:     return 0.90
		_:                return 1.0

# --- Scene rescan ---

func _on_tree_changed() -> void:
	# Debounce: tree_changed fires for EVERY node added (props, mobs,
	# particles), which would re-rescan and leak follower+particle
	# systems hundreds of times per scene load -> RID exhaustion crash.
	# Only rescan when the SCENE ROOT actually changes.
	# Guard: tree_changed can also fire mid-teardown when our own get_tree()
	# returns null. The engine logs "Parameter data.tree is null" before
	# any GDScript check can intercept, so check is_inside_tree() first
	# (it's a property read, no get_tree() call).
	if not is_inside_tree():
		return
	var current_scene := get_tree().current_scene
	if current_scene == _scene_root:
		return  # scene unchanged, ignore the spam
	call_deferred("_rescan")

func _rescan() -> void:
	var new_scene = get_tree().current_scene if get_tree() else null
	if new_scene == null:
		return
	# Idempotent: if we already attached to this scene, don't re-attach.
	# Particle nodes from prior scenes are GC'd when the scene unloads.
	if new_scene == _scene_root and _follower != null and is_instance_valid(_follower):
		return
	_scene_root = new_scene
	_camera = _find_camera(_scene_root)
	# Build a follower that hangs around the camera.
	_follower = Node3D.new()
	_follower.name = "WeatherFollower"
	_scene_root.add_child(_follower)
	_rain_particles = _make_rain_particles()
	_follower.add_child(_rain_particles)
	_storm_particles = _make_storm_particles()
	_follower.add_child(_storm_particles)
	_mist_particles = _make_mist_particles()
	_follower.add_child(_mist_particles)
	_apply_weather_visuals()

func _follow_camera() -> void:
	if _camera == null or not is_instance_valid(_camera) or _follower == null:
		return
	# Particles emit in a box ABOVE the player so rain falls around the
	# play area. We snap to the camera position (xz only) so player
	# motion drags the rain field with them.
	var pos := _camera.global_position
	pos.y = pos.y + 8.0  # spawn band 8m above camera height
	_follower.global_position = pos

# --- Weather state tick ---

func _tick_weather() -> void:
	if _now() < _next_change_at:
		return
	var next: int = _pick_next_weather()
	set_weather(next)

# --- Lightning ---

func _tick_lightning() -> void:
	if current != Weather.STORM:
		_next_lightning_at = _now() + LIGHTNING_MIN_INTERVAL
		return
	if _now() < _next_lightning_at:
		return
	_strike_lightning()
	_next_lightning_at = _now() + randf_range(LIGHTNING_MIN_INTERVAL, LIGHTNING_MAX_INTERVAL)

func _strike_lightning() -> void:
	# Brief white flash via the Juice autoload + a thunder cue if the
	# audio bus is wired. Two-stage: bright flash, then dim flicker.
	# Thunder fires 0.4s after the flash for that "see the bolt, hear
	# it shortly after" lag (light is faster than sound), sells
	# distance and scale.
	var juice: Node = get_node_or_null("/root/Juice")
	if juice and juice.has_method("flash"):
		juice.flash(Color(0.95, 0.95, 1.0), 0.08, 0.30)
		var t := get_tree().create_timer(0.15)
		t.timeout.connect(func():
			if juice and juice.has_method("flash"):
				juice.flash(Color(0.85, 0.85, 0.95), 0.05, 0.20)
		)
	# Thunder audio with a delay (audio lag = perceived distance)
	var thunder_t := get_tree().create_timer(randf_range(0.35, 0.55))
	thunder_t.timeout.connect(func():
		var ab: Node = get_node_or_null("/root/AudioBus")
		if ab and ab.has_method("play_cue") and _camera:
			ab.play_cue(&"thunder", _camera.global_position, -2.0, randf_range(0.85, 1.05))
	)

# --- Rainbow ---

func _spawn_rainbow() -> void:
	if _rainbow:
		_rainbow.queue_free()
	if _scene_root == null:
		return
	# Position rainbow opposite the sun. Without a sun reference we
	# pick a default direction; real sun position would mean reading
	# the DirectionalLight from the scene.
	var sun_dir: Vector3 = _find_sun_direction()
	var rainbow_dir: Vector3 = Vector3(-sun_dir.x, 0.5, -sun_dir.z).normalized()
	var distance: float = 80.0
	var center: Vector3 = (_camera.global_position if _camera else Vector3.ZERO) + rainbow_dir * distance
	# Build a torus mesh at that position, paint with rainbow shader
	_rainbow = MeshInstance3D.new()
	_rainbow.name = "Rainbow"
	var torus := TorusMesh.new()
	torus.inner_radius = 28.0
	torus.outer_radius = 32.0
	(_rainbow as MeshInstance3D).mesh = torus
	# Shader paints rainbow gradient by angle around torus + alpha pulse
	var shader := Shader.new()
	shader.code = """
shader_type spatial;
render_mode unshaded, cull_disabled, blend_mix, depth_draw_never;
uniform float fade_alpha : hint_range(0.0, 1.0) = 1.0;
varying vec3 v_local;
void vertex() { v_local = VERTEX; }
void fragment() {
	// polar angle in the torus's local XZ -> rainbow band
	float theta = atan(v_local.z, v_local.x);
	float t = (theta + 3.14159) / 6.28318;  // 0..1
	// Rainbow gradient: 6 stops red->violet
	vec3 col;
	if (t < 0.166)      col = mix(vec3(0.95, 0.20, 0.20), vec3(0.95, 0.55, 0.10), t/0.166);
	else if (t < 0.333) col = mix(vec3(0.95, 0.55, 0.10), vec3(0.95, 0.85, 0.20), (t-0.166)/0.167);
	else if (t < 0.5)   col = mix(vec3(0.95, 0.85, 0.20), vec3(0.20, 0.85, 0.30), (t-0.333)/0.167);
	else if (t < 0.666) col = mix(vec3(0.20, 0.85, 0.30), vec3(0.20, 0.55, 0.95), (t-0.5)/0.166);
	else if (t < 0.833) col = mix(vec3(0.20, 0.55, 0.95), vec3(0.45, 0.20, 0.85), (t-0.666)/0.167);
	else                col = mix(vec3(0.45, 0.20, 0.85), vec3(0.65, 0.10, 0.85), (t-0.833)/0.167);
	ALBEDO = col;
	ALPHA = 0.45 * fade_alpha;
}
"""
	var mat := ShaderMaterial.new()
	mat.shader = shader
	mat.set_shader_parameter("fade_alpha", 0.0)
	_rainbow.material_override = mat
	# Orient rainbow upright so the arc shows above the horizon
	_rainbow.rotation = Vector3(PI * 0.5, 0, 0)
	_rainbow.global_position = center
	_scene_root.add_child(_rainbow)
	_rainbow_started_at = _now()

func _tick_rainbow(_delta: float) -> void:
	if _rainbow == null or not is_instance_valid(_rainbow) or _rainbow_started_at < 0.0:
		return
	var elapsed: float = _now() - _rainbow_started_at
	var alpha: float
	if elapsed < RAINBOW_FADE:
		alpha = elapsed / RAINBOW_FADE  # fade-in
	elif elapsed < RAINBOW_DURATION - RAINBOW_FADE:
		alpha = 1.0
	elif elapsed < RAINBOW_DURATION:
		alpha = 1.0 - (elapsed - (RAINBOW_DURATION - RAINBOW_FADE)) / RAINBOW_FADE
	else:
		_rainbow.queue_free()
		_rainbow = null
		_rainbow_started_at = -1.0
		return
	var mat: ShaderMaterial = _rainbow.material_override
	if mat:
		mat.set_shader_parameter("fade_alpha", clamp(alpha, 0.0, 1.0))

# --- Apply visuals to particles ---

func _apply_weather_visuals() -> void:
	if _rain_particles:  _rain_particles.emitting = current == Weather.RAIN
	if _storm_particles: _storm_particles.emitting = current == Weather.STORM
	if _mist_particles:  _mist_particles.emitting = current == Weather.MIST
	# Audio: continuous rain hiss intensity tracks weather state.
	# AudioBus crossfades volume so transitions feel like the rain is
	# rolling in or letting up, not on/off switches.
	var ab: Node = get_node_or_null("/root/AudioBus")
	if ab and ab.has_method("set_rain_intensity"):
		var intensity: float = 0.0
		match current:
			Weather.RAIN:  intensity = 0.55
			Weather.STORM: intensity = 1.0
			Weather.MIST:  intensity = 0.10  # faint hiss for mist atmosphere
		ab.set_rain_intensity(intensity)

# --- Particle factories ---

func _make_rain_particles() -> GPUParticles3D:
	var p := GPUParticles3D.new()
	p.name = "Rain"
	p.amount = 280
	p.lifetime = 1.6
	p.preprocess = 1.0
	p.visibility_aabb = AABB(Vector3(-25, -10, -25), Vector3(50, 25, 50))
	var mat := ParticleProcessMaterial.new()
	mat.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_BOX
	mat.emission_box_extents = Vector3(20, 0.5, 20)
	mat.direction = Vector3(0.1, -1.0, 0.05)
	mat.spread = 5.0
	mat.initial_velocity_min = 18.0
	mat.initial_velocity_max = 24.0
	mat.gravity = Vector3(0.5, -8.0, 0.0)
	mat.scale_min = 0.04
	mat.scale_max = 0.06
	mat.color = Color(0.65, 0.78, 0.92, 0.8)
	p.process_material = mat
	var quad := QuadMesh.new()
	quad.size = Vector2(0.04, 0.5)  # narrow vertical streak
	var smat := StandardMaterial3D.new()
	smat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	smat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	smat.albedo_color = Color(0.72, 0.85, 0.95, 0.75)
	smat.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
	smat.billboard_keep_scale = true
	quad.material = smat
	p.draw_pass_1 = quad
	p.emitting = false
	return p

func _make_storm_particles() -> GPUParticles3D:
	var p := _make_rain_particles()
	p.name = "Storm"
	p.amount = 600  # heavier downpour
	# Storm wind angle is steeper
	var mat := p.process_material as ParticleProcessMaterial
	mat.direction = Vector3(0.4, -1.0, 0.2)
	mat.gravity = Vector3(2.0, -10.0, 0.5)
	mat.initial_velocity_min = 22.0
	mat.initial_velocity_max = 30.0
	p.emitting = false
	return p

func _make_mist_particles() -> GPUParticles3D:
	var p := GPUParticles3D.new()
	p.name = "Mist"
	p.amount = 80
	p.lifetime = 12.0
	p.preprocess = 6.0
	p.visibility_aabb = AABB(Vector3(-30, -5, -30), Vector3(60, 15, 60))
	var mat := ParticleProcessMaterial.new()
	mat.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_BOX
	mat.emission_box_extents = Vector3(25, 1.5, 25)
	mat.direction = Vector3(0.5, 0.0, 0.3)
	mat.spread = 30.0
	mat.initial_velocity_min = 0.4
	mat.initial_velocity_max = 1.2
	mat.gravity = Vector3(0.2, 0.0, 0.1)
	mat.scale_min = 1.5
	mat.scale_max = 3.5
	mat.color = Color(0.85, 0.88, 0.92, 0.25)
	p.process_material = mat
	var quad := QuadMesh.new()
	quad.size = Vector2(2.5, 1.0)
	var smat := StandardMaterial3D.new()
	smat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	smat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	smat.albedo_color = Color(0.85, 0.88, 0.92, 0.20)
	smat.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
	smat.billboard_keep_scale = true
	quad.material = smat
	p.draw_pass_1 = quad
	p.emitting = false
	return p

# --- Helpers ---

func _now() -> float:
	return Time.get_ticks_msec() / 1000.0

func _find_camera(node: Node) -> Camera3D:
	if node is Camera3D and (node as Camera3D).current:
		return node
	for c in node.get_children():
		var f := _find_camera(c)
		if f != null:
			return f
	return null

func _find_sun_direction() -> Vector3:
	# Default points roughly toward east-south horizon if no sun in
	# scene; rainbow ends up west-north which is fine for screenshots.
	if _scene_root == null:
		return Vector3(-0.5, -0.7, -0.5).normalized()
	for n in get_tree().get_nodes_in_group("sun"):
		if n is DirectionalLight3D:
			return -(n as DirectionalLight3D).global_transform.basis.z
	return Vector3(-0.5, -0.7, -0.5).normalized()

# --- Policy: Markov chain + time-of-day bias ---
#
# Two-stage decision:
#   1. Pull base transition weights from the Markov row for `current`.
#      Storms must be preceded by rain. Rainbow trigger
#      (STORM|RAIN -> CLEAR|OVERCAST) feels earned.
#   2. Multiply weights by time-of-day modifiers so dawn favors mist,
#      dusk favors storms, night favors overcast/mist.
#
# Self-transitions (CLEAR->CLEAR) are kept low so the duration timer
# doesn't burn 4 minutes on identical-looking weather.
func _pick_next_weather() -> int:
	var weights: Dictionary = _markov_row_for(current).duplicate()
	_apply_time_bias(weights, _time_of_day())
	_apply_zone_bias(weights)
	return _weighted_pick(weights)

# Per-zone weather palette: each region has its own climate. Black
# Citadel is permanently cursed (storms common, never sunny). Sunsworn
# Chapel is holy (mostly clear, no storms). Sword-Vow Ruins keeps the
# sakura grove pristine (gentle rain, no storms). Wastelands skip rain.
# Mist Vale lives up to its name. The Cradle is divinely clear.
#
# A weight of 0 hard-bans that weather; multipliers scale Markov base.
func _apply_zone_bias(weights: Dictionary) -> void:
	var zone: StringName = _detect_zone()
	match zone:
		&"sword_vow_ruins":
			weights[Weather.STORM] = 0.0  # protect the sakura grove
			weights[Weather.RAIN] = float(weights.get(Weather.RAIN, 0.0)) * 0.4
			weights[Weather.MIST] = float(weights.get(Weather.MIST, 0.0)) * 1.6
		&"sunsworn_chapel":
			weights[Weather.STORM] = 0.0  # holy zone, no torment
			weights[Weather.CLEAR] = float(weights.get(Weather.CLEAR, 0.0)) * 2.8
			weights[Weather.RAIN] = float(weights.get(Weather.RAIN, 0.0)) * 0.25
		&"black_citadel":
			weights[Weather.CLEAR] = 0.0  # the throne never knows light
			weights[Weather.OVERCAST] = float(weights.get(Weather.OVERCAST, 0.0)) * 2.0
			weights[Weather.STORM] = float(weights.get(Weather.STORM, 0.0)) * 3.0
			weights[Weather.RAIN] = float(weights.get(Weather.RAIN, 0.0)) * 2.0
		&"ember_steppes", &"the_reed_wastes", &"shrieking_highlands":
			weights[Weather.RAIN] = float(weights.get(Weather.RAIN, 0.0)) * 0.2
			weights[Weather.STORM] = float(weights.get(Weather.STORM, 0.0)) * 0.2
			weights[Weather.MIST] = float(weights.get(Weather.MIST, 0.0)) * 1.4
		&"mist_vale":
			weights[Weather.MIST] = float(weights.get(Weather.MIST, 0.0)) * 5.0
			weights[Weather.CLEAR] = float(weights.get(Weather.CLEAR, 0.0)) * 0.4
		&"the_cradle":
			weights[Weather.STORM] = 0.0
			weights[Weather.CLEAR] = float(weights.get(Weather.CLEAR, 0.0)) * 3.5
			weights[Weather.RAIN] = float(weights.get(Weather.RAIN, 0.0)) * 0.2
		&"verdant_wound":
			weights[Weather.RAIN] = float(weights.get(Weather.RAIN, 0.0)) * 1.8  # rainforest
			weights[Weather.MIST] = float(weights.get(Weather.MIST, 0.0)) * 1.6
		&"lapis_bay", &"sundered_coast":
			weights[Weather.RAIN] = float(weights.get(Weather.RAIN, 0.0)) * 1.5  # coastal
			weights[Weather.OVERCAST] = float(weights.get(Weather.OVERCAST, 0.0)) * 1.3
		&"bone_mountains":
			weights[Weather.STORM] = float(weights.get(Weather.STORM, 0.0)) * 1.5
			weights[Weather.MIST] = float(weights.get(Weather.MIST, 0.0)) * 1.3
		&"babilim", &"ashurim":
			weights[Weather.STORM] = float(weights.get(Weather.STORM, 0.0)) * 0.6  # cities, sheltered

func _detect_zone() -> StringName:
	if _scene_root == null:
		return &""
	var geometry := _scene_root.get_node_or_null("Geometry")
	if geometry and "style_id" in geometry:
		return StringName(String(geometry.style_id))
	return &""

func _time_of_day() -> float:
	var clock: Node = get_node_or_null("/root/WorldClock")
	if clock and "time_of_day" in clock:
		return float(clock.time_of_day)
	return 0.5

# Transition probabilities from `state`. Weights don't have to sum to
# 1.0 -- _weighted_pick normalizes. Tuned so:
#   - Storms always preceded by rain (no CLEAR -> STORM jumps)
#   - Rainbow trigger fires roughly every 5-10 min of play
#   - Self-transitions are minority (visible variety guaranteed)
func _markov_row_for(state: int) -> Dictionary:
	match state:
		Weather.CLEAR:
			return {Weather.CLEAR: 35.0, Weather.OVERCAST: 35.0, Weather.MIST: 18.0, Weather.RAIN: 12.0}
		Weather.OVERCAST:
			return {Weather.CLEAR: 25.0, Weather.OVERCAST: 30.0, Weather.RAIN: 30.0, Weather.MIST: 15.0}
		Weather.RAIN:
			return {Weather.RAIN: 15.0, Weather.OVERCAST: 50.0, Weather.STORM: 25.0, Weather.CLEAR: 10.0}
		Weather.STORM:
			return {Weather.STORM: 15.0, Weather.RAIN: 55.0, Weather.OVERCAST: 25.0, Weather.MIST: 5.0}
		Weather.MIST:
			return {Weather.CLEAR: 50.0, Weather.MIST: 25.0, Weather.OVERCAST: 20.0, Weather.RAIN: 5.0}
	return {Weather.CLEAR: 1.0}

# Time-of-day modulation. Multiplies the weight of certain weather
# types based on the WorldClock phase:
#   Dawn   (0.20-0.30): mist 2.5x  (mystical morning)
#   Dusk   (0.70-0.85): storm 1.7x, rain 1.4x  (epic boss-fight sky)
#   Night  (>=0.85 or <0.20): clear 0.6x, overcast 1.4x, mist 1.3x
#   Day    (0.30-0.70): no modifier (Markov base wins)
func _apply_time_bias(weights: Dictionary, t: float) -> void:
	if t >= 0.20 and t < 0.30:
		weights[Weather.MIST] = weights.get(Weather.MIST, 0.0) * 2.5
	elif t >= 0.70 and t < 0.85:
		weights[Weather.STORM] = weights.get(Weather.STORM, 0.0) * 1.7
		weights[Weather.RAIN] = weights.get(Weather.RAIN, 0.0) * 1.4
	elif t >= 0.85 or t < 0.20:
		weights[Weather.CLEAR] = weights.get(Weather.CLEAR, 0.0) * 0.6
		weights[Weather.OVERCAST] = weights.get(Weather.OVERCAST, 0.0) * 1.4
		weights[Weather.MIST] = weights.get(Weather.MIST, 0.0) * 1.3

# Sample a weighted-random key from `weights`. Robust to empty/zero
# weights (returns CLEAR as the safe default).
func _weighted_pick(weights: Dictionary) -> int:
	var total: float = 0.0
	for w in weights.values():
		total += float(w)
	if total <= 0.0:
		return Weather.CLEAR
	var roll: float = randf() * total
	var cumulative: float = 0.0
	for k in weights.keys():
		cumulative += float(weights[k])
		if roll <= cumulative:
			return int(k)
	return Weather.CLEAR
