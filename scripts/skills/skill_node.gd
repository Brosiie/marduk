extends Resource
class_name SkillNode

# A single node in a skill tree. Unlocking it costs skill points and
# applies modifiers to stats or unlocks/upgrades abilities.

enum Effect {
	STAT_FLAT,        # add flat amount to a stat (eg +20 max_hp)
	STAT_PERCENT,     # multiplier on a stat (eg +10% strength)
	UNLOCK_ABILITY,   # grants an ability the player did not have
	UPGRADE_ABILITY,  # modifies an existing ability (eg +20% damage)
	PASSIVE_TAG,      # tag for engine queries (eg "pierce_armor")
}

@export var id: StringName = &""
@export var display_name: String = ""
@export_multiline var description: String = ""
@export var icon: Texture2D
@export var cost: int = 1   # cost PER RANK; multi-rank nodes cost cost*max_ranks total

# Multi-rank passives can be invested up to max_ranks times. amount is per-rank.
# Single-unlock nodes (abilities) keep max_ranks = 1.
@export var max_ranks: int = 1

@export_group("Tree Topology")
@export var prerequisites: Array[StringName] = []  # node ids that must be unlocked first
@export var min_level: int = 1
@export var grid_position: Vector2 = Vector2.ZERO  # for UI rendering

@export_group("Effect")
@export var effect: Effect = Effect.STAT_FLAT
@export var target_key: StringName = &""  # stat name or ability id
@export var amount: float = 0.0  # per-rank amount; total contribution = amount * current_rank
@export var ability_unlock: Ability  # used when effect == UNLOCK_ABILITY

func is_multi_rank() -> bool:
	return max_ranks > 1

func total_cost() -> int:
	return cost * max_ranks
