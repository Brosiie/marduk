extends Node

# Autoload: 25+ canonical quests. Class prologues, faction storylines, exploration
# beats. Each quest has detailed rewards including titles via achievement tie-ins.

var quests: Dictionary = {}  # StringName -> Quest

func _ready() -> void:
	_register_prologues()
	_register_main_story()
	_register_faction_quests()
	_register_side_quests()
	_register_starter_quests()
	# Restore persisted active+completed+progress from SaveFlags AFTER
	# the quest dictionary is built. Without this, every relaunch
	# resets the player's quest log to empty even if they had an
	# active quest mid-objective. Auto-accepted prologues will
	# re-fire on top of restored state, that's fine because
	# accept_quest no-ops if the quest is already active or completed.
	call_deferred("_load_from_save_flags")

# --- Persistence (via SaveFlags autoload) ---
const _SAVEFLAG_ACTIVE: StringName = &"quests_active"
const _SAVEFLAG_COMPLETED: StringName = &"quests_completed"
const _SAVEFLAG_PROGRESS: StringName = &"quests_progress"

func _save_to_save_flags() -> void:
	var sf: Node = get_node_or_null("/root/SaveFlags")
	if sf == null or not sf.has_method("set_run"):
		return
	# Active quests: list of ids only, re-resolved from `quests` dict
	# at load time so we don't snapshot the (potentially huge) Quest
	# resource into the save file.
	var active_ids: Array = []
	for id in _active.keys():
		active_ids.append(String(id))
	sf.set_run(_SAVEFLAG_ACTIVE, active_ids)
	# Completed quests: same pattern, ids only.
	var completed_ids: Array = []
	for id in _completed.keys():
		completed_ids.append(String(id))
	sf.set_run(_SAVEFLAG_COMPLETED, completed_ids)
	# Progress: dict of quest_id -> Array[int]. Save the full payload
	# as keys-as-strings (StringNames don't ConfigFile-serialize).
	var progress_payload: Dictionary = {}
	for id in _progress.keys():
		progress_payload[String(id)] = _progress[id]
	sf.set_run(_SAVEFLAG_PROGRESS, progress_payload)

func _load_from_save_flags() -> void:
	var sf: Node = get_node_or_null("/root/SaveFlags")
	if sf == null or not sf.has_method("get_run"):
		return
	# SaveFlags.get_run defaults to `false` (bool), not `null`, when the
	# key is absent. Pass an explicit Array/Dictionary default so a
	# fresh save doesn't try to assign bool to typed Array/Dictionary
	# (which crashes Godot 4 typed-variable assignment).
	var active_raw: Variant = sf.get_run(_SAVEFLAG_ACTIVE, [])
	if not (active_raw is Array):
		return  # fresh save or corrupted payload, nothing to restore
	var active_ids: Array = active_raw
	var completed_raw: Variant = sf.get_run(_SAVEFLAG_COMPLETED, [])
	var completed_ids: Array = completed_raw if completed_raw is Array else []
	var progress_raw: Variant = sf.get_run(_SAVEFLAG_PROGRESS, {})
	var progress_payload: Dictionary = progress_raw if progress_raw is Dictionary else {}
	# Rehydrate active quests
	for id_str in active_ids:
		var qid: StringName = StringName(String(id_str))
		var q: Quest = quests.get(qid)
		if q == null:
			continue
		_active[qid] = q
		# Restore progress counters
		var counters: Array[int] = []
		var saved_counters: Variant = progress_payload.get(String(qid))
		if saved_counters is Array:
			for c in saved_counters:
				counters.append(int(c))
		# Pad with zeros if the quest grew objectives since save
		while counters.size() < q.objectives_data.size():
			counters.append(0)
		_progress[qid] = counters
	# Rehydrate completed quests
	for id_str in completed_ids:
		var cid: StringName = StringName(String(id_str))
		var q2: Quest = quests.get(cid)
		if q2:
			_completed[cid] = q2

func get_quest(id: StringName) -> Quest:
	return quests.get(id)

func quests_for_class(class_id: StringName, level: int) -> Array[Quest]:
	var arr: Array[Quest] = []
	for q: Quest in quests.values():
		if q.class_restriction.size() > 0 and not (class_id in q.class_restriction):
			continue
		if q.min_level > level:
			continue
		arr.append(q)
	return arr

func _make(id: StringName, name: String, desc: String,
		giver_npc_id: StringName, min_level: int,
		objectives: Array, xp: int, gold: int,
		class_restrict: Array = [],
		sets_run_flag: StringName = &"") -> Quest:
	var q := Quest.new()
	q.id = id
	q.display_name = name
	q.description = desc
	q.giver_npc_id = giver_npc_id
	q.min_level = min_level
	q.objectives_data = objectives
	q.xp_reward = xp
	q.gold_reward = gold
	for c in class_restrict:
		q.class_restriction.append(StringName(c))
	q.sets_run_flag = sets_run_flag
	quests[id] = q
	return q

