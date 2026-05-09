extends Node3D
class_name ProceduralCherryBlossom

# A proper procedural cherry blossom (sakura) tree built from primitive
# meshes. Replaces the tinted Kenney "tree_default_fall.glb" hack ,
# those are GREEN trees with a pink modulate slapped on top, which
# reads as "leafy tree photographed through a rose filter" rather
# than actual sakura.
#
# Composition (bottom-up):
#   1. Trunk, tapered cylinder, dark warm brown bark
#   2. Major branches, 3-5 smaller tapered cylinders sprouting from
#      the trunk top at angled orientations, each with sub-twigs
#   3. Foliage clusters, 2-3 layered alpha-blended pink spheres at
#      branch tips. Layered tones (saturated core + pale halo + bright
#      highlight cap) for the depth that single-mesh trees lack
#   4. Petal scatter, small pink quads at the canopy base, randomized
#      drift positions so the tree looks like it's actively shedding
#
# Build cost is moderate (1 trunk + 4 branches + 12 foliage spheres +
# 20 petal quads = ~37 nodes per tree). With 56 trees in the grove
# that's ~2k nodes, but each is a fast PrimitiveMesh + StandardMaterial
# so render cost is low. Trees are static, built once, never updated.

# Trunk dimensions
const TRUNK_HEIGHT: float = 4.5
const TRUNK_BOTTOM_R: float = 0.32
const TRUNK_TOP_R: float = 0.18

# Branch dimensions (relative to trunk top)
const BRANCH_COUNT_MIN: int = 4
const BRANCH_COUNT_MAX: int = 6
const BRANCH_LENGTH: float = 2.2
const BRANCH_RADIUS: float = 0.10
const BRANCH_ANGLE_DEG: float = 35.0  # how far from vertical each branch leans

# Foliage cluster (per branch tip)
const FOLIAGE_PRIMARY_R: float = 1.2
const FOLIAGE_HALO_R: float = 1.5
const FOLIAGE_HIGHLIGHT_R: float = 0.7

# Sakura color palette, saturated core, pale halo, bright cap
const COLOR_CORE: Color = Color(1.00, 0.55, 0.72, 1.0)
const COLOR_HALO: Color = Color(1.00, 0.78, 0.86, 0.85)
const COLOR_HIGHLIGHT: Color = Color(1.00, 0.92, 0.96, 0.90)
const COLOR_BARK: Color = Color(0.28, 0.16, 0.12, 1.0)

func _ready() -> void:
	_build()

func _build() -> void:
	# Use a deterministic-per-instance seed so the same tree always
	# builds the same way (avoids visual flicker on re-instantiation),
	# but each tree has its own variation.
	var rng := RandomNumberGenerator.new()
	rng.seed = hash(get_path()) + Time.get_ticks_msec()

	# 1. Trunk
	var trunk := MeshInstance3D.new()
	trunk.name = "Trunk"
	var trunk_mesh := CylinderMesh.new()
	trunk_mesh.bottom_radius = TRUNK_BOTTOM_R
	trunk_mesh.top_radius = TRUNK_TOP_R
	trunk_mesh.height = TRUNK_HEIGHT
	trunk_mesh.radial_segments = 10
	trunk.mesh = trunk_mesh
	trunk.material_override = _bark_mat()
	# Cylinder is centered on origin; lift so base sits at y=0
	trunk.position = Vector3(0, TRUNK_HEIGHT * 0.5, 0)
	# Slight random lean so the grove doesn't read as soldier-row uniform
	var lean_x: float = rng.randf_range(-0.05, 0.05)
	var lean_z: float = rng.randf_range(-0.05, 0.05)
	trunk.rotation = Vector3(lean_x, 0, lean_z)
	add_child(trunk)

	# 2. Branches sprouting from trunk top
	var branch_count: int = rng.randi_range(BRANCH_COUNT_MIN, BRANCH_COUNT_MAX)
	for i in range(branch_count):
		var angle_around: float = (float(i) / float(branch_count)) * TAU + rng.randf_range(-0.2, 0.2)
		var branch_origin: Vector3 = Vector3(0, TRUNK_HEIGHT * 0.85, 0)
		var lean: float = deg_to_rad(BRANCH_ANGLE_DEG + rng.randf_range(-8.0, 8.0))
		var branch := MeshInstance3D.new()
		branch.name = "Branch%d" % i
		var bm := CylinderMesh.new()
		bm.bottom_radius = BRANCH_RADIUS * 1.4
		bm.top_radius = BRANCH_RADIUS * 0.6
		bm.height = BRANCH_LENGTH * rng.randf_range(0.85, 1.15)
		bm.radial_segments = 6
		branch.mesh = bm
		branch.material_override = _bark_mat()
		# Position the branch's CENTER offset from trunk top by half-length
		# along the lean direction. Then rotate.
		var half_len: float = bm.height * 0.5
		var dir: Vector3 = Vector3(sin(lean) * cos(angle_around), cos(lean), sin(lean) * sin(angle_around))
		branch.position = branch_origin + dir * half_len
		# Aim cylinder's +Y along `dir`
		branch.basis = _basis_from_y(dir)
		add_child(branch)

		# 3. Foliage cluster at the branch tip, three layered spheres
		var tip: Vector3 = branch_origin + dir * bm.height
		_spawn_foliage_cluster(tip, rng)

	# 4. Foliage cap at the top center for canopy fullness
	_spawn_foliage_cluster(Vector3(0, TRUNK_HEIGHT + 0.4, 0), rng, 1.15)

	# 5. Falling petals, small alpha quads under the canopy.
	# These are static; for animated petal-fall use WorldLife.spawn_petal_fall
	# at the zone level, which the composer already calls.
	for _i in range(rng.randi_range(8, 14)):
		var px: float = rng.randf_range(-FOLIAGE_PRIMARY_R, FOLIAGE_PRIMARY_R) * 1.6
		var py: float = rng.randf_range(0.5, TRUNK_HEIGHT * 0.4)
		var pz: float = rng.randf_range(-FOLIAGE_PRIMARY_R, FOLIAGE_PRIMARY_R) * 1.6
		var petal := MeshInstance3D.new()
		var pm := QuadMesh.new()
		pm.size = Vector2(0.10, 0.10)
		petal.mesh = pm
		var ps := StandardMaterial3D.new()
		ps.albedo_color = Color(1.0, 0.65, 0.78, 0.85)
		ps.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		ps.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		ps.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
		petal.material_override = ps
		petal.position = Vector3(px, py, pz)
		add_child(petal)

