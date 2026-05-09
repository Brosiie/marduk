extends Node

# SkyDirector, autoload that drives the active scene's WorldEnvironment
# + DirectionalLight from WorldClock.time_of_day so the sun rises, peaks,
# sets, and the sky/fog colors interpolate smoothly. Makes the whole
# world feel alive without per-scene wiring.
#
# Hooks every scene change. Searches the scene for a WorldEnvironment
# and a DirectionalLight named "Sun" (or any DirectionalLight if no
# match). Updates them every frame WorldClock.time_changed fires.
#
# Color stops are 5-key gradients per channel (midnight, dawn, noon,
# dusk, late night), matched to time_of_day in [0.0, 1.0).

# Per time-of-day color stops. Times in [0.0, 1.0) where 0=midnight,
# 0.25=dawn, 0.5=noon, 0.75=dusk.
const SKY_TOP := [
	{"t": 0.00, "c": Color(0.04, 0.04, 0.10)},  # midnight
	{"t": 0.20, "c": Color(0.30, 0.20, 0.45)},  # pre-dawn
	{"t": 0.30, "c": Color(0.55, 0.65, 0.95)},  # dawn
	{"t": 0.50, "c": Color(0.40, 0.65, 1.00)},  # noon
	{"t": 0.70, "c": Color(0.55, 0.35, 0.50)},  # dusk
	{"t": 0.85, "c": Color(0.20, 0.10, 0.25)},  # late dusk
	{"t": 1.00, "c": Color(0.04, 0.04, 0.10)},  # midnight
]
const SKY_HORIZON := [
	{"t": 0.00, "c": Color(0.05, 0.05, 0.12)},
	{"t": 0.20, "c": Color(0.85, 0.50, 0.30)},  # warm dawn glow
	{"t": 0.50, "c": Color(0.75, 0.80, 0.95)},
	{"t": 0.70, "c": Color(0.95, 0.45, 0.20)},  # warm dusk glow
	{"t": 0.85, "c": Color(0.30, 0.15, 0.20)},
	{"t": 1.00, "c": Color(0.05, 0.05, 0.12)},
]
const SUN_COLOR := [
	{"t": 0.00, "c": Color(0.20, 0.20, 0.40)},  # moonlight
	{"t": 0.25, "c": Color(1.00, 0.65, 0.40)},  # dawn
	{"t": 0.50, "c": Color(1.00, 0.95, 0.85)},  # noon
	{"t": 0.75, "c": Color(1.00, 0.55, 0.30)},  # dusk
	{"t": 1.00, "c": Color(0.20, 0.20, 0.40)},
]
const SUN_ENERGY := [
	{"t": 0.00, "v": 0.20},  # moonlight, dim
	{"t": 0.20, "v": 0.50},
	{"t": 0.30, "v": 1.20},
	{"t": 0.50, "v": 1.80},  # noon, peak
	{"t": 0.70, "v": 1.20},
	{"t": 0.80, "v": 0.50},
	{"t": 1.00, "v": 0.20},
]

var _world_env: WorldEnvironment = null
var _sun: DirectionalLight3D = null
var _clock: Node = null

func _ready() -> void:
	_clock = get_node_or_null("/root/WorldClock")
	if _clock and _clock.has_signal("time_changed"):
		_clock.time_changed.connect(_on_time_changed)
	get_tree().tree_changed.connect(_on_tree_changed)
	call_deferred("_rescan")

func _on_tree_changed() -> void:
	# Debounce, multi-fire on scene changes; consolidate to next frame.
	call_deferred("_rescan")

func _rescan() -> void:
	var scene := get_tree().current_scene if get_tree() else null
	if scene == null:
		return
	_world_env = _find_world_env(scene)
	_sun = _find_sun(scene)
	# Apply current time immediately so the scene loads with the right
	# lighting instead of flashing through the default.
	if _clock and "time_of_day" in _clock:
		_apply(_clock.time_of_day)

func _find_world_env(node: Node) -> WorldEnvironment:
	if node is WorldEnvironment:
		return node
	for c in node.get_children():
		var f := _find_world_env(c)
		if f != null:
			return f
	return null

