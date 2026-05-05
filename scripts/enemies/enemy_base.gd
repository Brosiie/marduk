extends CharacterBody3D
class_name EnemyBase

# Tiamat's spawn. Generic base for all enemies.
# State machine: idle -> chase -> attack -> recover -> idle. Death is terminal.

enum State { IDLE, CHASE, ATTACK, RECOVER, DEAD }

@export var max_hp: float = 60.0
@export var hp: float = 60.0
@export var armor: float = 4.0
@export var magic_resist: float = 4.0
@export var move_speed: float = 3.5
@export var detect_radius: float = 9.0
@export var attack_range: float = 1.8
@export var attack_cooldown: float = 1.6
@export var contact_damage: float = 12.0
@export var xp_reward: int = 25

@export var crit_chance: float = 0.0
@export var crit_multiplier: float = 1.5

@export var loot_table: LootTable  # null = no drops

# Identity slot for mesh + animation library lookups. Region scenes set
# this on their MobSpawn_* markers (`metadata/mob_id`); the spawner reads
# it back into here before the enemy enters the tree.
@export var mob_id: StringName = &"usurper_footman"

var state: State = State.IDLE
var target: Node3D
var _attack_timer: float = 0.0
var gravity: float = 24.0

signal died

func _ready() -> void:
	add_to_group("enemy")
	_apply_prestige_scaling()
	_attach_nameplate()
	_load_marduk_animation_library()

# Merges the slot animations declared in AnimationRegistry for this mob_id
# into the spawned mesh's AnimationPlayer. Silent no-op if anim files
# aren't on disk yet.
func _load_marduk_animation_library() -> void:
	var loader_script: GDScript = load("res://scripts/anim/animation_library_loader.gd")
	if loader_script == null:
		return
	var loader = loader_script.new()
	loader.apply(self, "mob", mob_id)

func _attach_nameplate() -> void:
	# Lazily attach a WoW-style nameplate (HP bar mesh + name label +
	# target highlight ring). Bosses get the boss color (orange) and a
	# bigger plate; regular hostile mobs get red.
	if has_node("WowNameplate"):
		return
	var np_script: GDScript = load("res://scripts/ui/hud_components/wow_nameplate.gd")
	if np_script == null:
		return
	var np = np_script.new()
	np.name = "WowNameplate"
	np.actor = self
	np.position = Vector3(0, 2.2, 0)
	np.hostility = 3 if (self is BossBase) else 0
	add_child(np)

func _apply_prestige_scaling() -> void:
	# Scale stats by current cycle. Cycle 0 = 1x (no change), Cycle 1 = 2x, etc.
	if not Engine.has_singleton("Prestige") and not get_tree().root.has_node("Prestige"):
		return
	var p = get_tree().root.get_node_or_null("Prestige")
	if not p:
		return
	var mult: float = p.difficulty_multiplier()
	max_hp *= mult
	hp = max_hp
	contact_damage *= mult
	xp_reward = int(xp_reward * mult)

func _physics_process(delta: float) -> void:
	if state == State.DEAD:
		return
	_attack_timer = max(0.0, _attack_timer - delta)
	_acquire_target()

	match state:
		State.IDLE:
			_idle()
		State.CHASE:
			_chase(delta)
		State.ATTACK:
			_attack()
		State.RECOVER:
			pass

	if not is_on_floor():
		velocity.y -= gravity * delta
	move_and_slide()

func _acquire_target() -> void:
	if target and is_instance_valid(target):
		var d := global_position.distance_to(target.global_position)
		# Stealthed targets we already saw can be lost from sight if they re-stealth and walk out
		var effective_radius := detect_radius
		if target.has_method("get_detection_radius_override"):
			effective_radius = target.get_detection_radius_override(detect_radius)
		if d > effective_radius * 1.5:
			target = null
			state = State.IDLE
		return
	for p in get_tree().get_nodes_in_group("player"):
		# Stealth: each player can override the detection radius they're visible at.
		var radius := detect_radius
		if p.has_method("get_detection_radius_override"):
			radius = p.get_detection_radius_override(detect_radius)
		if global_position.distance_to(p.global_position) <= radius:
			target = p
			state = State.CHASE
			return

