extends BossBase
class_name EnforcerKazat

# Enforcer Kazat the Iron-Faced.
# Mini-boss at the end of Sword-Vow Ruins. Ronin's first real test.
# No dialogue. Just iron discipline and a greatsword.
#
# Phase 1 (100-50% HP): Measured. Wide sweep, patient spacing. Punishes button mashers.
# Phase 2 (50-0% HP):   Desperate. Adds a lunge. Shorter windup on sweep. Faster.

func _ready() -> void:
	boss_id = &"enforcer_kazat"
	# Kazat served the Crown — killing him gives the rebel/druid factions
	# a small win. Crown notices.
	faction_rep_on_kill = {&"crown": -100, &"druids": 50}
	display_name = "Enforcer Kazat the Iron-Faced"
	encounter_level = 1
	is_main_boss = false
	is_final_boss = false

	max_hp = 420.0
	hp = max_hp
	armor = 8.0
	magic_resist = 4.0
	move_speed = 3.2
	detect_radius = 20.0
	attack_range = 2.8
	attack_cooldown = 0.0  # pattern AI controls timing, not EnemyBase cooldown
	contact_damage = 18.0
	xp_reward = 150

	phases_data = [
		{"hp_pct": 1.0, "name": "Iron Discipline",  "dmg_mult": 1.0,  "speed_mult": 1.0},
		{"hp_pct": 0.5, "name": "Desperate Iron",   "dmg_mult": 1.25, "speed_mult": 1.15},
	]

	attack_patterns = _build_patterns()
	super._ready()

