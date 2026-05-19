extends CanvasLayer
class_name HUD

# Minimal HUD: HP bar, mana bar, XP bar, level, ability cooldowns.

@export var player_path: NodePath

@onready var hp_bar: ProgressBar = $Root/Bars/HPBar
@onready var mana_bar: ProgressBar = $Root/Bars/ManaBar
@onready var xp_bar: ProgressBar = $Root/Bars/XPBar
@onready var level_label: Label = $Root/Bars/LevelLabel
@onready var gold_label: Label = $Root/Bars/GoldLabel if has_node("Root/Bars/GoldLabel") else null
@onready var resource_label: Label = $Root/Bars/ResourceLabel if has_node("Root/Bars/ResourceLabel") else null
var _last_gold: int = -1
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
	_install_class_portrait()
	_install_player_posture_bar()
	# Bond's "cluttered" complaint had a concrete cause: hud.tscn ships
	# the legacy AbilitySlotBar at the bottom-center AND _ready below
	# adds the polished WowAbilityBar at the same anchor. Both rendered
	# overlapping. Hide the legacy one, WowAbilityBar supersedes it.
	# Kept in the tree (not queue_free'd) so any code that references
	# it via NodePath still resolves.
	var legacy_ability_bar: Control = $Root.get_node_or_null("AbilitySlotBar") as Control
	if legacy_ability_bar:
		legacy_ability_bar.visible = false
	player.hp_changed.connect(_on_hp)
	player.mana_changed.connect(_on_mana)
	player.resource_changed.connect(_on_resource)
	if player.has_signal("combo_changed"):
		player.combo_changed.connect(_on_combo_changed)
	if player.stats:
		player.stats.leveled_up.connect(_on_level_up)
		player.stats.max_level_reached.connect(_on_max_level)
		# Surface attribute + skill point awards as toasts. The signals
		# already fire on every level-up but went unconsumed, so Bond was
		# silently accruing points and could only discover them by opening
		# the character or skill panels and noticing the "unspent" counter.
		if player.stats.has_signal("attribute_points_awarded"):
			player.stats.attribute_points_awarded.connect(_on_attribute_points_awarded)
		if player.stats.has_signal("skill_points_awarded"):
			player.stats.skill_points_awarded.connect(_on_skill_points_awarded)
	# Faction tier-up toast. FactionRegistry already broadcasts every
	# crossing of a tier boundary (Neutral -> Friendly, Friendly -> Honored,
	# etc.) but only TiamatRegistry subscribed. Bond used to hit Honored
	# with Crown and not see anything change; now the HUD acknowledges
	# the breakthrough with a tier-colored toast.
	var fr: Node = get_node_or_null("/root/FactionRegistry")
	if fr and fr.has_signal("tier_changed") and not fr.tier_changed.is_connected(_on_faction_tier_changed):
		fr.tier_changed.connect(_on_faction_tier_changed)
	# Equip rejection toast. Inventory emits equip_blocked when can_equip
	# fails (wrong class, wrong armor type, too low level, etc.) — it
	# carries the human-readable reason string from can_equip. Without
	# a subscriber, the equip call just silently returned null and the
	# player wondered why nothing happened.
	if player.inventory and player.inventory.has_signal("equip_blocked"):
		if not player.inventory.equip_blocked.is_connected(_on_equip_blocked):
			player.inventory.equip_blocked.connect(_on_equip_blocked)
	# Perfect-dodge feedback. Player emits this on the late i-frame slice
	# dodge that earns a riposte buff. The buff was applied silently;
	# now the HUD acknowledges the moment with a "PERFECT DODGE" toast +
	# a brief screen flash so the player feels the cinematic Sekiro-
	# style reward.
	if player.has_signal("perfect_dodge_triggered"):
		if not player.perfect_dodge_triggered.is_connected(_on_perfect_dodge):
			player.perfect_dodge_triggered.connect(_on_perfect_dodge)
	# Achievement unlock celebration. AchievementRegistry already emits
	# on every unlock and combat_log writes a one-liner, but there's no
	# big screen banner. Now toasts with the gold trophy glyph + audio
	# sting so the moment feels earned. The combat_log line still fires
	# for the persistent feed.
	var ar: Node = get_node_or_null("/root/AchievementRegistry")
	if ar and ar.has_signal("achievement_unlocked"):
		if not ar.achievement_unlocked.is_connected(_on_achievement_unlocked):
			ar.achievement_unlocked.connect(_on_achievement_unlocked)
	# Codex entry unlocks (first kill of a new mob type, lore rune found,
	# lodestone attuned). Quieter than achievements — small mint-blue
	# toast, no audio sting — so the discovery feed reads as ambient
	# rather than celebratory.
	var cr: Node = get_node_or_null("/root/CodexRegistry")
	if cr and cr.has_signal("entry_unlocked"):
		if not cr.entry_unlocked.is_connected(_on_codex_entry_unlocked):
			cr.entry_unlocked.connect(_on_codex_entry_unlocked)
	# Tattoo glyph earned. The glyph system (Inkstone Sage) lets
	# characters earn permanent marks for milestones (100 kills of X,
	# survive Y, etc). The earn signal had no listener — the glyph was
	# saved to the character but Bond never knew he'd earned it.
	var gr: Node = get_node_or_null("/root/GlyphRegistry")
	if gr and gr.has_signal("glyph_earned"):
		if not gr.glyph_earned.is_connected(_on_glyph_earned):
			gr.glyph_earned.connect(_on_glyph_earned)
	# Title unlock. TitleRegistry awards display titles tied to
	# achievements (e.g., "the Mortal Returned" for Walk-Back-from-
	# Lucifer, "the Hammer" for 100 hammer kills, etc.). Title is saved
	# to SaveFlags but had no on-screen acknowledgement. Toasted as a
	# rare prestige cue with the gold "the" prefix the in-game lore
	# uses for these epithets.
	var tr: Node = get_node_or_null("/root/TitleRegistry")
	if tr and tr.has_signal("title_unlocked"):
		if not tr.title_unlocked.is_connected(_on_title_unlocked):
			tr.title_unlocked.connect(_on_title_unlocked)
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
	# Boss bar, built procedurally so we don't need a separate .tscn.
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
	# Buff/debuff bar (top right, under minimap), shows StatusEffect resources
	var bb_script: GDScript = load("res://scripts/ui/hud_components/buff_bar.gd")
	if bb_script:
		var buffs := Control.new()
		buffs.set_script(bb_script)
		buffs.name = "BuffBar"
		$Root.add_child(buffs)
	# Player transient buff bar (top left, under HP/Mana/XP). Shows
	# the timer-float buffs that live on Player directly: battle cry,
	# guard, riposte, and surge potions. These aren't StatusEffect
	# resources so BuffBar doesn't pick them up.
	var pbb_script: GDScript = load("res://scripts/ui/hud_components/player_buff_bar.gd")
	if pbb_script:
		var pbb := Control.new()
		pbb.set_script(pbb_script)
		pbb.name = "PlayerBuffBar"
		$Root.add_child(pbb)
	# Tiamat awareness widget (top right, beside the minimap). Hidden
	# at DORMANT; fades in at STIRRING and tracks her dream as it
	# climbs. Pulses on tier-ups so the player's eye catches the
	# transition without a full toast occluding combat.
	var taw_script: GDScript = load("res://scripts/ui/hud_components/tiamat_awareness_widget.gd")
	if taw_script:
		var taw := Control.new()
		taw.set_script(taw_script)
		taw.name = "TiamatAwarenessWidget"
		$Root.add_child(taw)
	# Wound creep widget (top right, below the Tiamat widget). Hidden
	# at CONTAINED; reveals at SEEPING and tracks the corruption's
	# spread. Distinct green palette so the player can tell the two
	# cosmic threats apart at a glance.
	var wcw_script: GDScript = load("res://scripts/ui/hud_components/wound_creep_widget.gd")
	if wcw_script:
		var wcw := Control.new()
		wcw.set_script(wcw_script)
		wcw.name = "WoundCreepWidget"
		$Root.add_child(wcw)
	# Compass strip (top center). N/E/S/W cardinals + warp portal +
	# lodestone + quest-target markers slide along the strip as the
	# player rotates. Skyrim/Fallout style heading reference so the
	# player can navigate without opening the map.
	var cb_script: GDScript = load("res://scripts/ui/hud_components/compass_bar.gd")
	if cb_script:
		var cb := Control.new()
		cb.set_script(cb_script)
		cb.name = "CompassBar"
		$Root.add_child(cb)
	# Controls cheat-sheet overlay (F1 toggles). Reads bindings live
	# from InputMap so it stays accurate when key-rebind UI ships.
	var ch_script: GDScript = load("res://scripts/ui/panels/controls_help_panel.gd")
	if ch_script:
		var ch := CanvasLayer.new()
		ch.set_script(ch_script)
		ch.name = "ControlsHelpPanel"
		ch.layer = 75  # above HUD root, below pause modal
		add_child(ch)
	# Player ability cast bar (bottom-center, above the WowAbilityBar)
	var pcb_script: GDScript = load("res://scripts/ui/hud_components/player_cast_bar.gd")
	if pcb_script:
		var pcb := Control.new()
		pcb.set_script(pcb_script)
		pcb.name = "PlayerCastBar"
		$Root.add_child(pcb)
	# Death overlay (full-screen, hidden until died signal fires)
	var death_script: GDScript = load("res://scripts/ui/hud_components/death_overlay.gd")
	if death_script:
		var death_overlay := CanvasLayer.new()
		death_overlay.set_script(death_script)
		death_overlay.name = "DeathOverlay"
		add_child(death_overlay)
	# Quest tracker (top left, under bars)
	var qt_script: GDScript = load("res://scripts/ui/hud_components/quest_tracker.gd")
	if qt_script:
		var qt := Control.new()
		qt.set_script(qt_script)
		qt.name = "QuestTracker"
		$Root.add_child(qt)
	# DPS meter (bottom right, above action bar). Auto-hides when no
	# damage in the last 5 seconds; surfaces during combat with current
	# DPS + per-element breakdown.
	var dps_script: GDScript = load("res://scripts/ui/hud_components/dps_meter.gd")
	if dps_script:
		var dps := Control.new()
		dps.set_script(dps_script)
		dps.name = "DpsMeter"
		$Root.add_child(dps)
	# Combat log (bottom left, above ability bar)
	var cl_script: GDScript = load("res://scripts/ui/hud_components/combat_log.gd")
	if cl_script:
		var cl := Control.new()
		cl.set_script(cl_script)
		cl.name = "CombatLog"
		$Root.add_child(cl)
	# Bottom-right action bar, visible buttons for the menu tabs so new
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
	# Zone-entry sting + banner. Fires once per zone per save profile;
	# subsequent re-entries skip both. Deferred so the player's class +
	# audio bus are fully ready before the cue plays.
	call_deferred("_maybe_play_zone_entry_sting")

