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
# Wander behavior: NPC paces around its spawn point. Set wander_radius=0
# for static NPCs (vendors anchored at counters). Default 5m gives a
# pleasant "townsfolk going about their day" feel without anyone
# wandering off the map.
@export var wander_radius: float = 5.0
@export var wander_speed: float = 1.4         # m/s - slow stroll
@export var wander_pause_min: float = 2.0     # seconds standing idle between strolls
@export var wander_pause_max: float = 5.5
@export var wander_arrive_dist: float = 0.6   # how close to target counts as "arrived"

# Wander state
enum WanderState { PAUSING, WALKING }
var _home: Vector3 = Vector3.ZERO
var _wander_target: Vector3 = Vector3.ZERO
var _wander_state: int = WanderState.PAUSING
var _wander_state_ends_at: float = 0.0

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

	# Wander setup: lock in home position so wander_target picks stay nearby
	# even after being moved by other systems.
	_home = global_position
	_wander_state = WanderState.PAUSING
	_wander_state_ends_at = _now() + randf_range(wander_pause_min, wander_pause_max)

func _physics_process(_delta: float) -> void:
	# Static NPCs (wander_radius == 0): nothing to do, idle anim already playing.
	if wander_radius <= 0.0:
		return
	# Don't wander while in dialogue (player just walked up to talk)
	if _player_inside:
		velocity = Vector3.ZERO
		_play_anim_for_state(WanderState.PAUSING)
		return
	# Day/night schedule: at night villagers stop wandering and stand
	# still (placeholder for going to bed). Resumes at dawn. Driven by
	# the WorldClock autoload's is_night helper.
	if _is_night_now():
		velocity = Vector3.ZERO
		_play_anim_for_state(WanderState.PAUSING)
		move_and_slide()
		return
	var t := _now()
	match _wander_state:
		WanderState.PAUSING:
			velocity = Vector3.ZERO
			move_and_slide()
			if t >= _wander_state_ends_at:
				_pick_new_wander_target()
		WanderState.WALKING:
			var to_target: Vector3 = _wander_target - global_position
			to_target.y = 0.0
			var dist := to_target.length()
			if dist < wander_arrive_dist or t >= _wander_state_ends_at:
				_wander_state = WanderState.PAUSING
				_wander_state_ends_at = t + randf_range(wander_pause_min, wander_pause_max)
				_play_anim_for_state(WanderState.PAUSING)
				return
			velocity = to_target.normalized() * wander_speed
			# Face the direction of travel (yaw only)
			rotation.y = atan2(velocity.x, velocity.z)
			move_and_slide()

func _pick_new_wander_target() -> void:
	# Pick a random point within wander_radius of home. Repeat up to a few
	# times if the random pick lands too close (avoid micro-shuffles).
	for _i in range(4):
		var angle := randf() * TAU
		var dist := randf_range(wander_radius * 0.4, wander_radius)
		var candidate := _home + Vector3(cos(angle) * dist, 0, sin(angle) * dist)
		if candidate.distance_to(global_position) > wander_arrive_dist * 2.0:
			_wander_target = candidate
			break
	_wander_state = WanderState.WALKING
	# Time-out after generous travel budget so a stuck NPC doesn't get
	# pinned forever against geometry. Distance / speed + slack.
	var travel_budget: float = (_wander_target.distance_to(global_position) / max(wander_speed, 0.1)) * 1.6
	_wander_state_ends_at = _now() + travel_budget
	_play_anim_for_state(WanderState.WALKING)

func _play_anim_for_state(s: int) -> void:
	var ap: AnimationPlayer = _find_anim_player(self)
	if ap == null:
		return
	# Walk anim candidates - peasant_female has its own walk override; fall
	# through to shared. PAUSING uses the same idle resolution as _ready did.
	var candidates: Array
	if s == WanderState.WALKING:
		candidates = ["marduk/walk", "marduk/walk_back", "marduk/walk_left", "Walking", "walk", "Mixamo_Walking"]
	else:
		candidates = ["marduk/idle", "marduk/unarmed_idle", "Mixamo_Idle", "idle", "Idle"]
	for cand in candidates:
		if ap.has_animation(cand) and ap.current_animation != cand:
			ap.play(cand)
			return

func _now() -> float:
	return Time.get_ticks_msec() / 1000.0

# True if the world clock is in night phase. Defaults to false if no
# WorldClock autoload (NPC keeps wandering as a safe fallback).
func _is_night_now() -> bool:
	var clock: Node = get_node_or_null("/root/WorldClock")
	if clock and clock.has_method("is_night"):
		return clock.is_night()
	return false

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
	# .glb pipeline (FBX2glTF) outputs at meter scale, so identity scale.
	# The old 0.01 (cm->m) was for raw Mixamo .fbx imports and made NPCs
	# 1.7cm tall (invisible). Same fix as enemy_base.tscn / boss_base.tscn.
	mesh.transform = Transform3D.IDENTITY
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
	_show_interact_prompt()

