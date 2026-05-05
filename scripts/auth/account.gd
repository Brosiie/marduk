extends Resource
class_name Account

# A signed-in player's account record. Local mirror of what the auth server
# returns. Auth-token is short-lived; refresh-token kept in OS keychain or
# disk-encrypted file (TODO when launcher ships).

@export var account_id: StringName = &""        # server-assigned UUID
@export var username: String = ""               # public display
@export var email: String = ""                  # for recovery
@export var auth_token: String = ""             # short-lived JWT/session
@export var refresh_token: String = ""          # long-lived, used to mint auth_token
@export var auth_expires_at: int = 0            # epoch seconds
@export var character_slots: int = 6            # how many save slots this account owns
@export var subscription_tier: StringName = &"free"  # free / supporter / lifetime
@export var prestige_max: int = 0               # highest prestige reached across all chars
@export var created_at_unix: int = 0
@export var last_seen_unix: int = 0

# Roster of characters owned (server is canonical; this is a local cache for the launcher)
class CharacterSummary:
	var slot: int = 0
	var character_name: String = ""
	var class_id: StringName = &""
	var level: int = 1
	var prestige: int = 0
	var current_zone: StringName = &""
	var saved_at_iso: String = ""

var characters: Array = []  # of CharacterSummary

func is_signed_in() -> bool:
	return account_id != &"" and auth_token != "" and not is_token_expired()

func is_token_expired() -> bool:
	return Time.get_unix_time_from_system() >= auth_expires_at - 30  # 30s grace

func clear() -> void:
	account_id = &""
	username = ""
	email = ""
	auth_token = ""
	refresh_token = ""
	auth_expires_at = 0
	characters.clear()
