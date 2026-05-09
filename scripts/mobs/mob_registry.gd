extends Node

# Autoload: 60+ mobs spread across the world. Each mob has lore. Reading every
# codex entry would teach a careful player half the world's history.

var mobs: Dictionary = {}  # StringName -> Mob

func _ready() -> void:
	_register_cradle_mobs()
	_register_iron_crown_mobs()
	_register_reed_wastes_mobs()
	_register_lapis_bay_mobs()
	_register_bone_mountains_mobs()
	_register_verdant_wound_mobs()
	_register_ember_steppes_mobs()
	_register_mist_vale_mobs()
	_register_shrieking_highlands_mobs()
	_register_sundered_coast_mobs()
	_register_black_citadel_mobs()
	_register_fire_stair_mobs()

func get_mob(id: StringName) -> Mob:
	return mobs.get(id)

func mobs_in_zone(zone: StringName) -> Array[Mob]:
	var arr: Array[Mob] = []
	for m: Mob in mobs.values():
		if m.home_zone == zone:
			arr.append(m)
	return arr

func _make(id: StringName, name: String, lore: String,
		zone: StringName, min_lvl: int, max_lvl: int,
		role: int, tags: Array, hp: float, dmg: float,
		armor: float = 4.0, move: float = 3.5, xp: int = 25) -> Mob:
	var m := Mob.new()
	m.id = id
	m.display_name = name
	m.lore = lore
	m.home_zone = zone
	m.min_level = min_lvl
	m.max_level = max_lvl
	m.role = role
	for t in tags:
		m.tags.append(int(t))
	m.base_hp = hp
	m.base_damage = dmg
	m.base_armor = armor
	m.move_speed = move
	m.xp_reward = xp
	mobs[id] = m
	return m

