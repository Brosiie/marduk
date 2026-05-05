extends Node

# Autoload registry of all boss encounters.
#
# 9 MAIN BOSSES, one per 10-level tier, lvl 9 through 89.
# 1 FINAL BOSS at lvl 99: Tiamat.
# 1 SECRET BOSS post-Tiamat: Lucifer.
# Many MINI-BOSSES sprinkled through zones (one per class intro + dungeon mini-bosses).
#
# Bosses live as data here. Spawning a boss instantiates a BossBase scene and
# applies the data record. This way one BossBase scene supports all 11 + minis.

class BossRecord:
	var id: StringName
	var display_name: String
	var encounter_level: int
	var zone_id: StringName
	var lore: String
	var is_main_boss: bool = false
	var is_final_boss: bool = false
	var is_secret_boss: bool = false
	var phases: Array = []  # phase definitions

var bosses: Dictionary = {}  # StringName id -> BossRecord
var mini_bosses: Dictionary = {}

func _ready() -> void:
	_register_class_intro_minibosses()
	_register_main_bosses()
	_register_final_boss()
	_register_secret_boss()
	_register_zone_minibosses()

func get_boss(id: StringName) -> BossRecord:
	if bosses.has(id): return bosses[id]
	if mini_bosses.has(id): return mini_bosses[id]
	return null

func main_bosses_in_order() -> Array:
	# Returns the 9 main bosses sorted by encounter_level
	var arr: Array = bosses.values().filter(func(b): return b.is_main_boss)
	arr.sort_custom(func(a, b): return a.encounter_level < b.encounter_level)
	return arr

func _make(id: StringName, name: String, level: int, zone: StringName, lore: String,
		main: bool = false, final: bool = false, secret: bool = false,
		phases: Array = []) -> BossRecord:
	var r := BossRecord.new()
	r.id = id
	r.display_name = name
	r.encounter_level = level
	r.zone_id = zone
	r.lore = lore
	r.is_main_boss = main
	r.is_final_boss = final
	r.is_secret_boss = secret
	r.phases = phases
	if main or final or secret:
		bosses[id] = r
	else:
		mini_bosses[id] = r
	return r

# ----------------------------------------------------------------
# CLASS INTRO MINI-BOSSES (6, lvl 4-5)
# Each ends a class prologue and triggers Ashurim convergence.
# ----------------------------------------------------------------
func _register_class_intro_minibosses() -> void:
	_make(&"raid_captain", "Hassu the Hooked", 5, &"ash_step_camp",
		"The man who put a spear through your father.")
	_make(&"corrupt_master", "Master Sapum, Five-Mouthed", 5, &"whisper_shrine",
		"The face you called father, now wearing five mouths.")
	_make(&"usurper_enforcer", "Enforcer Kazat, Iron-Faced", 5, &"sword_vow_ruins",
		"He held your lord's neck while Tashmu raised the sword.")
	_make(&"glade_terror", "The Glade Terror", 5, &"greenheart_glade",
		"It came up through the loam. It ate forty-one of your kin in a night.")
	_make(&"tower_warden", "The Tower Warden", 5, &"inkstone_tower",
		"What was bound around the breach, now broken loose. It still wears its old binding-rings like teeth.")
	_make(&"inquisitor_prime", "Sahirum the Witch-Burner", 5, &"coven_glen",
		"Inquisition Prime. Burned the women who taught you to be more than human. Will burn you next.")

