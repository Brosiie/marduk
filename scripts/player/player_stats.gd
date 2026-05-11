extends Resource
class_name PlayerStats

# Live mutable state for one player. Class is the static template,
# this is the runtime instance that levels up and prestiges.
#
# Recompute pipeline (run on level-up, attribute spend, equip, skill unlock, prestige):
#   recompute_base()          - class baseline at current level
#   apply_attribute_bonuses() - PlayerAttributes contributions
#   apply_all_skill_effects() - unlocked SkillNode flat/percent stat effects
#   apply_equipment_bonuses() - equipped Item bonuses (HP, str, etc)

const MAX_LEVEL := 100

# Leveling rewards (Bond's spec):
#   Even levels (2, 4, 6 ... 100): +3 attribute points  -> 150 AP total
#   Odd levels  (3, 5, 7 ... 99):  +1 skill point       -> 49 SP total
const ATTRIBUTE_POINTS_EVEN_LEVEL := 3
const SKILL_POINTS_ODD_LEVEL := 1

signal leveled_up(new_level: int)
signal max_level_reached
signal attribute_points_awarded(amount: int)
signal skill_points_awarded(amount: int)

@export var class_def: PlayerClass
@export var attributes: PlayerAttributes
@export var level: int = 1
@export var xp: int = 0
@export var unspent_skill_points: int = 0
# Single rank-1 nodes used to live here; this is now a synced view of node_ranks.
# Anything with rank >= 1 also appears in this array so legacy `id in unlocked_skill_node_ids`
# checks keep working.
@export var unlocked_skill_node_ids: Array[StringName] = []
# Per-node rank tracker. Multi-rank passives accumulate here. Capped by SkillNode.max_ranks.
@export var node_ranks: Dictionary = {}

# Pool current values (clamped to maxes during recompute)
@export var hp: float = 100.0
@export var max_hp: float = 100.0
@export var mana: float = 50.0
@export var max_mana: float = 50.0
@export var stamina: float = 50.0
@export var max_stamina: float = 50.0

# Regen per second
@export var hp_regen: float = 0.0
@export var mana_regen: float = 1.5
@export var stamina_regen: float = 8.0  # baseline; sprint/dodge consume

# Class-baseline scalar stats (kept for breathing form / item compat)
@export var strength: float = 10.0
@export var dexterity: float = 10.0
@export var intellect: float = 10.0
@export var vitality: float = 10.0

# New derived stats (from attributes + class + items)
@export var spellpower: float = 0.0   # adds to spell damage scaling
@export var accuracy: float = 0.0     # hit chance + crit chance
@export var wisdom: float = 0.0       # xp gain + drop chance
@export var luck: float = 0.0         # rare drops + crit mult
@export var endurance: float = 0.0    # stamina regen + carry

@export var armor: float = 5.0
@export var magic_resist: float = 5.0
@export var crit_chance: float = 0.05
@export var crit_multiplier: float = 1.75
@export var hit_chance: float = 0.95  # 95% baseline; missed hits feel rare

# Aggregate gain modifiers (read by quest/loot code)
@export var xp_gain_mult: float = 1.0
@export var drop_chance_mult: float = 1.0
@export var rare_drop_mult: float = 1.0
@export var carry_capacity: int = 100  # bag size or weight, depending on later impl

func _init() -> void:
	if not attributes:
		attributes = PlayerAttributes.new()

# ===========================================================
# XP curve and leveling
# ===========================================================
func xp_to_next_level() -> int:
	if level >= MAX_LEVEL:
		return 0
	return int(75 * pow(level, 1.55))

func gain_xp(amount: int) -> void:
	if level >= MAX_LEVEL:
		return
	# Wisdom/luck multipliers stack into incoming XP
	var effective: int = int(round(float(amount) * xp_gain_mult))
	# Party multiplier: +10% at full 4-member party (Bond's spec)
	var pm: Node = Engine.get_main_loop().root.get_node_or_null("PartyManager")
	if pm:
		effective = int(round(float(effective) * pm.xp_multiplier()))
	xp += effective
	while level < MAX_LEVEL and xp >= xp_to_next_level():
		xp -= xp_to_next_level()
		level += 1
		_award_level_up_rewards(level)
		recompute_derived()
		leveled_up.emit(level)
	if level >= MAX_LEVEL:
		xp = 0
		max_level_reached.emit()

