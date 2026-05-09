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
	_apply_faction_groups()
	_apply_prestige_scaling()
	_attach_nameplate()
	# Quest waypoint: floats a bobbing gold diamond above this enemy
	# whenever an active quest objective targets its mob_id. Self-polls,
	# so quests started/completed at runtime light up/dim the marker
	# without us wiring signals from QuestLog into every spawner.
	var qw_script: GDScript = load("res://scripts/quests/quest_waypoint.gd")
	if qw_script and qw_script.has_method("attach_to"):
		qw_script.attach_to(self)
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

# Tags this enemy with its faction group(s) on spawn so the player's
# CombatBus.kill_registered bridge can apply rep deltas via the
# _MOB_GROUP_TO_FACTION_REP table. Map is by mob_id substring, keeps
# the table concise and avoids requiring every Mob registration to
# explicitly carry a faction string.
const _MOB_FACTION_GROUPS := {
	"usurper":      ["crown_loyal"],     # Tashmu's forces serve the false Crown
	"raider":       ["black_sail"],      # Ash-step bandits sell to pirates
	"shrine_":      ["inquisition"],     # Whisper Shrine became Inquisition-aligned
	"witch_burner": ["inquisition"],
	"blood_hunter": ["inquisition"],
	"binding_construct": ["six_breaths"], # bound spirits the temple wants released
	"animated_book":     ["six_breaths"],
	"corrupted_wolf":    ["tiamat_spawn"],
	"forest_blight":     ["tiamat_spawn"],
	"reed_creeper":      ["tiamat_spawn"],
	"salt_demon":        ["tiamat_spawn"],
	"minor_demon":       ["tiamat_spawn"],
	"escaped_temple_slave": ["druids"],   # outcast labor; Druids shelter them
}

func _apply_faction_groups() -> void:
	if mob_id == &"":
		return
	var id_str: String = String(mob_id)
	for prefix in _MOB_FACTION_GROUPS.keys():
		if id_str.find(prefix) >= 0:
			for grp in _MOB_FACTION_GROUPS[prefix]:
				add_to_group(grp)
			return  # first-match wins so a mob isn't double-counted

# Merges the slot animations declared in AnimationRegistry for this mob_id
# into the spawned mesh's AnimationPlayer. Silent no-op if anim files
# aren't on disk yet.
#
# The role here ("mob") is overridden by BossBase to "boss" so each
# pulls from its own slot table.
var _anim_player_ref: AnimationPlayer = null
var _resolved_idle: String = ""
var _resolved_walk: String = ""
var _resolved_attack: String = ""
var _resolved_die: String = ""
var _resolved_hit: String = ""
# When a one-shot anim (attack / hit / death) is playing, suppress the
# state-driven _update_anim so it doesn't immediately overwrite back
# to idle/walk on the next physics frame. Cleared via animation_finished.
var _one_shot_lock_until: float = 0.0
# Cached so we know which anim was the one-shot triggering the lock.
var _last_one_shot: String = ""

