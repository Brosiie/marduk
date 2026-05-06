@tool
extends MeshInstance3D
class_name TerrainGenerator

# Procedural rolling-hills terrain. Builds a heightmap mesh from
# FastNoiseLite at _ready (or when properties change in the editor),
# applies a slope-blended StandardMaterial3D, and adds a matching
# StaticBody3D + ConcavePolygonShape3D collider so the player can walk
# on it.
#
# Drop-in replacement for the flat ground plane in every region scene.
# Configure via the @export properties; defaults look like a typical
# stylized fantasy clearing (gentle hills, ~2m amplitude, grass tint).

@export var size: float = 80.0:
	set(v):
		size = v
		_dirty = true
@export var resolution: int = 80:
	set(v):
		resolution = max(8, v)
		_dirty = true
@export var height_scale: float = 2.5:
	set(v):
		height_scale = v
		_dirty = true
@export var noise_frequency: float = 0.04:
	set(v):
		noise_frequency = v
		_dirty = true
@export var noise_seed: int = 1337:
	set(v):
		noise_seed = v
		_dirty = true
# Tint for the grass / dirt / rock blend. Override per region.
@export var grass_color: Color = Color(0.40, 0.60, 0.30):
	set(v):
		grass_color = v
		_dirty = true
@export var dirt_color: Color = Color(0.55, 0.40, 0.25):
	set(v):
		dirt_color = v
		_dirty = true
@export var rock_color: Color = Color(0.45, 0.40, 0.40):
	set(v):
		rock_color = v
		_dirty = true
# If true, generate a flat region around origin so spawn area is playable.
@export var flatten_center_radius: float = 8.0
@export var auto_collider: bool = true
@export var build_on_ready: bool = true

var _dirty: bool = true

func _ready() -> void:
	if build_on_ready:
		rebuild()

func rebuild() -> void:
	_dirty = false
	var noise := FastNoiseLite.new()
	noise.seed = noise_seed
	noise.frequency = noise_frequency
	noise.noise_type = FastNoiseLite.TYPE_PERLIN
	# Build a grid of vertices; sample noise for Y; produce ArrayMesh.
	var step: float = size / float(resolution)
	var half: float = size * 0.5
	var verts := PackedVector3Array()
	var normals := PackedVector3Array()
	var colors := PackedColorArray()
	var uvs := PackedVector2Array()
	var indices := PackedInt32Array()
	for iz in range(resolution + 1):
		for ix in range(resolution + 1):
			var x: float = ix * step - half
			var z: float = iz * step - half
			var d: float = sqrt(x * x + z * z)
			# Flatten the center playable area so spawns aren't on a slope
			var flatten: float = clamp((d - flatten_center_radius) / 4.0, 0.0, 1.0)
			var y: float = noise.get_noise_2d(x, z) * height_scale * flatten
			verts.append(Vector3(x, y, z))
			uvs.append(Vector2(float(ix) / resolution, float(iz) / resolution))
			# Color blend by height (low = grass, mid = dirt, high = rock)
			var h_norm: float = clamp((y + height_scale) / (height_scale * 2.0), 0.0, 1.0)
			var col: Color
			if h_norm < 0.5:
				col = grass_color.lerp(dirt_color, h_norm * 2.0)
			else:
				col = dirt_color.lerp(rock_color, (h_norm - 0.5) * 2.0)
			colors.append(col)
			normals.append(Vector3.UP)  # placeholder; smoothed below
	# Triangle indices, two per quad
	for iz in range(resolution):
		for ix in range(resolution):
			var i0: int = iz * (resolution + 1) + ix
			var i1: int = i0 + 1
			var i2: int = i0 + (resolution + 1)
			var i3: int = i2 + 1
			indices.append(i0); indices.append(i2); indices.append(i1)
			indices.append(i1); indices.append(i2); indices.append(i3)
	# Smooth normals from triangle averages
	normals = _compute_smooth_normals(verts, indices)
	var arr := []
	arr.resize(Mesh.ARRAY_MAX)
	arr[Mesh.ARRAY_VERTEX] = verts
	arr[Mesh.ARRAY_NORMAL] = normals
	arr[Mesh.ARRAY_COLOR] = colors
	arr[Mesh.ARRAY_TEX_UV] = uvs
	arr[Mesh.ARRAY_INDEX] = indices
	var array_mesh := ArrayMesh.new()
	array_mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arr)
	mesh = array_mesh
	# Material — vertex-colored with rough non-shiny look
	var mat := StandardMaterial3D.new()
	mat.vertex_color_use_as_albedo = true
	mat.roughness = 0.95
	mat.metallic = 0.0
	mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	material_override = mat
	# Collider so the player walks on it
	if auto_collider:
		_attach_collider(verts, indices)

func _compute_smooth_normals(verts: PackedVector3Array, indices: PackedInt32Array) -> PackedVector3Array:
	var normals := PackedVector3Array()
	normals.resize(verts.size())
	for i in range(verts.size()):
		normals[i] = Vector3.ZERO
	for i in range(0, indices.size(), 3):
		var a: int = indices[i]
		var b: int = indices[i + 1]
		var c: int = indices[i + 2]
		var n: Vector3 = (verts[b] - verts[a]).cross(verts[c] - verts[a])
		normals[a] += n
		normals[b] += n
		normals[c] += n
	for i in range(normals.size()):
		normals[i] = normals[i].normalized()
	return normals

func _attach_collider(verts: PackedVector3Array, indices: PackedInt32Array) -> void:
	# Replace any existing collider child
	for child in get_children():
		if child is StaticBody3D:
			child.queue_free()
	var body := StaticBody3D.new()
	body.collision_layer = 1
	body.collision_mask = 0
	add_child(body)
	var shape := ConcavePolygonShape3D.new()
	# ConcavePolygonShape3D wants a flat array of triangle vertices (3 per face).
	var faces := PackedVector3Array()
	for i in range(0, indices.size(), 3):
		faces.append(verts[indices[i]])
		faces.append(verts[indices[i + 1]])
		faces.append(verts[indices[i + 2]])
	shape.set_faces(faces)
	var cs := CollisionShape3D.new()
	cs.shape = shape
	body.add_child(cs)

# Sample the terrain height at world position (used by spawners /
# camera so they can snap to the ground above the surface).
func sample_height(world_x: float, world_z: float) -> float:
	# Local sample - assumes this node is at world origin.
	var noise := FastNoiseLite.new()
	noise.seed = noise_seed
	noise.frequency = noise_frequency
	noise.noise_type = FastNoiseLite.TYPE_PERLIN
	var d: float = sqrt(world_x * world_x + world_z * world_z)
	var flatten: float = clamp((d - flatten_center_radius) / 4.0, 0.0, 1.0)
	return noise.get_noise_2d(world_x, world_z) * height_scale * flatten
