extends Node

# IconAtlas — autoload that returns a procedural Texture2D for any Item.
#
# Why procedural: hand-drawing 200+ pixel icons before tonight's playtest is
# unrealistic. Each item's icon is generated from its slot + weapon type +
# rarity into a recognizable colored badge with a glyph. A real artist can
# replace each with a hand-painted PNG later by setting `Item.icon` directly,
# and the atlas falls through to that.
#
# Layout: 64x64 ImageTexture
#   - rim: 2px border in rarity color
#   - body: slot-color background gradient
#   - glyph: 16x16 symbol indicating weapon/armor type, drawn in white
#
# All textures are cached on first request so we only build them once per
# weapon-type+rarity combination.

const ICON_SIZE: int = 64
const RIM_THICKNESS: int = 2

var _cache: Dictionary = {}  # cache_key -> ImageTexture

# Color per rarity (border)
const RARITY_COLORS := {
	0: Color(0.4, 0.4, 0.4),      # JUNK - grey
	1: Color(0.85, 0.85, 0.85),   # BASIC - white
	2: Color(0.55, 0.85, 0.45),   # COMMON - green
	3: Color(0.40, 0.50, 0.95),   # RARE - blue
	4: Color(0.75, 0.30, 0.95),   # VERY_RARE - purple
	5: Color(1.00, 0.65, 0.10),   # LEGENDARY - orange
	6: Color(1.00, 0.95, 0.55),   # HEAVEN - pale gold
}

# Body color per slot family
const SLOT_BODY_COLORS := {
	1: Color(0.7, 0.2, 0.15),  # WEAPON_MAIN - blood-red
	2: Color(0.45, 0.35, 0.20), # WEAPON_OFFHAND - leather brown
	3: Color(0.55, 0.55, 0.65), # HEAD - slate
	4: Color(0.45, 0.45, 0.55), # CHEST - steel
	5: Color(0.40, 0.40, 0.50), # LEGS
	6: Color(0.30, 0.20, 0.15), # FEET
	7: Color(0.50, 0.40, 0.30), # HANDS
	8: Color(0.30, 0.20, 0.40), # BACK - cape
	9: Color(0.50, 0.40, 0.20), # BELT
	10: Color(0.95, 0.85, 0.30), # RING_LEFT - gold
	11: Color(0.95, 0.85, 0.30), # RING_RIGHT - gold
	12: Color(0.85, 0.80, 0.55), # AMULET - pale gold
	13: Color(0.65, 0.30, 0.65), # CHARM - violet
}

# Glyph stroke color
const GLYPH_COLOR := Color(0.97, 0.95, 0.90)

func get_icon_for_item(item: Item) -> Texture2D:
	if item == null:
		return _placeholder()
	if item.icon != null:
		# author-provided takes precedence
		return item.icon
	var key: String = "%d_%d_%d" % [int(item.slot), int(item.weapon_type), int(item.rarity)]
	if _cache.has(key):
		return _cache[key]
	var tex := _build_icon(item)
	_cache[key] = tex
	return tex

func get_icon_for_slot(slot: int, rarity: int = 2, weapon_type: int = 0) -> Texture2D:
	var key: String = "%d_%d_%d" % [slot, weapon_type, rarity]
	if _cache.has(key):
		return _cache[key]
	# build a synthetic Item-like fake with just the values we need
	var img := _draw(slot, weapon_type, rarity)
	var tex := ImageTexture.create_from_image(img)
	_cache[key] = tex
	return tex

func _placeholder() -> Texture2D:
	var key := "_placeholder"
	if _cache.has(key):
		return _cache[key]
	var img := Image.create(ICON_SIZE, ICON_SIZE, false, Image.FORMAT_RGBA8)
	img.fill(Color(0.15, 0.15, 0.18))
	# Question-mark shape (simplified): a square with hole at center
	for x in range(20, 44):
		for y in range(8, 12):
			img.set_pixel(x, y, GLYPH_COLOR)
	for x in range(40, 44):
		for y in range(12, 28):
			img.set_pixel(x, y, GLYPH_COLOR)
	for x in range(28, 44):
		for y in range(28, 32):
			img.set_pixel(x, y, GLYPH_COLOR)
	for x in range(28, 32):
		for y in range(32, 44):
			img.set_pixel(x, y, GLYPH_COLOR)
	for x in range(28, 32):
		for y in range(48, 56):
			img.set_pixel(x, y, GLYPH_COLOR)
	var tex := ImageTexture.create_from_image(img)
	_cache[key] = tex
	return tex

func _build_icon(item: Item) -> ImageTexture:
	var img := _draw(int(item.slot), int(item.weapon_type), int(item.rarity))
	return ImageTexture.create_from_image(img)

