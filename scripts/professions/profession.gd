extends Resource
class_name Profession

# Per-profession definition. The four professions in Marduk:
#   - Smithing    (forge weapons + armor from ingots)
#   - Mining      (gather ore from rock nodes)
#   - Woodcutting (gather wood from tree nodes)
#   - Crafting    (combine raw materials into consumables, charms, accessories)
#
# Each levels independently 1-100, parallel to character level.

enum Kind { SMITHING, MINING, WOODCUTTING, CRAFTING }

const MAX_LEVEL := 100

@export var id: StringName = &""
@export var display_name: String = ""
@export var kind: Kind = Kind.MINING
@export_multiline var description: String = ""
@export var icon: Texture2D
@export var primary_color: Color = Color.WHITE

# Recipes the player can learn at this profession (for crafting kinds).
# Gathering kinds (mining/woodcutting) reference no recipes; instead they consume
# nodes in the world and award XP per gather attempt.
@export var recipes: Array[Recipe] = []
