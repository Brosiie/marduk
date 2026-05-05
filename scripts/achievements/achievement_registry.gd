extends Node

# Autoload: ~80 achievements spanning combat, exploration, professions, story, feats.
# Each is data; the AchievementTracker on Player listens for events and unlocks them.

var achievements: Dictionary = {}  # StringName -> Achievement

func _ready() -> void:
	_register_combat()
	_register_feats()
	_register_exploration()
	_register_professions()
	_register_story()
	_register_collection()
	_register_meta()

func get_achievement(id: StringName) -> Achievement:
	return achievements.get(id)

func all_achievements() -> Array[Achievement]:
	var arr: Array[Achievement] = []
	for a in achievements.values():
		arr.append(a)
	return arr

func by_category(c: int) -> Array[Achievement]:
	var arr: Array[Achievement] = []
	for a: Achievement in achievements.values():
		if a.category == c:
			arr.append(a)
	return arr

func _make(id: StringName, name: String, desc: String, cat: int, trigger: int,
		data: Dictionary = {}, title_id: StringName = &"", xp: int = 0, gold: int = 0,
		flavor: String = "", hidden: bool = false) -> Achievement:
	var a := Achievement.new()
	a.id = id
	a.display_name = name
	a.description = desc
	a.category = cat
	a.trigger = trigger
	a.trigger_data = data
	a.awards_title_id = title_id
	a.xp_reward = xp
	a.gold_reward = gold
	a.unlock_flavor = flavor
	a.hidden_until_unlocked = hidden
	achievements[id] = a
	return a

# ----------------------------------------------------------------
# COMBAT - boss roster + kill milestones
# ----------------------------------------------------------------
func _register_combat() -> void:
	# Each main boss gets an achievement
	var boss_ids := [&"lord_of_outskirts", &"reed_demon_lord", &"pirate_king_first",
		&"bone_tyrant", &"beast_lord", &"flame_warlord", &"mist_thing",
		&"storm_lord", &"kingu"]
	for bid in boss_ids:
		_make(StringName("first_kill_" + String(bid)),
			"First Blood: %s" % String(bid).capitalize(),
			"Defeat the boss for the first time.",
			Achievement.Category.COMBAT,
			Achievement.TriggerKind.BOSS_DEFEATED,
			{"boss_id": bid}, &"", 500, 200, "")

	_make(&"first_kill_tiamat", "Mother-Slayer",
		"Defeat Tiamat. The cycle's first crown.",
		Achievement.Category.COMBAT, Achievement.TriggerKind.BOSS_DEFEATED,
		{"boss_id": &"tiamat"}, &"title_mother_slayer", 5000, 5000,
		"You stood where Marduk stood, and you did what he did. The wind in the throne hall stops, briefly, in respect.")

	_make(&"first_kill_lucifer", "Walker of the Stair",
		"Defeat Lucifer. The Demon class is now yours.",
		Achievement.Category.COMBAT, Achievement.TriggerKind.BOSS_DEFEATED,
		{"boss_id": &"lucifer"}, &"title_fall_walker", 10000, 10000,
		"He offered. You declined. The fire goes out behind you when you climb back up.")

	# Kill counts
	_make(&"slayer_100", "Hundred Cuts",
		"Kill 100 enemies.",
		Achievement.Category.COMBAT, Achievement.TriggerKind.KILL_COUNT,
		{"tag": &"any", "count": 100}, &"", 200, 100, "")
	_make(&"slayer_1000", "Thousand-Faced Death",
		"Kill 1,000 enemies.",
		Achievement.Category.COMBAT, Achievement.TriggerKind.KILL_COUNT,
		{"tag": &"any", "count": 1000}, &"title_death", 2000, 1000, "")
	_make(&"slayer_10000", "Ten-Thousand",
		"Kill 10,000 enemies.",
		Achievement.Category.COMBAT, Achievement.TriggerKind.KILL_COUNT,
		{"tag": &"any", "count": 10000}, &"title_grim_reaper", 20000, 10000,
		"Marduk himself only managed eleven monsters in single combat. You have outpaced the king of gods in raw arithmetic.")

	_make(&"demon_slayer_100", "Demon-Hunter",
		"Kill 100 demons.",
		Achievement.Category.COMBAT, Achievement.TriggerKind.KILL_COUNT,
		{"tag": &"demon", "count": 100}, &"title_demon_hunter", 1500, 800, "")
	_make(&"undead_slayer_100", "Walker of Graves",
		"Kill 100 undead.",
		Achievement.Category.COMBAT, Achievement.TriggerKind.KILL_COUNT,
		{"tag": &"undead", "count": 100}, &"title_grave_walker", 1500, 800, "")
	_make(&"spawn_slayer_50", "Spawn-Reaper",
		"Kill 50 Tiamat-spawn.",
		Achievement.Category.COMBAT, Achievement.TriggerKind.KILL_COUNT,
		{"tag": &"tiamat_spawn", "count": 50}, &"title_spawn_reaper", 2500, 1500, "")

