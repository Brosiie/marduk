extends CanvasLayer
class_name InkstoneSagePanel

# Multi-action panel for the Inkstone Sage NPC. Replaces the simple
# greeting-only dialogue with three branches:
#   - Speak   , the prose chronicle (the existing _generate_chronicle)
#   - Inscribe, turn earned glyphs into permanent body tattoos
#   - Purify  , remove an inscribed glyph (free; lore-respected)
#
# The Sage instantiates this panel on player interact instead of opening
# the base NPC dialogue.

signal closed

@onready var dim: ColorRect = $Dim if has_node("Dim") else null
@onready var panel: PanelContainer = $Panel if has_node("Panel") else null

var sage: Node = null            # the InkstoneSage NPC instance
var player: Node = null          # bound at open()
var character_id: String = "active"  # multi-character save support is Phase 2

var _tab_speak: Button = null
var _tab_inscribe: Button = null
var _tab_purify: Button = null
var _content_root: VBoxContainer = null
var _close_btn: Button = null
var _current_view: StringName = &"speak"

# Body locations available for inscription. Mirrors GlyphRegistry.BODY_LOCATIONS.
const BODY_LOCATIONS := [&"chest", &"back", &"arm_left", &"arm_right", &"neck", &"face", &"leg_left", &"leg_right"]
const LOCATION_LABELS := {
	&"chest":     "Chest",
	&"back":      "Back",
	&"arm_left":  "Left Arm",
	&"arm_right": "Right Arm",
	&"neck":      "Neck",
	&"face":      "Face",
	&"leg_left":  "Left Leg",
	&"leg_right": "Right Leg",
}

func _ready() -> void:
	visible = false
	process_mode = Node.PROCESS_MODE_ALWAYS

func open(p_sage: Node, p_player: Node) -> void:
	sage = p_sage
	player = p_player
	visible = true
	get_tree().paused = true
	_build_layout()
	_show_view(&"speak")

func _build_layout() -> void:
	if not panel:
		return
	for c in panel.get_children():
		c.queue_free()

	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 24)
	margin.add_theme_constant_override("margin_right", 24)
	margin.add_theme_constant_override("margin_top", 22)
	margin.add_theme_constant_override("margin_bottom", 22)
	panel.add_child(margin)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 14)
	margin.add_child(vbox)

	# Header
	var header := HBoxContainer.new()
	header.add_theme_constant_override("separation", 16)
	vbox.add_child(header)
	var title := Label.new()
	title.text = "The Inkstone Sage"
	title.add_theme_font_size_override("font_size", 22)
	title.add_theme_color_override("font_color", Color(0.95, 0.85, 0.45))
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header.add_child(title)
	_close_btn = Button.new()
	_close_btn.text = "Leave [Esc]"
	_close_btn.custom_minimum_size = Vector2(120, 32)
	_close_btn.pressed.connect(close)
	header.add_child(_close_btn)

	# Tab row
	var tabs := HBoxContainer.new()
	tabs.add_theme_constant_override("separation", 8)
	vbox.add_child(tabs)
	_tab_speak = _make_tab_button("Speak", &"speak")
	_tab_inscribe = _make_tab_button("Inscribe", &"inscribe")
	_tab_purify = _make_tab_button("Purify", &"purify")
	tabs.add_child(_tab_speak)
	tabs.add_child(_tab_inscribe)
	tabs.add_child(_tab_purify)

	# Content area (scrollable)
	var scroll := ScrollContainer.new()
	scroll.custom_minimum_size = Vector2(720, 480)
	scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	vbox.add_child(scroll)
	_content_root = VBoxContainer.new()
	_content_root.add_theme_constant_override("separation", 10)
	_content_root.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(_content_root)

func _make_tab_button(text: String, view: StringName) -> Button:
	var b := Button.new()
	b.text = text
	b.custom_minimum_size = Vector2(140, 36)
	b.pressed.connect(_show_view.bind(view))
	return b

func _show_view(view: StringName) -> void:
	_current_view = view
	_highlight_active_tab()
	if not _content_root:
		return
	for c in _content_root.get_children():
		c.queue_free()
	match view:
		&"speak":    _render_speak()
		&"inscribe": _render_inscribe()
		&"purify":   _render_purify()

func _highlight_active_tab() -> void:
	for tab in [_tab_speak, _tab_inscribe, _tab_purify]:
		if tab:
			tab.modulate = Color(0.65, 0.65, 0.65)
	var active: Button = null
	match _current_view:
		&"speak":    active = _tab_speak
		&"inscribe": active = _tab_inscribe
		&"purify":   active = _tab_purify
	if active:
		active.modulate = Color(1, 1, 1)

# ───────────────────── Speak view ─────────────────────
# Reuses the Sage's existing _generate_chronicle for the prose chronicle.

