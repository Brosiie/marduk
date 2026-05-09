extends BossBase
class_name GladeTerror

# The Glade Terror.
# Mini-boss at the end of Greenheart Glade. Ranger's first real test.
# Tiamat-spawn that came through a thin spot in the world; antlered,
# bone-veined, four-legged. Faster than anything natural. Hunts by smell.
#
# Phase 1 (100-50% HP): Wary. Tracks the player from distance, lunges
#                       when close. Heavy use of the LINE-shape pounce.
# Phase 2 (50-0% HP):   Berserk. Adds an antler GORE charge, a roar that
#                       pushes the player off cover, and a final desperate
#                       leap from above.

func _ready() -> void:
	boss_id = &"glade_terror"
	# A Tiamat-spawn — every faction has reason to want it dead.
	# Crown + Druids both notice.
	faction_rep_on_kill = {&"crown": 75, &"druids": 75, &"inquisition": 50}
	display_name = "The Glade Terror"
	encounter_level = 1
	is_main_boss = false
	is_final_boss = false

	max_hp = 440.0
	hp = max_hp
	armor = 5.0
	magic_resist = 5.0
	move_speed = 4.5  # very fast — Tiamat-spawn predator
	detect_radius = 26.0
	attack_range = 3.0
	attack_cooldown = 0.0
	contact_damage = 24.0
	xp_reward = 165

	phases_data = [
		{"hp_pct": 1.0, "name": "Wary Hunter",   "dmg_mult": 1.0,  "speed_mult": 1.0},
		{"hp_pct": 0.5, "name": "Berserk Spawn", "dmg_mult": 1.30, "speed_mult": 1.20},
	]

	attack_patterns = _build_patterns()
	super._ready()

