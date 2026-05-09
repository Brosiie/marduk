extends CanvasLayer
class_name SoulBindingPanel

# Soul-binding ritual UI. Two tabs: Weapon and Armor (chest only in Tier 1).
# Each tab:
#   - If already bound: shows the bound item + sacrifice ledger + warning
#     ("Binding is permanent. Cannot be undone except by prestige.")
#   - If not bound: lets the player pick the item to bind from their bag,
#     pick 5 same-slot sacrifices, and confirm. The 5 sacrifices are
#     consumed from inventory; the bound item gets the sacrifice names
#     inscribed in its lore field; CharacterAppearance.soul_binding records.
#
# See CHARACTER_DESIGN.md § 8.5.4 + DEMON_VISUAL_TRANSFORMATION.md (the
# binding altar is in Ashurim regardless of class).

signal closed

const SACRIFICE_COUNT := 5
const RESPEC_SACRIFICE_COUNT := 10  # respec costs more, it's a deeper sacrifice
const TAB_WEAPON := 0
const TAB_ARMOR := 1
const TAB_RESPEC := 2

# Pending respec sacrifice list (separate from the binding sacrifice list).
var _respec_sacrifices: Array = []

@onready var dim: ColorRect = $Dim if has_node("Dim") else null
@onready var panel: PanelContainer = $Panel if has_node("Panel") else null

var altar: Node = null
var player: Node = null
var _current_tab: int = TAB_WEAPON

# Pending selection state during the binding ritual
var _bind_target: Item = null
var _sacrifices: Array = []  # Array[Item]

func _ready() -> void:
	visible = false
	process_mode = Node.PROCESS_MODE_ALWAYS

func open(p_altar: Node, p_player: Node) -> void:
	altar = p_altar
	player = p_player
	visible = true
	get_tree().paused = true
	_reset_pending()
	_build()

func close() -> void:
	visible = false
	get_tree().paused = false
	closed.emit()

func _input(event: InputEvent) -> void:
	if visible and event.is_action_pressed("ui_cancel"):
		close()

func _reset_pending() -> void:
	_bind_target = null
	_sacrifices = []
	_respec_sacrifices = []

# ───────────────── Respec view ─────────────────
# Sacrifice 10 items of any kind. The altar refunds every spent skill point
# and clears the unlocked skill node ids. The character's level + class are
# preserved; only the skill tree resets.

func _render_respec(content: VBoxContainer) -> void:
	var stats_obj = player.get("stats") if player else null
	if not stats_obj:
		content.add_child(_make_label("The altar cannot read your spirit. Stand closer."))
		return

	var lore := Label.new()
	lore.text = "The altar will undo what you have learned in the way of skills. Your level remains. Your class remains. The points you spent return to you. The cost is ten of anything you carry."
	lore.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	lore.custom_minimum_size = Vector2(680, 0)
	lore.add_theme_font_size_override("font_size", 12)
	lore.add_theme_color_override("font_color", Color(0.85, 0.78, 0.55))
	content.add_child(lore)

	var unspent: int = int(stats_obj.unspent_skill_points)
	var spent_nodes: int = stats_obj.unlocked_skill_node_ids.size() if "unlocked_skill_node_ids" in stats_obj else 0
	var info := Label.new()
	info.text = "Currently: %d unspent · %d ranks invested across the tree." % [unspent, spent_nodes]
	info.add_theme_font_size_override("font_size", 13)
	info.add_theme_color_override("font_color", Color(0.95, 0.85, 0.45))
	content.add_child(info)

	if spent_nodes <= 0:
		content.add_child(_make_label("You have not spent any skill points. There is nothing to undo."))
		return

	# Pick sacrifices (any items in bag, no slot filter)
	var inv = player.get("inventory") if player else null
	if not inv or not "bag" in inv or inv.bag.is_empty():
		content.add_child(_make_label("Your bag is empty. The altar requires offerings."))
		return

	var picked_label := Label.new()
	picked_label.text = "Sacrifices selected: %d / %d" % [_respec_sacrifices.size(), RESPEC_SACRIFICE_COUNT]
	picked_label.add_theme_font_size_override("font_size", 14)
	picked_label.add_theme_color_override("font_color", Color(0.95, 0.85, 0.45))
	content.add_child(picked_label)

	# Group bag by item id for compact display
	var seen: Dictionary = {}
	for stack in inv.bag:
		if not stack or not stack.item:
			continue
		if seen.has(stack.item.id):
			continue
		seen[stack.item.id] = true
		var item = stack.item
		var picked: int = _respec_sacrifices.count(item)
		var btn := Button.new()
		btn.text = "%s%s" % [item.display_name, "  (×%d)" % picked if picked > 0 else ""]
		btn.custom_minimum_size = Vector2(0, 28)
		btn.modulate = Color(1, 1, 1) if picked > 0 else Color(0.78, 0.72, 0.60)
		btn.pressed.connect(func():
			if _respec_sacrifices.size() < RESPEC_SACRIFICE_COUNT:
				_respec_sacrifices.append(item)
				_build()
		)
		content.add_child(btn)

	# Confirm button
	if _respec_sacrifices.size() == RESPEC_SACRIFICE_COUNT:
		var confirm := Button.new()
		confirm.text = "Respec, Refund All Skill Points"
		confirm.custom_minimum_size = Vector2(0, 44)
		confirm.add_theme_font_size_override("font_size", 16)
		confirm.pressed.connect(_confirm_respec)
		content.add_child(confirm)
	else:
		var hint := Label.new()
		hint.text = "Pick %d more sacrifices to enable the respec." % (RESPEC_SACRIFICE_COUNT - _respec_sacrifices.size())
		hint.add_theme_font_size_override("font_size", 12)
		hint.add_theme_color_override("font_color", Color(0.65, 0.60, 0.50))
		content.add_child(hint)

