extends "res://scripts/enemies/enemy_base.gd"
class_name TankMob

# Tank-pattern AI. Slow, high-HP, big-damage swing. The "wall of meat"
# that doesn't go down quickly. Punishes players who try to face-tank;
# rewards spacing / kiting.
#
# Behavior:
#   - Acquires target same as EnemyBase.
#   - 0.7x base move speed — visibly slower than grunts.
#   - 2.5x HP — the player can SEE this mob's bar barely move per hit.
#   - 1.6x contact damage with a longer windup so the player has time
#     to read and dodge. Missing a dodge = catastrophic.
#   - Larger attack_radius so the swing covers more ground (tank's
#     greatsword sweep, not a fencing thrust).
#   - Wider rim color (deep purple) so the player reads the tier from
#     across the arena.

func _ready() -> void:
	super._ready()
	move_speed = move_speed * 0.7
	max_hp = max_hp * 2.5         # serious sustain
	contact_damage = contact_damage * 1.6
	attack_range = 3.2            # bigger swing reach
	attack_radius = 2.4           # wider AOE telegraph
	attack_cooldown = 2.4         # slow swings, big punishment per
	attack_windup = 1.2           # generous read window
	hp = max_hp
	# Deep purple rim — visual TIER signal at a glance.
	rim_color = Color(0.65, 0.30, 0.85, 1.0)
	rim_strength = 0.85
