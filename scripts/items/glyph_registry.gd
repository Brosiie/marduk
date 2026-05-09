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
	# One glyph per class-intro mini-boss. The bestiary grows from here as
	# each Phase 2/3 boss adds its own mark.
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

	_add_glyph(&"glyph_tower_warden",
		"Sigil of the Bound",
		"A circle bisected by a vertical line, ending in a teardrop. The mark of those who put down the Tower Warden bound to the Inkstone Sanctum.",
		&"tower_warden",
		"The Tower Warden",
		1,  # circle
		Color(0.65, 0.40, 0.95),
		&"inkstone_keepers",
		0.005,
		180,
		&"warden_inkstone_staff",
		1,
		"The Warden was a mage once. They wove the binding themselves and forgot why halfway through. The sigil you bear is the line they could not finish."
	)

	_add_glyph(&"glyph_sahirum_witch_burner",
		"Witch-Burner Brand",
		"A torch crossed by an iron pole. The mark of those who put down Sahirum at the Coven Glen.",
		&"sahirum_witch_burner",
		"Sahirum the Witch-Burner",
		6,  # cross
		Color(1.00, 0.55, 0.20),
		&"inquisition",
		0.005,
		200,
		&"sahirum_inquisitor_mace",
		1,
		"Sahirum burned three Druids before you. The torch on his belt was lit from the funeral pyre of the first. You let it go out."
	)

	_add_glyph(&"glyph_beleti_siege_master",
		"Breach-Hammer Mark",
		"A cracked shield with a hammer through it. The mark of those who put down Beleti at the Sun-Sworn Chapel doors.",
		&"beleti_siege_master",
		"Beleti the Siege-Master",
		7,  # crown — closest to a battered helm-shape in the placeholder set
		Color(1.00, 0.85, 0.45),
		&"crown_siege",
		0.005,
		200,
		&"beleti_breach_hammer",
		1,
		"Beleti broke seventeen doors before the chapel. The chapel was never going to be the eighteenth. He just hadn't realized yet."
	)

	_add_glyph(&"glyph_glade_terror",
		"Antler Brand",
		"A four-pointed antler over a single eye. The mark of those who put down the Tiamat-spawn that came through the Greenheart Glade.",
		&"glade_terror",
		"The Glade Terror",
		8,  # horn — antler-curve
		Color(0.65, 0.85, 0.45),
		&"tiamat_spawn",  # +0.5% damage vs Tiamat-spawn enemies
		0.005,
		180,
		&"terror_glade_widow_bow",
		1,
		"It came through a thin spot in the world. The Glade was its first kill on this side. You were its last."
	)

	_add_glyph(&"glyph_sapum_five_mouthed",
		"Five-Mouth Sigil",
		"A spiral with five points, each a mouth. The mark of those who put down Master Sapum at the Whisper Shrine.",
		&"master_sapum",
		"Master Sapum, Five-Mouthed",
		5,  # spiral
		Color(0.45, 0.85, 0.45),
		&"whisper_initiates",  # +0.5% damage vs Whisper Shrine cult members
		0.005,
		180,
		&"sapum_whisper_dagger",
		1,
		"Sapum taught by trying to kill his initiates. The five mouths he carried in his fan-belt were one each. The sigil you bear is the mouth that bit you back."
	)

	_add_glyph(&"glyph_hassu_hooked",
		"Hooked Brand",
		"A jagged hook-curve crossed by a chain link. Hassu's mark; carried by those who put down the Hooked One in the Ash-Step Camp.",
		&"hassu_hooked",
		"Hassu the Hooked",
		8,  # horn — closest shape to a hook curve in the placeholder set
		Color(0.95, 0.45, 0.20),
		&"steppe_clans",  # +0.5% damage vs steppe-clan mobs
		0.005,
		180,
		&"hassu_steppe_skull_axe",
		1,
		"Hassu wore his hook through three winters and never washed the chain. They said he'd kill anyone who tried. The chain came clean when you took it off him."
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
	# Audio: lodestone chirp at higher pitch — the Inkstone "settling" the
	# mark into skin. Distinguishes inscription from a generic pickup.
	var ab: Node = get_node_or_null("/root/AudioBus")
	if ab and ab.has_method("play_cue"):
		var p: Node = get_tree().get_first_node_in_group("player") if get_tree() else null
		var pos: Vector3 = p.global_position if p and p is Node3D else Vector3.ZERO
		ab.play_cue(&"lodestone", pos, -4.0, 1.6)
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
