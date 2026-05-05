extends RefCounted
class_name SkillTreeFactory

# Builds class skill trees programmatically. For Ronin: 7 styles x 7 forms = 49 nodes,
# each form an UNLOCK_ABILITY skill node, with linear in-style prereqs and capstone gating.

static func build_ronin_tree() -> SkillTree:
	var tree := SkillTree.new()
	tree.class_id = &"ronin"

	var styles := BreathingRegistry.all_styles()
	var col := 0
	for style in styles:
		_add_style_branch(tree, style, col)
		col += 1
	return tree

static func _add_style_branch(tree: SkillTree, style: BreathingStyle, col: int) -> void:
	for form: BreathingForm in style.forms:
		var n := SkillNode.new()
		n.id = StringName("ronin_%s_%d" % [style.id, form.form_number])
		n.display_name = "%s: %s Form" % [style.display_name, _ord_text(form.form_number)]
		n.description = form.description
		n.cost = 1 if form.form_number < 7 else 3  # capstone costs more
		n.min_level = form.min_player_level
		n.grid_position = Vector2(col * 2.0, float(form.form_number) * 1.2)
		n.effect = SkillNode.Effect.UNLOCK_ABILITY
		n.target_key = form.id
		n.ability_unlock = form

		# In-style linear prereq: form 2 needs form 1, etc.
		if form.form_number > 1:
			n.prerequisites = [StringName("ronin_%s_%d" % [style.id, form.form_number - 1])]

		# Sun Breathing requires mastery of ALL 6 base styles (Form 7 unlocked in each).
		# This is in addition to the save flag tiamat_defeated and min_player_level 18.
		# 7 prereqs is heavy by design: Sun is the true capstone of the entire Ronin path.
		if style.id == &"sun" and form.form_number == 1:
			n.prerequisites = [
				&"ronin_water_7", &"ronin_flame_7", &"ronin_mist_7",
				&"ronin_thunder_7", &"ronin_stone_7", &"ronin_wind_7"
			]
			n.cost = 5  # Sun Form 1 alone costs 5 skill points; this is a milestone, not a button

		tree.nodes.append(n)

static func _ord_text(n: int) -> String:
	match n:
		1: return "1st"
		2: return "2nd"
		3: return "3rd"
		_: return "%dth" % n

# ============================================================
# PALADIN GUARDIAN (TANK) skill tree
# Three branches: Aegis (mitigation), Wrath (threat + heavy hits), Ward (party buffs)
# ~30 nodes total. Capstone: "Living Wall" - immune to crits, take 30% less for 8 sec.
# ============================================================
static func build_paladin_guardian_tree() -> SkillTree:
	var tree := SkillTree.new()
	tree.class_id = &"paladin_guardian"

	# AEGIS branch (column 0): defensive mitigation, shield mastery
	_add_node(tree, &"pg_aegis_1", "Shield Mastery", "+10% block chance.",
		Vector2(0, 1), 1, 1, SkillNode.Effect.STAT_FLAT, &"armor", 5.0, [])
	_add_node(tree, &"pg_aegis_2", "Iron Skin", "+15% armor.",
		Vector2(0, 2), 1, 3, SkillNode.Effect.STAT_PERCENT, &"armor", 0.15, [&"pg_aegis_1"])
	_add_node(tree, &"pg_aegis_3", "Crystallized Faith", "+50 HP.",
		Vector2(0, 3), 1, 5, SkillNode.Effect.STAT_FLAT, &"max_hp", 50.0, [&"pg_aegis_2"])
	_add_node(tree, &"pg_aegis_4", "Stone Stance", "Reduces all incoming physical damage 8%.",
		Vector2(0, 4), 2, 8, SkillNode.Effect.PASSIVE_TAG, &"phys_dr_8", 0.08, [&"pg_aegis_3"])
	_add_node(tree, &"pg_aegis_5", "Bulwark", "+200 HP.",
		Vector2(0, 5), 2, 12, SkillNode.Effect.STAT_FLAT, &"max_hp", 200.0, [&"pg_aegis_4"])
	_add_node(tree, &"pg_aegis_6", "Living Wall (Capstone)", "Active: 8s immunity to crits, 30% reduced incoming damage. 90s cooldown.",
		Vector2(0, 6), 5, 25, SkillNode.Effect.UNLOCK_ABILITY, &"living_wall", 0.0, [&"pg_aegis_5"])

	# WRATH branch (column 2): threat, heavy hammer hits
	_add_node(tree, &"pg_wrath_1", "Heavy Swing", "+10% hammer damage.",
		Vector2(2, 1), 1, 1, SkillNode.Effect.STAT_PERCENT, &"strength", 0.10, [])
	_add_node(tree, &"pg_wrath_2", "Provoke", "Active: forces enemies in 5m to target you for 6 sec. 30s CD.",
		Vector2(2, 2), 1, 4, SkillNode.Effect.UNLOCK_ABILITY, &"provoke", 0.0, [&"pg_wrath_1"])
	_add_node(tree, &"pg_wrath_3", "Hammer's Decree", "+15% damage when wielding a hammer + shield.",
		Vector2(2, 3), 2, 7, SkillNode.Effect.STAT_PERCENT, &"strength", 0.15, [&"pg_wrath_2"])
	_add_node(tree, &"pg_wrath_4", "Crashing Verdict", "Active: AOE smash, 4m radius, stuns 1.5 sec. Costs 30 mana, 12s CD.",
		Vector2(2, 4), 2, 10, SkillNode.Effect.UNLOCK_ABILITY, &"crashing_verdict", 0.0, [&"pg_wrath_3"])
	_add_node(tree, &"pg_wrath_5", "Vengeance", "When struck, next hammer hit deals +50% damage.",
		Vector2(2, 5), 2, 14, SkillNode.Effect.PASSIVE_TAG, &"vengeance_proc", 0.50, [&"pg_wrath_4"])
	_add_node(tree, &"pg_wrath_6", "Sentence (Capstone)", "Active: 4m AOE judgment, deals damage equal to 2x current HP missing. 60s CD.",
		Vector2(2, 6), 5, 22, SkillNode.Effect.UNLOCK_ABILITY, &"sentence", 0.0, [&"pg_wrath_5"])

	# WARD branch (column 4): party buffs, holy auras
	_add_node(tree, &"pg_ward_1", "Aura of Resolve", "Passive: allies within 8m gain +5% damage reduction.",
		Vector2(4, 1), 1, 1, SkillNode.Effect.PASSIVE_TAG, &"aura_resolve", 0.05, [])
	_add_node(tree, &"pg_ward_2", "Lay On Hands (weak)", "Active: heal yourself or one ally for 25% max HP. 90s CD.",
		Vector2(4, 2), 1, 4, SkillNode.Effect.UNLOCK_ABILITY, &"lay_on_hands", 0.25, [&"pg_ward_1"])
	_add_node(tree, &"pg_ward_3", "Aura of Vigor", "Aura adds +3 HP/sec regen to allies in 8m.",
		Vector2(4, 3), 2, 7, SkillNode.Effect.PASSIVE_TAG, &"aura_vigor", 3.0, [&"pg_ward_2"])
	_add_node(tree, &"pg_ward_4", "Faithful Stand", "When an ally drops below 30% HP, you absorb 25% of damage they take for 4 sec.",
		Vector2(4, 4), 3, 11, SkillNode.Effect.PASSIVE_TAG, &"faithful_stand", 0.25, [&"pg_ward_3"])
	_add_node(tree, &"pg_ward_5", "Sun-Standard", "Active: plant a banner that grants +20% damage and +50% mana regen to all allies in 10m for 12 sec. 120s CD.",
		Vector2(4, 5), 3, 15, SkillNode.Effect.UNLOCK_ABILITY, &"sun_standard", 0.0, [&"pg_ward_4"])
	_add_node(tree, &"pg_ward_6", "Marduk's Mantle (Capstone)", "Active: party-wide invulnerability for 4 sec. 240s CD.",
		Vector2(4, 6), 5, 28, SkillNode.Effect.UNLOCK_ABILITY, &"marduks_mantle", 0.0, [&"pg_ward_5"])

	# VOW (col 6): oath buffs
	_unlock_ability(tree, &"pg_vow_1", "Oath of Defense", "Toggle: -10% damage taken, -10% damage dealt. 0 cost.", 6, 1, 1, &"oath_defense", [])
	_passive_rank(tree, &"pg_vow_2", "Sworn", "Oaths gain +3% potency per rank.", 6, 2, 4, &"oath_pot", 0.03, 5, [&"pg_vow_1"])
	_unlock_ability(tree, &"pg_vow_3", "Oath of Vengeance", "Toggle: +20% damage when below 50% HP. 0 cost.", 6, 3, 7, &"oath_vengeance", [&"pg_vow_2"])
	_passive_rank(tree, &"pg_vow_4", "Faithful", "+5% mana regen per rank.", 6, 4, 11, &"mana_regen", 5.0, 5, [&"pg_vow_3"])
	_unlock_ability(tree, &"pg_vow_5", "Oath of Light", "Toggle: 5 HP/sec aura to allies. 0 cost.", 6, 5, 16, &"oath_light", [&"pg_vow_4"])
	_passive_rank(tree, &"pg_vow_6", "Honorbound", "Active oaths cost -2% mana per rank.", 6, 6, 22, &"oath_cost_reduce", 0.02, 5, [&"pg_vow_5"])
	_capstone(tree, &"pg_vow_7", "All Oaths", "Active: maintain all 3 oaths simultaneously for 30 sec. 240s CD.", 6, 7, 30, &"all_oaths", [&"pg_vow_6"])

	# TENACITY (col 7): HP, regen
	_passive_rank(tree, &"pg_ten_1", "Resilient", "+15 max HP per rank.", 7, 1, 1, &"max_hp", 15.0, 5, [])
	_passive_rank(tree, &"pg_ten_2", "Stalwart", "+3% damage reduction per rank.", 7, 2, 4, &"dr", 0.03, 5, [&"pg_ten_1"])
	_unlock_ability(tree, &"pg_ten_3", "Last Stand", "Active: take 50% less damage for 6 sec. 90s CD.", 7, 3, 7, &"last_stand", [&"pg_ten_2"])
	_passive_rank(tree, &"pg_ten_4", "Hearty", "+2 HP regen per rank.", 7, 4, 11, &"hp_regen", 2.0, 5, [&"pg_ten_3"])
	_passive_rank(tree, &"pg_ten_5", "Steel Skin", "+3 armor per rank.", 7, 5, 16, &"armor", 3.0, 5, [&"pg_ten_4"])
	_unlock_ability(tree, &"pg_ten_6", "Iron Will", "Active: immune to crowd control 4 sec. 60s CD.", 7, 6, 22, &"iron_will", [&"pg_ten_5"])
	_capstone(tree, &"pg_ten_7", "Unbreakable", "Cannot drop below 1 HP from a single hit. 60s CD between procs.", 7, 7, 30, &"unbreakable", [&"pg_ten_6"])

	# VINDICATION (col 8): counter-attacks
	_unlock_ability(tree, &"pg_vin_1", "Riposte", "Active: parry, deal 200% counter damage. 12s CD.", 8, 1, 1, &"riposte", [])
	_passive_rank(tree, &"pg_vin_2", "Quick Reflexes", "+5% parry window per rank.", 8, 2, 4, &"parry_window", 0.05, 5, [&"pg_vin_1"])
	_unlock_ability(tree, &"pg_vin_3", "Retribution", "When struck, deal 30 holy damage to attacker. Passive.", 8, 3, 7, &"retribution", [&"pg_vin_2"])
	_passive_rank(tree, &"pg_vin_4", "Vengeful", "+10 retribution damage per rank.", 8, 4, 11, &"retal_dmg", 10.0, 5, [&"pg_vin_3"])
	_unlock_ability(tree, &"pg_vin_5", "Reflective Aura", "Toggle: 10% of damage taken reflects to attacker.", 8, 5, 16, &"reflect_aura", [&"pg_vin_4"])
	_passive_rank(tree, &"pg_vin_6", "Iron Counter", "Riposte damage +20% per rank.", 8, 6, 22, &"riposte_dmg", 0.20, 5, [&"pg_vin_5"])
	_capstone(tree, &"pg_vin_7", "Mirror of Marduk", "Active: 8 sec, all damage taken reflects 100% to attacker. 240s CD.", 8, 7, 30, &"mirror_marduk", [&"pg_vin_6"])

	# BANNER (col 9): party support
	_unlock_ability(tree, &"pg_ban_1", "Crown Banner", "Active: plant banner; allies in 8m gain +10% damage for 12 sec. 60s CD.", 9, 1, 1, &"crown_banner", [])
	_passive_rank(tree, &"pg_ban_2", "Standard Bearer", "Banner buff +2% per rank.", 9, 2, 4, &"banner_pot", 0.02, 5, [&"pg_ban_1"])
	_unlock_ability(tree, &"pg_ban_3", "Rallying Cry", "Active: 12m AOE, allies heal 50 HP and gain +10% atk speed for 8 sec. 90s CD.", 9, 3, 7, &"rallying_cry", [&"pg_ban_2"])
	_passive_rank(tree, &"pg_ban_4", "Captain", "+5% party damage in your aura per rank.", 9, 4, 11, &"captain_aura", 0.05, 5, [&"pg_ban_3"])
	_unlock_ability(tree, &"pg_ban_5", "Wall of Light", "Active: 6m line wall, allies behind take -50% damage 8 sec. 90s CD.", 9, 5, 16, &"wall_of_light", [&"pg_ban_4"])
	_passive_rank(tree, &"pg_ban_6", "Inspiring", "Allies in aura gain +1 HP regen per rank.", 9, 6, 22, &"aura_regen_grant", 1.0, 5, [&"pg_ban_5"])
	_capstone(tree, &"pg_ban_7", "Avatar of Marduk", "Active: 30 sec, party gains +30% damage and damage reduction. 600s CD.", 9, 7, 30, &"avatar_marduk", [&"pg_ban_6"])

	return tree