# ----------------------------------------------------------------
# FEATS OF STRENGTH - speed runs, no-hits, low-level kills
# ----------------------------------------------------------------
func _register_feats() -> void:
	# No-hit boss kills
	_make(&"no_hit_tiamat", "Untouched by the Mother",
		"Defeat Tiamat without taking any damage.",
		Achievement.Category.FEATS, Achievement.TriggerKind.BOSS_DEFEATED_NO_HIT,
		{"boss_id": &"tiamat"}, &"title_untouched", 10000, 8000,
		"She bled. You did not. The Storyteller writes a new line for you in the back of her ledger.")
	_make(&"no_hit_lucifer", "Unmarked by the Fall",
		"Defeat Lucifer without taking any damage.",
		Achievement.Category.FEATS, Achievement.TriggerKind.BOSS_DEFEATED_NO_HIT,
		{"boss_id": &"lucifer"}, &"title_unmarked", 15000, 12000,
		"He smiled the whole time. You smiled back, but yours had teeth.")
	_make(&"no_hit_kingu", "The Tablet Untouched",
		"Defeat Kingu the Tablet-Bearer without taking damage.",
		Achievement.Category.FEATS, Achievement.TriggerKind.BOSS_DEFEATED_NO_HIT,
		{"boss_id": &"kingu"}, &"title_tablet_walker", 5000, 3000, "")

	# Speed runs (Bond's example: final two bosses in under 60 seconds)
	_make(&"speed_tiamat_60", "Mother-Cracker",
		"Defeat Tiamat in under 60 seconds.",
		Achievement.Category.FEATS, Achievement.TriggerKind.BOSS_DEFEATED_UNDER_TIME,
		{"boss_id": &"tiamat", "seconds": 60}, &"title_mother_cracker", 8000, 5000,
		"Marduk took an entire afternoon. You took less than a minute.")
	_make(&"speed_lucifer_60", "Stair-Skipper",
		"Defeat Lucifer in under 60 seconds.",
		Achievement.Category.FEATS, Achievement.TriggerKind.BOSS_DEFEATED_UNDER_TIME,
		{"boss_id": &"lucifer", "seconds": 60}, &"title_stair_skipper", 12000, 8000,
		"He had not finished his opening line. He sat down, surprised, then disappointed, then dead.")
	_make(&"speed_finale_60", "Crown of Salt and Fire",
		"Defeat both Tiamat AND Lucifer in under 60 seconds combined (cycle time).",
		Achievement.Category.FEATS, Achievement.TriggerKind.BOSS_DEFEATED_UNDER_TIME,
		{"boss_id": &"finale_combo", "seconds": 60}, &"title_crown_salt_fire", 25000, 20000,
		"The cycle goes from Tiamat to Lucifer in less than a minute. Mortal arithmetic and divine arithmetic agree only here.")

	# Under-leveled kills
	_make(&"low_level_tiamat", "Beneath Her Notice",
		"Defeat Tiamat at character level 70 or below.",
		Achievement.Category.FEATS, Achievement.TriggerKind.BOSS_DEFEATED_AT_LEVEL,
		{"boss_id": &"tiamat", "max_level": 70}, &"title_beneath_notice", 8000, 5000, "")

	# Skill mastery feats
	_make(&"all_breathing_forms", "Master of the Seven Breaths",
		"Unlock all 49 breathing forms (Ronin only).",
		Achievement.Category.FEATS, Achievement.TriggerKind.ALL_BREATHING_FORMS,
		{}, &"title_seven_breaths", 15000, 10000,
		"Forty-nine forms. Six lifetimes of training in one. You can hold your breath for a quarter-hour without flinching.")
	_make(&"all_mage_spells", "Word-Keeper",
		"Unlock all 49 Mage spells.",
		Achievement.Category.FEATS, Achievement.TriggerKind.ALL_MAGE_SPELLS,
		{}, &"title_word_keeper", 15000, 10000,
		"Old Asaridu wanted you to remember everything. You did.")