# ----------------------------------------------------------------
# THE CRADLE (intros)
# ----------------------------------------------------------------
func _register_cradle_mobs() -> void:
	# Berserker intro - Ash-Step Camp
	_make(&"raider_grunt", "Ash-Step Raider",
		"A footsoldier under Hassu. Tattooed for grief. Will tell anyone who listens that he was promised a horse.",
		&"ash_step_camp", 1, 4, Mob.Role.GRUNT, [Mob.Tag.HUMAN], 50.0, 8.0)
	_make(&"raider_archer", "Ash-Step Archer",
		"Keeps to the rocks above the camp. Was a goat-herder until last winter.",
		&"ash_step_camp", 2, 5, Mob.Role.ARCHER, [Mob.Tag.HUMAN], 40.0, 12.0, 3.0, 3.0)
	_make(&"raider_chieftain_minor", "Hassu's Lieutenant",
		"Carries a hooked spear like Hassu's, but smaller. Wants Hassu's job. Will not get it.",
		&"ash_step_camp", 4, 5, Mob.Role.TANK, [Mob.Tag.HUMAN], 110.0, 16.0, 6.0, 3.5, 60)

	# Assassin intro - Whisper Shrine
	_make(&"shrine_acolyte", "Whisper Acolyte",
		"A first-year initiate of the Whisper Shrine. Practices the silent walk. Has not yet realized Sapum is feeding the shrine to the seal.",
		&"whisper_shrine", 1, 4, Mob.Role.RUSHER, [Mob.Tag.HUMAN], 45.0, 10.0, 3.0, 4.5)
	_make(&"shrine_zealot", "Whisper Zealot",
		"Senior brother. Has noticed something is wrong. Refuses to think about it. Throws daggers from the dark.",
		&"whisper_shrine", 3, 5, Mob.Role.ARCHER, [Mob.Tag.HUMAN], 60.0, 14.0, 4.0, 4.0, 45)

	# Ronin intro - Sword-Vow Ruins
	_make(&"usurper_footman", "Tashmu's Footman",
		"Conscripted from the same farms Lord Ennum used to visit. Some of them remember Ennum's kindness. Most have decided not to.",
		&"sword_vow_ruins", 1, 4, Mob.Role.GRUNT, [Mob.Tag.HUMAN], 55.0, 9.0)
	_make(&"usurper_archer", "Tashmu's Archer",
		"Stations on the burned ramparts. Aims well. Sleeps badly.",
		&"sword_vow_ruins", 2, 5, Mob.Role.ARCHER, [Mob.Tag.HUMAN], 45.0, 13.0, 3.0, 3.0, 35)

	# Ranger intro - Greenheart Glade
	_make(&"corrupted_wolf", "Tiamat-Touched Wolf",
		"Was a wolf, before the seal cracked. Now there are too many teeth, and the eyes are wrong, and the breath smells of salt water.",
		&"greenheart_glade", 1, 5, Mob.Role.RUSHER, [Mob.Tag.BEAST, Mob.Tag.SPAWN],
		70.0, 14.0, 3.0, 5.5, 35)
	_make(&"forest_blight", "Forest Blight",
		"Was a moss patch, before the seal cracked. Now it has ideas about you.",
		&"greenheart_glade", 2, 5, Mob.Role.SUPPORT, [Mob.Tag.SPAWN, Mob.Tag.SPIRIT],
		90.0, 7.0, 6.0, 1.5, 40)

	# Mage intro - Inkstone Tower
	_make(&"binding_construct", "Lesser Binding-Construct",
		"What was meant to keep the seal shut. The seal is open now and they are still patrolling, dutifully, the same hallways.",
		&"inkstone_tower", 2, 5, Mob.Role.TANK, [Mob.Tag.CONSTRUCT],
		95.0, 15.0, 8.0, 2.5, 50)
	_make(&"animated_book", "Animated Codex",
		"Some books read themselves when no one is watching. Some books read you.",
		&"inkstone_tower", 1, 4, Mob.Role.CASTER, [Mob.Tag.CONSTRUCT, Mob.Tag.SPIRIT],
		50.0, 18.0, 2.0, 2.0, 30)

	# Druid intro - Coven Glen
	_make(&"blood_hunter", "Inquisition Blood-Hunter",
		"Drains the blood of suspected witches into rune-carved jars. Carries six on his belt at all times. The jars are all full.",
		&"coven_glen", 1, 4, Mob.Role.GRUNT, [Mob.Tag.HUMAN], 60.0, 11.0, 5.0)
	_make(&"witch_burner", "Inquisition Burner",
		"A torch in one hand, a list of names in the other. Some of the names on the list are scratched out. Some are not.",
		&"coven_glen", 3, 5, Mob.Role.CASTER, [Mob.Tag.HUMAN], 55.0, 16.0, 4.0, 3.0, 45)

	# Paladin intro - Sunsworn Chapel
	_make(&"siege_lieutenant", "Siege Lieutenant",
		"Reports to Beleti. Was a soldier of the Crown until the schism. Now reports to the silver-tongued.",
		&"sunsworn_chapel", 2, 4, Mob.Role.TANK, [Mob.Tag.HUMAN], 95.0, 14.0, 7.0)
	_make(&"chapel_breaker", "Chapel Breaker",
		"Carries a sledge. Would rather be elsewhere. Took the contract for the silver, not the blood.",
		&"sunsworn_chapel", 1, 4, Mob.Role.GRUNT, [Mob.Tag.HUMAN], 70.0, 12.0)

# ----------------------------------------------------------------
# IRON CROWN OUTSKIRTS (lvl 6-12)
# ----------------------------------------------------------------
func _register_iron_crown_mobs() -> void:
	_make(&"caravan_brigand", "Caravan Brigand",
		"Most caravan-brigands started as discharged Crown soldiers. The pay was bad. The blood is good.",
		&"iron_crown_outskirts", 6, 11, Mob.Role.GRUNT, [Mob.Tag.HUMAN], 110.0, 16.0)
	_make(&"escaped_temple_slave", "The Temple-Marked",
		"Carries a brand on the inside of the wrist - the seal of one of the Six Breaths. Was sold to the temple at three. Walked out at nineteen.",
		&"iron_crown_outskirts", 7, 12, Mob.Role.RUSHER, [Mob.Tag.HUMAN], 95.0, 18.0)
	_make(&"minor_demon", "Reed-Demon",
		"A small one. Came up through a pinhole in a seal. Has not yet realized it is small. Will be killed before it does.",
		&"iron_crown_outskirts", 8, 12, Mob.Role.GRUNT, [Mob.Tag.DEMON], 130.0, 20.0, 6.0)