# ----------------------------------------------------------------
# CLASS PROLOGUES (per class, ends at Ashurim)
# ----------------------------------------------------------------
func _register_prologues() -> void:
	_make(&"prologue_berserker", "The Last of Ash-Step",
		"Return to the Ash-Step camp. Find Hassu the Hooked. End him.",
		&"berserker_intro_npc", 1,
		[
			{"description": "Eliminate Hassu the Hooked", "kind": "kill", "target_id": "raid_captain", "required_count": 1},
			{"description": "Travel to Ashurim", "kind": "reach_zone", "target_id": "ashurim", "required_count": 1}
		],
		1500, 250, [&"berserker"], &"prologue_complete")

	_make(&"prologue_assassin", "The Master's Lie",
		"Climb the Whisper Shrine. Confront Master Sapum.",
		&"assassin_intro_npc", 1,
		[
			{"description": "Defeat Master Sapum", "kind": "kill", "target_id": "corrupt_master", "required_count": 1},
			{"description": "Travel to Ashurim", "kind": "reach_zone", "target_id": "ashurim", "required_count": 1}
		],
		1500, 250, [&"assassin"], &"prologue_complete")

	_make(&"prologue_ronin", "Sword Without Lord",
		"Return to the Sword-Vow Ruins. Find Enforcer Kazat. Settle the matter.",
		&"ronin_intro_npc", 1,
		[
			{"description": "Defeat Kazat the Iron-Faced", "kind": "kill", "target_id": "usurper_enforcer", "required_count": 1},
			{"description": "Travel to Ashurim", "kind": "reach_zone", "target_id": "ashurim", "required_count": 1}
		],
		1500, 250, [&"ronin"], &"prologue_complete")

	_make(&"prologue_ranger", "The Spawn That Came Through",
		"Track the beast. Find it before it finds the next village.",
		&"ranger_intro_npc", 1,
		[
			{"description": "Slay the Glade Terror", "kind": "kill", "target_id": "glade_terror", "required_count": 1},
			{"description": "Travel to Ashurim", "kind": "reach_zone", "target_id": "ashurim", "required_count": 1}
		],
		1500, 250, [&"ranger"], &"prologue_complete")

	_make(&"prologue_mage", "Pages and Ash",
		"Climb the Inkstone Tower. End the Warden. Find Old Asaridu's last book.",
		&"mage_intro_npc", 1,
		[
			{"description": "Defeat the Tower Warden", "kind": "kill", "target_id": "tower_warden", "required_count": 1},
			{"description": "Travel to Ashurim", "kind": "reach_zone", "target_id": "ashurim", "required_count": 1}
		],
		1500, 250, [&"mage"], &"prologue_complete")

	_make(&"prologue_druid", "The Coven Burned",
		"Return to the Coven Glen. End Inquisitor Sahirum. Or do not. The Sanctum-Mother says the choice is yours.",
		&"druid_intro_npc", 1,
		[
			{"description": "Defeat Sahirum the Witch-Burner", "kind": "kill", "target_id": "inquisitor_prime", "required_count": 1},
			{"description": "Travel to Ashurim", "kind": "reach_zone", "target_id": "ashurim", "required_count": 1}
		],
		1500, 250, [&"chaos_druid"], &"prologue_complete")

	_make(&"prologue_paladin_guardian", "The Chapel Stood",
		"The chapel's wounded need defending. Find the siege-master and stop him before the chapel falls.",
		&"paladin_intro_npc", 1,
		[
			{"description": "Defeat the Siege-Master", "kind": "kill", "target_id": "siege_master", "required_count": 1},
			{"description": "Travel to Ashurim", "kind": "reach_zone", "target_id": "ashurim", "required_count": 1}
		],
		1500, 250, [&"paladin_guardian"], &"prologue_complete")

	_make(&"prologue_paladin_lightbringer", "The Chapel Wept",
		"The chapel-master is dying. The siege-master has chosen a path. Walk yours.",
		&"paladin_intro_npc", 1,
		[
			{"description": "Defeat the Siege-Master", "kind": "kill", "target_id": "siege_master", "required_count": 1},
			{"description": "Travel to Ashurim", "kind": "reach_zone", "target_id": "ashurim", "required_count": 1}
		],
		1500, 250, [&"paladin_lightbringer"], &"prologue_complete")

# ----------------------------------------------------------------
# MAIN STORY arc
# ----------------------------------------------------------------
func _register_main_story() -> void:
	_make(&"to_babilim", "The Iron Crown",
		"The Storyteller in Ashurim says you are wanted in Babilim. The Crown has questions, and answers, and more questions.",
		&"storyteller", 5,
		[{"description": "Reach Babilim", "kind": "reach_zone", "target_id": "babilim", "required_count": 1}],
		2000, 500, [], &"reached_babilim")

	_make(&"reed_failure", "The Failed Seal",
		"Mu-Ash, Throat of the Wastes, is feeding on the cracks. General Sin-Mushezib of the Crown wants the seal closed. The seal cannot close. Close the next-best thing.",
		&"general_sin", 18,
		[
			{"description": "Defeat Mu-Ash, Throat of the Wastes", "kind": "kill", "target_id": "reed_demon_lord", "required_count": 1},
		], 5000, 1500)

	_make(&"first_breath_master", "The First Breath-Master",
		"Visit a breathing temple. Any of them. Train under a master. Learn that there is more than one way to draw a breath.",
		&"storyteller", 12,
		[{"description": "Visit any breathing temple", "kind": "reach_zone", "target_id": "stone_dojo", "required_count": 1}],
		1500, 300)

	_make(&"to_tiamat", "The Mother of Wrong",
		"Babilim's edict is failing. The Storyteller and General Sin-Mushezib agree on this. They agree on little else. The path forward is the Black Citadel.",
		&"storyteller", 70,
		[
			{"description": "Reach the Black Citadel", "kind": "reach_zone", "target_id": "black_citadel", "required_count": 1},
			{"description": "Defeat Tiamat", "kind": "kill", "target_id": "tiamat", "required_count": 1}
		], 50000, 25000, [], &"tiamat_defeated")

	_make(&"the_fire_stair", "The Fire Stair",
		"The Sun Gate is open. Below the Sun Gate is a stair of fire. Below the stair is a man with a smile and a contract. The Storyteller says: do not negotiate.",
		&"storyteller", 90,
		[
			{"description": "Reach the Fire Stair", "kind": "reach_zone", "target_id": "fire_stair", "required_count": 1},
			{"description": "Defeat Lucifer", "kind": "kill", "target_id": "lucifer", "required_count": 1}
		], 100000, 50000, [], &"lucifer_defeated")