func _confirm_respec() -> void:
	if _respec_sacrifices.size() != RESPEC_SACRIFICE_COUNT:
		return
	var stats_obj = player.get("stats") if player else null
	if not stats_obj:
		return
	# Consume sacrifices
	var inv = player.get("inventory") if player else null
	if inv and inv.has_method("remove_item"):
		for s in _respec_sacrifices:
			inv.remove_item(s.id, 1)
	# Refund: count total ranks across all unlocked nodes (each rank cost = node.cost)
	var refunded: int = 0
	if stats_obj.class_def and stats_obj.class_def.skill_tree:
		for nid in stats_obj.unlocked_skill_node_ids.duplicate():
			var node := stats_obj.class_def.skill_tree.get_node_by_id(nid)
			if node:
				var rank: int = stats_obj.get_node_rank(nid)
				refunded += rank * node.cost
	# Wipe and add back
	stats_obj.unlocked_skill_node_ids = []
	stats_obj.node_ranks = {}
	stats_obj.unspent_skill_points += refunded
	# Toast + flash + audio
	var juice: Node = get_node_or_null("/root/Juice")
	if juice:
		if juice.has_method("flash"):
			juice.flash(Color(0.85, 0.45, 0.95), 0.4, 0.9)
		if juice.has_method("toast"):
			juice.toast("The tree resets. %d skill points returned to your hand." % refunded, Color(0.85, 0.45, 0.95), 3.0)
	var ab: Node = get_node_or_null("/root/AudioBus")
	if ab and ab.has_method("play_cue") and player is Node3D:
		ab.play_cue(&"warp", player.global_position, -4.0, 0.85)
	_respec_sacrifices = []
	_build()

# ───────────────────── Build ─────────────────────

func _build() -> void:
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
	vbox.add_child(header)
	var title := Label.new()
	title.text = "The Binding Altar"
	title.add_theme_font_size_override("font_size", 22)
	title.add_theme_color_override("font_color", Color(0.95, 0.85, 0.45))
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header.add_child(title)
	var close_btn := Button.new()
	close_btn.text = "Walk Away [Esc]"
	close_btn.custom_minimum_size = Vector2(140, 32)
	close_btn.pressed.connect(close)
	header.add_child(close_btn)

	# Lore line
	var lore := Label.new()
	lore.text = "Binding is permanent. The stone will not undo what it does. Bind one weapon. Bind one chest. Sacrifice five of the same kind to seal each."
	lore.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	lore.custom_minimum_size = Vector2(720, 0)
	lore.add_theme_font_size_override("font_size", 12)
	lore.add_theme_color_override("font_color", Color(0.75, 0.70, 0.60))
	vbox.add_child(lore)

	# Tabs
	var tabs := HBoxContainer.new()
	tabs.add_theme_constant_override("separation", 8)
	vbox.add_child(tabs)
	tabs.add_child(_make_tab("Bind Weapon", TAB_WEAPON))
	tabs.add_child(_make_tab("Bind Armor (Chest)", TAB_ARMOR))
	tabs.add_child(_make_tab("Respec Skill Points", TAB_RESPEC))

	# Content
	var scroll := ScrollContainer.new()
	scroll.custom_minimum_size = Vector2(720, 420)
	scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	vbox.add_child(scroll)
	var content := VBoxContainer.new()
	content.add_theme_constant_override("separation", 10)
	content.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(content)

	if _current_tab == TAB_RESPEC:
		_render_respec(content)
		return
	var slot_id: int = 1 if _current_tab == TAB_WEAPON else 4  # Item.Slot.WEAPON_MAIN or CHEST
	var binding = _get_or_create_binding()
	var already_bound: bool = (binding.has_weapon_binding() if _current_tab == TAB_WEAPON else binding.has_armor_binding())

	if already_bound:
		_render_already_bound(content, slot_id)
	else:
		_render_binding_picker(content, slot_id)

