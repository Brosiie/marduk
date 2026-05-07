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
	# Lock-on: smoothly auto-yaw so the lock target sits opposite the
	# camera (player between camera and target = standard soulslike
	# framing). Manual rotation still applies on top so the player can
	# nudge the angle while locked.
	if lock_target and is_instance_valid(lock_target) and target:
		var to_target: Vector3 = lock_target.global_position - target.global_position
		to_target.y = 0
		if to_target.length_squared() > 0.001:
			# Camera should sit on the OPPOSITE side of player from
			# target. Desired yaw = atan2 of -to_target so camera looks
			# from behind player toward target.
			var desired_yaw: float = atan2(-to_target.x, -to_target.z)
			yaw = lerp_angle(yaw, desired_yaw, LOCK_YAW_SPEED * delta)
	rotation.y = yaw

	if Input.is_action_just_released("zoom_in"):
		distance = max(min_distance, distance - zoom_step)
	if Input.is_action_just_released("zoom_out"):
		distance = min(max_distance, distance + zoom_step)
	spring.spring_length = lerp(spring.spring_length, distance, 8.0 * delta)
