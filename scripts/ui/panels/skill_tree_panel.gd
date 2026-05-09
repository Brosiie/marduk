extends CanvasLayer
class_name SkillTreePanel

# Preload-shadowed alias, bypasses the global class_name cache. When
# .godot/global_script_class_cache.cfg is stale, the bare class_name
# 'SkillTreeLines' fails to resolve and this whole panel goes offline
# silently. Preload is order-independent and outlives editor refreshes.
const SkillTreeLines := preload("res://scripts/ui/panels/skill_tree_lines.gd")

# Procedural skill-tree UI. Reads the active player's class skill tree
# (49 nodes laid out 7 branches x 7 tiers via grid_position) and renders:
#   - Header bar: class name + unspent skill points
#   - Grid: one button per node, positioned by grid_position
#   - Branch labels along the top
#   - Tier numbers down the left
#   - Tooltip panel: shown on click; name, description, cost, prereqs,
#     rank pips, Unlock/Upgrade/Maxed/Locked button
#   - Connecting lines between prerequisite chains (drawn under the buttons)
#
# Toggled by the `toggle_skills` input action (K). Pauses the game while open
# so combat doesn't continue under the panel.

const COLUMN_WIDTH := 132
const ROW_HEIGHT := 92
const NODE_SIZE := Vector2(72, 72)
const HEADER_HEIGHT := 84
const GRID_OFFSET := Vector2(120, 110)
const TIER_LABEL_WIDTH := 48

# Node visual state colors
const COLOR_MAXED      := Color(1.00, 0.85, 0.35, 1.0)   # gold, fully invested
const COLOR_AVAILABLE  := Color(0.95, 0.92, 0.80, 1.0)   # cream, can purchase
const COLOR_PARTIAL    := Color(0.85, 0.70, 0.30, 1.0)   # amber, partial investment
const COLOR_LOCKED     := Color(0.30, 0.28, 0.25, 1.0)   # dim grey, prereq unmet
const COLOR_PREREQ_MISS:= Color(0.55, 0.30, 0.30, 1.0)   # dim red, gated by level
const COLOR_CAPSTONE   := Color(1.00, 0.45, 0.20, 1.0)   # ember, tier-7 capstones

const BRANCH_LABEL_COLOR := Color(0.85, 0.80, 0.60, 0.95)
const TIER_LABEL_COLOR   := Color(0.65, 0.58, 0.45, 0.85)
const LINE_COLOR_NORMAL  := Color(0.40, 0.32, 0.20, 0.55)
const LINE_COLOR_ACTIVE  := Color(1.00, 0.85, 0.35, 0.85)

@onready var dim_layer: ColorRect = $Dim if has_node("Dim") else null
@onready var panel_root: Control = $Panel if has_node("Panel") else null

var player: Node = null
var stats = null
var tree: SkillTree = null
var _node_buttons: Dictionary = {}      # StringName -> Button
var _line_canvas: SkillTreeLines = null
var _tooltip_panel: PanelContainer = null
var _tooltip_label: RichTextLabel = null
var _tooltip_action_btn: Button = null
var _header_label: Label = null
var _points_label: Label = null
var _selected_node_id: StringName = &""

# Branch labels per class. The skill_tree_factory builds branches by index 0-6;
# the names below mirror those in the README's branch table (per-class section).
const BRANCH_LABELS := {
	&"berserker":            ["War", "Blood", "Fury", "Berserk", "Sunder", "Endurance", "Roar"],
	&"assassin":             ["Shadow", "Venom", "Crimson", "Dagger", "Agility", "Lethality", "Espionage"],
	&"ronin":                ["Water", "Flame", "Mist", "Thunder", "Stone", "Wind", "Sun"],
	&"ranger":               ["Marksman", "Beast", "Traps", "Survival", "Tracking", "Ambush", "Storm"],
	&"mage":                 ["Fire", "Frost", "Lightning", "Arcane", "Holy", "Shadow", "Void"],
	&"chaos_druid":          ["Wild", "Grove", "Chaos", "Thorn", "Beast", "Elemental", "Tiamat"],
	&"demon":                ["Legion", "Hunger", "Damnation", "Abyss", "Nightborn", "Infernal", "Wrath"],
	&"paladin_guardian":     ["Aegis", "Wrath", "Ward", "Vow", "Tenacity", "Vindication", "Banner"],
	&"paladin_lightbringer": ["Mercy", "Light", "Salt", "Devotion", "Compassion", "Wrath of Dawn", "Grace"],
}

