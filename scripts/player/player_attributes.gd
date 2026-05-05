extends Resource
class_name PlayerAttributes

# Player-allocated attribute points. Separate from class baseline stats.
# 150 points total over 100 levels (3 AP every 2 levels, 50 windows).
#
# The 10 attributes (Bond's 7 + 3 chosen extras):
#   POOLS (each point = larger resource pool):
#     1. Health      - max HP, regen
#     2. Stamina     - max stamina, regen (NEW pool for sprint/dodge/block)
#     3. Mana        - max mana, regen
#   SCALAR ATTRIBUTES (each point = % bonus to derived stats):
#     4. Strength    - physical melee damage
#     5. Accuracy    - hit chance, crit chance
#     6. Spellpower  - spell damage, mana cost reduction
#     7. Wisdom      - XP gain, drop chance
#     8. Vitality    - HP regen, status duration reduction
#     9. Endurance   - stamina regen, carry capacity
#    10. Luck        - rare drop chance, crit multiplier

const ATTRIBUTE_NAMES: Array[StringName] = [
	&"health", &"stamina", &"mana",
	&"strength", &"accuracy", &"spellpower", &"wisdom",
	&"vitality", &"endurance", &"luck"
]

# Per-attribute-point contribution to derived stats. The mapping table.
# Read by PlayerStats.apply_attribute_bonuses() and damage_calc.
const SCALING := {
	&"health":     { "max_hp": 12.0, "hp_regen": 0.2 },
	&"stamina":    { "max_stamina": 5.0, "stamina_regen": 0.4 },
	&"mana":       { "max_mana": 10.0, "mana_regen": 0.5 },
	&"strength":   { "phys_damage_pct": 0.015, "carry": 1.0 },        # +1.5% melee per pt
	&"accuracy":   { "hit_pct": 0.003, "crit_chance_pct": 0.004 },    # +0.3% hit, +0.4% crit per pt
	&"spellpower": { "spell_damage_pct": 0.015, "mana_cost_pct": -0.002 }, # +1.5% spell dmg, -0.2% cost
	&"wisdom":     { "xp_gain_pct": 0.005, "drop_chance_pct": 0.005 },     # +0.5% xp/drops per pt
	&"vitality":   { "hp_regen": 0.5, "status_resist_pct": 0.005 },        # +0.5% status dur reduction
	&"endurance":  { "stamina_regen": 0.4, "carry": 2.0 },
	&"luck":       { "rare_drop_pct": 0.003, "crit_mult_pct": 0.005 },     # +0.5% crit mult per pt
}

const HARD_CAPS := {
	&"hit_pct": 0.95,         # 95% max hit chance after accuracy
	&"mana_cost_pct": -0.50,  # 50% spell cost reduction max
}

# Spent points per attribute. Player allocates from `pending_points` pool.
@export var spent: Dictionary = {
	&"health": 0, &"stamina": 0, &"mana": 0,
	&"strength": 0, &"accuracy": 0, &"spellpower": 0, &"wisdom": 0,
	&"vitality": 0, &"endurance": 0, &"luck": 0,
}

@export var pending_points: int = 0  # unspent attribute points

signal point_spent(attribute_id: StringName, new_total: int)
signal points_added(amount: int)

func add_pending(amount: int) -> void:
	pending_points += amount
	points_added.emit(amount)

func can_spend(attribute_id: StringName) -> bool:
	return pending_points > 0 and spent.has(attribute_id)

func spend(attribute_id: StringName, count: int = 1) -> bool:
	if not spent.has(attribute_id):
		return false
	if pending_points < count:
		return false
	spent[attribute_id] = int(spent[attribute_id]) + count
	pending_points -= count
	point_spent.emit(attribute_id, spent[attribute_id])
	return true

func get_value(attribute_id: StringName) -> int:
	return int(spent.get(attribute_id, 0))

func total_spent() -> int:
	var t := 0
	for v in spent.values():
		t += int(v)
	return t

# Aggregate contribution to a derived stat across all 10 attributes.
# Eg `derived_bonus(&"max_hp")` returns total HP added by attribute points.
func derived_bonus(stat_key: StringName) -> float:
	var total := 0.0
	for attr_id in spent.keys():
		var pts: int = int(spent[attr_id])
		var rules: Dictionary = SCALING.get(attr_id, {})
		if rules.has(stat_key):
			total += float(rules[stat_key]) * float(pts)
	if HARD_CAPS.has(stat_key):
		var cap: float = HARD_CAPS[stat_key]
		if cap > 0:
			total = min(total, cap)
		else:
			total = max(total, cap)
	return total
