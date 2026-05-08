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
	var attacker: Node = get_parent()
	if attacker and attacker.has_method("get_outgoing_damage_mult"):
		result.damage *= attacker.get_outgoing_damage_mult()
	if target.has_method("take_damage"):
		target.take_damage(result.damage, attacker)
	# Combo: tell the attacker their hit landed so they can stack.
	# Players hold the combo state; mobs/bosses ignore.
	if attacker and attacker.has_method("on_hit_landed"):
		attacker.on_hit_landed()
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
