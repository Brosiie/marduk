extends Control
class_name ActionBar

# Bottom-right cluster of menu buttons. Each button toggles its corresponding
# MenuPanel tab. Mirrors the existing hotkeys (I, T, K, J, M, L, Y, Esc) so
# new players have a visible affordance instead of having to read the help
# footer.

const BUTTON_SIZE: Vector2 = Vector2(46, 46)
const BUTTON_GAP: int = 4
const MARGIN_RIGHT: float  = 16.0
const MARGIN_BOTTOM: float = 16.0

# {tab_name, label_glyph, hotkey_letter, tooltip}
# label_glyph stays text-only so the bar works without sprites.
const BUTTONS := [
	{ "tab": &"inventory",    "glyph": "I",  "key": "I",  "tip": "Inventory  (I)" },
	{ "tab": &"equipment",    "glyph": "E",  "key": "",   "tip": "Equipment" },
	{ "tab": &"character",    "glyph": "C",  "key": "T",  "tip": "Character  (T)" },
	{ "tab": &"skills",       "glyph": "K",  "key": "K",  "tip": "Skills  (K)" },
	{ "tab": &"quests",       "glyph": "Q",  "key": "J",  "tip": "Quests  (J)" },
	{ "tab": &"map",          "glyph": "M",  "key": "M",  "tip": "Map  (M)" },
	{ "tab": &"codex",        "glyph": "L",  "key": "L",  "tip": "Codex  (L)" },
	{ "tab": &"achievements", "glyph": "A",  "key": "Y",  "tip": "Achievements  (Y)" },
	{ "tab": &"friends",      "glyph": "F",  "key": "",   "tip": "Friends" },
	{ "tab": &"options",      "glyph": "S",  "key": "Esc","tip": "Settings  (Esc)" },
]

var _menu_panel: Control = null

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	anchor_left = 1.0
	anchor_top = 1.0
	anchor_right = 1.0
	anchor_bottom = 1.0
	# Resolve the MenuPanel, sibling under the HUD CanvasLayer.
	var hud := _find_hud()
	if hud:
		_menu_panel = hud.menu_panel if "menu_panel" in hud else hud.get_node_or_null("MenuPanel")
	# Layout: HBoxContainer pinned to bottom-right.
	var box := HBoxContainer.new()
	box.add_theme_constant_override("separation", BUTTON_GAP)
	box.mouse_filter = Control.MOUSE_FILTER_PASS
	add_child(box)
	for entry in BUTTONS:
		box.add_child(_make_button(entry))
	# Position after children so we know the actual width
	await get_tree().process_frame
	var w: float = box.get_combined_minimum_size().x
	var h: float = box.get_combined_minimum_size().y
	box.position = Vector2(-w - MARGIN_RIGHT, -h - MARGIN_BOTTOM)
	box.size = Vector2(w, h)

func _make_button(entry: Dictionary) -> Button:
	var b := Button.new()
	b.custom_minimum_size = BUTTON_SIZE
	b.text = String(entry.glyph)
	b.tooltip_text = String(entry.tip)
	b.focus_mode = Control.FOCUS_NONE
	b.add_theme_font_size_override("font_size", 18)
	# Subtle dark theme so the bar reads as HUD chrome, not a popup.
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.08, 0.08, 0.10, 0.85)
	sb.border_color = Color(0.45, 0.35, 0.20, 0.8)
	sb.set_border_width_all(1)
	sb.set_corner_radius_all(4)
	b.add_theme_stylebox_override("normal", sb)
	var sb_hover := sb.duplicate() as StyleBoxFlat
	sb_hover.bg_color = Color(0.16, 0.13, 0.08, 0.95)
	sb_hover.border_color = Color(0.95, 0.70, 0.30, 1.0)
	b.add_theme_stylebox_override("hover", sb_hover)
	var sb_pressed := sb_hover.duplicate() as StyleBoxFlat
	sb_pressed.bg_color = Color(0.32, 0.22, 0.10, 1.0)
	b.add_theme_stylebox_override("pressed", sb_pressed)
	b.add_theme_color_override("font_color",         Color(0.90, 0.85, 0.70))
	b.add_theme_color_override("font_hover_color",   Color(1.00, 0.95, 0.80))
	b.add_theme_color_override("font_pressed_color", Color(1.0, 0.85, 0.30))
	b.pressed.connect(_on_pressed.bind(entry.tab))
	return b

func _on_pressed(tab: StringName) -> void:
	if _menu_panel == null or not _menu_panel.has_method("toggle_tab"):
		push_warning("ActionBar: MenuPanel not available")
		return
	_menu_panel.toggle_tab(tab)

func _find_hud() -> Node:
	# The HUD adds this ActionBar as a child of $Root. Walk up until we
	# hit the CanvasLayer (HUD) so we can reach menu_panel.
	var n: Node = self
	while n:
		if n is HUD:
			return n
		n = n.get_parent()
	return null