func _render_speak() -> void:
	if not sage or not sage.has_method("_generate_chronicle"):
		_content_root.add_child(_make_label("The Sage is not in. Try again later."))
		return
	var prose: String = sage._generate_chronicle(player)
	var rt := RichTextLabel.new()
	rt.bbcode_enabled = true
	rt.fit_content = true
	rt.scroll_active = false
	rt.custom_minimum_size = Vector2(700, 420)
	rt.text = "[color=#D5C8B0]%s[/color]" % prose.replace("\n\n", "\n\n")
	_content_root.add_child(rt)

# ───────────────────── Inscribe view ─────────────────────
# Lists earned glyphs not yet inscribed. Each row: glyph name, lore, cost,
# location dropdown, Inscribe button. On click: GlyphRegistry.inscribe_glyph,
# deduct gold + token, refresh.

func _render_inscribe() -> void:
	var gr: Node = get_node_or_null("/root/GlyphRegistry")
	if not gr:
		_content_root.add_child(_make_label("The Inkstone is silent. The registry will not answer."))
		return
	var earned: Array = gr.earned_glyphs(character_id)
	var inscribed: Array = gr.inscribed_glyphs(character_id)
	var inscribed_ids: Dictionary = {}
	for entry in inscribed:
		inscribed_ids[entry.get("glyph_id", &"")] = true

	# Filter to glyphs earned but NOT yet inscribed
	var available: Array = []
	for gid in earned:
		if not inscribed_ids.has(gid):
			available.append(gid)

	if available.is_empty():
		var msg: String = "You carry no marks I can inscribe."
		if earned.size() > 0:
			msg = "Every mark you carry is already part of you. Nothing left to add."
		_content_root.add_child(_make_label(msg))
		return

	var intro := _make_label("Choose a mark. Choose a place on your body. The mark stays for the rest of your life. Choose well.")
	intro.add_theme_color_override("font_color", Color(0.85, 0.78, 0.55))
	_content_root.add_child(intro)

	for gid in available:
		var glyph = gr.get_glyph(gid)
		if glyph:
			_content_root.add_child(_make_glyph_row(glyph, gr))

func _make_glyph_row(glyph: Glyph, gr: Node) -> Control:
	var card := PanelContainer.new()
	var bg := StyleBoxFlat.new()
	bg.bg_color = Color(0.08, 0.06, 0.05, 0.85)
	bg.border_color = glyph.emission_color
	bg.border_color.a = 0.55
	bg.border_width_left = 1; bg.border_width_right = 1
	bg.border_width_top = 1; bg.border_width_bottom = 1
	bg.corner_radius_top_left = 4; bg.corner_radius_top_right = 4
	bg.corner_radius_bottom_left = 4; bg.corner_radius_bottom_right = 4
	bg.content_margin_left = 12; bg.content_margin_right = 12
	bg.content_margin_top = 10; bg.content_margin_bottom = 10
	card.add_theme_stylebox_override("panel", bg)

	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 16)
	card.add_child(row)

	# Left: glyph info
	var info := VBoxContainer.new()
	info.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	info.add_theme_constant_override("separation", 4)
	row.add_child(info)

	var name_label := Label.new()
	name_label.text = glyph.display_name
	name_label.add_theme_font_size_override("font_size", 16)
	name_label.add_theme_color_override("font_color", glyph.emission_color)
	info.add_child(name_label)

	var src_label := Label.new()
	src_label.text = "from %s · cost %d gold + %s token" % [glyph.source_boss_display_name, glyph.inscribe_gold_cost, _short_token(glyph.inscribe_token_id)]
	src_label.add_theme_font_size_override("font_size", 11)
	src_label.add_theme_color_override("font_color", Color(0.65, 0.60, 0.50))
	info.add_child(src_label)

	var lore_label := Label.new()
	lore_label.text = glyph.lore if glyph.lore != "" else glyph.description
	lore_label.add_theme_font_size_override("font_size", 12)
	lore_label.add_theme_color_override("font_color", Color(0.78, 0.72, 0.60))
	lore_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	lore_label.custom_minimum_size = Vector2(400, 0)
	info.add_child(lore_label)

	# Right: location picker + inscribe button
	var actions := VBoxContainer.new()
	actions.custom_minimum_size = Vector2(180, 0)
	actions.add_theme_constant_override("separation", 6)
	row.add_child(actions)

	var loc_label := Label.new()
	loc_label.text = "Where?"
	loc_label.add_theme_font_size_override("font_size", 11)
	loc_label.add_theme_color_override("font_color", Color(0.65, 0.60, 0.50))
	actions.add_child(loc_label)

	var loc_dropdown := OptionButton.new()
	for loc in BODY_LOCATIONS:
		loc_dropdown.add_item(LOCATION_LABELS.get(loc, String(loc).capitalize()))
	actions.add_child(loc_dropdown)

	var inscribe_btn := Button.new()
	inscribe_btn.text = "Inscribe"
	inscribe_btn.custom_minimum_size = Vector2(0, 36)
	inscribe_btn.pressed.connect(func():
		var loc_idx: int = loc_dropdown.selected
		var loc_id: StringName = BODY_LOCATIONS[loc_idx]
		_attempt_inscribe(glyph, loc_id, gr)
	)
	actions.add_child(inscribe_btn)

	return card

