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
	# Crits get a 'CRIT!' prefix + bigger fonts + brighter color so the
	# visual reads INSTANTLY. Non-crits stay readable but unobtrusive.
	floater.text = ("CRIT %d!" % int(round(amount))) if is_crit else ("%d" % int(round(amount)))
	floater.font_size = 48 if is_crit else 24
	floater.outline_size = 12 if is_crit else 4
	floater.outline_modulate = Color(0, 0, 0, 0.9)
	floater.modulate = ELEMENT_COLORS.get(element, ELEMENT_COLORS[&"physical"])
	if is_crit:
		# Crits lerp HARD toward bright gold and over-saturate
		floater.modulate = floater.modulate.lerp(Color(1.0, 0.92, 0.50), 0.7)
	floater.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	floater.no_depth_test = true
	floater.fixed_size = true
	floater.pixel_size = 0.006 if is_crit else 0.005
	# Spawn at target head height, jittered so stacked hits don't overlap
	var jitter := Vector3(randf_range(-0.3, 0.3), 0, randf_range(-0.3, 0.3))
	floater.position = target.global_position + Vector3(0, 1.8, 0) + jitter
	target.get_tree().current_scene.add_child(floater)
	floater._animate(is_crit)
	# Crit screen flash + audio cue: massive feedback for crit hits
	if is_crit:
		var juice: Node = target.get_node_or_null("/root/Juice")
		if juice and juice.has_method("flash"):
			juice.flash(Color(1.0, 0.92, 0.50), 0.18, 0.30)
	return floater

func _animate(is_crit: bool = false) -> void:
	var start_pos := position
	var end_pos := start_pos + Vector3(0, RISE_HEIGHT * (1.6 if is_crit else 1.0), 0)
	var tw := create_tween()
	tw.set_parallel(true)
	tw.tween_property(self, "position", end_pos, RISE_DURATION).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	# Crits scale up briefly for impact, then settle
	if is_crit:
		var orig_scale := scale
		scale = orig_scale * 0.6  # start small
		tw.tween_property(self, "scale", orig_scale * 1.4, 0.12).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		tw.chain().tween_property(self, "scale", orig_scale, 0.12)
	# Fade after SHRINK_AT
	tw.chain().tween_property(self, "modulate:a", 0.0, RISE_DURATION * (1.0 - SHRINK_AT)).set_delay(RISE_DURATION * SHRINK_AT)
	tw.set_parallel(false)
	tw.tween_callback(queue_free)
