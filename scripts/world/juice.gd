extends Node

# Juice, autoload owning the universal "make it feel good" hooks every
# combat / pickup / cutscene system calls into.
#
# API:
#   Juice.hit_stop(duration_seconds: float = 0.06)
#   Juice.shake(magnitude: float, duration: float = 0.25)
#   Juice.slowmo(time_scale: float, duration: float)
#   Juice.flash(color: Color, alpha: float, duration: float = 0.18)
#   Juice.cinematic_kill(target_pos: Vector3, duration: float = 0.6)
#   Juice.toast(text: String, color: Color, duration: float = 2.5)
#
# Internals: stores a CanvasLayer with a single ColorRect for fades, a
# Label for toasts. Camera shake is applied additively to the active
# Camera3D's transform; restored on each tween end.
#
# Why an autoload: every gameplay system needs to fire these at any
# time without coupling to the HUD or scene tree depth. Juice is the
# universal "feel" service.

var _canvas: CanvasLayer
var _flash_rect: ColorRect
var _toast_layer: VBoxContainer
var _shake_active: bool = false
var _shake_baseline_offset: Vector3 = Vector3.ZERO

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS  # so shakes work during paused state
	# Safety: defeat any leftover slowdown from a previous session that
	# crashed mid-hit-stop. Engine.time_scale persists across scene reloads.
	Engine.time_scale = 1.0
	_canvas = CanvasLayer.new()
	_canvas.layer = 100  # above HUD
	add_child(_canvas)
	# Full-screen flash rect (alpha=0 initially)
	_flash_rect = ColorRect.new()
	_flash_rect.color = Color(1, 1, 1, 0)
	_flash_rect.anchor_right = 1.0
	_flash_rect.anchor_bottom = 1.0
	_flash_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_canvas.add_child(_flash_rect)
	# Toast stack (top center)
	_toast_layer = VBoxContainer.new()
	_toast_layer.anchor_left = 0.5
	_toast_layer.anchor_top = 0.0
	_toast_layer.anchor_right = 0.5
	_toast_layer.anchor_bottom = 0.0
	_toast_layer.offset_left = -260.0
	_toast_layer.offset_top = 84.0
	_toast_layer.offset_right = 260.0
	_toast_layer.offset_bottom = 200.0
	_toast_layer.alignment = BoxContainer.ALIGNMENT_BEGIN
	_toast_layer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_canvas.add_child(_toast_layer)

# --- Hit-stop ---
# Briefly freeze the world to give a damage event impact. Used by
# every successful hit; the freeze is short enough that gameplay
# isn't interrupted, but long enough to feel meaty.
func hit_stop(duration: float = 0.06) -> void:
	# Gated on GameSettings.hit_stop. Default is 0.0 (off), slomo on every
	# hit was reported as nauseating during boss fights. Re-enable in
	# Settings → A11y → "Hit-stop intensity" if desired.
	if not _slomo_enabled():
		return
	Engine.time_scale = 0.05
	get_tree().create_timer(duration, false, true).timeout.connect(_restore_time_scale)

func _restore_time_scale() -> void:
	Engine.time_scale = 1.0

# --- Slow-mo ---
# Scaled time for cinematic moments (crit-kills, boss defeats, death
# fade). Different magnitudes for different moments; restores after
# duration.
func slowmo(scale: float = 0.35, duration: float = 0.4) -> void:
	# Same kill-switch as hit_stop, boss arena cinematic + lodestone discovery
	# both call this and the cumulative effect made movement feel weird.
	if not _slomo_enabled():
		return
	Engine.time_scale = scale
	get_tree().create_timer(duration, false, true).timeout.connect(_restore_time_scale)

# Returns true only when the user has explicitly opted in to slomo via
# Settings → A11y → "Hit-stop intensity" (>0 enables).
func _slomo_enabled() -> bool:
	var gs := get_node_or_null("/root/GameSettings")
	if gs == null:
		return false
	return float(gs.hit_stop) > 0.0

