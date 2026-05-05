extends CanvasLayer
class_name HUD

# Minimal HUD: HP bar, mana bar, XP bar, level, ability cooldowns.

@export var player_path: NodePath

@onready var hp_bar: ProgressBar = $Root/Bars/HPBar
@onready var mana_bar: ProgressBar = $Root/Bars/ManaBar
@onready var xp_bar: ProgressBar = $Root/Bars/XPBar
@onready var level_label: Label = $Root/Bars/LevelLabel
@onready var resource_label: Label = $Root/Bars/ResourceLabel if has_node("Root/Bars/ResourceLabel") else null
@onready var prestige_badge: Label = $Root/Bars/PrestigeBadge if has_node("Root/Bars/PrestigeBadge") else null
@onready var ascend_prompt: Label = $Root/AscendPrompt if has_node("Root/AscendPrompt") else null

# Color and label per resource mechanic so the bar feels right per class.
const RESOURCE_THEME := {
	&"mana":        { "color": Color(0.4, 0.6, 1.0), "label": "MP" },
	&"stamina":     { "color": Color(0.85, 0.85, 0.45), "label": "STA" },
	&"rage":        { "color": Color(0.9, 0.2, 0.2), "label": "RAGE" },
	&"focus":       { "color": Color(0.9, 0.85, 0.3), "label": "FOCUS" },
	&"stance":      { "color": Color(0.7, 0.7, 0.85), "label": "STANCE" },
	&"corruption":  { "color": Color(0.5, 0.0, 0.6), "label": "CORRUPT" },
	&"form_energy": { "color": Color(0.3, 0.85, 0.45), "label": "WILD" },
	&"blood":       { "color": Color(0.65, 0.05, 0.10), "label": "BLOOD" },
}

var player: Player

var menu_panel: Control = null
var boss_bar: Control = null

func _ready() -> void:
	add_to_group("hud")
	player = get_node_or_null(player_path) if player_path else get_tree().get_first_node_in_group("player")
	if not player:
		push_warning("HUD: no player found")
		return
	player.hp_changed.connect(_on_hp)
	player.mana_changed.connect(_on_mana)
	player.resource_changed.connect(_on_resource)
	if player.stats:
		player.stats.leveled_up.connect(_on_level_up)
		player.stats.max_level_reached.connect(_on_max_level)
		_refresh_all()
		_apply_resource_theme()
		_apply_prestige_badge()
	# Spawn the tabbed full-screen menu shell. It's invisible until a hotkey
	# brings it up.
	var menu_script: GDScript = load("res://scripts/ui/menu_panel.gd")
	if menu_script:
		menu_panel = Control.new()
		menu_panel.set_script(menu_script)
		menu_panel.name = "MenuPanel"
		add_child(menu_panel)
	# Boss bar — built procedurally so we don't need a separate .tscn.
	boss_bar = _build_boss_bar()
	$Root.add_child(boss_bar)
	# Toast container for pickup notifications
	_setup_toast_layer()
	if player.has_signal("item_collected"):
		player.item_collected.connect(_on_item_collected)

func _process(_delta: float) -> void:
	if player and player.stats:
		var need := float(player.stats.xp_to_next_level())
		xp_bar.max_value = max(1.0, need)
		xp_bar.value = player.stats.xp

func _refresh_all() -> void:
	if not player or not player.stats:
		return
	hp_bar.max_value = player.stats.max_hp
	hp_bar.value = player.stats.hp
	mana_bar.max_value = player.stats.max_mana
	mana_bar.value = player.stats.mana
	var lvl_text := "Lv %d" % player.stats.level
	if player.stats.level >= PlayerStats.MAX_LEVEL:
		lvl_text += " MAX"
	level_label.text = lvl_text

func _apply_prestige_badge() -> void:
	if not prestige_badge:
		return
	var p := get_tree().root.get_node_or_null("Prestige")
	if not p:
		prestige_badge.visible = false
		return
	var pl: int = p.current_prestige_level()
	if pl <= 0:
		prestige_badge.visible = false
	else:
		prestige_badge.visible = true
		prestige_badge.text = "Cycle %d" % pl

func _on_max_level() -> void:
	if ascend_prompt:
		ascend_prompt.visible = true
		ascend_prompt.text = "MAX LEVEL REACHED. Press [P] to begin a new cycle."
	_refresh_all()

func _unhandled_input(event: InputEvent) -> void:
	# Tabbed menu hotkeys. Each routes through MenuPanel.toggle_tab so press-
	# again closes the panel and switching tabs is one keypress.
	if not (event is InputEventKey) or not event.pressed:
		return
	if menu_panel == null:
		return
	if event.is_action_pressed("toggle_inventory"):
		menu_panel.toggle_tab(&"inventory")
	elif event.is_action_pressed("toggle_character"):
		menu_panel.toggle_tab(&"character")
	elif event.is_action_pressed("toggle_skills"):
		menu_panel.toggle_tab(&"skills")
	elif event.is_action_pressed("toggle_map"):
		menu_panel.toggle_tab(&"map")
	elif event.is_action_pressed("toggle_quests"):
		menu_panel.toggle_tab(&"quests")
	elif event.is_action_pressed("toggle_achievements"):
		menu_panel.toggle_tab(&"achievements")
	elif event.is_action_pressed("toggle_pause"):
		menu_panel.toggle_tab(&"options")

