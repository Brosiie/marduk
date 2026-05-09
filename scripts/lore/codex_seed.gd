extends Node

# CodexSeed, autoload that registers every canonical lore entry with
# the CodexRegistry on _ready. Pure data; no runtime logic.
#
# Entry shape:
#   { id: StringName, category: StringName, display_name: String,
#     unlock_hint: String, body: String }
#
# Categories are CodexRegistry's standard set: regions, characters,
# items, lore, bestiary, achievements. Add to those by editing the
# corresponding _seed_*() function.
#
# When the player encounters a region / NPC / item for the first time,
# CodexRegistry.unlock(id) flips the entry from locked to readable.

func _ready() -> void:
	var codex := get_node_or_null("/root/CodexRegistry")
	if codex == null:
		push_warning("CodexSeed: CodexRegistry not loaded; entries skipped")
		return
	_seed_regions(codex)
	_seed_classes(codex)
	_seed_characters(codex)
	_seed_lore(codex)
	_seed_items(codex)
	_seed_bestiary(codex)
	# Auto-seed every mob_id from MobRegistry that doesn't already have a
	# hand-written bestiary entry. The manual _seed_bestiary entries above
	# carry the polished prose; this pass picks up the long tail (60+ mobs)
	# so EnemyBase._die's `cdx.unlock(b_<mob_id>)` resolves to a real entry
	# with the mob's name + lore instead of the fallback "id: misc" stub.
	_seed_bestiary_from_mob_registry(codex)

# Helper: register one entry; unlock_hint defaults to a generic line.
func _entry(codex: Node, id: StringName, category: StringName,
		display_name: String, body: String,
		unlock_hint: String = "") -> void:
	if unlock_hint == "":
		unlock_hint = "Discover this in the world to unlock the entry."
	codex.register({
		"id": id,
		"category": category,
		"display_name": display_name,
		"body": body,
		"unlock_hint": unlock_hint,
	})

# ----------------------------------------------------------------
# Regions (14): one entry per zone, unlocked the first time the
# player enters that scene or attunes its lodestone.
# ----------------------------------------------------------------
func _seed_regions(codex: Node) -> void:
	_entry(codex, &"r_sword_vow_ruins", &"regions", "Sword-Vow Ruins",
		"The fortress where Lord Ennum took the Sword-Vow before Tashmu's blade ended his oath. The courtyard is broken pillars and burned banners; the throne hall holds Enforcer Kazat, who watched Ennum die and accepted the iron mask Tashmu offered him afterward. Most champions begin here. Some never leave.",
		"Walk the courtyard.")
	_entry(codex, &"r_the_cradle", &"regions", "The Cradle",
		"Sumerian temple grounds, cracked open by the same rift that loosed Tiamat. Mournful ruin under a pale rose sky. Three tiers of weathered ziggurat, with offering plinths down the central axis. Lord Ennum's first vows were spoken here; tradition has it the next champion's first kill should be made within sight of the dais.",
		"Walk the temple grounds.")
	_entry(codex, &"r_the_reed_wastes", &"regions", "The Reed Wastes",
		"A marsh fed by Tiamat's seep. Plank pathways crisscross brown water; broken huts dot the shoreline. The reeds whisper at night when the moon strikes the seal. Mu-Ash, the Throat of the Wastes, feeds on whatever falls in.",
		"Cross the planks.")
	_entry(codex, &"r_lapis_bay", &"regions", "Lapis Bay",
		"A trading dock that turned smuggler's port after the Iron Crown choked the inland routes. The lighthouse blew out the year Tiamat woke; no one has lit it since. Crates pile on the pier, half-rotted, owned by ghosts.",
		"Reach the dock.")
	_entry(codex, &"r_bone_mountains", &"regions", "Bone Mountains",
		"A pass strewn with the ribs of giants, or so the carvers say. The path winds between rock walls and bleached bone middens. The Ossuary at the apex holds the ribs of something so large its skeleton serves as the dungeon ceiling.",
		"Climb the pass.")
	_entry(codex, &"r_verdant_wound", &"regions", "Verdant Wound",
		"A forest growing through stone ruins, the trees rooted in the bones of an older empire. The corruption from Tiamat's breach manifests here as warped foliage; the sap is black, the leaves silver. Beautiful, in the worst way.",
		"Step into the wound.")
	_entry(codex, &"r_ember_steppes", &"regions", "Ember Steppes",
		"Wind-blown ash plain east of Ashurim. Hassu the Hooked's raiders camp here in tent-rings. Old fire pits dot the steppe; some still warm despite no one having walked there for a century.",
		"Walk the ash.")
	_entry(codex, &"r_mist_vale", &"regions", "Mist Vale",
		"A grove perpetually fogged by the river spirits Lord Ennum mediated peace with. The Coven Glen druids learn their first breath here. Standing stones in a half-circle mark a path that leads to a memorial cairn for Saru, when she falls.",
		"Walk the mist.")
	_entry(codex, &"r_shrieking_highlands", &"regions", "Shrieking Highlands",
		"Wind-cliffs above the empire's old border. Storm-cut runestones cluster around an abandoned shrine where the mountain priests prayed against Tiamat. The wind on the cliff edge sounds like screaming because it carries the prayers still.",
		"Climb the cliffs.")
	_entry(codex, &"r_sundered_coast", &"regions", "Sundered Coast",
		"Where Tiamat's first wave broke the cliffs. Pillars lie on their sides in the surf. The wreck of the Aurim, a Crown ship that ran aground trying to flee Babilim during the breach, is half-buried in the sand. Salvageable, but cursed.",
		"Reach the wreck.")
	_entry(codex, &"r_black_citadel", &"regions", "Black Citadel",
		"Tashmu's seat of power, raised on the rubble of the old keep. Iron banners, basalt walls, halls so dark only the throne is lit. Tashmu sits there still, as far as the world knows, though every champion who has reached the inner throne has reported him absent and the chair warm.",
		"Breach the gate.")
	_entry(codex, &"r_fire_stair", &"regions", "Fire Stair",
		"A spiral basalt stair descending into Lucifer's domain. Each step burns hotter than the one above. The Self-That-Said-Yes waits at the summit. The contract waits below.",
		"Descend the stair.")
	_entry(codex, &"r_ashurim", &"regions", "Ashurim",
		"The convergence town. Every class prologue ends here; the Storyteller recognizes everyone who arrives. Market stalls, an inn, the plaza fountain. Belitu, Iddinu, and the Storyteller hold the three quest-lines that branch the early game.",
		"Walk into the plaza.")
	_entry(codex, &"r_babilim", &"regions", "Babilim",
		"Capital of the Iron Crown. Holy and corrupt in equal measure. The grand chapel holds the Oracle, who has written your name on the pillar; the High Priest insists the prophecy is dust; the Crown's general says it doesn't matter what either of them says.",
		"Reach the capital.")

