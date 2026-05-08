extends Node

# Autoload: 60+ titles. Cool, humorous, lore-soaked. Awarded via Achievements.
# Player picks one to display in their nameplate.

signal title_unlocked(title_id: StringName)

var titles: Dictionary = {}  # StringName -> Title

func _ready() -> void:
	_register_combat_titles()
	_register_feat_titles()
	_register_sacrifice_titles()
	_register_humor_titles()
	_register_profession_titles()
	_register_meta_titles()

# Single API for awarding a title to the active character. Idempotent —
# re-awarding sets the SaveFlag again but only emits the unlock signal once.
# Mirrors the pattern used by AchievementTracker._award.
func award(title_id: StringName) -> bool:
	if not titles.has(title_id):
		push_warning("[TitleRegistry] award: unknown title_id %s" % title_id)
		return false
	var flag := StringName("title_unlocked_" + String(title_id))
	if SaveFlags.has_permanent(flag):
		return false  # already earned
	SaveFlags.set_permanent(flag, true)
	title_unlocked.emit(title_id)
	return true

func is_unlocked(title_id: StringName) -> bool:
	return SaveFlags.has_permanent(StringName("title_unlocked_" + String(title_id)))

func get_title(id: StringName) -> Title:
	return titles.get(id)

func all_titles() -> Array[Title]:
	var arr: Array[Title] = []
	for t in titles.values():
		arr.append(t)
	return arr

func _make(id: StringName, text: String, desc: String, fmt: int = Title.Format.PREFIX,
		color: Color = Color(0.95, 0.85, 0.55), lore: String = "", secret: bool = false) -> Title:
	var t := Title.new()
	t.id = id
	t.display_text = text
	t.description = desc
	t.format = fmt
	t.color = color
	t.lore = lore
	t.is_secret = secret
	titles[id] = t
	return t

# ----------------------------------------------------------------
# COMBAT TITLES (cool)
# ----------------------------------------------------------------
func _register_combat_titles() -> void:
	_make(&"title_mother_slayer", "Mother-Slayer", "Defeat Tiamat.",
		Title.Format.SUFFIX, Color(1.0, 0.6, 0.4),
		"What walked away from Tiamat's throne hall is no longer the same person who walked in.")

	_make(&"title_fall_walker", "Walker of the Stair", "Defeat Lucifer.",
		Title.Format.SUFFIX, Color(0.85, 0.3, 0.85),
		"You walked the stair of fire, refused his offer, and walked back up. The stair remembers.")

	_make(&"title_demon_hunter", "Demon-Hunter", "Kill 100 demons.",
		Title.Format.SUFFIX, Color(0.85, 0.4, 0.3))

	_make(&"title_grave_walker", "Grave-Walker", "Kill 100 undead.",
		Title.Format.SUFFIX, Color(0.5, 0.5, 0.7))

	_make(&"title_spawn_reaper", "Spawn-Reaper", "Kill 50 Tiamat-spawn.",
		Title.Format.SUFFIX, Color(0.4, 0.7, 0.5))

	_make(&"title_death", "Walker of Many Graves", "Kill 1,000 enemies.",
		Title.Format.PREFIX, Color(0.65, 0.65, 0.7))

	_make(&"title_grim_reaper", "the Grim Reaper", "Kill 10,000 enemies.",
		Title.Format.PREFIX, Color(0.30, 0.30, 0.40),
		"You have outpaced the king of gods in raw arithmetic.")