# ----------------------------------------------------------------
# FACTION QUESTS
# ----------------------------------------------------------------
func _register_faction_quests() -> void:
	_make(&"crown_brigand_pit", "The Crown's Problem",
		"General Sin-Mushezib has an outskirts brigand problem. Brigands have a Crown-soldier problem when you arrive.",
		&"general_sin", 6,
		[{"description": "Clear the Caravan Pit", "kind": "kill", "target_id": "caravan_butcher", "required_count": 1}],
		800, 400)

	_make(&"druid_traitor_grove", "The Traitor in the Grove",
		"The Sanctum-Mother knows there is an Inquisition agent among her druids. She wants you to find them. She knows which one. She will not tell you. Find them yourself.",
		&"sanctum_mother", 36,
		[{"description": "Find and defeat the traitor druid", "kind": "kill", "target_id": "druid_traitor", "required_count": 1}],
		8000, 4000, [&"chaos_druid"])

	_make(&"black_sail_problem", "Three Crowns of Salt",
		"Black-Sail of Lapis Bay has three pirate-king brothers. One is older than the others. He needs reminding.",
		&"lapis_dockmaster", 28,
		[{"description": "Defeat Black-Sail the First", "kind": "kill", "target_id": "pirate_king_first", "required_count": 1}],
		6000, 3000)

	_make(&"inquisitor_prime", "The Witch-Burner's End",
		"Sahirum survives the Glen if you let him. The Druid Sanctum offers a price for his head.",
		&"sanctum_mother", 30,
		[{"description": "Defeat Sahirum the Witch-Burner", "kind": "kill", "target_id": "inquisitor_prime", "required_count": 1}],
		5000, 2500, [&"chaos_druid"])

	_make(&"breathing_master_quest", "Form Seven of Anything",
		"A breathing-master at any of the Six Breaths temples will train you, if you bring proof of mastery. Any Form 7 breathing scroll will do.",
		&"breath_master", 22,
		[{"description": "Bring a Form 7 scroll", "kind": "collect", "target_id": "form_7_scroll", "required_count": 1}],
		3000, 1500, [&"ronin"])

	_make(&"asaridu_legacy", "Old Asaridu's Last Page",
		"The Inkstone Tower's central well still echoes Asaridu's voice. The Arcane Council wants the page he left behind. So does Old Asaridu.",
		&"high_magus", 50,
		[
			{"description": "Reach the Master's Well", "kind": "reach_zone", "target_id": "asaridu_well", "required_count": 1},
			{"description": "Recover the Final Page", "kind": "collect", "target_id": "legendary_mage_final_page", "required_count": 1}
		], 12000, 8000, [&"mage"])

# ----------------------------------------------------------------
# SIDE QUESTS / WORLDBUILDING
# ----------------------------------------------------------------
func _register_side_quests() -> void:
	_make(&"belitu_ledger", "Belitu's Ledger",
		"The innkeeper Belitu has lost her ledger. She suspects a customer took it. She knows who. She will not tell you. Find it.",
		&"belitu", 7,
		[{"description": "Recover Belitu's ledger", "kind": "collect", "target_id": "belitu_ledger", "required_count": 1}],
		500, 200)

	_make(&"oracle_chalk", "Oracle's Chalk",
		"The Oracle of the Pillar is out of chalk. The Crown will not requisition more. You can. The Apothecary in Babilim sells the right kind.",
		&"oracle_attendant", 9,
		[{"description": "Bring chalk to the Oracle", "kind": "collect", "target_id": "oracle_chalk", "required_count": 1}],
		400, 100)

	_make(&"hanging_gardens_keeper", "Garden Keeper's Trouble",
		"Something has been digging up the Hanging Gardens at night. The keeper suspects a Tiamat-spawn. Confirm or deny.",
		&"garden_keeper", 14,
		[{"description": "Investigate the Hanging Gardens disturbance", "kind": "kill", "target_id": "minor_demon", "required_count": 3}],
		1500, 400)

	_make(&"caravan_widow", "The Caravan Widow",
		"A widow at the Iron Crown gates has lost her husband to brigands. She wants his ring back. Not his body. Just the ring.",
		&"caravan_widow_npc", 7,
		[{"description": "Recover the husband's ring", "kind": "collect", "target_id": "caravan_widow_ring", "required_count": 1}],
		700, 250)

	_make(&"flame_temple_pilgrimage", "Pilgrimage to Nergal",
		"The Flame Breathing temple accepts pilgrims who can walk the inner spiral without a torch. The spiral is in total darkness.",
		&"flame_master", 35,
		[{"description": "Walk the Pillar of Nergal in total darkness", "kind": "reach_zone", "target_id": "flame_temple", "required_count": 1}],
		3500, 1500)

	_make(&"sunken_letter", "The Sunken Letter",
		"Lapis Bay's dockmaster has heard of a letter in the Wreck of the Alanak. The letter is for a man who has been dead seventy years. The dockmaster wants to read it anyway.",
		&"lapis_dockmaster", 22,
		[{"description": "Recover the Alanak Letter", "kind": "collect", "target_id": "sunken_letter", "required_count": 1}],
		2000, 800)

	_make(&"the_storytellers_request", "The Storyteller's Request",
		"The Storyteller asks if you would visit every landmark in the Cradle. She is making a list. She will not say of what.",
		&"storyteller", 5,
		[{"description": "Examine all 7 Cradle landmarks", "kind": "examine", "target_id": "cradle_landmarks", "required_count": 7}],
		2500, 1000)

	_make(&"the_oracle_prophecy", "The Oracle Wrote Your Name",
		"The Oracle of the Pillar has written a prophecy on the pillar. It begins with your name. The Crown is interested.",
		&"oracle_attendant", 60,
		[{"description": "Read the Oracle's full prophecy", "kind": "examine", "target_id": "crown_oracle_pillar", "required_count": 1}],
		8000, 0)