# ============================================================
# PALADIN LIGHTBRINGER (HEALER) skill tree
# Three branches: Mercy (heals), Light (smites), Salt (dispels/cleanses)
# Capstone: "Resurrection" - revive a fallen ally to 50% HP. 600s CD.
# ============================================================
static func build_paladin_lightbringer_tree() -> SkillTree:
	var tree := SkillTree.new()
	tree.class_id = &"paladin_lightbringer"

	# MERCY branch (column 0): single-target heals, group heals
	_add_node(tree, &"pl_mercy_1", "Mending Light", "Active: heal an ally for 80 + 0.6*spellpower. 8s CD.",
		Vector2(0, 1), 1, 1, SkillNode.Effect.UNLOCK_ABILITY, &"mending_light", 0.0, [])
	_add_node(tree, &"pl_mercy_2", "Quick Word", "Mending Light cooldown -50%.",
		Vector2(0, 2), 1, 3, SkillNode.Effect.PASSIVE_TAG, &"mending_haste", 0.50, [&"pl_mercy_1"])
	_add_node(tree, &"pl_mercy_3", "Hand of Healing", "Active: large heal, 200 + 1.5*spellpower. 25s CD.",
		Vector2(0, 3), 2, 6, SkillNode.Effect.UNLOCK_ABILITY, &"hand_of_healing", 0.0, [&"pl_mercy_2"])
	_add_node(tree, &"pl_mercy_4", "Sun-Bath", "Aura: allies in 10m heal 4 HP/sec.",
		Vector2(0, 4), 2, 10, SkillNode.Effect.PASSIVE_TAG, &"aura_sunbath", 4.0, [&"pl_mercy_3"])
	_add_node(tree, &"pl_mercy_5", "Circle of Mending", "Active: AOE heal in 8m, 150 + 1.0*spellpower per ally. 30s CD.",
		Vector2(0, 5), 3, 14, SkillNode.Effect.UNLOCK_ABILITY, &"circle_of_mending", 0.0, [&"pl_mercy_4"])
	_add_node(tree, &"pl_mercy_6", "Resurrection (Capstone)", "Active: revive a fallen ally to 50% HP. 600s CD. Once per dungeon ascent.",
		Vector2(0, 6), 5, 25, SkillNode.Effect.UNLOCK_ABILITY, &"resurrection", 0.0, [&"pl_mercy_5"])

	# LIGHT branch (column 2): smites, holy damage
	_add_node(tree, &"pl_light_1", "Smite", "Active: holy bolt at one target. 30 + 0.8*spellpower damage. 4s CD.",
		Vector2(2, 1), 1, 1, SkillNode.Effect.UNLOCK_ABILITY, &"smite", 0.0, [])
	_add_node(tree, &"pl_light_2", "Holy Strike", "+25% damage to demons and undead.",
		Vector2(2, 2), 1, 3, SkillNode.Effect.PASSIVE_TAG, &"holy_strike", 0.25, [&"pl_light_1"])
	_add_node(tree, &"pl_light_3", "Searing Light", "Smite ignites: 6 dmg/sec for 4 sec.",
		Vector2(2, 3), 2, 6, SkillNode.Effect.PASSIVE_TAG, &"searing_light", 6.0, [&"pl_light_2"])
	_add_node(tree, &"pl_light_4", "Beam of Conviction", "Active: 8m beam, 120 + 1.0*spellpower. Heals each ally it crosses for 30. 18s CD.",
		Vector2(2, 4), 3, 10, SkillNode.Effect.UNLOCK_ABILITY, &"beam_of_conviction", 0.0, [&"pl_light_3"])
	_add_node(tree, &"pl_light_5", "Solar Pulse", "Active: 6m AOE around self. Damages enemies, heals allies. 25s CD.",
		Vector2(2, 5), 3, 14, SkillNode.Effect.UNLOCK_ABILITY, &"solar_pulse", 0.0, [&"pl_light_4"])
	_add_node(tree, &"pl_light_6", "Day-Bringer (Capstone)", "Active: 12m radiant pillar, 4 sec channel. Allies heal 60 HP/sec, demons take 200 dmg/sec. 90s CD.",
		Vector2(2, 6), 5, 22, SkillNode.Effect.UNLOCK_ABILITY, &"day_bringer", 0.0, [&"pl_light_5"])

	# SALT branch (column 4): cleanses, debuffs, party utility
	_add_node(tree, &"pl_salt_1", "Cleanse", "Active: remove one debuff from an ally. 15s CD.",
		Vector2(4, 1), 1, 1, SkillNode.Effect.UNLOCK_ABILITY, &"cleanse", 0.0, [])
	_add_node(tree, &"pl_salt_2", "Pillar of Salt", "Cleanse also heals 50.",
		Vector2(4, 2), 1, 4, SkillNode.Effect.PASSIVE_TAG, &"pillar_of_salt", 50.0, [&"pl_salt_1"])
	_add_node(tree, &"pl_salt_3", "Ward of Saving", "Active: 4-sec absorb shield on an ally (200 + 1.0*spellpower). 12s CD.",
		Vector2(4, 3), 2, 7, SkillNode.Effect.UNLOCK_ABILITY, &"ward_of_saving", 0.0, [&"pl_salt_2"])
	_add_node(tree, &"pl_salt_4", "Stand-Down Aura", "Aura: enemies in 8m deal 8% less damage.",
		Vector2(4, 4), 3, 11, SkillNode.Effect.PASSIVE_TAG, &"aura_standdown", 0.08, [&"pl_salt_3"])
	_add_node(tree, &"pl_salt_5", "Mass Cleanse", "Active: Cleanse all allies in 10m. 30s CD.",
		Vector2(4, 5), 3, 15, SkillNode.Effect.UNLOCK_ABILITY, &"mass_cleanse", 0.0, [&"pl_salt_4"])
	_add_node(tree, &"pl_salt_6", "Storyteller's Oath (Capstone)", "Passive: when a party member would die, restore them to 30% HP and grant 5 sec invulnerability. Once per encounter, 600s CD between uses.",
		Vector2(4, 6), 5, 28, SkillNode.Effect.UNLOCK_ABILITY, &"storytellers_oath", 0.0, [&"pl_salt_5"])

	# DEVOTION (col 6): mana economy, faith
	_passive_rank(tree, &"pl_dev_1", "Sacred Vessel", "+15 max mana per rank.", 6, 1, 1, &"max_mana", 15.0, 5, [])
	_passive_rank(tree, &"pl_dev_2", "Inner Light", "+1 mana regen per rank.", 6, 2, 4, &"mana_regen", 1.0, 5, [&"pl_dev_1"])
	_unlock_ability(tree, &"pl_dev_3", "Prayer", "Active: meditate 4 sec, regen 100% mana. 0 cost. 120s CD.", 6, 3, 7, &"prayer", [&"pl_dev_2"])
	_passive_rank(tree, &"pl_dev_4", "Conviction", "Spell costs -2% per rank.", 6, 4, 11, &"spell_cost_reduce", 0.02, 5, [&"pl_dev_3"])
	_passive_rank(tree, &"pl_dev_5", "Faithful Hands", "+3% spellpower per rank.", 6, 5, 16, &"spellpower", 0.03, 5, [&"pl_dev_4"], true)
	_unlock_ability(tree, &"pl_dev_6", "Divine Inspiration", "Crit heals refund 30% mana. Passive.", 6, 6, 22, &"divine_inspiration", [&"pl_dev_5"])
	_capstone(tree, &"pl_dev_7", "Endless Light", "Active: 12 sec, 0-cost spells. 240s CD.", 6, 7, 30, &"endless_light", [&"pl_dev_6"])

	# COMPASSION (col 7): heal-over-time
	_unlock_ability(tree, &"pl_com_1", "Renewing Touch", "ST: HoT 8 dmg/sec for 12 sec. 25 mana. 8s CD.", 7, 1, 1, &"renewing_touch", [])
	_passive_rank(tree, &"pl_com_2", "Lasting Mercy", "HoT duration +1s per rank.", 7, 2, 4, &"hot_duration", 1.0, 5, [&"pl_com_1"])
	_unlock_ability(tree, &"pl_com_3", "Soothing Wave", "AOE: HoT 6 HP/sec to allies in 8m for 8 sec. 35 mana. 18s CD.", 7, 3, 7, &"soothing_wave", [&"pl_com_2"])
	_passive_rank(tree, &"pl_com_4", "Tender Hands", "+5% HoT effective per rank.", 7, 4, 11, &"hot_potency", 0.05, 5, [&"pl_com_3"])
	_passive_rank(tree, &"pl_com_5", "Gentle Touch", "+5% mana refund on crit-heals per rank.", 7, 5, 16, &"crit_heal_refund", 0.05, 5, [&"pl_com_4"])
	_unlock_ability(tree, &"pl_com_6", "Beacon of Hope", "Toggle: chosen ally takes 30% of your healing automatically.", 7, 6, 22, &"beacon_of_hope", [&"pl_com_5"])
	_capstone(tree, &"pl_com_7", "Communion", "Active: HoT 30 HP/sec on all allies for 12 sec. 80 mana. 180s CD.", 7, 7, 30, &"communion", [&"pl_com_6"])

	# WRATH OF DAWN (col 8): damaging holy
	_unlock_ability(tree, &"pl_wod_1", "Hammer of Dawn", "ST: 30 + 0.6*spellpower holy damage. 15 mana. 4s CD.", 8, 1, 1, &"hammer_of_dawn", [])
	_passive_rank(tree, &"pl_wod_2", "Sun-Anointed", "+3% holy damage per rank.", 8, 2, 4, &"holy_dmg", 0.03, 5, [&"pl_wod_1"])
	_unlock_ability(tree, &"pl_wod_3", "Crusader's Strike", "ST: weapon-strike empowered with holy. 25 mana. 6s CD.", 8, 3, 7, &"crusaders_strike", [&"pl_wod_2"])
	_passive_rank(tree, &"pl_wod_4", "Holy Vigor", "+5% damage to demons/undead per rank.", 8, 4, 11, &"vs_evil_dmg", 0.05, 5, [&"pl_wod_3"])
	_unlock_ability(tree, &"pl_wod_5", "Divine Storm", "AOE: 6m smite, 100 + 0.8*spellpower. 40 mana. 18s CD.", 8, 5, 16, &"divine_storm", [&"pl_wod_4"])
	_passive_rank(tree, &"pl_wod_6", "Wrath", "+3% crit chance with holy spells per rank.", 8, 6, 22, &"holy_crit", 0.03, 5, [&"pl_wod_5"])
	_capstone(tree, &"pl_wod_7", "Final Judgment", "Active: 12m radial pillar of holy fire. Demons/undead take instant lethal damage. 600s CD.", 8, 7, 30, &"final_judgment", [&"pl_wod_6"])

	# GRACE (col 9): mobility, blink
	_unlock_ability(tree, &"pl_grace_1", "Sunstride", "Active: blink 8m forward, brief speed boost. 30 mana. 18s CD.", 9, 1, 1, &"sunstride", [])
	_passive_rank(tree, &"pl_grace_2", "Quick Step", "+3% movement speed per rank.", 9, 2, 4, &"move_speed_bonus", 0.03, 5, [&"pl_grace_1"])
	_passive_rank(tree, &"pl_grace_3", "Light Footed", "Casting while moving doesn't slow per rank.", 9, 3, 7, &"cast_move", 0.20, 5, [&"pl_grace_2"])
	_unlock_ability(tree, &"pl_grace_4", "Hand of Salvation", "Active: shield ally with brief invulnerability. 40 mana. 60s CD.", 9, 4, 11, &"hand_of_salvation", [&"pl_grace_3"])
	_passive_rank(tree, &"pl_grace_5", "Graceful Recovery", "+5% HP regen out of combat per rank.", 9, 5, 16, &"oc_regen", 0.05, 5, [&"pl_grace_4"])
	_unlock_ability(tree, &"pl_grace_6", "Wings of Dawn", "Active: 6 sec flight. 50 mana. 120s CD.", 9, 6, 22, &"wings_dawn", [&"pl_grace_5"])
	_capstone(tree, &"pl_grace_7", "Walking Sun", "Aura: allies in 12m heal 1% max HP per sec, take -10% damage. Toggle.", 9, 7, 30, &"walking_sun", [&"pl_grace_6"])

	return tree