# ----------------------------------------------------------------
# FEAT TITLES (cool, hard-earned)
# ----------------------------------------------------------------
func _register_feat_titles() -> void:
	_make(&"title_untouched", "the Untouched", "Defeat Tiamat without taking damage.",
		Title.Format.PREFIX, Color(1.0, 0.95, 0.6),
		"Marduk took her in single combat and went home with a limp. You came back without a scratch.")

	_make(&"title_unmarked", "the Unmarked", "Defeat Lucifer without taking damage.",
		Title.Format.PREFIX, Color(1.0, 1.0, 1.0),
		"He marks all who touch him. You did not let him.")

	_make(&"title_tablet_walker", "the Tablet-Untouched", "Defeat Kingu without damage.",
		Title.Format.PREFIX, Color(0.8, 0.5, 0.7))

	_make(&"title_mother_cracker", "the Mother-Cracker", "Defeat Tiamat in under 60 seconds.",
		Title.Format.PREFIX, Color(1.0, 0.3, 0.4),
		"Marduk took an afternoon. You took less than a minute.")

	_make(&"title_stair_skipper", "the Stair-Skipper", "Defeat Lucifer in under 60 seconds.",
		Title.Format.PREFIX, Color(0.95, 0.4, 0.6),
		"He had not finished his opening line.")

	_make(&"title_crown_salt_fire", "Crown of Salt and Fire",
		"Defeat both final bosses in under 60 seconds combined.",
		Title.Format.FULL_REPLACE, Color(1.0, 0.55, 0.20),
		"The cycle goes from Tiamat to Lucifer in less than a minute. The world cannot tell whether to call you a hero or a problem.")

	_make(&"title_beneath_notice", "Beneath Her Notice",
		"Defeat Tiamat at level 70 or below.",
		Title.Format.SUFFIX, Color(0.7, 0.4, 0.6),
		"She did not see you coming. She does not see you going.")

	_make(&"title_seven_breaths", "of the Seven Breaths",
		"Master all 49 Ronin breathing forms.",
		Title.Format.SUFFIX, Color(1.0, 0.9, 0.5),
		"Six lifetimes of training, in one. The temples write you into their histories.")

	_make(&"title_word_keeper", "the Word-Keeper", "Unlock all 49 Mage spells.",
		Title.Format.PREFIX, Color(0.85, 0.55, 1.0),
		"Old Asaridu wanted you to remember everything. You did.")

	_make(&"title_chain_initiate", "of the First Chain", "Land your first Form 7 chain bonus.",
		Title.Format.SUFFIX, Color(0.85, 0.85, 0.45))

	_make(&"title_apex_apex", "Apex of Apexes", "As Ranger Apex Predator, kill another transformed enemy.",
		Title.Format.PREFIX, Color(0.4, 0.7, 0.4))

# ----------------------------------------------------------------
# SACRIFICE TITLES (the Heaven-Rule walked-back set)
# Awarded by SacrificeRitual.walk_back when a Demon character chooses
# to sacrifice the Demon form to claim Heaven. See CHARACTER_DESIGN.md
# § 8.4 + DEMON_VISUAL_TRANSFORMATION.md § 18.7.
# ----------------------------------------------------------------
func _register_sacrifice_titles() -> void:
	_make(&"the_mortal_returned", "The Mortal Returned",
		"Walk back through Lucifer's gate. Sacrifice the Demon form to reclaim mortality.",
		Title.Format.FULL_REPLACE, Color(0.95, 0.92, 0.80),
		"What walks back through Lucifer's gate is no longer mortal — but you walked back anyway. The gate does not open twice. The sword has decided you. It does not decide many.")

	# Display variant of the same earn. Player can pick either at the title-equip screen.
	_make(&"twice_walker", "Twice-Walker",
		"Sacrifice the Demon form via the Heaven Rule. Display variant of The Mortal Returned.",
		Title.Format.SUFFIX, Color(0.85, 0.82, 0.65),
		"You walked through the gate. You walked back. Two crossings of Lucifer's threshold — fewer have done it than have killed Tiamat.")

