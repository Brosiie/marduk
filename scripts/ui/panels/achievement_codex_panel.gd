extends CanvasLayer
class_name AchievementCodexPanel

# Achievement codex. P toggles open/close. Tabs by Category (Combat, Feats,
# Exploration, Professions, Story, Collection, Meta). Each row shows the
# achievement name + description + lore + reward summary, with a clear
# unlocked/locked indicator and a progress count in the tab label.
#
# Hidden achievements (hidden_until_unlocked = true) only appear once unlocked
#, they're easter eggs.

@onready var dim: ColorRect = $Dim if has_node("Dim") else null
@onready var panel: PanelContainer = $Panel if has_node("Panel") else null

const SIBLING_MODALS := ["SkillTreePanel", "InkstoneSagePanel", "SacrificePrompt", "SaveSlotPicker", "PauseMenu", "QuestLogPanel", "CharacterCreator", "SettingsMenu", "SoulBindingPanel"]

const CATEGORY_NAMES := ["Combat", "Exploration", "Professions", "Story", "Feats", "Collection", "Meta"]
const CATEGORY_COLORS := [
	Color(0.85, 0.30, 0.20),  # COMBAT, blood red
	Color(0.55, 0.85, 0.45),  # EXPLORATION, leaf green
	Color(0.65, 0.55, 0.30),  # PROFESSIONS, earth
	Color(0.85, 0.45, 0.95),  # STORY, story-violet
	Color(1.00, 0.85, 0.30),  # FEATS, gold
	Color(0.55, 0.45, 0.95),  # COLLECTION, arcane
	Color(0.65, 0.65, 0.65),  # META, neutral
]

var _current_category: int = 0  # Achievement.Category index
var ar: Node = null

func _ready() -> void:
	visible = false
	process_mode = Node.PROCESS_MODE_ALWAYS
	ar = get_node_or_null("/root/AchievementRegistry")

func _input(event: InputEvent) -> void:
	# P key toggles. Listen for raw key event since toggle_achievements isn't
	# bound to a project input action yet, plain KEY_P, no modifiers.
	if event is InputEventKey and event.pressed and not event.echo:
		var key_event: InputEventKey = event
		if key_event.physical_keycode == KEY_P and not _has_text_focus():
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
	margin.add_theme_constant_override("margin_left", 24)
	margin.add_theme_constant_override("margin_right", 24)
	margin.add_theme_constant_override("margin_top", 22)
	margin.add_theme_constant_override("margin_bottom", 22)
	panel.add_child(margin)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 14)
	margin.add_child(vbox)

	# Header
	var header := HBoxContainer.new()
	vbox.add_child(header)
	var title := Label.new()
	title.text = "Codex of Marks"
	title.add_theme_font_size_override("font_size", 22)
	title.add_theme_color_override("font_color", Color(0.95, 0.85, 0.45))
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header.add_child(title)
	if ar:
		var unlocked: int = ar.get_unlocked_ids().size() if ar.has_method("get_unlocked_ids") else 0
		var total: int = ar.all_achievements().size() if ar.has_method("all_achievements") else 0
		var counter := Label.new()
		counter.text = "%d / %d" % [unlocked, total]
		counter.add_theme_font_size_override("font_size", 16)
		counter.add_theme_color_override("font_color", Color(0.95, 0.85, 0.45))
		header.add_child(counter)
	var close_btn := Button.new()
	close_btn.text = "Close [P / Esc]"
	close_btn.custom_minimum_size = Vector2(140, 32)
	close_btn.pressed.connect(_close)
	header.add_child(close_btn)

	# Tabs
	var tabs := HBoxContainer.new()
	tabs.add_theme_constant_override("separation", 6)
	vbox.add_child(tabs)
	for i in range(CATEGORY_NAMES.size()):
		tabs.add_child(_make_tab(i))

	# Content
	var scroll := ScrollContainer.new()
	scroll.custom_minimum_size = Vector2(720, 420)
	scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	vbox.add_child(scroll)
	var content := VBoxContainer.new()
	content.add_theme_constant_override("separation", 10)
	content.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(content)

	if not ar:
		content.add_child(_make_label("AchievementRegistry not loaded."))
		return

	var list: Array = ar.by_category(_current_category) if ar.has_method("by_category") else []
	if list.is_empty():
		content.add_child(_make_label("Nothing here yet."))
		return
	for ach in list:
		var unlocked: bool = ar.is_unlocked(ach.id) if ar.has_method("is_unlocked") else false
		# Hidden achievements are invisible until unlocked
		if ach.hidden_until_unlocked and not unlocked:
			continue
		content.add_child(_make_achievement_row(ach, unlocked))

