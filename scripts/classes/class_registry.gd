extends Node

# Autoload singleton: holds all canonical class definitions.
# Built in code (not .tres) so the seven classes live in one readable place.
# Inspector users can still override by replacing entries with .tres resources.
#
# Roster:
#   1. Berserker     - Strength fury, Rage resource, build-on-damage
#   2. Assassin      - Dexterity crit, Stealth state, burst-then-vanish
#   3. Ronin         - Hybrid str/dex, Stance system, weapon discipline
#   4. Ranger        - Dexterity range, Focus stacks on consecutive hits
#   5. Mage          - Intellect spells, classic Mana, elemental schools
#   6. Chaos Druid   - Shapeshifter, Form Energy, capstone = mini-Tiamat dragon
#   7. Demon         - LOCKED. Unlocks after defeating Lucifer (post-Tiamat secret boss).
#                       Corruption resource, drains HP to fuel devastation.

var classes: Dictionary = {}  # StringName -> PlayerClass

func _ready() -> void:
	_register_berserker()
	_register_assassin()
	_register_ronin()
	_register_ranger()
	_register_mage()
	_register_chaos_druid()
	_register_demon()
	_register_paladin_guardian()
	_register_paladin_lightbringer()

func get_class_def(id: StringName) -> PlayerClass:
	return classes.get(id)

func all_classes() -> Array[PlayerClass]:
	var arr: Array[PlayerClass] = []
	for c in classes.values():
		arr.append(c)
	return arr

func selectable_classes() -> Array[PlayerClass]:
	# Only those unlocked by default OR whose save flag is set.
	var arr: Array[PlayerClass] = []
	for c in classes.values():
		if SaveFlags.is_class_unlocked(c):
			arr.append(c)
	return arr

# ----------------------------------------------------------------
# Class definitions
# ----------------------------------------------------------------

func _register_berserker() -> void:
	var c := PlayerClass.new()
	c.class_id = &"berserker"
	c.display_name = "Berserker"
	c.lore = "Wild-blooded shock-troopers from the ash-steppes. They feed on pain. The deeper their wounds, the harder they hit. Rage scales their damage, attack speed, and momentum: at 100 rage they hit 50% harder, swing 30% faster, and cover ground 15% quicker."
	c.base_hp = 145.0
	c.base_mana = 0.0
	c.base_strength = 16
	c.base_dexterity = 10
	c.base_intellect = 6
	c.base_vitality = 14
	c.hp_per_level = 15.0
	c.mana_per_level = 0.0
	c.strength_per_level = 1.4
	c.dexterity_per_level = 0.5
	c.vitality_per_level = 1.0
	c.primary_attribute = &"strength"
	c.armor = 8.0
	c.magic_resist = 3.0
	c.resource_mechanic = &"rage"
	c.resource_max = 100.0
	c.resource_regen_per_sec = 0.0  # rage builds from damage taken/dealt, no passive regen
	c.max_armor_type = Item.ArmorType.PLATE  # Berserker wears anything, prefers plate
	c.spec_role = &"dps"
	c.unlocked_by_default = true
	c.skill_tree = SkillTreeFactory.build_berserker_tree()
	classes[c.class_id] = c

func _register_assassin() -> void:
	var c := PlayerClass.new()
	c.class_id = &"assassin"
	c.display_name = "Assassin"
	c.lore = "Daggers in the dark. Marduk's quiet hand. Strike from shadow, kill before they turn. Stamina-driven; abilities cost stamina (4/sec regen) and hit for less than spell-cost equivalents but cycle four times as often."
	c.base_hp = 90.0
	c.base_mana = 45.0  # secondary pool for Stealth and rare spells
	c.base_strength = 9
	c.base_dexterity = 17
	c.base_intellect = 11
	c.base_vitality = 9
	c.hp_per_level = 9.0
	c.mana_per_level = 4.0
	c.strength_per_level = 0.5
	c.dexterity_per_level = 1.5
	c.intellect_per_level = 0.7
	c.primary_attribute = &"dexterity"
	c.armor = 4.0
	c.magic_resist = 5.0
	c.resource_mechanic = &"stamina"  # bond: assassin/ronin/ranger use stamina
	c.resource_max = 100.0
	c.resource_regen_per_sec = 4.0  # 4x mana regen rate
	c.max_armor_type = Item.ArmorType.LEATHER
	c.spec_role = &"dps"
	c.unlocked_by_default = true
	c.starting_abilities = [_make_stealth_ability()]
	c.skill_tree = SkillTreeFactory.build_assassin_tree()
	classes[c.class_id] = c

