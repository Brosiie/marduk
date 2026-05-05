extends Node

# Autoload: 14 dungeons, one or more per region, each with its own mini-story.
# Distinct from open-zone bosses; dungeons are run-and-clear instances.

var dungeons: Dictionary = {}  # StringName -> Dungeon

func _ready() -> void:
	_register_iron_crown_dungeons()
	_register_reed_wastes_dungeons()
	_register_lapis_bay_dungeons()
	_register_bone_mountains_dungeons()
	_register_verdant_wound_dungeons()
	_register_ember_steppes_dungeons()
	_register_mist_vale_dungeons()
	_register_shrieking_highlands_dungeons()
	_register_sundered_coast_dungeons()
	_register_endgame_dungeons()

func get_dungeon(id: StringName) -> Dungeon:
	return dungeons.get(id)

func dungeons_in_zone(zone: StringName) -> Array[Dungeon]:
	var arr: Array[Dungeon] = []
	for d: Dungeon in dungeons.values():
		if d.entry_zone == zone:
			arr.append(d)
	return arr

func _make(id: StringName, name: String, lore: String, amb: String,
		entry_zone: StringName, min_lvl: int, rec: int, tier: int,
		boss_id: StringName, encounter: Array, music: String = "") -> Dungeon:
	var d := Dungeon.new()
	d.id = id
	d.display_name = name
	d.lore = lore
	d.ambient_description = amb
	d.entry_zone = entry_zone
	d.min_level = min_lvl
	d.recommended_level = rec
	d.max_level = rec + 5
	d.tier = tier
	d.boss_id = boss_id
	for e in encounter:
		d.encounter_table.append(StringName(e))
	d.completion_flag = StringName("dungeon_cleared_" + String(id))
	d.music_track = music
	dungeons[id] = d
	return d

# ----------------------------------------------------------------
# Iron Crown Outskirts dungeons
# ----------------------------------------------------------------
func _register_iron_crown_dungeons() -> void:
	_make(&"caravan_pit", "The Caravan Pit",
		"A bandit camp dug into a collapsed caravan road. The brigands have lined the walls with the wagons of the people they have killed.",
		"You descend into the pit by a rope-ladder. The smell of woodsmoke is heavy. Somewhere below, a wheel still creaks in the wind.",
		&"iron_crown_outskirts", 6, 9, Dungeon.Tier.TUTORIAL,
		&"caravan_butcher", [&"caravan_brigand", &"escaped_temple_slave"])

	_make(&"pillar_underchamber", "The Pillar Underchamber",
		"Beneath Babilim's Iron Pillar, a sealed room older than Babilim itself. The Crown denies it exists. The Crown denies most things.",
		"You descend a stair carved into the pillar's foundation. The stone is warm. The script on the walls is in a language Marduk's edict does not include.",
		&"babilim", 8, 12, Dungeon.Tier.NORMAL,
		&"escaped_temple", [&"binding_construct", &"animated_book"])

# ----------------------------------------------------------------
# Reed Wastes dungeons
# ----------------------------------------------------------------
func _register_reed_wastes_dungeons() -> void:
	_make(&"failed_seal_one", "The Failed Seal at Mu-Ash",
		"A pinhole crack in one of Marduk's seven seals, here in the wastes. Demons trickle through, slowly, on their own schedule.",
		"You can hear the seal cracking, even from outside. The reeds bend toward the sound. You step through and the wind goes still.",
		&"reed_wastes", 14, 17, Dungeon.Tier.NORMAL,
		&"failed_seal", [&"reed_creeper", &"salt_demon", &"thirst-spirit"])

	_make(&"wastes_pilgrim_road", "The Pilgrim's Road",
		"A buried pilgrim road from before the marsh dried. The pilgrims who walked it never finished the journey. Some are still walking.",
		"You descend into a sunken trench. Bones line both sides, set in patterns that look like prayer.",
		&"reed_wastes", 16, 19, Dungeon.Tier.NORMAL,
		&"wastes_shaman", [&"wastes_walker", &"thirst-spirit", &"reed_creeper"])

# ----------------------------------------------------------------
# Lapis Bay dungeons
# ----------------------------------------------------------------
func _register_lapis_bay_dungeons() -> void:
	_make(&"drowned_school", "The Drowned School",
		"A Lapis Bay water-mage school that sank in a storm seventy years ago. Most of the students drowned politely, in their robes, holding hands.",
		"You enter through a flooded staircase. The water is warm. The first body you see is sitting at a desk, still pretending to read.",
		&"lapis_bay", 20, 23, Dungeon.Tier.NORMAL,
		&"port_gangmaster", [&"drowned_sailor", &"pirate_caster"])

	_make(&"black_sail_keep", "The Black-Sail Keep",
		"The eldest of the three Black-Sail kings rules from a stolen Crown ship beached on his island. He has not left it in twelve years.",
		"You climb the hull. The deck is pirate-court. The brigand-king sits on a throne of nailed-down chairs.",
		&"pirate_isles", 24, 28, Dungeon.Tier.NORMAL,
		&"second_pirate_king", [&"pirate_grunt", &"pirate_caster", &"isle_python"])

# ----------------------------------------------------------------
# Bone Mountains dungeons
# ----------------------------------------------------------------
func _register_bone_mountains_dungeons() -> void:
	_make(&"the_first_ossuary", "The First Ossuary",
		"The original burial-site of the first survey-party, who carved the Bone Mountains' charnel-roads and were buried by their own work.",
		"The roof is the underside of a shoulder-blade the size of a hall. You hear, faintly, the survey-party still arguing over measurements.",
		&"bone_mountains", 30, 36, Dungeon.Tier.NORMAL,
		&"ossuary_watcher", [&"ossuary_guardian", &"bone_swarm", &"echo_of_first_climber"])

	_make(&"stone_dojo_inner_path", "The Inner Path of Anshar",
		"The Stone Breathing dojo's senior trial. Walk the inner path; do not flinch. Most flinch.",
		"The path is a corridor of standing stones. Each stone is a former student who failed the trial and was kept here for instructional purposes.",
		&"stone_dojo", 34, 40, Dungeon.Tier.HEROIC,
		&"stone_master", [&"stone_priest", &"ossuary_guardian"])

