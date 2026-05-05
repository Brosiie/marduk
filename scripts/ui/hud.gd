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

func _ready() -> void:
	player = get_node_or_null(player_path) if player_path else get_tree().get_first_node_in_group("player")
	if not player:
		push_warning("HUD: no player found")
		return
	player.hp_changed.connect(_on_hp)
	player.mana_changed.connect(_on_mana)
	player.resource_changed.connect(_on_resource)
	if player.stats:
		player.stats.leveled_up.connect(_on_level_up)
		player.stats.max_level_reached.connect(_on_max_level)
		_refresh_all()
		_apply_resource_theme()
		_apply_prestige_badge()

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
	# Quick keyboard hook for ascension. Replace with real menu in Phase 2.
	if event is InputEventKey and event.pressed and event.keycode == KEY_P:
		var p := get_tree().root.get_node_or_null("Prestige")
		if p and player and p.can_prestige(player.stats):
			if p.ascend(player):
				if ascend_prompt:
					ascend_prompt.visible = false
				_refresh_all()
				_apply_prestige_badge()

func _on_hp(cur: float, mx: float) -> void:
	hp_bar.max_value = mx
	hp_bar.value = cur

func _on_mana(cur: float, mx: float) -> void:
	mana_bar.max_value = mx
	mana_bar.value = cur

func _on_level_up(_lvl: int) -> void:
	_refresh_all()

func _on_resource(cur: float, mx: float, _mech: StringName) -> void:
	mana_bar.max_value = max(1.0, mx)
	mana_bar.value = cur

func _apply_resource_theme() -> void:
	if not player or not player.stats or not player.stats.class_def:
		return
	var mech: StringName = player.stats.class_def.resource_mechanic
	var theme: Dictionary = RESOURCE_THEME.get(mech, RESOURCE_THEME[&"mana"])
	mana_bar.modulate = theme["color"]
	if resource_label:
		resource_label.text = theme["label"]
