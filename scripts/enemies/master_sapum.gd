extends BossBase
class_name MasterSapum

# Master Sapum the Five-Mouthed.
# Mini-boss at the end of the Whisper Shrine. Assassin's first real test.
# A poisoner-blade-master who teaches by trying to kill his initiates. He
# carries five daggers in a fan-belt and throws them in pairs.
#
# Phase 1 (100-50% HP): Patient. Daggers pull stealth, throws kunai pairs,
#                       paces the player.
# Phase 2 (50-0% HP):   Cornered. Adds a venom cloud, a teleport-strike
#                       (LEAP), and a desperate dual-blade flurry.

func _ready() -> void:
	boss_id = &"master_sapum"
	display_name = "Master Sapum, Five-Mouthed"
	encounter_level = 1
	is_main_boss = false
	is_final_boss = false

	max_hp = 380.0
	hp = max_hp
	armor = 4.0      # light, fast — Assassin tier
	magic_resist = 6.0
	move_speed = 4.2  # fastest mini-boss so far
	detect_radius = 24.0
	attack_range = 2.4
	attack_cooldown = 0.0
	contact_damage = 22.0
	xp_reward = 165

	phases_data = [
		{"hp_pct": 1.0, "name": "Five-Mouthed",  "dmg_mult": 1.0,  "speed_mult": 1.0},
		{"hp_pct": 0.5, "name": "Cornered Snake","dmg_mult": 1.30, "speed_mult": 1.30},
	]

	attack_patterns = _build_patterns()
	super._ready()

