extends Resource
class_name StatusEffect

# A timed condition applied to an actor. Common kinds: burn, poison, slow, stun, bleed,
# blind, weakness, mark, regen.
#
# Effects are RESOURCES (data) plus a behavior tick that runs on the holder via
# StatusEffectsHolder. Same tick logic for all effects, configured by these fields.

enum Kind { BURN, POISON, BLEED, SLOW, STUN, BLIND, WEAKNESS, MARK, REGEN, FROST_VULNERABILITY, IGNITE_VULNERABILITY }

@export var id: StringName = &""
@export var display_name: String = ""
@export var kind: Kind = Kind.BURN
@export var icon: Texture2D
@export var tint: Color = Color.WHITE  # for VFX

@export_group("Duration and Damage")
@export var duration: float = 4.0
@export var tick_interval: float = 1.0  # seconds between damage ticks (DoT effects)
@export var damage_per_tick: float = 0.0
@export var damage_type: int = 0  # Ability.DamageType
@export var ignores_armor: bool = false

@export_group("Stat Modifiers")
@export var move_speed_mult: float = 1.0  # eg 0.5 for slow
@export var damage_dealt_mult: float = 1.0  # eg 0.6 for weakness
@export var damage_taken_mult: float = 1.0  # eg 1.3 for vulnerability
@export var crit_chance_bonus: float = 0.0  # eg +0.25 for mark
@export var heal_per_tick: float = 0.0  # for regen

@export_group("Behavior")
@export var locks_actor: bool = false  # stun: prevents inputs/AI
@export var stacks: bool = false  # eg poison stacking up to N stacks
@export var max_stacks: int = 5
@export var refresh_on_reapply: bool = true
