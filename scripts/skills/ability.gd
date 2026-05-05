extends Resource
class_name Ability

# An ability is what fires when player presses an ability slot key.
# Heavy data, light logic: behavior comes from the Ability subclass or a script_path.

enum DamageType { PHYSICAL, ARCANE, FIRE, FROST, LIGHTNING, HOLY, SHADOW }
enum TargetMode { SELF, FORWARD_CONE, AOE_AROUND_SELF, PROJECTILE, GROUND_TARGETED }

@export var id: StringName = &"basic_attack"
@export var display_name: String = "Strike"
@export_multiline var description: String = ""
@export var icon: Texture2D

@export_group("Cost and Cadence")
@export var mana_cost: float = 0.0
# Which resource pool the cost is drawn from. Lets one Ability resource be honest about
# what it actually deducts. Druid spell -> &"mana"; Druid form ability -> &"stamina";
# Demon ability -> &"" (free, demons have no cost). Defaults to &"mana" for safety.
@export var cost_resource: StringName = &"mana"
@export var cooldown: float = 0.4
@export var cast_time: float = 0.0  # 0 = instant, >0 = windup with locked movement

@export_group("Targeting")
@export var target_mode: TargetMode = TargetMode.FORWARD_CONE
@export var range: float = 2.5
@export var radius: float = 1.5  # for AOE/cone width
@export var projectile_scene: PackedScene  # only used when target_mode = PROJECTILE

@export_group("Damage")
@export var damage_type: DamageType = DamageType.PHYSICAL
@export var base_damage: float = 18.0
@export var attribute_scaling: float = 0.6  # how strongly primary attr feeds damage
@export var armor_pen: float = 0.0
@export var crit_bonus_chance: float = 0.0