# Branch tint colors per class. Applied to the node border as a base hue;
# the state color (gold maxed / cream available / etc) layers on top via
# saturation. Colors mirror the lore-element of each branch.
const BRANCH_COLORS := {
	&"berserker": [
		Color(0.85, 0.30, 0.20),  # War, blood red
		Color(0.65, 0.10, 0.15),  # Blood, arterial
		Color(0.95, 0.45, 0.25),  # Fury, ember
		Color(0.75, 0.20, 0.45),  # Berserk, magenta
		Color(0.55, 0.45, 0.35),  # Sunder, bone
		Color(0.55, 0.65, 0.55),  # Endurance, moss
		Color(0.95, 0.70, 0.30),  # Roar, gold
	],
	&"assassin": [
		Color(0.45, 0.40, 0.55),  # Shadow, dim violet
		Color(0.45, 0.85, 0.40),  # Venom, green
		Color(0.85, 0.30, 0.40),  # Crimson, red
		Color(0.75, 0.75, 0.85),  # Dagger, silver
		Color(0.55, 0.85, 0.95),  # Agility, sky
		Color(0.95, 0.45, 0.20),  # Lethality, orange
		Color(0.30, 0.30, 0.45),  # Espionage, navy
	],
	&"ronin": [
		Color(0.35, 0.65, 1.00),  # Water, cobalt
		Color(0.95, 0.45, 0.20),  # Flame, ember
		Color(0.65, 0.55, 0.75),  # Mist, pale violet
		Color(0.95, 0.95, 0.40),  # Thunder, yellow
		Color(0.65, 0.55, 0.45),  # Stone, earth
		Color(0.85, 0.95, 0.85),  # Wind, pale celadon
		Color(1.00, 0.85, 0.30),  # Sun, gold
	],
	&"ranger": [
		Color(0.85, 0.75, 0.45),  # Marksman, wheat
		Color(0.65, 0.85, 0.45),  # Beast, leaf
		Color(0.55, 0.45, 0.30),  # Traps, wood
		Color(0.45, 0.65, 0.55),  # Survival, sage
		Color(0.55, 0.55, 0.55),  # Tracking, slate
		Color(0.30, 0.30, 0.30),  # Ambush, charcoal
		Color(0.55, 0.85, 1.00),  # Storm, pale lightning
	],
	&"mage": [
		Color(1.00, 0.45, 0.20),  # Fire
		Color(0.65, 0.85, 1.00),  # Frost
		Color(0.85, 0.85, 1.00),  # Lightning, pale electric
		Color(0.55, 0.40, 0.95),  # Arcane, violet
		Color(1.00, 0.85, 0.45),  # Holy, gold
		Color(0.55, 0.20, 0.65),  # Shadow, purple
		Color(0.30, 0.10, 0.40),  # Void, deep
	],
	&"chaos_druid": [
		Color(0.55, 0.85, 0.45),  # Wild, green
		Color(0.45, 0.65, 0.35),  # Grove, forest
		Color(0.85, 0.45, 0.95),  # Chaos, violet-pink
		Color(0.65, 0.55, 0.30),  # Thorn, brown
		Color(0.85, 0.65, 0.30),  # Beast, fawn
		Color(0.45, 0.85, 0.85),  # Elemental, teal
		Color(0.45, 0.20, 0.55),  # Tiamat, wound-violet
	],
	&"demon": [
		Color(0.55, 0.30, 0.65),  # Legion, necrotic violet
		Color(0.85, 0.30, 0.30),  # Hunger, blood
		Color(0.45, 0.20, 0.55),  # Damnation, purple
		Color(0.20, 0.20, 0.30),  # Abyss, void
		Color(0.30, 0.30, 0.55),  # Nightborn, midnight
		Color(0.95, 0.45, 0.20),  # Infernal, fire
		Color(0.85, 0.30, 0.20),  # Wrath, red
	],
	&"paladin_guardian": [
		Color(0.95, 0.95, 0.85),  # Aegis, bone-white
		Color(0.85, 0.30, 0.20),  # Wrath, crimson
		Color(0.55, 0.85, 0.95),  # Ward, pale blue
		Color(0.95, 0.85, 0.45),  # Vow, gold
		Color(0.65, 0.65, 0.65),  # Tenacity, steel
		Color(1.00, 0.85, 0.30),  # Vindication, sun-gold
		Color(0.95, 0.95, 0.95),  # Banner, pure white
	],
	&"paladin_lightbringer": [
		Color(0.85, 0.85, 0.85),  # Mercy, pale grey-white
		Color(1.00, 0.95, 0.55),  # Light, pale gold
		Color(0.85, 0.85, 0.65),  # Salt, sea-bone
		Color(0.95, 0.65, 0.65),  # Devotion, dawn-pink
		Color(0.95, 0.85, 0.55),  # Compassion, warm cream
		Color(1.00, 0.55, 0.30),  # Wrath of Dawn, sunrise
		Color(1.00, 0.95, 0.85),  # Grace, pale dawn
	],
}

