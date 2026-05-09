extends Resource
class_name CharacterAppearance

# A character's full visual identity. Saved per character slot.
# See CHARACTER_DESIGN.md § 3 for the design.
#
# Lifecycle:
#   1. Created in the character creator (scenes/menus/character_creator.tscn — TODO)
#   2. Stored on Player.character_appearance
#   3. Persisted in the save slot
#   4. Applied at scene load via AppearanceRegistry.apply(player_node, appearance)

# === Identity ===
@export var class_id: StringName = &""
@export var race_id: StringName = &"reed_walker"
@export var gender: StringName = &"male"  # &"male" or &"female"

# === Body ===
@export_range(0, 2) var body_type: int = 1  # 0 = lean, 1 = athletic, 2 = stocky
@export_range(0, 4) var skin_tone: int = 2  # index into Race.skin_palette
# Height multiplier baseline comes from Race.height_scale; this slider nudges it ±5%
@export_range(0.95, 1.05) var height_scale_modifier: float = 1.0

# === Face & hair ===
@export_range(0, 4) var face_preset: int = 0
@export_range(0, 7) var hair_style: int = 0
@export_range(0, 5) var hair_color: int = 0   # index into Race.hair_palette
@export_range(0, 4) var eye_color: int = 0    # index into Race.eye_palette
@export_range(0, 4) var beard_style: int = 0  # male only; 0 = clean shaven; gated by gender

# === Overlays ===
@export_range(0, 3) var scar_overlay: int = 0       # 0 = none
@export_range(0, 6) var warpaint_overlay: int = 0   # 0 = none; class+race specific
@export_range(0, 4) var cultural_marking: int = 0   # 0 = none; race-specific
@export_range(0, 3) var jewelry_set: int = 0        # 0 = none; race-specific

# === Audio ===
@export_range(0, 3) var voice_pack: int = 0  # per gender, accent layered from race

# === Class-specific toggles ===
@export var glow_eyes: bool = false                  # Mage / Sun-Breather toggle
@export_range(0.0, 1.0) var aura_intensity: float = 0.0  # Sun, late Demon

# === Demon overlay (only present for Demon-class characters) ===
# Sub-resource. Null for non-Demons. See DEMON_VISUAL_TRANSFORMATION.md.
# Implementation gated until Bond approves the Demon spec checklist.
@export var demon_overlay: Resource = null  # DemonOverlay when implemented

# === Soul Bindings (Tier 2 living-character mechanic) ===
# A SoulBinding sub-resource holds the bound weapon + bound armor + sacrifice
# ledger. Null until the player visits the altar at Ashurim and binds an item.
# See CHARACTER_DESIGN.md § 8.5.4.
@export var soul_binding: Resource = null  # SoulBinding when the binding ritual has been performed

# === Pre-Lucifer soul snapshot (set when Demon class is unlocked from a prior character) ===
# Used by the Sacrifice Ritual (DEMON_VISUAL_TRANSFORMATION.md § 18) to walk back
# the Demon transformation and restore the original mortal class.
# For non-Demon characters these are empty / default.
@export var pre_lucifer_class_id: StringName = &""              # the soul that walked the gate
@export var pre_lucifer_skill_node_ids: Array[StringName] = []  # skill tree backup
@export var lucifer_walked_back: bool = false                   # one-way flag; true after sacrifice
@export var carries_sacrifice_scar: bool = false                # white scar awarded post-sacrifice

# === Living Character state (Tier 2; updates over time during play) ===
# These fields mutate during gameplay rather than being set in the creator.
@export var racial_cosmetic_progress: float = 0.0  # 0..1 toward Race.earned_cosmetic_id
@export var racial_cosmetic_unlocked: bool = false
@export var wound_mutation_stage: int = 0          # Wound-Marked only, 0..4, locked by player toggle
@export var wound_mutation_locked: bool = false
@export var apothecary_hp_drinks: int = 0
@export var apothecary_mana_drinks: int = 0
@export var apothecary_stamina_drinks: int = 0
@export var apothecary_champion_drinks: int = 0

# === Time-of-creation gifts (set once at character creation, immutable) ===
# Each is a flag indicating an event was active when this character was made.
@export var gift_eclipse_halo: bool = false
@export var gift_blood_moon_eyes: bool = false
@export var gift_sun_dawn_aura: bool = false
@export var gift_dark_solstice_trail: bool = false
@export var gift_founder_mark_year: int = 0  # 0 = no founder gift, otherwise the year of creation

# Helper: returns true if this appearance has any time-of-creation gifts active.
func has_temporal_gifts() -> bool:
	return (gift_eclipse_halo or gift_blood_moon_eyes
		or gift_sun_dawn_aura or gift_dark_solstice_trail
		or gift_founder_mark_year > 0)

# Helper: total apothecary saturation across all potion types.
func total_potion_saturation() -> int:
	return apothecary_hp_drinks + apothecary_mana_drinks + apothecary_stamina_drinks + apothecary_champion_drinks

# Helper: returns the dominant potion saturation (which type the character has drunk most of).
func dominant_potion_type() -> StringName:
	var counts := {
		&"hp": apothecary_hp_drinks,
		&"mana": apothecary_mana_drinks,
		&"stamina": apothecary_stamina_drinks,
		&"champion": apothecary_champion_drinks,
	}
	var dominant: StringName = &""
	var best: int = 0
	for k in counts.keys():
		var v: int = counts[k]
		if v > best:
			best = v
			dominant = k
	return dominant

# Helper: cap apothecary drink counts at 1000 (visual saturation peak).
func record_potion_drink(potion_type: StringName) -> void:
	match potion_type:
		&"hp":       apothecary_hp_drinks = min(1000, apothecary_hp_drinks + 1)
		&"mana":     apothecary_mana_drinks = min(1000, apothecary_mana_drinks + 1)
		&"stamina":  apothecary_stamina_drinks = min(1000, apothecary_stamina_drinks + 1)
		&"champion": apothecary_champion_drinks = min(1000, apothecary_champion_drinks + 1)

# Helper: validation. Returns empty array if valid, otherwise list of error strings.
func validate() -> Array:
	var errs: Array = []
	if class_id == &"":
		errs.append("class_id is required")
	if race_id == &"":
		errs.append("race_id is required")
	if gender != &"male" and gender != &"female":
		errs.append("gender must be &\"male\" or &\"female\"")
	if gender == &"female" and beard_style != 0:
		errs.append("beard_style only valid for male characters")
	return errs
