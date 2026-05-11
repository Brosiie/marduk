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
	# Boss-defeated gate: if SaveFlags say we already killed this
	# boss, don't re-trigger the fight. Killing the boss + saving +
	# reloading should leave the arena clear, not respawn the boss.
	# The flag is set by BossBase._die via SaveFlags.mark_boss_defeated
	# so the contract is symmetric.
	if _is_boss_already_defeated():
		_skip_arena_for_defeated_boss()
		return
	_engage(body)

func _is_boss_already_defeated() -> bool:
	# Resolve which boss this arena would spawn so we can check the
	# flag for it.
	var boss_id_check: StringName = &""
	if boss_path != NodePath():
		var b: Node = get_node_or_null(boss_path)
		if b and "boss_id" in b:
			boss_id_check = StringName(b.get("boss_id"))
	if boss_id_check == &"":
		# Fall back to any boss in the scene that knows its id
		for n in get_tree().get_nodes_in_group("boss"):
			if "boss_id" in n:
				boss_id_check = StringName(n.get("boss_id"))
				break
	if boss_id_check == &"":
		return false
	var sf: Node = get_node_or_null("/root/SaveFlags")
	if sf == null:
		return false
	# Canonical API, flag key is "<boss_id>_defeated" via set_run
	# (per SaveFlags.mark_boss_defeated). Run flags persist across
	# save/load within a single prestige cycle, which is exactly the
	# scope we want: kill once, stays dead until next prestige.
	if sf.has_method("is_boss_defeated_this_cycle"):
		return bool(sf.is_boss_defeated_this_cycle(boss_id_check))
	if sf.has_method("has_run"):
		return bool(sf.has_run(StringName("%s_defeated" % boss_id_check)))
	return false

func _skip_arena_for_defeated_boss() -> void:
	# Mark engaged so the trigger doesn't re-evaluate, but DON'T build
	# gates / auto-lock / play the cinematic. Despawn ONLY this arena's
	# boss, not the global boss group. A region with multiple bosses
	# (Sword-Vow Ruins + a future expansion arena) used to have ALL of
	# them despawned when re-entering only ONE defeated arena.
	_engaged = true
	var defeated_id: StringName = _resolve_my_boss_id()
	# Prefer the explicit boss_path binding
	if boss_path != NodePath():
		var bound: Node = get_node_or_null(boss_path)
		if bound and is_instance_valid(bound):
			bound.queue_free()
			_spawn_victory_trophy(defeated_id)
			return
	# Fallback: find a boss in the scene whose boss_id matches this
	# arena's id. Only despawn that one. Bosses without ids (legacy)
	# are left alone rather than nuked indiscriminately.
	if defeated_id == &"":
		return
	for n in get_tree().get_nodes_in_group("boss"):
		if not is_instance_valid(n):
			continue
		if "boss_id" in n and StringName(n.get("boss_id")) == defeated_id:
			n.queue_free()
			_spawn_victory_trophy(defeated_id)
			return

# Persistent monument planted at the boss spawn point after a defeat.
# Visible the next time the player enters the (now empty) arena so the
# space reads as "I cleared this" instead of "where did the boss go?"
# Stack-of-skulls + a glowing rune. Interacting with it (V) shows a
# small lore card and offers a re-fight (resets _engaged + respawns
# the boss for sport / loot grinding).
func _spawn_victory_trophy(defeated_id: StringName) -> void:
	if defeated_id == &"":
		return
	# Resolve where the boss WAS so the trophy plants in the right spot.
	# If boss_path was set we use the bound node's position pre-free;
	# we already freed it, so fall back to this arena's position.
	var trophy_pos: Vector3 = global_position
	# Build a small Area3D + interact prompt + skull mesh
	var trophy := Area3D.new()
	trophy.name = "BossTrophy_" + String(defeated_id)
	trophy.add_to_group("boss_trophy")
	trophy.collision_layer = 0
	trophy.collision_mask = 2  # players-only
	trophy.set_meta("boss_id", defeated_id)
	var trigger := SphereShape3D.new()
	trigger.radius = 2.2
	var cs := CollisionShape3D.new()
	cs.shape = trigger
	trophy.add_child(cs)
	# Skull mesh stand-in: stacked spheres + emissive base
	var base := MeshInstance3D.new()
	var box_mesh := BoxMesh.new()
	box_mesh.size = Vector3(0.8, 0.4, 0.8)
	base.mesh = box_mesh
	var base_mat := StandardMaterial3D.new()
	base_mat.albedo_color = Color(0.18, 0.16, 0.14)
	base_mat.roughness = 0.85
	base.material_override = base_mat
	base.position = Vector3(0, 0.2, 0)
	trophy.add_child(base)
	# Skull (sphere) on top of the base
	var skull := MeshInstance3D.new()
	var sphere_mesh := SphereMesh.new()
	sphere_mesh.radius = 0.30
	sphere_mesh.height = 0.55
	skull.mesh = sphere_mesh
	var skull_mat := StandardMaterial3D.new()
	skull_mat.albedo_color = Color(0.85, 0.78, 0.65)
	skull_mat.roughness = 0.65
	skull.material_override = skull_mat
	skull.position = Vector3(0, 0.7, 0)
	trophy.add_child(skull)
	# Emissive rune light — orange glow reads as "monument to violence"
	var lit := OmniLight3D.new()
	lit.light_color = Color(1.0, 0.55, 0.20)
	lit.light_energy = 1.6
	lit.omni_range = 4.0
	lit.position = Vector3(0, 0.5, 0)
	trophy.add_child(lit)
	# Floating Label3D with the boss name + "[V] Re-fight"
	var br: Node = get_node_or_null("/root/BossRegistry")
	var boss_name: String = String(defeated_id).capitalize().replace("_", " ")
	if br and br.has_method("get_boss"):
		var rec = br.get_boss(defeated_id)
		if rec and rec.get("display_name") != null:
			boss_name = String(rec.display_name)
	var label := Label3D.new()
	label.text = "%s\n[V] Re-fight" % boss_name
	label.font_size = 22
	label.modulate = Color(1.0, 0.85, 0.55)
	label.outline_size = 4
	label.outline_modulate = Color(0, 0, 0, 0.92)
	label.position = Vector3(0, 1.6, 0)
	label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	label.no_depth_test = true
	label.fixed_size = true
	label.pixel_size = 0.005
	trophy.add_child(label)
	# Wire the V-press to clear the defeated flag + reload the scene.
	trophy.body_entered.connect(_on_trophy_body_entered.bind(trophy, defeated_id))
	trophy.body_exited.connect(_on_trophy_body_exited.bind(trophy))
	get_tree().current_scene.add_child(trophy)
	trophy.global_position = trophy_pos

