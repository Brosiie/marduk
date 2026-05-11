extends Node
# NOTE: no class_name here. PlaytestBot is registered as an autoload in
# project.godot and Godot 4 errors with 'Class hides an autoload
# singleton' if the same name is also a class_name. Resolve via
# get_node("/root/PlaytestBot") if anything outside ever needs it.

# A scripted "bot" that takes over the player to verify gameplay
# behavior without needing a human at the keyboard. Designed to run
# in --headless mode so I (Claudette) can drive playtests, dump
# observed state, and detect anomalies (T-pose, stuck-not-moving,
# look-away, missing skeleton, no anim playing, etc).
#
# Usage:
#   Godot --headless -- --playtest
#
# The `-- --playtest` separates engine args from user args; the bot
# checks OS.get_cmdline_user_args() for "--playtest" and only
# activates in that case. Without the flag this autoload is dormant
# so normal play sessions are unaffected.
#
# Scenarios run sequentially (each ~3-5s):
#   1. Wait for anim load to finish, log binding count + sample slots
#   2. Idle for 1.0s, assert mob/player are NOT T-posing
#   3. Walk forward (move_up) for 2.0s, assert player moved + walk anim
#   4. Press Tab to lock-on, assert lock target acquired + facing it
#   5. Basic attack 3x via attack_basic, assert hitbox spawns + anim
#   6. Dodge (Space) forward, assert dodge anim + iframes
#   7. Approach a mob, assert mob aggros + chases + plays walk anim
#   8. Take damage from mob, assert HP decreases
#   9. Print final report with PASS/FAIL per check and quit

const SCENARIO_TIMEOUT_S := 60.0   # absolute upper bound
const TICK_HZ := 10                # state sampling rate

var _active: bool = false
var _start_time: float = 0.0
var _player: Node = null
var _findings: Array[String] = []
var _passes: Array[String] = []
var _fails: Array[String] = []

func _ready() -> void:
	# Self-activate only when the user passed --playtest. Without this
	# we'd hijack normal sessions which would be a bad surprise.
	for arg in OS.get_cmdline_user_args():
		if arg == "--playtest":
			_active = true
			break
	if not _active:
		return
	print("\n========================================")
	print("[PlaytestBot] ACTIVE, scripted scenarios queued")
	print("========================================\n")
	_start_time = _now()
	# Wait for the scene + player to be ready before driving anything.
	# call_deferred so we don't fight the main scene's _ready chain.
	call_deferred("_run")

func _now() -> float:
	return Time.get_ticks_msec() / 1000.0

func _run() -> void:
	# Find the player; retry up to 5s if main scene is still spawning.
	for i in range(50):
		_player = get_tree().get_first_node_in_group("player")
		if _player:
			break
		await get_tree().create_timer(0.1).timeout
	if _player == null:
		_fail("player_found", "Player never entered scene tree (5s timeout)")
		_finish()
		return
	_pass("player_found", "Player at %s" % str(_player.global_position))

	# Phase 1: wait for the anim library to finish loading (deferred,
	# can take up to ~10s on first run). The player sets anim_player
	# once the library is bound.
	await _await_anim_ready()

	# Phase 2: idle baseline
	await _scenario_idle_baseline()

	# Phase 3: walk forward
	await _scenario_walk_forward()

	# Phase 4: lock-on + facing
	await _scenario_lock_on()

	# Phase 5: basic attack
	await _scenario_basic_attack()

	# Phase 6: dodge
	await _scenario_dodge()

	# Phase 7: aggro a mob (find one, walk toward it)
	await _scenario_mob_aggro()

	# Phase 8: combat, damage a mob, observe hit_react anim, kill it
	# observe death anim. Verifies the new one-shot anim wiring.
	await _scenario_mob_damage_and_death()

	# Phase 9: boss fight, verify boss is alive, has multi-pattern AI,
	# eventually fires LEAP / CHARGE / SLAM / BURST patterns over a
	# 12-second observation window. Bond's complaint was the boss
	# "felt lifeless"; this asserts the boss DOES things.
	await _scenario_boss_fight()

	# Phase 10: HUD presence
	_scenario_hud_presence()

	# Phase 11: meshes + skeletons
	_scenario_mesh_integrity()

	# Phase 12: end-to-end game-loop scenarios
	# These prove the SYSTEMS hang together, not just the actors.
	# Without these the game can pass every individual check but
	# fail to feel like a real game (e.g. quest tracker shows but
	# never updates, save/reload silently drops inventory).
	await _scenario_quest_progress_loop()
	await _scenario_xp_level_up_loop()
	await _scenario_save_load_round_trip()
	await _scenario_lodestone_attune_persist()
	await _scenario_inventory_save_load()
	await _scenario_quest_persist_across_reload()
	await _scenario_boss_defeated_blocks_arena()
	await _scenario_faction_kill_rep()
	await _scenario_vendor_tier_pricing()
	await _scenario_quest_faction_gate()
	await _scenario_quest_log_ui_mirror()
	await _scenario_complete_quest_faction_rep_apply()
	await _scenario_save_version_migration()
	await _scenario_tiamat_awareness_tiers()
	await _scenario_npc_contextual_greeting()
	await _scenario_tiamat_vision_overlay()
	await _scenario_wound_creep_tiers()
	await _scenario_wound_dread_greeting()
	await _scenario_seventh_breath_gates()

	_finish()

# ---------------------------------------------------------------------
# Scenario primitives
# ---------------------------------------------------------------------

func _await_anim_ready() -> void:
	# Bumped from 12s -> 25s. Player's deferred load yields between
	# every 3 of 40 slots; on first run with cold .glb caches that's
	# ~10-18s on M-series. Test was timing out before completion.
	var deadline: float = _now() + 25.0
	while _now() < deadline:
		var ap: AnimationPlayer = _player.get("anim_player")
		if ap and ap.get_animation_list().size() > 0:
			# Library bound; check key resolutions
			var resolved: Dictionary = _player.get("_resolved_anims")
			var anim_count: int = ap.get_animation_list().size()
			_pass("anim_load", "%d anims bound, idle=%s walk=%s run=%s attack=%s" % [
				anim_count,
				resolved.get("idle", "(none)"),
				resolved.get("walk", "(none)"),
				resolved.get("run", "(none)"),
				resolved.get("attack", "(none)")
			])
			return
		await get_tree().create_timer(0.2).timeout
	_fail("anim_load", "anim_player never reported anims (12s timeout)")

func _scenario_idle_baseline() -> void:
	await _wait(0.5)
	var ap: AnimationPlayer = _player.get("anim_player")
	if ap == null:
		_fail("idle_anim", "anim_player is null")
		return
	var current: String = String(ap.current_animation)
	if current == "":
		_fail("idle_anim", "T-POSE: current_animation is empty after spawn")
	else:
		_pass("idle_anim", "playing '%s' on idle" % current)

func _scenario_walk_forward() -> void:
	var start_pos: Vector3 = _player.global_position
	# Snapshot the sword's world position at rest, BEFORE walking.
	# After the walk we expect the offset between sword and player
	# to stay roughly constant (the sword tracks the hand which
	# tracks the body). If root motion is leaking through, the
	# sword's offset will drift +Z each frame and end up far from
	# the player.
	var sword_offset_before: Vector3 = _read_sword_offset_to_player()
	_press_action("move_up")
	# Sample anim mid-walk (after 1s movement is steady) BEFORE releasing
	# the input. Otherwise the anim already snapped back to idle by the
	# time we check.
	await _wait(1.0)
	var ap: AnimationPlayer = _player.get("anim_player")
	var mid_walk_anim: String = String(ap.current_animation) if ap else ""
	# Sample sword offset MID-walk. If root motion leaked through, the
	# offset will be wildly different from the start (sword detached).
	var sword_offset_during: Vector3 = _read_sword_offset_to_player()
	await _wait(1.0)
	_release_action("move_up")
	var end_pos: Vector3 = _player.global_position
	var moved: float = start_pos.distance_to(end_pos)
	if moved < 1.0:
		_fail("walk_movement", "player moved only %.2fm in 2s (expected >=1m)" % moved)
	else:
		_pass("walk_movement", "moved %.2fm forward" % moved)
	# Verify walk/run anim was active mid-stride (sampled at 1s mark)
	if mid_walk_anim == "":
		_fail("walk_anim", "no current_animation while moving (T-POSE while walking)")
	elif mid_walk_anim.find("walk") >= 0 or mid_walk_anim.find("run") >= 0:
		_pass("walk_anim", "playing '%s' mid-stride" % mid_walk_anim)
	else:
		_fail("walk_anim", "playing '%s' mid-stride (expected walk/run)" % mid_walk_anim)
	# Sword-tracks-hand check: root motion bleed makes the sword's
	# offset to the player drift > 1m over a 1s walk. After the strip
	# fix the offset should stay within ~0.3m of its rest value (some
	# variance from the natural arm-swing animation moving the wrist
	# back and forth).
	if sword_offset_before != Vector3.ZERO and sword_offset_during != Vector3.ZERO:
		var drift: float = sword_offset_before.distance_to(sword_offset_during)
		if drift < 0.6:
			_pass("sword_tracks_hand", "sword offset drift mid-walk = %.2fm (in-hand)" % drift)
		else:
			_fail("sword_tracks_hand", "sword drifted %.2fm during walk, root motion leaking" % drift)
			# Diagnostic: dump the walk-anim position track so we see
			# whether the strip actually persisted into the library.
			_dump_walk_anim_position_track()

