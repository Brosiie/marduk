extends Ability
class_name StealthAbility

# Toggleable stealth. Assassin signature.
# In stealth:
#   - Mob detection radius reduced to `stealth_detection_radius` (3m default vs 9m).
#   - Other players (PvP) cannot see this player until first attack.
#   - First strike from stealth gets `out_of_stealth_damage_mult` bonus.
# Breaks on:
#   - Dealing damage with any non-stealth ability.
#   - Taking damage.
#   - Manual cancel.
#   - Duration expiry (if duration > 0; -1 = until break).

@export var stealth_detection_radius: float = 3.0
@export var out_of_stealth_damage_mult: float = 1.5  # ambush bonus
@export var visual_alpha: float = 0.25  # mesh transparency for the local player
@export var ambush_crit_guarantee: bool = true  # the first hit from stealth always crits
@export var pvp_invisible: bool = true  # other players cannot target this player
@export var duration: float = -1.0  # -1 = indefinite

func _init() -> void:
	id = &"stealth"
	display_name = "Stealth"
	description = "Vanish from sight. Mob detection radius reduced to 3m. Invisible to enemy players until first attack. First strike from stealth crits and deals 50% extra damage."
	mana_cost = 25.0
	cost_resource = &"stamina"
	cooldown = 30.0
	cast_time = 0.0
	target_mode = Ability.TargetMode.SELF
	base_damage = 0.0
