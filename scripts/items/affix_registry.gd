extends Node

# Autoload: catalog of all affixes plus the roll-for-rarity helper.
#
# Affixes are SEEDED in code (not .tres files) so the data layer is
# greppable in one place and we don't pay the stale class_name cache tax
# for 40+ small Resources. AffixRegistry is registered in project.godot
# as the "AffixRegistry" autoload; access via /root/AffixRegistry.
#
# Usage:
#   var rolled: Array = AffixRegistry.roll_for_rarity(item, item.rarity, item.item_level)
#   for a in rolled:
#       (a.kind == Affix.Kind.PREFIX ? item.prefix_affixes : item.suffix_affixes).append(a.id)
# Then apply_bonuses_to_actor(item, actor) when the item is equipped to
# layer the rolled bonuses on top of the base item stats.
#
# Tier map (Item.Rarity):
#   COMMON      -> 1 affix  (prefix OR suffix, 50/50)
#   RARE        -> 2 affixes (1 prefix + 1 suffix)
#   VERY_RARE   -> 3 affixes (2 prefixes + 1 suffix, or 1 + 2, randomized)
#   LEGENDARY   -> 4 affixes (2 + 2) plus the base item's unique mechanic

const AffixRes := preload("res://scripts/items/affix.gd")

# Item.Rarity enum is: JUNK=0, BASIC=1, COMMON=2, RARE=3, VERY_RARE=4, LEGENDARY=5
const AFFIX_COUNT_BY_RARITY := {
	2: 1,  # COMMON
	3: 2,  # RARE
	4: 3,  # VERY_RARE
	5: 4,  # LEGENDARY
}

var prefixes: Array = []
var suffixes: Array = []

signal seeded(prefix_count: int, suffix_count: int)

func _ready() -> void:
	_seed_prefixes()
	_seed_suffixes()
	print("[AffixRegistry] seeded %d prefixes + %d suffixes" % [prefixes.size(), suffixes.size()])
	seeded.emit(prefixes.size(), suffixes.size())

# ─── Public API ──────────────────────────────────────────────────────

# Roll a valid set of affixes for an item at the given rarity + level.
# Returns an array of Affix resources; caller stamps IDs onto the item's
# prefix_affixes / suffix_affixes arrays.
func roll_for_rarity(_item, rarity: int, item_level: int) -> Array:
	var count: int = int(AFFIX_COUNT_BY_RARITY.get(rarity, 0))
	if count <= 0:
		return []
	var rolled: Array = []
	# Decide prefix/suffix split. RARE+ guarantees both; COMMON picks one.
	var pre_n: int = 0
	var suf_n: int = 0
	match count:
		1:
			if randi() % 2 == 0:
				pre_n = 1
			else:
				suf_n = 1
		2:
			pre_n = 1; suf_n = 1
		3:
			if randi() % 2 == 0:
				pre_n = 2; suf_n = 1
			else:
				pre_n = 1; suf_n = 2
		4:
			pre_n = 2; suf_n = 2
	for _i in range(pre_n):
		var a: Resource = _pick_weighted(prefixes, rarity, item_level, rolled)
		if a:
			rolled.append(a)
	for _i in range(suf_n):
		var a2: Resource = _pick_weighted(suffixes, rarity, item_level, rolled)
		if a2:
			rolled.append(a2)
	return rolled

# Look up an affix by ID for tooltip/equip-time use.
func get_affix(id: StringName) -> Resource:
	for a in prefixes:
		if a.id == id:
			return a
	for a in suffixes:
		if a.id == id:
			return a
	return null

# Apply every rolled affix's bonus dict additively to actor stat fields.
# Called at equip time. Returns a Dictionary of {field: delta_applied} so
# the unequip path can reverse exactly the same delta.
func apply_bonuses_to_actor(item, actor) -> Dictionary:
	var deltas: Dictionary = {}
	var all_affix_ids: Array = []
	all_affix_ids.append_array(item.prefix_affixes)
	all_affix_ids.append_array(item.suffix_affixes)
	for affix_id in all_affix_ids:
		var a: Resource = get_affix(affix_id)
		if a == null:
			continue
		for field in a.bonuses:
			var v: float = float(a.bonuses[field])
			if field in actor:
				actor.set(field, float(actor.get(field)) + v)
				deltas[field] = deltas.get(field, 0.0) + v
	return deltas

# Build the formatted display name for an item with affixes applied.
# "Bronze Sword" + prefix "Burning" + suffix "of Cleaving" ->
# "Burning Bronze Sword of Cleaving"
func format_item_name(item) -> String:
	var prefix_text: String = ""
	var suffix_text: String = ""
	for affix_id in item.prefix_affixes:
		var a: Resource = get_affix(affix_id)
		if a:
			prefix_text += a.name_part + " "
	for affix_id in item.suffix_affixes:
		var a: Resource = get_affix(affix_id)
		if a:
			suffix_text += " " + a.name_part
	return (prefix_text + item.display_name + suffix_text).strip_edges()

# ─── Internal: weighted picker ───────────────────────────────────────

func _pick_weighted(pool: Array, rarity: int, item_level: int, already_rolled: Array) -> Resource:
	# Filter: gated by rarity + item_level, exclude ids already rolled.
	var candidates: Array = []
	var total_weight: float = 0.0
	var rolled_ids: Array = []
	for r in already_rolled:
		rolled_ids.append(r.id)
	for a in pool:
		if a.min_rarity > rarity:
			continue
		if a.min_item_level > item_level:
			continue
		if a.id in rolled_ids:
			continue
		candidates.append(a)
		total_weight += a.weight
	if candidates.is_empty() or total_weight <= 0.0:
		return null
	var r: float = randf() * total_weight
	for a in candidates:
		r -= a.weight
		if r <= 0.0:
			return a
	return candidates.back()

