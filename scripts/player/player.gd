extends CharacterBody3D
class_name Player

# Marduk's champion. Camera-relative WASD movement, Diablo-style.
# Mesh rotates toward movement direction; body collider stays axis-aligned.

@export var stats: PlayerStats
@export var move_speed: float = 6.0
@export var rotation_speed: float = 14.0
@export var gravity: float = 24.0
@export var jump_velocity: float = 8.0

@onready var mesh: Node3D = $MeshRoot
var anim_player: AnimationPlayer = null

# Maps our generic animation slots to whatever the imported character provides.
# KayKit Adventurers ships with: Idle, Idle_Combat, Walking_A, Running_A,
# 1H_Melee_Attack_Slice_Diagonal, Dodge_Forward, Death_A, etc.
const ANIM_ALIASES := {
	# Resolution order: "marduk/<slot>" (merged by AnimationLibraryLoader from
	# AnimationRegistry) first, then legacy KayKit names so a class with no
	# Mixamo anims yet still moves.
	"idle":   ["marduk/katana_idle", "marduk/idle", "marduk/unarmed_idle", "Mixamo_Idle", "idle", "Idle", "Idle_Combat", "T-Pose", "Static"],
	"walk":   ["marduk/walk", "marduk/walk_back", "marduk/walk_left", "Mixamo_Walking", "walk", "Walking_A", "Walking_B", "Walking_C", "Run_Casual"],
	"run":    ["marduk/run", "marduk/run_left", "Mixamo_Running", "run", "Running_A", "Running_B", "Running_Strafe_Right"],
	"attack": ["marduk/attack_basic", "marduk/attack_combo_1", "marduk/cleave_1", "marduk/dagger_1", "marduk/iai_strike", "marduk/cast_release", "Mixamo_Sword_Slash", "attack", "1H_Melee_Attack_Slice_Diagonal", "1H_Melee_Attack_Slice_Horizontal", "1H_Melee_Attack_Chop", "Unarmed_Melee_Attack_Punch_A"],
	"dodge":  ["marduk/dodge_forward", "marduk/dodge_back", "marduk/dodge_corkscrew", "Mixamo_Dodge", "dodge", "Dodge_Forward", "Dodge_Right", "Cheer"],
	# Directional dodge variants resolved separately so _perform_dodge picks
	# the right Mixamo file based on input vs facing. Falls through to the
	# generic "dodge" slot when a direction is missing. Bond's 2026-05-07
	# anim drop filled all four cardinal slots.
	"dodge_forward":  ["marduk/dodge_forward", "marduk/dodge_corkscrew", "marduk/dodge_back"],
	"dodge_back":     ["marduk/dodge_back", "marduk/dodge_corkscrew", "marduk/dodge_forward"],
	"dodge_left":     ["marduk/dodge_left", "marduk/dodge_corkscrew", "marduk/dodge_back"],
	"dodge_right":    ["marduk/dodge_right", "marduk/dodge_corkscrew", "marduk/dodge_back"],
	"die":    ["marduk/death", "marduk/death_forward", "marduk/death_react_forward", "marduk/death_react_right", "marduk/death_back", "Mixamo_Dying", "die", "Death_A", "Death_A_Pose", "Death_B"],
	"hit":    ["marduk/hit_react", "marduk/hit_react_left", "marduk/hit_react_right", "Mixamo_Hit", "hit", "Hit_A", "Hit_B"],
	"jump":   ["marduk/jump_up", "marduk/jump_down", "Mixamo_Jump", "jump", "Jump_Full_Long", "Jump_Start"],
	"taunt":  ["marduk/taunt", "Mixamo_Taunt"],
	"stand_up": ["marduk/stand_up", "Mixamo_Stand"],
	"block":  ["marduk/block_idle", "marduk/katana_blocking", "marduk/shield_block"],
	# Heavy / iai / power_up: distinct anims for the 4-slot ability kit so
	# each Q/E/R/F plays a visibly different swing instead of the generic
	# attack_basic. Falls through to attack if the class hasn't downloaded
	# the specialised file yet.
	"heavy":    ["marduk/katana_jump_attack", "marduk/katana_impact", "marduk/attack_heavy", "marduk/attack_basic"],
	"iai":      ["marduk/katana_impact", "marduk/iai_strike", "marduk/attack_basic"],
	"power_up": ["marduk/katana_power_up", "marduk/taunt", "marduk/unarmed_idle_looking"],
	"turn":   ["marduk/turn_right", "marduk/change_direction", "marduk/run_to_turn", "marduk/katana_180"],
}

var _camera_basis_provider: Node3D
var input_dir: Vector3 = Vector3.ZERO
var locked: bool = false  # set true during ability windups, deaths, cutscenes

# Resource pools.
#   resource_value     = primary pool dictated by class.resource_mechanic
#                        (mana | stamina | rage | blood | focus | stance | corruption | form_energy)
#   stamina_value      = secondary stamina pool, ALWAYS tracked. Used by Druid form abilities,
#                        future sprint/dodge mechanics, and aliased to resource_value when the
#                        primary mechanic is &"stamina" itself (Assassin/Ronin/Ranger).
var resource_value: float = 0.0
var stamina_value: float = 100.0
const DEMON_DAY_DMG_MULT := 0.80
const DEMON_NIGHT_DMG_MULT := 1.20
const DEMON_NIGHT_HP_REGEN := 4.0
const DEMON_LIFESTEAL_PCT := 0.05
const DEMON_BLOOD_PER_KILL := 5.0
const DEMON_BLOOD_PER_BOSS := 25.0
const DEMON_KILL_HEAL_PCT := 0.05  # +5% max HP per kill for demons

# Shapeshift state (Druid + Demon wing-out). Null when in human form.
var current_form: Transformation = null
var _form_time_left: float = 0.0
var _saved_human_mesh: Node = null

# Ronin combo tracker. Last ability cast and timestamp; chain_predecessor + chain_window
# on the next ability gives a damage multiplier. Encourages learned form sequences.
var last_ability_id: StringName = &""
var last_ability_time: float = 0.0

# Inventory + character identity
var character_name: String = "Champion"
@export var inventory: Inventory

# Heaven sword permanent damage stack. Persisted via SaveFlags as `heaven_undead_kills`.
# Each undead/demon kill adds 0.0001 to the multiplier (0.01% per kill, no cap).
var _heaven_passive_heal_cd: float = 0.0
const HEAVEN_HEAL_INTERVAL := 1.0  # ticks once per second

# Stealth state (Assassin)
var _stealth_active: bool = false
var _stealth_breaks_after_attack: bool = true
var _ambush_pending: bool = false  # next hit from stealth gets bonus + auto-crit
const STEALTH_DETECTION_RADIUS_DEFAULT := 3.0

# Berserker rage scaling: as resource_value (rage) climbs 0->100, gain damage and speed.
# Read by combat code via get_rage_buffs(). Decays out of combat at RAGE_DECAY_PER_SEC.
const RAGE_MAX_DAMAGE_BONUS := 0.50   # at 100 rage, +50% melee damage
const RAGE_MAX_ATK_SPEED_BONUS := 0.30  # +30% atk speed
const RAGE_MAX_MOVE_SPEED_BONUS := 0.15  # +15% move speed
const RAGE_DECAY_PER_SEC := 4.0
var _last_combat_time: float = -INF
const RAGE_OUT_OF_COMBAT_GRACE := 5.0

# Battle-cry / Power-up damage buff timers. Set by Q/E/R/F abilities
# whose ID matches a known buff trigger (war_cry, power_up, battle_cry).
# Checked by get_outgoing_damage_mult() when computing swing damage.
var _damage_surge_until: float = 0.0
var _damage_surge_mult: float = 1.0
const BATTLE_CRY_DURATION := 6.0
const BATTLE_CRY_DAMAGE_BONUS := 0.35  # +35% outgoing damage for 6s

# Guard / block stance timer. While active, take_damage applies
# GUARD_DAMAGE_REDUCTION. Set by Guard ability (id &"guard").
var _guard_until: float = 0.0
const GUARD_DURATION := 2.0
const GUARD_DAMAGE_REDUCTION := 0.55  # take 45% damage while guarding

# Combo system: consecutive hits without taking damage build up a
# combo counter. Each stack adds COMBO_DMG_PER_STACK damage. Resets
# when player takes damage OR when no hit lands for COMBO_DECAY_TIME.
# Visible via combo_changed signal that the HUD listens to.
var _combo_count: int = 0
var _combo_decays_at: float = 0.0
const COMBO_DECAY_TIME := 4.5  # seconds before combo resets if no hit
const COMBO_MAX_STACKS := 30
const COMBO_DMG_PER_STACK := 0.05  # +5% damage per stack
signal combo_changed(stacks: int, max_stacks: int)

# Per-class buff color: tints the screen flash so each class's buff
# feels signature-y (Berserker red rage, Mage blue arcane, Demon
# hellfire, Paladin holy gold, etc.). Default gold for unknown.
const CLASS_BUFF_COLOR := {
	&"berserker":            Color(0.95, 0.30, 0.20, 1.0),  # rage red
	&"assassin":             Color(0.55, 0.30, 0.85, 1.0),  # shadow violet
	&"ronin":                Color(1.00, 0.85, 0.45, 1.0),  # gold (Kachujin)
	&"ranger":               Color(0.40, 0.85, 0.35, 1.0),  # forest green
	&"mage":                 Color(0.40, 0.65, 1.00, 1.0),  # arcane blue
	&"chaos_druid":          Color(0.55, 0.95, 0.40, 1.0),  # nature lime
	&"demon":                Color(0.85, 0.20, 0.30, 1.0),  # hellfire red
	&"paladin_guardian":     Color(0.95, 0.92, 0.75, 1.0),  # holy white-gold
	&"paladin_lightbringer": Color(1.00, 0.95, 0.55, 1.0),  # sun bright gold
}

# Buff trigger registries — abilities whose IDs match these get the
# corresponding effect. Adding new abilities to a class kit just needs
# the right ID pattern; no per-class plumbing.
const BATTLE_CRY_IDS := [
	&"war_cry", &"battle_cry", &"power_up", &"katana_power_up",
	&"bear_form", &"druid_form", &"demon_form",
	&"hawk_command", &"stealth_form",
]
const GUARD_IDS := [
	&"guard", &"parry",
	&"divine_shield", &"mana_shield",
]
const HEAL_IDS := [&"healing_aura", &"holy_blessing", &"healing_word"]
const HEAL_PCT_OF_MAX := 0.30  # 30% max HP per heal cast

# Surge-potion timers (epoch seconds). Set by use_potion(); checked by _tick_resource.
var _mana_surge_until: float = 0.0
var _stamina_surge_until: float = 0.0
var _hp_surge_until: float = 0.0
const SURGE_DURATION := 10.0
const SURGE_MULTIPLIER := 10.0

signal hp_changed(current: float, max_hp: float)
signal mana_changed(current: float, max_mana: float)
signal resource_changed(current: float, max_value: float, mechanic: StringName)
signal form_changed(form: Transformation)
signal died
signal item_collected(item: Item, quantity: int)

func _ready() -> void:
	add_to_group("player")
	if not stats:
		stats = PlayerStats.new()
		stats.recompute_derived()
	# Auto-class assignment: when the player spawns in an intro zone
	# (sword_vow_ruins, sunsworn_chapel, etc.) without a class picked
	# yet, infer the matching class from the zone. This means Kachujin
	# in Sword-Vow gets the Ronin katana_walk/run/idle overrides from
	# frame zero, instead of moving like an unarmed peasant.
	if stats and not stats.class_def:
		_auto_assign_class_from_scene()
	# Force-fresh HP/mana so HUD doesn't show stale values from the ProgressBar defaults
	stats.hp = stats.max_hp
	stats.mana = stats.max_mana
	if stats.class_def:
		resource_value = stats.class_def.resource_max if stats.class_def.resource_mechanic == &"mana" else 0.0
	_camera_basis_provider = get_tree().get_first_node_in_group("camera_rig")
	# Mixamo skin fix: reset bone poses + show rest only so the character
	# renders at T-pose instead of collapsing into a flat plane. Without
	# this, FBX-imported skinned meshes from Mixamo render invisible
	# until manual SkeletonProfileHumanoid retarget. Applied before any
	# animation work so the rest pose is the baseline.
	var fixer_script: GDScript = load("res://scripts/anim/mixamo_skeleton_fixer.gd")
	if fixer_script and fixer_script.has_method("fix") and mesh:
		fixer_script.fix(mesh)
	# Find the imported AnimationPlayer wherever it lives in the mesh hierarchy.
	# KayKit .glbs put AnimationPlayer inside the imported scene root, not directly under MeshRoot.
	anim_player = _find_animation_player(self)
	# Visibility safety net: if no MeshInstance3D is rendering under MeshRoot
	# (Mixamo import edge case, or scale collapses everything to a point),
	# spawn a tinted capsule fallback so the player position is always visible.
	# Also logs mesh AABB once for remote diagnostics.
	_install_visibility_fallback()
	# Merge shared + class-specific Mixamo anims onto the AnimationPlayer (silent if .fbx
	# files are missing on disk; gameplay falls through to whatever the mesh ships with).
	# NOTE: Mixamo character .glbs ship without an AnimationPlayer, so the loader
	# creates one if missing. After the loader runs, re-find anim_player so we
	# pick up the newly-created node.
	_load_marduk_animation_library()
	if anim_player == null:
		anim_player = _find_animation_player(self)
	# Resolve our generic animation aliases to whatever names the imported character uses.
	_resolve_anim_alias_map()
	# Loop the idle animation by default
	if anim_player:
		var idle_name: String = _resolved_anims.get("idle", "")
		if idle_name != "" and anim_player.has_animation(idle_name):
			anim_player.play(idle_name)