func _load_marduk_animation_library() -> void:
	var loader_script: GDScript = load("res://scripts/anim/animation_library_loader.gd")
	if loader_script == null:
		print("[EnemyAnim] loader script missing: %s" % name)
		return
	var loader = loader_script.new()
	# Async coroutine; wait for completion then resolve aliases. Without
	# the await the alias resolution would run BEFORE anims bind.
	# Duck-typed boss check: BossBase declares `boss_id`; EnemyBase
	# can't reference it directly without circular import. We probe
	# the property via `in` and fetch via `get()` to avoid forward
	# references.
	var role: String = "mob"
	var role_id: StringName = mob_id
	if "boss_id" in self:
		role = "boss"
		role_id = StringName(get("boss_id"))
	print("[EnemyAnim] %s starting load role=%s id=%s" % [name, role, role_id])
	await loader.apply(self, role, role_id)
	if not is_instance_valid(self):
		return
	_anim_player_ref = _find_anim_player_recursive(self)
	if _anim_player_ref == null:
		print("[EnemyAnim] %s NO AnimationPlayer found after load" % name)
		return
	var ap_anims: PackedStringArray = _anim_player_ref.get_animation_list()
	print("[EnemyAnim] %s found AP with %d anims" % [name, ap_anims.size()])
	# Sample first 8 anim names so the log shows the actual format
	# (qualified vs bare). This tells us whether to look for
	# "marduk/idle" or just "idle".
	var sample: Array = []
	for i in range(min(8, ap_anims.size())):
		sample.append(String(ap_anims[i]))
	print("[EnemyAnim] %s sample names: %s" % [name, str(sample)])
	# Resolve aliases against what's actually in the library
	# Resolve canonical alias chains. Each chain tries marduk/<name>
	# first (loaded by AnimationLibraryLoader), then falls through to
	# bare/embedded anim names so mobs whose marduk lib failed to bind
	# still play SOMETHING from their .glb's embedded AnimationPlayer
	# instead of T-posing forever. Bond reported T-pose mobs in the
	# inkstone tower; root cause was animated_book/binding_construct
	# having an empty marduk anim folder on disk + no embedded fallback.
	_resolved_idle = _resolve_first([
		"marduk/idle", "marduk/unarmed_idle", "marduk/katana_idle",
		"idle", "Idle", "Mixamo_Idle", "Standing_Idle",
		"mixamorig_Idle", "Armature|idle"
	])
	_resolved_walk = _resolve_first([
		"marduk/walk", "marduk/walk_back", "marduk/walk_left",
		"walk", "Walk", "Walking", "Mixamo_Walking", "mixamorig_Walk"
	])
	_resolved_attack = _resolve_first([
		"marduk/attack_basic", "marduk/attack",
		"attack", "Attack", "attack_basic", "Mixamo_Attack"
	])
	_resolved_die = _resolve_first([
		"marduk/death", "marduk/death_forward", "marduk/death_react_forward",
		"death", "Death", "Die", "Mixamo_Death"
	])
	_resolved_hit = _resolve_first([
		"marduk/hit_react_left", "marduk/hit_react_right", "marduk/hit_react",
		"hit_react", "hit_reaction", "HitReact", "Mixamo_Hit"
	])
	# Final safety net: if STILL nothing resolved, take the FIRST animation
	# in the player's library list and use it as idle so the mob at least
	# moves a little instead of T-posing. Better a wrong anim than no anim.
	if _resolved_idle == "" and _anim_player_ref:
		var any_anims: PackedStringArray = _anim_player_ref.get_animation_list()
		if any_anims.size() > 0:
			_resolved_idle = String(any_anims[0])
			print("[EnemyAnim] %s falling back to first available anim: %s" % [name, _resolved_idle])
	# Probe what got resolved so Bond can see in the log whether the
	# alias chain matched anything in the merged library.
	print("[EnemyAnim] %s resolved idle=%s walk=%s attack=%s die=%s hit=%s" % [name, _resolved_idle, _resolved_walk, _resolved_attack, _resolved_die, _resolved_hit])
	# Hook animation_finished so the one-shot lock auto-clears the
	# instant the anim ends, falling cleanly back into the state-
	# driven loop instead of holding a frozen final-frame pose.
	if not _anim_player_ref.animation_finished.is_connected(_on_anim_finished):
		_anim_player_ref.animation_finished.connect(_on_anim_finished)
	# Loop the idle so the mob isn't T-posing on spawn
	if _resolved_idle != "" and _anim_player_ref.has_animation(_resolved_idle):
		_anim_player_ref.play(_resolved_idle)
		print("[EnemyAnim] %s playing %s" % [name, _resolved_idle])

# Fire a one-shot anim (hit_react / attack swing / death) and lock the
# state-driven anim updater for at most `max_lock_s` so the one-shot
# can play to completion. The lock auto-releases on animation_finished,
# but we hard-cap the duration in case the AnimationPlayer never fires
# the signal (asset oddity, manual stop()s elsewhere, etc).
func _play_one_shot(anim_name: String, max_lock_s: float = 1.5) -> void:
	if _anim_player_ref == null or anim_name == "":
		return
	if not _anim_player_ref.has_animation(anim_name):
		return
	_anim_player_ref.stop()
	_anim_player_ref.play(anim_name)
	_last_one_shot = anim_name
	_one_shot_lock_until = Time.get_ticks_msec() / 1000.0 + max_lock_s

