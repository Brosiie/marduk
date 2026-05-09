extends CanvasLayer
class_name SettingsMenu

const T := preload("res://scripts/ui/ui_theme.gd")

# Sectioned settings panel. Reads/writes GameSettings autoload.
# Tabs: Display / Audio / Controls / Gameplay / Accessibility / Privacy.
# Each field is declared in FIELDS as (key, label, type, options) and the
# UI builds itself from that, adding a setting later is a dict edit, not a
# scene rebuild.

signal closed

const FIELD_TYPE_BOOL := 0
const FIELD_TYPE_FLOAT_SLIDER := 1
const FIELD_TYPE_INT_DROPDOWN := 2
const FIELD_TYPE_STRING_DROPDOWN := 3

# (key, label, type, ...kind-specific extras)
# float_slider: min, max, step
# int_dropdown:    options as Array[int]
# string_dropdown: options as Array[String]
const FIELDS := {
	"Display": [
		["fullscreen",        "Fullscreen",          FIELD_TYPE_BOOL],
		["vsync",             "VSync",               FIELD_TYPE_BOOL],
		["fps_cap",           "FPS Cap",             FIELD_TYPE_INT_DROPDOWN, [30, 60, 90, 120, 144, 240, 0]],
		["resolution_scale",  "Render Scale",        FIELD_TYPE_FLOAT_SLIDER, 0.5, 2.0, 0.1],
		["msaa",              "MSAA",                FIELD_TYPE_INT_DROPDOWN, [0, 2, 4, 8]],
		["brightness",        "Brightness",          FIELD_TYPE_FLOAT_SLIDER, 0.5, 1.5, 0.05],
		["contrast",          "Contrast",            FIELD_TYPE_FLOAT_SLIDER, 0.5, 1.5, 0.05],
		["ui_scale",          "UI Scale",            FIELD_TYPE_FLOAT_SLIDER, 0.75, 1.5, 0.05],
	],
	"Audio": [
		["master_volume",     "Master",              FIELD_TYPE_FLOAT_SLIDER, 0.0, 1.0, 0.05],
		["music_volume",      "Music",               FIELD_TYPE_FLOAT_SLIDER, 0.0, 1.0, 0.05],
		["sfx_volume",        "SFX",                 FIELD_TYPE_FLOAT_SLIDER, 0.0, 1.0, 0.05],
		["ambient_volume",    "Ambient",             FIELD_TYPE_FLOAT_SLIDER, 0.0, 1.0, 0.05],
		["voice_volume",      "Voice",               FIELD_TYPE_FLOAT_SLIDER, 0.0, 1.0, 0.05],
		["mute_when_unfocused","Mute when unfocused", FIELD_TYPE_BOOL],
	],
	"Controls": [
		["mouse_sensitivity", "Mouse Sensitivity",   FIELD_TYPE_FLOAT_SLIDER, 0.25, 3.0, 0.05],
		["camera_invert_y",   "Invert Camera Y",     FIELD_TYPE_BOOL],
		["camera_smoothing",  "Camera Smoothing",    FIELD_TYPE_FLOAT_SLIDER, 0.0, 1.0, 0.05],
		["sprint_toggle",     "Sprint Toggle (vs Hold)", FIELD_TYPE_BOOL],
		["auto_target",       "Auto-target nearest enemy", FIELD_TYPE_BOOL],
		["click_to_move",     "Click-to-Move (Diablo style)", FIELD_TYPE_BOOL],
	],
	"Gameplay": [
		["show_damage_numbers",         "Show damage numbers",   FIELD_TYPE_BOOL],
		["show_floating_loot_text",     "Show loot text",        FIELD_TYPE_BOOL],
		["aggressive_loot_pickup",      "Auto-pickup loot",      FIELD_TYPE_BOOL],
		["difficulty_warning_underleveled", "Difficulty warnings", FIELD_TYPE_BOOL],
		["show_minimap",                "Show minimap",          FIELD_TYPE_BOOL],
		["show_objective_marker",       "Show objective markers", FIELD_TYPE_BOOL],
		["hud_scale",                   "HUD Scale",             FIELD_TYPE_FLOAT_SLIDER, 0.75, 1.5, 0.05],
	],
	"Accessibility": [
		["screen_shake",     "Screen Shake",         FIELD_TYPE_FLOAT_SLIDER, 0.0, 1.0, 0.05],
		["hit_stop",         "Hit-stop / slow-mo",   FIELD_TYPE_FLOAT_SLIDER, 0.0, 1.0, 0.05],
		["color_blind_mode", "Color Blind Mode",     FIELD_TYPE_STRING_DROPDOWN, ["none", "protanopia", "deuteranopia", "tritanopia"]],
		["reduced_motion",   "Reduce motion",        FIELD_TYPE_BOOL],
		["subtitles_enabled","Subtitles",            FIELD_TYPE_BOOL],
		["subtitle_size",    "Subtitle size",        FIELD_TYPE_INT_DROPDOWN, [14, 18, 22, 28]],
		["hud_high_contrast","High-contrast HUD",    FIELD_TYPE_BOOL],
	],
	"Privacy": [
		["allow_anon_telemetry", "Anonymous telemetry",  FIELD_TYPE_BOOL],
		["allow_crash_reports",  "Crash reports",        FIELD_TYPE_BOOL],
	],
}

