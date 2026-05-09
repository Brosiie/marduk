extends BossBase
class_name SahirumWitchBurner

# Sahirum the Witch-Burner.
# Mini-boss at the end of Coven Glen. Druid's first real test.
# An Inquisition-prime sent to clean the Wound's frontier — torch, prayer-
# scroll, and a long iron pole. He hunts Druids specifically. The Wound
# pushes back through the Druid; Sahirum learned to expect that.
#
# Phase 1 (100-50% HP): Methodical. Pole strikes + a thrown torch.
# Phase 2 (50-0% HP):   Fanatical. Prayer-line ground burn, leap to
#                       reposition, holy detonation.

func _ready() -> void:
	boss_id = &"sahirum_witch_burner"
	display_name = "Sahirum the Witch-Burner"
	encounter_level = 1
	is_main_boss = false
	is_final_boss = false

	max_hp = 420.0
	hp = max_hp
	armor = 7.0       # Inquisition mail
	magic_resist = 8.0
	move_speed = 3.4
	detect_radius = 22.0
	attack_range = 3.5
	attack_cooldown = 0.0
	contact_damage = 18.0
	xp_reward = 165

	phases_data = [
		{"hp_pct": 1.0, "name": "Inquisitor",   "dmg_mult": 1.0,  "speed_mult": 1.0},
		{"hp_pct": 0.5, "name": "Burning Faith","dmg_mult": 1.30, "speed_mult": 1.15},
	]

	attack_patterns = _build_patterns()
	super._ready()