func _process(_delta: float) -> void:
	if player and player.stats:
		var need := float(player.stats.xp_to_next_level())
		xp_bar.max_value = max(1.0, need)
		xp_bar.value = player.stats.xp
		# Gold counter polls inventory.gold (the canonical, save-persisted
		# store). Vendor + quest + faction paths all write here; the
		# previous polling target (stats.gold) was a phantom field that
		# silently no-op'd. Cached compare avoids set_text every frame.
		if gold_label and player.inventory:
			var g: int = int(player.inventory.gold)
			if g != _last_gold:
				_last_gold = g
				gold_label.text = "%d gold" % g

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
	# Damage flash: detect HP drop and pulse the full-screen flash
	# overlay alpha 0.35 -> 0 over 250ms. Visceral 'I just got hit'
	# read separate from the slow low-HP vignette underneath.
	var prev_hp: float = float(hp_bar.value)
	if cur < prev_hp - 0.5:
		_pulse_hit_flash()
		# Low-HP heartbeat audio cue when below 30%
		var hp_pct_before: float = prev_hp / max(mx, 1.0)
		if hp_pct_before < 0.30:
			var ab: Node = get_node_or_null("/root/AudioBus")
			if ab and ab.has_method("play_cue"):
				ab.play_cue(&"hit", player.global_position if player else Vector3.ZERO, -3.0, 0.55)
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