var _player_at_trophy: Area3D = null

func _on_trophy_body_entered(_body: Node3D, trophy: Area3D, _id: StringName) -> void:
	if not _body.is_in_group("player"):
		return
	_player_at_trophy = trophy

func _on_trophy_body_exited(_body: Node3D, trophy: Area3D) -> void:
	if not _body.is_in_group("player"):
		return
	if _player_at_trophy == trophy:
		_player_at_trophy = null

func _unhandled_input(event: InputEvent) -> void:
	if not (event.is_action_pressed("interact") and _player_at_trophy):
		return
	# Re-fight: clear the boss-defeated run flag for this id, reload
	# the current scene. The arena's _is_boss_already_defeated will now
	# return false and the boss respawns + the gates rebuild.
	var defeated_id: StringName = StringName(_player_at_trophy.get_meta("boss_id", &""))
	if defeated_id == &"":
		return
	var sf: Node = get_node_or_null("/root/SaveFlags")
	if sf and sf.has_method("set_run"):
		sf.set_run(StringName("%s_defeated" % defeated_id), false)
	# Toast first so the player sees the prompt before the scene change.
	var juice: Node = get_node_or_null("/root/Juice")
	if juice and juice.has_method("toast"):
		juice.toast("Re-summoning the foe...", Color(0.95, 0.45, 0.20), 2.0)
	# Reload current scene to respawn the boss with full HP + cinematic.
	get_tree().reload_current_scene()

func _resolve_my_boss_id() -> StringName:
	# Resolve which boss this arena owns. Mirrors the logic in
	# _is_boss_already_defeated so the despawn path uses the same id.
	if boss_path != NodePath():
		var b: Node = get_node_or_null(boss_path)
		if b and "boss_id" in b:
			return StringName(b.get("boss_id"))
	for n in get_tree().get_nodes_in_group("boss"):
		if "boss_id" in n:
			return StringName(n.get("boss_id"))
	return &""

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
		# Cinematic nameplate flourish: split the boss's display_name into
		# title + epithet ("Enforcer Kazat, Iron-Faced" -> name="Enforcer
		# Kazat", epithet="Iron-Faced") so the sword-wipe nameplate reads
		# like a Bayonetta / DMC kill-card. Lore line pulled from
		# BossRegistry when the boss has a boss_id.
		var split_name: String = boss_name
		var split_epithet: String = ""
		if "," in boss_name:
			var parts := boss_name.split(",", false, 1)
			split_name = parts[0].strip_edges()
			split_epithet = parts[1].strip_edges() if parts.size() > 1 else ""
		elif " the " in boss_name:
			var idx: int = boss_name.find(" the ")
			split_name = boss_name.substr(0, idx).strip_edges()
			split_epithet = boss_name.substr(idx + 1).strip_edges()
		var lore_line: String = ""
		if "boss_id" in _boss:
			var br: Node = get_node_or_null("/root/BossRegistry")
			if br and br.has_method("get_boss"):
				var rec = br.get_boss(StringName(_boss.get("boss_id")))
				if rec and "lore" in rec:
					lore_line = String(rec.lore)
		if juice.has_method("boss_nameplate"):
			juice.boss_nameplate(split_name, split_epithet, lore_line, Color(0.95, 0.20, 0.20), 4.0)
		else:
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
		# Audio: deep low boom + thunder
		var ab = get_node_or_null("/root/AudioBus")
		if ab and ab.has_method("play_cue"):
			ab.play_cue(&"death", global_position, -2.0, 0.55)
			ab.play_cue(&"thunder", global_position, -4.0, 0.6)  # second layer
		# Music: crossfade in the combat tension layer.
		var md = get_node_or_null("/root/MusicDirector")
		if md and md.has_method("set_combat_intensity"):
			md.set_combat_intensity(1.0)
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

func _drop_combat_music() -> void:
	var md = get_node_or_null("/root/MusicDirector")
	if md and md.has_method("set_combat_intensity"):
		md.set_combat_intensity(0.0)

func _play_defeat_cinematic() -> void:
	_drop_combat_music()
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

# Wired into Player.died, when the player dies, drop the cage so they can
# fast-travel out, but keep the engagement gate disarmed so the arena
# re-fires on next entry.
func on_player_died() -> void:
	release_after_wipe()
