extends CanvasLayer
class_name TiamatVisionOverlay

# A vision: dim the screen, fade in violet text, hold, fade out. Fired
# at lodestones when Tiamat awareness >= WAKING_2 so the act of resting
# at a checkpoint becomes a chance to glimpse her dream. Spawned on
# demand by Lodestone, lives only as long as the vision plays.
#
# Visual sequence:
#   1. Black tint fades to alpha 0.55 over 0.6s while audio thrum starts
#   2. Violet text fades in, holds the line for 3.0s
#   3. Text + tint fade out together over 0.8s, then queue_free
#
# Vision lines are picked from a pool keyed by awareness tier so the
# WAKING_2 visions feel different from AWAKE visions, escalating from
# distant whispers to direct address.

const T := preload("res://scripts/ui/ui_theme.gd")

const FADE_IN_SECONDS: float = 0.6
const HOLD_SECONDS: float = 3.0
const FADE_OUT_SECONDS: float = 0.8
const TINT_TARGET_ALPHA: float = 0.55

# Per-tier vision line pools. The renderer picks a random entry from
# the pool that matches the player's current awareness tier. Lines
# escalate from "deep below" detachment to "she sees you" personal
# direct-address as awareness climbs.
const VISION_LINES_BY_TIER := {
	"WAKING_2": [
		"You feel something below the stone. It is not asleep. It is dreaming, and the dream is shaped like the city.",
		"The salt on your tongue tastes of the deep. Your mother's voice, coming from a place she has never been.",
		"A shape moves under the lodestone. Coils. The crystal goes cold. The shape is patient.",
		"The horizon has weight you can feel through your boots. Something is rising. Slowly. Patiently. Toward you.",
		"You hear breathing that is not yours, in a rhythm older than language. The lodestone hums in time with it.",
	],
	"AWAKE": [
		"She sees you. From the depth. From the salt. From every old well in every old city. She has been seeing you for some time.",
		"'Marduk's heir.' The thought is not yours. The voice is enormous. It is amused.",
		"You taste copper. You see, behind your eyes, a vast eye looking back. It does not blink. It is studying.",
		"The lodestone speaks. 'You woke me. We will meet at the edge of the world. Bring everything you carry.'",
		"There is no warning. She is just there, in your head, vast and tired and waiting. 'Soon, child. Come find me.'",
	],
}

# Tint color for the dim ColorRect. Slight violet so the moment reads
# as cosmic rather than just an arbitrary fade.
const TINT_COLOR: Color = Color(0.10, 0.06, 0.15)
const TEXT_COLOR_WAKING_2: Color = Color(0.85, 0.55, 0.95, 0.92)
const TEXT_COLOR_AWAKE: Color    = Color(0.95, 0.30, 0.55, 0.98)

func _ready() -> void:
	layer = 80  # above HUD bars + most modals, below death screen
	process_mode = Node.PROCESS_MODE_ALWAYS

# Public: fire the vision. Caller passes the awareness tier so we don't
# need to call back into TiamatRegistry from a class that's already
# downstream of it (Lodestone owns the trigger logic). `pool_override`
# lets tests inject deterministic lines.
func play(tier: String, pool_override: Array = []) -> void:
	var pool: Array = pool_override if not pool_override.is_empty() else VISION_LINES_BY_TIER.get(tier, [])
	if pool.is_empty():
		queue_free()
		return
	var line: String = pool[randi() % pool.size()]
	var text_color: Color = TEXT_COLOR_AWAKE if tier == "AWAKE" else TEXT_COLOR_WAKING_2
	_render_and_animate(line, text_color)

func _render_and_animate(line: String, text_color: Color) -> void:
	# Full-screen tint
	var tint := ColorRect.new()
	tint.color = Color(TINT_COLOR.r, TINT_COLOR.g, TINT_COLOR.b, 0.0)
	tint.anchor_left = 0.0; tint.anchor_right = 1.0
	tint.anchor_top = 0.0;  tint.anchor_bottom = 1.0
	tint.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(tint)

	# Text in the upper-third so it doesn't fight the action bar / chat log
	var label := Label.new()
	label.text = line
	label.add_theme_font_size_override("font_size", T.FONT_SUBHEAD)
	label.add_theme_color_override("font_color", Color(text_color.r, text_color.g, text_color.b, 0.0))
	label.add_theme_color_override("font_outline_color", Color(0.05, 0.0, 0.10, 0.0))
	label.add_theme_constant_override("outline_size", 4)
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.anchor_left = 0.5; label.anchor_right = 0.5
	label.anchor_top = 0.0;  label.anchor_bottom = 0.0
	label.offset_left = -380
	label.offset_right = 380
	label.offset_top = 100
	label.offset_bottom = 240
	add_child(label)

	# Audio thrum: low pitched lodestone cue layered with thunder. Fire
	# and forget; we don't sync the audio to the fade because the cue's
	# natural envelope already matches.
	var ab: Node = get_node_or_null("/root/AudioBus")
	if ab and ab.has_method("play_cue"):
		ab.play_cue(&"lodestone", Vector3.ZERO, -6.0, 0.4)
		ab.play_cue(&"thunder", Vector3.ZERO, -8.0, 0.5)

	# Tween: fade in, hold, fade out, free
	var tw := create_tween()
	tw.set_parallel(true)
	tw.tween_property(tint, "color:a", TINT_TARGET_ALPHA, FADE_IN_SECONDS).set_ease(Tween.EASE_OUT)
	tw.tween_property(label, "modulate:a", 1.0, FADE_IN_SECONDS).set_ease(Tween.EASE_OUT)
	tw.set_parallel(false)
	tw.tween_interval(HOLD_SECONDS)
	tw.set_parallel(true)
	tw.tween_property(tint, "color:a", 0.0, FADE_OUT_SECONDS).set_ease(Tween.EASE_IN)
	tw.tween_property(label, "modulate:a", 0.0, FADE_OUT_SECONDS).set_ease(Tween.EASE_IN)
	tw.set_parallel(false)
	tw.tween_callback(queue_free)
