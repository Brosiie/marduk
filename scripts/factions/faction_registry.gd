extends Node

# Autoload: 5 canonical Marduk factions. Per-character reputation lives in
# SaveFlags as int values keyed "rep_<faction_id>". The registry handles
# rep changes (clamped, signal-emitting), tier resolution, and starting rep
# seeding for new characters.
#
# class_name removed: this script is registered as the FactionRegistry
# autoload in project.godot.

# Explicit preload, bypasses the global class_name cache so a stale
# .godot/global_script_class_cache.cfg can't take this autoload offline.
# Without this, a missed cache rebuild left every Faction-typed signature
# unresolved and the whole registry failed to instantiate.
const FactionRes := preload("res://scripts/factions/faction.gd")

signal rep_changed(faction_id: StringName, new_value: int, old_value: int)
signal tier_changed(faction_id: StringName, new_tier: String, old_tier: String)

# WoW-standard tiers, players already know the shape
const TIER_BREAKPOINTS := [
	{"min": -42000, "max": -6000,  "name": "Hated"},
	{"min": -6000,  "max": -3000,  "name": "Hostile"},
	{"min": -3000,  "max": 0,      "name": "Unfriendly"},
	{"min": 0,      "max": 3000,   "name": "Neutral"},
	{"min": 3000,   "max": 9000,   "name": "Friendly"},
	{"min": 9000,   "max": 21000,  "name": "Honored"},
	{"min": 21000,  "max": 42000,  "name": "Revered"},
	{"min": 42000,  "max": 999999, "name": "Exalted"},
]

const REP_MIN := -42000
const REP_MAX := 42000

# Color per tier, drives the rep-bar fill in the UI
const TIER_COLORS := {
	"Hated":      Color(0.85, 0.20, 0.18),
	"Hostile":    Color(0.85, 0.40, 0.22),
	"Unfriendly": Color(0.85, 0.55, 0.30),
	"Neutral":    Color(0.65, 0.65, 0.65),
	"Friendly":   Color(0.55, 0.85, 0.40),
	"Honored":    Color(0.40, 0.85, 0.55),
	"Revered":    Color(0.40, 0.75, 0.95),
	"Exalted":    Color(1.00, 0.85, 0.30),
}

var factions: Dictionary = {}  # StringName -> FactionRes

func _ready() -> void:
	_register_all()

# ───────── Catalog ─────────

func _register_all() -> void:
	_make(&"crown",       "The Iron Crown",      "Marduk's official authority. The Crown stamps the coin and writes the laws. Most quests in Babilim go through them.",
		Color(0.95, 0.85, 0.45), "✠", 0)
	_make(&"inquisition", "The Inquisition",     "The Crown's purification arm. They burn what they cannot bind. Druids and Demons start at minimum rep with them.",
		Color(0.85, 0.45, 0.20), "♆", 0)
	_make(&"druids",      "Druids of the Wound", "The frontier coven. They tend the corruption that the Crown wants burned. Friendly to Wound-Marked and Demons.",
		Color(0.55, 0.85, 0.45), "♣", 0)
	_make(&"six_breaths", "The Six Breaths",     "The temple of breathing forms on the Lapis Bay coast. Six masters teach six styles. Sun is the seventh and unspoken.",
		Color(0.35, 0.65, 1.00), "刃", 0)
	_make(&"black_sail",  "The Black Sail",      "Pirate kings of the Reed Wastes coast. Three crowns, three captains. They sell to anyone with coin.",
		Color(0.55, 0.30, 0.65), "☠", 0)

func _make(id: StringName, name: String, desc: String, color: Color, motif: String, starting: int) -> FactionRes:
	var f := FactionRes.new()
	f.faction_id = id
	f.display_name = name
	f.description = desc
	f.color = color
	f.motif = motif
	f.starting_rep = starting
	factions[id] = f
	return f

func get_faction(id: StringName) -> FactionRes:
	return factions.get(id, null)

func all_factions() -> Array[FactionRes]:
	var out: Array[FactionRes] = []
	for f in factions.values():
		out.append(f)
	return out

# ───────── Reputation API ─────────

func get_rep(faction_id: StringName) -> int:
	var sf: Node = get_node_or_null("/root/SaveFlags")
	if not sf or not sf.has_method("get_permanent"):
		var f := get_faction(faction_id)
		return f.starting_rep if f else 0
	return int(sf.get_permanent(StringName("rep_" + String(faction_id)), get_faction(faction_id).starting_rep if get_faction(faction_id) else 0))

func add_rep(faction_id: StringName, delta: int) -> int:
	if not factions.has(faction_id):
		return 0
	var old: int = get_rep(faction_id)
	var new_val: int = clamp(old + delta, REP_MIN, REP_MAX)
	var sf: Node = get_node_or_null("/root/SaveFlags")
	if sf and sf.has_method("set_permanent"):
		sf.set_permanent(StringName("rep_" + String(faction_id)), new_val)
	rep_changed.emit(faction_id, new_val, old)
	var old_tier: String = tier_for(old)
	var new_tier: String = tier_for(new_val)
	if old_tier != new_tier:
		tier_changed.emit(faction_id, new_tier, old_tier)
		_toast_tier_change(faction_id, new_tier, delta > 0)
		# Tier-up milestone reward: grant gold + a stage flag the FIRST
		# time the player crosses Friendly / Honored / Revered / Exalted
		# with this faction. Once-only per faction-tier so reps that
		# yo-yo across a boundary don't double-reward.
		if delta > 0:
			_grant_tier_milestone_reward(faction_id, new_tier)
	return new_val

