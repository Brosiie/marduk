extends Node
class_name AchievementTracker

# Per-player achievement progress. Listens to gameplay events (kills, quests,
# zones discovered, etc) and updates progress. Unlocks fire as permanent flags
# so they survive prestige.

signal achievement_unlocked(achievement: Achievement)
signal title_unlocked(title_id: StringName)

@export var owner_player: Node

# Counters keyed by tag (eg "demon", "any") for KILL_COUNT achievements.
var kill_counts: Dictionary = {}     # StringName -> int
# Per-boss state for no-hit / time-attack tracking
var current_boss_fight: Dictionary = {}  # boss_id -> {start_time, took_damage, start_player_level}
# Earned achievement ids (mirror of permanent flags for fast lookup)
var earned: Dictionary = {}  # StringName -> true

func _ready() -> void:
	# Restore earned set from permanent flags
	for ach: Achievement in AchievementRegistry.all_achievements():
		if SaveFlags.has_permanent(StringName("achievement_" + String(ach.id))):
			earned[ach.id] = true

func is_earned(id: StringName) -> bool:
	return earned.has(id)

func unlocked_titles() -> Array[StringName]:
	# All titles unlocked through any earned achievement.
	var arr: Array[StringName] = []
	for id in earned.keys():
		var ach: Achievement = AchievementRegistry.get_achievement(id)
		if ach and ach.awards_title_id != &"":
			arr.append(ach.awards_title_id)
	return arr

# === Event hooks ===
func on_enemy_killed(enemy: Node, tags: Array = []) -> void:
	# Universal kill counter
	_inc_kill_count(&"any")
	for t in tags:
		_inc_kill_count(StringName(t))
	# Boss-specific
	if enemy and enemy is BossBase:
		_resolve_boss_kill(enemy)

func on_damage_taken(amount: float) -> void:
	# Mark any active boss-fight as "took damage" for no-hit achievement tracking.
	for boss_id in current_boss_fight.keys():
		current_boss_fight[boss_id]["took_damage"] = true

func on_boss_engaged(boss: BossBase) -> void:
	current_boss_fight[boss.boss_id] = {
		"start_time": Time.get_ticks_msec() / 1000.0,
		"took_damage": false,
		"start_player_level": owner_player.stats.level if owner_player and owner_player.stats else 1
	}

func on_zone_discovered(zone_id: StringName) -> void:
	SaveFlags.set_permanent(StringName("zone_discovered_" + String(zone_id)), true)
	_check_trigger(Achievement.TriggerKind.ZONE_DISCOVERED, {"zone_id": zone_id})
	# All-zones rollup
	if _all_zones_visited():
		_check_trigger(Achievement.TriggerKind.ALL_ZONES_DISCOVERED, {})

func on_landmark_examined(landmark_id: StringName) -> void:
	SaveFlags.set_permanent(StringName("landmark_examined_" + String(landmark_id)), true)
	_check_trigger(Achievement.TriggerKind.LANDMARK_EXAMINED, {"landmark_id": landmark_id})

func on_quest_completed(quest_id: StringName) -> void:
	_check_trigger(Achievement.TriggerKind.QUEST_COMPLETED, {"quest_id": quest_id})

func on_profession_maxed(profession_id: StringName) -> void:
	_check_trigger(Achievement.TriggerKind.PROFESSION_MAXED, {"profession_id": profession_id})
	if _all_professions_maxed():
		_check_trigger(Achievement.TriggerKind.ALL_PROFESSIONS_MAXED, {})

func on_prestige_reached(cycle_n: int) -> void:
	_check_trigger(Achievement.TriggerKind.PRESTIGE_REACHED, {"cycle_n": cycle_n})

func on_item_obtained(item_id: StringName) -> void:
	_check_trigger(Achievement.TriggerKind.ITEM_OBTAINED, {"item_id": item_id})

# === Internal ===
func _inc_kill_count(tag: StringName) -> void:
	kill_counts[tag] = int(kill_counts.get(tag, 0)) + 1
	# Re-check kill-count achievements
	for ach: Achievement in AchievementRegistry.all_achievements():
		if ach.trigger == Achievement.TriggerKind.KILL_COUNT:
			var data: Dictionary = ach.trigger_data
			if StringName(data.get("tag", "")) == tag:
				if int(kill_counts[tag]) >= int(data.get("count", 999999)):
					_award(ach)

