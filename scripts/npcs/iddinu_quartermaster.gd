extends "res://scripts/npcs/npc.gd"
class_name IddinuQuartermaster

# Iddinu the Quartermaster. Stands in the Ashurim courtyard with a clipboard
# and a lit pipe. Crown's logistics arm in the city. Hands the player a
# crate-recovery quest (q_iddinu_supplies) when they're up to it.
#
# Class-aware greeting flavor — Iddinu has opinions about every class he
# fields. Same quest_log bridge pattern as the Storyteller.

const CLASS_GREETINGS := {
	&"berserker":            "Steppe-blood. Good. Bring something back broken in half. I'll write it down as 'received broken.'",
	&"assassin":             "If you have to be paid to bring me three crates, sit down. Most of your kind think the price is the work itself.",
	&"ronin":                "Sword-Vow Ruins are full of crates. Tashmu's people don't carry their own iron. Bring me back what's yours by birthright.",
	&"ranger":               "I keep a list of who can find a thing without breaking it. You're going on the list. I expect you back with three.",
	&"mage":                 "I do not pay in mana. I pay in coin. If that's a problem, the Crown has a different desk for you.",
	&"chaos_druid":          "The Wound followed you in here. Wipe your boots. Take the assignment. Go.",
	&"paladin_guardian":     "Crown's white. Good. The crates have the Crown's seal — bring them back to the Crown.",
	&"paladin_lightbringer": "Sun-blooded. The crates I want recovered have Crown stamps. The Crown stamps are stamped over older marks. Bring back both.",
	&"demon":                "I do business with whoever pays. The Crown does not. So sit down, and we'll talk about what you carry that I might want.",
}

const DEFAULT_GREETING := "Quartermaster's hut. State your business. I have ledgers."

const IDDINU_QUEST_LADDER := [
	&"q_iddinu_supplies",  # 6 Tashmu's Footmen in Sword-Vow Ruins
]

func _ready() -> void:
	npc_id = &"iddinu"
	display_name = "Iddinu the Quartermaster"
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
	var class_id: StringName = &""
	if player.get("stats") and player.stats != null and player.stats.get("class_def") and player.stats.class_def:
		class_id = player.stats.class_def.class_id
	greeting = CLASS_GREETINGS.get(class_id, DEFAULT_GREETING)

func _refresh_quest_offer() -> void:
	has_quest = false
	quest_id = &""
	var qr: Node = get_node_or_null("/root/QuestRegistry")
	if not qr:
		return
	for qid in IDDINU_QUEST_LADDER:
		if _can_offer(qr, qid):
			has_quest = true
			quest_id = qid
			return

func _can_offer(qr: Node, qid: StringName) -> bool:
	if not qr.has_method("get_quest"):
		return false
	var q = qr.get_quest(qid)
	if not q:
		return false
	if "_active" in qr and qr._active.has(qid):
		return false
	if "_completed" in qr and qr._completed.has(qid):
		return false
	var p: Node = _find_active_player()
	if p and p.get("stats") and p.stats:
		var lvl: int = int(p.stats.get("level") if p.stats.get("level") != null else 1)
		if lvl < q.min_level:
			return false
	return true

func _find_active_player() -> Node:
	for p in get_tree().get_nodes_in_group("player"):
		if is_instance_valid(p):
			return p
	return null

func _on_accept_quest(dialog_panel: Control) -> void:
	super._on_accept_quest(dialog_panel)
	var p: Node = _find_active_player()
	var qlog: Node = p.get_node_or_null("QuestLog") if p else null
	var qr: Node = get_node_or_null("/root/QuestRegistry")
	if qlog and qlog.has_method("start") and qr and qr.has_method("get_quest"):
		var q = qr.get_quest(quest_id)
		if q:
			qlog.start(q)
	_refresh_quest_offer()

func _open_dialogue() -> void:
	_refresh_quest_offer()
	super._open_dialogue()
