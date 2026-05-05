extends Node
class_name WeatherSystem

# Per-zone weather. Lightweight: switches between weather presets, drives a
# particle layer (rain/snow/embers) and adjusts WorldEnvironment fog density.

enum Weather { CLEAR, OVERCAST, RAIN, STORM, SNOW, ASHFALL, MIST }

@export var environment_path: NodePath
@export var current: Weather = Weather.CLEAR
@export var fog_density_clear: float = 0.008
@export var fog_density_overcast: float = 0.014
@export var fog_density_storm: float = 0.025
@export var fog_density_mist: float = 0.05

@onready var rain_particles: GPUParticles3D = $RainParticles if has_node("RainParticles") else null
@onready var snow_particles: GPUParticles3D = $SnowParticles if has_node("SnowParticles") else null
@onready var ash_particles: GPUParticles3D = $AshParticles if has_node("AshParticles") else null

var _env: WorldEnvironment

func _ready() -> void:
	if environment_path:
		_env = get_node_or_null(environment_path)
	_apply()

func set_weather(w: Weather) -> void:
	current = w
	_apply()

func _apply() -> void:
	if rain_particles: rain_particles.emitting = current in [Weather.RAIN, Weather.STORM]
	if snow_particles: snow_particles.emitting = current == Weather.SNOW
	if ash_particles: ash_particles.emitting = current == Weather.ASHFALL
	if _env and _env.environment:
		var d := fog_density_clear
		match current:
			Weather.OVERCAST: d = fog_density_overcast
			Weather.STORM: d = fog_density_storm
			Weather.MIST: d = fog_density_mist
		_env.environment.fog_density = d
