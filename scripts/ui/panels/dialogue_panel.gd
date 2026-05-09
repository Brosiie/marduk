extends CanvasLayer
class_name DialoguePanel

# Renders Dialogue/Choice trees from DialogueRegistry. Replaces the
# single-greeting + Accept-Quest popup that NPC._open_dialogue used
# previously. Now branches, gating, and faction-rep consequences all
# work end-to-end.
#
# Visual:
#   ┌────────── slate panel, gold filigree, top center ────────────┐
#   │  NPC Name                                                     │
#   │  ────────                                                     │
#   │  "Sit. The kettle is on. Your shoulders are tighter than..."  │
#   │                                                                │
#   │  > Who are you?                                                │
#   │  > Why do you know my face?                                    │
#   │  > Tell me about Tiamat.                                       │
#   │  > Goodbye.                                                    │
#   └────────────────────────────────────────────────────────────────┘
#
# Choices that touch faction rep render with a colored tag:
#   > Tell the Crown captain where the rebels camp.   [Crown +250 / Druids -150]
#
# The tag color comes from FactionRegistry.tier_color_for(threshold) so
# the player reads the FACTION at a glance, not just "+250".
#
# Esc closes the dialogue. Clicking a choice fires its sets_run_flag /
# sets_permanent_flag / starts_quest_id / faction_rep_changes effects,
# then advances to next_id (or closes if ends_dialogue=true).

signal closed()
signal choice_picked(choice_label: String)

var dialogue: Dialogue = null
var current_line: Dialogue.Line = null
var npc_display_name: String = ""

@onready var panel: PanelContainer = $Panel if has_node("Panel") else null

func _ready() -> void:
	visible = false
	process_mode = Node.PROCESS_MODE_ALWAYS

func open(p_dialogue: Dialogue, p_npc_name: String = "") -> void:
	dialogue = p_dialogue
	npc_display_name = p_npc_name
	visible = true
	current_line = dialogue.get_entry() if dialogue else null
	if current_line:
		_apply_line_effects(current_line)
	_build()

func close() -> void:
	visible = false
	closed.emit()

func _input(event: InputEvent) -> void:
	if visible and event.is_action_pressed("ui_cancel"):
		close()

func _build() -> void:
	# Lazy panel creation: scenes that instantiate DialoguePanel without
	# an attached .tscn (CanvasLayer-as-script) won't have a $Panel node.
	# Build one in code to keep this drop-in usable from any spawn site.
	if panel == null:
		panel = PanelContainer.new()
		panel.name = "Panel"
		panel.anchor_left = 0.5
		panel.anchor_right = 0.5
		panel.anchor_top = 0.65
		panel.anchor_bottom = 0.65
		panel.offset_left = -440.0
		panel.offset_right = 440.0
		panel.offset_top = -180.0
		panel.offset_bottom = 200.0
		var sb := StyleBoxFlat.new()
		sb.bg_color = Color(0.05, 0.04, 0.06, 0.96)
		sb.border_color = Color(0.78, 0.62, 0.28, 1.0)
		sb.set_border_width_all(2)
		sb.border_width_top = 3
		sb.set_corner_radius_all(6)
		sb.shadow_color = Color(0, 0, 0, 0.7)
		sb.shadow_size = 10
		sb.shadow_offset = Vector2(0, 5)
		sb.content_margin_left = 22
		sb.content_margin_right = 22
		sb.content_margin_top = 16
		sb.content_margin_bottom = 16
		panel.add_theme_stylebox_override("panel", sb)
		add_child(panel)

	for c in panel.get_children():
		c.queue_free()
	if current_line == null:
		return

	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 10)
	panel.add_child(v)

	# Speaker name (line.speaker overrides npc_display_name when set,
	# so a Storyteller can be quoted with a different attribution mid-tree)
	var speaker: String = current_line.speaker if current_line.speaker != "" else npc_display_name
	if speaker != "":
		var name_lbl := Label.new()
		name_lbl.text = speaker
		name_lbl.add_theme_font_size_override("font_size", 22)
		name_lbl.add_theme_color_override("font_color", Color(1.0, 0.92, 0.55))
		name_lbl.add_theme_color_override("font_outline_color", Color(0.20, 0.05, 0.05, 1.0))
		name_lbl.add_theme_constant_override("outline_size", 4)
		v.add_child(name_lbl)
		var sep := ColorRect.new()
		sep.color = Color(0.78, 0.62, 0.28, 0.55)
		sep.custom_minimum_size = Vector2(0, 1)
		v.add_child(sep)

	# Line text
	var line_lbl := Label.new()
	line_lbl.text = current_line.text
	line_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	line_lbl.custom_minimum_size = Vector2(840, 0)
	line_lbl.add_theme_font_size_override("font_size", 14)
	line_lbl.add_theme_color_override("font_color", Color(0.95, 0.92, 0.85))
	line_lbl.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.85))
	line_lbl.add_theme_constant_override("outline_size", 2)
	v.add_child(line_lbl)

	# Spacer
	var spacer := Control.new()
	spacer.custom_minimum_size = Vector2(0, 8)
	v.add_child(spacer)

	# Choices, filtered by gating predicates (level / class / flag / item)
	var visible_choices: Array = []
	for c in current_line.choices:
		if _choice_visible(c):
			visible_choices.append(c)
	if visible_choices.is_empty():
		# No choices = auto-advance via next_id, or close if absent
		if current_line.next_id != &"":
			get_tree().create_timer(0.05).timeout.connect(func(): _go_to(current_line.next_id))
		else:
			# Add a default "[End]" button so the panel doesn't soft-lock
			var end_btn := _make_choice_button("[End]", null)
			end_btn.pressed.connect(close)
			v.add_child(end_btn)
		return
	for c in visible_choices:
		v.add_child(_make_choice_button(c.label, c))

