extends Node3D
class_name DungeonInstance

# A dungeon run instance. Resets all mob spawners, restocks loot, respawns the
# boss when entered fresh. Multiple parties can run different instances of the
# same Dungeon resource simultaneously (each gets their own DungeonInstance).
#
# Lifecycle:
#   1. Player approaches dungeon entrance.
#   2. ZoneLoader spawns a fresh DungeonInstance (server-allocated in Phase 4).
#   3. on_enter() resets all spawners, sets in_progress = true.
#   4. Boss dies -> mark cleared -> set Dungeon.completion_flag in SaveFlags.
#   5. Party leaves OR wipes -> instance lingers for grace period, then despawns.
#   6. Re-entering re-runs on_enter() -> full reset.

const MAX_PARTY_IN_DUNGEON := 4  # Bond's spec
const ABANDON_GRACE_SECONDS := 300.0  # 5min grace before instance recycles

signal dungeon_cleared(dungeon: Dungeon)
signal dungeon_wiped
signal dungeon_reset

@export var dungeon: Dungeon
@export var instance_id: StringName = &""
@export var party_id: StringName = &""

var _spawners: Array = []
var _boss_node: Node = null
var _in_progress: bool = false
var _last_player_seen_at: float = 0.0
var _abandon_check_t: float = 0.0

func _ready() -> void:
	_collect_spawners()
	on_enter()

func _process(delta: float) -> void:
	_abandon_check_t += delta
	if _abandon_check_t >= 5.0:
		_abandon_check_t = 0.0
		_check_abandonment()

func _collect_spawners() -> void:
	_spawners = get_tree().get_nodes_in_group("spawner")

# === Lifecycle ===
func on_enter() -> void:
	_in_progress = true
	dungeon_reset.emit()
	# Reset every spawner: respawn fresh mobs, clear cooldowns
	for s: Spawner in _spawners:
		s.enabled = true
		# Clear current alive mobs (they'll spawn fresh)
		for e in s.get("_alive") if s.get("_alive") else []:
			if is_instance_valid(e):
				e.queue_free()
		s.set("_alive", [])
		s.set("_next_respawn_at", 0.0)
	# Spawn the boss
	_spawn_boss()

func _spawn_boss() -> void:
	if not dungeon or dungeon.boss_id == &"":
		return
	# Real impl: instantiate the boss scene with BossRegistry data
	var boss_scene := preload("res://scenes/enemies/boss_base.tscn") if ResourceLoader.exists("res://scenes/enemies/boss_base.tscn") else null
	if not boss_scene:
		return
	var inst := boss_scene.instantiate()
	add_child(inst)
	# Boss spawn point in the dungeon scene; for now fall back to origin
	if has_node("BossSpawn"):
		inst.global_position = $BossSpawn.global_position
	if BossRegistry:
		var rec = BossRegistry.get_boss(dungeon.boss_id)
		if rec:
			inst.boss_id = rec.id
			inst.display_name = rec.display_name
			inst.encounter_level = rec.encounter_level
			inst.is_main_boss = rec.is_main_boss
			inst.is_final_boss = rec.is_final_boss
			inst.is_secret_boss = rec.is_secret_boss
			inst.phases_data = rec.phases
	inst.boss_defeated.connect(_on_boss_defeated)
	_boss_node = inst

func _on_boss_defeated(boss_id: StringName, _killer: Node) -> void:
	_in_progress = false
	if dungeon and dungeon.completion_flag != &"":
		SaveFlags.set_run(dungeon.completion_flag, true)
	dungeon_cleared.emit(dungeon)

func _check_abandonment() -> void:
	# If no players within the dungeon for ABANDON_GRACE_SECONDS, recycle
	var any_player := false
	for p in get_tree().get_nodes_in_group("player"):
		if p is Node3D and global_position.distance_to(p.global_position) < 200.0:
			any_player = true
			_last_player_seen_at = Time.get_ticks_msec() / 1000.0
			break
	if any_player:
		return
	if Time.get_ticks_msec() / 1000.0 - _last_player_seen_at > ABANDON_GRACE_SECONDS:
		queue_free()  # recycle instance

# === Party gating ===
static func can_party_enter(party: Party) -> bool:
	if not party:
		return true  # solo always allowed
	return party.size() <= MAX_PARTY_IN_DUNGEON
