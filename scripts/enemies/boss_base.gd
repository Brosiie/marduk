extends "res://scripts/enemies/enemy_base.gd"
class_name BossBase

# Bosses extend EnemyBase with: phase transitions, multi-stage HP gates, telegraphed
# specials, guaranteed loot drops, prestige badge on nameplate, Elden-Ring-style
# unforgiving cadence (long recovery on player whiffs, big damage windows, no fight
# difficulty modifier ever beyond prestige multiplier).
#
# Boss lifecycle:
#   _ready -> apply prestige mult, install phases
#   take_damage -> check phase gates, transition, broadcast
#   _die -> award guaranteed VERY_RARE drop, roll 1% LEGENDARY for killer's class.
#           If is_final_boss, additionally roll 1% any-legendary + 0.5% Heaven.

class Phase:
	var hp_threshold_pct: float = 1.0  # phase begins when HP drops below this fraction
	var name: String = ""
	var damage_mult: float = 1.0
	var move_speed_mult: float = 1.0
	var ability_set: Array[Ability] = []
	var on_enter_callable: Callable
	var transition_iframes: float = 1.5  # damage immunity during phase transition

@export var boss_id: StringName = &""
@export var display_name: String = "Unknown"
@export var encounter_level: int = 9  # used for level scaling and badge
@export var is_main_boss: bool = false  # 9 main bosses; mini-bosses are false
@export var is_final_boss: bool = false  # Tiamat
@export var is_secret_boss: bool = false  # Lucifer
@export var phases_data: Array = []  # serialized; each entry: {hp_pct, name, dmg_mult, speed_mult}

# Attack patterns. Each phase pulls from this list filtered by min_phase/max_phase.
# AI picks the highest-priority off-cooldown pattern within range.
@export var attack_patterns: Array[BossAttackPattern] = []
var _pattern_cooldowns: Dictionary = {}  # pattern_id -> available_at_unix
var _current_pattern: BossAttackPattern = null
var _pattern_state: StringName = &""  # &"windup" | &"execute" | &"recovery"
var _pattern_state_until: float = 0.0
# Telegraph decal: a flat MeshInstance3D parented under the boss showing
# where the next attack will land. Spawned on _begin_pattern, cleared on
# _execute_pattern so it disappears the instant the strike connects.
var _telegraph_decal: MeshInstance3D = null
const _TELEGRAPH_HEIGHT: float = 0.05  # decal hovers just above floor

var phases: Array = []
var current_phase_index: int = 0
var _in_transition: bool = false

signal phase_changed(phase_index: int, phase_name: String)
signal boss_defeated(boss_id: StringName, killer: Node)

func _ready() -> void:
	super._ready()
	add_to_group("boss")
	# Encounter-level scaling: bring HP/damage up to expected curve for this fight.
	var lvl_mult := 1.0 + float(encounter_level) * 0.10
	max_hp *= lvl_mult
	contact_damage *= lvl_mult
	xp_reward = int(xp_reward * lvl_mult * 2.5)  # bosses give meaty XP
	# Boss HP rule: bosses are 10x average mob HP at the same encounter level.
	# Average mob HP at L1 is ~50; we scale up to give bosses real heft.
	max_hp = max(max_hp, 600.0 * lvl_mult)
	hp = max_hp
	# Boss aura: dark crimson particle ring at the boss's feet so they
	# read as a serious threat the moment the player sees them, even
	# from far across the arena. Bigger than the player's class aura.
	_spawn_boss_aura()
	# Boss rim: brighter crimson + slow pulse so the silhouette
	# THROBS as you fight. Stronger than mob (0.65) but still capped
	# under the rim shader's alpha cap so base mesh shows through.
	rim_color = Color(1.00, 0.20, 0.20, 1.0)
	rim_power = 2.0
	rim_strength = 1.0

	# Inflate phase data
	for d in phases_data:
		var p := Phase.new()
		p.hp_threshold_pct = float(d.get("hp_pct", 1.0))
		p.name = d.get("name", "")
		p.damage_mult = float(d.get("dmg_mult", 1.0))
		p.move_speed_mult = float(d.get("speed_mult", 1.0))
		phases.append(p)

