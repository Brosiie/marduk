extends Node

# Persistent player preferences. Loaded on launch, saved on change.
# Categories: Display, Audio, Controls, Gameplay, Accessibility, Privacy.

const SAVE_PATH := "user://settings.cfg"

signal setting_changed(category: StringName, key: StringName, value)

# === Display ===
var fullscreen: bool = false
var resolution: Vector2i = Vector2i(1920, 1080)
var vsync: bool = true
var fps_cap: int = 60
var resolution_scale: float = 1.0     # 0.5 = half-res render scaled up (Octopath crunch)
var msaa: int = 2                      # 0,2,4,8
var brightness: float = 1.0
var contrast: float = 1.0
var ui_scale: float = 1.0

# === Audio ===
var master_volume: float = 1.0
var music_volume: float = 0.8
var sfx_volume: float = 1.0
var ambient_volume: float = 0.7
var voice_volume: float = 1.0
var mute_when_unfocused: bool = true

# === Controls (binding map lives in KeyBindings) ===
var mouse_sensitivity: float = 1.0
var camera_invert_y: bool = false
var camera_smoothing: float = 0.5
var hold_to_aim: bool = false
var sprint_toggle: bool = true       # press once to toggle vs hold
var auto_target: bool = true         # auto-acquire nearest enemy when attacking
var click_to_move: bool = false      # Diablo-style alternative to WASD

# === Gameplay ===
var difficulty_warning_underleveled: bool = true
var show_damage_numbers: bool = true
var show_floating_loot_text: bool = true
var aggressive_loot_pickup: bool = false  # auto-pickup on proximity
var show_minimap: bool = true
var show_objective_marker: bool = true
var hud_scale: float = 1.0
var rotate_camera_with_movement: bool = false

# === Accessibility ===
var screen_shake: float = 1.0       # 0.0 disables
var hit_stop: float = 0.0           # 0.0 disables all slomo + hit-stop (Juice + CombatFeedback both respect this)
var color_blind_mode: StringName = &"none"  # none / protanopia / deuteranopia / tritanopia
var reduced_motion: bool = false
var subtitle_size: int = 18
var subtitles_enabled: bool = true
var hud_high_contrast: bool = false

# === Privacy / Telemetry ===
var allow_anon_telemetry: bool = false
var allow_crash_reports: bool = true

# === Mobile ===
var is_mobile: bool = false           # auto-set on platform check
var virtual_joystick_size: float = 1.0
var virtual_joystick_position: StringName = &"bottom_left"  # bottom_left / bottom_right
var ability_buttons_size: float = 1.0
var customize_toolbar_layout: Dictionary = {}  # toolbar slot -> ability_id

func _ready() -> void:
	is_mobile = OS.has_feature("mobile") or OS.has_feature("web_android") or OS.has_feature("web_ios")
	load_settings()
	apply_all()

func apply_all() -> void:
	_apply_display()
	_apply_audio()

func set_value(category: StringName, key: StringName, value) -> void:
	# Reflection-style setter so settings UI can bind to anything by name.
	var prop_name := String(key)
	if not has_property(prop_name):
		push_warning("GameSettings: unknown key %s" % prop_name)
		return
	set(prop_name, value)
	setting_changed.emit(category, key, value)
	save_settings()
	apply_all()

func has_property(name: String) -> bool:
	for p in get_property_list():
		if p["name"] == name:
			return true
	return false

# === Apply ===
func _apply_display() -> void:
	if fullscreen:
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN)
	else:
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)
		DisplayServer.window_set_size(resolution)
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_ENABLED if vsync else DisplayServer.VSYNC_DISABLED)
	Engine.max_fps = fps_cap
	# Resolution scale via viewport stretch; project.godot stretch_mode = canvas_items
	get_viewport().scaling_3d_scale = resolution_scale

func _apply_audio() -> void:
	# Bus indices: 0=Master, 1=Music, 2=SFX, 3=Ambient, 4=Voice (set up in audio bus layout)
	AudioServer.set_bus_volume_db(0, linear_to_db(master_volume))
	AudioServer.set_bus_volume_db(_bus_idx("Music"), linear_to_db(music_volume))
	AudioServer.set_bus_volume_db(_bus_idx("SFX"), linear_to_db(sfx_volume))
	AudioServer.set_bus_volume_db(_bus_idx("Ambient"), linear_to_db(ambient_volume))
	AudioServer.set_bus_volume_db(_bus_idx("Voice"), linear_to_db(voice_volume))

func _bus_idx(name: String) -> int:
	var i := AudioServer.get_bus_index(name)
	return i if i >= 0 else 0