func _attempt_inscribe(glyph: Glyph, loc_id: StringName, gr: Node) -> void:
	# Charge cost. Player.inventory.gold for the gold deduction; consume token.
	var inv = player.get("inventory") if player else null
	if not inv:
		return
	# Token check (lenient, if token isn't in inventory, fail with message)
	if glyph.inscribe_token_id != &"":
		if inv.has_method("count_of") and inv.count_of(glyph.inscribe_token_id) < glyph.inscribe_token_count:
			_show_toast("You're missing the %s token. Bring it and return." % _short_token(glyph.inscribe_token_id))
			return
		if inv.has_method("remove_item"):
			inv.remove_item(glyph.inscribe_token_id, glyph.inscribe_token_count)
	# Gold check
	if inv.has_method("gold") and inv.gold() < glyph.inscribe_gold_cost:
		_show_toast("You're %d gold short." % (glyph.inscribe_gold_cost - inv.gold()))
		return
	if inv.has_method("spend_gold"):
		inv.spend_gold(glyph.inscribe_gold_cost)
	# Inscribe
	if gr.inscribe_glyph(character_id, glyph.glyph_id, loc_id):
		_show_toast("The %s settles into your %s." % [glyph.display_name, String(loc_id).replace("_", " ")])
		_show_view(&"inscribe")  # re-render the list

func _short_token(token_id: StringName) -> String:
	if token_id == &"":
		return "no token"
	return String(token_id).replace("_", " ")

# ───────────────────── Purify view ─────────────────────
# Lists inscribed glyphs. Click one to remove it (no cost, the Sage purifies
# in exchange for the privilege of having known the wearer).

func _render_purify() -> void:
	var gr: Node = get_node_or_null("/root/GlyphRegistry")
	if not gr:
		_content_root.add_child(_make_label("The Inkstone is silent."))
		return
	var inscribed: Array = gr.inscribed_glyphs(character_id)
	if inscribed.is_empty():
		_content_root.add_child(_make_label("You carry no inscriptions yet. Nothing to purify."))
		return

	var intro := _make_label("Removing a mark is free. You earned it; you are entitled to set it down. Some say purification is the harder choice.")
	intro.add_theme_color_override("font_color", Color(0.85, 0.78, 0.55))
	_content_root.add_child(intro)

	for entry in inscribed:
		var gid: StringName = entry.get("glyph_id", &"")
		var loc: String = String(entry.get("location", &"chest"))
		var glyph = gr.get_glyph(gid)
		if not glyph:
			continue
		_content_root.add_child(_make_purify_row(glyph, loc, gr))

func _make_purify_row(glyph: Glyph, loc: String, gr: Node) -> Control:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 16)

	var label := Label.new()
	label.text = "%s, on your %s" % [glyph.display_name, LOCATION_LABELS.get(StringName(loc), loc.capitalize())]
	label.add_theme_color_override("font_color", glyph.emission_color)
	label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(label)

	var btn := Button.new()
	btn.text = "Purify"
	btn.custom_minimum_size = Vector2(120, 32)
	btn.pressed.connect(func():
		if gr.has_method("remove_inscribed") and gr.remove_inscribed(character_id, glyph.glyph_id):
			_show_toast("The %s is gone. The skin remembers; the world will not." % glyph.display_name)
			_show_view(&"purify")
	)
	row.add_child(btn)

	return row

# ───────────────────── Helpers ─────────────────────

func _make_label(text: String) -> Label:
	var lab := Label.new()
	lab.text = text
	lab.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	lab.custom_minimum_size = Vector2(700, 0)
	lab.add_theme_font_size_override("font_size", 14)
	lab.add_theme_color_override("font_color", Color(0.85, 0.80, 0.65))
	return lab

func _show_toast(msg: String) -> void:
	var juice: Node = get_node_or_null("/root/Juice")
	if juice and juice.has_method("toast"):
		juice.toast(msg, Color(1.0, 0.85, 0.45), 2.5)

func _input(event: InputEvent) -> void:
	if visible and event.is_action_pressed("ui_cancel"):
		close()

func close() -> void:
	visible = false
	get_tree().paused = false
	closed.emit()
