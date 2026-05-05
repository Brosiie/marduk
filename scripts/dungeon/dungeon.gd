extends Resource
class_name Dungeon

# A discrete dungeon: gated entry, scaled mob list, named boss, story.
# Distinct from a Zone (open-roam region). Dungeons are entered from a Zone
# and have their own scene + level scaling + completion flag.

enum Tier {
	TUTORIAL,    # lvl 1-10, low difficulty, tells lore
	NORMAL,      # standard, level-matches recommendation
	HEROIC,      # repeatable, harder mob layout, better drops
	MYTHIC       # endgame, fixed-level cap, prestige-scaled
}

@export var id: StringName = &""
@export var display_name: String = ""
@export_multiline var lore: String = ""
@export_multiline var ambient_description: String = ""  # shown on entry
@export var entry_zone: StringName = &""               # zone the entrance lives in
@export var scene_path: String = "res://scenes/world/placeholder.tscn"
@export var min_level: int = 1
@export var recommended_level: int = 1
@export var max_level: int = 100  # mob ceiling
@export var tier: Tier = Tier.NORMAL
@export var encounter_table: Array[StringName] = []   # mob ids
@export var boss_id: StringName = &""                 # BossRegistry boss
@export var completion_flag: StringName = &""         # set when boss falls
@export var unique_drop_table: Array[StringName] = []  # special items only here

# Atmosphere
@export var music_track: String = ""
@export var ambient_color: Color = Color(0.4, 0.4, 0.5)
@export var fog_color: Color = Color(0.2, 0.2, 0.3)
