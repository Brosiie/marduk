extends Node

# Global relay for combat events. Hitbox emits here; HUD and floaters subscribe.
# Decouples Hitbox from every consumer that needs hit data.
#
# class_name removed: this script is registered as an autoload named
# "CombatBus" in project.godot, and Godot 4 forbids `class_name` from
# matching an autoload name (would shadow the singleton lookup).
# Access from other scripts via `get_node("/root/CombatBus")` or by
# name (since autoloads are accessible globally).

signal hit_landed(target: Node, result: DamageCalc.Result, ability: Ability)
signal kill_registered(target: Node, killer: Node)
signal perfect_parry(position: Vector3)
signal stance_broken(position: Vector3)
# Emits when the rolling DPS exceeds 150% of the session-average DPS.
# CombatLog hooks this to log a one-liner so build-tuners see when
# their loop is hot. Cooldown'd so a sustained spike fires once, not
# every frame above threshold.
signal dps_spike(current_dps: float, session_avg: float)

func emit_hit(target: Node, result: DamageCalc.Result, ability: Ability) -> void:
	hit_landed.emit(target, result, ability)
	if result.killed:
		kill_registered.emit(target, null)
	var element: StringName = _element_name(ability.damage_type if ability else 0)
	# Per-element DPS bookkeeping so build-tuners can see whether their
	# 60%-fire-bonus build is actually fire-skewed in practice. Tracked
	# in a rolling 5-second window so the meter shows CURRENT damage
	# pace, not lifetime totals (those live in the player run-stats).
	_record_damage_for_dps(element, result.damage)
	# Spawn damage floater immediately so every hit gets a number.
	if target is Node3D:
		# Class tint on crits, only resolve when crit so the lookup
		# doesn't run on every hit.
		var class_tint: Color = _resolve_class_tint() if result.crit else Color(0,0,0,0)
		DamageFloater.spawn(target as Node3D, result.damage, result.crit, element, class_tint)

const _CLASS_CRIT_TINTS := {
	&"berserker":            Color(0.95, 0.35, 0.20),
	&"assassin":             Color(0.55, 0.85, 0.45),
	&"ronin":                Color(0.35, 0.65, 1.00),
	&"ranger":               Color(0.85, 0.95, 0.55),
	&"mage":                 Color(0.65, 0.40, 0.95),
	&"chaos_druid":          Color(0.65, 0.85, 0.45),
	&"demon":                Color(0.95, 0.30, 0.20),
	&"paladin_guardian":     Color(1.00, 0.85, 0.45),
	&"paladin_lightbringer": Color(1.00, 0.65, 0.55),
}

func _resolve_class_tint() -> Color:
	for p in get_tree().get_nodes_in_group("player"):
		if is_instance_valid(p) and p.get("stats") and p.stats and p.stats.get("class_def") and p.stats.class_def:
			var c: StringName = p.stats.class_def.class_id
			return _CLASS_CRIT_TINTS.get(c, Color(0,0,0,0))
	return Color(0,0,0,0)

func _element_name(damage_type: int) -> StringName:
	match damage_type:
		Ability.DamageType.FIRE:      return &"fire"
		Ability.DamageType.FROST:     return &"frost"
		Ability.DamageType.LIGHTNING: return &"lightning"
		Ability.DamageType.HOLY:      return &"holy"
		Ability.DamageType.SHADOW:    return &"shadow"
		Ability.DamageType.ARCANE:    return &"void"
		_:                            return &"physical"

# ───────── DPS by element ─────────
#
# Rolling 5-second window. Each hit drops a {time, element, amount}
# entry into _dps_log; the getter prunes entries older than DPS_WINDOW
# before summing. Build-tuners read get_dps_breakdown() to see how
# their actual DPS distributes across elements (vs. theoretical
# tooltip math).