# ----------------------------------------------------------------
# 9 MAIN BOSSES (lvl 9, 19, 29, 39, 49, 59, 69, 79, 89)
# Each gates progression to the next region or storyline beat.
# All Elden-Ring-tuned: long telegraphs, real punish windows, no ramp.
# ----------------------------------------------------------------
func _register_main_bosses() -> void:
	# 1. lvl 9 - Outskirts mini-finale, demonstrates the world is breaking
	_make(&"lord_of_outskirts", "Etemenanki the Pillar-Wraith", 9, &"iron_crown_outskirts",
		"A noble of the Iron Crown's old age, now a pillar of bone walking the outskirts. Speaks only the year it died.",
		true, false, false,
		[
			{"hp_pct": 1.0, "name": "Pillar Form", "dmg_mult": 1.0, "speed_mult": 1.0},
			{"hp_pct": 0.5, "name": "Wraith Unbound", "dmg_mult": 1.4, "speed_mult": 1.3}
		])

	# 2. lvl 19 - Reed Wastes, demon-incursion lord
	_make(&"reed_demon_lord", "Mu-Ash, Throat of the Wastes", 19, &"reed_wastes",
		"A demon that crawled out of a failed seal in the marshes. Has a hundred throats and uses them to scream the names of every Ash-Step soul it ate.",
		true, false, false,
		[
			{"hp_pct": 1.0, "name": "Throated", "dmg_mult": 1.0, "speed_mult": 1.0},
			{"hp_pct": 0.6, "name": "Screaming", "dmg_mult": 1.3, "speed_mult": 1.2},
			{"hp_pct": 0.25, "name": "Silent", "dmg_mult": 1.7, "speed_mult": 1.4}
		])

	# 3. lvl 29 - Lapis Bay pirate king
	_make(&"pirate_king_first", "Black-Sail the First", 29, &"pirate_isles",
		"A former Lapis Bay duke who chose teeth over taxes. Fights with two cutlasses, a flintlock, and a permanently bleeding wound he refuses to heal.",
		true, false, false,
		[
			{"hp_pct": 1.0, "name": "Two Cutlasses", "dmg_mult": 1.0, "speed_mult": 1.0},
			{"hp_pct": 0.4, "name": "Pistol and Steel", "dmg_mult": 1.5, "speed_mult": 1.2}
		])

	# 4. lvl 39 - Bone Mountains stone-tyrant
	_make(&"bone_tyrant", "Ushar of the Single Step", 39, &"bone_mountains",
		"A man who once climbed the Bone Mountains in a single step. His feet are still up there. His body has come to find them.",
		true, false, false,
		[
			{"hp_pct": 1.0, "name": "Stomping Wide", "dmg_mult": 1.0, "speed_mult": 0.8},
			{"hp_pct": 0.5, "name": "Walking Sky", "dmg_mult": 1.4, "speed_mult": 1.3}
		])

	# 5. lvl 49 - Verdant Wound beast-lord
	_make(&"beast_lord", "The Mother of Wrong Things", 49, &"verdant_wound",
		"What the forest became after Tiamat bled. Twelve eyes, twelve mouths, walks on hands. Sings.",
		true, false, false,
		[
			{"hp_pct": 1.0, "name": "Singing", "dmg_mult": 1.0, "speed_mult": 1.1},
			{"hp_pct": 0.45, "name": "Whispering", "dmg_mult": 1.3, "speed_mult": 1.4},
			{"hp_pct": 0.15, "name": "Silent and Smiling", "dmg_mult": 1.8, "speed_mult": 1.6}
		])

	# 6. lvl 59 - Ember Steppes flame-warlord
	_make(&"flame_warlord", "Nergal-Iddin, Sun-Eater", 59, &"ember_steppes",
		"A bandit chief who ate a piece of the Pillar of Nergal and survived. The fire in his throat never goes out.",
		true, false, false,
		[
			{"hp_pct": 1.0, "name": "Fire Within", "dmg_mult": 1.0, "speed_mult": 1.0},
			{"hp_pct": 0.5, "name": "Fire Without", "dmg_mult": 1.6, "speed_mult": 1.3}
		])

	# 7. lvl 69 - Mist Vale mist-thing
	_make(&"mist_thing", "Lahmu, Whisperer in Cloud", 69, &"mist_vale",
		"You have heard her name in the fog at dusk. You have not seen her face. Tonight she is going to lend you one.",
		true, false, false,
		[
			{"hp_pct": 1.0, "name": "Hidden", "dmg_mult": 1.0, "speed_mult": 1.5},
			{"hp_pct": 0.5, "name": "Half-Seen", "dmg_mult": 1.4, "speed_mult": 1.7},
			{"hp_pct": 0.15, "name": "Looking At You", "dmg_mult": 2.0, "speed_mult": 1.4}
		])

	# 8. lvl 79 - Shrieking Highlands storm-lord
	_make(&"storm_lord", "Adad-Mukin, Last of the Hammer", 79, &"shrieking_highlands",
		"A monk of Adad who refused to die when Adad called him. The hammer is still in his chest. He still hears it.",
		true, false, false,
		[
			{"hp_pct": 1.0, "name": "The Hammer Sings", "dmg_mult": 1.0, "speed_mult": 1.2},
			{"hp_pct": 0.5, "name": "The Hammer Roars", "dmg_mult": 1.7, "speed_mult": 1.5}
		])

	# 9. lvl 89 - Sundered Coast, Tiamat's old champion
	_make(&"kingu", "Kingu, the Tablet-Bearer", 89, &"sundered_coast",
		"Tiamat's chosen general. She set the Tablet of Destinies on his chest. Marduk took it back, but the bolt-mark remains, and so does the loyalty.",
		true, false, false,
		[
			{"hp_pct": 1.0, "name": "Tablet-Marked", "dmg_mult": 1.0, "speed_mult": 1.0},
			{"hp_pct": 0.5, "name": "Tablet-Stripped", "dmg_mult": 1.5, "speed_mult": 1.4},
			{"hp_pct": 0.15, "name": "Mother's Champion", "dmg_mult": 2.2, "speed_mult": 1.6}
		])