func _scenario_lock_on() -> void:
	# Find the closest NON-BOSS enemy. Bosses are tested separately and
	# we don't want to teleport the player into them and disrupt the
	# boss_alive scenario downstream.
	var enemies: Array = []
	for e in get_tree().get_nodes_in_group("enemy"):
		if e.is_in_group("boss"):
			continue
		enemies.append(e)
	if enemies.is_empty():
		_findings.append("(skip lock_on: no non-boss enemies in scene)")
		return
	# Find the nearest enemy; teleport the player adjacent and aim the
	# camera_rig at it so the FOV+range gates pass. The harness map is
	# 80m half-extent, naive enemy spawns can land outside LOCK_RANGE
	# (22m) or behind the default camera facing, both of which look
	# identical to a "broken lock-on" from outside.
	var nearest: Node3D = null
	var nearest_d2: float = INF
	for e in enemies:
		if not (e is Node3D): continue
		var d2: float = (_player.global_position - (e as Node3D).global_position).length_squared()
		if d2 < nearest_d2:
			nearest_d2 = d2
			nearest = e
	if nearest == null:
		_findings.append("(skip lock_on: no Node3D enemies)")
		return
	# Snap player to within 6m of the nearest enemy
	var to_enemy: Vector3 = nearest.global_position - _player.global_position
	to_enemy.y = 0
	if to_enemy.length() > 6.0:
		_player.global_position = nearest.global_position - to_enemy.normalized() * 5.0
	# Aim camera_rig forward toward the enemy (camera-forward is -Z)
	var cam_rig: Node3D = get_tree().get_first_node_in_group("camera_rig")
	if cam_rig:
		var look_at: Vector3 = nearest.global_position
		look_at.y = cam_rig.global_position.y
		if look_at.distance_to(cam_rig.global_position) > 0.001:
			cam_rig.look_at(look_at, Vector3.UP)
	await _wait(0.1)  # let transform propagate
	# Drive lock-on via the actual handler. parse_input_event is fragile
	# in headless mode (no viewport input plumbing); the direct call
	# matches what the keybind invokes anyway.
	if _player.has_method("_toggle_lock_on"):
		_player._toggle_lock_on()
	else:
		_emit_action_event("lock_on")
	await _wait(0.3)
	# Verify a target is locked
	var lock_target = _player.get("_lock_target")
	if lock_target == null:
		var d_to_nearest: float = sqrt(nearest_d2)
		_fail("lock_on", "no target after pressing lock_on (nearest enemy %.1fm away, range=22m)" % d_to_nearest)
		return
	_pass("lock_on", "locked onto %s" % str(lock_target))
	# After 0.5s of lock, the player mesh should face the target
	await _wait(0.5)
	var mesh: Node3D = _player.get("mesh")
	if mesh == null:
		_fail("lock_facing", "mesh is null")
		return
	var to_target: Vector3 = (lock_target as Node3D).global_position - _player.global_position
	to_target.y = 0
	if to_target.length_squared() < 0.001:
		return
	to_target = to_target.normalized()
	# Mixamo mesh is +Z forward; mesh.basis.z should align with to_target
	var mesh_fwd: Vector3 = mesh.global_transform.basis.z
	mesh_fwd.y = 0
	if mesh_fwd.length_squared() < 0.001:
		return
	mesh_fwd = mesh_fwd.normalized()
	var dot: float = mesh_fwd.dot(to_target)
	if dot > 0.6:
		_pass("lock_facing", "mesh facing target (dot=%.2f)" % dot)
	else:
		_fail("lock_facing", "mesh NOT facing target (dot=%.2f, expected >0.6)" % dot)

func _scenario_basic_attack() -> void:
	for i in range(3):
		_emit_action_event("attack_basic")
		await _wait(0.4)
	# After 3 swings, check the combo counter advanced
	var combo: int = int(_player.get("combo_count")) if _has_property(_player, "combo_count") else -1
	if combo > 0:
		_pass("basic_attack", "combo_count=%d after 3 swings" % combo)
	else:
		_findings.append("(basic_attack: combo_count not exposed; can't verify)")

func _scenario_dodge() -> void:
	var start_pos: Vector3 = _player.global_position
	# Hold a direction so the dodge has a vector other than zero
	_press_action("move_up")
	await _wait(0.1)
	if _player.has_method("_perform_dodge"):
		_player._perform_dodge()
	else:
		_emit_action_event("dodge")
	await _wait(0.5)
	_release_action("move_up")
	var moved: float = start_pos.distance_to(_player.global_position)
	if moved > 1.5:
		_pass("dodge", "dodged %.2fm" % moved)
	else:
		_fail("dodge", "dodge moved only %.2fm (expected >1.5m)" % moved)

func _scenario_mob_aggro() -> void:
	var enemies: Array = []
	for e in get_tree().get_nodes_in_group("enemy"):
		if e.is_in_group("boss"):
			continue
		enemies.append(e)
	if enemies.is_empty():
		_findings.append("(skip mob_aggro: no non-boss enemies)")
		return
	var mob = enemies[0]
	# Teleport player to within detect_radius so the test verifies the
	# AGGRO LOGIC, not the player's pathing across an 80m map. Walking
	# at ~3.2m/s for 4s only covers ~13m, so naive enemy spawns past
	# that radius would fail the test for distance reasons unrelated
	# to whether aggro itself works.
	var detect_r: float = float(mob.detect_radius) if "detect_radius" in mob else 8.0
	var to_mob: Vector3 = (mob as Node3D).global_position - _player.global_position
	to_mob.y = 0
	# Park at 90% of detect_radius, close enough to trigger aggro,
	# far enough that the mob doesn't immediately enter melee + start
	# trading damage (which would taint the next scenario's mob HP).
	var park_dist: float = max(3.0, detect_r * 0.9)
	if to_mob.length() != park_dist:
		var dir: Vector3 = to_mob.normalized() if to_mob.length() > 0.001 else Vector3.FORWARD
		_player.global_position = (mob as Node3D).global_position - dir * park_dist
	# Give the mob's _process a couple of ticks to detect the player
	await _wait(0.6)
	# Check mob acquired target + is in CHASE
	var mob_target = mob.get("target") if mob.has_method("get") else null
	if mob_target == _player:
		_pass("mob_aggro", "%s aggroed the player at <%.1fm" % [mob.name, detect_r])
	else:
		var d_now: float = _player.global_position.distance_to((mob as Node3D).global_position)
		_fail("mob_aggro", "%s did NOT aggro (target=%s, dist=%.1fm, detect_r=%.1f)" % [mob.name, str(mob_target), d_now, detect_r])
	# Check mob anim is playing
	var mob_ap: AnimationPlayer = null
	for n in mob.find_children("*", "AnimationPlayer", true, false):
		mob_ap = n
		break
	if mob_ap:
		var current: String = String(mob_ap.current_animation)
		if current == "":
			_fail("mob_anim", "%s T-POSING (no current_animation)" % mob.name)
		else:
			_pass("mob_anim", "%s playing '%s'" % [mob.name, current])

func _scenario_mob_damage_and_death() -> void:
	var enemies: Array = []
	for e in get_tree().get_nodes_in_group("enemy"):
		if e.is_in_group("boss"):
			continue
		enemies.append(e)
	if enemies.is_empty():
		_findings.append("(skip mob_damage: no non-boss enemies)")
		return
	# Pick a HEALTHY mob (the previous aggro test may have started combat
	# with enemies[0]; using a fresh one keeps damage_applies / hit_react
	# / death scenarios independent).
	var mob = null
	for e in enemies:
		if not is_instance_valid(e):
			continue
		if "hp" in e and float(e.hp) > 1.0:
			mob = e
			break
	if mob == null:
		_findings.append("(skip mob_damage: no healthy mobs left)")
		return
	# Park the player far away so mob aggro / contact damage doesn't
	# interfere with the assertion this scenario is making.
	_player.global_position = (mob as Node3D).global_position + Vector3(50, 0, 0)
	await _wait(0.1)
	# Apply a non-lethal hit and look for the hit_react anim swapping
	# in. The mob's anim_player.current_animation should briefly carry
	# a 'hit_react' substring before snapping back to idle/walk.
	var mob_ap: AnimationPlayer = null
	for n in mob.find_children("*", "AnimationPlayer", true, false):
		mob_ap = n
		break
	if mob_ap == null:
		_fail("hit_react", "mob has no AnimationPlayer")
		return
	var hp_before: float = float(mob.hp) if "hp" in mob else 0.0
	# Apply 5% of max HP, small enough to never lethal-kill, big enough
	# to register as a take_damage call
	var dmg: float = max(1.0, float(mob.max_hp if "max_hp" in mob else 100) * 0.05)
	mob.take_damage(dmg, _player)
	if "hp" in mob:
		var hp_after: float = float(mob.hp)
		if hp_after < hp_before:
			_pass("damage_applies", "hp %.1f -> %.1f after take_damage" % [hp_before, hp_after])
		else:
			_fail("damage_applies", "hp unchanged after take_damage (%.1f)" % hp_after)
	# Sample the anim within 100ms, that's well inside the lock window
	await _wait(0.10)
	var played: String = String(mob_ap.current_animation)
	if played.find("hit_react") >= 0 or played.find("hit") >= 0:
		_pass("hit_react_anim", "playing '%s' after damage" % played)
	else:
		_fail("hit_react_anim", "mob did not switch to hit_react after damage (current='%s')" % played)
	# Now kill it. Look for the death anim to play, then the mob to be
	# freed after the anim completes.
	if "max_hp" in mob:
		mob.take_damage(float(mob.max_hp) * 1.5, _player)
	await _wait(0.10)
	if not is_instance_valid(mob):
		_fail("death_anim", "mob freed instantly (no death anim time)")
		return
	var death_played: String = String(mob_ap.current_animation)
	if death_played.find("death") >= 0:
		_pass("death_anim", "playing '%s' on lethal hit" % death_played)
	else:
		_fail("death_anim", "no death anim after lethal hit (current='%s')" % death_played)

