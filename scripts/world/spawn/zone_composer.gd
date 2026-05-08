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
	# --- Class intro zones (8) ---
	SWORD_VOW_RUINS,    # Burned stone fortress courtyard with throne at north (Ronin)
	ASH_STEP_CAMP,      # Open dirt steppe with raider tents and a spear-rack (Berserker)
	WHISPER_SHRINE,     # Underground temple corridor with columns and braziers (Assassin)
	GREENHEART_GLADE,   # Forest clearing with logs, mossy stones, broken cart (Ranger)
	INKSTONE_TOWER,     # Tower interior, stairs going up, books and runes (Mage)
	COVEN_GLEN,         # Standing-stone circle with offering altar (Chaos Druid)
	SUNSWORN_CHAPEL,    # Chapel courtyard with altar and pews (Paladin)
	PYRE_ASCENT,        # Spiral basalt stair with embers and braziers (Demon)
	# --- World regions (13) ---
	THE_CRADLE,             # Sumerian temple grounds, stepped ziggurat dais
	THE_REED_WASTES,        # Marshy reeds and broken huts, wood plank pathways
	LAPIS_BAY,              # Coastal docks, stacked crates, weathered piers
	BONE_MOUNTAINS,         # Rocky pass with scattered bones and rubble
	VERDANT_WOUND,          # Corrupted forest, tilted columns, weeds growing in stone
	EMBER_STEPPES,          # Windswept plain, scattered fire pits and bones
	MIST_VALE,              # Foggy druid grove, stones in mist, mossy logs
	SHRIEKING_HIGHLANDS,    # Windy cliffs, rune stones, abandoned shrine
	SUNDERED_COAST,         # Broken cliffs, fallen pillars, shipwreck pieces
	BLACK_CITADEL,          # Dark fortress interior, throne, banners
	FIRE_STAIR,             # Basalt spiral stair to the demon throne (alias of PYRE_ASCENT extended)
	ASHURIM,                # Convergence town: market stalls, banners, tables, NPCs
	BABILIM,                # Capital city, grand chapel layout, banners
}

const KIT := "res://assets/environments/kaykit_dungeon/Assets/gltf/"
const NATURE := "res://assets/environments/kenney_nature/"
const CASTLE := "res://assets/environments/kenney_castle/"

# Spawn from the castle kit (walls, towers, gates, bridges, siege).
# Castle assets are larger than nature (~2-4m tall walls, ~6-12m towers)
# so default scale is 1.0; pass a multiplier if needed.
func _cas(asset: String, pos: Vector3, rot_y_deg: float = 0.0, scale: float = 1.0) -> Node3D:
	var path: String = CASTLE + asset
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
	# Castle pieces (walls/towers/gates/bridges) are virtually never decor,
	# but flag and flag-banner pieces are matched as decor by name.
	if _is_decor(asset):
		_strip_colliders(inst)
	else:
		_ensure_collision(inst)
	return inst

# Spawn from the nature kit (trees, grass, flowers, cliffs).
func _nat(asset: String, pos: Vector3, rot_y_deg: float = 0.0, scale: float = 1.0) -> Node3D:
	var path: String = NATURE + asset
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
	# Grass / flowers / mushrooms / bushes / banners / small bamboo all
	# match as decor — player walks through. Trees, stumps, cliffs,
	# bridges, tall bamboo grove, campfires all get collision.
	if _is_decor(asset):
		_strip_colliders(inst)
	else:
		_ensure_collision(inst)
	return inst

# Cherry blossom helper: spawn a Kenney tree, then tint every surface's
# albedo toward soft pink. Uses surface_material_override so the original
# .glb textures are untouched (no perma-modifications). Used by the
# Japanese-themed Sword-Vow Ruins to make a forest of regular Kenney
# trees read as a sakura grove.
func _sakura(asset: String, pos: Vector3, rot_y_deg: float = 0.0, scale: float = 1.0) -> Node3D:
	var inst := _nat(asset, pos, rot_y_deg, scale)
	if inst == null:
		return null
	# Light pink + wind sway. anchor=0.4 keeps the trunk planted while
	# the canopy moves. amplitude=0.18 gives readable canopy bob without
	# tearing the tree apart visually.
	_apply_wind_tint(inst, Color(1.00, 0.78, 0.85, 1.0), 0.18, 0.4)
	return inst

# Walk MeshInstance3Ds under `node` and slap a pink-tinted StandardMaterial3D
# on every surface. We don't try to be clever about foliage-vs-trunk; the
# whole tree reads as cherry-pink which is the sakura silhouette.
func _tint_tree(node: Node, tint: Color) -> void:
	if node is MeshInstance3D:
		var mi := node as MeshInstance3D
		if mi.mesh:
			for i in range(mi.mesh.get_surface_count()):
				var mat := StandardMaterial3D.new()
				mat.albedo_color = tint
				mat.roughness = 0.85
				mi.set_surface_override_material(i, mat)
	for c in node.get_children():
		_tint_tree(c, tint)

# Wind shader: stylized vertex displacement. Reusing one Shader resource
# across all instances so the GPU compiles it once. Loaded lazily so
# zones that don't use wind don't pay the cost.
var _wind_shader: Shader = null

func _get_wind_shader() -> Shader:
	if _wind_shader == null:
		_wind_shader = load("res://shaders/wind.gdshader")
	return _wind_shader

# Replace every MeshInstance3D surface under `node` with a wind
# ShaderMaterial tinted to `color`. Bigger `amplitude` = more sway;
# `anchor` (model-Y) is the height below which vertices stay planted.
#
# Recommended params:
#   sakura tree foliage: color=pink   amplitude=0.18 anchor=0.4
#   banner / flag:       color=red    amplitude=0.40 anchor=0.0
#   tall grass / bush:   color=green  amplitude=0.06 anchor=0.0
func _apply_wind_tint(node: Node, color: Color, amplitude: float = 0.15, anchor: float = 0.0) -> void:
	var shader: Shader = _get_wind_shader()
	if shader == null:
		# Fall back to plain tint if shader is missing — never crash a zone
		_tint_tree(node, color)
		return
	_apply_wind_recursive(node, shader, color, amplitude, anchor)

func _apply_wind_recursive(node: Node, shader: Shader, color: Color, amplitude: float, anchor: float) -> void:
	if node is MeshInstance3D:
		var mi := node as MeshInstance3D
		if mi.mesh:
			for i in range(mi.mesh.get_surface_count()):
				var sm := ShaderMaterial.new()
				sm.shader = shader
				sm.set_shader_parameter("albedo", color)
				sm.set_shader_parameter("use_texture", false)
				sm.set_shader_parameter("amplitude", amplitude)
				sm.set_shader_parameter("anchor", anchor)
				sm.set_shader_parameter("wind_strength", 1.0)
				sm.set_shader_parameter("wind_dir", Vector3(1.0, 0.0, 0.3))
				mi.set_surface_override_material(i, sm)
	for c in node.get_children():
		_apply_wind_recursive(c, shader, color, amplitude, anchor)

# Banner with wind: spawns a Kenney castle banner/flag/pennant via _cas
# then applies the wind shader so the cloth waves. Pass the asset name
# (flag.glb / flag-banner-long.glb / flag-pennant.glb), color, and
# amplitude. anchor=0.0 because banners sway from the top down.
func _banner(asset: String, pos: Vector3, color: Color = Color(0.92, 0.92, 0.92, 1), rot_y_deg: float = 0.0, amplitude: float = 0.40) -> Node3D:
	var inst := _cas(asset, pos, rot_y_deg)
	if inst == null:
		return null
	_apply_wind_tint(inst, color, amplitude, 0.0)
	return inst

# Koi pond: a flat water plane with the water_pond.gdshader. Renders
# rippling sin-noise waves + fresnel gold rim + cool depth gradient.
# Adds a ReflectionProbe so the bridge + lanterns above actually
# mirror in the water.
func _spawn_koi_pond(center: Vector3, size_xz: Vector2) -> Node3D:
	var pond := MeshInstance3D.new()
	pond.name = "KoiPond"
	var plane := PlaneMesh.new()
	plane.size = size_xz
	plane.subdivide_width = 24
	plane.subdivide_depth = 8
	pond.mesh = plane
	var mat := ShaderMaterial.new()
	mat.shader = load("res://shaders/water_pond.gdshader")
	mat.set_shader_parameter("shallow_color", Color(0.55, 0.78, 0.82, 0.88))
	mat.set_shader_parameter("deep_color", Color(0.10, 0.20, 0.32, 1.0))
	mat.set_shader_parameter("fresnel_color", Color(1.0, 0.85, 0.55, 1.0))
	pond.material_override = mat
	add_child(pond)
	pond.global_position = global_position + center
	# Reflection probe so the bridge + lanterns mirror in the surface
	var probe := ReflectionProbe.new()
	probe.name = "PondReflection"
	probe.size = Vector3(size_xz.x + 4, 8, size_xz.y + 4)
	probe.update_mode = ReflectionProbe.UPDATE_ONCE  # bake at scene load
	probe.intensity = 0.65
	probe.box_projection = true
	probe.cull_mask = 0xFFFFFFFF
	add_child(probe)
	probe.global_position = global_position + center + Vector3(0, 1, 0)
	return pond

# Stone lantern (toro) — built from a tall narrow column piece + a tinted
# torch on top so it reads as a paper lantern atop a stone pedestal. No
# dedicated Kenney piece; this composition is the closest read.
func _lantern(pos: Vector3, lit: bool = true) -> Node3D:
	var pedestal := _spawn("column.gltf.glb", pos, 0.0, 0.6)
	# Torch with tinted warm light on top. We can't easily nest the torch
	# inside the pedestal scale, so spawn it as a separate entity offset up.
	_torch(pos + Vector3(0, 1.2, 0), lit)
	return pedestal

