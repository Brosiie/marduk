extends "res://scripts/npcs/npc.gd"
class_name BindingAltar

# The Binding Altar in Ashurim. Not a person, a stone slab carved with the
# old soul-binding glyphs. Player interacts (V) to open the SoulBindingPanel
# which shows their inventory, lets them pick a weapon + 5 sacrifices to
# bind, or pick a chest piece + 5 sacrifices.
#
# The altar is "spoken to" the same way as an NPC; the override on
# _open_dialogue spawns the panel instead of the dialogue UI.

const PANEL_SCENE := "res://scenes/ui/panels/soul_binding_panel.tscn"

func _ready() -> void:
	npc_id = &"binding_altar"
	display_name = "The Binding Altar"
	wander_radius = 0.0
	greeting = "Place your weapon. Place five offerings. The stone will know what to do."
	super._ready()

func _open_dialogue() -> void:
	var player: Node = _find_player()
	if not player:
		super._open_dialogue()
		return
	var packed: PackedScene = load(PANEL_SCENE)
	if not packed:
		super._open_dialogue()
		return
	var panel = packed.instantiate()
	get_tree().current_scene.add_child(panel)
	panel.open(self, player)

func _find_player() -> Node:
	for p in get_tree().get_nodes_in_group("player"):
		if is_instance_valid(p):
			return p
	return null
