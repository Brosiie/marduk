extends Resource
class_name CombatScar

# A single visible scar on the character's body. Created when a hit takes
# >= 25% of max HP in a single blow. See CHARACTER_DESIGN.md § 8.5.1.

@export var scar_id: StringName = &""              # unique per scar instance
@export var location: StringName = &"chest"        # body location (chest/back/arm_left/etc)
@export_range(0.0, 1.0) var intensity: float = 0.5 # 0..1
@export var element: int = 0                       # Ability.DamageType (drives color)
@export var source_id: StringName = &""            # mob/boss id that caused it
@export var source_display_name: String = ""
@export var timestamp: int = 0                     # unix seconds
@export var is_boss_scar: bool = false             # never fully heal
@export_range(0.0, 1.0) var heal_progress: float = 0.0  # 0 = fresh, 1 = fully faded

# Element color table (matches DamageFloater)
const ELEMENT_COLORS := {
	0: Color(0.55, 0.20, 0.18),  # PHYSICAL: dark red
	1: Color(0.40, 0.32, 0.85),  # ARCANE: violet
	2: Color(0.25, 0.10, 0.05),  # FIRE: charred black-red
	3: Color(0.70, 0.85, 1.00),  # FROST: pale frostbitten
	4: Color(0.55, 0.50, 0.30),  # LIGHTNING: scorched
	5: Color(0.85, 0.70, 0.30),  # HOLY: gold-edged
	6: Color(0.20, 0.10, 0.30),  # SHADOW: ink-black
}

func element_color() -> Color:
	return ELEMENT_COLORS.get(element, ELEMENT_COLORS[0])

# Visible alpha based on intensity and heal progress.
# Boss scars cap at 30% faded — they always remain visible.
func visible_alpha() -> float:
	var fade_cap: float = 0.30 if is_boss_scar else 1.0
	var faded: float = min(heal_progress, fade_cap)
	return intensity * (1.0 - faded)
