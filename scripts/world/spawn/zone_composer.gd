extends Node3D
class_name ZoneComposer

# Procedurally builds a zone's geometry from KayKit dungeon kit pieces. Place
# one of these as a Node3D in any zone scene and configure the `style` enum to
# get a region-flavored landscape.
#
# Design: hand-authoring 100+ static prop nodes per zone is tedious. This script
# composes the same look from a small set of preset templates. Each template is
# ~50-80 instanced .glb props arranged into a recognizable scene.

enum Style {
	SWORD_VOW_RUINS,    # Burned stone fortress courtyard with throne at north
	ASH_STEP_CAMP,      # Open dirt steppe with raider tents and a spear-rack
	WHISPER_SHRINE,     # Underground temple corridor with columns and braziers
	GREENHEART_GLADE,   # Forest clearing with logs, mossy stones, broken cart
	INKSTONE_TOWER,     # Tower interior, stairs going up, books and runes
	COVEN_GLEN,         # Standing-stone circle with offering altar
	SUNSWORN_CHAPEL,    # Chapel courtyard with altar and pews
	PYRE_ASCENT,        # Spiral basalt stair with embers and braziers
}

const KIT := "res://assets/environments/kaykit_dungeon/Assets/gltf/"

@export var style: Style = Style.SWORD_VOW_RUINS
@export var size: float = 40.0    # half-extent of the playable area
@export var auto_build_on_ready: bool = true

func _ready() -> void:
	if auto_build_on_ready:
		call_deferred("build")

func build() -> void:
	match style:
		Style.SWORD_VOW_RUINS: _build_sword_vow_ruins()
		Style.ASH_STEP_CAMP: _build_ash_step_camp()
		Style.WHISPER_SHRINE: _build_whisper_shrine()
		Style.GREENHEART_GLADE: _build_greenheart_glade()
		Style.INKSTONE_TOWER: _build_inkstone_tower()
		Style.COVEN_GLEN: _build_coven_glen()
		Style.SUNSWORN_CHAPEL: _build_sunsworn_chapel()
		Style.PYRE_ASCENT: _build_pyre_ascent()

# ----------------------------------------------------------------
# Helpers
# ----------------------------------------------------------------
func _spawn(asset: String, pos: Vector3, rot_y_deg: float = 0.0, scale: float = 1.0) -> Node3D:
	var path: String = KIT + asset
	if not ResourceLoader.exists(path):
		return null
	var packed: PackedScene = load(path)
	if not packed:
		return null
	var inst: Node3D = packed.instantiate()
	add_child(inst)
	inst.position = pos
	inst.rotation.y = deg_to_rad(rot_y_deg)
	inst.scale = Vector3.ONE * scale
	return inst

func _torch(pos: Vector3, lit: bool = true) -> void:
	var asset: String = "torch_lit.gltf.glb" if lit else "torch.gltf.glb"
	var t: Node3D = _spawn(asset, pos)
	if t and lit:
		var light := OmniLight3D.new()
		light.light_color = Color(1.0, 0.55, 0.20)
		light.light_energy = 1.5
		light.omni_range = 8.0
		t.add_child(light)
		light.position = Vector3(0, 1.5, 0)

