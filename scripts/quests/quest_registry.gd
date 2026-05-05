extends Node

# Autoload: 25+ canonical quests. Class prologues, faction storylines, exploration
# beats. Each quest has detailed rewards including titles via achievement tie-ins.

var quests: Dictionary = {}  # StringName -> Quest

func _ready() -> void:
	_register_prologues()
	_register_main_story()
	_register_faction_quests()
	_register_side_quests()

func get_quest(id: StringName) -> Quest:
	return quests.get(id)

func quests_for_class(class_id: StringName, level: int) -> Array[Quest]:
	var arr: Array[Quest] = []
	for q: Quest in quests.values():
		if q.class_restriction.size() > 0 and not (class_id in q.class_restriction):
			continue
		if q.min_level > level:
			continue
		arr.append(q)
	return arr

func _make(id: StringName, name: String, desc: String,
		giver_npc_id: StringName, min_level: int,
		objectives: Array, xp: int, gold: int,
		class_restrict: Array = [],
		sets_run_flag: StringName = &"") -> Quest:
	var q := Quest.new()
	q.id = id
	q.display_name = name
	q.description = desc
	q.giver_npc_id = giver_npc_id
	q.min_level = min_level
	q.objectives_data = objectives
	q.xp_reward = xp
	q.gold_reward = gold
	for c in class_restrict:
		q.class_restriction.append(StringName(c))
	q.sets_run_flag = sets_run_flag
	quests[id] = q
	return q

# ----------------------------------------------------------------
# CLASS PROLOGUES (per class, ends at Ashurim)
# ----------------------------------------------------------------
func _register_prologues() -> void:
	_make(&"prologue_berserker", "The Last of Ash-Step",
		"Return to the Ash-Step camp. Find Hassu the Hooked. End him.",
		&"berserker_intro_npc", 1,
		[
			{"description": "Eliminate Hassu the Hooked", "kind": "kill", "target_id": "raid_captain", "required_count": 1},
			{"description": "Travel to Ashurim", "kind": "reach_zone", "target_id": "ashurim", "required_count": 1}
		],
		1500, 250, [&"berserker"], &"prologue_complete")

	_make(&"prologue_assassin", "The Master's Lie",
		"Climb the Whisper Shrine. Confront Master Sapum.",
		&"assassin_intro_npc", 1,
		[
			{"description": "Defeat Master Sapum", "kind": "kill", "target_id": "corrupt_master", "required_count": 1},
			{"description": "Travel to Ashurim", "kind": "reach_zone", "target_id": "ashurim", "required_count": 1}
		],
		1500, 250, [&"assassin"], &"prologue_complete")

	_make(&"prologue_ronin", "Sword Without Lord",
		"Return to the Sword-Vow Ruins. Find Enforcer Kazat. Settle the matter.",
		&"ronin_intro_npc", 1,
		[
			{"description": "Defeat Kazat the Iron-Faced", "kind": "kill", "target_id": "usurper_enforcer", "required_count": 1},
			{"description": "Travel to Ashurim", "kind": "reach_zone", "target_id": "ashurim", "required_count": 1}
		],
		1500, 250, [&"ronin"], &"prologue_complete")

	_make(&"prologue_ranger", "The Spawn That Came Through",
		"Track the beast. Find it before it finds the next village.",
		&"ranger_intro_npc", 1,
		[
			{"description": "Slay the Glade Terror", "kind": "kill", "target_id": "glade_terror", "required_count": 1},
			{"description": "Travel to Ashurim", "kind": "reach_zone", "target_id": "ashurim", "required_count": 1}
		],
		1500, 250, [&"ranger"], &"prologue_complete")

	_make(&"prologue_mage", "Pages and Ash",
		"Climb the Inkstone Tower. End the Warden. Find Old Asaridu's last book.",
		&"mage_intro_npc", 1,
		[
			{"description": "Defeat the Tower Warden", "kind": "kill", "target_id": "tower_warden", "required_count": 1},
			{"description": "Travel to Ashurim", "kind": "reach_zone", "target_id": "ashurim", "required_count": 1}
		],
		1500, 250, [&"mage"], &"prologue_complete")

	_make(&"prologue_druid", "The Coven Burned",
		"Return to the Coven Glen. End Inquisitor Sahirum. Or do not. The Sanctum-Mother says the choice is yours.",
		&"druid_intro_npc", 1,
		[
			{"description": "Defeat Sahirum the Witch-Burner", "kind": "kill", "target_id": "inquisitor_prime", "required_count": 1},
			{"description": "Travel to Ashurim", "kind": "reach_zone", "target_id": "ashurim", "required_count": 1}
		],
		1500, 250, [&"chaos_druid"], &"prologue_complete")

	_make(&"prologue_paladin_guardian", "The Chapel Stood",
		"The chapel's wounded need defending. Find the siege-master and stop him before the chapel falls.",
		&"paladin_intro_npc", 1,
		[
			{"description": "Defeat the Siege-Master", "kind": "kill", "target_id": "siege_master", "required_count": 1},
			{"description": "Travel to Ashurim", "kind": "reach_zone", "target_id": "ashurim", "required_count": 1}
		],
		1500, 250, [&"paladin_guardian"], &"prologue_complete")

	_make(&"prologue_paladin_lightbringer", "The Chapel Wept",
		"The chapel-master is dying. The siege-master has chosen a path. Walk yours.",
		&"paladin_intro_npc", 1,
		[
			{"description": "Defeat the Siege-Master", "kind": "kill", "target_id": "siege_master", "required_count": 1},
			{"description": "Travel to Ashurim", "kind": "reach_zone", "target_id": "ashurim", "required_count": 1}
		],
		1500, 250, [&"paladin_lightbringer"], &"prologue_complete")