func _draw(slot: int, weapon_type: int, rarity: int) -> Image:
	var img := Image.create(ICON_SIZE, ICON_SIZE, false, Image.FORMAT_RGBA8)
	var rim_color: Color = RARITY_COLORS.get(rarity, Color.WHITE)
	var body_color: Color = SLOT_BODY_COLORS.get(slot, Color(0.3, 0.3, 0.35))
	# Border
	img.fill(rim_color)
	# Body
	var inner_color: Color = body_color.darkened(0.1)
	for x in range(RIM_THICKNESS, ICON_SIZE - RIM_THICKNESS):
		for y in range(RIM_THICKNESS, ICON_SIZE - RIM_THICKNESS):
			# Vertical gradient lighter top -> darker bottom
			var t: float = float(y - RIM_THICKNESS) / float(ICON_SIZE - 2 * RIM_THICKNESS)
			img.set_pixel(x, y, body_color.lerp(inner_color, t))
	# Glyph — simple shape per weapon type / slot family
	_draw_glyph(img, slot, weapon_type)
	return img

# Very simple glyph painter: a few pixel-art primitives for each weapon type,
# rotated/positioned within the 64x64 frame.
func _draw_glyph(img: Image, slot: int, weapon_type: int) -> void:
	var cx := ICON_SIZE / 2
	var cy := ICON_SIZE / 2
	# Pick the glyph based on weapon type first, then slot family
	if weapon_type == 1 or weapon_type == 2:    # SWORD / GREATSWORD
		_paint_line(img, cx, cy + 16, cx, cy - 18, GLYPH_COLOR, 3)  # blade
		_paint_line(img, cx - 8, cy + 14, cx + 8, cy + 14, GLYPH_COLOR, 2)  # cross-guard
	elif weapon_type == 3 or weapon_type == 4:  # AXE / GREATAXE
		_paint_line(img, cx, cy - 18, cx, cy + 18, GLYPH_COLOR, 2)  # haft
		_fill_rect(img, cx - 12, cy - 18, cx + 4, cy - 6, GLYPH_COLOR)  # blade
	elif weapon_type == 5 or weapon_type == 6:  # BLUDGEON / GREAT_BLUDGEON
		_paint_line(img, cx, cy + 18, cx, cy - 8, GLYPH_COLOR, 3)
		_fill_rect(img, cx - 8, cy - 18, cx + 8, cy - 6, GLYPH_COLOR)  # head
	elif weapon_type == 7 or weapon_type == 8:  # STAFF / WAND
		_paint_line(img, cx - 10, cy + 18, cx + 10, cy - 18, GLYPH_COLOR, 2)
		_fill_circle(img, cx + 10, cy - 18, 4, GLYPH_COLOR)  # gem
	elif weapon_type == 9 or weapon_type == 10:  # KATANA / NODACHI
		_paint_line(img, cx - 16, cy + 18, cx + 16, cy - 18, GLYPH_COLOR, 2)  # curved blade approximation
	elif weapon_type == 11:                       # DAGGER
		_paint_line(img, cx, cy + 8, cx, cy - 12, GLYPH_COLOR, 2)
		_paint_line(img, cx - 4, cy + 8, cx + 4, cy + 8, GLYPH_COLOR, 1)
	elif weapon_type == 12 or weapon_type == 13:  # BOW / CROSSBOW
		# Vertical "D" shape
		_fill_circle(img, cx + 4, cy, 16, GLYPH_COLOR.darkened(0.3), false)
		_paint_line(img, cx - 4, cy - 16, cx - 4, cy + 16, GLYPH_COLOR, 2)
	elif weapon_type == 14 or weapon_type == 15:  # THROWING_KNIVES / SHURIKEN
		_paint_line(img, cx - 8, cy - 8, cx + 8, cy + 8, GLYPH_COLOR, 2)
		_paint_line(img, cx + 8, cy - 8, cx - 8, cy + 8, GLYPH_COLOR, 2)
	elif weapon_type == 16:                       # POLEARM
		_paint_line(img, cx - 14, cy + 18, cx + 14, cy - 18, GLYPH_COLOR, 2)
		_fill_circle(img, cx + 14, cy - 18, 3, GLYPH_COLOR)
	elif weapon_type == 17:                       # SCYTHE
		_paint_line(img, cx, cy + 18, cx, cy - 14, GLYPH_COLOR, 2)
		_paint_line(img, cx, cy - 14, cx + 16, cy - 4, GLYPH_COLOR, 2)
	elif weapon_type == 18:                       # FIST
		_fill_circle(img, cx, cy, 12, GLYPH_COLOR.darkened(0.3))
		_fill_circle(img, cx, cy, 8, GLYPH_COLOR)
	elif weapon_type == 19:                       # WHIP
		_paint_line(img, cx - 18, cy, cx - 10, cy - 8, GLYPH_COLOR, 2)
		_paint_line(img, cx - 10, cy - 8, cx, cy + 8, GLYPH_COLOR, 2)
		_paint_line(img, cx, cy + 8, cx + 10, cy - 8, GLYPH_COLOR, 2)
		_paint_line(img, cx + 10, cy - 8, cx + 18, cy + 8, GLYPH_COLOR, 2)
	elif slot == 3:  # HEAD - helm shape
		_fill_circle(img, cx, cy - 4, 14, GLYPH_COLOR.darkened(0.3))
		_fill_rect(img, cx - 14, cy + 4, cx + 14, cy + 12, GLYPH_COLOR.darkened(0.5))
	elif slot == 4:  # CHEST - cuirass
		_fill_rect(img, cx - 16, cy - 12, cx + 16, cy + 14, GLYPH_COLOR.darkened(0.3))
		_paint_line(img, cx, cy - 8, cx, cy + 12, GLYPH_COLOR, 1)
	elif slot == 5:  # LEGS
		_fill_rect(img, cx - 12, cy - 16, cx - 2, cy + 16, GLYPH_COLOR.darkened(0.3))
		_fill_rect(img, cx + 2, cy - 16, cx + 12, cy + 16, GLYPH_COLOR.darkened(0.3))
	elif slot == 6:  # FEET - boot shape
		_fill_rect(img, cx - 14, cy + 4, cx + 8, cy + 14, GLYPH_COLOR.darkened(0.3))
		_fill_rect(img, cx - 8, cy - 8, cx, cy + 4, GLYPH_COLOR.darkened(0.3))
	elif slot == 7:  # HANDS - gauntlet
		_fill_rect(img, cx - 8, cy - 14, cx + 8, cy + 14, GLYPH_COLOR.darkened(0.3))
		_paint_line(img, cx - 6, cy - 14, cx + 6, cy - 14, GLYPH_COLOR, 1)
	elif slot == 10 or slot == 11:  # RINGS
		_fill_circle(img, cx, cy, 16, GLYPH_COLOR, false)
		_fill_circle(img, cx, cy, 10, body_color_for_slot(10).darkened(0.3), false)
	elif slot == 12:  # AMULET - chain + gem
		_fill_circle(img, cx, cy + 8, 6, GLYPH_COLOR)
		_paint_line(img, cx - 14, cy - 14, cx, cy + 4, GLYPH_COLOR, 1)
		_paint_line(img, cx + 14, cy - 14, cx, cy + 4, GLYPH_COLOR, 1)
	elif slot == 13:  # CHARM - rune
		_fill_circle(img, cx, cy, 14, GLYPH_COLOR.darkened(0.4))
		_paint_line(img, cx - 6, cy - 6, cx + 6, cy + 6, GLYPH_COLOR, 1)
		_paint_line(img, cx + 6, cy - 6, cx - 6, cy + 6, GLYPH_COLOR, 1)
	else:
		# Generic dot
		_fill_circle(img, cx, cy, 6, GLYPH_COLOR)