# Override the EnemyBase animation hook so bosses pull from the boss
# slot table (phase_1_combo, phase_2_charge, etc.) rather than the
# generic mob attack pool.
func _load_marduk_animation_library() -> void:
	var loader_script: GDScript = load("res://scripts/anim/animation_library_loader.gd")
	if loader_script == null:
		return
	var loader = loader_script.new()
	loader.apply(self, "boss", boss_id)

func take_damage(amount: float, source: Node = null) -> void:
	if state == State.DEAD or _in_transition:
		return
	super.take_damage(amount, source)
	_check_phase_transition()

func _physics_process(delta: float) -> void:
	if state == State.DEAD or _in_transition:
		return
	super._physics_process(delta)
	_tick_attack_pattern_ai(delta)

func _tick_attack_pattern_ai(_delta: float) -> void:
	# Drive the boss attack pattern state machine: windup -> execute -> recovery -> idle.
	if not target or not is_instance_valid(target):
		return
	var now := Time.get_ticks_msec() / 1000.0

	if _current_pattern:
		# During windup, push 0..1 progress to the telegraph shader so
		# the pulse intensifies as the strike approaches. This is the
		# 'urgency' channel — the player sees the decal getting harsher.
		if _pattern_state == &"windup" and _telegraph_decal and is_instance_valid(_telegraph_decal):
			var windup_total: float = max(0.001, _current_pattern.windup_seconds)
			var elapsed: float = windup_total - max(0.0, _pattern_state_until - now)
			var prog: float = clamp(elapsed / windup_total, 0.0, 1.0)
			var mat: ShaderMaterial = _telegraph_decal.material_override
			if mat:
				mat.set_shader_parameter("progress", prog)
		if now >= _pattern_state_until:
			match _pattern_state:
				&"windup":
					_execute_pattern(_current_pattern)
					_pattern_state = &"execute"
					_pattern_state_until = now + _current_pattern.execute_seconds
				&"execute":
					_pattern_state = &"recovery"
					_pattern_state_until = now + _current_pattern.recovery_seconds
				&"recovery":
					_pattern_cooldowns[_current_pattern.id] = now + _current_pattern.cooldown
					_current_pattern = null
					_pattern_state = &""
		return

	# No active pattern - try to pick one
	var pattern := _select_pattern(now)
	if pattern:
		_begin_pattern(pattern, now)

func _select_pattern(now: float) -> BossAttackPattern:
	# Hybrid selection (locked design):
	#   1. Filter by phase + cooldown + HP-gate + reachability
	#   2. Weighted random across the survivors using `priority_weight`
	#
	# Weighted random gives designers per-pattern frequency control without
	# making the boss feel like an algorithm. Reachability filter prevents
	# the boss from committing to a single-target attack on a player who
	# just dodged out of range, which would feel like AI tunnel vision.
	if attack_patterns.is_empty() or not target:
		return null

	var dist := global_position.distance_to(target.global_position)
	var hp_pct := hp / max_hp
	var candidates: Array[BossAttackPattern] = []
	var weights: Array[float] = []
	var total_weight := 0.0

	for p: BossAttackPattern in attack_patterns:
		# Phase gate
		if current_phase_index < p.min_phase or current_phase_index > p.max_phase:
			continue
		# Cooldown
		if now < float(_pattern_cooldowns.get(p.id, 0.0)):
			continue
		# HP threshold gate (eg desperation patterns)
		if hp_pct > p.requires_hp_below_pct:
			continue
		# Reachability filter: skip patterns that can't land from current position.
		# Arena-wide and ground-targeted attacks always count as reachable.
		if not p.ignores_reachability:
			match p.shape:
				BossAttackPattern.Shape.SINGLE_TARGET, \
				BossAttackPattern.Shape.FORWARD_CONE, \
				BossAttackPattern.Shape.LINE:
					if dist > p.range + 1.5:
						continue
				BossAttackPattern.Shape.AOE_AROUND_BOSS:
					# Pointless if player is way outside the radius
					if dist > p.radius + 8.0:
						continue
				BossAttackPattern.Shape.PROJECTILE:
					if dist > p.range + 5.0:
						continue
		candidates.append(p)
		weights.append(p.priority_weight)
		total_weight += p.priority_weight

	if candidates.is_empty() or total_weight <= 0.0:
		return null

	# Weighted-random pick
	var roll := randf() * total_weight
	var acc := 0.0
	for i in range(candidates.size()):
		acc += weights[i]
		if roll <= acc:
			return candidates[i]
	return candidates[candidates.size() - 1]  # fallback

