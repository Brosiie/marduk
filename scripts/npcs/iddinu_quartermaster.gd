extends "res://scripts/npcs/npc.gd"
class_name IddinuQuartermaster

# Iddinu the Quartermaster. Stands in the Ashurim courtyard with a clipboard
# and a lit pipe. Crown's logistics arm in the city. Hands the player a
# crate-recovery quest (q_iddinu_supplies) when they're up to it.
#
# Class-aware greeting flavor, Iddinu has opinions about every class he
# fields. Same quest_log bridge pattern as the Storyteller.

const CLASS_GREETINGS := {
	&"berserker":            "Steppe-blood. Good. Bring something back broken in half. I'll write it down as 'received broken.'",
	&"assassin":             "If you have to be paid to bring me three crates, sit down. Most of your kind think the price is the work itself.",
	&"ronin":                "Sword-Vow Ruins are full of crates. Tashmu's people don't carry their own iron. Bring me back what's yours by birthright.",
	&"ranger":               "I keep a list of who can find a thing without breaking it. You're going on the list. I expect you back with three.",
	&"mage":                 "I do not pay in mana. I pay in coin. If that's a problem, the Crown has a different desk for you.",
	&"chaos_druid":          "The Wound followed you in here. Wipe your boots. Take the assignment. Go.",
	&"paladin_guardian":     "Crown's white. Good. The crates have the Crown's seal, bring them back to the Crown.",
	&"paladin_lightbringer": "Sun-blooded. The crates I want recovered have Crown stamps. The Crown stamps are stamped over older marks. Bring back both.",
	&"demon":                "I do business with whoever pays. The Crown does not. So sit down, and we'll talk about what you carry that I might want.",
}

const DEFAULT_GREETING := "Quartermaster's hut. State your business. I have ledgers."

# Tiamat awareness dread: Iddinu is Crown logistics. He notices the
# system breaking before he notices the cause. Receipts come back
# wrong. Caravans miss waypoints. He's the kind of man who treats
# cosmic horror as a paperwork problem until he can't.
const DREAD_GREETINGS := {
	"WAKING":   "Two of last night's caravans are missing receipts. Three of yesterday's. The handwriting on the recovered ones is not the handwriting that left here. Sit. We're behind.",
	"WAKING_2": "I have a ledger entry for a delivery I did not make. The ink is wet. The clerk who would have written it has been dead nine years. State your business quickly. I have a fire to start.",
	"AWAKE":    "The Crown won't pay. The seals are dissolving on the page when the candle gets too close. Whatever you came here for, take it. The Quartermaster's office is closing. I am closing it.",
}

# Glyph-aware. Iddinu reads Crown marks favorably (same team), Black
# Sail with sour pragmatism (does business anyway), Wound with active
# distrust (Wound-Marked are Druid territory and he resents them).
const GLYPH_GREETINGS := {
	"crown":      "Crown seal at your collar. Welcome. The ledger is open. Your business gets prioritized over whatever the front of the line is here for.",
	"black_sail": "I see the captain's mark. I sell to anyone with coin. I file the paperwork as 'unspecified buyer' so my superiors don't ask. Sit down. Make it quick.",
	"wound":      "Wound mark. Wipe your boots BEFORE you cross the threshold. I will not have green on my floor. State your business in three sentences or fewer.",
}

const IDDINU_QUEST_LADDER := [
	&"q_iddinu_supplies",          # lvl 1, kill 6 Tashmu's Footmen, +Crown
	&"q_iddinu_crown_loyalty",     # lvl 3, Caravan Toll, big +Crown
	&"q_iddinu_blacksail_sidegig", # lvl 4, side-gig, +BlackSail / -Crown
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
	greeting = NPCLines.pick_contextual_greeting(
		player,
		CLASS_GREETINGS,
		DEFAULT_GREETING,
		DREAD_GREETINGS,
		GLYPH_GREETINGS
	)

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
	# Dual-purpose NPC: opens the VendorPanel directly because Iddinu's a
	# quartermaster (selling > talking). Quest offer comes through the
	# vendor panel header line; players can decline and walk back for the
	# old NPC dialog flow if needed.
	_refresh_quest_offer()
	var sk: Node = get_node_or_null("/root/ShopkeeperRegistry")
	if sk and sk.has_method("get_vendor"):
		# Iddinu's vendor in Babilim was named babilim_market_general; in
		# Ashurim he runs the quartermaster station, wire through ashurim_general
		# as a fallback so Belitu/Iddinu both have a stocked shop.
		var vendor = sk.get_vendor(&"ashurim_general")
		if vendor:
			var packed: PackedScene = load("res://scenes/ui/panels/vendor_panel.tscn")
			if packed:
				var p_panel = packed.instantiate()
				get_tree().current_scene.add_child(p_panel)
				p_panel.open(vendor, _find_active_player(), self)
				return
	# Fallback to standard NPC quest dialog
	super._open_dialogue()
