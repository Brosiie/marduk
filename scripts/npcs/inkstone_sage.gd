extends "res://scripts/npcs/npc.gd"
class_name InkstoneSage

# The Inkstone Sage. Sits at the Inkstone Sanctum and chronicles the player's
# character in flowing prose, generated each visit from current state.
#
# The Sage is THE personality NPC. They speak as if they've been watching the
# player's whole life. The description regenerates from the character's current
# stats, scars, glyphs, race, class, kills, hours played, and appearance.
#
# See CHARACTER_DESIGN.md § 8.5.8.

# Class-specific opening tells the player the Sage knows what they are.
const CLASS_OPENINGS := {
	&"berserker":            "I see the rage in you sleeps shallow. You wake it more easily than most.",
	&"assassin":             "You walk like the floor owes you a favor. Quietly. The shadows lean toward you.",
	&"ronin":                "Your breath has a count. Most people don't notice that about themselves.",
	&"ranger":               "I smell pine sap and bowstring oil on you. Not unpleasant.",
	&"mage":                 "There's a hum around you. Mana, settling into a shape it likes.",
	&"chaos_druid":          "The Wound has touched you. It's not malice — it's just what the Wound does to those who stand close.",
	&"paladin_guardian":     "You came in the Crown's white. You've kept it cleaner than most.",
	&"paladin_lightbringer": "Dawn-light follows you in. You probably don't see it. Most don't.",
	&"demon":                "Welcome back. I knew you when you had a different name. I won't say it. That's between you and the gate.",
	&"sun_breather":         "You burn quietly. I'd ask if it hurts, but I think you'd lie.",
}

# Heaven-Rule walk-back overrides the class-line for characters who have
# already sacrificed the Demon. Only one line — they earned it.
const WALKED_BACK_OPENING := "I knew you when you had a different name. You took it back. Most don't. Sit. Let me see what's left of you."

const RACE_FLAVOR := {
	&"anunnaki":         "Babilim's bones in your face — you carry them well.",
	&"ash_born":         "The steppes shaped you. The wind there shapes everyone.",
	&"reed_walker":      "Salt in your hair. The Bay or the Wastes — I won't guess which.",
	&"mountain_forged":  "Your hands have known a hammer. The forge marks on your knuckles never lie.",
	&"wound_marked":     "You were born close to the Wound. It's not your fault. It rarely is.",
}

func _ready() -> void:
	npc_id = &"inkstone_sage"
	display_name = "The Inkstone Sage"
	wander_radius = 0.0
	greeting = "Sit. Let me look at you."
	super._ready()

# Override the base NPC dialogue. Generate prose from current player state.
func _open_dialogue() -> void:
	var player: Node = _find_player()
	if not player:
		super._open_dialogue()
		return
	var prose: String = _generate_chronicle(player)
	# Temporarily swap greeting to the generated chronicle so the base
	# dialogue panel renders our text. Restore after the panel closes.
	var prior_greeting: String = greeting
	greeting = prose
	super._open_dialogue()
	greeting = prior_greeting

func _find_player() -> Node:
	for p in get_tree().get_nodes_in_group("player"):
		if is_instance_valid(p):
			return p
	return null

func _generate_chronicle(player: Node) -> String:
	# Build a personalized prose chronicle from the player's current state.
	# Each segment is its own helper so the order is easy to read and reorder.
	# Empty lines are filtered before join.
	var lines: Array[String] = []
	var ca = player.get("character_appearance")
	var stats_obj = player.get("stats")
	var class_id: StringName = _resolve_class_id(stats_obj)
	var walked_back: bool = ca != null and ca.lucifer_walked_back

	lines.append(_opening_line(class_id, walked_back))
	lines.append(_race_line(ca))
	lines.append(_marking_line(ca))
	lines.append(_level_line(stats_obj))
	lines.append(_wound_mutation_line(ca))
	lines.append(_weapon_line(player))
	lines.append(_scar_line(player))
	lines.append(_per_element_scar_line(player))
	lines.append(_glyph_line())
	lines.append(_inscribed_glyph_line())
	lines.append(_apothecary_line(ca))
	lines.append(_temporal_gifts_line(ca))
	lines.append(_closing_line(walked_back))

	var filtered: Array[String] = []
	for line in lines:
		if line != "":
			filtered.append(line)
	return "\n\n".join(filtered)

# === Segment helpers ===

func _resolve_class_id(stats_obj) -> StringName:
	if stats_obj and stats_obj.get("class_def") and stats_obj.class_def:
		return stats_obj.class_def.class_id
	return &""

