extends BossBase
class_name HassuTheHooked

# Hassu the Hooked.
# Mini-boss at the end of Ash-Step Camp. Berserker's first real test.
# Steppe warlord with a chained hook on a long haft. Brawls like he means it.
#
# Phase 1 (100-50% HP): Patient. Reads the player. Cleave + hook-pull lure.
# Phase 2 (50-0% HP):   Berserk. Adds leap, charge, ground slam — the whole
#                       Bond's-overhaul kit. Hassu's blood is up; you brought
#                       this on him.

func _ready() -> void:
	boss_id = &"hassu_hooked"
	# Hassu was a steppe-clan warlord; the Crown views him as an outlaw.
	# Killing him is mildly Crown-friendly.
	faction_rep_on_kill = {&"crown": 50}
	display_name = "Hassu the Hooked"
	encounter_level = 1
	is_main_boss = false
	is_final_boss = false

	max_hp = 460.0
	hp = max_hp
	armor = 6.0
	magic_resist = 3.0
	move_speed = 3.5  # slightly faster than Kazat — Hassu hunts, doesn't anchor
	detect_radius = 22.0
	attack_range = 3.2
	attack_cooldown = 0.0
	contact_damage = 20.0
	xp_reward = 160

	phases_data = [
		{"hp_pct": 1.0, "name": "Steppe Hunter",  "dmg_mult": 1.0,  "speed_mult": 1.0},
		{"hp_pct": 0.5, "name": "Hook-Madness",   "dmg_mult": 1.30, "speed_mult": 1.20},
	]

	attack_patterns = _build_patterns()
	super._ready()

