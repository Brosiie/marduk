extends Node

# Realtime channel client. Connects to wss://realtime.marduk.game once a player
# is signed in + on a world. Broadcasts presence (online/offline, current zone)
# and receives party + friends + boss-event updates.
#
# Phase 4 wires this in fully; for now it auto-reconnects with backoff and
# emits typed signals for the rest of the game to react.
#
# Message protocol (JSON over WebSocket):
#   { "type": "hello", "account_id": "..." }
#   { "type": "presence", "account_id": "...", "online": bool, "zone": "..." }
#   { "type": "party_update", "party": {...} }
#   { "type": "party_invite", "from_id": "...", "from_name": "..." }
#   { "type": "friend_request", "from_id": "...", "from_name": "..." }
#   { "type": "world_event", "event": "boss_telegraph", "boss_id": "...", "tell": "..." }
#   { "type": "chat", "channel": "party|world|whisper", "from_name": "...", "text": "..." }

signal connected
signal disconnected
signal message_received(payload: Dictionary)
signal presence_changed(account_id: StringName, online: bool, zone: StringName)
signal party_update_received(party: Dictionary)
signal invite_received(kind: StringName, from_id: StringName, from_name: String)
signal chat_received(channel: StringName, from_name: String, text: String)

const REALTIME_URL_TEMPLATE := "wss://realtime.marduk.game/{server_id}?token={auth_token}"
const RECONNECT_INITIAL_BACKOFF := 1.0
const RECONNECT_MAX_BACKOFF := 30.0
const HEARTBEAT_INTERVAL := 25.0

var _ws: WebSocketPeer
var _connected: bool = false
var _backoff: float = RECONNECT_INITIAL_BACKOFF
var _reconnect_t: float = 0.0
var _heartbeat_t: float = 0.0
var _wants_connection: bool = false

func _ready() -> void:
	_ws = WebSocketPeer.new()

func connect_to_world(server_id: StringName) -> void:
	if not AuthClient.account.is_signed_in():
		return
	_wants_connection = true
	var url := REALTIME_URL_TEMPLATE.replace("{server_id}", String(server_id))
	url = url.replace("{auth_token}", AuthClient.account.auth_token)
	_ws.connect_to_url(url)

func disconnect_from_world() -> void:
	_wants_connection = false
	_ws.close()

func send(payload: Dictionary) -> void:
	if not _connected:
		return
	_ws.send_text(JSON.stringify(payload))

func send_chat(channel: StringName, text: String) -> void:
	send({"type": "chat", "channel": String(channel), "text": text})

func update_zone(zone_id: StringName) -> void:
	send({"type": "presence", "zone": String(zone_id)})

func _process(delta: float) -> void:
	if not _ws:
		return
	_ws.poll()
	var state := _ws.get_ready_state()

	# State change: just-connected
	if state == WebSocketPeer.STATE_OPEN and not _connected:
		_connected = true
		_backoff = RECONNECT_INITIAL_BACKOFF
		send({"type": "hello", "account_id": String(AuthClient.account.account_id)})
		connected.emit()

	# State change: dropped
	if state in [WebSocketPeer.STATE_CLOSED, WebSocketPeer.STATE_CLOSING] and _connected:
		_connected = false
		disconnected.emit()

	# Drain incoming
	while _ws.get_available_packet_count() > 0:
		var pkt := _ws.get_packet()
		var text := pkt.get_string_from_utf8()
		var data = JSON.parse_string(text)
		if data is Dictionary:
			_dispatch(data)

	# Heartbeat keepalive
	if _connected:
		_heartbeat_t += delta
		if _heartbeat_t >= HEARTBEAT_INTERVAL:
			_heartbeat_t = 0.0
			send({"type": "ping"})

	# Reconnect with exponential backoff
	if _wants_connection and not _connected and state == WebSocketPeer.STATE_CLOSED:
		_reconnect_t += delta
		if _reconnect_t >= _backoff:
			_reconnect_t = 0.0
			_backoff = min(_backoff * 1.7, RECONNECT_MAX_BACKOFF)
			# Reuse last URL stashed on the peer, or rely on caller to re-invoke
			# connect_to_world. For simplicity, re-attach via WorldManager state.
			var server := WorldManager.current_server_id if WorldManager else &""
			if server != &"":
				connect_to_world(server)

func _dispatch(payload: Dictionary) -> void:
	message_received.emit(payload)
	match payload.get("type", ""):
		"presence":
			presence_changed.emit(
				StringName(payload.get("account_id", "")),
				bool(payload.get("online", false)),
				StringName(payload.get("zone", ""))
			)
		"party_update":
			party_update_received.emit(payload.get("party", {}))
		"party_invite":
			invite_received.emit(&"party",
				StringName(payload.get("from_id", "")),
				payload.get("from_name", ""))
		"friend_request":
			invite_received.emit(&"friend",
				StringName(payload.get("from_id", "")),
				payload.get("from_name", ""))
		"chat":
			chat_received.emit(
				StringName(payload.get("channel", "world")),
				payload.get("from_name", "?"),
				payload.get("text", "")
			)
