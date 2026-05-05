extends Resource
class_name Dialogue

# Branching dialogue tree resource. Lines have speaker + text + optional choices.
# Choices may have requirements (level, class, faction, flag) and effects (set flag,
# start quest, give item, lock node).

class Line:
	var id: StringName = &""
	var speaker: String = ""
	var text: String = ""
	var choices: Array = []  # of Choice. Empty = auto-advance to `next_id`.
	var next_id: StringName = &""  # auto-advance target
	var on_show_set_flag: StringName = &""  # set when reached
	var on_show_starts_quest: StringName = &""

class Choice:
	var label: String = ""
	var next_id: StringName = &""
	var require_class: Array[StringName] = []
	var require_min_level: int = 0
	var require_run_flag: StringName = &""
	var require_permanent_flag: StringName = &""
	var require_item_id: StringName = &""
	var require_quest_completed: StringName = &""
	var sets_run_flag: StringName = &""
	var sets_permanent_flag: StringName = &""
	var starts_quest_id: StringName = &""
	var ends_dialogue: bool = false

@export var id: StringName = &""
@export var npc_id: StringName = &""
@export var entry_line_id: StringName = &""
@export var lines_data: Array = []  # serialized lines and choices

func get_entry() -> Line:
	for d in lines_data:
		if StringName(d.get("id", "")) == entry_line_id:
			return _make_line(d)
	if lines_data.size() > 0:
		return _make_line(lines_data[0])
	return null

func get_line(line_id: StringName) -> Line:
	for d in lines_data:
		if StringName(d.get("id", "")) == line_id:
			return _make_line(d)
	return null

func _make_line(d: Dictionary) -> Line:
	var l := Line.new()
	l.id = StringName(d.get("id", ""))
	l.speaker = d.get("speaker", "")
	l.text = d.get("text", "")
	l.next_id = StringName(d.get("next_id", ""))
	l.on_show_set_flag = StringName(d.get("on_show_set_flag", ""))
	l.on_show_starts_quest = StringName(d.get("on_show_starts_quest", ""))
	for cd in d.get("choices", []):
		var c := Choice.new()
		c.label = cd.get("label", "")
		c.next_id = StringName(cd.get("next_id", ""))
		c.require_min_level = int(cd.get("require_min_level", 0))
		c.require_run_flag = StringName(cd.get("require_run_flag", ""))
		c.require_permanent_flag = StringName(cd.get("require_permanent_flag", ""))
		c.require_item_id = StringName(cd.get("require_item_id", ""))
		c.require_quest_completed = StringName(cd.get("require_quest_completed", ""))
		c.sets_run_flag = StringName(cd.get("sets_run_flag", ""))
		c.sets_permanent_flag = StringName(cd.get("sets_permanent_flag", ""))
		c.starts_quest_id = StringName(cd.get("starts_quest_id", ""))
		c.ends_dialogue = bool(cd.get("ends_dialogue", false))
		for cls in cd.get("require_class", []):
			c.require_class.append(StringName(cls))
		l.choices.append(c)
	return l