# Full-screen damage flash overlay. Sibling of the low-HP vignette
# but lazy-spawned because most players don't take damage on the
# very first frame.
var _hit_flash: ColorRect = null

func _pulse_hit_flash() -> void:
	if _hit_flash == null or not is_instance_valid(_hit_flash):
		_hit_flash = ColorRect.new()
		_hit_flash.name = "HitFlash"
		_hit_flash.color = Color(0.85, 0.10, 0.10, 0.0)
		_hit_flash.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		_hit_flash.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_hit_flash.z_index = 50
		$Root.add_child(_hit_flash)
	_hit_flash.color.a = 0.35
	# Tween fade-out
	var tw := create_tween()
	tw.tween_property(_hit_flash, "color:a", 0.0, 0.25).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	# Camera shake on hit (small kick)
	var juice: Node = get_node_or_null("/root/Juice")
	if juice and juice.has_method("shake"):
		juice.shake(0.18, 0.10)

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
	# Background: dark inset with gold filigree border. Two-color border
	# (top/bottom split) gives the bar a recessed-into-armor look that
	# the single-color version lacked.
	var sb_bg := StyleBoxFlat.new()
	sb_bg.bg_color = Color(0.04, 0.03, 0.07, 0.94)
	sb_bg.border_color = Color(0.55, 0.42, 0.20, 0.96)
	sb_bg.set_border_width_all(1)
	sb_bg.border_width_bottom = 2  # thicker bottom edge = inset shadow
	sb_bg.set_corner_radius_all(4)
	# Drop shadow lifts the bar off the screen
	sb_bg.shadow_color = Color(0, 0, 0, 0.55)
	sb_bg.shadow_size = 3
	sb_bg.shadow_offset = Vector2(0, 1)
	bar.add_theme_stylebox_override("background", sb_bg)
	# Fill: vertical 3-stop gradient via border_color trickery + an
	# overlaid scrolling shine ColorRect (added below). Reads like a
	# WoW orb fill with depth + life.
	var sb_fg := StyleBoxFlat.new()
	sb_fg.bg_color = mid
	# Bright top edge for the lit-from-above bevel
	sb_fg.border_color = light
	sb_fg.border_width_top = 2
	# Dark bottom edge for the inset shadow read
	sb_fg.set_corner_radius_all(3)
	# Slight glow on the fill so the bar pops against the dark bg
	sb_fg.shadow_color = mid * 0.5
	sb_fg.shadow_size = 0
	bar.add_theme_stylebox_override("fill", sb_fg)
	# Hide the default percentage text; we'll attach our own value label
	bar.show_percentage = false
	# Animated shine overlay, a thin bright strip that scrolls
	# left-to-right across the fill via a TIME-driven shader. Reads as
	# the bar BREATHING; without it the bars are static rectangles.
	# WoW retail HP/Mana orbs have an analogous gloss sweep.
	if bar.get_node_or_null("Shine") == null:
		var shine := ColorRect.new()
		shine.name = "Shine"
		shine.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		shine.mouse_filter = Control.MOUSE_FILTER_IGNORE
		shine.color = Color.WHITE  # shader paints the actual color
		var shader := Shader.new()
		shader.code = """
shader_type canvas_item;
uniform vec4 highlight : source_color = vec4(1.0, 1.0, 1.0, 0.45);
void fragment() {
	// One bright vertical band sliding across UV.x. Period 6s per cycle.
	float band = smoothstep(0.0, 0.08, abs(fract(UV.x - TIME * 0.18) - 0.5));
	float gloss = (1.0 - band);
	// Multiply by vertical falloff so the shine concentrates near the
	// top half of the bar (lit-from-above).
	gloss *= smoothstep(1.0, 0.30, UV.y);
	COLOR = vec4(highlight.rgb, highlight.a * gloss);
}
"""
		var smat := ShaderMaterial.new()
		smat.shader = shader
		shine.material = smat
		bar.add_child(shine)
	# Damage-flash overlay: brief white pulse when value drops, fades
	# over 200ms via _refresh_value_label tween. Telegraphs incoming
	# damage at a glance even when the player is looking at the
	# action, not the bar.
	if bar.get_node_or_null("Flash") == null:
		var flash := ColorRect.new()
		flash.name = "Flash"
		flash.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		flash.mouse_filter = Control.MOUSE_FILTER_IGNORE
		flash.color = Color(1, 1, 1, 0)
		bar.add_child(flash)

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
	# Cache last value in metadata so we can detect drops and flash.
	var prev: float = float(bar.get_meta("_prev_value", bar.value))
	if bar.value < prev - 0.01:
		_pulse_bar_flash(bar)
	bar.set_meta("_prev_value", bar.value)
	lbl.text = "%d / %d" % [int(bar.value), int(bar.max_value)]

# Brief white flash on a bar when its value drops. Tweens the Flash
# overlay alpha 0.55 -> 0 over 220ms. Visual cue for incoming damage
# even when the player is looking at the world, not the HUD.
func _pulse_bar_flash(bar: ProgressBar) -> void:
	var flash: ColorRect = bar.get_node_or_null("Flash")
	if flash == null:
		return
	flash.color = Color(1, 1, 1, 0.55)
	var tw := create_tween()
	tw.tween_property(flash, "color:a", 0.0, 0.22).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)

