extends Control
class_name CompassBar

# Top-center horizontal compass strip. Shows N/E/S/W cardinals + tick
# marks at every 15° + dynamic markers for nearby zone-exit warp
# portals, lodestones, and active quest waypoints. Skyrim/Fallout
# style: the marker slides along the strip as the player rotates,
# so glancing at the compass tells you "the exit is over your right
# shoulder" without opening the map.
#
# Source of truth for player heading: player.MeshRoot.rotation.y
# (matches Minimap's source so the two never disagree).
#
# Width: 460 px. Visible heading range: ±60° from forward (so you can
# see anything in front of you without the compass being absurdly
# wide). Markers OUTSIDE that range get clamped to the edge with a
# small arrow indicator suggesting "rotate this way to find it."

const COMPASS_WIDTH: float = 460.0
const COMPASS_HEIGHT: float = 38.0
const VISIBLE_ANGLE_DEG: float = 120.0  # ±60° from forward
const REFRESH_INTERVAL: float = 0.05    # 20 Hz, smooth rotation

var _player: Node3D = null
var _player_mesh: Node3D = null
var _refresh_t: float = 0.0

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	# Anchor top-center, just under the standard top edge but above the
	# quest tracker.
	anchor_left = 0.5
	anchor_right = 0.5
	anchor_top = 0.0
	anchor_bottom = 0.0
	offset_left = -COMPASS_WIDTH / 2.0
	offset_right = COMPASS_WIDTH / 2.0
	offset_top = 18.0
	offset_bottom = 18.0 + COMPASS_HEIGHT
	custom_minimum_size = Vector2(COMPASS_WIDTH, COMPASS_HEIGHT)
	_resolve_player()

func _resolve_player() -> void:
	_player = get_tree().get_first_node_in_group("player") as Node3D
	if _player == null:
		get_tree().create_timer(0.2).timeout.connect(_resolve_player)
		return
	_player_mesh = _player.get_node_or_null("MeshRoot") as Node3D

func _process(delta: float) -> void:
	_refresh_t += delta
	if _refresh_t < REFRESH_INTERVAL:
		return
	_refresh_t = 0.0
	if _player == null or not is_instance_valid(_player):
		_resolve_player()
		return
	queue_redraw()

func _draw() -> void:
	# Background strip with gold filigree border
	var bg_rect := Rect2(Vector2.ZERO, size)
	draw_rect(bg_rect, Color(0.05, 0.04, 0.06, 0.75), true)
	draw_rect(bg_rect, Color(0.78, 0.62, 0.28, 0.85), false, 1.0)
	# Center notch (player heading indicator)
	var center_x: float = size.x / 2.0
	draw_line(Vector2(center_x, 0), Vector2(center_x, size.y),
		Color(1.0, 0.85, 0.30, 0.95), 2.0, true)
	# Player yaw: read from mesh.rotation.y so compass + minimap agree.
	# Inverted because we want "forward = up on compass" -> angles to
	# the LEFT of forward show on the LEFT of the compass.
	var player_yaw: float = 0.0
	if _player_mesh and is_instance_valid(_player_mesh):
		player_yaw = _player_mesh.rotation.y
	# Cardinals at world angles (N=0, E=PI/2 if +X is east, etc).
	# Godot uses +Z as "forward" by default; in this game player faces
	# +Z when yaw=0. So world axes:
	#   N = -Z (yaw = PI)
	#   S = +Z (yaw = 0)
	#   E = +X (yaw = -PI/2)
	#   W = -X (yaw = +PI/2)
	# We label them on the compass at their world-yaw positions, then
	# offset by player_yaw so they slide as the player turns.
	var cardinals := [
		{"label": "N", "yaw": PI,       "color": Color(1.0, 0.92, 0.55), "size": 18},
		{"label": "E", "yaw": -PI/2.0,  "color": Color(0.85, 0.78, 0.55), "size": 16},
		{"label": "S", "yaw": 0.0,      "color": Color(0.85, 0.78, 0.55), "size": 16},
		{"label": "W", "yaw": PI/2.0,   "color": Color(0.85, 0.78, 0.55), "size": 16},
	]
	for card in cardinals:
		var x: float = _yaw_to_x(card["yaw"], player_yaw)
		if x >= 0 and x <= size.x:
			# Tick mark above
			draw_line(Vector2(x, 0), Vector2(x, 6), card["color"], 1.5, true)
			# Cardinal letter
			_draw_text(Vector2(x, size.y * 0.55), card["label"], card["color"], int(card["size"]))
	# 15° tick marks for fine-grained heading read
	for deg in range(0, 360, 15):
		var rad: float = deg_to_rad(float(deg)) - PI  # rotate so 0° = north
		var x: float = _yaw_to_x(rad, player_yaw)
		if x >= 4 and x <= size.x - 4:
			# Skip if it's already painted as a cardinal
			var is_cardinal: bool = (deg % 90 == 0)
			if is_cardinal:
				continue
			draw_line(Vector2(x, 0), Vector2(x, 4), Color(0.55, 0.45, 0.25, 0.7), 1.0, true)
	# Dynamic markers: nearby warp portals + lodestones + quest waypoints.
	# Each is rendered as a colored chevron at its world-direction-on-compass.
	_draw_dynamic_markers(player_yaw)

