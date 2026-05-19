extends CanvasLayer
class_name ControlsHelpPanel

# Cheat-sheet overlay listing every keybind grouped by category. Toggles
# on F1 (or on first scene load if the player hasn't seen it before, via
# SaveFlags.controls_help_seen). Walks Godot's InputMap to read the
# ACTUAL bound keys instead of hardcoded labels, so if Bond rebinds
# (when key-rebind UI lands) the cheat sheet stays accurate.
#
# Layout:
#   ┌──────── Controls ─────────┐
#   │ MOVEMENT   COMBAT  ABILITIES │
#   │  W ↑       LMB Atk    Q kit-1 │
#   │  ...                          │
#   └──────────────────────────────┘
#
# Visual: slate panel with three columns. Same gold-filigree language
# as the rest of the HUD so it doesn't read as out-of-place.

signal closed()

# Action -> friendly label for each category. Pull the actual bound
# key from InputMap at render time so this stays accurate if bindings
# change. Categories ordered by the order players touch them in the
# first 30 seconds: move, then attack, then look around, then UI.
const _CATEGORIES := [
	{
		"title": "MOVEMENT",
		"actions": [
			{"action": "move_up",    "label": "Forward"},
			{"action": "move_down",  "label": "Backward"},
			{"action": "move_left",  "label": "Strafe Left"},
			{"action": "move_right", "label": "Strafe Right"},
			{"action": "jump",       "label": "Jump"},
			{"action": "dodge",      "label": "Dodge"},
		],
	},
	{
		"title": "COMBAT",
		"actions": [
			{"action": "attack_basic", "label": "Basic Attack"},
			{"action": "block",        "label": "Block / Parry"},
			{"action": "lock_on",      "label": "Lock-on Toggle  (Shift+Tab cycle next, Ctrl+Tab cycle back)"},
			{"action": "ability_1",    "label": "Ability 1"},
			{"action": "ability_2",    "label": "Ability 2"},
			{"action": "ability_3",    "label": "Ability 3"},
			{"action": "ability_4",    "label": "Ability 4"},
		],
	},
	{
		"title": "INTERACT  ·  CAMERA",
		"actions": [
			{"action": "interact",         "label": "Interact / Pickup / Talk"},
			{"action": "toggle_mount",     "label": "Mount / Dismount"},
			{"action": "toggle_pet",       "label": "Summon / Recall Pet"},
			{"action": "cam_rotate_left",  "label": "Camera Rotate Left"},
			{"action": "cam_rotate_right", "label": "Camera Rotate Right"},
			{"action": "zoom_in",          "label": "Zoom In"},
			{"action": "zoom_out",         "label": "Zoom Out"},
		],
	},
	{
		"title": "MENUS",
		"actions": [
			{"action": "toggle_inventory",    "label": "Inventory"},
			{"action": "toggle_character",    "label": "Character Sheet"},
			{"action": "toggle_skills",       "label": "Skill Tree"},
			{"action": "toggle_map",          "label": "World Map"},
			{"action": "toggle_quests",       "label": "Quest Log"},
			{"action": "toggle_achievements", "label": "Achievements"},
			{"action": "toggle_codex",        "label": "Codex"},
			{"action": "toggle_pause",        "label": "Pause Menu"},
			{"action": "ui_cancel",           "label": "Close Panel / Esc"},
		],
	},
]

func _ready() -> void:
	visible = false
	process_mode = Node.PROCESS_MODE_ALWAYS

func _input(event: InputEvent) -> void:
	# F1 toggles. Esc closes if open.
	if event is InputEventKey:
		var ke: InputEventKey = event
		if ke.pressed and not ke.echo and ke.keycode == KEY_F1:
			toggle()
			get_viewport().set_input_as_handled()
		elif visible and ke.pressed and ke.keycode == KEY_ESCAPE:
			close()
			get_viewport().set_input_as_handled()

func toggle() -> void:
	if visible:
		close()
	else:
		open()

func open() -> void:
	visible = true
	for c in get_children():
		c.queue_free()
	_build()

func close() -> void:
	visible = false
	for c in get_children():
		c.queue_free()
	closed.emit()

