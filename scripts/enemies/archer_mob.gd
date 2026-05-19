extends "res://scripts/enemies/enemy_base.gd"
class_name ArcherMob

# Archer-pattern AI. Overrides the base chase/attack with kite + shoot.
# Used by mobs whose role == ARCHER (raider_archer, usurper_archer,
# shrine_zealot, etc).
#
# Behavior:
#   - Acquires target same as EnemyBase.
#   - Maintains a `kite_distance` band: too close -> backpedal, too far ->
#     close, in band -> stand and shoot.
#   - Every `attack_cooldown` seconds while in band + LOS, fires an Arrow
#     projectile that travels in a straight line and hits anything in the
#     player's hurtbox.

@export var kite_distance: float = 9.0
@export var min_distance: float = 5.0
@export var arrow_speed: float = 18.0
@export var arrow_damage: float = 0.0  # 0 = use contact_damage as default
@export var arrow_lifetime: float = 1.6

const RETREAT_SPEED_MULT := 0.85

# Strafe state, sign (-1 / +1) flips every 1.5-2.6s so the archer
# weaves laterally while in the kite-fire band.
var _strafe_dir_sign: float = 1.0
var _strafe_timer: float = 0.0

# Returns true if there's a clear line of sight from the archer's
# eye (1.6m up) to the target's chest (1.4m up). Used to gate firing
# so archers don't shoot blindly through walls.
func _has_line_of_sight() -> bool:
	if target == null:
		return false
	var space := get_world_3d().direct_space_state
	var from_pos: Vector3 = global_position + Vector3(0, 1.6, 0)
	var to_pos: Vector3 = (target as Node3D).global_position + Vector3(0, 1.4, 0)
	var query := PhysicsRayQueryParameters3D.create(from_pos, to_pos)
	query.collision_mask = 1  # world geometry layer only, ignore actors
	query.exclude = [get_rid()]
	var hit := space.intersect_ray(query)
	# Empty hit means no obstruction → LOS clear. A wall hit means
	# something is between us and the target.
	return hit.is_empty()

func _physics_process(delta: float) -> void:
	if state == State.DEAD:
		return
	# Acquire target
	if target == null or not is_instance_valid(target):
		_acquire_target()
	if target == null:
		_idle_step(delta)
		move_and_slide()
		return
	var to_target: Vector3 = target.global_position - global_position
	var dist: float = to_target.length()
	# Face target
	if to_target.length_squared() > 0.001:
		var fwd_xz := Vector3(to_target.x, 0, to_target.z).normalized()
		look_at(global_position + fwd_xz, Vector3.UP)
	# Kite zone behavior
	if dist < min_distance:
		# Backpedal
		var away: Vector3 = -to_target.normalized()
		velocity.x = away.x * move_speed * RETREAT_SPEED_MULT
		velocity.z = away.z * move_speed * RETREAT_SPEED_MULT
	elif dist > kite_distance + 1.5:
		# Close in
		var dir: Vector3 = to_target.normalized()
		velocity.x = dir.x * move_speed
		velocity.z = dir.z * move_speed
	else:
		# In band: STRAFE laterally while shooting. Strafing makes
		# archers a moving target (player can't just face-tank kite-
		# focus) AND adds visual life, they're not sentries, they're
		# active combatants. Pick a side once and persist for ~2s
		# before flipping so the strafe reads as deliberate not
		# random.
		_strafe_timer -= delta
		if _strafe_timer <= 0.0:
			_strafe_dir_sign *= -1
			_strafe_timer = randf_range(1.5, 2.6)
		var perp: Vector3 = Vector3(-to_target.z, 0, to_target.x).normalized() * _strafe_dir_sign
		velocity.x = perp.x * move_speed * 0.55
		velocity.z = perp.z * move_speed * 0.55
		_attack_timer -= delta
		if _attack_timer <= 0.0 and _has_line_of_sight():
			# LOS gate, don't fire blindly through walls. Without
			# this, archers in the dojo would shoot the player from
			# behind two walls, which is unfair AND breaks immersion.
			_fire_arrow()
			_attack_timer = attack_cooldown
		elif _attack_timer <= 0.0:
			# No LOS, short retry interval instead of full cooldown
			# so we don't lose 3s of fire time waiting for a clean shot.
			_attack_timer = 0.5
	# Apply gravity
	if not is_on_floor():
		velocity.y -= gravity * delta
	move_and_slide()

func _acquire_target() -> void:
	for p in get_tree().get_nodes_in_group("player"):
		if global_position.distance_to(p.global_position) < detect_radius:
			target = p
			break

func _idle_step(_delta: float) -> void:
	velocity.x = 0
	velocity.z = 0

# Spawns a small projectile that flies toward the target and damages on
# contact. Built procedurally so we don't need an arrow.tscn yet.
func _fire_arrow() -> void:
	if target == null:
		return
	var arrow := Area3D.new()
	arrow.name = "Arrow"
	arrow.collision_layer = 8
	arrow.collision_mask = 2  # players-only
	# Visual
	var mi := MeshInstance3D.new()
	var box := BoxMesh.new()
	box.size = Vector3(0.05, 0.05, 0.7)
	mi.mesh = box
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.5, 0.35, 0.20)
	mi.material_override = mat
	arrow.add_child(mi)
	# Trigger
	var sphere := SphereShape3D.new()
	sphere.radius = 0.25
	var cs := CollisionShape3D.new()
	cs.shape = sphere
	arrow.add_child(cs)
	# Position at archer's bow height, aim at target chest. The arrow has
	# to enter the tree BEFORE look_at() — Godot 4's look_at requires
	# is_inside_tree() and silently bailed (returning identity transform)
	# when called pre-attach. Two errors per shot got logged; reordering
	# clears them. Setting transform.origin first preserves the start_pos
	# during the brief moment before look_at runs.
	var start_pos: Vector3 = global_position + Vector3(0, 1.2, 0)
	var aim_pos: Vector3 = target.global_position + Vector3(0, 1.0, 0)
	get_tree().current_scene.add_child(arrow)
	arrow.global_position = start_pos
	arrow.look_at(aim_pos, Vector3.UP)
	# Drive movement via a Tween: linear travel for `arrow_lifetime` seconds
	var dir: Vector3 = (aim_pos - start_pos).normalized()
	var travel: float = arrow_speed * arrow_lifetime
	var end_pos: Vector3 = start_pos + dir * travel
	var tw := arrow.create_tween()
	tw.tween_property(arrow, "global_position", end_pos, arrow_lifetime)
	tw.tween_callback(arrow.queue_free)
	# Damage on body entered
	var dmg: float = arrow_damage if arrow_damage > 0.0 else contact_damage
	arrow.body_entered.connect(func(body: Node3D):
		if body.is_in_group("player") and body.has_method("take_damage"):
			body.take_damage(dmg, self)
			arrow.queue_free()
	)
	# Audio cue
	var ab = get_node_or_null("/root/AudioBus")
	if ab and ab.has_method("play_cue"):
		ab.play_cue(&"swing", global_position, -10.0, 1.6)
