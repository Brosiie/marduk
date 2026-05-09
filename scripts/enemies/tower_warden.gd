extends BossBase
class_name TowerWarden

# The Tower Warden.
# Mini-boss at the top of the Inkstone Tower. Mage's first real test.
# A bound spirit set to guard the upper archives — the Warden was once a
# mage themselves; the binding burned out everything but the spell-shapes
# they knew. They cast in long flowing arcs.
#
# Phase 1 (100-50% HP): Bookish. Bolts and a bound-magic ground sigil.
# Phase 2 (50-0% HP):   Burning. Adds a fire wave, a teleport-cast (the
#                       Warden no longer cares about the floor under them),
#                       and a desperate arcane detonation.

func _ready() -> void:
	boss_id = &"tower_warden"
	# Warden was bound to Inkstone (Six Breaths' sister-temple). Killing
	# unbinds the spirit; Six Breaths sees this as mercy.
	faction_rep_on_kill = {&"six_breaths": 75}
	display_name = "The Tower Warden"
	encounter_level = 1
	is_main_boss = false
	is_final_boss = false

	max_hp = 360.0  # less HP than melee bosses — the Warden is squishy
	hp = max_hp
	armor = 3.0      # cloth caster
	magic_resist = 9.0
	move_speed = 3.0
	detect_radius = 24.0
	attack_range = 8.0
	attack_cooldown = 0.0
	contact_damage = 14.0
	xp_reward = 165

	phases_data = [
		{"hp_pct": 1.0, "name": "Bound Warden",  "dmg_mult": 1.0,  "speed_mult": 1.0},
		{"hp_pct": 0.5, "name": "Binding Burns", "dmg_mult": 1.40, "speed_mult": 1.10},
	]

	attack_patterns = _build_patterns()
	super._ready()

