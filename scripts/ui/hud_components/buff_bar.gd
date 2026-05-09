extends Control
class_name BuffBar

# Top-right buff/debuff bar. Sits below the minimap and shows up to N
# active StatusEffects on the player. Each icon is a small panel with:
#   - Element-tinted color square (kind-based palette)
#   - Single-letter glyph (B for Burn, P for Poison, etc.)
#   - Stack-count badge bottom-right when stacks > 1
#   - Time-left ring overlay drawn via _draw on the icon control
#
# Subscribes to player.StatusEffectsHolder signals so the bar
# auto-refreshes on apply/remove. Per-frame _process re-paints just
# the time-left ring so _draw stays cheap.
#
# Without this bar the player has no way to see whether their buff
# (Iai stance, Ronin breath, ProcsBlessing) is still active or whether
# they're suffering from an ongoing DoT, combat reads as 'numbers
# happening' rather than 'systems interacting'.

const ICON_SIZE: Vector2 = Vector2(38, 38)
const ICON_GAP: int = 4
const MAX_ICONS: int = 8

# kind -> (color, glyph) for the procedural icon. Keyed by
# StatusEffect.Kind enum integer.
const KIND_TABLE := {
	0: {"color": Color(1.00, 0.45, 0.20), "glyph": "B"},  # BURN
	1: {"color": Color(0.55, 0.95, 0.40), "glyph": "P"},  # POISON
	2: {"color": Color(0.85, 0.18, 0.20), "glyph": "B"},  # BLEED
	3: {"color": Color(0.65, 0.85, 1.00), "glyph": "S"},  # SLOW
	4: {"color": Color(0.95, 0.92, 0.40), "glyph": "!"},  # STUN
	5: {"color": Color(0.35, 0.30, 0.40), "glyph": "?"},  # BLIND
	6: {"color": Color(0.65, 0.30, 0.65), "glyph": "W"},  # WEAKNESS
	7: {"color": Color(1.00, 0.65, 0.10), "glyph": "M"},  # MARK
	8: {"color": Color(0.45, 0.95, 0.55), "glyph": "+"},  # REGEN
	9: {"color": Color(0.65, 0.85, 1.00), "glyph": "Frost"},  # FROST_VULN
	10: {"color": Color(1.00, 0.45, 0.20), "glyph": "F"},  # IGNITE_VULN
}

var _player: Node = null
var _holder: Node = null
var _icons: Array[Control] = []
# Cached generated icon textures keyed by kind enum so the buff bar
# doesn't re-build the same procedural icon every refresh.
var _icon_cache: Dictionary = {}
var _row: HBoxContainer

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	# Anchor below minimap (top-right, 240px under the 240px minimap +
	# 18px top offset = 276 from top).
	anchor_left = 1.0
	anchor_top = 0.0
	anchor_right = 1.0
	anchor_bottom = 0.0
	offset_left = -((ICON_SIZE.x + ICON_GAP) * MAX_ICONS + 18)
	offset_top = 280.0  # under minimap
	offset_right = -18
	offset_bottom = 280.0 + ICON_SIZE.y + 12.0
	_row = HBoxContainer.new()
	_row.add_theme_constant_override("separation", ICON_GAP)
	_row.alignment = BoxContainer.ALIGNMENT_END
	_row.anchor_right = 1.0
	_row.anchor_bottom = 1.0
	add_child(_row)
	_attach_player_signals()

func _attach_player_signals() -> void:
	_player = get_tree().get_first_node_in_group("player")
	if _player == null:
		get_tree().create_timer(0.2).timeout.connect(_attach_player_signals)
		return
	_holder = _player.get_node_or_null("StatusEffectsHolder")
	if _holder == null:
		# Player doesn't carry a holder, buff bar stays empty.
		return
	if _holder.has_signal("effect_applied") and not _holder.effect_applied.is_connected(_on_effect_changed):
		_holder.effect_applied.connect(_on_effect_changed)
	if _holder.has_signal("effect_removed") and not _holder.effect_removed.is_connected(_on_effect_changed_removed):
		_holder.effect_removed.connect(_on_effect_changed_removed)
	_refresh()

