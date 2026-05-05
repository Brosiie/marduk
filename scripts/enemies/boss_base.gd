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
