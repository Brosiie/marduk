extends Control

# Quest log: lists active and completed quests with description + progress.
# Reads from QuestRegistry autoload.

var _v: VBoxContainer

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_PASS

	var title := Label.new()
	title.text = "Quests"
	title.add_theme_font_size_override("font_size", 22)
	add_child(title)

	var scroll := ScrollContainer.new()
	scroll.anchor_left = 0.0
	scroll.anchor_top = 0.07
	scroll.anchor_right = 1.0
	scroll.anchor_bottom = 1.0
	add_child(scroll)

	_v = VBoxContainer.new()
	scroll.add_child(_v)
	_v.add_theme_constant_override("separation", 8)

	refresh()

func refresh() -> void:
	for c in _v.get_children():
		c.queue_free()
	var qr := get_node_or_null("/root/QuestRegistry")
	if qr == null:
		_v.add_child(_label("(QuestRegistry not loaded)"))
		return
	var active: Array = qr.get_active_quests() if qr.has_method("get_active_quests") else []
	var completed: Array = qr.get_completed_quests() if qr.has_method("get_completed_quests") else []
	if active.is_empty() and completed.is_empty():
		_v.add_child(_label("No quests available yet. Talk to NPCs in Ashurim or visit landmarks."))
		return
	if not active.is_empty():
		_v.add_child(_section("Active"))
		for q in active:
			_v.add_child(_quest_card(q, false))
	if not completed.is_empty():
		_v.add_child(_section("Completed"))
		for q in completed:
			_v.add_child(_quest_card(q, true))

func _quest_card(q: Variant, completed: bool) -> Control:
	var box := PanelContainer.new()
	var v := VBoxContainer.new()
	box.add_child(v)
	var name := Label.new()
	var qname: String = q.get("display_name") if typeof(q) == TYPE_DICTIONARY else (q.display_name if q.has_method("get") else "Quest")
	name.text = qname
	name.add_theme_font_size_override("font_size", 14)
	if completed:
		name.modulate = Color(0.6, 0.95, 0.6)
	v.add_child(name)
	var desc := Label.new()
	desc.text = q.get("description") if typeof(q) == TYPE_DICTIONARY else (q.description if q.has_method("get") else "")
	desc.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	v.add_child(desc)
	return box

func _label(t: String) -> Label:
	var l := Label.new()
	l.text = t
	return l

func _section(t: String) -> Label:
	var l := Label.new()
	l.text = t
	l.modulate = Color(0.95, 0.85, 0.30)
	l.add_theme_font_size_override("font_size", 14)
	return l
