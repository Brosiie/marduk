extends StaticBody3D
class_name GatheringNode

# A world-placed gather target: ore vein, tree, herb patch, salvage pile.
# Player interacts (E) when in range, swings their tool, awards items + profession XP.
# Node respawns after a configured cooldown.

enum NodeKind { ORE, TREE, HERB, SALVAGE }

@export var kind: NodeKind = NodeKind.ORE
@export var profession_id: StringName = &"mining"
@export var required_profession_level: int = 1
@export var primary_yield: Item
@export var primary_yield_count_min: int = 1
@export var primary_yield_count_max: int = 3
@export var secondary_yield: Item        # rare bonus material
@export var secondary_yield_chance: float = 0.10
@export var xp_award: int = 15
@export var harvest_time_seconds: float = 1.8
@export var respawn_seconds: float = 25.0
@export var interact_radius: float = 2.0

var depleted: bool = false

signal harvest_started(player: Node)
signal harvest_completed(player: Node)
signal node_respawned

func interact(player: Node) -> bool:
	if depleted or not player:
		return false
	# Check profession level
	var pm: ProfessionManager = player.get_node_or_null("ProfessionManager")
	if not pm:
		return false
	if pm.level_of(profession_id) < required_profession_level:
		return false
	harvest_started.emit(player)
	get_tree().create_timer(harvest_time_seconds).timeout.connect(_complete_harvest.bind(player))
	return true

func _complete_harvest(player: Node) -> void:
	if not player or not is_instance_valid(player) or depleted:
		return
	var pm: ProfessionManager = player.get_node_or_null("ProfessionManager")
	if not pm:
		return
	var count: int = randi_range(primary_yield_count_min, primary_yield_count_max)
	if primary_yield:
		pm.register_gather(profession_id, primary_yield, count, xp_award)
	if secondary_yield and randf() < secondary_yield_chance:
		pm.register_gather(profession_id, secondary_yield, 1, xp_award / 3)
	depleted = true
	visible = false
	harvest_completed.emit(player)
	get_tree().create_timer(respawn_seconds).timeout.connect(_respawn)

func _respawn() -> void:
	depleted = false
	visible = true
	node_respawned.emit()