# ----------------------------------------------------------------
# EXPLORATION - zones, ruins
# ----------------------------------------------------------------
func _register_exploration() -> void:
	_make(&"explore_cradle", "Out of the Cradle",
		"Discover all 6 class intro zones + Ashurim.",
		Achievement.Category.EXPLORATION, Achievement.TriggerKind.HIDDEN, {},
		&"title_cradle_walker", 800, 200, "")
	_make(&"explore_iron_crown", "Crown-Familiar",
		"Discover Babilim and the Iron Crown Outskirts.",
		Achievement.Category.EXPLORATION, Achievement.TriggerKind.HIDDEN, {},
		&"", 500, 100, "")
	_make(&"explore_all_zones", "Sun-and-Salt Walker",
		"Discover every zone in the world.",
		Achievement.Category.EXPLORATION, Achievement.TriggerKind.ALL_ZONES_DISCOVERED, {},
		&"title_world_walker", 5000, 3000,
		"You have walked the road from the Cradle to the Stair. Few do; fewer come back to tell.")

	# Landmark examination achievements (lore-on-discover)
	_make(&"examine_pillar", "Pillar-Read",
		"Read the Edict carved on Babilim's Iron Pillar.",
		Achievement.Category.EXPLORATION, Achievement.TriggerKind.LANDMARK_EXAMINED,
		{"landmark_id": &"iron_pillar"}, &"", 200, 0,
		"The script is older than the city. Some of the words you do not have a word for.")
	_make(&"examine_silent_gate", "Door That Will Not Open",
		"Stand at the Silent Gate of Babilim. Listen.",
		Achievement.Category.EXPLORATION, Achievement.TriggerKind.LANDMARK_EXAMINED,
		{"landmark_id": &"silent_gate"}, &"title_door_listener", 500, 0,
		"You hear what is on the other side. You don't tell anyone. The Storyteller already knows.")
	_make(&"examine_apsu_well", "Apsu's Mouth",
		"Find the well where Old Asaridu sealed himself.",
		Achievement.Category.EXPLORATION, Achievement.TriggerKind.LANDMARK_EXAMINED,
		{"landmark_id": &"asaridu_well"}, &"", 800, 200,
		"His voice still speaks from the well, but only at noon, and only if you remember his student-name correctly.")

# ----------------------------------------------------------------
# PROFESSIONS
# ----------------------------------------------------------------
func _register_professions() -> void:
	_make(&"max_smithing", "Forge-Master",
		"Reach level 100 in Smithing.",
		Achievement.Category.PROFESSIONS, Achievement.TriggerKind.PROFESSION_MAXED,
		{"profession_id": &"smithing"}, &"title_forge_master", 5000, 5000,
		"Babilim's smithy nods to you. You have heard their secrets. You may now teach them.")
	_make(&"max_mining", "Stone-Whisperer",
		"Reach level 100 in Mining.",
		Achievement.Category.PROFESSIONS, Achievement.TriggerKind.PROFESSION_MAXED,
		{"profession_id": &"mining"}, &"title_stone_whisperer", 5000, 5000, "")
	_make(&"max_woodcutting", "Heart-Cutter",
		"Reach level 100 in Woodcutting.",
		Achievement.Category.PROFESSIONS, Achievement.TriggerKind.PROFESSION_MAXED,
		{"profession_id": &"woodcutting"}, &"title_heart_cutter", 5000, 5000, "")
	_make(&"max_crafting", "World-Maker",
		"Reach level 100 in Crafting.",
		Achievement.Category.PROFESSIONS, Achievement.TriggerKind.PROFESSION_MAXED,
		{"profession_id": &"crafting"}, &"title_world_maker", 5000, 5000, "")
	_make(&"all_professions_max", "Marduk's Hands",
		"Reach level 100 in all four professions.",
		Achievement.Category.PROFESSIONS, Achievement.TriggerKind.ALL_PROFESSIONS_MAXED, {},
		&"title_marduks_hands", 25000, 25000,
		"You build, you cut, you mine, you forge. The first king-of-gods built the world from a corpse. You build it from less.")