func _idle() -> void:
	velocity.x = 0
	velocity.z = 0

func _chase(_delta: float) -> void:
	if not target:
		state = State.IDLE
		return
	var to := target.global_position - global_position
	to.y = 0
	var dist := to.length()
	if dist <= attack_range:
		state = State.ATTACK
		velocity.x = 0; velocity.z = 0
		return
	var dir := to.normalized()
	velocity.x = dir.x * move_speed
	velocity.z = dir.z * move_speed
	look_at(global_position + dir, Vector3.UP)

func _attack() -> void:
	if _attack_timer > 0.0:
		state = State.CHASE
		return
	if target and target.has_method("take_damage"):
		target.take_damage(contact_damage, self)
	_attack_timer = attack_cooldown
	state = State.RECOVER
	get_tree().create_timer(0.3).timeout.connect(func(): if state != State.DEAD: state = State.CHASE)

func take_damage(amount: float, source: Node = null) -> void:
	if state == State.DEAD:
		return
	hp = max(0.0, hp - amount)
	# Spawn a damage floater so combat has visual feedback.
	var floater_script: GDScript = load("res://scripts/combat/damage_floater.gd")
	var is_crit: bool = false
	if floater_script and floater_script.has_method("spawn"):
		if source and source.has("stats") and source.stats:
			var cc: float = float(source.stats.get("crit_chance") if "crit_chance" in source.stats else 0.0)
			is_crit = randf() < cc and amount > 30.0
		floater_script.spawn(self, amount, is_crit, &"physical")
	# Audio cue (procedural since no .ogg yet)
	var ab = get_node_or_null("/root/AudioBus")
	if ab and ab.has_method("play_cue"):
		ab.play_cue(&"crit" if is_crit else &"hit", global_position, -8.0, randf_range(0.92, 1.08))
	if hp <= 0.0:
		_die(source)

func _die(killer: Node) -> void:
	state = State.DEAD
	died.emit()
	# Death SFX
	var ab = get_node_or_null("/root/AudioBus")
	if ab and ab.has_method("play_cue"):
		ab.play_cue(&"death", global_position, -6.0, randf_range(0.85, 1.0))
	# Achievement: first kill
	var ar = get_node_or_null("/root/AchievementRegistry")
	if ar and ar.has_method("unlock"):
		ar.unlock(&"a_first_blood")
		if self is BossBase:
			ar.unlock(&"a_first_boss")
	if killer and killer.get("stats") and killer.stats.has_method("gain_xp"):
		killer.stats.gain_xp(xp_reward)
	# Award stance charge to Ronin killers, drop loot via prestige-aware table
	if killer and killer.has_method("on_kill_credit"):
		killer.on_kill_credit()
	if loot_table and killer:
		var drops: Array[Item] = loot_table.roll(get_node("/root/Prestige").current_prestige_level() if get_node_or_null("/root/Prestige") else 0)
		_spawn_pickups(drops)
	queue_free()

# Drop ItemPickup nodes in a small ring around the enemy's death position.
# Each pickup pops out, glows in its rarity color, and waits to be looted.
func _spawn_pickups(items: Array[Item]) -> void:
	if items.is_empty():
		return
	var pickup_script: GDScript = load("res://scripts/items/item_pickup.gd")
	if pickup_script == null:
		return
	var i: int = 0
	for it in items:
		if it == null:
			continue
		var pu = pickup_script.new()
		pu.item = it
		pu.quantity = 1
		var angle: float = (TAU / max(items.size(), 1)) * float(i)
		var radius: float = 0.6
		pu.position = global_position + Vector3(cos(angle) * radius, 0.4, sin(angle) * radius)
		get_tree().current_scene.add_child(pu)
		i += 1

func get_attr(_a: StringName) -> float:
	return 0.0
