extends Area3D
class_name Lodestone

# A discoverable fast-travel anchor. Each region scene drops one. First time
# the player walks in and presses V it registers with LodestoneRegistry; from
# then on the World Map can teleport here.
#
# Visual: a tall blue obelisk with a glowing crystal at the top. Color shifts
# from cool grey-blue to warm amber once discovered.

@export var lodestone_id: StringName = &""
@export var display_name: String = ""

var _player_inside: bool = false
var _label3d: Label3D
var _crystal_mesh: MeshInstance3D
var _light: OmniLight3D

func _ready() -> void:
	add_to_group("lodestone")
	collision_layer = 64
	collision_mask = 2  # players only
	# Trigger
	var sphere := SphereShape3D.new()
	sphere.radius = 1.6
	var cs := CollisionShape3D.new()
	cs.shape = sphere
	cs.position = Vector3(0, 1.4, 0)
	add_child(cs)
	# Obelisk base
	var base := MeshInstance3D.new()
	var box := BoxMesh.new()
	box.size = Vector3(0.6, 1.6, 0.6)
	base.mesh = box
	var base_mat := StandardMaterial3D.new()
	base_mat.albedo_color = Color(0.18, 0.18, 0.22)
	base_mat.roughness = 0.7
	base.material_override = base_mat
	base.position = Vector3(0, 0.8, 0)
	add_child(base)
	# Crystal at the top
	_crystal_mesh = MeshInstance3D.new()
	var crystal := SphereMesh.new()
	crystal.radius = 0.35
	crystal.height = 0.8
	_crystal_mesh.mesh = crystal
	_crystal_mesh.material_override = _build_crystal_mat(false)
	_crystal_mesh.position = Vector3(0, 1.9, 0)
	add_child(_crystal_mesh)
	# Glow light
	_light = OmniLight3D.new()
	_light.light_color = Color(0.5, 0.7, 1.0)
	_light.light_energy = 1.2
	_light.omni_range = 6.0
	_light.position = Vector3(0, 1.9, 0)
	add_child(_light)
	# Floating label (only shows once you're close)
	_label3d = Label3D.new()
	_label3d.text = "Lodestone — V to attune"
	_label3d.modulate = Color(0.85, 0.85, 1.0)
	_label3d.position = Vector3(0, 2.6, 0)
	_label3d.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	_label3d.visible = false
	add_child(_label3d)

	body_entered.connect(_on_body_entered)
	body_exited.connect(_on_body_exited)
	# Recolor if already discovered on scene load
	var registry := get_node_or_null("/root/LodestoneRegistry")
	if registry and registry.is_discovered(lodestone_id):
		_apply_discovered_visual()

func _build_crystal_mat(discovered: bool) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	if discovered:
		m.albedo_color = Color(1.0, 0.75, 0.30, 0.85)
		m.emission = Color(1.0, 0.65, 0.20)
		m.emission_energy_multiplier = 2.0
	else:
		m.albedo_color = Color(0.50, 0.70, 1.0, 0.7)
		m.emission = Color(0.5, 0.7, 1.0)
		m.emission_energy_multiplier = 1.0
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	return m

func _apply_discovered_visual() -> void:
	if _crystal_mesh:
		_crystal_mesh.material_override = _build_crystal_mat(true)
	if _light:
		_light.light_color = Color(1.0, 0.65, 0.20)
		_light.light_energy = 2.0
	if _label3d:
		_label3d.text = display_name
		_label3d.modulate = Color(1.0, 0.85, 0.55)

func _process(delta: float) -> void:
	# Slow rotate the crystal so it feels alive
	if _crystal_mesh:
		_crystal_mesh.rotation.y += delta * 0.6

func _on_body_entered(body: Node3D) -> void:
	if not body.is_in_group("player"):
		return
	_player_inside = true
	if _label3d:
		_label3d.visible = true

func _on_body_exited(body: Node3D) -> void:
	if not body.is_in_group("player"):
		return
	_player_inside = false
	if _label3d:
		_label3d.visible = false

func _unhandled_input(event: InputEvent) -> void:
	if not _player_inside:
		return
	if event.is_action_pressed("interact"):
		_attune()

func _attune() -> void:
	var registry := get_node_or_null("/root/LodestoneRegistry")
	if registry == null:
		return
	if registry.is_discovered(lodestone_id):
		return
	if registry.discover(lodestone_id):
		_apply_discovered_visual()
		# Tween light pulse
		var tw := create_tween()
		tw.tween_property(_light, "light_energy", 4.0, 0.25)
		tw.tween_property(_light, "light_energy", 2.0, 0.4)