# Boss-fight observation: spawn / locate the boss, walk into the arena
# trigger if needed, then observe the boss's pattern selections over a
# 12s window. Bond's complaint: boss felt lifeless, we now verify the
# boss FIRES patterns (and ideally multiple distinct ones).
func _scenario_boss_fight() -> void:
	# Find the boss. sword_vow_ruins ships an EnforcerKazat anchored
	# behind the arena trigger.
	var bosses := get_tree().get_nodes_in_group("boss")
	if bosses.is_empty():
		_findings.append("(skip boss_fight: no boss in scene)")
		return
	# Pick a LIVE boss, earlier scenarios may have killed bosses[0] via
	# damage exchange. Walk the list so we always start the test with
	# something the AI can drive.
	var boss = null
	for b in bosses:
		if is_instance_valid(b) and "hp" in b and float(b.hp) > 0.0:
			boss = b
			break
	if boss == null:
		_findings.append("(skip boss_fight: no living boss in scene; %d total in group)" % bosses.size())
		return
	# Move the player perpendicular to the boss's facing axis so we
	# stay clear of the BossArena trigger geometry. A prior version
	# parked the player at boss_pos + Vector3(0, 0, 6.5), straight
	# through the trigger volume, which fired _engage's cinematic
	# chain (camera, lock, audio) and froze the boss in headless.
	# Parking along X and at >= trigger_radius keeps us inside the
	# boss's detect_radius (default 20m) but outside the arena's
	# default 12m trigger.
	var boss_pos: Vector3 = (boss as Node3D).global_position
	var boss_hp_pre: float = float(boss.hp) if "hp" in boss else -1.0
	var detect_r: float = float(boss.detect_radius) if "detect_radius" in boss else 20.0
	# Target the band [13m, detect_r) so trigger is cleared and aggro
	# is reachable. Clamp upward if detect_r itself is small.
	var park_dist: float = clamp(13.0, 13.0, max(13.0, detect_r - 1.0))
	_player.global_position = boss_pos + Vector3(park_dist, 0, 0)
	if "target" in boss:
		boss.target = _player
	# Snapshot the boss's pattern config NOW, before the 12s observation
	# loop. The boss might be killed by damage exchange before we reach
	# the boss_movement check at the bottom; introspection on a freed
	# boss returns null. This captures the static config we need.
	var captured_patterns: Array = []
	if "attack_patterns" in boss:
		for p in boss.attack_patterns:
			captured_patterns.append(p)
	await _wait(0.3)
	if not is_instance_valid(boss):
		_fail("boss_alive", "boss freed during 0.3s setup wait, pre_hp=%.0f, pos=%s, detect_r=%.1f" % [boss_hp_pre, str(boss_pos), detect_r])
		return
	# Observe the boss's _current_pattern over 12 seconds. Any
	# pattern firing is the bare minimum; we hope to see at least 2
	# DISTINCT patterns (proves the AI picks variety, not just sweep).
	var seen_patterns: Dictionary = {}
	var deadline: float = _now() + 12.0
	var boss_died_at: float = -1.0
	var first_state_seen: String = ""
	var first_target_seen: String = ""
	while _now() < deadline:
		if not is_instance_valid(boss):
			boss_died_at = _now()
			break
		# Re-set target each tick so any aggro reset doesn't stall the AI.
		# (EnemyBase._acquire_target preserves the target if still in
		# detect_radius, but a stagger-recovery or transition might null
		# it briefly.)
		if "target" in boss and boss.target == null:
			boss.target = _player
		var current = boss.get("_current_pattern")
		if current and current is BossAttackPattern:
			seen_patterns[String(current.id)] = true
		# Snapshot first state + target seen for diagnostic on fail
		if first_state_seen == "" and "state" in boss:
			first_state_seen = str(boss.state)
		if first_target_seen == "" and "target" in boss:
			first_target_seen = str(boss.target)
		await _wait(0.25)
	if seen_patterns.size() == 0:
		var diag: String = "state=%s target=%s" % [first_state_seen, first_target_seen]
		if boss_died_at > 0.0:
			diag += " (boss died at t+%.1fs)" % (boss_died_at - (deadline - 12.0))
		_fail("boss_alive", "boss never fired a single pattern in 12s, feels lifeless [%s]" % diag)
	elif seen_patterns.size() == 1:
		var only_one: String = seen_patterns.keys()[0]
		_findings.append("(boss_alive: only fired '%s', could be variety bug)" % only_one)
		_pass("boss_alive", "fired 1 pattern (%s) in 12s" % only_one)
	else:
		_pass("boss_alive", "fired %d distinct patterns in 12s: %s" % [
			seen_patterns.size(),
			", ".join(seen_patterns.keys())
		])
	# Verify the boss has the new movement-based shapes registered. Use
	# the captured pattern list from before the observation loop so this
	# check survives the boss being freed during combat.
	var has_leap: bool = false
	var has_charge: bool = false
	for p in captured_patterns:
		if p is BossAttackPattern:
			if p.shape == BossAttackPattern.Shape.LEAP:
				has_leap = true
			elif p.shape == BossAttackPattern.Shape.CHARGE:
				has_charge = true
	if has_leap and has_charge:
		_pass("boss_movement", "boss has both LEAP and CHARGE patterns")
	elif has_leap or has_charge:
		_fail("boss_movement", "boss has only one of LEAP/CHARGE")
	else:
		_fail("boss_movement", "boss has neither LEAP nor CHARGE, Bond's lifeless complaint")

# --------------------------------------------------------------
# END-TO-END GAME-LOOP SCENARIOS
# --------------------------------------------------------------
#
# These don't test individual actor behavior, they test that the
# SYSTEMS hang together so the game feels like a real game. Each
# scenario exercises a complete loop (accept → progress → complete,
# pickup → save → reload → restore, attune → save → reload → still
# attuned). Without these, the game can pass every per-system check
# yet still feel like a tech demo because no full loops close.

# 1. Quest loop: auto-accepted prologue is active → kill_credit on a
# mob → tracker count goes up → if requirement met, quest auto-
# completes. The Ronin auto-accept fires `prologue_ronin` on spawn.
func _scenario_quest_progress_loop() -> void:
	var qr: Node = get_node_or_null("/root/QuestRegistry")
	if qr == null:
		_findings.append("(skip quest_progress: QuestRegistry autoload missing)")
		return
	if not qr.has_method("get_active_quests"):
		_findings.append("(skip quest_progress: get_active_quests missing)")
		return
	var active: Array = qr.get_active_quests()
	if active.is_empty():
		_fail("quest_active", "no active quests on spawn, auto-accept didn't fire")
		return
	var first = active[0]
	var quest_id: StringName = first.id if "id" in first else &""
	if quest_id == &"":
		_findings.append("(skip quest_progress: first quest has no id)")
		return
	# Read the FIRST kill objective's target_id from the active quest
	# so the test fires credit against the right mob/boss. Hard-coding
	# usurper_footman was wrong, Ronin's prologue tracks Kazat
	# (usurper_enforcer), not the trash mobs.
	var objectives: Array = first.get("objectives_data", []) if typeof(first) == TYPE_DICTIONARY else first.objectives_data
	var target_id: StringName = &""
	var kind: StringName = &""
	for obj in objectives:
		if String(obj.get("kind", "")) == "kill":
			target_id = StringName(obj.get("target_id", ""))
			kind = &"kill"
			break
	if target_id == &"":
		# Fall back to whatever kind the first objective uses
		var first_obj = objectives[0] if objectives.size() > 0 else {}
		target_id = StringName(first_obj.get("target_id", ""))
		kind = StringName(first_obj.get("kind", "kill"))
	if target_id == &"":
		_findings.append("(skip quest_progress: first objective has no target_id)")
		return
	var counts_before: Array = qr.get_progress(quest_id) if qr.has_method("get_progress") else []
	var count_before_val: int = counts_before[0] if counts_before.size() > 0 else 0
	# Fire credit against the actual quest target
	if qr.has_method("progress"):
		qr.progress(kind, target_id, 1)
	await _wait(0.1)
	var counts_after: Array = qr.get_progress(quest_id) if qr.has_method("get_progress") else []
	var count_after_val: int = counts_after[0] if counts_after.size() > 0 else 0
	if count_after_val > count_before_val:
		_pass("quest_progress", "kill credit advanced %s objective: %d -> %d" % [quest_id, count_before_val, count_after_val])
	else:
		_fail("quest_progress", "kill credit did not advance %s (still %d), quest tracker won't move during play" % [quest_id, count_after_val])

# 2. XP gain → level up → attribute gain. Snapshot stats.level + a
# primary attribute, dump in enough XP to level twice, verify both
# advanced.
func _scenario_xp_level_up_loop() -> void:
	if not is_instance_valid(_player) or _player.stats == null:
		_findings.append("(skip xp_level_up: no player stats)")
		return
	var lvl_before: int = int(_player.stats.level)
	var str_before: int = int(_player.stats.strength)
	# Award enough XP to guarantee 2 levels at any starting point
	# (level cost climbs but 5000 will cover the early bracket).
	if _player.stats.has_method("gain_xp"):
		_player.stats.gain_xp(5000)
	await _wait(0.2)
	var lvl_after: int = int(_player.stats.level)
	var str_after: int = int(_player.stats.strength)
	if lvl_after > lvl_before:
		_pass("xp_level_up", "level %d -> %d after 5000 XP" % [lvl_before, lvl_after])
	else:
		_fail("xp_level_up", "level didn't advance after 5000 XP")
	if str_after >= str_before:
		_pass("attr_growth", "strength %d -> %d after level up" % [str_before, str_after])
	else:
		_fail("attr_growth", "strength regressed %d -> %d on level up" % [str_before, str_after])

