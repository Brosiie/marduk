extends Resource
class_name Transformation

# A shapeshift form. Used by Chaos Druid (and Demon's wing-out, optionally).
# When active, the player's mesh swaps, stats get multipliers, and the ability
# bar is replaced by form-specific abilities. Reverts on duration end or manual cancel.

@export var id: StringName = &"wolf"
@export var display_name: String = "Wolf"
@export_multiline var description: String = ""
@export var icon: Texture2D

@export_group("Visual")
@export var mesh_scene: PackedScene  # the model + AnimationPlayer for this form
@export var scale_multiplier: float = 1.0

@export_group("Stat Multipliers")
@export var hp_mult: float = 1.0
@export var move_speed_mult: float = 1.0
@export var armor_mult: float = 1.0
@export var damage_mult: float = 1.0
@export var crit_chance_bonus: float = 0.0

@export_group("Mechanics")
@export var duration: float = -1.0  # -1 = indefinite (canceled manually), >0 = auto-revert
@export var enter_cost: float = 30.0  # resource cost to shift in (mana, paid from primary pool)
@export var revert_cost: float = 0.0
@export var locks_human_abilities: bool = true
@export var form_abilities: Array[Ability] = []
# In-form stamina drain per second (Druid). 0 = no passive drain; abilities still cost from stamina pool.
@export var stamina_drain_per_sec: float = 0.0
@export var stamina_max_in_form: float = 100.0  # the form's stamina ceiling; can be > player's max

@export_group("Tags")
@export var tags: Array[StringName] = []  # eg [&"beast", &"dragon", &"flying"]
