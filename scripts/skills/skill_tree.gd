extends Resource
class_name SkillTree

# Container for a class's full skill tree. Topology is encoded in each
# SkillNode's prerequisites array. UI lays out via grid_position.

@export var class_id: StringName = &""
@export var nodes: Array[SkillNode] = []

func get_node_by_id(id: StringName) -> SkillNode:
	for n in nodes:
		if n.id == id:
			return n
	return null

func can_unlock(id: StringName, stats: PlayerStats) -> bool:
	# True if at least one rank can be purchased right now.
	var node := get_node_by_id(id)
	if not node:
		return false
	if stats.unspent_skill_points < node.cost:
		return false
	if stats.level < node.min_level:
		return false
	var current_rank: int = stats.get_node_rank(id)
	if current_rank >= node.max_ranks:
		return false  # already maxed
	# Prerequisites must be at least rank 1 (unlocked).
	for prereq in node.prerequisites:
		if stats.get_node_rank(prereq) < 1:
			return false
	return true

func unlock(id: StringName, stats: PlayerStats) -> bool:
	# Purchase one rank in this node. Multi-rank nodes can call unlock() up to max_ranks times.
	if not can_unlock(id, stats):
		return false
	var node := get_node_by_id(id)
	stats.unspent_skill_points -= node.cost
	stats.set_node_rank(id, stats.get_node_rank(id) + 1)
	_apply_effect(node, stats)
	return true

func _apply_effect(node: SkillNode, stats: PlayerStats) -> void:
	match node.effect:
		SkillNode.Effect.STAT_FLAT:
			_apply_flat(stats, node.target_key, node.amount)
		SkillNode.Effect.STAT_PERCENT:
			_apply_pct(stats, node.target_key, node.amount)
		SkillNode.Effect.UNLOCK_ABILITY, SkillNode.Effect.UPGRADE_ABILITY, SkillNode.Effect.PASSIVE_TAG:
			# These are queried by Player/AbilityRunner at runtime
			pass

func _apply_flat(stats: PlayerStats, key: StringName, v: float) -> void:
	match key:
		&"max_hp": stats.max_hp += v; stats.hp = min(stats.hp + v, stats.max_hp)
		&"max_mana": stats.max_mana += v; stats.mana = min(stats.mana + v, stats.max_mana)
		&"strength": stats.strength += v
		&"dexterity": stats.dexterity += v
		&"intellect": stats.intellect += v
		&"vitality": stats.vitality += v
		&"armor": stats.armor += v
		&"magic_resist": stats.magic_resist += v
		&"crit_chance": stats.crit_chance += v
		&"crit_multiplier": stats.crit_multiplier += v

func _apply_pct(stats: PlayerStats, key: StringName, pct: float) -> void:
	match key:
		&"max_hp": stats.max_hp *= (1.0 + pct); stats.hp = min(stats.hp, stats.max_hp)
		&"max_mana": stats.max_mana *= (1.0 + pct); stats.mana = min(stats.mana, stats.max_mana)
		&"strength": stats.strength *= (1.0 + pct)
		&"dexterity": stats.dexterity *= (1.0 + pct)
		&"intellect": stats.intellect *= (1.0 + pct)
		&"vitality": stats.vitality *= (1.0 + pct)
