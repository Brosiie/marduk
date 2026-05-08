extends CanvasLayer
class_name LoadingScreen

# Aesthetic loading overlay. Shows during the slow first-frame asset
# load (animation .glbs streaming in across deferred frames) and any
# future zone transitions.
#
# Visual: dark purple-black gradient backdrop, MARDUK title in gold
# serif at 88pt, rotating tip text, animated three-dot loader, ember
# particles drifting up. Auto-dismisses on signal `loading_complete`.
#
# Usage:
#   var ls := LoadingScreen.new()
#   add_child(ls)  # CanvasLayer; renders above the world
#   ls.set_subtitle("Sword Without Lord")
#   ls.show_for_seconds(3.0)  OR  ls.hide_now()

const TIPS := [
	"Press Tab to lock onto a target. Strafe-circle as you read their attacks.",
	"Roll INTO an attack to dodge through it. Watch the red ground decals.",
	"Stack hits without taking damage. Each combo stack adds +5% damage.",
	"Press F for your class buff: Battle Cry / Guard / Healing Aura.",
	"Lodestones (V to attune) are your respawn anchor. Their golden beam guides you home.",
	"Storms come at dusk. Rainbows follow rain. The world remembers.",
	"Boss attacks paint the ground before they land. Read the shape, time the dodge.",
	"Sakura petals fall over Sword-Vow Ruins. The grove never knew storms.",
	"Black Citadel knows no light. Storms are eternal there.",
	"In Ashurim plaza, the eight classes meet for the first time.",
	"The Iai Strike. Quick draw. Sword still dropping when the wound opens.",
	"Tiamat sleeps beneath Marduk. She is the world's mother. She wants it back.",
]

@onready var _root: Control
@onready var _title: Label
@onready var _subtitle: Label
@onready var _tip: Label
@onready var _dots: Label
var _progress_bg: ColorRect
var _progress_fill: ColorRect
var _slot_label: Label
var _t: float = 0.0
var _tip_timer: float = 0.0
var _dot_count: int = 1

signal loading_complete

func _ready() -> void:
	layer = 100  # render above gameplay HUD
	_build_ui()
	# Cycle a fresh tip on first frame
	_pick_random_tip()