func _yaw_to_x(target_yaw: float, player_yaw: float) -> float:
	# Convert (target_yaw - player_yaw) to a screen X. Negative = left,
	# positive = right. Wrap into [-PI, +PI] so a target directly behind
	# is far-left rather than going off-screen forever in one direction.
	var rel: float = target_yaw - player_yaw
	rel = wrapf(rel, -PI, PI)
	# Map [-VISIBLE/2, +VISIBLE/2] degrees to [0, COMPASS_WIDTH]
	var visible_rad: float = deg_to_rad(VISIBLE_ANGLE_DEG)
	var center_x: float = size.x / 2.0
	# rel: +ve = to the right of player's forward = right side of compass
	# Inverted because Godot screen X grows right but yaw is right-handed
	return center_x + (rel / (visible_rad / 2.0)) * (size.x / 2.0)

func _draw_dynamic_markers(player_yaw: float) -> void:
	if _player == null:
		return
	var origin: Vector3 = _player.global_position
	# Warp portals: gold up-arrow chevron with the destination label
	for portal in get_tree().get_nodes_in_group("warp_portal"):
		if not (portal is Node3D):
			continue
		var to_portal: Vector3 = (portal as Node3D).global_position - origin
		to_portal.y = 0
		if to_portal.length_squared() < 0.01:
			continue
		var portal_yaw: float = atan2(to_portal.x, to_portal.z)
		var x: float = _yaw_to_x(portal_yaw, player_yaw)
		# Edge-clamp markers if they're outside the visible range
		x = clamp(x, 6.0, size.x - 6.0)
		_draw_chevron(Vector2(x, size.y - 4), Color(0.95, 0.85, 0.30, 0.95), 6.0)
	# Lodestones: blue diamond
	for stone in get_tree().get_nodes_in_group("lodestone"):
		if not (stone is Node3D):
			continue
		var to_stone: Vector3 = (stone as Node3D).global_position - origin
		to_stone.y = 0
		if to_stone.length_squared() < 0.01 or to_stone.length() > 80.0:
			continue  # ignore far-away stones to avoid clutter
		var stone_yaw: float = atan2(to_stone.x, to_stone.z)
		var x: float = _yaw_to_x(stone_yaw, player_yaw)
		x = clamp(x, 6.0, size.x - 6.0)
		_draw_diamond(Vector2(x, size.y - 4), Color(0.55, 0.78, 1.0, 0.95), 4.0)
	# Quest objective waypoints (kill targets in scan range)
	# Reuse the same kill-target lookup the minimap uses so the two
	# UIs stay consistent. Falls back to the player's QuestLog walk
	# if the helper isn't available.
	var quest_targets: Dictionary = _collect_quest_kill_targets()
	if not quest_targets.is_empty():
		for n in get_tree().get_nodes_in_group("enemy"):
			if not (n is Node3D):
				continue
			var to_target: Vector3 = (n as Node3D).global_position - origin
			to_target.y = 0
			if to_target.length() > 60.0:
				continue
			# Only flag if this enemy is a quest target
			var is_target: bool = false
			if "boss_id" in n and (n.get("boss_id") in quest_targets):
				is_target = true
			elif "mob_id" in n and (n.get("mob_id") in quest_targets):
				is_target = true
			if not is_target:
				continue
			var target_yaw: float = atan2(to_target.x, to_target.z)
			var x: float = _yaw_to_x(target_yaw, player_yaw)
			x = clamp(x, 6.0, size.x - 6.0)
			# Pulsing gold ring for quest targets, matches minimap halo
			var pulse: float = 0.65 + 0.30 * sin(Time.get_ticks_msec() / 200.0)
			draw_arc(Vector2(x, size.y - 6), 5.0, 0.0, TAU, 16,
				Color(1.0, 0.85, 0.30, pulse), 1.6, true)

func _collect_quest_kill_targets() -> Dictionary:
	# Mirror Minimap._collect_quest_kill_targets — lift to a shared helper
	# later if a third UI surface needs the same data.
	var out: Dictionary = {}
	if _player == null:
		return out
	var qlog: Node = _player.get_node_or_null("QuestLog")
	if qlog == null:
		return out
	var active_dict = qlog.get("active") if "active" in qlog else null
	if not (active_dict is Dictionary):
		return out
	for aq in (active_dict as Dictionary).values():
		var state_val = aq.get("state") if "state" in aq else 2
		if int(state_val) != 2:
			continue
		var objs = aq.get("objectives") if "objectives" in aq else []
		for obj in (objs as Array):
			if obj == null:
				continue
			var kind: StringName = StringName(obj.get("kind") if "kind" in obj else &"")
			if kind != &"kill":
				continue
			if obj.has_method("is_complete") and obj.is_complete():
				continue
			var tid: StringName = StringName(obj.get("target_id") if "target_id" in obj else &"")
			if tid != &"":
				out[tid] = true
	return out

# Tiny helper to draw a chevron (filled triangle pointing up) at `pos`.
func _draw_chevron(pos: Vector2, color: Color, half: float) -> void:
	var pts := PackedVector2Array([
		pos + Vector2(0, -half),
		pos + Vector2(half, half * 0.6),
		pos + Vector2(-half, half * 0.6),
	])
	draw_colored_polygon(pts, color)

func _draw_diamond(pos: Vector2, color: Color, half: float) -> void:
	var pts := PackedVector2Array([
		pos + Vector2(0, -half),
		pos + Vector2(half, 0),
		pos + Vector2(0, half),
		pos + Vector2(-half, 0),
	])
	draw_colored_polygon(pts, color)

# Godot 4's Control._draw doesn't have draw_text; use draw_string with the
# default ThemeDB font.
func _draw_text(pos: Vector2, text: String, color: Color, font_size: int) -> void:
	var font := ThemeDB.fallback_font
	if font == null:
		return
	# Center horizontally on `pos.x`, baseline at pos.y
	var text_size: Vector2 = font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size)
	draw_string(font, Vector2(pos.x - text_size.x / 2.0, pos.y + font_size * 0.35),
		text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, color)