var _resolved_anims: Dictionary = {}  # generic key -> actual animation name in this character

# Walks the MeshRoot subtree to count visible MeshInstance3D nodes and
# computes their combined AABB. If the count is zero or the AABB is
# below 0.2m on any axis (effectively invisible due to scale collapse),
# spawn a colored capsule fallback so the player position is always
# discernible and log the diagnostic for remote debugging.
func _install_visibility_fallback() -> void:
	if not mesh:
		return
	var meshes: Array[MeshInstance3D] = []
	_collect_meshes(mesh, meshes)
	var combined_aabb := AABB()
	var first := true
	for mi in meshes:
		if mi.mesh == null:
			continue
		var aabb := mi.get_aabb()
		# Apply local scale chain up to MeshRoot
		var scale_chain: Vector3 = mi.global_transform.basis.get_scale()
		aabb.size *= scale_chain
		aabb.position *= scale_chain
		if first:
			combined_aabb = aabb
			first = false
		else:
			combined_aabb = combined_aabb.merge(aabb)
	var size: Vector3 = combined_aabb.size
	print("[Player] %d MeshInstance3D under MeshRoot, combined AABB size = %s" % [meshes.size(), str(size)])
	# Heuristic: a 1.7m-tall character should have AABB y >= 1.0m. If anything
	# collapses below 0.2m on the largest axis, the character is effectively
	# invisible.
	# Fallback capsule disabled while we test Mixamo skeleton-fix
	# rendering. Local AABB returned by mi.get_aabb() is the bind-pose
	# extent and doesn't reflect post-skinning rendered shape, so the
	# heuristic was firing false positives and the bright capsule was
	# occluding any Mixamo character that actually rendered.
	# Re-enable in a future iteration if the bug actually returns.
	if meshes.is_empty():
		_spawn_fallback_capsule()

func _collect_meshes(node: Node, out: Array[MeshInstance3D]) -> void:
	if node is MeshInstance3D:
		out.append(node)
	for c in node.get_children():
		_collect_meshes(c, out)

func _spawn_fallback_capsule() -> void:
	if mesh.get_node_or_null("FallbackCapsule") != null:
		return
	# Bright glowing capsule that's bigger than a normal character so
	# Bond can't miss it. Hue chosen to pop against the burned-out
	# Sword-Vow Ruins palette (pale gold against red-brown earth).
	var mi := MeshInstance3D.new()
	mi.name = "FallbackCapsule"
	var caps := CapsuleMesh.new()
	caps.radius = 0.5
	caps.height = 2.0
	mi.mesh = caps
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(1.0, 0.85, 0.30)
	mat.emission_enabled = true
	mat.emission = Color(1.0, 0.75, 0.25)
	mat.emission_energy_multiplier = 1.4
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_PER_PIXEL
	mi.material_override = mat
	mi.position = Vector3(0, 1.0, 0)
	mesh.add_child(mi)
	# Floating label above the capsule
	var lbl := Label3D.new()
	lbl.text = "PLAYER"
	lbl.font_size = 32
	lbl.outline_size = 6
	lbl.outline_modulate = Color(0, 0, 0, 0.9)
	lbl.modulate = Color(1.0, 0.95, 0.55)
	lbl.position = Vector3(0, 2.6, 0)
	lbl.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	lbl.no_depth_test = true
	lbl.fixed_size = true
	lbl.pixel_size = 0.005
	mesh.add_child(lbl)
	# Personal point light so the capsule is bright even at night
	var lit := OmniLight3D.new()
	lit.light_color = Color(1.0, 0.85, 0.40)
	lit.light_energy = 1.8
	lit.omni_range = 6.0
	lit.position = Vector3(0, 1.6, 0)
	mesh.add_child(lit)
	print("[Player] mesh invisible (skinning collapse) — spawned glowing fallback capsule + label + light")

# Look at the active scene's Geometry node (where ZoneComposer lives),
# read its style_id (e.g. &"sword_vow_ruins"), reverse-lookup the matching
# class via ClassIntros, and assign stats.class_def from ClassRegistry.
# This means Bond can drop straight into Sword-Vow Ruins and Kachujin
# already has the Ronin animation overrides + class kit + resource bar
# without needing to pick a class through a menu.
#
# No-op when the scene has no style_id, when the lookup misses, or when
# ClassRegistry isn't reachable. Doesn't override an already-set class.
func _auto_assign_class_from_scene() -> void:
	if stats and stats.class_def:
		return  # already picked
	var scene := get_tree().current_scene if get_tree() else null
	if scene == null:
		return
	var zone_id: StringName = _read_scene_zone_id(scene)
	if zone_id == &"":
		return
	# Reverse-lookup via ClassIntros (loaded as a script, not an autoload)
	var ci_script: GDScript = load("res://scripts/world/class_intros.gd")
	if ci_script == null:
		return
	var class_id: StringName = ci_script.class_for_zone(zone_id)
	if class_id == &"":
		return
	var registry: Node = get_node_or_null("/root/ClassRegistry")
	if registry == null or not registry.has_method("get_class_def"):
		return
	var class_def: PlayerClass = registry.get_class_def(class_id)
	if class_def == null:
		return
	stats.class_def = class_def
	# Recompute base stats now that we have a class. recompute_derived
	# runs the full pipeline (base + attribute bonuses + skill effects +
	# equipment) so HP/mana/str/dex/int/vit/armor all rescale.
	if stats.has_method("recompute_derived"):
		stats.recompute_derived()
		stats.hp = stats.max_hp
		stats.mana = stats.max_mana
	print("[Player] auto-assigned class %s from zone %s" % [class_id, zone_id])
	# Auto-accept the matching prologue quest so the player starts with
	# a real objective in the quest tracker, not 'Visit Ashurim plaza'.
	# Quest IDs follow the convention &"prologue_<class>".
	_auto_accept_prologue(class_id)

func _auto_accept_prologue(class_id: StringName) -> void:
	var qr: Node = get_node_or_null("/root/QuestRegistry")
	if qr == null or not qr.has_method("accept_quest"):
		return
	var quest_id: StringName = StringName("prologue_%s" % String(class_id))
	# Don't re-accept if already active (player coming back to the
	# zone after warping out)
	if qr.has_method("get_active_quests"):
		for q in qr.get_active_quests():
			var qid: StringName = q.id if "id" in q else q.get("id", &"")
			if qid == quest_id:
				return
	if qr.accept_quest(quest_id):
		print("[Player] auto-accepted prologue quest %s" % quest_id)

# Walk the scene to find a Geometry node carrying style_id (the
# ZoneComposer convention). Returns the StringName style_id or &"".
func _read_scene_zone_id(scene: Node) -> StringName:
	# Common case: scene root has a Geometry child with the script
	var geometry := scene.get_node_or_null("Geometry")
	if geometry and "style_id" in geometry:
		return StringName(String(geometry.style_id))
	# Fallback: walk the tree looking for any node with style_id
	for child in scene.get_children():
		if "style_id" in child:
			return StringName(String(child.style_id))
		var nested := child.get_node_or_null("Geometry")
		if nested and "style_id" in nested:
			return StringName(String(nested.style_id))
	return &""

# Pulls the Mixamo .fbx animations declared in AnimationRegistry onto this
# Player's AnimationPlayer under the canonical "marduk/<slot>" namespace.
# Keeps gameplay decoupled from filenames; ANIM_ALIASES picks up the merged
# names automatically. No-op if the autoloads or AnimationPlayer aren't ready.
#
# If class is unpicked we still merge SHARED anims so Kachujin / any character
# gets idle/walk/run/dodge/hit/death from day 1. Once class is picked
# (PlayerStats.class_def assigned), call this again to overlay the class
# slot map (e.g. ronin/katana_idle overrides shared idle).
func _load_marduk_animation_library() -> void:
	# Don't early-return on anim_player == null. Mixamo character .glbs ship
	# without an AnimationPlayer; the loader creates one if missing so this
	# function MUST run even when anim_player is null at this point.
	var loader_script: GDScript = load("res://scripts/anim/animation_library_loader.gd")
	if loader_script == null:
		return
	var loader = loader_script.new()
	if stats and stats.class_def:
		# Class picked: shared + class-specific overrides
		loader.apply(self, "class", StringName(stats.class_def.class_id))
	else:
		# No class yet: shared-only library so the character isn't a T-pose.
		# Pass an empty StringName -> get_class_slot_map() returns {} -> only
		# SHARED_SLOTS get merged. Once class is picked, this re-runs.
		loader.apply(self, "class", &"")

func _find_animation_player(node: Node) -> AnimationPlayer:
	if node is AnimationPlayer:
		return node as AnimationPlayer
	for child in node.get_children():
		var found := _find_animation_player(child)
		if found:
			return found
	return null

func _resolve_anim_alias_map() -> void:
	_resolved_anims.clear()
	if not anim_player:
		return
	var available: PackedStringArray = anim_player.get_animation_list()
	for slot_name in ANIM_ALIASES.keys():
		var aliases: Array = ANIM_ALIASES[slot_name]
		for alias in aliases:
			if alias in available:
				_resolved_anims[slot_name] = String(alias)
				break

func _input(event: InputEvent) -> void:
	# Basic attack: LMB swings a forward cone hitbox in front of the mesh.
	# This is the always-available fallback ability before any class-specific
	# ability is bound to a slot. Damage scales with primary attribute.
	if event.is_action_pressed("attack_basic"):
		_perform_basic_attack()
	elif event.is_action_pressed("interact"):
		_try_pickup_nearest_item()
	elif event.is_action_pressed("dodge"):
		_perform_dodge()
	elif event.is_action_pressed("ability_1"):
		_cast_ability_slot(0)
	elif event.is_action_pressed("ability_2"):
		_cast_ability_slot(1)
	elif event.is_action_pressed("ability_3"):
		_cast_ability_slot(2)
	elif event.is_action_pressed("ability_4"):
		_cast_ability_slot(3)
	elif event.is_action_pressed("toggle_mount"):
		toggle_mount()
	elif event.is_action_pressed("toggle_pet"):
		toggle_pet()
	elif event.is_action_pressed("lock_on"):
		_toggle_lock_on()

# --- Mount + Pet (WoW-style summon system) ---
# Mount: H key. While mounted, +60% movement speed and a visual mount mesh
# under the player. Dismounts on attack, dodge, or being hit.
const MOUNT_SPEED_BONUS: float = 0.6
var _mounted: bool = false
var _mount_visual: Node3D = null
var _base_move_speed: float = 0.0

func toggle_mount() -> void:
	if _mounted:
		_dismount()
	else:
		_mount()

func _mount() -> void:
	if locked or stats == null:
		return
	# Don't allow mounting in combat — last hit must be 5+ seconds ago
	var now: float = Time.get_ticks_msec() / 1000.0
	if now - _last_combat_time < 5.0:
		_play_deny_cue()
		return
	_mounted = true
	_base_move_speed = move_speed
	move_speed *= 1.0 + MOUNT_SPEED_BONUS
	# Cheap visual: blue glow disc under player + small horse stand-in mesh
	_mount_visual = MeshInstance3D.new()
	var mesh := BoxMesh.new()
	mesh.size = Vector3(0.8, 0.6, 1.6)
	(_mount_visual as MeshInstance3D).mesh = mesh
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.35, 0.20, 0.10)
	mat.roughness = 0.7
	(_mount_visual as MeshInstance3D).material_override = mat
	_mount_visual.position = Vector3(0, 0.4, 0)
	add_child(_mount_visual)
	var ab = get_node_or_null("/root/AudioBus")
	if ab and ab.has_method("play_cue"):
		ab.play_cue(&"warp", global_position, -8.0, 0.7)

func _dismount() -> void:
	if not _mounted:
		return
	_mounted = false
	move_speed = _base_move_speed if _base_move_speed > 0.0 else move_speed
	if _mount_visual and is_instance_valid(_mount_visual):
		_mount_visual.queue_free()
	_mount_visual = null

# Pet: G key. Summons a follower mob that auto-attacks the player's last
# attack target. Despawns on a second G press or on player death.
var _pet: Node = null

