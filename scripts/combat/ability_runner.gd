extends Node
class_name AbilityRunner

# Centralized ability execution: cooldowns, cast windups, hitbox spawning.
# Attached to the Player node. Handles all ability casts including breathing forms,
# class signatures, item-granted actives, and form-specific abilities.
#
# Lifecycle of a cast:
#   try_cast(ability) -> validate cost + cooldown + lock state
#                     -> begin windup (player.locked = true)
#                     -> on windup end: spawn hitbox, emit ability_cast signal
#                     -> on recovery end: unlock player

signal ability_cast(ability: Ability, was_perfect: bool)
signal ability_failed(ability: Ability, reason: String)
signal cooldown_started(ability_id: StringName, duration: float)
signal cooldown_ended(ability_id: StringName)

@export var owner_player: Node  # the Player CharacterBody3D

var cooldowns: Dictionary = {}  # StringName -> seconds remaining
var current_cast: Ability = null
var current_cast_time_left: float = 0.0
var current_cast_started_at: float = 0.0

func _process(delta: float) -> void:
	# Tick cooldowns
	var to_remove: Array = []
	for id in cooldowns.keys():
		cooldowns[id] = cooldowns[id] - delta
		if cooldowns[id] <= 0.0:
			to_remove.append(id)
	for id in to_remove:
		cooldowns.erase(id)
		cooldown_ended.emit(id)

	# Tick active cast
	if current_cast:
		current_cast_time_left -= delta
		if current_cast_time_left <= 0.0:
			_complete_cast()

func is_on_cooldown(ability_id: StringName) -> bool:
	return cooldowns.has(ability_id) and cooldowns[ability_id] > 0.0

func cooldown_remaining(ability_id: StringName) -> float:
	return cooldowns.get(ability_id, 0.0)

func try_cast(ability: Ability) -> bool:
	if not owner_player or not is_instance_valid(owner_player):
		return false
	if owner_player.locked:
		ability_failed.emit(ability, "locked")
		return false
	if current_cast:
		ability_failed.emit(ability, "already casting")
		return false
	if is_on_cooldown(ability.id):
		ability_failed.emit(ability, "on cooldown")
		return false

	# Resource cost check (mana / rage / stance / etc)
	if not _validate_cost(ability):
		ability_failed.emit(ability, "insufficient resource")
		return false

	# BreathingForm extra: stance charge cost (Ronin)
	if ability is BreathingForm and (ability as BreathingForm).stance_charge_cost > 0:
		if not owner_player.spend_stance_charges((ability as BreathingForm).stance_charge_cost):
			ability_failed.emit(ability, "insufficient stance")
			return false

	_pay_cost(ability)
	_begin_cast(ability)
	return true

func _validate_cost(ability: Ability) -> bool:
	if not owner_player.stats or not owner_player.stats.class_def:
		return true
	var mech: StringName = owner_player.stats.class_def.resource_mechanic
	# Mana classes pay from resource_value; rage/focus also pay from resource_value
	if ability.mana_cost > 0.0:
		if mech == &"corruption":
			# Demon abilities also bleed HP; check HP threshold instead
			return owner_player.stats.hp > ability.mana_cost
		return owner_player.resource_value >= ability.mana_cost
	return true

func _pay_cost(ability: Ability) -> void:
	if ability.mana_cost <= 0.0:
		return
	var mech: StringName = owner_player.stats.class_def.resource_mechanic
	if mech == &"corruption":
		# Demon: cost is HP drain into corruption
		owner_player.stats.hp = max(1.0, owner_player.stats.hp - ability.mana_cost)
		owner_player.resource_value = min(
			owner_player.stats.class_def.resource_max,
			owner_player.resource_value + ability.mana_cost
		)
		owner_player.hp_changed.emit(owner_player.stats.hp, owner_player.stats.max_hp)
	else:
		owner_player.resource_value = max(0.0, owner_player.resource_value - ability.mana_cost)
	owner_player.resource_changed.emit(
		owner_player.resource_value,
		owner_player.stats.class_def.resource_max,
		mech
	)

