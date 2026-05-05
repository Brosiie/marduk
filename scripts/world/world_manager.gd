extends Node

# Autoload: list of available worlds. 4 at launch. Server-authoritative; this is
# a polled local cache (refreshes every 30 seconds when in the launcher).
#
# Wires to /v1/worlds/list and /v1/worlds/transfer endpoints.

const POLL_INTERVAL := 30.0

signal worlds_refreshed(worlds: Array)
signal world_joined(server_id: StringName)
signal world_full(server_id: StringName)
signal world_transfer_requested(from_id: StringName, to_id: StringName)

var worlds: Dictionary = {}     # StringName -> WorldServer
var current_server_id: StringName = &""
var _poll_t: float = 0.0

func _ready() -> void:
	_register_initial_worlds()

func _process(delta: float) -> void:
	_poll_t += delta
	if _poll_t >= POLL_INTERVAL:
		_poll_t = 0.0
		_poll_world_status()

func get_world(id: StringName) -> WorldServer:
	return worlds.get(id)

func all_worlds() -> Array[WorldServer]:
	var arr: Array[WorldServer] = []
	for w in worlds.values():
		arr.append(w)
	return arr

# ----------------------------------------------------------------
# Initial roster (Bond's spec: 4 worlds at launch, 12 max each)
# ----------------------------------------------------------------
func _register_initial_worlds() -> void:
	_make(&"world_1_iron_pillar", "Iron Pillar (1)",
		"The first world. Founder population. Slower pace, deeper community.",
		&"na", false)

	_make(&"world_2_lapis_bay", "Lapis Bay (2)",
		"Coastal world. Social, lower-risk. Often used as a test world.",
		&"eu", false)

	_make(&"world_3_bone_mountains", "Bone Mountains (3)",
		"Mountain-climber's world. Higher endurance focus, harder respawns.",
		&"global", false)

	_make(&"world_4_pvp_mist_vale", "Mist Vale PvP (4)",
		"PvP-enabled world. Every contested zone allows player-vs-player. Mist Vale is permanently lethal.",
		&"global", true)

func _make(id: StringName, name: String, lore: String, region: StringName, pvp: bool) -> WorldServer:
	var w := WorldServer.new()
	w.server_id = id
	w.display_name = name
	w.lore = lore
	w.region = region
	w.is_pvp_enabled = pvp
	worlds[id] = w
	return w

# ----------------------------------------------------------------
# Polling stub - real implementation hits /v1/worlds/list
# ----------------------------------------------------------------
func _poll_world_status() -> void:
	# In Phase 4 this will GET /v1/worlds/list and update each WorldServer's
	# current_players + status from the server's response.
	# Stub: leave the placeholder counts.
	worlds_refreshed.emit(all_worlds())

# ----------------------------------------------------------------
# Selection
# ----------------------------------------------------------------
func attempt_join(server_id: StringName, prestige: int = 0, is_founder: bool = false) -> bool:
	var w: WorldServer = worlds.get(server_id)
	if not w or not w.can_join(prestige, is_founder):
		world_full.emit(server_id)
		return false
	current_server_id = server_id
	world_joined.emit(server_id)
	return true
