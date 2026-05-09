extends Resource
class_name CreatorQuestion

# A single question the Storyteller asks during character creation.
# Questions are authored as .tres files in resources/creator/questions/
# and loaded by CharacterCreator in the order specified by their
# question_order field (or alphabetically by id if order is left at 0).
#
# Each question carries a list of CreatorChoice options. The player picks
# one; the choice's effects mutate the in-progress CharacterAppearance.

@export var question_id: StringName = &""
@export var question_order: int = 0                  # lower = asked first; 0 = author order
@export_multiline var prompt: String = ""            # the Storyteller's question text
@export_multiline var subtext: String = ""           # optional smaller line beneath the prompt
@export var choices: Array[CreatorChoice] = []
@export var required: bool = true                    # if false, player can skip

# Display: which dimension this question primarily affects. Lets the UI
# show a small "now choosing: race" / "now choosing: class" indicator.
@export_enum("identity", "race", "class", "gender", "body", "face", "lifepath", "name") var category: String = "lifepath"

# Conditional: only ask this question if a previous choice tagged the appearance
# with one of the listed biographical_tags (e.g. only ask the breath-style
# question if the class is Ronin).
@export var requires_tags: Array[StringName] = []

# Free-text input mode. When true, the controller renders a LineEdit + confirm
# button instead of choice buttons. The typed string is written to the in-progress
# appearance via the field named in `text_input_target` (currently &"character_name").
# Used for q06_name and any future text questions (clan name, weapon nickname, etc).
@export var text_input_mode: bool = false
@export var text_input_target: StringName = &"character_name"
@export var text_input_placeholder: String = ""
@export var text_input_max_length: int = 24
