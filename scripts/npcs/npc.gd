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

# Day/night schedule: when night falls, the NPC walks to night_position
# and idles there until dawn (then walks back to spawn). Empty Vector3
# means "stay home and just stop wandering" (legacy behavior). Use this
# for vendors who go to the tavern to drink, market girls who go home
# to bed, blacksmiths who close up shop and head to the inn.
#
# The position is in WORLD space, set in the scene editor as a sibling
# Marker3D and copied here. Or set in code on _ready for procedural NPCs.
@export var night_position: Vector3 = Vector3.ZERO
# Same speed as wander, slightly slower so the commute reads as
# "tired walking home" not "panicked sprint."
@export var schedule_walk_speed: float = 1.1

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

	# Quest marker, dynamic indicator above the NPC's head:
	#   "!" gold = this NPC offers a quest the player hasn't taken yet
	#   "?" cyan = this NPC is the giver of an active quest with ALL
	#              objectives complete (ready to turn in)
	#   hidden  = nothing for the player to do here
	# Refreshed via _refresh_quest_marker on a 1s timer + on QuestRegistry
	# signal fires so newly-completed objectives flip the marker the
	# instant the kill counter ticks over.
	_quest_marker = Label3D.new()
	_quest_marker.font_size = 48
	_quest_marker.outline_size = 8
	_quest_marker.outline_modulate = Color(0, 0, 0, 0.9)
	_quest_marker.position = Vector3(0, 2.7, 0)
	_quest_marker.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	_quest_marker.no_depth_test = true
	_quest_marker.fixed_size = true
	_quest_marker.pixel_size = 0.005
	_quest_marker.visible = false
	add_child(_quest_marker)
	# Bob the marker so it draws the eye. ~1.5s period, 0.18m amplitude.
	# Tween auto-loops; pause-modes default keep it animating during
	# pause (we want the marker visible in the pause menu too).
	var tw := _quest_marker.create_tween().set_loops()
	tw.tween_property(_quest_marker, "position:y", 2.95, 0.75).set_trans(Tween.TRANS_SINE)
	tw.tween_property(_quest_marker, "position:y", 2.55, 0.75).set_trans(Tween.TRANS_SINE)
	# Refresh on a slow timer, plus immediately after _ready so the
	# marker shows up on the first frame instead of waiting 1s.
	var refresh_timer := Timer.new()
	refresh_timer.wait_time = 1.0
	refresh_timer.autostart = true
	refresh_timer.timeout.connect(_refresh_quest_marker)
	add_child(refresh_timer)
	# Hook QuestRegistry signals so kill-progress / accept / complete
	# update the marker the same frame instead of waiting for the timer.
	var qr := get_node_or_null("/root/QuestRegistry")
	if qr:
		if qr.has_signal("quest_accepted"):
			qr.quest_accepted.connect(_on_quest_state_changed)
		if qr.has_signal("quest_completed"):
			qr.quest_completed.connect(_on_quest_state_changed)
		if qr.has_signal("quest_progress"):
			qr.quest_progress.connect(_on_quest_progress)
	_refresh_quest_marker()

	_load_idle_animation()
	# Procedural breath/sway so static NPCs at vendor stalls don't read
	# as frozen statues when their idle anim hasn't bound yet. Self-
	# disables when a real anim plays. Deferred so the idle loader
	# wins on its first frame.
	call_deferred("_install_procedural_breath")

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
	# Day/night schedule. Three branches:
	#   1. Night + has night_position + not there yet -> walk toward it
	#   2. Day + not at home + has been to night_position -> walk back home
	#   3. Otherwise fall through to wander or idle
	# A brief "arrived" window where we're within wander_arrive_dist of the
	# scheduled destination just plays idle so the NPC doesn't shuffle.
	if _is_night_now() and night_position != Vector3.ZERO:
		var dist_to_night: float = global_position.distance_to(night_position)
		if dist_to_night > wander_arrive_dist:
			_walk_toward(night_position, schedule_walk_speed)
			return
		# At night spot -> idle
		velocity = Vector3.ZERO
		_play_anim_for_state(WanderState.PAUSING)
		move_and_slide()
		return
	elif not _is_night_now() and night_position != Vector3.ZERO:
		# Daytime: if we're not back home (within wander_radius), walk back.
		var dist_to_home: float = global_position.distance_to(_home)
		if dist_to_home > wander_radius * 1.2:
			_walk_toward(_home, schedule_walk_speed)
			return
	elif _is_night_now():
		# No night_position set, legacy behavior: stop and idle.
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

