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
		results.append(it)

	# Boss guarantee: at least one VERY_RARE in the result
	if guarantees_very_rare:
		var vr := _pick_first_of_rarity(Item.Rarity.VERY_RARE)
		if vr:
			results.append(vr)

	# Roll the chance gate (with prestige amplification)
	var effective_chance := min(1.0, base_drop_chance * (1.0 + float(prestige_level)))
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
				results.append(e.item)
				break

	return results

func _pick_first_of_rarity(rarity: int) -> Item:
	for e: Entry in entries:
		if e.item and e.item.rarity == rarity:
			return e.item
	return null
