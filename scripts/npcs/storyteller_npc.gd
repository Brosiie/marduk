extends "res://scripts/npcs/npc.gd"
class_name StorytellerNPC

# The Storyteller. Appears at the convergence point (Ashurim) where all six
# class intro paths meet. Speaks to the player by class. Phase 2 will expand
# these into branched dialogue trees. For now: one line that makes the class
# feel seen.

const CLASS_GREETINGS := {
	&"ronin":      "You carry Kazat's iron on your breath. The sword-vow is older than this ruin, but you already know that. Ashurim remembers those who bleed for it. Sit. Drink. We have much to discuss.",
	&"berserker":  "Still breathing. Good. I've seen rage like yours end men before the enemy could. Ashurim doesn't care what fuels you, only that the fire doesn't burn the wrong things.",
	&"assassin":   "You move like you're already gone. Smart. The city has eyes everywhere, it's how it survives. I won't ask where you've been. Only where you're going.",
	&"ranger":     "You tracked Kazat's patrol routes before the fight. I'm told you did it twice. The Wastes don't give that kind of patience; you brought it. Ashurim could use more of it.",
	&"mage":       "Your weave is... unusual. Efficient. Most of the Academis boys waste half their mana on flair. You didn't. I don't know if that's discipline or something darker. Either way, welcome.",
	&"chaos_druid":"The green still clings to you. The city doesn't like what it can't name. I do. The Wound sent you here for a reason. Maybe you'll figure it out before Tiamat does.",
	&"demon":      "You found your way here without burning the gate down. Either you've got more control than I expected, or you're very lucky. In Ashurim, the difference matters a great deal.",
}

const DEFAULT_GREETING := "The city hasn't seen someone like you in a long time. That's either an omen or an opportunity. In Ashurim, it's usually both."

# Heaven-Rule walk-back: characters who have sacrificed the Demon get this
# opening from the Storyteller. Overrides the class-line.
const WALKED_BACK_GREETING := "You came back. I've seen people make a lot of choices in this hall, that one I respect more than most. The sword has decided you. It doesn't decide many."

# Tiamat awareness dread: as her dream stirs, the Storyteller notices.
# He's older than this city; he remembers what came before, and he can
# feel her rising the same way he felt her last time. WAKING+ pulls
# focus from class flavor toward warning.
const DREAD_GREETINGS := {
	"WAKING":   "You've been busy. The deep below the Bay is restless tonight. I can feel it in the floor when I sit too long. Whatever you're doing, you're doing it loud.",
	"WAKING_2": "The kettle hums when no one is touching it. The lodestones are warm. Tell me you understand what you're waking. Tell me you have a plan.",
	"AWAKE":    "She is awake. The city knows. The walls know. You did this, and I will not pretend otherwise. Sit anyway. The kettle is on. We talk while we still can.",
}

# Glyph-aware override: NPCs who recognize specific marks. The
# Storyteller has seen every glyph in his time; the Wound mark in
# particular makes him careful with his words.
const GLYPH_GREETINGS := {
	"wound":      "I see the Wound's mark on you. The Sanctum-Mother chose well, or you chose her, hard to say which way that arrow flies. Either way, sit. Drink.",
	"crown":      "Crown's seal at your throat. That's a heavy thing to wear into MY hall. We'll talk anyway, but understand: in Ashurim, the Crown speaks last and quietest.",
	"inquisition":"Inquisition mark. Let me be plain: I've watched what your order does to the bodies it leaves behind. We'll talk if you can hear me through that. Not before.",
}

func _ready() -> void:
	npc_id = &"storyteller"
	display_name = "The Storyteller"
	wander_radius = 0.0  # Storyteller is stationary at his post
	greeting = DEFAULT_GREETING
	# Storyteller is the giver for to_babilim (the main-story bridge from
	# Ashurim out into the world). Wired so the NPC base class adds an
	# Accept Quest button to the dialog when the player is eligible.
	# Re-checked each interact via _refresh_quest_offer so accepting the
	# quest hides the button until the next eligible quest opens up.
	_refresh_quest_offer()
	# Greeting is updated once the player is known.
	# If player is already in the tree, resolve immediately.
	var players := get_tree().get_nodes_in_group("player")
	if players.size() > 0:
		_set_greeting_for(players[0])
	else:
		get_tree().node_added.connect(_on_node_added)
	super._ready()

