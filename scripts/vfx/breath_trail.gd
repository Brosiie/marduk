extends Node3D
class_name BreathTrail

# A sweeping colored ribbon spawned in front of the player when a Ronin
# breathing form fires. Modeled on Demon Slayer breathing-style VFX:
#   - Water: wide blue arc, sinuous wave shape
#   - Thunder: tight yellow streak, near-instant dash
#   - Flame: orange wide cone with rolling fire trail
#   - Wind: green spinning curl
#   - Stone: brown slow grounded swing
#   - Mist: white deceptive plume
#   - Sun:  golden 12-segment radiant arc
#   - Moon: red scattered crescents
#
# The trail is just a torus / arc mesh placed at the player's position with
# tweens applied to scale + alpha. Light + tinted material do the heavy
# lifting visually. Frees itself after `duration`.

@export var color: Color = Color(0.50, 0.75, 1.0)       # blue water default
@export var arc_radius: float = 2.6
@export var arc_thickness: float = 0.18
@export var duration: float = 0.45
@export var angle_span_deg: float = 130.0  # how wide the arc reads on screen

var _mi: MeshInstance3D
var _light: OmniLight3D

func _ready() -> void:
	_mi = MeshInstance3D.new()
	var torus := TorusMesh.new()
	torus.inner_radius = max(0.05, arc_radius - arc_thickness)
	torus.outer_radius = arc_radius
	torus.rings = 32
	torus.ring_segments = 8
	_mi.mesh = torus
	# Tilt the torus so it reads as a sword arc (lying on its side relative to
	# the player's forward axis)
	_mi.rotation.x = deg_to_rad(85.0)
	var mat := StandardMaterial3D.new()
	mat.albedo_color = color
	mat.albedo_color.a = 0.8
	mat.emission_enabled = true
	mat.emission = color
	mat.emission_energy_multiplier = 2.5
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	_mi.material_override = mat
	add_child(_mi)
	_light = OmniLight3D.new()
	_light.light_color = color
	_light.light_energy = 2.4
	_light.omni_range = 5.0
	add_child(_light)
	# Animate: sweep + scale up + fade out
	var tw := create_tween()
	tw.set_parallel(true)
	tw.tween_property(_mi, "scale", Vector3.ONE * 1.4, duration).set_trans(Tween.TRANS_CUBIC)
	tw.tween_property(_mi, "modulate:a", 0.0, duration).set_delay(duration * 0.3)
	tw.tween_property(_light, "light_energy", 0.0, duration)
	tw.set_parallel(false)
	tw.tween_callback(queue_free)

# Static factory: spawn a trail in front of `caster` colored by `style_id`.
# Picks color and shape from the Demon Slayer style map.
const STYLES := {
	&"water":   {"color": Color(0.45, 0.75, 1.0),   "radius": 2.8, "duration": 0.55, "thickness": 0.22},
	&"thunder": {"color": Color(0.95, 0.95, 0.40),  "radius": 1.4, "duration": 0.18, "thickness": 0.10},
	&"flame":   {"color": Color(1.00, 0.45, 0.20),  "radius": 3.0, "duration": 0.50, "thickness": 0.30},
	&"wind":    {"color": Color(0.55, 0.95, 0.60),  "radius": 2.4, "duration": 0.45, "thickness": 0.18},
	&"stone":   {"color": Color(0.70, 0.55, 0.40),  "radius": 2.0, "duration": 0.55, "thickness": 0.30},
	&"mist":    {"color": Color(0.92, 0.92, 0.95),  "radius": 2.6, "duration": 0.55, "thickness": 0.22},
	&"sun":     {"color": Color(1.00, 0.85, 0.30),  "radius": 3.4, "duration": 0.65, "thickness": 0.30},
	&"moon":    {"color": Color(0.85, 0.20, 0.20),  "radius": 3.2, "duration": 0.65, "thickness": 0.30},
}

static func spawn(caster: Node3D, style_id: StringName) -> BreathTrail:
	if caster == null or not is_instance_valid(caster):
		return null
	var trail := BreathTrail.new()
	var style: Dictionary = STYLES.get(style_id, STYLES[&"water"])
	trail.color = style.color
	trail.arc_radius = float(style.radius)
	trail.duration = float(style.duration)
	trail.arc_thickness = float(style.thickness)
	# Position one meter forward of the player at sword-arc height
	var fwd: Vector3 = -caster.global_transform.basis.z
	fwd.y = 0
	if fwd.length_squared() < 0.001:
		fwd = Vector3.FORWARD
	fwd = fwd.normalized()
	trail.global_position = caster.global_position + fwd * 1.4 + Vector3(0, 1.4, 0)
	# Yaw to face caster forward
	trail.look_at(caster.global_position + fwd * 5.0, Vector3.UP)
	caster.get_tree().current_scene.add_child(trail)
	return trail
