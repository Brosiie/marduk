extends Node

# Rebindable input system. Wraps Godot's InputMap with persistence and a UI-friendly
# API. The settings menu calls `start_rebinding(action_id)` and the next key/button
# captured replaces the binding.
#
# Default actions cover: movement, camera, dodge, parry, block, attack, abilities,
# interact, lock-on, inventory, map, character sheet, skill tree, options, etc.

const SAVE_PATH := "user://keybindings.cfg"

signal rebinding_started(action: StringName)
signal rebinding_completed(action: StringName, event: InputEvent)
signal rebinding_cancelled

var defaults: Dictionary = {}      # action_id -> default InputEvent
var _is_rebinding: bool = false
var _rebind_target: StringName = &""

func _ready() -> void:
	# Define every game action with a default. Settings UI iterates this dict.
	_define(&"move_up", _key(KEY_W))
	_define(&"move_down", _key(KEY_S))
	_define(&"move_left", _key(KEY_A))
	_define(&"move_right", _key(KEY_D))
	_define(&"jump", _key(KEY_SPACE))
	_define(&"sprint", _key(KEY_SHIFT))
	_define(&"dodge", _key(KEY_C))             # roll/dash
	_define(&"parry", _mouse(MOUSE_BUTTON_RIGHT))
	# block uses RMB-hold (same button as parry — tap = parry window,
	# hold = sustained guard). The F alt-block binding was removed because
	# it conflicted with ability_4: pressing F to cast "Stance Resolve"
	# simultaneously triggered the block guard state, soaking 65% of
	# incoming damage and changing the animation. RMB hold is the
	# canonical block; the F-alt is gone.
	_define(&"block", _mouse(MOUSE_BUTTON_RIGHT))
	_define(&"attack_basic", _mouse(MOUSE_BUTTON_LEFT))
	# Interact uses V to match every world label ("V to enter", "V to
	# attune", "V to pick up"). Was KEY_E which conflicted with ability_2
	# — pressing E near a warp portal cast the second ability AND
	# triggered the travel simultaneously.
	_define(&"interact", _key(KEY_V))
	_define(&"lock_on", _key(KEY_TAB))
	# Ability bar (Q E R F default; numbers also bound)
	_define(&"ability_1", _key(KEY_Q))
	_define(&"ability_2", _key(KEY_E))
	_define(&"ability_3", _key(KEY_R))
	_define(&"ability_4", _key(KEY_F))
	# Item slots
	_define(&"item_1", _key(KEY_1))
	_define(&"item_2", _key(KEY_2))
	_define(&"item_3", _key(KEY_3))
	_define(&"item_4", _key(KEY_4))
	_define(&"item_5", _key(KEY_5))
	# Health / mana / stamina potions (quick-use)
	_define(&"use_health_potion", _key(KEY_6))
	_define(&"use_mana_potion", _key(KEY_7))
	_define(&"use_stamina_potion", _key(KEY_8))
	# Camera
	_define(&"cam_rotate_left", _key(KEY_LEFT))
	_define(&"cam_rotate_right", _key(KEY_RIGHT))
	_define(&"zoom_in", _mouse(MOUSE_BUTTON_WHEEL_UP))
	_define(&"zoom_out", _mouse(MOUSE_BUTTON_WHEEL_DOWN))
	# UI / menus. Naming MUST match the listener side
	# (hud.gd._unhandled_input + menu_panel HOTKEY_TO_TAB), which uses the
	# toggle_* convention. The previous open_* names were defined but
	# never listened for — pressing I/K/T/etc. did nothing because the
	# action name didn't match the consumer.
	_define(&"toggle_inventory",    _key(KEY_I))
	_define(&"toggle_skills",       _key(KEY_K))
	_define(&"toggle_character",    _key(KEY_T))   # was C, but C is dodge default; T is character-sheet convention
	_define(&"toggle_quests",       _key(KEY_J))
	_define(&"toggle_map",          _key(KEY_M))
	_define(&"toggle_achievements", _key(KEY_Y))
	_define(&"toggle_codex",        _key(KEY_L))
	_define(&"toggle_pause",        _key(KEY_ESCAPE))
	_define(&"open_chat",           _key(KEY_ENTER))   # multiplayer
	_define(&"toggle_walk",         _key(KEY_CAPSLOCK))
	# Mount + pet + recall
	_define(&"toggle_mount",        _key(KEY_G))
	_define(&"toggle_pet",          _key(KEY_H))
	_define(&"toggle_recall",       _key(KEY_N))   # N for "navigate home"
	# Quest focus cycle (used by quest_tracker to highlight the active goal)
	_define(&"quest_focus_prev",    _key(KEY_COMMA))
	_define(&"quest_focus_next",    _key(KEY_PERIOD))
	# Inventory hotkey
	_define(&"inventory_sort",      _key(KEY_Z))   # was sheath_weapon (dead binding)
	# Combat utility, kept for forward compat with planned sheath/swap UI
	_define(&"swap_weapons",        _key(KEY_X))

	load_bindings()

