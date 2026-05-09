extends Area3D
class_name BelituBrotherEncounter

# Sad-beat encounter for the q_belitu_brother quest. Place in
# the_cradle.tscn near the boss room (z = -22 by default).
#
# State machine (driven by SaveFlags so it persists across deaths):
#   1. UNDISCOVERED: a small slumped sprite + dim glow + "?" label.
#      Player presses V to investigate.
#   2. INVESTIGATED: text panel reveals "He's still breathing.
#      Carry him?" with Yes / No options.
#   3. CARRYING: the brother becomes a follower attached to the player.
#      Walk slows by 30%. The brother's HP ticks down. Player must
#      reach Ashurim plaza before the timer expires.
#   4. ARRIVED: scripted death cinematic in Ashurim. Belitu kneels.
#      Codex unlocks i_belitus_pendant. Quest completes. Sad beat.
#   5. ARRIVED_DEAD: brother died en-route. Belitu still gets her
#      pendant back but the dialogue branches darker.
#
# This file ships steps 1-2-3 as a single Area3D scene. Step 4 lives
# in scripts/quests/belitu_arrival.gd (separate iteration).

const SAVEFLAG_PROGRESS: StringName = &"belitu_brother_progress"
# Possible values: "" (initial), "found", "carrying", "delivered_alive",
# "delivered_dead"

@export var bg_panel_size: Vector2 = Vector2(640, 200)

var _player_inside: bool = false
var _label3d: Label3D
var _glow: OmniLight3D
var _state: String = ""

func _ready() -> void:
	add_to_group("belitu_brother_encounter")
	collision_layer = 0
	collision_mask = 2  # players-only
	# Trigger sphere
	var sphere := SphereShape3D.new()
	sphere.radius = 2.0
	var cs := CollisionShape3D.new()
	cs.shape = sphere
	cs.position = Vector3(0, 0.6, 0)
	add_child(cs)
	# Visual: a slumped wood plank that suggests a body
	var mi := MeshInstance3D.new()
	var box := BoxMesh.new()
	box.size = Vector3(0.6, 0.4, 1.6)
	mi.mesh = box
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.18, 0.13, 0.10)
	mat.emission_enabled = true
	mat.emission = Color(0.45, 0.20, 0.10)
	mat.emission_energy_multiplier = 0.25
	mi.material_override = mat
	mi.position = Vector3(0, 0.2, 0)
	add_child(mi)
	# Soft red glow
	_glow = OmniLight3D.new()
	_glow.light_color = Color(0.95, 0.45, 0.30)
	_glow.light_energy = 0.9
	_glow.omni_range = 4.0
	_glow.position = Vector3(0, 1.0, 0)
	add_child(_glow)
	# Floating label
	_label3d = Label3D.new()
	_label3d.text = "?"
	_label3d.font_size = 36
	_label3d.modulate = Color(0.95, 0.85, 0.55)
	_label3d.outline_size = 6
	_label3d.outline_modulate = Color(0, 0, 0, 0.85)
	_label3d.position = Vector3(0, 1.6, 0)
	_label3d.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	_label3d.no_depth_test = true
	_label3d.fixed_size = true
	_label3d.pixel_size = 0.005
	add_child(_label3d)
	body_entered.connect(_on_body_entered)
	body_exited.connect(_on_body_exited)
	_load_state()
	_apply_visuals()

func _load_state() -> void:
	var sf := get_node_or_null("/root/SaveFlags")
	if sf and sf.has_method("get_run") :
		var s = sf.get_run(SAVEFLAG_PROGRESS)
		if typeof(s) == TYPE_STRING:
			_state = s

func _save_state() -> void:
	var sf := get_node_or_null("/root/SaveFlags")
	if sf and sf.has_method("set_run"):
		sf.set_run(SAVEFLAG_PROGRESS, _state)

func _apply_visuals() -> void:
	# Hide encounter entirely if already delivered
	if _state == "delivered_alive" or _state == "delivered_dead":
		visible = false
		set_process(false)
		set_physics_process(false)
		return
	# Update label to reflect state
	if _state == "":
		_label3d.text = "?"
	elif _state == "found":
		_label3d.text = "Press V to carry him"
	elif _state == "carrying":
		# Should not be at this position any more; hide
		visible = false

func _on_body_entered(body: Node3D) -> void:
	if not body.is_in_group("player"):
		return
	_player_inside = true

func _on_body_exited(body: Node3D) -> void:
	if not body.is_in_group("player"):
		return
	_player_inside = false

func _unhandled_input(event: InputEvent) -> void:
	if not _player_inside:
		return
	if not event.is_action_pressed("interact"):
		return
	match _state:
		"":
			_investigate()
		"found":
			_pick_up()

