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
	# Live refresh: subscribe to Inventory's mutation signals so the
	# panel updates without the player having to close + reopen. Without
	# this, picking up a quest reward while the panel is open left the
	# bag visually stale until next interaction.
	if _player and _player.inventory:
		var inv = _player.inventory
		if inv.has_signal("inventory_changed") and not inv.inventory_changed.is_connected(refresh):
			inv.inventory_changed.connect(refresh)
		if inv.has_signal("equipment_changed") and not inv.equipment_changed.is_connected(_on_equipment_changed):
			inv.equipment_changed.connect(_on_equipment_changed)

# Equipment changes touch BOTH the equipped panel area AND the bag
# (returned items go back to bag). Refresh the whole inventory panel
# so both halves stay in sync.
func _on_equipment_changed(_slot: int, _item) -> void:
	refresh()

	# Polished frame matching the rest of the HUD, gold filigree
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
	# InventorySlot is a PanelContainer subclass that overrides
	# _make_custom_tooltip so the hover card is a styled BBCode panel
	# (rarity-colored title + green/red diff arrows) instead of the
	# engine's plain-text tooltip. Falls back to PanelContainer if the
	# slot script isn't available so legacy panels still render.
	var slot_script: GDScript = load("res://scripts/ui/components/inventory_slot.gd")
	var slot: PanelContainer
	if slot_script:
		slot = slot_script.new()
	else:
		slot = PanelContainer.new()
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
	# Click handling. Routes through _on_slot_input on the panel so the
	# slot stays a dumb display while equip/consume logic lives where
	# it has access to inventory + player + audio. Until this commit,
	# inventory slots had no input handler at all and the player had no
	# way to equip items from the bag (auto-equip on pickup only fires
	# for weapons; armor/rings/consumables were stranded).
	slot.gui_input.connect(_on_slot_input.bind(slot))
	slot.mouse_filter = Control.MOUSE_FILTER_PASS
	return slot

# Per-slot input router. Left-click = equip equippable items OR consume
# consumables. Right-click = discard (drops one unit on the ground at
# the player's feet). Other inputs fall through to the engine's tooltip
# layer.
func _on_slot_input(event: InputEvent, slot: Control) -> void:
	if not (event is InputEventMouseButton) or not event.pressed:
		return
	if not "item" in slot:
		return
	var item = slot.item
	if item == null:
		return
	var mb := event as InputEventMouseButton
	if mb.button_index == MOUSE_BUTTON_LEFT:
		_try_use_or_equip(item)
	elif mb.button_index == MOUSE_BUTTON_RIGHT:
		_try_discard(item)

func _try_use_or_equip(item) -> void:
	if not _player or not _player.inventory:
		return
	# Consumables: trigger their use path. Heal potions, mana potions,
	# scrolls, etc. Player.use_potion handles HP + mana + status grants
	# and returns true if a consumption fired. On true, decrement the
	# stack so the player can see the count drop.
	if item.slot == Item.Slot.NONE and (item.heal_amount > 0.0 or item.mana_amount > 0.0 or item.grants_status != null):
		var used: bool = false
		if _player.has_method("use_potion"):
			used = _player.use_potion(item)
		if used and _player.inventory.has_method("remove_item"):
			_player.inventory.remove_item(item.id, 1)
		refresh()
		return
	# Equippables: route through Inventory.equip with the player's class
	# def so can_equip gates work + equip_blocked toast (added in HUD)
	# fires for invalid attempts.
	if item.slot == Item.Slot.NONE:
		return
	var class_def = _player.stats.class_def if _player.stats else null
	var prev = _player.inventory.equip(item, -1, class_def)
	# If equip succeeded, the picked-up item moves bag -> equipped slot;
	# the displaced item (if any) returns to bag. Refresh the panel so
	# the row layout reflects the swap.
	refresh()
	# Audio: gear-on cue at +20% pitch for the satisfying "click"
	var ab: Node = get_node_or_null("/root/AudioBus")
	if ab and ab.has_method("play_cue") and prev != null:
		ab.play_cue(&"pickup", _player.global_position, -10.0, 1.3)

func _try_discard(item) -> void:
	if not _player or not _player.inventory:
		return
	if item.is_soulbound or item.is_quest_item:
		var juice: Node = get_node_or_null("/root/Juice")
		if juice and juice.has_method("toast"):
			juice.toast("Cannot discard %s." % item.display_name, Color(0.95, 0.55, 0.30), 2.0)
		return
	if _player.inventory.has_method("remove_item"):
		_player.inventory.remove_item(item.id, 1)
	refresh()

