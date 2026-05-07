extends SceneTree

# Boot Sword-Vow Ruins and audit collision: count StaticBody3Ds /
# CollisionShape3Ds vs MeshInstance3Ds in the geometry subtree. Confirms
# auto-collision is firing on real spawned props.

func _init() -> void:
	var packed: PackedScene = load("res://scenes/world/intros/sword_vow_ruins.tscn")
	var inst: Node = packed.instantiate()
	root.add_child(inst)
	# Defer for one frame so deferred _ready calls fire (zone_composer
	# uses call_deferred to spawn its props).
	process_frame.connect(_after_frame.bind(inst))

var _frames: int = 0

func _after_frame(inst: Node) -> void:
	_frames += 1
	# Wait a few frames so call_deferred spawns finish
	if _frames < 6:
		return
	var geometry := inst.get_node_or_null("Geometry")
	if geometry == null:
		print("ERROR: no Geometry node in scene")
		quit(1)
		return
	var stats := {
		"meshes": 0,
		"static_bodies": 0,
		"collision_shapes": 0,
		"meshes_without_collision": 0,
		"sample_with_collision": [],
		"sample_without_collision": [],
	}
	_count(geometry, geometry, stats)
	print("\n=== Collision audit (Geometry subtree) ===")
	print("MeshInstance3D total:        %d" % stats.meshes)
	print("StaticBody3D total:          %d" % stats.static_bodies)
	print("CollisionShape3D total:      %d" % stats.collision_shapes)
	print("Meshes WITHOUT collision:    %d" % stats.meshes_without_collision)
	print("\nSample with collision:")
	for s in stats.sample_with_collision:
		print("  + %s" % s)
	print("\nSample without collision (should mostly be decor):")
	for s in stats.sample_without_collision:
		print("  - %s" % s)
	quit()

func _count(node: Node, root_node: Node, stats: Dictionary) -> void:
	if node is MeshInstance3D:
		stats.meshes += 1
		if _has_static_body_ancestor(node, root_node):
			if stats.sample_with_collision.size() < 8:
				stats.sample_with_collision.append(_path_under(node, root_node))
		else:
			stats.meshes_without_collision += 1
			if stats.sample_without_collision.size() < 8:
				stats.sample_without_collision.append(_path_under(node, root_node))
	elif node is StaticBody3D:
		stats.static_bodies += 1
	elif node is CollisionShape3D:
		stats.collision_shapes += 1
	for c in node.get_children():
		_count(c, root_node, stats)

func _has_static_body_ancestor(node: Node, stop_at: Node) -> bool:
	var p := node.get_parent()
	while p != null and p != stop_at:
		if p is StaticBody3D:
			return true
		p = p.get_parent()
	return false

func _path_under(node: Node, root_node: Node) -> String:
	var parts: Array[String] = []
	var n: Node = node
	while n != null and n != root_node:
		parts.push_front(n.name)
		n = n.get_parent()
	return "/".join(parts)