# ----------------------------------------------------------------
# REED WASTES (lvl 10-20)
# ----------------------------------------------------------------
func _register_reed_wastes_mobs() -> void:
	_make(&"reed_creeper", "Reed-Creeper",
		"Crawls on its belly through the reeds. The reeds remember being a marsh. The reed-creeper remembers being something with legs.",
		&"reed_wastes", 10, 16, Mob.Role.RUSHER, [Mob.Tag.SPAWN], 150.0, 22.0)
	_make(&"salt_demon", "Salt-Demon",
		"Tiamat's blood salted the wastes. Some of the salt got up and walked. It is doing what it can.",
		&"reed_wastes", 12, 18, Mob.Role.CASTER, [Mob.Tag.DEMON], 130.0, 26.0, 4.0)
	_make(&"wastes_walker", "Wastes-Walker",
		"Used to be an Ash-Step pilgrim. Got lost in the reeds during the cracking. The reeds did not let him leave.",
		&"reed_wastes", 14, 20, Mob.Role.ELITE, [Mob.Tag.UNDEAD], 220.0, 24.0, 8.0, 3.0)
	_make(&"thirst-spirit", "Thirst-Spirit",
		"A ghost from before the marsh dried. Still looking for the well it remembers.",
		&"reed_wastes", 15, 20, Mob.Role.CASTER, [Mob.Tag.SPIRIT, Mob.Tag.UNDEAD], 95.0, 22.0, 2.0)

# ----------------------------------------------------------------
# LAPIS BAY (lvl 15-25)
# ----------------------------------------------------------------
func _register_lapis_bay_mobs() -> void:
	_make(&"pirate_grunt", "Black-Sail Crew",
		"One of the three Black-Sail kings' lesser sailors. Will switch sides at the right offer. Will switch back at the better one.",
		&"lapis_bay", 15, 22, Mob.Role.GRUNT, [Mob.Tag.HUMAN], 180.0, 28.0)
	_make(&"pirate_caster", "Salt-Witch",
		"A discharged Lapis Bay water-mage who took a pirate contract. Pays better. Worse for the soul.",
		&"lapis_bay", 17, 24, Mob.Role.CASTER, [Mob.Tag.HUMAN], 140.0, 32.0, 3.0, 3.0, 90)
	_make(&"drowned_sailor", "Drowned Sailor",
		"Some of the lapis bay's old shipwrecks send up walking dead at low tide. They miss being alive. They are bad at it.",
		&"pirate_isles", 18, 26, Mob.Role.GRUNT, [Mob.Tag.UNDEAD], 200.0, 26.0, 5.0)
	_make(&"isle_python", "Lapis Python",
		"A python from before the bay was a bay. Bigger than it should be. Patient.",
		&"pirate_isles", 20, 28, Mob.Role.ELITE, [Mob.Tag.BEAST], 320.0, 36.0, 6.0)

# ----------------------------------------------------------------
# BONE MOUNTAINS (lvl 25-40)
# ----------------------------------------------------------------
func _register_bone_mountains_mobs() -> void:
	_make(&"ossuary_guardian", "Ossuary Guardian",
		"Made from the bones of the people who built the Bone Mountains' charnel-roads. Still holding tools. Still walking patrols.",
		&"bone_mountains", 25, 35, Mob.Role.ELITE, [Mob.Tag.UNDEAD, Mob.Tag.CONSTRUCT],
		350.0, 38.0, 12.0, 2.0)
	_make(&"bone_swarm", "Bone-Swarm",
		"Loose bones that found each other. They are not friends but they are doing teamwork.",
		&"bone_mountains", 26, 36, Mob.Role.RUSHER, [Mob.Tag.UNDEAD], 200.0, 30.0, 6.0, 5.5)
	_make(&"stone_priest", "Stone Priest",
		"A senior monk of Anshar's Foothold who refused to die when his stance broke. Now teaches stone to walk.",
		&"stone_dojo", 30, 40, Mob.Role.CASTER, [Mob.Tag.UNDEAD, Mob.Tag.HUMAN],
		260.0, 42.0, 8.0, 2.0, 200)
	_make(&"echo_of_first_climber", "Echo of the First Climber",
		"The Bone Mountains' first surveyor died here. Some of him keeps trying to finish the survey.",
		&"bone_mountains", 32, 40, Mob.Role.SCOUT, [Mob.Tag.SPIRIT], 180.0, 38.0, 4.0, 5.0)

