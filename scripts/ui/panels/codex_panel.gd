extends Control

# Codex tab: scrollable lore archive grouped by category. Two-column
# layout. Left: category buttons with unlocked / total counts. Right:
# scrollable card list for the selected category.
#
# Locked entries render as "? — locked" with the entry's unlock_hint
# dimmed grey; unlocked entries show the display_name in gold and the
# full body text below. The panel auto-refreshes when CodexRegistry
# emits entry_unlocked, so attuning a lodestone or first-pickup-of-an-
# item updates the codex live without re-opening the menu.

const CATEGORIES := [
	{"id": &"regions",      "label": "Regions"},
	{"id": &"characters",   "label": "Characters"},
	{"id": &"items",        "label": "Items"},
	{"id": &"lore",         "label": "Lore"},
	{"id": &"bestiary",     "label": "Bestiary"},
	{"id": &"achievements", "label": "Achievements"},
]

var _registry: Node = null
var _category_btns: Dictionary = {}
var _selected_category: StringName = &"regions"
var _list_v: VBoxContainer

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_PASS
	_registry = get_node_or_null("/root/CodexRegistry")

	var title := Label.new()
	title.text = "Codex"
	title.add_theme_font_size_override("font_size", 22)
	add_child(title)

	# Header summary: total unlocked across all categories
	var summary := Label.new()
	summary.name = "Summary"
	summary.anchor_left = 0.0
	summary.anchor_top = 0.06
	summary.modulate = Color(0.95, 0.85, 0.30)
	add_child(summary)

	# Two-column layout below the header
	var h := HBoxContainer.new()
	h.anchor_left = 0.0
	h.anchor_top = 0.10
	h.anchor_right = 1.0
	h.anchor_bottom = 1.0
	h.add_theme_constant_override("separation", 12)
	add_child(h)

	# Left column: category list
	var cat_v := VBoxContainer.new()
	cat_v.custom_minimum_size = Vector2(200, 0)
	cat_v.add_theme_constant_override("separation", 4)
	h.add_child(cat_v)
	for cat in CATEGORIES:
		var btn := Button.new()
		btn.alignment = HORIZONTAL_ALIGNMENT_LEFT
		btn.custom_minimum_size = Vector2(190, 32)
		btn.pressed.connect(_on_category_pressed.bind(cat.id))
		cat_v.add_child(btn)
		_category_btns[cat.id] = btn

	# Right column: scrollable entries
	var scroll := ScrollContainer.new()
	scroll.size_flags_horizontal = SIZE_EXPAND_FILL
	scroll.size_flags_vertical = SIZE_EXPAND_FILL
	h.add_child(scroll)
	_list_v = VBoxContainer.new()
	_list_v.add_theme_constant_override("separation", 8)
	_list_v.size_flags_horizontal = SIZE_EXPAND_FILL
	scroll.add_child(_list_v)

	refresh()

	if _registry and _registry.has_signal("entry_unlocked"):
		_registry.entry_unlocked.connect(func(_e): refresh())

func refresh() -> void:
	# Update summary count + per-category button labels
	if _registry:
		var sum: Label = get_node_or_null("Summary")
		if sum:
			sum.text = "Discovered  %d / %d entries" % [_registry.count_unlocked(), _registry.count_total()]
	for cat in CATEGORIES:
		var btn: Button = _category_btns.get(cat.id)
		if btn == null:
			continue
		var u := _count_unlocked(cat.id)
		var t := _count_total(cat.id)
		btn.text = "%s  (%d / %d)" % [cat.label, u, t]
		btn.modulate = Color(1, 1, 1) if cat.id == _selected_category else Color(0.7, 0.7, 0.75)

	# Clear and rebuild the entry list for the selected category
	for c in _list_v.get_children():
		c.queue_free()
	if _registry == null:
		var lbl := Label.new()
		lbl.text = "(CodexRegistry not loaded)"
		_list_v.add_child(lbl)
		return
	var entries: Array = _registry.entries_by_category(_selected_category)
	if entries.is_empty():
		var hint := Label.new()
		hint.text = "No entries in this category yet."
		hint.modulate = Color(0.65, 0.65, 0.7)
		_list_v.add_child(hint)
		return
	for entry in entries:
		_list_v.add_child(_entry_card(entry))

func _entry_card(entry: Dictionary) -> Control:
	var box := PanelContainer.new()
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 4)
	box.add_child(v)
	var id: StringName = entry.get("id", &"")
	var unlocked: bool = _registry.is_unlocked(id)
	# Header row: name + locked indicator
	var name_lbl := Label.new()
	name_lbl.add_theme_font_size_override("font_size", 14)
	if unlocked:
		name_lbl.text = String(entry.get("display_name", String(id)))
		name_lbl.modulate = Color(1.0, 0.85, 0.55)
	else:
		name_lbl.text = "? — undiscovered"
		name_lbl.modulate = Color(0.45, 0.45, 0.55)
	v.add_child(name_lbl)
	# Body: the lore prose if unlocked, otherwise the unlock hint
	var body := Label.new()
	body.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	body.add_theme_font_size_override("font_size", 12)
	if unlocked:
		body.text = String(entry.get("body", entry.get("description", "")))
		body.modulate = Color(0.85, 0.85, 0.85)
	else:
		body.text = String(entry.get("unlock_hint", "Discover this in the world."))
		body.modulate = Color(0.40, 0.40, 0.50)
	v.add_child(body)
	return box

func _on_category_pressed(id: StringName) -> void:
	_selected_category = id
	refresh()

func _count_unlocked(category: StringName) -> int:
	if _registry == null:
		return 0
	var count: int = 0
	for entry in _registry.entries_by_category(category):
		if _registry.is_unlocked(entry.get("id", &"")):
			count += 1
	return count

func _count_total(category: StringName) -> int:
	if _registry == null:
		return 0
	return _registry.entries_by_category(category).size()
