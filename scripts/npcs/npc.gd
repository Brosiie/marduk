extends CharacterBody3D
class_name NPC

# A friendly NPC in a town. Carries an idle animation, an above-head
# nameplate, an optional quest-giver indicator (yellow !), and triggers
# a dialogue panel when the player presses V inside the interaction
# radius.
#
# Spawned by region scenes with a properly-scaled Mixamo NPC mesh under
# `MeshRoot`. The npc_id determines which animations and dialogue this
# NPC carries.

@export var npc_id: StringName = &"peasant_male"
@export var display_name: String = "Stranger"
@export var has_quest: bool = false
@export var quest_id: StringName = &""
@export_multiline var greeting: String = "Stranger. The air is heavy today."

var _player_inside: bool = false
var _label3d: Label3D
var _quest_marker: Label3D
var _interaction_area: Area3D

func _ready() -> void:
	add_to_group("npc")
	# Static collision so the player can't walk through them
	collision_layer = 4
	collision_mask = 1
	# Trigger area for interaction range
	_interaction_area = Area3D.new()
	_interaction_area.collision_layer = 0
	_interaction_area.collision_mask = 2  # players-only
	var sphere := SphereShape3D.new()
	sphere.radius = 2.5
	var cs := CollisionShape3D.new()
	cs.shape = sphere
	_interaction_area.add_child(cs)
	add_child(_interaction_area)
	_interaction_area.body_entered.connect(_on_body_entered)
	_interaction_area.body_exited.connect(_on_body_exited)

	# Body collider (capsule)
	var body_cs := CollisionShape3D.new()
	var body_cap := CapsuleShape3D.new()
	body_cap.radius = 0.4
	body_cap.height = 1.7
	body_cs.shape = body_cap
	body_cs.position = Vector3(0, 0.85, 0)
	add_child(body_cs)

	# Auto-attach Mixamo NPC mesh
	_attach_npc_mesh()

	# Floating name label
	_label3d = Label3D.new()
	_label3d.text = display_name
	_label3d.font_size = 22
	_label3d.modulate = Color(0.55, 0.95, 0.55)  # green = friendly
	_label3d.outline_size = 4
	_label3d.outline_modulate = Color(0, 0, 0, 0.85)
	_label3d.position = Vector3(0, 2.2, 0)
	_label3d.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	_label3d.no_depth_test = true
	_label3d.fixed_size = true
	_label3d.pixel_size = 0.005
	add_child(_label3d)

	# Yellow exclamation mark if there's a quest
	_quest_marker = Label3D.new()
	_quest_marker.text = "!"
	_quest_marker.font_size = 48
	_quest_marker.modulate = Color(1.0, 0.85, 0.30)
	_quest_marker.outline_size = 8
	_quest_marker.outline_modulate = Color(0, 0, 0, 0.9)
	_quest_marker.position = Vector3(0, 2.7, 0)
	_quest_marker.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	_quest_marker.no_depth_test = true
	_quest_marker.fixed_size = true
	_quest_marker.pixel_size = 0.005
	_quest_marker.visible = has_quest
	add_child(_quest_marker)

	_load_idle_animation()

func _attach_npc_mesh() -> void:
	# If a MeshRoot already exists with a child, leave it. Otherwise
	# instantiate the Mixamo mesh by id.
	var existing := get_node_or_null("MeshRoot")
	if existing and existing.get_child_count() > 0:
		return
	var registry: Node = get_node_or_null("/root/ClassMeshRegistry")
	if registry == null or not registry.has_method("get_npc_mesh_path"):
		return
	var path: String = registry.get_npc_mesh_path(npc_id)
	if path == "" or not ResourceLoader.exists(path):
		return
	var packed: PackedScene = load(path)
	if packed == null:
		return
	var mesh_root := Node3D.new()
	mesh_root.name = "MeshRoot"
	add_child(mesh_root)
	var mesh := packed.instantiate()
	mesh.name = "NpcMesh"
	mesh.transform = Transform3D(Basis().scaled(Vector3(0.01, 0.01, 0.01)), Vector3.ZERO)
	mesh_root.add_child(mesh)

