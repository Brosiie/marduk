extends Resource
class_name Race

# A playable race. Defines geographic origin, visual palette, body proportions,
# small stat lean, voice tone, and class affinity hints. See CHARACTER_DESIGN.md § 2.5
# for the full design.
#
# Five races ship in v1: anunnaki, ash_born, reed_walker, mountain_forged, wound_marked.
# All races can play all classes; affinity is a visual suggestion in the creator,
# not a gate.

@export var race_id: StringName = &"anunnaki"
@export var display_name: String = ""
@export_multiline var lore: String = ""
@export_multiline var origin_region: String = ""

# === Body proportions ===
# Height multiplier applied to the base mesh. 1.0 = baseline, 0.85 = Mountain-Forged,
# 1.05 = Anunnaki-Blooded.
@export var height_scale: float = 1.0
# 0 = lean, 1 = athletic, 2 = stocky. Drives the body_type preset selection range.
@export var build_archetype: int = 1

# === Visual palettes ===
# 5 skin tones per race, all in the same family. Player picks index 0..4 in the creator.
@export var skin_palette: Array[Color] = []
# 6 hair colors. Wound-Marked includes moss-green and vine-purple; others are realistic.
@export var hair_palette: Array[Color] = []
# 5 eye colors. Race-specific (Anunnaki gets amber, Wound-Marked gets milk-white, etc.)
@export var eye_palette: Array[Color] = []

# === Stat lean (small adjustments, never dominant) ===
# Dictionary of attribute name -> int modifier. Applied at character creation
# on top of class base stats. Example: {&"intellect": 1, &"dexterity": 1, &"strength": -1}
@export var stat_lean: Dictionary = {}

# === Voice tone ===
# Base voice pack offset (0..3 baseline + race-tinted accent layered).
# 0 = measured/formal, 1 = clipped/hammered, 2 = sing-song, 3 = gravelly, 4 = breathy.
@export var voice_tone_id: int = 0

# === Cultural cosmetic options ===
# Number of unique cultural markings (tattoos, body paint, jewelry) available.
# Player picks 0 (none) up to this max in the creator.
@export var cultural_marking_max: int = 4
# Hair tradition: 0 = formal short, 1 = clan braids, 2 = long-and-loose, 3 = forge-rings, 4 = antler-pins.
@export var hair_tradition: int = 0
# Beard tradition (males): 0 = clean, 1 = short, 2 = full, 3 = braided, 4 = beard-rings.
@export var male_beard_tradition: int = 0

# === Class affinity (visual suggestions in creator) ===
@export var affinity_classes: Array[StringName] = []

# === Race-specific cosmetic earnable (Tier 2) ===
# Identifier for the race-specific Tier 2 earned cosmetic (see CHARACTER_DESIGN.md § 8.5.3).
# eg &"royal_bearing" for Anunnaki, &"ritual_scars" for Ash-Born.
@export var earned_cosmetic_id: StringName = &""
@export_multiline var earned_cosmetic_unlock_hint: String = ""

# Helper: returns true if this race offers an "exotic" feature (eg Wound-Marked
# vine-purple hair, Anunnaki silver-blonde). Used by character creator to flag
# rare options in the picker.
func has_exotic_hair() -> bool:
	for c in hair_palette:
		# Detect exotic by saturation + non-natural hue
		if c.s > 0.4 and (c.h < 0.05 or (c.h > 0.25 and c.h < 0.45) or c.h > 0.75):
			return true
	return false

func get_skin_tone(index: int) -> Color:
	if index < 0 or index >= skin_palette.size():
		return Color(0.7, 0.55, 0.45)  # safe default
	return skin_palette[index]

func get_hair_color(index: int) -> Color:
	if index < 0 or index >= hair_palette.size():
		return Color(0.2, 0.15, 0.10)
	return hair_palette[index]

func get_eye_color(index: int) -> Color:
	if index < 0 or index >= eye_palette.size():
		return Color(0.35, 0.25, 0.15)
	return eye_palette[index]

func stat_modifier(stat_name: StringName) -> int:
	return int(stat_lean.get(stat_name, 0))