# Internal: build and append a SkillNode in one call.
static func _add_node(tree: SkillTree, id: StringName, name: String, desc: String,
		grid_pos: Vector2, cost: int, min_level: int,
		effect: int, target_key: StringName, amount: float,
		prereqs: Array, max_ranks: int = 1) -> SkillNode:
	var n := SkillNode.new()
	n.id = id
	n.display_name = name
	n.description = desc
	n.grid_position = grid_pos
	n.cost = cost
	n.min_level = min_level
	n.effect = effect
	n.target_key = target_key
	n.amount = amount
	n.max_ranks = max_ranks
	for p in prereqs:
		n.prerequisites.append(StringName(p))
	tree.nodes.append(n)
	return n

# === Convenience helpers for the 49-node-per-class build ===

# 1-point ability unlock node.
static func _unlock_ability(tree: SkillTree, id: StringName, name: String, desc: String,
		col: int, tier: int, min_level: int, ability_id: StringName, prereqs: Array) -> SkillNode:
	return _add_node(tree, id, name, desc, Vector2(col * 2.0, float(tier) * 1.2),
		1, min_level, SkillNode.Effect.UNLOCK_ABILITY, ability_id, 0.0, prereqs, 1)

# Multi-rank passive that adds `amount_per_rank` to a stat per investment.
static func _passive_rank(tree: SkillTree, id: StringName, name: String, desc: String,
		col: int, tier: int, min_level: int,
		stat_key: StringName, amount_per_rank: float, max_ranks: int,
		prereqs: Array, percent: bool = false) -> SkillNode:
	var effect := SkillNode.Effect.STAT_PERCENT if percent else SkillNode.Effect.STAT_FLAT
	return _add_node(tree, id, "%s (1/%d)" % [name, max_ranks], desc,
		Vector2(col * 2.0, float(tier) * 1.2), 1, min_level,
		effect, stat_key, amount_per_rank, prereqs, max_ranks)

# Capstone: high-cost, single-rank, ability-or-flag effect.
static func _capstone(tree: SkillTree, id: StringName, name: String, desc: String,
		col: int, tier: int, min_level: int, ability_id: StringName, prereqs: Array,
		cost: int = 5) -> SkillNode:
	return _add_node(tree, id, "%s (Capstone)" % name, desc,
		Vector2(col * 2.0, float(tier) * 1.2), cost, min_level,
		SkillNode.Effect.UNLOCK_ABILITY, ability_id, 0.0, prereqs, 1)

# Passive tag: queried by gameplay code, no stat math here.
static func _passive_tag(tree: SkillTree, id: StringName, name: String, desc: String,
		col: int, tier: int, min_level: int,
		tag_key: StringName, amount: float, max_ranks: int, prereqs: Array) -> SkillNode:
	return _add_node(tree, id, "%s (1/%d)" % [name, max_ranks] if max_ranks > 1 else name, desc,
		Vector2(col * 2.0, float(tier) * 1.2), 1, min_level,
		SkillNode.Effect.PASSIVE_TAG, tag_key, amount, prereqs, max_ranks)