func _begin_pattern(p: BossAttackPattern, now: float) -> void:
	_current_pattern = p
	_pattern_state = &"windup"
	_pattern_state_until = now + p.windup_seconds
	# Spawn the danger-zone telegraph decal so the player can read the
	# attack BEFORE it lands. Removed when execute begins.
	_spawn_telegraph(p)

func _execute_pattern(p: BossAttackPattern) -> void:
	# Telegraph served its purpose: the strike has begun. Hitbox now
	# handles the actual damage; the decal is no longer informative.
	_clear_telegraph()
	# Spawn a Hitbox shaped by the pattern. Hitbox handles damage resolution.
	var hb := preload("res://scripts/combat/hitbox.gd").new()
	var ab := Ability.new()
	ab.id = p.id
	ab.base_damage = p.base_damage
	ab.damage_type = p.damage_type
	ab.armor_pen = p.armor_pen
	ab.target_mode = _shape_to_target_mode(p.shape)
	ab.range = p.range
	ab.radius = p.radius
	hb.ability = ab
	hb.attacker_stats = self
	hb.lifetime = max(0.05, p.execute_seconds)
	hb.team = &"enemy"

	var collider := CollisionShape3D.new()
	hb.add_child(collider)

	var fwd := -global_transform.basis.z
	fwd.y = 0
	fwd = fwd.normalized()

	match p.shape:
		BossAttackPattern.Shape.SINGLE_TARGET:
			var s := SphereShape3D.new()
			s.radius = 1.0
			collider.shape = s
			hb.position = (target.global_position if target else global_position + fwd * 2.0)
		BossAttackPattern.Shape.FORWARD_CONE:
			var b := BoxShape3D.new()
			b.size = Vector3(p.radius * 2.0, 2.5, p.range)
			collider.shape = b
			hb.position = global_position + fwd * (p.range * 0.5)
			hb.look_at(global_position + fwd * p.range, Vector3.UP)
		BossAttackPattern.Shape.AOE_AROUND_BOSS:
			var s := SphereShape3D.new()
			s.radius = p.radius
			collider.shape = s
			hb.position = global_position
		BossAttackPattern.Shape.AOE_GROUND:
			var s := SphereShape3D.new()
			s.radius = p.radius
			collider.shape = s
			hb.position = (target.global_position if target else global_position + fwd * p.range)
		BossAttackPattern.Shape.LINE:
			var b := BoxShape3D.new()
			b.size = Vector3(0.8, 2.0, p.range)
			collider.shape = b
			hb.position = global_position + fwd * (p.range * 0.5)
			hb.look_at(global_position + fwd * p.range, Vector3.UP)
		BossAttackPattern.Shape.PROJECTILE:
			var b := BoxShape3D.new()
			b.size = Vector3(0.5, 0.5, 1.0)
			collider.shape = b
			hb.position = global_position + fwd * 1.5
		BossAttackPattern.Shape.ARENA_WIDE:
			var s := SphereShape3D.new()
			s.radius = max(20.0, p.radius)
			collider.shape = s
			hb.position = global_position

	get_tree().current_scene.add_child(hb)