func _make_stealth_ability() -> Ability:
	var s := preload("res://scripts/skills/stealth_ability.gd").new()
	return s

func _register_ronin() -> void:
	# Hardest class to play, most rewarding. Stamina-driven (4/sec regen), with stance charges
	# layered on top as a SECONDARY meter built from successful parries and kills. Stance
	# charges feed Form 7 capstones for chain-bonus damage; stamina pays the per-cast cost.
	var c := PlayerClass.new()
	c.class_id = &"ronin"
	c.display_name = "Ronin"
	c.lore = "Masterless blade. Trained in the seven breaths. They die fast in the hands of the careless and cut gods in the hands of the patient. Stamina-driven combat (4/sec regen). Stance charges (max 3) accrue from parries and kills and feed the Form 7 capstones."
	c.base_hp = 100.0
	c.base_mana = 60.0
	c.base_strength = 12
	c.base_dexterity = 15
	c.base_intellect = 9
	c.base_vitality = 9
	c.hp_per_level = 9.5
	c.mana_per_level = 5.0
	c.strength_per_level = 0.9
	c.dexterity_per_level = 1.3
	c.intellect_per_level = 0.5
	c.vitality_per_level = 0.6
	c.primary_attribute = &"dexterity"
	c.spell_attribute = &"intellect"
	c.armor = 4.0
	c.magic_resist = 4.0
	c.crit_chance = 0.08
	c.crit_multiplier = 2.0
	c.resource_mechanic = &"stamina"  # primary cost pool
	c.resource_max = 100.0
	c.resource_regen_per_sec = 4.0    # 4x mana rate
	# Stance charges remain as a secondary mechanic (not the resource) - max 3, parry-gated,
	# tracked on Player via gain_stance_charge()/spend_stance_charges() and queried by Form 7s.
	c.max_armor_type = Item.ArmorType.LEATHER
	c.spec_role = &"dps"
	c.unlocked_by_default = true
	c.skill_tree = SkillTreeFactory.build_ronin_tree()
	classes[c.class_id] = c

func _register_ranger() -> void:
	var c := PlayerClass.new()
	c.class_id = &"ranger"
	c.display_name = "Ranger"
	c.lore = "Bow-bearers from the wilds. They read footprints, trap forests, and watch a battle from where no enemy looks."
	c.base_hp = 95.0
	c.base_mana = 35.0
	c.base_strength = 10
	c.base_dexterity = 16
	c.base_intellect = 11
	c.base_vitality = 10
	c.hp_per_level = 9.5
	c.mana_per_level = 3.0
	c.dexterity_per_level = 1.4
	c.strength_per_level = 0.5
	c.intellect_per_level = 0.7
	c.primary_attribute = &"dexterity"
	c.armor = 4.0
	c.magic_resist = 5.0
	c.resource_mechanic = &"stamina"  # primary cost pool
	c.resource_max = 100.0
	c.resource_regen_per_sec = 4.0    # 4x mana rate
	# Focus stacks remain as a secondary mechanic (max 5), built on consecutive hits,
	# decays on miss. Tracked separately on Player; queried by Ranger abilities for crit bonus.
	c.max_armor_type = Item.ArmorType.MAIL
	c.spec_role = &"dps"
	c.unlocked_by_default = true
	c.skill_tree = SkillTreeFactory.build_ranger_tree()
	classes[c.class_id] = c