# Torii gate — two tall posts + horizontal beam at top. Built from
# Kenney column pieces stacked vertically. Width is the player-passable
# opening between the posts.
func _torii(center: Vector3, width: float = 4.0) -> void:
	# Two posts (use 2x stacked decorated columns for height)
	for side in [-1, 1]:
		var post_x: float = float(side) * (width * 0.5)
		_spawn("column.gltf.glb", center + Vector3(post_x, 0, 0))
		_spawn("column.gltf.glb", center + Vector3(post_x, 1.4, 0))
		_spawn("pillar_decorated.gltf.glb", center + Vector3(post_x, 2.8, 0), 0.0)
	# Horizontal beam: 3 wide stones spanning the gap, tinted darker red.
	# We use floor_tile_large rotated 90° as the beam since Kenney has no
	# proper torii beam piece. Slap a red tint on it via _tint_tree.
	for i in range(-1, 2):
		var beam := _spawn("floor_tile_large.gltf.glb", center + Vector3(float(i) * 1.5, 4.0, 0), 0.0, 0.5)
		if beam:
			# Vermilion red — torii signature color
			_tint_tree(beam, Color(0.78, 0.18, 0.15, 1.0))

# Walk the prop subtree and disable every CollisionShape3D / StaticBody3D.
# Used only for asset names matching DECOR_PATTERNS (small ground decor
# like grass, flowers, banners, broken-sword props). For everything else
# we instead generate trimesh collision so walls/towers/dojo/lanterns
# all block the player.
func _strip_colliders(node: Node) -> void:
	for child in node.get_children():
		if child is CollisionShape3D:
			child.disabled = true
		elif child is StaticBody3D:
			# Keep the body but neutralize its collision layers so it
			# doesn't intersect the player's mask.
			(child as StaticBody3D).collision_layer = 0
			(child as StaticBody3D).collision_mask = 0
		_strip_colliders(child)

# Asset-name patterns that should be PASS-THROUGH (no collision). Anything
# whose filename contains one of these substrings is treated as decor.
# Everything else gets auto-generated trimesh collision so the player
# can't clip through walls / towers / lanterns / dojo platforms / trees.
#
# Edit this list to fine-tune what's walkable vs walk-through. The
# defaults err toward "solid" because Bond's spec was 'character doesn't
# clip through environments'.
const DECOR_PATTERNS := [
	"grass",        # tufts on the ground
	"flower",       # flower pickups (visual only)
	"mushroom",     # mushroom decor
	"plant_bush",   # all bush variants
	"crops_bamboo", # small bamboo crops; tall perimeter bamboo is also matched but it's fine
	"flag",         # banners, pennants — cloth shouldn't block player
	"rubble_small", # tiny debris
	"sword_shield_broken",  # half-buried sword in path (stepping on it is fine)
]

# Returns true if `asset` is considered decor (walk-through). Case-
# insensitive substring match against DECOR_PATTERNS.
func _is_decor(asset: String) -> bool:
	var lower := asset.to_lower()
	for pat in DECOR_PATTERNS:
		if lower.find(pat) != -1:
			return true
	return false

# Walk the prop subtree, find every MeshInstance3D that doesn't already
# live under a StaticBody3D, and call create_trimesh_collision() on it.
# This inserts a sibling StaticBody3D + CollisionShape3D (concave,
# matching the mesh exactly) so the player physically collides with
# walls, towers, columns, dojo platforms, lanterns, trees, etc.
#
# Idempotent: if a StaticBody3D ancestor already exists, we skip (avoid
# double-adding collision when an asset pack DID ship with colliders).
func _ensure_collision(root: Node) -> void:
	for mi in _find_mesh_instances(root):
		if _has_static_body_ancestor(mi):
			continue
		if mi.mesh == null:
			continue
		# Godot generates the StaticBody3D as a sibling of the
		# MeshInstance3D. We tag the body with a known name so we can
		# re-locate or skip it later if needed.
		mi.create_trimesh_collision()

func _find_mesh_instances(node: Node) -> Array[MeshInstance3D]:
	var out: Array[MeshInstance3D] = []
	if node is MeshInstance3D:
		out.append(node)
	for c in node.get_children():
		out.append_array(_find_mesh_instances(c))
	return out

func _has_static_body_ancestor(node: Node) -> bool:
	var p := node.get_parent()
	while p != null and p != self:
		if p is StaticBody3D:
			return true
		p = p.get_parent()
	return false

# String alias map so region scenes can carry region_id metadata and the
# composer auto-resolves to the right enum at build time.
const STYLE_BY_ID := {
	"sword_vow_ruins": Style.SWORD_VOW_RUINS,
	"ash_step_camp": Style.ASH_STEP_CAMP,
	"whisper_shrine": Style.WHISPER_SHRINE,
	"greenheart_glade": Style.GREENHEART_GLADE,
	"inkstone_tower": Style.INKSTONE_TOWER,
	"coven_glen": Style.COVEN_GLEN,
	"sunsworn_chapel": Style.SUNSWORN_CHAPEL,
	"pyre_ascent": Style.PYRE_ASCENT,
	"the_cradle": Style.THE_CRADLE,
	"the_reed_wastes": Style.THE_REED_WASTES,
	"lapis_bay": Style.LAPIS_BAY,
	"bone_mountains": Style.BONE_MOUNTAINS,
	"verdant_wound": Style.VERDANT_WOUND,
	"ember_steppes": Style.EMBER_STEPPES,
	"mist_vale": Style.MIST_VALE,
	"shrieking_highlands": Style.SHRIEKING_HIGHLANDS,
	"sundered_coast": Style.SUNDERED_COAST,
	"black_citadel": Style.BLACK_CITADEL,
	"fire_stair": Style.FIRE_STAIR,
	"ashurim": Style.ASHURIM,
	"babilim": Style.BABILIM,
}

@export var style: Style = Style.SWORD_VOW_RUINS
@export var size: float = 40.0    # half-extent of the playable area
@export var auto_build_on_ready: bool = true
# If set, overrides `style` by looking up the matching enum in STYLE_BY_ID.
# Convenient for region scenes that already declare metadata/region_id.
@export var style_id: StringName = &""

func _ready() -> void:
	# region_id-driven style override
	if style_id != &"":
		var key: String = String(style_id)
		if STYLE_BY_ID.has(key):
			style = STYLE_BY_ID[key]
	# Or pick up region_id from the parent scene root if we sit under one
	elif get_parent() and get_parent().has_meta("region_id"):
		var key2: String = String(get_parent().get_meta("region_id"))
		if STYLE_BY_ID.has(key2):
			style = STYLE_BY_ID[key2]
	print("[ZoneComposer] style=%d size=%s parent=%s" % [int(style), str(size), name])
	if auto_build_on_ready:
		call_deferred("_build_with_diag")

func _build_with_diag() -> void:
	var before: int = get_child_count()
	build()
	var after: int = get_child_count()
	print("[ZoneComposer] spawned %d props for style %d" % [after - before, int(style)])