# Round portrait/class crest in the top-left, anchoring the HP/Mana/XP
# stack. Without it the bars float in the upper-left corner with no
# visual anchor, Bond called this "cluttered". The portrait is a 70px
# disc with a class-themed glyph and a gold filigree ring; the bars
# slide right by 78px so they read as rooted to it instead of orphans.
# Thin gold posture bar layered just below the HP bar. Mirror of the
# boss posture meter but for the player. Subscribes to posture_changed
# on the player; auto-refreshes color toward red as posture climbs
# above 70% (visible "you're about to get staggered" cue).
func _install_player_posture_bar() -> void:
	if not player:
		return
	if hp_bar == null:
		return
	if hp_bar.get_node_or_null("PlayerPostureBar") != null:
		return
	var posture := ProgressBar.new()
	posture.name = "PlayerPostureBar"
	posture.show_percentage = false
	posture.max_value = 100.0
	posture.value = 0.0
	posture.custom_minimum_size = Vector2(0, 5)
	# Anchor across the HP bar's bottom edge (so it appears as a thin
	# gold strip under the HP fill, readable at a glance).
	posture.anchor_left = 0.0
	posture.anchor_top = 1.0
	posture.anchor_right = 1.0
	posture.anchor_bottom = 1.0
	posture.offset_top = 1
	posture.offset_bottom = 6
	# Use the same polished bar styling as the rest of the HUD ,
	# starts gold and shifts red via _on_player_posture as it fills.
	_apply_bar_style(posture, Color(1.0, 0.78, 0.32), Color(1.0, 0.92, 0.55), Color(0.45, 0.32, 0.10))
	posture.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hp_bar.add_child(posture)
	if player.has_signal("posture_changed") and not player.posture_changed.is_connected(_on_player_posture):
		player.posture_changed.connect(_on_player_posture)

func _on_player_posture(cur: float, mx: float) -> void:
	var posture: ProgressBar = hp_bar.get_node_or_null("PlayerPostureBar") if hp_bar else null
	if posture == null:
		return
	posture.max_value = max(1.0, mx)
	posture.value = cur
	# Color escalation: gold under 70%, orange 70-90%, red 90%+. Tells
	# the player visually how close they are to a stagger.
	var pct: float = cur / max(1.0, mx)
	var fill_sb: StyleBoxFlat = posture.get_theme_stylebox("fill") as StyleBoxFlat
	if fill_sb:
		if pct >= 0.90:
			fill_sb.bg_color = Color(0.95, 0.20, 0.18)
			fill_sb.border_color = Color(1.0, 0.50, 0.45)
		elif pct >= 0.70:
			fill_sb.bg_color = Color(0.95, 0.55, 0.20)
			fill_sb.border_color = Color(1.0, 0.78, 0.40)
		else:
			fill_sb.bg_color = Color(1.0, 0.78, 0.32)
			fill_sb.border_color = Color(1.0, 0.92, 0.55)

func _install_class_portrait() -> void:
	if not player or not player.stats or not player.stats.class_def:
		return
	if $Root.get_node_or_null("ClassPortrait"):
		return
	var portrait := Control.new()
	portrait.name = "ClassPortrait"
	portrait.anchor_left = 0.0
	portrait.anchor_top = 0.0
	portrait.anchor_right = 0.0
	portrait.anchor_bottom = 0.0
	portrait.offset_left = 18.0
	portrait.offset_top = 18.0
	portrait.offset_right = 90.0
	portrait.offset_bottom = 90.0
	portrait.mouse_filter = Control.MOUSE_FILTER_IGNORE
	$Root.add_child(portrait)
	# Gold ring background (the filigree frame)
	var ring := Panel.new()
	ring.anchor_right = 1.0
	ring.anchor_bottom = 1.0
	var ring_sb := StyleBoxFlat.new()
	ring_sb.bg_color = Color(0.06, 0.04, 0.06, 1.0)
	ring_sb.border_color = Color(0.78, 0.62, 0.28, 1.0)
	ring_sb.set_border_width_all(3)
	# Round corner radius equal to half-width => circle
	ring_sb.set_corner_radius_all(36)
	ring_sb.shadow_color = Color(0, 0, 0, 0.7)
	ring_sb.shadow_size = 8
	ring_sb.shadow_offset = Vector2(0, 4)
	ring.add_theme_stylebox_override("panel", ring_sb)
	portrait.add_child(ring)
	# Inner element-tinted disc, the class color shows through here
	var disc := Panel.new()
	disc.anchor_left = 0.0
	disc.anchor_top = 0.0
	disc.anchor_right = 1.0
	disc.anchor_bottom = 1.0
	disc.offset_left = 6
	disc.offset_top = 6
	disc.offset_right = -6
	disc.offset_bottom = -6
	var disc_sb := StyleBoxFlat.new()
	disc_sb.bg_color = _class_portrait_color().darkened(0.45)
	disc_sb.border_color = _class_portrait_color().lightened(0.25)
	disc_sb.set_border_width_all(1)
	disc_sb.set_corner_radius_all(30)
	disc.add_theme_stylebox_override("panel", disc_sb)
	portrait.add_child(disc)
	# Class glyph at center, uses the same procedural icon system as
	# the ability bar so the portrait reads as 'part of the same set'.
	var glyph := TextureRect.new()
	glyph.texture = _class_glyph_texture()
	glyph.expand_mode = TextureRect.EXPAND_FIT_WIDTH_PROPORTIONAL
	glyph.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	glyph.anchor_right = 1.0
	glyph.anchor_bottom = 1.0
	glyph.offset_left = 12
	glyph.offset_top = 12
	glyph.offset_right = -12
	glyph.offset_bottom = -12
	glyph.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	disc.add_child(glyph)
	# Slide the bar stack right so it doesn't overlap the portrait.
	var bars: Control = $Root.get_node_or_null("Bars")
	if bars:
		bars.offset_left = 100.0
		bars.offset_top = 18.0

# Pick a base color for the portrait disc based on class identity.
# Used by both the ring/disc tinting and the glyph painter so the
# portrait reads as a coherent class crest.
func _class_portrait_color() -> Color:
	if not player or not player.stats or not player.stats.class_def:
		return Color(0.55, 0.45, 0.35, 1)
	match player.stats.class_def.class_id:
		&"berserker":            return Color(0.85, 0.30, 0.20, 1)  # crimson
		&"assassin":             return Color(0.55, 0.20, 0.65, 1)  # shadow purple
		&"ronin":                return Color(0.45, 0.70, 1.00, 1)  # water blue (default style)
		&"ranger":               return Color(0.45, 0.85, 0.40, 1)  # forest green
		&"mage":                 return Color(0.55, 0.40, 0.95, 1)  # arcane violet
		&"chaos_druid":          return Color(0.20, 0.85, 0.60, 1)  # nature teal
		&"demon":                return Color(0.65, 0.20, 0.10, 1)  # hellfire
		&"paladin_guardian":     return Color(1.00, 0.85, 0.30, 1)  # holy gold
		&"paladin_lightbringer": return Color(0.95, 0.92, 0.65, 1)  # silver light
	return Color(0.85, 0.75, 0.50, 1)

