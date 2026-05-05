extends Area3D
class_name Hitbox

# Active offensive volume spawned during an attack. Activates briefly,
# scans for Hurtboxes, applies damage, despawns or disables.

@export var ability: Ability
@export var attacker_stats: Resource  # PlayerStats or EnemyStats
@export var lifetime: float = 0.15
@export var team: StringName = &"player"  # do not damage same-team hurtboxes

var hit_set: Dictionary = {}  # prevent multi-hits per swing

func _ready() -> void:
	collision_layer = _layer_for_team(team)
	collision_mask = _mask_for_team(team)
	body_entered.connect(_on_body_entered)
	area_entered.connect(_on_area_entered)
	if lifetime > 0.0:
		var t := get_tree().create_timer(lifetime)
		t.timeout.connect(queue_free)

func _layer_for_team(t: StringName) -> int:
	# layer 4 = PlayerHitbox, layer 5 = EnemyHitbox
	return 1 << 3 if t == &"player" else 1 << 4

func _mask_for_team(t: StringName) -> int:
	# scan opposing hurtboxes (player hitbox -> enemy bodies, enemy hitbox -> player body)
	return 1 << 2 if t == &"player" else 1 << 1

func _on_body_entered(body: Node) -> void:
	_try_damage(body)

func _on_area_entered(area: Area3D) -> void:
	if area is Hurtbox:
		_try_damage(area.owner_actor)

func _try_damage(target: Node) -> void:
	if not target or target in hit_set:
		return
	hit_set[target] = true
	var result: DamageCalc.Result = DamageCalc.calc(attacker_stats, target, ability)
	if target.has_method("take_damage"):
		target.take_damage(result.damage, get_parent())
	# Optional: emit a signal so VFX/SFX/floating numbers can react
	if has_node("/root/CombatBus"):
		get_node("/root/CombatBus").emit_hit(target, result, ability)
