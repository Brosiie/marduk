extends Control
class_name PlayerCastBar

# Bottom-center cast bar that lights up when the player triggers an
# ability. Mirror of the boss cast bar but anchored above the
# WowAbilityBar slots, so the player's cast feedback sits where the
# eye is already focused (the ability buttons).
#
# Wired to Player.ability_cast_started / ability_cast_finished signals.
# Hidden by default; tween-fades in over 100ms when a cast starts,
# drains the bar over `duration` seconds, fades out over 200ms when
# the cast completes.
#
# Without this widget the player has zero visual feedback when they
# press Q/E/R/F other than the cooldown overlay starting on the slot
# icon — which doesn't tell them WHICH ability fired (any of the 4
# could be on cooldown for unrelated reasons).

const BAR_WIDTH: float = 360.0
const BAR_HEIGHT: float = 14.0
const ROW_HEIGHT: float = 36.0  # label + bar combined

var _player: Node = null
var _label: Label
var _bar: ProgressBar
var _bar_fill_sb: StyleBoxFlat
var _t_remaining: float = 0.0
var _t_total: float = 0.0
var _is_casting: bool = false

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	# Anchor: bottom-center, ~120px above the WowAbilityBar slots.
	# WowAbilityBar sits at offset_top = -64 - 24 = -88 from bottom;
	# we need to be ABOVE that, so offset_top = -88 - ROW_HEIGHT - 8.
	anchor_left = 0.5
	anchor_top = 1.0
	anchor_right = 0.5
	anchor_bottom = 1.0
	offset_left = -BAR_WIDTH * 0.5
	offset_right = BAR_WIDTH * 0.5
	offset_top = -88.0 - ROW_HEIGHT - 12.0
	offset_bottom = -88.0 - 12.0
	visible = false

	_label = Label.new()
	_label.name = "Name"
	_label.add_theme_font_size_override("font_size", 16)
	_label.add_theme_color_override("font_color", Color(1.0, 0.92, 0.55, 1))
	_label.add_theme_color_override("font_outline_color", Color(0.20, 0.05, 0.05, 1.0))
	_label.add_theme_constant_override("outline_size", 4)
	_label.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.85))
	_label.add_theme_constant_override("shadow_offset_x", 1)
	_label.add_theme_constant_override("shadow_offset_y", 2)
	_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_label.set_anchors_and_offsets_preset(Control.PRESET_TOP_WIDE)
	_label.offset_top = -2
	_label.offset_bottom = 22
	add_child(_label)

	_bar = ProgressBar.new()
	_bar.name = "Bar"
	_bar.show_percentage = false
	_bar.max_value = 1.0
	_bar.value = 0.0
	_bar.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_WIDE)
	_bar.offset_top = -BAR_HEIGHT
	_bar.offset_bottom = 0
	# Bar background — dark slate with gold border (HUD language)
	var bg_sb := StyleBoxFlat.new()
	bg_sb.bg_color = Color(0.04, 0.03, 0.07, 0.92)
	bg_sb.border_color = Color(0.78, 0.62, 0.28, 0.95)
	bg_sb.set_border_width_all(1)
	bg_sb.border_width_top = 2
	bg_sb.set_corner_radius_all(4)
	bg_sb.shadow_color = Color(0, 0, 0, 0.55)
	bg_sb.shadow_size = 4
	bg_sb.shadow_offset = Vector2(0, 2)
	_bar.add_theme_stylebox_override("background", bg_sb)
	# Fill — class-color tinted, will adjust per-cast color via the
	# cached stylebox. Default = warm gold.
	_bar_fill_sb = StyleBoxFlat.new()
	_bar_fill_sb.bg_color = Color(1.0, 0.78, 0.32)
	_bar_fill_sb.border_color = Color(1.0, 0.92, 0.55)
	_bar_fill_sb.border_width_top = 2
	_bar_fill_sb.set_corner_radius_all(3)
	_bar.add_theme_stylebox_override("fill", _bar_fill_sb)
	add_child(_bar)

	_attach_signals()

func _attach_signals() -> void:
	_player = get_tree().get_first_node_in_group("player")
	if _player == null:
		get_tree().create_timer(0.2).timeout.connect(_attach_signals)
		return
	if _player.has_signal("ability_cast_started") and not _player.ability_cast_started.is_connected(_on_cast_started):
		_player.ability_cast_started.connect(_on_cast_started)
	if _player.has_signal("ability_cast_finished") and not _player.ability_cast_finished.is_connected(_on_cast_finished):
		_player.ability_cast_finished.connect(_on_cast_finished)

func _on_cast_started(_slot: int, ability_name: String, duration: float) -> void:
	_t_remaining = max(0.05, duration)
	_t_total = _t_remaining
	_label.text = ability_name.to_upper()
	_bar.value = 1.0
	_is_casting = true
	visible = true
	# Fade in
	modulate.a = 0.0
	var tw := create_tween()
	tw.tween_property(self, "modulate:a", 1.0, 0.10)
	# Color the fill based on the player's class buff color so each
	# class has its own cast-bar tint.
	if _player.has_method("_class_buff_color"):
		var c: Color = _player._class_buff_color()
		_bar_fill_sb.bg_color = c
		_bar_fill_sb.border_color = c.lightened(0.4)

func _on_cast_finished(_slot: int) -> void:
	if not _is_casting:
		return
	_is_casting = false
	_t_remaining = 0.0
	# Fade out and hide
	var tw := create_tween()
	tw.tween_property(self, "modulate:a", 0.0, 0.20)
	tw.tween_callback(func():
		if is_instance_valid(self):
			visible = false
	)

func _process(delta: float) -> void:
	if not _is_casting:
		return
	_t_remaining = max(0.0, _t_remaining - delta)
	if _t_total > 0:
		_bar.value = _t_remaining / _t_total
	# Auto-end safety: if the cast_finished signal got dropped (mob
	# death cancellation, scene swap, etc) and we drift past zero,
	# release the bar ourselves.
	if _t_remaining <= 0.0 and _is_casting:
		_on_cast_finished(0)