# ----------------------------------------------------------------
# STORY (quests + faction)
# ----------------------------------------------------------------
func _register_story() -> void:
	_make(&"prologue_complete", "First Step at Ashurim",
		"Complete your class prologue and arrive at Ashurim.",
		Achievement.Category.STORY, Achievement.TriggerKind.QUEST_COMPLETED,
		{"quest_id": &"prologue"}, &"", 300, 50,
		"The Storyteller knows your face. She has been waiting.")
	_make(&"reach_babilim", "Iron Crown",
		"Reach Babilim, the Iron Crown.",
		Achievement.Category.STORY, Achievement.TriggerKind.ZONE_DISCOVERED,
		{"zone_id": &"babilim"}, &"", 500, 200, "")
	_make(&"unlock_demon", "Inheritor of the Stair",
		"Unlock the Demon class.",
		Achievement.Category.STORY, Achievement.TriggerKind.ITEM_OBTAINED,
		{"item_id": &"demon_class_unlocked"}, &"title_inheritor", 8000, 6000, "")

# ----------------------------------------------------------------
# COLLECTION (rare items)
# ----------------------------------------------------------------
func _register_collection() -> void:
	_make(&"obtain_heaven", "The Sword Chose",
		"Obtain Heaven, the soulbound katana.",
		Achievement.Category.COLLECTION, Achievement.TriggerKind.ITEM_OBTAINED,
		{"item_id": &"heaven"}, &"title_sword_chosen", 50000, 25000,
		"The pure white katana. It rests in your hand without weight. You weigh on it instead.",
		true)  # hidden until earned

	_make(&"all_class_legendaries", "All Seven Champions",
		"Obtain all 7 class-bound legendaries.",
		Achievement.Category.COLLECTION, Achievement.TriggerKind.HIDDEN, {},
		&"title_seven_champions", 30000, 20000, "")

# ----------------------------------------------------------------
# META (prestige, play time)
# ----------------------------------------------------------------
func _register_meta() -> void:
	_make(&"prestige_1", "Second Time Around",
		"Reach prestige cycle 1.",
		Achievement.Category.META, Achievement.TriggerKind.PRESTIGE_REACHED,
		{"cycle_n": 1}, &"title_returner", 5000, 5000,
		"Tiamat is alive again. So are you, but heavier.")
	_make(&"prestige_5", "Halfway to the Sun",
		"Reach prestige cycle 5.",
		Achievement.Category.META, Achievement.TriggerKind.PRESTIGE_REACHED,
		{"cycle_n": 5}, &"title_halfway_sun", 15000, 15000, "")
	_make(&"prestige_10", "Closer of Cycles",
		"Reach prestige cycle 10. The maximum.",
		Achievement.Category.META, Achievement.TriggerKind.PRESTIGE_REACHED,
		{"cycle_n": 10}, &"title_cycle_closer", 100000, 100000,
		"Ten cycles. Ten Tiamats. Ten Lucifers. The world has stopped trying to hide its secrets from you.")

