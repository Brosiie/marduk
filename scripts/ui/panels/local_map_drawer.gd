extends Control
class_name LocalMapDrawer

# Renders a top-down view of the current scene by polling group memberships.
# Auto-frames the visible content; uses simple colored circles per node type.
# Refresh on open or every frame while visible (cheap — just queue_redraw).

const COLOR_FLOOR := Color(0.10, 0.08, 0.06, 0.92)
const COLOR_GRID  := Color(0.22, 0.18, 0.14, 0.55)
const COLOR_PLAYER:= Color(1.00, 0.85, 0.30)
const COLOR_BOSS  := Color(0.95, 0.20, 0.20)
const COLOR_ENEMY := Color(1.00, 0.55, 0.20)
const COLOR_NPC   := Color(0.55, 0.95, 0.45)
const COLOR_ITEM  := Color(0.35, 0.65, 1.00)
const COLOR_LOOT  := Color(0.85, 0.50, 0.95)
const COLOR_BORDER:= Color(0.55, 0.45, 0.25, 0.85)

const MARGIN_M := 6.0  # world-space margin around content when framing
const GRID_M   := 5.0  # one grid line per 5m

var _world_min: Vector2 = Vector2.ZERO
var _world_max: Vector2 = Vector2.ZERO
var _has_content: bool = false

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_PASS

func refresh() -> void:
	queue_redraw()

func _process(_delta: float) -> void:
	# Live updates while open — cheap, only redraw when visible
	if visible:
		queue_redraw()

func _draw() -> void:
	# Background panel
	draw_rect(Rect2(Vector2.ZERO, size), COLOR_FLOOR)
	draw_rect(Rect2(Vector2.ZERO, size), COLOR_BORDER, false, 1.5)

	var entries: Array = _gather_entries()
	if entries.is_empty():
		_draw_centered_text("No spatial data in this scene.", Color(0.65, 0.60, 0.50))
		return

	_compute_bounds(entries)
	_draw_grid()
	_draw_compass()
	_draw_scale_bar()

	for entry in entries:
		var pos: Vector2 = _world_to_screen(entry["pos"])
		var radius: float = entry.get("r", 4.0)
		# Boss arena ring + dot for the boss
		match entry.get("kind", "enemy"):
			"player":
				_draw_player_marker(pos)
			"boss":
				draw_circle(pos, radius * 1.5, COLOR_BOSS)
				draw_arc(pos, radius * 3.0, 0, TAU, 24, COLOR_BOSS, 1.5, true)
			"enemy":
				draw_circle(pos, radius, COLOR_ENEMY)
			"npc":
				draw_circle(pos, radius, COLOR_NPC)
			"loot":
				draw_circle(pos, radius, COLOR_LOOT)
			"pickup":
				draw_circle(pos, radius, COLOR_ITEM)

func _draw_player_marker(pos: Vector2) -> void:
	# Diamond shape so the player is unmistakable next to round dots
	var pts := PackedVector2Array([
		pos + Vector2(0, -7),
		pos + Vector2(7, 0),
		pos + Vector2(0, 7),
		pos + Vector2(-7, 0),
	])
	draw_colored_polygon(pts, COLOR_PLAYER)
	# Outline
	pts.append(pts[0])
	draw_polyline(pts, Color(0, 0, 0, 0.65), 1.5)

func _draw_grid() -> void:
	# Render a grid in screen space at GRID_M-spaced world coords
	var span: Vector2 = _world_max - _world_min
	if span.x <= 0 or span.y <= 0:
		return
	var x_start: float = floor(_world_min.x / GRID_M) * GRID_M
	while x_start < _world_max.x:
		var screen_x: float = _world_to_screen(Vector2(x_start, _world_min.y)).x
		draw_line(Vector2(screen_x, 0), Vector2(screen_x, size.y), COLOR_GRID, 1.0)
		x_start += GRID_M
	var y_start: float = floor(_world_min.y / GRID_M) * GRID_M
	while y_start < _world_max.y:
		var screen_y: float = _world_to_screen(Vector2(_world_min.x, y_start)).y
		draw_line(Vector2(0, screen_y), Vector2(size.x, screen_y), COLOR_GRID, 1.0)
		y_start += GRID_M

func _draw_compass() -> void:
	var origin := Vector2(28, 28)
	var label := Label.new()  # not actually added — use draw_string instead
	var font := ThemeDB.fallback_font
	if not font:
		return
	draw_string(font, origin + Vector2(-4, -10), "N", HORIZONTAL_ALIGNMENT_LEFT, -1, 14, Color(0.85, 0.78, 0.55))
	draw_line(origin, origin + Vector2(0, -16), Color(0.85, 0.78, 0.55), 2.0)

