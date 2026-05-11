extends Node

# Global day/night clock. Single source of truth for time-based mechanics
# (Demon damage modifier, NPC schedules, ambient lighting cues).
#
# time_of_day: 0.0 = midnight, 0.25 = sunrise, 0.5 = noon, 0.75 = sunset.
# Cycles continuously unless paused. TimeOfDay nodes in scenes can read this
# and drive their visuals.

const DAY_START := 0.20  # post-dawn
const DAY_END := 0.80    # pre-dusk

@export var time_of_day: float = 0.4
@export var cycle_minutes: float = 8.0  # full cycle in real-time minutes
# 8 minutes per full day = sunrise visible at start of play session,
# noon by minute 4, dusk by 6, full night by 7. Override per-zone if a
# specific scene wants a frozen time of day (set paused = true and
# manually set time_of_day).
@export var paused: bool = false

signal time_changed(new_value: float)
signal became_day
signal became_night

var _was_night: bool = true

func _ready() -> void:
	_was_night = is_night()

func _process(delta: float) -> void:
	if paused:
		return
	time_of_day += delta / (cycle_minutes * 60.0)
	if time_of_day >= 1.0:
		time_of_day -= 1.0
	time_changed.emit(time_of_day)
	# Fire transition signals exactly once per crossing
	var night_now := is_night()
	if night_now != _was_night:
		if night_now:
			became_night.emit()
			_announce_transition(false)
		else:
			became_day.emit()
			_announce_transition(true)
		_was_night = night_now

# Toast the day/night transition through Juice. "Dawn breaks" doubles
# as a player-facing prompt that vendors restocked + NPCs returned to
# their daytime stalls. "Dusk falls" cues NPC commute to taverns + bed.
# Skipped silently if Juice isn't available (boot / unit-test paths).
func _announce_transition(is_dawn: bool) -> void:
	var juice: Node = get_node_or_null("/root/Juice")
	if juice == null or not juice.has_method("toast"):
		return
	if is_dawn:
		juice.toast("Dawn breaks. Vendors have restocked.", Color(1.0, 0.85, 0.45), 3.0)
	else:
		juice.toast("Dusk falls.", Color(0.55, 0.45, 0.85), 2.5)

func is_day() -> bool:
	return time_of_day >= DAY_START and time_of_day <= DAY_END

func is_night() -> bool:
	return not is_day()

func set_to_dawn() -> void:
	time_of_day = DAY_START

func set_to_noon() -> void:
	time_of_day = 0.5

func set_to_dusk() -> void:
	time_of_day = DAY_END

func set_to_midnight() -> void:
	time_of_day = 0.0