# The Storyteller can carry one of N quests at a time. Order: prologue
# (auto-completed at intro mini-boss kill) -> to_babilim -> ... For now
# the only one wired is to_babilim, gated on player level + not-already-
# accepted/completed. Easy to extend.
const STORYTELLER_QUEST_LADDER := [
	&"q_storyteller_intro",              # lvl 1, discover 3 lodestones
	&"q_storyteller_six_breaths",        # lvl 4, release bound spirits, +SixBreaths
	&"q_storyteller_inquisition_choice", # lvl 4, hunt Tiamat-spawn, +Inquisition / -Druids
	&"to_babilim",                       # lvl 5, main-story bridge
	&"to_tiamat",                        # lvl 30, Black Citadel access
	&"the_fire_stair",                   # lvl 50+, Lucifer secret
]

func _refresh_quest_offer() -> void:
	has_quest = false
	quest_id = &""
	var qr: Node = get_node_or_null("/root/QuestRegistry")
	if not qr:
		return
	for qid in STORYTELLER_QUEST_LADDER:
		if _can_offer(qr, qid):
			has_quest = true
			quest_id = qid
			return  # offer the first eligible

func _can_offer(qr: Node, qid: StringName) -> bool:
	if not qr.has_method("get_quest"):
		return false
	var q = qr.get_quest(qid)
	if not q:
		return false
	# Already accepted (active) or already turned in?
	if "_active" in qr and qr._active.has(qid):
		return false
	if "_completed" in qr and qr._completed.has(qid):
		return false
	# Player level prereq
	var p: Node = _find_active_player()
	if p and p.get("stats") and p.stats:
		var lvl: int = int(p.stats.get("level") if p.stats.get("level") != null else 1)
		if lvl < q.min_level:
			return false
	# Run-flag prereq
	if q.prerequisite_run_flag != &"" and SaveFlags and not SaveFlags.has_run(q.prerequisite_run_flag):
		return false
	return true

func _find_active_player() -> Node:
	for p in get_tree().get_nodes_in_group("player"):
		if is_instance_valid(p):
			return p
	return null

# Override the base NPC accept-quest behavior to also start the quest in the
# per-player QuestLog node (so the J panel sees it). The base NPC only calls
# QuestRegistry.accept_quest; we need both layers for the UI to reflect state.
func _on_accept_quest(dialog_panel: Control) -> void:
	super._on_accept_quest(dialog_panel)
	var p: Node = _find_active_player()
	var qlog: Node = p.get_node_or_null("QuestLog") if p else null
	var qr: Node = get_node_or_null("/root/QuestRegistry")
	if qlog and qlog.has_method("start") and qr and qr.has_method("get_quest"):
		var q = qr.get_quest(quest_id)
		if q:
			qlog.start(q)
	# Re-evaluate which quest to offer next interaction
	_refresh_quest_offer()

# Re-check available quests every time the player walks up. Player may have
# leveled / completed prereqs since the last interaction.
func _open_dialogue() -> void:
	_refresh_quest_offer()
	super._open_dialogue()

func _on_node_added(node: Node) -> void:
	if node.is_in_group("player"):
		_set_greeting_for(node)
		get_tree().node_added.disconnect(_on_node_added)

func _set_greeting_for(player: Node) -> void:
	if player == null:
		return
	# Layered selection via shared helper: walk-back -> glyph -> dread
	# tier -> class -> default. Storyteller authors lines for every
	# layer; the helper picks the most-specific match.
	greeting = NPCLines.pick_contextual_greeting(
		player,
		CLASS_GREETINGS,
		DEFAULT_GREETING,
		DREAD_GREETINGS,
		GLYPH_GREETINGS,
		WALKED_BACK_GREETING
	)