# ============================================================
# BERSERKER skill tree (7 branches x 7 nodes = 49)
# WAR | BLOOD | FURY | BERSERK | SUNDER | ENDURANCE | ROAR
# ============================================================
static func build_berserker_tree() -> SkillTree:
	var tree := SkillTree.new()
	tree.class_id = &"berserker"

	# WAR (col 0): heavy melee scaling
	_unlock_ability(tree, &"bz_war_1", "Reckless Swing", "Active: heavy strike dealing 150% weapon damage. Costs 30 rage. 6s CD.", 0, 1, 1, &"reckless_swing", [])
	_passive_rank(tree, &"bz_war_2", "Heavy Hands", "+5% physical damage per rank.", 0, 2, 3, &"strength", 0.05, 5, [&"bz_war_1"], true)
	_unlock_ability(tree, &"bz_war_3", "Cleave", "Active: AOE swing in 3m arc. 25 rage. 8s CD.", 0, 3, 6, &"cleave", [&"bz_war_2"])
	_passive_rank(tree, &"bz_war_4", "Crushing Blow", "+5% crit damage per rank with 2H weapons.", 0, 4, 10, &"crit_multiplier", 0.05, 5, [&"bz_war_3"])
	_unlock_ability(tree, &"bz_war_5", "Earth-Shaker", "Active: ground slam, 5m AOE, knock-up. 50 rage. 18s CD.", 0, 5, 16, &"earth_shaker", [&"bz_war_4"])
	_passive_rank(tree, &"bz_war_6", "Two-Handed Mastery", "+8% damage with 2H weapons per rank.", 0, 6, 22, &"strength", 0.08, 5, [&"bz_war_5"], true)
	_capstone(tree, &"bz_war_7", "World-Ender", "Active: 3-second windup, 12m radius slam, 600 base damage. 90 rage. 90s CD.", 0, 7, 30, &"world_ender", [&"bz_war_6"])

	# BLOOD (col 1): rage building, lifesteal
	_passive_rank(tree, &"bz_blood_1", "Rage Surge", "+1 rage gained from damage taken per rank.", 1, 1, 1, &"rage_gain_taken", 1.0, 5, [])
	_unlock_ability(tree, &"bz_blood_2", "Blood Bath", "Active: 6 sec lifesteal aura, 8% of damage as heal. 60s CD.", 1, 2, 4, &"blood_bath", [&"bz_blood_1"])
	_passive_rank(tree, &"bz_blood_3", "Hemorrhage", "+1 rage per crit landed per rank.", 1, 3, 7, &"rage_gain_crit", 1.0, 5, [&"bz_blood_2"])
	_passive_rank(tree, &"bz_blood_4", "Tireless", "+5% rage decay resistance per rank.", 1, 4, 11, &"rage_decay_resist", 0.05, 5, [&"bz_blood_3"])
	_unlock_ability(tree, &"bz_blood_5", "Crimson Pact", "Active: spend 30% HP to fill rage to 100. 60s CD.", 1, 5, 16, &"crimson_pact", [&"bz_blood_4"])
	_passive_rank(tree, &"bz_blood_6", "Bloodthirst", "Lifesteal +2% per rank (passive).", 1, 6, 22, &"lifesteal", 0.02, 5, [&"bz_blood_5"])
	_capstone(tree, &"bz_blood_7", "Unkillable", "When HP would drop to 0, restore 30% HP. 300s CD.", 1, 7, 30, &"unkillable", [&"bz_blood_6"])

	# FURY (col 2): attack speed, crits
	_passive_rank(tree, &"bz_fury_1", "Quickdraw", "+2% attack speed per rank.", 2, 1, 1, &"attack_speed_bonus", 0.02, 5, [])
	_unlock_ability(tree, &"bz_fury_2", "Frenzy", "Active: 8 sec, +30% atk speed, +20% damage. 40 rage. 60s CD.", 2, 2, 4, &"frenzy", [&"bz_fury_1"])
	_passive_rank(tree, &"bz_fury_3", "Killer Instinct", "+1% crit chance per rank.", 2, 3, 7, &"crit_chance", 0.01, 5, [&"bz_fury_2"])
	_passive_rank(tree, &"bz_fury_4", "Battle Trance", "+5% atk speed at full rage per rank.", 2, 4, 11, &"trance_atk_speed", 0.05, 5, [&"bz_fury_3"])
	_unlock_ability(tree, &"bz_fury_5", "Whirlwind", "Channeled spinning AOE for 4 sec. 60 rage. 30s CD.", 2, 5, 16, &"whirlwind", [&"bz_fury_4"])
	_passive_rank(tree, &"bz_fury_6", "Untamed", "Crits at full rage refund 10 rage per rank.", 2, 6, 22, &"untamed_refund", 10.0, 5, [&"bz_fury_5"])
	_capstone(tree, &"bz_fury_7", "Eye of the Storm", "Active: 12 sec, attacks have no cooldown, +50% damage. 180s CD.", 2, 7, 30, &"eye_of_storm", [&"bz_fury_6"])

	# BERSERK (col 3): transformation/state
	_unlock_ability(tree, &"bz_berserk_1", "Berserk", "Toggle: +20% damage taken AND dealt. 0 cost.", 3, 1, 1, &"berserk_toggle", [])
	_passive_rank(tree, &"bz_berserk_2", "Wild Heart", "+3% rage cap per rank.", 3, 2, 4, &"rage_cap", 3.0, 5, [&"bz_berserk_1"])
	_passive_rank(tree, &"bz_berserk_3", "Adrenaline", "+5% damage at low HP per rank (below 50%).", 3, 3, 7, &"low_hp_damage", 0.05, 5, [&"bz_berserk_2"])
	_passive_rank(tree, &"bz_berserk_4", "Wrath of the Steppes", "+2% damage to fellow Ash-Steppe enemies per rank.", 3, 4, 11, &"steppe_dmg", 0.02, 5, [&"bz_berserk_3"])
	_unlock_ability(tree, &"bz_berserk_5", "Death Charge", "Active: dash 8m forward through enemies, deal 200 damage to each. 50 rage. 20s CD.", 3, 5, 16, &"death_charge", [&"bz_berserk_4"])
	_passive_rank(tree, &"bz_berserk_6", "Pain Tolerance", "+3% damage reduction per rank while in Berserk toggle.", 3, 6, 22, &"berserk_dr", 0.03, 5, [&"bz_berserk_5"])
	_capstone(tree, &"bz_berserk_7", "Final Stand", "Below 20% HP: damage dealt +100%, damage taken -50%. Lasts 8 sec, 240s CD.", 3, 7, 30, &"final_stand", [&"bz_berserk_6"])

	# SUNDER (col 4): armor pen
	_passive_rank(tree, &"bz_sunder_1", "Cracking Strikes", "+5% armor pen per rank.", 4, 1, 1, &"armor_pen", 0.05, 5, [])
	_unlock_ability(tree, &"bz_sunder_2", "Sunder Armor", "Active: hit applies 40% armor reduction debuff for 8 sec. 6s CD.", 4, 2, 4, &"sunder_armor", [&"bz_sunder_1"])
	_passive_rank(tree, &"bz_sunder_3", "Bleed Through", "+3% damage to armored targets per rank.", 4, 3, 7, &"vs_armor", 0.03, 5, [&"bz_sunder_2"])
	_passive_rank(tree, &"bz_sunder_4", "Heavy Hand", "+1% strength scaling per rank.", 4, 4, 11, &"strength", 0.01, 5, [&"bz_sunder_3"], true)
	_unlock_ability(tree, &"bz_sunder_5", "Shatter", "Active: heavy strike that ignores all armor. 40 rage. 18s CD.", 4, 5, 16, &"shatter", [&"bz_sunder_4"])
	_passive_rank(tree, &"bz_sunder_6", "Bloodied Edge", "+5% damage to bleeding targets per rank.", 4, 6, 22, &"vs_bleed", 0.05, 5, [&"bz_sunder_5"])
	_capstone(tree, &"bz_sunder_7", "Mountain Splitter", "Active: 1.5s windup, ignores 100% armor, 600 base damage. 60 rage. 90s CD.", 4, 7, 30, &"berserker_mountain_splitter", [&"bz_sunder_6"])

	# ENDURANCE (col 5): tankiness
	_passive_rank(tree, &"bz_end_1", "Iron Skin", "+15 max HP per rank.", 5, 1, 1, &"max_hp", 15.0, 5, [])
	_passive_rank(tree, &"bz_end_2", "Thick Hide", "+2 armor per rank.", 5, 2, 4, &"armor", 2.0, 5, [&"bz_end_1"])
	_unlock_ability(tree, &"bz_end_3", "Bloodroar", "Active: 6 sec, take 25% less damage. 30 rage. 30s CD.", 5, 3, 7, &"bloodroar", [&"bz_end_2"])
	_passive_rank(tree, &"bz_end_4", "Vitality", "+2 HP regen per rank.", 5, 4, 11, &"hp_regen", 2.0, 5, [&"bz_end_3"])
	_passive_rank(tree, &"bz_end_5", "Stoneblood", "+3% magic resist per rank.", 5, 5, 16, &"magic_resist", 0.03, 5, [&"bz_end_4"], true)
	_passive_rank(tree, &"bz_end_6", "Rooted", "+5% knockback resist per rank.", 5, 6, 22, &"knockback_resist", 0.05, 5, [&"bz_end_5"])
	_capstone(tree, &"bz_end_7", "Walking Mountain", "Passive: immune to crowd control while above 70% HP.", 5, 7, 30, &"walking_mountain", [&"bz_end_6"])

	# ROAR (col 6): debuffs, intimidation
	_unlock_ability(tree, &"bz_roar_1", "War Cry", "Active: 8m AOE, enemies deal -15% damage for 6 sec. 25 rage. 30s CD.", 6, 1, 1, &"war_cry", [])
	_passive_rank(tree, &"bz_roar_2", "Booming Voice", "War Cry radius +1m per rank.", 6, 2, 4, &"war_cry_radius", 1.0, 5, [&"bz_roar_1"])
	_passive_rank(tree, &"bz_roar_3", "Demoralize", "War Cry -3% additional damage per rank.", 6, 3, 7, &"war_cry_potency", 0.03, 5, [&"bz_roar_2"])
	_unlock_ability(tree, &"bz_roar_4", "Terrifying Shout", "Active: enemies in 8m flee for 3 sec. 30 rage. 60s CD.", 6, 4, 11, &"terrify", [&"bz_roar_3"])
	_passive_rank(tree, &"bz_roar_5", "Battlefield Presence", "Allies in 8m gain +2% damage per rank.", 6, 5, 16, &"presence_dmg", 0.02, 5, [&"bz_roar_4"])
	_passive_rank(tree, &"bz_roar_6", "Bull Rush", "Charge attacks +5% damage per rank.", 6, 6, 22, &"charge_dmg", 0.05, 5, [&"bz_roar_5"])
	_capstone(tree, &"bz_roar_7", "Avatar of War", "Active: 30 sec aura, allies +25% damage and +10% atk speed. 300s CD.", 6, 7, 30, &"avatar_of_war", [&"bz_roar_6"])

	return tree

