extends Node

# WeatherDirector — autoload that drives the active scene's weather:
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
	# Debounce: scene swaps fire many tree_changed events. Defer to
	# next frame and the latest call wins.
	call_deferred("_rescan")

func _rescan() -> void:
	_scene_root = get_tree().current_scene if get_tree() else null
	if _scene_root == null:
		return
	_camera = _find_camera(_scene_root)
	# Build a follower that hangs around the camera. We re-parent it
	# under the new scene every rescan because the old one is freed
	# with the previous scene.
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
	var juice: Node = get_node_or_null("/root/Juice")
	if juice and juice.has_method("flash"):
		juice.flash(Color(0.95, 0.95, 1.0), 0.08, 0.30)
		# Second weaker pulse 0.15s later for the flicker feel
		var t := get_tree().create_timer(0.15)
		t.timeout.connect(func():
			if juice and juice.has_method("flash"):
				juice.flash(Color(0.85, 0.85, 0.95), 0.05, 0.20)
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

# --- Policy: BOND, write this function ---
#
# This decides what weather comes next when the duration timer expires.
# Multiple valid approaches; pick whichever matches the gameplay vibe.
#
# OPTIONS:
# A) Simple weighted random:
#      60% CLEAR, 15% OVERCAST, 15% RAIN, 7% STORM, 3% MIST
# B) Markov chain (state-aware):
#      CLEAR  -> 70% CLEAR, 20% OVERCAST, 10% MIST
#      OVERCAST -> 30% CLEAR, 30% OVERCAST, 30% RAIN, 10% MIST
#      RAIN -> 25% RAIN, 50% OVERCAST, 20% STORM, 5% CLEAR
#      STORM -> 50% RAIN, 30% OVERCAST, 20% STORM (storms persist)
#      MIST -> 60% CLEAR, 30% MIST, 10% OVERCAST
# C) Time-of-day biased: storms more likely at dusk, mist at dawn
# D) Always cycle: CLEAR -> OVERCAST -> RAIN -> STORM -> RAIN -> OVERCAST -> CLEAR
#
# Markov (B) gives the most natural feel because storms must be preceded
# by RAIN (no sudden CLEAR -> STORM jumps), and the transition into
# CLEAR via OVERCAST gives the rainbow time to feel earned.
#
# TODO(Bond): pick A/B/C/D or write your own. Default below is option A
# as a placeholder so the system runs out of the box.
func _pick_next_weather() -> int:
	# Default placeholder: simple weighted random (option A above).
	# Replace this body with your weather policy of choice.
	var roll: float = randf()
	if roll < 0.60: return Weather.CLEAR
	if roll < 0.75: return Weather.OVERCAST
	if roll < 0.90: return Weather.RAIN
	if roll < 0.97: return Weather.STORM
	return Weather.MIST
