extends Resource
class_name BreathingStyle

# A breathing discipline. Houses 7 forms, color/element identity, and unlock gating.

@export var id: StringName = &""
@export var display_name: String = ""
@export_multiline var lore: String = ""
@export var element: StringName = &"physical"  # physical, fire, water, lightning, earth, wind, light, shadow
@export var primary_color: Color = Color.WHITE
@export var icon: Texture2D

@export_group("Forms")
@export var forms: Array[BreathingForm] = []

@export_group("Style Unlock")
# Most styles available from level 1 (just costs 1 skill point to learn Form 1).
# Sun Breathing is gated: requires defeating Tiamat AND mastering 2+ other styles.
@export var unlock_save_flag: StringName = &""
@export var requires_mastered_styles: int = 0  # eg 2 for Sun Breathing
@export var min_player_level_for_first_form: int = 1
@export_multiline var unlock_hint: String = ""

func get_form(num: int) -> BreathingForm:
	for f in forms:
		if f.form_number == num:
			return f
	return null