func _build_patterns() -> Array[BossAttackPattern]:
	# SWEEP: wide greatsword arc in front. Telegraphed by Kazat raising his blade.
	# Both phases. Phase 2 gains a shorter windup via the separate sweep_fast entry.
	var sweep := BossAttackPattern.new()
	sweep.id = &"kazat_sweep"
	sweep.display_name = "Iron Sweep"
	sweep.tell_description = "Kazat raises his greatsword to shoulder height — dodge back."
	sweep.shape = BossAttackPattern.Shape.FORWARD_CONE
	sweep.range = 3.0
	sweep.radius = 2.2
	sweep.arc_degrees = 120.0
	sweep.windup_seconds = 1.5
	sweep.execute_seconds = 0.30
	sweep.recovery_seconds = 1.3  # long recovery — punish him hard
	sweep.cooldown = 5.0
	sweep.base_damage = 28.0
	sweep.damage_type = 0  # PHYSICAL
	sweep.priority_weight = 7.0
	sweep.min_phase = 0
	sweep.max_phase = 0
	sweep.telegraph_color = Color(0.9, 0.25, 0.15, 0.55)
	sweep.dodge_window = 0.55

	# Phase 2 sweep: shorter windup, still the same pattern. Kazat is desperate now.
	var sweep_fast := BossAttackPattern.new()
	sweep_fast.id = &"kazat_sweep_fast"
	sweep_fast.display_name = "Iron Sweep (Enraged)"
	sweep_fast.tell_description = "Kazat sweeps without hesitation — you have less time."
	sweep_fast.shape = BossAttackPattern.Shape.FORWARD_CONE
	sweep_fast.range = 3.0
	sweep_fast.radius = 2.2
	sweep_fast.arc_degrees = 120.0
	sweep_fast.windup_seconds = 0.95
	sweep_fast.execute_seconds = 0.25
	sweep_fast.recovery_seconds = 0.9
	sweep_fast.cooldown = 4.0
	sweep_fast.base_damage = 28.0
	sweep_fast.damage_type = 0
	sweep_fast.priority_weight = 8.0
	sweep_fast.min_phase = 1
	sweep_fast.max_phase = 99
	sweep_fast.telegraph_color = Color(0.9, 0.25, 0.15, 0.55)
	sweep_fast.dodge_window = 0.40

	# LUNGE (legacy short-range stab): kept as a fallback when the boss
	# is just slightly out of melee. The new CHARGE replaces it as the
	# primary 'close the gap' move because CHARGE physically moves the
	# boss while LINE just spawned a stationary hitbox.
	var lunge := BossAttackPattern.new()
	lunge.id = &"kazat_lunge"
	lunge.display_name = "Iron Step"
	lunge.tell_description = "Kazat dips his blade — short stab forward."
	lunge.shape = BossAttackPattern.Shape.LINE
	lunge.range = 4.0
	lunge.radius = 0.8
	lunge.windup_seconds = 1.0
	lunge.execute_seconds = 0.30
	lunge.recovery_seconds = 1.0
	lunge.cooldown = 6.0
	lunge.base_damage = 32.0
	lunge.damage_type = 0
	lunge.priority_weight = 3.0
	lunge.min_phase = 1
	lunge.max_phase = 99
	lunge.telegraph_color = Color(0.75, 0.20, 0.10, 0.65)
	lunge.dodge_window = 0.55

	# CHARGE: Kazat sprints in a straight line for 9m. The hitbox
	# travels with the boss during execute_seconds (1.0s = 9m/s).
	# Player must SIDESTEP — back-pedaling means getting run over for
	# the full duration.
	var charge := BossAttackPattern.new()
	charge.id = &"kazat_charge"
	charge.display_name = "Iron Charge"
	charge.tell_description = "Kazat lowers his shoulder and roars — get out of the line."
	charge.shape = BossAttackPattern.Shape.CHARGE
	charge.range = 9.0
	charge.radius = 1.2
	charge.windup_seconds = 1.20
	charge.execute_seconds = 1.00  # = movement duration
	charge.recovery_seconds = 1.5
	charge.cooldown = 9.0
	charge.base_damage = 42.0
	charge.damage_type = 0
	charge.priority_weight = 6.0
	charge.min_phase = 0
	charge.max_phase = 99
	charge.telegraph_color = Color(1.0, 0.30, 0.10, 0.70)
	charge.dodge_window = 0.55

	# LEAP: Kazat crouches, jumps in an arc to player's last position,
	# lands with a shockwave AOE. Saves itself for phase 2 — desperation
	# distance-closer.
	var leap := BossAttackPattern.new()
	leap.id = &"kazat_leap"
	leap.display_name = "Iron Crash"
	leap.tell_description = "Kazat crouches deep — he is leaping at you. Dodge AT the marker, not through it."
	leap.shape = BossAttackPattern.Shape.LEAP
	leap.range = 12.0
	leap.radius = 3.5
	leap.windup_seconds = 1.40
	leap.execute_seconds = 0.55  # parabolic arc duration
	leap.recovery_seconds = 1.6
	leap.cooldown = 11.0
	leap.base_damage = 50.0
	leap.damage_type = 0
	leap.priority_weight = 5.0
	leap.min_phase = 1
	leap.max_phase = 99
	leap.telegraph_color = Color(1.0, 0.45, 0.18, 0.78)
	leap.dodge_window = 0.55

	# OVERHEAD SLAM: tracking AOE_GROUND at player's feet. Different
	# read from the cone sweep — this one CHASES, so the player must
	# MOVE rather than just dodge sideways.
	var slam := BossAttackPattern.new()
	slam.id = &"kazat_slam"
	slam.display_name = "Skybreak"
	slam.tell_description = "Kazat lifts the greatsword high — the marker chases your feet, keep moving."
	slam.shape = BossAttackPattern.Shape.AOE_GROUND
	slam.range = 8.0
	slam.radius = 2.0
	slam.windup_seconds = 1.30
	slam.execute_seconds = 0.30
	slam.recovery_seconds = 1.2
	slam.cooldown = 7.0
	slam.base_damage = 38.0
	slam.damage_type = 0
	slam.priority_weight = 4.0
	slam.min_phase = 0
	slam.max_phase = 99
	slam.telegraph_color = Color(0.95, 0.30, 0.20, 0.65)
	slam.dodge_window = 0.50

	# IRON ROAR: AOE_AROUND_BOSS knock-back for when the player is
	# camping behind / hugging the boss. Forces space, prevents
	# tail-hugging exploit.
	var burst := BossAttackPattern.new()
	burst.id = &"kazat_burst"
	burst.display_name = "Iron Roar"
	burst.tell_description = "Kazat plants his feet — back away before the burst lands."
	burst.shape = BossAttackPattern.Shape.AOE_AROUND_BOSS
	burst.radius = 3.0
	burst.range = 3.0
	burst.windup_seconds = 1.10
	burst.execute_seconds = 0.30
	burst.recovery_seconds = 1.4
	burst.cooldown = 9.0
	burst.base_damage = 36.0
	burst.damage_type = 0
	burst.priority_weight = 4.0
	burst.min_phase = 1
	burst.max_phase = 99
	burst.telegraph_color = Color(0.95, 0.30, 0.15, 0.70)
	burst.dodge_window = 0.45

	return [sweep, sweep_fast, lunge, charge, leap, slam, burst]

func _die_custom() -> void:
	# On death: drop Phase 1 demo loot inline (a bronze katana fitting for
	# the Sword-Vow Ruins narrative) and emit the phase clear signal so
	# the warp portal to Ashurim activates.
	_drop_bronze_katana()
	var arena: Node = _find_parent_arena()
	if arena and arena.has_method("on_boss_defeated"):
		arena.on_boss_defeated(boss_id)

func _drop_bronze_katana() -> void:
	# Build a minimal Item resource for the katana drop.
	var katana := Item.new()
	katana.id = &"kazat_bronze_katana"
	katana.display_name = "Kazat's Bronze Katana"
	katana.slot = Item.Slot.WEAPON_MAIN
	katana.weapon_type = Item.WeaponType.KATANA
	katana.rarity = Item.Rarity.RARE
	katana.item_level = 1
	katana.base_damage = 24.0
	katana.attack_speed = 1.1
	katana.weapon_range = 2.2
	katana.strength_bonus = 2.0
	katana.dexterity_bonus = 3.0
	katana.class_restriction = [&"ronin"]

	var pickup := ItemPickup.new()
	pickup.name = "KazatLoot_Katana"
	pickup.item = katana
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
