extends Node
class_name LockOn

# Tab is a TOGGLE: press to lock, press again to release. No state-aware
# overload, the key does the same thing every time. Cycling between enemies
# moves to Shift+Tab (with Ctrl+Tab as the backward cycle) so the toggle
# semantics on plain Tab stay clean. Middle-mouse also toggles.
# Bond's UX call: "locking on target should be a toggle button."
#
# Player rotation, camera, and abilities use current_target as their facing
# reference while locked. Releasing returns control to free-cam mode.

signal lock_acquired(target: Node3D)
signal lock_released

@export var max_lock_distance: float = 22.0
@export var fov_cone_degrees: float = 60.0
@export var camera_path: NodePath  # path to Camera3D
@export var owner_player: Node

var current_target: Node3D = null
var _camera: Camera3D

func _ready() -> void:
	if camera_path:
		_camera = get_node_or_null(camera_path)

func _input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_TAB:
			# Plain Tab = toggle. Shift+Tab = cycle forward through enemies.
			# Ctrl+Tab = cycle backward. The cycle commands ONLY work when a
			# target is already locked; otherwise they acquire (so the player
			# never gets a no-op from pressing a cycle modifier).
			if event.shift_pressed or event.ctrl_pressed:
				if current_target and is_instance_valid(current_target):
					cycle_target(-1 if event.ctrl_pressed else 1)
				else:
					acquire()
			else:
				toggle()
		elif event.keycode == KEY_ESCAPE and current_target:
			release()
	elif event is InputEventMouseButton and event.pressed:
		if event.button_index == MOUSE_BUTTON_MIDDLE:
			toggle()

func toggle() -> void:
	if current_target and is_instance_valid(current_target):
		release()
	else:
		acquire()

func acquire() -> void:
	var enemies := _candidates()
	if enemies.is_empty():
		return
	var best: Node3D = enemies[0]
	var best_score: float = -INF
	for e: Node3D in enemies:
		var score := _score_target(e)
		if score > best_score:
			best_score = score
			best = e
	current_target = best
	lock_acquired.emit(current_target)

func release() -> void:
	current_target = null
	lock_released.emit()

func cycle_target(direction: int) -> void:
	# direction = -1 (left) or +1 (right)
	var enemies := _candidates()
	if enemies.is_empty():
		return
	if not current_target:
		acquire()
		return
	var idx := enemies.find(current_target)
	if idx < 0:
		current_target = enemies[0]
	else:
		idx = (idx + direction + enemies.size()) % enemies.size()
		current_target = enemies[idx]
	lock_acquired.emit(current_target)

func _candidates() -> Array:
	var arr: Array = []
	if not owner_player:
		return arr
	var origin: Vector3 = owner_player.global_position
	var fwd: Vector3 = -_camera.global_transform.basis.z if _camera else -owner_player.global_transform.basis.z
	fwd.y = 0; fwd = fwd.normalized()
	var cone_cos := cos(deg_to_rad(fov_cone_degrees * 0.5))
	for n in get_tree().get_nodes_in_group("enemy"):
		if not (n is Node3D):
			continue
		var to_target: Vector3 = (n.global_position - origin)
		var dist := to_target.length()
		if dist > max_lock_distance:
			continue
		to_target.y = 0
		var dot: float = fwd.dot(to_target.normalized())
		if dot < cone_cos:
			continue
		arr.append(n)
	return arr

func _score_target(target: Node3D) -> float:
	if not owner_player:
		return 0.0
	var owner3d := owner_player as Node3D
	var dist: float = owner3d.global_position.distance_to(target.global_position)
	# Closer is better, also prefer ones near screen center
	var screen_score := 0.0
	if _camera:
		var sp: Vector2 = _camera.unproject_position(target.global_position)
		var center := Vector2(640, 360)  # assumes default viewport
		screen_score = -(sp.distance_to(center)) * 0.01
	return -dist + screen_score
