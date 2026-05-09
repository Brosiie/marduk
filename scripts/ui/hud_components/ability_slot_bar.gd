extends Control
class_name AbilitySlotBar

# Q/E/R/F ability slot bar for the kit system. Reads cooldowns directly
# from Player.get_ability_cooldown_remaining() and names from get_ability_slot_info().
# Slot visuals: grey panel, colored icon area, hotkey label, cooldown overlay label.

const HOTKEYS := ["Q", "E", "R", "F"]
const SLOT_SIZE := Vector2(64, 64)
const SLOT_GAP := 8.0
const WATER_COLOR := Color(0.35, 0.60, 1.0, 1.0)
const DEFAULT_COLOR := Color(0.55, 0.55, 0.55, 1.0)
const COOLDOWN_TINT := Color(0.0, 0.0, 0.0, 0.55)

# Element color table matches DamageFloater.ELEMENT_COLORS
const ELEMENT_COLORS := {
	0: Color(0.80, 0.75, 0.50),  # physical
	1: Color(0.45, 0.40, 0.95),  # arcane
	2: Color(1.00, 0.45, 0.20),  # fire
	3: Color(0.65, 0.85, 1.00),  # frost
	4: Color(0.80, 0.85, 1.00),  # lightning
	5: Color(1.00, 0.85, 0.45),  # holy
	6: Color(0.55, 0.20, 0.65),  # shadow
}

var player: Node = null

var _panels: Array[Panel] = []
var _icon_rects: Array[ColorRect] = []
var _cooldown_overlays: Array[ColorRect] = []
var _cooldown_labels: Array[Label] = []
var _name_labels: Array[Label] = []
var _hotkey_labels: Array[Label] = []

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_build_slots()
	_refresh_names()

func _build_slots() -> void:
	var total_w := SLOT_SIZE.x * 4 + SLOT_GAP * 3
	custom_minimum_size = Vector2(total_w, SLOT_SIZE.y + 20)

	for i in range(4):
		var x := i * (SLOT_SIZE.x + SLOT_GAP)

		# Background panel
		var panel := Panel.new()
		panel.position = Vector2(x, 0)
		panel.size = SLOT_SIZE
		var ss := StyleBoxFlat.new()
		ss.bg_color = Color(0.10, 0.08, 0.06, 0.88)
		ss.border_width_left = 1; ss.border_width_right = 1
		ss.border_width_top = 1; ss.border_width_bottom = 1
		ss.border_color = Color(0.35, 0.28, 0.20, 0.9)
		ss.corner_radius_top_left = 4; ss.corner_radius_top_right = 4
		ss.corner_radius_bottom_left = 4; ss.corner_radius_bottom_right = 4
		panel.add_theme_stylebox_override("panel", ss)
		add_child(panel)
		_panels.append(panel)

		# Icon color rect (placeholder until real icons ship). Using
		# .y for height (was .x, latent bug if SLOT_SIZE goes non-square
		# during the polish pass).
		var icon := ColorRect.new()
		icon.position = Vector2(8, 8)
		icon.size = Vector2(SLOT_SIZE.x - 16, SLOT_SIZE.y - 16)
		icon.color = DEFAULT_COLOR
		panel.add_child(icon)
		_icon_rects.append(icon)

		# Cooldown dim overlay (full slot, visible when on cooldown)
		var cd_overlay := ColorRect.new()
		cd_overlay.position = Vector2(0, 0)
		cd_overlay.size = SLOT_SIZE
		cd_overlay.color = COOLDOWN_TINT
		cd_overlay.visible = false
		panel.add_child(cd_overlay)
		_cooldown_overlays.append(cd_overlay)

		# Cooldown countdown label
		var cd_label := Label.new()
		cd_label.position = Vector2(0, SLOT_SIZE.y * 0.25)
		cd_label.size = Vector2(SLOT_SIZE.x, SLOT_SIZE.y * 0.5)
		cd_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		cd_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		cd_label.add_theme_font_size_override("font_size", 18)
		cd_label.add_theme_color_override("font_color", Color(1, 1, 1, 0.95))
		cd_label.visible = false
		panel.add_child(cd_label)
		_cooldown_labels.append(cd_label)

		# Hotkey label (bottom-left)
		var hk := Label.new()
		hk.text = HOTKEYS[i]
		hk.position = Vector2(4, SLOT_SIZE.y - 20)
		hk.size = Vector2(24, 18)
		hk.add_theme_font_size_override("font_size", 13)
		hk.add_theme_color_override("font_color", Color(0.85, 0.80, 0.65, 0.9))
		panel.add_child(hk)
		_hotkey_labels.append(hk)

		# Ability name label (below the slot)
		var name_label := Label.new()
		name_label.position = Vector2(x - 12, SLOT_SIZE.y + 3)
		name_label.size = Vector2(SLOT_SIZE.x + 24, 16)
		name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		name_label.add_theme_font_size_override("font_size", 10)
		name_label.add_theme_color_override("font_color", Color(0.75, 0.70, 0.60, 0.85))
		name_label.clip_text = true
		add_child(name_label)
		_name_labels.append(name_label)

func _refresh_names() -> void:
	if not player:
		return
	for i in range(4):
		var info: Dictionary = player.get_ability_slot_info(i)
		if info.is_empty():
			continue
		_name_labels[i].text = String(info.get("name", ""))
		var elem: int = int(info.get("element", 0))
		_icon_rects[i].color = ELEMENT_COLORS.get(elem, DEFAULT_COLOR)

func _process(_delta: float) -> void:
	if not player:
		# Try to locate the player in the scene
		var players := get_tree().get_nodes_in_group("player")
		if players.size() > 0:
			player = players[0]
			_refresh_names()
		return

	for i in range(4):
		# Explicit `: float` / `: bool` so `:=` infers correctly. Without
		# annotations Godot 4 errors because get_ability_cooldown_remaining
		# returns Variant if the player script hasn't loaded yet.
		var cd: float = player.get_ability_cooldown_remaining(i)
		var on_cd: bool = cd > 0.05
		_cooldown_overlays[i].visible = on_cd
		_cooldown_labels[i].visible = on_cd
		if on_cd:
			_cooldown_labels[i].text = "%.1f" % cd
