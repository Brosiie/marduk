extends Resource
class_name Landmark

# A point of interest in the world: ruin, monument, hidden grove, named tree.
# Approaching one (within examine_radius) lets the player examine it; the lore
# string fires once and is recorded as a permanent flag, granting XP and
# possibly an achievement (LANDMARK_EXAMINED).

enum Kind { RUIN, MONUMENT, GRAVE, TREE, WELL, ALTAR, GATE, BATTLEFIELD, OBSERVATION, OTHER }

@export var id: StringName = &""
@export var display_name: String = ""
@export var zone_id: StringName = &""
@export var kind: Kind = Kind.RUIN
@export_multiline var lore_on_discover: String = ""  # the prose shown when found
@export_multiline var inscription: String = ""        # short inline text (carved/written on the landmark)
@export var examine_radius: float = 4.0
@export var xp_reward: int = 100
@export var unlocks_achievement_id: StringName = &""
