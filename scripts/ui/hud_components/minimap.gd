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

	# Yaw offset rotates the world so the player's FORWARD always points
	# UP on the minimap (Skyrim / WoW convention). Source of truth is the
	# player's mesh.rotation.y, which Player._apply_horizontal sets to
	# atan2(input_dir.x, input_dir.z) every frame. Falling back to
	# camera_rig yaw worked for the old camera-locked rig, but in the
	# free-look isometric build the camera and player can desync, and
	# Bond reported the minimap not following player facing. Mesh-yaw
	# fixes that without coupling the minimap to the camera.
	var yaw_offset: float = 0.0
	var player_mesh: Node3D = player.get_node_or_null("MeshRoot") if player else null
	if player_mesh == null and player and "mesh" in player:
		player_mesh = player.get("mesh") as Node3D
	if player_mesh:
		yaw_offset = player_mesh.rotation.y
	elif camera_rig:
		# Fallback: pre-mesh-spawn frames (mesh hasn't loaded yet) -> use
		# camera so the dots aren't wildly mis-rotated for one frame.
		yaw_offset = camera_rig.rotation.y

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

	# Build the set of incomplete-objective target_ids so quest enemies can
	# be highlighted in gold below. Walks every active quest the player has,
	# inflating "kill <target_id> <count>" into a quick lookup. Reach-zone
	# and collect objectives are skipped here because they don't map to a
	# minimap-visible enemy node.
	var quest_targets: Dictionary = _collect_quest_kill_targets()

	# Draw mobs (enemies)
	for n in get_tree().get_nodes_in_group("enemy"):
		if not (n is Node3D):
			continue
		var d: float = player.global_position.distance_to(n.global_position)
		if d > scan_radius_world:
			continue
		var p: Vector2 = to_minimap.call(n.global_position)
		var color := Color(0.95, 0.25, 0.25)
		var is_quest_target: bool = _is_quest_target(n, quest_targets)
		if n is BossBase:
			color = Color(1.0, 0.5, 0.0)
			draw_circle(p, 5.0, color)
		else:
			draw_circle(p, 3.0, color)
		# Gold halo on top so the quest target is unmistakable. Drawn AFTER
		# the dot so the ring sits on top of the colored fill. Slightly
		# pulsing alpha (cheap sin) for "look at me" without the cost of a
		# tween per marker.
		if is_quest_target:
			var pulse: float = 0.55 + 0.35 * sin(Time.get_ticks_msec() / 220.0)
			var ring_color := Color(1.0, 0.85, 0.30, pulse)
			var ring_radius: float = 7.0 if n is BossBase else 5.5
			draw_arc(p, ring_radius, 0.0, TAU, 24, ring_color, 1.6, true)

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

# ────────────────── Quest objective markers ──────────────────
#
# Walks the player's QuestLog and returns the set of mob_id / boss_id
# values that still need to be killed for an active quest. Used by the
# minimap to halo enemies that match. Empty dict if QuestLog is missing
# or no active quests have remaining kill objectives.
#
# Stored as Dictionary<StringName, true> instead of Array because dict
# lookup is O(1) and we test membership once per visible enemy each
# minimap refresh.
func _collect_quest_kill_targets() -> Dictionary:
	var out: Dictionary = {}
	if not player or not is_instance_valid(player):
		return out
	var qlog: Node = player.get_node_or_null("QuestLog")
	if qlog == null:
		return out
	var active_dict = qlog.get("active") if "active" in qlog else null
	if not (active_dict is Dictionary):
		return out
	for aq in (active_dict as Dictionary).values():
		# ActiveQuest.state ACTIVE == 2 in Quest.State enum but we read by
		# name to stay decoupled from the int value.
		var state_val = aq.get("state") if "state" in aq else 2
		if int(state_val) != 2:  # Quest.State.ACTIVE
			continue
		var objs = aq.get("objectives") if "objectives" in aq else []
		for obj in (objs as Array):
			if obj == null:
				continue
			# Only kill-objectives map to a visible mob/boss node. Talk-to,
			# collect, and reach-zone objectives are tracked elsewhere.
			var kind: StringName = StringName(obj.get("kind") if "kind" in obj else &"")
			if kind != &"kill":
				continue
			# Skip already-completed sub-objectives so the marker drops off
			# the moment the kill count hits required_count.
			if obj.has_method("is_complete") and obj.is_complete():
				continue
			var tid: StringName = StringName(obj.get("target_id") if "target_id" in obj else &"")
			if tid != &"":
				out[tid] = true
	return out

func _is_quest_target(n: Node, targets: Dictionary) -> bool:
	if targets.is_empty():
		return false
	# BossBase has boss_id; EnemyBase has mob_id. Either match counts.
	if "boss_id" in n:
		var bid = n.get("boss_id")
		if bid != null and StringName(bid) in targets:
			return true
	if "mob_id" in n:
		var mid = n.get("mob_id")
		if mid != null and StringName(mid) in targets:
			return true
	return false
