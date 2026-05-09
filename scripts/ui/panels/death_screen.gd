extends CanvasLayer
class_name DeathScreen

# YOU DIED screen. Replaces the old auto-respawn-after-2.5s + camera-replay
# flow with an explicit player choice. Three actions:
#   - Respawn at Lodestone — warps to the most recently attuned lodestone
#   - Wait for Revive — sits with a countdown for a party member to res;
#                       in single-player, falls through to auto-respawn
#                       at REVIVE_TIMEOUT_SECONDS
#   - Quit to Title — change_scene_to_file back to the start menu
#
# Visual: blood-red dripping "YOU DIED" centered, dim red full-screen
# overlay, slow heartbeat fade animation. Heavy. No subtle.

signal respawn_chosen(player: Node)
signal revive_requested(player: Node)
signal quit_chosen()

# Bond's design call — see the Bond Review section below for the trade-off.
const REVIVE_TIMEOUT_SECONDS: float = 60.0
const HEARTBEAT_PERIOD: float = 1.6

var player: Node = null

# Wait-for-Revive state
var _waiting_for_revive: bool = false
var _revive_started_at: float = 0.0
var _revive_timer_label: Label = null

# UI references
@onready var dim: ColorRect = $Dim if has_node("Dim") else null
@onready var content: Control = $Content if has_node("Content") else null

func _ready() -> void:
	visible = false
	process_mode = Node.PROCESS_MODE_ALWAYS

func open(p_player: Node) -> void:
	player = p_player
	visible = true
	get_tree().paused = true
	_waiting_for_revive = false
	_build()

func close() -> void:
	visible = false
	get_tree().paused = false

func _input(event: InputEvent) -> void:
	# Esc on the death screen does NOTHING — death is a commitment moment.
	# The player must pick. (Quit to Title button is the escape hatch.)
	pass

# ───────────────────── Build ─────────────────────

func _build() -> void:
	if not content:
		return
	for c in content.get_children():
		c.queue_free()

	# Title — "YOU DIED" in heavy blood-red, large
	var title := Label.new()
	title.text = "YOU DIED"
	title.add_theme_font_size_override("font_size", 96)
	title.add_theme_color_override("font_color", Color(0.85, 0.05, 0.05))
	title.add_theme_color_override("font_outline_color", Color(0.20, 0.0, 0.0))
	title.add_theme_constant_override("outline_size", 12)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	title.anchor_left = 0.0; title.anchor_right = 1.0
	title.anchor_top = 0.0; title.anchor_bottom = 0.0
	title.offset_top = 120
	title.offset_bottom = 280
	content.add_child(title)
	# Slow heartbeat fade so the title pulses like the player's last
	# heartbeat — sells the moment without animating particles.
	_animate_heartbeat(title)

	# Sub-line — context. The bug-report-style "what killed you."
	var subtitle := Label.new()
	subtitle.text = _killer_subtitle()
	subtitle.add_theme_font_size_override("font_size", 16)
	subtitle.add_theme_color_override("font_color", Color(0.65, 0.20, 0.20, 0.85))
	subtitle.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	subtitle.anchor_left = 0.0; subtitle.anchor_right = 1.0
	subtitle.offset_top = 290
	subtitle.offset_bottom = 320
	content.add_child(subtitle)

	# Buttons stacked center-bottom
	var btns := VBoxContainer.new()
	btns.anchor_left = 0.5; btns.anchor_right = 0.5
	btns.anchor_top = 1.0; btns.anchor_bottom = 1.0
	btns.offset_left = -180
	btns.offset_right = 180
	btns.offset_top = -260
	btns.offset_bottom = -60
	btns.add_theme_constant_override("separation", 14)
	content.add_child(btns)

	btns.add_child(_make_button("Respawn at Last Lodestone", _on_respawn))
	btns.add_child(_make_button("Wait for Revive", _on_wait_for_revive))
	btns.add_child(_make_button("Quit to Title", _on_quit))

func _make_button(text: String, on_press: Callable) -> Button:
	var b := Button.new()
	b.text = text
	b.custom_minimum_size = Vector2(360, 48)
	b.add_theme_font_size_override("font_size", 16)
	b.add_theme_color_override("font_color", Color(0.85, 0.78, 0.55))
	b.add_theme_color_override("font_hover_color", Color(1.0, 0.92, 0.65))
	# Subtle red border that intensifies on hover
	var sb_normal := StyleBoxFlat.new()
	sb_normal.bg_color = Color(0.10, 0.04, 0.04, 0.92)
	sb_normal.border_color = Color(0.55, 0.10, 0.10, 0.85)
	sb_normal.border_width_left = 1; sb_normal.border_width_right = 1
	sb_normal.border_width_top = 1; sb_normal.border_width_bottom = 1
	sb_normal.corner_radius_top_left = 4; sb_normal.corner_radius_top_right = 4
	sb_normal.corner_radius_bottom_left = 4; sb_normal.corner_radius_bottom_right = 4
	b.add_theme_stylebox_override("normal", sb_normal)
	var sb_hover: StyleBoxFlat = sb_normal.duplicate()
	sb_hover.border_color = Color(0.95, 0.20, 0.20, 1.0)
	sb_hover.bg_color = Color(0.14, 0.05, 0.05, 0.95)
	b.add_theme_stylebox_override("hover", sb_hover)
	b.pressed.connect(on_press)
	return b

