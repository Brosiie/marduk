extends Node3D
class_name Nameplate

# Floating nameplate above an enemy / boss. Shows: prestige badge (if cycle > 0),
# display name, level, HP bar, posture bar (bosses only). Uses a viewport-aligned
# Sprite3D so the camera always sees it face-on.

@export var actor: Node       # the EnemyBase or BossBase
@export var label_scale: float = 0.4
@export var height_offset: float = 2.2
@export var show_posture_bar: bool = false
@export var show_prestige_badge: bool = true

var _label: Label3D
var _hp_bar: Sprite3D
var _hp_fill: ColorRect

func _ready() -> void:
	# Quick: build everything from scratch in code so a single Nameplate.tscn isn't required.
	_label = Label3D.new()
	_label.text = ""
	_label.font_size = 22
	_label.outline_size = 4
	_label.modulate = Color(1, 1, 1)
	_label.no_depth_test = true
	_label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	_label.position = Vector3(0, height_offset, 0)
	add_child(_label)
	if actor:
		actor.tree_exiting.connect(queue_free)

func _process(_delta: float) -> void:
	if not actor or not is_instance_valid(actor):
		queue_free()
		return
	_label.text = _build_text()

func _build_text() -> String:
	var name_part: String = actor.get("display_name") if actor.get("display_name") else actor.name
	var level_part := ""
	if actor.get("encounter_level"):
		level_part = " (Lv %d)" % actor.encounter_level
	var prestige_prefix := ""
	if show_prestige_badge:
		var p := get_node_or_null("/root/Prestige")
		if p and p.current_prestige_level() > 0:
			prestige_prefix = "[P%d] " % p.current_prestige_level()
	var hp_part := ""
	if actor.get("max_hp") and actor.get("hp"):
		hp_part = "\n%d / %d HP" % [int(actor.hp), int(actor.max_hp)]
	return "%s%s%s%s" % [prestige_prefix, name_part, level_part, hp_part]