func _on_anim_finished(anim_name: String) -> void:
	# Only release the lock if the FINISHED anim is the one we're
	# tracking, other animations finishing (e.g. an idle clip looping
	# wraps once on first play) shouldn't unlock a pending hit-react.
	if anim_name == _last_one_shot:
		_one_shot_lock_until = 0.0
		_last_one_shot = ""

func _find_anim_player_recursive(node: Node) -> AnimationPlayer:
	if node is AnimationPlayer:
		return node
	for c in node.get_children():
		var f := _find_anim_player_recursive(c)
		if f != null:
			return f
	return null

func _resolve_first(candidates: Array) -> String:
	if _anim_player_ref == null:
		return ""
	# Use has_animation() instead of `in get_animation_list()`. The list
	# returns PackedStringArray entries that don't compare equal to plain
	# String candidates with the `in` operator in Godot 4.6, the lookup
	# silently misses every alias and EVERY mob/boss ends up T-posing
	# despite the library being fully bound. has_animation() does its
	# own internal hash lookup with proper string equivalence.
	for c in candidates:
		var s: String = String(c)
		if _anim_player_ref.has_animation(s):
			return s
	return ""

# Per-frame anim driver: walk during chase, idle when stopped, attack
# anim during the strike commit, death anim when dead.
# Suppressed entirely while a one-shot (hit_react / attack swing /
# death) is in flight, otherwise it'd snap back to idle/walk on the
# very next physics frame and the player would never see the
# windup-to-hit transition complete.
func _update_anim() -> void:
	if _anim_player_ref == null:
		return
	var now: float = Time.get_ticks_msec() / 1000.0
	if now < _one_shot_lock_until:
		return
	var want: String = ""
	match state:
		State.DEAD:
			want = _resolved_die
		State.ATTACK:
			want = _resolved_attack if _resolved_attack != "" else _resolved_idle
		State.CHASE:
			# Only switch to walk if actually moving (e.g. archers stand to shoot)
			var horiz: float = Vector2(velocity.x, velocity.z).length()
			want = _resolved_walk if horiz > 0.5 else _resolved_idle
		_:
			want = _resolved_idle
	if want != "" and _anim_player_ref.current_animation != want and _anim_player_ref.has_animation(want):
		_anim_player_ref.play(want)

func _attach_nameplate() -> void:
	# Lazily attach a WoW-style nameplate (HP bar mesh + name label +
	# target highlight ring). Bosses get the boss color (orange) and a
	# bigger plate; regular hostile mobs get red.
	if has_node("WowNameplate"):
		return
	# Skip when this enemy has no resolvable identity. Without a mob_id
	# (and no display_name on a Boss subclass), the nameplate would render
	# Godot auto-names like "@CharacterBody3D@3184" floating above the
	# actor, debug noise, not a UI feature.
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
	# Drive the mob's animation based on state. Without this every
	# mob/boss T-poses despite having 28+ anims loaded into their
	# AnimationPlayer.
	_update_anim()

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
	# Mixamo meshes are +Z-forward (toes point +Z in rest pose). Godot's
	# look_at() points the node's -Z at the target, which would make the
	# imported mesh visually face AWAY. We rotate via atan2 directly so
	# the body's +Z (the mesh's forward) points at the player. Without
	# this, every mob/boss spins to face away the moment they aggro ,
	# THE "boss fight inverts the boss and the player" bug.
	rotation.y = atan2(dir.x, dir.z)

# Windup: spawns the telegraph decal, holds for attack_windup seconds,
# then commits to ATTACK regardless of player position. If the player
# dodged out of the danger zone the swing whiffs (handled in _attack).
var _windup_started_at: float = 0.0
var _windup_decal: MeshInstance3D = null

func _begin_windup() -> void:
	state = State.WINDUP
	_windup_started_at = Time.get_ticks_msec() / 1000.0
	_spawn_attack_telegraph()
	# Schedule the strike commit at the end of the windup window.
	# is_instance_valid guard FIRST: SceneTreeTimer outlives the mob,
	# so if the player one-shots the mob mid-windup the lambda fires
	# on a freed instance and crashes with 'Invalid access to property'.
	var windup := attack_windup
	get_tree().create_timer(windup).timeout.connect(func():
		if not is_instance_valid(self):
			return
		if state == State.WINDUP:
			_clear_attack_telegraph()
			state = State.ATTACK
	)

