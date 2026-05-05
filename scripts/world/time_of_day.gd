extends Node
class_name TimeOfDay

# Day/night cycle for outdoor zones. Drives DirectionalLight rotation, sky tint,
# and fog color over a configurable cycle length. Indoor and dungeon zones can
# disable by toggling `enabled = false`.

@export var enabled: bool = true
@export var cycle_minutes: float = 24.0  # real-world minutes per in-game day
@export var sun_path: NodePath
@export var environment_path: NodePath
@export var time_of_day: float = 0.4  # 0 = midnight, 0.25 = sunrise, 0.5 = noon, 0.75 = sunset

var _sun: DirectionalLight3D
var _env: WorldEnvironment

const DAY_SUN := Color(1.0, 0.95, 0.85)
const DUSK_SUN := Color(1.0, 0.55, 0.25)
const NIGHT_SUN := Color(0.30, 0.40, 0.65)

func _ready() -> void:
	if sun_path:
		_sun = get_node_or_null(sun_path)
	if environment_path:
		_env = get_node_or_null(environment_path)

func _process(delta: float) -> void:
	if not enabled:
		return
	time_of_day += delta / (cycle_minutes * 60.0)
	if time_of_day >= 1.0:
		time_of_day -= 1.0
	_apply()

func _apply() -> void:
	if _sun:
		# Sun arcs from east (rising at 0.25) to west (setting at 0.75)
		var angle := lerp(0.0, TAU, time_of_day) - PI * 0.5
		_sun.rotation.x = -sin(angle)
		_sun.rotation.y = cos(angle) * 0.4
		_sun.light_color = _sun_color_for_time(time_of_day)
		_sun.light_energy = _sun_energy_for_time(time_of_day)

func _sun_color_for_time(t: float) -> Color:
	# Smoothly blend between night, dawn, day, dusk
	if t < 0.20 or t > 0.80:
		return NIGHT_SUN
	if t >= 0.20 and t < 0.30:
		return DUSK_SUN.lerp(DAY_SUN, (t - 0.20) / 0.10)
	if t >= 0.30 and t < 0.70:
		return DAY_SUN
	if t >= 0.70 and t < 0.80:
		return DAY_SUN.lerp(DUSK_SUN, (t - 0.70) / 0.10)
	return NIGHT_SUN

func _sun_energy_for_time(t: float) -> float:
	if t < 0.20 or t > 0.80:
		return 0.15
	if t >= 0.30 and t < 0.70:
		return 1.2
	# dawn / dusk transitions
	return lerp(0.4, 1.2, abs(t - 0.5) / 0.20)
