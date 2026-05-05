extends Control

# Equipment paper-doll. Displays the 13 equipment slots arranged around a
# silhouette of the character. Click a slot -> open inventory filtered to
# items that fit. Drag-and-drop will land in a future iteration.

const SLOT_PX: Vector2 = Vector2(56, 56)

# Visual layout offsets relative to the central silhouette.
# y- is up; x+ is right.
const SLOT_LAYOUT := {
	&"head":           Vector2(0, -130),
	&"amulet":         Vector2(0, -75),
	&"chest":          Vector2(0, -10),
	&"belt":           Vector2(0, 50),
	&"legs":           Vector2(0, 105),
	&"feet":           Vector2(0, 165),
	&"hands":          Vector2(-90, 30),
	&"weapon_main":    Vector2(-150, -20),
	&"weapon_offhand": Vector2(150, -20),
	&"back":           Vector2(0, 5),
	&"ring_left":      Vector2(-90, 80),
	&"ring_right":     Vector2(90, 80),
	&"charm":          Vector2(90, 30),
}

const SLOT_TO_ENUM := {
	&"weapon_main":    1,
	&"weapon_offhand": 2,
	&"head":           3,
	&"chest":          4,
	&"legs":           5,
	&"feet":           6,
	&"hands":          7,
	&"back":           8,
	&"belt":           9,
	&"ring_left":      10,
	&"ring_right":     11,
	&"amulet":         12,
	&"charm":          13,
}

var _player: Node = null
var _slots: Dictionary = {}

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_PASS
	_player = get_tree().get_first_node_in_group("player")
	var title := Label.new()
	title.text = "Equipment"
	title.add_theme_font_size_override("font_size", 22)
	add_child(title)

	var center := Control.new()
	center.anchor_left = 0.5
	center.anchor_top = 0.5
	center.anchor_right = 0.5
	center.anchor_bottom = 0.5
	add_child(center)

	for slot_name in SLOT_LAYOUT.keys():
		var slot := _make_slot(slot_name)
		var off: Vector2 = SLOT_LAYOUT[slot_name]
		slot.position = off - SLOT_PX * 0.5
		center.add_child(slot)
		_slots[slot_name] = slot

	refresh()

func refresh() -> void:
	if _player == null:
		_player = get_tree().get_first_node_in_group("player")
	for slot_name in _slots.keys():
		var slot: Control = _slots[slot_name]
		var item: Item = _read_equipped(slot_name)
		_paint_slot(slot, item, slot_name)

func _read_equipped(slot_name: StringName) -> Item:
	if _player == null or _player.inventory == null:
		return null
	if _player.inventory.has_method("get_equipped"):
		return _player.inventory.get_equipped(SLOT_TO_ENUM[slot_name])
	# Fallback: equipment dictionary lookup
	var eq = _player.inventory.get("equipment") if _player.inventory.has_method("get") else null
	if typeof(eq) == TYPE_DICTIONARY:
		return eq.get(SLOT_TO_ENUM[slot_name], null)
	return null

func _make_slot(slot_name: StringName) -> Control:
	var slot := PanelContainer.new()
	slot.custom_minimum_size = SLOT_PX
	slot.size = SLOT_PX
	var bg := ColorRect.new()
	bg.color = Color(0.08, 0.08, 0.12, 0.9)
	bg.anchor_right = 1.0
	bg.anchor_bottom = 1.0
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	slot.add_child(bg)
	var icon := TextureRect.new()
	icon.name = "Icon"
	icon.expand_mode = TextureRect.EXPAND_FIT_WIDTH_PROPORTIONAL
	icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	icon.anchor_right = 1.0
	icon.anchor_bottom = 1.0
	icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	slot.add_child(icon)
	var caption := Label.new()
	caption.name = "Caption"
	caption.text = String(slot_name).replace("_", " ")
	caption.add_theme_font_size_override("font_size", 9)
	caption.modulate = Color(0.6, 0.6, 0.6)
	caption.anchor_top = 1.0
	caption.anchor_bottom = 1.0
	caption.offset_top = 2.0
	slot.add_child(caption)
	return slot

func _paint_slot(slot: Control, item: Item, slot_name: StringName) -> void:
	var icon: TextureRect = slot.get_node("Icon")
	if item == null:
		icon.texture = null
		slot.tooltip_text = "%s — empty" % String(slot_name).replace("_", " ")
		return
	var atlas: Node = get_node_or_null("/root/IconAtlas")
	if atlas and atlas.has_method("get_icon_for_item"):
		icon.texture = atlas.get_icon_for_item(item)
	else:
		icon.texture = item.icon
	slot.tooltip_text = "%s\n%s" % [item.display_name, item.description]