func build() -> void:
	match style:
		Style.SWORD_VOW_RUINS:     _build_sword_vow_ruins()
		Style.ASH_STEP_CAMP:       _build_ash_step_camp()
		Style.WHISPER_SHRINE:      _build_whisper_shrine()
		Style.GREENHEART_GLADE:    _build_greenheart_glade()
		Style.INKSTONE_TOWER:      _build_inkstone_tower()
		Style.COVEN_GLEN:          _build_coven_glen()
		Style.SUNSWORN_CHAPEL:     _build_sunsworn_chapel()
		Style.PYRE_ASCENT:         _build_pyre_ascent()
		Style.THE_CRADLE:          _build_the_cradle()
		Style.THE_REED_WASTES:     _build_the_reed_wastes()
		Style.LAPIS_BAY:           _build_lapis_bay()
		Style.BONE_MOUNTAINS:      _build_bone_mountains()
		Style.VERDANT_WOUND:       _build_verdant_wound()
		Style.EMBER_STEPPES:       _build_ember_steppes()
		Style.MIST_VALE:           _build_mist_vale()
		Style.SHRIEKING_HIGHLANDS: _build_shrieking_highlands()
		Style.SUNDERED_COAST:      _build_sundered_coast()
		Style.BLACK_CITADEL:       _build_black_citadel()
		Style.FIRE_STAIR:          _build_pyre_ascent()  # shares style
		Style.ASHURIM:             _build_ashurim()
		Style.BABILIM:             _build_babilim()

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
	# KayKit dungeon assets ship with no collision shapes either, so we
	# auto-generate trimesh colliders for everything except decor (small
	# props matched by DECOR_PATTERNS). Without this, the player walks
	# through walls / floor tiles / pillars / dojo platforms / altars.
	if _is_decor(asset):
		_strip_colliders(inst)
	else:
		_ensure_collision(inst)
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
# SWORD-VOW RUINS — open-air burned courtyard, throne at north.
# Re-tuned 2026-05-06: Bond's playtest feedback was "just random walls".
# This pass kills the wall-spam corridor look. The arena now reads as an
# OPEN ruin: scattered rubble, broken columns, low foliage suggested by
# barrier_columns, a clear central path to the throne, lit torches only
# at the throne (north) and entry (south). Walls only at the back of the
# throne dais so the player has line-of-sight to everything.
#
# When a real Quaternius nature pack lands, swap rubble/columns for grass
# tufts and tree stumps; swap walls for ruined-arch stone fragments.
func _build_sword_vow_ruins() -> void:
	# JAPANESE SAKURA GROVE & DOJO. Bond's spec:
	#   - Cherry blossoms instead of generic trees
	#   - Dojo style instead of stone castle
	#   - Save medieval/castle for the Paladin location (Sunsworn Chapel)
	#
	# Layout (south = player spawn, north = boss/dojo):
	#   SOUTH  vermilion torii gate flanked by stone lanterns
	#   MID    stone-tile path through cherry grove, wooden bridge over a
	#          dry stream of stones, bamboo perimeter
	#   NORTH  raised wooden dojo platform (boss arena), large sakura tree
	#          behind throne, two stone lanterns flanking, white-pink motes

	# --- Ground decor: grass + flower scatter, avoiding center path ---
	for _i in range(140):
		var ox: float = randf_range(-size / 2 + 2, size / 2 - 2)
		var oz: float = randf_range(-size / 2 + 2, size / 2 - 2)
		# Keep a 1.5m-wide central spine clear for the stone path
		if abs(ox) <= 1.5 and oz >= -int(size / 2) + 4:
			continue
		var roll: float = randf()
		if roll < 0.55:
			var gpick: String = ["grass.glb", "grass_large.glb", "grass_leafs.glb", "grass_leafsLarge.glb"].pick_random()
			_nat(gpick, Vector3(ox, 0, oz), randf() * 360.0)
		elif roll < 0.78:
			# Pink/red/purple palette so flower bed reads as a Japanese garden
			var fpick: String = ["flower_purpleA.glb", "flower_purpleB.glb", "flower_redA.glb", "flower_redB.glb"].pick_random()
			_nat(fpick, Vector3(ox, 0, oz), randf() * 360.0)
		elif roll < 0.95:
			# Bamboo crops scattered as ground decor (also used as a tall ring
			# perimeter below). Adds Japanese garden feel.
			if randf() < 0.5:
				_nat(["crops_bambooStageA.glb", "crops_bambooStageB.glb"].pick_random(), Vector3(ox, 0, oz), randf() * 360.0, randf_range(1.4, 2.2))
			else:
				_nat(["plant_bush.glb", "plant_bushDetailed.glb"].pick_random(), Vector3(ox, 0, oz), randf() * 360.0, randf_range(0.8, 1.2))

	# --- South entry: TORII GATE + flanking lanterns + welcome lanterns
	_torii(Vector3(0, 0, size / 2 - 4), 5.0)
	# Two stone lanterns flanking the entry path
	_lantern(Vector3(-3, 0, size / 2 - 4))
	_lantern(Vector3(3, 0, size / 2 - 4))
	# More lanterns walking the path (every 4m)
	for z_step in range(-12, 13, 4):
		_lantern(Vector3(-2.5, 0, z_step))
		_lantern(Vector3(2.5, 0, z_step))

	# --- Stone path of small decorated tiles (more zen than full cobble) ---
	for z in range(-int(size / 2) + 4, int(size / 2) + 1, 2):
		_spawn("floor_tile_small_decorated.gltf.glb", Vector3(0, 0.05, z))

	# --- Wooden arched bridge over a koi pond in middle ---
	# The bridge is the eye-magnet centerpiece. Now spans an actual
	# water plane with the water_pond shader (rippling waves +
	# fresnel rim + lantern-glow tint).
	_nat("bridge_wood.glb", Vector3(0, 0.1, 0), 0.0, 1.4)
	# Stones edging the pond banks (tells you water sits between them)
	for x_step in range(-8, 9, 2):
		_nat(["cliff_blockHalf_stone.glb"].pick_random(), Vector3(float(x_step), 0, -2.5), randf() * 360.0, randf_range(0.5, 0.8))
		_nat(["cliff_blockHalf_stone.glb"].pick_random(), Vector3(float(x_step), 0, 2.5), randf() * 360.0, randf_range(0.5, 0.8))
	# Water plane sitting just below the bridge
	_spawn_koi_pond(Vector3(0, 0.05, 0), Vector2(18, 5))

	# --- Cherry blossom grove perimeter (instead of generic trees) ---
	# Tinted to soft pink. We use the _fall variants because they have
	# fluffier silhouettes than the green trees and read more like sakura
	# canopies.
	for i in range(48):
		var ring: int = i / 24
		var angle: float = (i % 24) * TAU / 24.0 + (PI / 24.0 if ring == 1 else 0.0)
		var r: float = size / 2 + (1.5 + ring * 4.0) + randf_range(-1, 2)
		var tx: float = cos(angle) * r
		var tz: float = sin(angle) * r
		# Skip the south entry corridor so torii is visible from spawn
		if abs(tx) < 4 and tz > size / 2 - 2:
			continue
		var tree_pick: String = ["tree_default_fall.glb", "tree_detailed_fall.glb", "tree_fat_fall.glb", "tree_blocks_fall.glb"].pick_random()
		_sakura(tree_pick, Vector3(tx, 0, tz), randf() * 360.0, randf_range(2.6, 4.0))

	# --- Tall bamboo grove woven into the cherry perimeter for vertical
	# variety and dense Japanese-garden density ---
	for i in range(28):
		var angle: float = i * TAU / 28.0
		var r: float = size / 2 + 0.5
		var bx: float = cos(angle) * r
		var bz: float = sin(angle) * r
		if abs(bx) < 4 and bz > size / 2 - 2:
			continue
		# Bamboo crops scaled tall to read as 4-6m grove
		_nat(["crops_bambooStageA.glb", "crops_bambooStageB.glb"].pick_random(), Vector3(bx, 0, bz), randf() * 360.0, randf_range(2.5, 3.8))

	# --- Inner-arena cherry blossom scatter for foreground depth ---
	for _i in range(8):
		var ix: float = randf_range(-size / 2 + 6, size / 2 - 6)
		var iz: float = randf_range(-size / 2 + 8, size / 2 - 8)
		if abs(ix) < 5: continue  # keep central path clear
		_sakura(["tree_default_fall.glb", "tree_detailed_fall.glb"].pick_random(), Vector3(ix, 0, iz), randf() * 360.0, randf_range(2.0, 3.0))

	# --- Stone scatter (zen rocks) instead of broken columns + rubble ---
	# Replaces the Sumerian-ruin debris from the old layout.
	for _i in range(18):
		var ox: float = randf_range(-size / 2 + 4, size / 2 - 4)
		var oz: float = randf_range(-size / 2 + 8, size / 2 - 4)
		if abs(ox) < 4:
			continue
		var pick: int = randi() % 4
		match pick:
			0: _nat("cliff_blockHalf_stone.glb", Vector3(ox, 0, oz), randf() * 360.0, randf_range(0.6, 1.2))
			1: _nat("stump_round.glb", Vector3(ox, 0, oz), randf() * 360.0, randf_range(0.8, 1.4))
			2: _nat("plant_bushDetailed.glb", Vector3(ox, 0, oz), randf() * 360.0, randf_range(1.0, 1.6))
			3: _nat("plant_bushLarge.glb", Vector3(ox, 0, oz), randf() * 360.0, randf_range(0.8, 1.2))

	# --- NORTH end: WOODEN DOJO PLATFORM (boss arena) ---
	# Three-step rising wooden platform (use floor_dirt for warm wood read,
	# scaled wider than tall so it presents as a temple stage)
	for tier in range(3):
		var w: int = 5 - tier
		var y: float = 0.35 * float(tier + 1)
		for dx in range(-w, w + 1):
			_spawn("floor_dirt_large.gltf.glb", Vector3(float(dx) * 1.0, y, -size / 2 + 4 + tier))
	# Twin stone lanterns flanking the dojo
	_lantern(Vector3(-5, 1.05, -size / 2 + 4))
	_lantern(Vector3(5, 1.05, -size / 2 + 4))
	# Decorated columns at the back of the dojo (replace stone arches)
	_spawn("pillar_decorated.gltf.glb", Vector3(-3, 1.05, -size / 2 + 6))
	_spawn("pillar_decorated.gltf.glb", Vector3(3, 1.05, -size / 2 + 6))
	# A single grand sakura behind the dojo as a focal point
	_sakura("tree_fat_fall.glb", Vector3(0, 0, -size / 2 + 8), 0.0, 5.0)
	# Lore flavor: half-buried sword in the central path (oath-keeper)
	_spawn("sword_shield_broken.gltf.glb", Vector3(0, 0, 8), 25.0)

	# Campfire ring at the player spawn so south end is recognizable
	_nat("campfire_stones.glb", Vector3(0, 0, size / 2 - 7))

	# --- Ambient world life ---
	var wl: Node = get_node_or_null("/root/WorldLife")
	if wl:
		# Fewer birds, slower (peaceful temple grounds)
		wl.spawn_bird_flock(self, 3, Vector3(0, 16, 0), size * 0.6)
		# Cherry petals raining over the entire courtyard — the signature
		# Japanese touch. Volume sized to cover the play area.
		wl.spawn_petal_fall(self, Vector3(0, 12, 0), Vector3(size, 1, size), Color(1.0, 0.65, 0.78, 0.95))
		# Wisp of smoke from the campfire (warm spawn read)
		wl.spawn_chimney_smoke(self, Vector3(0, 1.2, size / 2 - 7))
		# Pale pink motes hanging at the dojo (sacred grove vibe, NOT the
		# orange/cursed-throne reading from the original castle layout)
		wl.spawn_intro_motes(self, Vector3(0, 1.5, -size / 2 + 5), 4.5, Color(1.0, 0.85, 0.92, 1.0))

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
# GREENHEART GLADE — Ranger intro forest clearing, dense canopy
# ----------------------------------------------------------------
func _build_greenheart_glade() -> void:
	# Forest floor: dirt + dense grass + flowers + mushrooms
	var tile_size := 4.0
	var grid := int(size / tile_size)
	for x in range(-grid, grid + 1):
		for z in range(-grid, grid + 1):
			var asset := "floor_dirt_small_A.gltf.glb"
			if randf() < 0.2:
				asset = "floor_dirt_large_rocky.gltf.glb"
			_spawn(asset, Vector3(x * tile_size, 0, z * tile_size), randf() * 360.0)
			# Dense ground cover (60% chance grass, 20% chance flower)
			if randf() < 0.60:
				var pick: String = ["grass.glb", "grass_large.glb", "grass_leafs.glb", "grass_leafsLarge.glb"].pick_random()
				_nat(pick, Vector3(x * tile_size + randf_range(-1.5, 1.5), 0, z * tile_size + randf_range(-1.5, 1.5)), randf() * 360.0)
			elif randf() < 0.30:
				var fpick: String = ["flower_purpleA.glb", "flower_purpleB.glb", "flower_redA.glb", "flower_yellowA.glb"].pick_random()
				_nat(fpick, Vector3(x * tile_size + randf_range(-1, 1), 0, z * tile_size + randf_range(-1, 1)), randf() * 360.0)
	# Dense tree canopy: 50 trees scattered, larger toward perimeter
	for _i in range(50):
		var ox: float = randf_range(-size / 2 + 2, size / 2 - 2)
		var oz: float = randf_range(-size / 2 + 2, size / 2 - 2)
		var d_from_center: float = sqrt(ox * ox + oz * oz)
		# Skip the center 6m so combat space is clear
		if d_from_center < 6:
			continue
		var t_pick: String = ["tree_default.glb", "tree_default_dark.glb", "tree_detailed.glb", "tree_detailed_dark.glb", "tree_fat.glb", "tree_fat_darkh.glb", "tree_thin.glb", "tree_thin_dark.glb"].pick_random()
		_nat(t_pick, Vector3(ox, 0, oz), randf() * 360.0, randf_range(0.9, 1.5))
	# Mossy log ring (campfire-style suggestion of past travelers)
	for i in range(6):
		var angle: float = i * TAU / 6.0
		var r: float = 4.0
		_nat("plant_bush.glb", Vector3(cos(angle) * r, 0, sin(angle) * r), randf() * 360.0, 1.2)
	# Center campfire stones — Greenheart hunter's bivouac
	_nat("campfire_stones.glb", Vector3(0, 0, 0))
	# Mushroom rings scattered (forest atmosphere)
	for _i in range(8):
		var ox: float = randf_range(-size / 2, size / 2)
		var oz: float = randf_range(-size / 2, size / 2)
		if abs(ox) < 4 and abs(oz) < 4: continue
		var m_pick: String = ["mushroom_red.glb", "mushroom_redGroup.glb", "mushroom_redTall.glb", "mushroom_tan.glb", "mushroom_tanGroup.glb"].pick_random()
		_nat(m_pick, Vector3(ox, 0, oz), randf() * 360.0)

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
# COVEN GLEN — Druid intro: standing stone circle in misty marsh
# ----------------------------------------------------------------
func _build_coven_glen() -> void:
	var tile_size := 4.0
	var grid := int(size / tile_size)
	for x in range(-grid, grid + 1):
		for z in range(-grid, grid + 1):
			# Mossy ground with weeds
			var asset: String = "floor_dirt_small_weeds.gltf.glb" if (x + z) % 2 == 0 else "floor_dirt_small_B.gltf.glb"
			_spawn(asset, Vector3(x * tile_size, 0, z * tile_size), randf() * 90.0)
			# Heavy moss/grass coverage
			if randf() < 0.55:
				_nat("grass_leafsLarge.glb", Vector3(x * tile_size + randf_range(-1.5, 1.5), 0, z * tile_size + randf_range(-1.5, 1.5)), randf() * 360.0)
	# Outer ring of trees framing the glen
	for i in range(20):
		var angle: float = i * TAU / 20.0
		var r: float = size / 2 + 1.0
		_nat("tree_detailed_dark.glb", Vector3(cos(angle) * r, 0, sin(angle) * r), randf() * 360.0, randf_range(2.86, 3.90))
	# Standing-stone circle (7 stones, lore: one per breathing style)
	for i in range(7):
		var angle: float = i * TAU / 7.0
		var radius := 8.0
		_spawn("pillar_decorated.gltf.glb",
			Vector3(cos(angle) * radius, 0, sin(angle) * radius),
			rad_to_deg(angle) + 90.0)
	# Central altar stone surrounded by candles
	_spawn("column.gltf.glb", Vector3(0, 0, 0))
	for i in range(4):
		var angle: float = i * TAU / 4.0
		_spawn("candle_thin_lit.gltf.glb", Vector3(cos(angle) * 1.4, 0.5, sin(angle) * 1.4))
	# Mushroom rings (witchy)
	for _i in range(12):
		var ox: float = randf_range(-size / 2 + 2, size / 2 - 2)
		var oz: float = randf_range(-size / 2 + 2, size / 2 - 2)
		var d: float = sqrt(ox * ox + oz * oz)
		if d < 12.0 and d > 9.0:  # ring just outside the standing stones
			_nat(["mushroom_red.glb", "mushroom_redGroup.glb"].pick_random(), Vector3(ox, 0, oz), randf() * 360.0)
	# 4 dim torches at cardinal points outside the stone circle
	for i in range(4):
		var angle: float = i * TAU / 4.0
		_torch(Vector3(cos(angle) * 14.0, 0, sin(angle) * 14.0), true)
	# Plant bushes scattered for marsh feel
	for _i in range(10):
		var ox: float = randf_range(-size / 2, size / 2)
		var oz: float = randf_range(-size / 2, size / 2)
		_nat("plant_bush.glb", Vector3(ox, 0, oz), randf() * 360.0, randf_range(0.8, 1.2))

