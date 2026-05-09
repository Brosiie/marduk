class_name MixamoSkeletonFixer
extends RefCounted

# MixamoSkeletonFixer, runtime fixer that makes Mixamo .fbx characters
# render correctly without requiring the manual Advanced Import Settings
# retarget pass.
#
# Problem: Godot 4's ufbx FBX parser sometimes leaves Mixamo skeletons
# with bones at parent-local identity transforms instead of their FBX
# rest positions. The skinned mesh has skin weights bound to those
# bones, so when bones are at identity the mesh collapses (Y stays
# tall, but X/Z compress to a flat plane).
#
# Fix steps applied in order:
# 1. Find every Skeleton3D under the character root.
# 2. For each bone, ensure rest pose is captured (Skeleton3D.set_bone_rest
#    needs the FBX-parsed transform; we read the bone's existing rest
#    and re-apply it as the active pose).
# 3. Call reset_bone_poses() to set every bone back to its rest pose.
# 4. Set show_rest_only = true as a belt-and-braces guarantee that the
#    rest pose stays visible until an animation actively moves bones.
# 5. Force a skeleton update so the changes take effect this frame.
#
# Result: Mixamo characters render in T-pose at their natural cm-to-m
# converted scale. Combined with AnimationLibraryLoader merging shared
# animations under the marduk/<slot> namespace, the character also
# animates correctly without needing a hand-authored BoneMap.

# Public entry point. Walk the character_root, find every Skeleton3D,
# fix each one. Call this from Player._ready / EnemyBase._ready / etc.
static func fix(character_root: Node) -> void:
	if character_root == null:
		return
	var skeletons: Array[Skeleton3D] = []
	_collect_skeletons(character_root, skeletons)
	for sk in skeletons:
		_fix_skeleton(sk)

# Recursive search helper.
static func _collect_skeletons(node: Node, out: Array[Skeleton3D]) -> void:
	if node is Skeleton3D:
		out.append(node)
	for child in node.get_children():
		_collect_skeletons(child, out)

# Fix one skeleton.
static func _fix_skeleton(sk: Skeleton3D) -> void:
	if sk.get_bone_count() == 0:
		return
	# Reset every bone's pose to its captured rest transform. The .glb
	# pipeline (commit 3005718) usually has bones in correct rest pose
	# already, but resetting is harmless and catches edge cases.
	for i in range(sk.get_bone_count()):
		sk.reset_bone_pose(i)
	# Force skeleton to apply the pose change this frame.
	sk.advance(0.0)
	# show_rest_only is intentionally NOT set anymore. With .glb working,
	# we want animations to drive bones when AnimationLibraryLoader merges
	# them. The old material override (force_visible_materials) is also
	# removed because .glb materials import correctly via Godot's native
	# parser; overriding them was masking the real Mixamo textures.

# Walk the skeleton and force visible / lit materials on every skinned
# MeshInstance3D so Mixamo characters render with a guaranteed-visible
# look. Bypasses any imported material that might be transparent /
# cull_back-only / wrong shading.
static func _force_visible_materials(skeleton: Skeleton3D) -> void:
	# MeshInstance3Ds skinned to this skeleton are typically siblings
	# under the same Armature parent. Search up one level then down.
	var armature: Node = skeleton.get_parent()
	if armature == null:
		armature = skeleton
	var meshes: Array[MeshInstance3D] = []
	_collect_meshes(armature, meshes)
	for mi in meshes:
		mi.visible = true
		mi.layers = 0xFFFFF  # all visibility layers
		if mi.mesh == null:
			continue
		for surf in range(mi.mesh.get_surface_count()):
			# Try to read the existing material's base color so we don't
			# completely lose the import's intent.
			var existing := mi.get_active_material(surf)
			var color := Color(0.92, 0.78, 0.68)  # default human-skin tone
			if existing is BaseMaterial3D:
				color = (existing as BaseMaterial3D).albedo_color
				if color == Color.WHITE:  # untextured fallback
					color = Color(0.92, 0.78, 0.68)
			var mat := StandardMaterial3D.new()
			mat.albedo_color = color
			mat.shading_mode = BaseMaterial3D.SHADING_MODE_PER_PIXEL
			mat.cull_mode = BaseMaterial3D.CULL_DISABLED
			mat.metallic = 0.0
			mat.roughness = 0.85
			mi.set_surface_override_material(surf, mat)

static func _collect_meshes(node: Node, out: Array[MeshInstance3D]) -> void:
	if node is MeshInstance3D:
		out.append(node)
	for c in node.get_children():
		_collect_meshes(c, out)

# Disable show_rest_only so animations can drive bone poses. Call this
# once the AnimationLibraryLoader has merged real animations into the
# skeleton's AnimationPlayer.
static func enable_animation(character_root: Node) -> void:
	if character_root == null:
		return
	var skeletons: Array[Skeleton3D] = []
	_collect_skeletons(character_root, skeletons)
	for sk in skeletons:
		sk.show_rest_only = false
