extends Node

# Global save state singleton. Two namespaces:
#
#   PERMANENT flags  - survive prestige. Class unlocks (Demon), style unlocks (Sun
#                      Breathing), achievements, prestige_level counter, NG+ rewards.
#
#   RUN flags        - reset on prestige. World state for THIS cycle: bosses defeated,
#                      quests completed, dungeons cleared, NPC dialogue progression.
#
# When a player defeats Tiamat: set permanent.sun_breathing_unlocked AND run.tiamat_defeated.
# Prestige clears run flags but leaves permanent intact. Tiamat respawns; Sun stays known.

const SAVE_PATH := "user://save_flags.cfg"

var permanent: Dictionary = {}  # StringName -> Variant. Survives prestige.
var run_flags: Dictionary = {}  # StringName -> Variant. Cleared on prestige.

signal permanent_changed(name: StringName, value: Variant)
signal run_changed(name: StringName, value: Variant)
signal run_cleared

func _ready() -> void:
	load_state()

# === Permanent flags ===
func get_permanent(name: StringName, default: Variant = false) -> Variant:
	return permanent.get(name, default)

func set_permanent(name: StringName, value: Variant) -> void:
	permanent[name] = value
	permanent_changed.emit(name, value)
	save_state()

func has_permanent(name: StringName) -> bool:
	var v: Variant = permanent.get(name, null)
	return v != null and v != false

func increment_permanent(name: StringName, delta: int = 1) -> int:
	var current: int = int(permanent.get(name, 0))
	var next := current + delta
	permanent[name] = next
	permanent_changed.emit(name, next)
	save_state()
	return next

# === Run flags ===
func get_run(name: StringName, default: Variant = false) -> Variant:
	return run_flags.get(name, default)

func set_run(name: StringName, value: Variant) -> void:
	run_flags[name] = value
	run_changed.emit(name, value)
	save_state()

func has_run(name: StringName) -> bool:
	var v: Variant = run_flags.get(name, null)
	return v != null and v != false

func clear_run_flags() -> void:
	run_flags.clear()
	run_cleared.emit()
	save_state()

# === Boss defeat helper ===
# Sets the run flag (gates THIS cycle's world state) and the matching permanent unlock.
# Permanent unlocks survive prestige; run state resets so bosses are re-fightable next cycle.
func mark_boss_defeated(boss_id: StringName) -> void:
	set_run(StringName("%s_defeated" % boss_id), true)
	match boss_id:
		&"tiamat":
			set_permanent(&"sun_breathing_unlocked", true)
		&"lucifer":
			set_permanent(&"demon_class_unlocked", true)

func is_boss_defeated_this_cycle(boss_id: StringName) -> bool:
	return has_run(StringName("%s_defeated" % boss_id))

# === Class / style unlock helpers ===
func is_class_unlocked(class_def) -> bool:
	if class_def.unlocked_by_default:
		return true
	if class_def.unlock_save_flag == &"":
		return false
	return has_permanent(class_def.unlock_save_flag)

func is_breathing_style_unlocked(style) -> bool:
	if style.unlock_save_flag == &"":
		return true
	return has_permanent(style.unlock_save_flag)

# === Persistence ===
func save_state() -> void:
	var cfg := ConfigFile.new()
	for k in permanent.keys():
		cfg.set_value("permanent", String(k), permanent[k])
	for k in run_flags.keys():
		cfg.set_value("run", String(k), run_flags[k])
	var err := cfg.save(SAVE_PATH)
	if err != OK:
		push_warning("SaveFlags: failed to save: %s" % err)

func load_state() -> void:
	var cfg := ConfigFile.new()
	if cfg.load(SAVE_PATH) != OK:
		permanent = {}
		run_flags = {}
		return
	permanent.clear()
	run_flags.clear()
	if cfg.has_section("permanent"):
		for key in cfg.get_section_keys("permanent"):
			permanent[StringName(key)] = cfg.get_value("permanent", key)
	if cfg.has_section("run"):
		for key in cfg.get_section_keys("run"):
			run_flags[StringName(key)] = cfg.get_value("run", key)

func reset_everything() -> void:
	permanent.clear()
	run_flags.clear()
	save_state()
