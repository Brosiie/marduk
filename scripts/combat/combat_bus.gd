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
		# Class tint on crits — only resolve when crit so the lookup
		# doesn't run on every hit.
		var class_tint: Color = _resolve_class_tint() if result.crit else Color(0,0,0,0)
		DamageFloater.spawn(target as Node3D, result.damage, result.crit, element, class_tint)

const _CLASS_CRIT_TINTS := {
	&"berserker":            Color(0.95, 0.35, 0.20),
	&"assassin":             Color(0.55, 0.85, 0.45),
	&"ronin":                Color(0.35, 0.65, 1.00),
	&"ranger":               Color(0.85, 0.95, 0.55),
	&"mage":                 Color(0.65, 0.40, 0.95),
	&"chaos_druid":          Color(0.65, 0.85, 0.45),
	&"demon":                Color(0.95, 0.30, 0.20),
	&"paladin_guardian":     Color(1.00, 0.85, 0.45),
	&"paladin_lightbringer": Color(1.00, 0.65, 0.55),
}

func _resolve_class_tint() -> Color:
	for p in get_tree().get_nodes_in_group("player"):
		if is_instance_valid(p) and p.get("stats") and p.stats and p.stats.get("class_def") and p.stats.class_def:
			var c: StringName = p.stats.class_def.class_id
			return _CLASS_CRIT_TINTS.get(c, Color(0,0,0,0))
	return Color(0,0,0,0)

func _element_name(damage_type: int) -> StringName:
	match damage_type:
		Ability.DamageType.FIRE:      return &"fire"
		Ability.DamageType.FROST:     return &"frost"
		Ability.DamageType.LIGHTNING: return &"lightning"
		Ability.DamageType.HOLY:      return &"holy"
		Ability.DamageType.SHADOW:    return &"shadow"
		Ability.DamageType.ARCANE:    return &"void"
		_:                            return &"physical"
