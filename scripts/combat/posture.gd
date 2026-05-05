extends Node
class_name Posture

# Sekiro-inspired posture/stagger system. Separate track from HP. Filling the bar
# breaks stance, opening a window for a deathblow (massive damage) or finisher.
#
# Hits accumulate posture damage. Successful guards reduce it. Posture regens out
# of combat after a short delay.
#
# Use: attach as child of Player or EnemyBase. Hitbox damage handlers call
# `add_posture_damage(amount, was_blocked)`.

signal posture_changed(current: float, max_value: float)
signal posture_broken
signal stance_recovered

@export var max_posture: float = 100.0
@export var current_posture: float = 0.0  # 0 = full stance, max = broken
@export var regen_rate: float = 25.0  # per second when out of combat
@export var regen_delay: float = 1.0   # seconds since last damage before regen begins
@export var block_dampening: float = 0.5  # blocked hits do this fraction of posture damage
@export var perfect_block_dampening: float = 0.0  # perfect parry does no posture damage
@export var hp_low_amplifier: float = 1.5  # at low HP, posture takes more damage (Sekiro behavior)

var _last_damage_time: float = -INF
var _broken_until: float = -INF
const BROKEN_LOCKOUT := 2.5  # how long stance break lasts (deathblow window)

func _process(delta: float) -> void:
	var now := Time.get_ticks_msec() / 1000.0
	if now < _broken_until:
		return  # frozen during stance break
	if now - _last_damage_time >= regen_delay and current_posture > 0.0:
		current_posture = max(0.0, current_posture - regen_rate * delta)
		posture_changed.emit(current_posture, max_posture)

func add_posture_damage(amount: float, was_blocked: bool = false, was_perfect_parry: bool = false, holder_hp_pct: float = 1.0) -> void:
	var dmg := amount
	if was_perfect_parry:
		dmg *= perfect_block_dampening
	elif was_blocked:
		dmg *= block_dampening
	# Low HP makes stance more fragile (Sekiro philosophy: weak fighters guard worse)
	if holder_hp_pct < 0.3:
		dmg *= hp_low_amplifier
	current_posture = min(max_posture, current_posture + dmg)
	_last_damage_time = Time.get_ticks_msec() / 1000.0
	posture_changed.emit(current_posture, max_posture)
	if current_posture >= max_posture:
		_break()

func _break() -> void:
	_broken_until = Time.get_ticks_msec() / 1000.0 + BROKEN_LOCKOUT
	posture_broken.emit()

func is_broken() -> bool:
	return Time.get_ticks_msec() / 1000.0 < _broken_until

func clear() -> void:
	current_posture = 0.0
	_broken_until = -INF
	posture_changed.emit(0.0, max_posture)
	stance_recovered.emit()