func _draw_scale_bar() -> void:
	# Draw a 10m scale bar bottom-left
	var span_x: float = max(0.001, _world_max.x - _world_min.x)
	var px_per_m: float = (size.x - 16) / span_x
	var bar_px: float = px_per_m * 10.0
	var y: float = size.y - 18
	draw_line(Vector2(16, y), Vector2(16 + bar_px, y), Color(0.85, 0.78, 0.55), 2.0)
	var font := ThemeDB.fallback_font
	if font:
		draw_string(font, Vector2(20 + bar_px, y - 2), "10 m", HORIZONTAL_ALIGNMENT_LEFT, -1, 12, Color(0.85, 0.78, 0.55))

func _draw_centered_text(text: String, color: Color) -> void:
	var font := ThemeDB.fallback_font
	if font:
		draw_string(font, size * 0.5 - Vector2(80, 0), text, HORIZONTAL_ALIGNMENT_CENTER, 200, 14, color)

# ───────────────────── Polling ─────────────────────

func _gather_entries() -> Array:
	var out: Array = []
	var tree := get_tree()
	if not tree:
		return out
	# Player(s) — diamond marker
	for p in tree.get_nodes_in_group("player"):
		if p is Node3D:
			out.append({"pos": _xz(p.global_position), "kind": "player", "r": 7})
	# Boss
	for b in tree.get_nodes_in_group("boss"):
		if b is Node3D:
			out.append({"pos": _xz(b.global_position), "kind": "boss", "r": 6})
	# Enemies (mobs that aren't bosses)
	for e in tree.get_nodes_in_group("enemy"):
		if e is Node3D and not e.is_in_group("boss"):
			out.append({"pos": _xz(e.global_position), "kind": "enemy", "r": 5})
	# NPCs
	for n in tree.get_nodes_in_group("npc"):
		if n is Node3D:
			out.append({"pos": _xz(n.global_position), "kind": "npc", "r": 5})
	# Item pickups
	for it in tree.get_nodes_in_group("item_pickup"):
		if it is Node3D:
			# Use loot color if it's a high-rarity drop, else generic pickup
			var kind: String = "pickup"
			if "item" in it and it.item and "rarity" in it.item and int(it.item.rarity) >= 3:
				kind = "loot"
			out.append({"pos": _xz(it.global_position), "kind": kind, "r": 4})
	return out

func _xz(v: Vector3) -> Vector2:
	# Top-down: world X = map X, world Z = map Y. Negate Z so north-on-screen
	# matches negative-Z (which is FORWARD in Godot world space).
	return Vector2(v.x, -v.z)

func _compute_bounds(entries: Array) -> void:
	_has_content = entries.size() > 0
	if not _has_content:
		_world_min = Vector2(-10, -10)
		_world_max = Vector2(10, 10)
		return
	_world_min = Vector2(INF, INF)
	_world_max = Vector2(-INF, -INF)
	for entry in entries:
		var p: Vector2 = entry["pos"]
		_world_min.x = min(_world_min.x, p.x)
		_world_min.y = min(_world_min.y, p.y)
		_world_max.x = max(_world_max.x, p.x)
		_world_max.y = max(_world_max.y, p.y)
	# Margin
	_world_min -= Vector2(MARGIN_M, MARGIN_M)
	_world_max += Vector2(MARGIN_M, MARGIN_M)
	# Square the aspect so circles stay circular at any view-size
	var span := _world_max - _world_min
	var aspect_ratio: float = size.x / max(1.0, size.y)
	var span_aspect: float = span.x / max(0.001, span.y)
	if span_aspect > aspect_ratio:
		# wider than panel — pad y
		var target_y: float = span.x / aspect_ratio
		var pad: float = (target_y - span.y) * 0.5
		_world_min.y -= pad
		_world_max.y += pad
	else:
		var target_x: float = span.y * aspect_ratio
		var pad: float = (target_x - span.x) * 0.5
		_world_min.x -= pad
		_world_max.x += pad

func _world_to_screen(world: Vector2) -> Vector2:
	var span := _world_max - _world_min
	if span.x <= 0 or span.y <= 0:
		return Vector2.ZERO
	var u: float = (world.x - _world_min.x) / span.x
	var v: float = (world.y - _world_min.y) / span.y
	return Vector2(u * size.x, v * size.y)