# === Persist ===
func save_settings() -> void:
	var cfg := ConfigFile.new()
	# Display
	cfg.set_value("display", "fullscreen", fullscreen)
	cfg.set_value("display", "resolution", resolution)
	cfg.set_value("display", "vsync", vsync)
	cfg.set_value("display", "fps_cap", fps_cap)
	cfg.set_value("display", "resolution_scale", resolution_scale)
	cfg.set_value("display", "msaa", msaa)
	cfg.set_value("display", "brightness", brightness)
	cfg.set_value("display", "contrast", contrast)
	cfg.set_value("display", "ui_scale", ui_scale)
	# Audio
	cfg.set_value("audio", "master", master_volume)
	cfg.set_value("audio", "music", music_volume)
	cfg.set_value("audio", "sfx", sfx_volume)
	cfg.set_value("audio", "ambient", ambient_volume)
	cfg.set_value("audio", "voice", voice_volume)
	cfg.set_value("audio", "mute_unfocused", mute_when_unfocused)
	# Controls
	cfg.set_value("controls", "mouse_sensitivity", mouse_sensitivity)
	cfg.set_value("controls", "invert_y", camera_invert_y)
	cfg.set_value("controls", "camera_smoothing", camera_smoothing)
	cfg.set_value("controls", "sprint_toggle", sprint_toggle)
	cfg.set_value("controls", "auto_target", auto_target)
	cfg.set_value("controls", "click_to_move", click_to_move)
	# Gameplay
	cfg.set_value("gameplay", "warn_underleveled", difficulty_warning_underleveled)
	cfg.set_value("gameplay", "damage_numbers", show_damage_numbers)
	cfg.set_value("gameplay", "loot_text", show_floating_loot_text)
	cfg.set_value("gameplay", "auto_pickup", aggressive_loot_pickup)
	cfg.set_value("gameplay", "minimap", show_minimap)
	cfg.set_value("gameplay", "objective_marker", show_objective_marker)
	cfg.set_value("gameplay", "hud_scale", hud_scale)
	# Accessibility
	cfg.set_value("a11y", "screen_shake", screen_shake)
	cfg.set_value("a11y", "hit_stop", hit_stop)
	cfg.set_value("a11y", "color_blind", String(color_blind_mode))
	cfg.set_value("a11y", "reduced_motion", reduced_motion)
	cfg.set_value("a11y", "subtitle_size", subtitle_size)
	cfg.set_value("a11y", "subtitles", subtitles_enabled)
	cfg.set_value("a11y", "high_contrast", hud_high_contrast)
	# Privacy
	cfg.set_value("privacy", "telemetry", allow_anon_telemetry)
	cfg.set_value("privacy", "crash_reports", allow_crash_reports)
	# Mobile
	cfg.set_value("mobile", "joystick_size", virtual_joystick_size)
	cfg.set_value("mobile", "joystick_position", String(virtual_joystick_position))
	cfg.set_value("mobile", "ability_buttons_size", ability_buttons_size)
	cfg.set_value("mobile", "toolbar_layout", customize_toolbar_layout)
	cfg.save(SAVE_PATH)

func load_settings() -> void:
	var cfg := ConfigFile.new()
	if cfg.load(SAVE_PATH) != OK:
		return
	fullscreen = bool(cfg.get_value("display", "fullscreen", false))
	resolution = cfg.get_value("display", "resolution", Vector2i(1920, 1080))
	vsync = bool(cfg.get_value("display", "vsync", true))
	fps_cap = int(cfg.get_value("display", "fps_cap", 60))
	resolution_scale = float(cfg.get_value("display", "resolution_scale", 1.0))
	msaa = int(cfg.get_value("display", "msaa", 2))
	brightness = float(cfg.get_value("display", "brightness", 1.0))
	contrast = float(cfg.get_value("display", "contrast", 1.0))
	ui_scale = float(cfg.get_value("display", "ui_scale", 1.0))
	master_volume = float(cfg.get_value("audio", "master", 1.0))
	music_volume = float(cfg.get_value("audio", "music", 0.8))
	sfx_volume = float(cfg.get_value("audio", "sfx", 1.0))
	ambient_volume = float(cfg.get_value("audio", "ambient", 0.7))
	voice_volume = float(cfg.get_value("audio", "voice", 1.0))
	mute_when_unfocused = bool(cfg.get_value("audio", "mute_unfocused", true))
	mouse_sensitivity = float(cfg.get_value("controls", "mouse_sensitivity", 1.0))
	camera_invert_y = bool(cfg.get_value("controls", "invert_y", false))
	camera_smoothing = float(cfg.get_value("controls", "camera_smoothing", 0.5))
	sprint_toggle = bool(cfg.get_value("controls", "sprint_toggle", true))
	auto_target = bool(cfg.get_value("controls", "auto_target", true))
	click_to_move = bool(cfg.get_value("controls", "click_to_move", false))
	difficulty_warning_underleveled = bool(cfg.get_value("gameplay", "warn_underleveled", true))
	show_damage_numbers = bool(cfg.get_value("gameplay", "damage_numbers", true))
	show_floating_loot_text = bool(cfg.get_value("gameplay", "loot_text", true))
	aggressive_loot_pickup = bool(cfg.get_value("gameplay", "auto_pickup", false))
	show_minimap = bool(cfg.get_value("gameplay", "minimap", true))
	show_objective_marker = bool(cfg.get_value("gameplay", "objective_marker", true))
	hud_scale = float(cfg.get_value("gameplay", "hud_scale", 1.0))
	screen_shake = float(cfg.get_value("a11y", "screen_shake", 1.0))
	hit_stop = float(cfg.get_value("a11y", "hit_stop", 0.0))
	color_blind_mode = StringName(cfg.get_value("a11y", "color_blind", "none"))
	reduced_motion = bool(cfg.get_value("a11y", "reduced_motion", false))
	subtitle_size = int(cfg.get_value("a11y", "subtitle_size", 18))
	subtitles_enabled = bool(cfg.get_value("a11y", "subtitles", true))
	hud_high_contrast = bool(cfg.get_value("a11y", "high_contrast", false))
	allow_anon_telemetry = bool(cfg.get_value("privacy", "telemetry", false))
	allow_crash_reports = bool(cfg.get_value("privacy", "crash_reports", true))
	virtual_joystick_size = float(cfg.get_value("mobile", "joystick_size", 1.0))
	virtual_joystick_position = StringName(cfg.get_value("mobile", "joystick_position", "bottom_left"))
	ability_buttons_size = float(cfg.get_value("mobile", "ability_buttons_size", 1.0))
	customize_toolbar_layout = cfg.get_value("mobile", "toolbar_layout", {})