func _opening_line(class_id: StringName, walked_back: bool) -> String:
	if walked_back:
		return WALKED_BACK_OPENING
	return CLASS_OPENINGS.get(class_id, "I see you. That's enough for now.")

func _race_line(ca) -> String:
	if not ca or ca.race_id == &"":
		return ""
	return RACE_FLAVOR.get(ca.race_id, "")

func _marking_line(ca) -> String:
	# Recognize the chosen cultural marking. Race-aware. The Sage doesn't
	# rattle off a stat; he names what he sees.
	if not ca or ca.cultural_marking <= 0:
		return ""
	match ca.race_id:
		&"anunnaki":
			match ca.cultural_marking:
				1: return "The kohl around your eyes is steady. Court-bred steady."
				2: return "I see the bindi at your brow. Whose temple? — never mind. A small mercy I let you keep."
				3: return "Calligraphy on the forearm. Which poem? You don't have to say."
		&"ash_born":
			match ca.cultural_marking:
				1: return "The clan pattern is still on your chest. You have not been gone so long."
				2: return "Two black bands across the eyes. Older tradition than most living can name."
				3: return "Your shoulders carry trial-scars. You earned the cuts before the cuts earned you."
		&"reed_walker":
			match ca.cultural_marking:
				1: return "Blue under your eyes. The sea-charm. Did it work?"
				2: return "Shell discs at the ear. You replace them every year, like a proper Wastes-walker."
				3: return "Reed-fiber at the wrist. The braid is your grandmother's, or close enough."
		&"mountain_forged":
			match ca.cultural_marking:
				1: return "The forge-burns on your forearms — geometric, Bone Mountains pattern. Trial earned, not faked."
				2: return "Iron rings in your braid. The clan's count of them, I trust. Don't tell me which."
				3: return "A pillar-stone amulet. Your line built the original pillars. The Crown took the credit. You remember anyway."
		&"wound_marked":
			match ca.cultural_marking:
				1: return "Woad in vine-and-antler. The Wound recognizes you. Most who wear the woad have stopped flinching."
				2: return "Bone-thorns through the brow. Painful. Honest."
				3: return "The scar-rune on your cheek. Survival rite. The Wound let you live. It rarely says why."
				4: return "Antler hair-pins. Heavy. They hold the storm-braid against weather most people would run from."
	return ""

func _level_line(stats_obj) -> String:
	if not stats_obj:
		return ""
	var lvl: int = int(stats_obj.get("level") if stats_obj.get("level") != null else 1)
	var xp: int = int(stats_obj.get("xp") if stats_obj.get("xp") != null else 0)
	return "You are level %d. The world has given you %d portions of itself; you have not refused them." % [lvl, xp]

func _wound_mutation_line(ca) -> String:
	if not ca or ca.wound_mutation_stage <= 0:
		return ""
	match ca.wound_mutation_stage:
		1: return "The Wound has begun in you. You can still go back, if you wish. Most don't."
		2: return "Your fingers are longer than they were. I trust you noticed."
		3: return "You are halfway to something old. I will not name it."
		4: return "There is more vine than blood in you now. I do not say this with pity."
	return ""

func _weapon_line(player: Node) -> String:
	# Item.Slot.WEAPON_MAIN = 1 (constant from item.gd enum)
	var inv = player.get("inventory")
	if not inv or not inv.has_method("equipped_in"):
		return ""
	var weap = inv.equipped_in(1)
	if not weap or not ("display_name" in weap):
		return ""
	# Heaven detection — a special acknowledgement when the player carries it.
	if "id" in weap and weap.id == &"heaven":
		return "You carry Heaven. The katana chose you. There is no tradition older. There is no weight greater. I am not going to ask if you sleep."
	return "You hold the %s. It will outlive most things." % weap.display_name

func _scar_line(player: Node) -> String:
	var scar_mgr: Node = player.get_node_or_null("ScarManager")
	if not scar_mgr or not scar_mgr.has_method("active_scars"):
		return ""
	var n: int = scar_mgr.active_scars().size()
	var b: int = scar_mgr.boss_scar_count() if scar_mgr.has_method("boss_scar_count") else 0
	if n <= 0:
		return ""
	var scar_line: String = "I count %d scars on you" % n
	if b > 0:
		scar_line += ", and %d of them will never close" % b
	scar_line += "."
	return scar_line

# Element color map: int → human noun. Matches Ability.DamageType.
const _ELEMENT_NOUNS := {
	0: "the body",       # PHYSICAL
	1: "arcane",
	2: "fire",
	3: "frost",
	4: "lightning",
	5: "the holy ones",  # HOLY
	6: "shadow",
}

