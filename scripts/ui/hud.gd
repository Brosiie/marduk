extends CanvasLayer
class_name HUD

# Minimal HUD: HP bar, mana bar, XP bar, level, ability cooldowns.

@export var player_path: NodePath

@onready var hp_bar: ProgressBar = $Root/Bars/HPBar
@onready var mana_bar: ProgressBar = $Root/Bars/ManaBar
@onready var xp_bar: ProgressBar = $Root/Bars/XPBar
@onready var level_label: Label = $Root/Bars/LevelLabel
@onready var resource_label: Label = $Root/Bars/ResourceLabel if has_node("Root/Bars/ResourceLabel") else null
@onready var prestige_badge: Label = $Root/Bars/PrestigeBadge if has_node("Root/Bars/PrestigeBadge") else null
@onready var ascend_prompt: Label = $Root/AscendPrompt if has_node("Root/AscendPrompt") else null

# Color and label per resource mechanic so the bar feels right per class.
const RESOURCE_THEME := {
	&"mana":        { "color": Color(0.4, 0.6, 1.0), "label": "MP" },
	&"stamina":     { "color": Color(0.85, 0.85, 0.45), "label": "STA" },
	&"rage":        { "color": Color(0.9, 0.2, 0.2), "label": "RAGE" },
	&"focus":       { "color": Color(0.9, 0.85, 0.3), "label": "FOCUS" },
	&"stance":      { "color": Color(0.7, 0.7, 0.85), "label": "STANCE" },
	&"corruption":  { "color": Color(0.5, 0.0, 0.6), "label": "CORRUPT" },
	&"form_energy": { "color": Color(0.3, 0.85, 0.45), "label": "WILD" },
	&"blood":       { "color": Color(0.65, 0.05, 0.10), "label": "BLOOD" },
}

var player: Player

var menu_panel: Control = null
var boss_bar: Control = null
# Low-HP vignette: a screen-filling ColorRect with a radial gradient
# shader. Alpha lerps in based on how low HP is, so the screen turns
# bloodier as the player edges toward death. Common ARPG juice.
var _low_hp_vignette: ColorRect = null
# Combo counter: small label that pops on the right-center showing
# 'x12 COMBO!' as hits stack. Fades when combo resets.
var _combo_label: Label = null

func _ready() -> void:
	add_to_group("hud")
	player = get_node_or_null(player_path) if player_path else get_tree().get_first_node_in_group("player")
	if not player:
		push_warning("HUD: no player found")
		return
	_install_low_hp_vignette()
	_install_combo_label()
	_polish_bars()
	player.hp_changed.connect(_on_hp)
	player.mana_changed.connect(_on_mana)
	player.resource_changed.connect(_on_resource)
	if player.has_signal("combo_changed"):
		player.combo_changed.connect(_on_combo_changed)
	if player.stats:
		player.stats.leveled_up.connect(_on_level_up)
		player.stats.max_level_reached.connect(_on_max_level)
		_refresh_all()
		_apply_resource_theme()
		_apply_prestige_badge()
	# Spawn the tabbed full-screen menu shell. It's invisible until a hotkey
	# brings it up.
	var menu_script: GDScript = load("res://scripts/ui/menu_panel.gd")
	if menu_script:
		menu_panel = Control.new()
		menu_panel.set_script(menu_script)
		menu_panel.name = "MenuPanel"
		add_child(menu_panel)
	# Boss bar — built procedurally so we don't need a separate .tscn.
	boss_bar = _build_boss_bar()
	$Root.add_child(boss_bar)
	# WoW-style ability bar (bottom center)
	var ab_script: GDScript = load("res://scripts/ui/hud_components/wow_ability_bar.gd")
	if ab_script:
		var ability_bar := Control.new()
		ability_bar.set_script(ab_script)
		ability_bar.name = "WowAbilityBar"
		$Root.add_child(ability_bar)
	# WoW-style minimap (top right)
	var mm_script: GDScript = load("res://scripts/ui/hud_components/wow_minimap.gd")
	if mm_script:
		var minimap := Control.new()
		minimap.set_script(mm_script)
		minimap.name = "WowMinimap"
		$Root.add_child(minimap)
	# Quest tracker (top left, under bars)
	var qt_script: GDScript = load("res://scripts/ui/hud_components/quest_tracker.gd")
	if qt_script:
		var qt := Control.new()
		qt.set_script(qt_script)
		qt.name = "QuestTracker"
		$Root.add_child(qt)
	# Combat log (bottom left, above ability bar)
	var cl_script: GDScript = load("res://scripts/ui/hud_components/combat_log.gd")
	if cl_script:
		var cl := Control.new()
		cl.set_script(cl_script)
		cl.name = "CombatLog"
		$Root.add_child(cl)
	# Bottom-right action bar — visible buttons for the menu tabs so new
	# players can find inventory / settings / friends without memorizing
	# hotkeys.
	var ab2_script: GDScript = load("res://scripts/ui/hud_components/action_bar.gd")
	if ab2_script:
		var action_bar := Control.new()
		action_bar.set_script(ab2_script)
		action_bar.name = "ActionBar"
		$Root.add_child(action_bar)
	# Toast container for pickup notifications
	_setup_toast_layer()
	if player.has_signal("item_collected"):
		player.item_collected.connect(_on_item_collected)

