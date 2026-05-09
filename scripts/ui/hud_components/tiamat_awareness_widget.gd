extends Control
class_name TiamatAwarenessWidget

# Top-right HUD widget for Tiamat's awareness. Hidden at DORMANT so the
# player doesn't see her until she stirs. Once STIRRING, the widget
# fades in with a small motif glyph + tier name + thin progress arc.
# Tier transitions pulse the widget to draw attention.
#
# Visual:
#   ┌─────────────────────┐
#   │   ⏣  STIRRING       │  small glyph (cuneiform tablet) + tier
#   │   ▰▰▰▱▱▱▱▱▱▱        │  thin progress to next tier
#   └─────────────────────┘
#
# Color shifts with tier:
#   STIRRING  -> dim violet
#   WAKING    -> deeper violet, slight glow
#   WAKING_2  -> ember red-violet, soft pulse
#   AWAKE     -> blood red, strong pulse, no progress arc

const T := preload("res://scripts/ui/ui_theme.gd")

const WIDGET_WIDTH: float = 200.0
const WIDGET_HEIGHT: float = 56.0
const ANCHOR_OFFSET_X: float = -220.0  # from right edge, leaves margin for minimap
const ANCHOR_OFFSET_Y: float = 18.0    # from top edge

const TIER_COLORS := {
	"STIRRING": Color(0.55, 0.40, 0.75, 0.85),
	"WAKING":   Color(0.65, 0.35, 0.85, 0.90),
	"WAKING_2": Color(0.85, 0.30, 0.55, 0.92),
	"AWAKE":    Color(0.95, 0.20, 0.20, 0.95),
}

const TIER_GLYPHS := {
	"STIRRING": "⏣",  # cuneiform-ish circular mark
	"WAKING":   "𒈗",  # cuneiform LUGAL (king/lord)
	"WAKING_2": "𒀭",  # cuneiform AN (sky-god, deity)
	"AWAKE":    "𒋾",  # cuneiform TI (eye/witness)
}

var _bg: PanelContainer = null
var _glyph_label: Label = null
var _tier_label: Label = null
var _progress: ProgressBar = null
var _pulse_tween: Tween = null

func _ready() -> void:
	# Anchor top-right of viewport. Mounting parent decides actual
	# placement, this keeps us out of the boss bar's lane (top center).
	anchor_left = 1.0
	anchor_right = 1.0
	anchor_top = 0.0
	anchor_bottom = 0.0
	offset_left = ANCHOR_OFFSET_X
	offset_right = ANCHOR_OFFSET_X + WIDGET_WIDTH
	offset_top = ANCHOR_OFFSET_Y
	offset_bottom = ANCHOR_OFFSET_Y + WIDGET_HEIGHT
	_build()
	# Subscribe to TiamatRegistry signals so the widget refreshes on
	# tick. Connect deferred so the autoload has finished _ready.
	call_deferred("_wire_signals")
	# Initial visibility: hide if DORMANT, show if any tier above.
	_refresh_from_state()

func _wire_signals() -> void:
	var tr: Node = get_node_or_null("/root/TiamatRegistry")
	if tr == null:
		return
	if tr.has_signal("awareness_changed"):
		var cb := Callable(self, "_on_awareness_changed")
		if not tr.awareness_changed.is_connected(cb):
			tr.awareness_changed.connect(cb)
	if tr.has_signal("tier_changed"):
		var tcb := Callable(self, "_on_tier_changed")
		if not tr.tier_changed.is_connected(tcb):
			tr.tier_changed.connect(tcb)

func _build() -> void:
	for c in get_children():
		c.queue_free()
	_bg = PanelContainer.new()
	_bg.add_theme_stylebox_override("panel", T.panel_box(
		Color(0.65, 0.30, 0.85, 0.85),
		Color(0.05, 0.04, 0.08, 0.75)
	))
	_bg.anchor_left = 0.0; _bg.anchor_right = 1.0
	_bg.anchor_top = 0.0;  _bg.anchor_bottom = 1.0
	add_child(_bg)

	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 4)
	_bg.add_child(v)

	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", 8)
	v.add_child(h)

	_glyph_label = Label.new()
	_glyph_label.text = TIER_GLYPHS.get("STIRRING", "?")
	_glyph_label.add_theme_font_size_override("font_size", 22)
	_glyph_label.custom_minimum_size = Vector2(28, 0)
	h.add_child(_glyph_label)

	_tier_label = Label.new()
	_tier_label.text = "DORMANT"
	_tier_label.add_theme_font_size_override("font_size", T.FONT_HINT)
	_tier_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	h.add_child(_tier_label)

	_progress = ProgressBar.new()
	_progress.min_value = 0.0
	_progress.max_value = 1.0
	_progress.value = 0.0
	_progress.show_percentage = false
	_progress.custom_minimum_size = Vector2(0, 4)
	v.add_child(_progress)

func _refresh_from_state() -> void:
	var tr: Node = get_node_or_null("/root/TiamatRegistry")
	if tr == null:
		visible = false
		return
	var awareness: int = int(tr.get_awareness()) if tr.has_method("get_awareness") else 0
	var tier: String = String(tr.current_tier()) if tr.has_method("current_tier") else "DORMANT"
	# DORMANT hides the widget. The first tier-up reveals it.
	visible = tier != "DORMANT"
	if not visible:
		return
	var color: Color = TIER_COLORS.get(tier, Color(0.55, 0.40, 0.75, 0.85))
	if _glyph_label:
		_glyph_label.text = TIER_GLYPHS.get(tier, "?")
		_glyph_label.add_theme_color_override("font_color", color)
	if _tier_label:
		_tier_label.text = tier
		_tier_label.add_theme_color_override("font_color", color)
	if _progress:
		# AWAKE has no "next tier", fill the bar to convey finality.
		if tier == "AWAKE":
			_progress.value = 1.0
			_progress.modulate = color
		else:
			var pct: float = float(tr.tier_progress()) if tr.has_method("tier_progress") else 0.0
			_progress.value = pct
			_progress.modulate = color
	# Border tracks tier color too
	if _bg:
		_bg.add_theme_stylebox_override("panel", T.panel_box(
			color,
			Color(0.05, 0.04, 0.08, 0.75)
		))

func _on_awareness_changed(_new_value: int, _old_value: int) -> void:
	_refresh_from_state()

func _on_tier_changed(_new_tier: String, _old_tier: String, _new_value: int) -> void:
	_refresh_from_state()
	_pulse_attention()

# Quick scale-pulse to draw the player's eye on tier-up. Falls through
# silently if a tween is already running so multi-tier jumps don't stack.
func _pulse_attention() -> void:
	if _pulse_tween and _pulse_tween.is_valid():
		_pulse_tween.kill()
	_pulse_tween = create_tween()
	_pulse_tween.set_parallel(false)
	_pulse_tween.tween_property(self, "scale", Vector2(1.18, 1.18), 0.18).set_ease(Tween.EASE_OUT)
	_pulse_tween.tween_property(self, "scale", Vector2(1.0, 1.0), 0.32).set_ease(Tween.EASE_IN)
