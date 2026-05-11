extends Node

# Autoload: faction PAIR-state machine. Where FactionRegistry tracks
# the player's rep with each faction in isolation, this layer tracks
# RELATIONSHIPS between factions and the player's effect on them.
#
# Same publisher/subscriber pattern as TiamatRegistry / WoundRegistry:
# subscribe to upstream signals (FactionRegistry.rep_changed,
# WoundRegistry.creep_changed), recompute state per tracked pair,
# emit pair_state_changed on transitions.
#
# class_name removed: registered as `FactionConflictRegistry` autoload
# in project.godot. Persists state via SaveFlags as run-scoped
# (per-prestige) values keyed "conflict_<pair_key>".
#
# State enum per pair:
#   COLD     = status quo, no overt tension
#   TENSE    = NPCs gossip, no skirmishes yet
#   SKIRMISH = open hostility, faction-vs-faction events at borders
#   OPEN_WAR = territory shifts, quest availability changes,
#              refugee NPCs spawn
#
# Tracked pairs (v1):
#   druid_vs_inquisition: the central political tension
#   crown_vs_black_sail:  the smuggling tension (Iddinu's side-gig
#                          strains this)
#   crown_vs_druid:       the slower-burning territorial tension
#
# Transition rules: pair state advances when EITHER side's rep
# crosses a threshold OR a relevant cosmic threat hits a tier
# boundary that would inflame the relationship. Rules per pair are
# in PAIR_RULES below.

signal pair_state_changed(pair_key: StringName, new_state: String, old_state: String)

const _SAVEFLAG_PREFIX: String = "conflict_"

# State names. Strings so the toast layer + UI surface can render
# without an additional enum-to-string mapping. Ordered roughly by
# tension so a numerical compare works for "which is hotter."
const STATES: Array[String] = ["COLD", "TENSE", "SKIRMISH", "OPEN_WAR"]

# Per-pair transition rules. Each rule returns the state given the
# current FactionRegistry rep readings + WoundRegistry creep + any
# other cosmic gauges. Centralizing the rules here keeps state
# computation deterministic and re-runnable on any signal tick.
const PAIR_RULES := {
	&"druid_vs_inquisition": {
		"factions": [&"druids", &"inquisition"],
		# Threshold pattern: read [druid_rep, inquisition_rep, wound_creep]
		# and pick state. The rules below escalate as the player's rep
		# diverges between the two factions AND as the Wound creep gives
		# both factions more reason to hate each other.
	},
	&"crown_vs_black_sail": {
		"factions": [&"crown", &"black_sail"],
	},
	&"crown_vs_druid": {
		"factions": [&"crown", &"druids"],
	},
}

# ────────── Public API ──────────

func get_state(pair_key: StringName) -> String:
	var sf: Node = get_node_or_null("/root/SaveFlags")
	if sf == null or not sf.has_method("get_run"):
		return "COLD"
	var raw: Variant = sf.get_run(StringName(_SAVEFLAG_PREFIX + String(pair_key)), "COLD")
	return String(raw) if raw is String else "COLD"

func set_state(pair_key: StringName, new_state: String) -> void:
	if not new_state in STATES:
		return
	var old: String = get_state(pair_key)
	if old == new_state:
		return
	var sf: Node = get_node_or_null("/root/SaveFlags")
	if sf and sf.has_method("set_run"):
		sf.set_run(StringName(_SAVEFLAG_PREFIX + String(pair_key)), new_state)
	pair_state_changed.emit(pair_key, new_state, old)
	_announce_state_change(pair_key, new_state, old)

func all_active_conflicts() -> Array:
	# Returns [{pair_key, state}] for every pair NOT in COLD. UI uses
	# this to render only the pairs that actually have tension.
	var out: Array = []
	for pair_key in PAIR_RULES.keys():
		var s: String = get_state(pair_key)
		if s != "COLD":
			out.append({"pair_key": pair_key, "state": s})
	return out

# ────────── Transition logic ──────────

# Recompute state for every tracked pair. Called on any upstream
# signal tick. Cheap (3 pairs); safe to fire on every rep change.
func recompute_all() -> void:
	for pair_key in PAIR_RULES.keys():
		_recompute_pair(pair_key)

func _recompute_pair(pair_key: StringName) -> void:
	var rule: Dictionary = PAIR_RULES.get(pair_key, {})
	var factions: Array = rule.get("factions", [])
	if factions.size() < 2:
		return
	var fr: Node = get_node_or_null("/root/FactionRegistry")
	if fr == null or not fr.has_method("get_rep"):
		return
	var rep_a: int = int(fr.get_rep(factions[0]))
	var rep_b: int = int(fr.get_rep(factions[1]))
	var wound_creep: int = 0
	var wr: Node = get_node_or_null("/root/WoundRegistry")
	if wr and wr.has_method("get_creep"):
		wound_creep = int(wr.get_creep())
	var new_state: String = _resolve_state_for_pair(pair_key, rep_a, rep_b, wound_creep)
	set_state(pair_key, new_state)