# ----------------------------------------------------------------
# SUNSWORN CHAPEL — interior chapel courtyard
# ----------------------------------------------------------------
func _build_sunsworn_chapel() -> void:
	# PALADIN INTRO: Medieval castle chapel. Bond's spec moved the heavy
	# stone-castle aesthetic out of Sword-Vow Ruins (now Japanese) and
	# into here. Stone-tile floor, 4 corner watch towers (Kenney castle),
	# stone walls at perimeter, twin colonnades down the spine to the
	# altar, white banners, holy braziers.
	var tile_size := 4.0
	var grid := int(size / tile_size)
	# Stone-tile floor across the whole footprint
	for x in range(-grid, grid + 1):
		for z in range(-grid, grid + 1):
			_spawn("floor_tile_large.gltf.glb", Vector3(x * tile_size, 0, z * tile_size))
	# Outer chapel walls (Kenney castle wall pieces) — encloses the chapel
	for x_step in range(-int(size / 2) + 4, int(size / 2) - 3, 4):
		_cas("wall.glb", Vector3(x_step, 0, -size / 2 + 1))
		_cas("wall.glb", Vector3(x_step, 0, size / 2 - 1))
	for z_step in range(-int(size / 2) + 4, int(size / 2) - 3, 4):
		_cas("wall.glb", Vector3(-size / 2 + 1, 0, z_step), 90.0)
		_cas("wall.glb", Vector3(size / 2 - 1, 0, z_step), 90.0)
	# Square watch towers at the four corners — paladin guard posts
	for corner in [Vector3(-size / 2 + 2, 0, -size / 2 + 2), Vector3(size / 2 - 2, 0, -size / 2 + 2), Vector3(-size / 2 + 2, 0, size / 2 - 2), Vector3(size / 2 - 2, 0, size / 2 - 2)]:
		_cas("tower-square-base-color.glb", corner)
		_cas("tower-square-mid.glb", corner + Vector3(0, 4, 0))
		_cas("tower-square-top.glb", corner + Vector3(0, 8, 0))
		_cas("tower-square-roof.glb", corner + Vector3(0, 11, 0))
	# Gate at south entry
	_cas("wall-narrow-gate.glb", Vector3(0, 0, size / 2 - 1))
	# Twin long colonnades down the spine
	for z_step in range(-16, 17, 4):
		_spawn("pillar_decorated.gltf.glb", Vector3(-10, 0, z_step))
		_spawn("pillar_decorated.gltf.glb", Vector3(10, 0, z_step))
	# Altar block at north end (raised platform with column behind)
	for dx in range(-3, 4):
		_spawn("floor_tile_large.gltf.glb", Vector3(float(dx), 0.4, -size / 2 + 4))
	_spawn("table_long_decorated_A.gltf.glb", Vector3(0, 0.4, -size / 2 + 4))
	_spawn("candle_triple.gltf.glb", Vector3(-2, 1.3, -size / 2 + 4))
	_spawn("candle_triple.gltf.glb", Vector3(2, 1.3, -size / 2 + 4))
	# Tall column behind the altar
	_spawn("column.gltf.glb", Vector3(-3, 0.4, -size / 2 + 6))
	_spawn("column.gltf.glb", Vector3(3, 0.4, -size / 2 + 6))
	# Pews indicated by stone barrier rows on either side of the spine
	for z_step in [-12, -6, 0, 6, 12]:
		_spawn("barrier_column.gltf.glb", Vector3(-5, 0, z_step), 0.0)
		_spawn("barrier_column.gltf.glb", Vector3(5, 0, z_step), 180.0)
	# White banners flanking the colonnade (paladin holy colors).
	# _banner adds wind sway so the cloth actually moves.
	for z_step in [-12, -4, 4, 12]:
		_banner("flag-banner-long.glb", Vector3(-10, 0.2, z_step), Color(0.96, 0.94, 0.85, 1.0))
		_banner("flag-banner-long.glb", Vector3(10, 0.2, z_step), Color(0.96, 0.94, 0.85, 1.0))
	# Many lit torches for holy atmosphere
	for z_step in range(-16, 17, 4):
		_torch(Vector3(-12, 0, z_step), true)
		_torch(Vector3(12, 0, z_step), true)
	# Lore: kneeling cushions / prayer mats at the altar (use small tiles)
	_spawn("floor_tile_small.gltf.glb", Vector3(-2, 0.05, -size / 2 + 8))
	_spawn("floor_tile_small.gltf.glb", Vector3(2, 0.05, -size / 2 + 8))

	# --- Ambient world life ---
	var wl: Node = get_node_or_null("/root/WorldLife")
	if wl:
		# Doves over the chapel (peaceful sacred reading)
		wl.spawn_bird_flock(self, 5, Vector3(0, 14, 0), size * 0.55)
		# Brazier/incense smoke at altar candles
		wl.spawn_chimney_smoke(self, Vector3(-2, 2.0, -size / 2 + 4))
		wl.spawn_chimney_smoke(self, Vector3(2, 2.0, -size / 2 + 4))
		# Tower-top brazier smoke
		for corner in [Vector3(-size / 2 + 2, 12, -size / 2 + 2), Vector3(size / 2 - 2, 12, -size / 2 + 2), Vector3(-size / 2 + 2, 12, size / 2 - 2), Vector3(size / 2 - 2, 12, size / 2 - 2)]:
			wl.spawn_chimney_smoke(self, corner)
		# Holy white-gold motes over the altar (paladin sun-light)
		wl.spawn_intro_motes(self, Vector3(0, 1.5, -size / 2 + 4), 5.0, Color(1.0, 0.95, 0.75, 1.0))

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

