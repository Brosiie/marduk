extends Node3D
class_name QuestWaypoint

# A self-managing 3D waypoint that floats above its parent enemy. Renders
# a bobbing gold diamond + label visible across the zone, but only when
# the parent's mob_id / boss_id matches an active QuestLog kill objective.
# When the player has no quest tracking this entity, the waypoint hides
# itself with zero per-frame cost beyond the visibility check.
#
# Attached automatically by EnemyBase._ready and BossBase._ready. Self-
# polls every WAYPOINT_REFRESH_INTERVAL because quests can start/complete
# at runtime; a signal-based refresh would require plumbing into every
# QuestLog instance, while this one-line poll handles the dynamic case
# without coupling.

const WAYPOINT_REFRESH_INTERVAL: float = 0.6
const BOB_PERIOD: float = 1.4
const BOB_AMPLITUDE: float = 0.18
const HEIGHT_ABOVE_PARENT: float = 2.6  # tuned to clear most enemy nameplates

var _diamond: MeshInstance3D
var _label: Label3D
var _refresh_t: float = 0.0
var _t: float = 0.0
var _active: bool = false  # cached so we only run scene-tree polling, not visibility-toggle every frame

func _ready() -> void:
	# Floating gold diamond, billboard so it always faces the camera.
	# QuadMesh + emissive material reads correctly through fog and at
	# distance without needing a custom shader.
	_diamond = MeshInstance3D.new()
	var quad := QuadMesh.new()
	quad.size = Vector2(0.55, 0.55)
	_diamond.mesh = quad
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(1.0, 0.85, 0.30, 0.95)
	mat.emission_enabled = true
	mat.emission = Color(1.0, 0.78, 0.25)
	mat.emission_energy_multiplier = 2.4
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
	mat.no_depth_test = true  # render on top so the marker is visible behind walls, Sekiro/Elden Ring style
	_diamond.material_override = mat
	_diamond.position = Vector3(0, HEIGHT_ABOVE_PARENT, 0)
	# Rotate 45° so the quad reads as a diamond (point-up) instead of a square.
	_diamond.rotation_degrees = Vector3(0, 0, 45)
	add_child(_diamond)

	# Optional small label above the diamond. Stays subtle so the
	# diamond carries the visual weight; the text is the disambiguator
	# when there are multiple targets in view.
	_label = Label3D.new()
	_label.text = "Quest Target"
	_label.modulate = Color(1.0, 0.9, 0.5)
	_label.outline_modulate = Color(0.10, 0.05, 0.0)
	_label.outline_size = 6
	_label.font_size = 22
	_label.position = Vector3(0, HEIGHT_ABOVE_PARENT + 0.55, 0)
	_label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	_label.no_depth_test = true
	add_child(_label)

	visible = false  # start hidden; refresh decides whether to show

func _process(delta: float) -> void:
	_refresh_t += delta
	if _refresh_t >= WAYPOINT_REFRESH_INTERVAL:
		_refresh_t = 0.0
		_refresh_active_state()
	if not _active:
		return
	# Bob: vertical sin oscillation around HEIGHT_ABOVE_PARENT. Using _t
	# instead of Time.get_ticks_msec keeps the bob phased to whatever
	# this Node3D's process delta is (works under slowmo without phase
	# jumps on speed change).
	_t += delta
	if _diamond:
		_diamond.position.y = HEIGHT_ABOVE_PARENT + sin(_t * TAU / BOB_PERIOD) * BOB_AMPLITUDE
		# Slow continuous Z-axis spin so the diamond catches the eye.
		_diamond.rotation.z = (_t * 0.7) + deg_to_rad(45.0)

# Walk QuestLog.active and decide whether the parent entity is a current
# kill objective. Sets `visible` and `_active` so the bob loop short-
# circuits when the marker is dormant.
#
# Reads parent.mob_id / parent.boss_id duck-typed so the same waypoint
# script works for both EnemyBase and BossBase.
func _refresh_active_state() -> void:
	var parent: Node = get_parent()
	if parent == null or not is_instance_valid(parent):
		_active = false
		visible = false
		return
	var parent_id: StringName = &""
	if "boss_id" in parent and parent.get("boss_id") != &"":
		parent_id = StringName(parent.get("boss_id"))
	elif "mob_id" in parent:
		parent_id = StringName(parent.get("mob_id"))
	if parent_id == &"":
		_active = false
		visible = false
		return
	var should_show: bool = _is_target(parent_id)
	if should_show != _active:
		_active = should_show
		visible = should_show

func _is_target(id: StringName) -> bool:
	var player: Node = get_tree().get_first_node_in_group("player")
	if player == null:
		return false
	var qlog: Node = player.get_node_or_null("QuestLog")
	if qlog == null:
		return false
	var active_dict = qlog.get("active") if "active" in qlog else null
	if not (active_dict is Dictionary):
		return false
	for aq in (active_dict as Dictionary).values():
		var state_val = aq.get("state") if "state" in aq else 2
		if int(state_val) != 2:  # Quest.State.ACTIVE
			continue
		var objs = aq.get("objectives") if "objectives" in aq else []
		for obj in (objs as Array):
			if obj == null:
				continue
			var kind: StringName = StringName(obj.get("kind") if "kind" in obj else &"")
			if kind != &"kill":
				continue
			if obj.has_method("is_complete") and obj.is_complete():
				continue
			var tid: StringName = StringName(obj.get("target_id") if "target_id" in obj else &"")
			if tid == id:
				return true
	return false

# Convenience helper, call from EnemyBase._ready or BossBase._ready to
# bolt a waypoint to this entity in one line. Safe to call multiple
# times: the second call is a no-op.
static func attach_to(entity: Node3D) -> void:
	if entity == null or not is_instance_valid(entity):
		return
	if entity.get_node_or_null("QuestWaypoint") != null:
		return
	var w := QuestWaypoint.new()
	w.name = "QuestWaypoint"
	entity.add_child(w)
