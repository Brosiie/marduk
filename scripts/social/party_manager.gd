extends Node

# Party lifecycle on the client. Talks to /v1/party/* endpoints on the backend.
# Solo players have no Party resource. When a party forms, this autoload owns
# the local mirror and listens for member updates over the WebSocket channel.
#
# Multiplayer Phase 4 wires the WebSocket; for now this is local-only stub.

signal party_created(party: Party)
signal party_joined(party: Party)
signal party_left
signal member_joined(member: Party.Member)
signal member_left(account_id: StringName)
signal invite_received(from_account_id: StringName, party_name: String)
signal invite_declined(from_account_id: StringName)
signal loot_rolled(item: Item, winner_account_id: StringName)

var current_party: Party = null

func is_in_party() -> bool:
	return current_party != null and current_party.size() > 1

func is_leader() -> bool:
	return current_party and current_party.leader_account_id == AuthClient.account.account_id

func size() -> int:
	return current_party.size() if current_party else 1

func xp_multiplier() -> float:
	return current_party.xp_multiplier() if current_party else 1.0

# === Local solo helpers (Phase 4 will network these) ===
func create_party(name: String) -> void:
	var p := Party.new()
	p.party_id = StringName("party_local_" + str(Time.get_unix_time_from_system()))
	p.leader_account_id = AuthClient.account.account_id
	p.name_for_lfg = name
	var m := Party.Member.new()
	m.account_id = AuthClient.account.account_id
	m.character_name = AuthClient.account.username
	m.is_leader = true
	p.members.append(m)
	current_party = p
	party_created.emit(p)

func leave_party() -> void:
	current_party = null
	party_left.emit()

func invite(account_id: StringName) -> void:
	# Phase 4: send /v1/party/invite RPC
	pass

func accept_invite(_party_id: StringName) -> void:
	# Phase 4: send /v1/party/accept RPC, server merges
	pass

func kick(_account_id: StringName) -> void:
	if not is_leader():
		return
	# Phase 4: send /v1/party/kick RPC