# ----------------------------------------------------------------
# THE CRADLE — Sumerian temple ground, stepped ziggurat dais north,
# weathered pillars, prayer offerings on plinths
# ----------------------------------------------------------------
func _build_the_cradle() -> void:
	var tile := 4.0
	var grid := int(size / tile)
	for x in range(-grid, grid + 1):
		for z in range(-grid, grid + 1):
			var asset := "floor_dirt_small_A.gltf.glb" if (x + z) % 2 == 0 else "floor_dirt_small_C.gltf.glb"
			_spawn(asset, Vector3(x * tile, 0, z * tile))
	# Stepped ziggurat dais at the north end (boss spawn) — three rising tiers
	for tier in range(3):
		var w: int = 6 - tier * 2
		var y: float = 0.4 * float(tier + 1)
		for dx in range(-w, w + 1):
			_spawn("floor_dirt_large.gltf.glb", Vector3(float(dx) * 1.0, y, -size / 2 + 4 + tier * 2))
	# Flanking columns at base of ziggurat
	_spawn("pillar_decorated.gltf.glb", Vector3(-7, 0.4, -size / 2 + 4))
	_spawn("pillar_decorated.gltf.glb", Vector3(7, 0.4, -size / 2 + 4))
	# Prayer offering plinths down the central axis
	for z_step in [-12, 0, 12]:
		_spawn("column.gltf.glb", Vector3(0, 0, z_step))
		_spawn("candle_lit.gltf.glb", Vector3(0, 1.6, z_step))
	# Side pillars marking the sacred path
	for z_step in [-16, -8, 0, 8, 16]:
		_spawn("pillar.gltf.glb", Vector3(-10, 0, z_step))
		_spawn("pillar.gltf.glb", Vector3(10, 0, z_step))
	# Torches at the cardinal entry points (south)
	_torch(Vector3(-4, 0, size / 2 - 2), true)
	_torch(Vector3(4, 0, size / 2 - 2), true)

# ----------------------------------------------------------------
# THE REED WASTES — marshy plain, plank pathways, broken huts
# ----------------------------------------------------------------
func _build_the_reed_wastes() -> void:
	var tile := 4.0
	var grid := int(size / tile)
	for x in range(-grid, grid + 1):
		for z in range(-grid, grid + 1):
			var asset := "floor_dirt_small_weeds.gltf.glb"
			if randf() < 0.4:
				asset = "floor_dirt_small_B.gltf.glb"
			_spawn(asset, Vector3(x * tile, 0, z * tile), randf() * 360.0)
	# Plank-board pathway down the spine (wood floor strip)
	for z in range(-int(size / 2), int(size / 2), 2):
		_spawn("floor_wood_small_dark.gltf.glb", Vector3(0, 0.05, z))
	# Broken hut framing on either side of path
	for offset in [-14, 14]:
		_spawn("wall_broken.gltf.glb", Vector3(offset, 0, -8), 0.0)
		_spawn("wall_broken.gltf.glb", Vector3(offset, 0, 0), 0.0)
		_spawn("wall_broken.gltf.glb", Vector3(offset, 0, 8), 0.0)
		_spawn("trunk_medium_A.gltf.glb", Vector3(offset, 0, -4))
		_spawn("trunk_medium_B.gltf.glb", Vector3(offset, 0, 4))
	# Standing reeds simulated by dense barrier columns at the edges
	for _i in range(20):
		var x: float = randf_range(-size / 2, size / 2)
		var z: float = randf_range(-size / 2, size / 2)
		if abs(x) < 12:
			continue
		_spawn("barrier_column.gltf.glb", Vector3(x, 0, z), randf() * 360.0)

# ----------------------------------------------------------------
# LAPIS BAY — coastal docks, stacked crates, weathered piers
# ----------------------------------------------------------------
func _build_lapis_bay() -> void:
	# Coastal dock: sandy beach south, wooden pier north, crates/barrels
	# stacked along the dock, broken bridges suggesting Crown's ban on
	# trade caused the smugglers to cut their own piers.
	var tile := 4.0
	var grid := int(size / tile)
	for x in range(-grid, grid + 1):
		for z in range(-grid, grid + 1):
			var asset: String
			if z > 4:
				# Pier wood
				asset = "floor_wood_large.gltf.glb" if (x + z) % 2 == 0 else "floor_wood_small.gltf.glb"
			elif z > -4:
				# Wet sand zone
				asset = "floor_dirt_small_A.gltf.glb"
			else:
				# Beach proper - sparse grass tufts above sand
				asset = "floor_dirt_small_A.gltf.glb"
			_spawn(asset, Vector3(x * tile, 0, z * tile))
			# Beach grass on south end
			if z < -4 and randf() < 0.20:
				_nat("grass.glb", Vector3(x * tile + randf_range(-1, 1), 0, z * tile + randf_range(-1, 1)), randf() * 360.0, 0.7)
	# Tree line at the south edge (where beach meets forest)
	for i in range(12):
		var tx: float = randf_range(-size / 2 + 2, size / 2 - 2)
		_nat("tree_thin.glb", Vector3(tx, 0, -size / 2 + 1), randf() * 360.0, randf_range(2.34, 3.12))
	# Cattails / bushes near water edge
	for _i in range(20):
		var ox: float = randf_range(-size / 2 + 2, size / 2 - 2)
		var oz: float = randf_range(-2, 4)  # at water line
		_nat(["plant_bush.glb", "grass_leafsLarge.glb"].pick_random(), Vector3(ox, 0, oz), randf() * 360.0)
	# Pier columns extending into bay (north end)
	for x in [-12, -8, -4, 4, 8, 12]:
		_spawn("pillar.gltf.glb", Vector3(x, 0, size / 2 - 2))
		_spawn("pillar.gltf.glb", Vector3(x, 0, size / 2 - 6))
	# Bridge sections (kenney has stone+wood variants)
	_nat("bridge_wood.glb", Vector3(0, 0, size / 2 - 2), 90.0)
	_nat("bridge_stone.glb", Vector3(0, 0, 0), 90.0)
	# Stacked crates and barrels — cargo
	for offset in [-10, -6, 6, 10]:
		_spawn("crates_stacked.gltf.glb", Vector3(offset, 0, 4))
		_spawn("barrel_large.gltf.glb", Vector3(offset + 1, 0, 6))
		_spawn("barrel_small_stack.gltf.glb", Vector3(offset, 0, 8))
	# Mooring banners
	_spawn("banner_blue.gltf.glb", Vector3(-12, 0.2, size / 2 - 2))
	_spawn("banner_blue.gltf.glb", Vector3(12, 0.2, size / 2 - 2))
	# Cliff edges around the bay (rock formations)
	for _i in range(6):
		var ox: float = randf_range(-size / 2, size / 2)
		var oz: float = randf_range(-size / 2 + 1, -size / 2 + 4)
		_nat(["cliff_blockHalf_rock.glb", "cliff_blockCave_rock.glb"].pick_random(), Vector3(ox, 0, oz), randf() * 360.0)
	# Lit lanterns along the dock
	for x in [-12, 0, 12]:
		_torch(Vector3(x, 0, size / 2 - 4), true)
	# Campfire on beach
	_nat("campfire_stones.glb", Vector3(0, 0, -size / 2 + 6))

# ----------------------------------------------------------------
# BONE MOUNTAINS — rocky pass, scattered bones, narrow path
# ----------------------------------------------------------------
func _build_bone_mountains() -> void:
	# Rocky pass strewn with bones (rubble) and cliff blocks. Lore: ribs
	# of giants line the path, scattered rocks form a narrow corridor.
	var tile := 4.0
	var grid := int(size / tile)
	for x in range(-grid, grid + 1):
		for z in range(-grid, grid + 1):
			var asset := "floor_dirt_large_rocky.gltf.glb"
			if randf() < 0.4:
				asset = "floor_tile_large_rocks.gltf.glb"
			_spawn(asset, Vector3(x * tile, 0, z * tile), randf() * 360.0)
	# Cliff walls flanking the spine — kenney cliff blocks at varied heights
	for z_step in range(-int(size / 2) + 4, int(size / 2), 4):
		# Stagger left wall
		var lh: float = 0.0 if (z_step / 4) % 2 == 0 else 1.5
		_nat(["cliff_blockHalf_rock.glb", "cliff_blockHalf_stone.glb"].pick_random(), Vector3(-12, lh, z_step), randf() * 360.0)
		var rh: float = 1.5 if (z_step / 4) % 2 == 0 else 0.0
		_nat(["cliff_blockHalf_rock.glb", "cliff_blockHalf_stone.glb"].pick_random(), Vector3(12, rh, z_step), randf() * 360.0)
	# Rubble (bone middens) scattered
	for _i in range(20):
		var x: float = randf_range(-size / 2 + 4, size / 2 - 4)
		var z: float = randf_range(-size / 2 + 4, size / 2 - 4)
		if abs(x) < 3: continue  # keep central path clear
		var asset: String = "rubble_large.gltf.glb" if randf() < 0.5 else "rubble_half.gltf.glb"
		_spawn(asset, Vector3(x, 0, z), randf() * 360.0)
	# Cliff blocks scattered as boulders
	for _i in range(12):
		var ox: float = randf_range(-size / 2 + 6, size / 2 - 6)
		var oz: float = randf_range(-size / 2 + 6, size / 2 - 6)
		if abs(ox) < 4: continue
		_nat(["cliff_blockCave_rock.glb", "cliff_blockCave_stone.glb", "cliff_blockDiagonal_rock.glb"].pick_random(), Vector3(ox, 0, oz), randf() * 360.0)
	# Sword & shield offerings (dropped from earlier expedition deaths)
	for z_step in [-10, 0, 10]:
		_spawn("sword_shield_broken.gltf.glb", Vector3(randf_range(-2, 2), 0, z_step))
	# Sparse dead grass tufts (high altitude is bare)
	for _i in range(10):
		var ox: float = randf_range(-size / 2, size / 2)
		var oz: float = randf_range(-size / 2, size / 2)
		_nat("grass.glb", Vector3(ox, 0, oz), randf() * 360.0, 0.8)

