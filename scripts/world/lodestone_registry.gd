extends Node

# LodestoneRegistry — autoload that tracks which lodestones the player has
# discovered. Soulslike fast-travel: only stones you've found are valid
# warp destinations on the World Map. Persisted via SaveFlags so progress
# survives session boundaries.
#
# Lodestones are placed in every region scene as Area3D nodes with the
# Lodestone script. When the player walks into one and presses V, it
# registers itself here.

const SAVEFLAG_KEY: StringName = &"lodestones_discovered"

# Static catalog of every lodestone in the game. id -> metadata. Region
# scenes carry the same ids on their Lodestone nodes; this registry is the
# canonical "what stones exist" list and what their displayed name is.
const LODESTONES := {
	# --- Class-intro hub ---
	&"sword_vow_dais":     { "name": "Sword-Vow Dais",     "region_id": &"sword_vow_ruins",    "scene": "res://scenes/world/intros/sword_vow_ruins.tscn",        "kind": "hub" },
	# --- 13 region entry stones (near village/town/spawn) ---
	&"cradle_altar":       { "name": "Cradle of Marduk",   "region_id": &"the_cradle",         "scene": "res://scenes/world/regions/the_cradle.tscn",            "kind": "village" },
	&"reed_marker":        { "name": "Reed-Wastes Marker", "region_id": &"the_reed_wastes",    "scene": "res://scenes/world/regions/the_reed_wastes.tscn",       "kind": "wilderness" },
	&"lapis_dock":         { "name": "Lapis Bay Dockstone","region_id": &"lapis_bay",          "scene": "res://scenes/world/regions/lapis_bay.tscn",             "kind": "village" },
	&"bone_pass":          { "name": "Bone-Pass Cairn",    "region_id": &"bone_mountains",     "scene": "res://scenes/world/regions/bone_mountains.tscn",        "kind": "wilderness" },
	&"verdant_altar":      { "name": "Verdant Altar",      "region_id": &"verdant_wound",      "scene": "res://scenes/world/regions/verdant_wound.tscn",         "kind": "wilderness" },
	&"ember_circle":       { "name": "Ember Circle",       "region_id": &"ember_steppes",      "scene": "res://scenes/world/regions/ember_steppes.tscn",         "kind": "wilderness" },
	&"mistvale_stone":     { "name": "Mist-Vale Stone",    "region_id": &"mist_vale",          "scene": "res://scenes/world/regions/mist_vale.tscn",             "kind": "wilderness" },
	&"shrieking_runestone":{ "name": "Shrieking Runestone","region_id": &"shrieking_highlands","scene": "res://scenes/world/regions/shrieking_highlands.tscn",   "kind": "wilderness" },
	&"sundered_marker":    { "name": "Sundered Coast Beacon","region_id": &"sundered_coast",   "scene": "res://scenes/world/regions/sundered_coast.tscn",        "kind": "wilderness" },
	&"black_throne":       { "name": "Black Citadel Gate", "region_id": &"black_citadel",      "scene": "res://scenes/world/regions/black_citadel.tscn",         "kind": "fortress" },
	&"fire_step":          { "name": "Fire-Stair Step",    "region_id": &"fire_stair",         "scene": "res://scenes/world/regions/fire_stair.tscn",            "kind": "wilderness" },
	&"ashurim_plaza":      { "name": "Ashurim Plaza",      "region_id": &"ashurim",            "scene": "res://scenes/world/regions/ashurim.tscn",               "kind": "city" },
	&"babilim_altar":      { "name": "Babilim Grand Altar","region_id": &"babilim",            "scene": "res://scenes/world/regions/babilim.tscn",               "kind": "city" },
	# --- 13 dungeon-boss stones (post-clear, found at the throne/boss room) ---
	&"cradle_throne":          { "name": "Cradle Throne",         "region_id": &"the_cradle",         "scene": "res://scenes/world/regions/the_cradle.tscn",         "kind": "dungeon_boss" },
	&"reed_drowned_keep":      { "name": "Drowned Keep",          "region_id": &"the_reed_wastes",    "scene": "res://scenes/world/regions/the_reed_wastes.tscn",    "kind": "dungeon_boss" },
	&"lapis_lighthouse":       { "name": "Sunken Lighthouse",     "region_id": &"lapis_bay",          "scene": "res://scenes/world/regions/lapis_bay.tscn",          "kind": "dungeon_boss" },
	&"bone_ossuary":           { "name": "Bone Ossuary Apex",     "region_id": &"bone_mountains",     "scene": "res://scenes/world/regions/bone_mountains.tscn",     "kind": "dungeon_boss" },
	&"verdant_grove_heart":    { "name": "Heartwood Grove",       "region_id": &"verdant_wound",      "scene": "res://scenes/world/regions/verdant_wound.tscn",      "kind": "dungeon_boss" },
	&"ember_warband_pyre":     { "name": "Warband Pyre",          "region_id": &"ember_steppes",      "scene": "res://scenes/world/regions/ember_steppes.tscn",      "kind": "dungeon_boss" },
	&"mistvale_cairn":         { "name": "Mist Cairn",            "region_id": &"mist_vale",          "scene": "res://scenes/world/regions/mist_vale.tscn",          "kind": "dungeon_boss" },
	&"shrieking_storm_tomb":   { "name": "Storm-Tomb",            "region_id": &"shrieking_highlands","scene": "res://scenes/world/regions/shrieking_highlands.tscn","kind": "dungeon_boss" },
	&"sundered_wreck":         { "name": "Wreck of the Aurim",    "region_id": &"sundered_coast",     "scene": "res://scenes/world/regions/sundered_coast.tscn",     "kind": "dungeon_boss" },
	&"black_inner_throne":     { "name": "Inner Throne",          "region_id": &"black_citadel",      "scene": "res://scenes/world/regions/black_citadel.tscn",      "kind": "dungeon_boss" },
	&"fire_summit":            { "name": "Fire-Summit",           "region_id": &"fire_stair",         "scene": "res://scenes/world/regions/fire_stair.tscn",         "kind": "dungeon_boss" },
	&"ashurim_inn":            { "name": "Ashurim Inn",           "region_id": &"ashurim",            "scene": "res://scenes/world/regions/ashurim.tscn",            "kind": "village" },
	&"babilim_holy_sanctum":   { "name": "Holy Sanctum",          "region_id": &"babilim",            "scene": "res://scenes/world/regions/babilim.tscn",            "kind": "dungeon_boss" },
}

