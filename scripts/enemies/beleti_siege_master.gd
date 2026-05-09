extends BossBase
class_name BeletiSiegeMaster

# Beleti the Siege-Master.
# Mini-boss at the end of Sun-Sworn Chapel. Both Paladin classes face him ,
# Guardian and Lightbringer share the chapel intro. He brought a battering
# ram + four kinsmen + a torch to the chapel. The kinsmen are dead; the
# torch is on the chapel doors; he's about to kick them in. You arrive in
# time to hear his final order.
#
# Phase 1 (100-50% HP): Heavy infantry. Shield-bash + hammer cleave.
# Phase 2 (50-0% HP):   Battering. Charges through, bashes again, leaps to
#                       break the line.

func _ready() -> void:
	boss_id = &"beleti_siege_master"
	# Beleti was a brigand siege-captain. Crown loves him dead. The
	# Sun-Sworn Chapel's bounty is gold, but the Crown gives diplomatic
	# weight too.
	faction_rep_on_kill = {&"crown": 100}
	display_name = "Beleti the Siege-Master"
	encounter_level = 1
	is_main_boss = false
	is_final_boss = false

	max_hp = 480.0   # heaviest mini-boss; he wears full plate
	hp = max_hp
	armor = 12.0     # heavy plate, Paladin's first lesson in armor pen
	magic_resist = 6.0
	move_speed = 2.8 # slowest mini-boss; weight of the armor
	detect_radius = 20.0
	attack_range = 3.6
	attack_cooldown = 0.0
	contact_damage = 22.0
	xp_reward = 165

	phases_data = [
		{"hp_pct": 1.0, "name": "Heavy Infantry","dmg_mult": 1.0,  "speed_mult": 1.0},
		{"hp_pct": 0.5, "name": "Battering",     "dmg_mult": 1.20, "speed_mult": 1.25},
	]

	attack_patterns = _build_patterns()
	super._ready()

