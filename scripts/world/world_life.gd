extends Node

# WorldLife — autoload that spawns ambient "the world is alive" details:
# birds arcing across the sky, smoke rising from chimneys, magical motes
# drifting at intro zones. None of these affect gameplay — they exist
# purely so the world feels inhabited.
#
# Usage from a zone scene (or zone_composer):
#   WorldLife.spawn_bird_flock(get_tree().current_scene, 4, Vector3(0, 18, 0), 50.0)
#   WorldLife.spawn_chimney_smoke(at_pos)
#   WorldLife.spawn_intro_motes(at_pos, 8.0)
#
# Each helper creates self-managing children that clean themselves up on
# scene unload. We never persist them in saves.

const BIRD_SPEED_RANGE := Vector2(8.0, 14.0)
const BIRD_BOB_AMPLITUDE := 0.8
const BIRD_BOB_FREQUENCY := 1.6

# Tracked birds: each entry is { node, center, radius, heading, speed, phase }.
# We drive movement here so each bird doesn't need its own script attached
# (cheaper, simpler, easier to debug).
var _birds: Array = []
var _t: float = 0.0

func _process(delta: float) -> void:
	_t += delta
	# Prune freed bird nodes (e.g. after scene unload)
	_birds = _birds.filter(func(b): return is_instance_valid(b.node))
	for b in _birds:
		_step_bird(b, delta)

func _step_bird(b: Dictionary, _delta: float) -> void:
	var phase: float = _t + b.phase
	var heading: float = b.heading
	var speed: float = b.speed
	var radius: float = b.radius
	# Loop along heading direction; wrap at the band ends for an infinite-feeling pass
	var distance: float = fposmod(speed * phase, radius * 2.0) - radius
	var dir := Vector3(cos(heading), 0.0, sin(heading))
	var pos: Vector3 = b.center + dir * distance
	pos.y += sin(phase * BIRD_BOB_FREQUENCY) * BIRD_BOB_AMPLITUDE
	var node: Node3D = b.node
	node.global_position = pos
	node.rotation.y = -heading + PI * 0.5
	# Wing flap effect: subtle scale jitter on Y
	var flap := 0.85 + 0.15 * sin(phase * 7.0)
	node.scale = Vector3(1.0, flap, 1.0)

# --- Public API ---

# Spawns `count` birds drifting back and forth across an area.
# `center` is the volume center. `radius` is the half-extent.
func spawn_bird_flock(parent: Node, count: int, center: Vector3, radius: float) -> Node3D:
	var flock := Node3D.new()
	flock.name = "BirdFlock"
	parent.add_child(flock)
	for i in range(count):
		var bird := _make_bird()
		flock.add_child(bird)
		# Stagger phases so birds don't move in lockstep
		var phase_offset: float = float(i) / float(count) * 6.0
		var entry := {
			"node": bird,
			"center": center + Vector3(randf_range(-radius * 0.4, radius * 0.4), randf_range(-2.0, 2.0), randf_range(-radius * 0.4, radius * 0.4)),
			"radius": radius,
			"heading": randf() * TAU,
			"speed": randf_range(BIRD_SPEED_RANGE.x, BIRD_SPEED_RANGE.y),
			"phase": phase_offset,
		}
		_birds.append(entry)
	return flock

# Slow grey smoke column at `at_pos` — chimneys, campfires, braziers.
func spawn_chimney_smoke(parent: Node, at_pos: Vector3) -> GPUParticles3D:
	var smoke := _make_smoke_particles()
	parent.add_child(smoke)
	smoke.global_position = at_pos
	return smoke

# Golden floating motes over a radius — sacred zones, lodestones, boss arenas.
func spawn_intro_motes(parent: Node, at_pos: Vector3, radius: float, color: Color = Color(1.0, 0.85, 0.5, 1.0)) -> GPUParticles3D:
	var motes := _make_mote_particles(radius, color)
	parent.add_child(motes)
	motes.global_position = at_pos
	return motes

# Cherry blossom petals drifting down across an area. For Japanese-themed
# zones (Sword-Vow Ruins). Petals drift sideways with wind, fall slowly,
# rotate gently. Read as pink confetti from far away — instantly says
# "Japan / spring / sakura". Returns the GPUParticles3D so caller can
# parent-rotate or move it.
func spawn_petal_fall(parent: Node, area_center: Vector3, area_size: Vector3, petal_color: Color = Color(1.0, 0.65, 0.75, 0.95)) -> GPUParticles3D:
	var p := _make_petal_particles(area_size, petal_color)
	parent.add_child(p)
	p.global_position = area_center
	return p

