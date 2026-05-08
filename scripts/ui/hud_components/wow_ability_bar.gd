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

const SLOT_PX: Vector2 = Vector2(64, 64)  # was 48; 64 reads as Dragonflight, 48 as Vanilla
const SLOT_GAP: int = 6
const SLOT_COUNT: int = 12
# Class color stays cached so the active-slot frame doesn't flicker
# every paint when the player.gd helper returns the same value.
const FRAME_GOLD: Color = Color(0.78, 0.62, 0.28, 1.0)
const FRAME_GOLD_BRIGHT: Color = Color(1.00, 0.86, 0.45, 1.0)
const FRAME_INNER_DARK: Color = Color(0.04, 0.03, 0.05, 0.96)

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
# Icon texture cache keyed by ability id. _paint_all runs at 10 Hz; each
# call previously did 12 * (Image.create + 64*64 set_pixel + ImageTexture
# .create_from_image) = 120 alloc/sec leaked to the GC. Cache flips that
# to one rebuild per unique ability per session — kit changes maybe 5
# times in a 30-min playthrough, so cache stays under 20 entries.
var _icon_cache: Dictionary = {}

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
	# OUTER frame: gold filigree look. We layer two stylebox panels —
	# the outer is the gold border with shadow under it, the inner is
	# the dark cell that holds the icon. Two panels read as 'beveled
	# metal frame with depth' instead of 'flat colored rectangle'.
	var sb := StyleBoxFlat.new()
	sb.bg_color = FRAME_INNER_DARK
	sb.border_color = FRAME_GOLD
	# Top border 1px brighter for the lit-from-above bevel illusion;
	# left/right borders match; bottom is darker to suggest shadow.
	sb.border_width_top = 2
	sb.border_width_left = 2
	sb.border_width_right = 2
	sb.border_width_bottom = 2
	sb.set_corner_radius_all(6)
	# Drop shadow behind the slot. Shadow_size 6 with offset (0,3) reads
	# as 'lifted off the screen' — the previous flat panels looked
	# pasted-on and cheap.
	sb.shadow_color = Color(0, 0, 0, 0.65)
	sb.shadow_size = 6
	sb.shadow_offset = Vector2(0, 3)
	# Subtle inner content margin so the icon doesn't paint over the
	# bevel border itself.
	sb.content_margin_top = 3
	sb.content_margin_left = 3
	sb.content_margin_right = 3
	sb.content_margin_bottom = 3
	s.add_theme_stylebox_override("panel", sb)
	s.mouse_filter = Control.MOUSE_FILTER_PASS

	# A thin TOP-EDGE highlight strip painted as a child ColorRect.
	# This is the 'molten gold' line that catches light at the top of
	# real-game ability frames (Diablo, Lost Ark). 1px tall, anchored
	# to the top, slightly inset.
	var hi := ColorRect.new()
	hi.name = "HighlightStrip"
	hi.color = FRAME_GOLD_BRIGHT
	hi.anchor_left = 0.0
	hi.anchor_top = 0.0
	hi.anchor_right = 1.0
	hi.anchor_bottom = 0.0
	hi.offset_left = 4.0
	hi.offset_right = -4.0
	hi.offset_top = 3.0
	hi.offset_bottom = 4.0
	hi.mouse_filter = Control.MOUSE_FILTER_IGNORE
	s.add_child(hi)

	var icon := TextureRect.new()
	icon.name = "Icon"
	icon.expand_mode = TextureRect.EXPAND_FIT_WIDTH_PROPORTIONAL
	icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	icon.anchor_right = 1.0
	icon.anchor_bottom = 1.0
	icon.offset_left = 4.0
	icon.offset_top = 4.0
	icon.offset_right = -4.0
	icon.offset_bottom = -4.0
	# NEAREST keeps the procedural pixel-art glyphs crisp at 64px.
	# LINEAR_MIPMAP (Godot default) blurs them into a smear.
	icon.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	s.add_child(icon)

	# Cooldown overlay (semi-transparent dark mask + countdown number)
	var cd := ColorRect.new()
	cd.name = "CD"
	cd.color = Color(0, 0, 0, 0.62)
	cd.anchor_right = 1.0
	cd.anchor_bottom = 1.0
	cd.offset_left = 3.0
	cd.offset_top = 3.0
	cd.offset_right = -3.0
	cd.offset_bottom = -3.0
	cd.mouse_filter = Control.MOUSE_FILTER_IGNORE
	cd.visible = false
	s.add_child(cd)

	var cd_lbl := Label.new()
	cd_lbl.name = "CDLabel"
	cd_lbl.add_theme_font_size_override("font_size", 22)  # was 14, doubles legibility
	cd_lbl.add_theme_color_override("font_color", Color(1.0, 0.95, 0.70, 1))
	cd_lbl.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.95))
	cd_lbl.add_theme_constant_override("outline_size", 5)
	cd_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	cd_lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	cd_lbl.anchor_right = 1.0
	cd_lbl.anchor_bottom = 1.0
	cd_lbl.visible = false
	s.add_child(cd_lbl)

	# Hotkey badge bottom-right. Sits inside a dark pill background so
	# the text reads on every icon color (no more 'Q' invisible against
	# yellow holy abilities).
	var hk_pill := Panel.new()
	hk_pill.name = "HotkeyPill"
	hk_pill.anchor_left = 0.0
	hk_pill.anchor_top = 1.0
	hk_pill.anchor_right = 0.0
	hk_pill.anchor_bottom = 1.0
	hk_pill.offset_left = 4.0
	hk_pill.offset_top = -18.0
	hk_pill.offset_right = 22.0
	hk_pill.offset_bottom = -4.0
	var pill_sb := StyleBoxFlat.new()
	pill_sb.bg_color = Color(0, 0, 0, 0.78)
	pill_sb.border_color = FRAME_GOLD
	pill_sb.set_border_width_all(1)
	pill_sb.set_corner_radius_all(3)
	hk_pill.add_theme_stylebox_override("panel", pill_sb)
	hk_pill.mouse_filter = Control.MOUSE_FILTER_IGNORE
	s.add_child(hk_pill)

	var hk := Label.new()
	hk.name = "Hotkey"
	hk.text = HOTKEYS[idx] if idx < HOTKEYS.size() else ""
	hk.add_theme_font_size_override("font_size", 12)
	hk.add_theme_color_override("font_color", FRAME_GOLD_BRIGHT)
	hk.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.9))
	hk.add_theme_constant_override("outline_size", 3)
	hk.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	hk.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	hk.anchor_right = 1.0
	hk.anchor_bottom = 1.0
	hk.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hk_pill.add_child(hk)
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

