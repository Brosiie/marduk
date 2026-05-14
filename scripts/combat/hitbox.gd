extends Area3D
class_name Hitbox

# Active offensive volume spawned during an attack. Activates briefly,
# scans for Hurtboxes, applies damage, despawns or disables.

@export var ability: Ability
var attacker_stats  # PlayerStats Resource OR an EnemyBase/BossBase Node (duck-typed)
@export var lifetime: float = 0.15
@export var team: StringName = &"player"  # do not damage same-team hurtboxes

var hit_set: Dictionary = {}  # prevent multi-hits per swing

func _ready() -> void:
	collision_layer = _layer_for_team(team)
	collision_mask = _mask_for_team(team)
	body_entered.connect(_on_body_entered)
	area_entered.connect(_on_area_entered)
	if lifetime > 0.0:
		var t := get_tree().create_timer(lifetime)
		t.timeout.connect(_on_expired)

func _on_expired() -> void:
	if hit_set.is_empty() and has_meta("miss_punishment_seconds"):
		var owner_node: Node = get_meta("punishable_owner", null)
		var secs: float = float(get_meta("miss_punishment_seconds", 0.0))
		if owner_node and is_instance_valid(owner_node) and secs > 0.0:
			owner_node.locked = true
			get_tree().create_timer(secs).timeout.connect(func(): if is_instance_valid(owner_node): owner_node.locked = false)
	queue_free()

func _layer_for_team(t: StringName) -> int:
	# layer 4 = PlayerHitbox, layer 5 = EnemyHitbox
	return 1 << 3 if t == &"player" else 1 << 4

func _mask_for_team(t: StringName) -> int:
	# scan opposing hurtboxes (player hitbox -> enemy bodies, enemy hitbox -> player body)
	return 1 << 2 if t == &"player" else 1 << 1

func _on_body_entered(body: Node) -> void:
	_try_damage(body)

func _on_area_entered(area: Area3D) -> void:
	if area is Hurtbox:
		_try_damage(area.owner_actor)

func _try_damage(target: Node) -> void:
	if not target or target in hit_set:
		return
	hit_set[target] = true
	var result: DamageCalc.Result = DamageCalc.calc(attacker_stats, target, ability)
	# Outgoing damage multiplier: applied AFTER DamageCalc so buffs like
	# Battle Cry stack on top of the standard formula. The attacker
	# (Player or any actor with get_outgoing_damage_mult) gets the say.
	# Duck-typed so mobs/bosses without this method behave normally.
	var attacker: Node = get_meta("attacker_node", get_parent())
	if attacker and attacker.has_method("get_outgoing_damage_mult"):
		result.damage *= attacker.get_outgoing_damage_mult()
	if target.has_method("take_damage"):
		target.take_damage(result.damage, attacker)
	# Combo: tell the attacker their hit landed so they can stack.
	# Players hold the combo state; mobs/bosses ignore.
	if attacker and attacker.has_method("on_hit_landed"):
		attacker.on_hit_landed()
	# ELEMENT STATUS EFFECTS, fire abilities apply burn DoT, frost
	# applies slow, lightning chains to nearby enemies. Each element
	# becomes a verb in combat instead of just a damage-type tag.
	# Skip for player-team hits on player (e.g. self-AOEs would
	# debuff the caster). Effects only apply to ENEMIES from PLAYER
	# attacks (and vice versa for symmetric design).
	if ability and team == &"player":
		_apply_element_effect(target, ability.damage_type, attacker)
	# Hit impact VFX: spawn a small element-themed burst at the target's
	# position so the strike CONNECTING is visible. Closes the cast ->
	# travel -> impact loop. Color from ability.damage_type.
	_spawn_impact_burst(target, ability.damage_type if ability else 0)
	# Optional: emit a signal so VFX/SFX/floating numbers can react
	if has_node("/root/CombatBus"):
		get_node("/root/CombatBus").emit_hit(target, result, ability)

