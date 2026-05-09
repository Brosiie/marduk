extends RefCounted
class_name NPCLines

# Shared greeting-selection helper. NPCs that want layered contextual
# dialogue (awareness-aware, glyph-aware, class-aware, walked-back) call
# pick_contextual_greeting() with their tables; the helper walks the
# layers in priority order and returns the first match.
#
# Priority (most specific wins):
#   1. WALKED_BACK overrides everything (lucifer_walked_back is a
#      campaign-defining choice; the line should always reflect it)
#   2. Glyph-conditional lines (player carries a faction-aligned mark)
#   3. Tiamat awareness dread tier (WAKING+ shifts NPCs toward dread)
#   4. Class greeting (the default flavor by player class)
#   5. DEFAULT_GREETING fallback
#
# Each NPC declares its own tables; the shape is consistent so this
# helper can be the single arbiter.

# Returns the most-specific applicable greeting line. Pass empty
# dictionaries / "" for layers the NPC doesn't use; the helper just
# skips them.
static func pick_contextual_greeting(
		player: Node,
		class_greetings: Dictionary,
		default_greeting: String,
		dread_greetings: Dictionary = {},
		glyph_greetings: Dictionary = {},
		walked_back_greeting: String = ""
	) -> String:
	# Layer 1: walked-back override
	if walked_back_greeting != "" and _player_walked_back(player):
		return walked_back_greeting

	# Layer 2: glyph-aware override. Glyph lines are keyed by glyph id
	# substring (eg "wound", "crown", "inquisition") so we don't need
	# the NPC to know exact ids. Walks the player's inscribed glyphs
	# and returns the first matching key.
	if not glyph_greetings.is_empty():
		var glyph_match: String = _glyph_aware_line(player, glyph_greetings)
		if glyph_match != "":
			return glyph_match

	# Layer 3: Tiamat awareness dread. Tables key by tier name
	# (STIRRING / WAKING / WAKING_2 / AWAKE). NPCs typically only
	# author the WAKING+ dread variants; STIRRING uses the class line.
	if not dread_greetings.is_empty():
		var dread_match: String = _dread_line(dread_greetings)
		if dread_match != "":
			return dread_match

	# Layer 4: class greeting. The default flavor pass.
	var class_id: StringName = _player_class_id(player)
	if class_id != &"" and class_greetings.has(class_id):
		return String(class_greetings[class_id])

	# Layer 5: fallback
	return default_greeting

# ─────── Layer helpers ───────

static func _player_walked_back(player: Node) -> bool:
	if player == null:
		return false
	if not player.get("character_appearance"):
		return false
	var ca = player.character_appearance
	if ca == null:
		return false
	return bool(ca.get("lucifer_walked_back")) if ca.get("lucifer_walked_back") != null else false

static func _player_class_id(player: Node) -> StringName:
	if player == null or not player.get("stats") or player.stats == null:
		return &""
	if not player.stats.get("class_def") or player.stats.class_def == null:
		return &""
	var cd = player.stats.class_def
	if "class_id" in cd:
		return StringName(cd.class_id)
	return &""

static func _glyph_aware_line(player: Node, glyph_greetings: Dictionary) -> String:
	# GlyphRegistry exposes inscribed_glyphs(character_id) -> Array[Dictionary]
	# where each entry has a glyph id. We don't have a character_id at
	# this layer reliably, so we scan all the player's inscribed glyphs
	# via the registry's full state and match by id substring.
	var gr: Node = Engine.get_main_loop().root.get_node_or_null("/root/GlyphRegistry") if Engine.get_main_loop() else null
	if gr == null:
		return ""
	# Try a method that returns the player's inscribed glyph ids list.
	var ids: Array = []
	if gr.has_method("inscribed_glyph_ids"):
		ids = gr.inscribed_glyph_ids()
	elif gr.has_method("all_inscribed_for_player"):
		ids = gr.all_inscribed_for_player()
	else:
		# Fall back: scan inscribed_records for glyph ids if the registry
		# exposes that field directly.
		if "inscribed_records" in gr:
			for rec in gr.inscribed_records:
				if rec is Dictionary and rec.has("glyph_id"):
					ids.append(StringName(rec["glyph_id"]))
	if ids.is_empty():
		return ""
	# For each glyph_greetings key (a substring), return the first
	# glyph that contains it. NPC authors think in terms of "carries a
	# wound mark" rather than exact glyph ids.
	for keyword in glyph_greetings.keys():
		var key_str: String = String(keyword).to_lower()
		for gid in ids:
			if String(gid).to_lower().find(key_str) >= 0:
				return String(glyph_greetings[keyword])
	return ""

static func _dread_line(dread_greetings: Dictionary) -> String:
	var tr: Node = Engine.get_main_loop().root.get_node_or_null("/root/TiamatRegistry") if Engine.get_main_loop() else null
	if tr == null or not tr.has_method("current_tier"):
		return ""
	var tier: String = String(tr.current_tier())
	# Walk highest-dread-first so AWAKE > WAKING_2 > WAKING. NPCs that
	# only author one dread line at WAKING get it; NPCs that ladder up
	# get the strongest applicable.
	const _DREAD_ORDER := ["AWAKE", "WAKING_2", "WAKING", "STIRRING"]
	for candidate_tier in _DREAD_ORDER:
		if tier == candidate_tier and dread_greetings.has(candidate_tier):
			return String(dread_greetings[candidate_tier])
	# If the NPC's table has the current tier but not in the iteration
	# above (typo / unsupported tier), still try a direct lookup
	if dread_greetings.has(tier):
		return String(dread_greetings[tier])
	return ""