# --- Camera shake ---
# Add jitter to the active Camera3D for `duration` seconds. Magnitude
# scales the noise amplitude; 0.05 is subtle, 0.5 is heavy boss slam.
func shake(magnitude: float = 0.15, duration: float = 0.25) -> void:
	var cam: Camera3D = get_viewport().get_camera_3d() if get_viewport() else null
	if cam == null:
		return
	if not _shake_active:
		_shake_baseline_offset = cam.position
		_shake_active = true
	var t: float = 0.0
	var step: float = 1.0 / 60.0
	# Rough timer-driven jitter
	while t < duration:
		var n: Vector3 = Vector3(
			randf_range(-1, 1),
			randf_range(-1, 1),
			randf_range(-1, 1)
		) * magnitude * (1.0 - t / duration)
		cam.position = _shake_baseline_offset + n
		t += step
		await get_tree().create_timer(step, false, true).timeout
	cam.position = _shake_baseline_offset
	_shake_active = false

# --- Screen flash ---
# Color burst over the screen, fades alpha back to 0. Used for
# pickup fanfare (white), crit (yellow), death (red), etc.
func flash(color: Color = Color.WHITE, alpha: float = 0.5, duration: float = 0.18) -> void:
	_flash_rect.color = Color(color.r, color.g, color.b, alpha)
	var tw := create_tween()
	tw.tween_property(_flash_rect, "color:a", 0.0, duration)

# --- Cinematic kill ---
# Combo: hit-stop + slow-mo + camera zoom + screen flash. Used for
# critical kill blows that end a boss / important enemy.
func cinematic_kill(_target_pos: Vector3, duration: float = 0.6) -> void:
	hit_stop(0.10)
	slowmo(0.35, duration)
	shake(0.20, 0.30)
	flash(Color(1.0, 0.95, 0.55), 0.40, 0.30)

# --- Toast banner ---
# Slide-in label at top-center. For region discovery / achievement
# unlock / quest accept-complete events that deserve a moment but
# not a full cutscene.
func toast(text: String, color: Color = Color(0.95, 0.85, 0.30), duration: float = 2.5) -> void:
	var lbl := Label.new()
	lbl.text = text
	lbl.add_theme_font_size_override("font_size", 22)
	lbl.modulate = color
	lbl.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.9))
	lbl.add_theme_constant_override("outline_size", 6)
	lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	# Animate in: slide down + fade in
	lbl.modulate.a = 0.0
	lbl.position.y -= 30.0
	_toast_layer.add_child(lbl)
	var tw_in := create_tween()
	tw_in.set_parallel(true)
	tw_in.tween_property(lbl, "modulate:a", 1.0, 0.30)
	tw_in.tween_property(lbl, "position:y", lbl.position.y + 30.0, 0.30)
	tw_in.set_parallel(false)
	tw_in.tween_interval(duration)
	tw_in.tween_property(lbl, "modulate:a", 0.0, 0.45)
	tw_in.tween_callback(lbl.queue_free)

