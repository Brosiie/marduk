extends Control
class_name SkillTreeLines

# Draws connecting lines between every skill node and its prerequisites.
# Highlighted chain (the prereq path leading INTO a hovered/selected node)
# renders in gold; everything else in dim brown.
#
# Coordinates mirror SkillTreePanel.GRID_OFFSET / COLUMN_WIDTH / ROW_HEIGHT.

const GRID_OFFSET := Vector2(120, 110)
const COLUMN_WIDTH := 132
const ROW_HEIGHT := 92
const NODE_SIZE := Vector2(72, 72)

const LINE_COLOR_NORMAL := Color(0.40, 0.32, 0.20, 0.55)
const LINE_COLOR_ACTIVE := Color(1.00, 0.85, 0.35, 0.85)
const LINE_THICKNESS_NORMAL := 1.5
const LINE_THICKNESS_ACTIVE := 2.5

var tree_ref: SkillTree = null
var stats_ref = null
var _highlighted_id: StringName = &""

func highlight_chain_for(id: StringName) -> void:
	_highlighted_id = id

func _draw() -> void:
	if not tree_ref:
		return
	var chain_ids: Dictionary = _resolve_chain(_highlighted_id)
	for n in tree_ref.nodes:
		var to_pos: Vector2 = _node_center(n)
		for prereq_id in n.prerequisites:
			var prereq := tree_ref.get_node_by_id(prereq_id)
			if not prereq:
				continue
			var from_pos: Vector2 = _node_center(prereq)
			var is_active: bool = chain_ids.has(n.id) and chain_ids.has(prereq_id)
			var color: Color = LINE_COLOR_ACTIVE if is_active else LINE_COLOR_NORMAL
			var thickness: float = LINE_THICKNESS_ACTIVE if is_active else LINE_THICKNESS_NORMAL
			# If the prereq is unlocked, brighten the normal line slightly so the
			# player can read which paths are "open" without selecting anything.
			if not is_active and stats_ref and stats_ref.get_node_rank(prereq_id) >= 1:
				color = Color(0.65, 0.50, 0.28, 0.75)
			draw_line(from_pos, to_pos, color, thickness, true)

func _node_center(n: SkillNode) -> Vector2:
	var col: int = int(n.grid_position.x)
	var tier: int = max(1, int(n.grid_position.y))
	return GRID_OFFSET + Vector2(col * COLUMN_WIDTH, (tier - 1) * ROW_HEIGHT) + NODE_SIZE * 0.5

# Walks prerequisites from the given node back through the chain. Returns a
# set (Dictionary[StringName, true]) of all node ids in the chain so _draw
# can highlight only the lines whose endpoints both sit in the chain.
func _resolve_chain(target_id: StringName) -> Dictionary:
	var out: Dictionary = {}
	if target_id == &"" or not tree_ref:
		return out
	var stack: Array[StringName] = [target_id]
	while not stack.is_empty():
		var id: StringName = stack.pop_back()
		if out.has(id):
			continue
		out[id] = true
		var n := tree_ref.get_node_by_id(id)
		if not n:
			continue
		for prereq in n.prerequisites:
			stack.append(prereq)
	return out
