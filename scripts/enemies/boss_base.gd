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
	hp = max_hp
	contact_damage *= lvl_mult
	xp_reward = int(xp_reward * lvl_mult * 2.5)  # bosses give meaty XP

	# Inflate phase data
	for d in phases_data:
		var p := Phase.new()
		p.hp_threshold_pct = float(d.get("hp_pct", 1.0))
		p.name = d.get("name", "")
		p.damage_mult = float(d.get("dmg_mult", 1.0))
		p.move_speed_mult = float(d.get("speed_mult", 1.0))
		phases.append(p)

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

func _execute_pattern(p: BossAttackPattern) -> void:
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
	# Brief invulnerability so the cinematic transition lands cleanly
	get_tree().create_timer(p.transition_iframes).timeout.connect(func(): _in_transition = false)

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