# ----------------------------------------------------------------
# Active / completed bookkeeping (used by quest panel + NPC accept)
# ----------------------------------------------------------------
var _active: Dictionary = {}     # quest_id -> Quest (started, not yet finished)
var _completed: Dictionary = {}  # quest_id -> Quest (already turned in)
# Per-active-quest objective counters. Parallel to _active. Each entry is
# Array[int] sized to the quest's objectives_data length; entry [i] is the
# current count for objective i. Reset on accept; never mutates after
# completion.
var _progress: Dictionary = {}   # quest_id -> Array[int]

signal quest_accepted(quest: Quest)
signal quest_completed(quest: Quest)
signal quest_progress(quest: Quest, objective_index: int, count: int)

func accept_quest(id: StringName) -> bool:
	var q: Quest = quests.get(id)
	if q == null:
		return false
	if _active.has(id) or _completed.has(id):
		return false
	# Faction prereq gate. If the player doesn't meet min_faction_rep
	# thresholds, the quest cannot be accepted yet. Toast tells the
	# player why so it doesn't feel like a silent failure.
	if q.has_method("meets_faction_requirements") and not q.meets_faction_requirements():
		var juice = get_node_or_null("/root/Juice")
		var reason: String = q.unmet_faction_summary() if q.has_method("unmet_faction_summary") else "higher reputation"
		if juice and juice.has_method("toast"):
			juice.toast("Locked: need %s" % reason, Color(0.85, 0.55, 0.30), 3.0)
		return false
	# Conflict gate: some quests are unavailable during OPEN_WAR with a
	# specific faction pair. Soft gate, becomes offerable again when the
	# pair cools to SKIRMISH or lower. The quest-giver isn't dismissing
	# the player; they're at war and can't run errands.
	if q.has_method("meets_conflict_requirements") and not q.meets_conflict_requirements():
		var juice2 = get_node_or_null("/root/Juice")
		if juice2 and juice2.has_method("toast"):
			juice2.toast("Locked: open war prevents this quest.", Color(0.95, 0.30, 0.30), 3.0)
		return false
	_active[id] = q
	# Initialize progress counters at zero for each objective.
	var counters: Array[int] = []
	for _i in range(q.objectives_data.size()):
		counters.append(0)
	_progress[id] = counters
	# Mirror to the player's QuestLog so the J-panel UI sees this quest.
	# QuestLog is a passive UI cache; QuestRegistry remains the canonical
	# store. Rewards are granted exclusively in complete_quest below.
	_mirror_to_quest_log_start(q)
	quest_accepted.emit(q)
	_save_to_save_flags()
	# Event-driven autosave so a freshly-accepted quest survives an
	# alt-F4 / crash / power loss between the 60s autosave timer.
	_request_autosave()
	# Cinematic ribbon banner so accepting a quest is a real moment, not
	# a notification stack entry. Falls back to toast if the Juice
	# autoload doesn't expose quest_banner (older builds).
	var juice = get_node_or_null("/root/Juice")
	if juice:
		var subtitle: String = "%d xp · %d gold" % [q.xp_reward, q.gold_reward]
		if juice.has_method("quest_banner"):
			juice.quest_banner("QUEST ACCEPTED", q.display_name, subtitle, Color(0.95, 0.85, 0.30), 3.0)
		else:
			juice.toast("Quest: %s" % q.display_name, Color(0.95, 0.85, 0.30), 3.0)
	return true