# ----------------------------------------------------------------
# SWORD-VOW RUINS — burned-out stone fortress, throne at north
# ----------------------------------------------------------------
func _build_sword_vow_ruins() -> void:
	# Floor tiles in a grid
	var tile_size := 4.0
	var grid := int(size / tile_size)
	for x in range(-grid, grid + 1):
		for z in range(-grid, grid + 1):
			var asset := "floor_dirt_large_rocky.gltf.glb" if (x + z) % 3 == 0 else "floor_dirt_large.gltf.glb"
			_spawn(asset, Vector3(x * tile_size, 0, z * tile_size))

	# Side walls - arched stone forming a corridor
	for z in range(-int(size / 2), int(size / 2), 4):
		_spawn("wall_arched.gltf.glb", Vector3(-size / 2, 0, z), 0.0)
		_spawn("wall_arched.gltf.glb", Vector3(size / 2, 0, z), 180.0)

	# Decorated pillars at the four corners
	_spawn("pillar_decorated.gltf.glb", Vector3(-size / 2 + 2, 0, -size / 2 + 2))
	_spawn("pillar_decorated.gltf.glb", Vector3(size / 2 - 2, 0, -size / 2 + 2))
	_spawn("pillar_decorated.gltf.glb", Vector3(-size / 2 + 2, 0, size / 2 - 2))
	_spawn("pillar_decorated.gltf.glb", Vector3(size / 2 - 2, 0, size / 2 - 2))

	# Smaller pillars lining the central path
	for z_step in [-12, -4, 4, 12]:
		_spawn("pillar.gltf.glb", Vector3(-6, 0, z_step))
		_spawn("pillar.gltf.glb", Vector3(6, 0, z_step))

	# Torches along the walls - lit, casting warm pools of light
	for z_step in [-16, -8, 0, 8, 16]:
		_torch(Vector3(-size / 2 + 1.5, 0, z_step), true)
		_torch(Vector3(size / 2 - 1.5, 0, z_step), true)

	# Throne dais at the north end (boss spawn area)
	_spawn("floor_dirt_large_rocky.gltf.glb", Vector3(0, 0.4, -size / 2 + 4))
	_spawn("floor_dirt_large_rocky.gltf.glb", Vector3(-4, 0.4, -size / 2 + 4))
	_spawn("floor_dirt_large_rocky.gltf.glb", Vector3(4, 0.4, -size / 2 + 4))

	# Two flanking columns on the throne dais
	_spawn("column.gltf.glb", Vector3(-3, 0.4, -size / 2 + 5))
	_spawn("column.gltf.glb", Vector3(3, 0.4, -size / 2 + 5))

# ----------------------------------------------------------------
# ASH-STEP CAMP — open steppe, raider tents, spear-rack, fire pit
# ----------------------------------------------------------------
func _build_ash_step_camp() -> void:
	var tile_size := 4.0
	var grid := int(size / tile_size)
	for x in range(-grid, grid + 1):
		for z in range(-grid, grid + 1):
			_spawn("floor_dirt_large.gltf.glb", Vector3(x * tile_size, 0, z * tile_size))

	# Scattered barrier columns to suggest abandoned camp boundaries
	for offset in [-12, -6, 0, 6, 12]:
		_spawn("barrier_column.gltf.glb", Vector3(offset, 0, -size / 2 + 2), randf() * 360.0)
		_spawn("barrier_column.gltf.glb", Vector3(offset, 0, size / 2 - 2), randf() * 360.0)

	# Central fire pit - a torch with a glow
	_torch(Vector3(0, 0, 0), true)

# ----------------------------------------------------------------
# WHISPER SHRINE — underground corridor, columns, dim
# ----------------------------------------------------------------
func _build_whisper_shrine() -> void:
	var tile_size := 4.0
	for x in range(-3, 4):
		for z in range(-int(size / tile_size), int(size / tile_size) + 1):
			_spawn("floor_dirt_small_A.gltf.glb" if (x + z) % 2 == 0 else "floor_dirt_small_B.gltf.glb",
				Vector3(x * tile_size, 0, z * tile_size))

	# Walls forming a long corridor
	for z in range(-int(size / 2), int(size / 2), 4):
		_spawn("wall_arched.gltf.glb", Vector3(-12, 0, z), 0.0)
		_spawn("wall_arched.gltf.glb", Vector3(12, 0, z), 180.0)

	# Columns down the middle
	for z_step in range(-int(size / 2) + 4, int(size / 2), 8):
		_spawn("pillar.gltf.glb", Vector3(0, 0, z_step))

	# Torches dim
	for z_step in range(-int(size / 2) + 4, int(size / 2), 12):
		_torch(Vector3(-10, 0, z_step), true)
		_torch(Vector3(10, 0, z_step), true)

# ----------------------------------------------------------------
# GREENHEART GLADE — forest clearing, mossy ground, broken cart
# ----------------------------------------------------------------
func _build_greenheart_glade() -> void:
	# Use small dirt tiles scattered with rocky patches for organic feel
	var tile_size := 4.0
	var grid := int(size / tile_size)
	for x in range(-grid, grid + 1):
		for z in range(-grid, grid + 1):
			var asset := "floor_dirt_small_A.gltf.glb"
			if randf() < 0.3:
				asset = "floor_dirt_large_rocky.gltf.glb"
			_spawn(asset, Vector3(x * tile_size, 0, z * tile_size), randf() * 360.0)

	# Scattered tree-stump-ish columns (using barrier_column as moss-covered logs)
	for _i in range(12):
		var x: float = randf_range(-size / 2, size / 2)
		var z: float = randf_range(-size / 2, size / 2)
		if abs(x) < 6 and abs(z) < 6:
			continue  # keep central area clear
		_spawn("barrier_column.gltf.glb", Vector3(x, 0, z), randf() * 360.0)

