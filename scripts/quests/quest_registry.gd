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
	# re-fire on top of restored state — that's fine because
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
	# Active quests: list of ids only — re-resolved from `quests` dict
	# at load time so we don't snapshot the (potentially huge) Quest
	# resource into the save file.
	var active_ids: Array = []
	for id in _active.keys():
		active_ids.append(String(id))
	sf.set_run(_SAVEFLAG_ACTIVE, active_ids)
	# Completed quests: same pattern — ids only.
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
	var active_ids: Array = sf.get_run(_SAVEFLAG_ACTIVE)
	if active_ids == null:
		return  # nothing to restore — fresh save
	var completed_ids: Array = sf.get_run(_SAVEFLAG_COMPLETED)
	var progress_payload: Dictionary = sf.get_run(_SAVEFLAG_PROGRESS)
	if completed_ids == null:
		completed_ids = []
	if progress_payload == null:
		progress_payload = {}
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
	_active[id] = q
	# Initialize progress counters at zero for each objective.
	var counters: Array[int] = []
	for _i in range(q.objectives_data.size()):
		counters.append(0)
	_progress[id] = counters
	quest_accepted.emit(q)
	_save_to_save_flags()
	# Event-driven autosave so a freshly-accepted quest survives an
	# alt-F4 / crash / power loss between the 60s autosave timer.
	_request_autosave()
	# Toast banner so accepting a quest feels like a moment
	var juice = get_node_or_null("/root/Juice")
	if juice:
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
	# Achievement: first quest completion
	var ar = get_node_or_null("/root/AchievementRegistry")
	if ar and ar.has_method("unlock"):
		ar.unlock(&"a_first_quest")
	quest_completed.emit(q)
	_save_to_save_flags()
	# Event-driven autosave so completion progress isn't lost on
	# crash. Quest completions are MAJOR moments — the player is
	# expecting their reward to be permanent.
	_request_autosave()
	# Toast for completion + brief slowmo to mark the moment
	var juice = get_node_or_null("/root/Juice")
	if juice:
		juice.toast("✓  Quest Complete: %s" % q.display_name, Color(0.45, 0.95, 0.55), 3.5)
		juice.flash(Color(0.45, 0.95, 0.55), 0.20, 0.4)
	return true

# Fire-and-forget autosave to slot 0 (the autosave slot). Skips
# silently if SaveSystem or Player isn't available — not every
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
# STARTER QUESTS (Ashurim NPCs) — bind directly to the 3 plaza NPCs
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

func _register_starter_quests() -> void:
	_register_starter_quests_v2()
