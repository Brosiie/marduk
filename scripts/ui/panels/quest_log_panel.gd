extends CanvasLayer
class_name QuestLogPanel

const T := preload("res://scripts/ui/ui_theme.gd")

# Quest log UI. J toggles open/close. Two-tab layout: Active / Completed.
# Active tab lists each quest with its description and per-objective progress
# bar (current/required). Completed tab is the history of turned-in quests.
# Listens to QuestLog signals for live updates.
#
# Attached to the HUD scene like the other panels; consumes the
# `toggle_quests` input action (J, physical_keycode 74).

const TAB_ACTIVE := 0
const TAB_COMPLETED := 1

@onready var dim: ColorRect = $Dim if has_node("Dim") else null
@onready var panel: PanelContainer = $Panel if has_node("Panel") else null

var player: Node = null
var quest_log: Node = null  # QuestLog instance attached to the player
var _current_tab: int = TAB_ACTIVE

# Modal-stack siblings whose visibility blocks J from opening this panel
const SIBLING_MODALS := ["SkillTreePanel", "InkstoneSagePanel", "SacrificePrompt", "SaveSlotPicker", "PauseMenu", "CharacterCreator"]

func _ready() -> void:
	visible = false
	process_mode = Node.PROCESS_MODE_ALWAYS
	_try_bind_player()
	get_tree().node_added.connect(_on_node_added)

func _on_node_added(node: Node) -> void:
	if not player and node.is_in_group("player"):
		player = node
		_resolve_quest_log()

func _try_bind_player() -> void:
	for p in get_tree().get_nodes_in_group("player"):
		if is_instance_valid(p):
			player = p
			_resolve_quest_log()
			break

func _resolve_quest_log() -> void:
	if not player:
		return
	quest_log = player.get_node_or_null("QuestLog")
	# Subscribe for live updates
	if quest_log and quest_log.has_signal("quest_started"):
		if not quest_log.quest_started.is_connected(_on_quest_event):
			quest_log.quest_started.connect(_on_quest_event)
		if not quest_log.quest_progressed.is_connected(_on_quest_progress):
			quest_log.quest_progressed.connect(_on_quest_progress)
		if not quest_log.quest_completed.is_connected(_on_quest_event):
			quest_log.quest_completed.connect(_on_quest_event)
		if not quest_log.quest_turned_in.is_connected(_on_quest_event):
			quest_log.quest_turned_in.connect(_on_quest_event)

func _on_quest_event(_q) -> void:
	if visible:
		_build()

func _on_quest_progress(_q, _i) -> void:
	if visible:
		_build()

func _input(event: InputEvent) -> void:
	if event.is_action_pressed("toggle_quests"):
		_toggle()
	elif event.is_action_pressed("ui_cancel") and visible:
		_close()

func _toggle() -> void:
	if visible:
		_close()
		return
	if _another_modal_visible():
		return
	if not player:
		_try_bind_player()
	if not quest_log:
		_resolve_quest_log()
	_open()

func _another_modal_visible() -> bool:
	for nm in SIBLING_MODALS:
		var n: Node = get_tree().root.get_node_or_null(nm)
		if n and n is CanvasLayer and (n as CanvasLayer).visible:
			return true
	return false

func _open() -> void:
	visible = true
	get_tree().paused = true
	_build()

func _close() -> void:
	visible = false
	get_tree().paused = false

# ───────────────────────── Build ─────────────────────────

func _build() -> void:
	if not panel:
		return
	for c in panel.get_children():
		c.queue_free()

	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", T.PANEL_MARGIN_X)
	margin.add_theme_constant_override("margin_right", T.PANEL_MARGIN_X)
	margin.add_theme_constant_override("margin_top", T.PANEL_MARGIN_Y)
	margin.add_theme_constant_override("margin_bottom", T.PANEL_MARGIN_Y)
	panel.add_child(margin)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", T.HBOX_SEPARATION)
	margin.add_child(vbox)

	vbox.add_child(T.make_header_row("Quest Log", _close, "Close [J / Esc]"))

	# Tabs
	var tabs := HBoxContainer.new()
	tabs.add_theme_constant_override("separation", 8)
	vbox.add_child(tabs)
	var active_count: int = quest_log.active.size() if quest_log else 0
	var completed_count: int = quest_log.completed_ids.size() if quest_log else 0
	tabs.add_child(_make_tab_button("Active (%d)" % active_count, TAB_ACTIVE))
	tabs.add_child(_make_tab_button("Completed (%d)" % completed_count, TAB_COMPLETED))

	# Content
	var scroll := ScrollContainer.new()
	scroll.custom_minimum_size = Vector2(T.CONTENT_WIDTH, T.CARD_INNER_HEIGHT)
	scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	vbox.add_child(scroll)
	var content := VBoxContainer.new()
	content.add_theme_constant_override("separation", T.VBOX_SEPARATION)
	content.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(content)

	if not quest_log:
		content.add_child(_make_label("No quest log attached. Quests won't track until a Player exists in the scene."))
		return

	if _current_tab == TAB_ACTIVE:
		_build_active(content)
	else:
		_build_completed(content)

