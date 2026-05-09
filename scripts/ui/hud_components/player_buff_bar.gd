extends Control
class_name PlayerBuffBar

# Top-left buff bar showing the player's TRANSIENT timer-based buffs:
#   - Damage Surge (Battle Cry / Power Up)   gold,    6s base
#   - Guard / Divine Shield                  blue,    2s base
#   - Riposte (perfect-dodge bonus)          violet,  1s base
#   - HP Surge potion                        red,    10s
#   - Mana Surge potion                      cyan,   10s
#   - Stamina Surge potion                   green,  10s
#
# Why a separate bar instead of folding into BuffBar (the StatusEffect
# bar):
#   - These are one-shot timer floats on Player, not StatusEffect
#     resources living in StatusEffectsHolder.
#   - They fire often (every dodge, every Q press) so the bar needs to
#     poll a small fixed set, not subscribe to per-effect signals.
#   - Sitting top-left under the HP bar matches Souls / WoW conventions
#     for "buffs you cast on yourself" vs "debuffs applied to you."
#
# Each chip shows: glyph in colored circle + countdown ring overlay +
# small seconds-remaining label. Drops away the moment the timer hits 0.

const ICON_SIZE: Vector2 = Vector2(36, 36)
const ICON_GAP: int = 6
const REFRESH_INTERVAL: float = 0.05  # 20 Hz, smooth countdown ring

var _player: Node = null
var _row: HBoxContainer
var _icons: Dictionary = {}  # buff_id -> Control
var _refresh_t: float = 0.0

# Buff catalog: id -> {label, color, glyph, source, duration}
# `source` is a Callable that returns the seconds-remaining for this buff
# (resolved on the player at runtime via lambdas). `duration` is the max
# duration so the countdown ring can compute pct = remaining / duration.
const _BUFF_DEFS := {
	&"surge_dmg":     {"label": "Battle Cry", "color": Color(1.00, 0.85, 0.30), "glyph": "+"},
	&"guard":         {"label": "Guard",      "color": Color(0.45, 0.75, 1.00), "glyph": "G"},
	&"riposte":       {"label": "Riposte",    "color": Color(0.85, 0.45, 1.00), "glyph": "R"},
	&"surge_hp":      {"label": "HP Surge",   "color": Color(1.00, 0.30, 0.30), "glyph": "♥"},
	&"surge_mana":    {"label": "Mana Surge", "color": Color(0.45, 0.85, 1.00), "glyph": "M"},
	&"surge_stam":    {"label": "Stamina",    "color": Color(0.55, 0.95, 0.55), "glyph": "S"},
}

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	# Anchor top-left, just below the player HP/mana/XP bar stack.
	# HP bar lives around y=20, XP bar pushes the stack to ~y=110.
	# Buffs sit at y=130 so they don't overlap.
	anchor_left = 0.0
	anchor_top = 0.0
	anchor_right = 0.0
	anchor_bottom = 0.0
	offset_left = 20.0
	offset_top = 130.0
	offset_right = 380.0
	offset_bottom = 130.0 + ICON_SIZE.y + 16.0
	_row = HBoxContainer.new()
	_row.add_theme_constant_override("separation", ICON_GAP)
	add_child(_row)
	_resolve_player()

func _resolve_player() -> void:
	_player = get_tree().get_first_node_in_group("player")
	if _player == null:
		# Player might not be in tree yet (HUD spawned first); retry shortly.
		get_tree().create_timer(0.2).timeout.connect(_resolve_player)

func _process(delta: float) -> void:
	_refresh_t += delta
	if _refresh_t < REFRESH_INTERVAL:
		return
	_refresh_t = 0.0
	if _player == null or not is_instance_valid(_player):
		_resolve_player()
		return
	var now: float = Time.get_ticks_msec() / 1000.0
	# Read buff timers off the player. Using `get()` so missing fields
	# return null and we treat them as "not active" instead of crashing
	# on older player.gd builds that don't carry every buff.
	_update_buff(&"surge_dmg",  _read_remaining(now, "_damage_surge_until"),  _player.get("BATTLE_CRY_DURATION") if "BATTLE_CRY_DURATION" in _player else 6.0)
	_update_buff(&"guard",      _read_remaining(now, "_guard_until"),         _player.get("GUARD_DURATION") if "GUARD_DURATION" in _player else 2.0)
	_update_buff(&"riposte",    _read_remaining(now, "_riposte_until"),       _player.get("RIPOSTE_DURATION") if "RIPOSTE_DURATION" in _player else 1.0)
	_update_buff(&"surge_hp",   _read_remaining(now, "_hp_surge_until"),      _player.get("SURGE_DURATION") if "SURGE_DURATION" in _player else 10.0)
	_update_buff(&"surge_mana", _read_remaining(now, "_mana_surge_until"),    _player.get("SURGE_DURATION") if "SURGE_DURATION" in _player else 10.0)
	_update_buff(&"surge_stam", _read_remaining(now, "_stamina_surge_until"), _player.get("SURGE_DURATION") if "SURGE_DURATION" in _player else 10.0)

