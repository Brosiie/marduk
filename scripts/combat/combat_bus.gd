extends Node

# Global relay for combat events. Hitbox emits here; HUD and floaters subscribe.
# Decouples Hitbox from every consumer that needs hit data.
#
# class_name removed: this script is registered as an autoload named
# "CombatBus" in project.godot, and Godot 4 forbids `class_name` from
# matching an autoload name (would shadow the singleton lookup).
# Access from other scripts via `get_node("/root/CombatBus")` or by
# name (since autoloads are accessible globally).

signal hit_landed(target: Node, result: DamageCalc.Result, ability: Ability)
signal kill_registered(target: Node, killer: Node)
signal perfect_parry(position: Vector3)
signal stance_broken(position: Vector3)

func emit_hit(target: Node, result: DamageCalc.Result, ability: Ability) -> void:
	hit_landed.emit(target, result, ability)
	if result.killed:
		kill_registered.emit(target, null)
	# Spawn damage floater immediately so every hit gets a number.
	if target is Node3D:
		var element: StringName = _element_name(ability.damage_type if ability else 0)
		DamageFloater.spawn(target as Node3D, result.damage, result.crit, element)

func _element_name(damage_type: int) -> StringName:
	match damage_type:
		Ability.DamageType.FIRE:      return &"fire"
		Ability.DamageType.FROST:     return &"frost"
		Ability.DamageType.LIGHTNING: return &"lightning"
		Ability.DamageType.HOLY:      return &"holy"
		Ability.DamageType.SHADOW:    return &"shadow"
		Ability.DamageType.ARCANE:    return &"void"
		_:                            return &"physical"