func _build_patterns() -> Array[BossAttackPattern]:
	# CLAW SWIPE: short forward arc; the Terror's bread-and-butter melee.
	# Quick windup so a Ranger camping at melee range pays for it.
	var swipe := BossAttackPattern.new()
	swipe.id = &"terror_swipe"
	swipe.display_name = "Antler-Slash"
	swipe.tell_description = "The Terror lowers its head — the antler arc is coming."
	swipe.shape = BossAttackPattern.Shape.FORWARD_CONE
	swipe.range = 3.0
	swipe.radius = 2.0
	swipe.arc_degrees = 110.0
	swipe.windup_seconds = 0.95
	swipe.execute_seconds = 0.30
	swipe.recovery_seconds = 0.9
	swipe.cooldown = 3.5
	swipe.base_damage = 28.0
	swipe.damage_type = 0
	swipe.priority_weight = 8.0
	swipe.min_phase = 0
	swipe.max_phase = 99
	swipe.telegraph_color = Color(0.65, 0.45, 0.30, 0.55)
	swipe.dodge_window = 0.50

	# POUNCE: a long LINE-shape lunge. The Terror covers ground fast.
	# Phase 1 distance-closer aimed at Rangers who think they can kite.
	var pounce := BossAttackPattern.new()
	pounce.id = &"terror_pounce"
	pounce.display_name = "Pounce"
	pounce.tell_description = "The Terror coils — it is leaping. Sidestep."
	pounce.shape = BossAttackPattern.Shape.LINE
	pounce.range = 8.0
	pounce.radius = 1.4
	pounce.windup_seconds = 0.85
	pounce.execute_seconds = 0.40
	pounce.recovery_seconds = 1.0
	pounce.cooldown = 6.0
	pounce.base_damage = 32.0
	pounce.damage_type = 0
	pounce.priority_weight = 7.0
	pounce.min_phase = 0
	pounce.max_phase = 99
	pounce.telegraph_color = Color(0.85, 0.45, 0.30, 0.65)
	pounce.dodge_window = 0.50

	# GORE CHARGE: phase 2, full CHARGE shape. The Terror sprints + the
	# antler hitbox travels with it. Get out of the line early.
	var gore := BossAttackPattern.new()
	gore.id = &"terror_gore"
	gore.display_name = "Antler-Gore"
	gore.tell_description = "The Terror lowers its head and ROARS — the charge is committed."
	gore.shape = BossAttackPattern.Shape.CHARGE
	gore.range = 10.0
	gore.radius = 1.4
	gore.windup_seconds = 1.10
	gore.execute_seconds = 1.10
	gore.recovery_seconds = 1.4
	gore.cooldown = 8.5
	gore.base_damage = 42.0
	gore.damage_type = 0
	gore.priority_weight = 6.0
	gore.min_phase = 1
	gore.max_phase = 99
	gore.telegraph_color = Color(0.85, 0.30, 0.20, 0.70)
	gore.dodge_window = 0.55

	# ROAR: phase 2, AOE_AROUND_BOSS knockback. Pushes the Ranger off cover
	# (the boss arena has tree stumps + boulders). Forces the player to
	# rotate position.
	var roar := BossAttackPattern.new()
	roar.id = &"terror_roar"
	roar.display_name = "Hunting-Roar"
	roar.tell_description = "The Terror plants and roars — the air pushes you back. Hold ground or move."
	roar.shape = BossAttackPattern.Shape.AOE_AROUND_BOSS
	roar.radius = 4.0
	roar.range = 4.0
	roar.windup_seconds = 1.05
	roar.execute_seconds = 0.30
	roar.recovery_seconds = 1.2
	roar.cooldown = 9.0
	roar.base_damage = 24.0
	roar.damage_type = 0
	roar.priority_weight = 5.0
	roar.min_phase = 1
	roar.max_phase = 99
	roar.telegraph_color = Color(0.55, 0.85, 0.45, 0.65)
	roar.dodge_window = 0.55

	# DEATH-FROM-ABOVE: phase 2 desperation LEAP. The Terror jumps to a
	# tree branch off-screen and crashes down on the player's last position.
	var leap := BossAttackPattern.new()
	leap.id = &"terror_death_from_above"
	leap.display_name = "Death-From-Above"
	leap.tell_description = "The Terror vanishes UP — it is on a branch. Watch the marker."
	leap.shape = BossAttackPattern.Shape.LEAP
	leap.range = 12.0
	leap.radius = 3.0
	leap.windup_seconds = 1.40
	leap.execute_seconds = 0.55
	leap.recovery_seconds = 1.6
	leap.cooldown = 12.0
	leap.base_damage = 48.0
	leap.damage_type = 0
	leap.priority_weight = 4.0
	leap.min_phase = 1
	leap.max_phase = 99
	leap.requires_hp_below_pct = 0.35
	leap.telegraph_color = Color(0.85, 0.45, 0.20, 0.78)
	leap.dodge_window = 0.55

	return [swipe, pounce, gore, roar, leap]

func _die_custom() -> void:
	_drop_glade_widow_bow()
	var arena: Node = _find_parent_arena()
	if arena and arena.has_method("on_boss_defeated"):
		arena.on_boss_defeated(boss_id)

func _drop_glade_widow_bow() -> void:
	var bow := Item.new()
	bow.id = &"terror_glade_widow_bow"
	bow.display_name = "The Terror's Bone-Bow"
	bow.slot = Item.Slot.WEAPON_MAIN
	bow.weapon_type = Item.WeaponType.BOW
	bow.rarity = Item.Rarity.RARE
	bow.item_level = 1
	bow.base_damage = 24.0
	bow.attack_speed = 1.0
	bow.weapon_range = 14.0
	bow.dexterity_bonus = 4.0
	bow.crit_chance_bonus = 0.05
	bow.is_two_handed = true
	bow.class_restriction = [&"ranger"]

	var pickup := ItemPickup.new()
	pickup.name = "TerrorLoot_Bow"
	pickup.item = bow
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
