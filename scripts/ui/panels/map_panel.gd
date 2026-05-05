extends Control

# World Map: renders all 14 lodestone tiles in a layout chosen to feel like
# the Marduk continent. Discovered lodestones glow gold and click to teleport;
# undiscovered lodestones show as grey "?" with a hint where they live.
#
# This is the player's progression-gated fast-travel UI. It reads from the
# LodestoneRegistry autoload.

# Approximate continental layout (x, y in 0..1 normalized). North up, west left.
const LODESTONE_LAYOUT := {
	&"sword_vow_dais":      Vector2(0.50, 0.10),
	&"the_cradle":          Vector2(0.50, 0.20),
	&"the_reed_wastes":     Vector2(0.40, 0.30),
	&"lapis_bay":           Vector2(0.18, 0.40),
	&"bone_mountains":      Vector2(0.62, 0.25),
	&"verdant_wound":       Vector2(0.30, 0.55),
	&"ember_steppes":       Vector2(0.55, 0.50),
	&"mist_vale":           Vector2(0.22, 0.65),
	&"shrieking_highlands": Vector2(0.78, 0.40),
	&"sundered_coast":      Vector2(0.10, 0.55),
	&"black_citadel":       Vector2(0.85, 0.65),
	&"fire_stair":          Vector2(0.92, 0.78),
	&"ashurim":             Vector2(0.50, 0.42),  # central hub
	&"babilim":             Vector2(0.50, 0.85),
}

# Maps the LODESTONE_LAYOUT keys (region_id) to the lodestone id used by
# the registry. The registry's LODESTONES catalog stores both, so we look
# up by region_id.
var _registry: Node = null
var _canvas: Control
var _summary: Label

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_PASS
	_registry = get_node_or_null("/root/LodestoneRegistry")

	var title := Label.new()
	title.text = "World Map  ·  Lodestones of Marduk's Realm"
	title.add_theme_font_size_override("font_size", 22)
	add_child(title)

	_summary = Label.new()
	_summary.anchor_left = 0.0
	_summary.anchor_top = 0.06
	_summary.modulate = Color(0.95, 0.85, 0.30)
	add_child(_summary)

	_canvas = Control.new()
	_canvas.anchor_left = 0.05
	_canvas.anchor_top = 0.12
	_canvas.anchor_right = 0.95
	_canvas.anchor_bottom = 0.95
	add_child(_canvas)

	# Background
	var bg := ColorRect.new()
	bg.color = Color(0.08, 0.08, 0.10, 0.95)
	bg.anchor_right = 1.0
	bg.anchor_bottom = 1.0
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_canvas.add_child(bg)

	refresh()

	if _registry and _registry.has_signal("discovered"):
		_registry.discovered.connect(func(_id, _name): refresh())

func refresh() -> void:
	# Clear and rebuild buttons
	for c in _canvas.get_children():
		if c is Button:
			c.queue_free()
	if _registry == null:
		return
	# Build by region/lodestone position
	# Look up each region_id in LODESTONE_LAYOUT against the registry's ids.
	var all_meta: Dictionary = _registry.get_all() if _registry.has_method("get_all") else {}
	var disc_count: int = 0
	for lid in all_meta.keys():
		var meta: Dictionary = all_meta[lid]
		var region_id: StringName = meta.get("region_id", &"")
		var pos: Vector2 = LODESTONE_LAYOUT.get(region_id, Vector2(0.5, 0.5))
		if region_id == &"sword_vow_ruins":
			pos = LODESTONE_LAYOUT.get(&"sword_vow_dais", Vector2(0.5, 0.1))
		var discovered: bool = _registry.is_discovered(lid)
		if discovered:
			disc_count += 1
		_canvas.add_child(_make_node(lid, meta, pos, discovered))
	_summary.text = "Discovered  %d / %d lodestones" % [disc_count, all_meta.size()]

func _make_node(lid: StringName, meta: Dictionary, pos: Vector2, discovered: bool) -> Button:
	var btn := Button.new()
	if discovered:
		btn.text = String(meta.get("name", lid))
		btn.modulate = Color(1.0, 0.85, 0.55)
	else:
		btn.text = "?"
		btn.modulate = Color(0.4, 0.4, 0.45)
	btn.custom_minimum_size = Vector2(160, 36)
	btn.anchor_left = pos.x
	btn.anchor_top = pos.y
	btn.anchor_right = pos.x
	btn.anchor_bottom = pos.y
	btn.offset_left = -80.0
	btn.offset_top = -18.0
	btn.offset_right = 80.0
	btn.offset_bottom = 18.0
	btn.disabled = not discovered
	if discovered:
		btn.tooltip_text = "Travel to %s" % meta.get("name", "")
		btn.pressed.connect(_on_lodestone_pressed.bind(lid))
	else:
		btn.tooltip_text = "Undiscovered. Find this lodestone in the world to attune."
	return btn

func _on_lodestone_pressed(lid: StringName) -> void:
	if _registry and _registry.has_method("travel"):
		_registry.travel(lid)