func _read_remaining(now: float, field: String) -> float:
	if not field in _player:
		return 0.0
	var until: float = float(_player.get(field))
	return max(0.0, until - now)

func _update_buff(id: StringName, remaining: float, max_duration: float) -> void:
	if remaining <= 0.01:
		# Buff expired (or never fired). Drop the chip if present.
		if _icons.has(id):
			var ic: Control = _icons[id]
			if is_instance_valid(ic):
				ic.queue_free()
			_icons.erase(id)
		return
	# Active. Build chip if missing, else update countdown.
	if not _icons.has(id):
		_icons[id] = _build_chip(id)
	var chip: Control = _icons[id]
	if not is_instance_valid(chip):
		_icons.erase(id)
		return
	var pct: float = clamp(remaining / max(max_duration, 0.01), 0.0, 1.0)
	chip.set_meta("pct", pct)
	chip.set_meta("remaining", remaining)
	# Update seconds-remaining label inside the chip
	var sec_lbl: Label = chip.get_node_or_null("SecondsLabel")
	if sec_lbl:
		sec_lbl.text = "%.1f" % remaining if remaining < 10.0 else "%d" % int(remaining)
	chip.queue_redraw()  # repaint the countdown ring

func _build_chip(id: StringName) -> Control:
	var def: Dictionary = _BUFF_DEFS.get(id, {})
	var color: Color = def.get("color", Color(0.85, 0.85, 0.85))
	var glyph: String = String(def.get("glyph", "?"))
	var label: String = String(def.get("label", String(id)))
	# Chip is a Control with custom _draw for the countdown ring + a
	# centered glyph label + a tiny seconds-remaining label below.
	var chip := Control.new()
	chip.custom_minimum_size = ICON_SIZE
	chip.set_meta("color", color)
	chip.tooltip_text = label
	# Background panel with rim color
	var frame := Panel.new()
	frame.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	frame.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var sb := StyleBoxFlat.new()
	sb.bg_color = color.darkened(0.55)
	sb.border_color = color
	sb.set_border_width_all(2)
	sb.set_corner_radius_all(18)  # circular feel
	sb.shadow_color = Color(0, 0, 0, 0.6)
	sb.shadow_size = 4
	sb.shadow_offset = Vector2(0, 2)
	frame.add_theme_stylebox_override("panel", sb)
	chip.add_child(frame)
	# Glyph centered
	var glyph_lbl := Label.new()
	glyph_lbl.text = glyph
	glyph_lbl.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	glyph_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	glyph_lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	glyph_lbl.add_theme_font_size_override("font_size", 18)
	glyph_lbl.add_theme_color_override("font_color", color.lightened(0.55))
	glyph_lbl.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.95))
	glyph_lbl.add_theme_constant_override("outline_size", 3)
	chip.add_child(glyph_lbl)
	# Seconds-remaining label, tiny, bottom of chip
	var sec_lbl := Label.new()
	sec_lbl.name = "SecondsLabel"
	sec_lbl.add_theme_font_size_override("font_size", 9)
	sec_lbl.add_theme_color_override("font_color", Color(1.0, 0.95, 0.65))
	sec_lbl.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.95))
	sec_lbl.add_theme_constant_override("outline_size", 2)
	sec_lbl.anchor_left = 0.0; sec_lbl.anchor_right = 1.0
	sec_lbl.anchor_top = 1.0; sec_lbl.anchor_bottom = 1.0
	sec_lbl.offset_top = -12
	sec_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	chip.add_child(sec_lbl)
	# Override _draw with the countdown ring via a script attached at
	# runtime. Easier: connect to the draw signal from this script.
	chip.draw.connect(_draw_ring.bind(chip))
	_row.add_child(chip)
	return chip

func _draw_ring(chip: Control) -> void:
	# Draw a thick arc on the chip's perimeter that shrinks as the buff
	# expires. Full ring at pct=1.0, empty at pct=0. Gives an at-a-glance
	# read for "how much time is left" without parsing the seconds label.
	var pct: float = float(chip.get_meta("pct", 0.0))
	if pct <= 0.0:
		return
	var color: Color = chip.get_meta("color", Color(0.85, 0.85, 0.85))
	var center: Vector2 = chip.size / 2.0
	var radius: float = chip.size.x / 2.0 - 2.0
	# Draw from -PI/2 (12 o'clock) clockwise. pct=1 -> full circle.
	var start_angle: float = -PI / 2.0
	var end_angle: float = start_angle + TAU * pct
	chip.draw_arc(center, radius, start_angle, end_angle, 32, color, 2.5, true)
