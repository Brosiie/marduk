extends Node

# AutoSave, autoload that calls SaveSystem.save_slot(0, player) every
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
# Track whether we've already wired event-driven autosave hooks
# so we don't double-subscribe on scene reload.
var _event_hooks_wired: bool = false
# True once the player's leveled_up signal is connected. Prevents
# the _attach_player_signals retry from chaining timers forever
# when no player ever spawns (eg start-menu sessions).
var _player_signals_attached: bool = false

func _ready() -> void:
	# Hook event-driven save triggers in addition to the 60s timer.
	# Major state changes (level-up, lodestone discover, boss defeat)
	# should crystallize IMMEDIATELY so a crash 5s after a milestone
	# doesn't lose it. The 60s timer remains as a safety net for
	# everything in between.
	call_deferred("_wire_event_hooks")

func _wire_event_hooks() -> void:
	if _event_hooks_wired:
		return
	_event_hooks_wired = true
	# Lodestone discovery
	var lr: Node = get_node_or_null("/root/LodestoneRegistry")
	if lr and lr.has_signal("discovered"):
		var cb := Callable(self, "_on_milestone_event")
		if not lr.discovered.is_connected(cb):
			lr.discovered.connect(cb)
	# Quest accept + complete already trigger save_to_save_flags +
	# _request_autosave inside QuestRegistry. Listening here would
	# double-save; skip.
	# Player level-up, defer until player exists (player isn't in
	# the tree at autoload-_ready time)
	_attach_player_signals()

func _attach_player_signals() -> void:
	# Idempotent: once connected, never re-fire the retry chain. Without
	# this guard, sitting on the start menu (no player) would chain
	# 0.5s timers forever, leaking a Timer per tick.
	if _player_signals_attached:
		return
	var p: Node = get_tree().get_first_node_in_group("player") if get_tree() else null
	if p == null:
		# Retry on next frame until player spawns
		get_tree().create_timer(0.5).timeout.connect(_attach_player_signals)
		return
	if p.get("stats") and p.stats.has_signal("leveled_up"):
		var cb := Callable(self, "_on_milestone_event_int")
		if not p.stats.leveled_up.is_connected(cb):
			p.stats.leveled_up.connect(cb)
	_player_signals_attached = true

func _on_milestone_event(_a = null, _b = null) -> void:
	# Generic catch-all for signals with 0-2 args. Saving immediately
	# on these moments lets the player recover their progress even if
	# they alt-F4 right after the achievement.
	_attempt_save()

func _on_milestone_event_int(_n: int) -> void:
	# Variant for signals that pass an int (level number).
	_attempt_save()

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
	# Don't autosave during boss fights or while dead, those are bad
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
