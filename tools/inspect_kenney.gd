extends SceneTree

func _init() -> void:
	var paths := [
		"res://assets/environments/kenney_castle/wall.glb",
		"res://assets/environments/kenney_castle/tower-square-base-color.glb",
		"res://assets/environments/kenney_nature/tree_default.glb",
		"res://assets/environments/kenney_nature/grass.glb",
		"res://assets/environments/kaykit_dungeon/Assets/gltf/floor_tile_large.gltf.glb",
		"res://assets/environments/kaykit_dungeon/Assets/gltf/wall_arched.gltf.glb",
		"res://assets/environments/kaykit_dungeon/Assets/gltf/column.gltf.glb",
		"res://assets/environments/kaykit_dungeon/Assets/gltf/pillar.gltf.glb",
	]
	for p in paths:
		print("\n=== %s ===" % p)
		if not ResourceLoader.exists(p):
			print("  (missing on disk)")
			continue
		var packed: PackedScene = load(p)
		var inst: Node = packed.instantiate()
		_dump(inst, 0)
	quit()

func _dump(n: Node, depth: int) -> void:
	var pad := "  ".repeat(depth)
	var extra := ""
	if n is StaticBody3D:
		extra = " <-- StaticBody3D"
	elif n is CollisionShape3D:
		var cs := n as CollisionShape3D
		extra = " <-- CollisionShape3D shape=%s" % str(cs.shape)
	elif n is MeshInstance3D:
		var mi := n as MeshInstance3D
		extra = " (mesh)"
	print("%s%s [%s]%s" % [pad, n.name, n.get_class(), extra])
	for c in n.get_children():
		_dump(c, depth + 1)