func complete_quest(id: StringName) -> bool:
	if not _active.has(id):
		return false
	var q: Quest = _active[id]
	_active.erase(id)
	_progress.erase(id)
	_completed[id] = q
	# Award XP + gold to the player
	var player = get_tree().get_first_node_in_group("player") if get_tree() else null
	if player and "stats" in player and player.stats and player.stats.has_method("gain_xp"):
		player.stats.gain_xp(int(q.xp_reward))
	if player and "stats" in player and player.stats and "gold" in player.stats:
		player.stats.gold += int(q.gold_reward)
	# Apply faction rep changes from the quest. Kill-objective auto-
	# completes never go through QuestLog.turn_in, so they previously
	# silently skipped the rep deltas. The 5 starter faction quests
	# (Crown Loyalty / Black Sail / Druid Friend / etc) ship 250 to
	# 1000 rep deltas that need to fire on auto-complete.
	if q.faction_rep_changes.size() > 0:
		var fr: Node = get_node_or_null("/root/FactionRegistry")
		if fr and fr.has_method("add_rep"):
			for fid in q.faction_rep_changes.keys():
				fr.add_rep(fid, int(q.faction_rep_changes[fid]))
	# Mirror state to the player's QuestLog so the J-panel reflects the
	# completion. We move the entry from QuestLog.active to its
	# completed_ids list and emit quest_turned_in directly rather than
	# calling QuestLog.turn_in (which would double-grant rewards).
	_mirror_to_quest_log_complete(q)
	# Achievement: first quest completion
	var ar = get_node_or_null("/root/AchievementRegistry")
	if ar and ar.has_method("unlock"):
		ar.unlock(&"a_first_quest")
	quest_completed.emit(q)
	_save_to_save_flags()
	# Event-driven autosave so completion progress isn't lost on
	# crash. Quest completions are MAJOR moments, the player is
	# expecting their reward to be permanent.
	_request_autosave()
	# Quest completion ribbon: the BIG moment. Eyebrow says "QUEST
	# COMPLETE", title is the quest name, subtitle summarizes XP + gold +
	# any item rewards. Green tint distinguishes from accept (gold).
	var juice = get_node_or_null("/root/Juice")
	if juice:
		var reward_bits: Array[String] = []
		if q.xp_reward > 0:
			reward_bits.append("%d xp" % q.xp_reward)
		if q.gold_reward > 0:
			reward_bits.append("%d gold" % q.gold_reward)
		if q.item_rewards.size() > 0:
			reward_bits.append("%d item%s" % [q.item_rewards.size(), "" if q.item_rewards.size() == 1 else "s"])
		if q.skill_point_reward > 0:
			reward_bits.append("%d skill point%s" % [q.skill_point_reward, "" if q.skill_point_reward == 1 else "s"])
		var subtitle: String = "  ·  ".join(reward_bits) if reward_bits.size() > 0 else ""
		if juice.has_method("quest_banner"):
			juice.quest_banner("QUEST COMPLETE", q.display_name, subtitle, Color(0.45, 0.95, 0.55), 4.0)
		else:
			juice.toast("✓  Quest Complete: %s" % q.display_name, Color(0.45, 0.95, 0.55), 3.5)
		juice.flash(Color(0.45, 0.95, 0.55), 0.20, 0.4)
		# Triumph audio sting: lodestone cue at high pitch + level-up
		# fanfare layered on top. Big payoff vs the toast's silent reward.
		var ab: Node = get_node_or_null("/root/AudioBus")
		if ab and ab.has_method("play_cue"):
			ab.play_cue(&"level_up", Vector3.ZERO, -2.0, 1.1)
			ab.play_cue(&"lodestone", Vector3.ZERO, -4.0, 1.4)
	return true

# Fire-and-forget autosave to slot 0 (the autosave slot). Skips
# silently if SaveSystem or Player isn't available, not every
# context (e.g. main menu) has a player to snapshot.
func _request_autosave() -> void:
	var ss: Node = get_node_or_null("/root/SaveSystem")
	if ss == null or not ss.has_method("save_slot"):
		return
	var p: Node = get_tree().get_first_node_in_group("player") if get_tree() else null
	if p == null:
		return
	ss.save_slot(0, p)

# Public: bump progress on every active quest whose objectives match
# (kind, target_id). When all objectives of a quest reach their
# required_count, the quest auto-completes.
#
# `kind` examples: "kill" (target_id is mob_id), "lodestone_count"
# (target_id is "lodestone"), "examine" (target_id is landmark_id).
# `delta` is the increment (1 for a single kill, N for batched events).
func progress(kind: StringName, target_id: StringName, delta: int = 1) -> void:
	if delta <= 0:
		return
	var to_complete: Array[StringName] = []
	for quest_id in _active.keys():
		var q: Quest = _active[quest_id]
		var counters: Array = _progress.get(quest_id, [])
		var changed: bool = false
		for i in range(q.objectives_data.size()):
			var obj: Dictionary = q.objectives_data[i]
			var obj_kind: String = String(obj.get("kind", ""))
			var obj_target: String = String(obj.get("target_id", ""))
			if obj_kind != String(kind):
				continue
			# target_id "" means any target of the matching kind
			if obj_target != "" and obj_target != String(target_id):
				continue
			var required: int = int(obj.get("required_count", 1))
			if i < counters.size():
				if counters[i] >= required:
					continue
				counters[i] = min(required, counters[i] + delta)
				changed = true
				quest_progress.emit(q, i, counters[i])
		if changed and _all_objectives_done(q, counters):
			to_complete.append(quest_id)
	# Mirror to the player's QuestLog so the J-panel reflects the new
	# counts. QuestLog.report_event matches the same (kind, target_id,
	# delta) signature so this is a one-line forward.
	_mirror_to_quest_log_progress(kind, target_id, delta)
	for quest_id in to_complete:
		complete_quest(quest_id)
	# Persist the new progress numbers. Skipped completion path
	# already saves via complete_quest, but partial advancements
	# need their own persistence so progress survives a crash mid-
	# objective.
	if to_complete.is_empty():
		_save_to_save_flags()

func _all_objectives_done(q: Quest, counters: Array) -> bool:
	for i in range(q.objectives_data.size()):
		var obj: Dictionary = q.objectives_data[i]
		var required: int = int(obj.get("required_count", 1))
		if i >= counters.size() or counters[i] < required:
			return false
	return true

# ─────── QuestLog UI mirror ───────
# Player has a QuestLog child node that the J-panel UI reads from. We
# keep it in lockstep with QuestRegistry's canonical state so the UI
# shows live data. QuestLog used to be its own quest engine but is now
# a passive cache; rewards live exclusively in QuestRegistry.