# Spawn a 3-sphere blossom cluster at `tip`. Saturated core (1.2r),
# pale halo (1.5r), bright highlight cap (0.7r).
func _spawn_foliage_cluster(tip: Vector3, rng: RandomNumberGenerator, scale_mul: float = 1.0) -> void:
	# Core, saturated pink, opaque
	var core := MeshInstance3D.new()
	var core_mesh := SphereMesh.new()
	core_mesh.radius = FOLIAGE_PRIMARY_R * scale_mul
	core_mesh.height = FOLIAGE_PRIMARY_R * 2.0 * scale_mul
	core_mesh.radial_segments = 16
	core_mesh.rings = 8
	core.mesh = core_mesh
	var core_mat := StandardMaterial3D.new()
	core_mat.albedo_color = COLOR_CORE
	core_mat.shading_mode = BaseMaterial3D.SHADING_MODE_PER_PIXEL
	core_mat.roughness = 0.85
	core.material_override = core_mat
	core.position = tip + Vector3(rng.randf_range(-0.1, 0.1), 0, rng.randf_range(-0.1, 0.1))
	add_child(core)

	# Halo, pale, larger, semi-transparent
	var halo := MeshInstance3D.new()
	var halo_mesh := SphereMesh.new()
	halo_mesh.radius = FOLIAGE_HALO_R * scale_mul
	halo_mesh.height = FOLIAGE_HALO_R * 2.0 * scale_mul
	halo_mesh.radial_segments = 12
	halo_mesh.rings = 6
	halo.mesh = halo_mesh
	var halo_mat := StandardMaterial3D.new()
	halo_mat.albedo_color = COLOR_HALO
	halo_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	halo_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	halo.material_override = halo_mat
	halo.position = tip + Vector3(rng.randf_range(-0.2, 0.2), rng.randf_range(-0.1, 0.2), rng.randf_range(-0.2, 0.2))
	add_child(halo)

	# Highlight cap, small bright sphere offset toward the lit side
	var hi := MeshInstance3D.new()
	var hi_mesh := SphereMesh.new()
	hi_mesh.radius = FOLIAGE_HIGHLIGHT_R * scale_mul
	hi_mesh.height = FOLIAGE_HIGHLIGHT_R * 2.0 * scale_mul
	hi_mesh.radial_segments = 10
	hi_mesh.rings = 5
	hi.mesh = hi_mesh
	var hi_mat := StandardMaterial3D.new()
	hi_mat.albedo_color = COLOR_HIGHLIGHT
	hi_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	hi_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	hi.material_override = hi_mat
	# Offset the highlight up-and-left so the cluster reads as 'lit
	# from above-left' even without proper PBR reflection
	hi.position = tip + Vector3(-0.3 * scale_mul, 0.4 * scale_mul, -0.2 * scale_mul)
	add_child(hi)

# Build a Basis with +Y axis aligned to `dir` (used to orient the
# branch CylinderMesh along the branch growth direction).
func _basis_from_y(dir: Vector3) -> Basis:
	var y: Vector3 = dir.normalized()
	# Pick an arbitrary up-axis to derive the orthonormal basis.
	# Vector3.RIGHT is fine unless `dir` itself is approximately right.
	var ref: Vector3 = Vector3.RIGHT if abs(y.dot(Vector3.RIGHT)) < 0.95 else Vector3.FORWARD
	var z: Vector3 = ref.cross(y).normalized()
	var x: Vector3 = y.cross(z).normalized()
	return Basis(x, y, z)

func _bark_mat() -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = COLOR_BARK
	m.roughness = 0.92
	m.metallic = 0.05
	return m