# ----------------------------------------------------------------
# MAIN STORY arc
# ----------------------------------------------------------------
func _register_main_story() -> void:
	_make(&"to_babilim", "The Iron Crown",
		"The Storyteller in Ashurim says you are wanted in Babilim. The Crown has questions, and answers, and more questions.",
		&"storyteller", 5,
		[{"description": "Reach Babilim", "kind": "reach_zone", "target_id": "babilim", "required_count": 1}],
		2000, 500, [], &"reached_babilim")

	_make(&"reed_failure", "The Failed Seal",
		"Mu-Ash, Throat of the Wastes, is feeding on the cracks. General Sin-Mushezib of the Crown wants the seal closed. The seal cannot close. Close the next-best thing.",
		&"general_sin", 18,
		[
			{"description": "Defeat Mu-Ash, Throat of the Wastes", "kind": "kill", "target_id": "reed_demon_lord", "required_count": 1},
		], 5000, 1500)

	_make(&"first_breath_master", "The First Breath-Master",
		"Visit a breathing temple. Any of them. Train under a master. Learn that there is more than one way to draw a breath.",
		&"storyteller", 12,
		[{"description": "Visit any breathing temple", "kind": "reach_zone", "target_id": "stone_dojo", "required_count": 1}],
		1500, 300)

	_make(&"to_tiamat", "The Mother of Wrong",
		"Babilim's edict is failing. The Storyteller and General Sin-Mushezib agree on this. They agree on little else. The path forward is the Black Citadel.",
		&"storyteller", 70,
		[
			{"description": "Reach the Black Citadel", "kind": "reach_zone", "target_id": "black_citadel", "required_count": 1},
			{"description": "Defeat Tiamat", "kind": "kill", "target_id": "tiamat", "required_count": 1}
		], 50000, 25000, [], &"tiamat_defeated")

	_make(&"the_fire_stair", "The Fire Stair",
		"The Sun Gate is open. Below the Sun Gate is a stair of fire. Below the stair is a man with a smile and a contract. The Storyteller says: do not negotiate.",
		&"storyteller", 90,
		[
			{"description": "Reach the Fire Stair", "kind": "reach_zone", "target_id": "fire_stair", "required_count": 1},
			{"description": "Defeat Lucifer", "kind": "kill", "target_id": "lucifer", "required_count": 1}
		], 100000, 50000, [], &"lucifer_defeated")

