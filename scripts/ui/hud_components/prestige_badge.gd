extends Control
class_name PrestigeBadge

# Reusable prestige badge. Displays a styled glyph + number indicating cycle depth.
# Used in: HUD player display, character creation roster, enemy nameplates, auction
# house seller name, multiplayer lobby roster.
#
# Styling tiers (cycle 0 hides the badge entirely):
#   1-3   - bronze edge, gold star
#   4-6   - silver edge, white star
#   7-9   - gold edge, blue star
#   10    - black edge, white sun glyph (max prestige)

const TIER_COLORS := {
	1:  { "edge": Color(0.50, 0.30, 0.10), "fill": Color(1.0, 0.7, 0.2), "glyph": "★" },
	4:  { "edge": Color(0.60, 0.60, 0.65), "fill": Color(1.0, 1.0, 1.0), "glyph": "★" },
	7:  { "edge": Color(0.95, 0.85, 0.30), "fill": Color(0.40, 0.65, 1.0), "glyph": "★" },
	10: { "edge": Color(0.05, 0.05, 0.05), "fill": Color(1.0, 1.0, 1.0), "glyph": "☉" },
}

@export var prestige_level: int = 0:
	set(value):
		prestige_level = clamp(value, 0, 10)
		queue_redraw()

@export var size_pixels: float = 20.0
@export var show_label: bool = true

func _ready() -> void:
	custom_minimum_size = Vector2(size_pixels * 1.6, size_pixels)

func _draw() -> void:
	if prestige_level <= 0:
		return
	var theme := _theme_for(prestige_level)
	var center := Vector2(size_pixels * 0.5, size_pixels * 0.5)
	# Edge ring
	draw_circle(center, size_pixels * 0.5, theme["edge"])
	# Inner fill
	draw_circle(center, size_pixels * 0.42, Color(0.05, 0.05, 0.08))
	# Glyph (rendered as small text)
	var font := ThemeDB.fallback_font
	var glyph: String = theme["glyph"]
	var glyph_size := int(size_pixels * 0.65)
	draw_string(font, center + Vector2(-glyph_size * 0.35, glyph_size * 0.30),
		glyph, HORIZONTAL_ALIGNMENT_LEFT, -1, glyph_size, theme["fill"])
	if show_label:
		draw_string(font, Vector2(size_pixels + 4, size_pixels * 0.7),
			"P%d" % prestige_level, HORIZONTAL_ALIGNMENT_LEFT, -1, int(size_pixels * 0.7),
			Color(0.95, 0.92, 0.65))

func _theme_for(lvl: int) -> Dictionary:
	if lvl >= 10: return TIER_COLORS[10]
	if lvl >= 7:  return TIER_COLORS[7]
	if lvl >= 4:  return TIER_COLORS[4]
	return TIER_COLORS[1]
