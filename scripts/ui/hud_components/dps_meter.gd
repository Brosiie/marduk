extends Control
class_name DpsMeter

# Small bottom-right DPS readout. Shows current rolling 5-second total
# DPS as the headline number + a one-line element breakdown beneath
# (e.g. "fire 65% · physical 30% · holy 5%"). Hidden when no damage
# has been dealt in the window so it stops cluttering the screen
# during exploration. Refreshes at 4 Hz (every 0.25s) — DPS doesn't
# need 60fps fidelity, the reader just wants the magnitude.
#
# Reads from CombatBus.get_dps_breakdown(). If CombatBus exposes no
# damage in the window, the widget hides itself. Cheap.

const REFRESH_INTERVAL: float = 0.25
const ELEMENT_COLORS := {
	&"physical":  Color(0.95, 0.92, 0.55),
	&"fire":      Color(1.00, 0.45, 0.20),
	&"frost":     Color(0.65, 0.85, 1.00),
	&"lightning": Color(0.80, 0.85, 1.00),
	&"holy":      Color(1.00, 0.85, 0.45),
	&"shadow":    Color(0.55, 0.30, 0.75),
	&"void":      Color(0.45, 0.20, 0.55),
}

var _refresh_t: float = 0.0
var _dps_label: Label = null
var _breakdown: RichTextLabel = null

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	# Anchor bottom-right, just above the action bar.
	anchor_left = 1.0
	anchor_right = 1.0
	anchor_top = 1.0
	anchor_bottom = 1.0
	offset_left = -260.0
	offset_right = -20.0
	offset_top = -150.0
	offset_bottom = -90.0
	visible = false
	# Background panel
	var panel := PanelContainer.new()
	panel.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.05, 0.04, 0.06, 0.78)
	sb.border_color = Color(0.55, 0.42, 0.20, 0.85)
	sb.set_border_width_all(1)
	sb.border_width_top = 2
	sb.set_corner_radius_all(4)
	sb.shadow_color = Color(0, 0, 0, 0.55)
	sb.shadow_size = 3
	sb.content_margin_left = 12
	sb.content_margin_right = 12
	sb.content_margin_top = 6
	sb.content_margin_bottom = 6
	panel.add_theme_stylebox_override("panel", sb)
	add_child(panel)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 1)
	panel.add_child(v)
	# Headline DPS number
	_dps_label = Label.new()
	_dps_label.add_theme_font_size_override("font_size", 18)
	_dps_label.add_theme_color_override("font_color", Color(1.0, 0.85, 0.30))
	_dps_label.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.92))
	_dps_label.add_theme_constant_override("outline_size", 3)
	_dps_label.text = "0 DPS"
	v.add_child(_dps_label)
	# Element breakdown beneath
	_breakdown = RichTextLabel.new()
	_breakdown.bbcode_enabled = true
	_breakdown.fit_content = true
	_breakdown.scroll_active = false
	_breakdown.custom_minimum_size = Vector2(220, 16)
	v.add_child(_breakdown)

func _process(delta: float) -> void:
	_refresh_t += delta
	if _refresh_t < REFRESH_INTERVAL:
		return
	_refresh_t = 0.0
	var cb: Node = get_node_or_null("/root/CombatBus")
	if cb == null or not cb.has_method("get_dps_breakdown"):
		visible = false
		return
	var by_el: Dictionary = cb.get_dps_breakdown()
	if by_el.is_empty():
		visible = false
		return
	visible = true
	var total: float = 0.0
	for v in by_el.values():
		total += float(v)
	_dps_label.text = "%d DPS" % int(round(total))
	# Breakdown line: sort elements by dps desc, show top 3 with %.
	# Format: "[color=#xxxx]fire 65%[/color] · ..."
	var sorted_elems: Array = by_el.keys()
	sorted_elems.sort_custom(func(a, b): return float(by_el[a]) > float(by_el[b]))
	var bits: Array[String] = []
	for i in range(min(3, sorted_elems.size())):
		var el: StringName = sorted_elems[i]
		var pct: int = int(round(float(by_el[el]) / max(total, 0.01) * 100.0))
		var c: Color = ELEMENT_COLORS.get(el, Color(0.85, 0.85, 0.85))
		var hex: String = "#%02X%02X%02X" % [int(c.r8), int(c.g8), int(c.b8)]
		bits.append("[color=%s]%s %d%%[/color]" % [hex, String(el), pct])
	_breakdown.text = " · ".join(bits)
