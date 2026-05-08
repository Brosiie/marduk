extends CharacterBody3D
class_name EnemyBase

# Tiamat's spawn. Generic base for all enemies.
# State machine: idle -> chase -> attack -> recover -> idle. Death is terminal.

enum State { IDLE, CHASE, WINDUP, ATTACK, RECOVER, DEAD }

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

# WINDUP: how long the mob telegraphs its attack before the strike
# lands. Player can dodge during this window. Set to 0 to skip the
# telegraph entirely (instant attacks). Default ~0.7s for grunts so
# new players have time to read; archers/casters override longer.
@export var attack_windup: float = 0.7
@export var attack_radius: float = 1.6  # AOE radius for telegraph circle
@export var telegraph_color: Color = Color(0.85, 0.25, 0.15, 0.9)

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
	# Crimson rim-light pass on enemy meshes: separates them from the
	# volumetric-fogged backgrounds and signals 'hostile' through color.
	# Bosses override this with a stronger pulse in BossBase._ready.
	call_deferred("_apply_enemy_rim")
	# Reset Mixamo skeleton bones to rest pose so the skinned mesh
	# renders correctly. Without this Mixamo characters appear
	# invisible (skin collapses to a flat plane).
	var fixer_script: GDScript = load("res://scripts/anim/mixamo_skeleton_fixer.gd")
	if fixer_script and fixer_script.has_method("fix"):
		fixer_script.fix(self)
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
	# Skip when this enemy has no resolvable identity. Without a mob_id
	# (and no display_name on a Boss subclass), the nameplate would render
	# Godot auto-names like "@CharacterBody3D@3184" floating above the
	# actor — debug noise, not a UI feature.
	var has_mob_id: bool = mob_id != &""
	var has_display: bool = ("display_name" in self) and (str(get("display_name")) != "")
	if not has_mob_id and not has_display:
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
		State.WINDUP:
			# Hold position during windup so the player can read the
			# telegraph without the mob walking past them.
			velocity.x = 0
			velocity.z = 0
			_tick_telegraph_progress()
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
		# Enter WINDUP if mob has a non-zero windup, else attack
		# immediately. Windup gives the player a dodge window.
		if attack_windup > 0.0 and _attack_timer <= 0.0:
			_begin_windup()
		else:
			state = State.ATTACK
		velocity.x = 0; velocity.z = 0
		return
	var dir := to.normalized()
	velocity.x = dir.x * move_speed
	velocity.z = dir.z * move_speed
	look_at(global_position + dir, Vector3.UP)

# Windup: spawns the telegraph decal, holds for attack_windup seconds,
# then commits to ATTACK regardless of player position. If the player
# dodged out of the danger zone the swing whiffs (handled in _attack).
var _windup_started_at: float = 0.0
var _windup_decal: MeshInstance3D = null

func _begin_windup() -> void:
	state = State.WINDUP
	_windup_started_at = Time.get_ticks_msec() / 1000.0
	_spawn_attack_telegraph()
	# Schedule the strike commit at the end of the windup window
	var windup := attack_windup
	get_tree().create_timer(windup).timeout.connect(func():
		if state == State.WINDUP:
			_clear_attack_telegraph()
			state = State.ATTACK
	)

func _attack() -> void:
	if _attack_timer > 0.0:
		state = State.CHASE
		return
	# Whiff check: target must still be inside attack_range when the
	# strike commits. If the player dodged out, no damage. This is
	# what makes mob telegraphs MEAN something.
	if target and is_instance_valid(target):
		var d := global_position.distance_to(target.global_position)
		if d <= attack_range + 0.5 and target.has_method("take_damage"):
			target.take_damage(contact_damage, self)
	_attack_timer = attack_cooldown
	state = State.RECOVER
	get_tree().create_timer(0.3).timeout.connect(func(): if state != State.DEAD: state = State.CHASE)

# --- Mob telegraph (mirror of boss telegraph but circle-only) ---