# Procedural class crest texture, small 64x64 image with the class's
# canonical glyph (sword for ronin, flame for berserker, etc.).
# Painted once, cached as a static var so HUD recreation is free.
static var _crest_cache: Dictionary = {}
func _class_glyph_texture() -> Texture2D:
	if not player or not player.stats or not player.stats.class_def:
		return null
	var cid: StringName = player.stats.class_def.class_id
	if _crest_cache.has(cid):
		return _crest_cache[cid]
	var img := Image.create(64, 64, false, Image.FORMAT_RGBA8)
	var c: Color = _class_portrait_color().lightened(0.55).lerp(Color.WHITE, 0.25)
	# Each class gets its own glyph drawn into the 64x64 image.
	# Reuse the wow_ability_bar drawing primitives where possible by
	# loading the script and calling its static-style draw helpers.
	# For simplicity we inline a small subset here.
	match cid:
		&"berserker":            _draw_axe(img, c)
		&"assassin":             _draw_dagger(img, c)
		&"ronin":                _draw_katana(img, c)
		&"ranger":               _draw_bow(img, c)
		&"mage":                 _draw_staff(img, c)
		&"chaos_druid":          _draw_leaf(img, c)
		&"demon":                _draw_horns(img, c)
		&"paladin_guardian":     _draw_shield_cross(img, c)
		&"paladin_lightbringer": _draw_sun(img, c)
		_:                       _draw_diamond(img, c)
	var tex: Texture2D = ImageTexture.create_from_image(img)
	_crest_cache[cid] = tex
	return tex

# --- Class glyph drawing primitives (64x64 grid) ---
# Each one paints into `img` at 64x64. Centered, simple, recognizable
# at a glance. The portrait downstream tints these via its parent
# Panel's StyleBoxFlat so we only need the silhouette here.

func _draw_katana(img: Image, c: Color) -> void:
	# Diagonal blade upper-right -> lower-left + crossguard + dot pommel
	for i in range(-22, 23):
		var x: int = clamp(32 + i, 1, 62)
		var y: int = clamp(32 - i, 1, 62)
		_pset(img, x, y, c)
		if x + 1 < 63 and y - 1 > 0:
			_pset(img, x + 1, y - 1, c.lightened(0.3))
	# Crossguard
	for off in range(-7, 8):
		_pset(img, 22 + off, 42 + off, Color(0.92, 0.72, 0.30))

func _draw_axe(img: Image, c: Color) -> void:
	# Vertical haft + curved head
	for y in range(8, 56):
		_pset(img, 32, y, Color(0.30, 0.20, 0.10))  # haft
		_pset(img, 33, y, Color(0.30, 0.20, 0.10))
	for dy in range(-12, 13):
		var w: int = int(14 - abs(dy) * 0.4)
		for dx in range(0, w):
			_pset(img, 34 + dx, 22 + dy, c)

func _draw_dagger(img: Image, c: Color) -> void:
	# Short blade pointing up
	for y in range(8, 36):
		_pset(img, 32, y, c)
		_pset(img, 33, y, c.lightened(0.4))
		_pset(img, 31, y, c.darkened(0.3))
	# Crossguard
	for x in range(24, 41):
		_pset(img, x, 38, Color(0.78, 0.62, 0.28))
	# Grip
	for y in range(40, 56):
		_pset(img, 31, y, Color(0.18, 0.10, 0.08))
		_pset(img, 32, y, Color(0.18, 0.10, 0.08))

func _draw_bow(img: Image, c: Color) -> void:
	# C-shaped curve + string
	for t in range(0, 36):
		var theta: float = float(t) / 36.0 * PI
		var bx: int = 22 + int(sin(theta) * 18)
		var by: int = 12 + t
		_pset(img, bx, by, c)
		_pset(img, bx + 1, by, c)
	# String (vertical line)
	for y in range(14, 50):
		_pset(img, 28, y, c.lightened(0.4))

func _draw_staff(img: Image, c: Color) -> void:
	# Vertical staff + glowing orb at top
	for y in range(20, 60):
		_pset(img, 32, y, Color(0.28, 0.18, 0.12))
		_pset(img, 33, y, Color(0.28, 0.18, 0.12))
	# Orb
	for dy in range(-8, 9):
		for dx in range(-8, 9):
			if dx * dx + dy * dy <= 64:
				_pset(img, 32 + dx, 14 + dy, c)

func _draw_leaf(img: Image, c: Color) -> void:
	# Pointed leaf shape
	for y in range(8, 56):
		var t: float = float(y - 8) / 48.0
		var w: int = int(sin(t * PI) * 14)
		for dx in range(-w, w + 1):
			_pset(img, 32 + dx, y, c if (dx + y) % 3 != 0 else c.darkened(0.3))

func _draw_horns(img: Image, c: Color) -> void:
	# Demon horns curving outward
	for t in range(0, 24):
		var lx: int = 30 - t / 2
		var rx: int = 34 + t / 2
		var y: int = 40 - t
		_pset(img, lx, y, c)
		_pset(img, rx, y, c)
		_pset(img, lx + 1, y, c.darkened(0.3))
		_pset(img, rx - 1, y, c.darkened(0.3))

func _draw_shield_cross(img: Image, c: Color) -> void:
	# Shield silhouette + cross
	for y in range(10, 56):
		var t: float = float(y - 10) / 46.0
		var w: int = int(lerp(20.0, 4.0, t * t))
		for dx in range(-w, w + 1):
			_pset(img, 32 + dx, y, c.darkened(0.2))
	# Vertical cross
	for y in range(16, 46):
		_pset(img, 32, y, Color(1.0, 0.92, 0.55))
	for x in range(22, 43):
		_pset(img, x, 28, Color(1.0, 0.92, 0.55))