func _build_patterns() -> Array[BossAttackPattern]:
	# DUAL DAGGER STRIKE: short cone arc, fast windup. Phase 1 mainstay.
	# Assassin-flavored — quick double-stab that opens with a feint.
	var dual := BossAttackPattern.new()
	dual.id = &"sapum_dual"
	dual.display_name = "Five-Stab"
	dual.tell_description = "Sapum's hands blur — a double-strike feint and follow-through."
	dual.shape = BossAttackPattern.Shape.FORWARD_CONE
	dual.range = 2.6
	dual.radius = 1.4
	dual.arc_degrees = 80.0
	dual.windup_seconds = 0.85
	dual.execute_seconds = 0.30
	dual.recovery_seconds = 0.7
	dual.cooldown = 3.0
	dual.base_damage = 26.0
	dual.damage_type = 0
	dual.priority_weight = 9.0
	dual.min_phase = 0
	dual.max_phase = 99
	dual.telegraph_color = Color(0.65, 0.95, 0.45, 0.55)
	dual.dodge_window = 0.45

	# KUNAI PAIR: two thrown daggers, line shape — long range pickoff.
	# Phase 1; the projectile spawn isn't bound to a real projectile node yet
	# so it deals damage at range as if Sapum's reach extended.
	var kunai := BossAttackPattern.new()
	kunai.id = &"sapum_kunai"
	kunai.display_name = "Twin Kunai"
	kunai.tell_description = "Sapum draws two from his fan-belt — get sideways or expect to bleed."
	kunai.shape = BossAttackPattern.Shape.LINE
	kunai.range = 11.0
	kunai.radius = 0.6
	kunai.windup_seconds = 0.95
	kunai.execute_seconds = 0.30
	kunai.recovery_seconds = 0.85
	kunai.cooldown = 5.0
	kunai.base_damage = 22.0
	kunai.damage_type = 0
	kunai.priority_weight = 6.0
	kunai.min_phase = 0
	kunai.max_phase = 99
	kunai.telegraph_color = Color(0.85, 0.65, 0.20, 0.65)
	kunai.dodge_window = 0.50

	# VENOM CLOUD: ground AOE that lingers. Phase 2.
	# Forces position rotation; player can't camp the kill window after a
	# parry without eating poison. AOE_GROUND with longer execute_seconds
	# makes the cloud hover during the window.
	var cloud := BossAttackPattern.new()
	cloud.id = &"sapum_venom_cloud"
	cloud.display_name = "Venom Bloom"
	cloud.tell_description = "Sapum hurls a green vial — the cloud lingers, do not stand in it."
	cloud.shape = BossAttackPattern.Shape.AOE_GROUND
	cloud.range = 7.0
	cloud.radius = 2.4
	cloud.windup_seconds = 1.10
	cloud.execute_seconds = 1.20  # long cloud lifetime
	cloud.recovery_seconds = 1.0
	cloud.cooldown = 8.5
	cloud.base_damage = 14.0  # per-tick, lower per hit but the duration sells it
	cloud.damage_type = 0
	cloud.priority_weight = 5.0
	cloud.min_phase = 1
	cloud.max_phase = 99
	cloud.telegraph_color = Color(0.45, 0.85, 0.40, 0.70)
	cloud.dodge_window = 0.55

	# SHADOW STEP: short LEAP-style teleport-strike. Phase 2 distance closer.
	# Sapum vanishes and reappears on the player's last position with a
	# strike. Shorter range than Hassu's Pillar-Vault — this is a knife,
	# not a hammer.
	var shadow_step := BossAttackPattern.new()
	shadow_step.id = &"sapum_shadow_step"
	shadow_step.display_name = "Shadow Step"
	shadow_step.tell_description = "Sapum dissolves into smoke — he is appearing AT you. Dodge through, not back."
	shadow_step.shape = BossAttackPattern.Shape.LEAP
	shadow_step.range = 7.0
	shadow_step.radius = 1.6
	shadow_step.windup_seconds = 0.95
	shadow_step.execute_seconds = 0.45
	shadow_step.recovery_seconds = 1.2
	shadow_step.cooldown = 8.0
	shadow_step.base_damage = 36.0
	shadow_step.damage_type = 0
	shadow_step.priority_weight = 5.0
	shadow_step.min_phase = 1
	shadow_step.max_phase = 99
	shadow_step.telegraph_color = Color(0.20, 0.30, 0.25, 0.70)
	shadow_step.dodge_window = 0.45

	# FLURRY: phase 2 capstone — Sapum spins through a full arc fast,
	# anti-camping radial. Five strikes in 0.6 seconds; sounds like
	# his five mouths are speaking at once.
	var flurry := BossAttackPattern.new()
	flurry.id = &"sapum_flurry"
	flurry.display_name = "Five-Mouth Chorus"
	flurry.tell_description = "Sapum lowers all five blades and starts to spin — back away, do not block."
	flurry.shape = BossAttackPattern.Shape.AOE_AROUND_BOSS
	flurry.radius = 2.6
	flurry.range = 2.6
	flurry.windup_seconds = 1.20
	flurry.execute_seconds = 0.60
	flurry.recovery_seconds = 1.6
	flurry.cooldown = 11.0
	flurry.base_damage = 32.0
	flurry.damage_type = 0
	flurry.priority_weight = 4.0
	flurry.min_phase = 1
	flurry.max_phase = 99
	flurry.requires_hp_below_pct = 0.30  # only when desperate
	flurry.telegraph_color = Color(0.85, 0.30, 0.40, 0.75)
	flurry.dodge_window = 0.50

	return [dual, kunai, cloud, shadow_step, flurry]

func _die_custom() -> void:
	_drop_whisper_initiate_dagger()
	var arena: Node = _find_parent_arena()
	if arena and arena.has_method("on_boss_defeated"):
		arena.on_boss_defeated(boss_id)

func _drop_whisper_initiate_dagger() -> void:
	# Mirror's the Bronze-Katana / Steppe-Skull-Axe pattern: a
	# class-restricted RARE drop straight into ItemPickup.
	var dagger := Item.new()
	dagger.id = &"sapum_whisper_dagger"
	dagger.display_name = "Sapum's Whisper-Initiate Dagger"
	dagger.slot = Item.Slot.WEAPON_MAIN
	dagger.weapon_type = Item.WeaponType.DAGGER
	dagger.rarity = Item.Rarity.RARE
	dagger.item_level = 1
	dagger.base_damage = 18.0
	dagger.attack_speed = 1.4
	dagger.weapon_range = 1.6
	dagger.dexterity_bonus = 5.0
	dagger.crit_chance_bonus = 0.06
	dagger.class_restriction = [&"assassin"]

	var pickup := ItemPickup.new()
	pickup.name = "SapumLoot_Dagger"
	pickup.item = dagger
	pickup.quantity = 1
	pickup.position = global_position + Vector3(0, 0.5, 0)
	get_tree().current_scene.add_child(pickup)

func _find_parent_arena() -> Node:
	var p := get_parent()
	while p:
		if p.is_in_group("boss_arena"):
			return p
		p = p.get_parent()
	return null