# ----------------------------------------------------------------
# FACTION QUESTS
# ----------------------------------------------------------------
func _register_faction_quests() -> void:
	_make(&"crown_brigand_pit", "The Crown's Problem",
		"General Sin-Mushezib has an outskirts brigand problem. Brigands have a Crown-soldier problem when you arrive.",
		&"general_sin", 6,
		[{"description": "Clear the Caravan Pit", "kind": "kill", "target_id": "caravan_butcher", "required_count": 1}],
		800, 400)

	_make(&"druid_traitor_grove", "The Traitor in the Grove",
		"The Sanctum-Mother knows there is an Inquisition agent among her druids. She wants you to find them. She knows which one. She will not tell you. Find them yourself.",
		&"sanctum_mother", 36,
		[{"description": "Find and defeat the traitor druid", "kind": "kill", "target_id": "druid_traitor", "required_count": 1}],
		8000, 4000, [&"chaos_druid"])

	_make(&"black_sail_problem", "Three Crowns of Salt",
		"Black-Sail of Lapis Bay has three pirate-king brothers. One is older than the others. He needs reminding.",
		&"lapis_dockmaster", 28,
		[{"description": "Defeat Black-Sail the First", "kind": "kill", "target_id": "pirate_king_first", "required_count": 1}],
		6000, 3000)

	_make(&"inquisitor_prime", "The Witch-Burner's End",
		"Sahirum survives the Glen if you let him. The Druid Sanctum offers a price for his head.",
		&"sanctum_mother", 30,
		[{"description": "Defeat Sahirum the Witch-Burner", "kind": "kill", "target_id": "inquisitor_prime", "required_count": 1}],
		5000, 2500, [&"chaos_druid"])

	_make(&"breathing_master_quest", "Form Seven of Anything",
		"A breathing-master at any of the Six Breaths temples will train you, if you bring proof of mastery. Any Form 7 breathing scroll will do.",
		&"breath_master", 22,
		[{"description": "Bring a Form 7 scroll", "kind": "collect", "target_id": "form_7_scroll", "required_count": 1}],
		3000, 1500, [&"ronin"])

	_make(&"asaridu_legacy", "Old Asaridu's Last Page",
		"The Inkstone Tower's central well still echoes Asaridu's voice. The Arcane Council wants the page he left behind. So does Old Asaridu.",
		&"high_magus", 50,
		[
			{"description": "Reach the Master's Well", "kind": "reach_zone", "target_id": "asaridu_well", "required_count": 1},
			{"description": "Recover the Final Page", "kind": "collect", "target_id": "legendary_mage_final_page", "required_count": 1}
		], 12000, 8000, [&"mage"])

# ----------------------------------------------------------------
# SIDE QUESTS / WORLDBUILDING
# ----------------------------------------------------------------
func _register_side_quests() -> void:
	_make(&"belitu_ledger", "Belitu's Ledger",
		"The innkeeper Belitu has lost her ledger. She suspects a customer took it. She knows who. She will not tell you. Find it.",
		&"belitu", 7,
		[{"description": "Recover Belitu's ledger", "kind": "collect", "target_id": "belitu_ledger", "required_count": 1}],
		500, 200)

	_make(&"oracle_chalk", "Oracle's Chalk",
		"The Oracle of the Pillar is out of chalk. The Crown will not requisition more. You can. The Apothecary in Babilim sells the right kind.",
		&"oracle_attendant", 9,
		[{"description": "Bring chalk to the Oracle", "kind": "collect", "target_id": "oracle_chalk", "required_count": 1}],
		400, 100)

	_make(&"hanging_gardens_keeper", "Garden Keeper's Trouble",
		"Something has been digging up the Hanging Gardens at night. The keeper suspects a Tiamat-spawn. Confirm or deny.",
		&"garden_keeper", 14,
		[{"description": "Investigate the Hanging Gardens disturbance", "kind": "kill", "target_id": "minor_demon", "required_count": 3}],
		1500, 400)

	_make(&"caravan_widow", "The Caravan Widow",
		"A widow at the Iron Crown gates has lost her husband to brigands. She wants his ring back. Not his body. Just the ring.",
		&"caravan_widow_npc", 7,
		[{"description": "Recover the husband's ring", "kind": "collect", "target_id": "caravan_widow_ring", "required_count": 1}],
		700, 250)

	_make(&"flame_temple_pilgrimage", "Pilgrimage to Nergal",
		"The Flame Breathing temple accepts pilgrims who can walk the inner spiral without a torch. The spiral is in total darkness.",
		&"flame_master", 35,
		[{"description": "Walk the Pillar of Nergal in total darkness", "kind": "reach_zone", "target_id": "flame_temple", "required_count": 1}],
		3500, 1500)

	_make(&"sunken_letter", "The Sunken Letter",
		"Lapis Bay's dockmaster has heard of a letter in the Wreck of the Alanak. The letter is for a man who has been dead seventy years. The dockmaster wants to read it anyway.",
		&"lapis_dockmaster", 22,
		[{"description": "Recover the Alanak Letter", "kind": "collect", "target_id": "sunken_letter", "required_count": 1}],
		2000, 800)

	_make(&"the_storytellers_request", "The Storyteller's Request",
		"The Storyteller asks if you would visit every landmark in the Cradle. She is making a list. She will not say of what.",
		&"storyteller", 5,
		[{"description": "Examine all 7 Cradle landmarks", "kind": "examine", "target_id": "cradle_landmarks", "required_count": 7}],
		2500, 1000)

	_make(&"the_oracle_prophecy", "The Oracle Wrote Your Name",
		"The Oracle of the Pillar has written a prophecy on the pillar. It begins with your name. The Crown is interested.",
		&"oracle_attendant", 60,
		[{"description": "Read the Oracle's full prophecy", "kind": "examine", "target_id": "crown_oracle_pillar", "required_count": 1}],
		8000, 0)
