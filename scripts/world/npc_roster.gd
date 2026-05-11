extends Node

# Autoload: zone-keyed NPC roster. Decouples NPC placement from .tscn
# files. Zones load and the roster looks up which NPCs belong here,
# then spawns them at the declared positions. Authors can add an NPC
# to a zone with one register() call in _ready instead of editing the
# zone's .tscn file (which is fragile for non-Godot-editor workflows).
#
# class_name removed: registered as `NPCRoster` autoload in
# project.godot. Subscribes to tree_changed via call_deferred so the
# initial scene + every subsequent scene_change_to_file load triggers
# a spawn pass.
#
# Roster entries are stored as a Dictionary keyed by zone_id (the
# region's metadata/region_id field). Each value is an Array of
# Dictionaries: {script_path, position, params}. The spawner reads
# this and instantiates each entry as a child of the scene root.
#
# Visibility / lifecycle guards happen at the NPC script level (eg
# SeventhMaster only renders when the right flags are set). The
# roster's job is JUST to drop the script-bearing node into the scene.

signal npc_spawned(zone_id: StringName, npc: Node)

# zone_id -> Array of {script_path: String, position: Vector3, params: Dictionary}
var _roster: Dictionary = {}
var _last_scene: Node = null

func _ready() -> void:
	# Register the canonical placements before the first scene loads.
	_register_canonical()
	# Subscribe to tree_changed so we catch every scene_change_to_file
	# transition. Defer to next frame so the new scene_root is settled.
	get_tree().tree_changed.connect(_on_tree_changed)
	call_deferred("_spawn_for_current_scene")

func _exit_tree() -> void:
	# Autoload teardown: disconnect to avoid get_tree() null spam.
	# Same pattern as WeatherDirector's exit guard.
	var t := get_tree()
	if t and t.tree_changed.is_connected(_on_tree_changed):
		t.tree_changed.disconnect(_on_tree_changed)

# ────────── Public API ──────────

# Register an NPC for a zone. Authors call this at startup (or from a
# class-name registry file) to declare "this NPC lives in this zone."
# Subsequent calls with the same script_path REPLACE the prior entry
# at that position; otherwise entries accumulate.
func register(zone_id: StringName, script_path: String, position: Vector3, params: Dictionary = {}) -> void:
	if not _roster.has(zone_id):
		_roster[zone_id] = []
	_roster[zone_id].append({
		"script_path": script_path,
		"position": position,
		"params": params,
	})

func entries_for(zone_id: StringName) -> Array:
	return _roster.get(zone_id, [])

# ────────── Canonical placements ──────────

func _register_canonical() -> void:
	# The Seventh Master lives at the Sun Gate. The script's
	# visibility-gate handles whether he's actually shown.
	register(&"sun_gate",
		"res://scripts/npcs/seventh_master_npc.gd",
		Vector3(0, 1.0, 0))
	# Future additions go here as one-liners. The roster is the single
	# source of truth for "which NPCs belong in which zones" once the
	# game ships in earnest.

# ────────── Scene-change handling ──────────

func _on_tree_changed() -> void:
	if not is_inside_tree():
		return
	# Detect actual scene_root change (not just child additions).
	var current: Node = get_tree().current_scene if get_tree() else null
	if current == _last_scene:
		return
	_last_scene = current
	call_deferred("_spawn_for_current_scene")

func _spawn_for_current_scene() -> void:
	var scene: Node = get_tree().current_scene if get_tree() else null
	if scene == null:
		return
	# Read zone_id from the scene root's metadata. Region scenes use
	# metadata/region_id; intros may or may not have one. No metadata
	# = no spawns, which is fine.
	var zone_id: StringName = StringName(scene.get_meta("region_id", ""))
	if zone_id == &"":
		return
	var entries: Array = entries_for(zone_id)
	if entries.is_empty():
		return
	for entry in entries:
		_spawn_entry(scene, zone_id, entry)

func _spawn_entry(scene: Node, zone_id: StringName, entry: Dictionary) -> void:
	var script_path: String = String(entry.get("script_path", ""))
	if script_path == "" or not ResourceLoader.exists(script_path):
		return
	var script: GDScript = load(script_path)
	if script == null:
		return
	# Avoid double-spawning if the scene was reloaded and the roster
	# fires again. Each script-path gets at most one instance per zone
	# entry. Scan existing children for a matching node and skip.
	for c in scene.get_children():
		if c.get_script() == script:
			return
	# All current canonical NPCs extend CharacterBody3D via the NPC
	# base. Use that as the spawn type. NPCs that need different bases
	# can opt out via a base_type param.
	var base_type: String = String(entry.get("params", {}).get("base_type", "CharacterBody3D"))
	var npc: Node = _make_node_of_type(base_type)
	if npc == null:
		return
	npc.set_script(script)
	npc.name = script_path.get_file().get_basename().capitalize().replace("_", "")
	# Apply any params declared in the roster (eg fled_from for refugees)
	for k in (entry.get("params", {}) as Dictionary).keys():
		if k == "base_type":
			continue
		npc.set(k, (entry["params"] as Dictionary)[k])
	scene.add_child(npc)
	# Position AFTER add_child so global_position resolves correctly.
	if npc is Node3D:
		(npc as Node3D).global_position = Vector3(entry.get("position", Vector3.ZERO))
	npc_spawned.emit(zone_id, npc)

func _make_node_of_type(type_name: String) -> Node:
	# Whitelist the node types the roster can spawn. Adding new types
	# is intentional; we don't want a typo to spawn an Object instead.
	match type_name:
		"CharacterBody3D": return CharacterBody3D.new()
		"Node3D":          return Node3D.new()
		"Area3D":          return Area3D.new()
		_:                 return null
