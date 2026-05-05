extends Area3D
class_name WarpPortal

# A portal the player walks into to fast-travel to another region scene.
# Place under a region scene with `target_scene_path = res://scenes/world/...`.
# Visualization: a glowing torus plus a column for visibility.

@export_file("*.tscn") var target_scene_path: String = "res://scenes/world/regions/ashurim.tscn"
@export var label: String = "To Ashurim (V to enter)"
@export var auto_warp: bool = false  # if true, walking into the area fires immediately

var _player_inside: bool = false
var _label3d: Label3D

func _ready() -> void:
	add_to_group("warp_portal")
	collision_layer = 32
	collision_mask = 2  # players-only
	# Trigger area
	var sphere := SphereShape3D.new()
	sphere.radius = 1.4
	var cs := CollisionShape3D.new()
	cs.shape = sphere
	cs.position = Vector3(0, 1.0, 0)
	add_child(cs)
	# Visual: cylinder of light
	var mi := MeshInstance3D.new()
	var cyl := CylinderMesh.new()
	cyl.top_radius = 0.4
	cyl.bottom_radius = 0.4
	cyl.height = 3.5
	mi.mesh = cyl
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.5, 0.7, 1.0, 0.4)
	mat.emission_enabled = true
	mat.emission = Color(0.5, 0.7, 1.0)
	mat.emission_energy_multiplier = 1.4
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mi.material_override = mat
	mi.position = Vector3(0, 1.75, 0)
	add_child(mi)
	# Floating label
	_label3d = Label3D.new()
	_label3d.text = label
	_label3d.modulate = Color(0.85, 0.85, 1.0)
	_label3d.position = Vector3(0, 3.6, 0)
	_label3d.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	add_child(_label3d)
	# OmniLight tint
	var lit := OmniLight3D.new()
	lit.light_color = Color(0.6, 0.7, 1.0)
	lit.light_energy = 1.4
	lit.omni_range = 6.0
	lit.position = Vector3(0, 1.75, 0)
	add_child(lit)

	body_entered.connect(_on_body_entered)
	body_exited.connect(_on_body_exited)

func _on_body_entered(body: Node3D) -> void:
	if not body.is_in_group("player"):
		return
	_player_inside = true
	if auto_warp:
		_warp()

func _on_body_exited(body: Node3D) -> void:
	if not body.is_in_group("player"):
		return
	_player_inside = false

func _unhandled_input(event: InputEvent) -> void:
	# Player presses interact (V) while inside the portal radius
	if not _player_inside:
		return
	if event.is_action_pressed("interact"):
		_warp()

func _warp() -> void:
	if not ResourceLoader.exists(target_scene_path):
		push_warning("WarpPortal: target scene missing: %s" % target_scene_path)
		return
	get_tree().change_scene_to_file(target_scene_path)
