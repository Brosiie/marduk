extends CanvasLayer
class_name DeathOverlay

# Full-screen "YOU HAVE FALLEN" overlay. Listens for the player's
# `died` signal, fades a dark vignette in over 1.5s, displays the
# headline + killer name + death count, then waits for the respawn.
# When respawn fires, fades back out.
#
# Polish layers:
#   1. Dark blood-red full-screen vignette (matches the low-HP mood)
#   2. "YOU HAVE FALLEN" headline in gold filigree text with crimson
#      outline + drop shadow
#   3. Killer subtitle ("Slain by Enforcer Kazat")
#   4. Death-count footer in small cream text
#   5. Slow ember particles drifting upward (signature funeral mood)
#
# This is spawned ONCE by hud.gd at boot; it stays hidden until the
# player dies. Respawn hides it again.

const FADE_IN_S: float = 1.5
const FADE_OUT_S: float = 0.6
const FALLEN_HOLD_S: float = 2.5

var _root: Control
var _bg: ColorRect
var _headline: Label
var _subtitle: Label
var _footer: Label
var _embers: CPUParticles2D

var _player: Node = null

func _ready() -> void:
	layer = 50  # above HUD, below pause menu
	_build_ui()
	visible = false
	_attach_signals()

func _attach_signals() -> void:
	_player = get_tree().get_first_node_in_group("player")
	if _player == null:
		get_tree().create_timer(0.2).timeout.connect(_attach_signals)
		return
	if _player.has_signal("died") and not _player.died.is_connected(_on_player_died):
		_player.died.connect(_on_player_died)

func _build_ui() -> void:
	_root = Control.new()
	_root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_root.mouse_filter = Control.MOUSE_FILTER_STOP  # block interaction during death
	add_child(_root)
	# Background, deep crimson radial gradient via shader
	_bg = ColorRect.new()
	_bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_bg.color = Color(0.04, 0.02, 0.03, 1.0)
	_bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var shader := Shader.new()
	shader.code = """
shader_type canvas_item;
uniform vec4 inner : source_color = vec4(0.18, 0.04, 0.04, 0.92);
uniform vec4 outer : source_color = vec4(0.02, 0.00, 0.00, 1.0);
void fragment() {
	float d = distance(SCREEN_UV, vec2(0.5));
	// Slow pulse so the screen breathes, not static
	float pulse = 0.55 + 0.04 * sin(TIME * 1.0);
	COLOR = mix(inner, outer, smoothstep(0.0, pulse, d));
}
"""
	var sm := ShaderMaterial.new()
	sm.shader = shader
	_bg.material = sm
	_root.add_child(_bg)
	# Headline
	_headline = Label.new()
	_headline.text = "YOU HAVE FALLEN"
	_headline.add_theme_font_size_override("font_size", 88)
	_headline.add_theme_color_override("font_color", Color(0.95, 0.20, 0.18, 1))
	_headline.add_theme_color_override("font_outline_color", Color(0.10, 0.02, 0.02, 1.0))
	_headline.add_theme_constant_override("outline_size", 12)
	_headline.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.85))
	_headline.add_theme_constant_override("shadow_offset_x", 4)
	_headline.add_theme_constant_override("shadow_offset_y", 6)
	_headline.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_headline.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_headline.anchor_left = 0
	_headline.anchor_top = 0.34
	_headline.anchor_right = 1
	_headline.anchor_bottom = 0.34
	_headline.offset_top = -50
	_headline.offset_bottom = 60
	_root.add_child(_headline)
	# Gold filigree separator under the headline
	var sep := ColorRect.new()
	sep.color = Color(0.78, 0.62, 0.28, 0.55)
	sep.anchor_left = 0.5
	sep.anchor_top = 0.50
	sep.anchor_right = 0.5
	sep.anchor_bottom = 0.50
	sep.offset_left = -180
	sep.offset_right = 180
	sep.offset_top = -1
	sep.offset_bottom = 1
	sep.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.add_child(sep)
	# Subtitle ("slain by ...")
	_subtitle = Label.new()
	_subtitle.text = ""
	_subtitle.add_theme_font_size_override("font_size", 22)
	_subtitle.add_theme_color_override("font_color", Color(0.85, 0.78, 0.55, 1))
	_subtitle.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.85))
	_subtitle.add_theme_constant_override("outline_size", 4)
	_subtitle.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_subtitle.anchor_left = 0
	_subtitle.anchor_top = 0.55
	_subtitle.anchor_right = 1
	_subtitle.anchor_bottom = 0.55
	_subtitle.offset_top = 10
	_subtitle.offset_bottom = 60
	_root.add_child(_subtitle)
	# Footer
	_footer = Label.new()
	_footer.text = "Returning to the lodestone..."
	_footer.add_theme_font_size_override("font_size", 14)
	_footer.add_theme_color_override("font_color", Color(0.65, 0.55, 0.45, 0.85))
	_footer.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.7))
	_footer.add_theme_constant_override("outline_size", 2)
	_footer.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_footer.anchor_left = 0
	_footer.anchor_top = 0.85
	_footer.anchor_right = 1
	_footer.anchor_bottom = 0.85
	_footer.offset_top = -10
	_footer.offset_bottom = 30
	_root.add_child(_footer)
	# Slow ember particles drifting upward (funeral mood)
	_embers = CPUParticles2D.new()
	_embers.amount = 30
	_embers.lifetime = 6.0
	_embers.preprocess = 2.0
	_embers.emission_shape = CPUParticles2D.EMISSION_SHAPE_RECTANGLE
	_embers.emission_rect_extents = Vector2(900, 20)
	_embers.direction = Vector2(0, -1)
	_embers.spread = 25.0
	_embers.initial_velocity_min = 20.0
	_embers.initial_velocity_max = 50.0
	_embers.gravity = Vector2(0, -6)
	_embers.scale_amount_min = 1.5
	_embers.scale_amount_max = 3.5
	_embers.color = Color(0.85, 0.30, 0.18, 0.85)
	_embers.position = Vector2(get_viewport().get_visible_rect().size.x * 0.5, get_viewport().get_visible_rect().size.y - 60)
	_embers.z_index = 5
	_root.add_child(_embers)