func toggle_pet() -> void:
	if _pet and is_instance_valid(_pet):
		_pet.queue_free()
		_pet = null
		return
	# Simple stub pet: a small Area3D with floating text "Pet" that
	# follows the player. Real pet AI lives in PetRegistry but this gives
	# us a visible cue tonight.
	var pet := CharacterBody3D.new()
	pet.add_to_group("pet")
	pet.collision_layer = 4
	pet.collision_mask = 1
	var cs := CollisionShape3D.new()
	var caps := CapsuleShape3D.new()
	caps.radius = 0.3
	caps.height = 1.0
	cs.shape = caps
	pet.add_child(cs)
	var mi := MeshInstance3D.new()
	var sphere := SphereMesh.new()
	sphere.radius = 0.4
	sphere.height = 0.8
	mi.mesh = sphere
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.95, 0.65, 0.25)
	mat.emission_enabled = true
	mat.emission = Color(0.95, 0.65, 0.25)
	mat.emission_energy_multiplier = 0.4
	mi.material_override = mat
	mi.position = Vector3(0, 0.6, 0)
	pet.add_child(mi)
	var lbl := Label3D.new()
	lbl.text = character_name + "'s Pet"
	lbl.font_size = 18
	lbl.modulate = Color(1.0, 0.85, 0.55)
	lbl.outline_size = 4
	lbl.no_depth_test = true
	lbl.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	lbl.position = Vector3(0, 1.4, 0)
	pet.add_child(lbl)
	# Attach a tiny follow script via lambda timer
	var follow_timer := Timer.new()
	follow_timer.wait_time = 0.05
	follow_timer.autostart = true
	pet.add_child(follow_timer)
	follow_timer.timeout.connect(func():
		if not is_instance_valid(pet):
			return
		var to_player: Vector3 = global_position - pet.global_position
		var dist: float = to_player.length()
		if dist > 4.0:
			pet.velocity.x = to_player.normalized().x * (move_speed * 0.95)
			pet.velocity.z = to_player.normalized().z * (move_speed * 0.95)
		elif dist > 2.0:
			pet.velocity.x = to_player.normalized().x * (move_speed * 0.5)
			pet.velocity.z = to_player.normalized().z * (move_speed * 0.5)
		else:
			pet.velocity.x = 0
			pet.velocity.z = 0
		# Gravity
		if not pet.is_on_floor():
			pet.velocity.y -= 24.0 * 0.05
		pet.move_and_slide()
	)
	pet.global_position = global_position + Vector3(1.0, 0, 1.0)
	get_tree().current_scene.add_child(pet)
	_pet = pet
	var ab = get_node_or_null("/root/AudioBus")
	if ab and ab.has_method("play_cue"):
		ab.play_cue(&"pickup", global_position, -6.0, 1.4)

# Class kit: 4-slot list of (display_name, range, radius, damage_mult,
# cooldown, target_mode, animation_alias). Resolved in _ready from
# stats.class_def.class_id. Indexes map to Q / E / R / F.
var _ability_kit: Array = []
var _ability_cooldowns: Array = [0.0, 0.0, 0.0, 0.0]

func _build_ability_kit() -> void:
	_ability_kit.clear()
	if not stats or not stats.class_def:
		_ability_kit = _kit_default()
		return
	match stats.class_def.class_id:
		&"ronin":                _ability_kit = _kit_ronin()
		&"berserker":            _ability_kit = _kit_berserker()
		&"assassin":             _ability_kit = _kit_assassin()
		&"ranger":               _ability_kit = _kit_ranger()
		&"mage":                 _ability_kit = _kit_mage()
		&"chaos_druid":          _ability_kit = _kit_druid()
		&"demon":                _ability_kit = _kit_demon()
		&"paladin_guardian":     _ability_kit = _kit_paladin_guardian()
		&"paladin_lightbringer": _ability_kit = _kit_paladin_light()
		_:                       _ability_kit = _kit_default()

func _cast_ability_slot(slot: int) -> void:
	if locked or stats == null:
		return
	if slot < 0 or slot >= _ability_kit.size():
		return
	if _ability_kit[slot].is_empty():
		return
	var now: float = Time.get_ticks_msec() / 1000.0
	if _ability_cooldowns[slot] > now:
		_play_deny_cue()
		return
	var k: Dictionary = _ability_kit[slot]
	# Cost gate: spend resource if any
	var cost: float = float(k.get("cost", 0.0))
	if cost > 0.0 and stats.class_def:
		if stats.class_def.resource_mechanic == &"mana":
			if stats.mana < cost:
				_play_deny_cue()
				return
			stats.mana -= cost
			mana_changed.emit(stats.mana, stats.max_mana)
		elif stats.class_def.resource_mechanic == &"stamina":
			if resource_value < cost:
				_play_deny_cue()
				return
			resource_value = max(0.0, resource_value - cost)
			resource_changed.emit(resource_value, stats.class_def.resource_max, &"stamina")
	# Cooldown
	_ability_cooldowns[slot] = now + float(k.get("cooldown", 1.0))
	# Buff trigger: well-known ability ids grant a temporary damage
	# surge instead of (or in addition to) hitting an enemy. This is
	# what makes War Cry / Power Up / Battle Cry feel useful instead
	# of being a 0-damage taunt with a long cooldown.
	var ability_id: StringName = StringName(k.get("id", ""))
	if ability_id in BATTLE_CRY_IDS:
		_trigger_battle_cry()
	elif ability_id in GUARD_IDS:
		_trigger_guard()
	elif ability_id in HEAL_IDS:
		_trigger_heal()
	# Animation cue (best-effort)
	if anim_player:
		var anim_key: String = String(k.get("anim", "attack"))
		var resolved: String = _resolved_anims.get(anim_key, "")
		if resolved == "":
			resolved = _resolved_anims.get("attack", "")
		if resolved != "":
			anim_player.stop()
			anim_player.play(resolved)
	# Spawn a hitbox in front of the player using the existing combat layer.
	var hb := preload("res://scripts/combat/hitbox.gd").new()
	var swing := Ability.new()
	swing.id = StringName(k.get("id", "ability"))
	swing.display_name = String(k.get("name", "Ability"))
	swing.base_damage = float(k.get("damage", 30.0))
	swing.damage_type = int(k.get("element", Ability.DamageType.PHYSICAL))
	swing.target_mode = Ability.TargetMode.FORWARD_CONE
	swing.range = float(k.get("range", 3.0))
	swing.radius = float(k.get("radius", 1.5))
	swing.attribute_scaling = 0.4
	hb.ability = swing
	hb.attacker_stats = stats
	hb.lifetime = 0.20
	hb.team = &"player"
	var collider := CollisionShape3D.new()
	hb.add_child(collider)
	var b := BoxShape3D.new()
	b.size = Vector3(swing.radius * 2.0, 2.0, swing.range)
	collider.shape = b
	var fwd := -mesh.global_transform.basis.z if mesh else -global_transform.basis.z
	fwd.y = 0; fwd = fwd.normalized()
	hb.position = global_position + fwd * (swing.range * 0.5)
	hb.look_at(global_position + fwd * swing.range, Vector3.UP)
	get_tree().current_scene.add_child(hb)
	# Audio cue
	var ab = get_node_or_null("/root/AudioBus")
	if ab and ab.has_method("play_cue"):
		ab.play_cue(&"swing", global_position, -7.0, float(k.get("pitch", 1.0)))
	# Breath-trail VFX. Picks Demon Slayer style by ability id when available
	# so Ronin's swings actually look like breathing forms.
	var trail_style: StringName = _trail_style_for(StringName(k.get("id", "")))
	if trail_style != &"":
		var trail_script: GDScript = load("res://scripts/vfx/breath_trail.gd")
		if trail_script and trail_script.has_method("spawn"):
			trail_script.spawn(self, trail_style)
	on_combat_event(2.0)

# Maps ability ids -> Demon-Slayer-style breathing colors. Non-Ronin classes
# get a neutral physical / element style based on the ability's element.
func _trail_style_for(ability_id: StringName) -> StringName:
	var s: String = String(ability_id)
	# Ronin breathing forms
	if s.begins_with("water_breath") or s == "iai_strike": return &"water"
	if s.begins_with("thunder_breath"): return &"thunder"
	if s.begins_with("flame_breath"): return &"flame"
	if s.begins_with("wind_breath"): return &"wind"
	if s.begins_with("stone_breath"): return &"stone"
	if s.begins_with("mist_breath"): return &"mist"
	if s.begins_with("sun_breath"): return &"sun"
	if s.begins_with("moon_breath"): return &"moon"
	# Non-ronin elemental fallbacks
	if "fireball" in s or "hellfire" in s: return &"flame"
	if "frost" in s: return &"mist"
	if "spark" in s or "lightning" in s: return &"thunder"
	if "holy" in s or "sun_beam" in s or "judgment" in s or "smite" in s: return &"sun"
	if "shadow" in s or "soul_drain" in s: return &"moon"
	if "vine" in s or "wolf" in s: return &"wind"
	# Generic physical: thin water-blue trail so combat reads
	return &"water"

func _play_deny_cue() -> void:
	var ab = get_node_or_null("/root/AudioBus")
	if ab and ab.has_method("play_cue"):
		ab.play_cue(&"deny", global_position, -10.0, 1.0)

# --- Damage surge buffs (Battle Cry / Power Up) ---
func _trigger_battle_cry() -> void:
	var now: float = Time.get_ticks_msec() / 1000.0
	_damage_surge_until = now + BATTLE_CRY_DURATION
	_damage_surge_mult = 1.0 + BATTLE_CRY_DAMAGE_BONUS
	var color: Color = _class_buff_color()
	var label: String = _battle_cry_label()
	# Visual + audio feel: class-themed flash, named toast, audio cue.
	var juice: Node = get_node_or_null("/root/Juice")
	if juice:
		if juice.has_method("flash"):
			juice.flash(color, 0.18, 0.40)
		if juice.has_method("toast"):
			juice.toast("%s  +%d%% DMG  %ds" % [label, int(BATTLE_CRY_DAMAGE_BONUS * 100), int(BATTLE_CRY_DURATION)], color, 1.6)
	var ab: Node = get_node_or_null("/root/AudioBus")
	if ab and ab.has_method("play_cue"):
		ab.play_cue(&"taunt", global_position, -3.0, 0.92)

# Returns the class-themed buff flash color, or default gold if no class
# is picked / class is unknown.
func _class_buff_color() -> Color:
	if not stats or not stats.class_def:
		return Color(1.00, 0.85, 0.45, 1.0)
	return CLASS_BUFF_COLOR.get(stats.class_def.class_id, Color(1.00, 0.85, 0.45, 1.0))

# Class-flavored toast label so the buff feels themed instead of every
# class shouting "BATTLE CRY". Falls back to BATTLE CRY for unknowns.
func _battle_cry_label() -> String:
	if not stats or not stats.class_def:
		return "BATTLE CRY"
	match stats.class_def.class_id:
		&"berserker":            return "RAGE UNCHAINED"
		&"assassin":             return "SHADOW VEIL"
		&"ronin":                return "STANCE RESOLVE"
		&"ranger":               return "HAWK'S EYE"
		&"mage":                 return "ARCANE FOCUS"
		&"chaos_druid":          return "PRIMAL FORM"
		&"demon":                return "DEMON UNLEASHED"
		&"paladin_guardian":     return "HOLY ZEAL"
		&"paladin_lightbringer": return "SUNBLESSED"
	return "BATTLE CRY"

# Read by combat code (hitbox / ability_runner) to scale outgoing
# damage. Stacks Battle Cry surge + combo bonus multiplicatively so
# a 12-stack combo + active Battle Cry deals 1.35 * (1 + 12*0.05) =
# 2.16x normal damage.
func get_outgoing_damage_mult() -> float:
	var now: float = Time.get_ticks_msec() / 1000.0
	var mult: float = 1.0
	if now < _damage_surge_until:
		mult *= _damage_surge_mult
	# Combo bonus
	mult *= (1.0 + float(_combo_count) * COMBO_DMG_PER_STACK)
	return mult

# Called from hitbox when this player lands a hit. Adds a combo stack
# and refreshes the decay timer. Caps at COMBO_MAX_STACKS so the
# multiplier doesn't run unbounded.
func on_hit_landed() -> void:
	_combo_count = min(_combo_count + 1, COMBO_MAX_STACKS)
	_combo_decays_at = (Time.get_ticks_msec() / 1000.0) + COMBO_DECAY_TIME
	combo_changed.emit(_combo_count, COMBO_MAX_STACKS)

func _tick_combo(_delta: float) -> void:
	if _combo_count == 0:
		return
	if Time.get_ticks_msec() / 1000.0 >= _combo_decays_at:
		_combo_count = 0
		combo_changed.emit(0, COMBO_MAX_STACKS)

func get_combo_count() -> int:
	return _combo_count

# Returns true while the Guard / Parry ability's stance is active. Read
# by take_damage to soak incoming damage.
func is_guarding() -> bool:
	return Time.get_ticks_msec() / 1000.0 < _guard_until

func _trigger_guard() -> void:
	var now: float = Time.get_ticks_msec() / 1000.0
	_guard_until = now + GUARD_DURATION
	# Class-themed flash for the stance entry. Berserker gets red guard
	# (defiance!), Mage gets blue (mana shield), Paladin gets gold
	# (divine), etc. Defaults to a steel blue if no class picked.
	var color: Color = _class_buff_color()
	# Lighten slightly so guard reads as defensive vs the saturated
	# Battle Cry color
	color = color.lightened(0.25)
	var juice: Node = get_node_or_null("/root/Juice")
	if juice and juice.has_method("flash"):
		juice.flash(color, 0.10, 0.20)
	if juice and juice.has_method("toast"):
		juice.toast(_guard_label(), color, 1.0)

