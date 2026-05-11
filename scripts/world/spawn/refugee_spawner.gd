extends Node3D
class_name RefugeeSpawner

# Reactive spawner that creates Refugee NPCs at child Marker3D
# positions when a faction conflict pair reaches SKIRMISH+. Despawns
# them when the conflict cools to COLD. Place one in each safe city
# scene (Ashurim, Babilim, Lapis Bay, the Cradle); the spawner reads
# FactionConflictRegistry and the world reacts automatically.
#
# Child markers carry a `fled_from` metadata field naming which
# faction's territory they escaped from. The Refugee's greeting line
# is keyed to that faction.
#
# Density tiers:
#   COLD / TENSE: 0 refugees, no one has fled yet
#   SKIRMISH:     refugee_count_skirmish (default 1, the first wave)
#   OPEN_WAR:     refugee_count_open_war (fill the markers)
#
# The spawner is the THIRD pattern for FactionConflictRegistry
# consumers (after dialog + quest gates + mob pools). Different from
# the mob spawner: refugees aren't randomly picked, they have stable
# positions and each one is keyed to a specific faction's collapse.

@export var pair_key: StringName = &"druid_vs_inquisition"
@export var refugee_count_skirmish: int = 1
@export var refugee_count_open_war: int = 3

const REFUGEE_SCRIPT_PATH := "res://scripts/npcs/refugee_npc.gd"

var _spawned: Array[Node] = []
var _markers: Array[Marker3D] = []

func _ready() -> void:
	add_to_group("refugee_spawner")
	# Collect Marker3D children as spawn slots. Authors can drop in any
	# number of markers; the spawner uses up to the configured density
	# for the current state.
	for c in get_children():
		if c is Marker3D:
			_markers.append(c)
	# Subscribe to conflict state changes. Spawn population is
	# recomputed on every transition.
	call_deferred("_wire_conflict_signal")
	# Initial pass: if conflict is already hot when the scene loads,
	# refugees should already be here.
	call_deferred("_refresh_population")

func _wire_conflict_signal() -> void:
	var fcr: Node = get_node_or_null("/root/FactionConflictRegistry")
	if fcr == null or not fcr.has_signal("pair_state_changed"):
		return
	var cb := Callable(self, "_on_pair_state_changed")
	if not fcr.pair_state_changed.is_connected(cb):
		fcr.pair_state_changed.connect(cb)

func _on_pair_state_changed(changed_pair: StringName, _new_state: String, _old_state: String) -> void:
	if changed_pair != pair_key:
		return  # not our pair
	_refresh_population()

func _refresh_population() -> void:
	var target_count: int = _target_count_for_state()
	# Prune freed instances first
	_spawned = _spawned.filter(func(n): return is_instance_valid(n))
	# Already at target: nothing to do
	if _spawned.size() == target_count:
		return
	# Need fewer: despawn the most recently spawned (LIFO so older
	# refugees stay put longer, which reads as "they're still here").
	while _spawned.size() > target_count:
		var n: Node = _spawned.pop_back()
		if is_instance_valid(n):
			n.queue_free()
	# Need more: spawn into the next unused markers.
	while _spawned.size() < target_count and _spawned.size() < _markers.size():
		var marker: Marker3D = _markers[_spawned.size()]
		_spawn_at(marker)

func _target_count_for_state() -> int:
	var fcr: Node = get_node_or_null("/root/FactionConflictRegistry")
	if fcr == null or not fcr.has_method("get_state"):
		return 0
	var state: String = String(fcr.get_state(pair_key))
	match state:
		"OPEN_WAR": return min(refugee_count_open_war, _markers.size())
		"SKIRMISH": return min(refugee_count_skirmish, _markers.size())
		_:          return 0  # COLD / TENSE / unknown

func _spawn_at(marker: Marker3D) -> void:
	var fled_from: StringName = StringName(marker.get_meta("fled_from", ""))
	var refugee: CharacterBody3D = CharacterBody3D.new()
	var script: GDScript = load(REFUGEE_SCRIPT_PATH)
	if script == null:
		return
	refugee.set_script(script)
	# Set fled_from BEFORE adding to the tree so the refugee's _ready
	# can pick the right line on first frame.
	refugee.set("fled_from", fled_from)
	refugee.name = "Refugee_%s_%d" % [String(fled_from), _spawned.size()]
	get_tree().current_scene.add_child(refugee)
	refugee.global_position = marker.global_position
	_spawned.append(refugee)