# ----------------------------------------------------------------
# Player classes (9): one entry per class, unlocked when chosen at
# CharacterCreation.
# ----------------------------------------------------------------
func _seed_classes(codex: Node) -> void:
	_entry(codex, &"c_berserker", &"characters", "Berserker",
		"Heavy melee. Ash-steppe tribesmen who burn rage into damage. At 100 rage they swing for +50% dmg and move +15% faster. Wielders of axes and great-weapons.",
		"Pick this class.")
	_entry(codex, &"c_assassin", &"characters", "Assassin",
		"Stealth-class. Whisper Shrine initiates who learned that silence is the truest blade. Stealth toggles invisibility; first strike from stealth crits and bonus-damages. Daggers are the calling card.",
		"Pick this class.")
	_entry(codex, &"c_ronin", &"characters", "Ronin",
		"Sword-vow class. Took the oath at the Sword-Vow Ruins, lost their lord, walks the world in his memory. 49 breathing forms across 7 styles. Hardest class to play; the most rewarding.",
		"Pick this class.")
	_entry(codex, &"c_ranger", &"characters", "Ranger",
		"Bow specialist. Greenheart Glade's hunters; the only class that brings a hawk companion. Focus stacks per consecutive hit; the higher the focus, the truer the shot.",
		"Pick this class.")
	_entry(codex, &"c_mage", &"characters", "Mage",
		"Spell-class. Inkstone Tower scribes who learned the syllables of unmaking. Mana regen 1/sec base; surge potions give 10x for 10s. 49 spells across 7 schools (Fire / Frost / Lightning / Arcane / Holy / Shadow / Void).",
		"Pick this class.")
	_entry(codex, &"c_chaos_druid", &"characters", "Chaos Druid",
		"Shapeshifter. Coven Glen witches whose hunters' lineage fused with the wild. Mana to cast, stamina drains in beast form. Capstone: Spawn of Tiamat dragon.",
		"Pick this class.")
	_entry(codex, &"c_demon", &"characters", "Demon (locked)",
		"Hybrid. Lifesteal vampire; heals from damage dealt + max-HP gain on each kill. Locked behind defeating Lucifer. Once unlocked, available to ALL future characters on the same save profile.",
		"Defeat Lucifer to unlock.")
	_entry(codex, &"c_paladin_guardian", &"characters", "Paladin Guardian",
		"Tank. Plate, shield, hammer. Sun-Sworn Chapel veterans who chose to defend their order against the siege. Heavy mitigation, holy damage vs undead and demons.",
		"Pick this class.")
	_entry(codex, &"c_paladin_lightbringer", &"characters", "Paladin Lightbringer",
		"Healer. Mail (no plate), ceremonial mace, strong heals. The Chapel's other half: those who survived because they could heal, but who blame themselves for not having held the wall.",
		"Pick this class.")