# Per-pair state resolution. Returns the state given the inputs.
# Same shape as TiamatRegistry.tier_for, but compares deltas between
# faction reputations rather than a single linear scale.
func _resolve_state_for_pair(pair_key: StringName, rep_a: int, rep_b: int, wound_creep: int) -> String:
	# Magnitude of divergence: how far apart the player is between
	# the two factions. Big divergence = strong allegiance to one
	# side, which inflames the other.
	var divergence: int = abs(rep_a - rep_b)
	match pair_key:
		&"druid_vs_inquisition":
			# This is THE central tension. The Wound creep multiplies
			# the divergence (a SEEPING+ Wound makes the disagreement
			# matter more). OPEN_WAR requires either UNCONTAINED Wound
			# OR a 30k+ rep divergence (essentially Exalted-vs-Hated).
			if wound_creep >= 70 or divergence >= 30000:
				return "OPEN_WAR"
			if wound_creep >= 45 or divergence >= 15000:
				return "SKIRMISH"
			if wound_creep >= 20 or divergence >= 6000:
				return "TENSE"
			return "COLD"
		&"crown_vs_black_sail":
			# Smuggling tension. No cosmic-threat multiplier; this is
			# pure rep math. Black Sail's quest line directly trades
			# Crown rep for theirs, so divergence climbs naturally.
			if divergence >= 18000:
				return "OPEN_WAR"
			if divergence >= 9000:
				return "SKIRMISH"
			if divergence >= 3000:
				return "TENSE"
			return "COLD"
		&"crown_vs_druid":
			# Slower-burning territorial tension. The Crown won't go to
			# OPEN_WAR with the Druids easily; needs both heavy
			# divergence AND a UNCONTAINED Wound for the Crown to feel
			# the Druids are losing control of their territory.
			if wound_creep >= 70 and divergence >= 15000:
				return "OPEN_WAR"
			if wound_creep >= 45 or divergence >= 12000:
				return "SKIRMISH"
			if wound_creep >= 20 or divergence >= 4000:
				return "TENSE"
			return "COLD"
	return "COLD"

# ────────── Wiring ──────────

func _ready() -> void:
	call_deferred("_wire_signal_sources")

func _wire_signal_sources() -> void:
	var fr: Node = get_node_or_null("/root/FactionRegistry")
	if fr and fr.has_signal("rep_changed"):
		var fcb := Callable(self, "_on_rep_changed")
		if not fr.rep_changed.is_connected(fcb):
			fr.rep_changed.connect(fcb)
	var wr: Node = get_node_or_null("/root/WoundRegistry")
	if wr and wr.has_signal("creep_changed"):
		var wcb := Callable(self, "_on_creep_changed")
		if not wr.creep_changed.is_connected(wcb):
			wr.creep_changed.connect(wcb)
	# Initial pass so loaded saves immediately surface accurate state.
	recompute_all()

func _on_rep_changed(_faction_id: StringName, _new_value: int, _old_value: int) -> void:
	recompute_all()

func _on_creep_changed(_new_value: int, _old_value: int) -> void:
	recompute_all()

# ────────── UI announcement ──────────

func _announce_state_change(pair_key: StringName, new_state: String, old_state: String) -> void:
	var juice: Node = get_node_or_null("/root/Juice")
	if juice == null or not juice.has_method("toast"):
		return
	# State up vs down: hotter = warning red, cooling = soft green.
	var new_idx: int = STATES.find(new_state)
	var old_idx: int = STATES.find(old_state)
	var escalating: bool = new_idx > old_idx
	var pretty: String = _pretty_pair(pair_key)
	var msg: String = ""
	var color: Color = Color(0.85, 0.55, 0.30)  # warm amber
	if escalating:
		match new_state:
			"TENSE":    msg = "%s: tension rising." % pretty
			"SKIRMISH": msg = "%s: skirmishes at the borders." % pretty
			"OPEN_WAR": msg = "%s: open war." % pretty
			_:          return
		match new_state:
			"TENSE":    color = Color(0.85, 0.75, 0.30)
			"SKIRMISH": color = Color(0.85, 0.45, 0.20)
			"OPEN_WAR": color = Color(0.95, 0.20, 0.20)
	else:
		# State cooled. Less dramatic, but still worth a toast.
		msg = "%s: tension cools to %s." % [pretty, new_state.capitalize()]
		color = Color(0.55, 0.85, 0.55)
	juice.toast(msg, color, 3.5)

func _pretty_pair(pair_key: StringName) -> String:
	# Render pair_key as "Druids vs Inquisition" etc for the toast.
	# Substring rule (split on _vs_) keeps this future-proof against
	# new pair additions.
	var s: String = String(pair_key)
	var parts: PackedStringArray = s.split("_vs_")
	if parts.size() != 2:
		return s.capitalize()
	return "%s vs %s" % [String(parts[0]).capitalize(), String(parts[1]).capitalize()]