func _guard_label() -> String:
	if not stats or not stats.class_def:
		return "GUARD"
	match stats.class_def.class_id:
		&"mage":                 return "MANA SHIELD"
		&"paladin_guardian":     return "DIVINE SHIELD"
		&"paladin_lightbringer": return "DIVINE SHIELD"
		&"ronin":                return "PARRY STANCE"
	return "GUARD"

# Healing pulse: heals HEAL_PCT_OF_MAX of max HP, fires green flash +
# toast. Used by Lightbringer's Healing Aura and other heal-themed
# abilities. Doesn't grant the Battle Cry damage buff so it stays a
# pure defensive option.
func _trigger_heal() -> void:
	if not stats:
		return
	var amount: float = stats.max_hp * HEAL_PCT_OF_MAX
	heal(amount)
	var juice: Node = get_node_or_null("/root/Juice")
	if juice:
		if juice.has_method("flash"):
			juice.flash(Color(0.40, 0.95, 0.55), 0.15, 0.45)
		if juice.has_method("toast"):
			juice.toast("HEALED  +%d HP" % int(amount), Color(0.40, 0.95, 0.55), 1.4)
	var ab: Node = get_node_or_null("/root/AudioBus")
	if ab and ab.has_method("play_cue"):
		ab.play_cue(&"heal", global_position, -6.0, 1.0)

# --- Class kits ---
# Default kit: 4 standard abilities every class can fall back to. Each
# uses a distinct anim alias so visually they read differently. Class
# kits below override this for class-specific flavor.
func _kit_default() -> Array:
	return [
		# Q: Light Strike - quick fast slash. Uses attack alias (attack_basic).
		{"id": &"light_strike", "name": "Light Strike", "damage": 25.0, "range": 2.5, "radius": 1.4, "cooldown": 0.6, "anim": "attack"},
		# E: Heavy Strike - slow big-damage downward swing. Uses heavy alias
		# which resolves to katana_jump_attack -> katana_impact -> attack_basic.
		{"id": &"heavy_strike", "name": "Heavy Strike", "damage": 60.0, "range": 3.2, "radius": 2.0, "cooldown": 2.4, "anim": "heavy", "pitch": 0.78},
		# R: Battle Cry - 6s self-buff +35% damage. Triggers _trigger_battle_cry.
		# Uses power_up alias (katana_power_up). 0 damage, big cooldown.
		{"id": &"battle_cry", "name": "Battle Cry", "damage": 0.0, "range": 1.0, "radius": 1.0, "cooldown": 18.0, "anim": "power_up"},
		# F: Guard - block stance for 2s soaking damage. Uses block alias.
		# Combat code reads is_blocking() for damage soak (separate wire).
		{"id": &"guard", "name": "Guard", "damage": 0.0, "range": 1.0, "radius": 1.0, "cooldown": 4.0, "anim": "block"},
	]

func _kit_ronin() -> Array:
	# Each ability uses a different anim alias so Q/E/R/F look distinct
	# in play. All resolve to Mixamo .glbs Bond has on disk for Kachujin.
	return [
		# Q: Iai Strike - sudden draw + slash. Uses iai alias -> katana_impact.
		{"id": &"iai_strike", "name": "Iai Strike", "damage": 38.0, "range": 3.2, "radius": 1.0, "cooldown": 0.6, "cost": 8.0, "anim": "iai", "pitch": 1.4},
		# E: Water Breath - quick combo flow. Uses attack alias (attack_basic).
		{"id": &"water_breath_1", "name": "Water Breath: First Form", "damage": 32.0, "range": 4.5, "radius": 2.0, "cooldown": 1.2, "cost": 12.0, "anim": "attack", "pitch": 0.95},
		# R: Thunder Breath - airborne downward slam. Uses heavy alias ->
		# katana_jump_attack. Big damage, big cooldown, massive readability.
		{"id": &"thunder_breath_1", "name": "Thunder Breath: First Form", "damage": 56.0, "range": 6.5, "radius": 1.6, "cooldown": 4.0, "cost": 24.0, "anim": "heavy", "pitch": 1.6},
		# F: Power Up - 6s damage surge. Triggers _trigger_battle_cry via
		# the &"katana_power_up" id match. Replaces the dead 0-dmg parry.
		{"id": &"katana_power_up", "name": "Stance Resolve", "damage": 0.0, "range": 1.0, "radius": 1.0, "cooldown": 18.0, "anim": "power_up"},
	]

func _kit_berserker() -> Array:
	# Aggression. War Cry triggers Battle Cry buff (red rage flash).
	return [
		# Q: Cleave - quick wide swing
		{"id": &"cleave_1", "name": "Cleave", "damage": 40.0, "range": 3.0, "radius": 2.0, "cooldown": 0.8, "anim": "attack", "pitch": 0.85},
		# E: Leap Smash - airborne committed attack
		{"id": &"leap_smash", "name": "Leap Smash", "damage": 60.0, "range": 4.0, "radius": 2.4, "cooldown": 6.0, "anim": "heavy", "pitch": 0.8},
		# R: War Cry - +35% damage buff for 6s (Battle Cry trigger)
		{"id": &"war_cry", "name": "War Cry", "damage": 0.0, "range": 6.0, "radius": 6.0, "cooldown": 14.0, "anim": "power_up"},
		# F: Fury Swing - heaviest strike, gates on long cooldown
		{"id": &"fury_swing", "name": "Fury Swing", "damage": 80.0, "range": 3.5, "radius": 2.0, "cooldown": 4.0, "anim": "heavy", "pitch": 0.75},
	]

func _kit_assassin() -> Array:
	# Quick precision; Stealth doubles as a Battle Cry buff trigger.
	return [
		# Q: Dagger Combo - quick draw + slash via iai (katana_impact)
		{"id": &"dagger_1", "name": "Dagger Combo", "damage": 24.0, "range": 2.2, "radius": 1.0, "cooldown": 0.4, "cost": 5.0, "anim": "iai", "pitch": 1.5},
		# E: Backstab - heavy precision strike
		{"id": &"backstab", "name": "Backstab", "damage": 70.0, "range": 2.0, "radius": 0.8, "cooldown": 5.0, "cost": 18.0, "anim": "heavy", "pitch": 1.3},
		# R: Throw Kunai - ranged
		{"id": &"throw_kunai", "name": "Throw Kunai", "damage": 22.0, "range": 12.0, "radius": 0.6, "cooldown": 1.0, "cost": 8.0, "anim": "attack", "pitch": 1.6},
		# F: Shadow Veil - 6s damage buff (themed flash violet)
		{"id": &"stealth_form", "name": "Shadow Veil", "damage": 0.0, "range": 1.0, "radius": 1.0, "cooldown": 18.0, "anim": "power_up"},
	]

func _kit_ranger() -> Array:
	# Bow class: range + Hawk's Eye buff.
	return [
		# Q: Arrow Shot - basic ranged
		{"id": &"arrow_shot", "name": "Arrow Shot", "damage": 30.0, "range": 14.0, "radius": 0.6, "cooldown": 0.5, "cost": 5.0, "anim": "attack", "pitch": 1.3},
		# E: Snipe - charged precision
		{"id": &"snipe", "name": "Snipe", "damage": 90.0, "range": 24.0, "radius": 0.5, "cooldown": 6.0, "cost": 22.0, "anim": "heavy", "pitch": 1.0},
		# R: Hawk's Eye - +35% damage buff (Battle Cry trigger via hawk_command id)
		{"id": &"hawk_command", "name": "Hawk's Eye", "damage": 0.0, "range": 1.0, "radius": 1.0, "cooldown": 14.0, "anim": "power_up"},
		# F: Bear Trap - place hostile zone
		{"id": &"trap_set", "name": "Bear Trap", "damage": 35.0, "range": 4.0, "radius": 1.5, "cooldown": 10.0, "anim": "block"},
	]

func _kit_mage() -> Array:
	# Spell-slinger: Mana Shield is Guard, Frost Nova is AOE.
	return [
		# Q: Spark - quick ranged lightning
		{"id": &"spark", "name": "Spark", "damage": 22.0, "range": 12.0, "radius": 1.0, "cooldown": 0.6, "cost": 5.0, "element": Ability.DamageType.LIGHTNING, "anim": "iai", "pitch": 1.5},
		# E: Fireball - charged AOE
		{"id": &"fireball", "name": "Fireball", "damage": 65.0, "range": 14.0, "radius": 2.5, "cooldown": 3.0, "cost": 22.0, "element": Ability.DamageType.FIRE, "anim": "heavy", "pitch": 0.85},
		# R: Frost Nova - point-blank AOE freeze
		{"id": &"frost_nova", "name": "Frost Nova", "damage": 45.0, "range": 5.0, "radius": 5.0, "cooldown": 8.0, "cost": 28.0, "element": Ability.DamageType.FROST, "anim": "attack", "pitch": 0.7},
		# F: Mana Shield - 2s damage soak (Guard trigger via mana_shield id)
		{"id": &"mana_shield", "name": "Mana Shield", "damage": 0.0, "range": 1.0, "radius": 1.0, "cooldown": 6.0, "cost": 15.0, "anim": "block"},
	]

func _kit_druid() -> Array:
	# Shapeshifter; Druid Form triggers Battle Cry-equivalent buff.
	return [
		# Q: Vine Lash - quick range
		{"id": &"vine_lash", "name": "Vine Lash", "damage": 30.0, "range": 5.0, "radius": 1.5, "cooldown": 0.7, "cost": 6.0, "anim": "attack", "pitch": 0.9},
		# E: Bear Swipe - heavy melee
		{"id": &"bear_swipe", "name": "Bear Swipe", "damage": 55.0, "range": 3.0, "radius": 2.4, "cooldown": 4.0, "cost": 18.0, "anim": "heavy", "pitch": 0.7},
		# R: Druid Form - Battle Cry-equivalent buff (lime flash)
		{"id": &"druid_form", "name": "Primal Form", "damage": 0.0, "range": 1.0, "radius": 1.0, "cooldown": 18.0, "anim": "power_up"},
		# F: Plant Totem - utility AOE that places a stationary aura
		{"id": &"totem_plant", "name": "Plant Totem", "damage": 0.0, "range": 3.0, "radius": 4.0, "cooldown": 18.0, "cost": 25.0, "anim": "stand_up"},
	]

func _kit_demon() -> Array:
	# Hellfire + soul magic; Demon Form is the buff cap.
	return [
		# Q: Claw Rake - fast melee
		{"id": &"claw_rake", "name": "Claw Rake", "damage": 38.0, "range": 2.6, "radius": 1.4, "cooldown": 0.5, "anim": "iai", "pitch": 0.95},
		# E: Hellfire Burst - AOE fire
		{"id": &"hellfire_burst", "name": "Hellfire Burst", "damage": 70.0, "range": 5.0, "radius": 5.0, "cooldown": 6.0, "element": Ability.DamageType.FIRE, "anim": "heavy", "pitch": 0.7},
		# R: Soul Drain - shadow lifesteal (range)
		{"id": &"soul_drain", "name": "Soul Drain", "damage": 55.0, "range": 8.0, "radius": 1.5, "cooldown": 4.0, "element": Ability.DamageType.SHADOW, "anim": "attack", "pitch": 0.85},
		# F: Demon Form - Battle Cry buff (hellfire-red flash)
		{"id": &"demon_form", "name": "Demon Unleashed", "damage": 0.0, "range": 1.0, "radius": 1.0, "cooldown": 18.0, "anim": "power_up"},
	]

func _kit_paladin_guardian() -> Array:
	# Tank-paladin: Divine Shield is Guard, holy strikes for damage.
	return [
		# Q: Sword Smite - holy melee
		{"id": &"sword_smite", "name": "Sword Smite", "damage": 42.0, "range": 3.0, "radius": 1.6, "cooldown": 0.7, "cost": 6.0, "element": Ability.DamageType.HOLY, "anim": "attack", "pitch": 1.1},
		# E: Shield Bash - close stagger
		{"id": &"shield_bash", "name": "Shield Bash", "damage": 28.0, "range": 2.4, "radius": 1.6, "cooldown": 4.0, "cost": 12.0, "anim": "block", "pitch": 0.9},
		# R: Judgment Strike - heavy holy slam (capstone)
		{"id": &"judgment", "name": "Judgment Strike", "damage": 110.0, "range": 3.5, "radius": 2.0, "cooldown": 18.0, "cost": 50.0, "element": Ability.DamageType.HOLY, "anim": "heavy", "pitch": 0.9},
		# F: Divine Shield - 2s damage soak (Guard trigger)
		{"id": &"divine_shield", "name": "Divine Shield", "damage": 0.0, "range": 1.0, "radius": 1.0, "cooldown": 12.0, "cost": 30.0, "anim": "power_up"},
	]