# Default branch colors when class_id isn't in the map (eg test characters).
const DEFAULT_BRANCH_COLORS := [
	Color(0.55, 0.55, 0.55),  # x7 neutral grey
	Color(0.55, 0.55, 0.55), Color(0.55, 0.55, 0.55), Color(0.55, 0.55, 0.55),
	Color(0.55, 0.55, 0.55), Color(0.55, 0.55, 0.55), Color(0.55, 0.55, 0.55),
]

# Class-aware visual theme. Each class gets:
#   - dim_color:    full-screen background tint behind the panel
#   - border_color: header + tooltip panel border hue (state colors layer over)
#   - accent_color: motif label color
#   - motif:        large Unicode character displayed bottom-right as a watermark
#   - title_suffix: appended to the class display name in the header (lore flair)
#
# Procedural for now, Tier 2 polish swaps in real parchment/starfield/ember
# textures by adding a `background_texture: Texture2D` field here.
const CLASS_THEMES := {
	&"berserker": {
		"dim_color":    Color(0.10, 0.04, 0.03, 0.92),   # ash-and-blood
		"border_color": Color(0.65, 0.20, 0.15, 0.95),
		"accent_color": Color(0.95, 0.45, 0.20),
		"motif":        "⚔",
		"title_suffix": ", War Without Rest",
	},
	&"assassin": {
		"dim_color":    Color(0.04, 0.05, 0.06, 0.94),   # midnight + venom
		"border_color": Color(0.30, 0.50, 0.30, 0.85),
		"accent_color": Color(0.55, 0.85, 0.45),
		"motif":        "✶",
		"title_suffix": ", Whispered Edge",
	},
	&"ronin": {
		"dim_color":    Color(0.05, 0.08, 0.14, 0.92),   # cobalt night, parchment-warm border
		"border_color": Color(0.95, 0.85, 0.55, 0.95),
		"accent_color": Color(0.35, 0.65, 1.00),
		"motif":        "刃",
		"title_suffix": ", Seven Breaths",
	},
	&"ranger": {
		"dim_color":    Color(0.04, 0.08, 0.05, 0.92),   # forest dark
		"border_color": Color(0.55, 0.80, 0.45, 0.85),
		"accent_color": Color(0.85, 0.95, 0.55),
		"motif":        "➳",
		"title_suffix": ", Eyes of the Glade",
	},
	&"mage": {
		"dim_color":    Color(0.04, 0.04, 0.10, 0.93),   # arcane starfield
		"border_color": Color(0.55, 0.40, 0.95, 0.95),
		"accent_color": Color(0.85, 0.85, 1.00),
		"motif":        "✦",
		"title_suffix": ", The Inkstone Holds",
	},
	&"chaos_druid": {
		"dim_color":    Color(0.05, 0.07, 0.05, 0.92),   # bog dark + woad accents
		"border_color": Color(0.55, 0.30, 0.65, 0.85),
		"accent_color": Color(0.65, 0.85, 0.45),
		"motif":        "♆",
		"title_suffix": ", The Wound Speaks",
	},
	&"demon": {
		"dim_color":    Color(0.06, 0.02, 0.02, 0.95),   # ember-black
		"border_color": Color(0.85, 0.20, 0.10, 0.95),
		"accent_color": Color(0.95, 0.45, 0.20),
		"motif":        "♅",
		"title_suffix": ", Blood Pays the Toll",
	},
	&"paladin_guardian": {
		"dim_color":    Color(0.08, 0.07, 0.06, 0.92),   # marble-warm
		"border_color": Color(1.00, 0.85, 0.45, 0.95),
		"accent_color": Color(0.95, 0.95, 0.85),
		"motif":        "✠",
		"title_suffix": ", The Wall That Stands",
	},
	&"paladin_lightbringer": {
		"dim_color":    Color(0.08, 0.07, 0.07, 0.92),   # dawn warm
		"border_color": Color(1.00, 0.65, 0.55, 0.95),
		"accent_color": Color(1.00, 0.95, 0.85),
		"motif":        "☼",
		"title_suffix": ", Dawn-Bringer",
	},
}

