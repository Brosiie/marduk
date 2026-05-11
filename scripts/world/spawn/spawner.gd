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

# ─────── Conflict-aware spawning (optional) ───────
# A spawner placed at a faction-border zone can declare a pair_key
# from FactionConflictRegistry. When that pair escalates to SKIRMISH+,
# additional mob ids enter the spawn pool, producing visible faction
# patrols at the border. At OPEN_WAR, MORE mobs enter the pool. Cooling
# the conflict back to TENSE/COLD restores the base mob_pool only.
#
# Existing spawners that don't set conflict_pair_key keep their
# behavior unchanged (both fields default to empty arrays).
#
# Example: a base mob_pool of [&"forest_blight"] at the Verdant Wound
# edge with conflict_pair_key = &"druid_vs_inquisition" and
# pool_skirmish = [&"witch_burner", &"blood_hunter"]. At COLD, only
# forest_blights spawn. At SKIRMISH, burners start patrolling. At
# OPEN_WAR, add a Druid Courier scout (pool_open_war) representing
# the temple pushing back at the burners.
@export var conflict_pair_key: StringName = &""
@export var pool_skirmish: Array[StringName] = []
@export var pool_open_war: Array[StringName] = []

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
	# Build effective pool from base + conflict overlays. Re-evaluated
	# on every spawn so a tier transition during a respawn cycle
	# affects the very next mob picked; no scene reload required.
	var pool: Array = _effective_pool()
	if pool.is_empty():
		return
	var mob_id: StringName = pool[randi() % pool.size()]
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
	# Role-specific behavior swap: replace the script before _ready
	# runs so the right AI tree boots from frame 0.
	# Enum values are sourced from Mob.Role (see scripts/mobs/mob.gd).
	# Reading via Mob.Role.* keeps these in sync if the enum is
	# reordered, raw integer literals were a maintenance trap.
	match int(mob.role):
		Mob.Role.ARCHER:
			var s: GDScript = load("res://scripts/enemies/archer_mob.gd")
			if s: inst.set_script(s)
		Mob.Role.CASTER:
			var s2: GDScript = load("res://scripts/enemies/caster_mob.gd")
			if s2: inst.set_script(s2)
		Mob.Role.RUSHER:
			# Glass cannon, fast move speed, low HP, low windup.
			# Script swaps in dedicated stats + orange rim color so
			# the player can read the threat type at a glance.
			var s3: GDScript = load("res://scripts/enemies/rusher_mob.gd")
			if s3: inst.set_script(s3)
		Mob.Role.TANK:
			# Slow, high-HP, big-swing punisher. Purple rim tier.
			var s4: GDScript = load("res://scripts/enemies/tank_mob.gd")
			if s4: inst.set_script(s4)
	# Mesh swap re-enabled now that .glb conversion landed (commit 3005718).
	# Each mob_id pulls its own Mixamo character from ClassMeshRegistry so
	# usurper_footman / raider_grunt / shrine_acolyte all look distinct.
	_swap_mesh_for_mob(inst, mob_id)
	get_tree().current_scene.add_child(inst)
	inst.global_position = global_position
	# Level-scale: every mob gets +10% HP / +6% damage / +5% XP per player
	# level past 1. Keeps the world from going trivial as the player grows.
	var p = get_tree().get_first_node_in_group("player")
	var player_level: int = 1
	if p and "stats" in p and p.stats and "level" in p.stats:
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
		# remove_child BEFORE queue_free so the old MobMesh is detached
		# from enemy_inst before _ready runs. queue_free is deferred to
		# end of frame; without remove_child, the old mesh sits in
		# enemy_inst.get_children() and AnimationLibraryLoader's
		# recursive AP search picks up the OLD AnimationPlayer (which
		# is queued for deletion). The loader then yields, the frame
		# ends, the old mesh is freed, the loader resumes with a now-
		# invalid anim_player, and aborts WITHOUT binding the marduk
		# library. Result: every spawned mob T-poses despite the
		# library being on disk. Detaching first keeps the recursive
		# search from ever seeing the dying mesh.
		enemy_inst.remove_child(old_mesh)
		old_mesh.queue_free()
	var new_mesh := packed.instantiate()
	new_mesh.name = "MobMesh"
	new_mesh.transform = Transform3D(Basis().scaled(Vector3(1, 1, 1)), Vector3.ZERO)
	enemy_inst.add_child(new_mesh)

func _on_mob_died() -> void:
	var jitter := randf_range(-respawn_jitter, respawn_jitter)
	_next_respawn_at = Time.get_ticks_msec() / 1000.0 + max(5.0, respawn_seconds + jitter)

func _player_within_radius() -> bool:
	for p in get_tree().get_nodes_in_group("player"):
		if global_position.distance_to(p.global_position) < disturb_radius:
			return true
	return false

# Build the effective spawn pool by reading FactionConflictRegistry.
# COLD or unset conflict_pair_key returns mob_pool unchanged. SKIRMISH
# adds pool_skirmish entries. OPEN_WAR adds pool_open_war on top of
# pool_skirmish (escalations compound). Each entry occupies a slot
# in the resulting Array, so a 3-base + 2-skirmish pool weights
# random pick 60/40 toward the base at SKIRMISH; authors can tune
# the bias by sizing the overlay arrays.
func _effective_pool() -> Array:
	var pool: Array = []
	for mid in mob_pool:
		pool.append(mid)
	if conflict_pair_key == &"":
		return pool
	var fcr: Node = get_node_or_null("/root/FactionConflictRegistry")
	if fcr == null or not fcr.has_method("get_state"):
		return pool
	var state: String = String(fcr.get_state(conflict_pair_key))
	if state == "SKIRMISH" or state == "OPEN_WAR":
		for mid in pool_skirmish:
			pool.append(mid)
	if state == "OPEN_WAR":
		for mid in pool_open_war:
			pool.append(mid)
	return pool