func _award_level_up_rewards(new_level: int) -> void:
	# Alternating reward: even levels grant 3 AP, odd levels grant 1 SP.
	# Level 1 is starting state, no reward there.
	if new_level % 2 == 0:
		if attributes:
			attributes.add_pending(ATTRIBUTE_POINTS_EVEN_LEVEL)
			attribute_points_awarded.emit(ATTRIBUTE_POINTS_EVEN_LEVEL)
	else:
		unspent_skill_points += SKILL_POINTS_ODD_LEVEL
		skill_points_awarded.emit(SKILL_POINTS_ODD_LEVEL)

# ===========================================================
# Stat recompute pipeline
# ===========================================================
func recompute_base() -> void:
	if not class_def:
		return
	var lvl_mult := float(level - 1)
	max_hp = class_def.base_hp + class_def.hp_per_level * lvl_mult
	max_mana = class_def.base_mana + class_def.mana_per_level * lvl_mult
	max_stamina = 50.0 + 1.5 * lvl_mult  # Class-agnostic baseline; attributes top up
	strength = class_def.base_strength + class_def.strength_per_level * lvl_mult
	dexterity = class_def.base_dexterity + class_def.dexterity_per_level * lvl_mult
	intellect = class_def.base_intellect + class_def.intellect_per_level * lvl_mult
	vitality = class_def.base_vitality + class_def.vitality_per_level * lvl_mult
	armor = class_def.armor
	magic_resist = class_def.magic_resist

	# Reset derived stats that pure-attribute-fed (will be summed in apply_attribute_bonuses)
	spellpower = 0.0
	accuracy = 0.0
	wisdom = 0.0
	luck = 0.0
	endurance = 0.0
	hp_regen = 0.5  # baseline
	mana_regen = 1.5
	stamina_regen = 8.0
	xp_gain_mult = 1.0
	drop_chance_mult = 1.0
	rare_drop_mult = 1.0
	hit_chance = 0.95
	carry_capacity = 100

func apply_attribute_bonuses() -> void:
	if not attributes:
		return
	# Pool maxes
	max_hp += attributes.derived_bonus(&"max_hp")
	max_mana += attributes.derived_bonus(&"max_mana")
	max_stamina += attributes.derived_bonus(&"max_stamina")
	# Regen
	hp_regen += attributes.derived_bonus(&"hp_regen")
	mana_regen += attributes.derived_bonus(&"mana_regen")
	stamina_regen += attributes.derived_bonus(&"stamina_regen")
	# Scalar attributes (numeric counters, queried by damage_calc)
	# These are stored as multipliers/bonuses, not as direct stat values.
	spellpower = attributes.derived_bonus(&"spell_damage_pct")
	accuracy   = attributes.derived_bonus(&"hit_pct") + attributes.derived_bonus(&"crit_chance_pct")
	wisdom     = attributes.derived_bonus(&"xp_gain_pct") + attributes.derived_bonus(&"drop_chance_pct")
	luck       = attributes.derived_bonus(&"rare_drop_pct") + attributes.derived_bonus(&"crit_mult_pct")
	endurance  = attributes.derived_bonus(&"carry")
	# Hit / crit / mults
	hit_chance = min(0.95, hit_chance + attributes.derived_bonus(&"hit_pct"))
	crit_chance += attributes.derived_bonus(&"crit_chance_pct")
	crit_multiplier += attributes.derived_bonus(&"crit_mult_pct")
	# Gain mults
	xp_gain_mult     = 1.0 + attributes.derived_bonus(&"xp_gain_pct")
	drop_chance_mult = 1.0 + attributes.derived_bonus(&"drop_chance_pct")
	rare_drop_mult   = 1.0 + attributes.derived_bonus(&"rare_drop_pct")
	carry_capacity  += int(attributes.derived_bonus(&"carry"))

