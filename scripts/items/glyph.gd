extends Resource
class_name Glyph

# A unique mark earned by first-time-killing a specific boss. Players can inscribe
# Glyphs as tattoos at the Inkstone Sanctum vendor for a tiny stat bonus and
# permanent visible mark on the character body.
#
# See CHARACTER_DESIGN.md § 8.5.2.

@export var glyph_id: StringName = &""
@export var display_name: String = ""
@export_multiline var description: String = ""

# Source: which boss earned this glyph
@export var source_boss_id: StringName = &""
@export var source_boss_display_name: String = ""

# Visual: small Mesh shape + emission color. Tier 1 uses procedural primitives;
# Tier 2 will hand-author per-glyph artwork.
# Shape ids: 0=triangle, 1=circle, 2=square, 3=star, 4=eye, 5=spiral, 6=cross, 7=crown, 8=horn, 9=blade
@export var shape_id: int = 0
@export var emission_color: Color = Color(1.0, 0.85, 0.30)

# Stat bonus when inscribed: small (0.005 = 0.5%) bonus vs the source faction.
@export var faction_bonus_target: StringName = &""  # eg &"crown" or &"undead"
@export var faction_bonus_pct: float = 0.005  # +0.5% damage vs that faction

# Cost to inscribe at the Inkstone Sanctum vendor
@export var inscribe_gold_cost: int = 100
@export var inscribe_token_id: StringName = &""  # eg &"kazat_iron_token"
@export var inscribe_token_count: int = 1

# Lore: shown on the glyph entry in the Codex of Marks
@export_multiline var lore: String = ""

# Helper: human-readable shape name for tooltips.
func shape_name() -> String:
	match shape_id:
		0: return "Triangle"
		1: return "Circle"
		2: return "Square"
		3: return "Star"
		4: return "Eye"
		5: return "Spiral"
		6: return "Cross"
		7: return "Crown"
		8: return "Horn"
		9: return "Blade"
	return "Unknown"
