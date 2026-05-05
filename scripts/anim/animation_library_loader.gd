class_name AnimationLibraryLoader
extends RefCounted

# AnimationLibraryLoader — pulls Mixamo .fbx animation files off disk,
# extracts their Animation resources, and merges them into a character's
# AnimationPlayer under canonical slot names from AnimationRegistry.
#
# Usage:
#   var loader := AnimationLibraryLoader.new()
#   loader.apply(player_node, "class", &"ronin")
#
# Where player_node has an AnimationPlayer descendant (Player or any
# CharacterBody3D mesh).
#
# Why this is a RefCounted helper, not an autoload:
# - It's stateless except for the one library it builds per call.
# - Different characters need different anim sets, so the loader is
#   spawn-time, not session-time.
#
# All loads are guarded so missing .fbx files don't crash the game; they
# just leave that slot unbound, and gameplay code is expected to fall
# back to whatever the spawned mesh's own embedded AnimationPlayer
# already has (player.gd already does this via ANIM_ALIASES).

const ANIM_LIB_NAME := &"marduk"  # all merged anims live under "marduk/<slot>"

# True = print a single warning per missing slot (debug). False = silent.
const VERBOSE_MISSING := true

func apply(character_root: Node, role: String, role_id: StringName) -> void:
	var anim_player: AnimationPlayer = _find_anim_player(character_root)
	if anim_player == null:
		if VERBOSE_MISSING:
			push_warning("[AnimLoader] No AnimationPlayer under %s; skipping %s/%s" % [character_root.name, role, role_id])
		return

	var lib := AnimationLibrary.new()
	var slot_map: Dictionary = _build_slot_map(role, role_id)

	for slot in slot_map.keys():
		var rel_path: String = slot_map[slot]
		var abs_path := "res://assets/animations/%s" % rel_path
		var anim := _load_animation_from_fbx(abs_path)
		if anim != null:
			lib.add_animation(slot, anim)
		elif VERBOSE_MISSING:
			# downgrade to one-line print so missing slots don't spam
			print_verbose("[AnimLoader] missing slot %s -> %s" % [slot, rel_path])

	# Merge / replace the named library on the player.
	if anim_player.has_animation_library(ANIM_LIB_NAME):
		anim_player.remove_animation_library(ANIM_LIB_NAME)
	anim_player.add_animation_library(ANIM_LIB_NAME, lib)

# Returns shared_slots merged with role-specific slots; role-specific wins.
# AnimationRegistry is registered as an autoload in project.godot, so it
# is reachable from any script via /root/AnimationRegistry.
func _build_slot_map(role: String, role_id: StringName) -> Dictionary:
	var tree := Engine.get_main_loop() as SceneTree
	if tree == null:
		return {}
	var registry: Node = tree.root.get_node_or_null("AnimationRegistry")
	if registry == null:
		push_warning("[AnimLoader] AnimationRegistry autoload missing")
		return {}
	var merged: Dictionary = (registry.get_shared_slot_map() as Dictionary).duplicate()
	var role_map: Dictionary
	match role:
		"class": role_map = registry.get_class_slot_map(role_id)
		"mob":   role_map = registry.get_mob_slot_map(role_id)
		"boss":  role_map = registry.get_boss_slot_map(role_id)
		"npc":   role_map = registry.get_npc_slot_map(role_id)
		_:       role_map = {}
	for k in role_map.keys():
		merged[k] = role_map[k]
	return merged

# Recursively find the first AnimationPlayer under `node`.
func _find_anim_player(node: Node) -> AnimationPlayer:
	if node is AnimationPlayer:
		return node
	for child in node.get_children():
		var found := _find_anim_player(child)
		if found != null:
			return found
	return null

# Load a Mixamo .fbx and return the FIRST embedded Animation resource,
# or null if the file is missing / un-importable.
#
# Mixamo anims-without-skin import as PackedScene whose AnimationPlayer
# carries one or more clips. The clip we want is usually the only one,
# named "mixamo.com" by default.
func _load_animation_from_fbx(path: String) -> Animation:
	if not ResourceLoader.exists(path):
		return null
	var packed: PackedScene = load(path)
	if packed == null:
		return null
	var inst: Node = packed.instantiate()
	if inst == null:
		return null
	var ap: AnimationPlayer = _find_anim_player(inst)
	if ap == null:
		inst.queue_free()
		return null
	var anim: Animation = null
	for lib_name in ap.get_animation_library_list():
		var lib := ap.get_animation_library(lib_name)
		for clip_name in lib.get_animation_list():
			anim = lib.get_animation(clip_name)
			break
		if anim != null:
			break
	inst.queue_free()
	return anim
