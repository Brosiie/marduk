extends Control
class_name WowAbilityBar

# WoW-style action bar at the bottom-center of the screen. Reads the
# Player's _ability_kit dictionary and paints 12 slots (4 active + 8
# reserved). Each slot shows:
#   - Tinted icon (rarity-style border)
#   - Hotkey label bottom-right (Q/E/R/F/1/2/3/4/...)
#   - Cooldown swirl overlay (alpha fade)
#   - Tooltip with name + cooldown + cost on hover
#
# The bar draws procedurally — no separate .tscn — so it can be added by
# the HUD on _ready and instantly start working.

const SLOT_PX: Vector2 = Vector2(48, 48)
const SLOT_GAP: int = 4
const SLOT_COUNT: int = 12

# Hotkey labels per slot index.
const HOTKEYS := ["Q", "E", "R", "F", "1", "2", "3", "4", "5", "6", "7", "8"]
# Slots 0..3 trigger via existing ability_1..4 actions; slots 4-11 are
# placeholders for future swap bars (consumables, mount, pet, etc).
const ACTION_BY_SLOT := [
	&"ability_1", &"ability_2", &"ability_3", &"ability_4",
	&"", &"", &"", &"", &"", &"", &"", &""
]

var _player: Node = null
var _slot_nodes: Array = []
var _bg: Panel
var _t: float = 0.0

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	anchor_left = 0.5
	anchor_top = 1.0
	anchor_right = 0.5
	anchor_bottom = 1.0
	var bar_w: float = SLOT_COUNT * (SLOT_PX.x + SLOT_GAP) - SLOT_GAP
	offset_left = -bar_w * 0.5
	offset_top = -SLOT_PX.y - 24.0
	offset_right = bar_w * 0.5
	offset_bottom = -16.0

	_bg = Panel.new()
	_bg.anchor_right = 1.0
	_bg.anchor_bottom = 1.0
	_bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_bg)

	var row := HBoxContainer.new()
	row.anchor_right = 1.0
	row.anchor_bottom = 1.0
	row.add_theme_constant_override("separation", SLOT_GAP)
	add_child(row)

	for i in range(SLOT_COUNT):
		var slot := _make_slot(i)
		row.add_child(slot)
		_slot_nodes.append(slot)

	_player = get_tree().get_first_node_in_group("player")
	_paint_all()

func _make_slot(idx: int) -> Control:
	var s := Panel.new()
	s.custom_minimum_size = SLOT_PX
	# Frame
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.10, 0.10, 0.13, 0.95)
	sb.border_color = Color(0.3, 0.3, 0.35)
	sb.set_border_width_all(2)
	sb.set_corner_radius_all(4)
	s.add_theme_stylebox_override("panel", sb)
	s.mouse_filter = Control.MOUSE_FILTER_PASS

	var icon := TextureRect.new()
	icon.name = "Icon"
	icon.expand_mode = TextureRect.EXPAND_FIT_WIDTH_PROPORTIONAL
	icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	icon.anchor_right = 1.0
	icon.anchor_bottom = 1.0
	icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	s.add_child(icon)

	# Cooldown overlay (semi-transparent dark mask + countdown number)
	var cd := ColorRect.new()
	cd.name = "CD"
	cd.color = Color(0, 0, 0, 0.55)
	cd.anchor_right = 1.0
	cd.anchor_bottom = 1.0
	cd.mouse_filter = Control.MOUSE_FILTER_IGNORE
	cd.visible = false
	s.add_child(cd)

	var cd_lbl := Label.new()
	cd_lbl.name = "CDLabel"
	cd_lbl.add_theme_font_size_override("font_size", 14)
	cd_lbl.modulate = Color(1, 1, 1)
	cd_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	cd_lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	cd_lbl.anchor_right = 1.0
	cd_lbl.anchor_bottom = 1.0
	cd_lbl.visible = false
	s.add_child(cd_lbl)

	# Hotkey badge bottom-right
	var hk := Label.new()
	hk.name = "Hotkey"
	hk.text = HOTKEYS[idx] if idx < HOTKEYS.size() else ""
	hk.add_theme_font_size_override("font_size", 11)
	hk.modulate = Color(0.95, 0.95, 0.65)
	hk.anchor_left = 1.0
	hk.anchor_top = 1.0
	hk.anchor_right = 1.0
	hk.anchor_bottom = 1.0
	hk.offset_left = -16.0
	hk.offset_top = -13.0
	s.add_child(hk)
	return s

func _process(delta: float) -> void:
	_t += delta
	if _t > 0.1:
		_t = 0.0
		_paint_all()
	_update_cooldowns()

func _paint_all() -> void:
	if _player == null:
		_player = get_tree().get_first_node_in_group("player")
	var kit: Array = []
	if _player and "_ability_kit" in _player:
		kit = _player._ability_kit
	# Class color for the active-ability border. Read once per paint.
	var class_color: Color = _read_class_color()
	for i in range(_slot_nodes.size()):
		var s: Control = _slot_nodes[i]
		var icon: TextureRect = s.get_node("Icon")
		var has_ability: bool = i < kit.size() and not kit[i].is_empty()
		if has_ability:
			var k: Dictionary = kit[i]
			# Procedural icon: tint a colored square by ability id hash + element
			icon.texture = _build_ability_icon(k)
			s.tooltip_text = "%s\nCost: %s\nCooldown: %.1fs" % [
				str(k.get("name", "")),
				str(int(k.get("cost", 0))),
				float(k.get("cooldown", 0))
			]
		else:
			icon.texture = null
			s.tooltip_text = "Empty slot"
		# Update slot border color: active slots glow class-colored
		# (Berserker red, Mage blue, Ronin gold, etc), inactive stay
		# subdued gray. The bar instantly tells the player WHICH class
		# they're playing without checking the menu.
		_apply_slot_border(s, class_color if has_ability else Color(0.3, 0.3, 0.35))

