extends Node
class_name MultiplayerHost

# Phase 4 scaffold. Authoritative-host model using Godot's high-level MultiplayerAPI.
# Host = peer 1 = source of truth for damage, loot, boss state. Clients send inputs
# and receive state updates.
#
# DO NOT enable until Phases 1-3 (single-player core) are stable. Networking layered
# on a shifting foundation is a debugging nightmare.

const DEFAULT_PORT := 7654
const MAX_PLAYERS := 4  # dungeon-co-op scope

signal host_started(port: int)
signal client_connected(peer_id: int)
signal client_disconnected(peer_id: int)
signal connection_failed
signal connection_succeeded

func host(port: int = DEFAULT_PORT) -> bool:
	var peer := ENetMultiplayerPeer.new()
	var err := peer.create_server(port, MAX_PLAYERS)
	if err != OK:
		push_warning("MultiplayerHost: failed to create server: %s" % err)
		return false
	multiplayer.multiplayer_peer = peer
	multiplayer.peer_connected.connect(_on_peer_connected)
	multiplayer.peer_disconnected.connect(_on_peer_disconnected)
	host_started.emit(port)
	return true

func join(address: String, port: int = DEFAULT_PORT) -> bool:
	var peer := ENetMultiplayerPeer.new()
	var err := peer.create_client(address, port)
	if err != OK:
		push_warning("MultiplayerHost: failed to create client: %s" % err)
		connection_failed.emit()
		return false
	multiplayer.multiplayer_peer = peer
	multiplayer.connected_to_server.connect(func(): connection_succeeded.emit())
	multiplayer.connection_failed.connect(func(): connection_failed.emit())
	return true

func leave() -> void:
	if multiplayer.multiplayer_peer:
		multiplayer.multiplayer_peer.close()
	multiplayer.multiplayer_peer = null

func is_host() -> bool:
	return multiplayer.is_server()

func _on_peer_connected(id: int) -> void:
	client_connected.emit(id)

func _on_peer_disconnected(id: int) -> void:
	client_disconnected.emit(id)

# RPCs (call_local=false ensures the message round-trips through the host)
@rpc("authority", "call_local", "reliable")
func notify_boss_defeated(boss_id: StringName) -> void:
	# Host calls this to broadcast boss kill. Each client updates SaveFlags locally.
	SaveFlags.mark_boss_defeated(boss_id)

@rpc("any_peer", "call_local", "reliable")
func request_zone_change(zone_id: StringName) -> void:
	# Clients ask host. Host validates eligibility, broadcasts a confirmed change.
	if not is_host():
		return
	# TODO: validate. For now broadcast.
	rpc("apply_zone_change", zone_id)

@rpc("authority", "call_local", "reliable")
func apply_zone_change(zone_id: StringName) -> void:
	var loader: Node = get_tree().root.get_node_or_null("ZoneLoader")
	if loader:
		var player := get_tree().get_first_node_in_group("player")
		loader.confirm_travel(zone_id, player)