func _install_procedural_breath() -> void:
	var breath_script: GDScript = load("res://scripts/anim/procedural_breath.gd")
	if breath_script == null:
		return
	var mesh_root: Node3D = get_node_or_null("MeshRoot") as Node3D
	if mesh_root == null:
		return
	var ap: AnimationPlayer = _find_anim_player(self)
	if breath_script.has_method("attach_to"):
		breath_script.attach_to(mesh_root, ap)

# Walk directly toward a world point at `speed`. Used by the schedule
# system to move between home + night_position. Handles facing, walk
# anim, and one move_and_slide step. The schedule branches in
# _physics_process call this every frame until they arrive.
func _walk_toward(target: Vector3, speed: float) -> void:
	var to_target: Vector3 = target - global_position
	to_target.y = 0.0
	if to_target.length_squared() < 0.001:
		velocity = Vector3.ZERO
		move_and_slide()
		return
	velocity = to_target.normalized() * speed
	rotation.y = atan2(velocity.x, velocity.z)
	_play_anim_for_state(WanderState.WALKING)
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
	# Ambient chatter: the NPC mutters a one-liner overhead the moment
	# the player gets within talking range. Different lines per NPC type
	# + per time-of-day so the world reads as alive instead of a roster
	# of mute statues. Cooldown so re-entering the radius doesn't spam.
	_maybe_ambient_chatter()

func _on_body_exited(body: Node3D) -> void:
	if not body.is_in_group("player"):
		return
	_player_inside = false
	_label3d.modulate = Color(0.55, 0.95, 0.55)
	_hide_interact_prompt()

# Floating "press V to talk" Label3D above the NPC's head, visible
# only when the player is inside the interaction area. Without this
# the player has no visual cue that the NPC is interactable.
var _interact_prompt: Label3D = null

# Ambient chatter: per-NPC-id lines that float above the head when the
# player walks into the interact radius. Day/night variants give the
# world a different register depending on when you're walking through.
# Generic fallback when an NPC has no specific lines so every NPC at
# least gestures at being alive.
const _AMBIENT_LINES_DAY := {
	&"peasant_male": [
		"Bread's burnt again. Gods.",
		"You can smell the marsh from here today.",
		"The market is louder than usual.",
	],
	&"peasant_female": [
		"My boy ran off again. He'll come back.",
		"Cleaner air than yesterday at least.",
		"Beggars at the gate again. Crown won't move them.",
	],
	&"vendor": [
		"Best prices on this side of Babilim. Honest.",
		"Take a look. Touch nothing you can't pay for.",
		"You are blocking the stall. Move along or buy.",
	],
	&"guard": [
		"Move along. Marduk's eye is on the streets.",
		"State your business or keep walking.",
		"Anything to declare. No. Then move.",
	],
	&"_default": [
		"Marduk's blessing.",
		"Stranger.",
		"Mind your own.",
	],
}
const _AMBIENT_LINES_NIGHT := {
	&"peasant_male": [
		"Should be inside. Whole street should.",
		"Quieter at night. I prefer it.",
	],
	&"peasant_female": [
		"My boy isn't home yet. I should fetch him.",
		"The lamps are guttering. Bad oil this season.",
	],
	&"vendor": [
		"Closing up. Come back at dawn.",
		"Everything's locked. Locks do not stop everything.",
	],
	&"guard": [
		"Curfew. Either you have a reason or you have a problem.",
		"Quiet tonight. Too quiet sometimes.",
	],
	&"_default": [
		"Late hour, stranger.",
		"The cold is settling.",
		"Be safe.",
	],
}
const AMBIENT_CHATTER_COOLDOWN: float = 30.0
var _last_chatter_at: float = -INF
var _chatter_label: Label3D = null
# Class-ID lines: NPC's first-meeting reaction to seeing the player's
# class. Reads as "this NPC clocks who you are." Once-per-NPC-per-save
# via SaveFlags so the second visit gets normal ambient lines.
const _CLASS_ID_LINES := {
	&"ronin":                "Ronin. Where is your lord?",
	&"berserker":            "Ash-Step on you. Smell it from here.",
	&"assassin":             "I didn't see you walk up. That's a trick.",
	&"ranger":               "Hawk-handler. The hawk is judging me.",
	&"mage":                 "Inkstone scholar. I can tell from the fingers.",
	&"chaos_druid":          "Druid. The Wound followed you in, didn't it.",
	&"demon":                "...don't come closer.",
	&"paladin_guardian":     "Sun on you, Paladin. Bless this house.",
	&"paladin_lightbringer": "Lightbringer. They said you were dead.",
}