func _choice_visible(c: Dialogue.Choice) -> bool:
	# Gate: class restriction
	if c.require_class.size() > 0:
		var player: Node = get_tree().get_first_node_in_group("player")
		var class_id: StringName = &""
		if player and "stats" in player and player.stats and "class_def" in player.stats and player.stats.class_def:
			class_id = StringName(player.stats.class_def.class_id)
		if not (class_id in c.require_class):
			return false
	# Gate: minimum level
	if c.require_min_level > 0:
		var player2: Node = get_tree().get_first_node_in_group("player")
		var lvl: int = 1
		if player2 and "stats" in player2 and player2.stats and "level" in player2.stats:
			lvl = int(player2.stats.level)
		if lvl < c.require_min_level:
			return false
	# Gate: required run flag
	if c.require_run_flag != &"":
		var sf: Node = get_node_or_null("/root/SaveFlags")
		if sf == null or not sf.has_method("has_run") or not sf.has_run(c.require_run_flag):
			return false
	# Gate: required permanent flag
	if c.require_permanent_flag != &"":
		var sf2: Node = get_node_or_null("/root/SaveFlags")
		if sf2 == null or not sf2.has_method("has_permanent") or not sf2.has_permanent(c.require_permanent_flag):
			return false
	# Gate: required quest completed
	if c.require_quest_completed != &"":
		var qr: Node = get_node_or_null("/root/QuestRegistry")
		if qr == null or not qr.has_method("is_completed") or not qr.is_completed(c.require_quest_completed):
			return false
	return true

func _make_choice_button(label: String, c) -> Button:
	var b := Button.new()
	b.text = "  >  " + label
	b.alignment = HORIZONTAL_ALIGNMENT_LEFT
	b.add_theme_font_size_override("font_size", 14)
	b.add_theme_color_override("font_color", Color(0.85, 0.92, 1.0))
	b.add_theme_color_override("font_hover_color", Color(1.0, 0.95, 0.65))
	b.custom_minimum_size = Vector2(0, 32)
	# Render the rep-consequence tag inline in the button label so
	# the player sees the cost up front. Format: "[Crown +250 / Druids -150]"
	if c != null and not c.faction_rep_changes.is_empty():
		var tag: String = _format_rep_tag(c.faction_rep_changes)
		if tag != "":
			b.text = b.text + "    " + tag
	# Style: subtle dark bg with gold left border that brightens on hover
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.10, 0.08, 0.06, 0.85)
	sb.border_color = Color(0.55, 0.45, 0.20, 0.85)
	sb.border_width_left = 3
	sb.set_corner_radius_all(2)
	sb.content_margin_left = 12
	sb.content_margin_right = 12
	sb.content_margin_top = 6
	sb.content_margin_bottom = 6
	b.add_theme_stylebox_override("normal", sb)
	var sb_hover: StyleBoxFlat = sb.duplicate()
	sb_hover.bg_color = Color(0.16, 0.10, 0.06, 0.92)
	sb_hover.border_color = Color(1.0, 0.85, 0.30, 1.0)
	b.add_theme_stylebox_override("hover", sb_hover)
	b.pressed.connect(_on_choice_pressed.bind(c))
	return b

