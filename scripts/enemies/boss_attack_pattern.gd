extends Resource
class_name BossAttackPattern

# A single attack the boss can perform. BossBase's AI selects from a phase-specific
# pattern list, telegraphs the wind-up, executes the hit-frame, then enters recovery.
# Designed for Elden-Ring-style read-and-react gameplay.

enum Shape {
	SINGLE_TARGET,    # tracks current target, cone or ray
	FORWARD_CONE,     # fixed cone in front, telegraphed
	AOE_AROUND_BOSS,  # circle centered on boss
	AOE_GROUND,       # marked ground spot, lands after delay
	LINE,             # straight line, dash or beam
	PROJECTILE,       # spawned projectile, dodgeable in flight
	ARENA_WIDE,       # full arena sweep, requires position-counter
	LEAP,             # boss arcs through the air to target's last position
	                  # and lands with a shockwave AOE. The landing decal
	                  # is the player's dodge cue, get out of the circle.
	CHARGE,           # boss sprints in a straight line at high speed,
	                  # damaging anything in its path. Sidestep, don't backpedal.
}

@export var id: StringName = &""
@export var display_name: String = ""
@export_multiline var tell_description: String = ""  # what the boss does to telegraph

@export_group("Cadence")
@export var windup_seconds: float = 1.2     # telegraph time
@export var execute_seconds: float = 0.2    # active hit window
@export var recovery_seconds: float = 0.8   # vulnerable window after
@export var cooldown: float = 6.0           # per-pattern reuse delay

@export_group("Shape and Range")
@export var shape: Shape = Shape.SINGLE_TARGET
@export var range: float = 4.0
@export var radius: float = 3.0      # for AOE / cone
@export var arc_degrees: float = 60.0 # for cone

@export_group("Damage")
@export var base_damage: float = 80.0
@export var damage_type: int = 0      # Ability.DamageType
@export var armor_pen: float = 0.0
@export var inflicts_status: StatusEffect

@export_group("Phase Restriction")
@export var min_phase: int = 0   # 0 = available from start; bumps to phase index
@export var max_phase: int = 99  # last phase that can use this attack

@export_group("Selection Tuning")
# Higher weight = more likely to fire each cycle. Common attacks weight 5-10,
# climactic capstones weight 1. Tiamat's "World-Wave" stays rare even on cooldown.
@export var priority_weight: float = 5.0
# Minimum phase HP the boss must be below to use this. Lets you reserve attacks
# for desperate moments without changing phase index.
@export var requires_hp_below_pct: float = 1.0
# If true, this pattern is allowed even when the boss can't currently land it
# (used for AOE arena-wide patterns that hit anywhere).
@export var ignores_reachability: bool = false

@export_group("Telegraph")
@export var telegraph_color: Color = Color(1.0, 0.3, 0.3, 0.5)  # red ground decal
@export var telegraph_sound_id: StringName = &""
@export var dodge_window: float = 0.4  # how long the player has to escape