const DEFAULT_THEME := {
	"dim_color":    Color(0.02, 0.015, 0.025, 0.85),
	"border_color": Color(0.55, 0.40, 0.20, 0.90),
	"accent_color": Color(0.95, 0.85, 0.55),
	"motif":        "✷",
	"title_suffix": "",
}

func _theme_for_class() -> Dictionary:
	var class_id: StringName = stats.class_def.class_id if stats and stats.class_def else &""
	return CLASS_THEMES.get(class_id, DEFAULT_THEME)

func _ready() -> void:
	visible = false
	process_mode = Node.PROCESS_MODE_ALWAYS  # tick even while paused
	# Locate the player on first frame; rebind if a player joins later.
	_try_bind_player()
	get_tree().node_added.connect(_on_node_added)

func _on_node_added(node: Node) -> void:
	if not player and node.is_in_group("player"):
		player = node
		_rebind()

func _try_bind_player() -> void:
	for p in get_tree().get_nodes_in_group("player"):
		if is_instance_valid(p):
			player = p
			_rebind()
			break

func _rebind() -> void:
	if not player:
		return
	stats = player.get("stats")
	if stats and stats.class_def and stats.class_def.skill_tree:
		tree = stats.class_def.skill_tree

func _input(event: InputEvent) -> void:
	if event.is_action_pressed("toggle_skills"):
		_toggle()
	elif event.is_action_pressed("ui_cancel") and visible:
		_close()

func _toggle() -> void:
	if visible:
		_close()
	else:
		_open()

func _open() -> void:
	if not player or not stats or not tree:
		_rebind()
	if not tree:
		push_warning("[SkillTreePanel] no skill tree available for current class")
		return
	visible = true
	get_tree().paused = true
	_build_panel()

func _close() -> void:
	visible = false
	get_tree().paused = false
	_selected_node_id = &""

# ---------------------------------------------------------------
# Build pass: full rebuild on open. Cheap enough at 49 nodes; lets
# us avoid managing diff state between class swaps + rank changes.
# ---------------------------------------------------------------
func _build_panel() -> void:
	if not panel_root:
		return
	# Wipe previous build
	for c in panel_root.get_children():
		c.queue_free()
	_node_buttons.clear()
	_line_canvas = null
	_tooltip_panel = null

	_apply_class_theme()
	_build_motif_watermark()
	_build_header()
	_build_branch_labels()
	_build_tier_labels()
	_build_lines_canvas()
	_build_node_grid()
	_build_tooltip()