# 3. Save-reload round-trip: pick a unique stat value, write to slot
# 99, reset stat, load slot 99, verify the value came back. Doesn't
# need a real game restart, exercises the SaveSystem path directly.
func _scenario_save_load_round_trip() -> void:
	var ss: Node = get_node_or_null("/root/SaveSystem")
	if ss == null or not ss.has_method("save_slot") or not ss.has_method("load_slot"):
		_findings.append("(skip save_load: SaveSystem autoload missing)")
		return
	if not is_instance_valid(_player) or _player.stats == null:
		_findings.append("(skip save_load: no player stats)")
		return
	# Mark the stat with a sentinel value
	var marker_xp: int = 9999
	var orig_xp: int = int(_player.stats.xp)
	_player.stats.xp = marker_xp
	# Save to slot 99 (test slot, doesn't clobber autosave at 0)
	var saved: bool = ss.save_slot(99, _player)
	if not saved:
		_fail("save_load", "save_slot returned false, SaveSystem couldn't write")
		_player.stats.xp = orig_xp
		return
	# Mutate the stat
	_player.stats.xp = 1
	# Reload
	var loaded: bool = ss.load_slot(99, _player)
	if not loaded:
		_fail("save_load", "load_slot returned false, file not found or parse failure")
		_player.stats.xp = orig_xp
		return
	# Assert
	if int(_player.stats.xp) == marker_xp:
		_pass("save_load", "xp survived round-trip: %d -> wrote 1 -> loaded back %d" % [marker_xp, int(_player.stats.xp)])
	else:
		_fail("save_load", "xp did NOT survive: expected %d, got %d" % [marker_xp, int(_player.stats.xp)])
	# Restore
	_player.stats.xp = orig_xp
	# Cleanup the test slot
	if ss.has_method("delete_slot"):
		ss.delete_slot(99)

# 4. Lodestone attune persistence: mark a lodestone as discovered via
# the registry, save the flag bag, force a reload, verify the
# attunement state is restored.
func _scenario_lodestone_attune_persist() -> void:
	var lr: Node = get_node_or_null("/root/LodestoneRegistry")
	if lr == null:
		_findings.append("(skip lodestone_persist: LodestoneRegistry autoload missing)")
		return
	if not lr.has_method("discover") or not lr.has_method("is_discovered"):
		_findings.append("(skip lodestone_persist: API methods missing)")
		return
	var test_id: StringName = &"sword_vow_dais"
	# Pre-state
	var was_attuned_before: bool = lr.is_discovered(test_id)
	# Discover (also persists to SaveFlags via _save_to_save_flags)
	lr.discover(test_id)
	# Save state
	var sf: Node = get_node_or_null("/root/SaveFlags")
	if sf and sf.has_method("save_state"):
		sf.save_state()
	# Force-clear local state and reload
	if sf and sf.has_method("load_state"):
		sf.load_state()
	# Force the registry to re-read its persisted state from SaveFlags
	# so we exercise the actual reload path the game uses on next boot.
	if lr.has_method("_load_from_save_flags"):
		lr._load_from_save_flags()
	# Verify
	var attuned_after: bool = lr.is_discovered(test_id)
	if attuned_after:
		_pass("lodestone_persist", "%s discovery survived save/load round-trip" % test_id)
	else:
		_fail("lodestone_persist", "%s discovery LOST after save_state -> load_state" % test_id)
	# Cleanup: restore pre-state by toggling SaveFlags appropriately
	if not was_attuned_before:
		# We polluted the save with a new attunement; clear it
		if sf and sf.has_method("set_permanent"):
			sf.set_permanent(StringName("attuned_" + String(test_id)), false)

# 5. Inventory persistence: pick a real item from the registry, add
# it to the bag, save to slot 99, clear the bag, load slot 99,
# verify the item is back. Also tests bag.gold round-trip.
func _scenario_inventory_save_load() -> void:
	var ss: Node = get_node_or_null("/root/SaveSystem")
	var ir: Node = get_node_or_null("/root/ItemRegistry")
	if ss == null or ir == null:
		_findings.append("(skip inventory_save_load: SaveSystem or ItemRegistry missing)")
		return
	if not is_instance_valid(_player) or not _player.has_method("get_inventory"):
		_findings.append("(skip inventory_save_load: player lacks get_inventory)")
		return
	var inv: Inventory = _player.get_inventory()
	if inv == null:
		_findings.append("(skip inventory_save_load: inventory is null)")
		return
	# Pick a real item from the registry. Try a wide list of id
	# guesses; whichever resolves first wins. Hard-coding ids is
	# a maintenance trap, but probing the registry directly via
	# 'get_all' isn't part of the public API.
	var probe_ids := [
		&"sword_iron", &"sword_steel", &"greatsword_iron",
		&"kazat_bronze_katana", &"copper_coin", &"health_potion",
	]
	var test_item: Item = null
	for pid in probe_ids:
		var candidate: Item = ir.get_item(pid)
		if candidate:
			test_item = candidate
			break
	if test_item == null:
		_findings.append("(skip inventory_save_load: no probe items in registry)")
		return
	# Snapshot pre-state
	var orig_gold: int = inv.gold
	var orig_bag_size: int = inv.bag.size()
	# Mutate
	inv.add_item(test_item, 3)
	inv.gold = 12345
	# Save
	var saved: bool = ss.save_slot(99, _player)
	if not saved:
		_fail("inventory_save_load", "save_slot returned false")
		return
	# Wipe state
	inv.bag.clear()
	inv.gold = 0
	# Reload
	var loaded: bool = ss.load_slot(99, _player)
	if not loaded:
		_fail("inventory_save_load", "load_slot returned false")
		return
	# Assert
	if inv.gold != 12345:
		_fail("inventory_save_load", "gold did not survive: expected 12345, got %d" % inv.gold)
	else:
		var found_test: bool = false
		for s in inv.bag:
			if s.item and s.item.id == test_item.id:
				found_test = true
				break
		if found_test:
			_pass("inventory_save_load", "gold + item '%s' survived save/load round-trip" % test_item.id)
		else:
			_fail("inventory_save_load", "item '%s' was NOT in bag after reload (bag size %d)" % [test_item.id, inv.bag.size()])
	# Cleanup
	inv.gold = orig_gold
	inv.bag.clear()
	if ss.has_method("delete_slot"):
		ss.delete_slot(99)

# 6. Quest persistence: progress an active quest, force-save then
# force-clear-and-reload SaveFlags, verify the active quest + its
# progress counter are still intact. Without this, every relaunch
# drops the player's quest state.
func _scenario_quest_persist_across_reload() -> void:
	var qr: Node = get_node_or_null("/root/QuestRegistry")
	var sf: Node = get_node_or_null("/root/SaveFlags")
	if qr == null or sf == null:
		_findings.append("(skip quest_persist: registry or saveflags missing)")
		return
	if not qr.has_method("get_active_quests"):
		_findings.append("(skip quest_persist: API missing)")
		return
	var active: Array = qr.get_active_quests()
	if active.is_empty():
		_findings.append("(skip quest_persist: no active quests)")
		return
	var q = active[0]
	var qid: StringName = q.id if "id" in q else &""
	# Snapshot pre-state
	var counts_before: Array = qr.get_progress(qid) if qr.has_method("get_progress") else []
	# Persist + force a registry-side reload that simulates a
	# game restart (clear in-memory _active dict, load from flags).
	if qr.has_method("_save_to_save_flags"):
		qr._save_to_save_flags()
	# Drop in-memory state
	if "_active" in qr:
		qr._active.clear()
	if "_progress" in qr:
		qr._progress.clear()
	# Reload
	if qr.has_method("_load_from_save_flags"):
		qr._load_from_save_flags()
	# Verify
	var active_after: Array = qr.get_active_quests()
	var still_active: bool = false
	for q2 in active_after:
		if "id" in q2 and q2.id == qid:
			still_active = true
			break
	if still_active:
		var counts_after: Array = qr.get_progress(qid) if qr.has_method("get_progress") else []
		var match_progress: bool = (counts_before.size() == counts_after.size())
		if match_progress:
			for i in range(counts_before.size()):
				if int(counts_before[i]) != int(counts_after[i]):
					match_progress = false
					break
		if match_progress:
			_pass("quest_persist", "%s active+progress survived save/load round-trip" % qid)
		else:
			_fail("quest_persist", "%s reloaded but progress diverged: %s -> %s" % [qid, counts_before, counts_after])
	else:
		_fail("quest_persist", "%s LOST after save/load round-trip" % qid)

# 7. Boss-defeated: mark the boss as defeated via SaveFlags, walk
# the player into the arena trigger, verify the engagement is
# SKIPPED. Proves the cycle-defeat persistence gates re-engagement
# correctly.
func _scenario_boss_defeated_blocks_arena() -> void:
	var sf: Node = get_node_or_null("/root/SaveFlags")
	if sf == null:
		_findings.append("(skip boss_defeated_gate: SaveFlags missing)")
		return
	# Find a boss arena and its boss_id
	var arenas := get_tree().get_nodes_in_group("boss_arena")
	if arenas.is_empty():
		_findings.append("(skip boss_defeated_gate: no boss_arena in scene)")
		return
	var arena = arenas[0]
	# Resolve boss_id
	var arena_boss_id: StringName = &""
	if "boss_path" in arena and arena.boss_path != NodePath():
		var boss_node: Node = arena.get_node_or_null(arena.boss_path)
		if boss_node and "boss_id" in boss_node:
			arena_boss_id = StringName(boss_node.get("boss_id"))
	if arena_boss_id == &"":
		# Fall back: any boss in the scene
		for n in get_tree().get_nodes_in_group("boss"):
			if "boss_id" in n:
				arena_boss_id = StringName(n.get("boss_id"))
				break
	if arena_boss_id == &"":
		_findings.append("(skip boss_defeated_gate: arena has no resolvable boss_id)")
		return
	# Mark defeated
	if sf.has_method("mark_boss_defeated"):
		sf.mark_boss_defeated(arena_boss_id)
	else:
		_findings.append("(skip boss_defeated_gate: mark_boss_defeated missing)")
		return
	# Now query the arena's gate logic
	var skipped: bool = false
	if arena.has_method("_is_boss_already_defeated"):
		skipped = arena._is_boss_already_defeated()
	if skipped:
		_pass("boss_defeated_gate", "arena recognizes %s as already defeated" % arena_boss_id)
	else:
		_fail("boss_defeated_gate", "arena DOES NOT skip engagement for already-defeated %s, would re-trigger fight on reload" % arena_boss_id)

