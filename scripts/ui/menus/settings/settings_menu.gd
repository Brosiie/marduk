extends Control
class_name SettingsMenu

# Tabbed settings menu. Each tab is a category from GameSettings. Bound via
# reflection: rows describe (label, type, key, range/options) and write back
# via GameSettings.set_value(category, key, value).
#
# Open: Esc (or pause menu). Closes: Esc again or Apply/Close button.

signal closed

const TABS := [
	{"id": &"display", "name": "Display"},
	{"id": &"audio", "name": "Audio"},
	{"id": &"controls", "name": "Controls"},
	{"id": &"keybindings", "name": "Key Bindings"},
	{"id": &"gameplay", "name": "Gameplay"},
	{"id": &"a11y", "name": "Accessibility"},
	{"id": &"privacy", "name": "Privacy"},
	{"id": &"mobile", "name": "Mobile"},
]

# Schema for each tab. Entries: {key, label, kind, args}
# kind: "toggle" | "slider" | "options" | "vector2i" | "rebind"
const SCHEMA := {
	&"display": [
		{"key": &"fullscreen", "label": "Fullscreen", "kind": "toggle"},
		{"key": &"resolution", "label": "Resolution", "kind": "options",
		 "options": [Vector2i(1280, 720), Vector2i(1600, 900), Vector2i(1920, 1080), Vector2i(2560, 1440), Vector2i(3840, 2160)]},
		{"key": &"vsync", "label": "VSync", "kind": "toggle"},
		{"key": &"fps_cap", "label": "FPS Cap", "kind": "options",
		 "options": [30, 60, 90, 120, 144, 240, 0]},
		{"key": &"resolution_scale", "label": "Render Scale (0.5 = Octopath crunch)",
		 "kind": "slider", "min": 0.5, "max": 2.0, "step": 0.1},
		{"key": &"msaa", "label": "MSAA", "kind": "options", "options": [0, 2, 4, 8]},
		{"key": &"brightness", "label": "Brightness", "kind": "slider", "min": 0.5, "max": 2.0, "step": 0.05},
		{"key": &"contrast", "label": "Contrast", "kind": "slider", "min": 0.5, "max": 1.5, "step": 0.05},
		{"key": &"ui_scale", "label": "UI Scale", "kind": "slider", "min": 0.75, "max": 1.5, "step": 0.05},
	],
	&"audio": [
		{"key": &"master_volume", "label": "Master", "kind": "slider", "min": 0.0, "max": 1.0, "step": 0.01},
		{"key": &"music_volume", "label": "Music", "kind": "slider", "min": 0.0, "max": 1.0, "step": 0.01},
		{"key": &"sfx_volume", "label": "SFX", "kind": "slider", "min": 0.0, "max": 1.0, "step": 0.01},
		{"key": &"ambient_volume", "label": "Ambient", "kind": "slider", "min": 0.0, "max": 1.0, "step": 0.01},
		{"key": &"voice_volume", "label": "Voice", "kind": "slider", "min": 0.0, "max": 1.0, "step": 0.01},
		{"key": &"mute_when_unfocused", "label": "Mute when window unfocused", "kind": "toggle"},
	],
	&"controls": [
		{"key": &"mouse_sensitivity", "label": "Mouse Sensitivity", "kind": "slider", "min": 0.1, "max": 3.0, "step": 0.05},
		{"key": &"camera_invert_y", "label": "Invert Y", "kind": "toggle"},
		{"key": &"camera_smoothing", "label": "Camera Smoothing", "kind": "slider", "min": 0.0, "max": 1.0, "step": 0.05},
		{"key": &"sprint_toggle", "label": "Sprint Toggle (vs Hold)", "kind": "toggle"},
		{"key": &"auto_target", "label": "Auto-Target Enemies", "kind": "toggle"},
		{"key": &"click_to_move", "label": "Click-to-Move (Diablo style)", "kind": "toggle"},
	],
	&"keybindings": [
		# Filled dynamically from KeyBindings.defaults
	],
	&"gameplay": [
		{"key": &"difficulty_warning_underleveled", "label": "Warn when entering under-leveled zones", "kind": "toggle"},
		{"key": &"show_damage_numbers", "label": "Show damage numbers", "kind": "toggle"},
		{"key": &"show_floating_loot_text", "label": "Show floating loot text", "kind": "toggle"},
		{"key": &"aggressive_loot_pickup", "label": "Auto-pickup loot on proximity", "kind": "toggle"},
		{"key": &"show_minimap", "label": "Show minimap", "kind": "toggle"},
		{"key": &"show_objective_marker", "label": "Show quest objective markers", "kind": "toggle"},
		{"key": &"hud_scale", "label": "HUD Scale", "kind": "slider", "min": 0.75, "max": 1.5, "step": 0.05},
	],
	&"a11y": [
		{"key": &"screen_shake", "label": "Screen shake intensity (0 disables)", "kind": "slider", "min": 0.0, "max": 1.5, "step": 0.05},
		{"key": &"hit_stop", "label": "Hit-stop intensity (0 disables)", "kind": "slider", "min": 0.0, "max": 1.5, "step": 0.05},
		{"key": &"color_blind_mode", "label": "Color-blind mode", "kind": "options",
		 "options": [&"none", &"protanopia", &"deuteranopia", &"tritanopia"]},
		{"key": &"reduced_motion", "label": "Reduced motion", "kind": "toggle"},
		{"key": &"subtitle_size", "label": "Subtitle size", "kind": "options", "options": [14, 16, 18, 20, 24, 28]},
		{"key": &"subtitles_enabled", "label": "Subtitles", "kind": "toggle"},
		{"key": &"hud_high_contrast", "label": "High-contrast HUD", "kind": "toggle"},
	],
	&"privacy": [
		{"key": &"allow_anon_telemetry", "label": "Allow anonymous telemetry", "kind": "toggle"},
		{"key": &"allow_crash_reports", "label": "Send crash reports", "kind": "toggle"},
	],
	&"mobile": [
		{"key": &"virtual_joystick_size", "label": "Joystick size", "kind": "slider", "min": 0.6, "max": 1.5, "step": 0.05},
		{"key": &"virtual_joystick_position", "label": "Joystick position", "kind": "options",
		 "options": [&"bottom_left", &"bottom_right"]},
		{"key": &"ability_buttons_size", "label": "Ability button size", "kind": "slider", "min": 0.6, "max": 1.5, "step": 0.05},
	],
}

