extends Control
class_name MenuPanel

# Tabbed full-screen menu shell. Toggled by hotkeys (I/C/K/M/J/Y/Esc).
# Each tab is a child Control under `Tabs/<TabName>`. Switching shows one,
# hides the rest. Auto-pauses the game while open (settable per-tab).
#
# Wired to the HUD; the HUD adds it as a child once on _ready and the HUD
# routes input actions here via toggle_tab(StringName).

const TABS := [
	&"inventory",
	&"equipment",
	&"character",
	&"skills",
	&"quests",
	&"map",
	&"achievements",
	&"options",
]

# Hotkey -> tab name, source-of-truth for cycling
const HOTKEY_TO_TAB := {
	&"toggle_inventory":     &"inventory",
	&"toggle_character":     &"character",
	&"toggle_skills":        &"skills",
	&"toggle_map":           &"map",
	&"toggle_quests":        &"quests",
	&"toggle_achievements":  &"achievements",
	&"toggle_pause":         &"options",
}

@export var pause_when_open: bool = false  # default off so combat keeps flowing

var _open_tab: StringName = &""
var _tab_buttons: Dictionary = {}   # tab name -> Button
var _tab_panels: Dictionary = {}    # tab name -> Control

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS  # so it works while paused
	visible = false
	mouse_filter = Control.MOUSE_FILTER_STOP  # block clicks behind the menu
	anchor_right = 1.0
	anchor_bottom = 1.0
	_build_layout()

func _build_layout() -> void:
	# Background dim
	var dim := ColorRect.new()
	dim.color = Color(0.05, 0.05, 0.08, 0.78)
	dim.anchor_right = 1.0
	dim.anchor_bottom = 1.0
	dim.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(dim)

	# Frame
	var frame := PanelContainer.new()
	frame.anchor_left = 0.5
	frame.anchor_top = 0.5
	frame.anchor_right = 0.5
	frame.anchor_bottom = 0.5
	frame.offset_left = -480.0
	frame.offset_top = -300.0
	frame.offset_right = 480.0
	frame.offset_bottom = 300.0
	add_child(frame)

	var v := VBoxContainer.new()
	frame.add_child(v)
	v.add_theme_constant_override("separation", 12)

	# Tab strip
	var tab_row := HBoxContainer.new()
	v.add_child(tab_row)
	tab_row.add_theme_constant_override("separation", 6)
	for tab in TABS:
		var btn := Button.new()
		btn.text = String(tab).capitalize()
		btn.custom_minimum_size = Vector2(110, 36)
		btn.pressed.connect(_on_tab_button_pressed.bind(tab))
		tab_row.add_child(btn)
		_tab_buttons[tab] = btn

	# Tab content area
	var content := PanelContainer.new()
	content.size_flags_vertical = Control.SIZE_EXPAND_FILL
	content.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	v.add_child(content)

	var stack := Control.new()
	stack.size_flags_vertical = Control.SIZE_EXPAND_FILL
	stack.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	content.add_child(stack)

	for tab in TABS:
		var panel: Control = _spawn_tab_panel(tab)
		panel.visible = false
		panel.anchor_right = 1.0
		panel.anchor_bottom = 1.0
		stack.add_child(panel)
		_tab_panels[tab] = panel

	# Footer
	var hint := Label.new()
	hint.text = "  V=Pick Up  Shift=Dodge  I=Inventory  T=Character  K=Skills  M=Map  J=Quests  Y=Achievements  Esc=Close"
	hint.modulate = Color(0.7, 0.7, 0.7)
	v.add_child(hint)

func _spawn_tab_panel(tab: StringName) -> Control:
	var script_paths := {
		&"inventory":    "res://scripts/ui/panels/inventory_panel.gd",
		&"equipment":    "res://scripts/ui/panels/equipment_panel.gd",
		&"character":    "res://scripts/ui/panels/character_panel.gd",
		&"skills":       "res://scripts/ui/panels/skills_panel.gd",
		&"quests":       "res://scripts/ui/panels/quests_panel.gd",
		&"map":          "res://scripts/ui/panels/map_panel.gd",
		&"achievements": "res://scripts/ui/panels/achievements_panel.gd",
		&"options":      "res://scripts/ui/panels/options_panel.gd",
	}
	var path: String = script_paths.get(tab, "")
	var script: GDScript = load(path) if path != "" and ResourceLoader.exists(path) else null
	var panel: Control
	if script:
		panel = Control.new()
		panel.set_script(script)
	else:
		panel = _make_placeholder_panel(tab)
	panel.name = String(tab)
	return panel

func _make_placeholder_panel(tab: StringName) -> Control:
	var c := Control.new()
	var lbl := Label.new()
	lbl.text = "[%s] panel coming online — stub for now." % String(tab).to_upper()
	lbl.anchor_left = 0.5
	lbl.anchor_top = 0.5
	lbl.offset_left = -180.0
	lbl.offset_top = -10.0
	c.add_child(lbl)
	return c

func _on_tab_button_pressed(tab: StringName) -> void:
	_show_tab(tab)

# Public — called from HUD when a hotkey fires.
func toggle_tab(tab: StringName) -> void:
	if visible and _open_tab == tab:
		close()
	else:
		open(tab)

func open(tab: StringName) -> void:
	visible = true
	_show_tab(tab)
	if pause_when_open:
		get_tree().paused = true

func close() -> void:
	visible = false
	if pause_when_open:
		get_tree().paused = false

func _show_tab(tab: StringName) -> void:
	_open_tab = tab
	for t in TABS:
		if _tab_panels.has(t):
			_tab_panels[t].visible = (t == tab)
		if _tab_buttons.has(t):
			_tab_buttons[t].modulate = Color(1, 1, 1, 1) if t == tab else Color(0.7, 0.7, 0.7, 1)
	# Notify the freshly-shown panel so it can refresh its content
	var panel = _tab_panels.get(tab)
	if panel and panel.has_method("refresh"):
		panel.refresh()