# ----------------------------------------------------------------
# HUMOR TITLES (the funny ones)
# ----------------------------------------------------------------
func _register_humor_titles() -> void:
	_make(&"title_self_made", "the Self-Made", "Die to your own ability.",
		Title.Format.PREFIX, Color(0.9, 0.6, 0.6),
		"At least the technique was sound.", true)

	_make(&"title_potion_addict", "Apothecary's Best Customer",
		"Drink 50 potions in a single dungeon.",
		Title.Format.SUFFIX, Color(0.7, 0.5, 0.85),
		"The Salt-and-Stone Apothecary inscribes your name on a small bronze plaque.", true)

	_make(&"title_glade_problem", "Has a Glade Problem", "Die three times to the Glade Terror.",
		Title.Format.SUFFIX, Color(0.5, 0.7, 0.5),
		"It is one creature. We have faith.", true)

	_make(&"title_well_diver", "the Well-Diver", "Fall into Old Asaridu's well.",
		Title.Format.PREFIX, Color(0.4, 0.6, 0.85),
		"\"Out. Now.\" - O. Asaridu, from beyond.", true)

	_make(&"title_pillar_puncher", "the Pillar-Puncher", "Strike Babilim's Iron Pillar.",
		Title.Format.PREFIX, Color(0.8, 0.7, 0.4),
		"The pillar chimed. Several Crown guards reconsidered their afternoon.", true)

	_make(&"title_one_hp", "the 1-HP Hero", "Finish a fight at exactly 1 HP as Berserker.",
		Title.Format.PREFIX, Color(0.95, 0.3, 0.3),
		"Living on borrowed time. Refusing to give it back.", true)

	_make(&"title_dragon_paddler", "the Dragon-Paddler", "Try to swim as Druid Dragon.",
		Title.Format.PREFIX, Color(0.6, 0.85, 0.8),
		"Tiamat herself was the salt sea. Her descendants do not, however, swim.", true)

	_make(&"title_unlucky_thief", "the Unlucky Thief", "As Assassin, die to a trap you triggered.",
		Title.Format.PREFIX, Color(0.6, 0.3, 0.3),
		"The universe has tells. You missed them.", true)

	_make(&"title_sun_cooked", "Sun-Cooked", "As Demon, die to a non-boss at midday.",
		Title.Format.PREFIX, Color(1.0, 0.7, 0.3),
		"Should have stayed indoors.", true)

	_make(&"title_briefly_royal", "Briefly Royal", "Sit on Tiamat's throne (her skull).",
		Title.Format.SUFFIX, Color(0.85, 0.85, 0.95),
		"The skull does not protest. The skull is, after all, a skull.", true)

	_make(&"title_terrible_diplomat", "the Terrible Diplomat", "Insult Lucifer.",
		Title.Format.PREFIX, Color(0.85, 0.3, 0.5),
		"He laughs. He is going to kill you with extra effort now.", true)

	_make(&"title_one_buyer_economy", "Single-Buyer Economy",
		"Empty a vendor's stock in one transaction.",
		Title.Format.SUFFIX, Color(1.0, 0.85, 0.4),
		"Iddinu in Babilim takes the day off. He goes to the Hanging Gardens and just sits.", true)

	_make(&"title_stubborn", "the Stubborn", "Enter under-leveled zones 10 times without dying.",
		Title.Format.PREFIX, Color(0.7, 0.7, 0.4),
		"You may have a problem. Or be very good. We cannot tell.", true)

	_make(&"title_humble_beginnings", "the Humble", "Die to a level-1 mob.",
		Title.Format.PREFIX, Color(0.6, 0.65, 0.55),
		"It happens. We promise it happens to others.", true)

	_make(&"title_returned_hand", "the Returned-Hand", "Try to pickpocket the Storyteller.",
		Title.Format.PREFIX, Color(0.7, 0.5, 0.7),
		"She did not keep it. She made a point.", true)

	_make(&"title_goat_regular", "Regular at the Goat", "Talk to Belitu 100 times.",
		Title.Format.SUFFIX, Color(0.85, 0.7, 0.5),
		"\"Same drink? Or are we trying something new today?\"", true)

	_make(&"title_door_listener", "the Door-Listener", "Stand at the Silent Gate and listen.",
		Title.Format.PREFIX, Color(0.5, 0.3, 0.6),
		"You heard what is on the other side. You did not tell anyone. The Storyteller knows already.", true)

	_make(&"title_tourist_souls", "Tourist of Souls", "Reach lvl 10 with five classes.",
		Title.Format.PREFIX, Color(0.7, 0.85, 0.95))

	_make(&"title_council_nine", "of the Council of Nine", "Reach lvl 10 with all 9 classes.",
		Title.Format.SUFFIX, Color(1.0, 0.9, 0.5),
		"All nine seats taken. The Storyteller has tea ready for each of you.")

	_make(&"title_solo_healer", "the Solo Healer", "Beat a boss as Lightbringer with no allies in heal range.",
		Title.Format.PREFIX, Color(0.95, 0.95, 0.6),
		"All those heals, wasted on the air.", true)

