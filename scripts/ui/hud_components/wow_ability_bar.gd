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
	# Fallback: if the player exists with a class assigned but the kit
	# is somehow empty (race during scene-load, deferred class assign,
	# script load order), force-rebuild. Cheap, idempotent, prevents
	# the bar from staying blank when class+kit fall out of sync.
	if _player and kit.is_empty():
		var class_set: bool = _player.has_method("get") and _player.stats and _player.stats.class_def != null
		if class_set and _player.has_method("_build_ability_kit"):
			_player._build_ability_kit()
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

# Procedural icon: 64x64 image with a per-ability glyph drawn on top
# of an element-tinted gradient. No sprite assets required; everything
# is drawn pixel-by-pixel based on the ability id.
const ICON_SIZE: int = 64

func _build_ability_icon(k: Dictionary) -> Texture2D:
	var img := Image.create(ICON_SIZE, ICON_SIZE, false, Image.FORMAT_RGBA8)
	var bg: Color = _color_for_id(StringName(k.get("id", "")))
	# Radial gradient body (lighter center -> darker edges)
	var center := Vector2(ICON_SIZE * 0.5, ICON_SIZE * 0.4)
	for x in ICON_SIZE:
		for y in ICON_SIZE:
			var d: float = Vector2(x, y).distance_to(center) / float(ICON_SIZE * 0.6)
			d = clamp(d, 0.0, 1.0)
			img.set_pixel(x, y, bg.lightened(0.25 * (1.0 - d)).lerp(bg.darkened(0.4), d))
	# Glyph overlay
	var glyph_color: Color = bg.lightened(0.6)
	_draw_glyph(img, StringName(k.get("id", "")), glyph_color)
	# Inner bevel highlight (top edge bright, bottom dim)
	for x in ICON_SIZE:
		img.set_pixel(x, 1, bg.lightened(0.45))
		img.set_pixel(x, ICON_SIZE - 2, bg.darkened(0.5))
	for y in ICON_SIZE:
		img.set_pixel(1, y, bg.lightened(0.30))
		img.set_pixel(ICON_SIZE - 2, y, bg.darkened(0.45))
	# Outer gold border
	var border := Color(0.95, 0.78, 0.40)
	for x in ICON_SIZE:
		img.set_pixel(x, 0, border)
		img.set_pixel(x, ICON_SIZE - 1, border)
	for y in ICON_SIZE:
		img.set_pixel(0, y, border)
		img.set_pixel(ICON_SIZE - 1, y, border)
	return ImageTexture.create_from_image(img)

# Picks a glyph based on ability id. Each glyph is drawn into the
# image via simple per-pixel paths. The id string is matched against
# substring keywords so naming variations all hit the right glyph.
func _draw_glyph(img: Image, id: StringName, c: Color) -> void:
	var s := String(id).to_lower()
	if "iai" in s or "katana" in s or "swing" in s or "smite" in s or "swipe" in s or "cleave" in s or "strike" in s or "rake" in s or "stab" in s or "shot" in s or "snipe" in s or "kunai" in s or "vine" in s or "lash" in s:
		_glyph_sword(img, c)
	elif "water" in s or "tide" in s or "redirect" in s or "flowing" in s:
		_glyph_water(img, c)
	elif "thunder" in s or "lightning" in s or "spark" in s:
		_glyph_lightning(img, c)
	elif "fire" in s or "fireball" in s or "flame" in s or "hellfire" in s or "fury" in s:
		_glyph_flame(img, c)
	elif "frost" in s or "nova" in s or "ice" in s:
		_glyph_frost(img, c)
	elif "holy" in s or "sun" in s or "judgment" in s or "pillar" in s or "beam" in s:
		_glyph_sun(img, c)
	elif "moon" in s or "shadow" in s or "soul" in s or "drain" in s or "stealth" in s or "demon_form" in s:
		_glyph_moon(img, c)
	elif "shield" in s or "guard" in s or "block" in s or "parry" in s or "divine_shield" in s or "mana_shield" in s:
		_glyph_shield(img, c)
	elif "heal" in s or "aura" in s:
		_glyph_heart(img, c)
	elif "war_cry" in s or "power_up" in s or "battle_cry" in s or "katana_power_up" in s or "primal" in s or "druid_form" in s or "hawk" in s or "stance_resolve" in s or "resolve" in s:
		_glyph_aura(img, c)
	elif "leap" in s or "trap" in s or "totem" in s or "throw" in s or "wing" in s:
		_glyph_target(img, c)
	else:
		_glyph_diamond(img, c)

