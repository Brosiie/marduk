extends StaticBody3D
class_name LegacyQuestNPC

# Legacy NPC implementation kept for compatibility. The active NPC class
# lives in scripts/npcs/npc.gd which has Mixamo mesh attachment,
# animation library merge, and a dialogue panel. Renamed from `NPC` to
# avoid class_name collision; nothing currently extends this.
#
# Original purpose: carries a Dialogue resource, optionally offers Quests,
# optionally vends items. Player triggers via E key when in interact_radius.

@export var id: StringName = &""
@export var display_name: String = ""
@export var dialogue: Dialogue
@export var quests_offered: Array[Quest] = []
@export var vendor_inventory: Array[Item] = []
@export var interact_radius: float = 2.5
@export var faction: StringName = &""

@export var sprite_or_mesh: Node3D  # optional visual

signal interact_requested(npc: NPC)
signal dialogue_started(dialogue: Dialogue)

var _player_in_range: bool = false

func _ready() -> void:
	add_to_group("npc")

func _process(_delta: float) -> void:
	# Cheap proximity check; replace with Area3D for performance at scale
	var player := get_tree().get_first_node_in_group("player")
	if player:
		var dist: float = global_position.distance_to(player.global_position)
		_player_in_range = dist <= interact_radius
		if _player_in_range and Input.is_action_just_pressed("interact"):
			start_interaction()

func start_interaction() -> void:
	interact_requested.emit(self)
	if dialogue:
		dialogue_started.emit(dialogue)

func offer_quests_for(class_id: StringName, player_level: int) -> Array[Quest]:
	var arr: Array[Quest] = []
	for q in quests_offered:
		var ok := true
		if q.class_restriction.size() > 0 and not (class_id in q.class_restriction):
			ok = false
		if q.min_level > player_level:
			ok = false
		if ok:
			arr.append(q)
	return arr