# Procedural icon: 64x64 image rendered with multiple compositing
# passes — vertical gradient body (lit from above), corner vignette,
# element glyph, top molten highlight, sparkles. The icon's outer
# border is drawn by the slot Panel's StyleBoxFlat (gold frame +
# shadow), so the image itself does NOT paint a 1px outer ring; the
# previous version did and produced a double-border 'comic-book'
# look. ICON_SIZE stays at 64 because every _glyph_* helper uses
# hard-coded 64-grid coords; bumping to 96 would shrink every glyph
# into the upper-left quarter.
const ICON_SIZE: int = 64

func _build_ability_icon(k: Dictionary) -> Texture2D:
	var ability_id: String = String(k.get("id", ""))
	if ability_id != "" and _icon_cache.has(ability_id):
		return _icon_cache[ability_id]
	var img := Image.create(ICON_SIZE, ICON_SIZE, false, Image.FORMAT_RGBA8)
	var bg: Color = _color_for_id(StringName(k.get("id", "")))
	# Pass 1 — sky-to-stone vertical gradient. The top of the slot is
	# a brighter saturated version of the element color, the bottom
	# fades to a darker desaturated rocky tone. This reads as 'molten
	# metal disc set into stone' rather than 'flat colored square'.
	var top_color: Color = bg.lightened(0.32)
	var bot_color: Color = bg.darkened(0.50).lerp(Color(0.07, 0.06, 0.08, 1), 0.35)
	for y in ICON_SIZE:
		var t: float = float(y) / float(ICON_SIZE - 1)
		# Quadratic curve so transition concentrates in the lower half
		t = t * t
		var row: Color = top_color.lerp(bot_color, t)
		for x in ICON_SIZE:
			img.set_pixel(x, y, row)
	# Pass 2 — radial vignette darkens the corners so the eye is drawn
	# to the central glyph. Without this the icons read flat even with
	# the gradient pass.
	var center := Vector2(ICON_SIZE * 0.5, ICON_SIZE * 0.5)
	var max_d: float = ICON_SIZE * 0.55
	for x in ICON_SIZE:
		for y in ICON_SIZE:
			var d: float = Vector2(x, y).distance_to(center) / max_d
			if d > 0.7:
				var fade: float = clamp((d - 0.7) / 0.5, 0.0, 0.85)
				var px: Color = img.get_pixel(x, y)
				img.set_pixel(x, y, px.darkened(fade * 0.55))
	# Pass 3 — glyph. We paint at higher detail using the same
	# coordinate space; downstream nearest-filter scaling keeps it
	# crisp at the 64px slot size.
	var glyph_color: Color = bg.lightened(0.85).lerp(Color.WHITE, 0.35)
	_draw_glyph(img, StringName(k.get("id", "")), glyph_color)
	# Pass 4 — inner bevel highlights: bright top, mid-dark bottom.
	# These run inside the gold-frame margin so the icon reads as 'lit
	# from above' even after the slot StyleBoxFlat draws its border.
	for x in ICON_SIZE:
		img.set_pixel(x, 1, bg.lightened(0.45))
		img.set_pixel(x, ICON_SIZE - 2, bg.darkened(0.5))
	for y in ICON_SIZE:
		img.set_pixel(1, y, bg.lightened(0.30))
		img.set_pixel(ICON_SIZE - 2, y, bg.darkened(0.45))
	# Pass 5 — top-edge molten highlight. Two-pixel band of bright
	# bg-tinted color across the top, fading down. Adds a 'wet metal'
	# read at the top edge that simulates the gloss WoW icons get
	# from their gradient overlays.
	var molten: Color = bg.lightened(0.65)
	for x in ICON_SIZE:
		img.set_pixel(x, 2, molten.lerp(top_color, 0.25))
		img.set_pixel(x, 3, molten.lerp(top_color, 0.55))
	# Pass 6 — corner sparkles for legendary/active abilities. Tiny
	# 1px dots in the top-left and bottom-right that catch the eye
	# without dominating. Hue pulled from bg so they read as part of
	# the same set.
	var spark: Color = bg.lightened(0.95).lerp(Color.WHITE, 0.5)
	img.set_pixel(4, 4, spark)
	img.set_pixel(5, 4, spark.lerp(top_color, 0.5))
	img.set_pixel(4, 5, spark.lerp(top_color, 0.5))
	# Note: outer border is now drawn by the slot Panel's StyleBoxFlat
	# (gold frame with shadow) — we no longer paint a 1px border on
	# the image itself, which was causing a double-border artifact.
	var tex: Texture2D = ImageTexture.create_from_image(img)
	if ability_id != "":
		_icon_cache[ability_id] = tex
	return tex

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
	# Katana-style diagonal blade with proper geometry: tip in upper-
	# right, grip in lower-left, gold tsuba (crossguard), dark tsuka
	# (handle). Three layers — outline, fill, highlight stripe along
	# the edge — read as a real sword instead of a slash.
	var c_outline: Color = c.darkened(0.55)
	var c_fill: Color = c
	var c_highlight: Color = c.lightened(0.55)
	# Blade body: parallel diagonal stripe from (16,48) -> (48,16)
	for i in range(-22, 23):
		var x: int = clamp(32 + i, 1, ICON_SIZE - 2)
		var y: int = clamp(32 - i, 1, ICON_SIZE - 2)
		# 3-thick blade: outline / fill / fill / highlight
		_blot(img, x, y, c_fill, 1)
		# Highlight one px above (perpendicular to slash direction)
		if x + 1 < ICON_SIZE - 1 and y - 1 > 0:
			img.set_pixel(x + 1, y - 1, c_highlight)
		if x - 1 > 0 and y + 1 < ICON_SIZE - 1:
			img.set_pixel(x - 1, y + 1, c_outline)
	# Tsuba (gold crossguard) - perpendicular to blade at lower-left
	var gold := Color(0.92, 0.72, 0.30)
	for off in range(-6, 7):
		var gx: int = clamp(20 + off, 1, ICON_SIZE - 2)
		var gy: int = clamp(44 + off, 1, ICON_SIZE - 2)
		_blot(img, gx, gy, gold, 1)
	# Tsuka (dark handle) extending past the tsuba
	var dark := Color(0.18, 0.12, 0.10)
	for k in range(0, 10):
		var hx: int = clamp(16 - k, 1, ICON_SIZE - 2)
		var hy: int = clamp(48 + k, 1, ICON_SIZE - 2)
		_blot(img, hx, hy, dark, 1)

