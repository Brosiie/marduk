extends Resource
class_name CreatorChoice

# A single answer to a CreatorQuestion. Carries the effects that get applied
# to the in-progress CharacterAppearance when the player picks this option.
#
# Effects use -1 / &"" as "leave unchanged" sentinels so a choice can affect
# only the dimensions it cares about. Stat lean is additive (multiple choices
# can stack a +1 strength toward the same race's profile).

@export var choice_id: StringName = &""
@export_multiline var text: String = ""             # button label / what the player picks
@export_multiline var storyteller_response: String = ""  # what the Storyteller says back

# === Identity assignments ===
@export var sets_race: StringName = &""             # &"anunnaki" / &"ash_born" / etc
@export var sets_class_id: StringName = &""         # &"ronin" / &"berserker" / etc
@export var sets_gender: StringName = &""           # &"male" / &"female"

# === Appearance assignments (-1 = no change) ===
@export var sets_body_type: int = -1                # 0..2
@export var sets_face_preset: int = -1              # 0..4
@export var sets_voice_pack: int = -1               # 0..3
@export var sets_skin_tone: int = -1                # 0..4
@export var sets_hair_style: int = -1               # 0..7
@export var sets_hair_color: int = -1               # 0..5
@export var sets_eye_color: int = -1                # 0..4
@export var sets_beard_style: int = -1              # 0..4 (male only)

# === Overlays (-1 = no change) ===
@export var sets_scar_overlay: int = -1
@export var sets_warpaint_overlay: int = -1
@export var sets_cultural_marking: int = -1
@export var sets_jewelry_set: int = -1
@export var sets_glow_eyes: int = -1                # 0 = off, 1 = on, -1 = no change

# === Stat lean push (additive on top of race lean) ===
# Use this for "soft" character-shaping questions: "Which weapon did you
# train with as a child?", the answer pushes 1 stat point regardless of class.
@export var pushes_stat_lean: Dictionary = {}      # StringName -> int

# === Branching ===
# If non-empty, override the next question_id to jump to. Lets a class choice
# unlock a class-specific follow-up question. Empty = continue linear flow.
@export var next_question_id: StringName = &""

# === Lore tags (for Codex / Sage / dialogue) ===
# Tags get stored on the appearance as biographical hints. Lets NPCs later say
# "I see your father worked the forge" if the player picked the smith answer.
@export var biographical_tags: Array[StringName] = []

# === Race-affinity filter ===
# Optional. If set, this choice only appears when the in-progress appearance's
# race_id matches. Lets a single CreatorQuestion carry race-specific options
# (eg cultural markings) that filter at runtime to the relevant 4-5 instead of
# bombarding the player with all 25.
@export var race_filter: StringName = &""