func _find_sun(node: Node) -> DirectionalLight3D:
	# Prefer one named "Sun" if there's a match
	for d in get_tree().get_nodes_in_group("sun"):
		if d is DirectionalLight3D:
			return d
	for d in _all_directional_lights(node):
		if d.name == "Sun":
			return d
	# Otherwise any DirectionalLight
	var all := _all_directional_lights(node)
	if all.size() > 0:
		return all[0]
	return null

func _all_directional_lights(node: Node) -> Array[DirectionalLight3D]:
	var out: Array[DirectionalLight3D] = []
	if node is DirectionalLight3D:
		out.append(node)
	for c in node.get_children():
		out.append_array(_all_directional_lights(c))
	return out

func _on_time_changed(t: float) -> void:
	_apply(t)

func _apply(t: float) -> void:
	# Storm/rain/mist multiplier from WeatherDirector (1.0 if no weather
	# autoload). Darkens sky + sun energy so storms read visually.
	var wd: Node = get_node_or_null("/root/WeatherDirector")
	var dark: float = 1.0
	if wd and wd.has_method("storm_darkness"):
		dark = wd.storm_darkness()
	if _world_env and _world_env.environment:
		var env: Environment = _world_env.environment
		var sky_mat: ProceduralSkyMaterial = env.sky.sky_material if env.sky else null
		if sky_mat:
			sky_mat.sky_top_color = _sample(SKY_TOP, t).darkened(1.0 - dark)
			sky_mat.sky_horizon_color = _sample(SKY_HORIZON, t).darkened((1.0 - dark) * 0.7)
			sky_mat.ground_horizon_color = _sample(SKY_HORIZON, t).darkened(0.4 + (1.0 - dark) * 0.3)
			sky_mat.ground_bottom_color = _sample(SKY_TOP, t).darkened(0.5 + (1.0 - dark) * 0.3)
		# Ambient color tracks the horizon so shadows feel right
		env.ambient_light_color = _sample(SKY_HORIZON, t).lightened(0.2).darkened((1.0 - dark) * 0.5)
		env.ambient_light_energy = lerp(0.45, 1.0, _sun_brightness(t)) * dark
		# Storm fog: bump density when overcast / raining / storming
		env.fog_density = lerp(0.005, 0.035, 1.0 - dark)
	if _sun:
		_sun.light_color = _sample(SUN_COLOR, t)
		_sun.light_energy = _sample_float(SUN_ENERGY, t) * dark
		# Rotate the sun around the X axis: 0.0 = bottom, 0.5 = top, 1.0 = bottom.
		# Use sine for smooth rise/set arc.
		var sun_pitch_deg: float = sin(t * TAU - PI * 0.5) * 75.0
		var sun_yaw_deg: float = (t - 0.5) * 30.0  # slight east-to-west drift
		_sun.rotation_degrees = Vector3(sun_pitch_deg - 45.0, sun_yaw_deg, 0)

func _sun_brightness(t: float) -> float:
	# 0 at midnight, 1 at noon
	return clamp(sin(t * TAU - PI * 0.5) * 0.5 + 0.5, 0.0, 1.0)

# Sample a list-of-{t, c} keyframes by interpolation. List MUST be
# sorted by `t`. Wraps at 1.0.
func _sample(stops: Array, t: float) -> Color:
	t = fposmod(t, 1.0)
	var prev: Dictionary = stops[stops.size() - 1]
	for s in stops:
		if t <= s.t:
			var span: float = s.t - prev.t if s.t > prev.t else (s.t + 1.0 - prev.t)
			if span <= 0.0:
				return s.c
			var local_t: float = (t - prev.t) / span if t >= prev.t else (t + 1.0 - prev.t) / span
			return prev.c.lerp(s.c, local_t)
		prev = s
	return stops[stops.size() - 1].c

func _sample_float(stops: Array, t: float) -> float:
	t = fposmod(t, 1.0)
	var prev: Dictionary = stops[stops.size() - 1]
	for s in stops:
		if t <= s.t:
			var span: float = s.t - prev.t if s.t > prev.t else (s.t + 1.0 - prev.t)
			if span <= 0.0:
				return s.v
			var local_t: float = (t - prev.t) / span if t >= prev.t else (t + 1.0 - prev.t) / span
			return lerp(prev.v, s.v, local_t)
		prev = s
	return stops[stops.size() - 1].v
