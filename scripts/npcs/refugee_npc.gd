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

# Night variants. Refugees are tired. At night their lines are
# quieter, more haunted, less directly explanatory. The day-line is
# what they tell strangers; the night-line is what they say to the
# fire when they think no one is listening.
const FLED_LINES_NIGHT := {
	&"druids":       "I cannot sleep. The Glen used to hum at night. The hum is gone. I keep listening for it anyway.",
	&"inquisition":  "I tell my children the smoke was a thunderstorm. They are too young for the truth. They will figure it out without me.",
	&"crown":        "Crown said the levy was temporary. The taxmen said that too, the last time. Every time. The road south is just easier than waiting.",
	&"black_sail":   "The salt is still in my hair. I taste it when I close my eyes. The captain who left us was singing. He was SINGING.",
	&"six_breaths":  "The Sixth Master is awake somewhere. He's awake right now. I can feel it. So I am too.",
}

const DEFAULT_LINE := "We had a home. We don't anymore. Ashurim takes everyone, they say. We are testing that."
const DEFAULT_LINE_NIGHT := "Sleep doesn't come. None of us sleep here. We sit. The fire watches us watching the fire."

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
	# Subscribe to WorldClock's day/night transitions so the greeting
	# updates without forcing the player to re-interact. Day and
	# night lines reveal different facets of the same loss.
	var wc: Node = get_node_or_null("/root/WorldClock")
	if wc and wc.has_signal("became_night"):
		if not wc.became_night.is_connected(_refresh_line):
			wc.became_night.connect(_refresh_line)
	if wc and wc.has_signal("became_day"):
		if not wc.became_day.is_connected(_refresh_line):
			wc.became_day.connect(_refresh_line)
	super._ready()

func _refresh_line() -> void:
	greeting = _pick_line()

func _pick_line() -> String:
	var night: bool = _is_night()
	if fled_from == &"":
		return DEFAULT_LINE_NIGHT if night else DEFAULT_LINE
	var table: Dictionary = FLED_LINES_NIGHT if night else FLED_LINES
	var fallback: String = DEFAULT_LINE_NIGHT if night else DEFAULT_LINE
	return String(table.get(fled_from, fallback))

func _is_night() -> bool:
	var wc: Node = get_node_or_null("/root/WorldClock")
	if wc and wc.has_method("is_night"):
		return bool(wc.is_night())
	return false
