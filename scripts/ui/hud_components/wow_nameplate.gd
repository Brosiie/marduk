extends Node3D
class_name WowNameplate

# WoW-style nameplate that floats above an actor (enemy/boss/npc).
#  - Name label at top, color-coded by hostility
#  - Health bar centered (red for hostile, gold for boss, green for friendly)
#  - Optional cast bar below (only visible while target is mid-cast)
#  - Optional target ring (gold rim) when this actor is the player's target
#
# Uses Sprite3D-based UI rather than Label3D so we get a proper bar
# without depth weirdness. The whole node billboards toward the camera.

const NP_WIDTH: float = 1.6
const NP_HEIGHT: float = 0.28
const HP_BAR_HEIGHT: float = 0.18

@export var actor_path: NodePath
@export var hostility: int = 0  # 0 hostile, 1 neutral, 2 friendly, 3 boss
@export var show_cast_bar: bool = false

var actor: Node = null
var _name_label: Label3D
var _hp_label: Label3D
var _hp_back: MeshInstance3D
var _hp_frame: MeshInstance3D  # gold rim around the bar (polish layer)
var _hp_fill: MeshInstance3D
var _hp_fill_mat: StandardMaterial3D
var _hp_flash: MeshInstance3D  # bright white overlay that pulses on damage
var _hp_flash_mat: StandardMaterial3D
var _target_ring: MeshInstance3D
var _status_holder: Node = null
var _status_nodes: Array[Node3D] = []
var _camera_ref: Camera3D = null
var _hp_pct: float = 1.0
var _last_hp: float = -1.0
var _flash_timer: float = 0.0
var _is_targeted: bool = false
var _ring_phase: float = 0.0
# Cached colors so _process doesn't allocate fresh Color structs every
# tick. With 20 mobs on screen the previous version did 40-60 Color
# allocations per frame plus 40 material-property writes. Caching once
# at _ready and only re-applying when the critical-state actually
# changes drops both to zero on steady-state frames.
var _hostility_color_cache: Color = Color.WHITE
const _CRIT_HOT_COLOR: Color = Color(1.0, 0.18, 0.10)
var _critical_state_applied: bool = false  # tracks if we're currently in the <30% HP visual

