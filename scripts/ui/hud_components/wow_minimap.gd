extends Control
class_name WowMinimap

# Top-right WoW-style circular minimap. Player is always centered; the
# environment + blips rotate with the camera so "up" on the minimap is
# always "in front of the player". Blips:
#   red    = hostile enemy
#   gold   = boss
#   green  = friendly NPC
#   blue   = lodestone
#   purple = item pickup
#   cyan   = warp portal
#
# Uses _draw to render so it stays cheap; only refreshes when the player
# or any tagged entity moves significantly.

const MAP_SIZE: int = 220
const MAP_RADIUS: float = 110.0
const VIEW_RANGE: float = 60.0  # world units shown across the diameter
const PLAYER_DOT_RADIUS: float = 4.0
const BLIP_RADIUS: float = 3.0

var _player: Node = null
var _camera_basis: Basis = Basis.IDENTITY

func _ready() -> void:
	custom_minimum_size = Vector2(MAP_SIZE, MAP_SIZE)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	anchor_left = 1.0
	anchor_top = 0.0
	anchor_right = 1.0
	anchor_bottom = 0.0
	offset_left = -(MAP_SIZE + 18)
	offset_top = 18
	offset_right = -18
	offset_bottom = 18 + MAP_SIZE
	_player = get_tree().get_first_node_in_group("player")
	set_process(true)

func _process(_delta: float) -> void:
	if _player == null:
		_player = get_tree().get_first_node_in_group("player")
	# Pull camera basis so map "up" tracks the camera yaw
	var cam: Camera3D = get_viewport().get_camera_3d()
	if cam:
		_camera_basis = cam.global_transform.basis
	queue_redraw()

func _draw() -> void:
	# Background ring
	draw_circle(Vector2(MAP_SIZE * 0.5, MAP_SIZE * 0.5), MAP_RADIUS, Color(0.04, 0.04, 0.06, 0.92))
	draw_arc(Vector2(MAP_SIZE * 0.5, MAP_SIZE * 0.5), MAP_RADIUS - 1.0, 0.0, TAU, 64, Color(0.95, 0.85, 0.55), 2.0)
	# Compass tick at top
	var center := Vector2(MAP_SIZE * 0.5, MAP_SIZE * 0.5)
	draw_string(ThemeDB.fallback_font, center + Vector2(-4, -MAP_RADIUS + 4), "N", HORIZONTAL_ALIGNMENT_LEFT, -1, 12, Color(0.95, 0.85, 0.55))

	if _player == null or not is_instance_valid(_player):
		return
	var player_pos: Vector3 = _player.global_position
	# Camera-relative yaw so map rotates with the camera
	var cam_fwd: Vector3 = -_camera_basis.z
	cam_fwd.y = 0
	if cam_fwd.length_squared() < 0.001:
		cam_fwd = Vector3.FORWARD
	cam_fwd = cam_fwd.normalized()
	var yaw: float = atan2(cam_fwd.x, cam_fwd.z)

	# Player dot
	draw_circle(center, PLAYER_DOT_RADIUS, Color(0.95, 0.95, 0.95))

	# Iterate tagged entities and place blips
	_blip_group(center, player_pos, yaw, "enemy", Color(0.95, 0.30, 0.25))
	_blip_group(center, player_pos, yaw, "boss",  Color(1.00, 0.65, 0.10), 5.0)
	_blip_group(center, player_pos, yaw, "npc",   Color(0.40, 0.95, 0.50))
	_blip_group(center, player_pos, yaw, "lodestone", Color(0.45, 0.65, 1.00))
	_blip_group(center, player_pos, yaw, "item_pickup", Color(0.75, 0.30, 0.95))
	_blip_group(center, player_pos, yaw, "warp_portal", Color(0.30, 0.95, 1.00))

func _blip_group(center: Vector2, player_pos: Vector3, yaw: float, group_name: String, color: Color, radius: float = 0.0) -> void:
	var nodes := get_tree().get_nodes_in_group(group_name)
	var r: float = radius if radius > 0.0 else BLIP_RADIUS
	for n in nodes:
		if not is_instance_valid(n):
			continue
		if not (n is Node3D):
			continue
		var rel: Vector3 = n.global_position - player_pos
		# Only show within view range
		if rel.length() > VIEW_RANGE:
			continue
		# Rotate by negative yaw so map's "up" follows camera forward
		var x_world: float = rel.x
		var z_world: float = rel.z
		var x_rot: float = x_world * cos(-yaw) - z_world * sin(-yaw)
		var z_rot: float = x_world * sin(-yaw) + z_world * cos(-yaw)
		# Scale into pixels: VIEW_RANGE world units -> diameter pixels
		var px: float = (x_rot / VIEW_RANGE) * MAP_RADIUS
		var py: float = (z_rot / VIEW_RANGE) * MAP_RADIUS
		var p := center + Vector2(px, py)
		# Clip outside the circle
		if p.distance_to(center) > MAP_RADIUS - 2.0:
			continue
		draw_circle(p, r, color)