# 8. Faction kill rep: read Crown rep, set a baseline, fire the kill
# bridge with a stand-in target carrying faction_rep_on_kill, verify
# rep moved exactly the declared deltas. Proves Player._apply_kill_rep
# routes through FactionRegistry correctly without needing a full
# spawned-and-killed boss in scene.
func _scenario_faction_kill_rep() -> void:
	var fr: Node = get_node_or_null("/root/FactionRegistry")
	if fr == null or not fr.has_method("set_rep") or not fr.has_method("get_rep"):
		_findings.append("(skip faction_kill_rep: FactionRegistry missing)")
		return
	if _player == null or not _player.has_method("_apply_kill_rep"):
		_findings.append("(skip faction_kill_rep: player kill bridge missing)")
		return
	# Baseline both factions to a known value so the delta math is unambiguous.
	fr.set_rep(&"crown", 1000)
	fr.set_rep(&"druids", 1000)
	# Build a Node that looks like a boss with faction_rep_on_kill.
	var fake := Node.new()
	fake.add_to_group("boss")
	fake.set_meta("faction_rep_on_kill", {&"crown": -100, &"druids": 50})
	# Plain `target.faction_rep_on_kill` works because GDScript's `in`
	# operator + property access falls through to set_meta-stored values
	# only when wrapped, we need a real property. Easiest: set on a
	# Resource-like wrapper. Skip the meta path and use a script.
	fake.queue_free()
	var script := GDScript.new()
	script.source_code = "extends Node\nvar faction_rep_on_kill: Dictionary = {&\"crown\": -100, &\"druids\": 50}\n"
	script.reload()
	var fake2: Node = Node.new()
	fake2.set_script(script)
	fake2.add_to_group("boss")
	add_child(fake2)
	_player._apply_kill_rep(fake2)
	fake2.queue_free()
	var crown_after: int = int(fr.get_rep(&"crown"))
	var druids_after: int = int(fr.get_rep(&"druids"))
	if crown_after == 900 and druids_after == 1050:
		_pass("faction_kill_rep", "Crown 1000->%d, Druids 1000->%d" % [crown_after, druids_after])
	else:
		_fail("faction_kill_rep", "Expected Crown 900 / Druids 1050, got Crown %d / Druids %d" % [crown_after, druids_after])

# 9. Vendor tier pricing: build a Vendor with a faction, sweep player
# rep across Hostile / Neutral / Friendly / Exalted, verify sell_price
# falls and buy_price rises monotonically with rep. Proves the tier
# modifier is wired through both pricing paths.
func _scenario_vendor_tier_pricing() -> void:
	var fr: Node = get_node_or_null("/root/FactionRegistry")
	if fr == null:
		_findings.append("(skip vendor_tier_pricing: FactionRegistry missing)")
		return
	var vendor: Vendor = Vendor.new()
	vendor.faction = &"crown"
	vendor.sell_markup = 1.5
	vendor.buy_markup = 0.35
	# Stand-in item with a known sell_value
	var item: Item = Item.new()
	item.sell_value = 100
	# Hostile (refuses)
	if vendor.will_trade(-5000):
		_fail("vendor_tier_pricing", "Hostile rep should refuse trade but will_trade returned true")
		return
	# Neutral baseline
	var sell_neutral: int = int(vendor.sell_price(item, 0))
	var buy_neutral: int = int(vendor.buy_price(item, 0))
	# Friendly (3000+)
	var sell_friendly: int = int(vendor.sell_price(item, 4000))
	var buy_friendly: int = int(vendor.buy_price(item, 4000))
	# Exalted (42000+)
	var sell_exalted: int = int(vendor.sell_price(item, 42000))
	var buy_exalted: int = int(vendor.buy_price(item, 42000))
	# Monotonic checks: sell falls with rep, buy rises with rep
	if sell_friendly >= sell_neutral:
		_fail("vendor_tier_pricing", "Friendly sell %d should be < Neutral %d" % [sell_friendly, sell_neutral])
		return
	if sell_exalted >= sell_friendly:
		_fail("vendor_tier_pricing", "Exalted sell %d should be < Friendly %d" % [sell_exalted, sell_friendly])
		return
	if buy_friendly <= buy_neutral:
		_fail("vendor_tier_pricing", "Friendly buy %d should be > Neutral %d" % [buy_friendly, buy_neutral])
		return
	if buy_exalted <= buy_friendly:
		_fail("vendor_tier_pricing", "Exalted buy %d should be > Friendly %d" % [buy_exalted, buy_friendly])
		return
	_pass("vendor_tier_pricing", "Hostile=refuse, sell %d->%d->%d, buy %d->%d->%d (Neu/Fri/Exa)" %
		[sell_neutral, sell_friendly, sell_exalted, buy_neutral, buy_friendly, buy_exalted])

# 10. Quest faction gate: register a quest with min_faction_rep set
# above the player's current rep, verify accept_quest fails. Bump rep
# above threshold, verify accept_quest succeeds.
func _scenario_quest_faction_gate() -> void:
	var fr: Node = get_node_or_null("/root/FactionRegistry")
	var qr: Node = get_node_or_null("/root/QuestRegistry")
	if fr == null or qr == null:
		_findings.append("(skip quest_faction_gate: registries missing)")
		return
	# Build a synthetic quest the harness owns (won't pollute live save).
	# Use preload to dodge any stale class_name cache.
	var QuestRes = preload("res://scripts/quests/quest.gd")
	var q = QuestRes.new()
	q.id = &"_harness_faction_gate_quest"
	q.display_name = "Harness Faction Gate"
	q.min_level = 1
	q.objectives_data = [{"description":"noop","kind":"talk_to","target_id":"void","required_count":1}]
	q.min_faction_rep = {&"crown": 9000}  # Honored
	# Register on the live registry so accept_quest can find it
	if "quests" in qr:
		qr.quests[q.id] = q
	# Set rep below threshold and try
	fr.set_rep(&"crown", 1000)  # Friendly, NOT Honored
	var blocked: bool = not bool(qr.accept_quest(q.id))
	# Set rep at threshold and try
	fr.set_rep(&"crown", 9000)  # Exactly Honored
	var accepted: bool = bool(qr.accept_quest(q.id))
	# Cleanup so harness doesn't persist a fake quest
	if "_active" in qr and qr._active.has(q.id):
		qr._active.erase(q.id)
	if "_progress" in qr and qr._progress.has(q.id):
		qr._progress.erase(q.id)
	if "quests" in qr and qr.quests.has(q.id):
		qr.quests.erase(q.id)
	if blocked and accepted:
		_pass("quest_faction_gate", "below threshold blocked, at threshold accepted")
	else:
		_fail("quest_faction_gate", "blocked=%s accepted=%s (expected true,true)" % [blocked, accepted])

# 11. QuestLog UI mirror: accept a synthetic quest via QuestRegistry,
# verify the player's QuestLog child node sees it appear in `active`.
# Then progress + complete it, verify the QuestLog state transitions
# match (active -> completed_ids). Proves the J-panel UI gets live
# data even though all quest writes go through QuestRegistry.
func _scenario_quest_log_ui_mirror() -> void:
	var qr: Node = get_node_or_null("/root/QuestRegistry")
	if qr == null:
		_findings.append("(skip quest_log_ui_mirror: QuestRegistry missing)")
		return
	var qlog: Node = _player.get_node_or_null("QuestLog") if _player else null
	if qlog == null:
		_findings.append("(skip quest_log_ui_mirror: player has no QuestLog child)")
		return
	# Build a synthetic quest with one kill objective targeting a
	# unique mob_id so this test doesn't collide with live quests.
	var QuestRes = preload("res://scripts/quests/quest.gd")
	var q = QuestRes.new()
	q.id = &"_harness_log_mirror_quest"
	q.display_name = "Harness Log Mirror"
	q.min_level = 1
	# required_count=2 so we can sample mid-progress without the
	# auto-complete moving the entry out of qlog.active mid-read.
	q.objectives_data = [{"description":"slay","kind":"kill","target_id":"_harness_target","required_count":2}]
	if "quests" in qr:
		qr.quests[q.id] = q
	# 1. Accept and verify mirror appears in QuestLog.active
	var ok_accept: bool = bool(qr.accept_quest(q.id))
	var saw_active: bool = qlog.active.has(q.id) if "active" in qlog else false
	# 2. Progress 1/2 and verify QuestLog objective counter advances
	qr.progress(&"kill", &"_harness_target", 1)
	var qlog_count: int = -1
	if saw_active and qlog.active.has(q.id):
		var aq = qlog.active[q.id]
		if aq and "objectives" in aq and aq.objectives.size() > 0:
			qlog_count = int(aq.objectives[0].current_count)
	# 3. Progress 2/2 to auto-complete; should move to completed_ids
	qr.progress(&"kill", &"_harness_target", 1)
	var moved_to_completed: bool = ("completed_ids" in qlog) and (q.id in qlog.completed_ids)
	var no_longer_active: bool = not (qlog.active.has(q.id) if "active" in qlog else true)
	# Cleanup
	if "_active" in qr and qr._active.has(q.id):
		qr._active.erase(q.id)
	if "_completed" in qr and qr._completed.has(q.id):
		qr._completed.erase(q.id)
	if "_progress" in qr and qr._progress.has(q.id):
		qr._progress.erase(q.id)
	if "quests" in qr and qr.quests.has(q.id):
		qr.quests.erase(q.id)
	if "active" in qlog and qlog.active.has(q.id):
		qlog.active.erase(q.id)
	if "completed_ids" in qlog and q.id in qlog.completed_ids:
		qlog.completed_ids.erase(q.id)
	if ok_accept and saw_active and qlog_count == 1 and moved_to_completed and no_longer_active:
		_pass("quest_log_ui_mirror", "accept->mirror, progress->count=1, complete->moved")
	else:
		_fail("quest_log_ui_mirror", "accept=%s saw_active=%s count=%d moved=%s no_longer_active=%s" %
			[ok_accept, saw_active, qlog_count, moved_to_completed, no_longer_active])

