extends Node

# AutoSave — autoload that calls SaveSystem.save_slot(0, player) every
# AUTO_SAVE_INTERVAL seconds while a player exists in the scene.
#
# Quiet by design: only logs to the combat log and console, never blocks
# gameplay. If SaveSystem isn't loaded yet (e.g. early in start menu),
# the save tick is skipped and retried next interval.
#
# Slot 0 is the autosave. Manual saves via OptionsPanel write to slot 0
# too, so players can resume from either flow seamlessly.

const AUTO_SAVE_INTERVAL: float = 60.0  # seconds

var _enabled: bool = true
var _ticks_since_save: float = 0.0

func _process(delta: float) -> void:
	if not _enabled:
		return
	_ticks_since_save += delta
	if _ticks_since_save < AUTO_SAVE_INTERVAL:
		return
	_ticks_since_save = 0.0
	_attempt_save()

func _attempt_save() -> void:
	var player := get_tree().get_first_node_in_group("player") if get_tree() else null
	if player == null:
		return
	# Don't autosave during boss fights or while dead — those are bad
	# moments to crystallize state.
	if "locked" in player and player.locked:
		return
	if "stats" in player and player.stats and "hp" in player.stats and player.stats.hp <= 0.0:
		return
	var save_sys := get_node_or_null("/root/SaveSystem")
	if save_sys == null or not save_sys.has_method("save_slot"):
		return
	if save_sys.save_slot(0, player):
		# Log a soft toast via combat log if it exists
		var hud := get_tree().get_first_node_in_group("hud") if get_tree() else null
		if hud and hud.has_method("get_node"):
			var log_node := hud.get_node_or_null("Root/CombatLog")
			if log_node and log_node.has_method("log_event"):
				log_node.log_event("Autosaved.", Color(0.6, 0.7, 0.85))

func set_enabled(yes: bool) -> void:
	_enabled = yes
	if yes:
		_ticks_since_save = 0.0
