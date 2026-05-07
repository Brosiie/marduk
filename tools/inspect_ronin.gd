extends SceneTree

func _init():
	var packed: PackedScene = load("res://assets/characters/mixamo/classes/ronin.glb")
	if packed == null:
		print("ERROR: could not load ronin.glb")
		quit(1)
		return
	var inst: Node = packed.instantiate()
	print("=== ronin.glb structure ===")
	_dump(inst, 0)
	quit()

func _dump(n: Node, depth: int) -> void:
	var pad = "  ".repeat(depth)
	var extra = ""
	if n is AnimationPlayer:
		var ap := n as AnimationPlayer
		extra = " | libs=%s" % str(ap.get_animation_library_list())
	if n is Skeleton3D:
		var sk := n as Skeleton3D
		extra = " | bones=%d" % sk.get_bone_count()
	if n is MeshInstance3D:
		var mi := n as MeshInstance3D
		extra = " | mesh=%s aabb=%s" % [str(mi.mesh) if mi.mesh else "null", str(mi.get_aabb().size) if mi.mesh else ""]
	print("%s%s [%s]%s" % [pad, n.name, n.get_class(), extra])
	for c in n.get_children():
		_dump(c, depth + 1)
