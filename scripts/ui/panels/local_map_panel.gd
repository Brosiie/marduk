extends CanvasLayer
class_name LocalMapPanel

# Preload-shadowed alias — bypasses the global class_name cache. Stale
# .godot/global_script_class_cache.cfg was leaving LocalMapDrawer
# unresolved at parse time and taking the M key offline silently.
const LocalMapDrawer := preload("res://scripts/ui/panels/local_map_drawer.gd")

# Full-screen LOCAL map (the current scene). M toggles. Renders a top-down
# view of nodes by polling group memberships: player (gold), boss (red),
# enemy (orange), npc (green), item_pickup (blue/violet), boss_arena (red
# ring). Auto-frames the visible content with a 6m margin.
#
# Companion to:
#   - The minimap HUD widget (always-on corner radar)
#   - map_panel.gd / WorldMap (the lodestone-based continent map)
# This is the pause-the-game-and-look at the current zone view.

const SIBLING_MODALS := ["SkillTreePanel", "InkstoneSagePanel", "SacrificePrompt", "SaveSlotPicker", "PauseMenu", "QuestLogPanel", "CharacterCreator", "SettingsMenu", "SoulBindingPanel", "AchievementCodexPanel"]

@onready var dim: ColorRect = $Dim if has_node("Dim") else null
@onready var panel: PanelContainer = $Panel if has_node("Panel") else null

var _drawer: LocalMapDrawer = null

func _ready() -> void:
	visible = false
	process_mode = Node.PROCESS_MODE_ALWAYS

func _input(event: InputEvent) -> void:
	if event.is_action_pressed("toggle_map"):
		_toggle()
	elif visible and event.is_action_pressed("ui_cancel"):
		_close()

func _toggle() -> void:
	if visible:
		_close()
		return
	if _another_modal_visible():
		return
	_open()

func _another_modal_visible() -> bool:
	for nm in SIBLING_MODALS:
		var n: Node = get_tree().root.get_node_or_null(nm)
		if n and n is CanvasLayer and (n as CanvasLayer).visible:
			return true
	return false

func _open() -> void:
	visible = true
	get_tree().paused = true
	_build()

func _close() -> void:
	visible = false
	get_tree().paused = false

func _build() -> void:
	if not panel:
		return
	for c in panel.get_children():
		c.queue_free()

	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 24)
	margin.add_theme_constant_override("margin_right", 24)
	margin.add_theme_constant_override("margin_top", 22)
	margin.add_theme_constant_override("margin_bottom", 22)
	panel.add_child(margin)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 12)
	margin.add_child(vbox)

	var header := HBoxContainer.new()
	vbox.add_child(header)
	var title := Label.new()
	title.text = "Local Map"
	title.add_theme_font_size_override("font_size", 22)
	title.add_theme_color_override("font_color", Color(0.95, 0.85, 0.45))
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header.add_child(title)
	var zone_label := Label.new()
	zone_label.text = _resolve_zone_name()
	zone_label.add_theme_font_size_override("font_size", 14)
	zone_label.add_theme_color_override("font_color", Color(0.85, 0.78, 0.55))
	header.add_child(zone_label)
	var close_btn := Button.new()
	close_btn.text = "Close [M / Esc]"
	close_btn.custom_minimum_size = Vector2(140, 32)
	close_btn.pressed.connect(_close)
	header.add_child(close_btn)

	# Drawer canvas
	_drawer = LocalMapDrawer.new()
	_drawer.custom_minimum_size = Vector2(800, 520)
	_drawer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_drawer.size_flags_vertical = Control.SIZE_EXPAND_FILL
	vbox.add_child(_drawer)
	_drawer.refresh()

	# Legend
	var legend := Label.new()
	legend.text = "Player gold  ·  Boss red  ·  Enemy orange  ·  NPC green  ·  Loot violet  ·  Pickup blue"
	legend.add_theme_font_size_override("font_size", 11)
	legend.add_theme_color_override("font_color", Color(0.65, 0.60, 0.50))
	legend.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(legend)

func _resolve_zone_name() -> String:
	var current: Node = get_tree().current_scene
	return String(current.name).capitalize().replace("_", " ") if current else ""
