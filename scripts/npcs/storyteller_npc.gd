extends "res://scripts/npcs/npc.gd"
class_name StorytellerNPC

# The Storyteller. Appears at the convergence point (Ashurim) where all six
# class intro paths meet. Speaks to the player by class. Phase 2 will expand
# these into branched dialogue trees. For now: one line that makes the class
# feel seen.

const CLASS_GREETINGS := {
	&"ronin":      "You carry Kazat's iron on your breath. The sword-vow is older than this ruin — but you already know that. Ashurim remembers those who bleed for it. Sit. Drink. We have much to discuss.",
	&"berserker":  "Still breathing. Good. I've seen rage like yours end men before the enemy could. Ashurim doesn't care what fuels you — only that the fire doesn't burn the wrong things.",
	&"assassin":   "You move like you're already gone. Smart. The city has eyes everywhere — it's how it survives. I won't ask where you've been. Only where you're going.",
	&"ranger":     "You tracked Kazat's patrol routes before the fight. I'm told you did it twice. The Wastes don't give that kind of patience; you brought it. Ashurim could use more of it.",
	&"mage":       "Your weave is... unusual. Efficient. Most of the Academis boys waste half their mana on flair. You didn't. I don't know if that's discipline or something darker. Either way — welcome.",
	&"chaos_druid":"The green still clings to you. The city doesn't like what it can't name. I do. The Wound sent you here for a reason. Maybe you'll figure it out before Tiamat does.",
	&"demon":      "You found your way here without burning the gate down. Either you've got more control than I expected, or you're very lucky. In Ashurim, the difference matters a great deal.",
}

const DEFAULT_GREETING := "The city hasn't seen someone like you in a long time. That's either an omen or an opportunity. In Ashurim, it's usually both."

# Heaven-Rule walk-back: characters who have sacrificed the Demon get this
# opening from the Storyteller. Overrides the class-line.
const WALKED_BACK_GREETING := "You came back. I've seen people make a lot of choices in this hall — that one I respect more than most. The sword has decided you. It doesn't decide many."

func _ready() -> void:
	npc_id = &"storyteller"
	display_name = "The Storyteller"
	wander_radius = 0.0  # Storyteller is stationary at his post
	greeting = DEFAULT_GREETING
	# Greeting is updated once the player is known.
	# If player is already in the tree, resolve immediately.
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
	# Heaven-Rule: walk-back overrides the class-greeting permanently.
	if player.get("character_appearance") and player.character_appearance and player.character_appearance.lucifer_walked_back:
		greeting = WALKED_BACK_GREETING
		return
	var class_id: StringName = &""
	if player.get("stats") and player.stats != null and player.stats.get("class_def") and player.stats.class_def:
		class_id = player.stats.class_def.class_id
	greeting = CLASS_GREETINGS.get(class_id, DEFAULT_GREETING)
