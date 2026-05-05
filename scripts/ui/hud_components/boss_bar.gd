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

var _boss: Node = null

func _ready() -> void:
	visible = false
	mouse_filter = Control.MOUSE_FILTER_IGNORE

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

func hide_bar() -> void:
	var tw := create_tween()
	tw.tween_property(self, "modulate:a", 0.0, 0.5)
	tw.tween_callback(func():
		visible = false
		_boss = null
	)

func _on_boss_defeated(_id: StringName, _killer: Node) -> void:
	hide_bar()

func _on_boss_died_simple() -> void:
	hide_bar()

func _on_phase_changed(_idx: int, name: String) -> void:
	_phase_label.text = name