# ----------------------------------------------------------------
# VERDANT WOUND (lvl 30-45)
# ----------------------------------------------------------------
func _register_verdant_wound_mobs() -> void:
	_make(&"thorn_creature", "Thorn-Walker",
		"What the Verdant Wound's thorn bushes became when Tiamat's blood reached the roots.",
		&"verdant_wound", 30, 38, Mob.Role.GRUNT, [Mob.Tag.SPAWN, Mob.Tag.SPIRIT],
		320.0, 36.0, 7.0)
	_make(&"corrupt_dryad", "Wound-Dryad",
		"Was a dryad. Still is, technically. The wood is wrong. The voice is right.",
		&"verdant_wound", 32, 42, Mob.Role.CASTER, [Mob.Tag.SPIRIT, Mob.Tag.SPAWN],
		260.0, 44.0, 5.0, 2.5, 160)
	_make(&"twelve_clawed", "Twelve-Clawed",
		"Crawls on its hands. Sings the Greenheart's old songs wrong. Knows your name from somewhere.",
		&"verdant_wound", 36, 45, Mob.Role.ELITE, [Mob.Tag.SPAWN], 480.0, 48.0, 8.0, 4.0)
	_make(&"sanctum_apprentice_lost", "Sanctum Apprentice (Lost)",
		"A Druid student who walked too far into the Wound. Came back wearing more skin.",
		&"verdant_wound", 35, 43, Mob.Role.RUSHER, [Mob.Tag.HUMAN, Mob.Tag.SPAWN],
		300.0, 42.0, 6.0, 5.5, 180)

# ----------------------------------------------------------------
# EMBER STEPPES (lvl 35-50)
# ----------------------------------------------------------------
func _register_ember_steppes_mobs() -> void:
	_make(&"salamander", "Steppe Salamander",
		"Lives in the fissures. Larger than a horse. Will eat one if offered.",
		&"ember_steppes", 35, 45, Mob.Role.ELITE, [Mob.Tag.BEAST], 450.0, 50.0, 10.0, 3.0)
	_make(&"flame_apostate", "Flame Apostate",
		"A Flame Breathing senior who let his inner flame go out and replaced it with something else. Smells of sulfur. The breathing forms still work, but they are wrong now.",
		&"ember_steppes", 38, 48, Mob.Role.CASTER, [Mob.Tag.HUMAN, Mob.Tag.DEMON],
		340.0, 56.0, 6.0, 3.0, 220)
	_make(&"steppe_bandit", "Steppe Bandit",
		"Rides salamanders. Will sell anyone for a price. Has a rule about children. Refuses to discuss it.",
		&"ember_steppes", 36, 44, Mob.Role.GRUNT, [Mob.Tag.HUMAN], 280.0, 44.0)
	_make(&"ember_imp", "Ember Imp",
		"A small fire-spirit attached to the Pillar of Nergal. Sometimes one comes loose and goes wandering. They are mostly harmless. Mostly.",
		&"flame_temple", 40, 50, Mob.Role.RUSHER, [Mob.Tag.DEMON, Mob.Tag.SPIRIT],
		200.0, 48.0, 4.0, 5.0, 130)

# ----------------------------------------------------------------
# MIST VALE (lvl 40-55)
# ----------------------------------------------------------------
func _register_mist_vale_mobs() -> void:
	_make(&"fog_walker", "Walker in the Fog at Dusk",
		"You have always seen them at dusk. You have always thought they were the next-door neighbor. They were not. They are wearing the neighbor's face. They never were the neighbor.",
		&"mist_vale", 40, 50, Mob.Role.SCOUT, [Mob.Tag.SPIRIT, Mob.Tag.UNDEAD],
		300.0, 52.0, 4.0, 4.5, 220)
	_make(&"mist_apostate", "Mist Apostate",
		"A Mist Breathing monk who walked too far in. Came back wearing someone else's face. Will not say whose.",
		&"mist_vale", 45, 55, Mob.Role.CASTER, [Mob.Tag.HUMAN, Mob.Tag.SPIRIT],
		380.0, 60.0, 5.0, 3.5, 280)
	_make(&"echo_of_lost_pilgrim", "Pilgrim's Echo",
		"Pilgrims used to come to Mist Vale to be forgiven. Some of them stay. Forgiveness is hard to leave.",
		&"mist_vale", 42, 52, Mob.Role.SUPPORT, [Mob.Tag.SPIRIT], 250.0, 38.0, 3.0)

