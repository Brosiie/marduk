extends Marker3D
class_name BossAnchor

# Place this in a dungeon/zone scene where you want a boss to spawn. Configure
# `boss_id` to match a BossRegistry id; the anchor instantiates BossBase.tscn,
# applies stats from the registry record, and attaches per-boss attack patterns.
#
# For Sword-Vow Ruins / Enforcer Kazat: the patterns below give him a real
# Elden-Ring-tuned moveset (telegraphed cone, AOE slam, charge line, recovery).

@export var boss_id: StringName = &"usurper_enforcer"
@export var auto_spawn_on_ready: bool = true

func _ready() -> void:
	if auto_spawn_on_ready:
		# Defer to next frame so the parent scene is fully constructed before
		# we add the boss as a sibling.
		call_deferred("spawn_boss")

func spawn_boss() -> void:
	var boss_scene := preload("res://scenes/enemies/boss_base.tscn") if ResourceLoader.exists("res://scenes/enemies/boss_base.tscn") else null
	if not boss_scene:
		return
	var inst := boss_scene.instantiate() as BossBase
	# Stamp boss_id BEFORE add_child so BossBase._ready() and its
	# AnimationLibraryLoader.apply() see the correct id. Without this, the
	# loader runs with the default empty StringName and the boss-specific
	# anim slot map is empty (only shared anims merge).
	inst.boss_id = boss_id
	get_tree().current_scene.add_child(inst)
	inst.global_position = global_position
	# Cinematic spawn: fade alpha in over 1.4s + ground rise from -1.0
	# to 0 + dust column at the spawn point. Reads as 'they appear from
	# the earth like a curse manifesting' instead of just popping in.
	_play_boss_spawn_pose(inst)

	# Apply registry data (boss_id was already stamped above; rest of fields
	# are stat overrides that can be applied post-add safely).
	var rec = BossRegistry.get_boss(boss_id) if has_node("/root/BossRegistry") else null
	if rec:
		inst.display_name = rec.display_name
		inst.encounter_level = rec.encounter_level
		inst.is_main_boss = rec.is_main_boss
		inst.is_final_boss = rec.is_final_boss
		inst.is_secret_boss = rec.is_secret_boss
		inst.phases_data = rec.phases

	# Bake attack patterns matching the boss
	inst.attack_patterns = _build_patterns(boss_id)

func _play_boss_spawn_pose(boss: Node3D) -> void:
	if boss == null or not is_instance_valid(boss):
		return
	# Fade in: drop the boss to alpha 0 first, then tween up. We use
	# modulate which works on Node3D's RenderingServer instance via
	# self_modulate. For meshes embedded under MeshInstance3D parents
	# we set per-mesh transparency through albedo color alpha.
	var origin: Vector3 = boss.global_position
	# Sink the boss 1m into the ground, rise back up over 1.4s
	boss.global_position = origin - Vector3(0, 1.0, 0)
	var rise := boss.create_tween()
	rise.tween_property(boss, "global_position", origin, 1.4).set_trans(Tween.TRANS_QUART).set_ease(Tween.EASE_OUT)
	# Dust column at the spawn point (column of dirt particles rising)
	_spawn_boss_dust(origin)
	# Audio sting on spawn so the player ear hears the curse manifest
	var ab: Node = get_node_or_null("/root/AudioBus")
	if ab and ab.has_method("play_cue"):
		ab.play_cue(&"thunder", origin, -3.0, 0.5)
		ab.play_cue(&"shadow_cast", origin, -1.0, 0.6)

func _spawn_boss_dust(at_pos: Vector3) -> void:
	var p := GPUParticles3D.new()
	p.name = "BossSpawnDust"
	p.amount = 80
	p.lifetime = 1.6
	p.one_shot = true
	p.explosiveness = 0.85
	p.visibility_aabb = AABB(Vector3(-3, 0, -3), Vector3(6, 5, 6))
	var mat := ParticleProcessMaterial.new()
	mat.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_RING
	mat.emission_ring_radius = 1.20
	mat.emission_ring_inner_radius = 0.70
	mat.emission_ring_axis = Vector3.UP
	mat.emission_ring_height = 0.10
	mat.direction = Vector3.UP
	mat.spread = 30.0
	mat.initial_velocity_min = 1.5
	mat.initial_velocity_max = 3.5
	mat.gravity = Vector3(0, -2.0, 0)
	mat.scale_min = 0.18
	mat.scale_max = 0.42
	# Dark dust + ember tinge: curse manifesting into the world
	mat.color = Color(0.40, 0.20, 0.18, 0.9)
	p.process_material = mat
	var quad := QuadMesh.new()
	quad.size = Vector2(0.30, 0.30)
	var smat := StandardMaterial3D.new()
	smat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	smat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	smat.albedo_color = Color(0.40, 0.20, 0.18, 0.85)
	smat.emission_enabled = true
	smat.emission = Color(0.95, 0.30, 0.10)
	smat.emission_energy_multiplier = 0.7
	smat.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
	smat.billboard_keep_scale = true
	quad.material = smat
	p.draw_pass_1 = quad
	get_tree().current_scene.add_child(p)
	p.global_position = at_pos
	get_tree().create_timer(2.5).timeout.connect(func(): if is_instance_valid(p): p.queue_free())

