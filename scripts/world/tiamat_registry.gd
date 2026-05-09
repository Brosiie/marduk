extends Node

# Autoload: Tiamat awareness, the global "she stirs" counter that turns
# the player's progress into cosmic stakes. Every prologue boss kill,
# every faction tilt, every Wound-aligned glyph inscription, every
# faction war event ticks awareness up. The world reads it back through
# WeatherDirector / SkyDirector / MobRegistry / DialogueRegistry as
# tiered visual + narrative effects.
#
# class_name removed: registered as `TiamatRegistry` autoload in
# project.godot. Persists to SaveFlags as a permanent (cross-prestige)
# value because Tiamat's dream remembers what the player did even
# across prestige cycles.
#
# Awareness ranges 0 to 100. Tier breakpoints are wide so tier
# transitions feel earned rather than mechanical:
#
#   DORMANT   [0,   25)   world feels normal
#   STIRRING  [25,  50)   storms more common, mob populations skew
#   WAKING    [50,  75)   Awakening Heralds rare-spawn, NPC dialog
#                          carries dread, sky tints toward purple
#   WAKING_2  [75, 100)   Tiamat speaks in lodestone meditations,
#                          time-of-day cycle slows, zone-edge corruption
#                          visible in adjacent territories
#   AWAKE    [100, +inf)  final encounter unlocks; boss fights apply
#                          a global awareness-scaled difficulty mult

signal awareness_changed(new_value: int, old_value: int)
signal tier_changed(new_tier: String, old_tier: String, new_value: int)

const _SAVEFLAG_AWARENESS: StringName = &"tiamat_awareness"
const AWARENESS_MIN: int = 0
const AWARENESS_MAX: int = 999  # uncapped above 100 so completionists feel weight at endgame

# Tier breakpoints. Order matters: lookup walks ascending and returns
# the first matching tier. Above 100 stays AWAKE.
const TIER_BREAKPOINTS := [
	{"min":   0, "max":  25, "name": "DORMANT"},
	{"min":  25, "max":  50, "name": "STIRRING"},
	{"min":  50, "max":  75, "name": "WAKING"},
	{"min":  75, "max": 100, "name": "WAKING_2"},
	{"min": 100, "max": 99999, "name": "AWAKE"},
]

# Per-source awareness deltas. Centralized here so the cost curve is
# visible in one place rather than scattered through 14 call sites.
# Adjust these to retune pacing without hunting for the sources.
const DELTA_PROLOGUE_BOSS_KILL: int = 8     # 7 prologues = 56, lands mid-WAKING by Ashurim arrival
const DELTA_MAIN_BOSS_KILL: int = 5         # mid-tier story bosses contribute less than prologues
const DELTA_TIAMAT_SPAWN_KILL: int = 1      # mob-tier, accumulates slowly
const DELTA_FACTION_REP_TIER_UP: int = 2    # pressing harder into ANY faction wakes her
const DELTA_GLYPH_INSCRIBE_WOUND: int = 4   # binding the Wound's mark feeds her directly
const DELTA_GLYPH_INSCRIBE_OTHER: int = 1   # other glyphs barely register
const DELTA_LODESTONE_DISCOVER: int = 1     # exploration counts a little
const DELTA_DRUID_QUEST_COMPLETE: int = -3  # tending the Wound REDUCES awareness
const DELTA_INQUISITION_QUEST_COMPLETE: int = 4  # burning the Wound aggravates her instead

func _ready() -> void:
	# Subscribe to publisher registries on next frame: those autoloads
	# may not have finished _ready themselves yet at this exact tick.
	# call_deferred is the standard Godot pattern for cross-autoload
	# wiring.
	call_deferred("_wire_signal_sources")

