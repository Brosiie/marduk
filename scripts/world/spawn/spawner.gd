extends Node3D
class_name Spawner

# Open-world mob spawner. Place these around a zone scene; each carries a small
# spawn pool and a respawn timer. When the spawned mob dies, the spawner waits
# for `respawn_seconds` then respawns a (possibly different) mob from the pool.
# Pauses respawn if a player is within `disturb_radius` to avoid spawning in face.

@export var mob_pool: Array[StringName] = []   # mob ids from MobRegistry
@export var initial_count: int = 1             # how many to spawn at scene load
@export var max_concurrent: int = 1
@export var respawn_seconds: float = 60.0
@export var disturb_radius: float = 8.0        # do not respawn while a player is closer than this
@export var respawn_jitter: float = 6.0        # +/- variance on respawn time
@export var enabled: bool = true

var _alive: Array = []  # of EnemyBase
var _next_respawn_at: float = 0.0

func _ready() -> void:
	add_to_group("spawner")
	# Defer initial spawns: scene is still adding children, can't add siblings yet
	call_deferred("_initial_spawn")

func _initial_spawn() -> void:
	for _i in range(initial_count):
		_spawn_one()

func _process(_delta: float) -> void:
	if not enabled:
		return
	# Prune freed mobs
	_alive = _alive.filter(func(e): return is_instance_valid(e))
	if _alive.size() >= max_concurrent:
		return
	var now := Time.get_ticks_msec() / 1000.0
	if now < _next_respawn_at:
		return
	# Don't spawn under players' feet
	if _player_within_radius():
		_next_respawn_at = now + 2.0  # check again in 2s
		return
	_spawn_one()

func _spawn_one() -> void:
	if mob_pool.is_empty():
		return
	var mob_id: StringName = mob_pool[randi() % mob_pool.size()]
	var mob: Mob = MobRegistry.get_mob(mob_id) if MobRegistry else null
	if not mob:
		return
	# Real impl: instantiate the mob's scene with stats applied.
	# Stub: spawn an EnemyBase with the mob's stats baked in.
	var enemy_scene := preload("res://scenes/enemies/enemy_base.tscn") if ResourceLoader.exists("res://scenes/enemies/enemy_base.tscn") else null
	if not enemy_scene:
		return
	var inst := enemy_scene.instantiate()
	# Stamp mob_id BEFORE adding to tree so EnemyBase._ready() resolves the
	# right Mixamo mesh + animation library on first frame instead of
	# defaulting to usurper_footman.
	inst.mob_id = mob_id
	# Role-specific behavior swap: ARCHER role gets the kite + arrow AI.
	# Done by replacing the script before _ready runs.
	if int(mob.role) == 1:  # Mob.Role.ARCHER
		var archer_script: GDScript = load("res://scripts/enemies/archer_mob.gd")
		if archer_script:
			inst.set_script(archer_script)
	_swap_mesh_for_mob(inst, mob_id)
	get_tree().current_scene.add_child(inst)
	inst.global_position = global_position
	# Level-scale: every mob gets +10% HP / +6% damage / +5% XP per player
	# level past 1. Keeps the world from going trivial as the player grows.
	var p = get_tree().get_first_node_in_group("player")
	var player_level: int = 1
	if p and p.has("stats") and p.stats and "level" in p.stats:
		player_level = max(1, int(p.stats.level))
	var lvl_step: int = max(0, player_level - 1)
	var hp_mult: float = 1.0 + 0.10 * float(lvl_step)
	var dmg_mult: float = 1.0 + 0.06 * float(lvl_step)
	var xp_mult: float = 1.0 + 0.05 * float(lvl_step)
	inst.max_hp = mob.base_hp * hp_mult
	inst.hp = inst.max_hp
	inst.contact_damage = mob.base_damage * dmg_mult
	inst.move_speed = mob.move_speed
	inst.detect_radius = mob.detect_radius
	inst.xp_reward = int(mob.xp_reward * xp_mult)
	# Generate a LootTable from the mob's role+level. Without this every
	# enemy.died fires with a null loot_table and nothing drops.
	var lg = get_node_or_null("/root/LootGenerator")
	if lg and lg.has_method("for_mob"):
		inst.loot_table = lg.for_mob(mob)
	inst.set_meta("mob_id", mob_id)
	inst.died.connect(_on_mob_died)
	_alive.append(inst)

# enemy_base.tscn ships with the default usurper_footman mesh baked into
# `MobMesh`. For mobs with a different Mixamo character, hot-swap the
# instanced PackedScene before _ready() runs.
func _swap_mesh_for_mob(enemy_inst: Node, requested_mob_id: StringName) -> void:
	var mesh_path: String = ""
	var reg = get_tree().root.get_node_or_null("ClassMeshRegistry")
	if reg and reg.has_method("get_mob_mesh_path"):
		mesh_path = reg.get_mob_mesh_path(requested_mob_id)
	if mesh_path == "" or not ResourceLoader.exists(mesh_path):
		return
	var packed: PackedScene = load(mesh_path)
	if packed == null:
		return
	var old_mesh: Node = enemy_inst.get_node_or_null("MobMesh")
	if old_mesh:
		old_mesh.queue_free()
	var new_mesh := packed.instantiate()
	new_mesh.name = "MobMesh"
	new_mesh.transform = Transform3D(Basis().scaled(Vector3(0.01, 0.01, 0.01)), Vector3.ZERO)
	enemy_inst.add_child(new_mesh)

func _on_mob_died() -> void:
	var jitter := randf_range(-respawn_jitter, respawn_jitter)
	_next_respawn_at = Time.get_ticks_msec() / 1000.0 + max(5.0, respawn_seconds + jitter)

func _player_within_radius() -> bool:
	for p in get_tree().get_nodes_in_group("player"):
		if global_position.distance_to(p.global_position) < disturb_radius:
			return true
	return false