# Recolor the full-screen dim layer to the class's theme color so the panel
# reads as Mage's starfield-purple vs Demon's ember-black at a glance.
func _apply_class_theme() -> void:
	if not dim_layer:
		return
	var theme: Dictionary = _theme_for_class()
	dim_layer.color = theme.get("dim_color", DEFAULT_THEME["dim_color"])

# Large Unicode character in the bottom-right as a class watermark.
# Visible behind the node grid so it doesn't compete with content.
func _build_motif_watermark() -> void:
	var theme: Dictionary = _theme_for_class()
	var motif: String = theme.get("motif", "")
	if motif == "":
		return
	var lab := Label.new()
	lab.text = motif
	lab.add_theme_font_size_override("font_size", 220)
	var c: Color = theme.get("accent_color", Color.WHITE)
	c.a = 0.10
	lab.add_theme_color_override("font_color", c)
	lab.position = Vector2(960, 460)
	lab.size = Vector2(280, 280)
	lab.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lab.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	lab.mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel_root.add_child(lab)

func _build_header() -> void:
	var theme: Dictionary = _theme_for_class()
	var header := PanelContainer.new()
	header.position = Vector2(20, 16)
	header.custom_minimum_size = Vector2(900, HEADER_HEIGHT)
	var hbg := StyleBoxFlat.new()
	hbg.bg_color = Color(0.10, 0.08, 0.06, 0.90)
	hbg.border_color = theme.get("border_color", Color(0.40, 0.30, 0.20, 1.0))
	hbg.border_width_left = 1; hbg.border_width_right = 1
	hbg.border_width_top = 1; hbg.border_width_bottom = 1
	hbg.corner_radius_top_left = 6; hbg.corner_radius_top_right = 6
	hbg.corner_radius_bottom_left = 6; hbg.corner_radius_bottom_right = 6
	header.add_theme_stylebox_override("panel", hbg)
	panel_root.add_child(header)

	var hbox := HBoxContainer.new()
	hbox.add_theme_constant_override("separation", 24)
	header.add_child(hbox)

	var class_label := Label.new()
	var name_text: String = stats.class_def.display_name if stats and stats.class_def else "Unknown"
	class_label.text = name_text + String(theme.get("title_suffix", ""))
	class_label.add_theme_font_size_override("font_size", 26)
	class_label.add_theme_color_override("font_color", theme.get("accent_color", Color(0.95, 0.85, 0.45)))
	hbox.add_child(class_label)
	_header_label = class_label

	var spacer := Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	hbox.add_child(spacer)

	var pts_label := Label.new()
	pts_label.text = "%d unspent" % stats.unspent_skill_points
	pts_label.add_theme_font_size_override("font_size", 22)
	pts_label.add_theme_color_override("font_color", Color(1.00, 0.95, 0.65))
	hbox.add_child(pts_label)
	_points_label = pts_label

	var close_btn := Button.new()
	close_btn.text = "Close [Esc]"
	close_btn.custom_minimum_size = Vector2(120, 36)
	close_btn.pressed.connect(_close)
	hbox.add_child(close_btn)

func _build_branch_labels() -> void:
	if not stats or not stats.class_def:
		return
	var class_id: StringName = stats.class_def.class_id
	var labels: Array = BRANCH_LABELS.get(class_id, [])
	var colors: Array = BRANCH_COLORS.get(class_id, DEFAULT_BRANCH_COLORS)
	for i in range(7):
		var label_text: String = labels[i] if i < labels.size() else "Branch %d" % (i + 1)
		var branch_color: Color = colors[i] if i < colors.size() else BRANCH_LABEL_COLOR
		# Lighten so dark colors (Void, Abyss, Espionage) stay readable on the
		# dark panel background.
		var label_color: Color = branch_color.lerp(Color.WHITE, 0.35)
		var lab := Label.new()
		lab.text = label_text
		lab.add_theme_font_size_override("font_size", 13)
		lab.add_theme_color_override("font_color", label_color)
		lab.position = Vector2(GRID_OFFSET.x + i * COLUMN_WIDTH + (NODE_SIZE.x * 0.5) - 50, GRID_OFFSET.y - 28)
		lab.size = Vector2(100, 20)
		lab.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		panel_root.add_child(lab)

