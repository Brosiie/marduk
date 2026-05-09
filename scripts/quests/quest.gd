extends Resource
class_name Quest

# A quest: chain of objectives with rewards on completion. Tracked in a per-character
# QuestLog. Can be class-restricted (some quests only offer for certain classes).

enum State { LOCKED, AVAILABLE, ACTIVE, COMPLETED, FAILED, TURNED_IN }

class Objective:
	var description: String = ""
	var kind: StringName = &""    # eg &"kill", &"collect", &"talk_to", &"reach_zone"
	var target_id: StringName = &"" # boss id, item id, NPC id, zone id
	var required_count: int = 1
	var current_count: int = 0
	func is_complete() -> bool:
		return current_count >= required_count

@export var id: StringName = &""
@export var display_name: String = ""
@export_multiline var description: String = ""
@export var giver_npc_id: StringName = &""
@export var min_level: int = 1
@export var class_restriction: Array[StringName] = []  # empty = any
@export var prerequisite_quests: Array[StringName] = []
@export var prerequisite_run_flag: StringName = &""

@export var objectives_data: Array = []  # serialized: [{description, kind, target_id, required_count}, ...]

@export_group("Rewards")
@export var xp_reward: int = 100
@export var gold_reward: int = 25
@export var item_rewards: Array[Item] = []
@export var skill_point_reward: int = 0
@export var sets_run_flag: StringName = &""    # eg &"prologue_complete"
@export var sets_permanent_flag: StringName = &""

@export_group("Faction Reputation")
# Map of faction_id -> rep delta applied on quest turn-in. Negative values
# damage rep with that faction. Empty by default; only quests with
# diplomatic stakes use this.
# Example: {&"crown": 250, &"black_sail": -100} for a Crown loyalty quest.
@export var faction_rep_changes: Dictionary = {}

func build_objectives() -> Array:
	# Inflate inspector data into Objective instances
	var arr: Array = []
	for d in objectives_data:
		var o := Objective.new()
		o.description = d.get("description", "")
		o.kind = StringName(d.get("kind", ""))
		o.target_id = StringName(d.get("target_id", ""))
		o.required_count = int(d.get("required_count", 1))
		arr.append(o)
	return arr