func _kit_paladin_light() -> Array:
	# Holy support: Sun Beam ranged, Healing Aura HEALS the player.
	return [
		# Q: Mace Swing - basic holy melee
		{"id": &"mace_swing", "name": "Mace Swing", "damage": 30.0, "range": 2.6, "radius": 1.4, "cooldown": 0.6, "cost": 4.0, "element": Ability.DamageType.HOLY, "anim": "attack"},
		# E: Sun Beam - focused holy beam
		{"id": &"sun_beam", "name": "Sun Beam", "damage": 60.0, "range": 12.0, "radius": 1.0, "cooldown": 5.0, "cost": 24.0, "element": Ability.DamageType.HOLY, "anim": "iai", "pitch": 1.4},
		# R: Holy Pillar - heavy AOE
		{"id": &"holy_pillar", "name": "Holy Pillar", "damage": 80.0, "range": 5.0, "radius": 2.5, "cooldown": 12.0, "cost": 35.0, "element": Ability.DamageType.HOLY, "anim": "heavy", "pitch": 1.0},
		# F: Healing Aura - heals player 30% max HP (Heal trigger)
		{"id": &"healing_aura", "name": "Healing Aura", "damage": 0.0, "range": 4.0, "radius": 8.0, "cooldown": 18.0, "cost": 35.0, "anim": "power_up"},
	]

# Short forward dash with i-frames + dodge animation. Bound to Shift via
# the InputMap action `dodge`. Costs 15 stamina; if no stamina mechanic
# is set yet (early-game / unassigned class) the dodge still works at
# half strength.
const DODGE_DISTANCE: float = 4.0
const DODGE_DURATION: float = 0.32
const DODGE_STAMINA_COST: float = 15.0
var _dodging: bool = false
var _dodge_iframes_until: float = 0.0
const DODGE_IFRAME_DURATION: float = 0.25

func _perform_dodge() -> void:
	if _dodging or locked or not stats:
		return
	# Stamina gate (or rage-class equivalent). Don't crash if no class.
	var has_stamina: bool = stats.class_def != null and stats.class_def.resource_mechanic == &"stamina"
	if has_stamina and resource_value < DODGE_STAMINA_COST:
		return
	if has_stamina:
		resource_value = max(0.0, resource_value - DODGE_STAMINA_COST)
	# Direction: current input dir if moving, else mesh forward
	var dir: Vector3 = input_dir
	if dir.length_squared() < 0.001 and mesh:
		dir = -mesh.global_transform.basis.z
	dir.y = 0
	if dir.length_squared() < 0.001:
		return
	dir = dir.normalized()
	# Directional animation: pick the dodge slot that matches the dodge
	# vector relative to the player's facing. Forward dot > 0.5 -> forward;
	# < -0.5 -> back; otherwise classify by sign of right-cross.
	if anim_player:
		var slot_key: String = _classify_dodge_dir(dir)
		var anim_name: String = _resolved_anims.get(slot_key, _resolved_anims.get("dodge", ""))
		if anim_name != "":
			anim_player.stop()
			anim_player.play(anim_name)
	_dodging = true
	_dodge_iframes_until = (Time.get_ticks_msec() / 1000.0) + DODGE_IFRAME_DURATION
	# Tween position over DODGE_DURATION
	var target_pos := global_position + dir * DODGE_DISTANCE
	var tw := create_tween()
	tw.tween_property(self, "global_position", target_pos, DODGE_DURATION).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	tw.tween_callback(func(): _dodging = false)

# Picks the right ANIM_ALIASES key for a dodge in `world_dir`. Compares
# the dodge vector to the player's mesh forward (and right via cross
# product) to decide forward/back/left/right. Returns one of:
#   "dodge_forward" / "dodge_back" / "dodge_left" / "dodge_right"
# Generic "dodge" is used as the fallback inside _perform_dodge so this
# never returns "dodge" directly.
func _classify_dodge_dir(world_dir: Vector3) -> String:
	if mesh == null:
		return "dodge_forward"
	var forward: Vector3 = -mesh.global_transform.basis.z
	forward.y = 0.0
	if forward.length_squared() < 0.001:
		return "dodge_forward"
	forward = forward.normalized()
	var fwd_dot: float = forward.dot(world_dir)
	if fwd_dot > 0.5:
		return "dodge_forward"
	if fwd_dot < -0.5:
		return "dodge_back"
	# Sideways: figure left vs right via cross
	var right: Vector3 = forward.cross(Vector3.UP).normalized()
	var right_dot: float = right.dot(world_dir)
	return "dodge_right" if right_dot > 0.0 else "dodge_left"

# Combat damage filter — dodging i-frames make the player invulnerable
# during the early window. Combat code can call this gate before applying
# damage.
func is_invulnerable() -> bool:
	return Time.get_ticks_msec() / 1000.0 < _dodge_iframes_until

# --- Lock-on targeting ---
# Tab toggles a target lock. While locked: camera auto-yaws to keep the
# target framed; player faces the target every frame; dodge becomes
# strafe-relative instead of input-relative; nameplate gets a reticle.
var _lock_target: Node = null
var _lock_reticle: Node3D = null
const LOCK_RANGE: float = 22.0
const LOCK_FOV_DOT: float = 0.30  # cosine of half-angle the candidate must be within (camera-forward)

func _toggle_lock_on() -> void:
	if _lock_target and is_instance_valid(_lock_target):
		_clear_lock()
		return
	var cam_rig: Node3D = get_tree().get_first_node_in_group("camera_rig")
	if cam_rig == null:
		return
	# Candidate enemies: anything in the 'enemy' group within LOCK_RANGE,
	# preferring those most centered in the camera's view.
	var cam_pos: Vector3 = cam_rig.global_position
	var cam_fwd: Vector3 = -cam_rig.global_transform.basis.z
	cam_fwd.y = 0
	if cam_fwd.length_squared() < 0.001:
		return
	cam_fwd = cam_fwd.normalized()
	var best: Node = null
	var best_score: float = -INF
	for e in get_tree().get_nodes_in_group("enemy"):
		if not is_instance_valid(e) or not (e is Node3D):
			continue
		var to_e: Vector3 = (e as Node3D).global_position - global_position
		var dist: float = to_e.length()
		if dist > LOCK_RANGE:
			continue
		to_e.y = 0
		var dir_e: Vector3 = to_e.normalized() if to_e.length_squared() > 0.001 else cam_fwd
		var dot: float = cam_fwd.dot(dir_e)
		if dot < LOCK_FOV_DOT:
			continue
		# Score prefers tight FOV alignment over raw distance:
		# centered-far beats off-axis-near.
		var score: float = dot - (dist / LOCK_RANGE) * 0.4
		if score > best_score:
			best_score = score
			best = e
	if best == null:
		_play_deny_cue()
		return
	_set_lock(best)

func _set_lock(target_node: Node) -> void:
	_lock_target = target_node
	# Tell the camera rig
	var cam_rig: Node3D = get_tree().get_first_node_in_group("camera_rig")
	if cam_rig and "lock_target" in cam_rig:
		cam_rig.lock_target = target_node
	# Spawn a small reticle ring above the target so the player sees
	# what's locked. Removed on _clear_lock or target death.
	_spawn_lock_reticle(target_node)
	# Audio cue + brief flash
	var ab: Node = get_node_or_null("/root/AudioBus")
	if ab and ab.has_method("play_cue"):
		ab.play_cue(&"button", global_position, -10.0, 1.4)
	# Listen for target death so we auto-unlock
	if target_node.has_signal("died"):
		var cb := Callable(self, "_on_lock_target_died")
		if not target_node.died.is_connected(cb):
			target_node.died.connect(cb, CONNECT_ONE_SHOT)

func _on_lock_target_died() -> void:
	_clear_lock()

func _clear_lock() -> void:
	_lock_target = null
	var cam_rig: Node3D = get_tree().get_first_node_in_group("camera_rig")
	if cam_rig and "lock_target" in cam_rig:
		cam_rig.lock_target = null
	if _lock_reticle and is_instance_valid(_lock_reticle):
		_lock_reticle.queue_free()
	_lock_reticle = null

func _spawn_lock_reticle(at: Node) -> void:
	if _lock_reticle and is_instance_valid(_lock_reticle):
		_lock_reticle.queue_free()
	if not (at is Node3D):
		return
	var reticle := MeshInstance3D.new()
	reticle.name = "LockReticle"
	# Use the telegraph shader's ring shape for instant visual reuse
	var quad := PlaneMesh.new()
	quad.size = Vector2(2.4, 2.4)
	reticle.mesh = quad
	var mat := ShaderMaterial.new()
	mat.shader = load("res://shaders/telegraph.gdshader")
	mat.set_shader_parameter("shape_id", 6)  # ring
	mat.set_shader_parameter("telegraph_color", Color(1.0, 0.85, 0.45, 1.0))
	mat.set_shader_parameter("progress", 1.0)  # full intensity
	mat.set_shader_parameter("pulse_speed", 4.0)
	reticle.material_override = mat
	# Parent under the locked target so it follows movement
	(at as Node3D).add_child(reticle)
	# Position above the target's head
	reticle.position = Vector3(0, 2.6, 0)
	# Rotate so the ring lies horizontal
	reticle.rotation = Vector3(PI * 0.5, 0, 0)
	_lock_reticle = reticle

# Returns true if the player is locked onto a still-valid target.
# Combat code can use this to bias swing direction toward the lock.
func is_locked() -> bool:
	return _lock_target != null and is_instance_valid(_lock_target)

# Walks every ItemPickup in the scene and tries to loot the nearest one
# inside its own pickup radius. Bound to the F key via the InputMap action
# `interact`. Auto-loot (when enabled in settings) bypasses this entirely.
func _try_pickup_nearest_item() -> void:
	var nearest: Node = null
	var best_d: float = 9999.0
	for pu in get_tree().get_nodes_in_group("item_pickup"):
		if not is_instance_valid(pu):
			continue
		var d: float = global_position.distance_to(pu.global_position)
		if d < best_d:
			best_d = d
			nearest = pu
	if nearest and nearest.has_method("try_pickup"):
		nearest.try_pickup(self)

# Public hook called by ItemPickup when the player walks onto / loots a drop.
# Routes the item into Inventory, broadcasts a HUD toast event.
func collect_item(item: Item, quantity: int = 1) -> void:
	if item == null:
		return
	if inventory == null:
		inventory = Inventory.new()
	if inventory.has_method("add_item"):
		inventory.add_item(item, quantity)
	if has_signal("item_collected"):
		emit_signal("item_collected", item, quantity)
	# Existing receive_loot shim stays compatible with code paths that already
	# call it (tests, scripted drops, etc.).
	if has_method("receive_loot"):
		receive_loot(item)
	# Auto-equip weapons: if the picked-up item is a weapon and the
	# main-hand slot is empty (or the new weapon is rarer), swap it in
	# and update the visible mesh in the KatanaSocket.
	if item.slot == Item.Slot.WEAPON_MAIN:
		_auto_equip_weapon(item)

# Refresh the visible weapon mesh in the player's hand socket.
# Reads inventory.equipped_in(WEAPON_MAIN), looks up the matching
# KayKit weapon prop mesh, and swaps it in. Falls back to the bound
# katana mesh when no item is equipped.
func _auto_equip_weapon(item: Item) -> void:
	var current: Item = inventory.equipped_in(Item.Slot.WEAPON_MAIN) if inventory and inventory.has_method("equipped_in") else null
	# Equip the new weapon if no current weapon OR rarity strictly higher
	if current == null or int(item.rarity) > int(current.rarity):
		if inventory and inventory.has_method("equip"):
			inventory.equip(item, Item.Slot.WEAPON_MAIN)
		_refresh_weapon_mesh()

# Public — call this after manual equip changes too.
func _refresh_weapon_mesh() -> void:
	var socket: Node3D = mesh.get_node_or_null("KatanaSocket") if mesh else null
	if socket == null:
		return
	# Remove old mesh under KatanaSocket
	for c in socket.get_children():
		c.queue_free()
	# Pick mesh path by equipped weapon type
	var equipped: Item = inventory.equipped_in(Item.Slot.WEAPON_MAIN) if inventory and inventory.has_method("equipped_in") else null
	var path: String = ""
	if equipped:
		match equipped.weapon_type:
			1:  path = "res://assets/characters/kaykit/Assets/gltf/sword_1handed.gltf"
			2:  path = "res://assets/characters/kaykit/Assets/gltf/sword_2handed.gltf"
			3:  path = "res://assets/characters/kaykit/Assets/gltf/axe_1handed.gltf"
			4:  path = "res://assets/characters/kaykit/Assets/gltf/axe_2handed.gltf"
			7:  path = "res://assets/characters/kaykit/Assets/gltf/staff.gltf"
			8:  path = "res://assets/characters/kaykit/Assets/gltf/wand.gltf"
			9:  path = "res://assets/characters/kaykit/Assets/gltf/sword_1handed.gltf"
			10: path = "res://assets/characters/kaykit/Assets/gltf/sword_2handed.gltf"
			11: path = "res://assets/characters/kaykit/Assets/gltf/dagger.gltf"
			12: path = "res://assets/characters/kaykit/Assets/gltf/crossbow_2handed.gltf"
			13: path = "res://assets/characters/kaykit/Assets/gltf/crossbow_1handed.gltf"
	if path == "":
		# No equipped weapon -> use default katana
		path = "res://assets/characters/kaykit/Assets/gltf/sword_1handed.gltf"
	if not ResourceLoader.exists(path):
		return
	var packed: PackedScene = load(path)
	if packed == null:
		return
	var weapon_mesh: Node3D = packed.instantiate()
	weapon_mesh.name = "WeaponMesh"
	# Match the original KatanaMesh transform: rotated to lie flat in
	# the hand, no translation
	weapon_mesh.transform = Transform3D(Basis(Vector3(0, 0.7071, 0.7071), Vector3(0, -0.7071, 0.7071), Vector3(1, 0, 0)), Vector3.ZERO)
	socket.add_child(weapon_mesh)

