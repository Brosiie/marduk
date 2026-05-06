extends Control
class_name SkillTreeView

# Visual skill tree rendered as nodes on a 2D canvas. Each SkillNode is positioned by
# `grid_position`. Lines drawn between prerequisites. Click to unlock if eligible.
#
# For Ronin's 49-form tree, lay out 7 columns (one per breathing style) and 7 rows
# (form 1 at bottom, form 7 capstone at top).

signal node_unlocked(node: SkillNode)

@export var player_path: NodePath
const CELL := Vector2(80, 80)
const ORIGIN := Vector2(60, 60)

var player: Node
var tree: SkillTree

func _ready() -> void:
	player = get_node_or_null(player_path) if player_path else get_tree().get_first_node_in_group("player")
	# class_def can be null when the player hasn't picked a class yet (start
	# menu / pre-creation). Skip the tree lookup in that case so the panel
	# just renders empty rather than crashing.
	if player and player.stats and player.stats.class_def:
		tree = player.stats.class_def.skill_tree
	queue_redraw()

func _draw() -> void:
	if not tree:
		return
	# Draw connections first (so nodes overlay)
	for n: SkillNode in tree.nodes:
		var to := _node_pos(n)
		for prereq_id in n.prerequisites:
			var prereq := tree.get_node_by_id(prereq_id)
			if prereq:
				var color := Color(0.4, 0.4, 0.4, 0.6)
				if prereq_id in player.stats.unlocked_skill_node_ids:
					color = Color(0.8, 0.7, 0.3, 0.9)
				draw_line(_node_pos(prereq), to, color, 2.0, true)

	# Draw nodes
	for n: SkillNode in tree.nodes:
		var pos := _node_pos(n)
		var unlocked: bool = n.id in player.stats.unlocked_skill_node_ids
		var can: bool = tree.can_unlock(n.id, player.stats)
		var color := Color(0.25, 0.25, 0.25, 1.0)
		if unlocked:
			color = Color(0.85, 0.7, 0.25, 1.0)
		elif can:
			color = Color(0.5, 0.45, 0.3, 1.0)
		draw_circle(pos, 22.0, color)
		# Border
		var border := Color(0.7, 0.65, 0.5)
		draw_arc(pos, 22.0, 0.0, TAU, 32, border, 2.0, true)
		# Label below
		var font := ThemeDB.fallback_font
		draw_string(font, pos + Vector2(-30, 38), n.display_name.left(14),
			HORIZONTAL_ALIGNMENT_LEFT, -1, 12, Color(0.9, 0.9, 0.9))

func _node_pos(n: SkillNode) -> Vector2:
	return ORIGIN + n.grid_position * CELL

func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		var click: Vector2 = event.position
		for n: SkillNode in tree.nodes:
			if click.distance_to(_node_pos(n)) <= 22.0:
				if tree.unlock(n.id, player.stats):
					node_unlocked.emit(n)
					player.stats.recompute_base()
					player.stats.apply_all_skill_effects()
					queue_redraw()
				return