func _register_mage() -> void:
	var c := PlayerClass.new()
	c.class_id = &"mage"
	c.display_name = "Mage"
	c.lore = "Words bound the world. Mages remember those words. Fire, frost, lightning, void: each obeys the right syllable. Starts with 100 mana; pool grows with the Mana attribute (+10 per point) and gear."
	c.base_hp = 75.0
	c.base_mana = 100.0  # Bond: starts at 100
	c.base_strength = 6
	c.base_dexterity = 9
	c.base_intellect = 18
	c.base_vitality = 8
	c.hp_per_level = 7.0
	c.mana_per_level = 7.0
	c.intellect_per_level = 1.6
	c.dexterity_per_level = 0.4
	c.primary_attribute = &"intellect"
	c.armor = 2.0
	c.magic_resist = 8.0
	c.resource_mechanic = &"mana"
	c.resource_max = 100.0  # Bond: starts at 100
	c.resource_regen_per_sec = 1.0  # Bond: 1 mana/sec default; potions or buffs accelerate
	c.max_armor_type = Item.ArmorType.CLOTH  # Cloth-only
	c.spec_role = &"dps"
	c.unlocked_by_default = true
	c.skill_tree = SkillTreeFactory.build_mage_tree()
	classes[c.class_id] = c

func _register_chaos_druid() -> void:
	var c := PlayerClass.new()
	c.class_id = &"chaos_druid"
	c.display_name = "Chaos Druid"
	c.lore = "Touched by Tiamat's blood before the binding. They speak with beasts and become them. The chaos that broke the world is the chaos they wear."
	c.base_hp = 110.0
	c.base_mana = 55.0
	c.base_strength = 12
	c.base_dexterity = 12
	c.base_intellect = 13
	c.base_vitality = 11
	c.hp_per_level = 11.0
	c.mana_per_level = 4.5
	c.intellect_per_level = 1.0
	c.strength_per_level = 0.7
	c.dexterity_per_level = 0.7
	c.primary_attribute = &"intellect"
	c.spell_attribute = &"intellect"
	c.armor = 5.0
	c.magic_resist = 6.0
	# Bond's Druid: MANA primary in human form (like Mage, 1/sec regen for spells/heals).
	# In shapeshift form, a SECONDARY stamina pool drains for form abilities.
	# Player handles the dual-pool routing via cost_resource on each ability.
	c.resource_mechanic = &"mana"
	c.resource_max = 100.0
	c.resource_regen_per_sec = 1.0  # human-form mana, same cadence as Mage
	c.max_armor_type = Item.ArmorType.LEATHER
	c.spec_role = &"dps"
	c.unlocked_by_default = true
	c.available_forms = _build_druid_forms()  # wolf, bear, raven, serpent, dragon
	c.skill_tree = SkillTreeFactory.build_chaos_druid_tree()
	classes[c.class_id] = c

# ----------------------------------------------------------------
# Paladin (one conceptual class, two specs grouped under spec_group_id = &"paladin")
#
# GUARDIAN (Tank): Plate, shield + hammer, mana for protection auras and self-shields,
# huge HP/armor pool, weak healing. Built to take hits, control aggro, mitigate.
#
# LIGHTBRINGER (Healer): Mail (no plate), shield + hammer, mana for healing spells,
# moderate stats, low damage but strong sustained heals.
#
# Both share visual identity (shield + hammer) and the spec_group_id so CharCreation
# can present them as Paladin -> pick spec.
# ----------------------------------------------------------------