# Quest milestone banner: a wide gold ribbon that sweeps across the
# upper-third of the screen for accept / complete / turn-in moments.
# Bigger than a toast (toasts stack and read like notifications); the
# ribbon is its own moment with an eyebrow line above the title and
# a reward summary below.
#
# Visual:
#   ┌─────────────── eyebrow (small gold) ───────────────┐
#   │                  TITLE (big, gold)                  │
#   └────────── subtitle (rewards, muted) ───────────────┘
#
# Animates: ribbon slides in from the right, settles for `duration`
# seconds, then sweeps out to the left. Bond's other panels live around
# offset_top 84 (toasts) and 0 (action bar); the ribbon parks at top
# 18% of screen so it doesn't fight either.
func quest_banner(eyebrow: String, title: String, subtitle: String = "",
		color: Color = Color(1.0, 0.85, 0.30), duration: float = 3.5) -> void:
	# Use a PanelContainer with a styled stylebox so the ribbon has a
	# proper backdrop (toasts are bare labels). Anchored top-center.
	var ribbon := PanelContainer.new()
	ribbon.anchor_left = 0.5
	ribbon.anchor_right = 0.5
	ribbon.anchor_top = 0.0
	ribbon.anchor_bottom = 0.0
	ribbon.offset_left = -340.0
	ribbon.offset_right = 340.0
	ribbon.offset_top = 130.0
	ribbon.offset_bottom = 250.0
	ribbon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	# Slate panel with a colored top border (matches the milestone color
	# so a faction-colored quest reads as Crown gold / Druid green / etc).
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.05, 0.04, 0.06, 0.92)
	sb.border_color = color
	sb.border_width_top = 3
	sb.border_width_bottom = 1
	sb.border_width_left = 1
	sb.border_width_right = 1
	sb.set_corner_radius_all(4)
	sb.shadow_color = Color(0, 0, 0, 0.7)
	sb.shadow_size = 10
	sb.shadow_offset = Vector2(0, 4)
	sb.content_margin_left = 30
	sb.content_margin_right = 30
	sb.content_margin_top = 14
	sb.content_margin_bottom = 14
	ribbon.add_theme_stylebox_override("panel", sb)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 4)
	v.alignment = BoxContainer.ALIGNMENT_CENTER
	ribbon.add_child(v)
	# Eyebrow: tiny uppercase tag above the title. Reads as a category
	# marker ("QUEST ACCEPTED", "QUEST COMPLETE", "TURNED IN").
	var eyebrow_lbl := Label.new()
	eyebrow_lbl.text = eyebrow.to_upper()
	eyebrow_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	eyebrow_lbl.add_theme_font_size_override("font_size", 11)
	eyebrow_lbl.add_theme_color_override("font_color", color * 0.85)
	eyebrow_lbl.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.9))
	eyebrow_lbl.add_theme_constant_override("outline_size", 3)
	v.add_child(eyebrow_lbl)
	# Title: the quest name. Large gold.
	var title_lbl := Label.new()
	title_lbl.text = title
	title_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title_lbl.add_theme_font_size_override("font_size", 28)
	title_lbl.add_theme_color_override("font_color", color)
	title_lbl.add_theme_color_override("font_outline_color", Color(0.10, 0.05, 0.05, 0.95))
	title_lbl.add_theme_constant_override("outline_size", 6)
	v.add_child(title_lbl)
	# Subtitle: optional reward / progress summary in muted bronze.
	if subtitle != "":
		var sub_lbl := Label.new()
		sub_lbl.text = subtitle
		sub_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		sub_lbl.add_theme_font_size_override("font_size", 13)
		sub_lbl.add_theme_color_override("font_color", Color(0.85, 0.78, 0.55, 0.85))
		sub_lbl.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.85))
		sub_lbl.add_theme_constant_override("outline_size", 3)
		v.add_child(sub_lbl)
	_canvas.add_child(ribbon)
	# Animate: slide in from the right (offset_left starts at +600 outside
	# screen), settle, then sweep out to the left. Modulate fades on the
	# in/out edges so the slide feels less abrupt.
	var settle_left: float = ribbon.offset_left
	var settle_right: float = ribbon.offset_right
	ribbon.offset_left = settle_left + 600.0
	ribbon.offset_right = settle_right + 600.0
	ribbon.modulate.a = 0.0
	var tw := create_tween()
	tw.set_parallel(true)
	tw.tween_property(ribbon, "offset_left", settle_left, 0.45).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	tw.tween_property(ribbon, "offset_right", settle_right, 0.45).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	tw.tween_property(ribbon, "modulate:a", 1.0, 0.30)
	tw.set_parallel(false)
	tw.tween_interval(duration)
	tw.set_parallel(true)
	tw.tween_property(ribbon, "offset_left", settle_left - 600.0, 0.55).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN)
	tw.tween_property(ribbon, "offset_right", settle_right - 600.0, 0.55).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN)
	tw.tween_property(ribbon, "modulate:a", 0.0, 0.40)
	tw.set_parallel(false)
	tw.tween_callback(ribbon.queue_free)
