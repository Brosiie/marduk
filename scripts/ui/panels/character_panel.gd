extends Control

# Character sheet: name, class, level, primary attributes, derived stats,
# resistances, prestige cycle. Read-only for now; level-up attribute spend
# will route through here in a later pass.

var _player: Node = null
var _v: VBoxContainer

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_PASS
	_player = get_tree().get_first_node_in_group("player")

	var title := Label.new()
	title.text = "Character"
	title.add_theme_font_size_override("font_size", 22)
	add_child(title)

	_v = VBoxContainer.new()
	_v.anchor_left = 0.05
	_v.anchor_top = 0.1
	_v.anchor_right = 0.95
	_v.anchor_bottom = 0.95
	add_child(_v)

	refresh()

func refresh() -> void:
	for child in _v.get_children():
		child.queue_free()

	if _player == null or _player.stats == null:
		_v.add_child(_label("(no player loaded)"))
		return

	var s = _player.stats

	var hdr := HBoxContainer.new()
	_v.add_child(hdr)
	hdr.add_child(_label_big(_player.character_name if _player.has("character_name") else "Champion"))
	var class_id: String = String(s.class_def.class_id) if s.class_def else "no_class"
	hdr.add_child(_label("  · " + class_id.capitalize()))
	hdr.add_child(_label("  · Lv " + str(s.level)))

	_v.add_child(_separator())

	# Primary attributes
	_v.add_child(_section("Attributes"))
	_v.add_child(_pair("Strength",     str(s.strength)))
	_v.add_child(_pair("Dexterity",    str(s.dexterity)))
	_v.add_child(_pair("Constitution", str(s.constitution)))
	_v.add_child(_pair("Intelligence", str(s.intelligence)))
	_v.add_child(_pair("Wisdom",       str(s.wisdom)))
	_v.add_child(_pair("Charisma",     str(s.charisma) if s.has_method("get") and "charisma" in s else "-"))

	_v.add_child(_separator())

	# Derived stats
	_v.add_child(_section("Vitals"))
	_v.add_child(_pair("HP",        "%d / %d" % [int(s.hp), int(s.max_hp)]))
	_v.add_child(_pair("Mana",      "%d / %d" % [int(s.mana), int(s.max_mana)]))
	_v.add_child(_pair("Armor",     "%d" % int(s.armor) if "armor" in s else "-"))
	_v.add_child(_pair("Crit",      "%.1f%%" % (s.crit_chance * 100.0) if "crit_chance" in s else "-"))

	_v.add_child(_separator())

	# Prestige
	var p = get_node_or_null("/root/Prestige")
	if p:
		_v.add_child(_section("Prestige"))
		_v.add_child(_pair("Cycle", str(p.current_prestige_level()) if p.has_method("current_prestige_level") else "-"))
		_v.add_child(_pair("Difficulty", "%.1fx" % p.difficulty_multiplier() if p.has_method("difficulty_multiplier") else "-"))

func _label(t: String) -> Label:
	var l := Label.new()
	l.text = t
	return l

func _label_big(t: String) -> Label:
	var l := Label.new()
	l.text = t
	l.add_theme_font_size_override("font_size", 18)
	return l

func _section(t: String) -> Label:
	var l := Label.new()
	l.text = t
	l.add_theme_font_size_override("font_size", 14)
	l.modulate = Color(0.95, 0.85, 0.30)
	return l

func _pair(k: String, v: String) -> Control:
	var row := HBoxContainer.new()
	var key := Label.new()
	key.text = k
	key.custom_minimum_size = Vector2(140, 0)
	row.add_child(key)
	var val := Label.new()
	val.text = v
	row.add_child(val)
	return row

func _separator() -> Control:
	var sep := HSeparator.new()
	return sep
