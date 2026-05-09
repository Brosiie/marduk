extends Node
class_name ScarManager

# Manages the player's visible combat scars. Attached as a child of Player.
# Listens for hits taken; when a hit takes >= SCAR_THRESHOLD_PCT of max HP,
# spawns a CombatScar and a corresponding visible mesh on the character.
#
# See CHARACTER_DESIGN.md § 8.5.1.

const SCAR_THRESHOLD_PCT: float = 0.25  # hit must take >= 25% max HP
const MAX_VISIBLE_SCARS: int = 16
const HEAL_RATE_PER_SEC: float = 0.0005  # ~30min real-time to fully heal
const BOSS_SCAR_HEAL_RATE: float = 0.0001  # ~3hr real-time, cap at 0.30

const SCAR_LOCATIONS := [&"chest", &"back", &"arm_left", &"arm_right", &"shoulder_left", &"shoulder_right", &"thigh_left", &"thigh_right", &"forearm_left", &"forearm_right"]

# Local body-anchor offsets (relative to the player's MeshRoot). Tier 1, Tier 2 will
# bind to actual skeleton bones via attachment nodes.
const ANCHOR_OFFSETS := {
	&"chest":          Vector3( 0.00, 1.20,  0.18),
	&"back":           Vector3( 0.00, 1.20, -0.18),
	&"arm_left":       Vector3(-0.30, 1.10,  0.00),
	&"arm_right":      Vector3( 0.30, 1.10,  0.00),
	&"shoulder_left":  Vector3(-0.25, 1.45,  0.00),
	&"shoulder_right": Vector3( 0.25, 1.45,  0.00),
	&"thigh_left":     Vector3(-0.15, 0.55,  0.00),
	&"thigh_right":    Vector3( 0.15, 0.55,  0.00),
	&"forearm_left":   Vector3(-0.40, 0.85,  0.05),
	&"forearm_right":  Vector3( 0.40, 0.85,  0.05),
}

@export var owner_player: Node = null
@export var scars_visible: bool = true  # Settings > Display > Show Combat Scars

var scars: Array[CombatScar] = []
var scar_meshes: Dictionary = {}  # scar_id -> MeshInstance3D

signal scar_added(scar: CombatScar)
signal scar_healed(scar_id: StringName)

func _ready() -> void:
	if not owner_player:
		owner_player = get_parent()
	# Listen for damage taken on the player. Player.gd's take_damage calls
	# us via record_hit_taken() which we expose as a public API.
	set_process(true)

func _process(delta: float) -> void:
	# Tick healing on all scars
	var to_remove: Array[StringName] = []
	for scar in scars:
		var rate: float = BOSS_SCAR_HEAL_RATE if scar.is_boss_scar else HEAL_RATE_PER_SEC
		scar.heal_progress = min(1.0, scar.heal_progress + rate * delta)
		# Update visible mesh alpha
		_refresh_scar_visual(scar)
		# Remove fully-healed non-boss scars
		if not scar.is_boss_scar and scar.heal_progress >= 1.0:
			to_remove.append(scar.scar_id)
	for sid in to_remove:
		_remove_scar(sid)

# Public API: called by Player.gd in take_damage() when a hit lands.
func record_hit_taken(damage: float, max_hp: float, source: Node, element: int = 0) -> void:
	if not scars_visible:
		return
	if max_hp <= 0:
		return
	var pct: float = damage / max_hp
	if pct < SCAR_THRESHOLD_PCT:
		return
	# Build scar
	var scar := CombatScar.new()
	scar.scar_id = StringName("scar_%d_%d" % [Time.get_ticks_msec(), randi()])
	scar.location = _pick_location()
	scar.intensity = clamp(pct, SCAR_THRESHOLD_PCT, 1.0)
	scar.element = element
	scar.timestamp = int(Time.get_unix_time_from_system())
	scar.is_boss_scar = source != null and is_instance_valid(source) and source.is_in_group("boss")
	if source and is_instance_valid(source):
		if "boss_id" in source:
			scar.source_id = source.boss_id
		elif "mob_id" in source:
			scar.source_id = source.mob_id
		if "display_name" in source:
			scar.source_display_name = source.display_name
	# Cap visible scars: drop oldest non-boss
	if scars.size() >= MAX_VISIBLE_SCARS:
		_drop_oldest_non_boss()
	scars.append(scar)
	_spawn_scar_visual(scar)
	scar_added.emit(scar)

func _pick_location() -> StringName:
	# Random within the location list, weighted slightly toward chest/arms
	var roll := randf()
	if roll < 0.35:
		return [&"chest", &"back"][randi() % 2]
	elif roll < 0.70:
		return [&"arm_left", &"arm_right", &"forearm_left", &"forearm_right"][randi() % 4]
	else:
		return SCAR_LOCATIONS[randi() % SCAR_LOCATIONS.size()]

func _drop_oldest_non_boss() -> void:
	for i in range(scars.size()):
		if not scars[i].is_boss_scar:
			_remove_scar(scars[i].scar_id)
			return
	# All boss scars: drop the oldest of those
	if scars.size() > 0:
		_remove_scar(scars[0].scar_id)

func _remove_scar(scar_id: StringName) -> void:
	for i in range(scars.size()):
		if scars[i].scar_id == scar_id:
			scars.remove_at(i)
			break
	if scar_meshes.has(scar_id):
		var mesh: Node = scar_meshes[scar_id]
		if is_instance_valid(mesh):
			mesh.queue_free()
		scar_meshes.erase(scar_id)
	scar_healed.emit(scar_id)

func _spawn_scar_visual(scar: CombatScar) -> void:
	if not owner_player:
		return
	var mesh_root: Node = owner_player.get_node_or_null("MeshRoot")
	if not mesh_root:
		return
	# Tier 1: scar = small flat plane with element-tinted unshaded material.
	# Tier 2 will use a shader-based skin overlay for real wound rendering.
	var mi := MeshInstance3D.new()
	mi.name = "Scar_%s" % str(scar.scar_id)
	var quad := QuadMesh.new()
	quad.size = Vector2(0.18 * scar.intensity, 0.05 + 0.05 * scar.intensity)
	mi.mesh = quad
	var mat := StandardMaterial3D.new()
	var color := scar.element_color()
	color.a = scar.visible_alpha()
	mat.albedo_color = color
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	if scar.is_boss_scar:
		# Boss scars get faint emission along the wound, mark of legend
		mat.emission_enabled = true
		mat.emission = color
		mat.emission_energy_multiplier = 0.4
	mi.material_override = mat
	mi.position = ANCHOR_OFFSETS.get(scar.location, Vector3(0, 1.2, 0.18))
	# Random rotation within the body's plane so scars don't all line up
	mi.rotation_degrees.y = randf_range(-25, 25)
	mi.rotation_degrees.z = randf_range(-90, 90)
	mesh_root.add_child(mi)
	scar_meshes[scar.scar_id] = mi

func _refresh_scar_visual(scar: CombatScar) -> void:
	if not scar_meshes.has(scar.scar_id):
		return
	var mi: MeshInstance3D = scar_meshes[scar.scar_id]
	if not is_instance_valid(mi):
		return
	var mat: StandardMaterial3D = mi.material_override
	if mat:
		var color := mat.albedo_color
		color.a = scar.visible_alpha()
		mat.albedo_color = color

# Public API for the Inkstone Sage and codex panel
func active_scars() -> Array[CombatScar]:
	return scars

func boss_scar_count() -> int:
	var n: int = 0
	for s in scars:
		if s.is_boss_scar:
			n += 1
	return n
