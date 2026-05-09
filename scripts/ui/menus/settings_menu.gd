extends CanvasLayer
class_name SettingsMenu

# Sectioned settings panel. Reads/writes GameSettings autoload.
# Tabs: Display / Audio / Controls / Gameplay / Accessibility / Privacy.
# Each field is declared in FIELDS as (key, label, type, options) and the
# UI builds itself from that — adding a setting later is a dict edit, not a
# scene rebuild.

signal closed

const FIELD_TYPE_BOOL := 0
const FIELD_TYPE_FLOAT_SLIDER := 1
const FIELD_TYPE_INT_DROPDOWN := 2
const FIELD_TYPE_STRING_DROPDOWN := 3

# (key, label, type, ...kind-specific extras)
# float_slider: min, max, step
# int_dropdown:    options as Array[int]
# string_dropdown: options as Array[String]
const FIELDS := {
	"Display": [
		["fullscreen",        "Fullscreen",          FIELD_TYPE_BOOL],
		["vsync",             "VSync",               FIELD_TYPE_BOOL],
		["fps_cap",           "FPS Cap",             FIELD_TYPE_INT_DROPDOWN, [30, 60, 90, 120, 144, 240, 0]],
		["resolution_scale",  "Render Scale",        FIELD_TYPE_FLOAT_SLIDER, 0.5, 2.0, 0.1],
		["msaa",              "MSAA",                FIELD_TYPE_INT_DROPDOWN, [0, 2, 4, 8]],
		["brightness",        "Brightness",          FIELD_TYPE_FLOAT_SLIDER, 0.5, 1.5, 0.05],
		["contrast",          "Contrast",            FIELD_TYPE_FLOAT_SLIDER, 0.5, 1.5, 0.05],
		["ui_scale",          "UI Scale",            FIELD_TYPE_FLOAT_SLIDER, 0.75, 1.5, 0.05],
	],
	"Audio": [
		["master_volume",     "Master",              FIELD_TYPE_FLOAT_SLIDER, 0.0, 1.0, 0.05],
		["music_volume",      "Music",               FIELD_TYPE_FLOAT_SLIDER, 0.0, 1.0, 0.05],
		["sfx_volume",        "SFX",                 FIELD_TYPE_FLOAT_SLIDER, 0.0, 1.0, 0.05],
		["ambient_volume",    "Ambient",             FIELD_TYPE_FLOAT_SLIDER, 0.0, 1.0, 0.05],
		["voice_volume",      "Voice",               FIELD_TYPE_FLOAT_SLIDER, 0.0, 1.0, 0.05],
		["mute_when_unfocused","Mute when unfocused", FIELD_TYPE_BOOL],
	],
	"Controls": [
		["mouse_sensitivity", "Mouse Sensitivity",   FIELD_TYPE_FLOAT_SLIDER, 0.25, 3.0, 0.05],
		["camera_invert_y",   "Invert Camera Y",     FIELD_TYPE_BOOL],
		["camera_smoothing",  "Camera Smoothing",    FIELD_TYPE_FLOAT_SLIDER, 0.0, 1.0, 0.05],
		["sprint_toggle",     "Sprint Toggle (vs Hold)", FIELD_TYPE_BOOL],
		["auto_target",       "Auto-target nearest enemy", FIELD_TYPE_BOOL],
		["click_to_move",     "Click-to-Move (Diablo style)", FIELD_TYPE_BOOL],
	],
	"Gameplay": [
		["show_damage_numbers",         "Show damage numbers",   FIELD_TYPE_BOOL],
		["show_floating_loot_text",     "Show loot text",        FIELD_TYPE_BOOL],
		["aggressive_loot_pickup",      "Auto-pickup loot",      FIELD_TYPE_BOOL],
		["difficulty_warning_underleveled", "Difficulty warnings", FIELD_TYPE_BOOL],
		["show_minimap",                "Show minimap",          FIELD_TYPE_BOOL],
		["show_objective_marker",       "Show objective markers", FIELD_TYPE_BOOL],
		["hud_scale",                   "HUD Scale",             FIELD_TYPE_FLOAT_SLIDER, 0.75, 1.5, 0.05],
	],
	"Accessibility": [
		["screen_shake",     "Screen Shake",         FIELD_TYPE_FLOAT_SLIDER, 0.0, 1.0, 0.05],
		["hit_stop",         "Hit-stop / slow-mo",   FIELD_TYPE_FLOAT_SLIDER, 0.0, 1.0, 0.05],
		["color_blind_mode", "Color Blind Mode",     FIELD_TYPE_STRING_DROPDOWN, ["none", "protanopia", "deuteranopia", "tritanopia"]],
		["reduced_motion",   "Reduce motion",        FIELD_TYPE_BOOL],
		["subtitles_enabled","Subtitles",            FIELD_TYPE_BOOL],
		["subtitle_size",    "Subtitle size",        FIELD_TYPE_INT_DROPDOWN, [14, 18, 22, 28]],
		["hud_high_contrast","High-contrast HUD",    FIELD_TYPE_BOOL],
	],
	"Privacy": [
		["allow_anon_telemetry", "Anonymous telemetry",  FIELD_TYPE_BOOL],
		["allow_crash_reports",  "Crash reports",        FIELD_TYPE_BOOL],
	],
}

const TAB_ORDER := ["Display", "Audio", "Controls", "Gameplay", "Accessibility", "Privacy"]

@onready var dim: ColorRect = $Dim if has_node("Dim") else null
@onready var panel: PanelContainer = $Panel if has_node("Panel") else null