func _spawn_attack_telegraph() -> void:
	_clear_attack_telegraph()
	var decal := MeshInstance3D.new()
	decal.name = "MobTelegraph"
	var quad := PlaneMesh.new()
	quad.size = Vector2(attack_radius * 2.0, attack_radius * 2.0)
	decal.mesh = quad
	var mat := ShaderMaterial.new()
	mat.shader = load("res://shaders/telegraph.gdshader")
	# shape_id 2 = AOE_AROUND_BOSS (filled circle) - matches the visual
	# the boss system uses for ground AOEs.
	mat.set_shader_parameter("shape_id", 2)
	mat.set_shader_parameter("telegraph_color", telegraph_color)
	mat.set_shader_parameter("progress", 0.0)
	mat.set_shader_parameter("pulse_speed", 6.0)  # slightly slower than boss for tier reading
	decal.material_override = mat
	# Add to scene root so the decal stays put if the mob jiggles
	get_tree().current_scene.add_child(decal)
	decal.global_position = global_position + Vector3(0, 0.05, 0)
	_windup_decal = decal

func _clear_attack_telegraph() -> void:
	if _windup_decal and is_instance_valid(_windup_decal):
		_windup_decal.queue_free()
	_windup_decal = null

# Death puff: short-lived particle burst spawned at the mob's last
# position. Parented to current_scene (not self) so it lives past
# queue_free. Dark embers expand and fade for that satisfying 'soul
# leaving the body' read.
# Apply additive rim shader to all MeshInstance3Ds under self. Walks
# the imported .glb's tree (Skeleton3D > MeshInstance3D for Mixamo).
# Hostile crimson by default; bosses override with bigger strength.
@export var rim_color: Color = Color(0.92, 0.18, 0.20, 1.0)
@export var rim_power: float = 2.2
@export var rim_strength: float = 1.3

func _apply_enemy_rim() -> void:
	var rim_shader: Shader = load("res://shaders/rim_pass.gdshader")
	if rim_shader == null:
		return
	_apply_rim_recurse(self, rim_shader)

func _apply_rim_recurse(node: Node, shader: Shader) -> void:
	if node is MeshInstance3D:
		var mi := node as MeshInstance3D
		if mi.mesh:
			for i in range(mi.mesh.get_surface_count()):
				var src: Material = mi.get_surface_override_material(i)
				if src == null:
					src = mi.mesh.surface_get_material(i)
				var rim_mat := ShaderMaterial.new()
				rim_mat.shader = shader
				rim_mat.set_shader_parameter("rim_color", rim_color)
				rim_mat.set_shader_parameter("rim_power", rim_power)
				rim_mat.set_shader_parameter("rim_strength", rim_strength)
				if src:
					var src_dup: Material = src.duplicate()
					src_dup.next_pass = rim_mat
					mi.set_surface_override_material(i, src_dup)
				else:
					mi.set_surface_override_material(i, rim_mat)
	for c in node.get_children():
		_apply_rim_recurse(c, shader)

func _spawn_death_puff() -> void:
	var puff := GPUParticles3D.new()
	puff.name = "DeathPuff"
	puff.amount = 50
	puff.lifetime = 1.4
	puff.one_shot = true
	puff.explosiveness = 0.95  # fire all at once
	puff.visibility_aabb = AABB(Vector3(-2, -1, -2), Vector3(4, 4, 4))
	var mat := ParticleProcessMaterial.new()
	mat.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_SPHERE
	mat.emission_sphere_radius = 0.3
	mat.direction = Vector3.UP
	mat.spread = 70.0
	mat.initial_velocity_min = 1.5
	mat.initial_velocity_max = 4.0
	mat.gravity = Vector3(0, -2.0, 0)
	mat.scale_min = 0.20
	mat.scale_max = 0.45
	# Dark crimson with slight orange glow — souls + spent blood
	mat.color = Color(0.45, 0.10, 0.10, 0.95)
	mat.angular_velocity_min = -180.0
	mat.angular_velocity_max = 180.0
	puff.process_material = mat
	var quad := QuadMesh.new()
	quad.size = Vector2(0.40, 0.40)
	var smat := StandardMaterial3D.new()
	smat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	smat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	smat.albedo_color = Color(0.45, 0.10, 0.10, 0.85)
	smat.emission_enabled = true
	smat.emission = Color(0.95, 0.30, 0.10)
	smat.emission_energy_multiplier = 0.8
	smat.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
	smat.billboard_keep_scale = true
	quad.material = smat
	puff.draw_pass_1 = quad
	get_tree().current_scene.add_child(puff)
	puff.global_position = global_position + Vector3(0, 0.8, 0)
	# Auto-cleanup after the burst dies down
	get_tree().create_timer(2.0).timeout.connect(func(): if is_instance_valid(puff): puff.queue_free())

