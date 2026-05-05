extends Ability
class_name BreathingForm

# A single Ronin breathing form. Extends Ability with lineage data.
# Forms within a style chain linearly: Form N requires Form N-1.
# Form 7 of each style is the capstone; long windup, devastating payoff.
# Ronin uses stamina, so all breathing forms cost from the stamina pool.

func _init() -> void:
	cost_resource = &"stamina"

@export_group("Breathing")
@export var style_id: StringName = &""
@export var form_number: int = 1
@export var animation_name: StringName = &""  # eg &"breath_water_1" on the player AnimationPlayer
@export var vfx_color: Color = Color.WHITE
@export var trail_intensity: float = 1.0
@export var sound_id: StringName = &""

@export_group("Mastery")
@export var stance_charge_cost: int = 0  # how many stance charges this form spends
@export var stance_charge_gain_on_hit: int = 0  # parry-clean hits refund/build charges
@export var min_player_level: int = 1
@export var prereq_form_id: StringName = &""  # eg &"water_3" for Form 4 to require Form 3

@export_group("Skill Ceiling Knobs")
@export var perfect_window_seconds: float = 0.0  # >0 means there is a "just frame" damage bonus
@export var perfect_bonus_mult: float = 1.5
@export var miss_punishment_seconds: float = 0.0  # how long player is locked if the swing whiffs

# Form chain bonus: if the previous form cast within `chain_window` was `chain_predecessor`,
# this form deals `chain_bonus_mult` extra damage. Encourages learning combo paths.
@export var chain_predecessor: StringName = &""
@export var chain_window: float = 2.5
@export var chain_bonus_mult: float = 1.4