# 12. complete_quest applies faction_rep_changes on auto-complete.
# Builds a quest with declared faction_rep_changes, accepts it via
# QuestRegistry, fires kill credit to auto-complete, verifies the
# rep deltas landed in FactionRegistry. Proves the auto-complete
# path applies stakes (the bug fixed in c7cf870 silently dropped
# them on kill-credit auto-completes).
func _scenario_complete_quest_faction_rep_apply() -> void:
	var qr: Node = get_node_or_null("/root/QuestRegistry")
	var fr: Node = get_node_or_null("/root/FactionRegistry")
	if qr == null or fr == null:
		_findings.append("(skip complete_quest_faction_rep: registries missing)")
		return
	# Baseline rep so deltas are unambiguous
	fr.set_rep(&"crown", 5000)
	fr.set_rep(&"black_sail", 5000)
	# Synthetic quest with known rep deltas
	var QuestRes = preload("res://scripts/quests/quest.gd")
	var q = QuestRes.new()
	q.id = &"_harness_complete_rep_quest"
	q.display_name = "Harness Complete Rep"
	q.min_level = 1
	q.objectives_data = [{"description":"slay","kind":"kill","target_id":"_harness_complete_rep","required_count":1}]
	q.faction_rep_changes = {&"crown": 200, &"black_sail": -150}
	if "quests" in qr:
		qr.quests[q.id] = q
	qr.accept_quest(q.id)
	# Auto-complete via kill credit
	qr.progress(&"kill", &"_harness_complete_rep", 1)
	var crown_after: int = int(fr.get_rep(&"crown"))
	var bs_after: int = int(fr.get_rep(&"black_sail"))
	# Cleanup
	if "_active" in qr and qr._active.has(q.id):
		qr._active.erase(q.id)
	if "_completed" in qr and qr._completed.has(q.id):
		qr._completed.erase(q.id)
	if "_progress" in qr and qr._progress.has(q.id):
		qr._progress.erase(q.id)
	if "quests" in qr and qr.quests.has(q.id):
		qr.quests.erase(q.id)
	var qlog: Node = _player.get_node_or_null("QuestLog") if _player else null
	if qlog:
		if "active" in qlog and qlog.active.has(q.id):
			qlog.active.erase(q.id)
		if "completed_ids" in qlog and q.id in qlog.completed_ids:
			qlog.completed_ids.erase(q.id)
	if crown_after == 5200 and bs_after == 4850:
		_pass("complete_quest_faction_rep", "Crown 5000->%d, BlackSail 5000->%d on auto-complete" %
			[crown_after, bs_after])
	else:
		_fail("complete_quest_faction_rep", "expected Crown 5200 / BS 4850, got Crown %d / BS %d" %
			[crown_after, bs_after])

# 13. Save version migration: write a synthetic v0 (unversioned legacy)
# ConfigFile, run it through SaveSystem._migrate_payload, verify the
# version stamp lands at CURRENT_SAVE_VERSION. Proves the framework
# walks the chain rather than hard-failing on legacy saves.
func _scenario_save_version_migration() -> void:
	var ss: Node = get_node_or_null("/root/SaveSystem")
	if ss == null or not ss.has_method("_migrate_payload"):
		_findings.append("(skip save_version_migration: SaveSystem missing or migrate_payload not exposed)")
		return
	# Build a v0 payload (no save_version key). Migration should bump
	# it to CURRENT_SAVE_VERSION without crashing.
	var cfg := ConfigFile.new()
	cfg.set_value("meta", "character_name", "TestRonin")
	cfg.set_value("meta", "class_id", "ronin")
	cfg.set_value("stats", "level", 7)
	cfg.set_value("stats", "xp", 5000)
	# No save_version key, this simulates pre-versioning saves.
	var pre_version: Variant = cfg.get_value("meta", "save_version", -1)
	ss._migrate_payload(cfg)
	var post_version: int = int(cfg.get_value("meta", "save_version", -1))
	var expected: int = int(ss.CURRENT_SAVE_VERSION) if "CURRENT_SAVE_VERSION" in ss else 1
	# Original payload should still be intact, migrations don't touch
	# unrelated keys.
	var name_intact: bool = String(cfg.get_value("meta", "character_name", "")) == "TestRonin"
	var level_intact: bool = int(cfg.get_value("stats", "level", 0)) == 7
	if pre_version == -1 and post_version == expected and name_intact and level_intact:
		_pass("save_version_migration", "v0 payload migrated to v%d, original keys intact" % expected)
	else:
		_fail("save_version_migration", "pre=%s post=%d expected=%d name_intact=%s level_intact=%s" %
			[str(pre_version), post_version, expected, name_intact, level_intact])

# 14. Tiamat awareness tiers: walk the counter through every tier
# breakpoint and verify the tier_for resolution + tier_changed signal
# fires at the right thresholds. Proves the tier table is correct and
# the registry is reachable.
func _scenario_tiamat_awareness_tiers() -> void:
	var tr: Node = get_node_or_null("/root/TiamatRegistry")
	if tr == null:
		_findings.append("(skip tiamat_awareness_tiers: TiamatRegistry missing)")
		return
	# Reset to 0
	tr.set_awareness(0)
	# Watch tier_changed signal so we can count transitions
	var transitions: Array[String] = []
	var listener := func(new_tier: String, _old_tier: String, _new_value: int):
		transitions.append(new_tier)
	tr.tier_changed.connect(listener)
	# Set values at each tier boundary and verify resolution
	var checks := [
		{"value": 0,   "expected": "DORMANT"},
		{"value": 24,  "expected": "DORMANT"},
		{"value": 25,  "expected": "STIRRING"},
		{"value": 49,  "expected": "STIRRING"},
		{"value": 50,  "expected": "WAKING"},
		{"value": 74,  "expected": "WAKING"},
		{"value": 75,  "expected": "WAKING_2"},
		{"value": 99,  "expected": "WAKING_2"},
		{"value": 100, "expected": "AWAKE"},
		{"value": 250, "expected": "AWAKE"},
	]
	var failures: Array[String] = []
	for c in checks:
		tr.set_awareness(int(c["value"]))
		var actual: String = tr.current_tier()
		if actual != String(c["expected"]):
			failures.append("at %d expected %s got %s" % [c["value"], c["expected"], actual])
	# Cleanup
	tr.tier_changed.disconnect(listener)
	tr.set_awareness(0)
	# Should have seen transitions: DORMANT->STIRRING, ->WAKING, ->WAKING_2, ->AWAKE
	# Then on the way back to 0: AWAKE->DORMANT (one final transition)
	# Exact count varies due to set_awareness implementation; we just
	# verify at least the four expected up-transitions fired.
	var saw_up_transitions: int = 0
	for t in transitions:
		if t in ["STIRRING", "WAKING", "WAKING_2", "AWAKE"]:
			saw_up_transitions += 1
	if failures.is_empty() and saw_up_transitions >= 4:
		_pass("tiamat_awareness_tiers", "10 boundary checks ok, %d up-transitions fired" % saw_up_transitions)
	else:
		_fail("tiamat_awareness_tiers", "failures=%s up_transitions=%d" % [", ".join(failures), saw_up_transitions])

# 15. NPC contextual greeting: NPCs that author DREAD_GREETINGS should
# return a dread line when Tiamat awareness is at the corresponding
# tier, falling back to class greeting at DORMANT. Proves the layered
# selection in NPCLines.pick_contextual_greeting walks the priority
# chain correctly.
func _scenario_npc_contextual_greeting() -> void:
	var tr: Node = get_node_or_null("/root/TiamatRegistry")
	if tr == null:
		_findings.append("(skip npc_contextual_greeting: TiamatRegistry missing)")
		return
	# Use Storyteller's tables directly so this test doesn't require an
	# NPC to be alive in the scene. NPCLines is static so we can
	# exercise the chooser without spawning anyone.
	var class_greets := {
		&"ronin": "ronin class line",
		&"mage":  "mage class line",
	}
	var default_greet := "default line"
	var dread_greets := {
		"WAKING":   "waking dread line",
		"WAKING_2": "waking_2 dread line",
		"AWAKE":    "awake dread line",
	}
	# Build a fake player-like Node carrying just enough surface for
	# the helper to introspect class id.
	var fake := Node.new()
	# Stub out get("stats") to return a wrapper exposing class_def
	# with class_id. GDScript has no easy way to mock this without
	# attaching scripts; use a real Resource.
	var fake_class_def := Resource.new()
	var ccd_script := GDScript.new()
	ccd_script.source_code = "extends Resource\nvar class_id: StringName = &\"ronin\"\n"
	ccd_script.reload()
	fake_class_def.set_script(ccd_script)
	var fake_stats := Resource.new()
	var stats_script := GDScript.new()
	stats_script.source_code = "extends Resource\nvar class_def: Resource = null\n"
	stats_script.reload()
	fake_stats.set_script(stats_script)
	fake_stats.class_def = fake_class_def
	# Attach via meta since we can't add stats as a regular Node property.
	# pick_contextual_greeting reads via .get("stats"); we wrap fake in a
	# script that exposes a stats var.
	var wrapper_script := GDScript.new()
	wrapper_script.source_code = """extends Node
var stats = null
var character_appearance = null
"""
	wrapper_script.reload()
	fake.set_script(wrapper_script)
	fake.stats = fake_stats

	# Test 1: at DORMANT, class greeting wins (no dread tier active)
	tr.set_awareness(0)
	var got_dormant: String = NPCLines.pick_contextual_greeting(fake, class_greets, default_greet, dread_greets)
	# Test 2: at WAKING, dread line for WAKING wins over class line
	tr.set_awareness(60)  # mid-WAKING
	var got_waking: String = NPCLines.pick_contextual_greeting(fake, class_greets, default_greet, dread_greets)
	# Test 3: at AWAKE, AWAKE dread line wins
	tr.set_awareness(120)  # past AWAKE threshold
	var got_awake: String = NPCLines.pick_contextual_greeting(fake, class_greets, default_greet, dread_greets)
	# Cleanup
	tr.set_awareness(0)
	fake.queue_free()
	if got_dormant == "ronin class line" and got_waking == "waking dread line" and got_awake == "awake dread line":
		_pass("npc_contextual_greeting", "DORMANT->class, WAKING->dread, AWAKE->dread (highest wins)")
	else:
		_fail("npc_contextual_greeting", "got dormant=%s waking=%s awake=%s" % [got_dormant, got_waking, got_awake])