# ----------------------------------------------------------------
# Story characters (12): named NPCs whose lore matters.
# ----------------------------------------------------------------
func _seed_characters(codex: Node) -> void:
	_entry(codex, &"c_storyteller", &"characters", "The Storyteller of Ashurim",
		"An elder of indeterminate age who sits in the plaza and tells the world's history to anyone who asks. She remembers more than any living person should. The Crown leaves her alone; nobody is sure why.",
		"Speak with her in Ashurim.")
	_entry(codex, &"c_iddinu", &"characters", "Iddinu, Quartermaster",
		"Runs supply for Ashurim's volunteer guard. Friendly. Practical. Three crates of iron from his ledgers always come back short, and he never quite explains why. What you find in his coded ledger ends a friendship and starts a hunt.",
		"Take work from him.")
	_entry(codex, &"c_belitu", &"characters", "Belitu, Market Girl",
		"Twelve-year-old at the fountain. Her brother walked into The Cradle two days ago. She has eight copper coins saved and will give them all if you bring him back. Whether he comes back alive is the test of the early game.",
		"Speak with her in the plaza.")
	_entry(codex, &"c_lord_ennum", &"characters", "Lord Ennum the Sword-Vowed",
		"Ronin lord of the Sword-Vow Keep. Took the vow before Tashmu's blade ended him. His sword is half-buried in the courtyard; pick it up to see his last memory. The vow is what drives the Ronin class; whether you keep it is yours to decide.",
		"Find his broken sword.")
	_entry(codex, &"c_tashmu", &"characters", "Tashmu the Iron-Crowned",
		"Usurper-king of the Iron Crown. Took the throne of Babilim with Kazat's hand on Ennum's neck. Has not been seen since the breach; rumor places him in the Black Citadel; the throne there is always warm but always empty when champions arrive.",
		"Investigate the throne.")
	_entry(codex, &"c_kazat", &"characters", "Enforcer Kazat, Iron-Faced",
		"Tashmu's blade. Held Lord Ennum's neck while Tashmu raised the killing blade. Wears the iron mask Tashmu gave him afterward; some say the mask grew into him. The first major boss most ronin players face.",
		"Defeat him at the Sword-Vow throne.")
	_entry(codex, &"c_hassu", &"characters", "Hassu the Hooked",
		"Bandit chieftain of the Ash-Step Camp. Killed berserker fathers for sport. Hooked-spear specialist; the spear was a gift from Tashmu the year of the breach. Whether to spare or slay him affects an Ashurim NPC's dialogue forever.",
		"Confront him in the steppes.")
	_entry(codex, &"c_master_sapum", &"characters", "Master Sapum, Five-Mouthed",
		"Headmaster of the Whisper Shrine, the Assassin's training ground. Has been feeding the shrine to Tiamat's seal in exchange for power. Five mouths grew on his face the year of the betrayal; he no longer needs to speak to be heard.",
		"Strike him at the shrine.")
	_entry(codex, &"c_saru", &"characters", "Saru the Wandering Ronin (companion)",
		"You meet her in the Bone Mountains, tied to a rock by raiders. You free her. She joins your party, fights alongside you for ten conversation beats, learns who you really are, and dies in the Black Citadel boss fight defending you from a hit you didn't see coming. Her sword is engraved with your name afterward.",
		"Free her in the Bone Mountains.")
	_entry(codex, &"c_oracle", &"characters", "The Oracle of Babilim",
		"Sits in a cell beneath the grand chapel. Has written your name on the pillar before you arrived. The Crown is interested but will not say why. Her prophecies tend to come true, but never the way she said them.",
		"Visit the holy sanctum.")
	_entry(codex, &"c_lucifer", &"characters", "Lucifer the Diplomat",
		"Sits at the bottom of the Fire Stair. Wears a smile and offers a contract. The contract reads better than any deal you have been offered before. Reading it carefully is harder than refusing it.",
		"Descend the Fire Stair.")
	_entry(codex, &"c_tiamat", &"characters", "Tiamat, Mother of Wrong",
		"The breach. The reason. The end of the visible game. Three forms: Drowned, Risen, Mother-of-Monsters dragon. Defeating her sets the world's clock back; refusing to defeat her sets your own clock forward.",
		"Reach the Black Citadel.")

