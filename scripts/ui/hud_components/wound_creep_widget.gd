extends Control
class_name WoundCreepWidget

# Top-right HUD widget for Wound creep, tucked just below the Tiamat
# awareness widget. Hidden at CONTAINED so the player isn't shown a
# threat that doesn't yet exist. SEEPING fades it in with a small
# vegetal glyph + tier name + a creep bar that fills toward the next
# threshold.
#
# Visual:
#   ┌─────────────────────┐
#   │  ☘  SEEPING          │  small leaf-ish glyph + tier
#   │  ▰▰▰▱▱▱▱▱▱▱          │  thin progress to next tier
#   └─────────────────────┘
#
# Color shifts with tier from soft moss-green (CONTAINED, hidden) up
# through warning ambers/reds at CONSUMING. Distinct palette from the
# Tiamat widget so the two threats read as independent.

const T := preload("res://scripts/ui/ui_theme.gd")

const WIDGET_WIDTH: float = 200.0
const WIDGET_HEIGHT: float = 56.0
const ANCHOR_OFFSET_X: float = -220.0
const ANCHOR_OFFSET_Y: float = 84.0  # below Tiamat widget (y=18, h=56, gap=10)

const TIER_COLORS := {
	"SEEPING":     Color(0.55, 0.85, 0.45, 0.85),  # green, healthy-warning
	"BLEEDING":    Color(0.65, 0.85, 0.30, 0.90),  # yellow-green, escalating
	"UNCONTAINED": Color(0.85, 0.65, 0.20, 0.92),  # amber, danger
	"CONSUMING":   Color(0.85, 0.30, 0.20, 0.95),  # red, terminal
}

# Wound-themed glyphs. Mix of botanical/wound symbols. The progression
# goes from "growing thing" through "spreading" into "consuming". Same
# pattern as Tiamat's cuneiform escalation.
const TIER_GLYPHS := {
	"SEEPING":     "☘",   # Shamrock (alive, spreading)
	"BLEEDING":    "✤",   # quaternary leaf (more aggressive)
	"UNCONTAINED": "✣",   # filled flower star (out of bounds)
	"CONSUMING":   "✺",   # eight-pointed pinwheel (chaotic, total)
}

var _bg: PanelContainer = null
var _glyph_label: Label = null
var _tier_label: Label = null
var _progress: ProgressBar = null
var _pulse_tween: Tween = null

func _ready() -> void:
	anchor_left = 1.0
	anchor_right = 1.0
	anchor_top = 0.0
	anchor_bottom = 0.0
	offset_left = ANCHOR_OFFSET_X
	offset_right = ANCHOR_OFFSET_X + WIDGET_WIDTH
	offset_top = ANCHOR_OFFSET_Y
	offset_bottom = ANCHOR_OFFSET_Y + WIDGET_HEIGHT
	_build()
	call_deferred("_wire_signals")
	_refresh_from_state()

func _wire_signals() -> void:
	var wr: Node = get_node_or_null("/root/WoundRegistry")
	if wr == null:
		return
	if wr.has_signal("creep_changed"):
		var cb := Callable(self, "_on_creep_changed")
		if not wr.creep_changed.is_connected(cb):
			wr.creep_changed.connect(cb)
	if wr.has_signal("tier_changed"):
		var tcb := Callable(self, "_on_tier_changed")
		if not wr.tier_changed.is_connected(tcb):
			wr.tier_changed.connect(tcb)

func _build() -> void:
	for c in get_children():
		c.queue_free()
	_bg = PanelContainer.new()
	_bg.add_theme_stylebox_override("panel", T.panel_box(
		Color(0.45, 0.65, 0.30, 0.85),
		Color(0.04, 0.08, 0.05, 0.75)
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
	_glyph_label.text = TIER_GLYPHS.get("SEEPING", "?")
	_glyph_label.add_theme_font_size_override("font_size", 22)
	_glyph_label.custom_minimum_size = Vector2(28, 0)
	h.add_child(_glyph_label)

	_tier_label = Label.new()
	_tier_label.text = "CONTAINED"
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
	var wr: Node = get_node_or_null("/root/WoundRegistry")
	if wr == null:
		visible = false
		return
	var tier: String = String(wr.current_tier()) if wr.has_method("current_tier") else "CONTAINED"
	# CONTAINED hides the widget. The first tier-up reveals it.
	visible = tier != "CONTAINED"
	if not visible:
		return
	var color: Color = TIER_COLORS.get(tier, Color(0.55, 0.85, 0.45, 0.85))
	if _glyph_label:
		_glyph_label.text = TIER_GLYPHS.get(tier, "?")
		_glyph_label.add_theme_color_override("font_color", color)
	if _tier_label:
		_tier_label.text = tier
		_tier_label.add_theme_color_override("font_color", color)
	if _progress:
		if tier == "CONSUMING":
			_progress.value = 1.0
			_progress.modulate = color
		else:
			var pct: float = float(wr.tier_progress()) if wr.has_method("tier_progress") else 0.0
			_progress.value = pct
			_progress.modulate = color
	if _bg:
		_bg.add_theme_stylebox_override("panel", T.panel_box(
			color,
			Color(0.04, 0.08, 0.05, 0.75)
		))

func _on_creep_changed(_new_value: int, _old_value: int) -> void:
	_refresh_from_state()

func _on_tier_changed(_new_tier: String, _old_tier: String, _new_value: int) -> void:
	_refresh_from_state()
	_pulse_attention()

func _pulse_attention() -> void:
	if _pulse_tween and _pulse_tween.is_valid():
		_pulse_tween.kill()
	_pulse_tween = create_tween()
	_pulse_tween.set_parallel(false)
	_pulse_tween.tween_property(self, "scale", Vector2(1.18, 1.18), 0.18).set_ease(Tween.EASE_OUT)
	_pulse_tween.tween_property(self, "scale", Vector2(1.0, 1.0), 0.32).set_ease(Tween.EASE_IN)
