extends Resource
class_name WorldServer

# A "world" / "shard" / "realm". 4 worlds at launch, max 12 concurrent players each.
# Tight intimate world like Mortal Online or classic Tibia. Capacity grows
# with subscription tier purchases of the game.
#
# Player chooses a world at character creation. Characters bind to a world.
# Cross-world transfer is possible but cooldown-gated (24h, server-enforced).

const MAX_PLAYERS_PER_WORLD := 12

@export var server_id: StringName = &""
@export var display_name: String = ""
@export_multiline var lore: String = ""
@export var region: StringName = &"global"   # global / na / eu / asia (latency hint)
@export var current_players: int = 0
@export var max_players: int = MAX_PLAYERS_PER_WORLD
@export var is_pvp_enabled: bool = false
@export var prestige_floor: int = 0          # only players at this prestige+ allowed
@export var founder_only: bool = false       # founders' edition exclusive
@export var status: StringName = &"online"   # online / maintenance / offline

func is_full() -> bool:
	return current_players >= max_players

func can_join(player_prestige: int, is_founder: bool = false) -> bool:
	if status != &"online":
		return false
	if is_full():
		return false
	if player_prestige < prestige_floor:
		return false
	if founder_only and not is_founder:
		return false
	return true