func _wire_signal_sources() -> void:
	# FactionRegistry.tier_changed: every faction tier-up wakes her a
	# little. We hook the SIGNAL rather than amending FactionRegistry
	# itself so the faction system stays standalone and Tiamat is the
	# subscriber. Tier DOWN doesn't tick (she only stirs on rising
	# tension, not on rep loss).
	var fr: Node = get_node_or_null("/root/FactionRegistry")
	if fr and fr.has_signal("tier_changed"):
		var fcb := Callable(self, "_on_faction_tier_changed")
		if not fr.tier_changed.is_connected(fcb):
			fr.tier_changed.connect(fcb)
	# LodestoneRegistry.discovered: exploration counts a little. The
	# more of the world the player has touched, the more there is for
	# her to react to.
	var lr: Node = get_node_or_null("/root/LodestoneRegistry")
	if lr and lr.has_signal("discovered"):
		var lcb := Callable(self, "_on_lodestone_discovered")
		if not lr.discovered.is_connected(lcb):
			lr.discovered.connect(lcb)
	# GlyphRegistry.glyph_inscribed: binding the Wound's mark feeds
	# her directly; other glyphs barely register.
	var gr: Node = get_node_or_null("/root/GlyphRegistry")
	if gr and gr.has_signal("glyph_inscribed"):
		var gcb := Callable(self, "_on_glyph_inscribed")
		if not gr.glyph_inscribed.is_connected(gcb):
			gr.glyph_inscribed.connect(gcb)

func _on_faction_tier_changed(faction_id: StringName, _new_tier: String, old_tier: String) -> void:
	# Only count tier UPS. Tier_changed fires on both directions so we
	# need to compare. The breakpoint table in FactionRegistry is
	# strictly ordered, so a string compare against tier ordering
	# would be fragile; we just take the rep value via FactionRegistry
	# instead.
	var fr: Node = get_node_or_null("/root/FactionRegistry")
	if fr == null:
		return
	# Heuristic: if the old tier is among the lower tiers (Hated /
	# Hostile / Unfriendly / Neutral), any change to a higher band is
	# a tier-up; otherwise also count Friendly -> Honored / Honored ->
	# Revered / Revered -> Exalted as tier-ups. Simpler: treat any
	# tier change OTHER than going DOWN as awareness-positive.
	const _DESCENT_TARGETS := ["Hated", "Hostile", "Unfriendly", "Neutral"]
	const _DESCENT_FROM_HIGHER := ["Friendly", "Honored", "Revered", "Exalted"]
	# If we descended into a lower band, skip
	if old_tier in _DESCENT_FROM_HIGHER and fr.has_method("get_rep"):
		var current_rep: int = int(fr.get_rep(faction_id))
		if current_rep < 3000:  # below Friendly = descended
			return
	on_faction_tier_up(faction_id)

func _on_lodestone_discovered(_id, _name = null) -> void:
	on_lodestone_discovered()

func _on_glyph_inscribed(_glyph, _location = null, _character = null) -> void:
	# GlyphRegistry.glyph_inscribed signal carries (glyph, location, character_id).
	# We only need the glyph id for the Wound-or-other split.
	var glyph_id: StringName = &""
	if _glyph and _glyph.get("id"):
		glyph_id = StringName(_glyph.get("id"))
	on_glyph_inscribed(glyph_id)

# ────────── Public API ──────────

func get_awareness() -> int:
	var sf: Node = get_node_or_null("/root/SaveFlags")
	if sf == null or not sf.has_method("get_permanent"):
		return AWARENESS_MIN
	return int(sf.get_permanent(_SAVEFLAG_AWARENESS, AWARENESS_MIN))

func set_awareness(value: int) -> void:
	add_awareness(value - get_awareness())

func add_awareness(delta: int) -> int:
	if delta == 0:
		return get_awareness()
	var old: int = get_awareness()
	var new_val: int = clamp(old + delta, AWARENESS_MIN, AWARENESS_MAX)
	if new_val == old:
		return old  # clamped to no-op
	var sf: Node = get_node_or_null("/root/SaveFlags")
	if sf and sf.has_method("set_permanent"):
		sf.set_permanent(_SAVEFLAG_AWARENESS, new_val)
	awareness_changed.emit(new_val, old)
	var old_tier: String = tier_for(old)
	var new_tier: String = tier_for(new_val)
	if old_tier != new_tier:
		tier_changed.emit(new_tier, old_tier, new_val)
		_announce_tier_change(new_tier, old_tier, delta > 0)
	return new_val