func _killer_subtitle() -> String:
	if not player:
		return ""
	var src = player.get("_last_damage_source") if player else null
	if src and is_instance_valid(src):
		var name: String = ""
		if "display_name" in src:
			name = String(src.display_name)
		elif "boss_id" in src and src.boss_id != &"":
			name = String(src.boss_id).replace("_", " ").capitalize()
		elif "mob_id" in src and src.mob_id != &"":
			name = String(src.mob_id).replace("_", " ").capitalize()
		if name != "":
			return "Killed by %s" % name
	return ""

# Slow heartbeat: pulse alpha 1.0 → 0.55 → 1.0 over HEARTBEAT_PERIOD.
# Sustains forever while the screen is up — heart's still trying.
func _animate_heartbeat(node: Control) -> void:
	var tw := node.create_tween().set_loops()
	tw.tween_property(node, "modulate:a", 0.55, HEARTBEAT_PERIOD * 0.5).set_trans(Tween.TRANS_SINE)
	tw.tween_property(node, "modulate:a", 1.00, HEARTBEAT_PERIOD * 0.5).set_trans(Tween.TRANS_SINE)

# ───────────────────── Actions ─────────────────────

func _on_respawn() -> void:
	if not player:
		close()
		return
	if player.has_method("_respawn"):
		player._respawn()
	respawn_chosen.emit(player)
	close()

# Wait for revive: a party member's res-skill brings the player back.
# In single-player there's no party, so this becomes a forced-wait timer
# that auto-respawns at REVIVE_TIMEOUT_SECONDS. The player can still
# Quit to Title or click Respawn anytime.
func _on_wait_for_revive() -> void:
	_waiting_for_revive = true
	_revive_started_at = Time.get_ticks_msec() / 1000.0
	revive_requested.emit(player)
	_render_wait_state()

func _render_wait_state() -> void:
	if not content:
		return
	for c in content.get_children():
		c.queue_free()

	var title := Label.new()
	title.text = "AWAITING REVIVE"
	title.add_theme_font_size_override("font_size", 56)
	title.add_theme_color_override("font_color", Color(0.85, 0.20, 0.20))
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.anchor_left = 0.0; title.anchor_right = 1.0
	title.offset_top = 160
	title.offset_bottom = 240
	content.add_child(title)
	_animate_heartbeat(title)

	# Countdown label updates each frame from _process
	_revive_timer_label = Label.new()
	_revive_timer_label.add_theme_font_size_override("font_size", 22)
	_revive_timer_label.add_theme_color_override("font_color", Color(0.85, 0.40, 0.40, 0.85))
	_revive_timer_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_revive_timer_label.anchor_left = 0.0; _revive_timer_label.anchor_right = 1.0
	_revive_timer_label.offset_top = 280
	_revive_timer_label.offset_bottom = 320
	content.add_child(_revive_timer_label)

	# Hint — clarifies the multiplayer-vs-single-player behavior
	var hint := Label.new()
	hint.text = "A party member with a revive ability can bring you back. With no allies near, you will respawn at the last lodestone when the timer expires."
	hint.add_theme_font_size_override("font_size", 13)
	hint.add_theme_color_override("font_color", Color(0.65, 0.45, 0.45, 0.85))
	hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	hint.anchor_left = 0.0; hint.anchor_right = 1.0
	hint.offset_left = 200
	hint.offset_right = -200
	hint.offset_top = 340
	hint.offset_bottom = 410
	content.add_child(hint)

	# Bottom buttons — escape hatches stay
	var btns := VBoxContainer.new()
	btns.anchor_left = 0.5; btns.anchor_right = 0.5
	btns.anchor_top = 1.0; btns.anchor_bottom = 1.0
	btns.offset_left = -180
	btns.offset_right = 180
	btns.offset_top = -200
	btns.offset_bottom = -60
	btns.add_theme_constant_override("separation", 14)
	content.add_child(btns)
	btns.add_child(_make_button("Respawn Now", _on_respawn))
	btns.add_child(_make_button("Quit to Title", _on_quit))

func _process(_delta: float) -> void:
	if not visible or not _waiting_for_revive:
		return
	var now: float = Time.get_ticks_msec() / 1000.0
	var elapsed: float = now - _revive_started_at
	var remaining: float = max(0.0, REVIVE_TIMEOUT_SECONDS - elapsed)
	if _revive_timer_label:
		_revive_timer_label.text = "%d seconds remaining" % int(ceil(remaining))
	if remaining <= 0.0:
		_on_respawn()  # forced respawn at lodestone

func _on_quit() -> void:
	get_tree().paused = false
	quit_chosen.emit()
	close()
	get_tree().change_scene_to_file("res://scenes/menus/start_menu.tscn")

# Public API for party revive — called by an ally's revive ability when
# the rezzer's hitbox overlaps the dead player. Closes the screen and
# resurrects without warping.
func consume_revive() -> bool:
	if not visible or not _waiting_for_revive or not player:
		return false
	# Restore player to half HP at current position
	if player.get("stats") and player.stats:
		player.stats.hp = player.stats.max_hp * 0.5
		if player.has_signal("hp_changed"):
			player.emit_signal("hp_changed", player.stats.hp, player.stats.max_hp)
	if "locked" in player:
		player.locked = false
	close()
	return true