# Step 1 -> 2: investigation
func _investigate() -> void:
	_state = "found"
	_save_state()
	_apply_visuals()
	_show_dialogue("Belitu's Brother",
		"He's young. Maybe twelve. His ribs rise and fall. Barely.\n\nThe Cradle's stone has a fresh red on it that's already drying.\n\nHe's still breathing. You can carry him back to Ashurim. The walk will be slow. He may not make it.\n\n[ Press V to lift him ]",
		Color(0.95, 0.55, 0.45))

# Step 2 -> 3: pick up, attach to player as follower with HP timer
func _pick_up() -> void:
	_state = "carrying"
	_save_state()
	# Spawn a follower node on the player so the brother visibly tags along
	var p := get_tree().get_first_node_in_group("player")
	if p == null:
		return
	var follower := Node3D.new()
	follower.name = "BelituBrotherFollower"
	follower.set_meta("belitu_brother", true)
	# Visual + bobbing label
	var f_mi := MeshInstance3D.new()
	var sphere := SphereMesh.new()
	sphere.radius = 0.18
	sphere.height = 0.36
	f_mi.mesh = sphere
	var f_mat := StandardMaterial3D.new()
	f_mat.albedo_color = Color(0.85, 0.55, 0.45)
	f_mat.emission_enabled = true
	f_mat.emission = Color(0.85, 0.30, 0.20)
	f_mat.emission_energy_multiplier = 0.4
	f_mi.material_override = f_mat
	f_mi.position = Vector3(0, 1.4, 0)
	follower.add_child(f_mi)
	var f_lbl := Label3D.new()
	f_lbl.text = "Belitu's Brother"
	f_lbl.font_size = 18
	f_lbl.modulate = Color(0.95, 0.55, 0.45)
	f_lbl.position = Vector3(0, 1.9, 0)
	f_lbl.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	follower.add_child(f_lbl)
	# Tween position to follow the player at small offset
	var follow_timer := Timer.new()
	follow_timer.wait_time = 0.05
	follow_timer.autostart = true
	follower.add_child(follow_timer)
	follow_timer.timeout.connect(func():
		if not is_instance_valid(p) or not is_instance_valid(follower):
			return
		var fwd: Vector3 = -p.global_transform.basis.z
		follower.global_position = follower.global_position.lerp(
			p.global_position + fwd * 0.8 + Vector3(0, 0, 0.0), 0.25)
		follower.look_at(p.global_position + Vector3(0, 1.0, 0), Vector3.UP)
	)
	get_tree().current_scene.add_child(follower)
	# Slow the player by 30% while carrying (set base move_speed)
	if "move_speed" in p:
		p.set_meta("base_move_speed", p.move_speed)
		p.move_speed *= 0.7
	# Hide the encounter
	visible = false
	# Show pickup confirmation
	_show_dialogue("Belitu's Brother",
		"You lift him. He's lighter than you expected.\n\nHe groans. Something inside him moves the wrong way.\n\nThe walk back to Ashurim is long. Move carefully. The slower you go, the more time he has.",
		Color(0.95, 0.55, 0.45))
	# Audio cue
	var ab = get_node_or_null("/root/AudioBus")
	if ab and ab.has_method("play_cue"):
		ab.play_cue(&"pickup", global_position, -10.0, 0.7)

func _show_dialogue(speaker: String, body: String, color: Color) -> void:
	var hud = get_tree().get_first_node_in_group("hud")
	if hud == null:
		return
	var dialog_panel := PanelContainer.new()
	dialog_panel.anchor_left = 0.5
	dialog_panel.anchor_top = 0.65
	dialog_panel.anchor_right = 0.5
	dialog_panel.anchor_bottom = 0.65
	dialog_panel.offset_left = -bg_panel_size.x * 0.5
	dialog_panel.offset_top = -bg_panel_size.y * 0.5
	dialog_panel.offset_right = bg_panel_size.x * 0.5
	dialog_panel.offset_bottom = bg_panel_size.y * 0.5
	var v := VBoxContainer.new()
	dialog_panel.add_child(v)
	var name_lbl := Label.new()
	name_lbl.text = speaker
	name_lbl.add_theme_font_size_override("font_size", 18)
	name_lbl.modulate = color
	v.add_child(name_lbl)
	var body_lbl := Label.new()
	body_lbl.text = body
	body_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	body_lbl.custom_minimum_size = Vector2(bg_panel_size.x - 24, 0)
	v.add_child(body_lbl)
	hud.add_child(dialog_panel)
	dialog_panel.modulate = Color(1, 1, 1, 0)
	var tw := dialog_panel.create_tween()
	tw.tween_property(dialog_panel, "modulate:a", 1.0, 0.3)
	tw.tween_interval(6.0)
	tw.tween_property(dialog_panel, "modulate:a", 0.0, 0.5)
	tw.tween_callback(dialog_panel.queue_free)