func _shape_to_target_mode(shape: int) -> int:
	match shape:
		BossAttackPattern.Shape.SINGLE_TARGET: return Ability.TargetMode.SELF
		BossAttackPattern.Shape.FORWARD_CONE: return Ability.TargetMode.FORWARD_CONE
		BossAttackPattern.Shape.AOE_AROUND_BOSS: return Ability.TargetMode.AOE_AROUND_SELF
		BossAttackPattern.Shape.AOE_GROUND: return Ability.TargetMode.GROUND_TARGETED
		BossAttackPattern.Shape.LINE: return Ability.TargetMode.FORWARD_CONE
		BossAttackPattern.Shape.PROJECTILE: return Ability.TargetMode.PROJECTILE
		_: return Ability.TargetMode.AOE_AROUND_SELF

func _check_phase_transition() -> void:
	var hp_pct: float = hp / max_hp
	var next_phase_index := current_phase_index
	for i in range(current_phase_index + 1, phases.size()):
		if hp_pct <= phases[i].hp_threshold_pct:
			next_phase_index = i
	if next_phase_index != current_phase_index:
		_enter_phase(next_phase_index)

func _enter_phase(idx: int) -> void:
	_in_transition = true
	current_phase_index = idx
	var p: Phase = phases[idx]
	contact_damage *= p.damage_mult
	move_speed *= p.move_speed_mult
	phase_changed.emit(idx, p.name)
	# Phase-shift cinematic: each cross of an HP gate is a moment.
	# Slowmo punch + sky-color flash + boss roar audio + music
	# intensity bump. Reads as 'the boss got harder, take notice'.
	_play_phase_transition_cinematic(idx, p)
	# Brief invulnerability so the cinematic transition lands cleanly
	get_tree().create_timer(p.transition_iframes).timeout.connect(func(): _in_transition = false)

func _play_phase_transition_cinematic(idx: int, p: Phase) -> void:
	var juice: Node = get_node_or_null("/root/Juice")
	# Color palette per phase: 0->normal, 1->amber, 2->crimson, 3->void
	var phase_colors := [
		Color(0.95, 0.55, 0.20, 1.0),  # phase 1 amber
		Color(0.95, 0.20, 0.20, 1.0),  # phase 2 crimson
		Color(0.55, 0.20, 0.85, 1.0),  # phase 3 void
		Color(1.00, 0.85, 0.30, 1.0),  # phase 4+ gold
	]
	var color: Color = phase_colors[min(idx - 1, phase_colors.size() - 1)] if idx > 0 else phase_colors[0]
	if juice:
		if juice.has_method("slowmo"):
			juice.slowmo(0.25, 0.6)  # punch
		if juice.has_method("flash"):
			juice.flash(color, 0.30, 0.45)
		if juice.has_method("shake"):
			juice.shake(0.50, 0.35)
		if juice.has_method("toast"):
			juice.toast("PHASE %d  %s" % [idx + 1, p.name.to_upper()], color, 3.0)
	# Boss roar audio (lower pitch on later phases)
	var ab: Node = get_node_or_null("/root/AudioBus")
	if ab and ab.has_method("play_cue"):
		var pitch: float = max(0.4, 0.7 - 0.1 * float(idx))
		ab.play_cue(&"death", global_position, -1.0, pitch)
		ab.play_cue(&"thunder", global_position, -3.0, 0.7)
	# Music: bump combat intensity for the phase. Phase 0=1.0,
	# 1=1.15, 2=1.3, 3=1.45 — saturating push as the boss escalates.
	var md: Node = get_node_or_null("/root/MusicDirector")
	if md and md.has_method("set_combat_intensity"):
		md.set_combat_intensity(1.0 + 0.15 * float(idx))

func _die(killer: Node) -> void:
	state = State.DEAD
	boss_defeated.emit(boss_id, killer)
	if killer and killer.get("stats") and killer.stats.has_method("gain_xp"):
		killer.stats.gain_xp(xp_reward)
	if killer and killer.has_method("on_kill_credit"):
		killer.on_kill_credit()
	_award_guaranteed_drops(killer)
	# Set save flags for major bosses (mini-bosses have their own quest flags via QuestLog)
	if is_main_boss or is_final_boss or is_secret_boss:
		SaveFlags.mark_boss_defeated(boss_id)
	queue_free()