# ----------------------------------------------------------------
# VERDANT WOUND — corrupted forest, tilted ruins, weeds in stone
# ----------------------------------------------------------------
func _build_verdant_wound() -> void:
	# Corrupted forest: dark trees, twisted growth, broken ruins
	# overgrown with weeds. Lore: Tiamat's seep warps the foliage here.
	var tile := 4.0
	var grid := int(size / tile)
	for x in range(-grid, grid + 1):
		for z in range(-grid, grid + 1):
			var asset := "floor_tile_small_weeds_A.gltf.glb" if (x + z) % 2 == 0 else "floor_tile_small_weeds_B.gltf.glb"
			_spawn(asset, Vector3(x * tile, 0, z * tile), randf() * 360.0)
			# Heavy weed coverage suggests corruption
			if randf() < 0.55:
				_nat(["grass_leafs.glb", "grass_leafsLarge.glb"].pick_random(), Vector3(x * tile + randf_range(-1.5, 1.5), 0, z * tile + randf_range(-1.5, 1.5)), randf() * 360.0)
	# Dense DARK tree canopy (corruption-twisted)
	for _i in range(40):
		var ox: float = randf_range(-size / 2 + 2, size / 2 - 2)
		var oz: float = randf_range(-size / 2 + 2, size / 2 - 2)
		if abs(ox) < 5 and abs(oz) < 5: continue
		var tp: Node3D = _nat(["tree_default_dark.glb", "tree_detailed_dark.glb", "tree_thin_dark.glb", "tree_fat_darkh.glb", "tree_blocks_dark.glb"].pick_random(), Vector3(ox, 0, oz), randf() * 360.0, randf_range(2.34, 3.64))
		# 30% of trees tilted to read as corrupted/withered
		if tp and randf() < 0.30:
			tp.rotation.x = deg_to_rad(randf_range(-15, 15))
			tp.rotation.z = deg_to_rad(randf_range(-15, 15))
	# Tilted broken pillars (overgrown ruin)
	for _i in range(10):
		var x: float = randf_range(-size / 2 + 4, size / 2 - 4)
		var z: float = randf_range(-size / 2 + 4, size / 2 - 4)
		if abs(x) < 5 and abs(z) < 5: continue
		var p := _spawn("pillar.gltf.glb", Vector3(x, 0, z), randf() * 360.0)
		if p:
			p.rotation.x = deg_to_rad(randf_range(-20, 20))
			p.rotation.z = deg_to_rad(randf_range(-20, 20))
	# Cracked walls scattered, half-eaten by foliage
	for _i in range(8):
		var ox: float = randf_range(-size / 2 + 6, size / 2 - 6)
		var oz: float = randf_range(-size / 2 + 6, size / 2 - 6)
		_spawn("wall_cracked.gltf.glb", Vector3(ox, 0, oz), randf() * 360.0)
	# Center: ancient corrupted altar with red candles
	_spawn("column.gltf.glb", Vector3(0, 0, 0))
	_spawn("candle_thin_lit.gltf.glb", Vector3(0.6, 1.0, 0))
	_spawn("candle_thin_lit.gltf.glb", Vector3(-0.6, 1.0, 0))
	# Mushroom growth (forest corruption signal)
	for _i in range(20):
		var ox: float = randf_range(-size / 2, size / 2)
		var oz: float = randf_range(-size / 2, size / 2)
		_nat(["mushroom_red.glb", "mushroom_redGroup.glb", "mushroom_redTall.glb"].pick_random(), Vector3(ox, 0, oz), randf() * 360.0)

# ----------------------------------------------------------------
# EMBER STEPPES — wind-blown plain with scattered fire pits
# ----------------------------------------------------------------
func _build_ember_steppes() -> void:
	var tile := 4.0
	var grid := int(size / tile)
	for x in range(-grid, grid + 1):
		for z in range(-grid, grid + 1):
			_spawn("floor_dirt_large.gltf.glb", Vector3(x * tile, 0, z * tile))
	# Scattered fire pits (raider camps long-cold and freshly-lit)
	for offset in [-16, -8, 0, 8, 16]:
		_torch(Vector3(offset, 0, randf_range(-12, 12)), randf() < 0.5)
		_spawn("rubble_half.gltf.glb", Vector3(offset + randf_range(-1.5, 1.5), 0, randf_range(-12, 12)))
	# Spear-rack barriers at boss spawn
	for x in [-3, -1, 1, 3]:
		_spawn("barrier.gltf.glb", Vector3(x, 0, -size / 2 + 4))
	# Banners marking territory
	_spawn("banner_red.gltf.glb", Vector3(-6, 0.2, -size / 2 + 4))
	_spawn("banner_red.gltf.glb", Vector3(6, 0.2, -size / 2 + 4))

# ----------------------------------------------------------------
# MIST VALE — fogged grove, stones in mist, mossy logs
# ----------------------------------------------------------------
func _build_mist_vale() -> void:
	# Foggy druid grove: scattered standing stones, mossy logs, dense
	# light-fall trees suggesting autumn mist. Memorial cairn near
	# center for Saru once she falls in the storyline.
	var tile := 4.0
	var grid := int(size / tile)
	for x in range(-grid, grid + 1):
		for z in range(-grid, grid + 1):
			var asset := "floor_dirt_small_weeds.gltf.glb" if (x + z) % 2 == 0 else "floor_dirt_small_A.gltf.glb"
			_spawn(asset, Vector3(x * tile, 0, z * tile), randf() * 360.0)
			# Light coverage of ground (more dirt visible than greenheart)
			if randf() < 0.35:
				_nat(["grass.glb", "grass_leafs.glb"].pick_random(), Vector3(x * tile + randf_range(-1.5, 1.5), 0, z * tile + randf_range(-1.5, 1.5)), randf() * 360.0)
	# Tree perimeter — autumn fall variants for that misty-grove look
	for i in range(24):
		var angle: float = i * TAU / 24.0
		var r: float = size / 2
		var tree_pick: String = ["tree_default_fall.glb", "tree_detailed_fall.glb", "tree_fat_fall.glb", "tree_blocks_fall.glb"].pick_random()
		_nat(tree_pick, Vector3(cos(angle) * r, 0, sin(angle) * r), randf() * 360.0, randf_range(1.0, 1.4))
	# Standing stone half-circle (north end)
	for i in range(5):
		var angle: float = lerp(PI * 0.25, PI * 0.75, float(i) / 4.0)
		var radius := 12.0
		_spawn("pillar_decorated.gltf.glb",
			Vector3(cos(angle) * radius, 0, -sin(angle) * radius),
			rad_to_deg(angle))
	# Mossy logs scattered (from KayKit dungeon kit's trunk variants)
	for _i in range(8):
		var x: float = randf_range(-size / 2, size / 2)
		var z: float = randf_range(-size / 2, size / 2)
		if abs(x) < 4 and abs(z) < 4: continue
		var asset: String = ["trunk_medium_A.gltf.glb","trunk_medium_B.gltf.glb","trunk_medium_C.gltf.glb"].pick_random()
		_spawn(asset, Vector3(x, 0, z), randf() * 360.0)
	# Center: druid altar with candles
	_spawn("column.gltf.glb", Vector3(0, 0, 0))
	for i in range(4):
		var angle: float = i * TAU / 4.0
		_spawn("candle_thin_lit.gltf.glb", Vector3(cos(angle) * 1.4, 0.5, sin(angle) * 1.4))
	# Bushes for misty undergrowth
	for _i in range(15):
		var ox: float = randf_range(-size / 2, size / 2)
		var oz: float = randf_range(-size / 2, size / 2)
		_nat("plant_bush.glb", Vector3(ox, 0, oz), randf() * 360.0, randf_range(0.7, 1.1))

# ----------------------------------------------------------------
# SHRIEKING HIGHLANDS — windy cliffs, runestones, abandoned shrine
# ----------------------------------------------------------------
func _build_shrieking_highlands() -> void:
	var tile := 4.0
	var grid := int(size / tile)
	for x in range(-grid, grid + 1):
		for z in range(-grid, grid + 1):
			_spawn("floor_dirt_large_rocky.gltf.glb", Vector3(x * tile, 0, z * tile))
	# Runestone monoliths in a scattered pattern
	for _i in range(6):
		var x: float = randf_range(-size / 2 + 4, size / 2 - 4)
		var z: float = randf_range(-size / 2 + 4, size / 2 - 4)
		if abs(x) < 4 and abs(z) < 4:
			continue
		_spawn("pillar_decorated.gltf.glb", Vector3(x, 0, z), randf() * 360.0)
	# Abandoned shrine: small wall fragments around a center column
	_spawn("column.gltf.glb", Vector3(0, 0, 0))
	_spawn("wall_cracked.gltf.glb", Vector3(-3, 0, -3), 0.0)
	_spawn("wall_cracked.gltf.glb", Vector3(3, 0, -3), 0.0)
	_spawn("wall_broken.gltf.glb", Vector3(-3, 0, 3), 180.0)
	_spawn("wall_broken.gltf.glb", Vector3(3, 0, 3), 180.0)
	# Cliff edge boundary on east/west
	for z_step in range(-int(size / 2), int(size / 2), 4):
		_spawn("wall.gltf.glb", Vector3(-size / 2 + 2, 0, z_step), 90.0)
		_spawn("wall.gltf.glb", Vector3(size / 2 - 2, 0, z_step), -90.0)

# ----------------------------------------------------------------
# SUNDERED COAST — broken cliffs, fallen pillars, shipwreck pieces
# ----------------------------------------------------------------
func _build_sundered_coast() -> void:
	var tile := 4.0
	var grid := int(size / tile)
	for x in range(-grid, grid + 1):
		for z in range(-grid, grid + 1):
			var asset := "floor_dirt_large_rocky.gltf.glb"
			if z > 4 and randf() < 0.5:
				asset = "floor_wood_large_dark.gltf.glb"
			_spawn(asset, Vector3(x * tile, 0, z * tile))
	# Fallen pillars in chaotic angles (wreckage)
	for _i in range(8):
		var x: float = randf_range(-size / 2, size / 2)
		var z: float = randf_range(-size / 2, size / 2)
		var p := _spawn("pillar.gltf.glb", Vector3(x, 0, z), randf() * 360.0)
		if p:
			p.rotation.z = deg_to_rad(90.0 + randf_range(-15, 15))
	# Shipwreck pieces (large trunks + barrels)
	for offset in [-10, -2, 6]:
		_spawn("trunk_large_A.gltf.glb", Vector3(offset, 0, 6))
		_spawn("barrel_large.gltf.glb", Vector3(offset + 2, 0, 8))
		_spawn("crates_stacked.gltf.glb", Vector3(offset, 0, 10))
	# Lone torch on a high stone
	_torch(Vector3(0, 0.4, -size / 2 + 4), true)