func _ready() -> void:
	if actor_path != NodePath():
		actor = get_node_or_null(actor_path)
	# Cache the hostility color once. _color_for_hostility is a match()
	# block that allocs a new Color on every call; caching keeps it
	# out of _process.
	_hostility_color_cache = _color_for_hostility()
	# Layered HP bar: gold rim (back) + dark inset (mid) + colored fill
	# (front) + flash overlay (above all). Three-layer compositing
	# reads as a real game HP bar with depth, not just a flat colored
	# rectangle floating in space.
	#
	# Gold rim layer 0.005m behind the dark back so we get a thin
	# gold border showing through. NP_WIDTH+0.06 / HP_HEIGHT+0.04
	# gives a 30mm rim on each side which scales with camera distance.
	_hp_frame = MeshInstance3D.new()
	var rim_mesh := QuadMesh.new()
	rim_mesh.size = Vector2(NP_WIDTH + 0.06, HP_BAR_HEIGHT + 0.04)
	_hp_frame.mesh = rim_mesh
	var rim_mat := StandardMaterial3D.new()
	rim_mat.albedo_color = Color(0.78, 0.62, 0.28, 0.95)
	rim_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	rim_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	rim_mat.no_depth_test = true
	_hp_frame.material_override = rim_mat
	_hp_frame.position = Vector3(0, 0, -0.002)
	add_child(_hp_frame)
	# Panel back (dark inset). Slightly transparent so the gold rim
	# behind it edges through, gives the bar a 'recessed metal' feel.
	_hp_back = MeshInstance3D.new()
	var back_mesh := QuadMesh.new()
	back_mesh.size = Vector2(NP_WIDTH, HP_BAR_HEIGHT)
	_hp_back.mesh = back_mesh
	var back_mat := StandardMaterial3D.new()
	back_mat.albedo_color = Color(0.06, 0.05, 0.07, 0.93)
	back_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	back_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	back_mat.no_depth_test = true
	_hp_back.material_override = back_mat
	add_child(_hp_back)
	# HP fill
	_hp_fill = MeshInstance3D.new()
	var fill_mesh := QuadMesh.new()
	fill_mesh.size = Vector2(NP_WIDTH - 0.04, HP_BAR_HEIGHT - 0.04)
	_hp_fill.mesh = fill_mesh
	_hp_fill_mat = StandardMaterial3D.new()
	_hp_fill_mat.albedo_color = _color_for_hostility()
	_hp_fill_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	# Faint emission so the fill stays visible in volumetric fog. Boss
	# bars (hostility=3) get a stronger pulse so they read as the
	# 'special' health bar in the scene.
	_hp_fill_mat.emission_enabled = true
	_hp_fill_mat.emission = _color_for_hostility()
	_hp_fill_mat.emission_energy_multiplier = 0.55 if hostility != 3 else 1.0
	_hp_fill_mat.no_depth_test = true
	_hp_fill.material_override = _hp_fill_mat
	_hp_fill.position = Vector3(0, 0, 0.001)
	add_child(_hp_fill)
	# Damage-flash overlay: invisible by default, briefly turns bright
	# white when HP drops, then fades. Reads as 'this enemy just took
	# a hit' without needing extra particle/sfx work.
	_hp_flash = MeshInstance3D.new()
	var flash_mesh := QuadMesh.new()
	flash_mesh.size = Vector2(NP_WIDTH - 0.04, HP_BAR_HEIGHT - 0.04)
	_hp_flash.mesh = flash_mesh
	_hp_flash_mat = StandardMaterial3D.new()
	_hp_flash_mat.albedo_color = Color(1, 1, 1, 0)
	_hp_flash_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_hp_flash_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_hp_flash_mat.no_depth_test = true
	_hp_flash.material_override = _hp_flash_mat
	_hp_flash.position = Vector3(0, 0, 0.002)
	add_child(_hp_flash)
	# Small numeric HP label below the bar, only shown for bosses
	# (hostility=3) so regular mobs don't clutter the screen with
	# numbers.
	_hp_label = Label3D.new()
	_hp_label.font_size = 22
	_hp_label.outline_size = 5
	_hp_label.outline_modulate = Color(0, 0, 0, 0.95)
	_hp_label.modulate = Color(1.0, 0.92, 0.55, 1)
	_hp_label.fixed_size = true
	_hp_label.pixel_size = 0.005
	_hp_label.no_depth_test = true
	_hp_label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	_hp_label.position = Vector3(0, -HP_BAR_HEIGHT * 0.7 - 0.04, 0)
	_hp_label.visible = (hostility == 3)
	add_child(_hp_label)
	# Name label, hide entirely if we can't resolve a meaningful name
	_name_label = Label3D.new()
	var resolved_name := _read_actor_name()
	_name_label.text = resolved_name
	_name_label.visible = resolved_name != ""
	_name_label.modulate = _color_for_hostility()
	_name_label.outline_modulate = Color(0, 0, 0, 0.85)
	_name_label.outline_size = 6
	_name_label.font_size = 26
	_name_label.fixed_size = true
	_name_label.pixel_size = 0.005
	_name_label.no_depth_test = true
	_name_label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	_name_label.position = Vector3(0, HP_BAR_HEIGHT * 0.7 + 0.05, 0)
	add_child(_name_label)
	# Target highlight ring (hidden by default)
	_target_ring = MeshInstance3D.new()
	var ring := TorusMesh.new()
	ring.inner_radius = NP_WIDTH * 0.55
	ring.outer_radius = NP_WIDTH * 0.6
	_target_ring.mesh = ring
	_target_ring.rotation.x = deg_to_rad(90.0)
	var ring_mat := StandardMaterial3D.new()
	ring_mat.albedo_color = Color(1.0, 0.85, 0.30, 0.6)
	ring_mat.emission_enabled = true
	ring_mat.emission = Color(1.0, 0.85, 0.30)
	ring_mat.emission_energy_multiplier = 1.6
	ring_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	ring_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	ring_mat.no_depth_test = true
	_target_ring.material_override = ring_mat
	_target_ring.position = Vector3(0, -1.5, 0)  # under the actor's feet
	_target_ring.visible = false
	add_child(_target_ring)
	_attach_status_holder()

