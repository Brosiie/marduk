extends "res://scripts/npcs/npc.gd"
class_name TrainerNPC

# Class trainer: pressing V opens the Skills tab so the player can spend
# skill points on the next breathing form / spell / talent. Yellow
# graduation-cap style marker above the head when the player has unspent
# skill points.

@export var trains_class_id: StringName = &"ronin"

func _ready() -> void:
	# Trainers stand fixed at their training spot. Override before super so
	# the wander state machine in npc.gd respects this from frame 0.
	wander_radius = 0.0
	super._ready()
	# Override default name color to make trainers visually distinct
	if _label3d:
		_label3d.modulate = Color(0.55, 0.85, 1.00)  # blue-ish for trainers
	# Replace the quest-mark with a "K" symbol for "Trainer"
	if _quest_marker:
		_quest_marker.text = "K"
		_quest_marker.modulate = Color(0.55, 0.85, 1.00)
		_quest_marker.visible = _player_has_unspent_points()

func _process(delta: float) -> void:
	if _quest_marker:
		_quest_marker.visible = _player_has_unspent_points()

func _player_has_unspent_points() -> bool:
	var p := get_tree().get_first_node_in_group("player") if get_tree() else null
	if p == null or not ("stats" in p and p.stats):
		return false
	var pts = p.stats.get("skill_points") if p.stats.has_method("get") else 0
	return int(pts) > 0

func _open_dialogue() -> void:
	# Skip the default greeting panel, open the skills tab directly.
	var hud = get_tree().get_first_node_in_group("hud")
	if hud == null:
		return
	var menu = hud.get("menu_panel") if hud.has_method("get") else null
	if menu and menu.has_method("open"):
		menu.open(&"skills")
		# Light SFX
		var ab = get_node_or_null("/root/AudioBus")
		if ab and ab.has_method("play_cue"):
			ab.play_cue(&"button", global_position, -8.0, 1.0)