const TAB_ORDER := ["Display", "Audio", "Controls", "Keybinds", "Gameplay", "Accessibility", "Privacy"]

# Rebindable input actions surfaced in the Keybinds tab. Order matters;
# the panel renders rows in this list-order.
const REBINDABLE_ACTIONS: Array[Dictionary] = [
	{"action": &"move_up",         "label": "Move Forward"},
	{"action": &"move_down",       "label": "Move Back"},
	{"action": &"move_left",       "label": "Move Left"},
	{"action": &"move_right",      "label": "Move Right"},
	{"action": &"jump",            "label": "Jump"},
	{"action": &"dodge",           "label": "Dodge"},
	{"action": &"attack_basic",    "label": "Basic Attack"},
	{"action": &"interact",        "label": "Interact / Pickup"},
	{"action": &"ability_1",       "label": "Ability Q"},
	{"action": &"ability_2",       "label": "Ability E"},
	{"action": &"ability_3",       "label": "Ability R"},
	{"action": &"ability_4",       "label": "Ability F"},
	{"action": &"toggle_inventory","label": "Inventory (I)"},
	{"action": &"toggle_skills",   "label": "Skill Tree (K)"},
	{"action": &"toggle_quests",   "label": "Quest Log (J)"},
	{"action": &"toggle_map",      "label": "Map (M)"},
	{"action": &"toggle_character","label": "Character Sheet (T)"},
	{"action": &"toggle_mount",    "label": "Mount (H)"},
	{"action": &"toggle_pet",      "label": "Pet (G)"},
]

# Capture state: when non-empty, the panel is listening for the next key
# press to remap the named action. Set by clicking a Rebind button.
var _rebinding_action: StringName = &""
var _rebinding_button: Button = null

@onready var dim: ColorRect = $Dim if has_node("Dim") else null
@onready var panel: PanelContainer = $Panel if has_node("Panel") else null

var settings: Node = null
var _current_tab: String = "Display"

func _ready() -> void:
	visible = false
	process_mode = Node.PROCESS_MODE_ALWAYS
	settings = get_node_or_null("/root/GameSettings")

func open() -> void:
	visible = true
	get_tree().paused = true
	_build()

func close() -> void:
	visible = false
	get_tree().paused = false
	# Persist on close so the player doesn't have to manually save
	if settings and settings.has_method("save_settings"):
		settings.save_settings()
	closed.emit()