func _per_element_scar_line(player: Node) -> String:
	# Counts scars by element. If two or more elements are present, the Sage
	# names them. Adds depth past the bare "I count 9 scars."
	var scar_mgr: Node = player.get_node_or_null("ScarManager")
	if not scar_mgr or not scar_mgr.has_method("active_scars"):
		return ""
	var counts := {}
	for scar in scar_mgr.active_scars():
		var e: int = int(scar.element)
		counts[e] = int(counts.get(e, 0)) + 1
	# Skip if all scars are physical (or only one element type present)
	var distinct: int = counts.size()
	if distinct < 2:
		return ""
	var fragments: Array[String] = []
	for e in counts.keys():
		var noun: String = String(_ELEMENT_NOUNS.get(int(e), "something I don't recognize"))
		fragments.append("%d from %s" % [int(counts[e]), noun])
	return "Of those: " + ", ".join(fragments) + "."

func _glyph_line() -> String:
	var gr: Node = get_node_or_null("/root/GlyphRegistry")
	if not gr or not gr.has_method("earned_glyphs"):
		return ""
	var earned: Array = gr.earned_glyphs("active")
	if earned.size() <= 0:
		return ""
	var phrase: String
	match earned.size():
		1: phrase = "one"
		2: phrase = "two"
		3: phrase = "three"
		4: phrase = "four"
		5: phrase = "five"
		_: phrase = str(earned.size())
	return "You carry %s mark%s of those you have put down." % [phrase, "" if earned.size() == 1 else "s"]

func _inscribed_glyph_line() -> String:
	# The Sage names the inscribed glyphs specifically. He pulls them from
	# the GlyphRegistry by id and reports their display name + location.
	var gr: Node = get_node_or_null("/root/GlyphRegistry")
	if not gr or not gr.has_method("inscribed_glyphs"):
		return ""
	var inscribed: Array = gr.inscribed_glyphs("active")
	if inscribed.size() <= 0:
		return ""
	if inscribed.size() == 1:
		var entry: Dictionary = inscribed[0]
		var glyph = gr.get_glyph(entry.get("glyph_id", &"")) if gr.has_method("get_glyph") else null
		var glyph_name: String = glyph.display_name if glyph else "an unnamed mark"
		var location: String = String(entry.get("location", &"chest"))
		return "I see the %s on your %s. The Inkstone holds the cost; you hold the proof." % [glyph_name, location.replace("_", " ")]
	var names: Array[String] = []
	for entry in inscribed:
		var g = gr.get_glyph(entry.get("glyph_id", &"")) if gr.has_method("get_glyph") else null
		if g:
			names.append(String(g.display_name))
	return "Of those, %d you have asked me to make permanent: %s. A choice I respect." % [inscribed.size(), ", ".join(names)]

func _apothecary_line(ca) -> String:
	if not ca:
		return ""
	var total: int = ca.total_potion_saturation()
	if total <= 100:
		return ""
	var dom: StringName = ca.dominant_potion_type()
	match dom:
		&"hp":       return "Your skin tells me you've drunk deep of red glass. The body remembers."
		&"mana":     return "There's blue in the small veins of your hands. Mana-potions, more than is wise."
		&"stamina":  return "You smell faintly of green herb. The stamina-flasks have made a home in you."
		&"champion": return "Gold under the skin. Champion's Draught. I rarely see anyone with the means to acquire that much of it."
	return ""

func _temporal_gifts_line(ca) -> String:
	if not ca or not ca.has_temporal_gifts():
		return ""
	var bits: Array[String] = []
	if ca.gift_eclipse_halo:
		bits.append("you were made on an eclipse-day; the thin crescent above you is the proof")
	if ca.gift_blood_moon_eyes:
		bits.append("blood-moon born; your eyes carry the weather of that night")
	if ca.gift_sun_dawn_aura:
		bits.append("sun-festival born; dawn lets you in everywhere")
	if ca.gift_dark_solstice_trail:
		bits.append("dark-solstice born; the long shadow is yours and you should learn to walk in it")
	if ca.gift_founder_mark_year > 0:
		bits.append("you bear the founder's mark of year %d — there are not many of you left" % ca.gift_founder_mark_year)
	if bits.is_empty():
		return ""
	# Capitalize first letter of the joined string for prose flow.
	var joined: String = "; ".join(bits) + "."
	return joined.substr(0, 1).to_upper() + joined.substr(1)

func _closing_line(walked_back: bool) -> String:
	if walked_back:
		return "Come back when you have done another impossible thing. There will be one. There always is."
	return "Come back when you have changed. I will look at you again."