func _perform_basic_attack() -> void:
	# Always-available fallback swing. Doesn't require a class_def so a fresh
	# Player (no class assigned yet) can still hit things in the demo arena.
	if locked or not stats:
		return
	# Play attack animation if available
	if anim_player:
		var atk_name: String = _resolved_anims.get("attack", "")
		if atk_name != "":
			anim_player.stop()
			anim_player.play(atk_name)
	# Build a tiny inline ability for the basic swing
	var swing := Ability.new()
	swing.id = &"basic_attack"
	swing.display_name = "Basic Attack"
	swing.base_damage = 18.0 + float(stats.strength) * 0.6 + float(stats.dexterity) * 0.4
	swing.damage_type = Ability.DamageType.PHYSICAL
	swing.target_mode = Ability.TargetMode.FORWARD_CONE
	swing.range = 2.6
	swing.radius = 1.4
	swing.attribute_scaling = 0.3
	swing.cooldown = 0.45
	swing.cost_resource = &""  # free
	# Strength/dex damage scaling falls back to baseline if class_def is null
	if not stats.class_def:
		swing.base_damage = 25.0  # solid baseline so demo combat works without a class

	# Spawn a hitbox the same way AbilityRunner does
	var hb := preload("res://scripts/combat/hitbox.gd").new()
	hb.ability = swing
	hb.attacker_stats = stats
	hb.lifetime = 0.18
	hb.team = &"player"
	var collider := CollisionShape3D.new()
	hb.add_child(collider)
	var b := BoxShape3D.new()
	b.size = Vector3(swing.radius * 2.0, 2.0, swing.range)
	collider.shape = b
	var fwd := -mesh.global_transform.basis.z if mesh else -global_transform.basis.z
	fwd.y = 0; fwd = fwd.normalized()
	hb.position = global_position + fwd * (swing.range * 0.5)
	hb.look_at(global_position + fwd * swing.range, Vector3.UP)
	get_tree().current_scene.add_child(hb)

	# Build rage / refresh combat timer
	on_combat_event(2.0)

var _debug_tick: float = 0.0

# Footstep cadence: every FOOTSTEP_INTERVAL seconds while moving on
# floor, fire a step audio cue. Pitch slightly randomized for variety.
var _footstep_clock: float = 0.0
const FOOTSTEP_INTERVAL: float = 0.42  # seconds per step at jogging speed
const FOOTSTEP_RUN_INTERVAL: float = 0.30  # faster during sprints / dashes

# How tall a step can be and still get auto-climbed. The dojo platform
# tiers are ~35cm so 50cm gives slack. Any wall taller than this stays
# a wall (you can't climb the chapel watch towers, only their steps).
const STEP_UP_HEIGHT: float = 0.5
const STEP_UP_FORWARD: float = 0.45  # slightly larger than capsule radius

# After move_and_slide, check if we hit a near-vertical wall. If we did,
# raycast forward+up to see if there's a horizontal surface within
# STEP_UP_HEIGHT we can snap onto. Snap if so. This makes any short
# stepped platform (dojo tiers, broken walls, low rocks) climbable
# without per-asset authoring.
#
# Cheap: only runs when there's a wall collision AND horizontal velocity.
# Most frames this is a no-op.
func _try_step_up() -> void:
	if velocity.y > 0.1:
		return  # already going up; falling/jumping path handles itself
	var horizontal := Vector3(velocity.x, 0.0, velocity.z)
	if horizontal.length() < 0.1:
		return  # not actively moving forward
	# Look for a wall collision in this frame
	var hit_wall: bool = false
	var move_dir := horizontal.normalized()
	for i in range(get_slide_collision_count()):
		var coll := get_slide_collision(i)
		var n: Vector3 = coll.get_normal()
		# Wall if the normal is mostly horizontal AND it's facing back
		# toward us (i.e., we're walking INTO it)
		if abs(n.y) > 0.5:
			continue  # ground / ceiling
		if n.dot(-move_dir) < 0.3:
			continue  # wall but not in our direction
		hit_wall = true
		break
	if not hit_wall:
		return
	# Probe: cast a ray downward from a position above-and-ahead. If it
	# hits a horizontal-ish surface within STEP_UP_HEIGHT below the
	# probe, snap player up to that height.
	var space := get_world_3d().direct_space_state
	var probe_top := global_position + move_dir * STEP_UP_FORWARD + Vector3.UP * STEP_UP_HEIGHT * 1.05
	var probe_bottom := probe_top - Vector3.UP * (STEP_UP_HEIGHT * 1.5)
	var query := PhysicsRayQueryParameters3D.create(probe_top, probe_bottom)
	query.exclude = [get_rid()]
	query.collision_mask = collision_mask
	var result := space.intersect_ray(query)
	if result.is_empty():
		return
	var hit_pos: Vector3 = result.get("position", Vector3.ZERO)
	var hit_norm: Vector3 = result.get("normal", Vector3.ZERO)
	if hit_norm.y < 0.7:
		return  # not flat enough; refuse to climb steep slopes via step-up
	# Step height = how much we'd need to lift the player. Refuse if the
	# step is below us (already on it) or too tall.
	var lift: float = hit_pos.y - global_position.y
	if lift < 0.05 or lift > STEP_UP_HEIGHT:
		return
	# Snap up. We add a tiny epsilon so we don't get stuck inside the new
	# floor surface.
	global_position = global_position + Vector3.UP * (lift + 0.02)
	# Keep horizontal velocity; zero vertical so the next frame doesn't
	# fight us with gravity.
	velocity.y = 0.0

# Cadenced footstep audio: cue fires every FOOTSTEP_INTERVAL seconds
# while the player is on the floor AND has horizontal velocity. Skips
# when locked, dodging, or in air. Procedural &"step" cue from AudioBus
# so we don't need .ogg files.
func _tick_footsteps(delta: float) -> void:
	if locked or _dodging or not is_on_floor():
		_footstep_clock = 0.0
		return
	var speed: float = Vector3(velocity.x, 0, velocity.z).length()
	if speed < 0.5:
		_footstep_clock = 0.0
		return
	# Faster cadence at higher speeds (running > walking)
	var interval: float = lerp(FOOTSTEP_INTERVAL, FOOTSTEP_RUN_INTERVAL, clamp(speed / 6.0, 0.0, 1.0))
	_footstep_clock += delta
	if _footstep_clock >= interval:
		_footstep_clock = 0.0
		var ab: Node = get_node_or_null("/root/AudioBus")
		if ab and ab.has_method("play_cue"):
			# Slight pitch jitter so steps don't drone
			ab.play_cue(&"step", global_position, -14.0, randf_range(0.92, 1.08))

func _physics_process(delta: float) -> void:
	if locked:
		velocity.x = 0
		velocity.z = 0
	else:
		_read_input()
		_apply_horizontal(delta)
	_apply_vertical(delta)
	move_and_slide()
	# Step-up safety: after slide, if we're stuck against a low wall and
	# moving into it, snap onto the surface above so steps + lantern bases
	# + tier transitions don't block us. Cap at STEP_UP_HEIGHT to avoid
	# climbing actual walls.
	_try_step_up()
	_update_animation()
	_tick_footsteps(delta)
	_tick_combo(delta)
	_tick_resource(delta)
	_tick_form(delta)
	_tick_heaven_aura(delta)
	# Heartbeat log — once per second print player position + on-floor
	# state + input dir so we can see remotely whether movement is working.
	_debug_tick += delta
	if _debug_tick >= 1.0:
		_debug_tick = 0.0
		print("[Player] pos=%s on_floor=%s locked=%s input=%s vel=%s" % [
			str(global_position.snapped(Vector3(0.1, 0.1, 0.1))),
			str(is_on_floor()),
			str(locked),
			str(input_dir.snapped(Vector3(0.01, 0, 0.01))),
			str(velocity.snapped(Vector3(0.1, 0.1, 0.1)))
		])

func _tick_resource(delta: float) -> void:
	if not stats or not stats.class_def:
		return
	var cls := stats.class_def
	var now := Time.get_ticks_msec() / 1000.0
	var mana_surge: float = 10.0 if now < _mana_surge_until else 1.0
	var stamina_surge: float = 10.0 if now < _stamina_surge_until else 1.0

	# Primary pool regen, dispatched by class mechanic
	match cls.resource_mechanic:
		&"mana":
			resource_value = clamp(resource_value + cls.resource_regen_per_sec * mana_surge * delta, 0.0, cls.resource_max)
		&"stamina":
			resource_value = clamp(resource_value + cls.resource_regen_per_sec * stamina_surge * delta, 0.0, cls.resource_max)
			stamina_value = resource_value  # alias for stamina-primary classes
		&"focus":
			resource_value = max(0.0, resource_value + cls.resource_regen_per_sec * delta)
		&"form_energy":
			if current_form == null:
				resource_value = clamp(resource_value + cls.resource_regen_per_sec * delta, 0.0, cls.resource_max)
		&"rage":
			if now - _last_combat_time > RAGE_OUT_OF_COMBAT_GRACE:
				resource_value = max(0.0, resource_value - RAGE_DECAY_PER_SEC * delta)
		&"blood":
			pass  # never regens; only kills fill it
		_:
			pass  # stance / corruption / unknown: no passive regen

	# Secondary stamina pool (Druid in-form, future sprint/dodge for any class)
	# For non-stamina-primary classes, this pool ticks separately.
	if cls.resource_mechanic != &"stamina":
		# In-form drain for Druid
		if cls.class_id == &"chaos_druid" and current_form != null:
			var drain: float = current_form.stamina_drain_per_sec * delta
			if drain > 0.0:
				stamina_value = max(0.0, stamina_value - drain)
		else:
			# Recharge passively when not draining
			if stats.max_stamina > 0:
				stamina_value = clamp(stamina_value + stats.stamina_regen * stamina_surge * delta, 0.0, stats.max_stamina)

	# HP regen with demon day/night override
	_tick_hp_regen(delta, now)

	resource_changed.emit(resource_value, cls.resource_max, cls.resource_mechanic)

func _tick_hp_regen(delta: float, now: float) -> void:
	if not stats:
		return
	if stats.hp >= stats.max_hp or stats.hp <= 0:
		return
	var cls := stats.class_def
	var hp_surge: float = 10.0 if now < _hp_surge_until else 1.0
	var regen: float = stats.hp_regen
	# Demon: zero auto regen by day, 4 HP/sec at night
	if cls and cls.class_id == &"demon":
		var clock = get_tree().root.get_node_or_null("WorldClock")
		if clock and clock.is_day():
			regen = 0.0  # day: no auto regen
		else:
			regen = DEMON_NIGHT_HP_REGEN  # night: 4 HP/sec
	if regen > 0.0:
		stats.hp = min(stats.max_hp, stats.hp + regen * hp_surge * delta)
		hp_changed.emit(stats.hp, stats.max_hp)

# Returns the current pool reading for a given resource id.
func get_pool(resource_id: StringName) -> Dictionary:
	# {value, max, name}
	if resource_id == &"":
		return {"value": 0.0, "max": 0.0, "name": "free"}
	if resource_id == &"stamina" and stats and stats.class_def and stats.class_def.resource_mechanic != &"stamina":
		return {"value": stamina_value, "max": stats.max_stamina, "name": "stamina"}
	if not stats or not stats.class_def:
		return {"value": 0.0, "max": 0.0, "name": ""}
	if resource_id == stats.class_def.resource_mechanic:
		return {"value": resource_value, "max": stats.class_def.resource_max, "name": String(resource_id)}
	# Mismatch: ability wants a resource our class doesn't provide
	return {"value": 0.0, "max": 0.0, "name": String(resource_id)}

# Spend a resource based on the ability's cost_resource. Returns true if paid.
func spend_for(ability: Ability) -> bool:
	if ability.mana_cost <= 0.0 or ability.cost_resource == &"":
		return true  # free abilities (Demon, passive-only)
	if ability.cost_resource == &"stamina" and stats:
		# Druid in-form drains the stamina pool; stamina-primary classes drain resource_value.
		if stats.class_def and stats.class_def.resource_mechanic == &"stamina":
			if resource_value < ability.mana_cost:
				return false
			resource_value -= ability.mana_cost
			stamina_value = resource_value
			return true
		else:
			if stamina_value < ability.mana_cost:
				return false
			stamina_value -= ability.mana_cost
			return true
	# Default: deduct from primary resource pool
	if resource_value < ability.mana_cost:
		return false
	resource_value -= ability.mana_cost
	return true

