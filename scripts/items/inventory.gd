extends Resource
class_name Inventory

# Player inventory. Grid-based with stack support. Equipment slots are separate and indexed.

const MAX_BAG_SLOTS := 64

class Stack:
	var item: Item
	var count: int = 1

@export var bag: Array = []  # of Stack
@export var equipped: Dictionary = {}  # Item.Slot -> Stack (count always 1)
@export var gold: int = 0

signal inventory_changed
signal equipment_changed(slot: int, item: Item)
signal gold_changed(new_total: int)

func add_item(item: Item, count: int = 1) -> int:
	# Returns leftover count that didn't fit.
	if not item:
		return count
	if item.stack_size > 1:
		for s: Stack in bag:
			if s.item.id == item.id and s.count < item.stack_size:
				var space: int = item.stack_size - s.count
				var add: int = min(space, count)
				s.count += add
				count -= add
				if count <= 0:
					inventory_changed.emit()
					return 0
	while count > 0 and bag.size() < MAX_BAG_SLOTS:
		var s := Stack.new()
		s.item = item
		s.count = min(count, item.stack_size)
		count -= s.count
		bag.append(s)
	inventory_changed.emit()
	return count

func remove_item(item_id: StringName, count: int = 1) -> int:
	# Returns how many were actually removed.
	var removed := 0
	for s: Stack in bag.duplicate():
		if s.item.id == item_id:
			var take: int = min(count - removed, s.count)
			s.count -= take
			removed += take
			if s.count <= 0:
				bag.erase(s)
			if removed >= count:
				break
	if removed > 0:
		inventory_changed.emit()
	return removed

func count_of(item_id: StringName) -> int:
	var n := 0
	for s: Stack in bag:
		if s.item.id == item_id:
			n += s.count
	return n

signal equip_blocked(item: Item, reason: String)

# Class-aware equip check. Returns true if the item passes:
#   - class_restriction (if any)
#   - armor_type vs class.max_armor_type (only for armor slots)
#   - weapon_type proficiency (no hard restriction; off-class is allowed but penalized)
func can_equip(item: Item, class_def: PlayerClass) -> Dictionary:
	if not item:
		return {"ok": false, "reason": "no item"}
	if item.class_restriction.size() > 0 and class_def:
		if not (class_def.class_id in item.class_restriction):
			return {"ok": false, "reason": "Class cannot wield: %s" % item.display_name}
	if item.armor_type != Item.ArmorType.NONE and class_def:
		if item.armor_type > class_def.max_armor_type:
			return {"ok": false, "reason": "Armor too heavy for class (cap: %s)" % _armor_type_name(class_def.max_armor_type)}
	return {"ok": true, "reason": ""}

func _armor_type_name(at: int) -> String:
	match at:
		Item.ArmorType.CLOTH: return "Cloth"
		Item.ArmorType.LEATHER: return "Leather"
		Item.ArmorType.MAIL: return "Mail"
		Item.ArmorType.PLATE: return "Plate"
		_: return "None"

func equip(item: Item, slot_override: int = -1, class_def: PlayerClass = null) -> Item:
	# Returns previously-equipped item (caller puts it in bag).
	# slot_override: pass RING_LEFT or RING_RIGHT explicitly when equipping a ring.
	# class_def: when non-null, enforces class restriction and armor type cap.
	if not item or item.slot == Item.Slot.NONE:
		return null

	if class_def:
		var check: Dictionary = can_equip(item, class_def)
		if not check["ok"]:
			equip_blocked.emit(item, check["reason"])
			return null

	var target_slot: int = slot_override if slot_override >= 0 else item.slot

	# Two-handed: equipping a 2H weapon must clear the off-hand.
	# Equipping any off-hand while a 2H is held must clear the 2H.
	var prev: Item = null
	if target_slot == Item.Slot.WEAPON_MAIN and item.is_two_handed:
		if equipped.has(Item.Slot.WEAPON_OFFHAND):
			# Drop offhand back to bag if there is room
			var ofh: Item = equipped[Item.Slot.WEAPON_OFFHAND].item
			equipped.erase(Item.Slot.WEAPON_OFFHAND)
			equipment_changed.emit(Item.Slot.WEAPON_OFFHAND, null)
			add_item(ofh, 1)
	elif target_slot == Item.Slot.WEAPON_OFFHAND:
		var main: Item = equipped[Item.Slot.WEAPON_MAIN].item if equipped.has(Item.Slot.WEAPON_MAIN) else null
		if main and main.is_two_handed:
			equipped.erase(Item.Slot.WEAPON_MAIN)
			equipment_changed.emit(Item.Slot.WEAPON_MAIN, null)
			add_item(main, 1)

	if equipped.has(target_slot):
		prev = equipped[target_slot].item

	var s := Stack.new()
	s.item = item
	s.count = 1
	equipped[target_slot] = s
	equipment_changed.emit(target_slot, item)
	return prev

func equip_ring(item: Item) -> Item:
	# Convenience: prefers the empty ring slot, otherwise replaces RING_LEFT.
	if item.slot != Item.Slot.RING_LEFT and item.slot != Item.Slot.RING_RIGHT:
		return null
	if not equipped.has(Item.Slot.RING_LEFT):
		return equip(item, Item.Slot.RING_LEFT)
	if not equipped.has(Item.Slot.RING_RIGHT):
		return equip(item, Item.Slot.RING_RIGHT)
	return equip(item, Item.Slot.RING_LEFT)

func unequip(slot: int) -> Item:
	if not equipped.has(slot):
		return null
	var prev: Item = equipped[slot].item
	equipped.erase(slot)
	equipment_changed.emit(slot, null)
	return prev

func equipped_in(slot: int) -> Item:
	if not equipped.has(slot):
		return null
	return equipped[slot].item

# Aggregate equipment bonuses for stat application
func aggregate_bonuses() -> Dictionary:
	var total := {
		"hp": 0.0, "mana": 0.0,
		"str": 0.0, "dex": 0.0, "int": 0.0, "vit": 0.0,
		"armor": 0.0, "mr": 0.0,
		"crit_chance": 0.0, "crit_mult": 0.0,
		"damage_pct": 0.0
	}
	for s in equipped.values():
		var it: Item = s.item
		total["hp"] += it.hp_bonus
		total["mana"] += it.mana_bonus
		total["str"] += it.strength_bonus
		total["dex"] += it.dexterity_bonus
		total["int"] += it.intellect_bonus
		total["vit"] += it.vitality_bonus
		total["armor"] += it.armor_bonus
		total["mr"] += it.magic_resist_bonus
		total["crit_chance"] += it.crit_chance_bonus
		total["crit_mult"] += it.crit_multiplier_bonus
		total["damage_pct"] += it.damage_bonus_pct
	return total

func add_gold(amount: int) -> void:
	gold = max(0, gold + amount)
	gold_changed.emit(gold)