func _process(_delta: float) -> void:
	if player and player.stats:
		var need := float(player.stats.xp_to_next_level())
		xp_bar.max_value = max(1.0, need)
		xp_bar.value = player.stats.xp

func _refresh_all() -> void:
	if not player or not player.stats:
		return
	hp_bar.max_value = player.stats.max_hp
	hp_bar.value = player.stats.hp
	mana_bar.max_value = player.stats.max_mana
	mana_bar.value = player.stats.mana
	var lvl_text := "Lv %d" % player.stats.level
	if player.stats.level >= PlayerStats.MAX_LEVEL:
		lvl_text += " MAX"
	level_label.text = lvl_text

func _apply_prestige_badge() -> void:
	if not prestige_badge:
		return
	var p := get_tree().root.get_node_or_null("Prestige")
	if not p:
		prestige_badge.visible = false
		return
	var pl: int = p.current_prestige_level()
	if pl <= 0:
		prestige_badge.visible = false
	else:
		prestige_badge.visible = true
		prestige_badge.text = "Cycle %d" % pl

func _on_max_level() -> void:
	if ascend_prompt:
		ascend_prompt.visible = true
		ascend_prompt.text = "MAX LEVEL REACHED. Press [P] to begin a new cycle."
	_refresh_all()

func _unhandled_input(event: InputEvent) -> void:
	# Tabbed menu hotkeys. Each routes through MenuPanel.toggle_tab so press-
	# again closes the panel and switching tabs is one keypress.
	if not (event is InputEventKey) or not event.pressed:
		return
	if menu_panel == null:
		return
	if event.is_action_pressed("toggle_inventory"):
		menu_panel.toggle_tab(&"inventory")
	elif event.is_action_pressed("toggle_character"):
		menu_panel.toggle_tab(&"character")
	elif event.is_action_pressed("toggle_skills"):
		menu_panel.toggle_tab(&"skills")
	elif event.is_action_pressed("toggle_map"):
		menu_panel.toggle_tab(&"map")
	elif event.is_action_pressed("toggle_quests"):
		menu_panel.toggle_tab(&"quests")
	elif event.is_action_pressed("toggle_achievements"):
		menu_panel.toggle_tab(&"achievements")
	elif event.is_action_pressed("toggle_codex"):
		menu_panel.toggle_tab(&"codex")
	elif event.is_action_pressed("toggle_pause"):
		menu_panel.toggle_tab(&"options")

