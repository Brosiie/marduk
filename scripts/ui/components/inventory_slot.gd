extends PanelContainer
class_name InventorySlot

# A custom inventory slot that overrides _make_custom_tooltip to render a
# styled card instead of the engine's plain-text tooltip. The card uses
# RichTextLabel BBCode so the rarity color, stat diffs, and section
# dividers all render correctly. Stat diffs are color-coded:
#   green = upgrade vs equipped
#   red   = downgrade vs equipped
#   gold  = neutral / informational
#
# The previous panel built the tooltip text once into slot.tooltip_text.
# That worked but lost all visual polish, every item looked the same as
# every other item, and a +5 dex item read identical to a -5 dex item.
# Color-coding the diff turns "should I equip this?" into a 200ms read
# instead of a parse-the-text exercise.

var item: Item = null
var equipped_compare: Item = null  # set by the panel when painting

func _make_custom_tooltip(_for_text: String) -> Object:
	# Tooltip is requested even on empty slots; show nothing in that case.
	if item == null:
		return null

	var card := PanelContainer.new()
	# Dark slate panel with gold border. The panel is intentionally a
	# little wider than the slot so long stat lines don't wrap mid-word.
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.06, 0.05, 0.07, 0.97)
	sb.border_color = item.rarity_color() if item.has_method("rarity_color") else Color(0.78, 0.62, 0.28)
	sb.set_border_width_all(2)
	sb.set_corner_radius_all(5)
	sb.shadow_color = Color(0, 0, 0, 0.7)
	sb.shadow_size = 8
	sb.content_margin_left = 14
	sb.content_margin_right = 14
	sb.content_margin_top = 12
	sb.content_margin_bottom = 12
	card.add_theme_stylebox_override("panel", sb)
	card.custom_minimum_size = Vector2(360, 0)

	var rt := RichTextLabel.new()
	rt.bbcode_enabled = true
	rt.fit_content = true
	rt.scroll_active = false
	rt.custom_minimum_size = Vector2(330, 0)
	rt.text = _build_bbcode()
	card.add_child(rt)
	return card

func _build_bbcode() -> String:
	var lines: Array[String] = []
	# Header, name in rarity color, rarity tag faded after
	var rcol_hex: String = _color_to_hex(item.rarity_color() if item.has_method("rarity_color") else Color.WHITE)
	var rname: String = item.rarity_name() if item.has_method("rarity_name") else ""
	var header: String = "[b][color=%s]%s[/color][/b]" % [rcol_hex, item.display_name]
	if rname != "":
		header += "  [color=#888]%s[/color]" % rname
	lines.append(header)

	# Sub-line, slot/weapon type/level/flags in muted gold
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
		subs.append("ilvl %d" % item.item_level)
	if item.is_two_handed:
		subs.append("Two-Handed")
	if item.is_soulbound:
		subs.append("Soulbound")
	if not subs.is_empty():
		lines.append("[color=#9b8654]%s[/color]" % "  ·  ".join(subs))

	# Weapon stats line
	if item.is_weapon():
		var wbits: Array[String] = []
		wbits.append("[color=#f0c060]%d dmg[/color]" % int(item.base_damage))
		if item.attack_speed != 1.0:
			wbits.append("%.2fx spd" % item.attack_speed)
		if item.weapon_range > 0:
			wbits.append("%.1fm reach" % item.weapon_range)
		if item.element != Item.Element.PHYSICAL and item.element_damage_pct > 0:
			var elem_name: String = item.element_name() if item.has_method("element_name") else ""
			wbits.append("[color=#ff8888]+%d%% %s[/color]" % [int(item.element_damage_pct * 100), elem_name])
		lines.append("  ·  ".join(wbits))

	# Bonus stats, gold for positive, no negatives currently in shipping
	# items but the BBCode handles them anyway.
	for line in _format_bonus_lines():
		lines.append(line)

	# Class restriction
	if item.class_restriction.size() > 0:
		var class_names: Array[String] = []
		for c in item.class_restriction:
			class_names.append(String(c).capitalize())
		lines.append("[color=#ff9050]Class: %s only[/color]" % ", ".join(class_names))

	# Implicit + flavor
	if item.implicit_text != "":
		lines.append("")
		lines.append("[i][color=#80c0ff]%s[/color][/i]" % item.implicit_text)
	if item.description != "":
		lines.append("")
		lines.append("[i][color=#888]%s[/color][/i]" % item.description)

	# Compare section: GREEN/RED tinted diffs vs equipped item in same slot.
	# The colored arrows make upgrade/downgrade scannable in <1s.
	var compare_block: String = _build_compare_block()
	if compare_block != "":
		lines.append("")
		lines.append(compare_block)

	return "\n".join(lines)