# ----------------------------------------------------------------
# INKSTONE TOWER — interior of magical tower, columns, dim
# ----------------------------------------------------------------
func _build_inkstone_tower() -> void:
	# Circular floor pattern
	var tile_size := 4.0
	for x in range(-3, 4):
		for z in range(-3, 4):
			if x * x + z * z > 9:
				continue
			_spawn("floor_dirt_small_A.gltf.glb", Vector3(x * tile_size, 0, z * tile_size))
	# Eight pillars in a circle
	for i in range(8):
		var angle: float = i * TAU / 8.0
		var radius := 10.0
		_spawn("pillar_decorated.gltf.glb",
			Vector3(cos(angle) * radius, 0, sin(angle) * radius),
			rad_to_deg(angle))
	# Center of room - the seal / well
	_spawn("column.gltf.glb", Vector3(0, 0, 0))
	# Torches between pillars
	for i in range(8):
		var angle: float = (i + 0.5) * TAU / 8.0
		var radius := 12.0
		_torch(Vector3(cos(angle) * radius, 0, sin(angle) * radius), true)

# ----------------------------------------------------------------
# COVEN GLEN — marshy circle of standing stones
# ----------------------------------------------------------------
func _build_coven_glen() -> void:
	var tile_size := 4.0
	var grid := int(size / tile_size)
	for x in range(-grid, grid + 1):
		for z in range(-grid, grid + 1):
			_spawn("floor_dirt_small_B.gltf.glb",
				Vector3(x * tile_size, 0, z * tile_size), randf() * 90.0)
	# Standing-stone circle
	for i in range(7):
		var angle: float = i * TAU / 7.0
		var radius := 8.0
		_spawn("pillar.gltf.glb",
			Vector3(cos(angle) * radius, 0, sin(angle) * radius),
			rad_to_deg(angle) + 90.0)
	# Central altar stone
	_spawn("column.gltf.glb", Vector3(0, 0, 0))
	# Dim torches at the cardinal points (only 4)
	for i in range(4):
		var angle: float = i * TAU / 4.0
		_torch(Vector3(cos(angle) * 14.0, 0, sin(angle) * 14.0), true)

# ----------------------------------------------------------------
# SUNSWORN CHAPEL — interior chapel courtyard
# ----------------------------------------------------------------
func _build_sunsworn_chapel() -> void:
	var tile_size := 4.0
	var grid := 5
	for x in range(-grid, grid + 1):
		for z in range(-grid, grid + 1):
			_spawn("floor_dirt_small_A.gltf.glb", Vector3(x * tile_size, 0, z * tile_size))
	# Two long colonnades
	for z_step in range(-16, 17, 4):
		_spawn("pillar_decorated.gltf.glb", Vector3(-12, 0, z_step))
		_spawn("pillar_decorated.gltf.glb", Vector3(12, 0, z_step))
	# Altar at the north end
	_spawn("column.gltf.glb", Vector3(0, 0, -16))
	_spawn("torch_lit.gltf.glb", Vector3(-2, 0, -18))
	_spawn("torch_lit.gltf.glb", Vector3(2, 0, -18))
	# Pews indicated by pillars
	for z_step in [-8, 0, 8]:
		_spawn("barrier_column.gltf.glb", Vector3(-6, 0, z_step), 0.0)
		_spawn("barrier_column.gltf.glb", Vector3(6, 0, z_step), 180.0)
	# Many lit torches for "holy" atmosphere
	for z_step in range(-16, 17, 8):
		_torch(Vector3(-13, 0, z_step), true)
		_torch(Vector3(13, 0, z_step), true)

# ----------------------------------------------------------------
# PYRE ASCENT — Demon intro, basalt spiral stair
# ----------------------------------------------------------------
func _build_pyre_ascent() -> void:
	# Spiral stair simulated as ascending tile rows
	for step in range(20):
		var angle: float = step * 0.3
		var height := step * 0.4
		var radius := 6.0
		_spawn("floor_dirt_large_rocky.gltf.glb",
			Vector3(cos(angle) * radius, height, sin(angle) * radius),
			rad_to_deg(angle))
	# Braziers at each turn
	for step in range(0, 20, 4):
		var angle: float = step * 0.3
		var height := step * 0.4
		var radius := 8.0
		_torch(Vector3(cos(angle) * radius, height, sin(angle) * radius), true)
