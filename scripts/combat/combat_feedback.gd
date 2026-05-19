extends Node

# Visual / haptic / audio response to combat events.
# Hit-stop frames, camera shake, floating damage numbers, screen flash on crit.
#
# Registered as the CombatFeedback autoload in project.godot. On _ready it
# subscribes to CombatBus signals (hit_landed, kill_registered, perfect_parry,
# stance_broken) and routes them to the register_* handlers below. Bond
# experience: every hit now nudges the camera, crits stop time briefly,
# kills flash "DEFEATED" and shake harder.
#
# class_name removed because autoload + class_name with the same identifier
# shadows the singleton lookup in Godot 4.

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
	# Subscribe to CombatBus so every hit/kill/parry/stance-break routes
	# through our register_* methods. CombatBus is loaded earlier in the
	# autoload chain (per project.godot order) so it's always present
	# by the time we _ready.
	var bus: Node = get_node_or_null("/root/CombatBus")
	if bus:
		if bus.has_signal("hit_landed") and not bus.hit_landed.is_connected(_on_hit_landed):
			bus.hit_landed.connect(_on_hit_landed)
		if bus.has_signal("kill_registered") and not bus.kill_registered.is_connected(_on_kill_registered):
			bus.kill_registered.connect(_on_kill_registered)
		if bus.has_signal("perfect_parry") and not bus.perfect_parry.is_connected(register_perfect_parry):
			bus.perfect_parry.connect(register_perfect_parry)
		if bus.has_signal("stance_broken") and not bus.stance_broken.is_connected(register_stance_break):
			bus.stance_broken.connect(register_stance_break)
	# Camera path support stays for the rare case where this is also
	# instanced as a scene node with an explicit @export.
	if camera_path:
		_camera = get_node_or_null(camera_path)

# Translate CombatBus.hit_landed (which carries the typed Result + Ability)
# into register_hit's flat args (damage, position, crit). The bus doesn't
# expose a perfect-window flag yet; register_hit's was_perfect path is
# reached only by direct calls (e.g., a parry counter would invoke this
# class manually with was_perfect=true).
func _on_hit_landed(target: Node, result, _ability) -> void:
	if target == null or not (target is Node3D):
		return
	var pos: Vector3 = (target as Node3D).global_position + Vector3(0, 1.2, 0)
	register_hit(float(result.damage), pos, bool(result.crit), false)

func _on_kill_registered(target: Node, killer: Node) -> void:
	if target == null or not (target is Node3D):
		return
	register_kill(killer, (target as Node3D).global_position + Vector3(0, 1.4, 0))

# Late-resolve the camera from the camera_rig group if @export wasn't set.
# Allows the autoload to find whatever camera the current scene installed
# without per-scene wiring. Cached after first hit.
func _ensure_camera() -> void:
	if _camera and is_instance_valid(_camera):
		return
	var rig: Node = get_tree().get_first_node_in_group("camera_rig") if get_tree() else null
	if rig == null:
		return
	# Common pattern: CameraRig has a SpringArm3D child with a Camera3D leaf.
	for cam in rig.get_children():
		if cam is Camera3D:
			_camera = cam as Camera3D
			return
		# Recurse one level for SpringArm3D -> Camera3D
		for sub in cam.get_children():
			if sub is Camera3D:
				_camera = sub as Camera3D
				return

func _process(delta: float) -> void:
	# Hit stop: pause physics briefly for impact emphasis. Gated on the
	# GameSettings.hit_stop slider, default 0.0 means we never set
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
	_ensure_camera()  # autoload path: resolve camera from active scene
	if not _camera:
		return
	# Respect the accessibility slider: GameSettings.screen_shake scales
	# [0..1]. Setting it to 0 fully disables shake while leaving hit-stop
	# + floating numbers intact for players sensitive to motion.
	var gs: Node = get_node_or_null("/root/GameSettings")
	var scale: float = 1.0
	if gs and "screen_shake" in gs:
		scale = float(gs.screen_shake)
	if scale <= 0.0:
		return
	if _shake_remaining <= 0.0:
		_shake_origin = _camera.transform
	_shake_strength = max(_shake_strength, strength * scale)
	_shake_remaining = max(_shake_remaining, duration)
	screen_shake_request.emit(strength, duration)