func _build_patterns() -> Array[BossAttackPattern]:
	# ARCANE BOLT: long-range LINE projectile. Phase 1 mainstay.
	# Mages should LEARN to dodge sideways; the bolt rewards exactly that.
	var bolt := BossAttackPattern.new()
	bolt.id = &"warden_arcane_bolt"
	bolt.display_name = "Arcane Bolt"
	bolt.tell_description = "The Warden raises their hand — light gathers at the fingertip."
	bolt.shape = BossAttackPattern.Shape.LINE
	bolt.range = 14.0
	bolt.radius = 0.7
	bolt.windup_seconds = 1.10
	bolt.execute_seconds = 0.30
	bolt.recovery_seconds = 0.85
	bolt.cooldown = 3.5
	bolt.base_damage = 28.0
	bolt.damage_type = 1  # ARCANE
	bolt.priority_weight = 8.0
	bolt.min_phase = 0
	bolt.max_phase = 99
	bolt.telegraph_color = Color(0.55, 0.40, 0.95, 0.65)
	bolt.dodge_window = 0.55

	# BINDING SIGIL: AOE_GROUND that locks the player in place if they're
	# inside on impact. The visual is a violet circle that pulses faster
	# as it ticks down.
	var sigil := BossAttackPattern.new()
	sigil.id = &"warden_binding_sigil"
	sigil.display_name = "Binding Sigil"
	sigil.tell_description = "The Warden traces a circle in the air — get out of the violet ring."
	sigil.shape = BossAttackPattern.Shape.AOE_GROUND
	sigil.range = 8.0
	sigil.radius = 2.4
	sigil.windup_seconds = 1.30
	sigil.execute_seconds = 0.40
	sigil.recovery_seconds = 1.0
	sigil.cooldown = 7.5
	sigil.base_damage = 32.0
	sigil.damage_type = 1
	sigil.priority_weight = 6.0
	sigil.min_phase = 0
	sigil.max_phase = 99
	sigil.telegraph_color = Color(0.65, 0.30, 0.85, 0.70)
	sigil.dodge_window = 0.55

	# FIRE WAVE: phase 2 — wide forward cone of fire. The binding has burned
	# through and the Warden can throw raw element now.
	var fire_wave := BossAttackPattern.new()
	fire_wave.id = &"warden_fire_wave"
	fire_wave.display_name = "Fire Wave"
	fire_wave.tell_description = "The Warden's hands burst into flame — wide cone, dodge sideways."
	fire_wave.shape = BossAttackPattern.Shape.FORWARD_CONE
	fire_wave.range = 7.0
	fire_wave.radius = 4.5
	fire_wave.arc_degrees = 100.0
	fire_wave.windup_seconds = 1.20
	fire_wave.execute_seconds = 0.35
	fire_wave.recovery_seconds = 1.2
	fire_wave.cooldown = 7.0
	fire_wave.base_damage = 38.0
	fire_wave.damage_type = 2  # FIRE
	fire_wave.priority_weight = 6.0
	fire_wave.min_phase = 1
	fire_wave.max_phase = 99
	fire_wave.telegraph_color = Color(1.00, 0.45, 0.20, 0.70)
	fire_wave.dodge_window = 0.55

	# BLINK STRIKE: phase 2 LEAP — the Warden teleports next to the player
	# and drops a close-range arcane burst. Anti-camping the back arch.
	var blink := BossAttackPattern.new()
	blink.id = &"warden_blink_strike"
	blink.display_name = "Blink-Strike"
	blink.tell_description = "The Warden vanishes — they are appearing AT you. Dodge through."
	blink.shape = BossAttackPattern.Shape.LEAP
	blink.range = 9.0
	blink.radius = 2.0
	blink.windup_seconds = 0.95
	blink.execute_seconds = 0.45
	blink.recovery_seconds = 1.4
	blink.cooldown = 9.0
	blink.base_damage = 36.0
	blink.damage_type = 1
	blink.priority_weight = 5.0
	blink.min_phase = 1
	blink.max_phase = 99
	blink.telegraph_color = Color(0.45, 0.40, 0.95, 0.70)
	blink.dodge_window = 0.45

	# DETONATION: phase 2 capstone, AOE_AROUND_BOSS. The Warden burns out
	# the binding with a full release of stored arcane. Big damage, big
	# recovery — punish window if you survive.
	var detonate := BossAttackPattern.new()
	detonate.id = &"warden_detonation"
	detonate.display_name = "Binding Detonation"
	detonate.tell_description = "The Warden's runes burn brighter — back away NOW. The detonation is short and total."
	detonate.shape = BossAttackPattern.Shape.AOE_AROUND_BOSS
	detonate.radius = 5.0
	detonate.range = 5.0
	detonate.windup_seconds = 1.40
	detonate.execute_seconds = 0.30
	detonate.recovery_seconds = 1.8
	detonate.cooldown = 12.0
	detonate.base_damage = 50.0
	detonate.damage_type = 1
	detonate.priority_weight = 4.0
	detonate.min_phase = 1
	detonate.max_phase = 99
	detonate.requires_hp_below_pct = 0.30
	detonate.telegraph_color = Color(0.85, 0.30, 0.95, 0.78)
	detonate.dodge_window = 0.65

	return [bolt, sigil, fire_wave, blink, detonate]

func _die_custom() -> void:
	_drop_warden_staff()
	var arena: Node = _find_parent_arena()
	if arena and arena.has_method("on_boss_defeated"):
		arena.on_boss_defeated(boss_id)

func _drop_warden_staff() -> void:
	var staff := Item.new()
	staff.id = &"warden_inkstone_staff"
	staff.display_name = "The Warden's Inkstone Staff"
	staff.slot = Item.Slot.WEAPON_MAIN
	staff.weapon_type = Item.WeaponType.STAFF
	staff.rarity = Item.Rarity.RARE
	staff.item_level = 1
	staff.base_damage = 22.0
	staff.element = Item.Element.ARCANE
	staff.element_damage_pct = 0.30
	staff.attack_speed = 0.85
	staff.weapon_range = 2.0
	staff.intellect_bonus = 6.0
	staff.mana_bonus = 18.0
	staff.is_two_handed = true
	staff.class_restriction = [&"mage"]

	var pickup := ItemPickup.new()
	pickup.name = "WardenLoot_Staff"
	pickup.item = staff
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
