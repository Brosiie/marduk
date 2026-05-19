extends Resource
class_name LootTable

# Drop table for an enemy or container. Supports weighted entries with rarity tiers.
# Prestige multiplier feeds in via Prestige.loot_multiplier() and Prestige.bonus_loot_rolls().

class Entry:
	var item: Item
	var weight: float = 1.0
	var min_count: int = 1
	var max_count: int = 1
	var rarity_floor: int = 0  # Item.Rarity minimum (for affix rolling)

@export var entries: Array = []  # of Entry  (use add_entry helper to append)
@export var base_drop_chance: float = 0.65  # 0.0-1.0, chance any drop happens at all
@export var guaranteed_drops: Array[Item] = []  # always drop, ignore chance
@export var guarantees_very_rare: bool = false  # bosses set this true

func add_entry(item: Item, weight: float, min_count: int = 1, max_count: int = 1) -> void:
	var e := Entry.new()
	e.item = item
	e.weight = weight
	e.min_count = min_count
	e.max_count = max_count
	entries.append(e)

func roll(prestige_level: int = 0) -> Array[Item]:
	var results: Array[Item] = []

	# Guaranteed drops
	for it in guaranteed_drops:
		results.append(_with_affixes(it))

	# Boss guarantee: at least one VERY_RARE in the result
	if guarantees_very_rare:
		var vr := _pick_first_of_rarity(Item.Rarity.VERY_RARE)
		if vr:
			results.append(_with_affixes(vr))

	# Roll the chance gate (with prestige amplification)
	var effective_chance: float = min(1.0, base_drop_chance * (1.0 + float(prestige_level)))
	if randf() >= effective_chance:
		return results

	# Weighted selection
	var total_weight := 0.0
	for e: Entry in entries:
		total_weight += e.weight
	if total_weight <= 0.0:
		return results

	var rolls := 1 + prestige_level  # one extra roll per prestige tier
	for _i in range(rolls):
		var r := randf() * total_weight
		var acc := 0.0
		for e: Entry in entries:
			acc += e.weight
			if r <= acc:
				results.append(_with_affixes(e.item))
				break

	return results

func _pick_first_of_rarity(rarity: int) -> Item:
	for e: Entry in entries:
		if e.item and e.item.rarity == rarity:
			return e.item
	return null

# Duplicate the base item and stamp rolled affixes onto the copy. The
# ItemRegistry's base Item stays untouched so every drop carries its own
# independent affix roll. Skips rolling for JUNK/BASIC rarity (those drop
# without affixes by design), and for soulbound/quest items so Heaven,
# prologue items, etc. stay canonical.
func _with_affixes(base: Item) -> Item:
	if base == null:
		return base
	if int(base.rarity) < int(Item.Rarity.COMMON):
		return base
	if base.is_soulbound or base.is_quest_item:
		return base
	var ml: SceneTree = Engine.get_main_loop() as SceneTree
	if ml == null or ml.root == null:
		return base
	var reg: Node = ml.root.get_node_or_null("AffixRegistry")
	if reg == null or not reg.has_method("roll_for_rarity"):
		return base
	var rolled: Array = reg.roll_for_rarity(base, int(base.rarity), base.item_level)
	if rolled.is_empty():
		return base
	var copy: Item = base.duplicate(true) as Item
	for affix in rolled:
		if affix == null:
			continue
		# Affix.Kind.PREFIX = 0, SUFFIX = 1
		if int(affix.kind) == 0:
			copy.prefix_affixes.append(affix.id)
		else:
			copy.suffix_affixes.append(affix.id)
	# Recompute display_name so the tooltip / inventory shows the affixed
	# name like "Burning Bronze Sword of Cleaving" instead of the base
	# "Bronze Sword".
	if reg.has_method("format_item_name"):
		copy.display_name = reg.format_item_name(copy)
	return copy