# --- pixel art primitives ---

func body_color_for_slot(slot: int) -> Color:
	return SLOT_BODY_COLORS.get(slot, Color(0.3, 0.3, 0.35))

func _set_px(img: Image, x: int, y: int, c: Color) -> void:
	if x < 0 or y < 0 or x >= ICON_SIZE or y >= ICON_SIZE:
		return
	img.set_pixel(x, y, c)

func _paint_line(img: Image, x0: int, y0: int, x1: int, y1: int, c: Color, thickness: int = 1) -> void:
	# Bresenham with thickness brush
	var dx: int = abs(x1 - x0)
	var dy: int = abs(y1 - y0)
	var sx: int = 1 if x0 < x1 else -1
	var sy: int = 1 if y0 < y1 else -1
	var err: int = dx - dy
	var x: int = x0
	var y: int = y0
	while true:
		for tx in range(-thickness / 2, thickness / 2 + 1):
			for ty in range(-thickness / 2, thickness / 2 + 1):
				_set_px(img, x + tx, y + ty, c)
		if x == x1 and y == y1:
			break
		var e2 := 2 * err
		if e2 > -dy:
			err -= dy
			x += sx
		if e2 < dx:
			err += dx
			y += sy

func _fill_rect(img: Image, x0: int, y0: int, x1: int, y1: int, c: Color) -> void:
	for x in range(min(x0, x1), max(x0, x1) + 1):
		for y in range(min(y0, y1), max(y0, y1) + 1):
			_set_px(img, x, y, c)

func _fill_circle(img: Image, cx: int, cy: int, r: int, c: Color, filled: bool = true) -> void:
	for x in range(cx - r, cx + r + 1):
		for y in range(cy - r, cy + r + 1):
			var dx: int = x - cx
			var dy: int = y - cy
			var d2: int = dx * dx + dy * dy
			if filled:
				if d2 <= r * r:
					_set_px(img, x, y, c)
			else:
				if d2 <= r * r and d2 >= (r - 2) * (r - 2):
					_set_px(img, x, y, c)