func _paint_slot(slot: Control, item: Item, qty: int) -> void:
	var icon: TextureRect = slot.get_node("Icon")
	var label: Label = slot.get_node("Qty")
	if item == null:
		icon.texture = null
		label.text = ""
		slot.tooltip_text = ""
		# Clear any previous item from custom-tooltip slot so the rich
		# tooltip stops appearing after a slot empties.
		if "item" in slot:
			slot.set("item", null)
		if "equipped_compare" in slot:
			slot.set("equipped_compare", null)
		return
	var atlas: Node = get_node_or_null("/root/IconAtlas")
	if atlas and atlas.has_method("get_icon_for_item"):
		icon.texture = atlas.get_icon_for_item(item)
	else:
		icon.texture = item.icon
	label.text = ("x%d" % qty) if qty > 1 else ""
	# Custom-tooltip path: set the item + currently-equipped comparator
	# on the slot so InventorySlot._make_custom_tooltip can render the
	# styled BBCode card. The plain-text tooltip_text is kept as a
	# fallback for slots that aren't InventorySlot.
	if "item" in slot:
		slot.set("item", item)
		var equipped: Item = null
		if _player and _player.inventory and _player.inventory.has_method("equipped_in") and item.slot != Item.Slot.NONE:
			equipped = _player.inventory.equipped_in(item.slot)
		if "equipped_compare" in slot:
			slot.set("equipped_compare", equipped)
		# Engine still calls tooltip_text-based path during the brief
		# moment before _make_custom_tooltip fires, set a non-empty
		# string so the tooltip surfaces at all. Content is the same
		# plain-text we used to ship.
		slot.tooltip_text = " "  # one space: engine needs non-empty to surface, but the rich card replaces it
	else:
		slot.tooltip_text = _compose_tooltip(item)

# Builds a plain-text tooltip with rarity, slot/weapon type, stats, bonuses,
# and an equip-compare diff against the currently-equipped item in the same
# slot. Plain text (no BBCode), Godot's slot tooltips don't render markup,
# so we use ASCII +/-/= prefixes for the diff to read at a glance.
func _compose_tooltip(item: Item) -> String:
	var lines: Array[String] = []
	# Header: name + rarity tag
	var rarity_tag: String = item.rarity_name() if item.has_method("rarity_name") else ""
	lines.append("%s%s" % [item.display_name, "  (" + rarity_tag + ")" if rarity_tag != "" else ""])

	# Sub-line: slot + weapon/armor type + item level + soulbound flag
	var subs: Array[String] = []
	if item.weapon_type != Item.WeaponType.NONE and item.has_method("weapon_type_name"):
		subs.append(item.weapon_type_name())
	if item.armor_type != Item.ArmorType.NONE:
		match item.armor_type:
			Item.ArmorType.CLOTH:   subs.append("Cloth")
			Item.ArmorType.LEATHER: subs.append("Leather")
			Item.ArmorType.MAIL:    subs.append("Mail")
			Item.ArmorType.PLATE:   subs.append("Plate")
	if item.item_level > 0:
		subs.append("Item lvl %d" % item.item_level)
	if item.is_soulbound:
		subs.append("Soulbound")
	if item.is_two_handed:
		subs.append("Two-Handed")
	if not subs.is_empty():
		lines.append("  ·  ".join(subs))

	# Weapon stats line
	if item.is_weapon():
		var w_bits: Array[String] = []
		w_bits.append("%d dmg" % int(item.base_damage))
		if item.attack_speed != 1.0:
			w_bits.append("%.2fx spd" % item.attack_speed)
		if item.weapon_range > 0:
			w_bits.append("%.1fm reach" % item.weapon_range)
		if item.element != Item.Element.PHYSICAL and item.element_damage_pct > 0:
			w_bits.append("+%d%% %s" % [int(item.element_damage_pct * 100), item.element_name() if item.has_method("element_name") else ""])
		lines.append("  ·  ".join(w_bits))

	# Bonuses (only non-zero shown)
	var bonus_lines: Array[String] = _format_bonuses(item)
	for b in bonus_lines:
		lines.append(b)

	# Affix lines: every rolled prefix + suffix with its bonus text.
	# The base bonuses above come from the item's own @export fields; the
	# affix block here is the procedural roll layered on top by LootTable.
	# Player sees, for "Heavy Trial Blade of Precision":
	#   Heavy:        +8 Str, +5% Damage
	#   of Precision: +6% Crit Chance, +12% Crit Multiplier
	var affix_lines: Array[String] = _format_affix_lines(item)
	if not affix_lines.is_empty():
		lines.append("")  # spacer
		for a in affix_lines:
			lines.append(a)

	# Class restriction
	if item.class_restriction.size() > 0:
		var class_names: Array[String] = []
		for c in item.class_restriction:
			class_names.append(String(c).capitalize())
		lines.append("Class: %s only" % ", ".join(class_names))

	# Implicit + description
	if item.implicit_text != "":
		lines.append("")
		lines.append(item.implicit_text)
	if item.description != "":
		lines.append("")
		lines.append(item.description)

	# Equip-compare against currently-equipped item in the same slot
	var compare: String = _compose_compare(item)
	if compare != "":
		lines.append("")
		lines.append(compare)

	return "\n".join(lines)

