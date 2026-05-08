class_name AnimationLibraryLoader
extends RefCounted

# Progress signals so LoadingScreen can show a slot-by-slot bar.
signal slot_loaded(current: int, total: int, slot_name: String)
signal apply_complete(bound: int, missing: int)

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
# OFF by default because verbose loader logs slowed splash dismissal
# from <1s to 60+s on first run with 36 slots x 4 texture conversions.
const VERBOSE_MISSING := false

# Static path -> Animation cache. The loader is RefCounted so a fresh
# instance is created per character spawn, but the cache lives at
# script-level so subsequent characters reuse extracted Animations.
# Going from 'load + instantiate + queue_free per slot per character'
# to 'load + instantiate + queue_free ONCE, then cache hit forever' is
# the difference between 30+s of boot stall and ~2s.
static var _ANIM_CACHE: Dictionary = {}

# Public API. Async coroutine that loads slots one at a time, yielding
# to the renderer between each. Caller can await the result if it
# wants to know when binding is done; ignoring is fine too.
#
#   await AnimationLibraryLoader.new().apply(player, "class", &"ronin")
#
# Yielding between slot loads is THE fix for "loading screen never
# appears" -- on M-series Macs each .glb load takes ~250-400ms and
# without yielding the renderer is starved through all 36 slots.
# With one yield per slot, the loading screen paints fresh frames
# every ~300ms and the world feels responsive instead of frozen.
func apply(character_root: Node, role: String, role_id: StringName) -> void:
	var anim_player: AnimationPlayer = _find_anim_player(character_root)
	if anim_player == null:
		# Mixamo character .glb files ship as T-pose only (no AnimationPlayer).
		# We create one so the merged library has a home. Parent it under the
		# character root so anim playback finds the skeleton via NodePath
		# resolution. Without this, characters like Kachujin would T-pose
		# despite having animations on disk.
		anim_player = AnimationPlayer.new()
		anim_player.name = "AnimationPlayer"
		var glb_root := _find_glb_root(character_root)
		if glb_root != null:
			glb_root.add_child(anim_player)
		else:
			character_root.add_child(anim_player)
		if VERBOSE_MISSING:
			print("[AnimLoader] Created AnimationPlayer for %s (Mixamo T-pose .glb)" % character_root.name)

	var lib := AnimationLibrary.new()
	var slot_map: Dictionary = _build_slot_map(role, role_id)
	var bound: Array[String] = []
	var missing: Array[String] = []

	# Process slots one at a time, yielding to the renderer between
	# each. This is what unblocks the loading screen — the renderer
	# gets a frame after every slot, so it can paint the LoadingScreen
	# overlay, the bg shader pulses, the tip text rotates, etc. while
	# we crank through .glb loads in the background.
	var tree := Engine.get_main_loop() as SceneTree
	var slot_keys: Array = slot_map.keys()
	for i in range(slot_keys.size()):
		var slot = slot_keys[i]
		var rel_path: String = slot_map[slot]
		var abs_path := "res://assets/animations/%s" % rel_path
		var anim := _load_animation_from_fbx(abs_path)
		if anim != null:
			lib.add_animation(slot, anim)
			bound.append(String(slot))
		else:
			missing.append(String(slot))
		# Emit progress so callers (LoadingScreen) can render a bar
		emit_signal("slot_loaded", i + 1, slot_keys.size(), String(slot))
		# Yield to the renderer every few slots; balances 'fast load'
		# vs 'visible progress'. Yielding every slot is too slow on
		# M-series; every 3 keeps the loop tight.
		if tree and i % 3 == 2:
			await tree.process_frame

	# Merge / replace the named library on the player.
	if anim_player.has_animation_library(ANIM_LIB_NAME):
		anim_player.remove_animation_library(ANIM_LIB_NAME)
	anim_player.add_animation_library(ANIM_LIB_NAME, lib)

	# Final diagnostic line
	var embedded_count: int = 0
	for embedded_lib_name in anim_player.get_animation_library_list():
		if embedded_lib_name == ANIM_LIB_NAME:
			continue
		var elib := anim_player.get_animation_library(embedded_lib_name)
		embedded_count += elib.get_animation_list().size()
	print("[AnimLoader] %s/%s: %d bound, %d missing | embedded: %d" % [role, role_id, bound.size(), missing.size(), embedded_count])
	if VERBOSE_MISSING and missing.size() > 0:
		print("  missing slots: %s" % ", ".join(missing))
	emit_signal("apply_complete", bound.size(), missing.size())

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

# Find the parent we should add the AnimationPlayer under so anim track
# NodePaths resolve correctly.
#
# Mixamo animation .fbx files reference bones via NodePath like
#   "RootNode/Skeleton3D:mixamorig_Hips"
# That path is relative to the AnimationPlayer's parent. So for the path
# to resolve, AnimationPlayer must sit at the SAME level as "RootNode" --
# i.e. as a sibling of RootNode, child of the imported scene's outer root.
#
# Mixamo .glb structure after fbx2gltf conversion:
#   Root Scene  (the imported scene root - PackedScene root)
#     RootNode             <- the path "RootNode/..." starts here
#       Skeleton3D
#         <mesh>
#     AnimationPlayer      <- this needs to live HERE (Root Scene's child)
#
# So we walk: Skeleton3D -> parent (RootNode) -> parent (Root Scene), and
# parent the AnimationPlayer to "Root Scene".
func _find_glb_root(node: Node) -> Node:
	var skel := _find_skeleton(node)
	if skel == null:
		return null
	var rootnode := skel.get_parent()       # RootNode
	if rootnode == null:
		return null
	var scene_root := rootnode.get_parent() # Root Scene
	if scene_root == null:
		# Skeleton3D is at the very top of the instance; fall back to it.
		return rootnode
	return scene_root

func _find_skeleton(node: Node) -> Skeleton3D:
	if node is Skeleton3D:
		return node
	for child in node.get_children():
		var found := _find_skeleton(child)
		if found != null:
			return found
	return null

# Load a Mixamo .fbx and return the FIRST embedded Animation resource,
# or null if the file is missing / un-importable.
#
# CACHED: extracted Animations are stored in _ANIM_CACHE so the
# expensive load+instantiate cycle runs once per path, not once per
# (path x character). On the second character spawn (mob, boss,
# re-loaded scene) every .glb is a free dictionary lookup.
func _load_animation_from_fbx(path: String) -> Animation:
	if _ANIM_CACHE.has(path):
		return _ANIM_CACHE[path]
	if not ResourceLoader.exists(path):
		_ANIM_CACHE[path] = null
		return null
	var packed: PackedScene = load(path)
	if packed == null:
		_ANIM_CACHE[path] = null
		return null
	var inst: Node = packed.instantiate()
	if inst == null:
		_ANIM_CACHE[path] = null
		return null
	var ap: AnimationPlayer = _find_anim_player(inst)
	if ap == null:
		inst.queue_free()
		_ANIM_CACHE[path] = null
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
	_ANIM_CACHE[path] = anim
	return anim