# ----------------------------------------------------------------
# Lore drops (6 starter): paragraph-length world history entries.
# ----------------------------------------------------------------
func _seed_lore(codex: Node) -> void:
	_entry(codex, &"l_the_breach", &"lore", "The Breach",
		"Three years ago, the seal on Tiamat's prison cracked. The cause was disputed at the time; the Iron Crown blamed the druids, the druids blamed the Crown's miners. Both were right. The miners were chasing a vein the Crown promised them; the vein was the seal itself; the druids had been told a hundred years to stop digging there. The breach is the wound through which everything leaks.",
		"Read a torn page in the Cradle.")
	_entry(codex, &"l_iron_crown", &"lore", "The Iron Crown",
		"Tashmu's empire. Holds Babilim, Ashurim's southern road, the Bone Mountains pass, and the Sundered Coast. Calls itself the only thing standing between the world and the breach. The world is unsure; the world is also tired.",
		"Read a Crown decree.")
	_entry(codex, &"l_sword_vow", &"lore", "The Sword-Vow",
		"A ronin oath: the sword serves the lord, the lord serves the people, the people are the empire's breath. Lord Ennum spoke the vow at the Sword-Vow Ruins. Tashmu's blade ended him before he could uphold it. The Ronin class begins by taking the vow back.",
		"Find Lord Ennum's sword.")
	_entry(codex, &"l_breathing_styles", &"lore", "On Breathing",
		"A combat technique borrowed from the mountain priests. Cycle stamina through specific patterns to match demon speed. Seven styles; each style has seven forms; the seventh form of each style is the capstone. Sun Breathing, the founding style, must be earned; the others must be chosen.",
		"Speak with a breath master.")
	_entry(codex, &"l_lucifer_contract", &"lore", "The Contract",
		"Lucifer's offer. Not formally written down; describes itself as 'the version of you that does not have to die for this'. Refusing it kills you in the original timeline. Accepting it kills the version of you who would have refused, every time. Either way, someone dies.",
		"Reach the Fire Stair.")
	_entry(codex, &"l_heaven_blade", &"lore", "Heaven, the Sun-Forged",
		"A katana. Drops only from the Self-That-Said-Yes, only for Ronin who have mastered Sun Breathing. Permanently kills any demon or undead it strikes. Each kill adds 0.01% to its damage stack, persisting through every prestige cycle. The blade whispers your name once at 1000 kills; nobody knows what happens at 10000.",
		"Master Sun Breathing; defeat the Self-That-Said-Yes.")

# ----------------------------------------------------------------
# Items (6 unique drops worth a lore entry).
# ----------------------------------------------------------------
func _seed_items(codex: Node) -> void:
	_entry(codex, &"i_heaven", &"items", "Heaven (Katana, Legendary)",
		"Sun-forged. Slays demons and undead in a single strike. +0.0001 damage per matching kill, permanent across all prestige cycles. Carried only by ronin who took Sun Breathing to the seventh form. The world has only ever seen one of these.",
		"Slay the Self-That-Said-Yes as a Ronin.")
	_entry(codex, &"i_lucifers_shed", &"items", "Lucifer's Shed (Charm)",
		"A scrap of contract paper, signed but not by you. Worn as a charm, it converts the Demon's Blood gain to come from damage TAKEN instead of dealt; cuts ability HP cost in half; reduces damage taken by 15%. The original contract is in the Fire Stair.",
		"Defeat Lucifer.")
	_entry(codex, &"i_ennums_blade", &"items", "Lord Ennum's Sword (Greatsword)",
		"Half-buried in the Sword-Vow courtyard. Pulling it up triggers a flashback of his last vow. Wieldable thereafter, but the blade leans toward your hand even when sheathed; it remembers.",
		"Pick it up in the Sword-Vow courtyard.")
	_entry(codex, &"i_belitus_pendant", &"items", "Belitu's Brother's Pendant (Charm)",
		"A copper disc her brother wore, found on his body in the Cradle. Returning it to her completes her quest and unlocks a flashback at the plaza fountain.",
		"Find it in the Cradle.")
	_entry(codex, &"i_iron_mask", &"items", "Iron Mask (Helm)",
		"Tashmu's gift to Kazat after the killing of Lord Ennum. The mask grew into him over the years. Drops from Kazat; cannot be unequipped once worn.",
		"Slay Kazat.")
	_entry(codex, &"i_oracles_pillar", &"items", "Oracle's Pillar (Lore Stone)",
		"A fragment of the pillar in Babilim's grand chapel. Carries one verse of the Oracle's prophecy. Multiple fragments combine to read the full prophecy.",
		"Find a fragment in the holy sanctum.")