func _format_rep_tag(rep_changes: Dictionary) -> String:
	var fr: Node = get_node_or_null("/root/FactionRegistry")
	if fr == null:
		return ""
	var bits: Array[String] = []
	for fid in rep_changes.keys():
		var delta: int = int(rep_changes[fid])
		if delta == 0:
			continue
		var f = fr.get_faction(fid) if fr.has_method("get_faction") else null
		var fname: String = f.display_name if f else String(fid)
		# Strip "The " prefix so tags read tighter ("Crown" not "The Iron Crown")
		fname = fname.replace("The ", "")
		var sign_char: String = "+" if delta > 0 else ""
		bits.append("%s %s%d" % [fname, sign_char, delta])
	if bits.is_empty():
		return ""
	# All-positive = green tag, all-negative = red, mixed = gold
	var pos: bool = false; var neg: bool = false
	for d in rep_changes.values():
		if int(d) > 0: pos = true
		if int(d) < 0: neg = true
	var color_hex: String = "9b8654"  # gold default
	if pos and not neg: color_hex = "60c060"
	elif neg and not pos: color_hex = "d05050"
	return "[color=#%s][%s][/color]" % [color_hex, " / ".join(bits)]

func _on_choice_pressed(c) -> void:
	choice_picked.emit(c.label if c else "")
	if c == null:
		close()
		return
	# Apply choice effects
	if c.sets_run_flag != &"":
		var sf: Node = get_node_or_null("/root/SaveFlags")
		if sf and sf.has_method("set_run"):
			sf.set_run(c.sets_run_flag, true)
	if c.sets_permanent_flag != &"":
		var sf2: Node = get_node_or_null("/root/SaveFlags")
		if sf2 and sf2.has_method("set_permanent"):
			sf2.set_permanent(c.sets_permanent_flag, true)
	if c.starts_quest_id != &"":
		var qr: Node = get_node_or_null("/root/QuestRegistry")
		if qr and qr.has_method("accept_quest"):
			qr.accept_quest(c.starts_quest_id)
	# Faction rep deltas: route through FactionRegistry so the standard
	# clamp + rep_changed signal + tier-change toast flow all fire.
	if not c.faction_rep_changes.is_empty():
		var fr: Node = get_node_or_null("/root/FactionRegistry")
		if fr and fr.has_method("add_rep"):
			for fid in c.faction_rep_changes.keys():
				fr.add_rep(StringName(fid), int(c.faction_rep_changes[fid]))
	if c.ends_dialogue:
		close()
		return
	if c.next_id != &"":
		_go_to(c.next_id)
	else:
		close()

func _go_to(line_id: StringName) -> void:
	if dialogue == null:
		close()
		return
	var nl: Dialogue.Line = dialogue.get_line(line_id)
	if nl == null:
		close()
		return
	current_line = nl
	_apply_line_effects(nl)
	_build()

func _apply_line_effects(line: Dialogue.Line) -> void:
	# Some lines fire side effects on display (set a flag, start a quest)
	# without requiring the player to pick a choice. Let those run as the
	# panel re-renders this line.
	if line.on_show_set_flag != &"":
		var sf: Node = get_node_or_null("/root/SaveFlags")
		if sf and sf.has_method("set_run"):
			sf.set_run(line.on_show_set_flag, true)
	if line.on_show_starts_quest != &"":
		var qr: Node = get_node_or_null("/root/QuestRegistry")
		if qr and qr.has_method("accept_quest"):
			qr.accept_quest(line.on_show_starts_quest)
