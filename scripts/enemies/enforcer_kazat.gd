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

	# LUNGE: Kazat charges forward 5m in a straight line.
	# Phase 2 only. Massive punish if it connects; big recovery if it misses.
	var lunge := BossAttackPattern.new()
	lunge.id = &"kazat_lunge"
	lunge.display_name = "Iron Charge"
	lunge.tell_description = "Kazat drops into a sprinting stance — sidestep, don't back-pedal."
	lunge.shape = BossAttackPattern.Shape.LINE
	lunge.range = 5.5
	lunge.radius = 1.0
	lunge.windup_seconds = 1.1
	lunge.execute_seconds = 0.35
	lunge.recovery_seconds = 1.0
	lunge.cooldown = 7.0
	lunge.base_damage = 38.0
	lunge.damage_type = 0
	lunge.priority_weight = 5.0
	lunge.min_phase = 1
	lunge.max_phase = 99
	lunge.ignores_reachability = false
	lunge.telegraph_color = Color(0.75, 0.20, 0.10, 0.65)
	lunge.dodge_window = 0.60

	return [sweep, sweep_fast, lunge]

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
