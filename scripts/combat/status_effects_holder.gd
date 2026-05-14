extends Node
class_name StatusEffectsHolder

# Lives on Player and EnemyBase. Tracks active status effects, ticks DoTs, applies modifiers,
# announces changes via signals so UI/VFX can respond.

signal effect_applied(effect: StatusEffect, stacks: int)
signal effect_removed(effect: StatusEffect)
signal effect_ticked(effect: StatusEffect, damage: float)

class ActiveEffect:
	var effect: StatusEffect
	var time_left: float
	var stacks: int = 1
	var time_until_next_tick: float

@export var actor: Node  # the Player or EnemyBase this attaches to

var active: Array = []  # of ActiveEffect
var _visuals: Dictionary = {}  # StringName -> Node3D

func _ready() -> void:
	if actor == null and get_parent() != null:
		actor = get_parent()

func _process(delta: float) -> void:
	if not actor or not is_instance_valid(actor):
		return
	var to_remove: Array = []
	for ae: ActiveEffect in active:
		ae.time_left -= delta
		if ae.effect.tick_interval > 0.0 and (ae.effect.damage_per_tick > 0.0 or ae.effect.heal_per_tick > 0.0):
			ae.time_until_next_tick -= delta
			while ae.time_until_next_tick <= 0.0 and ae.time_left > 0.0:
				_tick(ae)
				ae.time_until_next_tick += ae.effect.tick_interval
		if ae.time_left <= 0.0:
			to_remove.append(ae)
	for ae in to_remove:
		active.erase(ae)
		effect_removed.emit(ae.effect)
		_remove_visual(ae.effect.id)

func apply(effect: StatusEffect) -> void:
	# Look for existing of same id
	for ae: ActiveEffect in active:
		if ae.effect.id == effect.id:
			if effect.stacks and ae.stacks < effect.max_stacks:
				ae.stacks += 1
			if effect.refresh_on_reapply:
				ae.time_left = effect.duration
				ae.time_until_next_tick = effect.tick_interval
			effect_applied.emit(effect, ae.stacks)
			_pulse_visual(effect.id)
			return
	# New effect
	var ae := ActiveEffect.new()
	ae.effect = effect
	ae.time_left = effect.duration
	ae.time_until_next_tick = effect.tick_interval
	ae.stacks = 1
	active.append(ae)
	effect_applied.emit(effect, 1)
	_spawn_visual(ae)

func remove(effect_id: StringName) -> void:
	for ae: ActiveEffect in active.duplicate():
		if ae.effect.id == effect_id:
			active.erase(ae)
			effect_removed.emit(ae.effect)
			_remove_visual(ae.effect.id)

func has(effect_id: StringName) -> bool:
	for ae: ActiveEffect in active:
		if ae.effect.id == effect_id:
			return true
	return false

func clear_all() -> void:
	var copy := active.duplicate()
	active.clear()
	for ae in copy:
		effect_removed.emit(ae.effect)
		_remove_visual(ae.effect.id)

# Aggregate modifiers (multiply across active effects)
func move_speed_multiplier() -> float:
	var m := 1.0
	for ae: ActiveEffect in active:
		m *= ae.effect.move_speed_mult
	return m

func damage_dealt_multiplier() -> float:
	var m := 1.0
	for ae: ActiveEffect in active:
		m *= ae.effect.damage_dealt_mult
	return m

func damage_taken_multiplier() -> float:
	var m := 1.0
	for ae: ActiveEffect in active:
		m *= ae.effect.damage_taken_mult
	return m

func is_actor_locked() -> bool:
	for ae: ActiveEffect in active:
		if ae.effect.locks_actor:
			return true
	return false

func _tick(ae: ActiveEffect) -> void:
	if not actor:
		return
	if ae.effect.damage_per_tick > 0.0 and actor.has_method("take_damage"):
		var dmg := ae.effect.damage_per_tick * float(ae.stacks)
		actor.take_damage(dmg, null)
		effect_ticked.emit(ae.effect, dmg)
	if ae.effect.heal_per_tick > 0.0 and actor.has_method("heal"):
		actor.heal(ae.effect.heal_per_tick * float(ae.stacks))
		effect_ticked.emit(ae.effect, -ae.effect.heal_per_tick)
	_pulse_visual(ae.effect.id)