func _format_bonus_lines() -> Array[String]:
	var out: Array[String] = []
	var checks := [
		["hp_bonus",            "HP",        "%+d"],
		["mana_bonus",          "Mana",      "%+d"],
		["strength_bonus",      "Str",       "%+d"],
		["dexterity_bonus",     "Dex",       "%+d"],
		["intellect_bonus",     "Int",       "%+d"],
		["vitality_bonus",      "Vit",       "%+d"],
		["armor_bonus",         "Armor",     "%+d"],
		["magic_resist_bonus",  "MR",        "%+d"],
		["crit_chance_bonus",   "Crit",      "%+.0f%%"],
		["crit_multiplier_bonus","Crit Mult","%+.0f%%"],
		["damage_bonus_pct",    "Dmg",       "%+.0f%%"],
		["attack_speed_bonus",  "Atk Spd",   "%+.0f%%"],
		["move_speed_bonus",    "Move Spd",  "%+.0f%%"],
	]
	var bits: Array[String] = []
	for check in checks:
		var key: String = check[0]
		var label: String = check[1]
		var fmt: String = check[2]
		var v: float = float(item.get(key)) if item.get(key) != null else 0.0
		if v == 0.0:
			continue
		var s: String
		if fmt.ends_with("%%"):
			s = "%s %s" % [fmt % (v * 100.0), label]
		else:
			s = "%s %s" % [fmt % int(v), label]
		# Positive bonuses in soft green so the bonus block doesn't shout.
		var color_hex: String = "#90c870" if v >= 0.0 else "#d05050"
		bits.append("[color=%s]%s[/color]" % [color_hex, s])
	# Wrap two/three bonuses per visual line for readability.
	var i: int = 0
	while i < bits.size():
		out.append("  ".join(bits.slice(i, min(i + 3, bits.size()))))
		i += 3
	return out

# Build the [vs Currently Equipped] diff block. Each diff line uses
# colored arrows so the player gets the upgrade/downgrade verdict
# without parsing the numbers.
#   ↑  +N stat   (green: this item wins)
#   ↓  -N stat   (red: equipped wins)
#   ·  identical (skipped from output)
func _build_compare_block() -> String:
	var equipped: Item = equipped_compare
	if equipped == null or equipped == item:
		return ""
	if item.slot == Item.Slot.NONE:
		return ""
	var lines: Array[String] = []
	lines.append("[color=#9b8654]vs equipped: %s[/color]" % equipped.display_name)
	var diffs := _stat_diffs(equipped)
	if diffs.is_empty():
		lines.append("[color=#666]· identical[/color]")
	else:
		for d in diffs:
			lines.append(d)
	return "\n".join(lines)

func _stat_diffs(equipped: Item) -> Array[String]:
	var out: Array[String] = []
	_diff_stat(out, equipped, "base_damage",       "dmg",       "%+d",     false)
	_diff_stat(out, equipped, "attack_speed",      "spd",       "%+.2f",   false)
	_diff_stat(out, equipped, "armor_bonus",       "armor",     "%+d",     false)
	_diff_stat(out, equipped, "hp_bonus",          "HP",        "%+d",     false)
	_diff_stat(out, equipped, "mana_bonus",        "Mana",      "%+d",     false)
	_diff_stat(out, equipped, "strength_bonus",    "Str",       "%+d",     false)
	_diff_stat(out, equipped, "dexterity_bonus",   "Dex",       "%+d",     false)
	_diff_stat(out, equipped, "intellect_bonus",   "Int",       "%+d",     false)
	_diff_stat(out, equipped, "vitality_bonus",    "Vit",       "%+d",     false)
	_diff_stat(out, equipped, "crit_chance_bonus", "Crit",      "%+.0f%%", true)
	_diff_stat(out, equipped, "damage_bonus_pct",  "Dmg",       "%+.0f%%", true)
	return out

func _diff_stat(out: Array[String], equipped: Item, key: String, label: String, fmt: String, is_pct: bool) -> void:
	var av: float = float(item.get(key)) if item.get(key) != null else 0.0
	var bv: float = float(equipped.get(key)) if equipped.get(key) != null else 0.0
	var d: float = av - bv
	if abs(d) < 0.01:
		return
	# Choose arrow + color from the sign of the diff. A +base_damage of
	# +5 shows "↑ +5 dmg" in green; a -5 shows "↓ -5 dmg" in red.
	var arrow: String = "↑" if d > 0 else "↓"
	var color_hex: String = "#90e070" if d > 0 else "#e07070"
	var formatted: String
	if is_pct:
		formatted = fmt % (d * 100.0)
	elif fmt == "%+d":
		formatted = fmt % int(round(d))
	else:
		formatted = fmt % d
	out.append("[color=%s]%s  %s %s[/color]" % [color_hex, arrow, formatted, label])

func _color_to_hex(c: Color) -> String:
	return "#%02X%02X%02X" % [int(c.r8), int(c.g8), int(c.b8)]
