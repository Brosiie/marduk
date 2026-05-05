extends Node
class_name StatusEffectsHolder

# Lives on Player and EnemyBase. Tracks active status effects, ticks DoTs, applies modifiers,
# announces changes via signals so UI/VFX can respond.

signal effect_applied(effect: StatusEffect, stacks: int)
signal effect_removed(effect: StatusEffect)
signal effect_ticked(effect: StatusEffect, damage: float)

class ActiveEffect:
	var effect: StatusEffect
	var time_left: float
	var stacks: int = 1
	var time_until_next_tick: float

@export var actor: Node  # the Player or EnemyBase this attaches to

var active: Array = []  # of ActiveEffect

func _process(delta: float) -> void:
	if not actor or not is_instance_valid(actor):
		return
	var to_remove: Array = []
	for ae: ActiveEffect in active:
		ae.time_left -= delta
		if ae.effect.tick_interval > 0.0 and (ae.effect.damage_per_tick > 0.0 or ae.effect.heal_per_tick > 0.0):
			ae.time_until_next_tick -= delta
			while ae.time_until_next_tick <= 0.0 and ae.time_left > 0.0:
				_tick(ae)
				ae.time_until_next_tick += ae.effect.tick_interval
		if ae.time_left <= 0.0:
			to_remove.append(ae)
	for ae in to_remove:
		active.erase(ae)
		effect_removed.emit(ae.effect)

func apply(effect: StatusEffect) -> void:
	# Look for existing of same id
	for ae: ActiveEffect in active:
		if ae.effect.id == effect.id:
			if effect.stacks and ae.stacks < effect.max_stacks:
				ae.stacks += 1
			if effect.refresh_on_reapply:
				ae.time_left = effect.duration
				ae.time_until_next_tick = effect.tick_interval
			effect_applied.emit(effect, ae.stacks)
			return
	# New effect
	var ae := ActiveEffect.new()
	ae.effect = effect
	ae.time_left = effect.duration
	ae.time_until_next_tick = effect.tick_interval
	ae.stacks = 1
	active.append(ae)
	effect_applied.emit(effect, 1)

func remove(effect_id: StringName) -> void:
	for ae: ActiveEffect in active.duplicate():
		if ae.effect.id == effect_id:
			active.erase(ae)
			effect_removed.emit(ae.effect)

func has(effect_id: StringName) -> bool:
	for ae: ActiveEffect in active:
		if ae.effect.id == effect_id:
			return true
	return false

func clear_all() -> void:
	var copy := active.duplicate()
	active.clear()
	for ae in copy:
		effect_removed.emit(ae.effect)

# Aggregate modifiers (multiply across active effects)
func move_speed_multiplier() -> float:
	var m := 1.0
	for ae: ActiveEffect in active:
		m *= ae.effect.move_speed_mult
	return m

func damage_dealt_multiplier() -> float:
	var m := 1.0
	for ae: ActiveEffect in active:
		m *= ae.effect.damage_dealt_mult
	return m

func damage_taken_multiplier() -> float:
	var m := 1.0
	for ae: ActiveEffect in active:
		m *= ae.effect.damage_taken_mult
	return m

func is_actor_locked() -> bool:
	for ae: ActiveEffect in active:
		if ae.effect.locks_actor:
			return true
	return false

func _tick(ae: ActiveEffect) -> void:
	if not actor:
		return
	if ae.effect.damage_per_tick > 0.0 and actor.has_method("take_damage"):
		var dmg := ae.effect.damage_per_tick * float(ae.stacks)
		actor.take_damage(dmg, null)
		effect_ticked.emit(ae.effect, dmg)
	if ae.effect.heal_per_tick > 0.0 and actor.has_method("heal"):
		actor.heal(ae.effect.heal_per_tick * float(ae.stacks))
		effect_ticked.emit(ae.effect, -ae.effect.heal_per_tick)