const DPS_WINDOW: float = 5.0
const DPS_SPIKE_FACTOR: float = 1.5  # current must beat 150% of session avg
const DPS_SPIKE_COOLDOWN: float = 8.0  # min seconds between spike signals
const DPS_SPIKE_MIN_SESSION_TIME: float = 10.0  # need a baseline first
var _dps_log: Array = []  # of {t: float, element: StringName, dmg: float}
var _session_total_damage: float = 0.0
var _session_started_at: float = -1.0
var _last_dps_spike_at: float = -INF

func _record_damage_for_dps(element: StringName, damage: float) -> void:
	if damage <= 0.0:
		return
	var now: float = Time.get_ticks_msec() / 1000.0
	_dps_log.append({"t": now, "element": element, "dmg": damage})
	# Prune occasionally so the array doesn't grow unbounded between
	# reader calls. ~every 32 entries is cheap and keeps memory tight.
	if _dps_log.size() % 32 == 0:
		_prune_dps_log(now)
	# Session-average bookkeeping: total damage / session-elapsed gives
	# a baseline. We emit dps_spike when the rolling current DPS exceeds
	# DPS_SPIKE_FACTOR * session_avg. Cooldown'd so a sustained spike
	# fires once rather than every frame.
	_session_total_damage += damage
	if _session_started_at < 0.0:
		_session_started_at = now
	_check_dps_spike(now)

func _prune_dps_log(now: float) -> void:
	var cutoff: float = now - DPS_WINDOW
	var keep: Array = []
	for e in _dps_log:
		if float(e["t"]) >= cutoff:
			keep.append(e)
	_dps_log = keep

# Returns {element_id: dps_float} for each element with damage in the
# current window. Reader-friendly: sums over WINDOW seconds and divides
# by the actual elapsed time of the oldest tracked hit (or DPS_WINDOW
# if the window is full), so a 1-second burst of 600 dmg reads as
# 600 dps not 120.
func get_dps_breakdown() -> Dictionary:
	var now: float = Time.get_ticks_msec() / 1000.0
	_prune_dps_log(now)
	if _dps_log.is_empty():
		return {}
	var by_element: Dictionary = {}
	var oldest_t: float = float(_dps_log[0]["t"])
	for e in _dps_log:
		var el: StringName = e["element"]
		by_element[el] = float(by_element.get(el, 0.0)) + float(e["dmg"])
		oldest_t = min(oldest_t, float(e["t"]))
	var elapsed: float = max(0.5, now - oldest_t)
	for k in by_element.keys():
		by_element[k] = float(by_element[k]) / elapsed
	return by_element

# Total DPS across all elements over the rolling window. Cheap call
# for HUD / nameplate / cast-bar to show "current DPS = N" at a glance.
func get_dps_total() -> float:
	var by_el: Dictionary = get_dps_breakdown()
	var sum: float = 0.0
	for v in by_el.values():
		sum += float(v)
	return sum

# Session-average DPS. Useful as a baseline against which the rolling
# window compares for spike detection. Returns 0 until at least
# DPS_SPIKE_MIN_SESSION_TIME seconds of session.
func get_session_avg_dps() -> float:
	if _session_started_at < 0.0:
		return 0.0
	var now: float = Time.get_ticks_msec() / 1000.0
	var elapsed: float = now - _session_started_at
	if elapsed < DPS_SPIKE_MIN_SESSION_TIME:
		return 0.0
	return _session_total_damage / elapsed

# Spike detection: if current rolling DPS is over DPS_SPIKE_FACTOR x
# session_avg AND we haven't fired recently, emit dps_spike. CombatLog
# subscribes to log a "DPS SPIKE: 1,240" line for build-tuners.
func _check_dps_spike(now: float) -> void:
	if now - _last_dps_spike_at < DPS_SPIKE_COOLDOWN:
		return
	var avg: float = get_session_avg_dps()
	if avg <= 0.0:
		return  # not enough session time yet
	var current: float = get_dps_total()
	if current >= avg * DPS_SPIKE_FACTOR:
		_last_dps_spike_at = now
		dps_spike.emit(current, avg)