# --- Glyph primitives ---

func _glyph_sword(img: Image, c: Color) -> void:
	# Diagonal blade from upper-right to lower-left + crossguard
	var center := ICON_SIZE / 2
	for i in range(-22, 23):
		var x: int = clamp(center + i, 1, ICON_SIZE - 2)
		var y: int = clamp(center - i, 1, ICON_SIZE - 2)
		_blot(img, x, y, c, 1)
	# Crossguard
	var gy := center + 12
	for x in range(center - 14, center + 15):
		_blot(img, x, gy, c.darkened(0.2), 1)

func _glyph_water(img: Image, c: Color) -> void:
	# Teardrop: triangle on top, circle at bottom
	var cx := ICON_SIZE / 2
	for r in range(0, 14):
		var w: int = 14 - r
		for dx in range(-w / 2, w / 2 + 1):
			_blot(img, cx + dx, 14 + r, c, 0)
	# Circle bottom
	var by := 38
	for dx in range(-12, 13):
		for dy in range(-10, 11):
			if dx * dx + dy * dy <= 100:
				_blot(img, cx + dx, by + dy, c, 0)

func _glyph_lightning(img: Image, c: Color) -> void:
	# Z-shaped jagged bolt
	var pts := [
		Vector2i(38, 8), Vector2i(28, 26), Vector2i(36, 26),
		Vector2i(20, 56), Vector2i(30, 36), Vector2i(22, 36)
	]
	for i in range(pts.size() - 1):
		_draw_line(img, pts[i], pts[i + 1], c, 2)
	_draw_line(img, pts[pts.size() - 1], pts[0], c, 2)

func _glyph_flame(img: Image, c: Color) -> void:
	# Three rising flame tongues
	var cx := ICON_SIZE / 2
	for h in range(0, 38):
		var w: int = int(10.0 - h * 0.18)
		w = max(0, w)
		for dx in range(-w, w + 1):
			_blot(img, cx + dx, 56 - h, c, 0)
	# Side tongues
	for h in range(0, 22):
		var w2: int = int(5.0 - h * 0.20)
		w2 = max(0, w2)
		for dx in range(-w2, w2 + 1):
			_blot(img, cx - 12 + dx, 50 - h, c.darkened(0.15), 0)
			_blot(img, cx + 12 + dx, 50 - h, c.darkened(0.15), 0)

func _glyph_frost(img: Image, c: Color) -> void:
	# Six-pointed star
	var cx := ICON_SIZE / 2
	var cy := ICON_SIZE / 2
	for i in range(6):
		var angle: float = float(i) * PI / 3.0
		var dx: int = int(cos(angle) * 22.0)
		var dy: int = int(sin(angle) * 22.0)
		_draw_line(img, Vector2i(cx, cy), Vector2i(cx + dx, cy + dy), c, 1)

func _glyph_sun(img: Image, c: Color) -> void:
	# Center disc + radiating rays
	var cx := ICON_SIZE / 2
	var cy := ICON_SIZE / 2
	for dx in range(-8, 9):
		for dy in range(-8, 9):
			if dx * dx + dy * dy <= 64:
				_blot(img, cx + dx, cy + dy, c, 0)
	# 8 rays
	for i in range(8):
		var angle: float = float(i) * PI / 4.0
		var x1: int = cx + int(cos(angle) * 12.0)
		var y1: int = cy + int(sin(angle) * 12.0)
		var x2: int = cx + int(cos(angle) * 24.0)
		var y2: int = cy + int(sin(angle) * 24.0)
		_draw_line(img, Vector2i(x1, y1), Vector2i(x2, y2), c, 2)

func _glyph_moon(img: Image, c: Color) -> void:
	# Crescent: big disc minus offset disc
	var cx := ICON_SIZE / 2 - 2
	var cy := ICON_SIZE / 2
	for dx in range(-22, 23):
		for dy in range(-22, 23):
			var inside_big: bool = dx * dx + dy * dy <= 22 * 22
			var inside_cut: bool = (dx + 12) * (dx + 12) + dy * dy <= 20 * 20
			if inside_big and not inside_cut:
				_blot(img, cx + dx, cy + dy, c, 0)

