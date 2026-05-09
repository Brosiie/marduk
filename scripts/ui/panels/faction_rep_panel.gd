extends CanvasLayer
class_name FactionRepPanel

const T := preload("res://scripts/ui/ui_theme.gd")

# Faction reputation panel. Lists all 5 factions with rep bars showing
# current tier + progress within tier + numeric value + lore description.
# Subscribes to FactionRegistry.rep_changed for live updates.
#
# Bound to the U key (raw KEY_U; toggle_factions isn't in project.godot
# yet). Modal-stack aware via SIBLING_MODALS.

const SIBLING_MODALS := ["SkillTreePanel", "InkstoneSagePanel", "SacrificePrompt", "SaveSlotPicker", "PauseMenu", "QuestLogPanel", "CharacterCreator", "SettingsMenu", "SoulBindingPanel", "AchievementCodexPanel", "LocalMapPanel"]

@onready var dim: ColorRect = $Dim if has_node("Dim") else null
@onready var panel: PanelContainer = $Panel if has_node("Panel") else null

var fr: Node = null

func _ready() -> void:
	visible = false
	process_mode = Node.PROCESS_MODE_ALWAYS
	fr = get_node_or_null("/root/FactionRegistry")
	if fr and fr.has_signal("rep_changed"):
		fr.rep_changed.connect(_on_rep_changed)

func _on_rep_changed(_id, _new, _old) -> void:
	if visible:
		_build()

func _input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		var k: InputEventKey = event
		if k.physical_keycode == KEY_U and not _has_text_focus():
			_toggle()
			return
	if visible and event.is_action_pressed("ui_cancel"):
		_close()

func _has_text_focus() -> bool:
	var f: Control = get_viewport().gui_get_focus_owner() if get_viewport() else null
	return f and (f is LineEdit or f is TextEdit)

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
	margin.add_theme_constant_override("margin_left", T.PANEL_MARGIN_X)
	margin.add_theme_constant_override("margin_right", T.PANEL_MARGIN_X)
	margin.add_theme_constant_override("margin_top", T.PANEL_MARGIN_Y)
	margin.add_theme_constant_override("margin_bottom", T.PANEL_MARGIN_Y)
	panel.add_child(margin)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", T.HBOX_SEPARATION)
	margin.add_child(vbox)

	vbox.add_child(T.make_header_row("Reputation", _close, "Close [U / Esc]"))

	# Body
	var scroll := ScrollContainer.new()
	scroll.custom_minimum_size = Vector2(T.CONTENT_WIDTH, T.CARD_INNER_HEIGHT)
	scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	vbox.add_child(scroll)
	var content := VBoxContainer.new()
	content.add_theme_constant_override("separation", 10)
	content.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(content)

	if not fr:
		content.add_child(_make_label("FactionRegistry not loaded."))
		return
	for f in fr.all_factions():
		content.add_child(_make_faction_card(f))

func _make_faction_card(f) -> Control:
	var bar_data: Dictionary = fr.bar_for(f.faction_id)
	var tier: String = bar_data["tier"]
	var pct: float = bar_data["pct"]
	var current: int = bar_data["current"]
	var into_tier: int = bar_data["into_tier"]
	var span: int = bar_data["tier_max"] - bar_data["tier_min"]
	var tier_color: Color = fr.tier_color_for(current)

	var card := PanelContainer.new()
	card.add_theme_stylebox_override("panel", T.panel_box(f.color))

	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", T.VBOX_SEPARATION_TIGHT)
	card.add_child(v)

	var name_row := HBoxContainer.new()
	v.add_child(name_row)
	var motif := Label.new()
	motif.text = f.motif
	motif.add_theme_font_size_override("font_size", T.FONT_HEADING)
	motif.add_theme_color_override("font_color", f.color)
	motif.custom_minimum_size = Vector2(34, 0)
	name_row.add_child(motif)
	var name_label := Label.new()
	name_label.text = f.display_name
	name_label.add_theme_font_size_override("font_size", T.FONT_BUTTON)
	name_label.add_theme_color_override("font_color", T.BODY_CREAM)
	name_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	name_row.add_child(name_label)
	var tier_label := Label.new()
	tier_label.text = tier
	tier_label.add_theme_font_size_override("font_size", T.FONT_BODY)
	tier_label.add_theme_color_override("font_color", tier_color)
	name_row.add_child(tier_label)

	var bar := ProgressBar.new()
	bar.min_value = 0
	bar.max_value = span
	bar.value = into_tier
	bar.show_percentage = false
	bar.custom_minimum_size = Vector2(T.CARD_INNER_WIDTH, 12)
	bar.modulate = tier_color
	v.add_child(bar)

	var sub := Label.new()
	sub.text = "%d  ·  %d into %s, %d to next" % [current, into_tier, tier, max(0, span - into_tier)]
	sub.add_theme_font_size_override("font_size", T.FONT_TINY)
	sub.add_theme_color_override("font_color", T.HINT_BRONZE)
	v.add_child(sub)

	var desc := Label.new()
	desc.text = f.description
	desc.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	desc.custom_minimum_size = Vector2(T.CARD_INNER_WIDTH, 0)
	desc.add_theme_font_size_override("font_size", T.FONT_HINT)
	desc.add_theme_color_override("font_color", T.HINT_BRONZE)
	v.add_child(desc)

	return card

func _make_label(text: String) -> Label:
	return T.make_body(text)