# ----------------------------------------------------------------
# BLACK CITADEL — interior fortress, throne, banners
# ----------------------------------------------------------------
func _build_black_citadel() -> void:
	# DARK FORTRESS: Kenney castle towers + walls scaled up for
	# fortress feel. Throne hall down the spine, hexagon corner
	# towers, drawbridge gate at south, siege weapons (broken)
	# scattered to suggest a long siege has happened here.
	var tile := 4.0
	var grid := int(size / tile)
	for x in range(-grid, grid + 1):
		for z in range(-grid, grid + 1):
			_spawn("floor_tile_large.gltf.glb", Vector3(x * tile, 0, z * tile))
	# Outer fortress walls (Kenney castle)
	for x_step in range(-int(size / 2) + 4, int(size / 2) - 3, 4):
		_cas("wall.glb", Vector3(x_step, 0, -size / 2 + 1))
	for x_step in range(-int(size / 2) + 4, int(size / 2) - 3, 4):
		_cas("wall.glb", Vector3(x_step, 0, size / 2 - 1))
	for z_step in range(-int(size / 2) + 4, int(size / 2) - 3, 4):
		_cas("wall.glb", Vector3(-size / 2 + 1, 0, z_step), 90.0)
		_cas("wall.glb", Vector3(size / 2 - 1, 0, z_step), 90.0)
	# Hexagon towers at the four corners (more imposing than square)
	for corner in [Vector3(-size / 2 + 2, 0, -size / 2 + 2), Vector3(size / 2 - 2, 0, -size / 2 + 2), Vector3(-size / 2 + 2, 0, size / 2 - 2), Vector3(size / 2 - 2, 0, size / 2 - 2)]:
		_cas("tower-hexagon-base.glb", corner)
		_cas("tower-hexagon-mid.glb", corner + Vector3(0, 4, 0))
		_cas("tower-hexagon-top.glb", corner + Vector3(0, 8, 0))
		_cas("tower-hexagon-roof.glb", corner + Vector3(0, 11, 0))
	# Drawbridge south gate
	_cas("wall-narrow-gate.glb", Vector3(0, 0, size / 2 - 1))
	_cas("metal-gate.glb", Vector3(0, 0, size / 2 - 1))
	_cas("bridge-draw.glb", Vector3(0, 0, size / 2 + 4))
	# Long throne hall down the spine — interior walls
	for z_step in range(-int(size / 2) + 4, int(size / 2) - 4, 4):
		_spawn("wall.gltf.glb", Vector3(-12, 0, z_step), 90.0)
		_spawn("wall.gltf.glb", Vector3(12, 0, z_step), -90.0)
	# Decorated columns flanking the throne path
	for z_step in [-12, -4, 4, 12]:
		_spawn("pillar_decorated.gltf.glb", Vector3(-6, 0, z_step))
		_spawn("pillar_decorated.gltf.glb", Vector3(6, 0, z_step))
	# Brown banners every other column (dark Crown colors), waving in
	# wind via _banner.
	for z_step in [-12, -4, 4, 12]:
		_banner("flag-banner-long.glb", Vector3(-6, 0.2, z_step), Color(0.42, 0.30, 0.20, 1.0))
		_banner("flag-banner-long.glb", Vector3(6, 0.2, z_step), Color(0.42, 0.30, 0.20, 1.0))
	# Throne dais at north (raised platform)
	for dx in range(-3, 4):
		_spawn("floor_tile_large.gltf.glb", Vector3(float(dx), 0.4, -size / 2 + 4))
	_spawn("chair.gltf.glb", Vector3(0, 0.4, -size / 2 + 4))
	_spawn("column.gltf.glb", Vector3(-4, 0.4, -size / 2 + 4))
	_spawn("column.gltf.glb", Vector3(4, 0.4, -size / 2 + 4))
	# Broken siege weapons in the courtyard (long-finished assault)
	_cas("siege-catapult-demolished.glb", Vector3(-8, 0, 8), 30.0)
	_cas("siege-tower-demolished.glb", Vector3(8, 0, 12), -25.0)
	_cas("siege-ram-demolished.glb", Vector3(0, 0, 16), 90.0)
	_cas("rocks-large.glb", Vector3(-10, 0, 4))
	_cas("rocks-small.glb", Vector3(7, 0, 0))
	# Dim torches — oppressive lighting
	for z_step in [-16, -8, 0, 8, 16]:
		_torch(Vector3(-11, 0, z_step), true)
		_torch(Vector3(11, 0, z_step), true)

	# --- Ambient world life: dark fortress vibe ---
	# Crows circling above (4 silhouettes high overhead). Black smoke from
	# the four corner braziers (siege fires never extinguished). Crimson
	# motes drifting near the throne - cursed dust from Tashmu's reign.
	var wl_bc: Node = get_node_or_null("/root/WorldLife")
	if wl_bc:
		wl_bc.spawn_bird_flock(self, 4, Vector3(0, 22, 0), size * 0.6)
		# Brazier smoke at corner towers
		for corner in [Vector3(-size / 2 + 2, 12, -size / 2 + 2), Vector3(size / 2 - 2, 12, -size / 2 + 2), Vector3(-size / 2 + 2, 12, size / 2 - 2), Vector3(size / 2 - 2, 12, size / 2 - 2)]:
			wl_bc.spawn_chimney_smoke(self, corner)
		# Cursed motes on throne (deep red, low energy)
		wl_bc.spawn_intro_motes(self, Vector3(0, 1.2, -size / 2 + 4), 5.0, Color(0.85, 0.15, 0.20, 1.0))

# ----------------------------------------------------------------
# ASHURIM — convergence town hub, market stalls, NPCs dispense quests
# ----------------------------------------------------------------
func _build_ashurim() -> void:
	# CONVERGENCE TOWN: walled medieval city with central plaza, market
	# stalls, square towers at corners, gates, banner-flagged streets,
	# and houses (Kenney castle kit). Player walks in through south gate.
	var tile := 4.0
	var grid := int(size / tile)
	for x in range(-grid, grid + 1):
		for z in range(-grid, grid + 1):
			var asset: String
			if abs(x) < 3 and abs(z) < 3:
				asset = "floor_tile_small_decorated.gltf.glb"  # central plaza
			elif abs(x) < 5 or abs(z) < 5:
				asset = "floor_tile_large.gltf.glb"  # main streets
			else:
				asset = "floor_dirt_large.gltf.glb"  # outer dirt
			_spawn(asset, Vector3(x * tile, 0, z * tile))
	# Outer wall ring (Kenney castle) -- 4 sides with gates on N + S
	# North wall
	for x_step in range(-int(size / 2) + 4, int(size / 2) - 3, 4):
		_cas("wall.glb", Vector3(x_step, 0, -size / 2 + 1))
	for x_step in range(-int(size / 2) + 4, int(size / 2) - 3, 4):
		_cas("wall.glb", Vector3(x_step, 0, size / 2 - 1))
	# East + West walls (rotated 90)
	for z_step in range(-int(size / 2) + 4, int(size / 2) - 3, 4):
		_cas("wall.glb", Vector3(-size / 2 + 1, 0, z_step), 90.0)
		_cas("wall.glb", Vector3(size / 2 - 1, 0, z_step), 90.0)
	# Main south gate (player entry from outside)
	_cas("wall-narrow-gate.glb", Vector3(0, 0, size / 2 - 1))
	_cas("gate.glb", Vector3(0, 0, size / 2 - 1))
	# North gate (to deeper regions)
	_cas("wall-narrow-gate.glb", Vector3(0, 0, -size / 2 + 1))
	# Four corner towers
	_cas("tower-square-base.glb", Vector3(-size / 2 + 2, 0, -size / 2 + 2))
	_cas("tower-square-mid-windows.glb", Vector3(-size / 2 + 2, 4, -size / 2 + 2))
	_cas("tower-square-arch.glb", Vector3(-size / 2 + 2, 8, -size / 2 + 2))
	_cas("tower-square-base.glb", Vector3(size / 2 - 2, 0, -size / 2 + 2))
	_cas("tower-square-mid-windows.glb", Vector3(size / 2 - 2, 4, -size / 2 + 2))
	_cas("tower-square-arch.glb", Vector3(size / 2 - 2, 8, -size / 2 + 2))
	_cas("tower-square-base.glb", Vector3(-size / 2 + 2, 0, size / 2 - 2))
	_cas("tower-square-mid-windows.glb", Vector3(-size / 2 + 2, 4, size / 2 - 2))
	_cas("tower-square-base.glb", Vector3(size / 2 - 2, 0, size / 2 - 2))
	_cas("tower-square-mid-windows.glb", Vector3(size / 2 - 2, 4, size / 2 - 2))
	# Houses arranged around the plaza (4 along each side)
	# Each "house" = square tower base with a roof
	for offset in [-12, 12]:
		# West & East row of houses
		for z_step in [-12, -4, 4, 12]:
			_cas("tower-square-base-color.glb", Vector3(offset, 0, z_step))
			_cas("tower-square-mid-door.glb", Vector3(offset, 4, z_step), 90.0 if offset > 0 else -90.0)
			_cas("tower-slant-roof.glb", Vector3(offset, 8, z_step))
	# Four banner flags fluttering over plaza (Ashurim crimson)
	var ashurim_red := Color(0.78, 0.18, 0.20, 1.0)
	_banner("flag.glb", Vector3(-3, 0, -3), ashurim_red, 0.0)
	_banner("flag.glb", Vector3(3, 0, -3), ashurim_red, 0.0)
	_banner("flag.glb", Vector3(-3, 0, 3), ashurim_red, 0.0)
	_banner("flag.glb", Vector3(3, 0, 3), ashurim_red, 0.0)
	# Long banner over the south gate + corner pennants
	_banner("flag-banner-long.glb", Vector3(0, 0, size / 2 - 4), ashurim_red)
	_banner("flag-pennant.glb", Vector3(-size / 2 + 2, 8, -size / 2 + 2), ashurim_red, 0.0, 0.55)
	_banner("flag-pennant.glb", Vector3(size / 2 - 2, 8, -size / 2 + 2), ashurim_red, 0.0, 0.55)
	# Market stalls at four plaza corners
	for offset in [Vector3(-7, 0, -7), Vector3(7, 0, -7), Vector3(-7, 0, 7), Vector3(7, 0, 7)]:
		_spawn("table_long_tablecloth_decorated_A.gltf.glb", offset)
		_spawn("plate_food_A.gltf.glb", offset + Vector3(0, 0.85, 0))
		_spawn("barrel_small.gltf.glb", offset + Vector3(2.5, 0, 0))
		_spawn("crates_stacked.gltf.glb", offset + Vector3(-2.5, 0, 0))
	# Lit lanterns around plaza for atmosphere
	for offset in [Vector3(-3, 0, -3), Vector3(3, 0, -3), Vector3(-3, 0, 3), Vector3(3, 0, 3)]:
		_torch(offset, true)
	# Trees inside the city walls (small park)
	for _i in range(6):
		var tx: float = randf_range(-size / 2 + 4, size / 2 - 4)
		var tz: float = randf_range(-size / 2 + 6, size / 2 - 6)
		# Skip walking corridors
		if abs(tx) < 6 and abs(tz) < 6: continue
		if abs(tx) > 9 or abs(tz) > 9: continue  # only inside the park area
		_nat(["tree_default.glb", "tree_detailed.glb"].pick_random(), Vector3(tx, 0, tz), randf() * 360.0, randf_range(2.5, 3.5))
	# Treasure chest as quest reward stash at the plaza center
	_spawn("chest_gold.glb", Vector3(0, 0, 0))

	# --- Ambient world life: bustling town vibe ---
	# Doves over the plaza (peaceful), chimney smoke from each of the 8
	# houses, and warm hearth motes around the lanterns to feel inhabited.
	var wl_ash: Node = get_node_or_null("/root/WorldLife")
	if wl_ash:
		wl_ash.spawn_bird_flock(self, 6, Vector3(0, 14, 0), size * 0.5)
		# Chimney smoke at the 4 corner towers (city watchfires) + 4 quadrant houses
		for corner in [Vector3(-size / 2 + 3, 8, -size / 2 + 3), Vector3(size / 2 - 3, 8, -size / 2 + 3), Vector3(-size / 2 + 3, 8, size / 2 - 3), Vector3(size / 2 - 3, 8, size / 2 - 3)]:
			wl_ash.spawn_chimney_smoke(self, corner)
		# Hearth motes - warm gold/amber - around the central plaza
		wl_ash.spawn_intro_motes(self, Vector3(0, 1.0, 0), 3.0, Color(1.0, 0.78, 0.4, 1.0))