func _draw_sun(img: Image, c: Color) -> void:
	# Center disc + 8 rays
	for dy in range(-9, 10):
		for dx in range(-9, 10):
			if dx * dx + dy * dy <= 81:
				_pset(img, 32 + dx, 32 + dy, c)
	for i in range(8):
		var ang: float = float(i) * PI / 4.0
		for r in range(12, 24):
			_pset(img, 32 + int(cos(ang) * r), 32 + int(sin(ang) * r), c.lightened(0.3))

func _draw_diamond(img: Image, c: Color) -> void:
	for dx in range(-20, 21):
		for dy in range(-20, 21):
			if abs(dx) + abs(dy) <= 20:
				_pset(img, 32 + dx, 32 + dy, c)

func _pset(img: Image, x: int, y: int, c: Color) -> void:
	if x < 0 or x >= 64 or y < 0 or y >= 64:
		return
	img.set_pixel(x, y, c)

# Combo HUD widget: anchored right-center, font scales with stack count.
# Color crossfades from white -> yellow -> orange -> red as the combo
# climbs, so the player feels the climb visually.
func _install_combo_label() -> void:
	# Polished combo readout: outline + drop shadow so it reads on
	# every background, larger anchor area for the bigger pop scale,
	# and a brighter palette ramp for higher visibility on the
	# crimson/orange tier.
	_combo_label = Label.new()
	_combo_label.name = "ComboLabel"
	_combo_label.anchor_left = 1.0
	_combo_label.anchor_top = 0.5
	_combo_label.anchor_right = 1.0
	_combo_label.anchor_bottom = 0.5
	_combo_label.offset_left = -320.0
	_combo_label.offset_top = -50.0
	_combo_label.offset_right = -20.0
	_combo_label.offset_bottom = 50.0
	_combo_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_combo_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_combo_label.add_theme_font_size_override("font_size", 32)
	_combo_label.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.95))
	_combo_label.add_theme_constant_override("outline_size", 6)
	_combo_label.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.85))
	_combo_label.add_theme_constant_override("shadow_offset_x", 2)
	_combo_label.add_theme_constant_override("shadow_offset_y", 3)
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
	# Tier prefix changes the read at high stacks, "INSANE" /
	# "GODLIKE" call out the moment, not just numbers
	var tier_label: String = "COMBO"
	if stacks >= int(max_stacks * 0.85):
		tier_label = "GODLIKE"
	elif stacks >= int(max_stacks * 0.66):
		tier_label = "INSANE"
	elif stacks >= int(max_stacks * 0.40):
		tier_label = "RAMPAGE"
	_combo_label.text = "x%d  %s" % [stacks, tier_label]
	_combo_label.add_theme_color_override("font_color", col)
	_combo_label.modulate = Color(1, 1, 1, 1)
	_combo_label.add_theme_font_size_override("font_size", 28 + int(t * 36))  # 28..64 pt
	# Pop scale: brief 1.3x then back to 1.0
	_combo_label.scale = Vector2(1.3, 1.3)
	var tw := _combo_label.create_tween()
	tw.tween_property(_combo_label, "scale", Vector2.ONE, 0.22).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)

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

# Surface the +N attribute-points award as its own toast a beat after
# the level-up banner so the two cues don't pile on top of each other.
# Color matches the character panel's primary attribute swatch (red-
# orange) so the player learns "this is where these go" without a
# tutorial pointer.
func _on_attribute_points_awarded(amount: int) -> void:
	if amount <= 0:
		return
	var juice: Node = get_node_or_null("/root/Juice")
	if juice and juice.has_method("toast"):
		juice.toast("+%d attribute points  (T)" % amount, Color(0.95, 0.65, 0.30), 2.8)

# Same pattern for skill points; cyan-blue matches the skill tree
# panel chrome. "(K)" hint points at the rebindable key in case the
# player hasn't memorized it yet.
func _on_skill_points_awarded(amount: int) -> void:
	if amount <= 0:
		return
	var juice: Node = get_node_or_null("/root/Juice")
	if juice and juice.has_method("toast"):
		juice.toast("+%d skill point%s  (K)" % [amount, "s" if amount > 1 else ""], Color(0.55, 0.85, 1.00), 2.8)

# Surface a faction tier crossing. Uses FactionRegistry's own tier
# color palette so Hated reads red, Friendly reads green, Revered reads
# the gold-purple Crown color, etc. Tier DOWN (loss) gets a different
# tone so the player feels the difference between progress + setback.
func _on_faction_tier_changed(faction_id: StringName, new_tier: String, old_tier: String) -> void:
	var juice: Node = get_node_or_null("/root/Juice")
	if juice == null or not juice.has_method("toast"):
		return
	# Resolve faction display name + tier color from the registry so the
	# toast reads "Crown: Honored" rather than "crown_id: Honored".
	var fr: Node = get_node_or_null("/root/FactionRegistry")
	var faction_label: String = String(faction_id).capitalize().replace("_", " ")
	if fr and fr.has_method("get_faction"):
		var f = fr.get_faction(faction_id)
		if f and "display_name" in f and f.display_name != "":
			faction_label = f.display_name
	var color: Color = Color(0.85, 0.85, 0.85)
	if fr and "TIER_COLORS" in fr:
		color = (fr.TIER_COLORS as Dictionary).get(new_tier, color)
	# Tier-up vs tier-down arrows make the direction unmissable.
	var arrow: String = "↑" if _tier_index(new_tier) > _tier_index(old_tier) else "↓"
	juice.toast("%s %s: %s" % [arrow, faction_label, new_tier], color, 3.2)

# Helper for direction comparison. Falls back to 0 for unknown tiers so
# a future tier addition doesn't accidentally classify everything as a
# downgrade.
func _tier_index(tier_name: String) -> int:
	const ORDER := {"Hated": -3, "Hostile": -2, "Unfriendly": -1, "Neutral": 0, "Friendly": 1, "Honored": 2, "Revered": 3}
	return int(ORDER.get(tier_name, 0))