func _on_hp(cur: float, mx: float) -> void:
	hp_bar.max_value = mx
	hp_bar.value = cur

func _on_mana(cur: float, mx: float) -> void:
	mana_bar.max_value = mx
	mana_bar.value = cur

func _on_level_up(_lvl: int) -> void:
	_refresh_all()
	# Level-up arpeggio
	var ab = get_node_or_null("/root/AudioBus")
	if ab and ab.has_method("play_cue") and player:
		ab.play_cue(&"level_up", player.global_position, -3.0, 1.0)

func _on_resource(cur: float, mx: float, _mech: StringName) -> void:
	mana_bar.max_value = max(1.0, mx)
	mana_bar.value = cur

func _apply_resource_theme() -> void:
	if not player or not player.stats or not player.stats.class_def:
		return
	var mech: StringName = player.stats.class_def.resource_mechanic
	var theme: Dictionary = RESOURCE_THEME.get(mech, RESOURCE_THEME[&"mana"])
	mana_bar.modulate = theme["color"]
	if resource_label:
		resource_label.text = theme["label"]

# --- Pickup toasts ---
# A small VBox stacked top-right that scrolls up and fades. Each new
# pickup appends a label that tween-fades over 2.5 seconds.
var _toast_layer: VBoxContainer

func _setup_toast_layer() -> void:
	if _toast_layer != null:
		return
	_toast_layer = VBoxContainer.new()
	_toast_layer.anchor_left = 1.0
	_toast_layer.anchor_top = 0.0
	_toast_layer.anchor_right = 1.0
	_toast_layer.anchor_bottom = 0.0
	_toast_layer.offset_left = -320.0
	_toast_layer.offset_top = 80.0
	_toast_layer.offset_right = -20.0
	_toast_layer.offset_bottom = 200.0
	_toast_layer.alignment = BoxContainer.ALIGNMENT_END
	_toast_layer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	$Root.add_child(_toast_layer)

func _on_item_collected(item: Item, quantity: int) -> void:
	var row := HBoxContainer.new()
	# Icon
	var icon_rect := TextureRect.new()
	icon_rect.custom_minimum_size = Vector2(28, 28)
	icon_rect.expand_mode = TextureRect.EXPAND_FIT_WIDTH_PROPORTIONAL
	icon_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	var atlas: Node = get_node_or_null("/root/IconAtlas")
	if atlas and atlas.has_method("get_icon_for_item"):
		icon_rect.texture = atlas.get_icon_for_item(item)
	row.add_child(icon_rect)
	# Label
	var lbl := Label.new()
	lbl.text = "+ %s%s" % [item.display_name if item else "(unknown)", (" x%d" % quantity) if quantity > 1 else ""]
	lbl.modulate = _rarity_color(item.rarity if item else 2)
	row.add_child(lbl)
	_toast_layer.add_child(row)
	var tw := create_tween()
	tw.tween_interval(2.0)
	tw.tween_property(row, "modulate:a", 0.0, 0.4)
	tw.tween_callback(row.queue_free)

func _rarity_color(rarity: int) -> Color:
	match rarity:
		0: return Color(0.40, 0.40, 0.40)
		1: return Color(0.85, 0.85, 0.85)
		2: return Color(0.55, 0.85, 0.45)
		3: return Color(0.40, 0.50, 0.95)
		4: return Color(0.75, 0.30, 0.95)
		5: return Color(1.00, 0.65, 0.10)
		6: return Color(1.00, 0.95, 0.55)
	return Color.WHITE

# --- Boss bar ---
# Built procedurally because we want a boss bar without a separate .tscn.
# BossArena binds the boss to this bar via HUD.bind_boss(boss).
func _build_boss_bar() -> Control:
	var root := Control.new()
	root.name = "BossBar"
	root.anchor_left = 0.5
	root.anchor_top = 0.0
	root.anchor_right = 0.5
	root.anchor_bottom = 0.0
	root.offset_left = -360.0
	root.offset_top = 12.0
	root.offset_right = 360.0
	root.offset_bottom = 80.0
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.visible = false

	var frame := PanelContainer.new()
	frame.name = "Frame"
	frame.anchor_right = 1.0
	frame.anchor_bottom = 1.0
	root.add_child(frame)

	var v := VBoxContainer.new()
	v.name = "V"
	frame.add_child(v)

	var name := Label.new()
	name.name = "Name"
	name.add_theme_font_size_override("font_size", 18)
	name.modulate = Color(0.95, 0.85, 0.55)
	name.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(name)

	var phase := Label.new()
	phase.name = "Phase"
	phase.add_theme_font_size_override("font_size", 11)
	phase.modulate = Color(0.85, 0.65, 0.45)
	phase.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(phase)

	var hp := ProgressBar.new()
	hp.name = "HP"
	hp.custom_minimum_size = Vector2(700, 22)
	hp.modulate = Color(0.95, 0.20, 0.20)
	hp.show_percentage = false
	v.add_child(hp)

	var bar_script: GDScript = load("res://scripts/ui/hud_components/boss_bar.gd")
	if bar_script:
		root.set_script(bar_script)
	return root

# Public hooks for BossArena
func bind_boss(boss: Node) -> void:
	if boss_bar and boss_bar.has_method("bind_to_boss"):
		boss_bar.bind_to_boss(boss)

func unbind_boss() -> void:
	if boss_bar and boss_bar.has_method("hide_bar"):
		boss_bar.hide_bar()
