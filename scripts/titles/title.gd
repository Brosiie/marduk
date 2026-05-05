extends Resource
class_name Title

# A name-modifier earned through achievements. Player can equip one at a time.
# Displayed in nameplate above character name.
#
# Format options:
#   PREFIX: "the Untouched" -> "Brandon, the Untouched"
#   SUFFIX: "Mother-Slayer" -> "Mother-Slayer Brandon"  (less common)
#   FULL_REPLACE: title becomes the visible name (rare, only for top-tier feats)

enum Format { PREFIX, SUFFIX, FULL_REPLACE }

@export var id: StringName = &""
@export var display_text: String = ""  # the actual text shown
@export var format: Format = Format.PREFIX
@export var color: Color = Color(0.95, 0.85, 0.55)
@export_multiline var description: String = ""  # how earned
@export_multiline var lore: String = ""           # in-world flavor

@export var is_secret: bool = false  # only seen if equipped, hidden in selector otherwise
