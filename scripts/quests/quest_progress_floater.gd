extends Label3D
class_name QuestProgressFloater

# A Label3D that pops above a killed mob to show "(5/8) Tashmu's Footmen"
# the moment a kill ticks a quest objective forward. Reads as immediate
# feedback that the kill MATTERED beyond loot + XP.
#
# Pop tier:
#   in-progress (count < required) -> gold "(N/M) <objective desc>"
#   complete    (count = required) -> green "✓ <objective desc> COMPLETE"
#
# The floater rises slower and holds longer than DamageFloater because
# the player needs to actually READ it, not just see a number flash.
#
# Spawn pattern:
#   QuestProgressFloater.spawn(killed_mob, "Eliminate Tashmu's Footmen", 5, 8)

const RISE_HEIGHT: float = 2.4
const RISE_DURATION: float = 1.8
const HOLD_DURATION: float = 1.4   # time to read the text before fade
const FADE_DURATION: float = 0.6
# Y-offset above the killed mob's center. Higher than DamageFloater (1.8)
# so the two don't overlap when both fire in the same frame.
const SPAWN_HEIGHT: float = 2.4

static func spawn(target: Node3D, description: String, count: int, required: int) -> QuestProgressFloater:
	if target == null or not is_instance_valid(target):
		return null
	if description == "":
		return null
	var floater := QuestProgressFloater.new()
	var is_complete: bool = count >= required
	if is_complete:
		floater.text = "✓ %s COMPLETE" % description.to_upper()
		floater.modulate = Color(0.50, 0.95, 0.55)  # bright completion green
		floater.font_size = 30
		floater.outline_size = 7
	else:
		floater.text = "(%d/%d) %s" % [count, required, description]
		floater.modulate = Color(1.00, 0.85, 0.30)  # gold for in-progress
		floater.font_size = 24
		floater.outline_size = 5
	floater.outline_modulate = Color(0.10, 0.05, 0.0, 0.95)
	floater.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	floater.no_depth_test = true  # readable through walls so the player doesn't lose it behind geometry
	floater.fixed_size = true
	floater.pixel_size = 0.006
	# Spawn at SPAWN_HEIGHT above the target. No jitter, just one floater
	# per progress event, the text needs to read clearly.
	floater.position = target.global_position + Vector3(0, SPAWN_HEIGHT, 0)
	target.get_tree().current_scene.add_child(floater)
	floater._animate(is_complete)
	return floater

# Rise + linger + fade. Completion floaters get a small extra scale-up
# punch on spawn so the "✓ COMPLETE" hits harder than a routine
# "(5/8)" tick.
func _animate(is_complete: bool) -> void:
	var start_pos: Vector3 = position
	var end_pos: Vector3 = start_pos + Vector3(0, RISE_HEIGHT, 0)
	# Pre-tween punch for completes, scale 1.4 -> 1.0 over 0.18s before
	# the rise begins. Sells the milestone moment.
	if is_complete:
		scale = Vector3.ONE * 1.4
		var punch := create_tween()
		punch.tween_property(self, "scale", Vector3.ONE, 0.18).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	# Rise (slow ease-out so the eye can track it) parallel with hold
	var tw := create_tween()
	tw.set_parallel(true)
	tw.tween_property(self, "position", end_pos, RISE_DURATION).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tw.set_parallel(false)
	tw.tween_interval(HOLD_DURATION)
	tw.tween_property(self, "modulate:a", 0.0, FADE_DURATION)
	tw.tween_callback(queue_free)