func _process(delta: float) -> void:
	if actor == null or not is_instance_valid(actor):
		queue_free()
		return
	# Pull HP if available
	var hp_max: float = float(actor.get("max_hp") if actor.has_method("get") else 100.0)
	var hp_cur: float = float(actor.get("hp") if actor.has_method("get") else hp_max)
	if hp_max <= 0.0:
		hp_max = 1.0
	# Damage-flash trigger: if HP just dropped, kick the white overlay
	# alpha to 0.85 and let _process fade it down. Only fires on a
	# real decrease so spawn-init doesn't trigger it.
	if _last_hp >= 0.0 and hp_cur < _last_hp - 0.1:
		_flash_timer = 0.18
	_last_hp = hp_cur
	if _flash_timer > 0.0:
		_flash_timer = max(0.0, _flash_timer - delta)
		_hp_flash_mat.albedo_color = Color(1, 1, 1, _flash_timer / 0.18 * 0.85)
	else:
		_hp_flash_mat.albedo_color = Color(1, 1, 1, 0)
	_hp_pct = clamp(hp_cur / hp_max, 0.0, 1.0)
	# Scale the fill quad on x-axis
	_hp_fill.scale.x = max(0.001, _hp_pct)
	_hp_fill.position.x = -((1.0 - _hp_pct) * (NP_WIDTH - 0.04) * 0.5)
	# Color shifts to a hotter shade as HP drops below 30%, visual
	# 'critical' cue without needing a separate sfx hookup.
	# Edge-triggered: only update the material when we CROSS the 30%
	# threshold. Steady-state frames skip the assignment so the
	# StandardMaterial3D doesn't dirty itself every tick. With 20+
	# enemies this is the difference between zero per-frame material
	# writes and 40-80 of them.
	var should_be_critical: bool = (_hp_pct < 0.30 and hostility != 2)
	if should_be_critical and not _critical_state_applied:
		_hp_fill_mat.albedo_color = _hostility_color_cache.lerp(_CRIT_HOT_COLOR, 0.6)
		_hp_fill_mat.emission = _CRIT_HOT_COLOR
		_critical_state_applied = true
	elif not should_be_critical and _critical_state_applied:
		_hp_fill_mat.albedo_color = _hostility_color_cache
		_hp_fill_mat.emission = _hostility_color_cache
		_critical_state_applied = false
	# Boss numeric HP readout
	if _hp_label and hostility == 3:
		_hp_label.text = "%d / %d" % [int(hp_cur), int(hp_max)]
	# Pulse the target ring while shown
	if _is_targeted and _target_ring and _target_ring.visible:
		_ring_phase += delta * 2.5
		var pulse: float = 0.5 + 0.5 * sin(_ring_phase)
		_target_ring.scale = Vector3(1.0 + pulse * 0.10, 1.0, 1.0 + pulse * 0.10)
		var ring_mat: StandardMaterial3D = _target_ring.material_override
		if ring_mat:
			ring_mat.emission_energy_multiplier = 1.4 + pulse * 0.8
	# Hide if dead
	visible = hp_cur > 0.0
	# Billboard the whole nameplate
	if _camera_ref == null:
		_camera_ref = get_viewport().get_camera_3d()
	if _camera_ref:
		var cam_pos: Vector3 = _camera_ref.global_position
		var look_pos: Vector3 = cam_pos
		look_pos.y = global_position.y
		look_at(look_pos, Vector3.UP)