func _on_hp(cur: float, mx: float) -> void:
	hp_bar.max_value = mx
	hp_bar.value = cur
	_refresh_value_label(hp_bar, "hp")
	# Low-HP vignette: kicks in below 40% max HP, ramps to full opacity
	# at 0% (just before death). Pulses slightly via shader's _process so
	# the screen breathes red.
	if _low_hp_vignette and _low_hp_vignette.material:
		var hp_pct: float = cur / max(mx, 1.0)
		var threshold: float = 0.40
		var t: float = clamp((threshold - hp_pct) / threshold, 0.0, 1.0)  # 0 at 40%+, 1 at 0%
		(_low_hp_vignette.material as ShaderMaterial).set_shader_parameter("intensity", t)

func _install_low_hp_vignette() -> void:
	# Full-screen ColorRect with a radial-gradient shader. The shader is
	# inline so we don't ship an extra .gdshader file just for one effect.
	# Black at center, deep red at edges, alpha controlled by `intensity`.
	var shader := Shader.new()
	shader.code = """
shader_type canvas_item;
uniform float intensity : hint_range(0.0, 1.0) = 0.0;
uniform vec4 vignette_color : source_color = vec4(0.7, 0.05, 0.05, 1.0);

void fragment() {
	// SCREEN_UV is 0..1, distance from center
	float d = distance(SCREEN_UV, vec2(0.5));
	// Inner radius is fully clear; outer ring is the red. 0.35-0.75 range.
	float vignette = smoothstep(0.35, 0.75, d);
	// Subtle pulse so it 'breathes' at low HP
	float pulse = 0.85 + 0.15 * sin(TIME * 4.0);
	float a = vignette * intensity * pulse;
	COLOR = vec4(vignette_color.rgb, a);
}
"""
	var mat := ShaderMaterial.new()
	mat.shader = shader
	mat.set_shader_parameter("intensity", 0.0)
	_low_hp_vignette = ColorRect.new()
	_low_hp_vignette.name = "LowHPVignette"
	_low_hp_vignette.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_low_hp_vignette.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_low_hp_vignette.material = mat
	# Add as a child of the HUD so it renders above the world. Goes BEFORE
	# bars/menus so they stay readable through the vignette.
	add_child(_low_hp_vignette)
	move_child(_low_hp_vignette, 0)  # behind UI children

# Polish the three top-left bars with proper StyleBoxFlat overrides
# (dark inset frame, gradient fill, gold border) instead of bare
# ProgressBars with just a `modulate` tint.
func _polish_bars() -> void:
	# Remove the modulate color tints set in the .tscn -- the styleboxes
	# below paint the actual fill color, modulate would double-tint them.
	if hp_bar:
		hp_bar.modulate = Color.WHITE
		_apply_bar_style(hp_bar, Color(0.85, 0.18, 0.20), Color(1.00, 0.45, 0.45), Color(0.55, 0.10, 0.12))
		_attach_value_label(hp_bar, "%d / %d", "hp")
	if mana_bar:
		mana_bar.modulate = Color.WHITE
		_apply_bar_style(mana_bar, Color(0.30, 0.55, 1.00), Color(0.55, 0.78, 1.0), Color(0.15, 0.30, 0.65))
		_attach_value_label(mana_bar, "%d / %d", "mana")
	if xp_bar:
		xp_bar.modulate = Color.WHITE
		_apply_bar_style(xp_bar, Color(1.0, 0.78, 0.30), Color(1.0, 0.92, 0.55), Color(0.55, 0.40, 0.10))
	if level_label:
		level_label.add_theme_color_override("font_color", Color(1.0, 0.92, 0.55))
		level_label.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.85))
		level_label.add_theme_constant_override("outline_size", 4)
		level_label.add_theme_font_size_override("font_size", 22)

