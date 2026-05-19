extends Resource
class_name Affix

# A single rolled modifier on an Item. Prefixes go in front of the item's
# base name ("Burning Bronze Sword"), suffixes go after ("Bronze Sword of
# Cleaving"). An item can carry one prefix + one suffix at minimum; rarer
# items stack multiple prefixes and/or suffixes per the table:
#
#   Common (green):    1 affix  (50/50 prefix vs suffix)
#   Rare (blue):       2 affixes (1 prefix + 1 suffix)
#   Very Rare (purple): 3 affixes (1-2 prefixes + 1-2 suffixes)
#   Legendary (gold):  4 affixes + unique mechanic (class-bound)
#
# Each affix has:
#   - A modifier dictionary mapping Item field names to bonus values that
#     get ADDED to the item's base stats at equip time. The Affix doesn't
#     mutate the item; it's an additive layer the equip path applies.
#   - A min item_level so low-tier items can't roll endgame affixes.
#   - A weight for the roller (higher = more common).
#   - A min rarity tier (some affixes only roll on Rare+, e.g.
#     +1 to ability rank, lifesteal, etc).
#
# Use AffixRegistry.roll_for_rarity(item, rarity, item_level) to draw a
# valid set of affixes for a drop.

enum Kind { PREFIX, SUFFIX }

@export var id: StringName = &""
# Word that goes in the formatted item name. Prefix: "Burning". Suffix:
# "of Cleaving" (i.e., already include the "of " when authoring suffixes
# so the formatter just concatenates).
@export var name_part: String = ""
@export var kind: Kind = Kind.PREFIX

# Bonuses additive on equip. Keyed by Item @export field name. Values
# are applied as flat additions; the equip path translates these onto the
# wielder's stat bonuses. Examples:
#   {"crit_chance_bonus": 0.05}   -> +5% crit chance
#   {"strength_bonus": 12.0}       -> +12 strength
#   {"resist_fire": 0.10}          -> +10% fire resistance
#   {"damage_bonus_pct": 0.08}     -> +8% all outgoing damage
@export var bonuses: Dictionary = {}

# Tooltip line (UI shows this under the item name). Auto-generated if
# blank, by reading the bonuses dict.
@export var tooltip: String = ""

# Gating
@export var min_item_level: int = 1
@export var min_rarity: int = 1   # 1=BASIC, 2=COMMON, 3=RARE, 4=VERY_RARE, 5=LEGENDARY
@export var weight: float = 1.0

# Render the affix as a tooltip line. If `tooltip` was authored explicitly,
# return that; otherwise auto-format from the bonuses dict.
func format_tooltip() -> String:
	if tooltip != "":
		return tooltip
	var parts: Array[String] = []
	for stat in bonuses:
		var v: float = float(bonuses[stat])
		var stat_name := String(stat)
		# Convert "_bonus" / "_pct" suffixes and percentages
		var label: String = stat_name.replace("_bonus", "").replace("_", " ").capitalize()
		var sign: String = "+" if v >= 0 else ""
		if stat_name.ends_with("_pct") or stat_name.ends_with("_chance_bonus") or stat_name.begins_with("resist_"):
			parts.append("%s%d%% %s" % [sign, int(v * 100.0), label])
		else:
			parts.append("%s%d %s" % [sign, int(v), label])
	return ", ".join(parts)