@onready var tab_container: TabContainer = $Margin/Layout/Tabs if has_node("Margin/Layout/Tabs") else null
@onready var apply_button: Button = $Margin/Layout/Footer/ApplyButton if has_node("Margin/Layout/Footer/ApplyButton") else null
@onready var close_button: Button = $Margin/Layout/Footer/CloseButton if has_node("Margin/Layout/Footer/CloseButton") else null
@onready var reset_button: Button = $Margin/Layout/Footer/ResetButton if has_node("Margin/Layout/Footer/ResetButton") else null

func _ready() -> void:
	if apply_button: apply_button.pressed.connect(_on_apply)
	if close_button: close_button.pressed.connect(_on_close)
	if reset_button: reset_button.pressed.connect(_on_reset)
	_build_all_tabs()
	visible = false

func open() -> void:
	visible = true

func _build_all_tabs() -> void:
	# Builds rows for each tab. Real .tscn would have static layout; this is a code-driven fallback.
	if not tab_container:
		return
	for tab in TABS:
		var page := VBoxContainer.new()
		page.name = String(tab["name"])
		tab_container.add_child(page)
		var schema: Array = SCHEMA.get(tab["id"], [])
		for row_def in schema:
			page.add_child(_make_row(tab["id"], row_def))
		# Special: keybindings tab populates from KeyBindings.defaults
		if tab["id"] == &"keybindings":
			for action in KeyBindings.defaults.keys():
				page.add_child(_make_rebind_row(action))

func _make_row(category: StringName, def: Dictionary) -> Control:
	var row := HBoxContainer.new()
	var label := Label.new()
	label.text = String(def["label"])
	label.custom_minimum_size = Vector2(280, 28)
	row.add_child(label)
	var key: StringName = def["key"]
	var current = GameSettings.get(String(key))
	match def["kind"]:
		"toggle":
			var cb := CheckBox.new()
			cb.button_pressed = bool(current)
			cb.toggled.connect(func(v): GameSettings.set_value(category, key, v))
			row.add_child(cb)
		"slider":
			var sl := HSlider.new()
			sl.min_value = float(def.get("min", 0.0))
			sl.max_value = float(def.get("max", 1.0))
			sl.step = float(def.get("step", 0.05))
			sl.value = float(current)
			sl.custom_minimum_size = Vector2(180, 24)
			sl.value_changed.connect(func(v): GameSettings.set_value(category, key, v))
			row.add_child(sl)
		"options":
			var opt := OptionButton.new()
			for o in def.get("options", []):
				opt.add_item(str(o))
				opt.set_item_metadata(opt.item_count - 1, o)
			# Select current
			for i in range(opt.item_count):
				if opt.get_item_metadata(i) == current:
					opt.select(i)
					break
			opt.item_selected.connect(func(idx): GameSettings.set_value(category, key, opt.get_item_metadata(idx)))
			row.add_child(opt)
	return row

func _make_rebind_row(action: StringName) -> Control:
	var row := HBoxContainer.new()
	var label := Label.new()
	label.text = String(action)
	label.custom_minimum_size = Vector2(220, 28)
	row.add_child(label)
	var btn := Button.new()
	btn.text = KeyBindings.describe_binding(action)
	btn.custom_minimum_size = Vector2(160, 28)
	btn.pressed.connect(func():
		btn.text = "Press any key/button..."
		KeyBindings.start_rebinding(action)
		KeyBindings.rebinding_completed.connect(
			func(_a, _ev): btn.text = KeyBindings.describe_binding(action),
			CONNECT_ONE_SHOT))
	row.add_child(btn)
	var reset := Button.new()
	reset.text = "Default"
	reset.pressed.connect(func():
		KeyBindings.reset_to_default(action)
		btn.text = KeyBindings.describe_binding(action))
	row.add_child(reset)
	return row

func _on_apply() -> void:
	GameSettings.apply_all()
	GameSettings.save_settings()

func _on_close() -> void:
	visible = false
	closed.emit()

func _on_reset() -> void:
	# Reset to defaults (caveman: just reload from disk after deleting config)
	KeyBindings.reset_all_to_default()
	# Settings reset would clear the file; soft option is to just call defaults manually.
