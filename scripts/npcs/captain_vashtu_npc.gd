extends "res://scripts/npcs/npc.gd"
class_name CaptainVashtuNPC

# Captain Vashtu the Censor. Inquisition NPC at the Wound boundary. Her
# voice is the deliberate counterweight to the Sanctum-Mother's: same
# cosmic threats, same observations, but read through the Inquisition's
# certainty. Where the Druid sees the Wound as something to tend,
# Vashtu sees it as something to burn back harder.
#
# The writing brief is that Vashtu is EARNEST and SYMPATHETIC, not
# cackling. She believes her order's doctrine. The player's tragedy
# (and the Inquisition's) is that the WoundRegistry numbers prove she's
# wrong. Every burn pushes both Tiamat awareness AND Wound creep UP.
# The player can SEE this. Vashtu cannot. That's the design payoff.
#
# Hooked into the same NPCLines.pick_contextual_greeting chain as the
# Sanctum-Mother but with INVERTED dread reactions:
#   Druid: dread escalates toward grief
#   Inquisition: dread escalates toward vindication + redoubled fire

const CLASS_GREETINGS := {
	&"berserker":             "Steppes-blood. Useful. The corruption answers to violence. Walk with me.",
	&"assassin":              "You move quiet. Good. The Burners need eyes that don't announce themselves. The Sanctum's spies have ours.",
	&"ronin":                 "Sword-bearer. The Crown's stamp on your iron, yes? Then we are colleagues, by Crown's measure. Walk with me.",
	&"ranger":                "Tracker. The corrupted leave trails our novices cannot read. You can. Welcome to the Censor's company.",
	&"mage":                  "Academis-trained. Our doctrine and yours are not enemies, despite what the temple says. Sit. Tea?",
	&"chaos_druid":           "I will be plain: I should refuse you the well. The Sanctum-Mother has been kind to your kind for too long. But the Crown has business here. Speak.",
	&"paladin_guardian":      "Crown's white at the edge of the dark. You belong here. The Inquisition is the Crown's hand at the frontier; we work the same vow.",
	&"paladin_lightbringer":  "Dawn-blessed. Welcome. The sun and the fire are the same instrument by different names. Sit by ours.",
	&"demon":                 "You are not what I would have invited. But you are what walked in. The Inquisition does not waste edged tools. Speak. Briefly.",
}

const DEFAULT_GREETING := "Captain Vashtu of the Censor's Company. State your business. I have a fire to tend."

# Tiamat dread INVERSION: where the Sanctum-Mother feels Tiamat stirring
# and softens, Vashtu HARDENS. The same observation, the opposite
# conclusion. Doubling down is the Inquisition's whole doctrine.
const DREAD_GREETINGS := {
	"WAKING":   "The deep is restless because the Sanctum's coddling has fed it for sixty years. We will fix this. Not gently. Sit.",
	"WAKING_2": "The temple says we made it worse. The temple has not killed a Tiamat-spawn in three generations; we have. Statistics speak louder than scripture. Walk with me.",
	"AWAKE":    "She rises. Of course she rises, the rot was never burned out. The Sanctum will weep about this. We will arm. Tell me your blade is ours.",
}

# Wound dread INVERSION: where the Sanctum-Mother grieves the Wound
# spreading, Vashtu reads it as VINDICATION. Each escalation is, to her
# mind, proof that they should have burned harder sooner. This is the
# tragic-certainty writing: she's wrong, but the dialog never says so.
# The numbers say it for her.
const WOUND_DREAD_GREETINGS := {
	"SEEPING":     "You see it? The boundary is moving the wrong way. The Sanctum-Mother says contain. I say burn. Which one of us has the records?",
	"BLEEDING":    "Three Burners lost this month, the green ate them. The temple suggests we 'tend' the corruption. I have buried colleagues. Tending is what got them buried.",
	"UNCONTAINED":"It is uncontained because we were too cautious. Listen to me. I want more fire. I want it now. If the Crown will not authorize it, I will sign the orders myself.",
	"CONSUMING":   "The Sanctum has lost the Glen. We knew this would happen. We told them. Now the Crown will let us do what we should have done at the start, if there is anyone left to give the order.",
}

# Glyph awareness. Crown / Inquisition marks she welcomes; Wound / Druid
# she will speak with anyway (Censor doctrine is to convert, not banish),
# but the conversation has friction. Demon mark gets a CAREFUL welcome
# because she understands what a tool the player is.
const GLYPH_GREETINGS := {
	"inquisition":"You wear our mark. Welcome home. The fire is yours; the work, too. Sit.",
	"crown":      "Crown's seal. The Inquisition serves the Crown. By extension, you serve me. Welcome.",
	"wound":      "Wound mark on you. I do not refuse you the well. But I will be watching. The corruption rewards trust the way fire rewards dry tinder.",
	"druid":      "Druid mark. We have business with your Mother and you have business with us. Walk the careful path, Druid. I will too.",
}

# Quest ladder: 2 Inquisition burning quests. Gated by player level so
# they appear after the player has met the Sanctum-Mother's offer.
# These are the COUNTERWEIGHT lever: completing them pushes Wound creep
# UP and Tiamat awareness UP (the lore claim Druids are right). The
# player who values the Inquisition's doctrine can choose them anyway
# for the rep, the gold, and the simpler kill-list objectives.
const VASHTU_QUEST_LADDER := [
	&"q_vashtu_purify_grove",     # lvl 6, burn Wound-spawn near the boundary
	&"q_vashtu_silence_sanctum",  # lvl 12, gate at Friendly Inquisition, harder
]

func _ready() -> void:
	npc_id = &"captain_vashtu"
	display_name = "Captain Vashtu the Censor"
	wander_radius = 0.0
	greeting = DEFAULT_GREETING
	_refresh_quest_offer()
	var players := get_tree().get_nodes_in_group("player")
	if players.size() > 0:
		_set_greeting_for(players[0])
	else:
		get_tree().node_added.connect(_on_node_added)
	super._ready()

func _on_node_added(node: Node) -> void:
	if node.is_in_group("player"):
		_set_greeting_for(node)
		get_tree().node_added.disconnect(_on_node_added)

func _set_greeting_for(player: Node) -> void:
	if player == null:
		return
	# Layered selection. Same priority chain as the Sanctum-Mother but
	# every layer's voice INVERTS: vindication where she grieves,
	# doubling-down where she softens. The arithmetic of the priority
	# chain doesn't care about politics; it just picks the most-specific
	# layer the author wrote.
	greeting = NPCLines.pick_contextual_greeting(
		player,
		CLASS_GREETINGS,
		DEFAULT_GREETING,
		DREAD_GREETINGS,
		GLYPH_GREETINGS,
		"",  # no walked-back override
		WOUND_DREAD_GREETINGS
	)

func _refresh_quest_offer() -> void:
	has_quest = false
	quest_id = &""
	var qr: Node = get_node_or_null("/root/QuestRegistry")
	if not qr:
		return
	for qid in VASHTU_QUEST_LADDER:
		if qr.has_method("is_active") and qr.is_active(qid):
			continue
		if qr.has_method("is_completed") and qr.is_completed(qid):
			continue
		var q = qr.get_quest(qid) if qr.has_method("get_quest") else null
		if q == null:
			continue
		var player: Node = get_tree().get_first_node_in_group("player") if get_tree() else null
		var player_level: int = int(player.stats.level) if player and player.get("stats") and player.stats else 1
		if int(q.min_level) > player_level:
			continue
		has_quest = true
		quest_id = qid
		return
