extends Area3D
class_name Hurtbox

# Defensive volume attached to a damageable actor. Hitboxes scan for these.
# owner_actor is the node that should receive take_damage().

@export var owner_actor: Node
@export var team: StringName = &"player"

func _ready() -> void:
	# Player hurtbox -> layer 2, Enemy hurtbox -> layer 3 (matches project.godot layer names)
	collision_layer = 1 << 1 if team == &"player" else 1 << 2
	collision_mask = 0  # passive: hitboxes find us, we do not scan