# Returns a list of "+N stat" strings for non-zero bonuses on the item.
func _format_bonuses(item: Item) -> Array[String]:
	var out: Array[String] = []
	var checks := [
		["hp_bonus",            "HP",         "%+d"],
		["mana_bonus",          "Mana",       "%+d"],
		["strength_bonus",      "Str",        "%+d"],
		["dexterity_bonus",     "Dex",        "%+d"],
		["intellect_bonus",     "Int",        "%+d"],
		["vitality_bonus",      "Vit",        "%+d"],
		["armor_bonus",         "Armor",      "%+d"],
		["magic_resist_bonus",  "MR",         "%+d"],
		["crit_chance_bonus",   "Crit",       "%+.0f%%"],
		["crit_multiplier_bonus","Crit Mult", "%+.0f%%"],
		["damage_bonus_pct",    "Dmg",        "%+.0f%%"],
		["attack_speed_bonus",  "Atk Spd",    "%+.0f%%"],
		["move_speed_bonus",    "Move Spd",   "%+.0f%%"],
	]
	var line_bits: Array[String] = []
	for check in checks:
		var key: String = check[0]
		var label: String = check[1]
		var fmt: String = check[2]
		var v: float = float(item.get(key)) if item.get(key) != null else 0.0
		if v == 0.0:
			continue
		# Percent-style fields are stored as 0..1 fractions
		if fmt.ends_with("%%"):
			line_bits.append("%s %s" % [fmt % (v * 100.0), label])
		else:
			line_bits.append("%s %s" % [fmt % int(v), label])
	if not line_bits.is_empty():
		# Wrap two bonuses per line for readability
		var i: int = 0
		while i < line_bits.size():
			out.append("  ".join(line_bits.slice(i, min(i + 3, line_bits.size()))))
			i += 3
	return out

# List every rolled affix on the item with its tooltip. Both arrays
# (prefix_affixes + suffix_affixes) hold Affix IDs; the registry resolves
# each to an Affix resource that knows its bonus dict and can format
# its own tooltip line. Returns empty list when the item has no rolled
# affixes (junk/basic drops, base shop items, soulbound canonical items
# like Heaven that skip the rolling step).
func _format_affix_lines(item: Item) -> Array[String]:
	var out: Array[String] = []
	if item.prefix_affixes.is_empty() and item.suffix_affixes.is_empty():
		return out
	var reg: Node = get_node_or_null("/root/AffixRegistry")
	if reg == null or not reg.has_method("get_affix"):
		return out
	for affix_id in item.prefix_affixes:
		var a = reg.get_affix(affix_id)
		if a == null:
			continue
		out.append("%s: %s" % [a.name_part, a.format_tooltip()])
	for affix_id in item.suffix_affixes:
		var a = reg.get_affix(affix_id)
		if a == null:
			continue
		out.append("%s: %s" % [a.name_part.lstrip("of ").capitalize(), a.format_tooltip()])
	return out

# Build the diff section against the currently-equipped item in the same
# slot. Returns "" if nothing equipped or item has no slot.
func _compose_compare(item: Item) -> String:
	if not _player or not _player.inventory or not _player.inventory.has_method("equipped_in"):
		return ""
	if item.slot == Item.Slot.NONE:
		return ""
	var equipped = _player.inventory.equipped_in(item.slot)
	if equipped == null or equipped == item:
		return ""
	# Compute key diffs
	var diffs: Array[String] = []
	_diff_stat(diffs, item, equipped, "base_damage",      "dmg",      "%+d", false)
	_diff_stat(diffs, item, equipped, "attack_speed",     "spd",      "%+.2f", false)
	_diff_stat(diffs, item, equipped, "armor_bonus",      "armor",    "%+d", false)
	_diff_stat(diffs, item, equipped, "strength_bonus",   "str",      "%+d", false)
	_diff_stat(diffs, item, equipped, "dexterity_bonus",  "dex",      "%+d", false)
	_diff_stat(diffs, item, equipped, "intellect_bonus",  "int",      "%+d", false)
	_diff_stat(diffs, item, equipped, "vitality_bonus",   "vit",      "%+d", false)
	_diff_stat(diffs, item, equipped, "crit_chance_bonus","crit",     "%+.0f%%", true)
	if diffs.is_empty():
		return "vs %s: identical." % equipped.display_name
	return "vs %s:  %s" % [equipped.display_name, "  ".join(diffs)]

func _diff_stat(out: Array[String], a: Item, b: Item, key: String, label: String, fmt: String, is_pct: bool) -> void:
	var av: float = float(a.get(key)) if a.get(key) != null else 0.0
	var bv: float = float(b.get(key)) if b.get(key) != null else 0.0
	var d: float = av - bv
	if abs(d) < 0.01:
		return
	if is_pct:
		out.append("%s %s" % [fmt % (d * 100.0), label])
	elif fmt == "%+d":
		out.append("%s %s" % [fmt % int(round(d)), label])
	else:
		out.append("%s %s" % [fmt % d, label])
