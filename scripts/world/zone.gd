extends Resource
class_name Zone

# A discrete region of the world. Loaded as its own scene.
# Connections form the world graph. Gating uses SaveFlags.

enum SafetyTier {
	HUB,        # cities and main towns - full safety, vendors, fast travel anchors
	SAFE,       # small towns, outposts - safe, limited services
	WILD,       # contested - mobs, hostile spawns, normal play zone
	HOSTILE,    # high mob density - dungeons, contested ruins
	BOSS        # boss arena - one-way until cleared
}

enum Region {
	CRADLE,         # starter region (class intros + Ashurim)
	IRON_CROWN,     # Babilim metropolis and immediate surroundings
	REED_WASTES,    # cracked plains, demon incursions
	LAPIS_BAY,      # coastal kingdom, pirate-held islands
	BONE_MOUNTAINS, # ancient ruins, stone-breathing dojo, ossuaries
	VERDANT_WOUND,  # corrupted forest, druid sanctum, beast lairs
	EMBER_STEPPES,  # volcanic plains, fire temples, bandits
	MIST_VALE,      # fog-locked vale, mist temple, illusion-fields
	SHRIEKING_HIGHLANDS, # storm peaks, thunder dojo
	SUNDERED_COAST, # Tiamat's spawn nesting grounds, drowned ruins
	BLACK_CITADEL,  # Tiamat's seat, climactic dungeon stack
	SUN_GATE,       # post-Tiamat hidden passage
	FIRE_STAIR,     # Lucifer's domain, secret final boss
	ASCENSION_PLANE # prestige-only zone, NG+ rewards
}

@export var id: StringName = &""
@export var display_name: String = ""
@export_multiline var lore: String = ""

@export_group("World Graph")
@export var region: Region = Region.CRADLE
@export var safety: SafetyTier = SafetyTier.WILD
@export var connections: Array[StringName] = []  # zone ids reachable from here

@export_group("Level Scaling")
@export var min_level: int = 1
@export var max_level: int = 5
@export var recommended_level: int = 1

@export_group("Scene")
@export var scene_path: String = "res://scenes/world/placeholder.tscn"
@export var spawn_point_node: NodePath  # default spawn within scene
@export var thumbnail: Texture2D

@export_group("Atmosphere")
@export var music_track: String = ""
@export var ambient_color: Color = Color(0.5, 0.5, 0.6)
@export var fog_color: Color = Color(0.4, 0.3, 0.4)
@export var fog_density: float = 0.012
@export var sun_color: Color = Color(1.0, 0.85, 0.7)

@export_group("Gating")
@export var required_permanent_flag: StringName = &""  # eg &"sun_breathing_unlocked" for Sun Gate
@export var required_run_flag: StringName = &""        # eg &"tiamat_defeated" if cycle-only
@export var blocks_after_run_flag: StringName = &""    # eg Black Citadel sealed after Tiamat falls (this cycle)
@export_multiline var lock_hint: String = ""

@export_group("Encounters")
@export var encounter_table: Array[StringName] = []  # enemy ids that spawn here
@export var ambient_spawn_density: float = 0.0  # mobs per 100 sq m

@export_group("Class Intro Tag")
@export var is_class_intro: bool = false
@export var intro_for_class: StringName = &""  # eg &"berserker"

func recommended_label() -> String:
	if min_level == max_level:
		return "Lv %d" % min_level
	return "Lv %d-%d" % [min_level, max_level]

func is_under_leveled(player_level: int) -> bool:
	return player_level < min_level

func is_over_leveled(player_level: int) -> bool:
	return player_level > max_level + 5  # 5-level grace before "trivial" warning
