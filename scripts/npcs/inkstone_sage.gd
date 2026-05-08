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
	var lines: Array[String] = []

	# Opening line: walk-back takes priority, then class-aware fallback
	var class_id: StringName = &""
	if player.get("stats") and player.stats and player.stats.get("class_def") and player.stats.class_def:
		class_id = player.stats.class_def.class_id
	var walked_back: bool = false
	if player.get("character_appearance") and player.character_appearance:
		walked_back = player.character_appearance.lucifer_walked_back
	if walked_back:
		lines.append(WALKED_BACK_OPENING)
	else:
		lines.append(CLASS_OPENINGS.get(class_id, "I see you. That's enough for now."))

	# Race flavor
	var race_id: StringName = &""
	if player.get("character_appearance") and player.character_appearance:
		race_id = player.character_appearance.race_id
	if race_id != &"":
		lines.append(RACE_FLAVOR.get(race_id, ""))

	# Stats / level
	if player.get("stats") and player.stats:
		var lvl: int = int(player.stats.get("level") if player.stats.get("level") != null else 1)
		var xp: int = int(player.stats.get("xp") if player.stats.get("xp") != null else 0)
		lines.append("You are level %d. The world has given you %d portions of itself; you have not refused them." % [lvl, xp])

	# Scars
	var scar_mgr: Node = player.get_node_or_null("ScarManager")
	if scar_mgr and scar_mgr.has_method("active_scars"):
		var n: int = scar_mgr.active_scars().size()
		var b: int = scar_mgr.boss_scar_count() if scar_mgr.has_method("boss_scar_count") else 0
		if n > 0:
			var scar_line: String = "I count %d scars on you" % n
			if b > 0:
				scar_line += ", and %d of them will never close" % b
			scar_line += "."
			lines.append(scar_line)

	# Glyphs (earned + inscribed)
	var gr: Node = get_node_or_null("/root/GlyphRegistry")
	if gr:
		var earned: Array = gr.earned_glyphs("active")
		var inscribed: Array = gr.inscribed_glyphs("active")
		if earned.size() > 0:
			var phrase: String
			match earned.size():
				1: phrase = "one"
				2: phrase = "two"
				3: phrase = "three"
				_: phrase = str(earned.size())
			lines.append("You carry %s mark%s of those you have put down." % [phrase, "" if earned.size() == 1 else "s"])
		if inscribed.size() > 0:
			lines.append("Of those, %d you have asked the Inkstone to make permanent. A choice I respect." % inscribed.size())

	# Inventory: dominant item
	if player.get("inventory") and player.inventory and player.inventory.has_method("equipped_in"):
		var weapon = player.inventory.equipped_in(0 if not player.inventory.get("Slot") else 1)
		# Slot.WEAPON_MAIN is 1
		var weap = player.inventory.equipped_in(1) if player.inventory.has_method("equipped_in") else null
		if weap and "display_name" in weap:
			lines.append("You hold the %s. It will outlive most things." % weap.display_name)

	# Apothecary saturation
	if player.get("character_appearance") and player.character_appearance:
		var ca = player.character_appearance
		var total: int = ca.total_potion_saturation()
		if total > 100:
			var dom: StringName = ca.dominant_potion_type()
			match dom:
				&"hp":       lines.append("Your skin tells me you've drunk deep of red glass. The body remembers.")
				&"mana":     lines.append("There's blue in the small veins of your hands. Mana-potions, more than is wise.")
				&"stamina":  lines.append("You smell faintly of green herb. The stamina-flasks have made a home in you.")
				&"champion": lines.append("Gold under the skin — Champion's Draught. I rarely see anyone with the means to acquire that much of it.")

	# Time-of-creation gifts
	if player.get("character_appearance") and player.character_appearance:
		var ca2 = player.character_appearance
		if ca2.gift_eclipse_halo:
			lines.append("You were made on an eclipse-day. The thin crescent above you is the proof.")
		if ca2.gift_founder_mark_year > 0:
			lines.append("You bear the founder's mark of year %d. There are not many of you left." % ca2.gift_founder_mark_year)
		if ca2.gift_blood_moon_eyes:
			lines.append("Blood-moon born. Your eyes carry the weather of that night.")

	# Wound mutation (Wound-Marked only)
	if player.get("character_appearance") and player.character_appearance:
		var ca3 = player.character_appearance
		if ca3.wound_mutation_stage > 0:
			match ca3.wound_mutation_stage:
				1: lines.append("The Wound has begun. You can still go back, if you wish. Most don't.")
				2: lines.append("Your fingers are longer than they were. I trust you noticed.")
				3: lines.append("You are halfway to something old. I will not name it.")
				4: lines.append("There is more vine than blood in you now. I do not say this with pity.")

	# Closing
	lines.append("Come back when you have changed. I will look at you again.")

	# Filter empties and join with two newlines for prose-like spacing
	var filtered: Array[String] = []
	for line in lines:
		if line != "":
			filtered.append(line)
	return "\n\n".join(filtered)
