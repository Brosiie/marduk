extends Node

# Autoload: Wound creep, the second cosmic-threat counter alongside
# Tiamat awareness. Tracks how far the Verdant Wound has spread its
# corruption. Druids tend it (containment, decreases creep). Inquisition
# burns it (which the Druids say SPREADS the corruption like a fire fed
# wrong, increases creep). The narrative bet: Druids are right and
# Inquisition genuinely makes things worse without knowing it.
#
# Independent of TiamatRegistry: same publisher pattern, same SaveFlags
# storage shape, but creep responds to a smaller set of inputs and is
# reducible (unlike Tiamat awareness which only goes up except via
# specific stabilization quests).
#
# class_name removed: registered as `WoundRegistry` autoload in
# project.godot. Persists to SaveFlags as PERMANENT (cross-prestige)
# because the Wound's spread accumulates across the world's lifetime.
#
# Creep ranges 0 to 100. Tier breakpoints chosen to give the player
# meaningful visible state changes:
#
#   CONTAINED  [0,  20)   nothing visible; world feels normal
#   SEEPING    [20, 45)   Wound-corrupted mobs at zone-adjacent edges
#   BLEEDING   [45, 70)   Wound mobs common in adjacent zones, NPC dread
#   UNCONTAINED[70, 90)   zone-edge shaders dim, mob spawn shifted heavy
#   CONSUMING  [90, +inf) certain Druid quests lock (too late to stabilize)

signal creep_changed(new_value: int, old_value: int)
signal tier_changed(new_tier: String, old_tier: String, new_value: int)

const _SAVEFLAG_CREEP: StringName = &"wound_creep"
const CREEP_MIN: int = 0
const CREEP_MAX: int = 999  # uncapped above 100 for completionists who refuse to stabilize

const TIER_BREAKPOINTS := [
	{"min":   0, "max":  20, "name": "CONTAINED"},
	{"min":  20, "max":  45, "name": "SEEPING"},
	{"min":  45, "max":  70, "name": "BLEEDING"},
	{"min":  70, "max":  90, "name": "UNCONTAINED"},
	{"min":  90, "max": 99999, "name": "CONSUMING"},
]

# Per-source creep deltas. Centralized so pacing is one file edit.
# Druid stabilization quests reduce creep more than Inquisition burns
# raise it because the player needs a reachable path back from any
# escalation. Without that asymmetry, a single burn quest could lock
# the player into runaway creep.
const DELTA_DRUID_QUEST_COMPLETE: int = -5
const DELTA_INQUISITION_QUEST_COMPLETE: int = 4
const DELTA_WOUND_GLYPH_INSCRIBE: int = 2  # binding the mark on yourself feeds the spread
const DELTA_WOUND_BOSS_KILL: int = -8  # killing a Wound-Marked boss is a hard reset, biggest single delta

# ────────── Public API ──────────

func get_creep() -> int:
	var sf: Node = get_node_or_null("/root/SaveFlags")
	if sf == null or not sf.has_method("get_permanent"):
		return CREEP_MIN
	return int(sf.get_permanent(_SAVEFLAG_CREEP, CREEP_MIN))

func set_creep(value: int) -> void:
	add_creep(value - get_creep())

func add_creep(delta: int) -> int:
	if delta == 0:
		return get_creep()
	var old: int = get_creep()
	var new_val: int = clamp(old + delta, CREEP_MIN, CREEP_MAX)
	if new_val == old:
		return old
	var sf: Node = get_node_or_null("/root/SaveFlags")
	if sf and sf.has_method("set_permanent"):
		sf.set_permanent(_SAVEFLAG_CREEP, new_val)
	creep_changed.emit(new_val, old)
	var old_tier: String = tier_for(old)
	var new_tier: String = tier_for(new_val)
	if old_tier != new_tier:
		tier_changed.emit(new_tier, old_tier, new_val)
		_announce_tier_change(new_tier, old_tier, delta > 0)
	return new_val

# Convenience hooks. Centralizes the source semantics so pacing tuning
# is one file. on_* are the canonical entry points; subscribers should
# call these rather than add_creep directly.
func on_druid_quest_completed() -> void:
	add_creep(DELTA_DRUID_QUEST_COMPLETE)

func on_inquisition_quest_completed() -> void:
	add_creep(DELTA_INQUISITION_QUEST_COMPLETE)