# Runtime state
var _discovered: Dictionary = {}  # id -> true

signal discovered(id: StringName, name: String)
signal travelled(id: StringName)

func _ready() -> void:
	_load_from_save_flags()

func _load_from_save_flags() -> void:
	var sf = get_node_or_null("/root/SaveFlags")
	if sf == null:
		return
	if sf.has_method("get_permanent"):
		var saved: Variant = sf.get_permanent(SAVEFLAG_KEY)
		if typeof(saved) == TYPE_DICTIONARY:
			_discovered = saved.duplicate()
	elif sf.has_method("get"):
		var v = sf.get(SAVEFLAG_KEY)
		if typeof(v) == TYPE_DICTIONARY:
			_discovered = v.duplicate()

func _save_to_save_flags() -> void:
	var sf = get_node_or_null("/root/SaveFlags")
	if sf == null:
		return
	if sf.has_method("set_permanent"):
		sf.set_permanent(SAVEFLAG_KEY, _discovered)
	elif sf.has_method("set"):
		sf.set(SAVEFLAG_KEY, _discovered)

# --- Public API ---

func is_discovered(id: StringName) -> bool:
	return _discovered.has(id)

func discover(id: StringName) -> bool:
	if not LODESTONES.has(id):
		push_warning("Unknown lodestone id: %s" % id)
		return false
	if _discovered.has(id):
		return false  # already known
	_discovered[id] = true
	_save_to_save_flags()
	var nm: String = LODESTONES[id].get("name", String(id))
	discovered.emit(id, nm)
	return true

# Returns dict[id] -> metadata for every discovered lodestone.
func get_discovered() -> Dictionary:
	var out: Dictionary = {}
	for id in _discovered.keys():
		if LODESTONES.has(id):
			out[id] = LODESTONES[id]
	return out

func get_all() -> Dictionary:
	return LODESTONES.duplicate()

func get_meta(id: StringName) -> Dictionary:
	return LODESTONES.get(id, {})

# Travel: change_scene to the lodestone's owning scene if discovered.
func travel(id: StringName) -> bool:
	if not is_discovered(id):
		return false
	var meta: Dictionary = LODESTONES.get(id, {})
	var scene_path: String = meta.get("scene", "")
	if scene_path == "" or not ResourceLoader.exists(scene_path):
		return false
	# Warp SFX before scene change
	var ab = get_node_or_null("/root/AudioBus")
	if ab and ab.has_method("play_cue"):
		# Ambient cue at the player's position
		var player = get_tree().get_first_node_in_group("player")
		if player:
			ab.play_cue(&"warp", player.global_position, -3.0, 1.0)
	travelled.emit(id)
	get_tree().change_scene_to_file(scene_path)
	return true

# Stats
func count_discovered() -> int:
	return _discovered.size()

func count_total() -> int:
	return LODESTONES.size()
