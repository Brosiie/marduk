extends CanvasLayer
class_name SaveSlotPicker

const T := preload("res://scripts/ui/ui_theme.gd")

# Save / load slot picker. Two modes:
#   - LOAD: opened from start menu Continue or pause menu Load. Picking a
#           non-empty slot calls SaveSystem.load_slot(slot, player) and
#           routes to the saved zone. Empty slots route to the
#           CharacterCreator (treating the empty slot as the destination).
#   - SAVE: opened from the pause menu Save. Picking ANY slot writes the
#           current player to that slot (overwrite confirmation if non-empty).
#
# Delete is offered on every non-empty slot row regardless of mode.

signal slot_loaded(slot: int)
signal slot_saved(slot: int)
signal cancelled()

enum Mode { LOAD, SAVE }

@onready var dim: ColorRect = $Dim if has_node("Dim") else null
@onready var panel: PanelContainer = $Panel if has_node("Panel") else null

var mode: int = Mode.LOAD
var player: Node = null  # required for SAVE mode + LOAD-routes-to-zone

const ZONE_ROUTES := {
	&"sword_vow_ruins":  "res://scenes/world/intros/sword_vow_ruins.tscn",
	&"ash_step_camp":    "res://scenes/world/intros/ash_step_camp.tscn",
	&"sunsworn_chapel":  "res://scenes/world/intros/sunsworn_chapel.tscn",
	&"ashurim":          "res://scenes/world/cities/ashurim.tscn",
}
const FALLBACK_ZONE := "res://scenes/world/intros/sword_vow_ruins.tscn"

func _ready() -> void:
	visible = false
	process_mode = Node.PROCESS_MODE_ALWAYS

func open(p_mode: int = Mode.LOAD, p_player: Node = null) -> void:
	mode = p_mode
	player = p_player
	visible = true
	get_tree().paused = true
	_build()

func _input(event: InputEvent) -> void:
	if visible and event.is_action_pressed("ui_cancel"):
		_close(true)

func _close(was_cancel: bool = false) -> void:
	visible = false
	get_tree().paused = false
	if was_cancel:
		cancelled.emit()

func _build() -> void:
	if not panel:
		return
	for c in panel.get_children():
		c.queue_free()

	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", T.PANEL_MARGIN_X_LG)
	margin.add_theme_constant_override("margin_right", T.PANEL_MARGIN_X_LG)
	margin.add_theme_constant_override("margin_top", T.PANEL_MARGIN_Y_LG)
	margin.add_theme_constant_override("margin_bottom", T.PANEL_MARGIN_Y_LG)
	panel.add_child(margin)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", T.FONT_BUTTON)  # 16
	margin.add_child(vbox)

	vbox.add_child(T.make_header_row(
		"Choose Slot to %s" % ("Load" if mode == Mode.LOAD else "Save"),
		_close.bind(true),
		"Cancel [Esc]"
	))

	# Slot list
	var slots: Array = SaveSystem.list_slots() if SaveSystem else []
	for s in slots:
		vbox.add_child(_make_slot_row(s))

func _make_slot_row(slot_dict: Dictionary) -> Control:
	var slot: int = int(slot_dict.get("slot", 0))
	var is_empty: bool = bool(slot_dict.get("empty", true))

	var card := PanelContainer.new()
	# Empty slots get a dim border, occupied ones get the warm-gold accent.
	var border: Color = Color(0.30, 0.25, 0.20, 0.65) if is_empty else Color(0.55, 0.45, 0.25, 0.85)
	card.add_theme_stylebox_override("panel", T.panel_box(border, Color(0.08, 0.06, 0.05, 0.85)))

	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 16)
	card.add_child(row)

	# Left: slot label + thumbnail (when available). Thumbnail is a 240x135
	# screenshot captured at save time, downscaled here to 96x54 for the row.
	var left := VBoxContainer.new()
	left.custom_minimum_size = Vector2(120, 0)
	left.add_theme_constant_override("separation", 4)
	row.add_child(left)
	var slot_label := Label.new()
	slot_label.text = "Slot %d" % (slot + 1)
	slot_label.add_theme_font_size_override("font_size", T.FONT_BUTTON)
	slot_label.add_theme_color_override("font_color", Color(0.85, 0.78, 0.55))
	left.add_child(slot_label)
	if not is_empty and SaveSystem and SaveSystem.has_method("load_thumbnail"):
		var tex: Texture2D = SaveSystem.load_thumbnail(slot)
		if tex:
			var thumb := TextureRect.new()
			thumb.texture = tex
			thumb.custom_minimum_size = Vector2(112, 63)
			thumb.expand_mode = TextureRect.EXPAND_FIT_WIDTH_PROPORTIONAL
			thumb.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
			left.add_child(thumb)

	# Middle: character info
	var info := VBoxContainer.new()
	info.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	info.add_theme_constant_override("separation", 4)
	row.add_child(info)

	if is_empty:
		var empty_label := Label.new()
		empty_label.text = "(Empty)"
		empty_label.add_theme_color_override("font_color", Color(0.55, 0.50, 0.40))
		info.add_child(empty_label)
	else:
		var name_label := Label.new()
		name_label.text = "%s, level %d" % [slot_dict.get("character_name", ""), slot_dict.get("level", 1)]
		name_label.add_theme_font_size_override("font_size", T.FONT_BUTTON)
		name_label.add_theme_color_override("font_color", Color(0.95, 0.92, 0.80))
		info.add_child(name_label)

		var sub_label := Label.new()
		var class_id: String = String(slot_dict.get("class_id", ""))
		var zone: String = String(slot_dict.get("current_zone", ""))
		var prestige: int = int(slot_dict.get("prestige", 0))
		var prestige_text: String = "  ·  prestige %d" % prestige if prestige > 0 else ""
		sub_label.text = "%s%s%s" % [
			class_id.capitalize() if class_id != "" else "Unknown class",
			"  ·  " + zone.capitalize() if zone != "" else "",
			prestige_text,
		]
		sub_label.add_theme_font_size_override("font_size", T.FONT_HINT)
		sub_label.add_theme_color_override("font_color", Color(0.65, 0.60, 0.50))
		info.add_child(sub_label)

		var saved_label := Label.new()
		saved_label.text = "Last saved: %s" % slot_dict.get("saved_at", "-")
		saved_label.add_theme_font_size_override("font_size", T.FONT_TINY)
		saved_label.add_theme_color_override("font_color", Color(0.55, 0.50, 0.40))
		info.add_child(saved_label)

	# Right: actions
	var actions := VBoxContainer.new()
	actions.custom_minimum_size = Vector2(180, 0)
	actions.add_theme_constant_override("separation", 6)
	row.add_child(actions)

	var primary_btn := Button.new()
	primary_btn.custom_minimum_size = Vector2(0, 32)
	if mode == Mode.LOAD:
		primary_btn.text = "Load" if not is_empty else "New Character"
		primary_btn.pressed.connect(_on_load_pressed.bind(slot, is_empty))
	else:
		primary_btn.text = "Overwrite" if not is_empty else "Save Here"
		primary_btn.pressed.connect(_on_save_pressed.bind(slot, is_empty))
	actions.add_child(primary_btn)

	if not is_empty:
		var del_btn := Button.new()
		del_btn.text = "Delete"
		del_btn.custom_minimum_size = Vector2(0, 28)
		del_btn.pressed.connect(_on_delete_pressed.bind(slot))
		actions.add_child(del_btn)

	return card