func _apply_bar_style(bar: ProgressBar, mid: Color, light: Color, dark: Color) -> void:
	# Background: dark inset with gold border
	var sb_bg := StyleBoxFlat.new()
	sb_bg.bg_color = Color(0.04, 0.03, 0.07, 0.92)
	sb_bg.border_color = Color(0.45, 0.32, 0.15, 0.95)
	sb_bg.set_border_width_all(1)
	sb_bg.set_corner_radius_all(4)
	# Subtle inner shadow on top edge for depth
	sb_bg.shadow_color = Color(0, 0, 0, 0.5)
	sb_bg.shadow_size = 2
	sb_bg.shadow_offset = Vector2(0, 1)
	bar.add_theme_stylebox_override("background", sb_bg)
	# Fill: gradient via shader_material would be ideal but a flat
	# saturated fill + thin highlight strip is good enough at small
	# bar heights.
	var sb_fg := StyleBoxFlat.new()
	sb_fg.bg_color = mid
	sb_fg.border_color = light
	sb_fg.border_width_top = 2  # bright top edge for the gradient illusion
	sb_fg.set_corner_radius_all(3)
	# Slight glow on the fill so the bar pops against the dark bg
	sb_fg.shadow_color = mid * 0.5
	sb_fg.shadow_size = 0
	bar.add_theme_stylebox_override("fill", sb_fg)
	# Hide the default percentage text; we'll attach our own value label
	bar.show_percentage = false

# Floating value label inside the bar showing 'HP / max'. The label
# refreshes in _on_hp / _on_mana via _refresh_value_label.
func _attach_value_label(bar: ProgressBar, fmt: String, kind: String) -> void:
	var lbl := Label.new()
	lbl.name = "ValueLabel"
	lbl.set_meta("fmt", fmt)
	lbl.set_meta("kind", kind)
	lbl.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	# 13pt is the WoW-standard bar value size; 11pt was 55% of bar
	# height and squint-illegible on dark mid-fill segments.
	lbl.add_theme_font_size_override("font_size", 13)
	lbl.add_theme_color_override("font_color", Color(1, 1, 1, 0.97))
	lbl.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.95))
	lbl.add_theme_constant_override("outline_size", 4)
	# Drop shadow so the text reads on light fill colors (Stamina yellow,
	# Holy gold) without losing punch on dark fills (Shadow purple).
	lbl.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.75))
	lbl.add_theme_constant_override("shadow_offset_x", 1)
	lbl.add_theme_constant_override("shadow_offset_y", 1)
	lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	bar.add_child(lbl)
	_refresh_value_label(bar, kind)

func _refresh_value_label(bar: ProgressBar, kind: String) -> void:
	var lbl := bar.get_node_or_null("ValueLabel") as Label
	if lbl == null:
		return
	lbl.text = "%d / %d" % [int(bar.value), int(bar.max_value)]

# Combo HUD widget: anchored right-center, font scales with stack count.
# Color crossfades from white -> yellow -> orange -> red as the combo
# climbs, so the player feels the climb visually.
func _install_combo_label() -> void:
	_combo_label = Label.new()
	_combo_label.name = "ComboLabel"
	_combo_label.anchor_left = 1.0
	_combo_label.anchor_top = 0.5
	_combo_label.anchor_right = 1.0
	_combo_label.anchor_bottom = 0.5
	_combo_label.offset_left = -260.0
	_combo_label.offset_top = -36.0
	_combo_label.offset_right = -20.0
	_combo_label.offset_bottom = 36.0
	_combo_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_combo_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_combo_label.add_theme_font_size_override("font_size", 28)
	_combo_label.modulate = Color(1, 1, 1, 0)
	$Root.add_child(_combo_label)