# --- Actor-side status VFX ---

const KIND_VISUALS := {
	StatusEffect.Kind.BURN: { "color": Color(1.00, 0.35, 0.12), "height": 0.75, "ring": false },
	StatusEffect.Kind.POISON: { "color": Color(0.45, 0.95, 0.25), "height": 0.75, "ring": false },
	StatusEffect.Kind.BLEED: { "color": Color(0.90, 0.05, 0.08), "height": 0.85, "ring": false },
	StatusEffect.Kind.SLOW: { "color": Color(0.55, 0.85, 1.00), "height": 0.70, "ring": true },
	StatusEffect.Kind.STUN: { "color": Color(1.00, 0.90, 0.25), "height": 1.95, "ring": true },
	StatusEffect.Kind.BLIND: { "color": Color(0.30, 0.25, 0.38), "height": 1.30, "ring": false },
	StatusEffect.Kind.WEAKNESS: { "color": Color(0.70, 0.25, 0.85), "height": 1.15, "ring": false },
	StatusEffect.Kind.MARK: { "color": Color(1.00, 0.70, 0.18), "height": 2.05, "ring": true },
	StatusEffect.Kind.REGEN: { "color": Color(0.40, 1.00, 0.55), "height": 0.80, "ring": true },
	StatusEffect.Kind.FROST_VULNERABILITY: { "color": Color(0.55, 0.85, 1.00), "height": 1.00, "ring": true },
	StatusEffect.Kind.IGNITE_VULNERABILITY: { "color": Color(1.00, 0.42, 0.15), "height": 1.00, "ring": false },
}

func _spawn_visual(ae: ActiveEffect) -> void:
	if actor == null or not is_instance_valid(actor) or not (actor is Node3D):
		return
	var id: StringName = ae.effect.id
	_remove_visual(id)
	var entry: Dictionary = KIND_VISUALS.get(int(ae.effect.kind), KIND_VISUALS[StatusEffect.Kind.BURN])
	var color: Color = ae.effect.tint if ae.effect.tint != Color.WHITE else entry["color"]
	var root := Node3D.new()
	root.name = "StatusVisual_%s" % String(id)
	(actor as Node3D).add_child(root)
	root.position = Vector3(0, float(entry["height"]), 0)
	var particles := GPUParticles3D.new()
	particles.name = "Aura"
	particles.amount = _particle_amount_for(ae.effect.kind)
	particles.lifetime = 0.85
	particles.preprocess = 0.35
	particles.visibility_aabb = AABB(Vector3(-1.5, -1.5, -1.5), Vector3(3, 3, 3))
	var pm := ParticleProcessMaterial.new()
	pm.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_SPHERE
	pm.emission_sphere_radius = _emission_radius_for(ae.effect.kind)
	pm.direction = Vector3.UP
	pm.spread = _spread_for(ae.effect.kind)
	pm.initial_velocity_min = 0.15
	pm.initial_velocity_max = _velocity_for(ae.effect.kind)
	pm.gravity = _gravity_for(ae.effect.kind)
	pm.scale_min = 0.045
	pm.scale_max = _scale_for(ae.effect.kind)
	pm.color = color
	pm.tangential_accel_min = -0.6
	pm.tangential_accel_max = 0.9
	particles.process_material = pm
	var quad := QuadMesh.new()
	quad.size = Vector2(0.12, 0.12)
	var mat := StandardMaterial3D.new()
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.albedo_color = color
	mat.emission_enabled = true
	mat.emission = color
	mat.emission_energy_multiplier = _emission_energy_for(ae.effect.kind)
	mat.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
	mat.billboard_keep_scale = true
	quad.material = mat
	particles.draw_pass_1 = quad
	root.add_child(particles)
	if bool(entry["ring"]):
		root.add_child(_make_status_ring(color, ae.effect.kind))
		if ae.effect.kind == StatusEffect.Kind.MARK:
			root.add_child(_make_mark_label(color))
	_visuals[id] = root