func _build() -> void:
	if not panel:
		return
	for c in panel.get_children():
		c.queue_free()

	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", T.PANEL_MARGIN_X_LG)
	margin.add_theme_constant_override("margin_right", T.PANEL_MARGIN_X_LG)
	margin.add_theme_constant_override("margin_top", T.PANEL_MARGIN_Y_LG)
	margin.add_theme_constant_override("margin_bottom", T.PANEL_MARGIN_Y_LG)
	panel.add_child(margin)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", T.HBOX_SEPARATION)
	margin.add_child(vbox)

	vbox.add_child(T.make_header_row("Settings", close))

	# Tab row
	var tabs := HBoxContainer.new()
	tabs.add_theme_constant_override("separation", 6)
	vbox.add_child(tabs)
	for t in TAB_ORDER:
		tabs.add_child(_make_tab(t))

	# Content
	var scroll := ScrollContainer.new()
	scroll.custom_minimum_size = Vector2(T.CONTENT_WIDTH, 440)
	scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	vbox.add_child(scroll)
	var content := VBoxContainer.new()
	content.add_theme_constant_override("separation", 8)
	content.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(content)

	if _current_tab == "Keybinds":
		_render_keybinds(content)
		return

	if not settings:
		content.add_child(_make_label("GameSettings autoload not available."))
		return

	# Display tab: render the graphics-quality preset row above the
	# individual sliders so players can one-click set a coherent baseline.
	if _current_tab == "Display":
		content.add_child(_make_quality_preset_row())
		var sep := HSeparator.new()
		sep.custom_minimum_size = Vector2(0, 8)
		content.add_child(sep)

	for field_def in FIELDS.get(_current_tab, []):
		content.add_child(_make_field_row(field_def))

# Graphics-quality preset: one click sets msaa / resolution_scale / fog
# / shadow values to a coherent baseline, then re-renders the tab so
# the sliders show the new values.
const QUALITY_PRESETS := {
	"Low": {
		"msaa": 0,
		"resolution_scale": 0.75,
		"vsync": false,
		"fps_cap": 60,
		"brightness": 1.0,
	},
	"Medium": {
		"msaa": 2,
		"resolution_scale": 1.0,
		"vsync": true,
		"fps_cap": 60,
		"brightness": 1.0,
	},
	"High": {
		"msaa": 4,
		"resolution_scale": 1.0,
		"vsync": true,
		"fps_cap": 90,
		"brightness": 1.0,
	},
	"Ultra": {
		"msaa": 8,
		"resolution_scale": 1.25,
		"vsync": true,
		"fps_cap": 144,
		"brightness": 1.0,
	},
}

func _make_quality_preset_row() -> Control:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 12)

	var lab := Label.new()
	lab.text = "Quality Preset"
	lab.add_theme_font_size_override("font_size", T.FONT_ITEM_NAME)
	lab.add_theme_color_override("font_color", Color(0.85, 0.80, 0.65))
	lab.custom_minimum_size = Vector2(280, 32)
	row.add_child(lab)

	for preset_name in ["Low", "Medium", "High", "Ultra"]:
		var btn := Button.new()
		btn.text = preset_name
		btn.custom_minimum_size = Vector2(80, 32)
		btn.pressed.connect(_apply_quality_preset.bind(preset_name))
		row.add_child(btn)

	return row

func _apply_quality_preset(preset_name: String) -> void:
	var preset: Dictionary = QUALITY_PRESETS.get(preset_name, {})
	if preset.is_empty() or not settings:
		return
	for key in preset.keys():
		settings.set(key, preset[key])
	if settings.has_method("apply_all"):
		settings.apply_all()
	if settings.has_method("save_settings"):
		settings.save_settings()
	_show_toast("Quality: %s" % preset_name)
	_build()  # re-render so slider values reflect the new state

# ───────── Keybinds tab ─────────

func _render_keybinds(content: VBoxContainer) -> void:
	var hint := Label.new()
	hint.text = "Click a key to rebind. Press Esc during capture to cancel."
	hint.add_theme_font_size_override("font_size", T.FONT_HINT)
	hint.add_theme_color_override("font_color", Color(0.65, 0.60, 0.50))
	content.add_child(hint)

	for entry in REBINDABLE_ACTIONS:
		content.add_child(_make_keybind_row(entry))

	# Reset-to-defaults button at the bottom
	var spacer := Control.new()
	spacer.custom_minimum_size = Vector2(0, 12)
	content.add_child(spacer)
	var reset_btn := Button.new()
	reset_btn.text = "Reset all keybinds to defaults"
	reset_btn.custom_minimum_size = Vector2(0, 36)
	reset_btn.pressed.connect(_reset_all_keybinds)
	content.add_child(reset_btn)

