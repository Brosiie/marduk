extends Node3D
class_name BreathingVFX

# Spawn-on-cast VFX for a breathing form. Reads `vfx_color` and `style_id` off the
# BreathingForm to build a particle trail + flash + ground decal that matches the
# style's elemental identity.
#
# Phase 1: simple GPUParticles3D + OmniLight3D placeholder. Phase 2 swaps in
# bespoke shaders + meshes per style.

@export var color: Color = Color.WHITE
@export var lifetime: float = 0.6
@export var trail_amount: int = 80
@export var flash_energy: float = 6.0

@onready var particles: GPUParticles3D = $Particles if has_node("Particles") else null
@onready var flash: OmniLight3D = $Flash if has_node("Flash") else null

func _ready() -> void:
	if particles:
		particles.amount = trail_amount
		particles.lifetime = lifetime
		var mat: ParticleProcessMaterial = particles.process_material
		if mat:
			mat.color = color
		particles.emitting = true
	if flash:
		flash.light_color = color
		flash.light_energy = flash_energy
		var t := create_tween()
		t.tween_property(flash, "light_energy", 0.0, lifetime).set_trans(Tween.TRANS_EXPO)
	get_tree().create_timer(lifetime + 0.4).timeout.connect(queue_free)

# Static helper: spawn a configured VFX at a position with the form's data
static func spawn_for(form: BreathingForm, parent: Node, at_position: Vector3) -> Node:
	var inst := preload("res://scenes/vfx/breathing_vfx.tscn").instantiate()
	if inst is BreathingVFX:
		(inst as BreathingVFX).color = form.vfx_color
	parent.add_child(inst)
	inst.global_position = at_position
	return inst