# === Defining and binding ===
func _define(action: StringName, default_event: InputEvent) -> void:
	defaults[action] = default_event
	if not InputMap.has_action(action):
		InputMap.add_action(action)

func _key(code: Key) -> InputEvent:
	var e := InputEventKey.new()
	e.physical_keycode = code
	return e

func _mouse(button: MouseButton) -> InputEvent:
	var e := InputEventMouseButton.new()
	e.button_index = button
	return e

func get_binding(action: StringName) -> InputEvent:
	var events := InputMap.action_get_events(action)
	return events[0] if events.size() > 0 else null

func set_binding(action: StringName, event: InputEvent) -> void:
	if not InputMap.has_action(action):
		return
	InputMap.action_erase_events(action)
	InputMap.action_add_event(action, event)
	save_bindings()

func reset_to_default(action: StringName) -> void:
	if defaults.has(action):
		set_binding(action, defaults[action])

func reset_all_to_default() -> void:
	for action in defaults.keys():
		set_binding(action, defaults[action])

# === Rebinding flow ===
func start_rebinding(action: StringName) -> void:
	_is_rebinding = true
	_rebind_target = action
	rebinding_started.emit(action)
	set_process_input(true)

func cancel_rebinding() -> void:
	_is_rebinding = false
	_rebind_target = &""
	set_process_input(false)
	rebinding_cancelled.emit()

func _input(event: InputEvent) -> void:
	if not _is_rebinding:
		return
	if event is InputEventKey and event.pressed:
		if event.keycode == KEY_ESCAPE:
			cancel_rebinding()
			return
		set_binding(_rebind_target, event)
		_finish_rebind(event)
	elif event is InputEventMouseButton and event.pressed:
		set_binding(_rebind_target, event)
		_finish_rebind(event)
	elif event is InputEventJoypadButton and event.pressed:
		set_binding(_rebind_target, event)
		_finish_rebind(event)

func _finish_rebind(event: InputEvent) -> void:
	rebinding_completed.emit(_rebind_target, event)
	_is_rebinding = false
	_rebind_target = &""
	set_process_input(false)

# === Persistence ===
func save_bindings() -> void:
	var cfg := ConfigFile.new()
	for action in defaults.keys():
		var ev := get_binding(action)
		if ev:
			cfg.set_value("bindings", String(action), event_to_dict(ev))
	cfg.save(SAVE_PATH)

func load_bindings() -> void:
	var cfg := ConfigFile.new()
	if cfg.load(SAVE_PATH) != OK:
		return
	if not cfg.has_section("bindings"):
		return
	for key in cfg.get_section_keys("bindings"):
		var action := StringName(key)
		var data: Dictionary = cfg.get_value("bindings", key, {})
		var ev := dict_to_event(data)
		if ev:
			set_binding(action, ev)

func event_to_dict(event: InputEvent) -> Dictionary:
	if event is InputEventKey:
		return {"type": "key", "code": event.physical_keycode}
	if event is InputEventMouseButton:
		return {"type": "mouse", "button": event.button_index}
	if event is InputEventJoypadButton:
		return {"type": "pad", "button": event.button_index}
	return {}

func dict_to_event(d: Dictionary) -> InputEvent:
	match d.get("type", ""):
		"key":
			var e := InputEventKey.new()
			e.physical_keycode = int(d.get("code", 0))
			return e
		"mouse":
			var e := InputEventMouseButton.new()
			e.button_index = int(d.get("button", 0))
			return e
		"pad":
			var e := InputEventJoypadButton.new()
			e.button_index = int(d.get("button", 0))
			return e
		_:
			return null

# === Display helpers ===
func describe_binding(action: StringName) -> String:
	var ev := get_binding(action)
	if not ev:
		return "(unbound)"
	if ev is InputEventKey:
		return OS.get_keycode_string(ev.physical_keycode)
	if ev is InputEventMouseButton:
		match ev.button_index:
			MOUSE_BUTTON_LEFT: return "LMB"
			MOUSE_BUTTON_RIGHT: return "RMB"
			MOUSE_BUTTON_MIDDLE: return "MMB"
			MOUSE_BUTTON_WHEEL_UP: return "Wheel Up"
			MOUSE_BUTTON_WHEEL_DOWN: return "Wheel Down"
			_: return "Mouse %d" % ev.button_index
	if ev is InputEventJoypadButton:
		return "Pad %d" % ev.button_index
	return "(unknown)"