func _build_patterns(id: StringName) -> Array[BossAttackPattern]:
	var arr: Array[BossAttackPattern] = []
	# Pattern weights tuned for read-and-react feel:
	#   - common attacks: 6-8 (fire often, teach the player the moveset)
	#   - mid specials:  3-4 (force adaptation)
	#   - capstone/arena: 1   (rare, climactic, memorable)
	match id:
		&"usurper_enforcer":
			# Phase 0 (Iron Stance, 100%-66%): teach the moveset with one
			# telegraphed cone strike. Long enough windup to read.
			arr.append(_p(&"kazat_iron_swing", "Iron Swing",
				BossAttackPattern.Shape.FORWARD_CONE,
				1.0, 0.25, 0.7, 4.0, 90.0, 0, 4.0, 1.4, 0, 99, 8.0))
			# Phase 1 (Iron Resolve, 66%-33%): Iron Charge unlocks. Forces
			# the player to manage spacing.
			arr.append(_p(&"kazat_charge_line", "Iron Charge",
				BossAttackPattern.Shape.LINE,
				0.6, 0.40, 1.2, 11.0, 120.0, 0, 9.0, 1.0, 1, 99, 4.0))
			# Phase 2 (Iron Vow, 33%-0%): Ground Slam unlocks as Kazat
			# stops fencing and starts smashing.
			arr.append(_p(&"kazat_ground_slam", "Iron Quake",
				BossAttackPattern.Shape.AOE_AROUND_BOSS,
				1.4, 0.30, 1.0, 7.5, 160.0, 0, 6.0, 5.0, 2, 99, 5.0))
			# Phase 2 desperation: Final Vow only fires below 20% HP. A
			# slow telegraphed AOE_GROUND that hurts catastrophically if
			# you don't roll out of the targeted spot.
			arr.append(_p(&"kazat_final_vow", "Final Vow",
				BossAttackPattern.Shape.AOE_GROUND,
				1.8, 0.40, 1.2, 16.0, 280.0, 0, 6.0, 4.0, 2, 99, 2.0, 0.20))
		&"raid_captain":
			arr.append(_p(&"hassu_hook_thrust", "Hook Thrust",
				BossAttackPattern.Shape.LINE, 0.6, 0.20, 0.6, 5.0,
				75.0, 0, 6.0, 0.8, 0, 99, 8.0))
			arr.append(_p(&"hassu_sweep", "Hook Sweep",
				BossAttackPattern.Shape.FORWARD_CONE, 1.0, 0.30, 0.9, 7.0,
				90.0, 0, 4.5, 2.0, 0, 99, 4.0))
		&"siege_master":
			# Paladin intro mini-boss. Beleti the Siege-Master fights with hammer + shield-bash.
			arr.append(_p(&"beleti_hammer_swing", "Hammer Swing",
				BossAttackPattern.Shape.FORWARD_CONE, 0.9, 0.22, 0.6, 3.5,
				85.0, 0, 3.5, 1.6, 0, 99, 8.0))
			arr.append(_p(&"beleti_shield_bash", "Shield Bash",
				BossAttackPattern.Shape.SINGLE_TARGET, 0.6, 0.15, 0.5, 5.0,
				65.0, 0, 2.5, 1.0, 0, 99, 5.0))
			arr.append(_p(&"beleti_overhead_slam", "Overhead Slam",
				BossAttackPattern.Shape.AOE_GROUND, 1.5, 0.30, 1.0, 9.0,
				150.0, 0, 4.0, 3.5, 0, 99, 2.0))
		&"self_that_said_yes":
			# Demon intro mini-boss. A reflection of the player who took Lucifer's deal.
			# Mimics player abilities; uses every shape. Hard fight by design.
			arr.append(_p(&"reflection_strike", "Reflection Strike",
				BossAttackPattern.Shape.SINGLE_TARGET, 0.5, 0.18, 0.4, 3.0,
				100.0, 6, 3.5, 1.0, 0, 99, 7.0))
			arr.append(_p(&"reflection_void_arc", "Void Arc",
				BossAttackPattern.Shape.FORWARD_CONE, 0.9, 0.30, 0.7, 5.0,
				140.0, 7, 5.5, 2.5, 0, 99, 4.0))
			arr.append(_p(&"reflection_pillar_of_fire", "Pillar of the Yes",
				BossAttackPattern.Shape.AOE_GROUND, 1.6, 0.30, 1.0, 12.0,
				220.0, 2, 10.0, 4.0, 0, 99, 2.0))
			arr.append(_p(&"reflection_word_of_unmaking", "Word of Unmaking",
				BossAttackPattern.Shape.ARENA_WIDE, 3.5, 0.5, 2.5, 60.0,
				500.0, 6, 30.0, 4.0, 0, 99, 1.0, 0.30))
		&"tiamat":
			# Three-phase mother-of-monsters. Phase 0 attacks weight high, phase 2 capstones weight 1.
			arr.append(_p(&"tia_drown_grasp", "Drowning Grasp",
				BossAttackPattern.Shape.SINGLE_TARGET, 0.8, 0.25, 0.8, 6.0,
				180.0, 0, 4.0, 1.0, 0, 0, 8.0))
			arr.append(_p(&"tia_arcane_pulse", "Arcane Pulse",
				BossAttackPattern.Shape.AOE_AROUND_BOSS, 1.6, 0.40, 1.2, 12.0,
				260.0, 1, 8.0, 8.0, 1, 2, 5.0))
			arr.append(_p(&"tia_breath_cone", "Mother's Breath",
				BossAttackPattern.Shape.FORWARD_CONE, 2.0, 0.50, 1.5, 18.0,
				420.0, 2, 14.0, 4.0, 2, 2, 3.0))
			arr.append(_p(&"tia_arena_wave", "World-Wave",
				BossAttackPattern.Shape.ARENA_WIDE, 3.0, 0.5, 2.0, 30.0,
				600.0, 0, 30.0, 2.0, 2, 2, 1.0, 0.50))
		&"lucifer":
			arr.append(_p(&"luc_diplomatic_strike", "Diplomatic Strike",
				BossAttackPattern.Shape.SINGLE_TARGET, 0.7, 0.20, 0.6, 4.0,
				200.0, 6, 3.5, 1.0, 0, 0, 8.0))
			arr.append(_p(&"luc_hellfire_cone", "Hellfire Cone",
				BossAttackPattern.Shape.FORWARD_CONE, 1.5, 0.45, 1.2, 10.0,
				340.0, 2, 10.0, 5.0, 1, 2, 5.0))
			arr.append(_p(&"luc_fall_pillar", "Pillar of the Fall",
				BossAttackPattern.Shape.AOE_GROUND, 1.8, 0.40, 1.0, 14.0,
				420.0, 6, 8.0, 6.0, 1, 2, 4.0))
			arr.append(_p(&"luc_arena_inferno", "Arena Inferno",
				BossAttackPattern.Shape.ARENA_WIDE, 4.0, 0.6, 2.5, 40.0,
				700.0, 2, 35.0, 3.0, 2, 2, 1.0, 0.40))
	return arr

# Compact factory for an attack pattern.
# weight: priority for weighted-random selection (default 5.0)
# hp_below: requires_hp_below_pct (1.0 = always available, 0.30 = "desperation")
func _p(id: StringName, name: String, shape: int,
		windup: float, execute: float, recovery: float, cd: float,
		dmg: float, dmg_type: int, range_m: float, radius_m: float,
		min_phase: int = 0, max_phase: int = 99,
		weight: float = 5.0, hp_below: float = 1.0) -> BossAttackPattern:
	var p := BossAttackPattern.new()
	p.id = id
	p.display_name = name
	p.shape = shape
	p.windup_seconds = windup
	p.execute_seconds = execute
	p.recovery_seconds = recovery
	p.cooldown = cd
	p.base_damage = dmg
	p.damage_type = dmg_type
	p.range = range_m
	p.radius = radius_m
	p.min_phase = min_phase
	p.max_phase = max_phase
	p.priority_weight = weight
	p.requires_hp_below_pct = hp_below
	# Arena-wide patterns ignore reachability by default
	if shape == BossAttackPattern.Shape.ARENA_WIDE:
		p.ignores_reachability = true
	return p