# ============================================================
# RANGER skill tree (7 branches x 7 nodes = 49)
# MARKSMAN | BEAST | TRAPS | SURVIVAL | TRACKING | AMBUSH | STORM
# ============================================================
static func build_ranger_tree() -> SkillTree:
	var tree := SkillTree.new()
	tree.class_id = &"ranger"

	# MARKSMAN
	_unlock_ability(tree, &"rg_mark_1", "Aimed Shot", "1.5s charged bow shot, 200% weapon damage. 25 stamina. 6s CD.", 0, 1, 1, &"aimed_shot", [])
	_passive_rank(tree, &"rg_mark_2", "Steady Aim", "+5% bow damage per rank.", 0, 2, 3, &"strength", 0.05, 5, [&"rg_mark_1"], true)
	_unlock_ability(tree, &"rg_mark_3", "Piercing Shot", "Pierces 3 enemies in line. 30 stamina. 8s CD.", 0, 3, 6, &"piercing_shot", [&"rg_mark_2"])
	_passive_rank(tree, &"rg_mark_4", "Sniper", "+3% crit chance with bows per rank.", 0, 4, 10, &"crit_chance", 0.03, 5, [&"rg_mark_3"])
	_unlock_ability(tree, &"rg_mark_5", "Multishot", "3 arrows in cone. 35 stamina. 8s CD.", 0, 5, 16, &"multishot", [&"rg_mark_4"])
	_passive_rank(tree, &"rg_mark_6", "Hawk Eye", "+5% range per rank.", 0, 6, 22, &"weapon_range", 0.05, 5, [&"rg_mark_5"], true)
	_capstone(tree, &"rg_mark_7", "Death From Above", "Rain 9 arrows on a 6m circle, 4s. 60 stamina. 60s CD.", 0, 7, 30, &"death_from_above", [&"rg_mark_6"])

	# BEAST
	_unlock_ability(tree, &"rg_beast_1", "Summon Wolf", "Pet wolf for 60s, attacks chosen target. 40 stamina. 30s CD.", 1, 1, 1, &"summon_wolf", [])
	_passive_rank(tree, &"rg_beast_2", "Pack Bond", "+10% wolf damage per rank.", 1, 2, 4, &"pet_dmg", 0.10, 5, [&"rg_beast_1"])
	_passive_rank(tree, &"rg_beast_3", "Loyal Hunter", "Wolf duration +5s per rank.", 1, 3, 7, &"pet_duration", 5.0, 5, [&"rg_beast_2"])
	_unlock_ability(tree, &"rg_beast_4", "Bond Strike", "Toggle: shots on wolf's target +20% damage.", 1, 4, 11, &"bond_strike", [&"rg_beast_3"])
	_passive_rank(tree, &"rg_beast_5", "Beast Speak", "+5% pet HP per rank.", 1, 5, 16, &"pet_hp", 0.05, 5, [&"rg_beast_4"], true)
	_unlock_ability(tree, &"rg_beast_6", "Summon Bear", "Pet bear for 30s, tanks. 60 stamina. 60s CD.", 1, 6, 22, &"summon_bear", [&"rg_beast_5"])
	_capstone(tree, &"rg_beast_7", "Apex Predator", "12s self-transform: +50% dmg, +30% speed. 240s CD.", 1, 7, 30, &"apex_predator", [&"rg_beast_6"])

	# TRAPS
	_unlock_ability(tree, &"rg_traps_1", "Snare Trap", "6m trigger, 3s hold. 20 stamina. 10s CD.", 2, 1, 1, &"snare_trap", [])
	_passive_rank(tree, &"rg_traps_2", "Quick Hands", "Trap CD -8% per rank.", 2, 2, 4, &"trap_cd", 0.08, 5, [&"rg_traps_1"])
	_unlock_ability(tree, &"rg_traps_3", "Bear Trap", "Damage trap, 100 dmg + 4s hold. 25 stamina. 12s CD.", 2, 3, 7, &"bear_trap", [&"rg_traps_2"])
	_passive_rank(tree, &"rg_traps_4", "Demolitionist", "+5% trap damage per rank.", 2, 4, 11, &"trap_dmg", 0.05, 5, [&"rg_traps_3"])
	_unlock_ability(tree, &"rg_traps_5", "Explosive Trap", "200 dmg in 4m. 40 stamina. 20s CD.", 2, 5, 16, &"explosive_trap", [&"rg_traps_4"])
	_passive_rank(tree, &"rg_traps_6", "Field of Snares", "+1 max active trap per rank.", 2, 6, 22, &"trap_max_active", 1.0, 3, [&"rg_traps_5"])
	_capstone(tree, &"rg_traps_7", "Minefield", "Scatter 6 explosive traps in 8m. 80 stamina. 90s CD.", 2, 7, 30, &"minefield", [&"rg_traps_6"])

	# SURVIVAL
	_passive_rank(tree, &"rg_surv_1", "Hardy", "+15 max HP per rank.", 3, 1, 1, &"max_hp", 15.0, 5, [])
	_passive_rank(tree, &"rg_surv_2", "Wilderness Eye", "+5% xp gain per rank.", 3, 2, 4, &"xp_gain_pct", 0.05, 5, [&"rg_surv_1"], true)
	_unlock_ability(tree, &"rg_surv_3", "Field Bandage", "Heal 30% max HP. 0 cost. 90s CD.", 3, 3, 7, &"field_bandage", [&"rg_surv_2"])
	_passive_rank(tree, &"rg_surv_4", "Tracker's Stamina", "+5 stamina regen per rank.", 3, 4, 11, &"stamina_regen", 5.0, 5, [&"rg_surv_3"])
	_passive_rank(tree, &"rg_surv_5", "Hunter's Pace", "+3% movement speed per rank.", 3, 5, 16, &"move_speed_bonus", 0.03, 5, [&"rg_surv_4"])
	_passive_rank(tree, &"rg_surv_6", "Cautious", "+3% damage reduction per rank.", 3, 6, 22, &"dr", 0.03, 5, [&"rg_surv_5"])
	_capstone(tree, &"rg_surv_7", "Untouchable", "Below 30% HP: +50% dodge for 6s. 120s CD.", 3, 7, 30, &"untouchable", [&"rg_surv_6"])

	# TRACKING
	_unlock_ability(tree, &"rg_track_1", "Mark Target", "Marked enemy +20% dmg taken from you 30s. 6s CD.", 4, 1, 1, &"mark_target", [])
	_passive_rank(tree, &"rg_track_2", "Read Tracks", "+3% drop chance per rank.", 4, 2, 4, &"drop_chance_pct", 0.03, 5, [&"rg_track_1"], true)
	_unlock_ability(tree, &"rg_track_3", "Shadow Walk", "4s invisibility while not attacking. 30 stamina. 30s CD.", 4, 3, 7, &"shadow_walk", [&"rg_track_2"])
	_passive_rank(tree, &"rg_track_4", "Cover Master", "+5% damage from stealth per rank.", 4, 4, 11, &"stealth_dmg", 0.05, 5, [&"rg_track_3"])
	_passive_rank(tree, &"rg_track_5", "Hunter's Wit", "+3% accuracy per rank.", 4, 5, 16, &"accuracy", 0.03, 5, [&"rg_track_4"])
	_passive_rank(tree, &"rg_track_6", "Forager", "+5% gold per kill per rank.", 4, 6, 22, &"gold_per_kill", 0.05, 5, [&"rg_track_5"])
	_capstone(tree, &"rg_track_7", "Apex Hunter", "Marked targets always miss against you. Toggle.", 4, 7, 30, &"apex_hunter", [&"rg_track_6"])

	# AMBUSH
	_passive_rank(tree, &"rg_amb_1", "Backshot", "+5% damage from behind per rank.", 5, 1, 1, &"behind_dmg", 0.05, 5, [])
	_unlock_ability(tree, &"rg_amb_2", "Disengage", "Roll backwards 6m, brief invuln. 25 stamina. 12s CD.", 5, 2, 4, &"disengage", [&"rg_amb_1"])
	_passive_rank(tree, &"rg_amb_3", "Cover Crouch", "+3% accuracy still per rank.", 5, 3, 7, &"still_accuracy", 0.03, 5, [&"rg_amb_2"])
	_passive_rank(tree, &"rg_amb_4", "Cold Steel", "First arrow on target +10% damage per rank.", 5, 4, 11, &"first_arrow_dmg", 0.10, 5, [&"rg_amb_3"])
	_unlock_ability(tree, &"rg_amb_5", "Volley Combo", "Snared targets take +30% from your shots. Passive.", 5, 5, 16, &"snare_combo", [&"rg_amb_4"])
	_passive_rank(tree, &"rg_amb_6", "Patient Hand", "+1% crit per second held still per rank.", 5, 6, 22, &"patient_crit", 0.01, 5, [&"rg_amb_5"])
	_capstone(tree, &"rg_amb_7", "Ghost Volley", "4s invisible, no-CD shots. 90 stamina. 120s CD.", 5, 7, 30, &"ghost_volley", [&"rg_amb_6"])

	# STORM (elemental arrows)
	_unlock_ability(tree, &"rg_storm_1", "Frost Arrow", "Slow 50% for 3s. 15 stamina. 4s CD.", 6, 1, 1, &"frost_arrow", [])
	_unlock_ability(tree, &"rg_storm_2", "Fire Arrow", "Ignites: 8 dmg/sec for 5s. 20 stamina. 4s CD.", 6, 2, 4, &"fire_arrow", [&"rg_storm_1"])
	_unlock_ability(tree, &"rg_storm_3", "Lightning Arrow", "Chains to 1 nearby enemy at 70%. 25 stamina. 6s CD.", 6, 3, 7, &"lightning_arrow", [&"rg_storm_2"])
	_passive_rank(tree, &"rg_storm_4", "Elemental Affinity", "+5% elemental arrow damage per rank.", 6, 4, 11, &"element_arrow_dmg", 0.05, 5, [&"rg_storm_3"])
	_unlock_ability(tree, &"rg_storm_5", "Poison Arrow", "Stacking poison, 4 dmg/sec/stack. 25 stamina. 4s CD.", 6, 5, 16, &"poison_arrow", [&"rg_storm_4"])
	_passive_rank(tree, &"rg_storm_6", "Soaked Bowstring", "+3% element proc per rank.", 6, 6, 22, &"element_proc", 0.03, 5, [&"rg_storm_5"])
	_capstone(tree, &"rg_storm_7", "Storm Quiver", "12s, every shot random element proc. 80 stamina. 120s CD.", 6, 7, 30, &"storm_quiver", [&"rg_storm_6"])

	return tree

