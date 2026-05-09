extends Control
class_name BossBar

# Big global boss health bar that appears across the top of the screen when
# a boss aggros, and fades out on boss death or player wipe. One bar at a
# time (multi-boss arenas reuse the bar for the most-recently-engaged boss).
#
# Wired to BossBase signals via the HUD: hud calls `bind_to_boss(boss)` when
# the boss anchor fires its on-engage event.

const BAR_HEIGHT: int = 28
const FRAME_PADDING: int = 8

@onready var _name_label: Label = $Frame/V/Name
@onready var _phase_label: Label = $Frame/V/Phase
@onready var _hp_bar: ProgressBar = $Frame/V/HP
@onready var _posture_bar: ProgressBar = $Frame/V/Posture if has_node("Frame/V/Posture") else null

var _boss: Node = null
# Cast bar children, looked up lazily because they're only built when
# hud.gd._build_boss_bar runs (not in older HUD scenes that pre-date
# the cast bar feature).
var _cast_row: Control = null
var _cast_label: Label = null
var _cast_bar: ProgressBar = null
# Track the previously-shown cast id so we only flash-pulse the cast
# label when a NEW attack starts winding up.
var _last_cast_id: StringName = &""

func _ready() -> void:
	visible = false
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	# Lazy-locate cast-bar children. has_node lookup is cheap and lets
	# the script run on legacy HUDs that don't have the cast-bar layer.
	_cast_row = get_node_or_null("Frame/V/CastRow")
	_cast_label = get_node_or_null("Frame/V/CastRow/CastLabel")
	_cast_bar = get_node_or_null("Frame/V/CastRow/CastBar")
	_posture_bar = get_node_or_null("Frame/V/Posture")

# Public: bind to a BossBase. Hooks into hp_changed-equivalent and
# boss_defeated. Safe to call multiple times: re-binds to the new boss.
func bind_to_boss(boss: Node) -> void:
	_boss = boss
	if boss == null:
		hide_bar()
		return
	visible = true
	_name_label.text = String(boss.get("display_name") if boss.has_method("get") else boss.name)
	_phase_label.text = ""
	_hp_bar.max_value = float(boss.get("max_hp") if boss.has_method("get") else 100.0)
	_hp_bar.value = float(boss.get("hp") if boss.has_method("get") else _hp_bar.max_value)
	# Connect signals
	if boss.has_signal("boss_defeated"):
		if not boss.boss_defeated.is_connected(_on_boss_defeated):
			boss.boss_defeated.connect(_on_boss_defeated)
	# Posture: live-update the gold bar from the boss's `posture` /
	# `max_posture` state. Connect signal if available; otherwise
	# fall through to _process polling (already runs).
	if boss.has_signal("posture_changed") and not boss.posture_changed.is_connected(_on_posture_changed):
		boss.posture_changed.connect(_on_posture_changed)
	# Initialize posture bar
	if _posture_bar:
		var pmax: float = float(boss.get("max_posture") if boss.has_method("get") else 100.0)
		_posture_bar.max_value = max(1.0, pmax)
		_posture_bar.value = float(boss.get("posture") if boss.has_method("get") else 0.0)
	if boss.has_signal("phase_changed"):
		if not boss.phase_changed.is_connected(_on_phase_changed):
			boss.phase_changed.connect(_on_phase_changed)
	if boss.has_signal("died"):
		if not boss.died.is_connected(_on_boss_died_simple):
			boss.died.connect(_on_boss_died_simple)
	# Slide-in tween
	modulate.a = 0.0
	var tw := create_tween()
	tw.tween_property(self, "modulate:a", 1.0, 0.4)

func _process(_delta: float) -> void:
	if _boss == null or not is_instance_valid(_boss):
		return
	# Live-update HP
	var cur: float = float(_boss.get("hp") if _boss.has_method("get") else 0.0)
	var mx: float = float(_boss.get("max_hp") if _boss.has_method("get") else 1.0)
	_hp_bar.max_value = mx
	_hp_bar.value = cur
	# Cast bar: read the boss's pattern AI state and surface the
	# windup attack name + remaining time. Only shown during 'windup';
	# hidden during execute/recovery so the bar is a clean 'incoming'
	# read rather than 'currently mid-attack'.
	_update_cast_bar()