func _player_quest_log() -> Node:
	var p: Node = get_tree().get_first_node_in_group("player") if get_tree() else null
	if p == null:
		return null
	return p.get_node_or_null("QuestLog")

func _mirror_to_quest_log_start(q: Quest) -> void:
	var qlog: Node = _player_quest_log()
	if qlog == null or not qlog.has_method("start"):
		return
	# QuestLog.start runs its own min_level + prereq + run_flag gates.
	# Those already passed up at the QuestRegistry level (we got here),
	# so a false return here is OK and we just don't mirror. Common cause
	# of false return: the quest is already in qlog.completed_ids from
	# a prior session (rare but harmless to silently skip).
	qlog.start(q)

func _mirror_to_quest_log_progress(kind: StringName, target_id: StringName, delta: int) -> void:
	var qlog: Node = _player_quest_log()
	if qlog == null or not qlog.has_method("report_event"):
		return
	qlog.report_event(kind, target_id, delta)

func _mirror_to_quest_log_complete(q: Quest) -> void:
	# Move the entry from QuestLog.active to its completed_ids array
	# and emit quest_turned_in. We bypass QuestLog.turn_in to avoid
	# double-granting rewards (already granted in complete_quest above).
	var qlog: Node = _player_quest_log()
	if qlog == null:
		return
	if "active" in qlog and qlog.active.has(q.id):
		qlog.active.erase(q.id)
	if "completed_ids" in qlog and not (q.id in qlog.completed_ids):
		qlog.completed_ids.append(q.id)
	if qlog.has_signal("quest_turned_in"):
		qlog.quest_turned_in.emit(q)

# Public: counter array for an active quest. Returns [] if not active.
# Used by QuestTrackerHUD and InventoryPanel quests panel to render
# "[count / required]" tails.
func get_progress(id: StringName) -> Array:
	return _progress.get(id, [])

func get_active_quests() -> Array:
	return _active.values()

func get_completed_quests() -> Array:
	return _completed.values()

func is_active(id: StringName) -> bool:
	return _active.has(id)

func is_completed(id: StringName) -> bool:
	return _completed.has(id)

# ----------------------------------------------------------------
# STARTER QUESTS (Ashurim NPCs), bind directly to the 3 plaza NPCs
# (Storyteller, Iddinu, Belitu) so a fresh character gets immediate
# objectives the moment they reach Ashurim.
# ----------------------------------------------------------------
func _register_starter_quests_v2() -> void:
	_make(&"q_storyteller_intro", "The World Is Breaking",
		"The Storyteller wants you to attune lodestones across the realm. Three discoveries will satisfy her opening verse.",
		&"storyteller", 1,
		[{"description": "Discover 3 lodestones", "kind": "lodestone_count", "target_id": "lodestone", "required_count": 3}],
		400, 50)
	_make(&"q_iddinu_supplies", "Crates from the Sword-Vow",
		"Iddinu the Quartermaster needs three iron-bound crates recovered from Iron Crown loyalists in the Sword-Vow Ruins.",
		&"iddinu", 1,
		[{"description": "Slay 6 Tashmu's Footmen", "kind": "kill", "target_id": "usurper_footman", "required_count": 6}],
		300, 80)
	_make(&"q_belitu_brother", "Belitu's Brother",
		"Belitu the Market Girl says her twelve-year-old brother walked into The Cradle two days ago. Find him. Or what's left.",
		&"belitu", 1,
		[{"description": "Search The Cradle for the missing boy", "kind": "examine", "target_id": "cradle_brother_marker", "required_count": 1}],
		500, 60)
	_register_faction_starter_quests()

