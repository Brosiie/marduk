extends "res://scripts/npcs/npc.gd"
class_name BelituMarketGirl

# Belitu the Market Girl. Sells dried fish, runs the Singing Goat inn at
# night when her mother sleeps, and asks every passing fighter the same
# question: have you seen a twelve-year-old boy with my eyes? She gives
# q_belitu_brother to anyone willing to look.
#
# She's not stoic about it. The dialog reflects that.

const CLASS_GREETINGS := {
	&"berserker":            "You look like you've cracked skulls. My brother's twelve. He went into the Cradle two days ago. Could you look?",
	&"assassin":             "You move quiet. You'd find him faster than the patrols. They're not really looking, they say it's not safe, but I think they mean for them.",
	&"ronin":                "Sword-bearer. The Cradle's full of bandits. I think one of them took my brother. He's twelve. His name's Iddi.",
	&"ranger":               "You track. Could you track a child? He's twelve. Reddish hair. He'd have walked toward the river, he likes the river.",
	&"mage":                 "You can find things by spell, can't you? My brother walked into the Cradle. He's still alive, I'd know if he wasn't. I'd KNOW.",
	&"chaos_druid":          "You're Wound-Marked. People don't like you. I like you. My brother's been gone two days. The Cradle ate him. Bring him back.",
	&"paladin_guardian":     "Crown's white. You'd be expected to. My brother's twelve. The Cradle. Two days. Please.",
	&"paladin_lightbringer": "Sun-blessed. You hear it on people's voices when they pray. My brother prayed every night before bed. He's been gone two days. Find him for me.",
	&"demon":                "I know what you are. I know I shouldn't. My brother's been gone two days and you're the first person who looked at me like a person, so. Please.",
}

const DEFAULT_GREETING := "Excuse me, I sell fish, and I have a question. My brother. Have you seen him?"

# Tiamat awareness dread: Belitu doesn't know what's stirring. She just
# knows the kettle won't boil right anymore, and the river ran sour
# yesterday. Class-blind because dread is bigger than class flavor.
const DREAD_GREETINGS := {
	"WAKING":   "The fish don't bite right anymore. The water tastes wrong. Something's coming. My brother is still gone. Both things keep me up.",
	"WAKING_2": "There were rats in the storehouse last night that didn't look right. Three legs each, and they were singing. I don't know who to tell. You look like someone who'd believe me.",
	"AWAKE":    "I haven't slept since the moon turned purple. None of us have. The inn is empty. Find my brother before whatever is coming gets here. Please.",
}

# Glyph-aware: Belitu reads marks in a folk way. The Wound mark she
# distrusts (most market folk do); the Crown mark she defers to but
# also resents.
const GLYPH_GREETINGS := {
	"wound":      "Your skin's marked with the Wound. Mama says people like you bring trouble. I'm too tired for trouble. Please don't bring more.",
	"inquisition":"Burner mark. The last one of you took my uncle. I'll still ask if you've seen my brother. I have to. But I'm not glad you're here.",
}

# Faction-conflict observations from street level. Belitu sees what
# passes the market: the wounded, the corpses, the carts that don't
# come back. She doesn't speculate. She just tells you what she
# watched from her stall.
const CONFLICT_GREETINGS := {
	"druid_vs_inquisition:SKIRMISH": "Two carts of wounded came through this morning. Druid green on the canvas, Inquisition white on the bodies. Or the other way, I can't tell anymore. Have you seen my brother? Please.",
	"druid_vs_inquisition:OPEN_WAR": "The market's closing early. Mama won't say why. I will: there was a body in the well this morning. A burner. The well was the Sanctum's. Have you seen my brother. Please. Please.",
	"crown_vs_black_sail:SKIRMISH":  "The fish boats aren't coming in. Black Sail's blockading. The Crown won't say so but I know what an empty dock looks like. Have you seen my brother?",
}

const BELITU_QUEST_LADDER := [
	&"q_belitu_brother",       # lvl 1, find her missing brother
	&"q_belitu_druid_friend",  # lvl 3, slay Inquisition Burners, +Druids / -Inquisition
]

func _ready() -> void:
	npc_id = &"belitu"
	display_name = "Belitu the Market Girl"
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
		GLYPH_GREETINGS,
		"",  # no walked-back
		{},  # no wound dread
		CONFLICT_GREETINGS
	)

func _refresh_quest_offer() -> void:
	has_quest = false
	quest_id = &""
	var qr: Node = get_node_or_null("/root/QuestRegistry")
	if not qr:
		return
	for qid in BELITU_QUEST_LADDER:
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
	# Belitu runs the Singing Goat, opens the inn vendor (potions + drinks)
	# rather than the quest dialog. Her quest offer toasts when active so
	# players know to look for it.
	_refresh_quest_offer()
	if has_quest:
		_toast("Belitu has a quest. Open the J panel after to take it.")
	var sk: Node = get_node_or_null("/root/ShopkeeperRegistry")
	if sk and sk.has_method("get_vendor"):
		var vendor = sk.get_vendor(&"ashurim_innkeep")
		if vendor:
			var packed: PackedScene = load("res://scenes/ui/panels/vendor_panel.tscn")
			if packed:
				var p_panel = packed.instantiate()
				get_tree().current_scene.add_child(p_panel)
				p_panel.open(vendor, _find_active_player(), self)
				return
	super._open_dialogue()

func _toast(msg: String) -> void:
	var juice: Node = get_node_or_null("/root/Juice")
	if juice and juice.has_method("toast"):
		juice.toast(msg, Color(0.85, 0.78, 0.55), 2.5)