func _build() -> void:
	# Background dim
	var dim := ColorRect.new()
	dim.color = Color(0, 0, 0, 0.55)
	dim.anchor_right = 1.0
	dim.anchor_bottom = 1.0
	dim.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(dim)

	var panel := PanelContainer.new()
	panel.anchor_left = 0.5
	panel.anchor_right = 0.5
	panel.anchor_top = 0.5
	panel.anchor_bottom = 0.5
	panel.offset_left = -460.0
	panel.offset_right = 460.0
	panel.offset_top = -260.0
	panel.offset_bottom = 260.0
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.05, 0.04, 0.06, 0.97)
	sb.border_color = Color(0.78, 0.62, 0.28, 1.0)
	sb.set_border_width_all(2)
	sb.border_width_top = 3
	sb.set_corner_radius_all(6)
	sb.shadow_color = Color(0, 0, 0, 0.7)
	sb.shadow_size = 12
	sb.shadow_offset = Vector2(0, 6)
	sb.content_margin_left = 24
	sb.content_margin_right = 24
	sb.content_margin_top = 18
	sb.content_margin_bottom = 18
	panel.add_theme_stylebox_override("panel", sb)
	add_child(panel)

	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 12)
	panel.add_child(v)

	# Header
	var header := HBoxContainer.new()
	v.add_child(header)
	var title := Label.new()
	title.text = "CONTROLS"
	title.add_theme_font_size_override("font_size", 24)
	title.add_theme_color_override("font_color", Color(1.0, 0.92, 0.55))
	title.add_theme_color_override("font_outline_color", Color(0.20, 0.05, 0.05, 1.0))
	title.add_theme_constant_override("outline_size", 4)
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header.add_child(title)
	var close_lbl := Label.new()
	close_lbl.text = "F1 or Esc to close"
	close_lbl.add_theme_font_size_override("font_size", 11)
	close_lbl.add_theme_color_override("font_color", Color(0.65, 0.55, 0.40))
	header.add_child(close_lbl)
	# Gold separator
	var sep := ColorRect.new()
	sep.color = Color(0.78, 0.62, 0.28, 0.55)
	sep.custom_minimum_size = Vector2(0, 1)
	v.add_child(sep)

	# Four-column grid: each category gets a column with header + rows.
	var cols := HBoxContainer.new()
	cols.add_theme_constant_override("separation", 22)
	v.add_child(cols)
	for cat in _CATEGORIES:
		cols.add_child(_make_category_column(cat))

	# Footer hint
	var footer := Label.new()
	footer.text = "Bindings shown reflect your current keybind config (read live from InputMap)."
	footer.add_theme_font_size_override("font_size", 11)
	footer.add_theme_color_override("font_color", Color(0.55, 0.50, 0.40))
	footer.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(footer)

func _make_category_column(cat: Dictionary) -> Control:
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 4)
	col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	# Category header
	var header := Label.new()
	header.text = String(cat["title"])
	header.add_theme_font_size_override("font_size", 14)
	header.add_theme_color_override("font_color", Color(0.95, 0.85, 0.55))
	col.add_child(header)
	var sep := ColorRect.new()
	sep.color = Color(0.55, 0.40, 0.20, 0.55)
	sep.custom_minimum_size = Vector2(0, 1)
	col.add_child(sep)
	# Rows
	for entry in cat["actions"]:
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 8)
		var key_lbl := Label.new()
		key_lbl.text = _bound_key_for(String(entry["action"]))
		key_lbl.add_theme_font_size_override("font_size", 12)
		key_lbl.add_theme_color_override("font_color", Color(1.0, 0.95, 0.65))
		key_lbl.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.85))
		key_lbl.add_theme_constant_override("outline_size", 2)
		key_lbl.custom_minimum_size = Vector2(72, 0)
		row.add_child(key_lbl)
		var action_lbl := Label.new()
		action_lbl.text = String(entry["label"])
		action_lbl.add_theme_font_size_override("font_size", 12)
		action_lbl.add_theme_color_override("font_color", Color(0.85, 0.78, 0.65))
		action_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.add_child(action_lbl)
		col.add_child(row)
	return col

# Walk InputMap for `action_name` and return a friendly key label like
# "W", "LMB", "Tab", or "—" if the action has no binding.
func _bound_key_for(action_name: String) -> String:
	if not InputMap.has_action(action_name):
		return "—"
	var events: Array = InputMap.action_get_events(action_name)
	if events.is_empty():
		return "—"
	# Prefer keyboard binding over mouse for the primary label
	var ev = events[0]
	for e in events:
		if e is InputEventKey:
			ev = e
			break
	if ev is InputEventKey:
		var ke: InputEventKey = ev
		var key: int = ke.physical_keycode if ke.physical_keycode != 0 else ke.keycode
		var key_str: String = OS.get_keycode_string(key)
		# Friendlier rendering for common keys
		match key_str:
			"Up":    return "↑"
			"Down":  return "↓"
			"Left":  return "←"
			"Right": return "→"
			"":      return "—"
		return key_str
	if ev is InputEventMouseButton:
		var mb: InputEventMouseButton = ev
		match mb.button_index:
			MOUSE_BUTTON_LEFT:   return "LMB"
			MOUSE_BUTTON_RIGHT:  return "RMB"
			MOUSE_BUTTON_MIDDLE: return "MMB"
			MOUSE_BUTTON_WHEEL_UP:   return "Wheel↑"
			MOUSE_BUTTON_WHEEL_DOWN: return "Wheel↓"
		return "Mouse %d" % mb.button_index
	return "?"
