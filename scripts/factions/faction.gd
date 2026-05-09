extends Resource
class_name Faction

# A faction the player can earn reputation with. Faction rep is stored per-
# character via SaveFlags as int values (negative = enemy direction, positive
# = ally direction). FactionRegistry maps the rep value to a tier name.
#
# Tier breakpoints are deliberately WoW-standard so players already know how
# to read the bar shape:
#   Hated     [-42000, -6000)
#   Hostile   [-6000, -3000)
#   Unfriendly [-3000, 0)
#   Neutral   [0, 3000)
#   Friendly  [3000, 9000)
#   Honored   [9000, 21000)
#   Revered   [21000, 42000)
#   Exalted   [42000, +inf)

@export var faction_id: StringName = &""
@export var display_name: String = ""
@export_multiline var description: String = ""
@export var color: Color = Color.WHITE
@export var motif: String = ""  # short Unicode glyph for the panel badge

# Some factions have a starting rep adjustment. Crown is friendly to most
# classes by default; Druids of the Wound start neutral but shift fast.
@export var starting_rep: int = 0