func _maybe_ambient_chatter() -> void:
	var now: float = Time.get_ticks_msec() / 1000.0
	if (now - _last_chatter_at) < AMBIENT_CHATTER_COOLDOWN:
		return
	_last_chatter_at = now
	# Class-ID greeting wins on FIRST meeting if the NPC has a line for
	# the player's class. Reads as "this NPC sees who you are." After
	# the first encounter the standard ambient pool takes over.
	var class_line: String = _maybe_class_id_line()
	var line: String = ""
	if class_line != "":
		line = class_line
	else:
		# Pick line from day/night pool for this npc_id, fall through to
		# _default if no specific lines exist. Honest: many NPCs default.
		var night: bool = _is_night_now()
		var pool_dict: Dictionary = _AMBIENT_LINES_NIGHT if night else _AMBIENT_LINES_DAY
		var lines: Array = pool_dict.get(npc_id, [])
		if lines.is_empty():
			lines = pool_dict.get(&"_default", [])
		if lines.is_empty():
			return
		line = String(lines[randi() % lines.size()])
	# Spawn a transient Label3D above head, fade in then out over 4s.
	# Re-uses the existing _interact_prompt position so it sits where
	# the player's eye already is.
	if _chatter_label and is_instance_valid(_chatter_label):
		_chatter_label.queue_free()
	_chatter_label = Label3D.new()
	_chatter_label.text = "\"%s\"" % line
	_chatter_label.font_size = 18
	_chatter_label.modulate = Color(0.92, 0.95, 0.85, 0.0)  # fade in via tween
	_chatter_label.outline_size = 4
	_chatter_label.outline_modulate = Color(0, 0, 0, 0.85)
	_chatter_label.fixed_size = true
	_chatter_label.pixel_size = 0.005
	_chatter_label.no_depth_test = true
	_chatter_label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	_chatter_label.position = Vector3(0, 3.1, 0)  # above the [V] Talk prompt
	add_child(_chatter_label)
	var tw := _chatter_label.create_tween()
	tw.tween_property(_chatter_label, "modulate:a", 1.0, 0.30)
	tw.tween_interval(3.5)
	tw.tween_property(_chatter_label, "modulate:a", 0.0, 0.5)
	tw.tween_callback(func():
		if is_instance_valid(_chatter_label): _chatter_label.queue_free())

# Resolve the class-ID line for this NPC's first encounter with the
# player. Returns "" if (a) we already greeted this NPC before, (b)
# the player has no class yet, or (c) we have no canned line for the
# class. Once it returns a real line, the SaveFlag is set so future
# encounters fall through to the ambient pool.
func _maybe_class_id_line() -> String:
	if npc_id == &"":
		return ""
	# Already greeted? SaveFlag covers this NPC for the rest of the save.
	var sf: Node = get_node_or_null("/root/SaveFlags")
	var flag: StringName = StringName("npc_greeted_%s" % String(npc_id))
	if sf and sf.has_method("has_permanent") and sf.has_permanent(flag):
		return ""
	# Resolve the player's class id. Bail if no class assigned yet
	# (CharacterCreator hasn't run, or unit-test contexts).
	var player: Node = get_tree().get_first_node_in_group("player")
	if player == null:
		return ""
	if not ("stats" in player) or player.stats == null:
		return ""
	if not ("class_def" in player.stats) or player.stats.class_def == null:
		return ""
	var cid: StringName = StringName(player.stats.class_def.class_id)
	if not _CLASS_ID_LINES.has(cid):
		return ""
	# Stamp the flag so we don't re-trigger.
	if sf and sf.has_method("set_permanent"):
		sf.set_permanent(flag, true)
	return String(_CLASS_ID_LINES[cid])

# Resolve the voice-tone cue id by name pattern + faction. Returns one
# of the &"voice_*" cues registered in AudioBus. Order matters — the
# first match wins so you can override (e.g. "guard_priest" stays a
# priest tone instead of degrading to soldier).
func _voice_tone_cue() -> StringName:
	var id_str: String = String(npc_id).to_lower()
	if id_str.contains("priest") or id_str.contains("monk") or id_str.contains("oracle") or id_str.contains("sage"):
		return &"voice_priest"
	if id_str.contains("merchant") or id_str.contains("vendor") or id_str.contains("market") or id_str.contains("quartermaster"):
		return &"voice_merchant"
	if id_str.contains("guard") or id_str.contains("soldier") or id_str.contains("captain") or id_str.contains("general") or id_str.contains("inquisitor"):
		return &"voice_soldier"
	if id_str.contains("scholar") or id_str.contains("magus") or id_str.contains("storyteller") or id_str.contains("librarian"):
		return &"voice_scholar"
	if id_str.contains("pirate") or id_str.contains("sail") or id_str.contains("raider") or id_str.contains("hassu"):
		return &"voice_pirate"
	# Default: peasant (everyone else is a townsperson/villager)
	return &"voice_peasant"