# ============================================================
# ASSASSIN skill tree
# Three branches: SHADOW (stealth/burst), VENOM (poisons), CRIMSON (bleeds).
# All abilities cost stamina (cost_resource = &"stamina"). Capstones stack.
# ============================================================
static func build_assassin_tree() -> SkillTree:
	var tree := SkillTree.new()
	tree.class_id = &"assassin"

	# SHADOW branch (column 0): stealth mastery, ambush, mobility
	_add_node(tree, &"as_shadow_1", "Stealth Mastery", "Stealth duration +50%, exit cooldown -25%.",
		Vector2(0, 1), 1, 1, SkillNode.Effect.PASSIVE_TAG, &"stealth_mastery", 0.50, [])
	_add_node(tree, &"as_shadow_2", "Shadow Step", "Active: teleport behind target within 8m. Costs 30 stamina, 12s CD.",
		Vector2(0, 2), 1, 4, SkillNode.Effect.UNLOCK_ABILITY, &"shadow_step", 0.0, [&"as_shadow_1"])
	_add_node(tree, &"as_shadow_3", "Vanish on Kill", "Crit kills auto-stealth for 3 sec. No cooldown on the auto-trigger.",
		Vector2(0, 3), 2, 7, SkillNode.Effect.PASSIVE_TAG, &"vanish_on_kill", 3.0, [&"as_shadow_2"])
	_add_node(tree, &"as_shadow_4", "Ambush Mastery", "First-strike ambush bonus from Stealth: +50% (now 200% total).",
		Vector2(0, 4), 2, 10, SkillNode.Effect.PASSIVE_TAG, &"ambush_master", 0.50, [&"as_shadow_3"])
	_add_node(tree, &"as_shadow_5", "Smoke Vanish", "Active: instant escape stealth + 8m blink. 60s CD.",
		Vector2(0, 5), 3, 14, SkillNode.Effect.UNLOCK_ABILITY, &"smoke_vanish", 0.0, [&"as_shadow_4"])
	_add_node(tree, &"as_shadow_6", "Hidden Hand", "Pass under detection radius 1.5m for 5 sec after stealth ends.",
		Vector2(0, 6), 3, 18, SkillNode.Effect.PASSIVE_TAG, &"hidden_hand", 5.0, [&"as_shadow_5"])
	_add_node(tree, &"as_shadow_7", "King of Knives (Capstone)", "Active: ultimate stealth dance. 8 sec untargetable, attacks deal 250% damage. 180s CD.",
		Vector2(0, 7), 5, 24, SkillNode.Effect.UNLOCK_ABILITY, &"king_of_knives", 0.0, [&"as_shadow_6"])

	# VENOM branch (column 2): poisons, DoT, debilitation
	_add_node(tree, &"as_venom_1", "Coat Blade", "Active: weapon poisoned for 30 sec. Hits apply venom (3 dmg/sec for 6 sec). 60s CD.",
		Vector2(2, 1), 1, 1, SkillNode.Effect.UNLOCK_ABILITY, &"coat_blade", 0.0, [])
	_add_node(tree, &"as_venom_2", "Toxic Strike", "Active: melee strike applying 3 stacks of poison instantly. 8s CD.",
		Vector2(2, 2), 1, 4, SkillNode.Effect.UNLOCK_ABILITY, &"toxic_strike", 0.0, [&"as_venom_1"])
	_add_node(tree, &"as_venom_3", "Deepening Toxin", "Poison stacks max 8 (was 5). Each tick deals +50%.",
		Vector2(2, 3), 2, 7, SkillNode.Effect.PASSIVE_TAG, &"deepening_toxin", 0.50, [&"as_venom_2"])
	_add_node(tree, &"as_venom_4", "Paralysis", "Active: poison-coated dart, stuns target 2 sec if poisoned. 24s CD.",
		Vector2(2, 4), 2, 10, SkillNode.Effect.UNLOCK_ABILITY, &"paralysis_dart", 0.0, [&"as_venom_3"])
	_add_node(tree, &"as_venom_5", "Death Mark", "Hit applies a mark; after 6 sec, mark explodes for damage equal to total poison dealt to target.",
		Vector2(2, 5), 3, 14, SkillNode.Effect.UNLOCK_ABILITY, &"death_mark", 0.0, [&"as_venom_4"])
	_add_node(tree, &"as_venom_6", "Plague Cloud", "Active: poison cloud at target spot, 6m radius, 8 sec. Applies 1 stack/sec to enemies inside. 45s CD.",
		Vector2(2, 6), 3, 18, SkillNode.Effect.UNLOCK_ABILITY, &"plague_cloud", 0.0, [&"as_venom_5"])
	_add_node(tree, &"as_venom_7", "Carrion Dance (Capstone)", "Active: massive AOE poison field, 10m radius, 15 sec. All poisons on enemies inside tick at 5x rate. 240s CD.",
		Vector2(2, 7), 5, 24, SkillNode.Effect.UNLOCK_ABILITY, &"carrion_dance", 0.0, [&"as_venom_6"])

	# CRIMSON branch (column 4): bleeds, lifeblood, hemorrhage
	_add_node(tree, &"as_crimson_1", "Bleed Strike", "Active: melee strike applies bleed (5 dmg/sec for 6 sec). 6s CD.",
		Vector2(4, 1), 1, 1, SkillNode.Effect.UNLOCK_ABILITY, &"bleed_strike", 0.0, [])
	_add_node(tree, &"as_crimson_2", "Hemorrhage", "Bleed deals double damage to enemies who are moving.",
		Vector2(4, 2), 1, 4, SkillNode.Effect.PASSIVE_TAG, &"hemorrhage", 2.0, [&"as_crimson_1"])
	_add_node(tree, &"as_crimson_3", "Crimson Spray", "Active: cone attack, applies bleed to all in 4m cone. 12s CD.",
		Vector2(4, 3), 2, 7, SkillNode.Effect.UNLOCK_ABILITY, &"crimson_spray", 0.0, [&"as_crimson_2"])
	_add_node(tree, &"as_crimson_4", "Lifeblood", "Bleeding enemies heal you for 10% of bleed damage dealt.",
		Vector2(4, 4), 2, 10, SkillNode.Effect.PASSIVE_TAG, &"lifeblood", 0.10, [&"as_crimson_3"])
	_add_node(tree, &"as_crimson_5", "Eviscerate", "Active: heavy strike on bleeding target consumes all bleed stacks for burst damage. 15s CD.",
		Vector2(4, 5), 3, 14, SkillNode.Effect.UNLOCK_ABILITY, &"eviscerate", 0.0, [&"as_crimson_4"])
	_add_node(tree, &"as_crimson_6", "Crimson Mark", "Mark a target; all your bleeds on them tick at 3x speed for 8 sec.",
		Vector2(4, 6), 3, 18, SkillNode.Effect.UNLOCK_ABILITY, &"crimson_mark", 0.0, [&"as_crimson_5"])
	_add_node(tree, &"as_crimson_7", "Red Wedding (Capstone)", "Active: all enemies in 8m bleed for 10% max HP per second for 10 sec. 240s CD.",
		Vector2(4, 7), 5, 24, SkillNode.Effect.UNLOCK_ABILITY, &"red_wedding", 0.0, [&"as_crimson_6"])

	# DAGGER (col 5): single-target burst weapon mastery
	_unlock_ability(tree, &"as_dagger_1", "Backstab", "ST: behind-only strike for 250% damage. 25 stamina. 10s CD.", 5, 1, 1, &"backstab", [])
	_passive_rank(tree, &"as_dagger_2", "Dagger Mastery", "+5% dagger damage per rank.", 5, 2, 4, &"dexterity", 0.05, 5, [&"as_dagger_1"], true)
	_unlock_ability(tree, &"as_dagger_3", "Twin Strike", "ST: dual strike, 80% each. 30 stamina. 8s CD.", 5, 3, 7, &"twin_strike", [&"as_dagger_2"])
	_passive_rank(tree, &"as_dagger_4", "Sharpened Edge", "+5% crit damage per rank.", 5, 4, 11, &"crit_multiplier", 0.05, 5, [&"as_dagger_3"])
	_unlock_ability(tree, &"as_dagger_5", "Throat Cut", "ST: instant-kill if target below 10% HP. 25 stamina. 18s CD.", 5, 5, 16, &"throat_cut", [&"as_dagger_4"])
	_passive_rank(tree, &"as_dagger_6", "Off-Hand Mastery", "+8% off-hand damage per rank.", 5, 6, 22, &"offhand_dmg", 0.08, 5, [&"as_dagger_5"])
	_capstone(tree, &"as_dagger_7", "Hundred Cuts", "ST channel: 5 sec, 12 strikes, each +crit chance. 60 stamina. 90s CD.", 5, 7, 30, &"hundred_cuts", [&"as_dagger_6"])

	# AGILITY (col 6): movement, evasion
	_passive_rank(tree, &"as_agi_1", "Light Step", "+3% movement speed per rank.", 6, 1, 1, &"move_speed_bonus", 0.03, 5, [])
	_unlock_ability(tree, &"as_agi_2", "Roll Dodge", "Active: 4m roll, 0.3s i-frames. 20 stamina. 4s CD.", 6, 2, 4, &"roll_dodge", [&"as_agi_1"])
	_passive_rank(tree, &"as_agi_3", "Cat Reflexes", "+2% dodge chance per rank.", 6, 3, 7, &"dodge_chance", 0.02, 5, [&"as_agi_2"])
	_passive_rank(tree, &"as_agi_4", "Soft Soles", "Footsteps muted. Take 5% less fall damage per rank.", 6, 4, 11, &"fall_dmg_reduce", 0.05, 5, [&"as_agi_3"])
	_unlock_ability(tree, &"as_agi_5", "Wall Run", "Active: run on walls for 2 sec. 0 cost. 8s CD.", 6, 5, 16, &"wall_run", [&"as_agi_4"])
	_passive_rank(tree, &"as_agi_6", "Reactive", "+5 stamina regen in combat per rank.", 6, 6, 22, &"stamina_regen", 5.0, 5, [&"as_agi_5"])
	_capstone(tree, &"as_agi_7", "Wind-Walker", "Toggle: 50% chance to fully dodge any hit. Passive when active.", 6, 7, 30, &"wind_walker", [&"as_agi_6"])

	# LETHALITY (col 1.5/extension - reuse col 6 to col 7): crits + execution
	_passive_rank(tree, &"as_leth_1", "Killer Eye", "+1% crit chance per rank.", 7, 1, 1, &"crit_chance", 0.01, 5, [])
	_passive_rank(tree, &"as_leth_2", "Cruel", "+5% crit damage per rank.", 7, 2, 4, &"crit_multiplier", 0.05, 5, [&"as_leth_1"])
	_unlock_ability(tree, &"as_leth_3", "Execute", "ST: instant-kill if target below 25% HP. 20 stamina. 12s CD.", 7, 3, 7, &"execute", [&"as_leth_2"])
	_passive_rank(tree, &"as_leth_4", "Vital Strike", "+5% damage to bosses per rank.", 7, 4, 11, &"vs_boss_dmg", 0.05, 5, [&"as_leth_3"])
	_passive_rank(tree, &"as_leth_5", "Bloody Hands", "Crit kills refund 25% stamina per rank (max 100%).", 7, 5, 16, &"crit_kill_stamina", 0.25, 4, [&"as_leth_4"])
	_unlock_ability(tree, &"as_leth_6", "Decapitate", "ST: heavy strike, +50% to bosses, lifesteal 30%. 35 stamina. 18s CD.", 7, 6, 22, &"decapitate", [&"as_leth_5"])
	_capstone(tree, &"as_leth_7", "Reaper", "Below 50% HP enemies always crit on first hit. Passive.", 7, 7, 30, &"reaper", [&"as_leth_6"])

	# ESPIONAGE (col 8): utility, vendor discounts, lockpicking
	_passive_rank(tree, &"as_esp_1", "Light Fingers", "+5% gold from kills per rank.", 8, 1, 1, &"gold_per_kill", 0.05, 5, [])
	_unlock_ability(tree, &"as_esp_2", "Pickpocket", "Active: steal gold from target. 0 cost. 30s CD.", 8, 2, 4, &"pickpocket", [&"as_esp_1"])
	_passive_rank(tree, &"as_esp_3", "Black Market Friend", "Vendor discount 3% per rank.", 8, 3, 7, &"vendor_discount", 0.03, 5, [&"as_esp_2"])
	_passive_rank(tree, &"as_esp_4", "Lockpicker", "+5% rare drop chance from chests per rank.", 8, 4, 11, &"chest_rare", 0.05, 5, [&"as_esp_3"])
	_unlock_ability(tree, &"as_esp_5", "Disguise", "Active: 30 sec, neutral to non-aggressive enemies. 0 cost. 120s CD.", 8, 5, 16, &"disguise", [&"as_esp_4"])
	_passive_rank(tree, &"as_esp_6", "Information Broker", "+3% xp gain per rank.", 8, 6, 22, &"xp_gain_pct", 0.03, 5, [&"as_esp_5"], true)
	_capstone(tree, &"as_esp_7", "Ghost in Babilim", "Active: 60 sec invisible to all NPCs in town. 600s CD.", 8, 7, 30, &"ghost_in_babilim", [&"as_esp_6"])

	return tree

