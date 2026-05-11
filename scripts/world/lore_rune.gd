extends Area3D
class_name LoreRune

# A discoverable lore stone scattered through zones. Walking into it
# unlocks a CodexRegistry "lore" entry (id = "rune_<rune_id>") and
# pops a small banner with the lore prose. Once-only per save —
# subsequent passes do nothing visible. Glows brighter when undiscovered
# (drawing the player's eye), dims to a steady ember once collected.
#
# Place these in region scenes via:
#   [node name="ApsuFragment" type="Area3D" parent="."]
#   script = preload("res://scripts/world/lore_rune.gd")
#   rune_id = &"apsu_killing"
#   lore_title = "On the Killing of Apsu"
#   lore_body = "Marduk did not strike first..."
#
# Centralizing the "lore_<id>" codex entry registration HERE means
# zone designers don't have to touch CodexRegistry to add new lore.
# Each rune self-registers its entry on _ready.

@export var rune_id: StringName = &""
@export var lore_title: String = ""
@export_multiline var lore_body: String = ""
@export var radius: float = 1.6

var _player_inside: bool = false
var _light: OmniLight3D = null
var _crystal: MeshInstance3D = null

func _ready() -> void:
	add_to_group("lore_rune")
	collision_layer = 0
	collision_mask = 2  # players only
	# Trigger sphere
	var trigger := SphereShape3D.new()
	trigger.radius = radius
	var cs := CollisionShape3D.new()
	cs.shape = trigger
	cs.position = Vector3(0, 0.6, 0)
	add_child(cs)
	# Visual: floating crystal shard above a stone base
	var base := MeshInstance3D.new()
	var base_mesh := CylinderMesh.new()
	base_mesh.top_radius = 0.30
	base_mesh.bottom_radius = 0.42
	base_mesh.height = 0.40
	base.mesh = base_mesh
	var base_mat := StandardMaterial3D.new()
	base_mat.albedo_color = Color(0.22, 0.18, 0.16)
	base_mat.roughness = 0.85
	base.material_override = base_mat
	base.position = Vector3(0, 0.20, 0)
	add_child(base)
	# Crystal: small octahedron-ish (use BoxMesh rotated 45°)
	_crystal = MeshInstance3D.new()
	var crystal_mesh := BoxMesh.new()
	crystal_mesh.size = Vector3(0.30, 0.55, 0.30)
	_crystal.mesh = crystal_mesh
	_crystal.position = Vector3(0, 0.95, 0)
	_crystal.rotation_degrees = Vector3(0, 45, 0)
	_crystal.material_override = _build_crystal_mat(false)
	add_child(_crystal)
	# Glow light
	_light = OmniLight3D.new()
	_light.light_color = Color(0.55, 0.78, 1.0)
	_light.light_energy = 1.4
	_light.omni_range = 5.0
	_light.position = Vector3(0, 0.95, 0)
	add_child(_light)
	# Crystal slow rotate for life
	var tw := _crystal.create_tween().set_loops()
	tw.tween_property(_crystal, "rotation:y", deg_to_rad(45.0 + 360.0), 8.0)
	# Self-register the codex entry so zone designers don't have to
	# touch CodexSeed to add new lore. Idempotent — register() overwrites
	# metadata but preserves unlock state.
	_register_codex_entry()
	# Apply discovered visual if the player has seen this rune before
	var cdx: Node = get_node_or_null("/root/CodexRegistry")
	if cdx and cdx.has_method("is_unlocked") and cdx.is_unlocked(_codex_id()):
		_apply_discovered_visual()
	# Player trigger
	body_entered.connect(_on_body_entered)

func _codex_id() -> StringName:
	return StringName("rune_" + String(rune_id))

func _register_codex_entry() -> void:
	if rune_id == &"":
		return
	var cdx: Node = get_node_or_null("/root/CodexRegistry")
	if cdx == null or not cdx.has_method("register"):
		return
	cdx.register({
		"id": _codex_id(),
		"category": &"lore",
		"display_name": lore_title if lore_title != "" else String(rune_id).capitalize().replace("_", " "),
		"body": lore_body,
		"unlock_hint": "Find a lore-rune in the world.",
	})

func _build_crystal_mat(discovered: bool) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	if discovered:
		# Discovered: warm amber, dimmer, "spent" feel
		m.albedo_color = Color(1.0, 0.78, 0.40, 0.85)
		m.emission = Color(1.0, 0.65, 0.25)
		m.emission_energy_multiplier = 1.0
	else:
		# Undiscovered: bright cool blue, eye-catching
		m.albedo_color = Color(0.55, 0.78, 1.0, 0.85)
		m.emission = Color(0.55, 0.78, 1.0)
		m.emission_energy_multiplier = 2.4
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	return m

func _apply_discovered_visual() -> void:
	if _crystal:
		_crystal.material_override = _build_crystal_mat(true)
	if _light:
		_light.light_color = Color(1.0, 0.65, 0.25)
		_light.light_energy = 0.8

func _on_body_entered(body: Node3D) -> void:
	if not body.is_in_group("player"):
		return
	if _player_inside:
		return
	_player_inside = true
	_collect()

func _collect() -> void:
	var cdx: Node = get_node_or_null("/root/CodexRegistry")
	if cdx == null or not cdx.has_method("unlock"):
		return
	var was_new: bool = bool(cdx.unlock(_codex_id()))
	if not was_new:
		return  # already collected; rune still glows but no toast
	_apply_discovered_visual()
	# Cinematic moment: pulse the light bright + spawn a small particle
	# burst, then announce the lore via the quest banner if available.
	if _light:
		var lt := _light.create_tween()
		lt.tween_property(_light, "light_energy", 4.0, 0.30)
		lt.tween_property(_light, "light_energy", 0.8, 0.5)
	var juice: Node = get_node_or_null("/root/Juice")
	if juice:
		var title: String = lore_title if lore_title != "" else String(rune_id).capitalize().replace("_", " ")
		var subtitle: String = ""
		if lore_body.length() > 0:
			# First sentence as the eyebrow / preview line
			var first_period: int = lore_body.find(". ")
			subtitle = lore_body.substr(0, first_period + 1) if first_period > 0 else lore_body
			if subtitle.length() > 120:
				subtitle = subtitle.substr(0, 117) + "..."
		if juice.has_method("quest_banner"):
			juice.quest_banner("LORE FOUND", title, subtitle, Color(0.55, 0.78, 1.0), 4.0)
		elif juice.has_method("toast"):
			juice.toast("Lore: %s" % title, Color(0.55, 0.78, 1.0), 3.0)
	# Audio: lodestone-like chime
	var ab: Node = get_node_or_null("/root/AudioBus")
	if ab and ab.has_method("play_cue"):
		ab.play_cue(&"lodestone", global_position, -6.0, 1.6)