func _register_paladin_guardian() -> void:
	var c := PlayerClass.new()
	c.class_id = &"paladin_guardian"
	c.display_name = "Paladin (Guardian)"
	c.lore = "Marduk's wall-bearers. Where the line bends, the Guardian stands. Heavy plate, heavier shield, war-hammer. Their healing is small, but their absorption is enormous, and the auras they raise around them keep their allies alive even when the Guardian is on one knee."
	c.base_hp = 165.0  # highest of any class
	c.base_mana = 60.0  # mana for protection spells
	c.base_strength = 14
	c.base_dexterity = 8
	c.base_intellect = 12  # for spell-buff scaling
	c.base_vitality = 18  # highest vit
	c.hp_per_level = 16.0
	c.mana_per_level = 4.5
	c.strength_per_level = 1.0
	c.dexterity_per_level = 0.4
	c.intellect_per_level = 0.7
	c.vitality_per_level = 1.3
	c.primary_attribute = &"strength"
	c.spell_attribute = &"intellect"
	c.armor = 14.0  # highest armor baseline
	c.magic_resist = 10.0
	c.crit_chance = 0.04
	c.crit_multiplier = 1.6
	c.resource_mechanic = &"mana"
	c.resource_max = 100.0
	c.resource_regen_per_sec = 3.5
	c.max_armor_type = Item.ArmorType.PLATE
	c.spec_group_id = &"paladin"
	c.spec_role = &"tank"
	c.unlocked_by_default = true
	c.skill_tree = SkillTreeFactory.build_paladin_guardian_tree()
	classes[c.class_id] = c

func _register_paladin_lightbringer() -> void:
	var c := PlayerClass.new()
	c.class_id = &"paladin_lightbringer"
	c.display_name = "Paladin (Lightbringer)"
	c.lore = "Marduk's hand-of-mercy. Same shield, same hammer, but the hammer is gilded and the shield is ringed with prayer-script. Where the wounded fall the Lightbringer kneels. Mail, not plate: light enough to move between casualties, heavy enough to take a stray bolt."
	c.base_hp = 100.0
	c.base_mana = 120.0  # high mana pool for sustained healing
	c.base_strength = 9
	c.base_dexterity = 9
	c.base_intellect = 17  # primary for heal scaling
	c.base_vitality = 12
	c.hp_per_level = 9.0
	c.mana_per_level = 8.5
	c.strength_per_level = 0.4
	c.dexterity_per_level = 0.5
	c.intellect_per_level = 1.4
	c.vitality_per_level = 0.8
	c.primary_attribute = &"intellect"  # spell-power scales heals AND smites
	c.spell_attribute = &"intellect"
	c.armor = 6.0
	c.magic_resist = 9.0
	c.crit_chance = 0.06
	c.crit_multiplier = 1.7
	c.resource_mechanic = &"mana"
	c.resource_max = 130.0  # higher than Mage; healing is mana-hungry
	c.resource_regen_per_sec = 5.0
	c.max_armor_type = Item.ArmorType.MAIL  # Bond: healers cannot wear plate
	c.spec_group_id = &"paladin"
	c.spec_role = &"healer"
	c.unlocked_by_default = true
	c.skill_tree = SkillTreeFactory.build_paladin_lightbringer_tree()
	classes[c.class_id] = c

func _register_demon() -> void:
	# Blood-fed nightwalker. Abilities cost nothing. Damage scales with Blood (fills on kill).
	# Daytime: -20% damage and zero auto HP regen.
	# Nighttime: +20% damage and 4 HP/sec auto regen.
	# Lifesteal passive: 5% of all damage dealt heals.
	# Trades resource scarcity for time-of-day discipline.
	var c := PlayerClass.new()
	c.class_id = &"demon"
	c.display_name = "Demon"
	c.lore = "What walks back through Lucifer's gate is no longer mortal. They fight free of mana, paid only in blood. By day they are half-strength and never heal on their own. By night they are stronger than they were before the fall, and the world bleeds toward them."
	c.base_hp = 130.0
	c.base_mana = 0.0  # demons do not use mana
	c.base_strength = 15
	c.base_dexterity = 13
	c.base_intellect = 15
	c.base_vitality = 12
	c.hp_per_level = 13.0
	c.mana_per_level = 0.0
	c.strength_per_level = 1.1
	c.dexterity_per_level = 0.9
	c.intellect_per_level = 1.1
	c.primary_attribute = &"strength"
	c.spell_attribute = &"intellect"
	c.armor = 7.0
	c.magic_resist = 7.0
	c.resource_mechanic = &"blood"  # fills on kill, +1% ability dmg per point
	c.resource_max = 100.0
	c.resource_regen_per_sec = 0.0  # never regens; only kills fill it
	c.max_armor_type = Item.ArmorType.PLATE
	c.spec_role = &"dps"
	c.unlocked_by_default = false
	c.unlock_save_flag = &"demon_class_unlocked"
	c.unlock_hint = "Sealed. Walk through fire after the false dawn. Once earned, never lost."
	c.skill_tree = SkillTreeFactory.build_demon_tree()
	classes[c.class_id] = c