func _build_ui() -> void:
	_root = Control.new()
	_root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_root.mouse_filter = Control.MOUSE_FILTER_STOP  # block clicks during load
	add_child(_root)
	# Backdrop: deep purple-black with a subtle radial gradient via
	# ColorRect + a soft inner highlight via a smaller centered ColorRect.
	var bg := ColorRect.new()
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	bg.color = Color(0.04, 0.03, 0.07, 1.0)
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.add_child(bg)
	# Animated radial-gradient + film-grain + slow vignette pulse.
	# Old version was a static radial gradient — readable but flat. The
	# new shader pulses the inner color slowly (breathing) and overlays
	# a faint TIME-driven grain so the screen feels ALIVE the entire
	# load. Without this the loading screen reads as a static png.
	var shader := Shader.new()
	shader.code = """
shader_type canvas_item;
uniform vec4 inner : source_color = vec4(0.14, 0.06, 0.20, 1.0);
uniform vec4 outer : source_color = vec4(0.02, 0.01, 0.04, 1.0);
uniform vec4 accent : source_color = vec4(0.55, 0.18, 0.10, 1.0);
void fragment() {
	float d = distance(SCREEN_UV, vec2(0.5));
	// Slow breathing on the inner glow size — makes the corona pulse
	// over a 4s cycle. 0.5 * sin = +/- 0.5 amplitude around 0.85 base.
	float pulse = 0.85 + 0.06 * sin(TIME * 1.6);
	vec4 base = mix(inner, outer, smoothstep(0.0, pulse, d));
	// Crimson accent at the outer ring so the screen edges glow
	// red — frames Tiamat's heart-of-the-world theme.
	float ring = smoothstep(0.55, 0.95, d) * (1.0 - smoothstep(0.95, 1.20, d));
	base.rgb += accent.rgb * ring * 0.18;
	// Per-pixel grain. screen_uv * 1024 and fract gives a deterministic
	// noise-per-pixel that shifts via TIME — stops banding from showing.
	float grain = fract(sin(dot(SCREEN_UV * 1024.0 + TIME * 0.7, vec2(12.9898, 78.233))) * 43758.5453);
	base.rgb += (grain - 0.5) * 0.025;
	COLOR = base;
}
"""
	var bg_mat := ShaderMaterial.new()
	bg_mat.shader = shader
	bg.material = bg_mat

	# Title MARDUK at 88pt gold serif
	_title = Label.new()
	_title.text = "MARDUK"
	_title.add_theme_font_size_override("font_size", 88)
	_title.modulate = Color(1.00, 0.85, 0.45)
	_title.add_theme_color_override("font_outline_color", Color(0.0, 0.0, 0.0, 0.8))
	_title.add_theme_constant_override("outline_size", 8)
	_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_title.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_title.anchor_left = 0.0
	_title.anchor_top = 0.30
	_title.anchor_right = 1.0
	_title.anchor_bottom = 0.30
	_title.offset_top = -50.0
	_title.offset_bottom = 60.0
	_root.add_child(_title)

	# Subtitle: optional class / quest text
	_subtitle = Label.new()
	_subtitle.text = "An ARPG Forged in the Heart of Tiamat"
	_subtitle.add_theme_font_size_override("font_size", 18)
	_subtitle.modulate = Color(0.75, 0.65, 0.50)
	_subtitle.add_theme_color_override("font_outline_color", Color(0.0, 0.0, 0.0, 0.7))
	_subtitle.add_theme_constant_override("outline_size", 3)
	_subtitle.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_subtitle.anchor_left = 0.0
	_subtitle.anchor_top = 0.42
	_subtitle.anchor_right = 1.0
	_subtitle.anchor_bottom = 0.42
	_subtitle.offset_top = 0
	_subtitle.offset_bottom = 30
	_root.add_child(_subtitle)

	# Decorative line under subtitle
	var line := ColorRect.new()
	line.color = Color(1.00, 0.85, 0.45, 0.4)
	line.anchor_left = 0.5
	line.anchor_top = 0.50
	line.anchor_right = 0.5
	line.anchor_bottom = 0.50
	line.offset_left = -120.0
	line.offset_right = 120.0
	line.offset_top = -1.0
	line.offset_bottom = 1.0
	line.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.add_child(line)

	# Tip text near bottom
	_tip = Label.new()
	_tip.add_theme_font_size_override("font_size", 14)
	_tip.modulate = Color(0.85, 0.80, 0.70)
	_tip.add_theme_color_override("font_outline_color", Color(0.0, 0.0, 0.0, 0.7))
	_tip.add_theme_constant_override("outline_size", 2)
	_tip.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_tip.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_tip.anchor_left = 0.5
	_tip.anchor_top = 0.78
	_tip.anchor_right = 0.5
	_tip.anchor_bottom = 0.78
	_tip.offset_left = -380
	_tip.offset_right = 380
	_tip.offset_top = -40
	_tip.offset_bottom = 40
	_root.add_child(_tip)

	# Progress bar — beefier (8px tall, 480px wide) with a gold inset
	# frame, dark recessed bg, and a moving shimmer overlay on the fill
	# so the bar reads as 'energetically loading' rather than 'static
	# orange rectangle'.
	_progress_bg = ColorRect.new()
	_progress_bg.color = Color(0.06, 0.04, 0.10, 0.92)
	_progress_bg.anchor_left = 0.5
	_progress_bg.anchor_top = 0.86
	_progress_bg.anchor_right = 0.5
	_progress_bg.anchor_bottom = 0.86
	_progress_bg.offset_left = -240
	_progress_bg.offset_right = 240
	_progress_bg.offset_top = -6
	_progress_bg.offset_bottom = 6
	_progress_bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	# Gold filigree border via a child Panel underneath the ColorRect
	# so the bar gets the same frame language as the in-game HUD bars.
	var bar_frame := Panel.new()
	bar_frame.anchor_left = 0.0
	bar_frame.anchor_top = 0.0
	bar_frame.anchor_right = 1.0
	bar_frame.anchor_bottom = 1.0
	bar_frame.offset_left = -2
	bar_frame.offset_top = -2
	bar_frame.offset_right = 2
	bar_frame.offset_bottom = 2
	bar_frame.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var frame_sb := StyleBoxFlat.new()
	frame_sb.bg_color = Color(0, 0, 0, 0)  # transparent — we just want the border
	frame_sb.border_color = Color(0.78, 0.62, 0.28, 0.95)
	frame_sb.set_border_width_all(1)
	frame_sb.set_corner_radius_all(4)
	frame_sb.shadow_color = Color(0, 0, 0, 0.55)
	frame_sb.shadow_size = 4
	bar_frame.add_theme_stylebox_override("panel", frame_sb)
	_root.add_child(_progress_bg)
	_progress_bg.add_child(bar_frame)
	_progress_fill = ColorRect.new()
	_progress_fill.color = Color(1.0, 0.78, 0.32, 0.95)
	_progress_fill.anchor_left = 0.0
	_progress_fill.anchor_top = 0.0
	_progress_fill.anchor_right = 0.0  # animated to 1.0 as load progresses
	_progress_fill.anchor_bottom = 1.0
	_progress_fill.mouse_filter = Control.MOUSE_FILTER_IGNORE
	# Moving shimmer band — a brighter strip slides left-to-right across
	# the fill via a ShaderMaterial. Tells the player the load is
	# THINKING, not stuck.
	var shimmer_shader := Shader.new()
	shimmer_shader.code = """
shader_type canvas_item;
void fragment() {
	float band = smoothstep(0.0, 0.10, abs(fract(SCREEN_UV.x * 0.18 - TIME * 0.30) - 0.5));
	float gloss = (1.0 - band) * 0.55;
	vec3 base = vec3(1.0, 0.78, 0.32);
	vec3 hot = vec3(1.0, 0.98, 0.78);
	COLOR = vec4(mix(base, hot, gloss), 0.95);
}
"""
	var shimmer_mat := ShaderMaterial.new()
	shimmer_mat.shader = shimmer_shader
	_progress_fill.material = shimmer_mat
	_progress_bg.add_child(_progress_fill)

	# Slot-name label below the progress bar (reads what's loading)
	_slot_label = Label.new()
	_slot_label.text = "preparing..."
	_slot_label.add_theme_font_size_override("font_size", 11)
	_slot_label.modulate = Color(0.65, 0.60, 0.55)
	_slot_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_slot_label.anchor_left = 0.0
	_slot_label.anchor_top = 0.89
	_slot_label.anchor_right = 1.0
	_slot_label.anchor_bottom = 0.89
	_slot_label.offset_top = -8
	_slot_label.offset_bottom = 12
	_root.add_child(_slot_label)

	# Animated dot loader at very bottom
	_dots = Label.new()
	_dots.text = "."
	_dots.add_theme_font_size_override("font_size", 32)
	_dots.modulate = Color(1.00, 0.85, 0.45)
	_dots.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_dots.anchor_left = 0.0
	_dots.anchor_top = 0.93
	_dots.anchor_right = 1.0
	_dots.anchor_bottom = 0.93
	_dots.offset_top = -10
	_dots.offset_bottom = 30
	_root.add_child(_dots)

	# Ember particles drifting upward as flavor
	_spawn_embers()

