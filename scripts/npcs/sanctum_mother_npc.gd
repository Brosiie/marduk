extends "res://scripts/npcs/npc.gd"
class_name SanctumMotherNPC

# The Sanctum-Mother. Druids of the Wound's elder. Lives at the Coven
# Glen entry into the Verdant Wound. Her voice is the only one in the
# game that reads BOTH cosmic threats directly:
#   - Tiamat awareness: she's a druid, so she feels the deep stirring
#   - Wound creep: she literally tends the corruption, so she reads
#     it before anyone else
#
# Quest giver for druid stabilization line. Two quests authored in
# QuestRegistry give the player a real lever to reduce Wound creep.

const CLASS_GREETINGS := {
	&"chaos_druid":          "You wear the Wound's mark already. Sit beside the fire. The vines remember your name.",
	&"berserker":             "Steppes-blood. Good. The Wound likes anger more than mercy, you'll do well at the boundary.",
	&"assassin":              "You move like water. The Wound takes water and gives it back darker. Bring me what I ask for. Do not linger.",
	&"ronin":                 "Sword-bearer from the south. We have something the Crown does not understand. Sit. I'll explain.",
	&"ranger":                "Tracker. The corruption leaves trails most cannot read. You can. The Sanctum needs you.",
	&"mage":                  "Academis-trained. The Wound will hum to you. Don't answer. Just listen, then come back to me.",
	&"paladin_guardian":      "Crown's white in the Wound. Brave. Foolish. We'll see which. There is work here for someone who isn't afraid of the dark.",
	&"paladin_lightbringer":  "Sun-blessed at the edge of the dark. Some would call that a sign. I call it a tool. Sit.",
	&"demon":                 "Welcome. Your kind and ours have an older friendship than the temples remember. The Wound is patient with you. So am I.",
}

const DEFAULT_GREETING := "I am the Sanctum-Mother. The Wound is in my hands. Sit, and tell me why you've come."

# Tiamat awareness: the Sanctum-Mother is one of the few who
# understands what's actually below. The Druids' oldest texts name her.
# Awareness dread overrides class flavor because at WAKING+ this is
# what she NEEDS to say.
const DREAD_GREETINGS := {
	"WAKING":   "You feel her too, don't you. We have been preparing for this since before the Crown was crowned. Sit.",
	"WAKING_2": "She has the city's name in her mouth. The Crown does not know yet. The Inquisition will not believe me. You believe me. Sit, sit, sit.",
	"AWAKE":    "Marduk's heir, before the world ends, listen: she is not the enemy we tell stories about. She is older. We did not seal her. We were her gardeners. Now sit.",
}

# Wound dread: the Sanctum-Mother literally sees the Wound spread. Her
# Wound-tier lines escalate from concerned (SEEPING) through grief
# (CONSUMING). These OVERRIDE Tiamat dread because the Wound is in her
# hands first; she can talk about Tiamat later.
const WOUND_DREAD_GREETINGS := {
	"SEEPING":     "The vines are restless this week. We're behind. Whatever you can bring me, bring it quickly.",
	"BLEEDING":    "Three of my novices went into the green and did not come back themselves. The Wound is teaching the wrong lesson now. Sit. I have work.",
	"UNCONTAINED":"I cannot hold it. None of us can. The Inquisition's fires only fed it, the fools, the FOOLS. Tell me you have come to help. Tell me that.",
	"CONSUMING":   "The Glen is no longer mine. The vines speak in a voice I have not taught them. We have hours, maybe a day. If you have any strength left in you, spend it now.",
}

# Glyph awareness. Sanctum-Mother sees marks plainly. Wound-aligned
# glyphs make her warm; Crown / Inquisition glyphs make her careful
# but not hostile (her order survives by speaking to all comers).
const GLYPH_GREETINGS := {
	"wound":      "The Wound's mark on your skin. Good. The vines know you. The Glen is yours as much as mine.",
	"druid":      "A druid mark. Welcome. You don't need my permission for the Glen, but I'll give you tea anyway.",
	"crown":      "Crown's seal at your throat. We've had Crown visitors before. We bury what they leave behind, but we welcome them while they're here. Sit.",
	"inquisition":"Inquisition mark on you. Most of my order would refuse you the well. I am older than most of my order. Sit. Speak. We have a problem that may be larger than your order, and mine.",
}

# Quest ladder: druid stabilization, low to mid level. Each completion
# fires the +druids / -inquisition rep delta that WoundRegistry and
# TiamatRegistry both subscribe to. The player gains a real lever.
const SANCTUM_QUEST_LADDER := [
	&"q_sanctum_tending_glen",       # lvl 5, light Wound creep reduction
	&"q_sanctum_burner_at_the_edge", # lvl 10, harder, larger creep reduction
]

func _ready() -> void:
	npc_id = &"sanctum_mother"
	display_name = "The Sanctum-Mother"
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
	# Layered selection: walked-back > glyph > Wound dread > Tiamat
	# dread > class > default. Wound dread comes BEFORE Tiamat because
	# the Wound is what she tends with her own hands; Tiamat is the
	# bigger but more distant horror.
	greeting = NPCLines.pick_contextual_greeting(
		player,
		CLASS_GREETINGS,
		DEFAULT_GREETING,
		DREAD_GREETINGS,
		GLYPH_GREETINGS,
		"",  # no walked-back override; her welcome is for everyone
		WOUND_DREAD_GREETINGS
	)

func _refresh_quest_offer() -> void:
	has_quest = false
	quest_id = &""
	var qr: Node = get_node_or_null("/root/QuestRegistry")
	if not qr:
		return
	# Offer the first ladder quest that's available and not already
	# accepted or completed. Same pattern as Storyteller / Iddinu.
	for qid in SANCTUM_QUEST_LADDER:
		if qr.has_method("is_active") and qr.is_active(qid):
			continue
		if qr.has_method("is_completed") and qr.is_completed(qid):
			continue
		var q = qr.get_quest(qid) if qr.has_method("get_quest") else null
		if q == null:
			continue
		# Min-level gate: don't offer a quest the player can't accept
		var player: Node = get_tree().get_first_node_in_group("player") if get_tree() else null
		var player_level: int = int(player.stats.level) if player and player.get("stats") and player.stats else 1
		if int(q.min_level) > player_level:
			continue
		has_quest = true
		quest_id = qid
		return