# ----------------------------------------------------------------
# Druid forms (capstone = Tiamat-spawn dragon)
# ----------------------------------------------------------------

func _build_druid_forms() -> Array[Transformation]:
	var forms: Array[Transformation] = []

	var wolf := Transformation.new()
	wolf.id = &"wolf"
	wolf.display_name = "Dire Wolf"
	wolf.description = "Pack-hunter form. Fast, light, lethal in melee."
	wolf.hp_mult = 0.9
	wolf.move_speed_mult = 1.45
	wolf.armor_mult = 0.8
	wolf.damage_mult = 1.1
	wolf.crit_chance_bonus = 0.1
	wolf.duration = -1.0
	wolf.enter_cost = 25.0
	wolf.tags = [&"beast", &"melee"]
	forms.append(wolf)

	var bear := Transformation.new()
	bear.id = &"bear"
	bear.display_name = "Iron Bear"
	bear.description = "Tank form. Soak hits, hit back harder."
	bear.hp_mult = 1.6
	bear.move_speed_mult = 0.9
	bear.armor_mult = 2.0
	bear.damage_mult = 1.25
	bear.duration = -1.0
	bear.enter_cost = 35.0
	bear.tags = [&"beast", &"tank"]
	forms.append(bear)

	var raven := Transformation.new()
	raven.id = &"raven"
	raven.display_name = "Storm Raven"
	raven.description = "Aerial scout. Untouchable by ground enemies, scouts dungeons from above."
	raven.hp_mult = 0.6
	raven.move_speed_mult = 1.8
	raven.armor_mult = 0.5
	raven.damage_mult = 0.6
	raven.duration = -1.0
	raven.enter_cost = 20.0
	raven.tags = [&"beast", &"flying", &"scout"]
	forms.append(raven)

	var serpent := Transformation.new()
	serpent.id = &"serpent"
	serpent.display_name = "Venom Serpent"
	serpent.description = "Poison-fanged crawler. DoT specialist, low cooldown bites."
	serpent.hp_mult = 0.85
	serpent.move_speed_mult = 1.2
	serpent.armor_mult = 0.7
	serpent.damage_mult = 0.95
	serpent.crit_chance_bonus = 0.05
	serpent.duration = -1.0
	serpent.enter_cost = 25.0
	serpent.tags = [&"beast", &"poison", &"dot"]
	forms.append(serpent)

	# CAPSTONE: mini-Tiamat dragon. Skill-tree gated, not free.
	var dragon := Transformation.new()
	dragon.id = &"dragon"
	dragon.display_name = "Spawn of Tiamat"
	dragon.description = "Capstone unlock. The chaos in your blood remembers its mother. Brief, devastating, blue-fire breath."
	dragon.hp_mult = 1.8
	dragon.move_speed_mult = 1.1
	dragon.armor_mult = 1.6
	dragon.damage_mult = 2.4
	dragon.crit_chance_bonus = 0.15
	dragon.duration = 18.0  # auto-revert; not indefinite
	dragon.enter_cost = 100.0  # full bar
	dragon.tags = [&"dragon", &"flying", &"capstone"]
	forms.append(dragon)

	return forms
