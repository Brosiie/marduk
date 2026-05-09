extends Control
class_name WowMinimap

# Top-right WoW-style circular minimap. Player arrow stays centered;
# the world rotates so "up" on the minimap is always "in front of the
# player" (matches Cataclysm onward retail behavior).
#
# Polish layers, back-to-front:
#   1. Drop-shadow disc        (offset down-right, blur via alpha)
#   2. Outer gold filigree ring + 4 cardinal tick studs
#   3. Inner dark recessed bg with a faint radial gradient
#   4. Faint compass cross lines (N-S / E-W) at low alpha
#   5. Compass cardinal labels (N E S W)
#   6. Blips, sorted by importance, boss pulse last so it's on top
#   7. Player arrow (not dot, direction matters)
#   8. View-range crisp inner ring (so blips at the edge feel 'out of range')
#
# Blip vocabulary:
#   crimson   = hostile mob
#   gold      = boss (animated pulse, larger)
#   green     = friendly NPC
#   blue      = lodestone (diamond shape)
#   violet    = item pickup
#   cyan      = warp portal (star shape)

const MAP_SIZE: int = 240
const MAP_RADIUS: float = 116.0
const VIEW_RANGE: float = 60.0  # world units shown across the diameter
const PLAYER_ARROW_LEN: float = 8.0
const BLIP_RADIUS: float = 3.5

const FRAME_GOLD: Color = Color(0.78, 0.62, 0.28, 1.0)
const FRAME_GOLD_BRIGHT: Color = Color(1.00, 0.86, 0.45, 1.0)
const FRAME_INNER_DARK: Color = Color(0.05, 0.04, 0.06, 0.96)

var _player: Node = null
var _camera_basis: Basis = Basis.IDENTITY
var _t: float = 0.0  # for boss-blip pulse

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

func _process(delta: float) -> void:
	_t += delta
	if _player == null:
		_player = get_tree().get_first_node_in_group("player")
	# Pull camera basis so map "up" tracks the camera yaw
	var cam: Camera3D = get_viewport().get_camera_3d()
	if cam:
		_camera_basis = cam.global_transform.basis
	queue_redraw()

func _draw() -> void:
	var center := Vector2(MAP_SIZE * 0.5, MAP_SIZE * 0.5)
	# 1. Drop shadow
	draw_circle(center + Vector2(0, 4), MAP_RADIUS + 2, Color(0, 0, 0, 0.55))
	# 2. Outer gold filigree ring (3-layer for the polished bevel)
	draw_circle(center, MAP_RADIUS + 2, FRAME_GOLD.darkened(0.4))
	draw_arc(center, MAP_RADIUS + 1.5, 0.0, TAU, 96, FRAME_GOLD, 3.0)
	draw_arc(center, MAP_RADIUS + 0.5, 0.0, TAU, 96, FRAME_GOLD_BRIGHT, 1.0)
	# Cardinal stud markers, small gold pips at N/E/S/W on the outer ring.
	for i in 4:
		var a: float = float(i) * TAU / 4.0 - PI * 0.5  # start at top
		var pip: Vector2 = center + Vector2(cos(a), sin(a)) * (MAP_RADIUS + 1.5)
		draw_circle(pip, 4.0, FRAME_GOLD_BRIGHT)
		draw_circle(pip, 2.5, FRAME_GOLD.darkened(0.2))
	# 3. Inner dark recessed bg
	draw_circle(center, MAP_RADIUS - 1.5, FRAME_INNER_DARK)
	# Subtle radial gradient via concentric rings (cheap; no shader needed)
	for ring in 3:
		var rr: float = MAP_RADIUS - 1.5 - float(ring) * 18.0
		if rr > 0:
			var alpha: float = 0.04 + float(ring) * 0.02
			draw_arc(center, rr, 0.0, TAU, 64, Color(FRAME_GOLD.r, FRAME_GOLD.g, FRAME_GOLD.b, alpha), 1.5)
	# 4. Faint compass cross lines (N-S / E-W), readability aid
	var cross_color: Color = Color(FRAME_GOLD.r, FRAME_GOLD.g, FRAME_GOLD.b, 0.10)
	draw_line(center - Vector2(0, MAP_RADIUS - 4), center + Vector2(0, MAP_RADIUS - 4), cross_color, 1.0)
	draw_line(center - Vector2(MAP_RADIUS - 4, 0), center + Vector2(MAP_RADIUS - 4, 0), cross_color, 1.0)
	# 5. Compass labels, 4 cardinals with outline so they read on
	# the dark bg AND any blips behind them.
	var font: Font = ThemeDB.fallback_font
	var label_color: Color = FRAME_GOLD_BRIGHT
	var labels := [
		["N", Vector2(0, -MAP_RADIUS + 12)],
		["E", Vector2(MAP_RADIUS - 14, 4)],
		["S", Vector2(0, MAP_RADIUS - 6)],
		["W", Vector2(-MAP_RADIUS + 6, 4)],
	]
	for entry in labels:
		var pos: Vector2 = center + (entry[1] as Vector2) - Vector2(4, 0)
		draw_string_outline(font, pos, str(entry[0]), HORIZONTAL_ALIGNMENT_LEFT, -1, 13, 3, Color(0, 0, 0, 0.95))
		draw_string(font, pos, str(entry[0]), HORIZONTAL_ALIGNMENT_LEFT, -1, 13, label_color)

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

	# 6. Blips (drawn before the player arrow so the arrow stays on top).
	# Order matters for visual stacking, least important first.
	_blip_group(center, player_pos, yaw, "item_pickup", Color(0.78, 0.30, 0.95), false, false)
	_blip_group(center, player_pos, yaw, "warp_portal", Color(0.30, 0.95, 1.00), false, true)
	_blip_group(center, player_pos, yaw, "lodestone",   Color(0.45, 0.65, 1.00), true, false)
	_blip_group(center, player_pos, yaw, "npc",         Color(0.40, 0.95, 0.50), false, false)
	_blip_group(center, player_pos, yaw, "enemy",       Color(0.95, 0.30, 0.25), false, false)
	# Boss last so its pulsing dot draws above any overlapping mob blip.
	_blip_group(center, player_pos, yaw, "boss",        Color(1.00, 0.65, 0.10), false, false, true)

	# 7. Player arrow, stays at center pointing UP (because the world
	# rotates around the player).
	_draw_player_arrow(center)