func _tick_telegraph_progress() -> void:
	if _windup_decal == null or not is_instance_valid(_windup_decal):
		return
	var now: float = Time.get_ticks_msec() / 1000.0
	var elapsed: float = now - _windup_started_at
	var prog: float = clamp(elapsed / max(0.001, attack_windup), 0.0, 1.0)
	var mat: ShaderMaterial = _windup_decal.material_override
	if mat:
		mat.set_shader_parameter("progress", prog)

func take_damage(amount: float, source: Node = null) -> void:
	if state == State.DEAD:
		return
	hp = max(0.0, hp - amount)
	# Spawn a damage floater so combat has visual feedback.
	var floater_script: GDScript = load("res://scripts/combat/damage_floater.gd")
	var is_crit: bool = false
	if floater_script and floater_script.has_method("spawn"):
		if source and "stats" in source and source.stats:
			var cc: float = float(source.stats.get("crit_chance") if "crit_chance" in source.stats else 0.0)
			is_crit = randf() < cc and amount > 30.0
		floater_script.spawn(self, amount, is_crit, &"physical")
	# Audio cue (procedural since no .ogg yet)
	var ab = get_node_or_null("/root/AudioBus")
	if ab and ab.has_method("play_cue"):
		ab.play_cue(&"crit" if is_crit else &"hit", global_position, -8.0, randf_range(0.92, 1.08))
	# Combat juice: hit-stop on every successful hit so the swing
	# feels like it CONNECTED. Camera shake scales with damage as a
	# fraction of max HP so big hits feel bigger.
	var juice = get_node_or_null("/root/Juice")
	if juice:
		juice.hit_stop(0.05 if not is_crit else 0.10)
		var hp_pct: float = clamp(amount / max(max_hp, 1.0), 0.0, 1.0)
		juice.shake(0.05 + hp_pct * 0.30, 0.20)
		if is_crit:
			juice.flash(Color(1.0, 0.95, 0.55), 0.20, 0.18)
	if hp <= 0.0:
		# Cinematic death blow on a crit-kill
		if is_crit and juice:
			juice.cinematic_kill(global_position, 0.55)
		_die(source)

func _die(killer: Node) -> void:
	state = State.DEAD
	died.emit()
	# Death VFX: puff of dark dust + bright transient flash so the
	# kill feels SATISFYING. Spawned at the world position so it
	# persists past the queue_free of the mob.
	_spawn_death_puff()
	# Telegraph cleanup: if mob died mid-windup, kill the decal so it
	# doesn't linger after the mob is gone.
	_clear_attack_telegraph()
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
	# Quest progress: count this kill against any active quest with a
	# matching kill objective (e.g. "Slay 6 Tashmu's Footmen" tracks
	# every usurper_footman death).
	var qr = get_node_or_null("/root/QuestRegistry")
	if qr and qr.has_method("progress") and mob_id != &"":
		qr.progress(&"kill", mob_id, 1)
	# Codex bestiary unlock: first time the player kills a mob type, flip
	# its bestiary entry from locked to readable.
	var cdx = get_node_or_null("/root/CodexRegistry")
	if cdx and cdx.has_method("unlock") and mob_id != &"":
		cdx.unlock(StringName("b_" + String(mob_id)))
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
