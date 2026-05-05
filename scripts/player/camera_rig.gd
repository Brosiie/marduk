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
	rotation.y = yaw

	if Input.is_action_just_released("zoom_in"):
		distance = max(min_distance, distance - zoom_step)
	if Input.is_action_just_released("zoom_out"):
		distance = min(max_distance, distance + zoom_step)
	spring.spring_length = lerp(spring.spring_length, distance, 8.0 * delta)