var settings: Node = null
var _current_tab: String = "Display"

func _ready() -> void:
	visible = false
	process_mode = Node.PROCESS_MODE_ALWAYS
	settings = get_node_or_null("/root/GameSettings")

func open() -> void:
	visible = true
	get_tree().paused = true
	_build()

func close() -> void:
	visible = false
	get_tree().paused = false
	# Persist on close so the player doesn't have to manually save
	if settings and settings.has_method("save_settings"):
		settings.save_settings()
	closed.emit()

func _input(event: InputEvent) -> void:
	if visible and event.is_action_pressed("ui_cancel"):
		close()

func _build() -> void:
	if not panel:
		return
	for c in panel.get_children():
		c.queue_free()

	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 28)
	margin.add_theme_constant_override("margin_right", 28)
	margin.add_theme_constant_override("margin_top", 24)
	margin.add_theme_constant_override("margin_bottom", 24)
	panel.add_child(margin)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 14)
	margin.add_child(vbox)

	# Header
	var header := HBoxContainer.new()
	vbox.add_child(header)
	var title := Label.new()
	title.text = "Settings"
	title.add_theme_font_size_override("font_size", 22)
	title.add_theme_color_override("font_color", Color(0.95, 0.85, 0.45))
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header.add_child(title)
	var close_btn := Button.new()
	close_btn.text = "Close [Esc]"
	close_btn.custom_minimum_size = Vector2(120, 32)
	close_btn.pressed.connect(close)
	header.add_child(close_btn)

	# Tab row
	var tabs := HBoxContainer.new()
	tabs.add_theme_constant_override("separation", 6)
	vbox.add_child(tabs)
	for t in TAB_ORDER:
		tabs.add_child(_make_tab(t))

	# Content
	var scroll := ScrollContainer.new()
	scroll.custom_minimum_size = Vector2(720, 440)
	scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	vbox.add_child(scroll)
	var content := VBoxContainer.new()
	content.add_theme_constant_override("separation", 8)
	content.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(content)

	if not settings:
		content.add_child(_make_label("GameSettings autoload not available."))
		return
	for field_def in FIELDS.get(_current_tab, []):
		content.add_child(_make_field_row(field_def))

func _make_tab(t: String) -> Button:
	var b := Button.new()
	b.text = t
	b.custom_minimum_size = Vector2(110, 32)
	b.modulate = Color(1, 1, 1) if _current_tab == t else Color(0.65, 0.65, 0.65)
	b.pressed.connect(func():
		_current_tab = t
		_build()
	)
	return b

func _make_field_row(field_def: Array) -> Control:
	var key: String = field_def[0]
	var label: String = field_def[1]
	var ftype: int = field_def[2]

	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 16)
	var lab := Label.new()
	lab.text = label
	lab.add_theme_font_size_override("font_size", 13)
	lab.add_theme_color_override("font_color", Color(0.85, 0.80, 0.65))
	lab.custom_minimum_size = Vector2(280, 32)
	row.add_child(lab)

	match ftype:
		FIELD_TYPE_BOOL:
			var cb := CheckBox.new()
			cb.button_pressed = bool(settings.get(key))
			cb.toggled.connect(func(v): _set(key, v))
			row.add_child(cb)
		FIELD_TYPE_FLOAT_SLIDER:
			var min_v: float = field_def[3]
			var max_v: float = field_def[4]
			var step: float = field_def[5]
			var slider := HSlider.new()
			slider.min_value = min_v
			slider.max_value = max_v
			slider.step = step
			slider.value = float(settings.get(key))
			slider.custom_minimum_size = Vector2(220, 24)
			var val_lab := Label.new()
			val_lab.text = "%.2f" % float(slider.value)
			val_lab.custom_minimum_size = Vector2(60, 0)
			val_lab.add_theme_color_override("font_color", Color(0.95, 0.85, 0.45))
			slider.value_changed.connect(func(v):
				val_lab.text = "%.2f" % v
				_set(key, v)
			)
			row.add_child(slider)
			row.add_child(val_lab)
		FIELD_TYPE_INT_DROPDOWN:
			var options: Array = field_def[3]
			var dd := OptionButton.new()
			var current_v: int = int(settings.get(key))
			var sel_index: int = 0
			for i in range(options.size()):
				dd.add_item("Unlimited" if int(options[i]) == 0 else str(options[i]))
				if int(options[i]) == current_v:
					sel_index = i
			dd.select(sel_index)
			dd.item_selected.connect(func(i): _set(key, int(options[i])))
			row.add_child(dd)
		FIELD_TYPE_STRING_DROPDOWN:
			var options2: Array = field_def[3]
			var dd2 := OptionButton.new()
			var current_v2: String = String(settings.get(key))
			var sel_index2: int = 0
			for i in range(options2.size()):
				dd2.add_item(String(options2[i]).capitalize())
				if String(options2[i]) == current_v2:
					sel_index2 = i
			dd2.select(sel_index2)
			dd2.item_selected.connect(func(i): _set(key, options2[i]))
			row.add_child(dd2)

	return row

func _set(key: String, value) -> void:
	if not settings:
		return
	if settings.has_method("set_value"):
		settings.set_value(StringName(_current_tab.to_lower()), StringName(key), value)
	else:
		settings.set(key, value)
		if settings.has_method("apply_all"):
			settings.apply_all()

func _make_label(text: String) -> Label:
	var lab := Label.new()
	lab.text = text
	lab.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	lab.add_theme_font_size_override("font_size", 14)
	lab.add_theme_color_override("font_color", Color(0.75, 0.70, 0.60))
	return lab