# Five faction-rep starter quests authored on top of the existing trio.
# Each sets faction_rep_changes so completion shifts diplomatic standing.
# Authored to rough-balance: each faction has at least one quest that
# lifts it AND one that hurts it, so player choice carries weight.
func _register_faction_starter_quests() -> void:
	# Iddinu existing supplies quest gets retroactive Crown rep so the
	# starter loop already engages the faction system.
	if quests.has(&"q_iddinu_supplies"):
		quests[&"q_iddinu_supplies"].faction_rep_changes = {&"crown": 250, &"black_sail": -75}

	# IDDINU, Crown loyalty harder line. Big +Crown, moderate -BlackSail.
	var crown_q := _make(&"q_iddinu_crown_loyalty", "Caravan Toll",
		"Iddinu's caravan was hit on the Reed Road. He wants the bandits dealt with, properly, by the Crown's measure of properly. Eight Ash-Step raiders, ten if you're feeling thorough.",
		&"iddinu", 3,
		[{"description": "Slay 8 Ash-Step Raiders", "kind": "kill", "target_id": "raider_grunt", "required_count": 8}],
		600, 150)
	crown_q.faction_rep_changes = {&"crown": 500, &"black_sail": -200}

	# IDDINU, Black Sail side-gig. Quartermaster's running cargo on the
	# side; pirates pay too. +BlackSail, -Crown, forces a real choice.
	var bs_q := _make(&"q_iddinu_blacksail_sidegig", "Side Goods (No Questions)",
		"Iddinu pulls you aside. The Crown audit's on him next week. He's got crates that need to vanish before the auditor arrives. The Black Sail will pay if they make it to the Bay. The Crown will not be pleased if you do this.",
		&"iddinu", 4,
		[{"description": "Move 5 crates (kill 5 Tashmu's Footmen guarding the road)", "kind": "kill", "target_id": "usurper_footman", "required_count": 5}],
		700, 250)
	bs_q.faction_rep_changes = {&"black_sail": 400, &"crown": -300}

	# BELITU, Druid sympathy. Belitu has cousins in the Wound; she sends
	# the player to slow the Inquisition down. +Druids, -Inquisition.
	var druid_q := _make(&"q_belitu_druid_friend", "Cousin Across the Wound",
		"Belitu's cousin is in the Verdant Wound. She heard the Inquisition is coming through. She doesn't want her cousin to be there when they arrive. Slow the Inquisitors down. She'll pay what she has.",
		&"belitu", 3,
		[{"description": "Slay 5 Inquisition Burners", "kind": "kill", "target_id": "witch_burner", "required_count": 5}],
		550, 120)
	druid_q.faction_rep_changes = {&"druids": 400, &"inquisition": -300}

	# STORYTELLER, Six Breaths quest. Bound spirits left over from the
	# old binding-mage tradition. Releasing them is the temple's mercy.
	var sb_q := _make(&"q_storyteller_six_breaths", "The Bound Things Sleep Badly",
		"The Storyteller has been asked, quietly, to find someone willing to release the bound things in the Inkstone Tower's lower archives. The temple cannot order it. The temple does not forget those who try.",
		&"storyteller", 4,
		[{"description": "Release 6 Lesser Binding-Constructs", "kind": "kill", "target_id": "binding_construct", "required_count": 6}],
		600, 100)
	sb_q.faction_rep_changes = {&"six_breaths": 400}

	# STORYTELLER, Inquisition zealotry quest. The Storyteller doesn't
	# love the Inquisition either, but the Wound is the Wound; she'll
	# accept its containment as harm-reduction. Burns the player toward
	# the Inquisition.
	var inq_q := _make(&"q_storyteller_inquisition_choice", "What the Wound Eats",
		"The Storyteller will not pretend she likes them. But she will accept a Tiamat-spawn dead is better than a Tiamat-spawn breeding. Hunt six Tiamat-touched wolves. The Inquisition will hear of it.",
		&"storyteller", 4,
		[{"description": "Slay 6 Tiamat-Touched Wolves", "kind": "kill", "target_id": "corrupted_wolf", "required_count": 6}],
		600, 130)
	inq_q.faction_rep_changes = {&"inquisition": 350, &"druids": -150}

	# SANCTUM-MOTHER, low-level Wound tending. Cull the corruption's
	# physical avatars at the Glen's edge. Lower-tier than the
	# Inquisition's burn-everything approach; smaller individual reward
	# but the player is actually REDUCING Wound creep (Druid-positive
	# quests subtract from WoundRegistry on completion).
	var sm_q1 := _make(&"q_sanctum_tending_glen", "Tending the Glen",
		"The Sanctum-Mother needs the Glen's edge cleaner before the new moon. Reed creepers are pushing the boundary. Cull eight. Bring nothing back; the Glen takes its own offerings.",
		&"sanctum_mother", 5,
		[{"description": "Cull 8 Reed Creepers at the Glen's edge", "kind": "kill", "target_id": "reed_creeper", "required_count": 8}],
		700, 160)
	sm_q1.faction_rep_changes = {&"druids": 350, &"inquisition": -120}

	# SANCTUM-MOTHER, harder, gated on Friendly-with-Druids. The
	# Sanctum-Mother asks the player to find and end an Inquisition
	# Burner who has been salting wells inside the Wound. Bigger creep
	# reduction, bigger rep delta. min_faction_rep gate enforces that
	# the player has actually been TENDING the Druids before she
	# trusts them with this one.
	var sm_q2 := _make(&"q_sanctum_burner_at_the_edge", "Bury the Burner at the Edge",
		"A Witch-Burner has been salting our wells from the Inquisition side of the boundary. The vines refuse to grow near the salt. End him quietly. The Sanctum will see you cared for after.",
		&"sanctum_mother", 10,
		[{"description": "Slay the Witch-Burner at the Wound boundary", "kind": "kill", "target_id": "witch_burner_elite", "required_count": 1}],
		1400, 380)
	sm_q2.faction_rep_changes = {&"druids": 700, &"inquisition": -400}
	sm_q2.min_faction_rep = {&"druids": 3000}  # Friendly with Druids required
	# Conflict gate: while druid_vs_inquisition is at OPEN_WAR, the
	# Sanctum-Mother is running a war, not handing out side-quests.
	# Soft gate, becomes offerable again when conflict cools.
	sm_q1.disabled_during_open_war_with = &"druid_vs_inquisition"
	sm_q2.disabled_during_open_war_with = &"druid_vs_inquisition"

	# CAPTAIN VASHTU, low-level Inquisition burn. The Inquisition's
	# counter-lever to the Sanctum-Mother. Same shape, opposite rep
	# direction. Lore-critical: completing these pushes BOTH cosmic
	# threats UP via the registry subscribers. The player can see this
	# in the HUD widgets; the Captain cannot. That's the tragedy.
	var vq1 := _make(&"q_vashtu_purify_grove", "Purify the Grove's Edge",
		"Captain Vashtu asks that you cull the salt-demons crowding the grove's edge before they breed deeper. The Sanctum will not authorize the fire; the Censor's Company does not need authorization. Bring her six heads.",
		&"captain_vashtu", 6,
		[{"description": "Slay 6 Salt-Demons at the Wound boundary", "kind": "kill", "target_id": "salt_demon", "required_count": 6}],
		750, 200)
	vq1.faction_rep_changes = {&"inquisition": 350, &"druids": -150}

	# CAPTAIN VASHTU, harder. Strike a Druid agent the Censor has been
	# tracking. min_faction_rep on Inquisition makes the player commit
	# before she trusts them with a Druid kill (which is the line that
	# turns the cold faction tension into something hotter).
	var vq2 := _make(&"q_vashtu_silence_sanctum", "Silence the Sanctum's Hand",
		"The Sanctum has a courier moving between the Glen and Babilim. The Captain wants that courier silenced. She does not say killed; she says silenced. We both know what we mean.",
		&"captain_vashtu", 12,
		[{"description": "Slay the Druid Courier on the Reed Road", "kind": "kill", "target_id": "druid_courier", "required_count": 1}],
		1500, 420)
	vq2.faction_rep_changes = {&"inquisition": 700, &"druids": -500}
	vq2.min_faction_rep = {&"inquisition": 3000}  # Friendly with Inquisition required
	# Symmetric conflict gate: when the war is OPEN, even the Censor
	# can't take new contracts; she's running the war effort.
	vq1.disabled_during_open_war_with = &"druid_vs_inquisition"
	vq2.disabled_during_open_war_with = &"druid_vs_inquisition"

	# ─── THE SEVENTH BREATH (hidden lore unlock) ────────────────────
	# "Sun is the seventh and unspoken." Six Breaths public lore names
	# six disciplines: Flame, Frost, Stone, Wind, Reed, Bone. The
	# seventh is Marduk's own, hidden, taught only to those who have
	# already learned to listen at the temple. Three-stage chain
	# escalating from Honored to Revered gates. Reward is a title +
	# achievement + a permanent flag that other systems can read to
	# alter dialog (the temple masters will speak differently to
	# someone who knows).
	_register_seventh_breath_chain()