# Perfect dodge feedback: cyan-mint toast + brief screen flash + audio
# sting. The riposte buff itself is already applied in player.gd; this
# is purely the player-facing acknowledgement that "you nailed it."
func _on_perfect_dodge() -> void:
	var juice: Node = get_node_or_null("/root/Juice")
	if juice:
		if juice.has_method("toast"):
			juice.toast("PERFECT DODGE", Color(0.55, 1.00, 0.75), 1.8)
		if juice.has_method("flash"):
			juice.flash(Color(0.55, 1.0, 0.75), 0.12, 0.30)
	var ab: Node = get_node_or_null("/root/AudioBus")
	if ab and ab.has_method("play_cue") and player:
		ab.play_cue(&"parry", player.global_position, -6.0, 1.3)

# Achievement unlock: big gold trophy toast + audio sting. The achievement
# resource carries a display_name; falls back to a generic line if the
# shape is unfamiliar (some achievements ship as Dictionary, others as
# Achievement resources).
func _on_achievement_unlocked(a) -> void:
	var name: String = ""
	if a != null:
		if "display_name" in a and a.display_name != "":
			name = a.display_name
		elif a.has_method("get"):
			name = String(a.get("display_name") if a.get("display_name") != null else "")
	if name == "":
		name = "Achievement Unlocked"
	var juice: Node = get_node_or_null("/root/Juice")
	if juice:
		if juice.has_method("toast"):
			juice.toast("★  %s" % name, Color(1.00, 0.75, 0.20), 4.0)
		if juice.has_method("flash"):
			juice.flash(Color(1.0, 0.85, 0.45), 0.15, 0.35)
	var ab: Node = get_node_or_null("/root/AudioBus")
	if ab and ab.has_method("play_cue") and player:
		ab.play_cue(&"victory", player.global_position, -10.0, 1.4)

# Title unlock: gold serif-feeling toast (no audio on top of the
# achievement sting that usually fires alongside — the title is the
# epithet AT the achievement, not a separate cinematic). Reads as
# "you now bear this name" rather than "you accomplished a thing."
func _on_title_unlocked(title_id: StringName) -> void:
	var tr: Node = get_node_or_null("/root/TitleRegistry")
	if tr == null or not tr.has_method("get_title"):
		return
	var t = tr.get_title(title_id)
	if t == null:
		return
	var name: String = String(t.display_name) if "display_name" in t and t.display_name != "" else String(title_id)
	var juice: Node = get_node_or_null("/root/Juice")
	if juice and juice.has_method("toast"):
		juice.toast("Title earned: %s" % name, Color(1.00, 0.85, 0.45), 4.5)

# Tattoo glyph earned: dramatic, since glyphs are permanent character
# marks. Deep red-orange toast + heartbeat-style flash, audio sting at
# the parry pitch. Reads as "you carved something into yourself" not
# "you found a new collectible."
func _on_glyph_earned(glyph, _char_id: String) -> void:
	var name: String = ""
	if glyph != null:
		if "display_name" in glyph and glyph.display_name != "":
			name = glyph.display_name
		elif "glyph_id" in glyph:
			name = String(glyph.glyph_id).capitalize().replace("_", " ")
	if name == "":
		name = "a new glyph"
	var juice: Node = get_node_or_null("/root/Juice")
	if juice:
		if juice.has_method("toast"):
			juice.toast("✦ Glyph earned: %s" % name, Color(0.95, 0.55, 0.30), 4.5)
		if juice.has_method("flash"):
			juice.flash(Color(0.95, 0.55, 0.30), 0.18, 0.55)
	var ab: Node = get_node_or_null("/root/AudioBus")
	if ab and ab.has_method("play_cue") and player:
		ab.play_cue(&"parry", player.global_position, -8.0, 0.85)

# Codex entry discovery: smaller mint toast, no audio sting. Reads as
# "you noticed a new thing" rather than "you accomplished something."
func _on_codex_entry_unlocked(entry) -> void:
	var name: String = ""
	if entry is Dictionary:
		name = String(entry.get("display_name", entry.get("name", "")))
	elif entry and "display_name" in entry:
		name = String(entry.display_name)
	if name == "":
		return
	var juice: Node = get_node_or_null("/root/Juice")
	if juice and juice.has_method("toast"):
		juice.toast("Codex: %s" % name, Color(0.55, 0.85, 1.00), 2.4)

