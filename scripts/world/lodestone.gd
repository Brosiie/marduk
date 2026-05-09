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
	_label3d.text = "Lodestone, V to attune"
	_label3d.modulate = Color(0.85, 0.85, 1.0)
	_label3d.position = Vector3(0, 2.6, 0)
	_label3d.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	_label3d.visible = false
	add_child(_label3d)

	body_entered.connect(_on_body_entered)
	body_exited.connect(_on_body_exited)
	# Tall beacon beam: a vertical particle column that's visible from
	# across the zone. Color tracks discovery state (blue undiscovered,
	# warm gold discovered).
	_spawn_beacon_beam()
	# Recolor if already discovered on scene load
	var registry := get_node_or_null("/root/LodestoneRegistry")
	if registry and registry.is_discovered(lodestone_id):
		_apply_discovered_visual()

var _beacon_particles: GPUParticles3D = null

func _spawn_beacon_beam() -> void:
	var p := GPUParticles3D.new()
	p.name = "BeaconBeam"
	p.amount = 90
	p.lifetime = 3.0
	p.preprocess = 1.5
	p.visibility_aabb = AABB(Vector3(-1, 0, -1), Vector3(2, 14, 2))
	var mat := ParticleProcessMaterial.new()
	mat.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_SPHERE
	mat.emission_sphere_radius = 0.20
	mat.direction = Vector3.UP
	mat.spread = 4.0
	mat.initial_velocity_min = 3.5
	mat.initial_velocity_max = 4.5
	mat.gravity = Vector3.ZERO
	mat.scale_min = 0.10
	mat.scale_max = 0.18
	mat.color = Color(0.55, 0.78, 1.0, 0.95)  # blue (undiscovered default)
	mat.tangential_accel_min = -0.3
	mat.tangential_accel_max = 0.3
	p.process_material = mat
	var quad := QuadMesh.new()
	quad.size = Vector2(0.18, 0.18)
	var smat := StandardMaterial3D.new()
	smat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	smat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	smat.albedo_color = Color(0.55, 0.78, 1.0, 0.95)
	smat.emission_enabled = true
	smat.emission = Color(0.55, 0.78, 1.0)
	smat.emission_energy_multiplier = 1.8
	smat.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
	smat.billboard_keep_scale = true
	quad.material = smat
	p.draw_pass_1 = quad
	p.position = Vector3(0, 1.9, 0)
	add_child(p)
	_beacon_particles = p

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
	# Beacon beam: warm gold once discovered (was blue)
	if _beacon_particles:
		var mat := _beacon_particles.process_material as ParticleProcessMaterial
		if mat:
			mat.color = Color(1.0, 0.75, 0.35, 0.95)
		var quad := _beacon_particles.draw_pass_1 as QuadMesh
		if quad and quad.material:
			var smat := quad.material as StandardMaterial3D
			if smat:
				smat.albedo_color = Color(1.0, 0.75, 0.35, 0.95)
				smat.emission = Color(1.0, 0.65, 0.25)

func _process(delta: float) -> void:
	# Slow rotate the crystal so it feels alive
	if _crystal_mesh:
		_crystal_mesh.rotation.y += delta * 0.6

var _vision_played_this_visit: bool = false

func _on_body_entered(body: Node3D) -> void:
	if not body.is_in_group("player"):
		return
	_player_inside = true
	if _label3d:
		_label3d.visible = true
	# Tiamat vision: at WAKING_2 awareness or higher, the act of
	# resting at a discovered lodestone briefly opens the player to her
	# dream. Fires once per zone-entry; leaving and re-entering the
	# trigger plays a fresh vision (the deep is patient but it doesn't
	# repeat itself in the same visit). Undiscovered lodestones don't
	# fire because attunement is the bigger moment first time through.
	if not _vision_played_this_visit:
		_try_play_tiamat_vision()
		_vision_played_this_visit = true

func _try_play_tiamat_vision() -> void:
	var registry := get_node_or_null("/root/LodestoneRegistry")
	if registry == null or not registry.is_discovered(lodestone_id):
		return
	var tr: Node = get_node_or_null("/root/TiamatRegistry")
	if tr == null or not tr.has_method("current_tier"):
		return
	var tier: String = String(tr.current_tier())
	# Only WAKING_2 + AWAKE trigger visions. STIRRING / WAKING are too
	# subtle for a direct vision; the HUD widget + sky tint carry those
	# tiers' weight already.
	if tier != "WAKING_2" and tier != "AWAKE":
		return
	var overlay_script: GDScript = load("res://scripts/world/tiamat_vision_overlay.gd")
	if overlay_script == null:
		return
	var overlay: CanvasLayer = CanvasLayer.new()
	overlay.set_script(overlay_script)
	overlay.name = "TiamatVisionOverlay"
	get_tree().current_scene.add_child(overlay)
	overlay.play(tier)

func _on_body_exited(body: Node3D) -> void:
	if not body.is_in_group("player"):
		return
	_player_inside = false
	if _label3d:
		_label3d.visible = false
	# Reset vision lockout when the player leaves the trigger so the
	# next entry can play another vision if awareness is still high.
	# Without this, the player would have to reload the scene to get a
	# second vision at the same lodestone.
	_vision_played_this_visit = false

func _unhandled_input(event: InputEvent) -> void:
	if not _player_inside:
		return
	if not event.is_action_pressed("interact"):
		return
	var registry := get_node_or_null("/root/LodestoneRegistry")
	if registry == null:
		return
	if registry.is_discovered(lodestone_id):
		# Already attuned: pop the World Map (Lodestone tab) so the player can
		# teleport to any other discovered stone.
		_open_map_panel()
	else:
		_attune()
		# After first attune, also flash the map open so the player sees the
		# new dot light up.
		_open_map_panel()

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
		# Discovery SFX
		var ab = get_node_or_null("/root/AudioBus")
		if ab and ab.has_method("play_cue"):
			ab.play_cue(&"lodestone", global_position, -3.0, 1.0)
		# Cinematic discovery: brief slowmo + gold screen flash + toast.
		# Makes attunement feel like a milestone, not a chore.
		var juice = get_node_or_null("/root/Juice")
		if juice:
			juice.slowmo(0.45, 0.5)
			juice.flash(Color(1.0, 0.85, 0.45), 0.35, 0.5)
			juice.toast("✦  Lodestone Attuned: %s  ✦" % display_name, Color(1.0, 0.85, 0.45), 3.5)

# Walks the scene tree to find the HUD's MenuPanel and opens its `map` tab.
func _open_map_panel() -> void:
	var hud: Node = null
	for n in get_tree().get_nodes_in_group("hud"):
		hud = n
		break
	if hud == null:
		# fallback: search by name under the current scene
		for n in get_tree().current_scene.get_children():
			if n is HUD or n.name == "HUD":
				hud = n
				break
	if hud == null:
		return
	var menu = hud.get("menu_panel") if hud.has_method("get") else null
	if menu and menu.has_method("toggle_tab"):
		# Force-open the map tab even if menu is already showing a different tab
		if menu.visible and menu.has_method("close"):
			menu.close()
		menu.open(&"map")