# ----------------------------------------------------------------
# FINAL BOSS - Tiamat (lvl 99)
# 3 phases: Drowned, Risen, Mother-of-Monsters dragon
# ----------------------------------------------------------------
func _register_final_boss() -> void:
	_make(&"tiamat", "Tiamat, Mother of Wrong", 99, &"black_citadel",
		"The salt sea. The split body. The grief that built an army out of itself. She has waited seventeen hundred years for the cycle to crack and for someone to come back.",
		false, true, false,
		[
			{"hp_pct": 1.0, "name": "Drowned", "dmg_mult": 1.0, "speed_mult": 0.9},
			{"hp_pct": 0.65, "name": "Risen", "dmg_mult": 1.5, "speed_mult": 1.3},
			{"hp_pct": 0.30, "name": "Mother of Monsters", "dmg_mult": 2.4, "speed_mult": 1.6}
		])

# ----------------------------------------------------------------
# SECRET BOSS - Lucifer (post-Tiamat, accessed via Sun Gate -> Fire Stair)
# 3 phases: Diplomat (dialogue check), Ember, Fallen
# ----------------------------------------------------------------
func _register_secret_boss() -> void:
	_make(&"lucifer", "Lucifer, the Fall and the Light", 100, &"fire_stair",
		"The first to walk away from the Edict and the first to come back asking. He is polite. He is courteous. He is the only opponent who will ever offer to negotiate before the strike. Refuse.",
		false, false, true,
		[
			{"hp_pct": 1.0, "name": "Diplomat", "dmg_mult": 1.0, "speed_mult": 1.0},
			{"hp_pct": 0.66, "name": "Ember", "dmg_mult": 1.6, "speed_mult": 1.3},
			{"hp_pct": 0.30, "name": "Fallen", "dmg_mult": 2.6, "speed_mult": 1.7}
		])