# Toast the equip rejection reason (e.g., "Mages cannot wield greatswords",
# "Requires level 12", "Armor type Plate exceeds your class cap of Mail").
# Red-orange so it reads as a denial cue, paired with the deny audio for
# the same feedback every time a click is refused elsewhere in the HUD.
func _on_equip_blocked(_item, reason: String) -> void:
	var juice: Node = get_node_or_null("/root/Juice")
	if juice and juice.has_method("toast"):
		juice.toast(reason if reason != "" else "Cannot equip.", Color(0.95, 0.35, 0.20), 2.5)
	var ab: Node = get_node_or_null("/root/AudioBus")
	if ab and ab.has_method("play_cue") and player:
		ab.play_cue(&"deny", player.global_position, -10.0, 0.95)

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
		# Match the label color to the bar fill so STANCE reads pale
		# silver, RAGE reads red, BLOOD reads crimson, etc. Lightened
		# slightly + outline already in the .tscn keeps it readable.
		resource_label.add_theme_color_override("font_color", (theme["color"] as Color).lightened(0.25))

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
	# Bare modulate ditched, apply the same StyleBoxFlat treatment the
	# player bars get so the boss HP gets a polished inset frame +
	# bevel, not just a tinted ProgressBar.
	_apply_bar_style(hp, Color(0.92, 0.18, 0.20), Color(1.0, 0.50, 0.45), Color(0.45, 0.05, 0.07))
	# Boss HP gets its own value label (e.g. "8,250 / 12,000")
	_attach_value_label(hp, "%d / %d", "boss_hp")
	v.add_child(hp)

	# Posture meter, sits ABOVE the cast row but below HP. Thin gold
	# bar that fills as the player lands hits; full = boss staggered,
	# vulnerable to a finisher. Sekiro/Bloodborne convention.
	var posture := ProgressBar.new()
	posture.name = "Posture"
	posture.custom_minimum_size = Vector2(700, 8)
	posture.show_percentage = false
	posture.max_value = 100.0
	posture.value = 0.0
	# Gold-on-black styling distinct from the red HP fill, players
	# read 'this is a different mechanic' at a glance.
	_apply_bar_style(posture, Color(1.00, 0.78, 0.32), Color(1.00, 0.92, 0.55), Color(0.45, 0.32, 0.10))
	v.add_child(posture)

	# Cast bar, shown only while boss is winding up an attack. Reads
	# the boss's _current_pattern and _pattern_state in _process.
	# Without this the player has to guess from ground decals what's
	# coming. With it: 'IRON CHARGE' under a draining bar = clear
	# 'sidestep NOW' read.
	var cast_row := Control.new()
	cast_row.name = "CastRow"
	cast_row.custom_minimum_size = Vector2(700, 26)
	cast_row.visible = false
	v.add_child(cast_row)
	var cast_label := Label.new()
	cast_label.name = "CastLabel"
	cast_label.add_theme_font_size_override("font_size", 16)
	cast_label.add_theme_color_override("font_color", Color(1.0, 0.85, 0.55, 1))
	cast_label.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.95))
	cast_label.add_theme_constant_override("outline_size", 4)
	cast_label.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.85))
	cast_label.add_theme_constant_override("shadow_offset_x", 2)
	cast_label.add_theme_constant_override("shadow_offset_y", 2)
	cast_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	cast_label.set_anchors_and_offsets_preset(Control.PRESET_TOP_WIDE)
	cast_label.offset_top = -2
	cast_label.offset_bottom = 18
	cast_row.add_child(cast_label)
	var cast_bar := ProgressBar.new()
	cast_bar.name = "CastBar"
	cast_bar.custom_minimum_size = Vector2(700, 8)
	cast_bar.show_percentage = false
	cast_bar.max_value = 1.0
	cast_bar.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_WIDE)
	cast_bar.offset_top = -8
	cast_bar.offset_bottom = 0
	# Reuse the polished bar style for visual coherence, orange fill
	# so the cast bar reads as 'incoming danger' regardless of the
	# attack's element.
	_apply_bar_style(cast_bar, Color(1.0, 0.55, 0.18), Color(1.0, 0.78, 0.40), Color(0.50, 0.20, 0.06))
	cast_row.add_child(cast_bar)

	var bar_script: GDScript = load("res://scripts/ui/hud_components/boss_bar.gd")
	if bar_script:
		root.set_script(bar_script)
	return root

# Public hooks for BossArena
func bind_boss(boss: Node) -> void:
	if boss_bar and boss_bar.has_method("bind_to_boss"):
		boss_bar.bind_to_boss(boss)
	# Forward to CombatLog so phase + HP threshold transitions get
	# permanent log lines ("⚠ Kazat — ENRAGED"). The log handles
	# its own dedup via per-boss meta.
	var cl: Node = $Root.get_node_or_null("CombatLog")
	if cl and cl.has_method("bind_boss"):
		cl.bind_boss(boss)

func unbind_boss() -> void:
	if boss_bar and boss_bar.has_method("hide_bar"):
		boss_bar.hide_bar()

# Zone-entry sting: first time the player loads a region scene, fire
# a deep audio cue + a quest-banner-style "YOU HAVE ENTERED ..." card.
# Tracked via SaveFlags permanent so each zone announces itself once
# per save profile. Subsequent visits stay quiet so the player isn't
# bombarded every commute.
const _ZONE_NAME_BY_SCENE := {
	"sword_vow_ruins":     "Sword-Vow Ruins",
	"ash_step_camp":       "Ash-Step Camp",
	"whisper_shrine":      "Whisper Shrine",
	"inkstone_tower":      "Inkstone Tower",
	"coven_glen":          "Coven Glen",
	"greenheart_glade":    "Greenheart Glade",
	"sunsworn_chapel":     "Sunsworn Chapel",
	"the_cradle":          "The Cradle of Marduk",
	"the_reed_wastes":     "The Reed Wastes",
	"lapis_bay":           "Lapis Bay",
	"bone_mountains":      "Bone Mountains",
	"verdant_wound":       "The Verdant Wound",
	"ember_steppes":       "Ember Steppes",
	"mist_vale":           "Mist Vale",
	"shrieking_highlands": "Shrieking Highlands",
	"sundered_coast":      "Sundered Coast",
	"black_citadel":       "Black Citadel",
	"fire_stair":          "Fire-Stair",
	"ashurim":             "Ashurim",
	"babilim":             "Babilim",
}

func _maybe_play_zone_entry_sting() -> void:
	var tree := get_tree()
	if tree == null or tree.current_scene == null:
		return
	# Pull the scene-file name (no extension) so we can resolve the
	# friendly zone name + the SaveFlag key.
	var scene_path: String = tree.current_scene.scene_file_path
	if scene_path == "":
		return
	var fname: String = scene_path.get_file().trim_suffix(".tscn")
	if not _ZONE_NAME_BY_SCENE.has(fname):
		return  # not a tracked region scene (e.g. menu / intro / arena)
	var sf: Node = get_node_or_null("/root/SaveFlags")
	var flag: StringName = StringName("zone_entered_" + fname)
	if sf and sf.has_method("has_permanent") and sf.has_permanent(flag):
		return  # already announced this zone before
	if sf and sf.has_method("set_permanent"):
		sf.set_permanent(flag, true)
	# Audio sting first (lodestone cue at low pitch reads as "deep
	# place opening up to you"), then the banner.
	var ab: Node = get_node_or_null("/root/AudioBus")
	if ab and ab.has_method("play_cue"):
		ab.play_cue(&"lodestone", Vector3.ZERO, -3.0, 0.55)
	var juice: Node = get_node_or_null("/root/Juice")
	var name: String = String(_ZONE_NAME_BY_SCENE[fname])
	if juice and juice.has_method("quest_banner"):
		juice.quest_banner("YOU HAVE ENTERED", name, "", Color(0.95, 0.85, 0.45), 4.0)
	elif juice and juice.has_method("toast"):
		juice.toast("Entered: %s" % name, Color(0.95, 0.85, 0.45), 3.0)