func _remove_visual(effect_id: StringName) -> void:
	var node: Node = _visuals.get(effect_id, null)
	if node and is_instance_valid(node):
		node.queue_free()
	_visuals.erase(effect_id)

func _pulse_visual(effect_id: StringName) -> void:
	var node: Node3D = _visuals.get(effect_id, null)
	if node == null or not is_instance_valid(node):
		return
	node.scale = Vector3.ONE * 1.22
	var tw := node.create_tween()
	tw.tween_property(node, "scale", Vector3.ONE, 0.18).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)

func _make_status_ring(color: Color, kind: int) -> MeshInstance3D:
	var ring := MeshInstance3D.new()
	ring.name = "Ring"
	var mesh := TorusMesh.new()
	mesh.inner_radius = 0.52 if kind != StatusEffect.Kind.MARK else 0.34
	mesh.outer_radius = 0.56 if kind != StatusEffect.Kind.MARK else 0.38
	ring.mesh = mesh
	ring.rotation.x = deg_to_rad(90.0)
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.albedo_color = Color(color.r, color.g, color.b, 0.55)
	mat.emission_enabled = true
	mat.emission = color
	mat.emission_energy_multiplier = 1.9
	mat.no_depth_test = true
	ring.material_override = mat
	return ring

func _make_mark_label(color: Color) -> Label3D:
	var l := Label3D.new()
	l.text = "MARK"
	l.font_size = 18
	l.pixel_size = 0.004
	l.fixed_size = true
	l.no_depth_test = true
	l.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	l.outline_size = 5
	l.outline_modulate = Color(0, 0, 0, 0.9)
	l.modulate = color.lightened(0.35)
	l.position = Vector3(0, 0.16, 0)
	return l

func _particle_amount_for(kind: int) -> int:
	match kind:
		StatusEffect.Kind.BURN: return 42
		StatusEffect.Kind.SLOW, StatusEffect.Kind.FROST_VULNERABILITY: return 34
		StatusEffect.Kind.MARK: return 18
		StatusEffect.Kind.WEAKNESS, StatusEffect.Kind.BLIND: return 30
		_: return 24

func _emission_radius_for(kind: int) -> float:
	match kind:
		StatusEffect.Kind.MARK: return 0.12
		StatusEffect.Kind.SLOW, StatusEffect.Kind.FROST_VULNERABILITY: return 0.72
		_: return 0.42

func _spread_for(kind: int) -> float:
	match kind:
		StatusEffect.Kind.BURN: return 35.0
		StatusEffect.Kind.SLOW, StatusEffect.Kind.FROST_VULNERABILITY: return 80.0
		StatusEffect.Kind.WEAKNESS, StatusEffect.Kind.BLIND: return 95.0
		_: return 60.0

func _velocity_for(kind: int) -> float:
	match kind:
		StatusEffect.Kind.BURN: return 1.3
		StatusEffect.Kind.MARK: return 0.35
		StatusEffect.Kind.SLOW, StatusEffect.Kind.FROST_VULNERABILITY: return 0.55
		_: return 0.85

func _gravity_for(kind: int) -> Vector3:
	match kind:
		StatusEffect.Kind.BURN: return Vector3(0, 0.55, 0)
		StatusEffect.Kind.SLOW, StatusEffect.Kind.FROST_VULNERABILITY: return Vector3(0, -0.12, 0)
		StatusEffect.Kind.WEAKNESS, StatusEffect.Kind.BLIND: return Vector3(0, -0.25, 0)
		_: return Vector3.ZERO

func _scale_for(kind: int) -> float:
	match kind:
		StatusEffect.Kind.BURN: return 0.16
		StatusEffect.Kind.MARK: return 0.10
		StatusEffect.Kind.SLOW, StatusEffect.Kind.FROST_VULNERABILITY: return 0.13
		_: return 0.15

func _emission_energy_for(kind: int) -> float:
	match kind:
		StatusEffect.Kind.BURN: return 2.2
		StatusEffect.Kind.MARK: return 2.8
		StatusEffect.Kind.SLOW, StatusEffect.Kind.FROST_VULNERABILITY: return 1.7
		StatusEffect.Kind.WEAKNESS, StatusEffect.Kind.BLIND: return 1.5
		_: return 1.6