# ----------------------------------------------------------------
# Verdant Wound dungeons
# ----------------------------------------------------------------
func _register_verdant_wound_dungeons() -> void:
	_make(&"wound_of_wounds", "The Wound of Wounds",
		"The deepest part of the corruption. Where Tiamat's blood actually pooled. The Druid Sanctum forbids approach but cannot enforce the ban.",
		"You step into a clearing with no birdsong. The trees lean inward. Something laughs and it is not coming from a mouth.",
		&"verdant_wound", 38, 44, Dungeon.Tier.NORMAL,
		&"twelve_handed", [&"thorn_creature", &"corrupt_dryad", &"sanctum_apprentice_lost"])

	_make(&"druid_traitors_grove", "The Traitor's Grove",
		"A hidden Druid clearing where Inquisition agents posed as druids for a generation. The trees here remember their false-prayers.",
		"You enter through a screen of birches. The trees lean as if listening. The Sanctum-Mother has asked you specifically to handle this.",
		&"druid_sanctum", 36, 42, Dungeon.Tier.HEROIC,
		&"druid_traitor", [&"sanctum_apprentice_lost", &"corrupt_dryad"])

# ----------------------------------------------------------------
# Ember Steppes dungeons
# ----------------------------------------------------------------
func _register_ember_steppes_dungeons() -> void:
	_make(&"pillar_of_nergal_lower", "The Lower Pillar of Nergal",
		"Below the Flame Breathing temple, the actual fissure that the Pillar guards. Nergal's underworld speaks back if you listen.",
		"You climb down a basalt stair. The air is hot enough to burn breath. A voice asks if you are sure. The voice is patient. The voice is willing to wait.",
		&"flame_temple", 44, 50, Dungeon.Tier.HEROIC,
		&"flame_apostate", [&"flame_apostate", &"ember_imp", &"salamander"])

# ----------------------------------------------------------------
# Mist Vale dungeons
# ----------------------------------------------------------------
func _register_mist_vale_dungeons() -> void:
	_make(&"vale_of_lost_pilgrims", "The Vale of Lost Pilgrims",
		"Pilgrims used to come to Mist Vale to be forgiven for terrible things. The fog welcomes them with open arms. It has many open arms.",
		"You step into the deepest fog. Voices call your name. Some of them sound like family. Some of them are correct.",
		&"mist_vale", 50, 55, Dungeon.Tier.HEROIC,
		&"mist_apostate", [&"fog_walker", &"mist_apostate", &"echo_of_lost_pilgrim"])

# ----------------------------------------------------------------
# Shrieking Highlands dungeons
# ----------------------------------------------------------------
func _register_shrieking_highlands_dungeons() -> void:
	_make(&"adads_widow_keep", "Adad's Widow Keep",
		"A storm-blasted fortress at the highest point of the Shrieking Highlands. The Hammer Widow rules here, and the bolts arc to her hand.",
		"You climb the tower's broken stair. Each step is an arc of lightning. She is on the roof, swinging her dead husband's hammer at the sky.",
		&"shrieking_highlands", 58, 64, Dungeon.Tier.HEROIC,
		&"hammer_widow", [&"thunder_apostate", &"storm_rider", &"adad_drone"])

# ----------------------------------------------------------------
# Sundered Coast dungeons
# ----------------------------------------------------------------
func _register_sundered_coast_dungeons() -> void:
	_make(&"spawn_nesting_grounds", "The Spawn Nesting-Grounds",
		"The half-sunken ribs of Tiamat herself. Each rib is a hatchery. Three nesting-mothers tend the ribs. None are pleased with visitors.",
		"You wade in waist-deep at low tide. The water is warmer than it should be. You can hear the ribs breathing.",
		&"sundered_coast", 66, 72, Dungeon.Tier.HEROIC,
		&"spawn_brood_three", [&"spawn_brood", &"deep_servant", &"sundered_priest"])

# ----------------------------------------------------------------
# Endgame: Black Citadel + Fire Stair (these wrap to bosses)
# ----------------------------------------------------------------
func _register_endgame_dungeons() -> void:
	_make(&"black_citadel_climb", "The Black Citadel",
		"Six tiers stacked into the sky. Each tier holds a former champion of a faction, all turned. The seventh tier has no ceiling. Tiamat is there.",
		"You begin at the base. The walls breathe. Looking up makes you dizzy in a way that is not vertigo.",
		&"black_citadel", 78, 89, Dungeon.Tier.MYTHIC,
		&"tiamat", [&"citadel_grunt", &"citadel_priest", &"citadel_warden",
			&"citadel_first", &"citadel_second", &"citadel_third",
			&"citadel_fourth", &"citadel_fifth"])

	_make(&"fire_stair_descent", "The Fire Stair",
		"A spiral of basalt and ember. The stair narrows as it descends. At the bottom, a man waits with a smile and a contract.",
		"The first stair is warm. By the third revolution your boots smoke. By the seventh you have stopped sweating because you have run out of water. He is waiting.",
		&"fire_stair", 92, 100, Dungeon.Tier.MYTHIC,
		&"lucifer", [&"fall_servant", &"ember_drake", &"silver_negotiator"])
