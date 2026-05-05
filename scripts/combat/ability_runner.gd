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
	# Real implementation creates Area3D with shape based on ability.target_mode and range/radius.
	# For now this emits the cast event and leaves hitbox spawning to a per-ability handler
	# (each ability or its style can register a custom spawner).
	# A future patch will move the actual hitbox geometry into ability resources or sub-scenes.
	pass