func _build_tier_labels() -> void:
	for tier in range(1, 8):
		var lab := Label.new()
		lab.text = "T%d" % tier
		lab.add_theme_font_size_override("font_size", 12)
		lab.add_theme_color_override("font_color", TIER_LABEL_COLOR)
		lab.position = Vector2(GRID_OFFSET.x - TIER_LABEL_WIDTH, GRID_OFFSET.y + (tier - 1) * ROW_HEIGHT + (NODE_SIZE.y * 0.5) - 8)
		lab.size = Vector2(TIER_LABEL_WIDTH - 8, 16)
		lab.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		panel_root.add_child(lab)

func _build_lines_canvas() -> void:
	# Lines are drawn beneath buttons via a Control with custom _draw.
	_line_canvas = SkillTreeLines.new()
	_line_canvas.tree_ref = tree
	_line_canvas.stats_ref = stats
	_line_canvas.position = Vector2.ZERO
	_line_canvas.size = Vector2(1100, 760)
	_line_canvas.mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel_root.add_child(_line_canvas)

func _build_node_grid() -> void:
	for n in tree.nodes:
		var btn := _make_node_button(n)
		var col: int = int(n.grid_position.x)
		var tier: int = max(1, int(n.grid_position.y))
		btn.position = GRID_OFFSET + Vector2(col * COLUMN_WIDTH, (tier - 1) * ROW_HEIGHT)
		panel_root.add_child(btn)
		_node_buttons[n.id] = btn

func _make_node_button(n: SkillNode) -> Button:
	var btn := Button.new()
	btn.custom_minimum_size = NODE_SIZE
	btn.size = NODE_SIZE
	btn.text = _short_label(n)
	btn.add_theme_font_size_override("font_size", 10)
	btn.clip_text = true
	btn.tooltip_text = n.display_name
	_style_node_button(btn, n)
	btn.pressed.connect(_on_node_clicked.bind(n.id))
	btn.mouse_entered.connect(_on_node_hover.bind(n.id))
	btn.mouse_exited.connect(_on_node_unhover)
	return btn

func _short_label(n: SkillNode) -> String:
	# Wrap long names. Two short lines reads better in the 72px square than one long.
	var name: String = n.display_name
	if name.length() <= 9:
		return name
	# Add a soft break at the first space past midpoint
	var mid: int = int(name.length() / 2)
	var space_idx: int = name.find(" ", mid)
	if space_idx > 0:
		return name.substr(0, space_idx) + "\n" + name.substr(space_idx + 1)
	return name