# ----------------------------------------------------------------
# PROFESSION TITLES
# ----------------------------------------------------------------
func _register_profession_titles() -> void:
	_make(&"title_forge_master", "the Forge-Master", "Max Smithing.",
		Title.Format.PREFIX, Color(1.0, 0.5, 0.2))
	_make(&"title_stone_whisperer", "the Stone-Whisperer", "Max Mining.",
		Title.Format.PREFIX, Color(0.6, 0.55, 0.5))
	_make(&"title_heart_cutter", "the Heart-Cutter", "Max Woodcutting.",
		Title.Format.PREFIX, Color(0.5, 0.7, 0.45))
	_make(&"title_world_maker", "the World-Maker", "Max Crafting.",
		Title.Format.PREFIX, Color(0.85, 0.85, 0.6))
	_make(&"title_marduks_hands", "Marduk's Hands", "Max all four professions.",
		Title.Format.SUFFIX, Color(1.0, 0.85, 0.4),
		"You build, you cut, you mine, you forge. The first king-of-gods built the world from a corpse. You build it from less.")

# ----------------------------------------------------------------
# META TITLES (prestige, exploration)
# ----------------------------------------------------------------
func _register_meta_titles() -> void:
	_make(&"title_returner", "the Returner", "Reach prestige 1.",
		Title.Format.PREFIX, Color(0.6, 0.7, 0.85))
	_make(&"title_halfway_sun", "Halfway to the Sun", "Reach prestige 5.",
		Title.Format.SUFFIX, Color(1.0, 0.85, 0.4))
	_make(&"title_cycle_closer", "Closer of Cycles", "Reach prestige 10 (max).",
		Title.Format.FULL_REPLACE, Color(1.0, 1.0, 0.7),
		"Ten cycles. Ten Tiamats. Ten Lucifers. The world has stopped trying to hide its secrets from you.")
	_make(&"title_world_walker", "the World-Walker", "Discover every zone.",
		Title.Format.PREFIX, Color(0.7, 0.85, 0.55))
	_make(&"title_cradle_walker", "of the Cradle", "Discover all 6 intro zones + Ashurim.",
		Title.Format.SUFFIX, Color(0.8, 0.7, 0.55))
	_make(&"title_inheritor", "the Inheritor", "Unlock the Demon class.",
		Title.Format.PREFIX, Color(0.5, 0.0, 0.55),
		"What walks back through Lucifer's gate carries the gate's signature in its bones.")
	_make(&"title_sword_chosen", "the Sword-Chosen", "Obtain Heaven.",
		Title.Format.PREFIX, Color(1.0, 1.0, 1.0),
		"The pure white katana chose your hand. There has only ever been one wielder per cycle. You.", true)
	_make(&"title_seven_champions", "of Seven Champions", "Obtain all 7 class legendaries.",
		Title.Format.SUFFIX, Color(1.0, 0.85, 0.3),
		"Each of the seven championed someone. They championed you back.")

	# Storyteller's nickname (hidden)
	_make(&"title_named_one", "the Named-One",
		"Speak with the Storyteller after every main boss kill in a single cycle.",
		Title.Format.PREFIX, Color(0.95, 0.85, 0.6),
		"She uses the same voice for everyone. The voice is different for you.",
		true)