func _play_voice_tone() -> void:
	var ab: Node = get_node_or_null("/root/AudioBus")
	if ab == null or not ab.has_method("play_cue"):
		return
	# Slight pitch variation per NPC instance so two priests next to
	# each other don't sound identical. Hash by name for stable variance.
	var pitch: float = 1.0 + (float(hash(npc_id) % 100) - 50.0) * 0.004
	ab.play_cue(_voice_tone_cue(), global_position, -8.0, pitch)

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
	# Voice-tone audio cue: short distinct sting that reads as the NPC
	# "speaking up" when the dialogue opens. Picked from npc_id pattern
	# (priest / merchant / soldier / etc.) so the same NPC kind always
	# sounds the same. Falls through to peasant if no match.
	_play_voice_tone()
	# Branching dialogue path: if DialogueRegistry has a tree for this
	# npc_id, instantiate the DialoguePanel and let it render the full
	# Line/Choice tree (with faction-rep tags, gating, quest-start
	# effects). Falls through to the legacy single-greeting popup if
	# there's no registered dialogue for this NPC.
	var dr: Node = get_node_or_null("/root/DialogueRegistry")
	if dr and dr.has_method("get_dialogue"):
		var d = dr.get_dialogue(npc_id)
		if d != null:
			var panel_script: GDScript = load("res://scripts/ui/panels/dialogue_panel.gd")
			if panel_script:
				var dp := CanvasLayer.new()
				dp.set_script(panel_script)
				dp.layer = 60
				dp.name = "DialoguePanel"
				get_tree().current_scene.add_child(dp)
				dp.open(d, display_name)
				return
	# Polished dialogue panel, gold-filigree slate frame matching the
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
	# Marker refresh is handled by the quest_accepted signal hook so a
	# turn-in marker for THIS NPC's other quest can flip on right after
	# the accepted-quest marker drops off. Keep the explicit hide as a
	# belt-and-suspenders against signal lag.
	if _quest_marker:
		_quest_marker.visible = false
	_refresh_quest_marker()
	if dialog_panel and is_instance_valid(dialog_panel):
		dialog_panel.queue_free()

# ──────────────── Dynamic quest marker ────────────────
#
# Decides what "!" / "?" to render above the NPC. Rules:
#   - "?" cyan if any active quest's giver_npc_id matches this NPC AND
#     all objectives are complete -> ready to turn in
#   - "!" gold if has_quest is true AND quest_id is offerable (not
#     already active or completed)
#   - else hide
# Two-pass because turn-in (?) takes priority over offering a new (!) so
# a debt-NPC always reads as "you have something for me" before
# "I have something else for you."
func _refresh_quest_marker() -> void:
	if _quest_marker == null:
		return
	if _has_turn_in_for_me():
		_quest_marker.text = "?"
		_quest_marker.modulate = Color(0.45, 0.95, 1.00)
		_quest_marker.visible = true
		return
	if has_quest and _can_offer_my_quest():
		_quest_marker.text = "!"
		_quest_marker.modulate = Color(1.0, 0.85, 0.30)
		_quest_marker.visible = true
		return
	_quest_marker.visible = false

func _has_turn_in_for_me() -> bool:
	if npc_id == &"":
		return false
	var qr := get_node_or_null("/root/QuestRegistry")
	if qr == null or not qr.has_method("get_active_quests"):
		return false
	var active: Array = qr.get_active_quests()
	for q in active:
		if q == null:
			continue
		var giver: StringName = StringName(q.get("giver_npc_id") if "giver_npc_id" in q else &"")
		if giver != npc_id:
			continue
		# All objectives done? Pull live counters from QuestRegistry.
		var qid: StringName = StringName(q.get("id") if "id" in q else &"")
		if qid == &"":
			continue
		var counters: Array = qr.get_progress(qid) if qr.has_method("get_progress") else []
		var objs: Array = q.get("objectives_data") if "objectives_data" in q else []
		if objs.is_empty():
			continue
		var all_done: bool = true
		for i in range(objs.size()):
			var required: int = int(objs[i].get("required_count", 1))
			var current: int = int(counters[i]) if i < counters.size() else 0
			if current < required:
				all_done = false
				break
		if all_done:
			return true
	return false

func _can_offer_my_quest() -> bool:
	if quest_id == &"":
		return false
	var qr := get_node_or_null("/root/QuestRegistry")
	if qr == null:
		return false
	# Don't show "!" if quest already accepted or completed.
	var active = qr.get("_active") if "_active" in qr else null
	var completed = qr.get("_completed") if "_completed" in qr else null
	if active is Dictionary and (active as Dictionary).has(quest_id):
		return false
	if completed is Dictionary and (completed as Dictionary).has(quest_id):
		return false
	return true

func _on_quest_state_changed(_q: Variant) -> void:
	_refresh_quest_marker()

func _on_quest_progress(_q: Variant, _idx: int, _count: int) -> void:
	_refresh_quest_marker()
