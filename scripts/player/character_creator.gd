extends Control
class_name CharacterCreator

# The Storyteller-narrated character creation flow. Loads all CreatorQuestion
# resources from resources/creator/questions/, sorts them by question_order,
# walks them one at a time, applies the chosen effects to a CharacterAppearance,
# and on completion emits creator_finished(appearance).
#
# Branching: a CreatorChoice can specify next_question_id to jump out of order.
# Conditional: a CreatorQuestion with requires_tags is skipped unless those
# biographical tags are already on the appearance.
#
# UI is intentionally minimal — see scenes/menus/character_creator.tscn.
# All visual flair (Storyteller portrait, ambient music, character preview)
# is overlaid by the parent scene; this controller owns flow + state.

signal creator_finished(appearance: CharacterAppearance)
signal creator_cancelled()

const QUESTIONS_DIR := "res://resources/creator/questions/"

@export var prompt_label_path: NodePath
@export var subtext_label_path: NodePath
@export var category_label_path: NodePath
@export var choices_container_path: NodePath
@export var storyteller_response_path: NodePath  # optional, fades in after choice

@onready var prompt_label: Label = get_node_or_null(prompt_label_path) as Label
@onready var subtext_label: Label = get_node_or_null(subtext_label_path) as Label
@onready var category_label: Label = get_node_or_null(category_label_path) as Label
@onready var choices_container: VBoxContainer = get_node_or_null(choices_container_path) as VBoxContainer
@onready var storyteller_response_label: Label = get_node_or_null(storyteller_response_path) as Label

var questions: Array[CreatorQuestion] = []
var _current_index: int = 0
var _appearance: CharacterAppearance = null
var _biographical_tags: Array[StringName] = []
# Side channel for text-input answers (character name, etc) that don't fit on
# CharacterAppearance directly. The spawn flow reads these and applies them
# to the Player instance.
var _pending_text_inputs: Dictionary = {}

func _ready() -> void:
	_load_all_questions()
	_appearance = CharacterAppearance.new()
	# Seed sensible defaults so a player who skips optional questions still gets a valid character.
	_appearance.race_id = &"reed_walker"
	_appearance.gender = &"male"
	_appearance.class_id = &"ronin"
	_advance_to(0)

func _load_all_questions() -> void:
	questions.clear()
	var dir := DirAccess.open(QUESTIONS_DIR)
	if dir == null:
		push_warning("[CharacterCreator] questions dir missing: %s" % QUESTIONS_DIR)
		return
	dir.list_dir_begin()
	var fname: String = dir.get_next()
	while fname != "":
		if fname.ends_with(".tres"):
			var q: CreatorQuestion = load(QUESTIONS_DIR + fname)
			if q:
				questions.append(q)
		fname = dir.get_next()
	dir.list_dir_end()
	# Sort by question_order, fallback to question_id for stability
	questions.sort_custom(func(a, b):
		if a.question_order != b.question_order:
			return a.question_order < b.question_order
		return String(a.question_id) < String(b.question_id))
	print("[CharacterCreator] loaded %d questions" % questions.size())

func _advance_to(index: int) -> void:
	# Skip questions whose requires_tags aren't met by the current appearance.
	while index < questions.size():
		var q: CreatorQuestion = questions[index]
		if q.requires_tags.is_empty() or _has_all_tags(q.requires_tags):
			break
		index += 1

	if index >= questions.size():
		_finish()
		return

	_current_index = index
	_render(questions[index])

func _has_all_tags(required: Array) -> bool:
	for t in required:
		if not (t in _biographical_tags):
			return false
	return true

func _render(q: CreatorQuestion) -> void:
	if prompt_label:
		prompt_label.text = q.prompt
	if subtext_label:
		subtext_label.text = q.subtext
		subtext_label.visible = q.subtext != ""
	if category_label:
		category_label.text = "now choosing: %s" % q.category
	# Clear previous choices
	if choices_container:
		for c in choices_container.get_children():
			c.queue_free()
		if q.text_input_mode:
			_render_text_input(q)
		else:
			_render_choice_buttons(q)
	if storyteller_response_label:
		storyteller_response_label.text = ""
		storyteller_response_label.visible = false

func _render_choice_buttons(q: CreatorQuestion) -> void:
	# Race-affinity filter: a choice with race_filter set is hidden when it
	# doesn't match the in-progress appearance's race. Lets one question carry
	# race-specific options that filter to the relevant 4-5 at runtime.
	for choice in q.choices:
		if choice.race_filter != &"" and choice.race_filter != _appearance.race_id:
			continue
		var btn := Button.new()
		btn.text = choice.text
		btn.custom_minimum_size = Vector2(0, 44)
		btn.pressed.connect(_on_choice_picked.bind(choice))
		choices_container.add_child(btn)

func _render_text_input(q: CreatorQuestion) -> void:
	# LineEdit + confirm button for name-style questions.
	var input := LineEdit.new()
	input.placeholder_text = q.text_input_placeholder
	input.max_length = q.text_input_max_length
	input.custom_minimum_size = Vector2(0, 44)
	input.add_theme_font_size_override("font_size", 18)
	choices_container.add_child(input)
	var confirm := Button.new()
	confirm.text = "Confirm"
	confirm.custom_minimum_size = Vector2(0, 44)
	confirm.pressed.connect(func():
		var v: String = input.text.strip_edges()
		if v == "":
			v = "Champion"  # default if blank
		_apply_text_input(q, v)
		_advance_to(_current_index + 1)
	)
	choices_container.add_child(confirm)
	# Auto-focus so the player can just type
	input.grab_focus()
	# Allow Enter to confirm
	input.text_submitted.connect(func(_t):
		confirm.emit_signal("pressed")
	)

