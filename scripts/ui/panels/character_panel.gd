extends Control

# Character sheet: name, class, level, primary attributes, derived stats,
# resistances, prestige cycle. Includes the Allocate section where
# pending attribute points get spent. Click "+" next to an attribute
# row to invest one point; calls PlayerAttributes.spend() and triggers
# a derived-stat recompute on the player's stats.

# Order matches PlayerAttributes.ATTRIBUTE_NAMES so the panel reads in
# the same sequence as the data layer. Each row shows the current spent
# value plus a "+" button when pending_points > 0.
const SPENDABLE_ATTRIBUTES := [
	{"id": &"health",     "label": "Health"},
	{"id": &"stamina",    "label": "Stamina"},
	{"id": &"mana",       "label": "Mana"},
	{"id": &"strength",   "label": "Strength"},
	{"id": &"accuracy",   "label": "Accuracy"},
	{"id": &"spellpower", "label": "Spellpower"},
	{"id": &"wisdom",     "label": "Wisdom"},
	{"id": &"vitality",   "label": "Vitality"},
	{"id": &"endurance",  "label": "Endurance"},
	{"id": &"luck",       "label": "Luck"},
]

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
	hdr.add_child(_label_big(_player.character_name if "character_name" in _player else "Champion"))
	var class_id: String = String(s.class_def.class_id) if s.class_def else "no_class"
	hdr.add_child(_label("  · " + class_id.capitalize()))
	hdr.add_child(_label("  · Lv " + str(s.level)))

	_v.add_child(_separator())

	# Primary attributes (PlayerStats fields, see scripts/player/player_stats.gd)
	_v.add_child(_section("Attributes"))
	_v.add_child(_pair("Strength",  str(int(s.strength))))
	_v.add_child(_pair("Dexterity", str(int(s.dexterity))))
	_v.add_child(_pair("Intellect", str(int(s.intellect))))
	_v.add_child(_pair("Vitality",  str(int(s.vitality))))
	_v.add_child(_pair("Wisdom",    str(int(s.wisdom))))
	_v.add_child(_pair("Luck",      str(int(s.luck))))
	_v.add_child(_pair("Endurance", str(int(s.endurance))))

	_v.add_child(_separator())

	# Derived stats
	_v.add_child(_section("Vitals"))
	_v.add_child(_pair("HP",      "%d / %d" % [int(s.hp), int(s.max_hp)]))
	_v.add_child(_pair("Mana",    "%d / %d" % [int(s.mana), int(s.max_mana)]))
	_v.add_child(_pair("Stamina", "%d / %d" % [int(s.stamina), int(s.max_stamina)]))
	_v.add_child(_pair("XP",      "%d / next" % int(s.xp)))

	_v.add_child(_separator())

	# Allocate: lets the player spend PlayerAttributes.pending_points.
	# Until this commit, attribute points awarded at even levels were
	# silently accruing in PlayerAttributes with no way to invest them.
	if s.attributes:
		var pending: int = int(s.attributes.pending_points)
		var alloc_hdr := "Allocate"
		if pending > 0:
			alloc_hdr += "  (+%d available)" % pending
		_v.add_child(_section(alloc_hdr))
		for ent in SPENDABLE_ATTRIBUTES:
			_v.add_child(_alloc_row(s.attributes, ent.id, ent.label, pending))

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

# Build one allocate row: label + spent value + "+" button.
# Button is hidden when pending is 0 so the row reads as a stat snapshot
# rather than an interactive control until points are actually available.
func _alloc_row(attrs, attr_id: StringName, label: String, pending: int) -> Control:
	var row := HBoxContainer.new()
	var key := Label.new()
	key.text = label
	key.custom_minimum_size = Vector2(140, 0)
	row.add_child(key)
	var val := Label.new()
	val.text = str(attrs.get_value(attr_id))
	val.custom_minimum_size = Vector2(40, 0)
	row.add_child(val)
	if pending > 0:
		var btn := Button.new()
		btn.text = "+"
		btn.custom_minimum_size = Vector2(30, 0)
		btn.pressed.connect(_on_spend_pressed.bind(attr_id))
		row.add_child(btn)
	return row

# Spend one point. Calls PlayerAttributes.spend which decrements the
# pool + emits point_spent. Then trigger a stat recompute so the
# baseline + bonuses re-derive (the player's effective stats update
# immediately rather than waiting for the next level-up tick). Refresh
# the panel so the new spent count + remaining-pool number show up
# without the player having to close + reopen.
func _on_spend_pressed(attr_id: StringName) -> void:
	if _player == null or _player.stats == null or _player.stats.attributes == null:
		return
	if not _player.stats.attributes.spend(attr_id, 1):
		return
	if _player.stats.has_method("recompute_derived"):
		_player.stats.recompute_derived(_player.inventory if "inventory" in _player else null)
	# Audio: gear-on cue at +20% pitch for the satisfying allocation click
	var ab: Node = get_node_or_null("/root/AudioBus")
	if ab and ab.has_method("play_cue"):
		ab.play_cue(&"pickup", _player.global_position, -12.0, 1.4)
	refresh()