func _style_node_button(btn: Button, n: SkillNode) -> void:
	var rank: int = stats.get_node_rank(n.id) if stats else 0
	var state_color: Color
	var alpha: float = 1.0
	if rank >= n.max_ranks:
		state_color = COLOR_MAXED
	elif rank > 0:
		state_color = COLOR_PARTIAL
	elif tree.can_unlock(n.id, stats):
		state_color = COLOR_AVAILABLE
	elif stats and stats.level < n.min_level:
		state_color = COLOR_PREREQ_MISS
		alpha = 0.65  # dim level-locked
	else:
		state_color = COLOR_LOCKED
		alpha = 0.55  # dim prereq-locked
	# Branch tint: each column takes a lore-color (Ronin Water = cobalt etc).
	# Border lerps state_color with branch_color so the player reads BOTH
	# "is this purchasable" AND "what branch is this in" at a glance.
	var class_id: StringName = stats.class_def.class_id if stats and stats.class_def else &""
	var branch_colors: Array = BRANCH_COLORS.get(class_id, DEFAULT_BRANCH_COLORS)
	var col_index: int = clamp(int(n.grid_position.x), 0, 6)
	var branch_color: Color = branch_colors[col_index] if col_index < branch_colors.size() else COLOR_LOCKED
	# Maxed nodes lean into the branch color (the achievement); unlocked-but-
	# unspent nodes lean into the state color (so they pop as actionable).
	var border_color: Color
	if rank >= n.max_ranks:
		border_color = branch_color  # full branch color when maxed
	elif rank > 0:
		border_color = branch_color.lerp(state_color, 0.5)
	else:
		border_color = state_color.lerp(branch_color, 0.35)
	border_color.a = alpha
	# Tier-7 capstones: ember override regardless of state, these are LOUD.
	if int(n.grid_position.y) >= 7:
		border_color = branch_color.lerp(COLOR_CAPSTONE, 0.45)
		border_color.a = max(alpha, 0.85)

	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.10, 0.08, 0.06, 0.95)
	style.border_color = border_color
	# Capstones get thicker borders so they read as endgame from a screen away.
	var border_w: int = 3 if int(n.grid_position.y) >= 7 else 2
	style.border_width_left = border_w; style.border_width_right = border_w
	style.border_width_top = border_w; style.border_width_bottom = border_w
	style.corner_radius_top_left = 6; style.corner_radius_top_right = 6
	style.corner_radius_bottom_left = 6; style.corner_radius_bottom_right = 6
	# Hover/pressed/disabled all share the base; override font color instead.
	btn.add_theme_stylebox_override("normal", style)
	btn.add_theme_stylebox_override("hover", style)
	btn.add_theme_stylebox_override("pressed", style)
	btn.add_theme_color_override("font_color", state_color)
	btn.add_theme_color_override("font_hover_color", Color.WHITE)
	# Rank pips on multi-rank nodes, append "(r/max)"
	if n.max_ranks > 1:
		btn.text = "%s\n%d/%d" % [_short_label(n), rank, n.max_ranks]

# ---------------------------------------------------------------
# Tooltip panel, shows on click, anchored bottom-right of the panel.
# ---------------------------------------------------------------
func _build_tooltip() -> void:
	var theme: Dictionary = _theme_for_class()
	_tooltip_panel = PanelContainer.new()
	_tooltip_panel.position = Vector2(960, 110)
	_tooltip_panel.custom_minimum_size = Vector2(280, 480)
	var bg := StyleBoxFlat.new()
	bg.bg_color = Color(0.08, 0.06, 0.05, 0.95)
	bg.border_color = theme.get("border_color", Color(0.55, 0.40, 0.20, 0.90))
	bg.border_width_left = 1; bg.border_width_right = 1
	bg.border_width_top = 1; bg.border_width_bottom = 1
	bg.corner_radius_top_left = 6; bg.corner_radius_top_right = 6
	bg.corner_radius_bottom_left = 6; bg.corner_radius_bottom_right = 6
	bg.content_margin_left = 14; bg.content_margin_right = 14
	bg.content_margin_top = 14; bg.content_margin_bottom = 14
	_tooltip_panel.add_theme_stylebox_override("panel", bg)
	panel_root.add_child(_tooltip_panel)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 10)
	_tooltip_panel.add_child(vbox)

	_tooltip_label = RichTextLabel.new()
	_tooltip_label.bbcode_enabled = true
	_tooltip_label.fit_content = true
	_tooltip_label.custom_minimum_size = Vector2(252, 380)
	_tooltip_label.scroll_active = true
	vbox.add_child(_tooltip_label)

	_tooltip_action_btn = Button.new()
	_tooltip_action_btn.text = "Select a node"
	_tooltip_action_btn.disabled = true
	_tooltip_action_btn.custom_minimum_size = Vector2(0, 38)
	_tooltip_action_btn.pressed.connect(_on_tooltip_action)
	vbox.add_child(_tooltip_action_btn)

	_render_tooltip_empty()

func _render_tooltip_empty() -> void:
	if _tooltip_label:
		_tooltip_label.text = "[color=#807060]Click any node to inspect it.\n\nGold = maxed.\nCream = available.\nAmber = partial.\nGrey = locked (prereq).\nDim red = level-gated.[/color]"
	if _tooltip_action_btn:
		_tooltip_action_btn.text = "Select a node"
		_tooltip_action_btn.disabled = true