func _award_guaranteed_drops(killer: Node) -> void:
	if not killer or not killer.has_method("receive_loot"):
		return

	# Guaranteed VERY_RARE
	if loot_table:
		var rolls: Array[Item] = loot_table.roll(get_node_or_null("/root/Prestige").current_prestige_level() if get_node_or_null("/root/Prestige") else 0)
		for it in rolls:
			killer.receive_loot(it)

	# 1% LEGENDARY for killer's class
	var killer_class: StringName = &""
	if killer.get("stats") and killer.stats.class_def:
		killer_class = killer.stats.class_def.class_id
	if randf() < 0.01 and killer_class != &"":
		var legendary: Item = LegendaryRegistry.get_legendary_for(killer_class)
		if legendary:
			killer.receive_loot(legendary)

	# Final-boss-only: 1% ANY legendary + 0.5% Heaven (Ronin only)
	if is_final_boss or is_secret_boss:
		if randf() < 0.01:
			var any_legendary: Item = LegendaryRegistry.random_legendary()
			if any_legendary:
				killer.receive_loot(any_legendary)
		# Heaven only drops if (a) killer is Ronin, (b) once per save profile.
		# The sword refuses to manifest for any other hand. Bond's design.
		if killer_class == &"ronin" and randf() < 0.005:
			if not SaveFlags.has_permanent(&"heaven_obtained"):
				killer.receive_loot(LegendaryRegistry.get_heaven())
				SaveFlags.set_permanent(&"heaven_obtained", true)

# --- Boss aura ---
# Crimson particle ring + ominous mote column at the boss's feet so
# they read as a 'serious threat' from far across the arena. Stays
# parented to the boss so it follows movement.
func _spawn_boss_aura() -> void:
	var aura := GPUParticles3D.new()
	aura.name = "BossAura"
	aura.amount = 60
	aura.lifetime = 2.2
	aura.preprocess = 1.5
	aura.visibility_aabb = AABB(Vector3(-3, 0, -3), Vector3(6, 4, 6))
	var mat := ParticleProcessMaterial.new()
	mat.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_RING
	mat.emission_ring_radius = 1.40
	mat.emission_ring_inner_radius = 1.00
	mat.emission_ring_axis = Vector3.UP
	mat.emission_ring_height = 0.10
	mat.direction = Vector3.UP
	mat.spread = 12.0
	mat.initial_velocity_min = 0.4
	mat.initial_velocity_max = 0.8
	mat.gravity = Vector3.ZERO
	mat.scale_min = 0.10
	mat.scale_max = 0.20
	# Crimson with slight orange to read as 'iron / blood / heat'
	mat.color = Color(0.85, 0.15, 0.20, 0.95)
	mat.tangential_accel_min = 0.6  # whirl effect
	mat.tangential_accel_max = 1.2
	aura.process_material = mat
	var quad := QuadMesh.new()
	quad.size = Vector2(0.18, 0.18)
	var smat := StandardMaterial3D.new()
	smat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	smat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	smat.albedo_color = Color(0.85, 0.15, 0.20, 0.95)
	smat.emission_enabled = true
	smat.emission = Color(0.85, 0.15, 0.20)
	smat.emission_energy_multiplier = 1.5
	smat.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
	smat.billboard_keep_scale = true
	quad.material = smat
	aura.draw_pass_1 = quad
	add_child(aura)
	aura.position = Vector3(0, 0.05, 0)

# --- Telegraph decals ---