func _tick_form(delta: float) -> void:
	if current_form == null:
		return
	# fixed-duration forms tick down and auto-revert
	if current_form.duration > 0.0:
		_form_time_left -= delta
		if _form_time_left <= 0.0:
			revert_form()
			return
	# form_energy drain while transformed (Druid, Demon wing-out)
	if stats and stats.class_def and stats.class_def.resource_mechanic == &"form_energy":
		resource_value = max(0.0, resource_value - 5.0 * delta)
		if resource_value <= 0.0:
			revert_form()

func _read_input() -> void:
	var raw := Vector2(
		Input.get_action_strength("move_right") - Input.get_action_strength("move_left"),
		Input.get_action_strength("move_down") - Input.get_action_strength("move_up")
	)
	if _camera_basis_provider:
		var basis := _camera_basis_provider.global_transform.basis
		var fwd := -basis.z; fwd.y = 0; fwd = fwd.normalized()
		var right := basis.x; right.y = 0; right = right.normalized()
		input_dir = (right * raw.x + fwd * raw.y).limit_length(1.0)
	else:
		input_dir = Vector3(raw.x, 0, raw.y).limit_length(1.0)

func _apply_horizontal(delta: float) -> void:
	var target := input_dir * move_speed
	velocity.x = target.x
	velocity.z = target.z
	# Lock-on overrides input-relative facing: while locked, the player
	# always faces the target. Movement is still input-relative (so you
	# strafe-circle around the target). This matches Souls-style lock-on.
	if is_locked():
		var to_target: Vector3 = (_lock_target as Node3D).global_position - global_position
		to_target.y = 0
		if to_target.length_squared() > 0.001:
			var target_yaw := atan2(to_target.x, to_target.z)
			mesh.rotation.y = lerp_angle(mesh.rotation.y, target_yaw, rotation_speed * 1.5 * delta)
	elif input_dir.length() > 0.1:
		var target_yaw := atan2(input_dir.x, input_dir.z)
		mesh.rotation.y = lerp_angle(mesh.rotation.y, target_yaw, rotation_speed * delta)

func _apply_vertical(delta: float) -> void:
	if not is_on_floor():
		velocity.y -= gravity * delta
	elif Input.is_action_just_pressed("jump") and not locked:
		velocity.y = jump_velocity

func _update_animation() -> void:
	if not anim_player:
		return
	var moving: bool = Vector2(velocity.x, velocity.z).length() > 0.5 and is_on_floor()
	var slot: String = "walk" if moving else "idle"
	# Resolve the slot through our alias map to whatever the imported character provides
	var resolved: String = _resolved_anims.get(slot, "")
	if resolved == "":
		return
	if anim_player.current_animation != resolved:
		anim_player.play(resolved)

# Combat hooks
var _last_damage_source: Node = null  # tracked for death-replay camera focus

func take_damage(amount: float, source: Node = null) -> void:
	if stats.hp <= 0:
		return
	# Dodge i-frames absorb the hit completely
	if is_invulnerable():
		return
	# Remember who hit us last so the death replay can pan to them
	if source and is_instance_valid(source):
		_last_damage_source = source
	# Guard stance: reduce damage by GUARD_DAMAGE_REDUCTION (e.g., 55%
	# soaked, 45% taken). Parry-window classes can layer on top.
	if is_guarding():
		amount *= (1.0 - GUARD_DAMAGE_REDUCTION)
		# Audible + visual feedback that the block worked
		var jc: Node = get_node_or_null("/root/Juice")
		if jc and jc.has_method("shake"):
			jc.shake(0.05, 0.10)
		var ab: Node = get_node_or_null("/root/AudioBus")
		if ab and ab.has_method("play_cue"):
			ab.play_cue(&"block", global_position, -8.0, 1.0)
	stats.hp = max(0.0, stats.hp - amount)
	hp_changed.emit(stats.hp, stats.max_hp)
	# Combo broken: any time the player takes a non-i-frame, non-guard-
	# absorbed hit the combo resets. Encourages aggressive but safe play.
	if _combo_count > 0:
		_combo_count = 0
		combo_changed.emit(0, COMBO_MAX_STACKS)
	# Damage floater above the player so the player sees what's hitting them
	var floater_script: GDScript = load("res://scripts/combat/damage_floater.gd")
	if floater_script and floater_script.has_method("spawn"):
		floater_script.spawn(self, amount, false, &"physical")
	# Combat feel: small camera shake + red flash on incoming hits. Scaling
	# with damage as fraction of max HP so light scratches feel different
	# from "you just lost a quarter of your bar". Big hits also briefly
	# zoom-tint the screen for that "you're losing this fight" reading.
	var juice = get_node_or_null("/root/Juice")
	if juice:
		var hp_pct: float = clamp(amount / max(stats.max_hp, 1.0), 0.0, 1.0)
		juice.shake(0.05 + hp_pct * 0.40, 0.18)
		# Only flash on substantial hits (>=10% max HP) so chip damage doesn't
		# strobe the screen.
		if hp_pct >= 0.10:
			juice.flash(Color(0.85, 0.10, 0.10), 0.18 + hp_pct * 0.25, 0.22)
	# Hit react animation if available
	if anim_player:
		var hit_name: String = _resolved_anims.get("hit", "")
		if hit_name != "":
			anim_player.play(hit_name)
	if stats.hp <= 0:
		_die()

func heal(amount: float) -> void:
	stats.hp = min(stats.max_hp, stats.hp + amount)
	hp_changed.emit(stats.hp, stats.max_hp)

func spend_mana(amount: float) -> bool:
	if stats.mana < amount:
		return false
	stats.mana -= amount
	mana_changed.emit(stats.mana, stats.max_mana)
	return true

func _die() -> void:
	locked = true
	died.emit()
	# Achievement: first death
	var ar = get_node_or_null("/root/AchievementRegistry")
	if ar and ar.has_method("unlock"):
		ar.unlock(&"a_first_death")
	# DEATH REPLAY: before the YOU DIED toast, pan the camera to the
	# killer for 1.0s of deep slowmo so the player sees what got them.
	# Then drop the toast. Souls-style 'this is the bullshit that
	# killed you' framing.
	if _last_damage_source and is_instance_valid(_last_damage_source) and _last_damage_source is Node3D:
		_set_lock(_last_damage_source)  # camera tracks killer
	var juice = get_node_or_null("/root/Juice")
	if juice:
		# Deep slowmo (5% speed) for the replay window
		juice.slowmo(0.05, 1.0)
		juice.flash(Color(0.7, 0.05, 0.05), 0.55, 1.4)
		# Delay the YOU DIED toast slightly so the replay plays first
		var t := get_tree().create_timer(0.6)
		t.timeout.connect(func():
			if juice and juice.has_method("toast"):
				juice.toast("YOU DIED", Color(0.95, 0.20, 0.20), 2.4)
		)
	# Multiplayer-friendly arena rule: when a player dies, that player's
	# engagement is dropped but the BOSS keeps its HP. In a party run, the
	# boss only resets when every player has wiped (handled by checking
	# party_alive elsewhere). For now in single-player this is just one
	# arena.on_player_died() per active arena.
	for arena in get_tree().get_nodes_in_group("boss_arena"):
		if arena.has_method("on_player_died"):
			arena.on_player_died()
	# Death animation
	if anim_player:
		var death_name: String = _resolved_anims.get("die", "")
		if death_name != "":
			anim_player.stop()
			anim_player.play(death_name)
		elif anim_player.has_animation("die"):
			anim_player.play("die")
	# Death SFX
	var ab = get_node_or_null("/root/AudioBus")
	if ab and ab.has_method("play_cue"):
		ab.play_cue(&"death", global_position, -2.0, 0.85)
	# Drop a soul-marker at the death position so the player can return for
	# their lost XP. Soulslike convention.
	_drop_death_marker()
	# Wait 2.5s then respawn at the most recently attuned lodestone (Hub
	# fallback if none attuned).
	get_tree().create_timer(2.5).timeout.connect(_respawn)

# Persistent state across deaths — carries over via SaveFlags.
var _lost_xp: float = 0.0  # XP that drops on the ground at last death

func _drop_death_marker() -> void:
	# Surrender 50% of current XP-into-level. The player can return to this
	# spot to pick up the marker and recover it.
	if not stats:
		return
	var xp_lost: float = float(stats.xp) * 0.5
	if xp_lost < 1.0:
		return
	stats.xp = max(0, stats.xp - int(xp_lost))
	_lost_xp += xp_lost
	# Spawn a glowing marker at our position (cheap Area3D + light)
	var marker := Area3D.new()
	marker.name = "SoulMarker"
	var mi := MeshInstance3D.new()
	var sphere := SphereMesh.new()
	sphere.radius = 0.4
	sphere.height = 0.8
	mi.mesh = sphere
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.80, 0.85, 1.0, 0.7)
	mat.emission_enabled = true
	mat.emission = Color(0.6, 0.7, 1.0)
	mat.emission_energy_multiplier = 2.5
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mi.material_override = mat
	marker.add_child(mi)
	var lit := OmniLight3D.new()
	lit.light_color = Color(0.6, 0.7, 1.0)
	lit.light_energy = 2.0
	lit.omni_range = 5.0
	marker.add_child(lit)
	var cs := CollisionShape3D.new()
	var s2 := SphereShape3D.new()
	s2.radius = 1.0
	cs.shape = s2
	marker.add_child(cs)
	marker.collision_layer = 16
	marker.collision_mask = 2
	marker.global_position = global_position
	marker.set_meta("lost_xp", _lost_xp)
	get_tree().current_scene.add_child(marker)
	marker.body_entered.connect(func(body: Node3D):
		if body == self:
			var recovered: float = marker.get_meta("lost_xp", 0.0)
			if stats and stats.has_method("gain_xp"):
				stats.gain_xp(int(recovered))
			_lost_xp = 0
			# Achievement: souls reclaimed
			var ar2 = get_node_or_null("/root/AchievementRegistry")
			if ar2 and ar2.has_method("unlock"):
				ar2.unlock(&"a_recover_souls")
			marker.queue_free()
	)

func _respawn() -> void:
	# Pick the most recent attuned lodestone (or the hub if none).
	var registry: Node = get_node_or_null("/root/LodestoneRegistry")
	var target_id: StringName = &"sword_vow_dais"
	if registry and registry.has_method("get_discovered"):
		var disc: Dictionary = registry.get_discovered()
		# Prefer a non-hub stone if discovered
		for id in disc.keys():
			target_id = id
			break
	# Restore HP
	if stats:
		stats.hp = stats.max_hp
		hp_changed.emit(stats.hp, stats.max_hp)
	locked = false
	# Trigger fast-travel
	if registry and registry.has_method("travel"):
		registry.travel(target_id)

# === Shapeshift / Transformation API ===
# Druids call enter_form(form). Capstone dragon also goes here.
# Demons can use this for Wings of Lucifer flight burst.

func can_enter_form(form: Transformation) -> bool:
	if not stats or not stats.class_def:
		return false
	if not (form in stats.class_def.available_forms):
		return false
	if resource_value < form.enter_cost:
		return false
	return current_form == null

func enter_form(form: Transformation) -> bool:
	if not can_enter_form(form):
		return false
	resource_value -= form.enter_cost
	current_form = form
	_form_time_left = form.duration if form.duration > 0.0 else INF
	_swap_mesh(form.mesh_scene)
	form_changed.emit(form)
	return true

func revert_form() -> void:
	if current_form == null:
		return
	if current_form.revert_cost > 0.0:
		resource_value = max(0.0, resource_value - current_form.revert_cost)
	current_form = null
	_form_time_left = 0.0
	_restore_human_mesh()
	form_changed.emit(null)

func _swap_mesh(form_mesh_scene: PackedScene) -> void:
	if not form_mesh_scene:
		return
	if mesh:
		_saved_human_mesh = mesh
		mesh.visible = false
	var inst := form_mesh_scene.instantiate()
	add_child(inst)
	inst.name = "FormMesh"

func _restore_human_mesh() -> void:
	var fm := get_node_or_null("FormMesh")
	if fm:
		fm.queue_free()
	if _saved_human_mesh:
		_saved_human_mesh.visible = true

# === Ronin combo tracker ===
# Called by AbilityRunner just before damage resolution. Returns the chain bonus multiplier
# for `ability` given the previously cast ability and how recently it landed.
func consume_chain_bonus(ability: Ability) -> float:
	var now := Time.get_ticks_msec() / 1000.0
	var bonus := 1.0
	if ability is BreathingForm:
		var bf: BreathingForm = ability
		if bf.chain_predecessor != &"" \
			and last_ability_id == bf.chain_predecessor \
			and (now - last_ability_time) <= bf.chain_window:
			bonus = bf.chain_bonus_mult
	last_ability_id = ability.id
	last_ability_time = now
	return bonus