func _build_patterns() -> Array[BossAttackPattern]:
	# HAMMER CLEAVE: wide horizontal arc. Phase 1 mainstay.
	# Beleti's two-handed warhammer; reaches.
	var cleave := BossAttackPattern.new()
	cleave.id = &"beleti_cleave"
	cleave.display_name = "Hammer Arc"
	cleave.tell_description = "Beleti winds back the warhammer, wide arc, time the dodge."
	cleave.shape = BossAttackPattern.Shape.FORWARD_CONE
	cleave.range = 3.6
	cleave.radius = 2.8
	cleave.arc_degrees = 130.0
	cleave.windup_seconds = 1.30
	cleave.execute_seconds = 0.30
	cleave.recovery_seconds = 1.3
	cleave.cooldown = 5.0
	cleave.base_damage = 36.0
	cleave.damage_type = 0
	cleave.priority_weight = 8.0
	cleave.min_phase = 0
	cleave.max_phase = 99
	cleave.telegraph_color = Color(0.85, 0.30, 0.20, 0.55)
	cleave.dodge_window = 0.55

	# SHIELD BASH: short fast LINE, Beleti slams forward with the shield.
	# Phase 1 distance-controller; if he's getting kited he reels you in.
	var bash := BossAttackPattern.new()
	bash.id = &"beleti_shield_bash"
	bash.display_name = "Shield Bash"
	bash.tell_description = "Beleti drops his shoulder behind the shield, incoming bash."
	bash.shape = BossAttackPattern.Shape.LINE
	bash.range = 4.5
	bash.radius = 1.0
	bash.windup_seconds = 0.75
	bash.execute_seconds = 0.30
	bash.recovery_seconds = 0.85
	bash.cooldown = 4.5
	bash.base_damage = 24.0
	bash.damage_type = 0
	bash.priority_weight = 7.0
	bash.min_phase = 0
	bash.max_phase = 99
	bash.telegraph_color = Color(0.85, 0.85, 0.55, 0.55)
	bash.dodge_window = 0.45

	# SIEGE CHARGE: phase 2 CHARGE shape. The Siege-Master earns his name ,
	# physically sprints across the arena with the shield leading.
	var charge := BossAttackPattern.new()
	charge.id = &"beleti_charge"
	charge.display_name = "Siege Charge"
	charge.tell_description = "Beleti lowers the shield and runs, sidestep, do not back-pedal."
	charge.shape = BossAttackPattern.Shape.CHARGE
	charge.range = 9.0
	charge.radius = 1.4
	charge.windup_seconds = 1.10
	charge.execute_seconds = 1.00
	charge.recovery_seconds = 1.6
	charge.cooldown = 8.5
	charge.base_damage = 44.0
	charge.damage_type = 0
	charge.priority_weight = 6.0
	charge.min_phase = 1
	charge.max_phase = 99
	charge.telegraph_color = Color(1.00, 0.30, 0.10, 0.70)
	charge.dodge_window = 0.55

	# BREACH SLAM: phase 2 LEAP. Beleti vaults forward and slams the
	# warhammer down on the player's last position. Crashes through cover.
	var slam := BossAttackPattern.new()
	slam.id = &"beleti_breach_slam"
	slam.display_name = "Breach-Slam"
	slam.tell_description = "Beleti gathers all his weight, the slam is heavy. Dodge AT the marker."
	slam.shape = BossAttackPattern.Shape.LEAP
	slam.range = 8.0
	slam.radius = 2.6
	slam.windup_seconds = 1.30
	slam.execute_seconds = 0.55
	slam.recovery_seconds = 1.7
	slam.cooldown = 11.0
	slam.base_damage = 46.0
	slam.damage_type = 0
	slam.priority_weight = 5.0
	slam.min_phase = 1
	slam.max_phase = 99
	slam.requires_hp_below_pct = 0.40
	slam.telegraph_color = Color(0.95, 0.45, 0.15, 0.75)
	slam.dodge_window = 0.55

	# WARRIOR'S ROAR: phase 2 anti-camping AOE_AROUND_BOSS. Pushes the
	# Paladin off the back-of-shield camp.
	var roar := BossAttackPattern.new()
	roar.id = &"beleti_roar"
	roar.display_name = "Warrior's Roar"
	roar.tell_description = "Beleti plants his feet and roars, back away NOW."
	roar.shape = BossAttackPattern.Shape.AOE_AROUND_BOSS
	roar.radius = 3.5
	roar.range = 3.5
	roar.windup_seconds = 1.0
	roar.execute_seconds = 0.30
	roar.recovery_seconds = 1.4
	roar.cooldown = 9.5
	roar.base_damage = 32.0
	roar.damage_type = 0
	roar.priority_weight = 4.0
	roar.min_phase = 1
	roar.max_phase = 99
	roar.telegraph_color = Color(0.95, 0.30, 0.20, 0.65)
	roar.dodge_window = 0.45

	return [cleave, bash, charge, slam, roar]

func _die_custom() -> void:
	_drop_warhammer()
	var arena: Node = _find_parent_arena()
	if arena and arena.has_method("on_boss_defeated"):
		arena.on_boss_defeated(boss_id)

func _drop_warhammer() -> void:
	# Beleti's warhammer drops as a Paladin-Guardian-restricted GREAT_BLUDGEON.
	# Lightbringers pick up a smaller secondary in their version of the fight
	# (TODO: Bond's call whether to drop a class-aware item).
	var hammer := Item.new()
	hammer.id = &"beleti_breach_hammer"
	hammer.display_name = "Beleti's Breach-Hammer"
	hammer.slot = Item.Slot.WEAPON_MAIN
	hammer.weapon_type = Item.WeaponType.GREAT_BLUDGEON
	hammer.rarity = Item.Rarity.RARE
	hammer.item_level = 1
	hammer.base_damage = 30.0
	hammer.attack_speed = 0.75
	hammer.weapon_range = 2.6
	hammer.strength_bonus = 4.0
	hammer.vitality_bonus = 3.0
	hammer.is_two_handed = true
	hammer.class_restriction = [&"paladin_guardian", &"paladin_lightbringer"]

	var pickup := ItemPickup.new()
	pickup.name = "BeletiLoot_Hammer"
	pickup.item = hammer
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