# Convenience hooks. Call sites use these instead of add_awareness so
# the source semantics are documented and pacing is tunable in one place.
func on_prologue_boss_killed(_boss_id: StringName) -> void:
	add_awareness(DELTA_PROLOGUE_BOSS_KILL)

func on_main_boss_killed(_boss_id: StringName) -> void:
	add_awareness(DELTA_MAIN_BOSS_KILL)

func on_tiamat_spawn_killed() -> void:
	add_awareness(DELTA_TIAMAT_SPAWN_KILL)

func on_faction_tier_up(_faction_id: StringName) -> void:
	add_awareness(DELTA_FACTION_REP_TIER_UP)

func on_glyph_inscribed(glyph_id: StringName) -> void:
	# Wound-affiliated glyphs feed her the most. Other glyphs are
	# spiritual noise. The substring check keeps this future-proof
	# against new glyphs without amending this function.
	if String(glyph_id).find("wound") >= 0 or String(glyph_id).find("druid") >= 0:
		add_awareness(DELTA_GLYPH_INSCRIBE_WOUND)
	else:
		add_awareness(DELTA_GLYPH_INSCRIBE_OTHER)

func on_lodestone_discovered() -> void:
	add_awareness(DELTA_LODESTONE_DISCOVER)

func on_druid_quest_completed() -> void:
	add_awareness(DELTA_DRUID_QUEST_COMPLETE)

func on_inquisition_quest_completed() -> void:
	add_awareness(DELTA_INQUISITION_QUEST_COMPLETE)

# ────────── Tier resolution ──────────

func tier_for(value: int) -> String:
	for entry in TIER_BREAKPOINTS:
		if value >= int(entry["min"]) and value < int(entry["max"]):
			return String(entry["name"])
	return "AWAKE"  # fallback for values past the table

func current_tier() -> String:
	return tier_for(get_awareness())

# Returns 0..1 progress within the current tier. Useful for HUD bars
# that visualize the threat creeping up before the next transition.
func tier_progress() -> float:
	var v: int = get_awareness()
	for entry in TIER_BREAKPOINTS:
		var lo: int = int(entry["min"])
		var hi: int = int(entry["max"])
		if v >= lo and v < hi:
			return clamp(float(v - lo) / float(max(1, hi - lo)), 0.0, 1.0)
	return 1.0

# ────────── UI announcement ──────────

func _announce_tier_change(new_tier: String, _old_tier: String, was_increase: bool) -> void:
	# Tier UP is a moment. Tier DOWN (only via Druid quests reducing
	# awareness past a boundary) is a smaller moment but still worth
	# acknowledging because it's rare and earned.
	var juice: Node = get_node_or_null("/root/Juice")
	if juice == null or not juice.has_method("toast"):
		return
	var msg: String = ""
	var color: Color = Color(0.65, 0.30, 0.85)  # purple, Tiamat's signal
	if was_increase:
		match new_tier:
			"STIRRING": msg = "Something stirs in the deep."
			"WAKING":   msg = "The deep dreams of you."
			"WAKING_2": msg = "She wakes. The world tilts."
			"AWAKE":    msg = "Tiamat rises."
			_:          return
	else:
		# Awareness dropped a tier (Druid stabilization quest payoff)
		msg = "The deep settles. For now."
		color = Color(0.55, 0.85, 0.45)
	juice.toast(msg, color, 4.5)
	# Optional audio: layered low rumble. Skipped silently if AudioBus
	# doesn't expose the cue.
	var ab: Node = get_node_or_null("/root/AudioBus")
	if ab and ab.has_method("play_cue"):
		var pitch: float = 0.6 if was_increase else 1.2
		ab.play_cue(&"thunder", Vector3.ZERO, -3.0, pitch)