# ----------------------------------------------------------------
# BABILIM — capital city, grand chapel layout
# ----------------------------------------------------------------
func _build_babilim() -> void:
	# CAPITAL CITY: Iron Crown's seat. Grand chapel down the spine,
	# city walls with hexagon towers, white-banner-flagged streets,
	# bridges crossing into the central cathedral. Wider, more ceremonial
	# than Ashurim. Multiple buildings around the chapel.
	var tile := 4.0
	var grid := int(size / tile)
	for x in range(-grid, grid + 1):
		for z in range(-grid, grid + 1):
			var asset: String
			if abs(x) <= 4 and z >= -16 and z <= 16:
				asset = "floor_tile_small_decorated.gltf.glb"  # holy nave
			elif abs(x) < 8 or abs(z) < 8:
				asset = "floor_tile_small.gltf.glb"  # courtyards
			else:
				asset = "floor_tile_large.gltf.glb"  # outer streets
			_spawn(asset, Vector3(x * tile, 0, z * tile))
	# City wall ring (bigger than ashurim)
	for x_step in range(-int(size / 2) + 4, int(size / 2) - 3, 4):
		_cas("wall.glb", Vector3(x_step, 0, -size / 2 + 1))
	for x_step in range(-int(size / 2) + 4, int(size / 2) - 3, 4):
		_cas("wall.glb", Vector3(x_step, 0, size / 2 - 1))
	for z_step in range(-int(size / 2) + 4, int(size / 2) - 3, 4):
		_cas("wall.glb", Vector3(-size / 2 + 1, 0, z_step), 90.0)
		_cas("wall.glb", Vector3(size / 2 - 1, 0, z_step), 90.0)
	# Hexagon main tower at the cardinal corners
	for corner in [Vector3(-size / 2 + 2, 0, -size / 2 + 2), Vector3(size / 2 - 2, 0, -size / 2 + 2), Vector3(-size / 2 + 2, 0, size / 2 - 2), Vector3(size / 2 - 2, 0, size / 2 - 2)]:
		_cas("tower-hexagon-base.glb", corner)
		_cas("tower-hexagon-mid.glb", corner + Vector3(0, 4, 0))
		_cas("tower-hexagon-top.glb", corner + Vector3(0, 8, 0))
		_cas("tower-hexagon-roof-secondary.glb", corner + Vector3(0, 11, 0))
	# Grand south gate (capital approach)
	_cas("wall-narrow-gate.glb", Vector3(0, 0, size / 2 - 1))
	_cas("gate.glb", Vector3(0, 0, size / 2 - 1))
	# Outer flags marking the holy city (white-gold for Babilim's
	# ceremonial palette)
	var babilim_gold := Color(0.95, 0.92, 0.78, 1.0)
	for offset in [-12, 12]:
		_banner("flag-pennant.glb", Vector3(offset, 0, size / 2 - 4), babilim_gold, 0.0, 0.55)
		_banner("flag-pennant.glb", Vector3(offset, 0, -size / 2 + 4), babilim_gold, 0.0, 0.55)
	# Twin colonnades down the spine (grand chapel)
	for z_step in range(-16, 17, 4):
		_spawn("pillar_decorated.gltf.glb", Vector3(-10, 0, z_step))
		_spawn("pillar_decorated.gltf.glb", Vector3(10, 0, z_step))
	# Houses lined up east + west of the chapel
	for z_step in [-12, -4, 4, 12]:
		# East side houses
		_cas("tower-square-base-color.glb", Vector3(-16, 0, z_step))
		_cas("tower-square-mid-windows.glb", Vector3(-16, 4, z_step))
		_cas("tower-slant-roof.glb", Vector3(-16, 8, z_step))
		# West side houses
		_cas("tower-square-base-color.glb", Vector3(16, 0, z_step))
		_cas("tower-square-mid-windows.glb", Vector3(16, 4, z_step))
		_cas("tower-slant-roof.glb", Vector3(16, 8, z_step))
	# Grand altar at north
	_spawn("table_long_decorated_A.gltf.glb", Vector3(0, 0.4, -size / 2 + 4))
	_spawn("candle_triple.gltf.glb", Vector3(-2, 1.3, -size / 2 + 4))
	_spawn("candle_triple.gltf.glb", Vector3(2, 1.3, -size / 2 + 4))
	_spawn("column.gltf.glb", Vector3(-4, 0.4, -size / 2 + 4))
	_spawn("column.gltf.glb", Vector3(4, 0.4, -size / 2 + 4))
	# Pews — stone benches indicated by barrier columns
	for z_step in [-8, -4, 0, 4, 8]:
		_spawn("barrier_column.gltf.glb", Vector3(-5, 0, z_step), 0.0)
		_spawn("barrier_column.gltf.glb", Vector3(5, 0, z_step), 180.0)
	# Bridges crossing into the inner sanctum (north end)
	_cas("bridge-straight.glb", Vector3(0, 0, -16), 90.0)
	# Many lit torches for grand illumination
	for z_step in range(-16, 17, 4):
		_torch(Vector3(-11, 0, z_step), true)
		_torch(Vector3(11, 0, z_step), true)
	# Long white banners marking the holy capital, waving in wind.
	_banner("flag-banner-long.glb", Vector3(-10, 0, 0), babilim_gold)
	_banner("flag-banner-long.glb", Vector3(10, 0, 0), babilim_gold)
	# Trees in the outer courtyards (city park)
	for _i in range(8):
		var tx: float = randf_range(-size / 2 + 4, size / 2 - 4)
		var tz: float = randf_range(-size / 2 + 6, size / 2 - 6)
		if abs(tx) < 12 or abs(tz) < 4: continue  # avoid the streets
		_nat(["tree_detailed.glb", "tree_default.glb"].pick_random(), Vector3(tx, 0, tz), randf() * 360.0, randf_range(2.5, 3.5))

	# --- Ambient world life: ceremonial capital ---
	# White doves circling the cathedral (sacred reading), incense smoke
	# rising from the altar candles, and divine motes (white-gold) over
	# the inner sanctum.
	var wl_bab: Node = get_node_or_null("/root/WorldLife")
	if wl_bab:
		wl_bab.spawn_bird_flock(self, 8, Vector3(0, 16, 0), size * 0.55)
		# Incense smoke at the altar candles
		wl_bab.spawn_chimney_smoke(self, Vector3(-2, 2.2, -size / 2 + 4))
		wl_bab.spawn_chimney_smoke(self, Vector3(2, 2.2, -size / 2 + 4))
		# Tower-top brazier smoke (8 towers, every other one)
		for z_step in [-8, 0, 8]:
			wl_bab.spawn_chimney_smoke(self, Vector3(-16, 11, z_step))
			wl_bab.spawn_chimney_smoke(self, Vector3(16, 11, z_step))
		# Divine motes - white-gold - over the inner sanctum
		wl_bab.spawn_intro_motes(self, Vector3(0, 1.5, -size / 2 + 4), 5.0, Color(1.0, 0.95, 0.75, 1.0))