func _build_patterns() -> Array[BossAttackPattern]:
	# CLEAVE: wide horizontal hook-arc. Phase 1 mainstay.
	# Different read from Kazat's vertical sweep — the arc starts low and
	# rises, so dodging UNDER the swing doesn't work. Step inside or back.
	var cleave := BossAttackPattern.new()
	cleave.id = &"hassu_cleave"
	cleave.display_name = "Hook Arc"
	cleave.tell_description = "Hassu drops his weight onto his back foot — the arc is coming."
	cleave.shape = BossAttackPattern.Shape.FORWARD_CONE
	cleave.range = 3.4
	cleave.radius = 2.6
	cleave.arc_degrees = 140.0
	cleave.windup_seconds = 1.3
	cleave.execute_seconds = 0.30
	cleave.recovery_seconds = 1.2
	cleave.cooldown = 4.5
	cleave.base_damage = 30.0
	cleave.damage_type = 0
	cleave.priority_weight = 8.0
	cleave.min_phase = 0
	cleave.max_phase = 99
	cleave.telegraph_color = Color(0.85, 0.30, 0.15, 0.55)
	cleave.dodge_window = 0.55

	# CLEAVE FAST (phase 2): less windup, hits harder, recovers shorter.
	var cleave_fast := BossAttackPattern.new()
	cleave_fast.id = &"hassu_cleave_fast"
	cleave_fast.display_name = "Hook Arc (Bloodied)"
	cleave_fast.tell_description = "Hassu cleaves without setting his feet — there is no warning."
	cleave_fast.shape = BossAttackPattern.Shape.FORWARD_CONE
	cleave_fast.range = 3.4
	cleave_fast.radius = 2.6
	cleave_fast.arc_degrees = 140.0
	cleave_fast.windup_seconds = 0.85
	cleave_fast.execute_seconds = 0.25
	cleave_fast.recovery_seconds = 0.8
	cleave_fast.cooldown = 3.5
	cleave_fast.base_damage = 32.0
	cleave_fast.damage_type = 0
	cleave_fast.priority_weight = 9.0
	cleave_fast.min_phase = 1
	cleave_fast.max_phase = 99
	cleave_fast.telegraph_color = Color(0.85, 0.20, 0.15, 0.55)
	cleave_fast.dodge_window = 0.40

	# HOOK-PULL: a thrown hook that strikes the player at range and yanks them
	# into melee. Phase 1 — Hassu's distance-closer. Implemented as a long
	# narrow LINE pattern; if it lands the player should be dragged into cleave
	# range on hit. The pull effect is a TODO for the engine; for now the
	# pattern just deals damage at range, which still rewards reading + dodging.
	var pull := BossAttackPattern.new()
	pull.id = &"hassu_pull"
	pull.display_name = "Hook Pull"
	pull.tell_description = "Hassu winds the chain around his arm — the hook is leaving his hand soon."
	pull.shape = BossAttackPattern.Shape.LINE
	pull.range = 8.0
	pull.radius = 0.7
	pull.windup_seconds = 1.1
	pull.execute_seconds = 0.40
	pull.recovery_seconds = 1.3
	pull.cooldown = 7.0
	pull.base_damage = 28.0
	pull.damage_type = 0
	pull.priority_weight = 6.0
	pull.min_phase = 0
	pull.max_phase = 99
	pull.telegraph_color = Color(0.95, 0.45, 0.20, 0.60)
	pull.dodge_window = 0.55

	# CHARGE: phase 2. Hassu sprints in a straight line. Bond's CHARGE shape
	# physically moves the boss + travels the hitbox.
	var charge := BossAttackPattern.new()
	charge.id = &"hassu_charge"
	charge.display_name = "Steppe Charge"
	charge.tell_description = "Hassu lowers his shoulder and spits — sidestep, do not back-pedal."
	charge.shape = BossAttackPattern.Shape.CHARGE
	charge.range = 9.0
	charge.radius = 1.2
	charge.windup_seconds = 1.10
	charge.execute_seconds = 1.00
	charge.recovery_seconds = 1.4
	charge.cooldown = 8.0
	charge.base_damage = 40.0
	charge.damage_type = 0
	charge.priority_weight = 7.0
	charge.min_phase = 1
	charge.max_phase = 99
	charge.telegraph_color = Color(1.00, 0.30, 0.10, 0.70)
	charge.dodge_window = 0.55

	# LEAP: phase 2 capstone. Hassu vaults the broken pillar in the arena and
	# crashes down on the player's last position. Shockwave AOE on land.
	var leap := BossAttackPattern.new()
	leap.id = &"hassu_leap"
	leap.display_name = "Pillar-Vault"
	leap.tell_description = "Hassu bounds toward the broken pillar — he is using it. Watch the marker."
	leap.shape = BossAttackPattern.Shape.LEAP
	leap.range = 11.0
	leap.radius = 3.2
	leap.windup_seconds = 1.30
	leap.execute_seconds = 0.55
	leap.recovery_seconds = 1.5
	leap.cooldown = 11.0
	leap.base_damage = 48.0
	leap.damage_type = 0
	leap.priority_weight = 5.0
	leap.min_phase = 1
	leap.max_phase = 99
	leap.requires_hp_below_pct = 0.40  # only when desperate
	leap.telegraph_color = Color(1.00, 0.40, 0.15, 0.78)
	leap.dodge_window = 0.55

	# SLAM: tracking AOE_GROUND that follows the player's feet. Phase 2.
	# Different read from cleave — this CHASES, so the player has to MOVE
	# rather than just dodge sideways.
	var slam := BossAttackPattern.new()
	slam.id = &"hassu_slam"
	slam.display_name = "Earth-Splitter"
	slam.tell_description = "Hassu raises the hook overhead — the marker chases your feet, keep moving."
	slam.shape = BossAttackPattern.Shape.AOE_GROUND
	slam.range = 8.0
	slam.radius = 2.0
	slam.windup_seconds = 1.20
	slam.execute_seconds = 0.30
	slam.recovery_seconds = 1.1
	slam.cooldown = 6.5
	slam.base_damage = 36.0
	slam.damage_type = 0
	slam.priority_weight = 5.0
	slam.min_phase = 1
	slam.max_phase = 99
	slam.telegraph_color = Color(0.95, 0.30, 0.20, 0.65)
	slam.dodge_window = 0.50

	# BURST: anti-camping AOE_AROUND_BOSS. Forces the player off the back
	# (where Berserker melee chains often park).
	var burst := BossAttackPattern.new()
	burst.id = &"hassu_burst"
	burst.display_name = "Steppe-Roar"
	burst.tell_description = "Hassu plants and roars — back away before the burst lands."
	burst.shape = BossAttackPattern.Shape.AOE_AROUND_BOSS
	burst.radius = 3.2
	burst.range = 3.2
	burst.windup_seconds = 1.0
	burst.execute_seconds = 0.30
	burst.recovery_seconds = 1.4
	burst.cooldown = 9.0
	burst.base_damage = 34.0
	burst.damage_type = 0
	burst.priority_weight = 4.0
	burst.min_phase = 1
	burst.max_phase = 99
	burst.telegraph_color = Color(0.95, 0.30, 0.15, 0.70)
	burst.dodge_window = 0.45

	return [cleave, cleave_fast, pull, charge, leap, slam, burst]

func _die_custom() -> void:
	# Drop the Berserker-leaning loot inline. Mirrors Kazat's pattern.
	_drop_steppe_skull_axe()
	var arena: Node = _find_parent_arena()
	if arena and arena.has_method("on_boss_defeated"):
		arena.on_boss_defeated(boss_id)

func _drop_steppe_skull_axe() -> void:
	var axe := Item.new()
	axe.id = &"hassu_steppe_skull_axe"
	axe.display_name = "Hassu's Steppe-Skull Axe"
	axe.slot = Item.Slot.WEAPON_MAIN
	axe.weapon_type = Item.WeaponType.GREATAXE
	axe.rarity = Item.Rarity.RARE
	axe.item_level = 1
	axe.base_damage = 28.0
	axe.attack_speed = 0.85
	axe.weapon_range = 2.6
	axe.strength_bonus = 4.0
	axe.vitality_bonus = 2.0
	axe.is_two_handed = true
	axe.class_restriction = [&"berserker"]

	var pickup := ItemPickup.new()
	pickup.name = "HassuLoot_Axe"
	pickup.item = axe
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
