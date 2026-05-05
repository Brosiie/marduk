extends Node
class_name QuestLog

# Per-player quest tracker. Listens to world events (kills, collects, zone changes)
# and updates objective progress.

signal quest_started(quest: Quest)
signal quest_progressed(quest: Quest, objective_index: int)
signal quest_completed(quest: Quest)
signal quest_turned_in(quest: Quest)

class ActiveQuest:
	var quest: Quest
	var objectives: Array  # of Quest.Objective
	var state: int = Quest.State.ACTIVE

@export var owner_player: Node

var active: Dictionary = {}  # StringName -> ActiveQuest
var completed_ids: Array[StringName] = []

func start(quest: Quest) -> bool:
	if active.has(quest.id) or quest.id in completed_ids:
		return false
	if owner_player and owner_player.stats and quest.min_level > owner_player.stats.level:
		return false
	for prereq in quest.prerequisite_quests:
		if not (prereq in completed_ids):
			return false
	if quest.prerequisite_run_flag != &"" and not SaveFlags.has_run(quest.prerequisite_run_flag):
		return false
	var aq := ActiveQuest.new()
	aq.quest = quest
	aq.objectives = quest.build_objectives()
	aq.state = Quest.State.ACTIVE
	active[quest.id] = aq
	quest_started.emit(quest)
	return true

func report_event(kind: StringName, target_id: StringName, count: int = 1) -> void:
	for aq: ActiveQuest in active.values():
		if aq.state != Quest.State.ACTIVE:
			continue
		for i in range(aq.objectives.size()):
			var obj: Quest.Objective = aq.objectives[i]
			if obj.kind == kind and obj.target_id == target_id and not obj.is_complete():
				obj.current_count = min(obj.required_count, obj.current_count + count)
				quest_progressed.emit(aq.quest, i)
		if _all_complete(aq):
			aq.state = Quest.State.COMPLETED
			quest_completed.emit(aq.quest)

func turn_in(quest_id: StringName) -> bool:
	var aq: ActiveQuest = active.get(quest_id)
	if not aq or aq.state != Quest.State.COMPLETED:
		return false
	# Apply rewards
	if owner_player and owner_player.stats:
		owner_player.stats.gain_xp(aq.quest.xp_reward)
		if aq.quest.skill_point_reward > 0:
			owner_player.stats.unspent_skill_points += aq.quest.skill_point_reward
	if owner_player and owner_player.has_method("get_inventory"):
		var inv: Inventory = owner_player.get_inventory()
		if inv:
			inv.add_gold(aq.quest.gold_reward)
			for it in aq.quest.item_rewards:
				inv.add_item(it, 1)
	# Set flags
	if aq.quest.sets_run_flag != &"":
		SaveFlags.set_run(aq.quest.sets_run_flag, true)
	if aq.quest.sets_permanent_flag != &"":
		SaveFlags.set_permanent(aq.quest.sets_permanent_flag, true)
	aq.state = Quest.State.TURNED_IN
	completed_ids.append(quest_id)
	active.erase(quest_id)
	quest_turned_in.emit(aq.quest)
	return true

func _all_complete(aq: ActiveQuest) -> bool:
	for obj: Quest.Objective in aq.objectives:
		if not obj.is_complete():
			return false
	return true