func _load_idle_animation() -> void:
	# Pull AnimationLibrary via the loader so the NPC plays its idle if
	# Mixamo anims are on disk.
	var loader_script: GDScript = load("res://scripts/anim/animation_library_loader.gd")
	if loader_script == null:
		return
	var loader = loader_script.new()
	loader.apply(self, "npc", npc_id)
	# Try to play idle once anims are merged
	var ap: AnimationPlayer = _find_anim_player(self)
	if ap == null:
		return
	for cand in ["marduk/idle", "marduk/unarmed_idle", "Mixamo_Idle", "idle", "Idle"]:
		if ap.has_animation(cand):
			ap.play(cand)
			break

func _find_anim_player(node: Node) -> AnimationPlayer:
	if node is AnimationPlayer:
		return node
	for child in node.get_children():
		var found := _find_anim_player(child)
		if found:
			return found
	return null

func _on_body_entered(body: Node3D) -> void:
	if not body.is_in_group("player"):
		return
	_player_inside = true
	_label3d.modulate = Color(1.0, 0.95, 0.55)  # highlight on hover

func _on_body_exited(body: Node3D) -> void:
	if not body.is_in_group("player"):
		return
	_player_inside = false
	_label3d.modulate = Color(0.55, 0.95, 0.55)

func _unhandled_input(event: InputEvent) -> void:
	if not _player_inside:
		return
	if not event.is_action_pressed("interact"):
		return
	_open_dialogue()

func _open_dialogue() -> void:
	# Cheap dialogue: pop a centered label that fades in/out. Real dialogue
	# system can replace this — we just need V near an NPC to feel alive.
	var dialog_panel := PanelContainer.new()
	dialog_panel.anchor_left = 0.5
	dialog_panel.anchor_top = 0.65
	dialog_panel.anchor_right = 0.5
	dialog_panel.anchor_bottom = 0.65
	dialog_panel.offset_left = -360.0
	dialog_panel.offset_top = -50.0
	dialog_panel.offset_right = 360.0
	dialog_panel.offset_bottom = 80.0
	dialog_panel.modulate = Color(1, 1, 1, 0)
	var v := VBoxContainer.new()
	dialog_panel.add_child(v)
	var name_label := Label.new()
	name_label.text = display_name
	name_label.add_theme_font_size_override("font_size", 18)
	name_label.modulate = Color(1.0, 0.85, 0.55)
	v.add_child(name_label)
	var line := Label.new()
	line.text = greeting
	line.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	line.custom_minimum_size = Vector2(720, 0)
	v.add_child(line)
	if has_quest and quest_id != &"":
		var qbtn := Button.new()
		qbtn.text = "[ Accept Quest ]"
		qbtn.modulate = Color(1, 0.85, 0.5)
		qbtn.pressed.connect(_on_accept_quest.bind(dialog_panel))
		v.add_child(qbtn)
	# Find the HUD CanvasLayer to host the panel
	var hud = get_tree().get_first_node_in_group("hud")
	if hud == null:
		dialog_panel.queue_free()
		return
	hud.add_child(dialog_panel)
	# Fade in / out
	var tw := dialog_panel.create_tween()
	tw.tween_property(dialog_panel, "modulate:a", 1.0, 0.2)
	tw.tween_interval(4.5)
	tw.tween_property(dialog_panel, "modulate:a", 0.0, 0.4)
	tw.tween_callback(dialog_panel.queue_free)

func _on_accept_quest(dialog_panel: Control) -> void:
	var qr = get_node_or_null("/root/QuestRegistry")
	if qr and qr.has_method("accept_quest"):
		qr.accept_quest(quest_id)
	has_quest = false
	if _quest_marker:
		_quest_marker.visible = false
	if dialog_panel and is_instance_valid(dialog_panel):
		dialog_panel.queue_free()
