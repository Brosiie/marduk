extends Resource
class_name SoulBinding

# A character can bind ONE weapon and ONE armor piece for life. Bound items
# fuse to the character: cannot be dropped, cannot be lost, scale with player
# level (auto item_level = player.level), and visually never unequip from
# their slot (the bound katana hilt protrudes from the bare forearm bone
# when "sheathed", the binding is part of the body now).
#
# Binding cost: 5 same-slot items sacrificed at the altar in Ashurim. The
# sacrificed items are consumed; their lore-text is inscribed on the binding
# (the bound item carries the names of what made it).
#
# See CHARACTER_DESIGN.md § 8.5.4.

# Bound weapon, the soul-bound mainhand. Item.id reference.
@export var weapon_item_id: StringName = &""
@export var weapon_bound_at_unix: int = 0

# Bound armor, the soul-bound chest piece (Tier 1 supports CHEST only;
# Tier 2 expands to per-slot bindings).
@export var armor_item_id: StringName = &""
@export var armor_bound_at_unix: int = 0

# Sacrifice ledger: ids of items consumed during the binding ritual.
# Inscribed on the bound item's lore text and queried by the Inkstone Sage
# for the Sage's chronicle ("You bound your blade with these five names...").
@export var weapon_sacrifice_ledger: Array[StringName] = []
@export var armor_sacrifice_ledger: Array[StringName] = []

func has_weapon_binding() -> bool:
	return weapon_item_id != &""

func has_armor_binding() -> bool:
	return armor_item_id != &""

func sacrifice_count_for(slot: int) -> int:
	# Slot.WEAPON_MAIN = 1, Slot.CHEST = 4, matches Item.Slot enum
	if slot == 1:
		return weapon_sacrifice_ledger.size()
	if slot == 4:
		return armor_sacrifice_ledger.size()
	return 0

func record_weapon_binding(item_id: StringName, sacrifices: Array[StringName]) -> void:
	weapon_item_id = item_id
	weapon_bound_at_unix = int(Time.get_unix_time_from_system())
	weapon_sacrifice_ledger = sacrifices.duplicate()

func record_armor_binding(item_id: StringName, sacrifices: Array[StringName]) -> void:
	armor_item_id = item_id
	armor_bound_at_unix = int(Time.get_unix_time_from_system())
	armor_sacrifice_ledger = sacrifices.duplicate()
