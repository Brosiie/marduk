extends Control

# Skills tab: shows the player's class's 49-node skill tree as a scroll grid.
# Each node is a button. Pressing a node spends a skill point if available
# and the prereq node is already unlocked.

const NODE_PX: Vector2 = Vector2(72, 72)

var _player: Node = null

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_PASS
	_player = get_tree().get_first_node_in_group("player")

	var title := Label.new()
	title.text = "Skill Tree"
	title.add_theme_font_size_override("font_size", 22)
	add_child(title)

	# Inline-host the existing SkillTreeView script if present so this panel
	# is not a duplicate implementation. Otherwise, simple stub.
	var existing_path := "res://scripts/ui/menus/skill_tree_view.gd"
	if ResourceLoader.exists(existing_path):
		var view = Control.new()
		view.set_script(load(existing_path))
		view.anchor_left = 0.0
		view.anchor_top = 0.07
		view.anchor_right = 1.0
		view.anchor_bottom = 1.0
		add_child(view)
		return

	var pts := Label.new()
	pts.anchor_left = 0.0
	pts.anchor_top = 0.07
	pts.text = "Unspent skill points: %d" % _read_unspent_points()
	add_child(pts)

func _read_unspent_points() -> int:
	if _player == null or _player.stats == null:
		return 0
	if "skill_points" in _player.stats:
		return int(_player.stats.skill_points)
	return 0

func refresh() -> void:
	pass