# ─── Seeded affix catalog ────────────────────────────────────────────
# Naming convention:
#   Prefixes: single adjective ("Burning", "Wrathful", "Heavy")
#   Suffixes: "of <thing>" already-formatted ("of Cleaving", "of the Bear")
# Lower min_rarity = more common. Higher weight = more frequent within tier.

func _seed_prefixes() -> void:
	# Tier 1: low-level common prefixes (rare+ minimum)
	prefixes.append(_pre(&"sturdy",     "Sturdy",     {"armor_bonus": 8.0},                     1, 2, 5.0))
	prefixes.append(_pre(&"sharp",      "Sharp",      {"damage_bonus_pct": 0.06},               1, 2, 5.0))
	prefixes.append(_pre(&"swift",      "Swift",      {"attack_speed_bonus": 0.08},             1, 2, 4.0))
	prefixes.append(_pre(&"vital",      "Vital",      {"hp_bonus": 25.0},                       1, 2, 5.0))
	prefixes.append(_pre(&"warded",     "Warded",     {"magic_resist_bonus": 8.0},              3, 2, 4.0))
	prefixes.append(_pre(&"keen",       "Keen",       {"crit_chance_bonus": 0.04},              5, 2, 4.0))
	# Tier 2: rare+ only
	prefixes.append(_pre(&"burning",    "Burning",    {"damage_bonus_pct": 0.10, "resist_fire": 0.10},  8, 3, 3.0))
	prefixes.append(_pre(&"frozen",     "Frozen",     {"damage_bonus_pct": 0.10, "resist_frost": 0.10}, 8, 3, 3.0))
	prefixes.append(_pre(&"wrathful",   "Wrathful",   {"crit_multiplier_bonus": 0.20},          10, 3, 2.5))
	prefixes.append(_pre(&"heavy",      "Heavy",      {"strength_bonus": 8.0, "damage_bonus_pct": 0.05}, 6, 3, 3.0))
	# Tier 3: very_rare+ only
	prefixes.append(_pre(&"thundering", "Thundering", {"damage_bonus_pct": 0.15, "crit_chance_bonus": 0.05}, 15, 4, 1.5))
	prefixes.append(_pre(&"radiant",    "Radiant",    {"resist_holy": 0.20, "hp_bonus": 60.0},  18, 4, 1.5))
	# Tier 4: legendary only
	prefixes.append(_pre(&"world-eater", "World-Eater", {"damage_bonus_pct": 0.25, "crit_multiplier_bonus": 0.35}, 25, 5, 0.8))

func _seed_suffixes() -> void:
	# Tier 1: common
	suffixes.append(_suf(&"of_the_bear",   "of the Bear",   {"strength_bonus": 6.0},       1, 2, 5.0))
	suffixes.append(_suf(&"of_the_wolf",   "of the Wolf",   {"dexterity_bonus": 6.0},      1, 2, 5.0))
	suffixes.append(_suf(&"of_the_scribe", "of the Scribe", {"intellect_bonus": 6.0},      1, 2, 5.0))
	suffixes.append(_suf(&"of_the_ox",     "of the Ox",     {"vitality_bonus": 6.0},       1, 2, 5.0))
	suffixes.append(_suf(&"of_warding",    "of Warding",    {"magic_resist_bonus": 6.0},   3, 2, 4.0))
	suffixes.append(_suf(&"of_haste",      "of Haste",      {"move_speed_bonus": 0.05},    5, 2, 3.5))
	# Tier 2: rare
	suffixes.append(_suf(&"of_cleaving",   "of Cleaving",   {"damage_bonus_pct": 0.12},    8, 3, 3.0))
	suffixes.append(_suf(&"of_precision",  "of Precision",  {"crit_chance_bonus": 0.06, "crit_multiplier_bonus": 0.12}, 10, 3, 2.5))
	suffixes.append(_suf(&"of_endurance",  "of Endurance",  {"hp_bonus": 50.0, "vitality_bonus": 5.0}, 8, 3, 3.0))
	suffixes.append(_suf(&"of_the_flame",  "of the Flame",  {"resist_fire": 0.15, "damage_bonus_pct": 0.08}, 12, 3, 2.5))
	# Tier 3: very_rare
	suffixes.append(_suf(&"of_the_void",   "of the Void",   {"resist_shadow": 0.20, "damage_bonus_pct": 0.10}, 18, 4, 1.5))
	suffixes.append(_suf(&"of_kings",      "of Kings",      {"hp_bonus": 100.0, "armor_bonus": 15.0}, 20, 4, 1.5))
	# Tier 4: legendary
	suffixes.append(_suf(&"of_the_dragon", "of the Dragon", {"damage_bonus_pct": 0.20, "crit_chance_bonus": 0.08, "resist_fire": 0.15}, 28, 5, 0.8))

# ─── Builders (compact) ──────────────────────────────────────────────

func _pre(id: StringName, name_part: String, bonuses: Dictionary, min_il: int, min_rar: int, w: float) -> Resource:
	var a: Resource = AffixRes.new()
	a.id = id
	a.name_part = name_part
	a.kind = 0  # PREFIX
	a.bonuses = bonuses
	a.min_item_level = min_il
	a.min_rarity = min_rar
	a.weight = w
	return a

func _suf(id: StringName, name_part: String, bonuses: Dictionary, min_il: int, min_rar: int, w: float) -> Resource:
	var a: Resource = AffixRes.new()
	a.id = id
	a.name_part = name_part
	a.kind = 1  # SUFFIX
	a.bonuses = bonuses
	a.min_item_level = min_il
	a.min_rarity = min_rar
	a.weight = w
	return a