func _spawn_embers() -> void:
	# CPUParticles2D is Node2D so we host it inside a positioned
	# container. Read viewport size to place the emitter at the
	# bottom-center of screen.
	var vp_size: Vector2 = get_viewport().get_visible_rect().size
	var p := CPUParticles2D.new()
	p.amount = 60
	p.lifetime = 5.0
	p.preprocess = 2.0
	p.emission_shape = CPUParticles2D.EMISSION_SHAPE_RECTANGLE
	p.emission_rect_extents = Vector2(900, 20)
	p.direction = Vector2(0, -1)
	p.spread = 25.0
	p.initial_velocity_min = 30.0
	p.initial_velocity_max = 60.0
	p.gravity = Vector2(0, -8)
	p.scale_amount_min = 1.0
	p.scale_amount_max = 3.0
	p.color = Color(1.00, 0.55, 0.20, 0.85)
	# Bottom-center of viewport, slightly above the very edge
	p.position = Vector2(vp_size.x * 0.5, vp_size.y - 50.0)
	p.z_index = 5
	_root.add_child(p)

func _process(delta: float) -> void:
	_t += delta
	# Title pulses subtly: alpha 0.85 -> 1.0 over 2s sin
	if _title:
		var pulse: float = 0.85 + 0.15 * (sin(_t * 1.4) * 0.5 + 0.5)
		_title.modulate.a = pulse
	# Three-dot loader: . -> .. -> ... cycling every 0.4s
	if _dots:
		var tick := int(_t / 0.4) % 3 + 1
		if tick != _dot_count:
			_dot_count = tick
			_dots.text = ".".repeat(tick)
	# Tip rotates every 5 seconds
	_tip_timer += delta
	if _tip_timer > 5.0:
		_tip_timer = 0.0
		_pick_random_tip()

func _pick_random_tip() -> void:
	if _tip == null:
		return
	_tip.text = TIPS[randi() % TIPS.size()]

# Optional subtitle override (e.g. show class intro title during prologue load)
func set_subtitle(text: String) -> void:
	if _subtitle:
		_subtitle.text = text

# Connected to AnimationLibraryLoader.slot_loaded signal so the bar
# fills as slots stream in. current/total drive width; slot_name shows
# under the bar so the player can see WHICH animation is loading.
func on_anim_progress(current: int, total: int, slot_name: String) -> void:
	if _progress_fill == null or total <= 0:
		return
	var pct: float = float(current) / float(total)
	_progress_fill.anchor_right = pct
	if _slot_label:
		_slot_label.text = "binding %s  (%d / %d)" % [slot_name, current, total]

# Public API: dismiss with a fade-out. CanvasLayer has no modulate
# property so we fade the inner Control instead.
func hide_now(fade_seconds: float = 0.6) -> void:
	if _root == null or not is_instance_valid(_root):
		loading_complete.emit()
		queue_free()
		return
	var tw := create_tween()
	tw.tween_property(_root, "modulate:a", 0.0, fade_seconds)
	tw.tween_callback(func():
		loading_complete.emit()
		queue_free()
	)