func _on_combo_changed(stacks: int, max_stacks: int) -> void:
	if _combo_label == null:
		return
	if stacks <= 1:
		# Fade out
		var tw_out := _combo_label.create_tween()
		tw_out.tween_property(_combo_label, "modulate:a", 0.0, 0.35)
		return
	# Color climb: white -> yellow -> orange -> red as stacks rise
	var t: float = clamp(float(stacks) / float(max_stacks), 0.0, 1.0)
	var col: Color
	if t < 0.33:
		col = Color(1.0, 1.0, 1.0).lerp(Color(1.0, 0.92, 0.45), t / 0.33)
	elif t < 0.66:
		col = Color(1.0, 0.92, 0.45).lerp(Color(1.0, 0.55, 0.20), (t - 0.33) / 0.33)
	else:
		col = Color(1.0, 0.55, 0.20).lerp(Color(1.0, 0.20, 0.20), (t - 0.66) / 0.34)
	col.a = 1.0
	_combo_label.text = "x%d  COMBO" % stacks
	_combo_label.add_theme_font_size_override("font_size", 24 + int(t * 28))  # 24..52 pt
	_combo_label.modulate = col
	# Pop scale: brief 1.2x then back to 1.0
	_combo_label.scale = Vector2(1.2, 1.2)
	var tw := _combo_label.create_tween()
	tw.tween_property(_combo_label, "scale", Vector2.ONE, 0.18)

func _on_mana(cur: float, mx: float) -> void:
	mana_bar.max_value = mx
	mana_bar.value = cur

func _on_level_up(lvl: int) -> void:
	_refresh_all()
	# Cinematic: gold particle column rising from the player + screen
	# flash + toast banner. The player should FEEL the level-up.
	if player:
		_spawn_levelup_column(player)
	var juice: Node = get_node_or_null("/root/Juice")
	if juice:
		if juice.has_method("flash"):
			juice.flash(Color(1.0, 0.92, 0.50), 0.20, 0.50)
		if juice.has_method("toast"):
			juice.toast("LEVEL %d" % lvl, Color(1.0, 0.92, 0.50), 2.5)
	# Level-up arpeggio (existing audio cue)
	var ab = get_node_or_null("/root/AudioBus")
	if ab and ab.has_method("play_cue") and player:
		ab.play_cue(&"level_up", player.global_position, -3.0, 1.0)
	# Level milestone achievements
	var ar = get_node_or_null("/root/AchievementRegistry")
	if ar and ar.has_method("unlock"):
		if lvl >= 5:
			ar.unlock(&"a_level_5")
		if lvl >= 10:
			ar.unlock(&"a_level_10")

func _spawn_levelup_column(at_player: Node3D) -> void:
	var p := GPUParticles3D.new()
	p.name = "LevelUpColumn"
	p.amount = 120
	p.lifetime = 1.8
	p.one_shot = true
	p.explosiveness = 0.40  # staggered burst, looks like rising glow
	p.visibility_aabb = AABB(Vector3(-1.5, 0, -1.5), Vector3(3, 5, 3))
	var mat := ParticleProcessMaterial.new()
	mat.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_RING
	mat.emission_ring_radius = 0.7
	mat.emission_ring_inner_radius = 0.3
	mat.emission_ring_axis = Vector3.UP
	mat.emission_ring_height = 0.10
	mat.direction = Vector3.UP
	mat.spread = 6.0
	mat.initial_velocity_min = 3.5
	mat.initial_velocity_max = 5.0
	mat.gravity = Vector3.ZERO
	mat.scale_min = 0.10
	mat.scale_max = 0.22
	mat.color = Color(1.0, 0.88, 0.45, 0.95)
	mat.tangential_accel_min = 0.5
	mat.tangential_accel_max = 1.5
	p.process_material = mat
	var quad := QuadMesh.new()
	quad.size = Vector2(0.18, 0.18)
	var smat := StandardMaterial3D.new()
	smat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	smat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	smat.albedo_color = Color(1.0, 0.88, 0.45, 0.95)
	smat.emission_enabled = true
	smat.emission = Color(1.0, 0.88, 0.45)
	smat.emission_energy_multiplier = 1.8
	smat.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
	smat.billboard_keep_scale = true
	quad.material = smat
	p.draw_pass_1 = quad
	# Parent under current scene + position at player feet so the column
	# rises through the player as the upgrade lands.
	var scene := at_player.get_tree().current_scene
	scene.add_child(p)
	p.global_position = at_player.global_position
	get_tree().create_timer(2.5).timeout.connect(func(): if is_instance_valid(p): p.queue_free())