# ----------------------------------------------------------------
# SHRIEKING HIGHLANDS (lvl 50-65)
# ----------------------------------------------------------------
func _register_shrieking_highlands_mobs() -> void:
	_make(&"thunder_apostate", "Thunder-Apostate",
		"Walked into the storm to die. Did not. Still walking. Adad is embarrassed about it.",
		&"shrieking_highlands", 50, 60, Mob.Role.CASTER, [Mob.Tag.HUMAN, Mob.Tag.UNDEAD],
		460.0, 70.0, 6.0, 4.0, 330)
	_make(&"storm_rider", "Storm-Rider",
		"Used to ride horses. Now rides bolts. The horses are buried somewhere on the slopes.",
		&"shrieking_highlands", 52, 62, Mob.Role.ELITE, [Mob.Tag.HUMAN, Mob.Tag.SPIRIT],
		540.0, 68.0, 8.0, 5.5, 360)
	_make(&"adad_drone", "Adad's Drone",
		"A bee-shaped lightning elemental that hangs around the Thunder Dojo's eaves. Stings only insults.",
		&"shrieking_highlands", 55, 65, Mob.Role.RUSHER, [Mob.Tag.SPIRIT, Mob.Tag.INSECT],
		300.0, 60.0, 4.0, 6.0, 250)

# ----------------------------------------------------------------
# SUNDERED COAST (lvl 60-75)
# ----------------------------------------------------------------
func _register_sundered_coast_mobs() -> void:
	_make(&"spawn_brood", "Tiamat-Spawn Brood",
		"Hatched from one of the half-sunken ribs. Eats whatever the tide brings. Small, but never alone.",
		&"sundered_coast", 60, 68, Mob.Role.RUSHER, [Mob.Tag.SPAWN], 400.0, 70.0, 6.0, 5.5, 380)
	_make(&"deep_servant", "Tiamat's Deep Servant",
		"Walks the salt-lines along the tide. Older than the Black Citadel. Older than the binding.",
		&"sundered_coast", 65, 75, Mob.Role.ELITE, [Mob.Tag.SPAWN, Mob.Tag.UNDEAD],
		700.0, 80.0, 12.0, 3.0, 600)
	_make(&"sundered_priest", "Sundered Priest",
		"A surviving cultist of the Spawn-Eaters. Worships Tiamat as the wronged mother. Will negotiate.",
		&"sundered_coast", 62, 72, Mob.Role.CASTER, [Mob.Tag.HUMAN], 500.0, 78.0, 5.0)

# ----------------------------------------------------------------
# BLACK CITADEL (lvl 70-85)
# ----------------------------------------------------------------
func _register_black_citadel_mobs() -> void:
	_make(&"citadel_grunt", "Bound Spawn",
		"A Tiamat-spawn permanently bound to the Citadel's walls. Cannot leave. Has not eaten in 400 years. Is hungry.",
		&"black_citadel", 70, 80, Mob.Role.GRUNT, [Mob.Tag.SPAWN], 600.0, 90.0, 10.0)
	_make(&"citadel_priest", "Citadel Priest",
		"A spawn-eater who got promoted. Wears Crown vestments under spawn-skin.",
		&"black_citadel", 74, 84, Mob.Role.CASTER, [Mob.Tag.HUMAN, Mob.Tag.SPAWN],
		520.0, 100.0, 6.0, 3.0, 800)
	_make(&"citadel_warden", "Tier-Warden",
		"Each Citadel tier has a warden. They were people, once. Now they are paperwork that bites.",
		&"black_citadel", 78, 85, Mob.Role.ELITE, [Mob.Tag.UNDEAD], 900.0, 110.0, 14.0, 3.5)

# ----------------------------------------------------------------
# FIRE STAIR (lvl 85-100)
# ----------------------------------------------------------------
func _register_fire_stair_mobs() -> void:
	_make(&"fall_servant", "Servant of the Fall",
		"A demon Lucifer keeps. They are not bound, exactly; they are just used to him.",
		&"fire_stair", 85, 95, Mob.Role.GRUNT, [Mob.Tag.DEMON], 800.0, 130.0, 12.0)
	_make(&"ember_drake", "Ember Drake",
		"A small dragon of the Fire Stair. Lucifer feeds them with his off-hand. Loyal as dogs.",
		&"fire_stair", 90, 100, Mob.Role.ELITE, [Mob.Tag.DEMON, Mob.Tag.BEAST],
		1100.0, 150.0, 16.0, 4.0)
	_make(&"silver_negotiator", "Silver Negotiator",
		"Lucifer's lesser diplomats. They will offer you the same deal, in less polished words.",
		&"fire_stair", 88, 98, Mob.Role.CASTER, [Mob.Tag.DEMON], 700.0, 140.0, 8.0, 3.0)
