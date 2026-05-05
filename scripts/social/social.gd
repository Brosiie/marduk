extends Node

# Friends and block lists. Persists per-account on the Cloudflare backend.
# Local cache for fast UI rendering; updates pushed via WebSocket from server.

signal friend_added(account_id: StringName, username: String)
signal friend_removed(account_id: StringName)
signal friend_status_changed(account_id: StringName, online: bool)
signal block_added(account_id: StringName)
signal block_removed(account_id: StringName)

class FriendEntry:
	var account_id: StringName
	var username: String
	var current_class_id: StringName
	var current_level: int = 1
	var current_zone: StringName = &""
	var is_online: bool = false
	var added_at_unix: int = 0
	var note: String = ""

class BlockEntry:
	var account_id: StringName
	var username: String
	var blocked_at_unix: int = 0
	var reason: String = ""

var friends: Array = []  # of FriendEntry
var blocks: Array = []   # of BlockEntry

const SAVE_PATH := "user://social.cfg"

func _ready() -> void:
	_load_local_cache()

func is_friend(account_id: StringName) -> bool:
	for f: FriendEntry in friends:
		if f.account_id == account_id:
			return true
	return false

func is_blocked(account_id: StringName) -> bool:
	for b: BlockEntry in blocks:
		if b.account_id == account_id:
			return true
	return false

func add_friend(account_id: StringName, username: String, note: String = "") -> void:
	if is_friend(account_id):
		return
	# Phase 4: POST /v1/friends/add to backend
	var f := FriendEntry.new()
	f.account_id = account_id
	f.username = username
	f.added_at_unix = int(Time.get_unix_time_from_system())
	f.note = note
	friends.append(f)
	friend_added.emit(account_id, username)
	_save_local_cache()

func remove_friend(account_id: StringName) -> void:
	for f: FriendEntry in friends.duplicate():
		if f.account_id == account_id:
			friends.erase(f)
			friend_removed.emit(account_id)
			_save_local_cache()
			return

func block(account_id: StringName, username: String, reason: String = "") -> void:
	if is_blocked(account_id):
		return
	# Auto-unfriend on block
	if is_friend(account_id):
		remove_friend(account_id)
	var b := BlockEntry.new()
	b.account_id = account_id
	b.username = username
	b.blocked_at_unix = int(Time.get_unix_time_from_system())
	b.reason = reason
	blocks.append(b)
	block_added.emit(account_id)
	_save_local_cache()

func unblock(account_id: StringName) -> void:
	for b: BlockEntry in blocks.duplicate():
		if b.account_id == account_id:
			blocks.erase(b)
			block_removed.emit(account_id)
			_save_local_cache()
			return

func _load_local_cache() -> void:
	var cfg := ConfigFile.new()
	if cfg.load(SAVE_PATH) != OK:
		return
	for key in cfg.get_section_keys("friends") if cfg.has_section("friends") else []:
		var data: Dictionary = cfg.get_value("friends", key, {})
		var f := FriendEntry.new()
		f.account_id = StringName(key)
		f.username = data.get("username", "")
		f.added_at_unix = int(data.get("added_at_unix", 0))
		f.note = data.get("note", "")
		friends.append(f)
	for key in cfg.get_section_keys("blocks") if cfg.has_section("blocks") else []:
		var data: Dictionary = cfg.get_value("blocks", key, {})
		var b := BlockEntry.new()
		b.account_id = StringName(key)
		b.username = data.get("username", "")
		b.blocked_at_unix = int(data.get("blocked_at_unix", 0))
		b.reason = data.get("reason", "")
		blocks.append(b)

func _save_local_cache() -> void:
	var cfg := ConfigFile.new()
	for f: FriendEntry in friends:
		cfg.set_value("friends", String(f.account_id), {
			"username": f.username,
			"added_at_unix": f.added_at_unix,
			"note": f.note
		})
	for b: BlockEntry in blocks:
		cfg.set_value("blocks", String(b.account_id), {
			"username": b.username,
			"blocked_at_unix": b.blocked_at_unix,
			"reason": b.reason
		})
	cfg.save(SAVE_PATH)
