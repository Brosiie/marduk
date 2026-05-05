extends Node

# Authentication client. Talks to the Cloudflare-hosted auth backend.
# Backend lives at https://api.marduk.game (or local dev at http://localhost:8787).
# Stub mode: when backend unreachable, returns offline-only Account for solo play.
#
# API contract (see CLOUDFLARE_DEPLOY.md for full spec):
#   POST /v1/auth/register   {email, username, password} -> {account, auth_token, refresh_token, expires_at}
#   POST /v1/auth/login      {email_or_username, password} -> {account, auth_token, refresh_token, expires_at}
#   POST /v1/auth/refresh    {refresh_token} -> {auth_token, expires_at}
#   POST /v1/auth/logout     (auth header) -> 204
#   GET  /v1/account/me      (auth header) -> {account, characters}
#   GET  /v1/characters      (auth header) -> {characters}
#   POST /v1/characters/sync (auth header) {slot, save_blob} -> {ok}
#   GET  /v1/leaderboards/prestige -> {entries: [{username, prestige, title}]}

const AUTH_BASE_URL := "https://api.marduk.game"
const LOCAL_DEV_URL := "http://localhost:8787"
const CRED_PATH := "user://credentials.cfg"

signal sign_in_started
signal sign_in_succeeded(account: Account)
signal sign_in_failed(reason: String)
signal sign_out_completed
signal token_refreshed

var account: Account
var _http: HTTPRequest
var _use_local_dev: bool = false

func _ready() -> void:
	account = Account.new()
	_http = HTTPRequest.new()
	add_child(_http)
	_load_credentials()

func base_url() -> String:
	return LOCAL_DEV_URL if _use_local_dev else AUTH_BASE_URL

func set_local_dev(enabled: bool) -> void:
	_use_local_dev = enabled

# === Public API ===
func register(email: String, username: String, password: String) -> void:
	sign_in_started.emit()
	_post("/v1/auth/register",
		{"email": email, "username": username, "password": password},
		_on_sign_in_response)

func login(email_or_username: String, password: String) -> void:
	sign_in_started.emit()
	_post("/v1/auth/login",
		{"email_or_username": email_or_username, "password": password},
		_on_sign_in_response)

func refresh_token() -> void:
	if account.refresh_token == "":
		return
	_post("/v1/auth/refresh", {"refresh_token": account.refresh_token}, _on_refresh_response)

func logout() -> void:
	if account.is_signed_in():
		_post_with_auth("/v1/auth/logout", {}, func(success, _data): pass)
	account.clear()
	_save_credentials()
	sign_out_completed.emit()

func sync_character(slot: int, save_blob: Dictionary) -> void:
	if not account.is_signed_in():
		return
	_post_with_auth("/v1/characters/sync",
		{"slot": slot, "save_blob": save_blob},
		func(_success, _data): pass)

func fetch_leaderboard(callback: Callable) -> void:
	_http_get("/v1/leaderboards/prestige", callback)

# === Credential persistence ===
func _save_credentials() -> void:
	var cfg := ConfigFile.new()
	cfg.set_value("account", "id", String(account.account_id))
	cfg.set_value("account", "username", account.username)
	cfg.set_value("account", "email", account.email)
	cfg.set_value("account", "refresh_token", account.refresh_token)
	cfg.set_value("account", "subscription", String(account.subscription_tier))
	cfg.save_encrypted_pass(CRED_PATH, OS.get_unique_id())  # device-bound encryption

func _load_credentials() -> void:
	var cfg := ConfigFile.new()
	if cfg.load_encrypted_pass(CRED_PATH, OS.get_unique_id()) != OK:
		return
	account.account_id = StringName(cfg.get_value("account", "id", ""))
	account.username = cfg.get_value("account", "username", "")
	account.email = cfg.get_value("account", "email", "")
	account.refresh_token = cfg.get_value("account", "refresh_token", "")
	account.subscription_tier = StringName(cfg.get_value("account", "subscription", "free"))
	# Note: auth_token NOT persisted; must refresh on launch.
	if account.refresh_token != "":
		refresh_token()

# === HTTP helpers ===
func _post(path: String, body: Dictionary, callback: Callable) -> void:
	var url := base_url() + path
	var headers := PackedStringArray(["Content-Type: application/json"])
	var json := JSON.stringify(body)
	_http.request_completed.connect(_wrap_callback(callback), CONNECT_ONE_SHOT)
	_http.request(url, headers, HTTPClient.METHOD_POST, json)

func _post_with_auth(path: String, body: Dictionary, callback: Callable) -> void:
	var url := base_url() + path
	var headers := PackedStringArray([
		"Content-Type: application/json",
		"Authorization: Bearer " + account.auth_token
	])
	var json := JSON.stringify(body)
	_http.request_completed.connect(_wrap_callback(callback), CONNECT_ONE_SHOT)
	_http.request(url, headers, HTTPClient.METHOD_POST, json)

func _http_get(path: String, callback: Callable) -> void:
	var url := base_url() + path
	var headers := PackedStringArray([])
	if account.is_signed_in():
		headers.append("Authorization: Bearer " + account.auth_token)
	_http.request_completed.connect(_wrap_callback(callback), CONNECT_ONE_SHOT)
	_http.request(url, headers)

func _wrap_callback(callback: Callable) -> Callable:
	return func(_result, response_code, _headers, body):
		var success: bool = response_code >= 200 and response_code < 300
		var data: Dictionary = {}
		var text: String = ""
		if body is PackedByteArray:
			text = (body as PackedByteArray).get_string_from_utf8()
		if text.length() > 0:
			var parsed: Variant = JSON.parse_string(text)
			if parsed is Dictionary:
				data = parsed
		callback.call(success, data)

# === Response handlers ===
func _on_sign_in_response(success: bool, data: Dictionary) -> void:
	if not success:
		sign_in_failed.emit(data.get("error", "Authentication failed"))
		return
	_apply_account_payload(data)
	_save_credentials()
	sign_in_succeeded.emit(account)

func _on_refresh_response(success: bool, data: Dictionary) -> void:
	if not success:
		account.clear()
		_save_credentials()
		return
	account.auth_token = data.get("auth_token", "")
	account.auth_expires_at = int(data.get("expires_at", 0))
	token_refreshed.emit()

func _apply_account_payload(data: Dictionary) -> void:
	var acc: Dictionary = data.get("account", {})
	account.account_id = StringName(acc.get("id", ""))
	account.username = acc.get("username", "")
	account.email = acc.get("email", "")
	account.subscription_tier = StringName(acc.get("subscription_tier", "free"))
	account.prestige_max = int(acc.get("prestige_max", 0))
	account.character_slots = int(acc.get("character_slots", 6))
	account.created_at_unix = int(acc.get("created_at_unix", 0))
	account.auth_token = data.get("auth_token", "")
	account.refresh_token = data.get("refresh_token", account.refresh_token)
	account.auth_expires_at = int(data.get("expires_at", 0))
	account.characters.clear()
	for c in data.get("characters", []):
		var cs := Account.CharacterSummary.new()
		cs.slot = int(c.get("slot", 0))
		cs.character_name = c.get("character_name", "")
		cs.class_id = StringName(c.get("class_id", ""))
		cs.level = int(c.get("level", 1))
		cs.prestige = int(c.get("prestige", 0))
		cs.current_zone = StringName(c.get("current_zone", ""))
		cs.saved_at_iso = c.get("saved_at_iso", "")
		account.characters.append(cs)
