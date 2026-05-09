extends Control

# Inventory grid panel: 6x8 slot grid that paints each slot as the item's
# icon (via IconAtlas) with a quantity badge. Rebuilds whenever the player's
# inventory.changed signal fires.

const COLS: int = 8
const ROWS: int = 6
const SLOT_PX: Vector2 = Vector2(56, 56)
const SLOT_GAP: int = 4

var _grid: GridContainer
var _slots: Array = []  # Array[Control]
var _player: Node = null
var _hover_label: Label = null

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_PASS
	_player = get_tree().get_first_node_in_group("player")

	# Polished frame matching the rest of the HUD — gold filigree
	# border + drop shadow + dark slate bg. Was a bare VBoxContainer
	# floating over the menu background.
	var bg := PanelContainer.new()
	bg.anchor_right = 1.0
	bg.anchor_bottom = 1.0
	var bg_sb := StyleBoxFlat.new()
	bg_sb.bg_color = Color(0.05, 0.04, 0.06, 0.95)
	bg_sb.border_color = Color(0.78, 0.62, 0.28, 0.95)
	bg_sb.set_border_width_all(2)
	bg_sb.border_width_top = 3
	bg_sb.set_corner_radius_all(6)
	bg_sb.shadow_color = Color(0, 0, 0, 0.65)
	bg_sb.shadow_size = 6
	bg_sb.shadow_offset = Vector2(0, 3)
	bg_sb.content_margin_left = 16
	bg_sb.content_margin_right = 16
	bg_sb.content_margin_top = 14
	bg_sb.content_margin_bottom = 14
	bg.add_theme_stylebox_override("panel", bg_sb)
	add_child(bg)

	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 10)
	bg.add_child(v)

	var title := Label.new()
	title.text = "Inventory"
	title.add_theme_font_size_override("font_size", 26)
	title.add_theme_color_override("font_color", Color(1.0, 0.92, 0.55))
	title.add_theme_color_override("font_outline_color", Color(0.20, 0.05, 0.05, 1.0))
	title.add_theme_constant_override("outline_size", 4)
	title.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.85))
	title.add_theme_constant_override("shadow_offset_x", 1)
	title.add_theme_constant_override("shadow_offset_y", 2)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(title)
	# Gold filigree separator under the title
	var sep := ColorRect.new()
	sep.color = Color(0.78, 0.62, 0.28, 0.55)
	sep.custom_minimum_size = Vector2(0, 1)
	v.add_child(sep)

	_grid = GridContainer.new()
	_grid.columns = COLS
	_grid.add_theme_constant_override("h_separation", SLOT_GAP)
	_grid.add_theme_constant_override("v_separation", SLOT_GAP)
	v.add_child(_grid)

	for i in range(COLS * ROWS):
		var s := _make_slot()
		_slots.append(s)
		_grid.add_child(s)

	_hover_label = Label.new()
	_hover_label.add_theme_font_size_override("font_size", 14)
	_hover_label.add_theme_color_override("font_color", Color(0.95, 0.92, 0.85))
	_hover_label.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.85))
	_hover_label.add_theme_constant_override("outline_size", 3)
	v.add_child(_hover_label)

	if _player and _player.inventory and _player.inventory.has_signal("changed"):
		_player.inventory.changed.connect(refresh)
	refresh()

func refresh() -> void:
	if _player == null:
		_player = get_tree().get_first_node_in_group("player")
	var slots_data: Array = _read_inventory_slots()
	for i in range(_slots.size()):
		var slot: Control = _slots[i]
		var item: Item = slots_data[i].get("item", null) if i < slots_data.size() else null
		var qty: int = slots_data[i].get("count", 1) if i < slots_data.size() else 0
		_paint_slot(slot, item, qty)

func _read_inventory_slots() -> Array:
	if _player == null or _player.inventory == null:
		return []
	if _player.inventory.has_method("get_slots"):
		return _player.inventory.get_slots()
	# Fallback: try .slots property
	var slots = _player.inventory.get("slots") if _player.inventory.has_method("get") else null
	if typeof(slots) == TYPE_ARRAY:
		return slots
	return []

func _make_slot() -> Control:
	var slot := PanelContainer.new()
	slot.custom_minimum_size = SLOT_PX
	var bg := ColorRect.new()
	bg.color = Color(0.1, 0.1, 0.13, 0.95)
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
	icon.mouse_filter = Control.MOUSE_FILTER_PASS
	slot.add_child(icon)
	var qty := Label.new()
	qty.name = "Qty"
	qty.anchor_left = 1.0
	qty.anchor_top = 1.0
	qty.anchor_right = 1.0
	qty.anchor_bottom = 1.0
	qty.offset_left = -22.0
	qty.offset_top = -16.0
	qty.add_theme_font_size_override("font_size", 11)
	qty.modulate = Color(1, 1, 0.6)
	slot.add_child(qty)
	return slot

func _paint_slot(slot: Control, item: Item, qty: int) -> void:
	var icon: TextureRect = slot.get_node("Icon")
	var label: Label = slot.get_node("Qty")
	if item == null:
		icon.texture = null
		label.text = ""
		slot.tooltip_text = ""
		return
	var atlas: Node = get_node_or_null("/root/IconAtlas")
	if atlas and atlas.has_method("get_icon_for_item"):
		icon.texture = atlas.get_icon_for_item(item)
	else:
		icon.texture = item.icon
	label.text = ("x%d" % qty) if qty > 1 else ""
	slot.tooltip_text = "%s\n%s" % [item.display_name, item.description]