func _on_resource(cur: float, mx: float, _mech: StringName) -> void:
	mana_bar.max_value = max(1.0, mx)
	mana_bar.value = cur

func _apply_resource_theme() -> void:
	if not player or not player.stats or not player.stats.class_def:
		return
	var mech: StringName = player.stats.class_def.resource_mechanic
	var theme: Dictionary = RESOURCE_THEME.get(mech, RESOURCE_THEME[&"mana"])
	# Update the StyleBoxFlat fill directly. Setting `modulate` on top of
	# the polished bar would multiply with the stylebox bg_color and
	# double-tint the fill (Stamina ended up green-on-green, etc).
	mana_bar.modulate = Color.WHITE
	var fill_color: Color = theme["color"]
	var sb: StyleBoxFlat = mana_bar.get_theme_stylebox("fill") as StyleBoxFlat
	if sb:
		sb.bg_color = fill_color
		sb.border_color = fill_color.lightened(0.4)
		sb.shadow_color = fill_color * 0.5
	else:
		_apply_bar_style(mana_bar, fill_color, fill_color.lightened(0.3), fill_color.darkened(0.5))
	if resource_label:
		resource_label.text = theme["label"]

# --- Pickup toasts ---
# A small VBox stacked top-right that scrolls up and fades. Each new
# pickup appends a label that tween-fades over 2.5 seconds.
var _toast_layer: VBoxContainer

func _setup_toast_layer() -> void:
	if _toast_layer != null:
		return
	_toast_layer = VBoxContainer.new()
	_toast_layer.anchor_left = 1.0
	_toast_layer.anchor_top = 0.0
	_toast_layer.anchor_right = 1.0
	_toast_layer.anchor_bottom = 0.0
	_toast_layer.offset_left = -320.0
	_toast_layer.offset_top = 80.0
	_toast_layer.offset_right = -20.0
	_toast_layer.offset_bottom = 200.0
	_toast_layer.alignment = BoxContainer.ALIGNMENT_END
	_toast_layer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	$Root.add_child(_toast_layer)

func _on_item_collected(item: Item, quantity: int) -> void:
	var row := HBoxContainer.new()
	# Icon
	var icon_rect := TextureRect.new()
	icon_rect.custom_minimum_size = Vector2(28, 28)
	icon_rect.expand_mode = TextureRect.EXPAND_FIT_WIDTH_PROPORTIONAL
	icon_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	var atlas: Node = get_node_or_null("/root/IconAtlas")
	if atlas and atlas.has_method("get_icon_for_item"):
		icon_rect.texture = atlas.get_icon_for_item(item)
	row.add_child(icon_rect)
	# Label
	var lbl := Label.new()
	lbl.text = "+ %s%s" % [item.display_name if item else "(unknown)", (" x%d" % quantity) if quantity > 1 else ""]
	lbl.modulate = _rarity_color(item.rarity if item else 2)
	row.add_child(lbl)
	_toast_layer.add_child(row)
	var tw := create_tween()
	tw.tween_interval(2.0)
	tw.tween_property(row, "modulate:a", 0.0, 0.4)
	tw.tween_callback(row.queue_free)

func _rarity_color(rarity: int) -> Color:
	match rarity:
		0: return Color(0.40, 0.40, 0.40)
		1: return Color(0.85, 0.85, 0.85)
		2: return Color(0.55, 0.85, 0.45)
		3: return Color(0.40, 0.50, 0.95)
		4: return Color(0.75, 0.30, 0.95)
		5: return Color(1.00, 0.65, 0.10)
		6: return Color(1.00, 0.95, 0.55)
	return Color.WHITE