func set_rep(faction_id: StringName, value: int) -> void:
	add_rep(faction_id, value - get_rep(faction_id))

# ───────── Tier resolution ─────────

func tier_for(rep: int) -> String:
	for entry in TIER_BREAKPOINTS:
		if rep >= int(entry["min"]) and rep < int(entry["max"]):
			return String(entry["name"])
	# Above Exalted cap, still Exalted
	return "Exalted" if rep >= int(TIER_BREAKPOINTS[-1]["min"]) else "Hated"

func tier_color_for(rep: int) -> Color:
	return TIER_COLORS.get(tier_for(rep), Color.WHITE)

# Returns {min, max, current, pct, tier, next_tier_at} for the rep bar.
func bar_for(faction_id: StringName) -> Dictionary:
	var rep: int = get_rep(faction_id)
	var tier: String = tier_for(rep)
	var entry: Dictionary = {}
	for e in TIER_BREAKPOINTS:
		if String(e["name"]) == tier:
			entry = e
			break
	var tier_min: int = int(entry.get("min", REP_MIN))
	var tier_max: int = int(entry.get("max", REP_MAX))
	var span: int = max(1, tier_max - tier_min)
	var pct: float = clamp(float(rep - tier_min) / float(span), 0.0, 1.0)
	return {
		"current": rep,
		"tier": tier,
		"tier_min": tier_min,
		"tier_max": tier_max,
		"pct": pct,
		"into_tier": rep - tier_min,
		"to_next_tier": tier_max - rep,
	}

# ───────── UI helper ─────────

# Per-tier gold reward. Friendly is the first "you have a relationship"
# tier so it pays modestly. Exalted is the cap and pays correspondingly.
# Hostile/Hated tiers grant nothing (we don't pay you for being hated).
const _TIER_REWARDS := {
	"Friendly": 50,
	"Honored":  200,
	"Revered":  500,
	"Exalted":  1000,
}

func _grant_tier_milestone_reward(faction_id: StringName, new_tier: String) -> void:
	if not _TIER_REWARDS.has(new_tier):
		return
	# Already-claimed gate: each faction-tier pays out exactly once
	# across the whole save (not per prestige cycle - if you're Honored
	# at the moment of prestige reset, your next climb to Honored
	# doesn't double-pay). Tracked via SaveFlags permanent.
	var flag: StringName = StringName("tier_reward_%s_%s" % [String(faction_id), new_tier.to_lower()])
	var sf: Node = get_node_or_null("/root/SaveFlags")
	if sf and sf.has_method("has_permanent") and sf.has_permanent(flag):
		return
	if sf and sf.has_method("set_permanent"):
		sf.set_permanent(flag, true)
	# Award gold to the player. Skip silently if there's no player in
	# scene (e.g. menu / unit-test contexts).
	var amount: int = int(_TIER_REWARDS[new_tier])
	var tree := Engine.get_main_loop() as SceneTree
	if tree == null:
		return
	var player: Node = tree.get_first_node_in_group("player")
	# Faction-tier-up gold bonus. Old guard checked "gold in stats" but
	# PlayerStats never declared gold — value silently dropped. Routes
	# through Inventory.gold which is the canonical save-persisted store.
	if player and "inventory" in player and player.inventory and amount > 0:
		player.inventory.gold += amount
		if player.inventory.has_signal("gold_changed"):
			player.inventory.gold_changed.emit(player.inventory.gold)
	# Big toast announces the milestone + the reward
	var juice: Node = get_node_or_null("/root/Juice")
	if juice:
		var f := get_faction(faction_id)
		var name: String = f.display_name if f else String(faction_id)
		var color: Color = TIER_COLORS.get(new_tier, Color.WHITE)
		if juice.has_method("quest_banner"):
			juice.quest_banner(
				"REPUTATION MILESTONE",
				"%s — %s" % [name, new_tier],
				"+%d gold awarded" % amount,
				color,
				4.0,
			)
		elif juice.has_method("toast"):
			juice.toast("Milestone: %s %s  +%d gold" % [name, new_tier, amount], color, 3.5)

func _toast_tier_change(faction_id: StringName, new_tier: String, was_gain: bool) -> void:
	var juice: Node = get_node_or_null("/root/Juice")
	if juice and juice.has_method("toast"):
		var f := get_faction(faction_id)
		var name: String = f.display_name if f else String(faction_id)
		var prefix: String = "↑" if was_gain else "↓"
		var color: Color = TIER_COLORS.get(new_tier, Color.WHITE)
		juice.toast("%s %s: %s" % [prefix, name, new_tier], color, 3.0)
	# Audio: lodestone chirp ascends for gains, descends for losses (pitch
	# shift). Picked because the cue is already a tonal sweep that suits
	# both directions.
	var ab: Node = get_node_or_null("/root/AudioBus")
	if ab and ab.has_method("play_cue"):
		var pitch: float = 1.4 if was_gain else 0.7
		ab.play_cue(&"lodestone", Vector3.ZERO, -4.0, pitch)