func _make_tab(category_index: int) -> Button:
	var name: String = CATEGORY_NAMES[category_index] if category_index < CATEGORY_NAMES.size() else "?"
	var color: Color = CATEGORY_COLORS[category_index] if category_index < CATEGORY_COLORS.size() else Color.WHITE
	var unlocked: int = 0
	var total: int = 0
	if ar and ar.has_method("by_category"):
		var list: Array = ar.by_category(category_index)
		for ach in list:
			total += 1
			if ar.is_unlocked(ach.id):
				unlocked += 1
	var b := Button.new()
	b.text = "%s  %d/%d" % [name, unlocked, total]
	b.custom_minimum_size = Vector2(120, 32)
	b.modulate = Color(1, 1, 1) if _current_category == category_index else color.lerp(Color(0.55, 0.55, 0.55), 0.6)
	b.pressed.connect(func():
		_current_category = category_index
		_build()
	)
	return b

func _make_achievement_row(ach, unlocked: bool) -> Control:
	var card := PanelContainer.new()
	var bg := StyleBoxFlat.new()
	bg.bg_color = Color(0.08, 0.06, 0.05, 0.92)
	var category_color: Color = CATEGORY_COLORS[ach.category] if ach.category < CATEGORY_COLORS.size() else Color(0.65, 0.55, 0.45)
	bg.border_color = category_color if unlocked else category_color * Color(0.55, 0.55, 0.55, 0.6)
	bg.border_width_left = 2; bg.border_width_right = 1
	bg.border_width_top = 1; bg.border_width_bottom = 1
	bg.corner_radius_top_left = 4; bg.corner_radius_top_right = 4
	bg.corner_radius_bottom_left = 4; bg.corner_radius_bottom_right = 4
	bg.content_margin_left = 14; bg.content_margin_right = 14
	bg.content_margin_top = 12; bg.content_margin_bottom = 12
	card.add_theme_stylebox_override("panel", bg)

	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 4)
	card.add_child(v)

	var name_row := HBoxContainer.new()
	v.add_child(name_row)
	var icon := Label.new()
	icon.text = "✓" if unlocked else "○"
	icon.add_theme_font_size_override("font_size", 18)
	icon.add_theme_color_override("font_color", category_color if unlocked else Color(0.45, 0.40, 0.35))
	icon.custom_minimum_size = Vector2(28, 0)
	name_row.add_child(icon)
	var name_label := Label.new()
	name_label.text = ach.display_name
	name_label.add_theme_font_size_override("font_size", 16)
	name_label.add_theme_color_override("font_color", Color(0.95, 0.92, 0.80) if unlocked else Color(0.55, 0.50, 0.45))
	name_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	name_row.add_child(name_label)
	var rwd_label := Label.new()
	var rwd_bits: Array[String] = []
	if ach.xp_reward > 0:           rwd_bits.append("%d xp" % ach.xp_reward)
	if ach.gold_reward > 0:         rwd_bits.append("%d g" % ach.gold_reward)
	if ach.skill_point_reward > 0:  rwd_bits.append("%d sp" % ach.skill_point_reward)
	if ach.awards_title_id != &"":  rwd_bits.append("title")
	rwd_label.text = ("  ·  ".join(rwd_bits)) if not rwd_bits.is_empty() else ""
	rwd_label.add_theme_font_size_override("font_size", 11)
	rwd_label.add_theme_color_override("font_color", Color(0.85, 0.75, 0.30))
	name_row.add_child(rwd_label)

	var desc_label := Label.new()
	desc_label.text = ach.description
	desc_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	desc_label.custom_minimum_size = Vector2(680, 0)
	desc_label.add_theme_font_size_override("font_size", 12)
	desc_label.add_theme_color_override("font_color", Color(0.78, 0.72, 0.60) if unlocked else Color(0.55, 0.50, 0.42))
	v.add_child(desc_label)

	# Lore on unlocked achievements only, hidden until earned
	if unlocked and "lore" in ach and String(ach.lore) != "":
		var lore_label := Label.new()
		lore_label.text = String(ach.lore)
		lore_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		lore_label.custom_minimum_size = Vector2(680, 0)
		lore_label.add_theme_font_size_override("font_size", 11)
		lore_label.add_theme_color_override("font_color", Color(0.65, 0.60, 0.45))
		v.add_child(lore_label)

	return card

func _make_label(text: String) -> Label:
	var lab := Label.new()
	lab.text = text
	lab.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	lab.custom_minimum_size = Vector2(680, 0)
	lab.add_theme_font_size_override("font_size", 14)
	lab.add_theme_color_override("font_color", Color(0.75, 0.70, 0.60))
	return lab