func _on_body_exited(body: Node3D) -> void:
	if not body.is_in_group("player"):
		return
	_player_inside = false
	_label3d.modulate = Color(0.55, 0.95, 0.55)
	_hide_interact_prompt()

# Floating "press V to talk" Label3D above the NPC's head — visible
# only when the player is inside the interaction area. Without this
# the player has no visual cue that the NPC is interactable.
var _interact_prompt: Label3D = null

func _show_interact_prompt() -> void:
	if _interact_prompt and is_instance_valid(_interact_prompt):
		_interact_prompt.visible = true
		return
	_interact_prompt = Label3D.new()
	_interact_prompt.text = "[V] Talk"
	_interact_prompt.font_size = 28
	_interact_prompt.outline_size = 6
	_interact_prompt.outline_modulate = Color(0, 0, 0, 0.95)
	_interact_prompt.modulate = Color(1.0, 0.92, 0.55)
	_interact_prompt.fixed_size = true
	_interact_prompt.pixel_size = 0.005
	_interact_prompt.no_depth_test = true
	_interact_prompt.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	_interact_prompt.position = Vector3(0, 2.6, 0)
	add_child(_interact_prompt)

func _hide_interact_prompt() -> void:
	if _interact_prompt and is_instance_valid(_interact_prompt):
		_interact_prompt.queue_free()
		_interact_prompt = null

func _unhandled_input(event: InputEvent) -> void:
	if not _player_inside:
		return
	if not event.is_action_pressed("interact"):
		return
	_open_dialogue()

func _open_dialogue() -> void:
	# Codex unlock: first dialogue with this NPC flips their character
	# entry. Maps display_name to the codex id by lowercasing + spaces->_.
	var cdx = get_node_or_null("/root/CodexRegistry")
	if cdx and cdx.has_method("unlock"):
		# Try by display_name -> "c_<slug>" (storyteller, iddinu, belitu)
		var slug: String = display_name.to_lower().replace(",", "").replace(" ", "_").split("_")[0]
		cdx.unlock(StringName("c_" + slug))
	# Polished dialogue panel — gold-filigree slate frame matching the
	# rest of the HUD language. Fade in / out via tween.
	var dialog_panel := PanelContainer.new()
	dialog_panel.anchor_left = 0.5
	dialog_panel.anchor_top = 0.65
	dialog_panel.anchor_right = 0.5
	dialog_panel.anchor_bottom = 0.65
	dialog_panel.offset_left = -380.0
	dialog_panel.offset_top = -60.0
	dialog_panel.offset_right = 380.0
	dialog_panel.offset_bottom = 100.0
	dialog_panel.modulate = Color(1, 1, 1, 0)
	var dlg_sb := StyleBoxFlat.new()
	dlg_sb.bg_color = Color(0.05, 0.04, 0.06, 0.95)
	dlg_sb.border_color = Color(0.78, 0.62, 0.28, 1.0)
	dlg_sb.set_border_width_all(2)
	dlg_sb.border_width_top = 3
	dlg_sb.set_corner_radius_all(6)
	dlg_sb.shadow_color = Color(0, 0, 0, 0.65)
	dlg_sb.shadow_size = 8
	dlg_sb.shadow_offset = Vector2(0, 4)
	dlg_sb.content_margin_left = 18
	dlg_sb.content_margin_right = 18
	dlg_sb.content_margin_top = 12
	dlg_sb.content_margin_bottom = 12
	dialog_panel.add_theme_stylebox_override("panel", dlg_sb)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 8)
	dialog_panel.add_child(v)
	var name_label := Label.new()
	name_label.text = display_name
	name_label.add_theme_font_size_override("font_size", 22)
	name_label.add_theme_color_override("font_color", Color(1.0, 0.92, 0.55))
	name_label.add_theme_color_override("font_outline_color", Color(0.20, 0.05, 0.05, 1.0))
	name_label.add_theme_constant_override("outline_size", 4)
	name_label.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.85))
	name_label.add_theme_constant_override("shadow_offset_x", 1)
	name_label.add_theme_constant_override("shadow_offset_y", 2)
	v.add_child(name_label)
	# Gold separator line under the name
	var sep := ColorRect.new()
	sep.color = Color(0.78, 0.62, 0.28, 0.55)
	sep.custom_minimum_size = Vector2(0, 1)
	v.add_child(sep)
	var line := Label.new()
	line.text = greeting
	line.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	line.add_theme_font_size_override("font_size", 14)
	line.add_theme_color_override("font_color", Color(0.95, 0.92, 0.85))
	line.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.85))
	line.add_theme_constant_override("outline_size", 2)
	line.custom_minimum_size = Vector2(720, 0)
	v.add_child(line)
	if has_quest and quest_id != &"":
		var qbtn := Button.new()
		qbtn.text = "  ⚔  Accept Quest  ⚔  "
		qbtn.add_theme_font_size_override("font_size", 14)
		qbtn.add_theme_color_override("font_color", Color(1.0, 0.92, 0.55))
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