func _make_tab(text: String, tab_id: int) -> Button:
	var b := Button.new()
	b.text = text
	b.custom_minimum_size = Vector2(220, 36)
	b.modulate = Color(1, 1, 1) if _current_tab == tab_id else Color(0.65, 0.65, 0.65)
	b.pressed.connect(func():
		_current_tab = tab_id
		_reset_pending()
		_build()
	)
	return b

# ───────────────── Already-bound view ─────────────────

func _render_already_bound(content: VBoxContainer, slot_id: int) -> void:
	var binding = _get_or_create_binding()
	var bound_id: StringName = binding.weapon_item_id if slot_id == 1 else binding.armor_item_id
	var bound_at: int = binding.weapon_bound_at_unix if slot_id == 1 else binding.armor_bound_at_unix
	var ledger: Array = binding.weapon_sacrifice_ledger if slot_id == 1 else binding.armor_sacrifice_ledger

	var registry: Node = get_node_or_null("/root/ItemRegistry")
	var bound_item = registry.get_item(bound_id) if registry and registry.has_method("get_item") else null
	var bound_name: String = bound_item.display_name if bound_item else String(bound_id)

	var title := Label.new()
	title.text = "Bound: %s" % bound_name
	title.add_theme_font_size_override("font_size", 18)
	title.add_theme_color_override("font_color", Color(0.95, 0.85, 0.45))
	content.add_child(title)

	var sub := Label.new()
	sub.text = "Bound on %s. Cannot be dropped, traded, or lost. Scales with your level forever." % Time.get_datetime_string_from_unix_time(bound_at, true)
	sub.add_theme_font_size_override("font_size", 12)
	sub.add_theme_color_override("font_color", Color(0.65, 0.60, 0.50))
	content.add_child(sub)

	if not ledger.is_empty():
		var ledger_label := Label.new()
		ledger_label.text = "Sacrifices in the ledger:"
		ledger_label.add_theme_font_size_override("font_size", 13)
		ledger_label.add_theme_color_override("font_color", Color(0.85, 0.80, 0.60))
		content.add_child(ledger_label)
		for sid in ledger:
			var li := Label.new()
			var sname: String = String(sid)
			if registry and registry.has_method("get_item"):
				var sit = registry.get_item(sid)
				if sit:
					sname = sit.display_name
			li.text = "  · " + sname
			li.add_theme_font_size_override("font_size", 12)
			li.add_theme_color_override("font_color", Color(0.65, 0.60, 0.50))
			content.add_child(li)

# ───────────────── Binding picker view ─────────────────

func _render_binding_picker(content: VBoxContainer, slot_id: int) -> void:
	# Group inventory items by id (so we know how many copies the player has)
	var items: Array = _bag_items_for_slot(slot_id)
	if items.is_empty():
		content.add_child(_make_label("You carry nothing of this kind. Bring more before the altar."))
		return

	# Step 1: pick the item to bind
	var step1 := Label.new()
	step1.text = "1. Pick the item to bind:"
	step1.add_theme_font_size_override("font_size", 14)
	step1.add_theme_color_override("font_color", Color(0.95, 0.85, 0.45))
	content.add_child(step1)

	for item in items:
		var btn := Button.new()
		btn.text = "%s%s" % [item.display_name, "  (selected)" if _bind_target == item else ""]
		btn.custom_minimum_size = Vector2(0, 32)
		btn.modulate = Color(1, 1, 1) if _bind_target == item else Color(0.85, 0.80, 0.65)
		btn.pressed.connect(func():
			_bind_target = item
			# Re-pick sacrifices when target changes (avoid sacrificing the bind target itself)
			_sacrifices = []
			_build()
		)
		content.add_child(btn)

	if not _bind_target:
		return

	# Step 2: pick sacrifices (must be different items of the same slot)
	var step2 := Label.new()
	step2.text = "2. Pick %d sacrifices  (selected: %d / %d):" % [SACRIFICE_COUNT, _sacrifices.size(), SACRIFICE_COUNT]
	step2.add_theme_font_size_override("font_size", 14)
	step2.add_theme_color_override("font_color", Color(0.95, 0.85, 0.45))
	content.add_child(step2)

	for item in items:
		if item == _bind_target:
			continue
		var picked: int = _sacrifices.count(item)
		var btn := Button.new()
		btn.text = "%s%s" % [item.display_name, "  (×%d)" % picked if picked > 0 else ""]
		btn.custom_minimum_size = Vector2(0, 28)
		btn.modulate = Color(1, 1, 1) if picked > 0 else Color(0.78, 0.72, 0.60)
		btn.pressed.connect(func():
			if _sacrifices.size() < SACRIFICE_COUNT:
				_sacrifices.append(item)
				_build()
		)
		content.add_child(btn)

	# Step 3: confirm
	if _sacrifices.size() == SACRIFICE_COUNT:
		var confirm := Button.new()
		confirm.text = "Bind to the Stone"
		confirm.custom_minimum_size = Vector2(0, 44)
		confirm.add_theme_font_size_override("font_size", 16)
		confirm.pressed.connect(_confirm_binding.bind(slot_id))
		content.add_child(confirm)
	else:
		var hint := Label.new()
		hint.text = "Pick %d more sacrifices to enable the binding." % (SACRIFICE_COUNT - _sacrifices.size())
		hint.add_theme_font_size_override("font_size", 12)
		hint.add_theme_color_override("font_color", Color(0.65, 0.60, 0.50))
		content.add_child(hint)