# ============================================================
# CHAOS DRUID skill tree (7 branches x 7 nodes = 49)
# WILD | GROVE | CHAOS | THORN | BEAST | ELEMENTAL | TIAMAT
# Abilities cost mana out of form, stamina in form.
# ============================================================
static func build_chaos_druid_tree() -> SkillTree:
	var tree := SkillTree.new()
	tree.class_id = &"chaos_druid"

	# WILD (form unlocks)
	_unlock_ability(tree, &"cd_wild_1", "Wild Shape: Wolf", "Unlocks Dire Wolf form. 25 mana to enter.", 0, 1, 1, &"form_wolf", [])
	_passive_rank(tree, &"cd_wild_2", "Wild Endurance", "+10% form duration per rank.", 0, 2, 4, &"form_duration", 0.10, 5, [&"cd_wild_1"])
	_unlock_ability(tree, &"cd_wild_3", "Wild Shape: Bear", "Unlocks Iron Bear form. 35 mana to enter.", 0, 3, 7, &"form_bear", [&"cd_wild_2"])
	_unlock_ability(tree, &"cd_wild_4", "Wild Shape: Raven", "Unlocks Storm Raven form. 20 mana to enter.", 0, 4, 11, &"form_raven", [&"cd_wild_3"])
	_unlock_ability(tree, &"cd_wild_5", "Wild Shape: Serpent", "Unlocks Venom Serpent form. 25 mana.", 0, 5, 16, &"form_serpent", [&"cd_wild_4"])
	_passive_rank(tree, &"cd_wild_6", "Form Mastery", "+5% form damage per rank.", 0, 6, 22, &"form_dmg", 0.05, 5, [&"cd_wild_5"])
	_capstone(tree, &"cd_wild_7", "Spawn of Tiamat", "Unlocks Dragon form. 100 mana, 18s duration.", 0, 7, 30, &"form_dragon", [&"cd_wild_6"])

	# GROVE (nature spells)
	_unlock_ability(tree, &"cd_grove_1", "Healing Bloom", "Heal 100 HP. 20 mana, 6s CD.", 1, 1, 1, &"healing_bloom", [])
	_passive_rank(tree, &"cd_grove_2", "Verdant Hand", "+8% heal effective per rank.", 1, 2, 4, &"heal_potency", 0.08, 5, [&"cd_grove_1"])
	_unlock_ability(tree, &"cd_grove_3", "Entangle", "Roots target 3s. 25 mana. 12s CD.", 1, 3, 7, &"entangle", [&"cd_grove_2"])
	_passive_rank(tree, &"cd_grove_4", "Wisdom of Trees", "+3% wisdom per rank.", 1, 4, 11, &"wisdom", 0.03, 5, [&"cd_grove_3"], true)
	_unlock_ability(tree, &"cd_grove_5", "Spring Renewal", "AOE heal in 8m, 80 + 0.6*spellpower. 40 mana. 30s CD.", 1, 5, 16, &"spring_renewal", [&"cd_grove_4"])
	_passive_rank(tree, &"cd_grove_6", "Mother-Tree Bond", "+5 mana regen per rank.", 1, 6, 22, &"mana_regen", 5.0, 5, [&"cd_grove_5"])
	_capstone(tree, &"cd_grove_7", "World-Tree", "Plant living tree, 12s, heals allies in 10m. 80 mana. 180s CD.", 1, 7, 30, &"world_tree", [&"cd_grove_6"])

	# CHAOS (mutations, instability)
	_unlock_ability(tree, &"cd_chaos_1", "Chaos Bolt", "Random element bolt. 15 mana. 3s CD.", 2, 1, 1, &"chaos_bolt", [])
	_passive_rank(tree, &"cd_chaos_2", "Mutation", "Damage rolls a random +1-25% bonus per cast per rank.", 2, 2, 4, &"chaos_dmg_roll", 0.05, 5, [&"cd_chaos_1"])
	_unlock_ability(tree, &"cd_chaos_3", "Wildform Mark", "Mark target: random debuff applied. 20 mana. 8s CD.", 2, 3, 7, &"wildform_mark", [&"cd_chaos_2"])
	_passive_rank(tree, &"cd_chaos_4", "Unstable Blood", "+3% spell damage per rank.", 2, 4, 11, &"spell_damage_pct", 0.03, 5, [&"cd_chaos_3"], true)
	_unlock_ability(tree, &"cd_chaos_5", "Chaos Burst", "Random AOE: explodes, freezes, burns, or shocks. 35 mana. 18s CD.", 2, 5, 16, &"chaos_burst", [&"cd_chaos_4"])
	_passive_rank(tree, &"cd_chaos_6", "Embraced Chaos", "+1% crit chance per rank.", 2, 6, 22, &"crit_chance", 0.01, 5, [&"cd_chaos_5"])
	_capstone(tree, &"cd_chaos_7", "Wild Magic", "Each cast triggers a random additional spell at 50%. Toggle.", 2, 7, 30, &"wild_magic", [&"cd_chaos_6"])

	# THORN (DoT, poison)
	_unlock_ability(tree, &"cd_thorn_1", "Thorn Whip", "Bleed: 5 dmg/sec for 4s. 15 mana. 4s CD.", 3, 1, 1, &"thorn_whip", [])
	_passive_rank(tree, &"cd_thorn_2", "Deepening Poison", "+8% poison/bleed duration per rank.", 3, 2, 4, &"dot_duration", 0.08, 5, [&"cd_thorn_1"])
	_unlock_ability(tree, &"cd_thorn_3", "Thicket", "AOE field, 4m, slows + 4 dmg/sec. 30 mana. 18s CD.", 3, 3, 7, &"thicket", [&"cd_thorn_2"])
	_passive_rank(tree, &"cd_thorn_4", "Verdant Toxin", "+3% poison damage per rank.", 3, 4, 11, &"poison_dmg", 0.03, 5, [&"cd_thorn_3"])
	_unlock_ability(tree, &"cd_thorn_5", "Wrath of Thorns", "Channel: thorns burst from caster, 6m AOE, 3s. 50 mana. 30s CD.", 3, 5, 16, &"wrath_of_thorns", [&"cd_thorn_4"])
	_passive_rank(tree, &"cd_thorn_6", "Bloodroot", "DoT crits +25% damage per rank.", 3, 6, 22, &"dot_crit_dmg", 0.25, 5, [&"cd_thorn_5"])
	_capstone(tree, &"cd_thorn_7", "Garden of the Dying", "All enemies in 12m gain stacking thorn-poison; 8s, 240s CD.", 3, 7, 30, &"garden_dying", [&"cd_thorn_6"])

	# BEAST (form claw/fang abilities, in-form)
	_unlock_ability(tree, &"cd_beast_1", "Claw", "In Wolf/Bear form: physical strike, 30 stamina. 3s CD.", 4, 1, 1, &"form_claw", [])
	_passive_rank(tree, &"cd_beast_2", "Sharp Fangs", "+5% form damage per rank.", 4, 2, 4, &"form_dmg", 0.05, 5, [&"cd_beast_1"], true)
	_unlock_ability(tree, &"cd_beast_3", "Roar", "AOE 6m, fear 2s. 35 stamina. 18s CD.", 4, 3, 7, &"form_roar", [&"cd_beast_2"])
	_passive_rank(tree, &"cd_beast_4", "Pounce", "+5% leap distance per rank.", 4, 4, 11, &"leap_distance", 0.05, 5, [&"cd_beast_3"])
	_unlock_ability(tree, &"cd_beast_5", "Maul", "Heavy form-strike with bleed. 45 stamina. 12s CD.", 4, 5, 16, &"form_maul", [&"cd_beast_4"])
	_passive_rank(tree, &"cd_beast_6", "Beast Resilience", "+5% form max HP per rank.", 4, 6, 22, &"form_max_hp", 0.05, 5, [&"cd_beast_5"], true)
	_capstone(tree, &"cd_beast_7", "Alpha", "In any form: +25% damage and +25% HP. Toggle.", 4, 7, 30, &"alpha_form", [&"cd_beast_6"])

	# ELEMENTAL (storm, earth)
	_unlock_ability(tree, &"cd_elem_1", "Spark", "Lightning bolt. 15 mana. 3s CD.", 5, 1, 1, &"druid_spark", [])
	_unlock_ability(tree, &"cd_elem_2", "Frost Cone", "Frost cone, slow + dmg. 25 mana. 8s CD.", 5, 2, 4, &"frost_cone", [&"cd_elem_1"])
	_unlock_ability(tree, &"cd_elem_3", "Earthquake", "AOE ground stomp, 6m, knockup. 35 mana. 20s CD.", 5, 3, 7, &"earthquake", [&"cd_elem_2"])
	_passive_rank(tree, &"cd_elem_4", "Elemental Affinity", "+5% elemental damage per rank.", 5, 4, 11, &"elem_dmg", 0.05, 5, [&"cd_elem_3"])
	_unlock_ability(tree, &"cd_elem_5", "Storm Caller", "Channel: lightning strikes random enemies for 4s. 50 mana. 30s CD.", 5, 5, 16, &"storm_caller", [&"cd_elem_4"])
	_passive_rank(tree, &"cd_elem_6", "Stone Skin", "+3 armor per rank.", 5, 6, 22, &"armor", 3.0, 5, [&"cd_elem_5"])
	_capstone(tree, &"cd_elem_7", "Avatar of Storm", "Active: 12s storm form, +50% lightning dmg. 240s CD.", 5, 7, 30, &"avatar_storm", [&"cd_elem_6"])

	# TIAMAT (chaos blood)
	_passive_rank(tree, &"cd_tia_1", "Chaos Blood", "+3% all damage per rank.", 6, 1, 1, &"all_dmg", 0.03, 5, [], true)
	_unlock_ability(tree, &"cd_tia_2", "Bloodsong", "Heal 5% HP on kill while in form. Passive.", 6, 2, 4, &"bloodsong", [&"cd_tia_1"])
	_passive_rank(tree, &"cd_tia_3", "Tiamat's Memory", "+5% form damage per rank.", 6, 3, 7, &"form_dmg", 0.05, 5, [&"cd_tia_2"], true)
	_unlock_ability(tree, &"cd_tia_4", "Inheritor", "Active: enter dragon form for 8s without using capstone. 60 mana. 240s CD.", 6, 4, 11, &"inheritor_dragon", [&"cd_tia_3"])
	_passive_rank(tree, &"cd_tia_5", "Mother's Blood", "+10 max HP per rank.", 6, 5, 16, &"max_hp", 10.0, 5, [&"cd_tia_4"])
	_passive_rank(tree, &"cd_tia_6", "Chaos Reign", "+5% damage in dragon form per rank.", 6, 6, 22, &"dragon_dmg", 0.05, 5, [&"cd_tia_5"])
	_capstone(tree, &"cd_tia_7", "Heir of Tiamat", "Dragon form duration becomes indefinite while above 50% HP.", 6, 7, 30, &"heir_of_tiamat", [&"cd_tia_6"])

	return tree