# ───────── LOAD mode ─────────

func _on_load_pressed(slot: int, is_empty: bool) -> void:
	if is_empty:
		# Treat the empty slot as the destination for a fresh character
		_close(false)
		get_tree().change_scene_to_file("res://scenes/menus/character_creator.tscn")
		return
	# Non-empty: load the slot's data, route to its zone
	var p := player if player else _find_player()
	if p:
		SaveSystem.load_slot(slot, p)
	# Route based on saved zone metadata
	var summary: Dictionary = SaveSystem.read_slot_summary(slot)
	var zone_id: StringName = StringName(String(summary.get("current_zone", "")))
	var path: String = ZONE_ROUTES.get(zone_id, FALLBACK_ZONE)
	slot_loaded.emit(slot)
	_close(false)
	get_tree().change_scene_to_file(path)

# ───────── SAVE mode ─────────

func _on_save_pressed(slot: int, is_empty: bool) -> void:
	# Non-empty slots get a brief inline confirmation. Could promote to a
	# proper modal later, for now the row's bg-tint shift signals overwrite.
	if not is_empty and not _is_confirming_overwrite(slot):
		_mark_confirming_overwrite(slot)
		return
	var p := player if player else _find_player()
	if not p:
		return
	if SaveSystem.save_slot(slot, p):
		slot_saved.emit(slot)
		_show_toast("Saved to slot %d." % (slot + 1))
		_close(false)

# Overwrite confirmation, the second click within 3s actually saves.
var _confirming_slot: int = -1
var _confirming_at: float = 0.0

func _is_confirming_overwrite(slot: int) -> bool:
	var now := Time.get_ticks_msec() / 1000.0
	return _confirming_slot == slot and (now - _confirming_at) < 3.0

func _mark_confirming_overwrite(slot: int) -> void:
	_confirming_slot = slot
	_confirming_at = Time.get_ticks_msec() / 1000.0
	_show_toast("Click again to overwrite slot %d." % (slot + 1))

# ───────── Delete ─────────

func _on_delete_pressed(slot: int) -> void:
	if not _is_confirming_delete(slot):
		_mark_confirming_delete(slot)
		return
	if SaveSystem.delete_slot(slot):
		_show_toast("Slot %d deleted." % (slot + 1))
		_build()  # re-render

var _confirming_delete_slot: int = -1
var _confirming_delete_at: float = 0.0

func _is_confirming_delete(slot: int) -> bool:
	var now := Time.get_ticks_msec() / 1000.0
	return _confirming_delete_slot == slot and (now - _confirming_delete_at) < 3.0

func _mark_confirming_delete(slot: int) -> void:
	_confirming_delete_slot = slot
	_confirming_delete_at = Time.get_ticks_msec() / 1000.0
	_show_toast("Click Delete again to confirm slot %d." % (slot + 1))

func _find_player() -> Node:
	for p in get_tree().get_nodes_in_group("player"):
		if is_instance_valid(p):
			return p
	return null

func _show_toast(msg: String) -> void:
	var juice: Node = get_node_or_null("/root/Juice")
	if juice and juice.has_method("toast"):
		juice.toast(msg, Color(0.95, 0.85, 0.45), 2.5)
	else:
		print("[SaveSlotPicker] %s" % msg)
