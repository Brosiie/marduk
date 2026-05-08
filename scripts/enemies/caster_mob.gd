extends "res://scripts/enemies/enemy_base.gd"
class_name CasterMob

# Caster-pattern AI. Mid-range siegecraft: stays at `cast_distance` band,
# channels a long telegraph, then releases an AOE-ground orb at the
# player's last known position. Punishable during the channel window.
#
# Used by mobs whose role == CASTER (shrine_acolyte, blood_cultist,
# binding_shaman, etc).
#
# Behavior:
#   - Acquires target same as EnemyBase.
#   - Maintains `cast_distance` band: too close -> shuffle back, too far
#     -> shuffle forward (slower than archer kite to feel deliberate).
#   - In band -> channel for `channel_seconds`, spawn AOE on the floor.

@export var cast_distance: float = 11.0
@export var min_distance: float = 6.0
@export var channel_seconds: float = 1.6
@export var orb_speed: float = 9.0
@export var orb_aoe_radius: float = 2.6
@export var orb_lifetime: float = 1.2
@export var orb_color: Color = Color(0.55, 0.20, 0.85, 0.95)  # shadow violet default

const SHUFFLE_SPEED_MULT := 0.55  # slower than archer kite -> more vulnerable

var _channel_left: float = 0.0
var _channel_decal: MeshInstance3D = null

func _physics_process(delta: float) -> void:
	if state == State.DEAD:
		return
	if target == null or not is_instance_valid(target):
		_acquire_target_self()
	if target == null:
		velocity.x = 0; velocity.z = 0
		_apply_gravity(delta); move_and_slide()
		return
	var to_target: Vector3 = target.global_position - global_position
	var dist: float = to_target.length()
	# Face the target the whole time so the channel reads
	if to_target.length_squared() > 0.001:
		var fwd_xz := Vector3(to_target.x, 0, to_target.z).normalized()
		look_at(global_position + fwd_xz, Vector3.UP)
	# If channeling, hold still
	if _channel_left > 0.0:
		_channel_left -= delta
		velocity.x = 0; velocity.z = 0
		# Update telegraph progress (orb appears to bloom)
		_update_channel_decal()
		if _channel_left <= 0.0:
			_release_orb()
		_apply_gravity(delta); move_and_slide()
		return
	# Movement: shuffle to maintain band
	if dist < min_distance:
		var away: Vector3 = -to_target.normalized()
		velocity.x = away.x * move_speed * SHUFFLE_SPEED_MULT
		velocity.z = away.z * move_speed * SHUFFLE_SPEED_MULT
	elif dist > cast_distance + 1.5:
		var dir: Vector3 = to_target.normalized()
		velocity.x = dir.x * move_speed * SHUFFLE_SPEED_MULT
		velocity.z = dir.z * move_speed * SHUFFLE_SPEED_MULT
	else:
		# In band: begin channel if cooldown is done
		velocity.x = 0; velocity.z = 0
		_attack_timer -= delta
		if _attack_timer <= 0.0:
			_begin_channel()
			_attack_timer = attack_cooldown
	_apply_gravity(delta); move_and_slide()

func _apply_gravity(delta: float) -> void:
	if not is_on_floor():
		velocity.y -= gravity * delta

func _acquire_target_self() -> void:
	for p in get_tree().get_nodes_in_group("player"):
		if global_position.distance_to(p.global_position) < detect_radius:
			target = p
			break

# --- Channel ---

func _begin_channel() -> void:
	_channel_left = channel_seconds
	# Spawn telegraph at the target's CURRENT position so the player
	# can dodge if they move out. AOE_GROUND-style.
	_clear_channel_decal()
	var decal := MeshInstance3D.new()
	decal.name = "CastTelegraph"
	var quad := PlaneMesh.new()
	quad.size = Vector2(orb_aoe_radius * 2.0, orb_aoe_radius * 2.0)
	decal.mesh = quad
	var mat := ShaderMaterial.new()
	mat.shader = load("res://shaders/telegraph.gdshader")
	mat.set_shader_parameter("shape_id", 3)  # AOE_GROUND
	mat.set_shader_parameter("telegraph_color", orb_color)
	mat.set_shader_parameter("progress", 0.0)
	mat.set_shader_parameter("pulse_speed", 6.0)
	decal.material_override = mat
	get_tree().current_scene.add_child(decal)
	if target:
		decal.global_position = target.global_position + Vector3(0, 0.05, 0)
	_channel_decal = decal