func _apply_slot_border(slot: Control, color: Color) -> void:
	var sb: StyleBoxFlat = slot.get_theme_stylebox("panel")
	if sb == null:
		return
	# Mutate in place so we don't re-allocate StyleBoxes every paint
	sb.border_color = color
	sb.bg_color = Color(0.10, 0.10, 0.13, 0.95).lerp(color, 0.08)

func _read_class_color() -> Color:
	if _player == null or not "stats" in _player or _player.stats == null:
		return Color(0.85, 0.85, 0.50, 1.0)
	var class_def = _player.stats.class_def if "class_def" in _player.stats else null
	if class_def == null:
		return Color(0.85, 0.85, 0.50, 1.0)
	# Mirror of player.gd CLASS_BUFF_COLOR. Kept here as a duplicate so
	# the HUD doesn't need to introspect Player consts (avoids tight
	# coupling). If colors drift, fix both.
	match class_def.class_id:
		&"berserker":            return Color(0.95, 0.30, 0.20, 1.0)
		&"assassin":             return Color(0.55, 0.30, 0.85, 1.0)
		&"ronin":                return Color(1.00, 0.85, 0.45, 1.0)
		&"ranger":               return Color(0.40, 0.85, 0.35, 1.0)
		&"mage":                 return Color(0.40, 0.65, 1.00, 1.0)
		&"chaos_druid":          return Color(0.55, 0.95, 0.40, 1.0)
		&"demon":                return Color(0.85, 0.20, 0.30, 1.0)
		&"paladin_guardian":     return Color(0.95, 0.92, 0.75, 1.0)
		&"paladin_lightbringer": return Color(1.00, 0.95, 0.55, 1.0)
	return Color(0.85, 0.85, 0.50, 1.0)

func _update_cooldowns() -> void:
	if _player == null:
		return
	if not "_ability_cooldowns" in _player:
		return
	var cooldowns: Array = _player._ability_cooldowns
	var kit: Array = []
	if "_ability_kit" in _player:
		kit = _player._ability_kit
	var now: float = Time.get_ticks_msec() / 1000.0
	for i in range(min(_slot_nodes.size(), cooldowns.size())):
		var s: Control = _slot_nodes[i]
		var cd: ColorRect = s.get_node("CD")
		var cd_lbl: Label = s.get_node("CDLabel")
		var remaining: float = cooldowns[i] - now
		# Swirl: read this slot's total cooldown from the kit so the mask
		# can shrink from full to empty as the ability comes back. We
		# compute progress = remaining / total.
		var total: float = 1.0
		if i < kit.size() and not kit[i].is_empty():
			total = max(0.05, float(kit[i].get("cooldown", 1.0)))
		if remaining > 0.05:
			cd.visible = true
			cd_lbl.visible = true
			cd_lbl.text = ("%.1f" % remaining) if remaining < 10.0 else ("%d" % int(remaining))
			# Shrink the mask vertically as the cooldown progresses.
			# At remaining=total: mask covers full slot. At remaining=0:
			# mask covers nothing. Standard fill-up MOBA UI.
			var pct: float = clamp(remaining / total, 0.0, 1.0)
			cd.anchor_top = 1.0 - pct  # mask top edge climbs as ability returns
		else:
			cd.visible = false
			cd_lbl.visible = false
			cd.anchor_top = 0.0  # reset for next use

# Quick procedural icon: square colored by ability element with the first
# letter of the ability name overlaid. Replaceable later when art lands.
func _build_ability_icon(k: Dictionary) -> Texture2D:
	var img := Image.create(48, 48, false, Image.FORMAT_RGBA8)
	var col: Color = _color_for_id(StringName(k.get("id", "")))
	# Body fill with subtle gradient
	for x in range(48):
		for y in range(48):
			var t: float = float(y) / 48.0
			img.set_pixel(x, y, col.lerp(col.darkened(0.3), t))
	# Border
	for x in range(48):
		img.set_pixel(x, 0, Color(0.95, 0.85, 0.55))
		img.set_pixel(x, 47, Color(0.95, 0.85, 0.55))
		img.set_pixel(0, x, Color(0.95, 0.85, 0.55))
		img.set_pixel(47, x, Color(0.95, 0.85, 0.55))
	return ImageTexture.create_from_image(img)

func _color_for_id(id: StringName) -> Color:
	var s: String = String(id)
	if "fire" in s or "hellfire" in s or "flame" in s or "fury" in s: return Color(0.85, 0.30, 0.20)
	if "frost" in s or "ice" in s or "mist" in s: return Color(0.40, 0.65, 0.95)
	if "thunder" in s or "spark" in s or "lightning" in s: return Color(0.95, 0.85, 0.30)
	if "water" in s: return Color(0.30, 0.60, 0.95)
	if "holy" in s or "sun" in s or "judgment" in s or "smite" in s: return Color(1.00, 0.85, 0.45)
	if "shadow" in s or "drain" in s: return Color(0.55, 0.20, 0.65)
	if "wind" in s: return Color(0.55, 0.85, 0.55)
	if "stone" in s or "wolf" in s or "bear" in s: return Color(0.65, 0.50, 0.35)
	if "stealth" in s or "blink" in s: return Color(0.30, 0.30, 0.40)
	if "iai" in s or "katana" in s: return Color(0.85, 0.30, 0.20)
	if "moon" in s: return Color(0.55, 0.20, 0.55)
	return Color(0.45, 0.45, 0.55)
