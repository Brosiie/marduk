extends Node
class_name ProceduralBreath

# A tiny per-frame mesh transform that fakes a breath / weight-shift
# animation, so a character whose AnimationPlayer never bound any anims
# at least LOOKS alive instead of T-posing forever.
#
# Effect:
#   - Y-scale: gentle 1.0 -> 1.012 -> 1.0 sin oscillation (breath chest swell)
#   - Y-pos: tiny -0.012 -> +0.012 sin oscillation, half-cycle offset (subtle bob)
#   - rotation.y: ±2° slow drift so the silhouette doesn't read as locked
#
# Self-attaches as child of any Node3D (the mesh root). _process modifies
# the parent's transform when no AnimationPlayer is currently playing.
# That last guard means the moment a real anim starts (kill anim, hit
# react, idle from a freshly-bound library) we step out of the way and
# stop fighting the real animation.
#
# Spawn pattern:
#   ProceduralBreath.attach_to(mesh_root, anim_player_or_null)

const BREATH_PERIOD: float = 4.0      # full chest in-out cycle, seconds
const BREATH_AMPLITUDE: float = 0.012  # +/- meters of bob and scale delta
const SWAY_PERIOD: float = 7.5         # slow yaw drift, seconds per full oscillation
const SWAY_AMPLITUDE_DEG: float = 2.0  # degrees of yaw drift each side

var target_mesh: Node3D = null
var anim_player: AnimationPlayer = null  # null = always animate
var _t: float = 0.0
var _phase_offset: float = 0.0
var _baseline_pos: Vector3 = Vector3.ZERO
var _baseline_rot_y: float = 0.0

func _ready() -> void:
	# Random phase offset so two NPCs side-by-side don't breathe in unison.
	_phase_offset = randf() * TAU
	if target_mesh:
		_baseline_pos = target_mesh.position
		_baseline_rot_y = target_mesh.rotation.y

func _process(delta: float) -> void:
	if target_mesh == null or not is_instance_valid(target_mesh):
		queue_free()
		return
	# Step out of the way once a real anim is playing. The bound anim
	# will drive bones / position / rotation directly; we should NOT
	# overwrite it from here or we'd jitter the real animation.
	if anim_player and is_instance_valid(anim_player):
		if anim_player.is_playing() and anim_player.current_animation != "":
			# Restore baseline so the real anim starts from a clean slot
			# instead of inheriting our last sin offset.
			target_mesh.position = _baseline_pos
			target_mesh.rotation.y = _baseline_rot_y
			return
	_t += delta
	# Breath: scale Y + bob position
	var breath_phase: float = (_t / BREATH_PERIOD) * TAU + _phase_offset
	var breath: float = sin(breath_phase)
	target_mesh.scale.y = 1.0 + breath * BREATH_AMPLITUDE
	target_mesh.position = _baseline_pos + Vector3(0, breath * BREATH_AMPLITUDE, 0)
	# Sway: yaw drift, longer period so it doesn't fight the breath
	var sway_phase: float = (_t / SWAY_PERIOD) * TAU + _phase_offset * 0.5
	target_mesh.rotation.y = _baseline_rot_y + deg_to_rad(SWAY_AMPLITUDE_DEG * sin(sway_phase))

# Static spawn helper. Call from any character _ready (after the anim
# loader has had a chance to bind, or in a deferred call so the loader
# wins when it has real anims). Safe no-op if the parent already has
# one of these attached.
static func attach_to(mesh_root: Node3D, anim_player: AnimationPlayer = null) -> void:
	if mesh_root == null or not is_instance_valid(mesh_root):
		return
	if mesh_root.get_node_or_null("ProceduralBreath") != null:
		return
	var b := ProceduralBreath.new()
	b.name = "ProceduralBreath"
	b.target_mesh = mesh_root
	b.anim_player = anim_player
	mesh_root.add_child(b)