# ----------------------------------------------------------------
# Bestiary (8 starter mob types).
# ----------------------------------------------------------------
func _seed_bestiary(codex: Node) -> void:
	_entry(codex, &"b_usurper_footman", &"bestiary", "Tashmu's Footman",
		"Conscripted from farms Lord Ennum used to visit. Some remember Ennum's kindness; most have decided not to. Iron livery, spear, shield. Patrol formation by twos.",
		"Defeat one in the Sword-Vow Ruins.")
	_entry(codex, &"b_usurper_archer", &"bestiary", "Tashmu's Archer",
		"Castle-guard variant trained for the rooftops. Backpedals from melee, looses arrows from rooftops, never quite gets the arc right.",
		"Defeat one.")
	_entry(codex, &"b_raider_grunt", &"bestiary", "Ash-Step Raider",
		"A footsoldier under Hassu. Tattooed for grief. Will tell anyone who listens that he was promised a horse.",
		"Defeat one in the Ember Steppes.")
	_entry(codex, &"b_shrine_acolyte", &"bestiary", "Whisper Acolyte",
		"First-year initiate of the Whisper Shrine. Practices the silent walk; has not yet realized Master Sapum is feeding the shrine to the seal.",
		"Defeat one.")
	_entry(codex, &"b_binding_construct", &"bestiary", "Binding Construct",
		"Reanimated bone hybrid bound by druidic rope-magic gone wrong. Slow, hard to put down, immune to poison.",
		"Defeat one in the Bone Mountains.")
	_entry(codex, &"b_blood_hunter", &"bestiary", "Blood-Hunter",
		"A vampire-tier mob found in the Verdant Wound. Drinks from the corruption rather than the living, but doesn't say no to either.",
		"Defeat one.")
	_entry(codex, &"b_corrupted_wolf", &"bestiary", "Corrupted Wolf",
		"Forest wolves twisted by Tiamat's seep. Black sap weeping from their fur; teeth too long; minds the wolves they used to be still half there.",
		"Defeat one in the Verdant Wound.")
	_entry(codex, &"b_animated_book", &"bestiary", "Animated Book",
		"Inkstone Tower books that read themselves until the binding gave way. Float. Fire pages like darts. Surrender if their spine is cracked.",
		"Defeat one in the Inkstone Tower.")

# Walks every mob declared in MobRegistry and registers a fallback
# bestiary entry for any id not already covered by the hand-written
# block above. Skip-if-exists keeps the curated entries authoritative;
# this pass exists so the long tail (Lapis Bay, Mist Vale, Sundered
# Coast, etc) all have entries the moment the player kills one.
#
# CodexRegistry's `register()` is idempotent and overwrites metadata,
# so we explicitly check `_entries.has(id)` first to avoid clobbering
# the hand-written prose with the registry's shorter lore field.
func _seed_bestiary_from_mob_registry(codex: Node) -> void:
	var registry := get_node_or_null("/root/MobRegistry")
	if registry == null:
		return
	var mobs_dict = registry.get("mobs") if "mobs" in registry else null
	if not (mobs_dict is Dictionary):
		return
	var existing: Dictionary = codex.get("_entries") if "_entries" in codex else {}
	for mob_id in (mobs_dict as Dictionary).keys():
		var entry_id := StringName("b_" + String(mob_id))
		if existing.has(entry_id):
			continue
		var mob = mobs_dict[mob_id]
		if mob == null:
			continue
		var name: String = String(mob.get("display_name") if "display_name" in mob else String(mob_id))
		var lore: String = String(mob.get("lore") if "lore" in mob else "")
		if lore == "":
			lore = "An adversary of Marduk. Field notes pending."
		var zone: StringName = StringName(mob.get("home_zone") if "home_zone" in mob else &"")
		var hint: String = "Defeat one"
		if zone != &"":
			hint = "Defeat one in %s." % String(zone).capitalize().replace("_", " ")
		else:
			hint = "Defeat one in the field."
		_entry(codex, entry_id, &"bestiary", name, lore, hint)