func _update_cast_bar() -> void:
	if _cast_row == null:
		return
	# Defensive double-guard. The parent _process checks is_instance_valid
	# but the boss can be freed between the HP read and this call inside
	# the same frame (queue_free + signal cascade), and `_boss.get(...)`
	# on a freed instance crashes with 'Cannot call get'.
	if _boss == null or not is_instance_valid(_boss):
		_cast_row.visible = false
		return
	var cur_pat = _boss.get("_current_pattern") if "_current_pattern" in _boss else null
	var pat_state = _boss.get("_pattern_state") if "_pattern_state" in _boss else &""
	var pat_until: float = float(_boss.get("_pattern_state_until") if "_pattern_state_until" in _boss else 0.0)
	if cur_pat == null or pat_state != &"windup":
		_cast_row.visible = false
		_last_cast_id = &""
		return
	# Show the cast bar
	_cast_row.visible = true
	var pat_id: StringName = cur_pat.id if "id" in cur_pat else &""
	if pat_id != _last_cast_id:
		# New attack winding up, set the label, snap the bar full, and
		# briefly flash the row alpha for the player to notice.
		_last_cast_id = pat_id
		if _cast_label:
			_cast_label.text = ("⚠  %s  ⚠" % String(cur_pat.display_name)).to_upper()
		# Pulse the row alpha 0 -> 1 over 150ms so the bar SLIDES INTO
		# view rather than blinking on. Smaller cognitive load.
		_cast_row.modulate.a = 0.0
		var tw := create_tween()
		tw.tween_property(_cast_row, "modulate:a", 1.0, 0.15)
	# Drain the cast bar from 1.0 to 0.0 as the windup expires. Ratio
	# is "remaining / total" so the bar EMPTIES, empty == strike lands.
	if _cast_bar:
		var now: float = Time.get_ticks_msec() / 1000.0
		var total: float = max(0.001, float(cur_pat.windup_seconds) if "windup_seconds" in cur_pat else 1.0)
		var remaining: float = max(0.0, pat_until - now)
		_cast_bar.value = clamp(remaining / total, 0.0, 1.0)
		# Color shifts to redder hot as the cast nears completion ,
		# urgency cue. Below 30% remaining = imminent strike.
		var sb: StyleBoxFlat = _cast_bar.get_theme_stylebox("fill") as StyleBoxFlat
		if sb:
			var pct: float = remaining / total
			if pct < 0.30:
				sb.bg_color = Color(1.0, 0.25, 0.10)
				sb.border_color = Color(1.0, 0.55, 0.30)
			else:
				sb.bg_color = Color(1.0, 0.55, 0.18)
				sb.border_color = Color(1.0, 0.78, 0.40)

func hide_bar() -> void:
	var tw := create_tween()
	tw.tween_property(self, "modulate:a", 0.0, 0.5)
	tw.tween_callback(func():
		visible = false
		_boss = null
	)

func _on_posture_changed(cur: float, mx: float) -> void:
	if _posture_bar == null:
		return
	_posture_bar.max_value = max(1.0, mx)
	_posture_bar.value = cur
	# Color shift: when posture is full, the bar flashes white-ish
	# gold so the staggered window reads at a glance.
	var fill_sb: StyleBoxFlat = _posture_bar.get_theme_stylebox("fill") as StyleBoxFlat
	if fill_sb:
		var pct: float = cur / max(1.0, mx)
		if pct >= 0.95:
			fill_sb.bg_color = Color(1.00, 0.95, 0.65)
			fill_sb.border_color = Color(1.0, 1.0, 0.85)
		else:
			fill_sb.bg_color = Color(1.00, 0.78, 0.32)
			fill_sb.border_color = Color(1.00, 0.92, 0.55)

func _on_boss_defeated(_id: StringName, _killer: Node) -> void:
	hide_bar()

func _on_boss_died_simple() -> void:
	hide_bar()

func _on_phase_changed(_idx: int, name: String) -> void:
	_phase_label.text = name
