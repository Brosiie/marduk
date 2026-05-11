extends "res://scripts/npcs/npc.gd"
class_name SeventhMasterNPC

# The Seventh Master, at the Sun Gate. The Sixth says: "you will not
# find a master there. You will find a brother."
#
# Wordless meeting. The encounter has no class-aware dialog tree because
# the lore brief is that there is no instruction here, only the transfer
# of breath. The player walks up, the Seventh stands, one line is said,
# and the third Seventh Breath quest stage completes. The audio sting
# carries the weight that words would have to fake.
#
# Visibility:
#   - Hidden if seventh_breath_pilgrimage_done flag is unset (player
#     hasn't earned the meeting yet)
#   - Hidden if seventh_breath_known flag is already set (already met
#     him, the moment is one-time; the place stays in memory)
#   - Otherwise visible at the Sun Gate
#
# Hooked to QuestRegistry.progress directly on interact rather than
# relying on the reach_zone objective to fire from the player crossing
# a trigger volume. The interaction IS the completion; the player has
# to look at him.

const ONE_LINE := "Welcome, brother. The kettle is on. You will not need it."

# Alternative line if the player walked back (Heaven-Rule). The Seventh
# knows. He knew before the player did.
const WALKED_BACK_LINE := "Welcome back. I have been holding your seat warm. Sit."

func _ready() -> void:
	npc_id = &"seventh_master"
	display_name = "The Seventh"
	wander_radius = 0.0
	greeting = ONE_LINE
	has_quest = false
	quest_id = &""
	# Visibility gate via SaveFlags. Reads the pilgrimage flag from
	# stage 2 + the known flag from stage 3 to decide whether this NPC
	# is visible at all. Hidden = invisible + non-interactable; the
	# Area3D trigger only registers presence when visible.
	_apply_visibility_gate()
	super._ready()

func _apply_visibility_gate() -> void:
	var sf: Node = get_node_or_null("/root/SaveFlags")
	if sf == null:
		# Without SaveFlags we can't read the gate; hide to be safe.
		# The Seventh shouldn't appear before the player has earned him.
		visible = false
		set_process(false)
		set_physics_process(false)
		return
	var pilgrim_done: bool = false
	var already_known: bool = false
	if sf.has_method("has_permanent"):
		pilgrim_done = bool(sf.has_permanent(&"seventh_breath_pilgrimage_done"))
		already_known = bool(sf.has_permanent(&"seventh_breath_known"))
	visible = pilgrim_done and not already_known
	set_process(visible)
	set_physics_process(visible)

# Override the base NPC dialogue path. We don't open the standard
# branching panel; this is a single-line moment that fires effects.
func _open_dialogue() -> void:
	# Set greeting based on Heaven-Rule state. Two lines total in this
	# whole NPC, that's the lore weight.
	var player: Node = get_tree().get_first_node_in_group("player") if get_tree() else null
	if player and player.get("character_appearance") and player.character_appearance and player.character_appearance.get("lucifer_walked_back"):
		greeting = WALKED_BACK_LINE
	else:
		greeting = ONE_LINE

	# Fire the final stage's objective. QuestRegistry.progress(&"reach_zone",
	# &"sun_gate", 1) completes q_seventh_breath_unspoken, which sets the
	# seventh_breath_known permanent flag and unlocks the hidden achievement
	# + title via the existing achievement-tracker pipeline.
	var qr: Node = get_node_or_null("/root/QuestRegistry")
	if qr and qr.has_method("progress"):
		qr.progress(&"reach_zone", &"sun_gate", 1)

	# Cinematic sting: heaven cue layered with lodestone at a high pitch.
	# This is the SOUND the Sixth Master meant by "when the sun stops,
	# listen." Skipped silently if AudioBus isn't loaded.
	var ab: Node = get_node_or_null("/root/AudioBus")
	if ab and ab.has_method("play_cue"):
		ab.play_cue(&"level_up", global_position, -1.5, 1.0)
		ab.play_cue(&"lodestone", global_position, -4.0, 1.4)

	# Visual flourish: brief slowmo + warm flash so the moment carries
	# even on a silent run. Juice exposes these primitives already.
	var juice: Node = get_node_or_null("/root/Juice")
	if juice:
		if juice.has_method("slowmo"):
			juice.slowmo(0.40, 0.6)
		if juice.has_method("flash"):
			juice.flash(Color(1.00, 0.92, 0.55), 0.40, 0.85)

	# Now let the base panel show the single greeting line. This is the
	# only time the Seventh speaks; after this exchange the gate hides
	# him (seventh_breath_known will be set by the quest completion
	# above, which re-evaluates visibility on next scene load).
	super._open_dialogue()

# Re-evaluate visibility when SaveFlags change. The Seventh disappears
# the moment the player completes stage 3 even within the same scene.
# Called by Player on flag updates if the integration is wired; safe
# to call manually too.
func refresh_gate() -> void:
	_apply_visibility_gate()