func _register_seventh_breath_chain() -> void:
	# Stage 1: Apprentice. The temple acknowledges the player. Gated
	# at Friendly with Six Breaths so the player has to have done
	# their starter quest first. Small reward, sets a flag.
	var sb1 := _make(&"q_seventh_breath_apprentice", "What the Sixth Hears",
		"The Sixth Master takes you aside. He says you breathe like someone who has already lost something. He asks if you would like to learn what the temple does not teach. He will not say more. Not yet.",
		&"flame_master", 12,
		[{"description": "Walk the temple at dawn (visit Lapis Bay temple landmark)", "kind": "examine", "target_id": "six_breaths_temple", "required_count": 1}],
		1200, 200)
	sb1.faction_rep_changes = {&"six_breaths": 300}
	sb1.min_faction_rep = {&"six_breaths": 3000}  # Friendly required
	sb1.sets_permanent_flag = &"seventh_breath_invited"

	# Stage 2: Pilgrimage. The player must learn from each of the Six
	# in turn. reach_zone objectives across the regions where each
	# master teaches. Honored required because asking five other
	# masters to vouch for you means the temple already trusts you.
	var sb2 := _make(&"q_seventh_breath_pilgrimage", "The Six Names of Air",
		"The temple asks you to sit with each of the Six in turn. Flame at the Pillar. Frost in the Bone Mountains. Stone in the Reed Cliffs. Wind on Lapis cliffs. Reed in the Wastes. Bone in the Highlands. None will explain why.",
		&"flame_master", 25,
		[
			{"description": "Sit with the Flame Master", "kind": "reach_zone", "target_id": "flame_temple",     "required_count": 1},
			{"description": "Sit with the Frost Master", "kind": "reach_zone", "target_id": "bone_mountains",  "required_count": 1},
			{"description": "Sit with the Stone Master", "kind": "reach_zone", "target_id": "reed_cliffs",     "required_count": 1},
			{"description": "Sit with the Wind Master",  "kind": "reach_zone", "target_id": "lapis_bay",       "required_count": 1},
			{"description": "Sit with the Reed Master",  "kind": "reach_zone", "target_id": "the_reed_wastes", "required_count": 1},
			{"description": "Sit with the Bone Master",  "kind": "reach_zone", "target_id": "shrieking_highlands", "required_count": 1},
		],
		3500, 800)
	sb2.faction_rep_changes = {&"six_breaths": 800}
	sb2.min_faction_rep = {&"six_breaths": 9000}  # Honored required
	sb2.prerequisite_quests = [&"q_seventh_breath_apprentice"]
	sb2.sets_permanent_flag = &"seventh_breath_pilgrimage_done"

	# Stage 3: The Unspoken. The temple finally names the Seventh. The
	# player walks alone into the Sun Gate's threshold and meets the
	# Seventh Master, who is and is not Marduk himself. Revered with
	# Six Breaths required because this isn't a lesson, it's a gift.
	# Reward: title + permanent flag + a real ability slot. Other
	# systems can read seventh_breath_known to alter Master dialog
	# from formal to family.
	var sb3 := _make(&"q_seventh_breath_unspoken", "The Seventh, and Unspoken",
		"The Sixth Master tells you to walk the Sun Gate at noon. Alone. He says you will not find a master there. He says you will find a brother. He says: when the sun stops, listen.",
		&"flame_master", 40,
		[{"description": "Walk the Sun Gate at noon", "kind": "reach_zone", "target_id": "sun_gate", "required_count": 1}],
		8000, 0)  # no gold; this isn't a transaction
	sb3.faction_rep_changes = {&"six_breaths": 2000}
	sb3.min_faction_rep = {&"six_breaths": 21000}  # Revered required
	sb3.prerequisite_quests = [&"q_seventh_breath_pilgrimage"]
	sb3.sets_permanent_flag = &"seventh_breath_known"

func _register_starter_quests() -> void:
	_register_starter_quests_v2()