func _update_channel_decal() -> void:
	if _channel_decal == null or not is_instance_valid(_channel_decal):
		return
	var prog: float = clamp(1.0 - (_channel_left / max(0.001, channel_seconds)), 0.0, 1.0)
	var mat: ShaderMaterial = _channel_decal.material_override
	if mat:
		mat.set_shader_parameter("progress", prog)

func _clear_channel_decal() -> void:
	if _channel_decal and is_instance_valid(_channel_decal):
		_channel_decal.queue_free()
	_channel_decal = null

func _release_orb() -> void:
	# Resolve where the orb lands. Snap to the telegraph position so
	# dodging out actually saves you (the orb committed to that spot).
	var land_pos: Vector3 = _channel_decal.global_position if (_channel_decal and is_instance_valid(_channel_decal)) else global_position
	_clear_channel_decal()
	# Spawn an AOE Hitbox at the landing spot
	var hb_script: GDScript = load("res://scripts/combat/hitbox.gd")
	if hb_script == null:
		return
	var hb: Node = hb_script.new()
	hb.team = &"enemy"
	hb.lifetime = 0.18
	# Build the ability resource
	var ab_res := Ability.new()
	ab_res.id = &"caster_orb"
	ab_res.base_damage = contact_damage * 1.4
	ab_res.damage_type = Ability.DamageType.SHADOW
	ab_res.range = orb_aoe_radius
	ab_res.radius = orb_aoe_radius
	hb.ability = ab_res
	hb.attacker_stats = self
	# Simple sphere shape at the landing spot
	var coll := CollisionShape3D.new()
	var sphere := SphereShape3D.new()
	sphere.radius = orb_aoe_radius
	coll.shape = sphere
	hb.add_child(coll)
	get_tree().current_scene.add_child(hb)
	hb.global_position = land_pos + Vector3(0, 0.5, 0)
	# Visual: a bright violet burst at the landing spot
	_spawn_orb_burst(land_pos)
	# Audio
	var aud: Node = get_node_or_null("/root/AudioBus")
	if aud and aud.has_method("play_cue"):
		aud.play_cue(&"shadow_cast", land_pos, -4.0, 0.85)

func _spawn_orb_burst(at_pos: Vector3) -> void:
	var burst := GPUParticles3D.new()
	burst.name = "OrbBurst"
	burst.amount = 35
	burst.lifetime = 0.7
	burst.one_shot = true
	burst.explosiveness = 0.95
	burst.visibility_aabb = AABB(Vector3(-3, -1, -3), Vector3(6, 4, 6))
	var mat := ParticleProcessMaterial.new()
	mat.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_SPHERE
	mat.emission_sphere_radius = 0.4
	mat.direction = Vector3.UP
	mat.spread = 80.0
	mat.initial_velocity_min = 2.5
	mat.initial_velocity_max = 5.5
	mat.gravity = Vector3(0, -3.0, 0)
	mat.scale_min = 0.18
	mat.scale_max = 0.36
	mat.color = orb_color
	burst.process_material = mat
	var quad := QuadMesh.new()
	quad.size = Vector2(0.30, 0.30)
	var smat := StandardMaterial3D.new()
	smat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	smat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	smat.albedo_color = orb_color
	smat.emission_enabled = true
	smat.emission = orb_color
	smat.emission_energy_multiplier = 1.8
	smat.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
	smat.billboard_keep_scale = true
	quad.material = smat
	burst.draw_pass_1 = quad
	get_tree().current_scene.add_child(burst)
	burst.global_position = at_pos + Vector3(0, 0.6, 0)
	get_tree().create_timer(1.5).timeout.connect(func(): if is_instance_valid(burst): burst.queue_free())

# Cleanup on death so a caster killed mid-channel doesn't leave its
# telegraph lingering in the world.
func _die(killer: Node) -> void:
	_clear_channel_decal()
	super._die(killer)