# === Stance economy (Ronin) ===
# Stance charges accrue from successful parries (+1) and kills (+1), max = resource_max.
# Forms consume stance_charge_cost. No passive regen.
func gain_stance_charge(amount: int = 1) -> void:
	if not stats or not stats.class_def or stats.class_def.resource_mechanic != &"stance":
		return
	resource_value = min(stats.class_def.resource_max, resource_value + amount)
	resource_changed.emit(resource_value, stats.class_def.resource_max, &"stance")

func spend_stance_charges(amount: int) -> bool:
	if not stats or not stats.class_def or stats.class_def.resource_mechanic != &"stance":
		return true  # not a Ronin, no-op success
	if resource_value < amount:
		return false
	resource_value -= amount
	resource_changed.emit(resource_value, stats.class_def.resource_max, &"stance")
	return true

func on_kill_credit(victim: Node = null) -> void:
	gain_stance_charge(1)
	# Demon: gain Blood + heal a bit on kill (ignores time-of-day; lifesteal works always)
	if stats and stats.class_def and stats.class_def.class_id == &"demon":
		var blood_gain: float = DEMON_BLOOD_PER_KILL
		if victim and (victim is BossBase):
			blood_gain = DEMON_BLOOD_PER_BOSS
		resource_value = min(stats.class_def.resource_max, resource_value + blood_gain)
		# Kill-heal: +5% max HP regardless of day/night
		heal(stats.max_hp * DEMON_KILL_HEAL_PCT)
		resource_changed.emit(resource_value, stats.class_def.resource_max, &"blood")

# Demon lifesteal: 5% of all damage dealt heals (passive). Hooked from damage_calc post-resolution.
func apply_lifesteal(damage_dealt: float) -> void:
	if not stats or not stats.class_def or stats.class_def.class_id != &"demon":
		return
	if damage_dealt <= 0.0:
		return
	heal(damage_dealt * DEMON_LIFESTEAL_PCT)

# Returns the current Demon damage modifier from time-of-day (1.0 if not Demon).
# Day = 0.8x, Night = 1.2x, plus +1% per Blood point (cap +100%).
func demon_damage_multiplier() -> float:
	if not stats or not stats.class_def or stats.class_def.class_id != &"demon":
		return 1.0
	var clock = get_tree().root.get_node_or_null("WorldClock")
	var time_mult: float = DEMON_DAY_DMG_MULT
	if clock and clock.is_night():
		time_mult = DEMON_NIGHT_DMG_MULT
	# Blood scaling: +1% per point, cap at +100% (full bar = 2x damage)
	var blood_mult: float = 1.0 + min(1.0, resource_value / 100.0)
	return time_mult * blood_mult

func on_perfect_parry() -> void:
	gain_stance_charge(1)
	heal(stats.max_hp * 0.05)  # Water Form 5 bonus, also general parry reward

# === Heaven sword API ===
# Called by Hitbox/AbilityRunner when this player carries the Heaven sword and
# strikes a target tagged demon or undead. Triggers instant kill + absorption.
# Returns true if the hit was instant-killed by Heaven's effect.
func heaven_attempt_oneshot(target: Node) -> bool:
	if not _is_carrying_heaven():
		return false
	if not target:
		return false
	# Check target tags
	var target_tags: Array = []
	if target.has_method("get_tags"):
		target_tags = target.get_tags()
	if target.is_in_group("demon"):
		target_tags.append(&"demon")
	if target.is_in_group("undead"):
		target_tags.append(&"undead")
	if not (&"demon" in target_tags or &"undead" in target_tags):
		return false
	# Instant kill
	if target.has_method("take_damage"):
		target.take_damage(99999.0, self)  # massive overkill triggers _die path
	# Permanent damage stack
	var heaven: Item = inventory.equipped_in(Item.Slot.WEAPON_MAIN) if inventory else null
	if heaven and heaven.id == &"heaven":
		var prev: int = int(SaveFlags.get_permanent(&"heaven_undead_kills", 0))
		SaveFlags.set_permanent(&"heaven_undead_kills", prev + 1)
	return true

func heaven_damage_multiplier() -> float:
	if not _is_carrying_heaven():
		return 1.0
	var kills: int = int(SaveFlags.get_permanent(&"heaven_undead_kills", 0))
	# 0.01% per kill -> kills * 0.0001
	return 1.0 + float(kills) * 0.0001

func _is_carrying_heaven() -> bool:
	if not inventory:
		return false
	if not _can_wield_heaven():
		return false  # the sword does not bond if the wielder is unworthy
	# Check both equipped weapon and bag (Heaven returns to inventory if dropped)
	var weapon: Item = inventory.equipped_in(Item.Slot.WEAPON_MAIN)
	if weapon and weapon.id == &"heaven":
		return true
	for s in inventory.bag:
		if s.item and s.item.id == &"heaven":
			return true
	return false

# Heaven wielding gate: must be Ronin AND have Sun Breathing Form 1 unlocked.
# Even with the sword in hand, a non-Ronin or pre-Sun Ronin gets nothing from it.
func _can_wield_heaven() -> bool:
	if not stats or not stats.class_def:
		return false
	if stats.class_def.class_id != &"ronin":
		return false
	# Must have at least Sun Form 1 unlocked (which itself requires mastery of all 6 base styles)
	return &"ronin_sun_1" in stats.unlocked_skill_node_ids

func _tick_heaven_aura(delta: float) -> void:
	if not _is_carrying_heaven():
		return
	_heaven_passive_heal_cd -= delta
	if _heaven_passive_heal_cd > 0.0:
		return
	_heaven_passive_heal_cd = HEAVEN_HEAL_INTERVAL
	var heal_per_sec: float = 5.0  # Heaven's passive
	var radius: float = 6.0
	# Self heal
	heal(heal_per_sec)
	# Allies in radius (multiplayer; single-player nobody nearby)
	for p in get_tree().get_nodes_in_group("player"):
		if p == self or not is_instance_valid(p):
			continue
		if global_position.distance_to(p.global_position) <= radius and p.has_method("heal"):
			p.heal(heal_per_sec)

# === Loot intake ===
func receive_loot(item: Item) -> void:
	if not item:
		return
	if not inventory:
		inventory = Inventory.new()
	# Heaven: only one ever exists per save; refuse duplicates if somehow rolled twice.
	if item.id == &"heaven" and _is_carrying_heaven():
		return
	inventory.add_item(item, 1)

func get_inventory() -> Inventory:
	return inventory

# === Mount API ===
var current_mount: Mount = null
var _saved_move_speed: float = 0.0

func summon_mount(mount: Mount) -> bool:
	if not mount or not MountRegistry.is_owned(mount.id):
		return false
	if current_mount:
		dismiss_mount()
	current_mount = mount
	_saved_move_speed = move_speed
	move_speed = move_speed * mount.move_speed_multiplier
	# Real impl: spawn mount mesh, hide player legs, parent player to mount node
	return true

func dismiss_mount() -> void:
	if not current_mount:
		return
	move_speed = _saved_move_speed if _saved_move_speed > 0 else 6.0
	current_mount = null

func is_mounted() -> bool:
	return current_mount != null

# Combat hook: dismiss on combat if mount.dismiss_on_combat
func _on_combat_started() -> void:
	if current_mount and current_mount.dismiss_on_combat:
		dismiss_mount()

# === Pet API ===
var current_pet: Pet = null

func summon_pet(pet: Pet) -> bool:
	if not pet or not PetRegistry.is_owned(pet.id):
		return false
	current_pet = pet
	# Real impl: spawn pet mesh as child, follow logic
	return true

func dismiss_pet() -> void:
	current_pet = null

# Yak inventory bonus is granted to the player AND every party member within range.
# Inventory.MAX_BAG_SLOTS isn't dynamic; the bonus increases an "extra slots" counter
# that the inventory UI surfaces.
func extra_inventory_slots_from_pet() -> int:
	if current_pet and current_pet.inventory_bonus > 0:
		return current_pet.inventory_bonus
	# Also check party members (anyone in the party with a Yak summoned shares with us)
	var party = PartyManager.current_party if PartyManager else null
	if party:
		for member: Party.Member in party.members:
			# Phase 4 server tells us each member's pet state. Stub: 0.
			pass
	return 0

# === Potion consumption ===
# Items reach here via inventory UI / hotkey. The Item resource carries:
#   heal_amount (instant HP)
#   mana_amount (instant mana)
#   unique_tags: &"surge_mana" / &"surge_stamina" / &"surge_hp" trigger 10x regen for 10 sec
func use_potion(item: Item) -> bool:
	if not item or not stats:
		return false
	var consumed := false
	if item.heal_amount > 0.0:
		heal(item.heal_amount)
		consumed = true
	if item.mana_amount > 0.0:
		# Instant mana refill (or partial). Mages get this; stamina classes get a separate stamina potion.
		if stats.class_def and stats.class_def.resource_mechanic == &"mana":
			resource_value = min(stats.class_def.resource_max, resource_value + item.mana_amount)
			consumed = true
	# Stamina restoration via tag (separate field would be cleaner but tags work)
	if &"restore_stamina" in item.unique_tags:
		if stats.class_def and stats.class_def.resource_mechanic == &"stamina":
			resource_value = min(stats.class_def.resource_max, resource_value + 100.0)
			consumed = true
	# Surge potions: temporary 10x regen for 10 sec
	var now := Time.get_ticks_msec() / 1000.0
	if &"surge_mana" in item.unique_tags:
		_mana_surge_until = now + SURGE_DURATION
		consumed = true
	if &"surge_stamina" in item.unique_tags:
		_stamina_surge_until = now + SURGE_DURATION
		consumed = true
	if &"surge_hp" in item.unique_tags:
		_hp_surge_until = now + SURGE_DURATION
		consumed = true
	if consumed and inventory:
		inventory.remove_item(item.id, 1)
	return consumed

# === Berserker Rage Scaling ===
# Returns a dict {damage_mult, atk_speed_mult, move_speed_mult} based on current rage.
# Combat hooks query this each strike. Out-of-combat decay is handled in _tick_resource.
func get_rage_buffs() -> Dictionary:
	if not stats or not stats.class_def or stats.class_def.resource_mechanic != &"rage":
		return {"damage_mult": 1.0, "atk_speed_mult": 1.0, "move_speed_mult": 1.0}
	var rage_pct: float = clamp(resource_value / stats.class_def.resource_max, 0.0, 1.0)
	return {
		"damage_mult":     1.0 + rage_pct * RAGE_MAX_DAMAGE_BONUS,
		"atk_speed_mult":  1.0 + rage_pct * RAGE_MAX_ATK_SPEED_BONUS,
		"move_speed_mult": 1.0 + rage_pct * RAGE_MAX_MOVE_SPEED_BONUS,
	}

# Called by combat hooks when this player deals or takes damage. Builds rage and refreshes
# the combat-grace timer so rage doesn't decay between blows.
func on_combat_event(rage_gain: float = 4.0) -> void:
	_last_combat_time = Time.get_ticks_msec() / 1000.0
	if stats and stats.class_def and stats.class_def.resource_mechanic == &"rage":
		resource_value = min(stats.class_def.resource_max, resource_value + rage_gain)
		resource_changed.emit(resource_value, stats.class_def.resource_max, &"rage")

# === Stealth (Assassin) ===
func is_stealthed() -> bool:
	return _stealth_active

func enter_stealth(ability: StealthAbility = null) -> bool:
	if _stealth_active:
		return false
	if not stats or not stats.class_def:
		return false
	if stats.class_def.class_id != &"assassin":
		return false  # other classes do not get the full stealth treatment
	_stealth_active = true
	_ambush_pending = true
	_apply_stealth_visual(true)
	return true

func exit_stealth(reason: StringName = &"manual") -> void:
	if not _stealth_active:
		return
	_stealth_active = false
	# `_ambush_pending` stays true if exit was caused by the player's first attack;
	# combat code sets `consume_ambush()` on the strike to use the bonus and clear the flag.
	_apply_stealth_visual(false)

# Returns the detection radius for AI to use against this player.
# When stealthed, mobs only see this player at very short range.
func get_detection_radius_override(default_radius: float) -> float:
	if _stealth_active:
		return STEALTH_DETECTION_RADIUS_DEFAULT
	return default_radius

# Combat hook: returns the ambush bonus and consumes it (one-shot).
# Damage_calc multiplies by the returned mult and reads `was_ambush_crit` for crit force.
func consume_ambush_bonus() -> Dictionary:
	if not _ambush_pending:
		return {"damage_mult": 1.0, "guarantee_crit": false}
	_ambush_pending = false
	# Stealth always breaks on the first attack out of stealth
	if _stealth_active:
		exit_stealth(&"first_strike")
	return {"damage_mult": 1.5, "guarantee_crit": true}

func _apply_stealth_visual(is_active: bool) -> void:
	# Local-player mesh transparency; actual PvP invisibility is a network-layer concern
	# handled by MultiplayerSynchronizer visibility filter (Phase 4).
	if not mesh:
		return
	for child in mesh.get_children():
		if child is MeshInstance3D:
			var mat: Material = child.get_surface_override_material(0)
			if mat is StandardMaterial3D:
				mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA if is_active else BaseMaterial3D.TRANSPARENCY_DISABLED
				if is_active:
					mat.albedo_color.a = 0.25
				else:
					mat.albedo_color.a = 1.0
