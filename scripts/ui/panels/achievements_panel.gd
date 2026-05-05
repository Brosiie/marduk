extends Control

# Achievements tab: scrollable list of all achievements with unlock states.
# Reads from AchievementRegistry autoload.

var _v: VBoxContainer

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_PASS

	var title := Label.new()
	title.text = "Achievements"
	title.add_theme_font_size_override("font_size", 22)
	add_child(title)

	var scroll := ScrollContainer.new()
	scroll.anchor_left = 0.0
	scroll.anchor_top = 0.07
	scroll.anchor_right = 1.0
	scroll.anchor_bottom = 1.0
	add_child(scroll)

	_v = VBoxContainer.new()
	_v.add_theme_constant_override("separation", 4)
	scroll.add_child(_v)

	refresh()

func refresh() -> void:
	for c in _v.get_children():
		c.queue_free()
	var ar := get_node_or_null("/root/AchievementRegistry")
	if ar == null:
		_v.add_child(_label("(AchievementRegistry not loaded)"))
		return

	var unlocked: Array = []
	if ar.has_method("get_unlocked_ids"):
		unlocked = ar.get_unlocked_ids()
	var all_records: Array = []
	if ar.has_method("get_all"):
		all_records = ar.get_all()
	if all_records.is_empty():
		_v.add_child(_label("No achievements registered yet."))
		return

	var unlocked_count: int = unlocked.size()
	var summary := Label.new()
	summary.text = "Unlocked %d / %d" % [unlocked_count, all_records.size()]
	summary.add_theme_font_size_override("font_size", 14)
	summary.modulate = Color(0.95, 0.85, 0.30)
	_v.add_child(summary)

	for rec in all_records:
		_v.add_child(_card(rec, unlocked))

func _card(rec: Variant, unlocked: Array) -> Control:
	var box := PanelContainer.new()
	var h := HBoxContainer.new()
	box.add_child(h)
	var dot := ColorRect.new()
	dot.custom_minimum_size = Vector2(12, 12)
	var rec_id: StringName = rec.get("id") if typeof(rec) == TYPE_DICTIONARY else (rec.id if rec.has_method("get") else &"")
	dot.color = Color(0.3, 0.95, 0.5) if rec_id in unlocked else Color(0.4, 0.4, 0.4)
	h.add_child(dot)
	var v := VBoxContainer.new()
	h.add_child(v)
	var name := Label.new()
	name.text = rec.get("display_name") if typeof(rec) == TYPE_DICTIONARY else (rec.display_name if rec.has_method("get") else "Achievement")
	name.add_theme_font_size_override("font_size", 12)
	v.add_child(name)
	var desc := Label.new()
	desc.text = rec.get("description") if typeof(rec) == TYPE_DICTIONARY else (rec.description if rec.has_method("get") else "")
	desc.modulate = Color(0.7, 0.7, 0.7)
	desc.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	v.add_child(desc)
	return box

func _label(t: String) -> Label:
	var l := Label.new()
	l.text = t
	return l