# Draw a triangle arrow pointing up (player-relative forward direction).
# Outline + fill for the polished read.
func _draw_player_arrow(center: Vector2) -> void:
	var tip: Vector2 = center + Vector2(0, -PLAYER_ARROW_LEN)
	var bl: Vector2 = center + Vector2(-PLAYER_ARROW_LEN * 0.7, PLAYER_ARROW_LEN * 0.5)
	var br: Vector2 = center + Vector2(PLAYER_ARROW_LEN * 0.7, PLAYER_ARROW_LEN * 0.5)
	var pts: PackedVector2Array = [tip, br, bl]
	# Drop-shadow / outline
	var shadow_pts: PackedVector2Array = [
		tip + Vector2(0, 1), br + Vector2(1, 1), bl + Vector2(-1, 1)
	]
	draw_colored_polygon(shadow_pts, Color(0, 0, 0, 0.65))
	# Body, ivory white, sharp
	draw_colored_polygon(pts, Color(1.0, 0.98, 0.92))
	# Outline strokes
	draw_polyline([tip, br, bl, tip], Color(0.20, 0.10, 0.08), 1.5)
	# Tiny gold dot at center (pivot mark)
	draw_circle(center, 1.5, FRAME_GOLD_BRIGHT)

# Walk a group, project + rotate each node into minimap space, draw a
# blip. is_diamond / is_star flags substitute special shapes for that
# group. is_pulsing adds a sin()-driven scale for boss markers.
func _blip_group(center: Vector2, player_pos: Vector3, yaw: float, group_name: String, color: Color, is_diamond: bool = false, is_star: bool = false, is_pulsing: bool = false) -> void:
	var nodes := get_tree().get_nodes_in_group(group_name)
	for n in nodes:
		if not is_instance_valid(n):
			continue
		if not (n is Node3D):
			continue
		var rel: Vector3 = n.global_position - player_pos
		if rel.length() > VIEW_RANGE:
			continue
		var x_rot: float = rel.x * cos(-yaw) - rel.z * sin(-yaw)
		var z_rot: float = rel.x * sin(-yaw) + rel.z * cos(-yaw)
		var px: float = (x_rot / VIEW_RANGE) * MAP_RADIUS
		var py: float = (z_rot / VIEW_RANGE) * MAP_RADIUS
		var p := center + Vector2(px, py)
		if p.distance_to(center) > MAP_RADIUS - 4.0:
			continue
		# Pulse: bosses scale 1.0 -> 1.4 -> 1.0 over 1.6s. Reads as
		# 'this is a serious target' across the screen.
		var size_mul: float = 1.0
		if is_pulsing:
			size_mul = 1.0 + 0.4 * (sin(_t * 4.0) * 0.5 + 0.5)
		# Shadow
		draw_circle(p + Vector2(0, 1), BLIP_RADIUS * size_mul + 0.5, Color(0, 0, 0, 0.55))
		if is_diamond:
			# 4-point diamond
			var s: float = BLIP_RADIUS * 1.4 * size_mul
			var diamond: PackedVector2Array = [
				p + Vector2(0, -s), p + Vector2(s, 0),
				p + Vector2(0, s), p + Vector2(-s, 0)
			]
			draw_colored_polygon(diamond, color)
			draw_polyline([diamond[0], diamond[1], diamond[2], diamond[3], diamond[0]], color.lightened(0.3), 1.0)
		elif is_star:
			# 4-point star (cross of 2 diamonds at 45deg offset)
			var s2: float = BLIP_RADIUS * 1.5 * size_mul
			draw_colored_polygon([p + Vector2(0, -s2), p + Vector2(s2 * 0.4, 0), p + Vector2(0, s2), p + Vector2(-s2 * 0.4, 0)], color)
			draw_colored_polygon([p + Vector2(-s2, 0), p + Vector2(0, -s2 * 0.4), p + Vector2(s2, 0), p + Vector2(0, s2 * 0.4)], color)
		else:
			# Standard filled circle with bright rim
			draw_circle(p, BLIP_RADIUS * size_mul, color)
			draw_arc(p, BLIP_RADIUS * size_mul, 0.0, TAU, 12, color.lightened(0.4), 1.0)
