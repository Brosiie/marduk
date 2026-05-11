extends "res://scripts/npcs/npc.gd"
class_name RefugeeNPC

# A refugee fleeing a faction conflict. Wanders idle near their spawn
# marker, speaks one line on interact based on which side they fled.
# Carries no quest. Their presence in a city is the consequence of
# war reaching the borders, the player sees them and knows the
# conflict state at a glance.
#
# Spawned + despawned by RefugeeSpawner reacting to
# FactionConflictRegistry.pair_state_changed.

# Which faction the refugee fled FROM. The greeting line references
# the opposite faction (the one that drove them out). Set externally
# by the spawner before _ready.
@export var fled_from: StringName = &""  # eg &"druids" -> fled from Druid territory

# Per-faction lines. Each is a short one-line cry from someone who
# has lost their home. No quest hook; this is pure flavor + presence.
const FLED_LINES := {
	&"druids":       "The Druids closed the Glen behind us. My mother is still in there. Please, traveler. Someone has to go in.",
	&"inquisition":  "The Inquisition burned our wells. They said the water was 'unclean.' My children are thirsty. I have nothing to trade.",
	&"crown":        "Crown taxmen took our last cart. They said it was a 'wartime levy.' We walked here. The road is full of others walking too.",
	&"black_sail":   "Black Sail boarded our boat. They left us alive on the salt flats with no water. That was four days ago. Some of us made it. Most of us didn't.",
	&"six_breaths":  "We came from the temple. The Sixth Master told us to leave before whatever is coming arrives. He did not say what was coming. He told us to leave.",
}

const DEFAULT_LINE := "We had a home. We don't anymore. Ashurim takes everyone, they say. We are testing that."

func _ready() -> void:
	npc_id = &"refugee"
	display_name = "Refugee"
	# Refugees wander slightly to look alive but stay near their
	# spawn marker so they don't drift across the city.
	wander_radius = 2.0
	wander_speed = 0.6
	wander_pause_min = 4.0
	wander_pause_max = 8.0
	greeting = _pick_line()
	has_quest = false
	quest_id = &""
	super._ready()

func _pick_line() -> String:
	if fled_from == &"":
		return DEFAULT_LINE
	return String(FLED_LINES.get(fled_from, DEFAULT_LINE))