# --- API ---

# Toggle the gold target ring under this actor.
func set_targeted(yes: bool) -> void:
	_is_targeted = yes
	_target_ring.visible = yes

func _color_for_hostility() -> Color:
	match hostility:
		0: return Color(0.95, 0.30, 0.25)  # hostile red
		1: return Color(0.95, 0.85, 0.30)  # neutral yellow
		2: return Color(0.40, 0.95, 0.50)  # friendly green
		3: return Color(1.00, 0.65, 0.10)  # boss orange
	return Color.WHITE

func _read_actor_name() -> String:
	if actor == null:
		return ""
	# 1) Explicit display_name (bosses, named NPCs)
	if "display_name" in actor and actor.display_name != "":
		return actor.display_name
	# 2) MobRegistry lookup by mob_id (canonical "Ash-Step Raider" etc.)
	if "mob_id" in actor and actor.mob_id != &"":
		var reg := get_node_or_null("/root/MobRegistry")
		if reg and reg.has_method("get_mob"):
			var m = reg.get_mob(actor.mob_id)
			if m and m.display_name != "":
				return m.display_name
	# 3) NEVER fall back to actor.name. Godot auto-names like
	#    "@CharacterBody3D@3184" leak engine internals into the HUD.
	#    Returning "" tells the caller to hide the label.
	return ""

# --- Status effect icon row ---

const STATUS_ICON_SIZE: float = 0.145
const STATUS_ICON_GAP: float = 0.035
const STATUS_ICON_MAX: int = 5
const STATUS_ICON_TABLE := {
	0: {"color": Color(1.00, 0.45, 0.20), "glyph": "B"},  # BURN
	1: {"color": Color(0.55, 0.95, 0.40), "glyph": "P"},  # POISON
	2: {"color": Color(0.85, 0.18, 0.20), "glyph": "B"},  # BLEED
	3: {"color": Color(0.65, 0.85, 1.00), "glyph": "S"},  # SLOW
	4: {"color": Color(0.95, 0.92, 0.40), "glyph": "!"},  # STUN
	5: {"color": Color(0.35, 0.30, 0.40), "glyph": "?"},  # BLIND
	6: {"color": Color(0.65, 0.30, 0.65), "glyph": "W"},  # WEAKNESS
	7: {"color": Color(1.00, 0.65, 0.10), "glyph": "M"},  # MARK
	8: {"color": Color(0.45, 0.95, 0.55), "glyph": "+"},  # REGEN
	9: {"color": Color(0.65, 0.85, 1.00), "glyph": "F"},  # FROST_VULN
	10: {"color": Color(1.00, 0.45, 0.20), "glyph": "I"}, # IGNITE_VULN
}

func _attach_status_holder() -> void:
	if actor == null or not is_instance_valid(actor):
		return
	_status_holder = actor.get_node_or_null("StatusEffectsHolder") if actor is Node else null
	if _status_holder == null:
		return
	if _status_holder.has_signal("effect_applied") and not _status_holder.effect_applied.is_connected(_on_status_effect_applied):
		_status_holder.effect_applied.connect(_on_status_effect_applied)
	if _status_holder.has_signal("effect_removed") and not _status_holder.effect_removed.is_connected(_on_status_effect_removed):
		_status_holder.effect_removed.connect(_on_status_effect_removed)
	_refresh_status_icons()

func _on_status_effect_applied(_effect: StatusEffect, _stacks: int) -> void:
	_refresh_status_icons()

func _on_status_effect_removed(_effect: StatusEffect) -> void:
	_refresh_status_icons()

