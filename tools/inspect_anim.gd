extends SceneTree

func _init() -> void:
	# Inspect a source animation .glb to see where AnimationPlayer lives
	# and what NodePaths the tracks use. This tells us where we need to
	# place the runtime-created AnimationPlayer.
	var path := "res://assets/animations/shared/locomotion/idle.glb"
	var packed: PackedScene = load(path)
	if packed == null:
		print("ERROR: could not load %s" % path)
		quit(1)
		return
	var inst: Node = packed.instantiate()
	print("=== %s structure ===" % path)
	_dump(inst, 0)
	# Now find first AnimationPlayer and report track paths for first anim
	var ap := _find_ap(inst)
	if ap:
		print("\n=== AnimationPlayer location: %s ===" % ap.get_path())
		for lib_name in ap.get_animation_library_list():
			var lib := ap.get_animation_library(lib_name)
			for clip_name in lib.get_animation_list():
				var anim := lib.get_animation(clip_name)
				print("\nAnimation %s/%s: %d tracks" % [lib_name, clip_name, anim.get_track_count()])
				for i in range(min(8, anim.get_track_count())):
					print("  track[%d] path = %s" % [i, str(anim.track_get_path(i))])
				break
			break
	quit()

func _dump(n: Node, depth: int) -> void:
	var pad = "  ".repeat(depth)
	var extra = ""
	if n is AnimationPlayer:
		extra = " <-- AnimationPlayer"
	print("%s%s [%s]%s" % [pad, n.name, n.get_class(), extra])
	for c in n.get_children():
		_dump(c, depth + 1)

func _find_ap(node: Node) -> AnimationPlayer:
	if node is AnimationPlayer:
		return node
	for child in node.get_children():
		var found := _find_ap(child)
		if found != null:
			return found
	return null