func _attack() -> void:
	if _attack_timer > 0.0:
		state = State.CHASE
		return
	# Fire the attack swing anim. Lock so _update_anim doesn't yank
	# back to walk mid-swing. Without this you'd see the mob's body
	# hit the player but the SWING animation never visually played.
	if _resolved_attack != "":
		_play_one_shot(_resolved_attack, 0.6)
	# Whiff check: target must still be inside attack_range when the
	# strike commits. If the player dodged out, no damage. This is
	# what makes mob telegraphs MEAN something.
	if target and is_instance_valid(target):
		var d := global_position.distance_to(target.global_position)
		if d <= attack_range + 0.5 and target.has_method("take_damage"):
			# Perfect-dodge gate: if the player is in the LATE i-frame
			# slice when the strike commits, this triggers their Riposte
			# buff and we skip damage entirely (they 'parried' the hit).
			# Otherwise the regular take_damage path runs (which itself
			# checks is_invulnerable for the broader i-frame window).
			if target.has_method("check_perfect_dodge") and target.check_perfect_dodge():
				pass  # Riposte triggered; no damage
			else:
				target.take_damage(contact_damage, self)
	_attack_timer = attack_cooldown
	state = State.RECOVER
	get_tree().create_timer(0.3).timeout.connect(func():
		if not is_instance_valid(self): return
		if state != State.DEAD:
			state = State.CHASE
	)

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
@export var rim_strength: float = 0.65

func _apply_enemy_rim() -> void:
	var rim_shader: Shader = load("res://shaders/rim_pass.gdshader")
	if rim_shader == null:
		return
	_apply_rim_recurse(self, rim_shader)

# Per-mob_id rim ShaderMaterial cache. The rim shader + params are
# identical for every instance of the same mob type, so we share one
# ShaderMaterial across all of them via next_pass. Previously each
# spawn `.duplicate()`d the base material and built a fresh
# ShaderMaterial, which with 10+ footmen loaded ~30 redundant Material
# resources into VRAM.
static var _rim_mat_cache: Dictionary = {}

func _get_cached_rim_mat(shader: Shader) -> ShaderMaterial:
	# Cache key bundles the shader + visual params so distinct rim
	# tunings (e.g. boss vs. mob vs. demon) get distinct cached mats.
	var key: String = "%s|%s|%.2f|%.2f" % [shader.resource_path, str(rim_color), rim_power, rim_strength]
	if _rim_mat_cache.has(key):
		return _rim_mat_cache[key]
	var rim_mat := ShaderMaterial.new()
	rim_mat.shader = shader
	rim_mat.set_shader_parameter("rim_color", rim_color)
	rim_mat.set_shader_parameter("rim_power", rim_power)
	rim_mat.set_shader_parameter("rim_strength", rim_strength)
	_rim_mat_cache[key] = rim_mat
	return rim_mat