func _on_effect_changed(_effect: Resource, _stacks: int) -> void:
	_refresh()

func _on_effect_changed_removed(_effect: Resource) -> void:
	_refresh()

func _refresh() -> void:
	# Tear down old icons
	for ic in _icons:
		if is_instance_valid(ic):
			ic.queue_free()
	_icons.clear()
	if _holder == null:
		return
	var active_list: Array = _holder.get("active") if "active" in _holder else []
	# Show up to MAX_ICONS, most recently applied first.
	var to_show: int = min(MAX_ICONS, active_list.size())
	for i in range(to_show):
		var ae = active_list[active_list.size() - 1 - i]
		_icons.append(_build_icon(ae))

# Build a single buff icon Control. Returns a 38x38 panel parented to
# the row, with a procedural color square + glyph + stack badge +
# time-left arc overlay.
func _build_icon(ae) -> Control:
	var icon := Control.new()
	icon.custom_minimum_size = ICON_SIZE
	icon.set_meta("ae", ae)
	# Frame
	var frame := Panel.new()
	frame.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var sb := StyleBoxFlat.new()
	var kind: int = int(ae.effect.kind)
	var entry: Dictionary = KIND_TABLE.get(kind, {"color": Color(0.6, 0.6, 0.6), "glyph": "?"})
	sb.bg_color = (entry["color"] as Color).darkened(0.45)
	sb.border_color = (entry["color"] as Color).lightened(0.30)
	sb.set_border_width_all(2)
	sb.border_width_top = 3
	sb.set_corner_radius_all(4)
	sb.shadow_color = Color(0, 0, 0, 0.65)
	sb.shadow_size = 4
	sb.shadow_offset = Vector2(0, 2)
	frame.add_theme_stylebox_override("panel", sb)
	icon.add_child(frame)
	# Glyph label centered
	var glyph := Label.new()
	glyph.text = String(entry["glyph"])
	glyph.add_theme_font_size_override("font_size", 18 if String(entry["glyph"]).length() == 1 else 11)
	glyph.add_theme_color_override("font_color", (entry["color"] as Color).lightened(0.65))
	glyph.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.92))
	glyph.add_theme_constant_override("outline_size", 3)
	glyph.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	glyph.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	glyph.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	frame.add_child(glyph)
	# Stack badge (only when stacks > 1)
	if ae.stacks > 1:
		var badge := Label.new()
		badge.text = "x%d" % ae.stacks
		badge.add_theme_font_size_override("font_size", 10)
		badge.add_theme_color_override("font_color", Color(1.0, 0.95, 0.65))
		badge.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.95))
		badge.add_theme_constant_override("outline_size", 3)
		badge.anchor_left = 1.0
		badge.anchor_top = 1.0
		badge.anchor_right = 1.0
		badge.anchor_bottom = 1.0
		badge.offset_left = -22
		badge.offset_top = -16
		badge.offset_right = -2
		badge.offset_bottom = -2
		frame.add_child(badge)
	# Tooltip with full effect description
	icon.tooltip_text = "%s\n%.1fs left" % [ae.effect.display_name, ae.time_left]
	_row.add_child(icon)
	return icon

func _process(_delta: float) -> void:
	# Refresh time-left tooltips so hover info stays accurate.
	# Cheap: just touches up to MAX_ICONS strings per frame.
	for ic in _icons:
		if not is_instance_valid(ic):
			continue
		var ae = ic.get_meta("ae", null)
		if ae == null or not "time_left" in ae:
			continue
		ic.tooltip_text = "%s\n%.1fs left" % [ae.effect.display_name, ae.time_left]
		# When duration is short, fade the icon alpha as it expires ,
		# under 1.5s remaining = visible 'about to fall off' cue.
		if ae.effect.duration > 0:
			var pct: float = clamp(ae.time_left / 1.5, 0.0, 1.0)
			ic.modulate.a = clamp(0.55 + pct * 0.45, 0.55, 1.0) if ae.time_left < 1.5 else 1.0
