extends Area3D
class_name BossArena

# Triggers a boss encounter when the player enters. Spawns invisible
# StaticBody3D walls (gates) along the arena perimeter so the player can't
# leave until the boss dies, and tells the HUD to show the BossBar.
#
# Place under a region scene with `boss_path` pointing at the BossSpawn
# anchor (or a fully-resolved BossBase node). Configure `arena_radius` for
# how big the cage is.

@export var boss_path: NodePath
@export var arena_radius: float = 18.0
@export var trigger_radius: float = 12.0
@export var lock_on_engage: bool = true   # build invisible walls

var _engaged: bool = false
var _gates: Array[StaticBody3D] = []
var _boss: Node = null

func _ready() -> void:
	add_to_group("boss_arena")
	# Trigger volume
	var sphere := SphereShape3D.new()
	sphere.radius = trigger_radius
	var cs := CollisionShape3D.new()
	cs.shape = sphere
	add_child(cs)
	collision_layer = 0
	collision_mask = 2  # players-only
	body_entered.connect(_on_body_entered)

func _on_body_entered(body: Node3D) -> void:
	if _engaged:
		return
	if not body.is_in_group("player"):
		return
	_engage(body)

func _engage(player_node: Node) -> void:
	_engaged = true
	# Resolve the boss
	if boss_path != NodePath():
		_boss = get_node_or_null(boss_path)
	if _boss == null:
		# Fallback: take the first BossBase under the current scene
		for n in get_tree().get_nodes_in_group("boss"):
			_boss = n
			break
	# Bind the HUD boss bar
	for hud in get_tree().get_nodes_in_group("hud"):
		if hud.has_method("bind_boss"):
			hud.bind_boss(_boss)
			break
	# Build invisible cage so the player can't leave
	if lock_on_engage:
		_build_gates()
	# Cinematic engagement (full pipe): camera zoom-in, slowmo, red
	# flash, name banner, audio sting, AND auto-lock the player onto
	# the boss so the duel posture starts immediately.
	var juice = get_node_or_null("/root/Juice")
	if juice and _boss:
		var boss_name: String = String(_boss.get("display_name") if _boss.has_method("get") else "")
		if boss_name == "":
			boss_name = String(_boss.name)
		juice.shake(0.55, 0.45)  # gates slamming closed (heavier than before)
		juice.flash(Color(0.95, 0.20, 0.20), 0.40, 0.50)
		juice.toast("⚔  %s  ⚔" % boss_name.to_upper(), Color(0.95, 0.20, 0.20), 4.0)
		juice.slowmo(0.30, 1.1)  # longer + deeper slowmo for cinematic weight
		# Camera zoom-in: pull the SpringArm length down for ~1.5s, then
		# release back to the player's chosen distance. Reads as 'the
		# camera is leaning in to watch this fight'.
		var cam_rig: Node3D = get_tree().get_first_node_in_group("camera_rig")
		if cam_rig and "distance" in cam_rig:
			var saved_distance: float = cam_rig.distance
			cam_rig.distance = max(5.0, saved_distance * 0.65)
			get_tree().create_timer(1.6).timeout.connect(func():
				if is_instance_valid(cam_rig):
					cam_rig.distance = saved_distance
			)
		# Auto-lock the player onto this boss so the duel begins framed.
		# Player's _set_lock handles reticle + camera tracking.
		if player_node and player_node.has_method("_set_lock"):
			player_node._set_lock(_boss)
		# Audio: deep low boom
		var ab = get_node_or_null("/root/AudioBus")
		if ab and ab.has_method("play_cue"):
			ab.play_cue(&"death", global_position, -2.0, 0.55)
			ab.play_cue(&"thunder", global_position, -4.0, 0.6)  # second layer
	# Wait for boss death; then unlock
	if _boss and _boss.has_signal("boss_defeated"):
		_boss.boss_defeated.connect(_on_boss_defeated)
	elif _boss and _boss.has_signal("died"):
		_boss.died.connect(_on_boss_died)

func _build_gates() -> void:
	# 8-sided invisible cage
	for i in range(8):
		var angle: float = i * TAU / 8.0
		var gate := StaticBody3D.new()
		gate.collision_layer = 1
		gate.collision_mask = 0
		var box := BoxShape3D.new()
		box.size = Vector3(arena_radius * 0.85, 6.0, 0.4)
		var cs := CollisionShape3D.new()
		cs.shape = box
		gate.add_child(cs)
		gate.position = Vector3(cos(angle) * arena_radius, 3.0, sin(angle) * arena_radius)
		gate.rotation.y = angle + PI / 2.0
		add_child(gate)
		_gates.append(gate)

func _release_gates() -> void:
	for g in _gates:
		if is_instance_valid(g):
			g.queue_free()
	_gates.clear()

func _on_boss_defeated(_id: StringName, _killer: Node) -> void:
	_play_defeat_cinematic()
	_release_gates()
	for hud in get_tree().get_nodes_in_group("hud"):
		if hud.has_method("unbind_boss"):
			hud.unbind_boss()
			break

func _on_boss_died() -> void:
	_play_defeat_cinematic()
	_release_gates()
	for hud in get_tree().get_nodes_in_group("hud"):
		if hud.has_method("unbind_boss"):
			hud.unbind_boss()
			break

func _play_defeat_cinematic() -> void:
	# Big finish: cinematic_kill (slowmo + flash) + golden victory toast
	# with the boss name + audio sting. The player has earned this moment.
	var juice = get_node_or_null("/root/Juice")
	if juice == null:
		return
	var boss_name: String = ""
	if _boss and _boss.has_method("get"):
		boss_name = String(_boss.get("display_name"))
	if boss_name == "":
		boss_name = "FOE"
	if juice.has_method("cinematic_kill"):
		var pos: Vector3 = (_boss as Node3D).global_position if _boss else global_position
		juice.cinematic_kill(pos, 0.85)
	if juice.has_method("toast"):
		juice.toast("%s  FALLEN" % boss_name.to_upper(), Color(1.00, 0.88, 0.50), 4.5)
	# Audio: triumph chord
	var ab = get_node_or_null("/root/AudioBus")
	if ab and ab.has_method("play_cue"):
		ab.play_cue(&"level_up", global_position, -3.0, 0.8)

# Manual release (player wipes -> respawn elsewhere -> arena should re-arm
# but the BOSS keeps its current HP until killed). In a multiplayer build
# this would only fire after every player has died and respawned.
func release_after_wipe() -> void:
	_release_gates()
	_engaged = false
	# IMPORTANT: do NOT reset the boss's HP. Bond's rule: boss only resets on
	# boss death. Returning players resume where the fight left off.

# Wired into Player.died — when the player dies, drop the cage so they can
# fast-travel out, but keep the engagement gate disarmed so the arena
# re-fires on next entry.
func on_player_died() -> void:
	release_after_wipe()
