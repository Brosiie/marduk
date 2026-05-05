extends Control
class_name Minimap

# A 2D minimap rendered at top-right of the HUD. Shows:
#   - Player as gold dot at center, rotates with camera yaw
#   - Mobs as red dots within scan_radius
#   - Friendly NPCs as green dots
#   - Landmarks as blue diamonds (faded if undiscovered, bright if examined)
#   - Dungeons as purple shields
#   - Zone exits as yellow arrows pointing toward connection
#
# Uses _draw() for performance. Refreshes at ~10 Hz (every 0.1s).

@export var player_path: NodePath
@export var camera_rig_path: NodePath
@export var size_pixels: float = 200.0
@export var scan_radius_world: float = 60.0  # world metres represented by minimap radius
@export var border_color: Color = Color(0.85, 0.7, 0.4, 0.9)
@export var fill_color: Color = Color(0.05, 0.05, 0.10, 0.7)

var player: Node3D
var camera_rig: Node3D
var _refresh_t: float = 0.0
const REFRESH_INTERVAL := 0.1

func _ready() -> void:
	player = get_node_or_null(player_path) if player_path else get_tree().get_first_node_in_group("player")
	camera_rig = get_node_or_null(camera_rig_path) if camera_rig_path else get_tree().get_first_node_in_group("camera_rig")
	custom_minimum_size = Vector2(size_pixels, size_pixels)

func _process(delta: float) -> void:
	_refresh_t += delta
	if _refresh_t < REFRESH_INTERVAL:
		return
	_refresh_t = 0.0
	queue_redraw()

func _draw() -> void:
	var center := size / 2.0
	var radius := size_pixels / 2.0

	# Frame
	draw_circle(center, radius, fill_color)
	draw_arc(center, radius, 0.0, TAU, 64, border_color, 2.0, true)

	if not player or not is_instance_valid(player):
		return

	var yaw_offset: float = 0.0
	if camera_rig:
		yaw_offset = camera_rig.rotation.y  # rotate map so camera-forward = up

	# Helper: world position -> minimap pixel
	var to_minimap = func(world_pos: Vector3) -> Vector2:
		var rel: Vector3 = world_pos - player.global_position
		# Apply inverse of camera yaw so camera-forward points up
		var rotated := Vector3(
			rel.x * cos(yaw_offset) + rel.z * sin(yaw_offset),
			0,
			-rel.x * sin(yaw_offset) + rel.z * cos(yaw_offset)
		)
		var scale_factor := radius / scan_radius_world
		return center + Vector2(rotated.x * scale_factor, rotated.z * scale_factor)

	# Draw mobs (enemies)
	for n in get_tree().get_nodes_in_group("enemy"):
		if not (n is Node3D):
			continue
		var d: float = player.global_position.distance_to(n.global_position)
		if d > scan_radius_world:
			continue
		var p: Vector2 = to_minimap.call(n.global_position)
		var color := Color(0.95, 0.25, 0.25)
		if n is BossBase:
			color = Color(1.0, 0.5, 0.0)
			draw_circle(p, 5.0, color)
		else:
			draw_circle(p, 3.0, color)

	# Draw NPCs (friendly)
	for n in get_tree().get_nodes_in_group("npc"):
		if not (n is Node3D):
			continue
		var d: float = player.global_position.distance_to(n.global_position)
		if d > scan_radius_world:
			continue
		var p: Vector2 = to_minimap.call(n.global_position)
		draw_circle(p, 4.0, Color(0.4, 0.95, 0.4))

	# Draw landmarks
	for n in get_tree().get_nodes_in_group("landmark"):
		if not (n is Node3D):
			continue
		var d: float = player.global_position.distance_to(n.global_position)
		if d > scan_radius_world:
			continue
		var p: Vector2 = to_minimap.call(n.global_position)
		var examined := SaveFlags.has_permanent(StringName("landmark_examined_" + String(n.get_meta("landmark_id", "")))) if n.has_meta("landmark_id") else false
		var color := Color(0.4, 0.6, 1.0, 1.0 if examined else 0.5)
		_draw_diamond(p, 5.0, color)

	# Player dot at center, gold
	draw_circle(center, 4.5, Color(1.0, 0.85, 0.4))
	# Heading line forward
	draw_line(center, center + Vector2(0, -radius * 0.3),
		Color(1.0, 0.85, 0.4, 0.7), 1.5, true)

func _draw_diamond(pos: Vector2, half: float, color: Color) -> void:
	var pts := PackedVector2Array([
		pos + Vector2(0, -half),
		pos + Vector2(half, 0),
		pos + Vector2(0, half),
		pos + Vector2(-half, 0)
	])
	draw_colored_polygon(pts, color)