func _glyph_water(img: Image, c: Color) -> void:
	# Teardrop with proper lit shading: dark outline at edges, mid
	# fill, bright highlight on the upper-left where light catches.
	var cx := ICON_SIZE / 2
	var c_dark: Color = c.darkened(0.45)
	var c_lit: Color = c.lightened(0.55)
	# Top triangle (point)
	for r in range(0, 14):
		var w: int = 14 - r
		for dx in range(-w / 2, w / 2 + 1):
			var col: Color = c
			# Edge pixels darker
			if abs(dx) >= w / 2 - 1:
				col = c_dark
			# Lit pixel
			if dx <= -w / 4:
				col = col.lerp(c_lit, 0.5)
			_blot(img, cx + dx, 14 + r, col, 0)
	# Round body
	var by := 38
	for dx in range(-12, 13):
		for dy in range(-10, 11):
			var d2: int = dx * dx + dy * dy
			if d2 <= 100:
				var col2: Color = c
				if d2 >= 80:
					col2 = c_dark
				# Highlight
				if dx <= -4 and dy <= -2:
					col2 = c_lit
				_blot(img, cx + dx, by + dy, col2, 0)

func _glyph_lightning(img: Image, c: Color) -> void:
	# Bolt: stylized Z with thick body, dark outline, bright core.
	# The earlier version drew a jagged 6-segment polygon that read as
	# noise instead of a bolt. New shape uses 4 segments forming an
	# unmistakable lightning Z.
	var pts := [
		Vector2i(38, 6),   # top peak
		Vector2i(24, 28),  # bend left
		Vector2i(34, 28),  # bend right
		Vector2i(18, 58),  # bottom point
	]
	# Outline pass — darker, 1px wider
	for i in range(pts.size() - 1):
		_draw_line(img, pts[i], pts[i + 1], c.darkened(0.55), 3)
	# Body pass
	for i in range(pts.size() - 1):
		_draw_line(img, pts[i], pts[i + 1], c, 2)
	# Bright core
	for i in range(pts.size() - 1):
		_draw_line(img, pts[i], pts[i + 1], c.lightened(0.55), 0)
	# Cap the top peak with a bright dot
	_blot(img, 38, 6, c.lightened(0.85), 1)

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