func _on_player_died() -> void:
	# Resolve killer name for the subtitle
	var killer_name: String = ""
	if _player and "_last_damage_source" in _player:
		var src = _player.get("_last_damage_source")
		if src and is_instance_valid(src):
			# Bosses set display_name; mobs set mob_id; fall back to scene name
			if "display_name" in src and String(src.get("display_name")) != "":
				killer_name = String(src.get("display_name"))
			elif "mob_id" in src and src.get("mob_id") != &"":
				killer_name = String(src.get("mob_id")).replace("_", " ").capitalize()
			else:
				killer_name = src.name
	if killer_name != "":
		_subtitle.text = "Slain by %s" % killer_name
	else:
		_subtitle.text = ""
	# Show + fade in
	visible = true
	_root.modulate.a = 0.0
	var tw := create_tween()
	tw.tween_property(_root, "modulate:a", 1.0, FADE_IN_S).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	# Wait for the player's _respawn to fire; its 2.5s timer is the
	# right cue for our fade-out. Connect to player's hp_changed via
	# a one-shot to detect respawn (HP back to full).
	if _player and _player.has_signal("hp_changed"):
		var cb := Callable(self, "_on_hp_after_death")
		if not _player.hp_changed.is_connected(cb):
			_player.hp_changed.connect(cb)

func _on_hp_after_death(cur: float, mx: float) -> void:
	# After respawn, HP is restored to full. Use that as our cue to
	# fade back out. Disconnect to avoid re-firing on every HP tick.
	if cur >= mx * 0.99 and visible:
		var tw := create_tween()
		tw.tween_property(_root, "modulate:a", 0.0, FADE_OUT_S)
		tw.tween_callback(func():
			if is_instance_valid(self):
				visible = false
		)
		if _player and _player.has_signal("hp_changed"):
			var cb := Callable(self, "_on_hp_after_death")
			if _player.hp_changed.is_connected(cb):
				_player.hp_changed.disconnect(cb)
