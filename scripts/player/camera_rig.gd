extends Node3D
class_name CameraRig

# Diablo-style isometric-ish camera. Pitched 45deg, free yaw with Q/E,
# zoom on scrollwheel. SpringArm pulls in when geometry blocks the shot.

@export var follow_target_path: NodePath
@export var follow_height: float = 1.4
@export var follow_smooth: float = 10.0
@export var pitch_deg: float = 45.0
@export var rotate_speed: float = 2.4
@export var zoom_step: float = 1.0
@export var min_distance: float = 4.0
@export var max_distance: float = 18.0
@export var initial_distance: float = 11.0

@onready var spring: SpringArm3D = $SpringArm3D
@onready var camera: Camera3D = $SpringArm3D/Camera3D

var target: Node3D
var yaw: float = 0.0
var distance: float = 11.0

# Lock-on target. While set, the rig auto-yaws to keep the lock_target
# centered behind the player so the player + lock_target always read
# in-frame. Set/cleared by Player on Tab press.
var lock_target: Node3D = null
const LOCK_YAW_SPEED: float = 4.0  # rad/sec
# Lock-on snap: when the player first locks onto a target, accelerate
# the camera yaw correction for the first 0.5s so the framing snaps
# in fast. After that the lerp settles to LOCK_YAW_SPEED for subtle
# tracking. Without the snap-in the lock-on feels slow/floaty.
const LOCK_SNAP_SPEED: float = 16.0  # rad/sec during initial snap
const LOCK_SNAP_DURATION: float = 0.45  # seconds of fast snap
var _lock_acquired_at: float = 0.0
var _last_lock_target: Node3D = null
# Interior tightness: when the camera senses it's inside a building
# (raycast hits a ceiling within 6m), pull spring_length toward this
# value so the player isn't fighting clipping walls. Released back to
# the user's chosen distance once outside.
const INTERIOR_DISTANCE: float = 5.5
var _interior_blend: float = 0.0  # 0..1, lerps toward 1 when inside
# Boss-windup zoom: when the locked boss enters a windup state, pull
# the spring 30% closer for the windup duration. Reads as the camera
# 'leaning in' for the danger moment. Auto-releases when windup ends.
const WINDUP_ZOOM_FACTOR: float = 0.70  # 0.70 = 30% closer than current
var _windup_zoom_until: float = 0.0
var _windup_locked_boss: Node = null

# Mouse drag rotate: hold RMB or MMB and move mouse to spin the camera.
# Standard ARPG control. Sensitivity in radians per pixel.
const MOUSE_YAW_SENSITIVITY: float = 0.005
var _mouse_dragging: bool = false

func _ready() -> void:
	add_to_group("camera_rig")
	if follow_target_path:
		target = get_node_or_null(follow_target_path)
	distance = initial_distance
	spring.spring_length = distance
	spring.rotation_degrees.x = -pitch_deg