func _apply_text_input(q: CreatorQuestion, value: String) -> void:
	# Currently only character_name is supported. Extend by adding fields here.
	match q.text_input_target:
		&"character_name":
			# CharacterAppearance doesn't carry a name field by default — the name
			# lives on Player. Stash it on a side dict so the spawn flow picks it up.
			_pending_text_inputs[&"character_name"] = value
		_:
			push_warning("[CharacterCreator] unknown text_input_target: %s" % q.text_input_target)

func _on_choice_picked(choice: CreatorChoice) -> void:
	_apply_choice(choice)
	_show_response_then_advance(choice)

func _apply_choice(choice: CreatorChoice) -> void:
	if choice.sets_race != &"":
		_appearance.race_id = choice.sets_race
	if choice.sets_class_id != &"":
		_appearance.class_id = choice.sets_class_id
	if choice.sets_gender != &"":
		_appearance.gender = choice.sets_gender
	if choice.sets_body_type >= 0:        _appearance.body_type = choice.sets_body_type
	if choice.sets_face_preset >= 0:      _appearance.face_preset = choice.sets_face_preset
	if choice.sets_voice_pack >= 0:       _appearance.voice_pack = choice.sets_voice_pack
	if choice.sets_skin_tone >= 0:        _appearance.skin_tone = choice.sets_skin_tone
	if choice.sets_hair_style >= 0:       _appearance.hair_style = choice.sets_hair_style
	if choice.sets_hair_color >= 0:       _appearance.hair_color = choice.sets_hair_color
	if choice.sets_eye_color >= 0:        _appearance.eye_color = choice.sets_eye_color
	if choice.sets_beard_style >= 0:      _appearance.beard_style = choice.sets_beard_style
	if choice.sets_scar_overlay >= 0:     _appearance.scar_overlay = choice.sets_scar_overlay
	if choice.sets_warpaint_overlay >= 0: _appearance.warpaint_overlay = choice.sets_warpaint_overlay
	if choice.sets_cultural_marking >= 0: _appearance.cultural_marking = choice.sets_cultural_marking
	if choice.sets_jewelry_set >= 0:      _appearance.jewelry_set = choice.sets_jewelry_set
	if choice.sets_glow_eyes >= 0:        _appearance.glow_eyes = (choice.sets_glow_eyes == 1)
	# Stat lean is additive — multiple soft-shaping questions can stack.
	# Stored on the appearance as biographical_tags for now; a Phase 2 pass
	# can apply them to PlayerStats at character spawn.
	for tag in choice.biographical_tags:
		if not (tag in _biographical_tags):
			_biographical_tags.append(tag)

func _show_response_then_advance(choice: CreatorChoice) -> void:
	if storyteller_response_label and choice.storyteller_response != "":
		storyteller_response_label.text = choice.storyteller_response
		storyteller_response_label.visible = true
		# Brief pause so the player reads the line, then advance.
		await get_tree().create_timer(1.6).timeout
	# Apply branching jump if specified
	if choice.next_question_id != &"":
		var idx: int = _index_of_question(choice.next_question_id)
		if idx >= 0:
			_advance_to(idx)
			return
	_advance_to(_current_index + 1)

func _index_of_question(id: StringName) -> int:
	for i in range(questions.size()):
		if questions[i].question_id == id:
			return i
	return -1

func _finish() -> void:
	# Validation pass — surface obvious errors (gender mismatch with beard, etc).
	var errs: Array = _appearance.validate()
	if not errs.is_empty():
		push_warning("[CharacterCreator] appearance validation: %s" % errs)
	# Stash the appearance + name on AppearanceRegistry so the spawned Player
	# can pick them up across the scene change.
	var ar: Node = get_node_or_null("/root/AppearanceRegistry")
	if ar:
		if "pending_appearance" in ar:
			ar.pending_appearance = _appearance
		if "pending_name" in ar:
			ar.pending_name = String(_pending_text_inputs.get(&"character_name", "Champion"))
	creator_finished.emit(_appearance)
	_route_to_intro_zone()

# Route to the class-appropriate intro zone. Falls back to Sword-Vow Ruins for
# classes whose intro hasn't been authored yet (Phase 2 work).
const INTRO_ZONES := {
	&"ronin":                "res://scenes/world/intros/sword_vow_ruins.tscn",
	&"paladin_guardian":     "res://scenes/world/intros/sunsworn_chapel.tscn",
	&"paladin_lightbringer": "res://scenes/world/intros/sunsworn_chapel.tscn",
	&"berserker":            "res://scenes/world/intros/ash_step_camp.tscn",
	&"assassin":             "res://scenes/world/intros/whisper_shrine.tscn",
	&"ranger":               "res://scenes/world/intros/greenheart_glade.tscn",
}

const FALLBACK_INTRO := "res://scenes/world/intros/sword_vow_ruins.tscn"

func _route_to_intro_zone() -> void:
	var class_id: StringName = _appearance.class_id if _appearance else &"ronin"
	var path: String = INTRO_ZONES.get(class_id, FALLBACK_INTRO)
	get_tree().change_scene_to_file(path)

# === Public API for cancellation / restart ===
func cancel() -> void:
	creator_cancelled.emit()

func current_appearance() -> CharacterAppearance:
	return _appearance

func biographical_tags() -> Array[StringName]:
	return _biographical_tags