# ----------------------------------------------------------------
# ZONE MINI-BOSSES (sprinkled, lvl 12-85)
# Roughly 3 per zone past Ashurim. Each drops a guaranteed VERY_RARE.
# ----------------------------------------------------------------
func _register_zone_minibosses() -> void:
	# Iron Crown Outskirts
	_make(&"caravan_butcher", "Akir the Caravan-Butcher", 8, &"iron_crown_outskirts", "Brigand chief.")
	_make(&"escaped_temple", "The Temple-Bound", 10, &"iron_crown_outskirts", "An escaped temple-slave with a chain still around its neck.")

	# Reed Wastes
	_make(&"reed_walker", "Walker in Reeds", 13, &"reed_wastes", "A drowned thing that walks during the day.")
	_make(&"failed_seal", "What Came Through the Crack", 16, &"reed_wastes", "A minor demon, but persistent.")
	_make(&"wastes_shaman", "Mu-Lu, Crack-Touched Shaman", 18, &"reed_wastes", "An Ash-Step shaman who heard the seal break and went out to listen.")

	# Lapis Bay
	_make(&"port_gangmaster", "The Port Gangmaster", 17, &"lapis_bay", "Owns half the dock workers, all of the crime.")
	_make(&"second_pirate_king", "The Second Black-Sail", 22, &"pirate_isles", "Younger sibling of the first.")
	_make(&"third_pirate_king", "The Third Black-Sail", 26, &"pirate_isles", "The youngest, the meanest.")

	# Bone Mountains
	_make(&"ossuary_watcher", "The Ossuary Watcher", 28, &"bone_mountains", "What was set to guard the bones. Still doing its job.")
	_make(&"stone_master", "The Stone Master's Echo", 32, &"stone_dojo", "A master who refused to die when his stance broke.")
	_make(&"bone_dragon", "The Lesser Bone Dragon", 36, &"bone_mountains", "Not Tiamat-spawn. Older.")

	# Verdant Wound
	_make(&"twelve_handed", "The Twelve-Handed", 33, &"verdant_wound", "Crawls. Sings the Greenheart's old songs wrong.")
	_make(&"druid_traitor", "The Druid Who Sold Us", 38, &"druid_sanctum", "Inquisition agent who infiltrated the Sanctum. The Sanctum-Mother knows. The Sanctum-Mother waits for you to handle it.")
	_make(&"forest_blight", "Forest Blight Prime", 42, &"verdant_wound", "What the corruption became when it found the Mother-Tree's roots.")

	# Ember Steppes
	_make(&"salamander_lord", "The Salamander Lord", 38, &"ember_steppes", "Bandit chief who tamed a sub-volcanic lizard.")
	_make(&"flame_apostate", "Flame-Apostate", 44, &"flame_temple", "A senior monk who let his inner flame go out and replaced it with something else.")

	# Mist Vale
	_make(&"fog_one", "The One in the Fog at Dusk", 47, &"mist_vale", "You have always seen them at dusk. You have always thought they were the next-door neighbor. They were not.")
	_make(&"mist_apostate", "Mist-Apostate", 52, &"mist_vale", "A monk who walked too far in. Came back wearing someone else's face.")

	# Shrieking Highlands
	_make(&"thunder_apostate", "Thunder-Apostate", 56, &"shrieking_highlands", "A monk who walked into the storm to die. Came back. Still walking.")
	_make(&"hammer_widow", "The Hammer Widow", 62, &"shrieking_highlands", "Wife of a Thunder monk. Took up his hammer when he died and now refuses to put it down.")

	# Sundered Coast
	_make(&"spawn_brood_one", "Spawn-Brood Mother (One)", 64, &"sundered_coast", "A lesser nesting-mother. Tiamat had hundreds.")
	_make(&"spawn_brood_two", "Spawn-Brood Mother (Two)", 68, &"sundered_coast", "Older. Smarter.")
	_make(&"spawn_brood_three", "Spawn-Brood Mother (Three)", 72, &"sundered_coast", "Oldest. Knows your name.")

	# Black Citadel (climb tier)
	_make(&"citadel_first", "The First Tier Warden", 76, &"black_citadel", "Used to be a Crown lieutenant.")
	_make(&"citadel_second", "The Second Tier Sister", 80, &"black_citadel", "Used to be a sister of Inquisition.")
	_make(&"citadel_third", "The Third Tier Druid", 82, &"black_citadel", "Used to be Sanctum-Mother. Different name now.")
	_make(&"citadel_fourth", "The Fourth Tier Pirate", 84, &"black_citadel", "Used to be the First Black-Sail. Came back.")
	_make(&"citadel_fifth", "The Fifth Tier Lord", 86, &"black_citadel", "Used to be Lord Ennum. Yes, that one. The Ronin recognizes him.")
