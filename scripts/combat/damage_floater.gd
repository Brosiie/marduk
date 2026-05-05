extends Label3D
class_name DamageFloater

# A Label3D that pops above a damaged actor, tween-rises, scales briefly,
# fades, and queue_frees. Spawned on every hit registration so combat has
# crunch.
#
# Color encodes damage element and crit state:
#   PHYSICAL = pale yellow
#   FIRE     = orange-red
#   FROST    = pale blue
#   LIGHTNING= electric blue
#   HOLY     = warm gold
#   SHADOW   = dark violet
#   POISON   = bile green
# Crits get bigger size + bolder outline.
#
# Usage:
#   DamageFloater.spawn(target, 24.5, false, &"physical")
#   DamageFloater.spawn(target, 78.0, true,  &"fire")
#
# Static factory creates the node, configures it, parents under
# current_scene at the target's head position, and starts the tween.

const RISE_HEIGHT: float = 1.6
const RISE_DURATION: float = 0.95
const SHRINK_AT: float = 0.65   # 0..1 of duration before fade out

const ELEMENT_COLORS := {
	&"physical":  Color(0.95, 0.92, 0.55),
	&"fire":      Color(1.00, 0.45, 0.20),
	&"frost":     Color(0.65, 0.85, 1.00),
	&"lightning": Color(0.80, 0.85, 1.00),
	&"holy":      Color(1.00, 0.85, 0.45),
	&"shadow":    Color(0.55, 0.30, 0.75),
	&"poison":    Color(0.55, 0.95, 0.40),
	&"void":      Color(0.45, 0.20, 0.55),
	&"heal":      Color(0.40, 0.95, 0.55),
}

static func spawn(target: Node3D, amount: float, is_crit: bool = false, element: StringName = &"physical") -> DamageFloater:
	if target == null or not is_instance_valid(target):
		return null
	var floater := DamageFloater.new()
	floater.text = ("%d!" % int(round(amount))) if is_crit else ("%d" % int(round(amount)))
	floater.font_size = 36 if is_crit else 24
	floater.outline_size = 8 if is_crit else 4
	floater.outline_modulate = Color(0, 0, 0, 0.85)
	floater.modulate = ELEMENT_COLORS.get(element, ELEMENT_COLORS[&"physical"])
	if is_crit:
		floater.modulate = floater.modulate.lerp(Color(1.0, 0.95, 0.55), 0.4)
	floater.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	floater.no_depth_test = true
	floater.fixed_size = true
	floater.pixel_size = 0.005
	# Spawn at target head height (capsule top + 0.5m), small randomized x/z
	var jitter := Vector3(randf_range(-0.3, 0.3), 0, randf_range(-0.3, 0.3))
	floater.position = target.global_position + Vector3(0, 1.8, 0) + jitter
	target.get_tree().current_scene.add_child(floater)
	floater._animate()
	return floater

func _animate() -> void:
	var start_pos := position
	var end_pos := start_pos + Vector3(0, RISE_HEIGHT, 0)
	var tw := create_tween()
	tw.set_parallel(true)
	tw.tween_property(self, "position", end_pos, RISE_DURATION).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	# Fade after SHRINK_AT
	tw.tween_property(self, "modulate:a", 0.0, RISE_DURATION * (1.0 - SHRINK_AT)).set_delay(RISE_DURATION * SHRINK_AT)
	tw.set_parallel(false)
	tw.tween_callback(queue_free)