func _glyph_shield(img: Image, c: Color) -> void:
	# Heater shield outline
	var cx := ICON_SIZE / 2
	for y in range(8, 56):
		var t: float = float(y - 8) / 48.0
		var w: int = int(lerp(20.0, 4.0, t * t))
		for dx in range(-w, w + 1):
			_blot(img, cx + dx, y, c, 0)

func _glyph_heart(img: Image, c: Color) -> void:
	var cx := ICON_SIZE / 2
	# Two top circles + V bottom
	for dx in range(-10, 11):
		for dy in range(-10, 11):
			if dx * dx + dy * dy <= 80:
				_blot(img, cx - 9 + dx, 22 + dy, c, 0)
				_blot(img, cx + 9 + dx, 22 + dy, c, 0)
	for y in range(20, 50):
		var w: int = int(20.0 - (y - 20) * 0.85)
		w = max(0, w)
		for dx in range(-w, w + 1):
			_blot(img, cx + dx, y, c, 0)

func _glyph_aura(img: Image, c: Color) -> void:
	# Concentric rings + center pip (rage / power-up)
	var cx := ICON_SIZE / 2
	var cy := ICON_SIZE / 2
	for r in [22, 16, 10]:
		_draw_circle_outline(img, cx, cy, r, c, 1)
	for dx in range(-3, 4):
		for dy in range(-3, 4):
			if dx * dx + dy * dy <= 9:
				_blot(img, cx + dx, cy + dy, c.lightened(0.2), 0)

func _glyph_target(img: Image, c: Color) -> void:
	# Crosshair with center pip
	var cx := ICON_SIZE / 2
	var cy := ICON_SIZE / 2
	_draw_circle_outline(img, cx, cy, 22, c, 1)
	_draw_circle_outline(img, cx, cy, 12, c, 1)
	for x in range(cx - 6, cx + 7):
		_blot(img, x, cy, c, 0)
	for y in range(cy - 6, cy + 7):
		_blot(img, cx, y, c, 0)

func _glyph_diamond(img: Image, c: Color) -> void:
	# Generic fallback diamond
	var cx := ICON_SIZE / 2
	var cy := ICON_SIZE / 2
	for dx in range(-20, 21):
		for dy in range(-20, 21):
			if abs(dx) + abs(dy) <= 20:
				_blot(img, cx + dx, cy + dy, c, 0)

# --- Drawing primitives ---

func _blot(img: Image, x: int, y: int, c: Color, radius: int = 0) -> void:
	if radius == 0:
		if x >= 0 and y >= 0 and x < ICON_SIZE and y < ICON_SIZE:
			img.set_pixel(x, y, c)
		return
	for dx in range(-radius, radius + 1):
		for dy in range(-radius, radius + 1):
			if dx * dx + dy * dy <= radius * radius:
				var px: int = x + dx
				var py: int = y + dy
				if px >= 0 and py >= 0 and px < ICON_SIZE and py < ICON_SIZE:
					img.set_pixel(px, py, c)

# Bresenham line with thickness
func _draw_line(img: Image, a: Vector2i, b: Vector2i, c: Color, thickness: int) -> void:
	var dx: int = abs(b.x - a.x)
	var dy: int = -abs(b.y - a.y)
	var sx: int = 1 if a.x < b.x else -1
	var sy: int = 1 if a.y < b.y else -1
	var err: int = dx + dy
	var x: int = a.x
	var y: int = a.y
	while true:
		_blot(img, x, y, c, thickness)
		if x == b.x and y == b.y:
			break
		var e2: int = 2 * err
		if e2 >= dy:
			err += dy
			x += sx
		if e2 <= dx:
			err += dx
			y += sy

func _draw_circle_outline(img: Image, cx: int, cy: int, r: int, c: Color, thickness: int) -> void:
	for theta_step in range(0, 360, 3):
		var theta: float = deg_to_rad(theta_step)
		var x: int = cx + int(cos(theta) * float(r))
		var y: int = cy + int(sin(theta) * float(r))
		_blot(img, x, y, c, thickness)

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