func _make_keybind_row(entry: Dictionary) -> Control:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 16)

	var label := Label.new()
	label.text = String(entry["label"])
	label.add_theme_font_size_override("font_size", T.FONT_ITEM_NAME)
	label.add_theme_color_override("font_color", Color(0.85, 0.80, 0.65))
	label.custom_minimum_size = Vector2(280, 32)
	row.add_child(label)

	var action: StringName = entry["action"]
	var btn := Button.new()
	btn.text = _key_text_for_action(action)
	btn.custom_minimum_size = Vector2(180, 32)
	btn.pressed.connect(_begin_capture.bind(action, btn))
	row.add_child(btn)

	return row

func _key_text_for_action(action: StringName) -> String:
	if not InputMap.has_action(action):
		return "(unbound)"
	var events: Array[InputEvent] = InputMap.action_get_events(action)
	for event in events:
		if event is InputEventKey:
			var k: InputEventKey = event
			# Prefer label/keycode; fallback to physical
			var keycode: int = k.physical_keycode if k.physical_keycode != 0 else k.keycode
			return OS.get_keycode_string(keycode).capitalize()
		if event is InputEventMouseButton:
			var mb: InputEventMouseButton = event
			match mb.button_index:
				MOUSE_BUTTON_LEFT:   return "Mouse Left"
				MOUSE_BUTTON_RIGHT:  return "Mouse Right"
				MOUSE_BUTTON_MIDDLE: return "Mouse Middle"
				_: return "Mouse %d" % mb.button_index
	return "(unbound)"

func _begin_capture(action: StringName, btn: Button) -> void:
	# Cancel any other capture in flight
	if _rebinding_button:
		_rebinding_button.text = _key_text_for_action(_rebinding_action)
	_rebinding_action = action
	_rebinding_button = btn
	btn.text = "...press a key..."

func _input(event: InputEvent) -> void:
	if visible and _rebinding_action != &"":
		_handle_capture(event)
		return
	if visible and event.is_action_pressed("ui_cancel"):
		close()

func _handle_capture(event: InputEvent) -> void:
	# Esc during capture cancels (instead of closing the menu)
	if event is InputEventKey:
		var k: InputEventKey = event
		if not k.pressed or k.echo:
			return
		if k.physical_keycode == KEY_ESCAPE:
			get_viewport().set_input_as_handled()
			_cancel_capture()
			return
		# Bind the new key
		_apply_new_binding(_rebinding_action, k)
		get_viewport().set_input_as_handled()
		return
	if event is InputEventMouseButton:
		var mb: InputEventMouseButton = event
		if not mb.pressed:
			return
		_apply_new_binding(_rebinding_action, mb)
		get_viewport().set_input_as_handled()

func _apply_new_binding(action: StringName, event: InputEvent) -> void:
	if not InputMap.has_action(action):
		_cancel_capture()
		return
	# Strip key/mouse events from the action and add the new one. Leaves
	# joypad bindings alone so a player who set both keyboard + gamepad
	# keeps the gamepad mapping.
	var existing: Array[InputEvent] = InputMap.action_get_events(action)
	for e in existing:
		if e is InputEventKey or e is InputEventMouseButton:
			InputMap.action_erase_event(action, e)
	InputMap.action_add_event(action, event)
	# Refresh the button label
	if _rebinding_button:
		_rebinding_button.text = _key_text_for_action(action)
	_rebinding_action = &""
	_rebinding_button = null

func _cancel_capture() -> void:
	if _rebinding_button:
		_rebinding_button.text = _key_text_for_action(_rebinding_action)
	_rebinding_action = &""
	_rebinding_button = null