func _on_node_clicked(node_id: StringName) -> void:
	_selected_node_id = node_id
	_render_tooltip_for(node_id)
	if _line_canvas:
		_line_canvas.highlight_chain_for(node_id)
		_line_canvas.queue_redraw()

func _on_node_hover(node_id: StringName) -> void:
	if _line_canvas and _selected_node_id == &"":
		_line_canvas.highlight_chain_for(node_id)
		_line_canvas.queue_redraw()

func _on_node_unhover() -> void:
	if _line_canvas and _selected_node_id == &"":
		_line_canvas.highlight_chain_for(&"")
		_line_canvas.queue_redraw()

func _render_tooltip_for(node_id: StringName) -> void:
	var n := tree.get_node_by_id(node_id)
	if not n:
		_render_tooltip_empty()
		return
	var rank: int = stats.get_node_rank(node_id) if stats else 0
	var lines: Array[String] = []
	lines.append("[font_size=18][color=#FFE08A]%s[/color][/font_size]" % n.display_name)
	if n.max_ranks > 1:
		lines.append("[color=#B0A080]Rank %d / %d[/color]" % [rank, n.max_ranks])
	else:
		lines.append("[color=#B0A080]%s[/color]" % ("Unlocked" if rank > 0 else "Not unlocked"))
	lines.append("")
	lines.append("[color=#D5C8B0]%s[/color]" % n.description)
	lines.append("")
	lines.append("[color=#807060]Cost:[/color] [color=#FFE08A]%d skill point%s per rank[/color]" % [n.cost, "" if n.cost == 1 else "s"])
	if n.min_level > 1:
		var ok: bool = stats.level >= n.min_level if stats else false
		var color: String = "#A0E0A0" if ok else "#E07070"
		lines.append("[color=#807060]Min level:[/color] [color=%s]%d[/color]" % [color, n.min_level])
	if n.prerequisites.size() > 0:
		lines.append("[color=#807060]Requires:[/color]")
		for prereq in n.prerequisites:
			var pr_node := tree.get_node_by_id(prereq)
			var pr_name: String = pr_node.display_name if pr_node else String(prereq)
			var pr_rank: int = stats.get_node_rank(prereq) if stats else 0
			var ok: bool = pr_rank >= 1
			var color: String = "#A0E0A0" if ok else "#E07070"
			var mark: String = "[color=%s] · %s%s[/color]" % [color, pr_name, " (yes)" if ok else " (no)"]
			lines.append(mark)
	if _tooltip_label:
		_tooltip_label.text = "\n".join(lines)
	# Action button
	if _tooltip_action_btn:
		var can: bool = tree.can_unlock(node_id, stats)
		if rank >= n.max_ranks:
			_tooltip_action_btn.text = "Maxed"
			_tooltip_action_btn.disabled = true
		elif not can:
			_tooltip_action_btn.text = "Locked"
			_tooltip_action_btn.disabled = true
		else:
			var verb: String = "Upgrade" if rank > 0 else "Unlock"
			_tooltip_action_btn.text = "%s  (-%d sp)" % [verb, n.cost]
			_tooltip_action_btn.disabled = false

func _on_tooltip_action() -> void:
	if _selected_node_id == &"":
		return
	var ok: bool = tree.unlock(_selected_node_id, stats)
	if ok:
		# Notify the player so HUD ability bar / aura can refresh
		if player and player.has_signal("class_changed") and player.stats and player.stats.class_def:
			player.emit_signal("class_changed", player.stats.class_def)
		_refresh_after_purchase()

func _refresh_after_purchase() -> void:
	if _points_label and stats:
		_points_label.text = "%d unspent" % stats.unspent_skill_points
	# Restyle every node, purchasing one can newly-enable downstream ones
	for nid in _node_buttons.keys():
		var btn: Button = _node_buttons[nid]
		var n := tree.get_node_by_id(nid)
		if n:
			_style_node_button(btn, n)
	# Re-render the tooltip to reflect the new rank
	if _selected_node_id != &"":
		_render_tooltip_for(_selected_node_id)
	if _line_canvas:
		_line_canvas.queue_redraw()