func _resolve_boss_kill(boss: BossBase) -> void:
	var fight: Dictionary = current_boss_fight.get(boss.boss_id, {})
	var fight_time: float = (Time.get_ticks_msec() / 1000.0) - float(fight.get("start_time", 0))
	var no_hit: bool = not bool(fight.get("took_damage", true))
	var start_lvl: int = int(fight.get("start_player_level", 999))

	# BOSS_DEFEATED
	_check_trigger(Achievement.TriggerKind.BOSS_DEFEATED, {"boss_id": boss.boss_id})

	# BOSS_DEFEATED_NO_HIT
	if no_hit:
		_check_trigger(Achievement.TriggerKind.BOSS_DEFEATED_NO_HIT, {"boss_id": boss.boss_id})

	# BOSS_DEFEATED_UNDER_TIME
	for ach: Achievement in AchievementRegistry.all_achievements():
		if ach.trigger == Achievement.TriggerKind.BOSS_DEFEATED_UNDER_TIME:
			var data: Dictionary = ach.trigger_data
			if StringName(data.get("boss_id", "")) == boss.boss_id:
				if fight_time <= float(data.get("seconds", 0)):
					_award(ach)

	# BOSS_DEFEATED_AT_LEVEL
	for ach: Achievement in AchievementRegistry.all_achievements():
		if ach.trigger == Achievement.TriggerKind.BOSS_DEFEATED_AT_LEVEL:
			var data: Dictionary = ach.trigger_data
			if StringName(data.get("boss_id", "")) == boss.boss_id:
				if start_lvl <= int(data.get("max_level", 0)):
					_award(ach)

	current_boss_fight.erase(boss.boss_id)

func _check_trigger(kind: int, data: Dictionary) -> void:
	for ach: Achievement in AchievementRegistry.all_achievements():
		if ach.trigger != kind:
			continue
		if _data_matches(ach.trigger_data, data):
			_award(ach)

func _data_matches(required: Dictionary, given: Dictionary) -> bool:
	for k in required.keys():
		if not given.has(k):
			return false
		# StringName/int/string comparisons
		if String(given[k]) != String(required[k]):
			# numeric tolerant compare
			if typeof(given[k]) in [TYPE_INT, TYPE_FLOAT] and typeof(required[k]) in [TYPE_INT, TYPE_FLOAT]:
				if float(given[k]) < float(required[k]):
					return false
			else:
				return false
	return true

func _award(ach: Achievement) -> void:
	if earned.has(ach.id):
		return
	earned[ach.id] = true
	SaveFlags.set_permanent(StringName("achievement_" + String(ach.id)), true)

	# Apply rewards
	if owner_player and owner_player.stats:
		if ach.xp_reward > 0:
			owner_player.stats.gain_xp(ach.xp_reward)
		if ach.skill_point_reward > 0:
			owner_player.stats.unspent_skill_points += ach.skill_point_reward
	if owner_player and owner_player.has_method("get_inventory"):
		var inv = owner_player.get_inventory()
		if inv and ach.gold_reward > 0:
			inv.add_gold(ach.gold_reward)
	if ach.awards_title_id != &"":
		SaveFlags.set_permanent(StringName("title_unlocked_" + String(ach.awards_title_id)), true)
		title_unlocked.emit(ach.awards_title_id)

	achievement_unlocked.emit(ach)

func _all_zones_visited() -> bool:
	for z: Zone in WorldMap.all_zones():
		if not SaveFlags.has_permanent(StringName("zone_discovered_" + String(z.id))):
			return false
	return true

func _all_professions_maxed() -> bool:
	if not owner_player:
		return false
	var pm: ProfessionManager = owner_player.get_node_or_null("ProfessionManager")
	if not pm:
		return false
	for prof_id in [&"smithing", &"mining", &"woodcutting", &"crafting"]:
		if pm.level_of(prof_id) < ProfessionManager.MAX_LEVEL:
			return false
	return true