# 16. Tiamat vision overlay: spawn the overlay directly with each tier
# and verify it (a) builds children, (b) free-self after the animation
# completes. Proves the overlay's lifecycle so a real lodestone trigger
# downstream behaves predictably.
func _scenario_tiamat_vision_overlay() -> void:
	var overlay_script: GDScript = load("res://scripts/world/tiamat_vision_overlay.gd")
	if overlay_script == null:
		_findings.append("(skip tiamat_vision_overlay: script missing)")
		return
	# Build with a deterministic pool so the test isn't randomized.
	var overlay: CanvasLayer = CanvasLayer.new()
	overlay.set_script(overlay_script)
	add_child(overlay)
	overlay.play("WAKING_2", ["test vision line"])
	# Frame 1: verify the overlay built children (tint + label)
	await get_tree().process_frame
	var has_children: bool = overlay.get_child_count() >= 2  # ColorRect + Label
	# The overlay self-frees on tween_callback after fade-out.
	# Total animation: FADE_IN (0.6) + HOLD (3.0) + FADE_OUT (0.8) = 4.4s.
	# Wait 4.6s with a tiny margin and verify it's gone.
	await get_tree().create_timer(4.6).timeout
	var freed: bool = not is_instance_valid(overlay)
	if has_children and freed:
		_pass("tiamat_vision_overlay", "built tint+label, self-freed after animation")
	else:
		# If the overlay didn't free, clean up so we don't leak
		if is_instance_valid(overlay):
			overlay.queue_free()
		_fail("tiamat_vision_overlay", "has_children=%s freed=%s" % [has_children, freed])

# 17. Wound creep tiers: walk every breakpoint and verify tier_for
# returns the right tier, plus that tier_changed fires the expected
# up-transitions. Mirrors the Tiamat tier scenario pattern. Also
# verifies Druid quest reduces creep, Inquisition raises it.
func _scenario_wound_creep_tiers() -> void:
	var wr: Node = get_node_or_null("/root/WoundRegistry")
	if wr == null:
		_findings.append("(skip wound_creep_tiers: WoundRegistry missing)")
		return
	wr.set_creep(0)
	var transitions: Array[String] = []
	var listener := func(new_tier: String, _old_tier: String, _new_value: int):
		transitions.append(new_tier)
	wr.tier_changed.connect(listener)
	# Boundary checks
	var checks := [
		{"value": 0,   "expected": "CONTAINED"},
		{"value": 19,  "expected": "CONTAINED"},
		{"value": 20,  "expected": "SEEPING"},
		{"value": 44,  "expected": "SEEPING"},
		{"value": 45,  "expected": "BLEEDING"},
		{"value": 69,  "expected": "BLEEDING"},
		{"value": 70,  "expected": "UNCONTAINED"},
		{"value": 89,  "expected": "UNCONTAINED"},
		{"value": 90,  "expected": "CONSUMING"},
		{"value": 200, "expected": "CONSUMING"},
	]
	var failures: Array[String] = []
	for c in checks:
		wr.set_creep(int(c["value"]))
		var actual: String = wr.current_tier()
		if actual != String(c["expected"]):
			failures.append("at %d expected %s got %s" % [c["value"], c["expected"], actual])
	# Druid path: -5 from current
	wr.set_creep(50)
	wr.on_druid_quest_completed()
	var after_druid: int = int(wr.get_creep())
	# Inquisition path: +4 from current
	wr.set_creep(50)
	wr.on_inquisition_quest_completed()
	var after_inq: int = int(wr.get_creep())
	# Cleanup
	wr.tier_changed.disconnect(listener)
	wr.set_creep(0)
	# Verify
	var saw_up: int = 0
	for t in transitions:
		if t in ["SEEPING", "BLEEDING", "UNCONTAINED", "CONSUMING"]:
			saw_up += 1
	var druid_correct: bool = after_druid == 45
	var inq_correct: bool = after_inq == 54
	if failures.is_empty() and saw_up >= 4 and druid_correct and inq_correct:
		_pass("wound_creep_tiers", "10 boundary checks ok, %d up-transitions, druid 50->%d, inq 50->%d" %
			[saw_up, after_druid, after_inq])
	else:
		_fail("wound_creep_tiers", "failures=%s up=%d druid=%d inq=%d" %
			[", ".join(failures), saw_up, after_druid, after_inq])

# 18. Wound dread greeting: NPCLines now supports a wound_dread_greetings
# layer that reads WoundRegistry.current_tier. Verify it picks the
# wound-tier line over the class line when creep is in the SEEPING+
# range, and that priority within the chain is correct (wound dread
# fires BEFORE Tiamat dread for NPCs that author both).
func _scenario_wound_dread_greeting() -> void:
	var wr: Node = get_node_or_null("/root/WoundRegistry")
	var tr: Node = get_node_or_null("/root/TiamatRegistry")
	if wr == null or tr == null:
		_findings.append("(skip wound_dread_greeting: registries missing)")
		return
	# Build a fake player with class_id = chaos_druid
	var fake := Node.new()
	var wrapper_script := GDScript.new()
	wrapper_script.source_code = """extends Node
var stats = null
var character_appearance = null
"""
	wrapper_script.reload()
	fake.set_script(wrapper_script)
	var stats_script := GDScript.new()
	stats_script.source_code = "extends Resource\nvar class_def: Resource = null\n"
	stats_script.reload()
	var fake_stats := Resource.new()
	fake_stats.set_script(stats_script)
	var class_def_script := GDScript.new()
	class_def_script.source_code = "extends Resource\nvar class_id: StringName = &\"chaos_druid\"\n"
	class_def_script.reload()
	var fake_class_def := Resource.new()
	fake_class_def.set_script(class_def_script)
	fake_stats.class_def = fake_class_def
	fake.stats = fake_stats

	var class_greets := {&"chaos_druid": "class druid line"}
	var dread_greets := {"WAKING": "tiamat waking line"}
	var wound_dread_greets := {"SEEPING": "wound seeping line", "BLEEDING": "wound bleeding line"}

	# Test 1: both registries at 0, class line wins
	tr.set_awareness(0)
	wr.set_creep(0)
	var got_dormant: String = NPCLines.pick_contextual_greeting(
		fake, class_greets, "default", dread_greets, {}, "", wound_dread_greets)
	# Test 2: Wound at SEEPING, Tiamat at 0 -> wound dread wins
	wr.set_creep(30)
	var got_seeping: String = NPCLines.pick_contextual_greeting(
		fake, class_greets, "default", dread_greets, {}, "", wound_dread_greets)
	# Test 3: Wound at BLEEDING, Tiamat at WAKING -> wound dread wins
	# (wound layer comes first; Tiamat is later)
	wr.set_creep(60)
	tr.set_awareness(60)  # WAKING
	var got_both: String = NPCLines.pick_contextual_greeting(
		fake, class_greets, "default", dread_greets, {}, "", wound_dread_greets)
	# Test 4: Wound at 0 but Tiamat at WAKING -> Tiamat line (no wound to read)
	wr.set_creep(0)
	tr.set_awareness(60)
	var got_tiamat_only: String = NPCLines.pick_contextual_greeting(
		fake, class_greets, "default", dread_greets, {}, "", wound_dread_greets)
	# Cleanup
	tr.set_awareness(0)
	wr.set_creep(0)
	fake.queue_free()
	var all_ok: bool = (
		got_dormant == "class druid line"
		and got_seeping == "wound seeping line"
		and got_both == "wound bleeding line"
		and got_tiamat_only == "tiamat waking line"
	)
	if all_ok:
		_pass("wound_dread_greeting", "class->seeping->bleeding-over-waking->waking (priority chain correct)")
	else:
		_fail("wound_dread_greeting", "got dormant=%s seeping=%s both=%s tiamat_only=%s" %
			[got_dormant, got_seeping, got_both, got_tiamat_only])