func _reset_all_keybinds() -> void:
	# Godot's InputMap doesn't expose a "reset to project default" call, so
	# we reload from ProjectSettings. Each action's default events are stored
	# at "input/<action>" with the events array.
	for entry in REBINDABLE_ACTIONS:
		var action: StringName = entry["action"]
		var key: String = "input/" + String(action)
		if not ProjectSettings.has_setting(key):
			continue
		var data: Dictionary = ProjectSettings.get_setting(key)
		# Erase current events
		var existing: Array[InputEvent] = InputMap.action_get_events(action)
		for e in existing:
			InputMap.action_erase_event(action, e)
		# Restore from project default
		var events: Array = data.get("events", [])
		for e in events:
			InputMap.action_add_event(action, e)
	_build()
	_show_toast("All keybinds reset to defaults.")

func _show_toast(msg: String) -> void:
	var juice: Node = get_node_or_null("/root/Juice")
	if juice and juice.has_method("toast"):
		juice.toast(msg, Color(0.85, 0.78, 0.55), 2.0)

func _make_tab(t: String) -> Button:
	var b := Button.new()
	b.text = t
	b.custom_minimum_size = Vector2(110, 32)
	b.modulate = Color(1, 1, 1) if _current_tab == t else Color(0.65, 0.65, 0.65)
	b.pressed.connect(func():
		_current_tab = t
		_build()
	)
	return b

func _make_field_row(field_def: Array) -> Control:
	var key: String = field_def[0]
	var label: String = field_def[1]
	var ftype: int = field_def[2]

	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 16)
	var lab := Label.new()
	lab.text = label
	lab.add_theme_font_size_override("font_size", T.FONT_ITEM_NAME)
	lab.add_theme_color_override("font_color", Color(0.85, 0.80, 0.65))
	lab.custom_minimum_size = Vector2(280, 32)
	row.add_child(lab)

	match ftype:
		FIELD_TYPE_BOOL:
			var cb := CheckBox.new()
			cb.button_pressed = bool(settings.get(key))
			cb.toggled.connect(func(v): _set(key, v))
			row.add_child(cb)
		FIELD_TYPE_FLOAT_SLIDER:
			var min_v: float = field_def[3]
			var max_v: float = field_def[4]
			var step: float = field_def[5]
			var slider := HSlider.new()
			slider.min_value = min_v
			slider.max_value = max_v
			slider.step = step
			slider.value = float(settings.get(key))
			slider.custom_minimum_size = Vector2(220, 24)
			var val_lab := Label.new()
			val_lab.text = "%.2f" % float(slider.value)
			val_lab.custom_minimum_size = Vector2(60, 0)
			val_lab.add_theme_color_override("font_color", Color(0.95, 0.85, 0.45))
			slider.value_changed.connect(func(v):
				val_lab.text = "%.2f" % v
				_set(key, v)
			)
			row.add_child(slider)
			row.add_child(val_lab)
		FIELD_TYPE_INT_DROPDOWN:
			var options: Array = field_def[3]
			var dd := OptionButton.new()
			var current_v: int = int(settings.get(key))
			var sel_index: int = 0
			for i in range(options.size()):
				dd.add_item("Unlimited" if int(options[i]) == 0 else str(options[i]))
				if int(options[i]) == current_v:
					sel_index = i
			dd.select(sel_index)
			dd.item_selected.connect(func(i): _set(key, int(options[i])))
			row.add_child(dd)
		FIELD_TYPE_STRING_DROPDOWN:
			var options2: Array = field_def[3]
			var dd2 := OptionButton.new()
			var current_v2: String = String(settings.get(key))
			var sel_index2: int = 0
			for i in range(options2.size()):
				dd2.add_item(String(options2[i]).capitalize())
				if String(options2[i]) == current_v2:
					sel_index2 = i
			dd2.select(sel_index2)
			dd2.item_selected.connect(func(i): _set(key, options2[i]))
			row.add_child(dd2)

	return row

func _set(key: String, value) -> void:
	if not settings:
		return
	if settings.has_method("set_value"):
		settings.set_value(StringName(_current_tab.to_lower()), StringName(key), value)
	else:
		settings.set(key, value)
		if settings.has_method("apply_all"):
			settings.apply_all()

func _make_label(text: String) -> Label:
	var lab := Label.new()
	lab.text = text
	lab.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	lab.add_theme_font_size_override("font_size", 14)
	lab.add_theme_color_override("font_color", Color(0.75, 0.70, 0.60))
	return lab
