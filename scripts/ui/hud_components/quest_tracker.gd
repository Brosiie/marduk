extends Control
class_name QuestTrackerHUD

# Top-left always-visible quest tracker. Shows the player's currently
# focused quest with its objectives and counted progress. Subscribes to
# QuestRegistry signals so it auto-refreshes when quests are accepted,
# completed, or progressed.
#
# Visual: small dark panel right under the HP/mana/XP bars. Header is the
# quest name in gold; each objective is a green check (done) or grey dot
# (pending) followed by the description and "[count / required]" tail.

const PANEL_WIDTH: float = 320.0
const PANEL_PAD: float = 8.0

var _registry: Node = null
var _v: VBoxContainer
var _focused_id: StringName = &""

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	anchor_left = 0.0
	anchor_top = 0.0
	anchor_right = 0.0
	anchor_bottom = 0.0
	offset_left = 20.0
	offset_top = 160.0  # below the HP/Mana/XP bars
	offset_right = offset_left + PANEL_WIDTH
	offset_bottom = offset_top + 200.0

	# Background panel — same gold-filigree language as the rest of
	# the HUD. Old version was a transparent dark rect with a barely-
	# visible 1px border. Now a polished slate panel with shadow.
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.05, 0.04, 0.06, 0.85)
	sb.border_color = Color(0.78, 0.62, 0.28, 0.95)
	sb.set_border_width_all(1)
	sb.border_width_top = 2
	sb.set_corner_radius_all(4)
	sb.shadow_color = Color(0, 0, 0, 0.55)
	sb.shadow_size = 4
	sb.shadow_offset = Vector2(0, 2)
	sb.content_margin_left = PANEL_PAD
	sb.content_margin_top = PANEL_PAD
	sb.content_margin_right = PANEL_PAD
	sb.content_margin_bottom = PANEL_PAD
	var panel := PanelContainer.new()
	panel.anchor_right = 1.0
	panel.anchor_bottom = 1.0
	panel.add_theme_stylebox_override("panel", sb)
	add_child(panel)

	_v = VBoxContainer.new()
	_v.add_theme_constant_override("separation", 4)
	panel.add_child(_v)

	_registry = get_node_or_null("/root/QuestRegistry")
	if _registry:
		if _registry.has_signal("quest_accepted"):
			_registry.quest_accepted.connect(_on_quest_changed)
		if _registry.has_signal("quest_completed"):
			_registry.quest_completed.connect(_on_quest_changed)
		if _registry.has_signal("quest_progress"):
			_registry.quest_progress.connect(_on_progress)
	refresh()

func refresh() -> void:
	for c in _v.get_children():
		c.queue_free()
	if _registry == null:
		return
	var active = _registry.get_active_quests() if _registry.has_method("get_active_quests") else []
	if active.is_empty():
		var hint := Label.new()
		hint.text = "No active quests. Visit Ashurim plaza."
		hint.modulate = Color(0.65, 0.65, 0.65)
		hint.add_theme_font_size_override("font_size", 11)
		_v.add_child(hint)
		visible = false  # hide entirely when there's nothing to show
		return
	visible = true
	# Pick a focused quest (the most recently accepted, for now)
	var focused = active[0]
	var qname: String = ""
	if typeof(focused) == TYPE_DICTIONARY:
		qname = focused.get("display_name", "Quest")
	else:
		qname = focused.display_name if focused.has_method("get") else "Quest"
	var header := Label.new()
	header.text = qname
	header.add_theme_font_size_override("font_size", 16)
	header.add_theme_color_override("font_color", Color(1.0, 0.92, 0.55))
	header.add_theme_color_override("font_outline_color", Color(0.20, 0.05, 0.05, 0.95))
	header.add_theme_constant_override("outline_size", 4)
	header.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.85))
	header.add_theme_constant_override("shadow_offset_x", 1)
	header.add_theme_constant_override("shadow_offset_y", 2)
	_v.add_child(header)
	# Subtle gold separator line between header and objectives
	var sep := ColorRect.new()
	sep.color = Color(0.78, 0.62, 0.28, 0.55)
	sep.custom_minimum_size = Vector2(0, 1)
	_v.add_child(sep)
	# Objectives list — pull live counters from QuestRegistry.get_progress
	var objectives: Array = []
	var quest_id: StringName = &""
	if typeof(focused) == TYPE_DICTIONARY:
		objectives = focused.get("objectives_data", [])
		quest_id = StringName(focused.get("id", ""))
	else:
		objectives = focused.objectives_data
		quest_id = focused.id
	var counters: Array = []
	if _registry.has_method("get_progress"):
		counters = _registry.get_progress(quest_id)
	for i in range(objectives.size()):
		var current: int = counters[i] if i < counters.size() else 0
		_v.add_child(_objective_row(objectives[i], current))

func _objective_row(obj: Dictionary, current_count: int) -> Control:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 6)
	var required: int = int(obj.get("required_count", 1))
	var done: bool = current_count >= required
	var bullet := Label.new()
	bullet.text = "✓" if done else "•"
	bullet.add_theme_color_override("font_color", Color(0.45, 0.95, 0.55) if done else Color(0.85, 0.78, 0.55))
	bullet.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.92))
	bullet.add_theme_constant_override("outline_size", 3)
	bullet.add_theme_font_size_override("font_size", 14)
	row.add_child(bullet)
	var lbl := Label.new()
	lbl.text = "%s [%d / %d]" % [obj.get("description", ""), current_count, required]
	lbl.add_theme_font_size_override("font_size", 13)
	lbl.add_theme_color_override("font_color", Color(0.95, 0.92, 0.85) if not done else Color(0.55, 0.85, 0.55))
	lbl.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.85))
	lbl.add_theme_constant_override("outline_size", 3)
	lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	lbl.size_flags_horizontal = SIZE_EXPAND_FILL
	row.add_child(lbl)
	return row

func _on_quest_changed(_q: Variant) -> void:
	refresh()

func _on_progress(_q: Variant, _idx: int, _count: int) -> void:
	refresh()