func _process(delta: float) -> void:
	if target:
		var goal := target.global_position + Vector3.UP * follow_height
		global_position = global_position.lerp(goal, follow_smooth * delta)

	if Input.is_action_pressed("cam_rotate_left"):
		yaw += rotate_speed * delta
	if Input.is_action_pressed("cam_rotate_right"):
		yaw -= rotate_speed * delta
	# Mouse drag: while RMB or MMB is held, mouse motion spins yaw.
	# Implemented in _input below; here we just continue applying yaw.
	# Lock-on: smoothly auto-yaw so the lock target sits opposite the
	# camera (player between camera and target = standard soulslike
	# framing). Manual rotation still applies on top so the player can
	# nudge the angle while locked.
	if lock_target and is_instance_valid(lock_target) and target:
		# Detect lock-on acquisition (fresh target) so we can apply
		# the fast snap-in for ~0.45s before settling into normal
		# tracking speed.
		if lock_target != _last_lock_target:
			_lock_acquired_at = Time.get_ticks_msec() / 1000.0
			_last_lock_target = lock_target
		var time_locked: float = (Time.get_ticks_msec() / 1000.0) - _lock_acquired_at
		var snap_blend: float = clamp(1.0 - time_locked / LOCK_SNAP_DURATION, 0.0, 1.0)
		var yaw_speed: float = lerp(LOCK_YAW_SPEED, LOCK_SNAP_SPEED, snap_blend)
		var to_target: Vector3 = lock_target.global_position - target.global_position
		to_target.y = 0
		if to_target.length_squared() > 0.001:
			# Camera should sit on the OPPOSITE side of player from
			# target. Desired yaw = atan2 of -to_target so camera looks
			# from behind player toward target.
			var desired_yaw: float = atan2(-to_target.x, -to_target.z)
			yaw = lerp_angle(yaw, desired_yaw, yaw_speed * delta)
	else:
		_last_lock_target = null
	rotation.y = yaw

	if Input.is_action_just_released("zoom_in"):
		distance = max(min_distance, distance - zoom_step)
	if Input.is_action_just_released("zoom_out"):
		distance = min(max_distance, distance + zoom_step)
	# Interior tightness: raycast straight up from the player's head.
	# If we hit a ceiling within 6m, blend the spring toward
	# INTERIOR_DISTANCE so the camera doesn't poke through the dojo
	# roof. Smooth blend (3s) so transitions don't feel jerky.
	_update_interior_blend(delta)
	var goal_distance: float = lerp(distance, INTERIOR_DISTANCE, _interior_blend)
	# Hook the locked boss's windup signals lazily, we can't connect
	# in _ready because the boss may not exist yet.
	_attach_boss_windup_signals()
	# During boss windup, tighten the spring further. Multiplicative
	# on top of interior tightness so dojo + boss windup compound.
	var now: float = Time.get_ticks_msec() / 1000.0
	if now < _windup_zoom_until:
		goal_distance *= WINDUP_ZOOM_FACTOR
	spring.spring_length = lerp(spring.spring_length, goal_distance, 6.0 * delta)

func _attach_boss_windup_signals() -> void:
	if _windup_locked_boss == lock_target or lock_target == null:
		return
	# Disconnect from previous boss
	if _windup_locked_boss and is_instance_valid(_windup_locked_boss):
		var cb := Callable(self, "_on_boss_windup_started")
		if _windup_locked_boss.has_signal("windup_started") and _windup_locked_boss.windup_started.is_connected(cb):
			_windup_locked_boss.windup_started.disconnect(cb)
	# Connect to new boss if it has the windup signal
	if lock_target and lock_target.has_signal("windup_started"):
		var cb2 := Callable(self, "_on_boss_windup_started")
		if not lock_target.windup_started.is_connected(cb2):
			lock_target.windup_started.connect(cb2)
		_windup_locked_boss = lock_target

func _on_boss_windup_started(_pattern_id: StringName, windup_seconds: float) -> void:
	_windup_zoom_until = (Time.get_ticks_msec() / 1000.0) + windup_seconds + 0.05

# Raycast up from the player's head; if we're under a ceiling within
# 6m, fade _interior_blend toward 1.0 over ~0.6s. Released back to
# 0.0 when we step out into open sky.
func _update_interior_blend(delta: float) -> void:
	if target == null:
		return
	var space := target.get_world_3d().direct_space_state
	var origin: Vector3 = target.global_position + Vector3(0, 1.6, 0)
	var query := PhysicsRayQueryParameters3D.create(origin, origin + Vector3(0, 6.0, 0))
	query.collision_mask = 1
	query.exclude = [target.get_rid()]
	var hit := space.intersect_ray(query)
	var should_be_interior: bool = not hit.is_empty()
	var target_blend: float = 1.0 if should_be_interior else 0.0
	_interior_blend = move_toward(_interior_blend, target_blend, delta * 1.6)

# Mouse drag camera. RMB or MMB held = rotate yaw with mouse motion.
# Standard ARPG control alongside Q/E and arrow-key rotation.
func _input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		var mb := event as InputEventMouseButton
		if mb.button_index == MOUSE_BUTTON_RIGHT or mb.button_index == MOUSE_BUTTON_MIDDLE:
			_mouse_dragging = mb.pressed
	elif event is InputEventMouseMotion and _mouse_dragging:
		var mm := event as InputEventMouseMotion
		yaw -= mm.relative.x * MOUSE_YAW_SENSITIVITY