# ----------------------------------------------------------------
# HUMOROUS / SILLY achievements
# Some serious, some absurd, all 100% earnable through actual play
# ----------------------------------------------------------------
	_make(&"death_by_self", "Self-Inflicted Wounds Are Still Wounds",
		"Die to your own ability (Demon HP-cost finisher kills you, Berserker self-damage, etc).",
		Achievement.Category.FEATS, Achievement.TriggerKind.HIDDEN, {},
		&"title_self_made", 100, 50,
		"Technically a kill. Technically not a win.")

	_make(&"chug_potions_50", "Apothecary's Best Friend",
		"Drink 50 potions in a single dungeon run.",
		Achievement.Category.META, Achievement.TriggerKind.HIDDEN, {},
		&"title_potion_addict", 200, 0,
		"The Salt-and-Stone Apothecary in Babilim asks if you are alright. You are not.",
		true)

	_make(&"die_to_glade_terror_three", "Stop Dying to the Glade Terror",
		"Die to the Glade Terror three times. Maybe try a different forest.",
		Achievement.Category.FEATS, Achievement.TriggerKind.HIDDEN, {},
		&"title_glade_problem", 50, 0,
		"It is one (1) creature. You have a sword. We are rooting for you.",
		true)

	_make(&"fall_in_well", "Asaridu Says Hello",
		"Fall into Old Asaridu's well. He cushions your landing with a binding-rune. He is not pleased.",
		Achievement.Category.EXPLORATION, Achievement.TriggerKind.LANDMARK_EXAMINED,
		{"landmark_id": &"asaridu_well_fallen"}, &"title_well_diver", 200, 100,
		"\"You are not dead. You are also not invited.\"",
		true)

	_make(&"sell_to_storyteller", "She Doesn't Want Your Junk",
		"Try to sell something to the Storyteller in Ashurim.",
		Achievement.Category.STORY, Achievement.TriggerKind.HIDDEN, {},
		&"", 0, 0,
		"\"I do not buy. I do not sell. Sit. The kettle is on.\"",
		true)

	_make(&"hit_the_pillar", "Treasonous Strike",
		"Strike the Edict pillar in Babilim. Marduk's wards are very polite about it.",
		Achievement.Category.FEATS, Achievement.TriggerKind.HIDDEN, {},
		&"title_pillar_puncher", 300, 0,
		"The pillar makes a single soft chime, like a wet cup tapped with a fingernail. Several Crown guards stop what they are doing.",
		true)

	_make(&"berserker_low_hp_survivor", "Below the Door, Above the Dirt",
		"As Berserker, finish a fight at exactly 1 HP.",
		Achievement.Category.FEATS, Achievement.TriggerKind.HIDDEN, {},
		&"title_one_hp", 1000, 500,
		"The Storyteller has a saying about this. She refuses to repeat it.",
		true)

	_make(&"druid_dragon_drown", "Dragons Are Not Strong Swimmers",
		"As Chaos Druid, attempt to enter water in Dragon form. Revert immediately.",
		Achievement.Category.FEATS, Achievement.TriggerKind.HIDDEN, {},
		&"title_dragon_paddler", 100, 0,
		"Tiamat herself was the salt sea. Her descendants do not, however, swim.",
		true)

	_make(&"assassin_die_to_lockpick", "The Universe Has Tells",
		"As Assassin, fail a lockpick check and die to the trap that sprung as a result.",
		Achievement.Category.FEATS, Achievement.TriggerKind.HIDDEN, {},
		&"title_unlucky_thief", 200, 0,
		"One of the oldest jokes in Babilim's underclass. It is told nightly.",
		true)

	_make(&"mage_oom_in_boss", "All Out of Words",
		"Run out of mana mid-boss-fight.",
		Achievement.Category.FEATS, Achievement.TriggerKind.HIDDEN, {},
		&"", 0, 0,
		"You stand quietly. The fire goes out in your fingers. The boss looks confused.",
		true)

	_make(&"ronin_chain_perfect_1", "First Sequence",
		"Land a chain bonus on a Ronin Form 7 capstone for the first time.",
		Achievement.Category.COMBAT, Achievement.TriggerKind.HIDDEN, {},
		&"title_chain_initiate", 500, 200,
		"Six masters who taught the form, six masters who failed. You.",
		false)

	_make(&"ranger_apex_kills_apex", "Predator-on-Predator",
		"As Ranger in Apex Predator transform, kill another transformed enemy.",
		Achievement.Category.FEATS, Achievement.TriggerKind.HIDDEN, {},
		&"title_apex_apex", 1500, 800,
		"The food chain becomes a dinner table.",
		true)

	_make(&"paladin_solo_no_party", "Why Did You Pick Healer",
		"As Paladin Lightbringer, kill a main boss solo with no allies in range of any heal.",
		Achievement.Category.FEATS, Achievement.TriggerKind.BOSS_DEFEATED_NO_HIT,
		{"boss_id": &"any_main_no_party"}, &"title_solo_healer", 4000, 2500,
		"All those heals, wasted on the air.",
		true)

	_make(&"demon_die_at_noon", "Sun-Cooked",
		"As Demon, die to a non-boss enemy at exactly midday (highest sun debuff).",
		Achievement.Category.FEATS, Achievement.TriggerKind.HIDDEN, {},
		&"title_sun_cooked", 100, 0,
		"Should have stayed indoors.",
		true)

	_make(&"sit_on_throne", "Briefly Royal",
		"Sit on Tiamat's throne (her skull) before fighting her.",
		Achievement.Category.EXPLORATION, Achievement.TriggerKind.HIDDEN, {},
		&"title_briefly_royal", 1500, 500,
		"The skull does not protest. The skull is, after all, a skull.",
		true)

	_make(&"insult_lucifer", "Worst Negotiator",
		"Refuse Lucifer's offer and insult him before Phase 2 begins.",
		Achievement.Category.STORY, Achievement.TriggerKind.HIDDEN, {},
		&"title_terrible_diplomat", 500, 0,
		"He laughs. He is going to kill you with extra effort now.",
		true)

	_make(&"vendor_max_gold", "Buy the Whole Shop",
		"Empty a single vendor's stock entirely in one transaction.",
		Achievement.Category.META, Achievement.TriggerKind.HIDDEN, {},
		&"title_one_buyer_economy", 500, 500,
		"Iddinu in Babilim takes the day off. He goes to the Hanging Gardens and just sits.",
		true)

	_make(&"ten_zone_warning_ignored", "Stubborn Adventurer",
		"Enter a zone while under-leveled by 10+ levels, ten times, without dying.",
		Achievement.Category.FEATS, Achievement.TriggerKind.HIDDEN, {},
		&"title_stubborn", 1500, 500,
		"You may have a problem. Or be very good. We cannot tell.",
		true)

	_make(&"die_to_first_mob", "Lv 1, Day 1",
		"Die to a level-1 mob in your intro zone. Yes. The very first one.",
		Achievement.Category.FEATS, Achievement.TriggerKind.HIDDEN, {},
		&"title_humble_beginnings", 50, 0,
		"It happens. We promise it happens to others. Not us, but others.",
		true)

	_make(&"steal_from_storyteller", "She Will Find You",
		"Try to pickpocket the Storyteller. She will return your hand.",
		Achievement.Category.FEATS, Achievement.TriggerKind.HIDDEN, {},
		&"title_returned_hand", 100, 0,
		"You did not lose the hand permanently. She is not unkind. But she is making a point.",
		true)

	_make(&"talk_to_belitu_100", "Regular at the Goat",
		"Talk to Belitu the Innkeeper 100 times.",
		Achievement.Category.STORY, Achievement.TriggerKind.HIDDEN, {},
		&"title_goat_regular", 500, 250,
		"\"Same drink? Or are we trying something new today.\" She knows. She always knows.",
		true)

	_make(&"five_classes_played", "Tourist of Souls",
		"Reach level 10 with five different classes on this save profile.",
		Achievement.Category.META, Achievement.TriggerKind.HIDDEN, {},
		&"title_tourist_souls", 5000, 2500,
		"You have walked five lives. Each one was harder than promised. Each one was easier than feared.",
		false)

	_make(&"all_nine_classes", "Council of Nine",
		"Reach level 10 with all 9 classes on this save profile (Demon included).",
		Achievement.Category.META, Achievement.TriggerKind.HIDDEN, {},
		&"title_council_nine", 25000, 15000,
		"All nine seats taken. The Storyteller has tea ready for each of you. She knew.",
		false)
