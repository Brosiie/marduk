extends Ability
class_name MageSpell

# A Mage spell. Extends Ability with school + tier + spell-specific behaviors.
# Spells cost 5-100 mana per cast. Higher-tier spells cost more, deal more,
# have longer cast times. Schools have distinct identities (DoT, burst, control, etc).

@export var school_id: StringName = &""    # eg &"fire", &"frost"
@export var tier: int = 1                  # within school, 1-7
@export var prereq_spell_id: StringName = &""  # eg &"fire_2" requires &"fire_1"
@export var animation_name: StringName = &""
@export var vfx_color: Color = Color.WHITE

func _init() -> void:
	cost_resource = &"mana"
