extends Node

# Autoload: registers all Glyph definitions, tracks per-character earned glyphs
# (first-time boss kills) and inscribed glyphs (active tattoos).
#
# class_name removed: registered as autoload "GlyphRegistry" in project.godot.
# See CHARACTER_DESIGN.md § 8.5.2.

signal glyph_earned(glyph: Glyph, character_id: String)
signal glyph_inscribed(glyph: Glyph, location: StringName, character_id: String)
signal glyph_removed(glyph_id: StringName, character_id: String)

# Master glyph catalog: glyph_id -> Glyph
var glyphs: Dictionary = {}

# Per-character state: character_id -> {earned: Array[StringName], inscribed: Array[Dictionary]}
# inscribed entries: {glyph_id, location} where location is StringName from BODY_LOCATIONS
var earned_per_character: Dictionary = {}

const BODY_LOCATIONS := [&"chest", &"back", &"arm_left", &"arm_right", &"neck", &"face", &"leg_left", &"leg_right"]

func _ready() -> void:
	_seed_glyphs()
	# Subscribe to CombatBus.kill_registered to catch first-time boss kills.
	var cb: Node = get_node_or_null("/root/CombatBus")
	if cb and cb.has_signal("kill_registered"):
		cb.kill_registered.connect(_on_kill_registered)
	print("[GlyphRegistry] seeded %d glyphs" % glyphs.size())

func _seed_glyphs() -> void:
	# Phase 1 demo glyph: Kazat. More will land per-boss as the bestiary grows.
	_add_glyph(&"glyph_kazat_iron",
		"Iron-Faced Mark",
		"The geometric brand of Enforcer Kazat — three iron lines crossed with a single horizontal stroke. Earned by the first to put him down.",
		&"enforcer_kazat",
		"Enforcer Kazat the Iron-Faced",
		6,  # cross
		Color(0.85, 0.55, 0.20),
		&"crown",  # Kazat served the Crown
		0.005,
		200,
		&"katana_kazat_iron",  # the bronze katana drops as the inscribe token
		1,
		"They say Kazat broke his own nose every dawn so he'd remember pain. The mark you carry is the line that finally broke his."
	)

func _add_glyph(id: StringName, name: String, desc: String, boss_id: StringName,
		boss_name: String, shape: int, color: Color, faction: StringName,
		bonus_pct: float, gold: int, token: StringName, token_count: int, lore: String) -> void:
	var g := Glyph.new()
	g.glyph_id = id
	g.display_name = name
	g.description = desc
	g.source_boss_id = boss_id
	g.source_boss_display_name = boss_name
	g.shape_id = shape
	g.emission_color = color
	g.faction_bonus_target = faction
	g.faction_bonus_pct = bonus_pct
	g.inscribe_gold_cost = gold
	g.inscribe_token_id = token
	g.inscribe_token_count = token_count
	g.lore = lore
	glyphs[id] = g

func get_glyph(id: StringName) -> Glyph:
	return glyphs.get(id, null)

func glyph_for_boss(boss_id: StringName) -> Glyph:
	for g: Glyph in glyphs.values():
		if g.source_boss_id == boss_id:
			return g
	return null

# === Per-character state ===

func _ensure_character(character_id: String) -> void:
	if not earned_per_character.has(character_id):
		earned_per_character[character_id] = {
			"earned": [],
			"inscribed": [],
		}

func earned_glyphs(character_id: String) -> Array:
	_ensure_character(character_id)
	return earned_per_character[character_id]["earned"]

func inscribed_glyphs(character_id: String) -> Array:
	_ensure_character(character_id)
	return earned_per_character[character_id]["inscribed"]

func has_earned(character_id: String, glyph_id: StringName) -> bool:
	_ensure_character(character_id)
	return glyph_id in earned_per_character[character_id]["earned"]

func has_inscribed(character_id: String, glyph_id: StringName) -> bool:
	_ensure_character(character_id)
	for entry in earned_per_character[character_id]["inscribed"]:
		if entry["glyph_id"] == glyph_id:
			return true
	return false

# Earn a glyph (called automatically on first boss kill, manually for testing).
func earn_glyph(character_id: String, glyph_id: StringName) -> bool:
	if not glyphs.has(glyph_id):
		return false
	_ensure_character(character_id)
	if glyph_id in earned_per_character[character_id]["earned"]:
		return false  # already earned
	earned_per_character[character_id]["earned"].append(glyph_id)
	glyph_earned.emit(glyphs[glyph_id], character_id)
	return true

# Inscribe an earned glyph at a body location. Caller is responsible for the gold/token cost.
func inscribe_glyph(character_id: String, glyph_id: StringName, location: StringName) -> bool:
	if not has_earned(character_id, glyph_id):
		return false
	if not (location in BODY_LOCATIONS):
		return false
	if has_inscribed(character_id, glyph_id):
		return false  # already inscribed somewhere
	_ensure_character(character_id)
	earned_per_character[character_id]["inscribed"].append({
		"glyph_id": glyph_id,
		"location": location,
	})
	glyph_inscribed.emit(glyphs[glyph_id], location, character_id)
	return true

# Remove an inscribed glyph (free; lore-allowed via Inkstone Sage purification).
func remove_inscribed(character_id: String, glyph_id: StringName) -> bool:
	_ensure_character(character_id)
	var arr: Array = earned_per_character[character_id]["inscribed"]
	for i in range(arr.size()):
		if arr[i]["glyph_id"] == glyph_id:
			arr.remove_at(i)
			glyph_removed.emit(glyph_id, character_id)
			return true
	return false

# Auto-earn glyph when a boss dies for the first time on this character.
func _on_kill_registered(target: Node, _killer: Node) -> void:
	if not target or not is_instance_valid(target):
		return
	if not target.is_in_group("boss"):
		return
	var boss_id: StringName = &""
	if "boss_id" in target:
		boss_id = target.boss_id
	if boss_id == &"":
		return
	var glyph: Glyph = glyph_for_boss(boss_id)
	if not glyph:
		return
	# For now use a single character_id "active" — proper save-slot wiring is Phase 2.
	var char_id: String = "active"
	earn_glyph(char_id, glyph.glyph_id)