func _make_petal_particles(area_size: Vector3, color: Color) -> GPUParticles3D:
	var p := GPUParticles3D.new()
	p.name = "PetalFall"
	p.amount = 80
	p.lifetime = 12.0
	p.preprocess = 6.0  # already raining petals on scene load
	var mat := ParticleProcessMaterial.new()
	# Spawn at top of the volume, drift down + sideways
	mat.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_BOX
	mat.emission_box_extents = Vector3(area_size.x * 0.5, 0.5, area_size.z * 0.5)
	# Petal direction: very gentle downward + slight wind drift
	mat.direction = Vector3(0.3, -1.0, 0.1)
	mat.spread = 30.0
	mat.initial_velocity_min = 0.3
	mat.initial_velocity_max = 0.8
	mat.gravity = Vector3(0.4, -0.4, 0.2)  # mostly down with sideways wind
	# Petals tumble as they fall
	mat.angular_velocity_min = -120.0
	mat.angular_velocity_max = 120.0
	mat.scale_min = 0.04
	mat.scale_max = 0.10
	mat.color = color
	# Subtle horizontal sine drift via tangential accel
	mat.tangential_accel_min = -0.3
	mat.tangential_accel_max = 0.3
	p.process_material = mat
	# Petal shape: small quad, billboard-aligned, soft pink albedo
	var quad := QuadMesh.new()
	quad.size = Vector2(0.18, 0.10)  # rectangular like a real petal
	var smat := StandardMaterial3D.new()
	smat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	smat.shading_mode = BaseMaterial3D.SHADING_MODE_PER_PIXEL
	smat.albedo_color = color
	smat.cull_mode = BaseMaterial3D.CULL_DISABLED  # visible from any angle
	smat.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
	smat.billboard_keep_scale = true
	quad.material = smat
	p.draw_pass_1 = quad
	# Set the visibility AABB so the renderer doesn't cull when player walks
	# around. Big enough to cover the full area volume.
	var box := AABB(-area_size * 0.5 - Vector3(0, 5, 0), area_size + Vector3(0, 10, 0))
	p.visibility_aabb = box
	return p

# --- Bird mesh ---

func _make_bird() -> Node3D:
	var bird := MeshInstance3D.new()
	bird.name = "Bird"
	# Tiny dark "winged silhouette" mesh — reads as a bird at any angle.
	# 4 verts: tail, two wingtips, dorsal point. 3 triangles.
	var arr_mesh := ArrayMesh.new()
	var verts := PackedVector3Array([
		Vector3(0.0, 0.0, 0.4),       # tail
		Vector3(-0.5, 0.0, -0.2),     # left wing
		Vector3(0.5, 0.0, -0.2),      # right wing
		Vector3(0.0, 0.05, -0.05),    # subtle dome
	])
	var indices := PackedInt32Array([
		0, 1, 2,
		0, 2, 3,
		0, 3, 1,
	])
	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = verts
	arrays[Mesh.ARRAY_INDEX] = indices
	arr_mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	bird.mesh = arr_mesh
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.05, 0.04, 0.03, 1)
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	bird.set_surface_override_material(0, mat)
	return bird

# --- Smoke particles ---

func _make_smoke_particles() -> GPUParticles3D:
	var p := GPUParticles3D.new()
	p.name = "ChimneySmoke"
	p.amount = 24
	p.lifetime = 5.0
	p.preprocess = 2.0
	var mat := ParticleProcessMaterial.new()
	mat.direction = Vector3.UP
	mat.spread = 8.0
	mat.initial_velocity_min = 0.6
	mat.initial_velocity_max = 1.2
	mat.gravity = Vector3(0, 0.4, 0)
	mat.angular_velocity_min = -10.0
	mat.angular_velocity_max = 10.0
	mat.scale_min = 0.6
	mat.scale_max = 1.6
	mat.color = Color(0.4, 0.4, 0.42, 0.45)
	mat.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_SPHERE
	mat.emission_sphere_radius = 0.15
	p.process_material = mat
	var quad := QuadMesh.new()
	quad.size = Vector2(0.8, 0.8)
	var smat := StandardMaterial3D.new()
	smat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	smat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	smat.albedo_color = Color(0.55, 0.55, 0.58, 0.55)
	smat.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
	smat.billboard_keep_scale = true
	quad.material = smat
	p.draw_pass_1 = quad
	return p

# --- Magical mote particles (intro/lodestone/boss zones) ---

func _make_mote_particles(radius: float, color: Color) -> GPUParticles3D:
	var p := GPUParticles3D.new()
	p.name = "AmbientMotes"
	p.amount = 60
	p.lifetime = 9.0
	p.preprocess = 4.0
	var mat := ParticleProcessMaterial.new()
	mat.direction = Vector3.UP
	mat.spread = 30.0
	mat.initial_velocity_min = 0.05
	mat.initial_velocity_max = 0.25
	mat.gravity = Vector3(0, 0.05, 0)
	mat.scale_min = 0.05
	mat.scale_max = 0.12
	mat.color = color
	mat.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_SPHERE
	mat.emission_sphere_radius = radius
	mat.tangential_accel_min = -0.4
	mat.tangential_accel_max = 0.4
	p.process_material = mat
	var quad := QuadMesh.new()
	quad.size = Vector2(0.18, 0.18)
	var smat := StandardMaterial3D.new()
	smat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	smat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	smat.albedo_color = color
	smat.emission_enabled = true
	smat.emission = color
	smat.emission_energy_multiplier = 1.4
	smat.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
	smat.billboard_keep_scale = true
	quad.material = smat
	p.draw_pass_1 = quad
	return p