func _apply_rim_recurse(node: Node, shader: Shader) -> void:
	if node is MeshInstance3D:
		var mi := node as MeshInstance3D
		if mi.mesh:
			var shared_rim: ShaderMaterial = _get_cached_rim_mat(shader)
			for i in range(mi.mesh.get_surface_count()):
				var src: Material = mi.get_surface_override_material(i)
				if src == null:
					src = mi.mesh.surface_get_material(i)
				if src:
					# We still have to duplicate the BASE material so we
					# can attach next_pass (next_pass is per-Material).
					# But the rim shader itself is now shared, so we
					# only pay the base-material dup, not the shader.
					var src_dup: Material = src.duplicate()
					src_dup.next_pass = shared_rim
					mi.set_surface_override_material(i, src_dup)
				else:
					mi.set_surface_override_material(i, shared_rim)
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
	# Dark crimson with slight orange glow, souls + spent blood
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
	# Hit-react anim flashes on every non-lethal hit. Now that the
	# library actually binds, fire it. Dodge/lethal hits skip, the
	# death anim takes priority, and reactions stutter combat anyway
	# if the mob was about to die. Lock 0.4s so the reaction plays
	# without _update_anim snapping back to walk mid-flinch.
	if hp > 0.0 and _resolved_hit != "":
		_play_one_shot(_resolved_hit, 0.4)
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
	# every usurper_footman death). After progress fires, spawn a
	# QuestProgressFloater above the corpse for any objective whose
	# counter actually advanced, so the player sees the kill MATTERED
	# beyond loot + XP.
	var qr = get_node_or_null("/root/QuestRegistry")
	if qr and qr.has_method("progress") and mob_id != &"":
		qr.progress(&"kill", mob_id, 1)
		_spawn_quest_progress_floaters(qr)
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
		# Prestige autoload is missing in unit-test contexts. Resolve once
		# and short-circuit to 0 if absent, so a missing Prestige doesn't
		# crash the whole death-loot pipeline.
		var prestige_node: Node = get_node_or_null("/root/Prestige")
		var cycle: int = prestige_node.current_prestige_level() if prestige_node else 0
		var drops: Array[Item] = loot_table.roll(cycle)
		_spawn_pickups(drops)
	# Play the death anim BEFORE queue_free so the player sees the mob
	# crumple instead of vanishing mid-air. Lock duration matches anim
	# length where we can read it; otherwise default 1.6s covers
	# Mixamo Standing Death Forward (~1.4s with a 200ms grace).
	# Disable physics during the death anim so the body doesn't slide
	# when no input is keeping it up.
	set_physics_process(false)
	if _anim_player_ref and _resolved_die != "":
		_play_one_shot(_resolved_die, 2.0)
		var death_len: float = 1.6
		if _anim_player_ref.has_animation(_resolved_die):
			var anim: Animation = _anim_player_ref.get_animation(_resolved_die)
			if anim:
				death_len = max(0.8, anim.length + 0.2)
		# Disconnect the nameplate before the body fades so it doesn't
		# linger floating mid-air after queue_free.
		var np: Node = get_node_or_null("WowNameplate")
		if np:
			np.queue_free()
		await get_tree().create_timer(death_len).timeout
		if not is_instance_valid(self):
			return
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

# Walks every active quest right after a kill and spawns a
# QuestProgressFloater for each objective that incremented. Reads live
# counters from QuestRegistry._progress so we know the exact (count /
# required) numbers to display.
#
# Why we re-scan instead of using the quest_progress signal:
#   - We need the killed mob's POSITION to anchor the floater. The
#     signal carries (quest, objective_index, count) but no source.
#   - We need the OBJECTIVE DESCRIPTION (e.g. "Eliminate Tashmu's
#     Footmen") which is static metadata on the quest. Walking the
#     quest list here gives us both the count AND the description in
#     one pass without storing a sidetable mapping mob_id -> objectives.
#
# Skipped if QuestProgressFloater isn't loadable so older builds that
# don't have the floater script don't crash on kill.
func _spawn_quest_progress_floaters(qr: Node) -> void:
	var floater_script: GDScript = load("res://scripts/quests/quest_progress_floater.gd")
	if floater_script == null:
		return
	var active = qr.get("_active") if "_active" in qr else null
	var progress = qr.get("_progress") if "_progress" in qr else null
	if not (active is Dictionary) or not (progress is Dictionary):
		return
	for quest_id in (active as Dictionary).keys():
		var q = (active as Dictionary)[quest_id]
		if q == null:
			continue
		var objs: Array = q.get("objectives_data") if "objectives_data" in q else []
		var counters: Array = (progress as Dictionary).get(quest_id, [])
		for i in range(objs.size()):
			var obj: Dictionary = objs[i]
			if String(obj.get("kind", "")) != "kill":
				continue
			if String(obj.get("target_id", "")) != String(mob_id):
				continue
			var current: int = int(counters[i]) if i < counters.size() else 0
			var required: int = int(obj.get("required_count", 1))
			# Only show if this kill actually advanced the counter.
			# Past-required kills (player kept farming) don't re-fire.
			if current == 0 or current > required:
				continue
			var desc: String = String(obj.get("description", ""))
			floater_script.spawn(self, desc, current, required)