# ───────────────── Confirm logic ─────────────────

func _confirm_binding(slot_id: int) -> void:
	if not _bind_target or _sacrifices.size() != SACRIFICE_COUNT:
		return
	var binding = _get_or_create_binding()
	var sac_ids: Array[StringName] = []
	for s in _sacrifices:
		sac_ids.append(s.id)
	# Consume sacrifices from inventory
	var inv = player.get("inventory") if player else null
	if inv and inv.has_method("remove_item"):
		for s in _sacrifices:
			inv.remove_item(s.id, 1)
	# Record the binding on the appearance
	if slot_id == 1:
		binding.record_weapon_binding(_bind_target.id, sac_ids)
	else:
		binding.record_armor_binding(_bind_target.id, sac_ids)
	# Persist back onto character_appearance
	if player.get("character_appearance") and player.character_appearance:
		player.character_appearance.soul_binding = binding
	# Mark the bound item as soulbound + auto-returns so it can never be lost
	_bind_target.is_soulbound = true
	_bind_target.auto_returns_to_inventory = true
	# Visual + audio confirmation
	var juice: Node = get_node_or_null("/root/Juice")
	if juice:
		if juice.has_method("flash"):
			juice.flash(Color(1.0, 0.85, 0.30), 0.4, 0.9)
		if juice.has_method("toast"):
			juice.toast("Bound: %s. The stone will not let go." % _bind_target.display_name, Color(1.0, 0.85, 0.30), 3.0)
	# Audio: layered cue, level_up arpeggio + lodestone chirp underneath.
	# Reads as ceremony.
	var ab: Node = get_node_or_null("/root/AudioBus")
	if ab and ab.has_method("play_cue") and player is Node3D:
		ab.play_cue(&"level_up", player.global_position, -3.0, 0.7)
		ab.play_cue(&"lodestone", player.global_position, -5.0, 0.5)
	_reset_pending()
	_build()

# ───────────────── Helpers ─────────────────

func _get_or_create_binding():
	var sb_script: GDScript = load("res://scripts/items/soul_binding.gd")
	if not sb_script:
		return null
	if player.get("character_appearance") and player.character_appearance and player.character_appearance.soul_binding:
		return player.character_appearance.soul_binding
	var binding = sb_script.new()
	if player.get("character_appearance") and player.character_appearance:
		player.character_appearance.soul_binding = binding
	return binding

func _bag_items_for_slot(slot_id: int) -> Array:
	var inv = player.get("inventory") if player else null
	if not inv or not "bag" in inv:
		return []
	var seen: Dictionary = {}
	var out: Array = []
	for stack in inv.bag:
		if not stack or not stack.item:
			continue
		if int(stack.item.slot) != slot_id:
			continue
		if seen.has(stack.item.id):
			continue
		seen[stack.item.id] = true
		out.append(stack.item)
	return out

func _make_label(text: String) -> Label:
	var lab := Label.new()
	lab.text = text
	lab.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	lab.custom_minimum_size = Vector2(680, 0)
	lab.add_theme_font_size_override("font_size", 14)
	lab.add_theme_color_override("font_color", Color(0.75, 0.70, 0.60))
	return lab