func apply_all_skill_effects() -> void:
	if not class_def or not class_def.skill_tree:
		return
	for node_id in unlocked_skill_node_ids:
		var node := class_def.skill_tree.get_node_by_id(node_id)
		if node:
			# Apply effect once per current rank. Multi-rank nodes stack their amount.
			var ranks: int = get_node_rank(node_id)
			for _r in range(ranks):
				class_def.skill_tree._apply_effect(node, self)

func recompute_derived() -> void:
	if not class_def:
		return
	recompute_base()
	apply_attribute_bonuses()
	apply_all_skill_effects()
	# Clamp current pools to new maxes; full-heal on first compute
	hp = clamp(hp if hp > 0 else max_hp, 0.0, max_hp)
	mana = clamp(mana if mana > 0 else max_mana, 0.0, max_mana)
	stamina = clamp(stamina if stamina > 0 else max_stamina, 0.0, max_stamina)

func get_attr(attr: StringName) -> float:
	# For damage_calc scaling. Reads CLASS-level stats (str/dex/int/vit), not attribute points.
	# Attribute points layer in via spellpower / accuracy modifiers, applied separately.
	match attr:
		&"strength": return strength
		&"dexterity": return dexterity
		&"intellect": return intellect
		&"vitality": return vitality
		&"spellpower": return intellect + spellpower * 100.0  # int + spellpower bonus
		_: return 0.0

func get_node_rank(id: StringName) -> int:
	return int(node_ranks.get(id, 0))

func set_node_rank(id: StringName, rank: int) -> void:
	node_ranks[id] = rank
	if rank > 0 and not (id in unlocked_skill_node_ids):
		unlocked_skill_node_ids.append(id)
	elif rank <= 0 and id in unlocked_skill_node_ids:
		unlocked_skill_node_ids.erase(id)

# Refund every spent skill point back to unspent. Walks node_ranks +
# multiplies each rank by the node's per-rank cost (read from
# SkillTreeRegistry so we honor variable-cost nodes), refunds the
# total, and clears all rank state.
#
# Returns the number of skill points refunded so the caller can show
# "+47 skill points" toast. Caller is responsible for the gold cost
# (the skill tree panel handles the cost gate before calling).
func refund_all_skill_points() -> int:
	var refunded: int = 0
	# Resolve each unlocked node's cost from the SkillTreeRegistry so
	# we don't assume cost=1 for every rank. Falls back to cost=1 if
	# the registry doesn't expose the node (defensive).
	var tree_root := Engine.get_main_loop() as SceneTree
	var registry: Node = null
	if tree_root:
		registry = tree_root.root.get_node_or_null("SkillTreeRegistry")
	for id in node_ranks.keys():
		var rank: int = int(node_ranks[id])
		if rank <= 0:
			continue
		var per_rank_cost: int = 1
		if registry and registry.has_method("get_node_by_id"):
			var n = registry.get_node_by_id(id)
			if n and "cost" in n:
				per_rank_cost = max(1, int(n.cost))
		refunded += rank * per_rank_cost
	# Wipe all rank state + reset the unlocked-ids list
	node_ranks.clear()
	unlocked_skill_node_ids.clear()
	unspent_skill_points += refunded
	return refunded

func mastered_breathing_styles() -> int:
	var count := 0
	for style_id in [&"water", &"flame", &"mist", &"thunder", &"stone", &"wind"]:
		var node_id := StringName("ronin_%s_7" % style_id)
		if node_id in unlocked_skill_node_ids:
			count += 1
	return count

# Convenience for spell-cost reduction reading from attributes
func spell_cost_multiplier() -> float:
	if not attributes:
		return 1.0
	return 1.0 + attributes.derived_bonus(&"mana_cost_pct")  # value is negative for reduction