func _build_patterns() -> Array[BossAttackPattern]:
	# POLE STRIKE: long forward thrust. Phase 1 mainstay; the iron pole
	# has reach, so backing up doesn't always escape.
	var thrust := BossAttackPattern.new()
	thrust.id = &"sahirum_thrust"
	thrust.display_name = "Iron Thrust"
	thrust.tell_description = "Sahirum sets his back foot — the pole comes straight."
	thrust.shape = BossAttackPattern.Shape.LINE
	thrust.range = 4.5
	thrust.radius = 0.9
	thrust.windup_seconds = 1.05
	thrust.execute_seconds = 0.30
	thrust.recovery_seconds = 1.0
	thrust.cooldown = 4.0
	thrust.base_damage = 30.0
	thrust.damage_type = 0
	thrust.priority_weight = 8.0
	thrust.min_phase = 0
	thrust.max_phase = 99
	thrust.telegraph_color = Color(0.95, 0.85, 0.45, 0.55)
	thrust.dodge_window = 0.55

	# TORCH HURL: thrown ranged HOLY damage. Phase 1.
	# A LINE pattern carrying a holy-tagged hitbox. Druids in Wound-
	# corruption form take double damage from holy — flagged via
	# the existing damage_type system.
	var torch := BossAttackPattern.new()
	torch.id = &"sahirum_torch"
	torch.display_name = "Burning Torch"
	torch.tell_description = "Sahirum unhooks his torch — incoming, ducks the line."
	torch.shape = BossAttackPattern.Shape.LINE
	torch.range = 9.0
	torch.radius = 0.9
	torch.windup_seconds = 0.95
	torch.execute_seconds = 0.30
	torch.recovery_seconds = 0.85
	torch.cooldown = 5.5
	torch.base_damage = 26.0
	torch.damage_type = 5  # HOLY
	torch.priority_weight = 6.0
	torch.min_phase = 0
	torch.max_phase = 99
	torch.telegraph_color = Color(1.00, 0.65, 0.20, 0.65)
	torch.dodge_window = 0.50

	# PRAYER-LINE BURN: a thin AOE_GROUND that burns in a long line.
	# Phase 2. The Druid's animal forms have to break stance to clear it.
	var prayer_line := BossAttackPattern.new()
	prayer_line.id = &"sahirum_prayer_line"
	prayer_line.display_name = "Prayer-Line"
	prayer_line.tell_description = "Sahirum chants and draws a line of holy fire across the ground — leap or run."
	prayer_line.shape = BossAttackPattern.Shape.AOE_GROUND
	prayer_line.range = 8.0
	prayer_line.radius = 1.4
	prayer_line.windup_seconds = 1.30
	prayer_line.execute_seconds = 1.40   # long-burning line
	prayer_line.recovery_seconds = 0.85
	prayer_line.cooldown = 8.0
	prayer_line.base_damage = 18.0
	prayer_line.damage_type = 5
	prayer_line.priority_weight = 5.0
	prayer_line.min_phase = 1
	prayer_line.max_phase = 99
	prayer_line.telegraph_color = Color(1.00, 0.85, 0.30, 0.70)
	prayer_line.dodge_window = 0.55

	# CRUSADER LEAP: phase 2 LEAP — Sahirum vaults onto the player. Slower
	# than other bosses' leaps (he's heavier in mail) but punishing on
	# landing.
	var leap := BossAttackPattern.new()
	leap.id = &"sahirum_leap"
	leap.display_name = "Crusader Leap"
	leap.tell_description = "Sahirum gathers himself and JUMPS — heavy crash incoming, dodge AT the marker."
	leap.shape = BossAttackPattern.Shape.LEAP
	leap.range = 9.0
	leap.radius = 2.6
	leap.windup_seconds = 1.40
	leap.execute_seconds = 0.70
	leap.recovery_seconds = 1.5
	leap.cooldown = 11.0
	leap.base_damage = 44.0
	leap.damage_type = 5
	leap.priority_weight = 5.0
	leap.min_phase = 1
	leap.max_phase = 99
	leap.requires_hp_below_pct = 0.40
	leap.telegraph_color = Color(0.95, 0.65, 0.25, 0.78)
	leap.dodge_window = 0.55

	# HOLY DETONATION: phase 2 capstone. AOE_AROUND_BOSS holy explosion.
	# Sahirum invokes the full prayer; clear the radius or eat 50.
	var detonation := BossAttackPattern.new()
	detonation.id = &"sahirum_detonation"
	detonation.display_name = "Final Prayer"
	detonation.tell_description = "Sahirum kneels and prays — back away NOW. The light is total."
	detonation.shape = BossAttackPattern.Shape.AOE_AROUND_BOSS
	detonation.radius = 4.5
	detonation.range = 4.5
	detonation.windup_seconds = 1.50
	detonation.execute_seconds = 0.30
	detonation.recovery_seconds = 1.8
	detonation.cooldown = 12.0
	detonation.base_damage = 50.0
	detonation.damage_type = 5
	detonation.priority_weight = 4.0
	detonation.min_phase = 1
	detonation.max_phase = 99
	detonation.requires_hp_below_pct = 0.30
	detonation.telegraph_color = Color(1.00, 0.95, 0.55, 0.80)
	detonation.dodge_window = 0.65

	return [thrust, torch, prayer_line, leap, detonation]

func _die_custom() -> void:
	_drop_inquisitor_mace()
	var arena: Node = _find_parent_arena()
	if arena and arena.has_method("on_boss_defeated"):
		arena.on_boss_defeated(boss_id)

func _drop_inquisitor_mace() -> void:
	# Sahirum carries a polearm but the loot is a one-handed bludgeon —
	# his secondary, the one he used to break confessions out of suspects.
	# Druid-restricted because the Druid is the one who took it from him.
	var mace := Item.new()
	mace.id = &"sahirum_inquisitor_mace"
	mace.display_name = "Sahirum's Confession-Mace"
	mace.slot = Item.Slot.WEAPON_MAIN
	mace.weapon_type = Item.WeaponType.BLUDGEON
	mace.rarity = Item.Rarity.RARE
	mace.item_level = 1
	mace.base_damage = 24.0
	mace.attack_speed = 0.95
	mace.weapon_range = 2.2
	mace.intellect_bonus = 3.0
	mace.vitality_bonus = 3.0
	mace.class_restriction = [&"chaos_druid"]

	var pickup := ItemPickup.new()
	pickup.name = "SahirumLoot_Mace"
	pickup.item = mace
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