# Element->color (mirrors player.gd._color_for_element so we don't need
# to introspect the player from here). Adding new elements means
# updating both -- a tiny coupling that keeps Hitbox decoupled from
# Player.
const ELEMENT_COLORS := {
	0: Color(0.95, 0.85, 0.55),  # PHYSICAL: pale gold sparks
	1: Color(0.45, 0.40, 0.95),  # ARCANE
	2: Color(1.00, 0.45, 0.20),  # FIRE
	3: Color(0.65, 0.85, 1.00),  # FROST
	4: Color(0.95, 0.95, 0.40),  # LIGHTNING
	5: Color(1.00, 0.85, 0.45),  # HOLY
	6: Color(0.55, 0.20, 0.65),  # SHADOW
}

# Apply an element-driven status effect to the target. Looks up the
# target's StatusEffectsHolder (lives as a sibling on bosses/mobs)
# and calls .apply() with a configured StatusEffect resource.
#
# Elements covered:
#   FIRE      -> burn (DoT, 4s, 8 dmg/sec)
#   FROST     -> slow (move_speed_mult 0.55, 3s)
#   LIGHTNING -> chain (instant: 50% damage to one nearby enemy
#                within 5m of the original hit)
#   SHADOW    -> weakness (damage_dealt_mult 0.65, 4s)
#   HOLY      -> mark (defender takes +25% from all sources, 3s)
#
# Other elements (PHYSICAL, ARCANE) are no-ops, those rely on raw
# damage as their identity.
func _apply_element_effect(target: Node, element: int, attacker: Node) -> void:
	if target == null or not is_instance_valid(target):
		return
	var holder: Node = target.get_node_or_null("StatusEffectsHolder")
	if holder == null:
		return
	var effect: StatusEffect = null
	match element:
		Ability.DamageType.FIRE:
			effect = StatusEffect.new()
			effect.id = &"burn"
			effect.display_name = "Burn"
			effect.kind = StatusEffect.Kind.BURN
			effect.tint = Color(1.00, 0.35, 0.12)
			effect.duration = 4.0
			effect.tick_interval = 1.0
			effect.damage_per_tick = 8.0
			effect.damage_type = Ability.DamageType.FIRE
		Ability.DamageType.FROST:
			effect = StatusEffect.new()
			effect.id = &"slow"
			effect.display_name = "Frost Slow"
			effect.kind = StatusEffect.Kind.SLOW
			effect.tint = Color(0.55, 0.85, 1.00)
			effect.duration = 3.0
			effect.move_speed_mult = 0.55
		Ability.DamageType.SHADOW:
			effect = StatusEffect.new()
			effect.id = &"weakness"
			effect.display_name = "Weakness"
			effect.kind = StatusEffect.Kind.WEAKNESS
			effect.tint = Color(0.70, 0.25, 0.85)
			effect.duration = 4.0
			effect.damage_dealt_mult = 0.65
		Ability.DamageType.HOLY:
			effect = StatusEffect.new()
			effect.id = &"mark"
			effect.display_name = "Holy Mark"
			effect.kind = StatusEffect.Kind.MARK
			effect.tint = Color(1.00, 0.70, 0.18)
			effect.duration = 3.0
			effect.damage_taken_mult = 1.25
		Ability.DamageType.LIGHTNING:
			# Lightning is INSTANT chain, no DoT/buff. Find the
			# nearest other enemy within 5m of the original target
			# and deal 50% damage. No status effect resource needed.
			_chain_lightning_jump(target, attacker)
			return
	if effect and holder.has_method("apply"):
		holder.apply(effect)

# One-shot chain: pick the nearest OTHER enemy within 5m of the
# original target and deal 50% damage to it. Used by FIRE/FROST?
# No, only by LIGHTNING. Reads as 'electric arc jumps to second
# foe'.
func _chain_lightning_jump(original_target: Node, attacker: Node) -> void:
	if original_target == null or not original_target is Node3D:
		return
	var src: Node3D = original_target as Node3D
	var best: Node = null
	var best_dist: float = 5.0
	for n in get_tree().get_nodes_in_group("enemy"):
		if n == original_target:
			continue
		if not is_instance_valid(n) or not n is Node3D:
			continue
		var d: float = src.global_position.distance_to((n as Node3D).global_position)
		if d < best_dist:
			best_dist = d
			best = n
	if best and best.has_method("take_damage"):
		var chain_dmg: float = 0.5 * (ability.base_damage if ability else 20.0)
		best.take_damage(chain_dmg, attacker)
		# Lightning-arc visual: a thin yellow line from source to
		# target, fades over 250ms.
		_spawn_lightning_arc(src.global_position + Vector3(0, 1.4, 0),
			(best as Node3D).global_position + Vector3(0, 1.4, 0))

