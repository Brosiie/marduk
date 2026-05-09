extends "res://scripts/enemies/enemy_base.gd"
class_name RusherMob

# Rusher-pattern AI. Glass-cannon: fast move speed, low HP, low windup,
# zero cooldown. Punishes players who try to kite, it closes the gap
# in 2 seconds from any reasonable distance.
#
# Behavior:
#   - Acquires target same as EnemyBase.
#   - When in attack_range, INSTANT attack (no windup), high damage per
#     hit. After the strike, brief recovery THEN immediate re-engage.
#   - 1.4x base move speed makes it feel like a charging dog.
#   - Lower HP than other roles so the player can burst it down before
#     it gets too many hits in.
#
# Designed as the "wake up" mob in Bond's playtest: every player who
# encounters one learns IMMEDIATELY that backpedaling is not a strategy.

func _ready() -> void:
	super._ready()
	# Rusher tuning, applied AFTER super so spawner-level scaling
	# (level / prestige) compounds correctly on top of the base values.
	move_speed = move_speed * 1.4
	max_hp = max_hp * 0.65        # ~half HP, kill it fast or eat hits
	contact_damage = contact_damage * 1.25
	attack_range = 2.4            # slightly extended reach for the lunge
	attack_cooldown = 0.6         # back-to-back hits
	attack_windup = 0.20          # nearly-instant, no telegraph mercy
	hp = max_hp
	# Brighter rim color so the player CAN tell rushers from grunts at
	# a glance, orange instead of mob default crimson.
	rim_color = Color(1.00, 0.55, 0.20, 1.0)
	rim_strength = 0.85