# ============================================================
# DEMON skill tree (7 branches x 7 nodes = 49)
# Abilities are FREE; tree shapes how Blood, day/night, lifesteal compose.
# LEGION | HUNGER | DAMNATION | ABYSS | NIGHTBORN | INFERNAL | WRATH
# ============================================================
static func build_demon_tree() -> SkillTree:
	var tree := SkillTree.new()
	tree.class_id = &"demon"

	# LEGION (summons)
	_unlock_ability(tree, &"dm_legion_1", "Summon Shade", "Pet shade for 30s, free. 30s CD.", 0, 1, 1, &"summon_shade", [])
	_passive_rank(tree, &"dm_legion_2", "Pact-Bound", "+10% shade damage per rank.", 0, 2, 4, &"pet_dmg", 0.10, 5, [&"dm_legion_1"])
	_unlock_ability(tree, &"dm_legion_3", "Summon Imp", "Pet imp, fast attacker. 45s CD.", 0, 3, 7, &"summon_imp", [&"dm_legion_2"])
	_passive_rank(tree, &"dm_legion_4", "Sworn Servants", "+1 max active pets per rank.", 0, 4, 11, &"max_pets", 1.0, 3, [&"dm_legion_3"])
	_unlock_ability(tree, &"dm_legion_5", "Summon Hellhound", "Pet hellhound, AOE bite. 60s CD.", 0, 5, 16, &"summon_hellhound", [&"dm_legion_4"])
	_passive_rank(tree, &"dm_legion_6", "Master of Pets", "Pets share 5% of your damage per rank.", 0, 6, 22, &"pet_share_dmg", 0.05, 5, [&"dm_legion_5"])
	_capstone(tree, &"dm_legion_7", "Legion", "Active: 8 sec, summon 4 lesser shades. 240s CD.", 0, 7, 30, &"legion_capstone", [&"dm_legion_6"])

	# HUNGER (lifesteal)
	_passive_rank(tree, &"dm_hung_1", "Hungering Blade", "+1% lifesteal per rank.", 1, 1, 1, &"lifesteal", 0.01, 5, [])
	_unlock_ability(tree, &"dm_hung_2", "Soul Drain", "Single target heavy lifesteal: heals 100% of damage dealt for 4s. 30s CD.", 1, 2, 4, &"soul_drain", [&"dm_hung_1"])
	_passive_rank(tree, &"dm_hung_3", "Devour", "+2% kill heal per rank.", 1, 3, 7, &"kill_heal_pct", 0.02, 5, [&"dm_hung_2"])
	_passive_rank(tree, &"dm_hung_4", "Insatiable", "+5% damage to wounded enemies (below 50% HP) per rank.", 1, 4, 11, &"wounded_dmg", 0.05, 5, [&"dm_hung_3"])
	_unlock_ability(tree, &"dm_hung_5", "Feast", "AOE 6m, heals 50% of damage dealt. 60s CD.", 1, 5, 16, &"feast", [&"dm_hung_4"])
	_passive_rank(tree, &"dm_hung_6", "Crimson Form", "+5 max HP per rank.", 1, 6, 22, &"max_hp", 5.0, 5, [&"dm_hung_5"])
	_capstone(tree, &"dm_hung_7", "Crimson Tide", "Active: 8s aura, all damage dealt heals 50% to caster. 240s CD.", 1, 7, 30, &"crimson_tide", [&"dm_hung_6"])

	# DAMNATION (curses)
	_unlock_ability(tree, &"dm_dam_1", "Curse of Weakness", "Target: -25% damage dealt for 12s. Free. 8s CD.", 2, 1, 1, &"curse_weakness", [])
	_passive_rank(tree, &"dm_dam_2", "Lingering Curse", "+5% curse duration per rank.", 2, 2, 4, &"curse_dur", 0.05, 5, [&"dm_dam_1"])
	_unlock_ability(tree, &"dm_dam_3", "Curse of Pain", "Target: takes +20% damage from all sources for 8s. Free. 12s CD.", 2, 3, 7, &"curse_pain", [&"dm_dam_2"])
	_passive_rank(tree, &"dm_dam_4", "Hex Master", "+3% curse potency per rank.", 2, 4, 11, &"curse_pot", 0.03, 5, [&"dm_dam_3"])
	_unlock_ability(tree, &"dm_dam_5", "Curse of Doom", "Target: explodes for 200 damage in 5m on death. Free. 18s CD.", 2, 5, 16, &"curse_doom", [&"dm_dam_4"])
	_passive_rank(tree, &"dm_dam_6", "Cursed Blade", "Curses tick +5% per rank.", 2, 6, 22, &"curse_tick", 0.05, 5, [&"dm_dam_5"])
	_capstone(tree, &"dm_dam_7", "Plague Mark", "Active: 8m AOE applies all 3 curses. 180s CD.", 2, 7, 30, &"plague_mark", [&"dm_dam_6"])

	# ABYSS (void)
	_unlock_ability(tree, &"dm_abyss_1", "Void Bolt", "Bolt ignoring 30% armor. Free. 4s CD.", 3, 1, 1, &"void_bolt_demon", [])
	_passive_rank(tree, &"dm_abyss_2", "Void-Touched", "+3% armor pen per rank.", 3, 2, 4, &"armor_pen", 0.03, 5, [&"dm_abyss_1"])
	_unlock_ability(tree, &"dm_abyss_3", "Dark Step", "Teleport 8m forward + brief invulnerability. 24s CD.", 3, 3, 7, &"dark_step", [&"dm_abyss_2"])
	_passive_rank(tree, &"dm_abyss_4", "Shadow Skin", "+3% magic resist per rank.", 3, 4, 11, &"magic_resist", 0.03, 5, [&"dm_abyss_3"], true)
	_unlock_ability(tree, &"dm_abyss_5", "Void Pull", "Pull all in 8m to caster. 30s CD.", 3, 5, 16, &"void_pull", [&"dm_abyss_4"])
	_passive_rank(tree, &"dm_abyss_6", "Abyssal Eye", "+1% crit chance per rank.", 3, 6, 22, &"crit_chance", 0.01, 5, [&"dm_abyss_5"])
	_capstone(tree, &"dm_abyss_7", "Beyond Sight", "Phased: 6 sec untargetable, attack from anywhere. 180s CD.", 3, 7, 30, &"beyond_sight", [&"dm_abyss_6"])

	# NIGHTBORN (night-only)
	_passive_rank(tree, &"dm_night_1", "Nightblood", "+5% damage at night per rank.", 4, 1, 1, &"night_dmg_bonus", 0.05, 5, [])
	_passive_rank(tree, &"dm_night_2", "Moonlit Veins", "+1 HP regen at night per rank.", 4, 2, 4, &"night_hp_regen", 1.0, 5, [&"dm_night_1"])
	_unlock_ability(tree, &"dm_night_3", "Twilight Veil", "At night: 8s damage reduction 25%. 60s CD.", 4, 3, 7, &"twilight_veil", [&"dm_night_2"])
	_passive_rank(tree, &"dm_night_4", "Lightless Step", "+5% movement at night per rank.", 4, 4, 11, &"night_move", 0.05, 5, [&"dm_night_3"])
	_passive_rank(tree, &"dm_night_5", "Day-Cursed", "Reduce day damage debuff by 5% per rank.", 4, 5, 16, &"day_debuff_reduce", 0.05, 4, [&"dm_night_4"])
	_passive_rank(tree, &"dm_night_6", "Sun-Eater", "+5% damage to enemies in light (their daytime) per rank.", 4, 6, 22, &"sunlit_dmg", 0.05, 5, [&"dm_night_5"])
	_capstone(tree, &"dm_night_7", "Eternal Night", "Active: become immune to day debuff for 30 sec. 600s CD.", 4, 7, 30, &"eternal_night", [&"dm_night_6"])

	# INFERNAL (fire/sulfur)
	_unlock_ability(tree, &"dm_inf_1", "Hellfire Bolt", "Fire bolt, 60 dmg + 6/sec burn. Free. 4s CD.", 5, 1, 1, &"hellfire_bolt", [])
	_passive_rank(tree, &"dm_inf_2", "Smoldering", "Burn duration +1s per rank.", 5, 2, 4, &"burn_dur", 1.0, 5, [&"dm_inf_1"])
	_unlock_ability(tree, &"dm_inf_3", "Sulfur Cloud", "AOE 5m, ignite, 8s duration. Free. 18s CD.", 5, 3, 7, &"sulfur_cloud", [&"dm_inf_2"])
	_passive_rank(tree, &"dm_inf_4", "Inner Furnace", "+3% fire damage per rank.", 5, 4, 11, &"fire_dmg", 0.03, 5, [&"dm_inf_3"])
	_unlock_ability(tree, &"dm_inf_5", "Hellfire Cone", "Cone breath, ignites all in path. 18s CD.", 5, 5, 16, &"hellfire_cone", [&"dm_inf_4"])
	_passive_rank(tree, &"dm_inf_6", "Body of Embers", "Damage taken triggers 10 fire dmg retaliation per rank.", 5, 6, 22, &"ember_retal", 10.0, 5, [&"dm_inf_5"])
	_capstone(tree, &"dm_inf_7", "Pyre", "Active: 12s, become a moving inferno, 6m AOE 30 dmg/sec. 180s CD.", 5, 7, 30, &"pyre", [&"dm_inf_6"])

	# WRATH (Blood scaling)
	_passive_rank(tree, &"dm_wrath_1", "Bloodthirst", "+1 Blood per kill per rank.", 6, 1, 1, &"blood_per_kill", 1.0, 5, [])
	_passive_rank(tree, &"dm_wrath_2", "Crimson Edge", "+2% damage per Blood point above 50 per rank.", 6, 2, 4, &"blood_high_dmg", 0.02, 5, [&"dm_wrath_1"])
	_unlock_ability(tree, &"dm_wrath_3", "Sacrifice", "Spend 50 Blood: gain +50% damage for 8s. 30s CD.", 6, 3, 7, &"blood_sacrifice", [&"dm_wrath_2"])
	_passive_rank(tree, &"dm_wrath_4", "Scion of Lucifer", "+5% damage in dragon, demon, or any transform per rank.", 6, 4, 11, &"transform_dmg", 0.05, 5, [&"dm_wrath_3"])
	_passive_rank(tree, &"dm_wrath_5", "Bloody Cap", "+5 max Blood per rank (above the 100 baseline).", 6, 5, 16, &"blood_cap", 5.0, 5, [&"dm_wrath_4"])
	_passive_rank(tree, &"dm_wrath_6", "Endless Hunger", "Blood does not decay over time. (Default no decay; this slot reserved for future use.)", 6, 6, 22, &"blood_no_decay", 1.0, 1, [&"dm_wrath_5"])
	_capstone(tree, &"dm_wrath_7", "Lucifer's Heir", "At full Blood: +200% damage instead of +100%. Costs 50 Blood per attack.", 6, 7, 30, &"lucifer_heir", [&"dm_wrath_6"])

	return tree

# ============================================================
# MAGE skill tree (built from MageSpellRegistry)
# 7 schools x 7 tiers = 49 spell unlocks. Linear within school.
# ============================================================
static func build_mage_tree() -> SkillTree:
	var tree := SkillTree.new()
	tree.class_id = &"mage"
	var schools := MageSpellRegistry.all_schools()
	var col := 0
	for school in schools:
		_add_school_branch(tree, school, col)
		col += 1
	return tree

static func _add_school_branch(tree: SkillTree, school: SpellSchool, col: int) -> void:
	for spell: MageSpell in school.spells:
		var n := SkillNode.new()
		n.id = StringName("mage_%s_%d" % [school.id, spell.tier])
		n.display_name = "%s: Tier %d" % [school.display_name, spell.tier]
		n.description = spell.description
		n.cost = 1 if spell.tier < 7 else 3  # capstone tier costs more
		n.min_level = max(1, spell.tier * 7 - 6)  # tier 1 = lvl 1, tier 7 = lvl 43+
		n.grid_position = Vector2(col * 2.0, float(spell.tier) * 1.2)
		n.effect = SkillNode.Effect.UNLOCK_ABILITY
		n.target_key = spell.id
		n.ability_unlock = spell
		if spell.tier > 1:
			n.prerequisites = [StringName("mage_%s_%d" % [school.id, spell.tier - 1])]
		tree.nodes.append(n)
