extends Node

# Prestige (Champion's Cycle / NG+) system.
#
# At level 100, the player can ascend. Ascension:
#   - Resets level to 1, XP to 0.
#   - KEEPS skill points spent and unlocked skill nodes (full toolkit retained).
#   - KEEPS unspent skill points (any banked).
#   - KEEPS permanent unlocks: Demon class, Sun Breathing, achievements.
#   - CLEARS run flags: Tiamat alive again, dungeons un-cleared, quests reset.
#   - INCREMENTS prestige_level counter (saved as permanent flag).
#
# Each prestige tier scales:
#   - Enemy difficulty: hp x (1 + prestige), damage x (1 + prestige), xp_reward x (1 + prestige).
#   - Loot drop chance: x (1 + prestige).
#   - Rare item rolls: extra rolls equal to prestige level.
#
# Cycle 0 = first playthrough. Cycle 1 = "second time around" (Bond's words: 2x diff, 2x rewards).
# Cycle 2 = NG+2 = 3x. No upper cap; bring sand for the long sit.

const MAX_LEVEL := 100
const PRESTIGE_FLAG := &"prestige_level"

signal prestige_completed(new_prestige_level: int)
signal max_level_reached  # fires once when player first hits level 100

func _ready() -> void:
	pass

# === Read-only API for the rest of the game ===
func current_prestige_level() -> int:
	return int(SaveFlags.get_permanent(PRESTIGE_FLAG, 0))

func difficulty_multiplier() -> float:
	# Cycle 0 -> 1.0, Cycle 1 -> 2.0, Cycle 2 -> 3.0, ...
	return 1.0 + float(current_prestige_level())

func loot_multiplier() -> float:
	return 1.0 + float(current_prestige_level())

func bonus_loot_rolls() -> int:
	return current_prestige_level()  # 1 extra roll per cycle

# === Eligibility ===
func can_prestige(stats) -> bool:
	if not stats:
		return false
	return stats.level >= MAX_LEVEL

# === Ascension ===
# Returns true if the cycle was performed.
# `player` should be the live Player node so HP can be reset to new max.
func ascend(player) -> bool:
	if not player or not player.stats:
		return false
	if not can_prestige(player.stats):
		return false

	# Bump permanent counter
	var new_level := SaveFlags.increment_permanent(PRESTIGE_FLAG, 1)

	# Reset run state (bosses, quests, dungeons cleared, NPC progression)
	SaveFlags.clear_run_flags()

	# Reset level + XP, keep skills + skill points + unlocked node ids
	var stats = player.stats
	stats.level = 1
	stats.xp = 0
	# DO NOT clear: stats.unspent_skill_points, stats.unlocked_skill_node_ids
	# They survive ascension by design.

	# Recompute base from class+level=1, then re-apply all skill node effects on top.
	stats.recompute_base()
	stats.apply_all_skill_effects()

	# Heal to new (level-1) max
	stats.hp = stats.max_hp
	stats.mana = stats.max_mana

	# Notify
	if player.has_signal("hp_changed"):
		player.hp_changed.emit(stats.hp, stats.max_hp)
	if player.has_signal("mana_changed"):
		player.mana_changed.emit(stats.mana, stats.max_mana)

	prestige_completed.emit(new_level)
	return true

# Called by PlayerStats once when level first hits MAX_LEVEL in a cycle.
func notify_max_level() -> void:
	max_level_reached.emit()

# === World scaling helpers consumed by enemies and loot tables ===
func scale_enemy_hp(base: float) -> float:
	return base * difficulty_multiplier()

func scale_enemy_damage(base: float) -> float:
	return base * difficulty_multiplier()

func scale_xp_reward(base: int) -> int:
	return int(base * difficulty_multiplier())

func roll_loot_chance(base_chance: float) -> bool:
	# `base_chance` is 0.0-1.0; effective chance = base * loot_multiplier(), capped at 1.0
	return randf() < min(1.0, base_chance * loot_multiplier())