func _begin_cast(ability: Ability) -> void:
	current_cast = ability
	current_cast_started_at = Time.get_ticks_msec() / 1000.0
	if ability.cast_time > 0.0:
		owner_player.locked = true
		current_cast_time_left = ability.cast_time
		# Play windup animation if available
		if owner_player.anim_player and ability is BreathingForm:
			var bf: BreathingForm = ability
			if owner_player.anim_player.has_animation(String(bf.animation_name)):
				owner_player.anim_player.play(String(bf.animation_name))
	else:
		# Instant cast
		current_cast_time_left = 0.0
		_complete_cast()

func _complete_cast() -> void:
	if not current_cast:
		return
	var ability := current_cast
	var was_perfect := false  # TODO: hook perfect-window detection (input frame timing)

	# Apply chain bonus from Ronin sequence tracker
	var chain_mult: float = 1.0
	if owner_player.has_method("consume_chain_bonus"):
		chain_mult = owner_player.consume_chain_bonus(ability)

	# Spawn the hitbox(es) for this ability
	_spawn_hitbox(ability, chain_mult)

	# Set cooldown
	if ability.cooldown > 0.0:
		cooldowns[ability.id] = ability.cooldown
		cooldown_started.emit(ability.id, ability.cooldown)

	owner_player.locked = false
	ability_cast.emit(ability, was_perfect)
	current_cast = null

func _spawn_hitbox(ability: Ability, damage_mult: float) -> void:
	# Build an Area3D with a CollisionShape3D matching the ability's target_mode.
	# The Hitbox script handles damage resolution + lifetime cleanup. Damage_mult
	# pre-scales base_damage on the ability's effective payload.
	if not owner_player or not is_inside_tree():
		return

	var hb := preload("res://scripts/combat/hitbox.gd").new()
	hb.ability = ability
	hb.attacker_stats = owner_player.stats
	hb.lifetime = max(0.10, ability.cast_time + 0.15)
	hb.team = &"player"
	hb.set_meta("attacker_node", owner_player)

	var collider := CollisionShape3D.new()
	hb.add_child(collider)

	# Pose origin in front of player by ability range/2, oriented to mesh forward
	var fwd: Vector3 = Vector3.FORWARD
	if owner_player.mesh:
		fwd = -owner_player.mesh.global_transform.basis.z
		fwd.y = 0
		fwd = fwd.normalized()

	# Build geometry based on target_mode
	match ability.target_mode:
		Ability.TargetMode.SELF:
			# Tiny sphere on player position; primarily for buffs that hit self
			var s := SphereShape3D.new()
			s.radius = 0.5
			collider.shape = s

		Ability.TargetMode.FORWARD_CONE:
			# Approximate cone with a forward-extended box. Radius = arc width.
			var b := BoxShape3D.new()
			var width: float = max(0.8, ability.radius)
			var depth: float = max(1.0, ability.range)
			b.size = Vector3(width, 2.0, depth)
			collider.shape = b
			hb.position = owner_player.global_position + fwd * (depth * 0.5)
			hb.look_at(owner_player.global_position + fwd * depth, Vector3.UP)

		Ability.TargetMode.AOE_AROUND_SELF:
			var s := SphereShape3D.new()
			s.radius = max(0.5, ability.radius)
			collider.shape = s
			hb.position = owner_player.global_position

		Ability.TargetMode.GROUND_TARGETED:
			# Ground circle at end of range
			var s := SphereShape3D.new()
			s.radius = max(0.5, ability.radius)
			collider.shape = s
			hb.position = owner_player.global_position + fwd * ability.range

		Ability.TargetMode.PROJECTILE:
			# Thin box that travels forward over lifetime
			var b := BoxShape3D.new()
			b.size = Vector3(0.5, 0.5, max(1.0, ability.range))
			collider.shape = b
			hb.position = owner_player.global_position + fwd * (ability.range * 0.5)
			# TODO: attach to a moving body in a real impl

	# Pre-scale base damage by chain bonus and class proficiency. damage_calc applies the rest.
	var scaled_damage := ability.base_damage * damage_mult
	# Stash the multiplier on the hitbox via meta for damage_calc to read
	hb.set_meta("pre_scale", damage_mult)

	get_tree().current_scene.add_child(hb)
