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

# Map of faction_id -> minimum rep value required to ACCEPT this quest.
# Empty = no faction prereq. Non-empty entries are AND-ed: all listed
# factions must meet their threshold. Use FactionRegistry tier
# breakpoints (3000 = Friendly, 9000 = Honored, 21000 = Revered).
# Example: {&"crown": 3000} = "must be Friendly with Crown."
@export var min_faction_rep: Dictionary = {}

func meets_faction_requirements() -> bool:
	if min_faction_rep.is_empty():
		return true
	var fr: Node = Engine.get_main_loop().root.get_node_or_null("/root/FactionRegistry") if Engine.get_main_loop() else null
	if fr == null or not fr.has_method("get_rep"):
		return true  # registry not loaded, fail open so tests + offline don't soft-lock
	for fid in min_faction_rep.keys():
		var threshold: int = int(min_faction_rep[fid])
		if int(fr.get_rep(fid)) < threshold:
			return false
	return true

func unmet_faction_summary() -> String:
	# Human-readable list of unmet faction requirements, eg
	# "Friendly with The Iron Crown". Empty string when all met.
	if min_faction_rep.is_empty():
		return ""
	var fr: Node = Engine.get_main_loop().root.get_node_or_null("/root/FactionRegistry") if Engine.get_main_loop() else null
	if fr == null:
		return ""
	var parts: Array[String] = []
	for fid in min_faction_rep.keys():
		var threshold: int = int(min_faction_rep[fid])
		if int(fr.get_rep(fid)) < threshold:
			var tier_name: String = fr.tier_for(threshold) if fr.has_method("tier_for") else str(threshold)
			var f = fr.get_faction(fid) if fr.has_method("get_faction") else null
			var fname: String = f.display_name if f else String(fid)
			parts.append("%s with %s" % [tier_name, fname])
	return ", ".join(parts)

# Faction-conflict gate: quests can declare a pair_key they're
# unavailable during. Use case: Sanctum-Mother stabilization quests
# cannot be ACCEPTED while druid_vs_inquisition is at OPEN_WAR, because
# the Druids are fighting a war, not running errands. Soft gate:
# becomes offerable again when conflict cools to SKIRMISH or lower.
# This is meaningful design, war is reversible but the quests it
# pauses are not deferred; the Druid path is genuinely closed while
# the war is hot, and the player must push rep to cool it.
# Format: pair_key (StringName). Empty (&"") means no gate.
@export var disabled_during_open_war_with: StringName = &""

func meets_conflict_requirements() -> bool:
	if disabled_during_open_war_with == &"":
		return true
	var fcr: Node = Engine.get_main_loop().root.get_node_or_null("/root/FactionConflictRegistry") if Engine.get_main_loop() else null
	if fcr == null or not fcr.has_method("get_state"):
		return true  # registry not loaded, fail open
	var state: String = String(fcr.get_state(disabled_during_open_war_with))
	# Currently gated only at OPEN_WAR. SKIRMISH+ still allows the
	# quest, on the theory that border raids are exactly when the
	# faction needs the player's help most.
	return state != "OPEN_WAR"

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
