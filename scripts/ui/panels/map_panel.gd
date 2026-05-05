extends Control

# World Map: renders all 13 region tiles in a layout chosen to feel like the
# Marduk continent. Click a region to fast-travel (when WorldManager exposes
# `travel_to(region_id)`); otherwise just shows current region highlighted.

# Approximate continental layout (x, y) — north is up, west is left.
const REGION_LAYOUT := {
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

var _canvas: Control

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_PASS

	var title := Label.new()
	title.text = "World Map  ·  Marduk's Realm"
	title.add_theme_font_size_override("font_size", 22)
	add_child(title)

	_canvas = Control.new()
	_canvas.anchor_left = 0.05
	_canvas.anchor_top = 0.10
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

	# Region tiles
	for region_id in REGION_LAYOUT.keys():
		var btn := Button.new()
		btn.text = String(region_id).replace("_", " ").capitalize()
		btn.custom_minimum_size = Vector2(150, 36)
		var pos: Vector2 = REGION_LAYOUT[region_id]
		btn.anchor_left = pos.x
		btn.anchor_top = pos.y
		btn.anchor_right = pos.x
		btn.anchor_bottom = pos.y
		btn.offset_left = -75.0
		btn.offset_top = -18.0
		btn.offset_right = 75.0
		btn.offset_bottom = 18.0
		btn.pressed.connect(_on_region_pressed.bind(region_id))
		_canvas.add_child(btn)

	refresh()

func refresh() -> void:
	pass

func _on_region_pressed(region_id: StringName) -> void:
	# Try WorldManager.travel_to; if not available, scene-change directly.
	var wm = get_node_or_null("/root/WorldManager")
	if wm and wm.has_method("travel_to"):
		wm.travel_to(region_id)
		return
	# Fallback: load scenes/world/regions/<id>.tscn directly
	var path := "res://scenes/world/regions/%s.tscn" % String(region_id)
	if ResourceLoader.exists(path):
		get_tree().change_scene_to_file(path)