# Render a one-shot lightning bolt between two world points. Built
# from an ImmediateMesh line strip with random per-segment jitter
# so the arc reads as electrical, not laser.
func _spawn_lightning_arc(from_pos: Vector3, to_pos: Vector3) -> void:
	var arc := MeshInstance3D.new()
	arc.name = "ChainLightning"
	var im := ImmediateMesh.new()
	im.surface_begin(Mesh.PRIMITIVE_LINE_STRIP)
	var segments: int = 8
	for i in range(segments + 1):
		var t: float = float(i) / float(segments)
		var p: Vector3 = from_pos.lerp(to_pos, t)
		# Perpendicular jitter (skip endpoints for clean attach)
		if i > 0 and i < segments:
			p.x += (randf() - 0.5) * 0.6
			p.y += (randf() - 0.5) * 0.4
			p.z += (randf() - 0.5) * 0.6
		im.surface_add_vertex(p - from_pos)  # local coords
	im.surface_end()
	arc.mesh = im
	var amat := StandardMaterial3D.new()
	amat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	amat.albedo_color = Color(0.95, 0.95, 0.40, 1.0)
	amat.emission_enabled = true
	amat.emission = Color(1.0, 1.0, 0.6)
	amat.emission_energy_multiplier = 4.0
	amat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	amat.no_depth_test = true
	arc.material_override = amat
	get_tree().current_scene.add_child(arc)
	arc.global_position = from_pos
	# Fade out quick
	var tw := arc.create_tween()
	tw.tween_property(amat, "albedo_color:a", 0.0, 0.25)
	tw.parallel().tween_property(amat, "emission_energy_multiplier", 0.0, 0.25)
	get_tree().create_timer(0.4).timeout.connect(func():
		if is_instance_valid(arc): arc.queue_free())

func _spawn_impact_burst(target: Node, element: int) -> void:
	if not target or not (target is Node3D):
		return
	var color: Color = ELEMENT_COLORS.get(element, Color(0.95, 0.85, 0.55))
	var burst := GPUParticles3D.new()
	burst.name = "ImpactBurst"
	burst.amount = 16
	burst.lifetime = 0.45
	burst.one_shot = true
	burst.explosiveness = 0.95
	burst.visibility_aabb = AABB(Vector3(-1.5, -1, -1.5), Vector3(3, 3, 3))
	var mat := ParticleProcessMaterial.new()
	mat.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_SPHERE
	mat.emission_sphere_radius = 0.15
	mat.direction = Vector3.UP
	mat.spread = 75.0
	mat.initial_velocity_min = 1.4
	mat.initial_velocity_max = 3.2
	mat.gravity = Vector3(0, -2.0, 0)
	mat.scale_min = 0.10
	mat.scale_max = 0.20
	mat.color = color
	burst.process_material = mat
	var quad := QuadMesh.new()
	quad.size = Vector2(0.18, 0.18)
	var smat := StandardMaterial3D.new()
	smat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	smat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	smat.albedo_color = color
	smat.emission_enabled = true
	smat.emission = color
	smat.emission_energy_multiplier = 1.7
	smat.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
	smat.billboard_keep_scale = true
	quad.material = smat
	burst.draw_pass_1 = quad
	# Parent under current_scene so the burst persists past target queue_free
	# (death by this hit). Position at target's hurt zone (~chest).
	get_tree().current_scene.add_child(burst)
	burst.global_position = (target as Node3D).global_position + Vector3(0, 1.2, 0)
	# Auto-cleanup after the burst fades
	get_tree().create_timer(1.0).timeout.connect(func(): if is_instance_valid(burst): burst.queue_free())
