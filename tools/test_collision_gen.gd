extends SceneTree

# Minimal smoke test for the new auto-collision logic. Spawns three
# representative props (wall, tree, grass), runs _ensure_collision /
# _strip_colliders, then audits whether collision was added.
#
# Confirms the pattern matching + auto-collision works without booting
# a full scene + autoloads.

func _init() -> void:
	# Load a few real assets and instantiate them
	var paths := {
		"wall (structural)":   "res://assets/environments/kenney_castle/wall.glb",
		"tree (structural)":   "res://assets/environments/kenney_nature/tree_default.glb",
		"grass (decor)":       "res://assets/environments/kenney_nature/grass.glb",
		"flag (decor)":        "res://assets/environments/kenney_castle/flag.glb",
	}
	for label in paths:
		var path: String = paths[label]
		print("\n=== %s -> %s ===" % [label, path])
		if not ResourceLoader.exists(path):
			print("  (missing)")
			continue
		var packed: PackedScene = load(path)
		var inst: Node3D = packed.instantiate()
		root.add_child(inst)
		var asset_name := path.get_file()
		var is_decor: bool = _is_decor(asset_name)
		print("  is_decor: %s" % str(is_decor))
		if is_decor:
			# (no-op for this test; strip would just disable nothing)
			pass
		else:
			_ensure_collision(inst)
		# Audit
		var bodies := _count_static_bodies(inst)
		var shapes := _count_collision_shapes(inst)
		print("  StaticBody3D after: %d, CollisionShape3D after: %d" % [bodies, shapes])
		inst.queue_free()
	quit()

# Mirrored from zone_composer.gd
const DECOR_PATTERNS := [
	"grass", "flower", "mushroom", "plant_bush",
	"crops_bamboo", "flag", "rubble_small", "sword_shield_broken",
]

func _is_decor(asset: String) -> bool:
	var lower := asset.to_lower()
	for pat in DECOR_PATTERNS:
		if lower.find(pat) != -1:
			return true
	return false

func _ensure_collision(root_node: Node) -> void:
	for mi in _find_mesh_instances(root_node):
		if _has_static_body_ancestor(mi, root_node):
			continue
		if mi.mesh == null:
			continue
		mi.create_trimesh_collision()

func _find_mesh_instances(node: Node) -> Array[MeshInstance3D]:
	var out: Array[MeshInstance3D] = []
	if node is MeshInstance3D:
		out.append(node)
	for c in node.get_children():
		out.append_array(_find_mesh_instances(c))
	return out

func _has_static_body_ancestor(node: Node, stop_at: Node) -> bool:
	var p := node.get_parent()
	while p != null and p != stop_at:
		if p is StaticBody3D:
			return true
		p = p.get_parent()
	return false

func _count_static_bodies(node: Node) -> int:
	var n: int = 1 if node is StaticBody3D else 0
	for c in node.get_children():
		n += _count_static_bodies(c)
	return n

func _count_collision_shapes(node: Node) -> int:
	var n: int = 1 if node is CollisionShape3D else 0
	for c in node.get_children():
		n += _count_collision_shapes(c)
	return n