func _refresh_status_icons() -> void:
	for n in _status_nodes:
		if is_instance_valid(n):
			n.queue_free()
	_status_nodes.clear()
	if _status_holder == null or not is_instance_valid(_status_holder):
		return
	var active_list: Array = _status_holder.get("active") if "active" in _status_holder else []
	if active_list.is_empty():
		return
	var count: int = min(STATUS_ICON_MAX, active_list.size())
	var total_width: float = count * STATUS_ICON_SIZE + max(0, count - 1) * STATUS_ICON_GAP
	var start_x: float = -total_width * 0.5 + STATUS_ICON_SIZE * 0.5
	for i in range(count):
		var ae = active_list[active_list.size() - 1 - i]
		var icon := _build_status_icon(ae)
		icon.position = Vector3(start_x + float(i) * (STATUS_ICON_SIZE + STATUS_ICON_GAP), _status_icon_y(), 0.012)
		add_child(icon)
		_status_nodes.append(icon)

func _status_icon_y() -> float:
	return -0.43 if hostility == 3 else -0.27

func _build_status_icon(ae) -> Node3D:
	var root := Node3D.new()
	root.name = "StatusIcon_%s" % String(ae.effect.id)
	var entry: Dictionary = STATUS_ICON_TABLE.get(int(ae.effect.kind), {"color": Color(0.6, 0.6, 0.6), "glyph": "?"})
	var color: Color = ae.effect.tint if ae.effect.tint != Color.WHITE else entry["color"]
	var bg := MeshInstance3D.new()
	bg.name = "Back"
	var quad := QuadMesh.new()
	quad.size = Vector2(STATUS_ICON_SIZE, STATUS_ICON_SIZE)
	bg.mesh = quad
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.albedo_color = Color(color.r * 0.35, color.g * 0.35, color.b * 0.35, 0.88)
	mat.emission_enabled = true
	mat.emission = color
	mat.emission_energy_multiplier = 0.85
	mat.no_depth_test = true
	bg.material_override = mat
	root.add_child(bg)
	var rim := MeshInstance3D.new()
	rim.name = "Rim"
	var rim_mesh := QuadMesh.new()
	rim_mesh.size = Vector2(STATUS_ICON_SIZE + 0.02, STATUS_ICON_SIZE + 0.02)
	rim.mesh = rim_mesh
	var rim_mat := StandardMaterial3D.new()
	rim_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	rim_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	rim_mat.albedo_color = Color(color.r, color.g, color.b, 0.45)
	rim_mat.emission_enabled = true
	rim_mat.emission = color
	rim_mat.emission_energy_multiplier = 1.25
	rim_mat.no_depth_test = true
	rim.material_override = rim_mat
	rim.position.z = -0.001
	root.add_child(rim)
	var glyph := Label3D.new()
	glyph.name = "Glyph"
	glyph.text = String(entry["glyph"])
	glyph.font_size = 18
	glyph.pixel_size = 0.004
	glyph.fixed_size = true
	glyph.no_depth_test = true
	glyph.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	glyph.outline_size = 5
	glyph.outline_modulate = Color(0, 0, 0, 0.92)
	glyph.modulate = color.lightened(0.55)
	glyph.position = Vector3(-0.006, -0.018, 0.006)
	root.add_child(glyph)
	if ae.stacks > 1:
		var stack := Label3D.new()
		stack.text = "x%d" % int(ae.stacks)
		stack.font_size = 12
		stack.pixel_size = 0.003
		stack.fixed_size = true
		stack.no_depth_test = true
		stack.billboard = BaseMaterial3D.BILLBOARD_ENABLED
		stack.outline_size = 4
		stack.outline_modulate = Color(0, 0, 0, 0.95)
		stack.modulate = Color(1.0, 0.94, 0.62)
		stack.position = Vector3(STATUS_ICON_SIZE * 0.20, -STATUS_ICON_SIZE * 0.22, 0.008)
		root.add_child(stack)
	return root