# --- Boss bar ---
# Built procedurally because we want a boss bar without a separate .tscn.
# BossArena binds the boss to this bar via HUD.bind_boss(boss).
func _build_boss_bar() -> Control:
	var root := Control.new()
	root.name = "BossBar"
	root.anchor_left = 0.5
	root.anchor_top = 0.0
	root.anchor_right = 0.5
	root.anchor_bottom = 0.0
	root.offset_left = -360.0
	root.offset_top = 12.0
	root.offset_right = 360.0
	root.offset_bottom = 80.0
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.visible = false

	var frame := PanelContainer.new()
	frame.name = "Frame"
	frame.anchor_right = 1.0
	frame.anchor_bottom = 1.0
	# Backing panel: dark slate with gold filigree border + shadow,
	# matching the ability bar slot styling so the HUD reads as a set.
	var frame_sb := StyleBoxFlat.new()
	frame_sb.bg_color = Color(0.06, 0.04, 0.06, 0.94)
	frame_sb.border_color = Color(0.78, 0.62, 0.28, 1.0)
	frame_sb.set_border_width_all(2)
	frame_sb.set_corner_radius_all(6)
	frame_sb.shadow_color = Color(0, 0, 0, 0.65)
	frame_sb.shadow_size = 8
	frame_sb.shadow_offset = Vector2(0, 4)
	frame_sb.content_margin_top = 6
	frame_sb.content_margin_bottom = 6
	frame_sb.content_margin_left = 14
	frame_sb.content_margin_right = 14
	frame.add_theme_stylebox_override("panel", frame_sb)
	root.add_child(frame)

	var v := VBoxContainer.new()
	v.name = "V"
	v.add_theme_constant_override("separation", 4)
	frame.add_child(v)

	var name := Label.new()
	name.name = "Name"
	# 22pt bold-bright with crisp dark outline + drop shadow. 18pt was
	# below WoW boss-name reading distance.
	name.add_theme_font_size_override("font_size", 22)
	name.add_theme_color_override("font_color", Color(1.0, 0.92, 0.55, 1))
	name.add_theme_color_override("font_outline_color", Color(0.20, 0.05, 0.05, 1.0))
	name.add_theme_constant_override("outline_size", 5)
	name.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.85))
	name.add_theme_constant_override("shadow_offset_x", 2)
	name.add_theme_constant_override("shadow_offset_y", 2)
	name.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(name)

	var phase := Label.new()
	phase.name = "Phase"
	phase.add_theme_font_size_override("font_size", 13)
	phase.add_theme_color_override("font_color", Color(0.95, 0.75, 0.55, 1))
	phase.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.85))
	phase.add_theme_constant_override("outline_size", 3)
	phase.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(phase)

	var hp := ProgressBar.new()
	hp.name = "HP"
	hp.custom_minimum_size = Vector2(700, 26)
	hp.show_percentage = false
	# Bare modulate ditched — apply the same StyleBoxFlat treatment the
	# player bars get so the boss HP gets a polished inset frame +
	# bevel, not just a tinted ProgressBar.
	_apply_bar_style(hp, Color(0.92, 0.18, 0.20), Color(1.0, 0.50, 0.45), Color(0.45, 0.05, 0.07))
	# Boss HP gets its own value label (e.g. "8,250 / 12,000")
	_attach_value_label(hp, "%d / %d", "boss_hp")
	v.add_child(hp)

	var bar_script: GDScript = load("res://scripts/ui/hud_components/boss_bar.gd")
	if bar_script:
		root.set_script(bar_script)
	return root

# Public hooks for BossArena
func bind_boss(boss: Node) -> void:
	if boss_bar and boss_bar.has_method("bind_to_boss"):
		boss_bar.bind_to_boss(boss)

func unbind_boss() -> void:
	if boss_bar and boss_bar.has_method("hide_bar"):
		boss_bar.hide_bar()
