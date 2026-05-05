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
		spawn_boss()

func spawn_boss() -> void:
	var boss_scene := preload("res://scenes/enemies/boss_base.tscn") if ResourceLoader.exists("res://scenes/enemies/boss_base.tscn") else null
	if not boss_scene:
		return
	var inst := boss_scene.instantiate() as BossBase
	get_tree().current_scene.add_child(inst)
	inst.global_position = global_position

	# Apply registry data
	var rec = BossRegistry.get_boss(boss_id) if has_node("/root/BossRegistry") else null
	if rec:
		inst.boss_id = rec.id
		inst.display_name = rec.display_name
		inst.encounter_level = rec.encounter_level
		inst.is_main_boss = rec.is_main_boss
		inst.is_final_boss = rec.is_final_boss
		inst.is_secret_boss = rec.is_secret_boss
		inst.phases_data = rec.phases

	# Bake attack patterns matching the boss
	inst.attack_patterns = _build_patterns(boss_id)

func _build_patterns(id: StringName) -> Array[BossAttackPattern]:
	var arr: Array[BossAttackPattern] = []
	match id:
		&"usurper_enforcer":
			arr.append(_p(&"kazat_iron_swing", "Iron Swing",
				BossAttackPattern.Shape.FORWARD_CONE,
				1.0, 0.25, 0.7, 4.0,
				90.0, 0, 4.0, 1.4))
			arr.append(_p(&"kazat_ground_slam", "Ground Slam",
				BossAttackPattern.Shape.AOE_AROUND_BOSS,
				1.4, 0.30, 1.0, 8.0,
				140.0, 0, 6.0, 4.5))
			arr.append(_p(&"kazat_charge_line", "Iron Charge",
				BossAttackPattern.Shape.LINE,
				0.6, 0.40, 1.2, 12.0,
				120.0, 0, 9.0, 1.0))
		&"raid_captain":
			arr.append(_p(&"hassu_hook_thrust", "Hook Thrust",
				BossAttackPattern.Shape.LINE, 0.6, 0.20, 0.6, 5.0,
				75.0, 0, 6.0, 0.8))
			arr.append(_p(&"hassu_sweep", "Hook Sweep",
				BossAttackPattern.Shape.FORWARD_CONE, 1.0, 0.30, 0.9, 7.0,
				90.0, 0, 4.5, 2.0))
		&"tiamat":
			# Three-phase mother-of-monsters
			arr.append(_p(&"tia_drown_grasp", "Drowning Grasp",
				BossAttackPattern.Shape.SINGLE_TARGET, 0.8, 0.25, 0.8, 6.0,
				180.0, 0, 4.0, 1.0, 0, 0))
			arr.append(_p(&"tia_arcane_pulse", "Arcane Pulse",
				BossAttackPattern.Shape.AOE_AROUND_BOSS, 1.6, 0.40, 1.2, 12.0,
				260.0, 1, 8.0, 8.0, 1, 2))
			arr.append(_p(&"tia_breath_cone", "Mother's Breath",
				BossAttackPattern.Shape.FORWARD_CONE, 2.0, 0.50, 1.5, 18.0,
				420.0, 2, 14.0, 4.0, 2, 2))
			arr.append(_p(&"tia_arena_wave", "World-Wave",
				BossAttackPattern.Shape.ARENA_WIDE, 3.0, 0.5, 2.0, 30.0,
				600.0, 0, 30.0, 2.0, 2, 2))
		&"lucifer":
			arr.append(_p(&"luc_diplomatic_strike", "Diplomatic Strike",
				BossAttackPattern.Shape.SINGLE_TARGET, 0.7, 0.20, 0.6, 4.0,
				200.0, 6, 3.5, 1.0, 0, 0))
			arr.append(_p(&"luc_hellfire_cone", "Hellfire Cone",
				BossAttackPattern.Shape.FORWARD_CONE, 1.5, 0.45, 1.2, 10.0,
				340.0, 2, 10.0, 5.0, 1, 2))
			arr.append(_p(&"luc_fall_pillar", "Pillar of the Fall",
				BossAttackPattern.Shape.AOE_GROUND, 1.8, 0.40, 1.0, 14.0,
				420.0, 6, 8.0, 6.0, 1, 2))
			arr.append(_p(&"luc_arena_inferno", "Arena Inferno",
				BossAttackPattern.Shape.ARENA_WIDE, 4.0, 0.6, 2.5, 40.0,
				700.0, 2, 35.0, 3.0, 2, 2))
	return arr

# Compact factory for an attack pattern.
func _p(id: StringName, name: String, shape: int,
		windup: float, execute: float, recovery: float, cd: float,
		dmg: float, dmg_type: int, range_m: float, radius_m: float,
		min_phase: int = 0, max_phase: int = 99) -> BossAttackPattern:
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
	return p
