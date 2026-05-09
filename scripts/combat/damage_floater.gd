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

static func spawn(target: Node3D, amount: float, is_crit: bool = false, element: StringName = &"physical", class_tint: Color = Color(0,0,0,0)) -> DamageFloater:
	if target == null or not is_instance_valid(target):
		return null
	var floater := DamageFloater.new()
	# Damage tiers — three sizes based on raw damage and crit flag so
	# small chip damage doesn't dominate the screen and big hits
	# really LAND. Tiers mirror Diablo / PoE conventions.
	#   tier 0 (chip):      under 15 damage         -> 18pt, no prefix
	#   tier 1 (normal):    15-50, non-crit         -> 26pt, no prefix
	#   tier 2 (heavy):     >=50 damage non-crit    -> 36pt, no prefix
	#   tier 3 (crit):      any crit                -> 56pt, "CRIT" prefix
	# Crit detection takes priority over numeric tier.
	var tier: int = 0
	if is_crit:
		tier = 3
	elif amount >= 50.0:
		tier = 2
	elif amount >= 15.0:
		tier = 1
	# Tier-driven label
	if tier == 3:
		floater.text = "CRIT %d!" % int(round(amount))
	elif tier == 2:
		floater.text = "%d!" % int(round(amount))  # heavy hit punctuated
	else:
		floater.text = "%d" % int(round(amount))
	floater.font_size = [18, 26, 36, 56][tier]
	floater.outline_size = [3, 5, 8, 14][tier]
	floater.outline_modulate = Color(0, 0, 0, 0.92)
	floater.modulate = ELEMENT_COLORS.get(element, ELEMENT_COLORS[&"physical"])
	if is_crit:
		# Crits lerp HARD toward bright gold and over-saturate. If a class
		# tint is provided (alpha > 0), the crit lean blends to the class
		# color instead, so Berserker crits go red, Mage crits go violet,
		# Demon crits go ember. Reads as 'this hit was YOURS' at a glance
		# in PvP / parties.
		if class_tint.a > 0.0:
			floater.modulate = floater.modulate.lerp(class_tint, 0.65)
		else:
			floater.modulate = floater.modulate.lerp(Color(1.0, 0.92, 0.50), 0.7)
	# Tier 2+ gets a faint shadow offset for extra punch — text shadow
	# doubles as a subtle motion-blur read when the number rises.
	if tier >= 2:
		floater.shaded = true
		floater.modulate = floater.modulate.lightened(0.15)
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
