extends Node
class_name CombatFeedback

# Visual / haptic / audio response to combat events.
# Hit-stop frames, camera shake, floating damage numbers, screen flash on crit.
# Feeds off the global "combat_bus" autoload signals (not yet implemented; for now
# you can call these methods directly from Hitbox._try_damage).

signal floating_text_request(text: String, position: Vector3, color: Color, scale: float)
signal screen_shake_request(strength: float, duration: float)
signal hit_stop_request(duration: float)

@export var camera_path: NodePath
@export var enable_hit_stop: bool = true
@export var enable_camera_shake: bool = true

var _camera: Camera3D
var _shake_strength: float = 0.0
var _shake_remaining: float = 0.0
var _shake_origin: Transform3D
var _hit_stop_remaining: float = 0.0

func _ready() -> void:
	if camera_path:
		_camera = get_node_or_null(camera_path)

func _process(delta: float) -> void:
	# Hit stop: pause physics briefly for impact emphasis. Gated on the
	# GameSettings.hit_stop slider — default 0.0 means we never set
	# Engine.time_scale here. Tracked timer still ticks down so the
	# request signal fires for any system that wants visual-only feedback.
	if _hit_stop_remaining > 0.0:
		_hit_stop_remaining -= delta
		if _slomo_enabled():
			Engine.time_scale = 0.05 if _hit_stop_remaining > 0.0 else 1.0
			if _hit_stop_remaining <= 0.0:
				Engine.time_scale = 1.0

	# Camera shake decays
	if _shake_remaining > 0.0 and _camera:
		_shake_remaining -= delta
		if _shake_remaining <= 0.0:
			_camera.transform = _shake_origin
			_shake_remaining = 0.0
		else:
			var t := _shake_remaining
			var offset := Vector3(
				randf_range(-1, 1),
				randf_range(-1, 1),
				randf_range(-1, 1)
			) * _shake_strength * t
			_camera.transform.origin = _shake_origin.origin + offset

# === Public hook API ===
func register_hit(damage: float, position: Vector3, was_crit: bool, was_perfect: bool = false) -> void:
	# Floating number
	var color := Color(1, 1, 1)
	var scale := 1.0
	if was_crit:
		color = Color(1.0, 0.85, 0.3)
		scale = 1.4
	if was_perfect:
		color = Color(0.5, 1.0, 0.7)
		scale = 1.3
	floating_text_request.emit("%d" % int(damage), position, color, scale)

	# Hit stop scales with damage tier
	if enable_hit_stop:
		var stop_dur := 0.04
		if was_crit:
			stop_dur = 0.08
		if damage > 100.0:
			stop_dur = 0.12
		hit_stop(stop_dur)

	# Camera shake scales with damage
	if enable_camera_shake:
		var shake := 0.05
		if was_crit:
			shake = 0.12
		if damage > 100.0:
			shake = 0.18
		camera_shake(shake, 0.18)

func register_kill(_who: Node, position: Vector3) -> void:
	floating_text_request.emit("DEFEATED", position, Color(1, 0.4, 0.4), 1.6)
	hit_stop(0.18)
	camera_shake(0.22, 0.30)

func register_perfect_parry(position: Vector3) -> void:
	floating_text_request.emit("PERFECT", position, Color(0.6, 1.0, 0.8), 1.5)
	hit_stop(0.10)
	camera_shake(0.05, 0.12)

func register_stance_break(position: Vector3) -> void:
	floating_text_request.emit("STANCE BROKEN", position, Color(1, 0.3, 0.6), 1.6)
	hit_stop(0.20)
	camera_shake(0.30, 0.40)

# === Implementation primitives ===
func hit_stop(seconds: float) -> void:
	_hit_stop_remaining = max(_hit_stop_remaining, seconds)
	hit_stop_request.emit(seconds)

func _slomo_enabled() -> bool:
	var gs := get_node_or_null("/root/GameSettings")
	if gs == null:
		return false
	return float(gs.hit_stop) > 0.0

func camera_shake(strength: float, duration: float) -> void:
	if not _camera:
		return
	if _shake_remaining <= 0.0:
		_shake_origin = _camera.transform
	_shake_strength = max(_shake_strength, strength)
	_shake_remaining = max(_shake_remaining, duration)
	screen_shake_request.emit(strength, duration)