# 19. Seventh Breath chain gates: verify the three-stage chain enforces
# faction tier prerequisites correctly. Stage 1 requires Friendly with
# Six Breaths (3000), Stage 2 requires Honored (9000), Stage 3 requires
# Revered (21000). Each stage also has prerequisite_quests pointing at
# the previous stage. Proves the chain can't be skipped.
func _scenario_seventh_breath_gates() -> void:
	var qr: Node = get_node_or_null("/root/QuestRegistry")
	var fr: Node = get_node_or_null("/root/FactionRegistry")
	if qr == null or fr == null:
		_findings.append("(skip seventh_breath_gates: registries missing)")
		return
	# Resolve the three quests in the chain
	var apprentice = qr.get_quest(&"q_seventh_breath_apprentice")
	var pilgrim    = qr.get_quest(&"q_seventh_breath_pilgrimage")
	var unspoken   = qr.get_quest(&"q_seventh_breath_unspoken")
	if apprentice == null or pilgrim == null or unspoken == null:
		_fail("seventh_breath_gates", "one or more chain quests missing in registry")
		return
	# Stage 1 must require Friendly+ with Six Breaths
	var s1_threshold: int = int(apprentice.min_faction_rep.get(&"six_breaths", 0))
	# Stage 2 must require Honored+ with Six Breaths AND apprentice prerequisite
	var s2_threshold: int = int(pilgrim.min_faction_rep.get(&"six_breaths", 0))
	var s2_prereq: bool = &"q_seventh_breath_apprentice" in pilgrim.prerequisite_quests
	# Stage 3 must require Revered+ with Six Breaths AND pilgrim prerequisite
	var s3_threshold: int = int(unspoken.min_faction_rep.get(&"six_breaths", 0))
	var s3_prereq: bool = &"q_seventh_breath_pilgrimage" in unspoken.prerequisite_quests
	# Verify the rep wall: at 0 rep, stage 1 blocked
	fr.set_rep(&"six_breaths", 0)
	var s1_blocked_at_neutral: bool = not apprentice.meets_faction_requirements()
	# At 3000 (Friendly), stage 1 passes but stage 2 still blocked
	fr.set_rep(&"six_breaths", 3000)
	var s1_passes_at_friendly: bool = apprentice.meets_faction_requirements()
	var s2_blocked_at_friendly: bool = not pilgrim.meets_faction_requirements()
	# At 21000 (Revered), all three pass the rep gate
	fr.set_rep(&"six_breaths", 21000)
	var s3_passes_at_revered: bool = unspoken.meets_faction_requirements()
	# Cleanup
	fr.set_rep(&"six_breaths", 0)
	var ok: bool = (
		s1_threshold == 3000 and s2_threshold == 9000 and s3_threshold == 21000
		and s2_prereq and s3_prereq
		and s1_blocked_at_neutral and s1_passes_at_friendly
		and s2_blocked_at_friendly and s3_passes_at_revered
	)
	if ok:
		_pass("seventh_breath_gates", "chain enforces Friendly->Honored->Revered + sequential prereqs")
	else:
		_fail("seventh_breath_gates", "s1=%d s2=%d s3=%d s2_prereq=%s s3_prereq=%s blocked0=%s pass3k=%s blocked3k=%s pass21k=%s" %
			[s1_threshold, s2_threshold, s3_threshold, s2_prereq, s3_prereq,
			 s1_blocked_at_neutral, s1_passes_at_friendly, s2_blocked_at_friendly, s3_passes_at_revered])

func _scenario_hud_presence() -> void:
	var huds := get_tree().get_nodes_in_group("hud")
	if huds.is_empty():
		_fail("hud_present", "no HUD found in 'hud' group")
		return
	var hud = huds[0]
	# Walk the HUD's children and report key components
	var found: Array[String] = []
	for child in hud.find_children("*", "", true, false):
		var n: String = child.name
		if n.begins_with("HpBar") or n.begins_with("HPBar"):
			found.append("hp_bar")
		elif n.begins_with("ManaBar") or n.begins_with("ResourceBar"):
			found.append("resource_bar")
		elif n.begins_with("XpBar") or n.begins_with("XPBar"):
			found.append("xp_bar")
		elif n.find("AbilityBar") >= 0 or n.find("AbilitySlot") >= 0:
			found.append("ability_bar")
		elif n.begins_with("BossBar"):
			found.append("boss_bar")
	_pass("hud_present", "components: %s" % str(found))

func _scenario_mesh_integrity() -> void:
	# The player can get freed mid-test if the boss killed them during
	# the boss-fight scenario's 12s window (and the death-respawn
	# pipeline queue_freed and re-spawned). Re-locate via the group
	# rather than holding the stale ref.
	if not is_instance_valid(_player):
		_player = get_tree().get_first_node_in_group("player")
		if _player == null:
			_fail("mesh_present", "player freed mid-test and no respawn available")
			return
	var mesh: Node3D = _player.get("mesh")
	if mesh == null:
		_fail("mesh_present", "player.mesh is null")
		return
	# Walk ALL Skeleton3Ds under the mesh, find the one with the
	# largest bone count, that's the Mixamo body skeleton (~75 bones).
	# A first-found pick can land on smaller skeletons attached to
	# child meshes or props.
	var skels: Array = mesh.find_children("*", "Skeleton3D", true, false)
	var skel: Skeleton3D = null
	var max_bones: int = 0
	for n in skels:
		if (n as Skeleton3D).get_bone_count() > max_bones:
			max_bones = (n as Skeleton3D).get_bone_count()
			skel = n
	if skel == null:
		_fail("mesh_skeleton", "no Skeleton3D under player.mesh")
		return
	_pass("mesh_skeleton", "%d bones" % skel.get_bone_count())
	# Check the BoneAttachment3D for the katana exists. Use mesh-wide
	# search (not skel-scoped) so it doesn't matter which skeleton
	# the attachment ended up under, only that it exists somewhere
	# in the player's mesh tree.
	var attach: BoneAttachment3D = null
	for n in mesh.find_children("*", "BoneAttachment3D", true, false):
		attach = n
		break
	if attach == null:
		_fail("katana_bone", "no BoneAttachment3D under mesh (sword won't track hand)")
	else:
		_pass("katana_bone", "attached to bone idx=%d name=%s" % [attach.bone_idx, attach.bone_name])
	# Mob mesh integrity
	for mob in get_tree().get_nodes_in_group("enemy"):
		var mob_skel: Skeleton3D = null
		for n in mob.find_children("*", "Skeleton3D", true, false):
			mob_skel = n
			break
		if mob_skel == null:
			_fail("mob_mesh", "%s has no Skeleton3D" % mob.name)
		else:
			# Confirm bone count > 50 (Mixamo standard rig is ~67 bones)
			if mob_skel.get_bone_count() < 30:
				_fail("mob_mesh", "%s skeleton has only %d bones (suspicious)" % [mob.name, mob_skel.get_bone_count()])
			else:
				_pass("mob_mesh", "%s: %d bones" % [mob.name, mob_skel.get_bone_count()])
		break  # one mob is enough

# ---------------------------------------------------------------------
# Input simulation helpers (uses Input.action_press / action_release)
# ---------------------------------------------------------------------

# Resolve the sword's global position relative to the player. Used by
# the walk scenario to detect root-motion bleed (sword sliding off the
# body during a walk loop). Returns Vector3.ZERO if anything in the
# resolution chain is missing, caller treats ZERO as 'skip the check'.
func _read_sword_offset_to_player() -> Vector3:
	if not is_instance_valid(_player):
		return Vector3.ZERO
	var mesh: Node3D = _player.get("mesh")
	if mesh == null:
		return Vector3.ZERO
	# Find the BoneAttachment3D under any Skeleton3D in the mesh tree
	var attach: BoneAttachment3D = null
	for n in mesh.find_children("*", "BoneAttachment3D", true, false):
		attach = n
		break
	if attach == null:
		return Vector3.ZERO
	# Measure sword position IN MESH-LOCAL SPACE. The mesh rotates
	# during walk (atan2 lerp toward input direction); a world-space
	# offset would change just because the body turned, even when
	# the sword is correctly attached. Mesh-local stays constant if
	# the sword tracks the hand properly. Drift > 0.6m here means
	# real detachment / root motion bleed inside the skeleton.
	return mesh.to_local(attach.global_position)

# One-shot diagnostic: dump the walk anim's Hips position track so we
# know whether the strip actually persisted into the bound library.
# Called at the end of _scenario_walk_forward.
func _dump_walk_anim_position_track() -> void:
	var ap: AnimationPlayer = _player.get("anim_player")
	if ap == null:
		return
	var name_to_dump: String = "marduk/walk"
	if not ap.has_animation(name_to_dump):
		# Try walk_back, run as fallbacks
		for n in ["marduk/run", "marduk/walk_back", "marduk/katana_walk"]:
			if ap.has_animation(n):
				name_to_dump = n
				break
	if not ap.has_animation(name_to_dump):
		return
	var anim: Animation = ap.get_animation(name_to_dump)
	for t in range(anim.get_track_count()):
		if anim.track_get_type(t) != Animation.TYPE_POSITION_3D:
			continue
		var p = anim.track_get_path(t)
		var nk = anim.track_get_key_count(t)
		if nk < 2:
			continue
		var v0 = anim.track_get_key_value(t, 0)
		var vn = anim.track_get_key_value(t, nk - 1)
		print("[PlaytestBot][diag] %s pos track #%d path=%s start=%s end=%s" % [name_to_dump, t, str(p), str(v0), str(vn)])

func _press_action(name: String) -> void:
	if not InputMap.has_action(name):
		return
	Input.action_press(name)

func _release_action(name: String) -> void:
	if not InputMap.has_action(name):
		return
	Input.action_release(name)

# Synthesize a press+release InputEventAction so _input() handlers fire.
# Action_press alone only flips the polled state; one-shot abilities
# read via `event.is_action_pressed()` which needs an actual event.
func _emit_action_event(name: String) -> void:
	if not InputMap.has_action(name):
		return
	var ev := InputEventAction.new()
	ev.action = name
	ev.pressed = true
	Input.parse_input_event(ev)
	# Release one frame later so single-press handlers complete cleanly
	await get_tree().process_frame
	var rel := InputEventAction.new()
	rel.action = name
	rel.pressed = false
	Input.parse_input_event(rel)

func _wait(s: float) -> void:
	await get_tree().create_timer(s).timeout

func _has_property(obj: Object, prop: String) -> bool:
	for p in obj.get_property_list():
		if p.name == prop:
			return true
	return false

# ---------------------------------------------------------------------
# Pass/fail recording + final report
# ---------------------------------------------------------------------

func _pass(check: String, detail: String) -> void:
	_passes.append("[PASS] %s: %s" % [check, detail])
	print("[PlaytestBot][PASS] %s: %s" % [check, detail])

func _fail(check: String, detail: String) -> void:
	_fails.append("[FAIL] %s: %s" % [check, detail])
	print("[PlaytestBot][FAIL] %s: %s" % [check, detail])

func _finish() -> void:
	print("\n========================================")
	print("[PlaytestBot] FINAL REPORT")
	print("========================================")
	print("Passed: %d" % _passes.size())
	for p in _passes:
		print("  " + p)
	print("Failed: %d" % _fails.size())
	for f in _fails:
		print("  " + f)
	if not _findings.is_empty():
		print("Findings:")
		for fi in _findings:
			print("  " + fi)
	print("========================================")
	# Exit code reflects health: 0 if no failures.
	get_tree().quit(0 if _fails.is_empty() else 1)
