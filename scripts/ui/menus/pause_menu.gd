extends CanvasLayer
class_name PauseMenu

# Preload-shadowed alias — bypasses the global class_name cache. Without
# this, a stale .godot/global_script_class_cache.cfg leaves SaveSlotPicker
# unresolved and the entire pause menu fails to load, taking Esc with it.
const SaveSlotPicker := preload("res://scripts/ui/menus/save_slot_picker.gd")

# Esc-toggle pause menu. Lives in the HUD so it ships in every in-game scene.
# Five actions: Resume / Save / Load / Settings / Quit to Title.
#
# Esc conflict resolution: this menu only opens if no other modal is currently
# visible (SkillTreePanel, InkstoneSagePanel, SacrificePrompt, SaveSlotPicker
# all live in the same canvas-layer space). Those modals close on Esc first;
# pressing Esc again then opens the pause menu.

signal resumed()
signal returning_to_title()

const SAVE_SLOT_PICKER_SCENE := "res://scenes/menus/save_slot_picker.tscn"
const START_MENU_SCENE := "res://scenes/menus/start_menu.tscn"

const MODAL_GROUP_NODE_NAMES := [
	"SkillTreePanel",
	"InkstoneSagePanel",
	"SacrificePrompt",
	"SaveSlotPicker",
	"CharacterCreator",
	"QuestLogPanel",
	"SettingsMenu",
	"SoulBindingPanel",
	"AchievementCodexPanel",
	"LocalMapPanel",
	"FactionRepPanel",
]

@onready var dim: ColorRect = $Dim if has_node("Dim") else null
@onready var panel: PanelContainer = $Panel if has_node("Panel") else null

func _ready() -> void:
	visible = false
	process_mode = Node.PROCESS_MODE_ALWAYS

func _input(event: InputEvent) -> void:
	if not event.is_action_pressed("ui_cancel"):
		return
	if visible:
		_resume()
		return
	# Don't open if any other modal is visible — let those handle their own Esc.
	if _another_modal_visible():
		return
	_open()

func _another_modal_visible() -> bool:
	for name in MODAL_GROUP_NODE_NAMES:
		var n: Node = get_tree().root.get_node_or_null(name)
		if n and n is CanvasLayer and (n as CanvasLayer).visible:
			return true
		# Also check nested under HUD
		var hud: Node = get_tree().root.find_child(name, true, false) if get_tree().root else null
		if hud and hud is CanvasLayer and (hud as CanvasLayer).visible:
			return true
	# Also: never open over the start menu / character creator
	var current: Node = get_tree().current_scene
	if current and (current.name == "StartMenu" or current.name == "CharacterCreator"):
		return true
	return false

func _open() -> void:
	visible = true
	get_tree().paused = true
	_build()

func _resume() -> void:
	visible = false
	get_tree().paused = false
	resumed.emit()

func _build() -> void:
	if not panel:
		return
	for c in panel.get_children():
		c.queue_free()

	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 32)
	margin.add_theme_constant_override("margin_right", 32)
	margin.add_theme_constant_override("margin_top", 28)
	margin.add_theme_constant_override("margin_bottom", 28)
	panel.add_child(margin)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 12)
	margin.add_child(vbox)

	var title := Label.new()
	title.text = "Paused"
	title.add_theme_font_size_override("font_size", 24)
	title.add_theme_color_override("font_color", Color(0.95, 0.85, 0.45))
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(title)

	var spacer := Control.new()
	spacer.custom_minimum_size = Vector2(0, 8)
	vbox.add_child(spacer)

	vbox.add_child(_make_button("Resume [Esc]", _resume))
	vbox.add_child(_make_button("Save",         _open_save))
	vbox.add_child(_make_button("Load",         _open_load))
	vbox.add_child(_make_button("Settings",     _open_settings))

	var spacer2 := Control.new()
	spacer2.custom_minimum_size = Vector2(0, 8)
	vbox.add_child(spacer2)

	vbox.add_child(_make_button("Quit to Title", _quit_to_title))

func _make_button(text: String, on_press: Callable) -> Button:
	var b := Button.new()
	b.text = text
	b.custom_minimum_size = Vector2(280, 44)
	b.add_theme_font_size_override("font_size", 16)
	b.pressed.connect(on_press)
	return b

# ───────── Actions ─────────

func _open_save() -> void:
	_spawn_slot_picker(SaveSlotPicker.Mode.SAVE)

func _open_load() -> void:
	_spawn_slot_picker(SaveSlotPicker.Mode.LOAD)

func _spawn_slot_picker(mode: int) -> void:
	var packed: PackedScene = load(SAVE_SLOT_PICKER_SCENE)
	if not packed:
		push_warning("[PauseMenu] save_slot_picker.tscn not found")
		return
	var picker = packed.instantiate()
	get_tree().current_scene.add_child(picker)
	var p: Node = _find_player()
	picker.open(mode, p)
	# Close the pause menu while the picker is up; reopen if user cancels.
	visible = false
	picker.cancelled.connect(_on_picker_closed)
	if picker.has_signal("slot_loaded"):
		picker.slot_loaded.connect(func(_s): _resume())
	if picker.has_signal("slot_saved"):
		picker.slot_saved.connect(func(_s): _on_picker_closed())

func _on_picker_closed() -> void:
	# After the picker closes (cancel or save), reopen the pause menu so the
	# player isn't dropped straight into combat.
	if not visible:
		visible = true

const SETTINGS_MENU_SCENE := "res://scenes/menus/settings_menu.tscn"

func _open_settings() -> void:
	var packed: PackedScene = load(SETTINGS_MENU_SCENE)
	if not packed:
		var juice: Node = get_node_or_null("/root/Juice")
		if juice and juice.has_method("toast"):
			juice.toast("Settings menu scene not found.", Color(0.85, 0.30, 0.20), 2.0)
		return
	var menu = packed.instantiate()
	get_tree().current_scene.add_child(menu)
	menu.open()
	visible = false
	if menu.has_signal("closed"):
		menu.closed.connect(_on_picker_closed)

func _quit_to_title() -> void:
	get_tree().paused = false
	returning_to_title.emit()
	get_tree().change_scene_to_file(START_MENU_SCENE)

func _find_player() -> Node:
	for p in get_tree().get_nodes_in_group("player"):
		if is_instance_valid(p):
			return p
	return null
