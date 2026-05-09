extends Node

# LootGenerator, autoload that builds a LootTable for any Mob on demand.
# Lets us avoid hand-authoring a unique loot_table for every mob in the
# game. The generator picks items from ItemRegistry filtered by:
#
#   - mob's home_zone (level range matches)
#   - mob's role (elites get rarer drops, archers favor ranged gear)
#   - mob's tags (humans drop swords/armor, undead drop bones, etc)
#
# Cached per mob_id so the table is only built once per mob type.
#
# Usage:
#   var lt = LootGenerator.for_mob(mob)
#   var drops = lt.roll(prestige_level)
#
# Used by Spawner._spawn_one which now installs the generated table on
# the spawned EnemyBase before adding it to the tree.

var _cache: Dictionary = {}  # mob_id -> LootTable

# Drop chance per role: elites and bosses drop more frequently.
const ROLE_DROP_CHANCE := {
	0: 0.55,  # GRUNT
	1: 0.45,  # ARCHER (lighter loot)
	2: 0.50,  # CASTER
	3: 0.85,  # ELITE
	4: 0.50,  # RUSHER
	5: 0.50,  # SUPPORT
	6: 0.75,  # SUMMONER
	7: 0.45,  # SCOUT
}

# Rarity weight curve. Higher mob level shifts weight toward higher rarities.
const BASE_RARITY_WEIGHTS := {
	0: 5.0,   # JUNK
	1: 60.0,  # BASIC
	2: 30.0,  # COMMON
	3: 4.0,   # RARE
	4: 0.9,   # VERY_RARE
	5: 0.1,   # LEGENDARY
}

func for_mob(mob: Mob) -> LootTable:
	if mob == null:
		return null
	if _cache.has(mob.id):
		return _cache[mob.id]
	var lt := _build_table(mob)
	_cache[mob.id] = lt
	return lt

func _build_table(mob: Mob) -> LootTable:
	var lt := LootTable.new()
	var registry: Node = get_node_or_null("/root/ItemRegistry")
	if registry == null:
		return lt

	# Drop chance scales with role
	lt.base_drop_chance = ROLE_DROP_CHANCE.get(int(mob.role), 0.5)

	# Pull all items in the mob's level band, +/- 4 levels for variety
	var min_il: int = max(1, mob.min_level - 2)
	var max_il: int = mob.max_level + 4

	# Always include a small chance of consumables (potions) regardless of zone
	_seed_consumables(lt, registry)

	# Weapon and armor pools filtered to the mob's level range
	for entry: Item in registry.items.values():
		if entry == null:
			continue
		if entry.item_level < min_il or entry.item_level > max_il:
			continue
		# skip class-restricted items unless the mob's role suggests them
		if entry.class_restriction.size() > 0:
			continue  # generic mobs don't drop class-locked gear; bosses unique-drop those
		# skip unique drop sources unless this mob is the source
		if entry.unique_drop_source != &"" and entry.unique_drop_source != mob.id:
			continue
		var weight: float = _weight_for_item(entry, mob)
		if weight <= 0.0:
			continue
		lt.add_entry(entry, weight)

	# Elites: bias toward rarer drops by adding a guaranteed RARE+ pick
	if mob.role == 3:  # ELITE
		var rare := _pick_random_in_range(registry, 3, min_il, max_il)
		if rare:
			lt.guaranteed_drops.append(rare)

	# Bosses (encoded as ELITE + boss_tag in BossBase) handled separately
	# via boss-specific tables.
	return lt

func _seed_consumables(lt: LootTable, registry: Node) -> void:
	# Small chance of a health potion per kill so combat keeps refilling
	var hp_pot: Item = registry.items.get(&"potion_health_minor")
	if hp_pot:
		lt.add_entry(hp_pot, 8.0)
	var mana_pot: Item = registry.items.get(&"potion_mana_minor")
	if mana_pot:
		lt.add_entry(mana_pot, 4.0)

# Higher rarity = lower weight. Higher mob level shifts the curve up.
func _weight_for_item(item: Item, mob: Mob) -> float:
	var base: float = BASE_RARITY_WEIGHTS.get(int(item.rarity), 1.0)
	# Level scaling: at level 30+ rare items are ~3x more likely
	var lvl_scale: float = 1.0 + max(0, mob.max_level - 5) * 0.05 * float(item.rarity)
	return base * lvl_scale

func _pick_random_in_range(registry: Node, rarity: int, min_il: int, max_il: int) -> Item:
	var pool: Array[Item] = []
	for entry: Item in registry.items.values():
		if entry == null:
			continue
		if int(entry.rarity) != rarity:
			continue
		if entry.item_level < min_il or entry.item_level > max_il:
			continue
		if entry.class_restriction.size() > 0:
			continue
		pool.append(entry)
	if pool.is_empty():
		return null
	return pool[randi() % pool.size()]