func on_wound_glyph_inscribed() -> void:
	add_creep(DELTA_WOUND_GLYPH_INSCRIBE)

func on_wound_boss_killed() -> void:
	add_creep(DELTA_WOUND_BOSS_KILL)

# ────────── Tier resolution ──────────

func tier_for(value: int) -> String:
	for entry in TIER_BREAKPOINTS:
		if value >= int(entry["min"]) and value < int(entry["max"]):
			return String(entry["name"])
	return "CONSUMING"

func current_tier() -> String:
	return tier_for(get_creep())

func tier_progress() -> float:
	var v: int = get_creep()
	for entry in TIER_BREAKPOINTS:
		var lo: int = int(entry["min"])
		var hi: int = int(entry["max"])
		if v >= lo and v < hi:
			return clamp(float(v - lo) / float(max(1, hi - lo)), 0.0, 1.0)
	return 1.0

# ────────── Wiring ──────────

func _ready() -> void:
	call_deferred("_wire_signal_sources")

func _wire_signal_sources() -> void:
	# Subscribe to QuestRegistry.quest_completed and route based on
	# faction_rep_changes direction. Same dispatch shape as TiamatRegistry.
	var qr: Node = get_node_or_null("/root/QuestRegistry")
	if qr and qr.has_signal("quest_completed"):
		var qcb := Callable(self, "_on_quest_completed")
		if not qr.quest_completed.is_connected(qcb):
			qr.quest_completed.connect(qcb)
	# Subscribe to GlyphRegistry.glyph_inscribed for wound-mark feed.
	var gr: Node = get_node_or_null("/root/GlyphRegistry")
	if gr and gr.has_signal("glyph_inscribed"):
		var gcb := Callable(self, "_on_glyph_inscribed")
		if not gr.glyph_inscribed.is_connected(gcb):
			gr.glyph_inscribed.connect(gcb)

func _on_quest_completed(quest) -> void:
	if quest == null or not "faction_rep_changes" in quest:
		return
	var changes: Dictionary = quest.faction_rep_changes
	if changes.is_empty():
		return
	var druid_delta: int = int(changes.get(&"druids", 0))
	var inq_delta: int = int(changes.get(&"inquisition", 0))
	# Use the stronger signal so a mixed quest doesn't double-tick.
	if druid_delta > 0 and druid_delta >= abs(inq_delta):
		on_druid_quest_completed()
	elif inq_delta > 0:
		on_inquisition_quest_completed()

func _on_glyph_inscribed(_glyph, _location = null, _character = null) -> void:
	var glyph_id: StringName = &""
	if _glyph and _glyph.get("id"):
		glyph_id = StringName(_glyph.get("id"))
	# Only Wound-aligned glyphs feed the spread.
	if String(glyph_id).find("wound") >= 0 or String(glyph_id).find("druid") >= 0:
		on_wound_glyph_inscribed()

# ────────── UI announcement ──────────

func _announce_tier_change(new_tier: String, _old_tier: String, was_increase: bool) -> void:
	var juice: Node = get_node_or_null("/root/Juice")
	if juice == null or not juice.has_method("toast"):
		return
	var msg: String = ""
	# Wound-green palette, distinct from Tiamat's purple. The two
	# threats should read as separate cosmic forces, not one.
	var color: Color = Color(0.55, 0.75, 0.40)
	if was_increase:
		match new_tier:
			"SEEPING":     msg = "The Wound bleeds wider."
			"BLEEDING":    msg = "The Wound is bleeding through."
			"UNCONTAINED": msg = "The Wound is uncontained. The Druids cannot hold it alone."
			"CONSUMING":   msg = "The Wound consumes. The frontier is gone."
			_:             return
		color = Color(0.40, 0.65, 0.30)  # darker green = warning
	else:
		# Player tended the Wound back. The Sanctum-Mother thanks them
		# in spirit; the line is bright because tending earned it.
		msg = "The Wound settles. The Sanctum-Mother breathes easier."
		color = Color(0.55, 0.85, 0.45)
	juice.toast(msg, color, 4.0)
	# Audio: lodestone cue at vegetal pitch. Distinct from Tiamat's
	# thunder so the player can tell which threat moved.
	var ab: Node = get_node_or_null("/root/AudioBus")
	if ab and ab.has_method("play_cue"):
		var pitch: float = 0.85 if was_increase else 1.15
		ab.play_cue(&"lodestone", Vector3.ZERO, -5.0, pitch)