# Build a flat MeshInstance3D + telegraph shader and place it on the
# ground where the attack will land. Called from _begin_pattern.
#
# Position rules per shape:
#   FORWARD_CONE / LINE     -> centered at boss feet, oriented toward target
#   AOE_AROUND_BOSS         -> centered at boss feet
#   AOE_GROUND / SINGLE_TARGET / PROJECTILE -> centered at target's position
#   ARENA_WIDE              -> centered at boss feet, large ring
func _spawn_telegraph(p: BossAttackPattern) -> void:
	_clear_telegraph()
	var decal := MeshInstance3D.new()
	decal.name = "Telegraph"
	var quad := PlaneMesh.new()
	# Quad is laid flat on the ground (default PlaneMesh is XZ plane). Size
	# the quad to the danger area so the shader's UV-based shape fills it.
	var size: Vector2 = _telegraph_size_for(p)
	quad.size = size
	decal.mesh = quad
	# Shader material with shape_id and color from the pattern
	var mat := ShaderMaterial.new()
	mat.shader = load("res://shaders/telegraph.gdshader")
	mat.set_shader_parameter("shape_id", int(p.shape))
	mat.set_shader_parameter("telegraph_color", p.telegraph_color)
	mat.set_shader_parameter("progress", 0.0)
	# Cone arc -- shader uses half-arc in radians
	mat.set_shader_parameter("arc_radians", deg_to_rad(p.arc_degrees) * 0.5)
	mat.set_shader_parameter("pulse_speed", 8.0)
	decal.material_override = mat
	# Place + orient
	var origin: Vector3 = _telegraph_origin_for(p)
	# Add as child of the world (current_scene) NOT the boss, so the
	# decal doesn't move when the boss does. Player needs a stable
	# danger zone they can dodge out of.
	get_tree().current_scene.add_child(decal)
	decal.global_position = origin + Vector3(0, _TELEGRAPH_HEIGHT, 0)
	# For shapes that have a forward direction (CONE, LINE), rotate the
	# decal so its +X axis aligns with the boss-to-target direction.
	if p.shape == BossAttackPattern.Shape.FORWARD_CONE or p.shape == BossAttackPattern.Shape.LINE:
		var dir: Vector3 = (target.global_position - global_position) if target else -global_transform.basis.z
		dir.y = 0
		if dir.length_squared() > 0.001:
			decal.rotation.y = atan2(dir.x, dir.z) - PI * 0.5
	_telegraph_decal = decal

func _clear_telegraph() -> void:
	if _telegraph_decal and is_instance_valid(_telegraph_decal):
		_telegraph_decal.queue_free()
	_telegraph_decal = null

# Size the decal quad to match the attack's footprint. The quad's UVs
# are 0..1 across the full surface, and the shader assumes the danger
# zone fills the quad.
func _telegraph_size_for(p: BossAttackPattern) -> Vector2:
	match p.shape:
		BossAttackPattern.Shape.SINGLE_TARGET, BossAttackPattern.Shape.PROJECTILE:
			# Small marker
			return Vector2(2.0, 2.0)
		BossAttackPattern.Shape.FORWARD_CONE:
			# Quad covers full cone reach, double the range for visual heft
			return Vector2(p.range * 2.0, p.range * 2.0)
		BossAttackPattern.Shape.AOE_AROUND_BOSS, BossAttackPattern.Shape.AOE_GROUND:
			return Vector2(p.radius * 2.0, p.radius * 2.0)
		BossAttackPattern.Shape.LINE:
			# Long thin strip; width = 2 (matches shader's 0.16 height band)
			return Vector2(p.range * 2.0, 2.0)
		BossAttackPattern.Shape.ARENA_WIDE:
			return Vector2(36.0, 36.0)
	return Vector2(2.0, 2.0)

# Where to PLACE the decal in world space.
func _telegraph_origin_for(p: BossAttackPattern) -> Vector3:
	match p.shape:
		BossAttackPattern.Shape.AOE_GROUND, BossAttackPattern.Shape.SINGLE_TARGET, BossAttackPattern.Shape.PROJECTILE:
			# Decal lands at the player's current location (where the
			# attack will resolve)
			return target.global_position if target else global_position
		_:
			# Centered on the boss
			return global_position