func _make_tab_button(text: String, tab_id: int) -> Button:
	var b := Button.new()
	b.text = text
	b.custom_minimum_size = Vector2(180, 36)
	b.modulate = Color(1, 1, 1) if _current_tab == tab_id else T.DIM_GRAY
	b.pressed.connect(func():
		_current_tab = tab_id
		_build()
	)
	return b

# ───────────────── Active tab ─────────────────

func _build_active(content: VBoxContainer) -> void:
	if quest_log.active.is_empty():
		content.add_child(_make_label("You have not accepted any quests. Speak to NPCs around the world to take them on."))
		return
	for aq in quest_log.active.values():
		content.add_child(_make_active_quest_card(aq))

func _make_active_quest_card(aq) -> Control:
	var card := PanelContainer.new()
	# Color the border by quest state: green when ready to turn in,
	# warm gold while still active.
	var ready_to_turn_in: bool = false
	if aq and "state" in aq:
		ready_to_turn_in = (aq.state == 3)  # Quest.State.COMPLETED
	var border := T.SUCCESS_GREEN if ready_to_turn_in else T.QUEST_ACTIVE
	card.add_theme_stylebox_override("panel", T.panel_box(border))

	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", T.VBOX_SEPARATION_TIGHT)
	card.add_child(v)

	var name_row := HBoxContainer.new()
	v.add_child(name_row)
	var name_label := Label.new()
	name_label.text = aq.quest.display_name
	name_label.add_theme_font_size_override("font_size", T.FONT_BUTTON)
	name_label.add_theme_color_override("font_color", T.BODY_CREAM)
	name_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	name_row.add_child(name_label)
	if ready_to_turn_in:
		var ready_label := Label.new()
		ready_label.text = "READY TO TURN IN"
		ready_label.add_theme_font_size_override("font_size", T.FONT_TINY)
		ready_label.add_theme_color_override("font_color", T.SUCCESS_GREEN)
		name_row.add_child(ready_label)

	var desc_label := Label.new()
	desc_label.text = aq.quest.description
	desc_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	desc_label.custom_minimum_size = Vector2(T.CARD_INNER_WIDTH, 0)
	desc_label.add_theme_font_size_override("font_size", T.FONT_HINT)
	desc_label.add_theme_color_override("font_color", T.HINT_BRONZE)
	v.add_child(desc_label)

	# Objectives with progress
	for i in range(aq.objectives.size()):
		var obj = aq.objectives[i]
		var obj_row := HBoxContainer.new()
		obj_row.add_theme_constant_override("separation", T.VBOX_SEPARATION)
		v.add_child(obj_row)
		var bullet := Label.new()
		bullet.text = "•" if not obj.is_complete() else "✓"
		bullet.add_theme_color_override("font_color", T.SUCCESS_GREEN if obj.is_complete() else T.QUEST_ACTIVE)
		bullet.custom_minimum_size = Vector2(20, 0)
		obj_row.add_child(bullet)
		var obj_label := Label.new()
		obj_label.text = "%s  (%d / %d)" % [obj.description, obj.current_count, obj.required_count]
		obj_label.add_theme_font_size_override("font_size", T.FONT_HINT)
		obj_label.add_theme_color_override("font_color", T.HINT_BRONZE)
		obj_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		obj_row.add_child(obj_label)

	# Reward summary
	var reward_label := Label.new()
	reward_label.text = "Rewards: %d xp · %d gold%s%s" % [
		aq.quest.xp_reward,
		aq.quest.gold_reward,
		"  ·  %d skill points" % aq.quest.skill_point_reward if aq.quest.skill_point_reward > 0 else "",
		"  ·  %d items" % aq.quest.item_rewards.size() if aq.quest.item_rewards.size() > 0 else "",
	]
	reward_label.add_theme_font_size_override("font_size", T.FONT_TINY)
	reward_label.add_theme_color_override("font_color", T.HINT_BRONZE)
	v.add_child(reward_label)

	return card

# ───────────────── Completed tab ─────────────────

func _build_completed(content: VBoxContainer) -> void:
	if quest_log.completed_ids.is_empty():
		content.add_child(_make_label("Nothing turned in yet. Finish what you started."))
		return
	for qid in quest_log.completed_ids:
		var q: Quest = QuestRegistry.get_quest(qid) if get_node_or_null("/root/QuestRegistry") else null
		if not q:
			continue
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 12)
		var check := Label.new()
		check.text = "✓"
		check.add_theme_color_override("font_color", Color(0.55, 0.95, 0.45))
		check.custom_minimum_size = Vector2(20, 0)
		row.add_child(check)
		var lab := Label.new()
		lab.text = q.display_name
		lab.add_theme_font_size_override("font_size", 14)
		lab.add_theme_color_override("font_color", Color(0.75, 0.85, 0.65))
		row.add_child(lab)
		content.add_child(row)

# ───────────────── Helpers ─────────────────

func _make_label(text: String) -> Label:
	var lab := Label.new()
	lab.text = text
	lab.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	lab.custom_minimum_size = Vector2(680, 0)
	lab.add_theme_font_size_override("font_size", 14)
	lab.add_theme_color_override("font_color", Color(0.75, 0.70, 0.60))
	return lab
