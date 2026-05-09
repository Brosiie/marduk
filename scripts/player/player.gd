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

# Character appearance (race, gender, body, face, scars, gifts, apothecary saturation,
# pre-Lucifer class snapshot for the Heaven Rule, etc). Populated by the character
# creator at New Character or restored from save. Null until set; the AppearanceRegistry
# only applies a non-null appearance, so absence is safe.
@export var character_appearance: CharacterAppearance

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

# Ability-cast announcer: HUD subscribes to this so the player cast
# bar can light up with the ability name + duration. Emit at the
# start of every cast; the bar drains for `duration` seconds. Slot
# is the Q/E/R/F index (0..3) so the cast bar can position itself
# above the right ability button.
signal ability_cast_started(slot: int, name: String, duration: float)
signal ability_cast_finished(slot: int)
signal hp_changed(current: float, max_hp: float)
signal mana_changed(current: float, max_mana: float)
signal resource_changed(current: float, max_value: float, mechanic: StringName)
signal form_changed(form: Transformation)
signal died
signal item_collected(item: Item, quantity: int)
# Player posture: symmetric to boss posture. Each hit taken adds
# posture; full = brief stagger (1.0s). Decays passively. HUD
# subscribes to draw a meter below the HP bar.
signal posture_changed(current: float, max_posture: float)
const PLAYER_MAX_POSTURE: float = 100.0
const PLAYER_POSTURE_DAMAGE_SCALE: float = 0.40
const PLAYER_POSTURE_DAMAGE_PER_HIT_MAX: float = 22.0
const PLAYER_POSTURE_DECAY_PER_SEC: float = 18.0
const PLAYER_POSTURE_DECAY_DELAY: float = 1.2
const PLAYER_STAGGER_DURATION: float = 1.0
var player_posture: float = 0.0
var _last_player_posture_hit_at: float = 0.0
var _player_staggered_until: float = 0.0

func _ready() -> void:
	add_to_group("player")
	if not stats:
		stats = PlayerStats.new()
		stats.recompute_derived()
	# Pending-appearance consumption: if the player just came through the
	# CharacterCreator (Storyteller flow), AppearanceRegistry holds the
	# created CharacterAppearance + chosen name. Apply them BEFORE class
	# auto-assign so the creator's class pick wins over zone-inferred class.
	_consume_pending_appearance()
	# Auto-class assignment: when the player spawns in an intro zone
	# (sword_vow_ruins, sunsworn_chapel, etc.) without a class picked
	# yet, infer the matching class from the zone. This means Kachujin
	# in Sword-Vow gets the Ronin katana_walk/run/idle overrides from
	# frame zero, instead of moving like an unarmed peasant.
	if stats and not stats.class_def:
		_auto_assign_class_from_scene()
	# Quest log: attach a QuestLog instance as a child if one isn't there yet.
	# The QuestLogPanel UI walks player.get_node("QuestLog") to read state, and
	# QuestLog itself listens for game events (kills, collects) to advance
	# objectives. No quests will track if the log node is missing.
	_attach_quest_log()
	# Achievement tracker: same pattern as QuestLog. Listens for CombatBus
	# kill_registered + Player.take_damage to evaluate triggers (kill counts,
	# no-hit boss fights, time-attack, etc). Without this hook the
	# AchievementCodexPanel only ever shows locked entries.
	_attach_achievement_tracker()
	# Class aura: subtle particle ring at the player's feet, color
	# matching the class buff palette (Ronin gold, Mage blue, etc).
	# Spawned once class is set; reads as 'this character is powered'.
	_spawn_class_aura()
	# Character rim lighting: applies an additive next_pass shader to
	# every MeshInstance3D under the player so the silhouette glows
	# in class color. Critical for keeping the character readable
	# against volumetric-fogged backgrounds.
	_apply_character_rim()
	# Reparent the KatanaSocket onto a BoneAttachment3D pinned to the
	# right hand so the sword tracks Kachujin's hand during animations
	# instead of staying frozen at a fixed mesh-root offset.
	call_deferred("_attach_katana_to_hand_bone")
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
	# Show the aesthetic loading screen during the slow async anim load.
	# AnimationLibraryLoader has to load 36 .glbs (each ~16MB with
	# embedded textures) which takes 30-60s on first run. Showing a
	# pretty themed overlay reads as 'this is intentional' instead of
	# 'frozen on Godot's default splash'.
	_spawn_loading_screen()
	# Merge shared + class-specific Mixamo anims onto the AnimationPlayer.
	# DEFERRED to next frame so the loading screen renders first.
	# Idle anim loop fires from inside _load_marduk_animation_library_deferred
	# AFTER the alias map resolves -- guarantees the right anim plays.
	call_deferred("_load_marduk_animation_library_deferred")

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
	# Build the ability kit NOW that class is set. Without this the
	# ability bar slots stay empty and Q/E/R/F do nothing.
	_build_ability_kit()
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

# Loading screen handle so we can dismiss it once anims are loaded.
var _loading_screen: CanvasLayer = null

func _spawn_loading_screen() -> void:
	var ls_script: GDScript = load("res://scripts/ui/loading_screen.gd")
	if ls_script == null:
		return
	_loading_screen = ls_script.new()
	# Subtitle: show the class-flavored prologue title if we have one
	var sub: String = "An ARPG Forged in the Heart of Tiamat"
	if stats and stats.class_def:
		var ci_script: GDScript = load("res://scripts/world/class_intros.gd")
		if ci_script and ci_script.has_method("intro_title_for"):
			var title: String = ci_script.intro_title_for(stats.class_def.class_id)
			if title != "":
				sub = title
	# Add to the SCENE tree, not the player, so it persists across
	# the deferred load. CanvasLayer renders above HUD. Use deferred
	# add because we're called from the scene's setup phase where
	# direct add_child triggers 'parent busy setting up children'.
	get_tree().current_scene.add_child.call_deferred(_loading_screen)
	if _loading_screen.has_method("set_subtitle"):
		_loading_screen.call_deferred("set_subtitle", sub)

# Async wrapper that drives the AnimationLibraryLoader's coroutine.
# Yields between slot loads so the renderer can paint the LoadingScreen
# every ~300ms during the load. Connect the loader's progress signal
# to the LoadingScreen so the player sees real progress text.
func _load_marduk_animation_library_deferred() -> void:
	# Wait one frame so the loading screen has rendered before we
	# start blocking on .glb loads.
	await get_tree().process_frame
	# Hand off the loader's signals to the LoadingScreen if available
	var loader_script: GDScript = load("res://scripts/anim/animation_library_loader.gd")
	if loader_script == null:
		return
	var loader = loader_script.new()
	if _loading_screen and is_instance_valid(_loading_screen):
		if _loading_screen.has_method("on_anim_progress"):
			loader.slot_loaded.connect(_loading_screen.on_anim_progress)
	# Run the async load; await its completion so we can hide the
	# loading screen at the right moment.
	if stats and stats.class_def:
		await loader.apply(self, "class", StringName(stats.class_def.class_id))
	else:
		await loader.apply(self, "class", &"")
	# Re-find the AnimationPlayer (the loader may have created one)
	if anim_player == null:
		anim_player = _find_animation_player(self)
	_resolve_anim_alias_map()
	# Diagnostic: report what we ACTUALLY have so the T-pose
	# problem is debuggable.
	if anim_player:
		var avail: PackedStringArray = anim_player.get_animation_list()
		print("[Player] anim_player has %d anims, sample: %s" % [
			avail.size(),
			str(avail.slice(0, min(5, avail.size())))
		])
		print("[Player] resolved aliases: idle=%s walk=%s run=%s attack=%s dodge=%s" % [
			_resolved_anims.get("idle", "(none)"),
			_resolved_anims.get("walk", "(none)"),
			_resolved_anims.get("run", "(none)"),
			_resolved_anims.get("attack", "(none)"),
			_resolved_anims.get("dodge", "(none)"),
		])
	else:
		push_warning("[Player] anim_player is NULL after deferred load")
	# Loop the idle once anims are resolved. Try multiple fallbacks
	# so the character isn't T-posing if our alias resolution missed.
	if anim_player:
		var idle_name: String = _resolved_anims.get("idle", "")
		if idle_name == "" or not anim_player.has_animation(idle_name):
			# Fallback: walk the available list and pick the first
			# anim whose name contains 'idle' or just play the first
			# anim available so the character moves.
			var fallback: String = ""
			for n in anim_player.get_animation_list():
				if String(n).to_lower().find("idle") >= 0:
					fallback = String(n); break
			if fallback == "" and anim_player.get_animation_list().size() > 0:
				fallback = String(anim_player.get_animation_list()[0])
			idle_name = fallback
		if idle_name != "":
			anim_player.play(idle_name)
			print("[Player] playing idle: %s" % idle_name)
	# Hide the loading screen with a soft fade
	if _loading_screen and is_instance_valid(_loading_screen) and _loading_screen.has_method("hide_now"):
		_loading_screen.hide_now(0.7)
		_loading_screen = null

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
	# Use has_animation() not `alias in get_animation_list()`. The list
	# returns PackedStringArray entries that don't compare equal to plain
	# String aliases via the `in` operator in Godot 4.6 — the lookup
	# silently misses every alias and the player T-poses despite the
	# library being fully bound. has_animation() does the right hash
	# lookup. THIS is what made Bond's Kachujin freeze on every anim
	# transition the moment Mixamo overrides loaded.
	for slot_name in ANIM_ALIASES.keys():
		var aliases: Array = ANIM_ALIASES[slot_name]
		for alias in aliases:
			if anim_player.has_animation(String(alias)):
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
# First-press tracker: when the player casts an ability for the first
# time, fire a one-shot tutorial floater so they know what just
# happened. Reset per session so re-rolling a class re-shows the hints.
var _ability_first_press: Array = [false, false, false, false]

func _build_ability_kit() -> void:
	_ability_kit.clear()
	if not stats or not stats.class_def:
		_ability_kit = _kit_default()
		print("[Player] kit=default (no class), %d slots" % _ability_kit.size())
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
	print("[Player] kit=%s, %d slots: %s" % [
		str(stats.class_def.class_id),
		_ability_kit.size(),
		str(_ability_kit.map(func(k): return k.get("name", "(empty)") if k is Dictionary else "(non-dict)"))
	])

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
	# Announce the cast so the HUD can show the cast bar with the
	# ability name. Duration is the ANIMATION TIME — for one-shot
	# swings that's ~0.6s; for charged abilities it could be longer
	# from a `windup_seconds` field on the kit dict if we ever add one.
	var cast_duration: float = float(k.get("windup_seconds", 0.5))
	emit_signal("ability_cast_started", slot, String(k.get("name", "Ability")), cast_duration)
	# Defer the finished-event by the cast duration so the bar drains
	# fully before disappearing.
	get_tree().create_timer(cast_duration).timeout.connect(func():
		if not is_instance_valid(self): return
		emit_signal("ability_cast_finished", slot)
	)
	# First-press tutorial: name the ability the first time each slot
	# fires, so the player learns the kit by playing instead of by
	# reading menus. After that the toasts go silent for that slot.
	if slot < _ability_first_press.size() and not _ability_first_press[slot]:
		_ability_first_press[slot] = true
		var juice: Node = get_node_or_null("/root/Juice")
		if juice and juice.has_method("toast"):
			var name_label: String = String(k.get("name", "Ability"))
			var desc: String = String(k.get("desc", ""))
			var hk_labels := ["Q", "E", "R", "F"]
			var hk: String = hk_labels[slot] if slot < hk_labels.size() else ""
			var line := "[%s]  %s" % [hk, name_label]
			if desc != "":
				line += "  ·  " + desc
			juice.toast(line, _class_buff_color(), 3.5)
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
	# Chain bonus: if last ability matches this form's predecessor within the window,
	# multiply base_damage by chain_bonus_mult. Always update the tracker.
	var chain_mult: float = 1.0
	var chain_pred: StringName = StringName(k.get("chain_predecessor", &""))
	var chain_window: float = float(k.get("chain_window", 0.0))
	var chain_bonus: float = float(k.get("chain_bonus_mult", 1.0))
	if chain_pred != &"" and last_ability_id == chain_pred and chain_window > 0.0:
		if (now - last_ability_time) <= chain_window:
			chain_mult = chain_bonus
	last_ability_id = StringName(k.get("id", &""))
	last_ability_time = now

	# Spawn a hitbox using target_mode from the kit dict (defaults to FORWARD_CONE).
	var hb := preload("res://scripts/combat/hitbox.gd").new()
	var swing := Ability.new()
	swing.id = StringName(k.get("id", "ability"))
	swing.display_name = String(k.get("name", "Ability"))
	# Riposte buff: if the player just perfect-dodged, the next swing
	# does +50% damage and is consumed on first hit. Apply BEFORE
	# chain_mult so the rewards stack — a perfect-dodge into a chain
	# combo is the highest-DPS expression of skill.
	var dmg: float = float(k.get("damage", 30.0)) * chain_mult
	if has_riposte_buff():
		dmg *= RIPOSTE_DAMAGE_MULT
		consume_riposte_buff()
	swing.base_damage = dmg
	swing.damage_type = int(k.get("element", Ability.DamageType.PHYSICAL))
	swing.target_mode = int(k.get("target_mode", Ability.TargetMode.FORWARD_CONE))
	swing.range = float(k.get("range", 3.0))
	swing.radius = float(k.get("radius", 1.5))
	swing.attribute_scaling = 0.4
	hb.ability = swing
	hb.attacker_stats = stats
	hb.lifetime = 0.20
	hb.team = &"player"
	var collider := CollisionShape3D.new()
	hb.add_child(collider)
	# +mesh.basis.z (not -basis.z) because Mixamo meshes are +Z-forward
	# and _apply_horizontal rotates mesh so its +Z axis points at the
	# input/lock direction. Using -basis.z would fire attacks BEHIND
	# the visible character.
	var fwd := mesh.global_transform.basis.z if mesh else global_transform.basis.z
	fwd.y = 0; fwd = fwd.normalized()
	match swing.target_mode:
		Ability.TargetMode.AOE_AROUND_SELF:
			var s := SphereShape3D.new()
			s.radius = swing.radius
			collider.shape = s
			hb.position = global_position
			# Miss punishment: if AoE finisher whiffs, lock player briefly.
			var miss_sec: float = float(k.get("miss_punishment", 0.0))
			if miss_sec > 0.0:
				hb.set_meta("miss_punishment_seconds", miss_sec)
				hb.set_meta("punishable_owner", self)
		_:
			var b := BoxShape3D.new()
			b.size = Vector3(swing.radius * 2.0, 2.0, max(swing.range, 0.5))
			collider.shape = b
			hb.position = global_position + fwd * (swing.range * 0.5)
			hb.look_at(global_position + fwd * max(swing.range, 0.5) + Vector3(0, 0.001, 0), Vector3.UP)
	get_tree().current_scene.add_child(hb)
	# Audio cue: per-element so fire abilities sound different than holy
	# than swords. Picks the cue from element type, falls back to swing.
	var ab = get_node_or_null("/root/AudioBus")
	if ab and ab.has_method("play_cue"):
		var elem: int = int(k.get("element", Ability.DamageType.PHYSICAL))
		var cue: StringName = _cue_for_element(elem)
		ab.play_cue(cue, global_position, -7.0, float(k.get("pitch", 1.0)))
	# Breath-trail VFX. Picks Demon Slayer style by ability id when available
	# so Ronin's swings actually look like breathing forms.
	var trail_style: StringName = _trail_style_for(StringName(k.get("id", "")))
	if trail_style != &"":
		var trail_script: GDScript = load("res://scripts/vfx/breath_trail.gd")
		if trail_script and trail_script.has_method("spawn"):
			trail_script.spawn(self, trail_style)
	# Cast burst: small particle puff at cast point, color-coded to
	# the ability element. Reads as 'magic happens here'.
	_spawn_cast_burst(int(k.get("element", Ability.DamageType.PHYSICAL)))
	# Breath VFX: for Ronin breath/iai abilities, spawn a mouth puff
	# AND coat the katana blade in matching elemental material for
	# the duration of the swing. Demon-Slayer style.
	_spawn_breath_vfx(StringName(k.get("id", "")))
	# Weapon trail arc — element-tinted curve sweeping in front of
	# the player to read the SWING SHAPE clearly. Distinct from the
	# blade-coat (which sticks to the katana mesh) — this is the
	# motion-blur read of the strike itself.
	_spawn_swing_arc(int(k.get("element", Ability.DamageType.PHYSICAL)))
	on_combat_event(2.0)

# Maps Ability.DamageType to the AudioBus cue name. Each element gets
# its own procedural sound: fire = low burst, lightning = high crack,
# frost = chirp, holy = arpeggio, shadow = deep tone, physical = swing.
func _cue_for_element(element: int) -> StringName:
	match element:
		Ability.DamageType.FIRE:      return &"fire_cast"
		Ability.DamageType.LIGHTNING: return &"thunder"  # reuses storm cue
		Ability.DamageType.FROST:     return &"frost_cast"
		Ability.DamageType.HOLY:      return &"holy_cast"
		Ability.DamageType.SHADOW:    return &"shadow_cast"
		Ability.DamageType.ARCANE:    return &"frost_cast"  # arcane = high chirp
	return &"swing"

# Cast burst: short-lived particle pop at the player's hand height,
# color-themed to ability element. Spawned at the player's forward
# offset so it reads as the spell launching.
func _spawn_cast_burst(element: int) -> void:
	var color: Color = _color_for_element(element)
	var burst := GPUParticles3D.new()
	burst.name = "CastBurst"
	burst.amount = 22
	burst.lifetime = 0.6
	burst.one_shot = true
	burst.explosiveness = 0.95
	burst.visibility_aabb = AABB(Vector3(-2, -1, -2), Vector3(4, 4, 4))
	var mat := ParticleProcessMaterial.new()
	mat.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_SPHERE
	mat.emission_sphere_radius = 0.18
	mat.direction = Vector3.UP
	mat.spread = 60.0
	mat.initial_velocity_min = 1.2
	mat.initial_velocity_max = 2.6
	mat.gravity = Vector3(0, -1.5, 0)
	mat.scale_min = 0.10
	mat.scale_max = 0.22
	mat.color = color
	burst.process_material = mat
	var quad := QuadMesh.new()
	quad.size = Vector2(0.20, 0.20)
	var smat := StandardMaterial3D.new()
	smat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	smat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	smat.albedo_color = color
	smat.emission_enabled = true
	smat.emission = color
	smat.emission_energy_multiplier = 1.6
	smat.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
	smat.billboard_keep_scale = true
	quad.material = smat
	burst.draw_pass_1 = quad
	get_tree().current_scene.add_child(burst)
	# Mesh is +Z-forward; use +basis.z so the breath/aura spawns IN FRONT
	# of the character, not behind it.
	var fwd := mesh.global_transform.basis.z if mesh else global_transform.basis.z
	fwd.y = 0
	if fwd.length_squared() > 0.001:
		fwd = fwd.normalized()
	burst.global_position = global_position + Vector3(0, 1.2, 0) + fwd * 0.8
	get_tree().create_timer(1.2).timeout.connect(func(): if is_instance_valid(burst): burst.queue_free())

# --- Breath VFX (Demon Slayer-style elemental breathing forms) ---
#
# When the Ronin casts an iai or breath form, we layer two effects:
#   1. Mouth puff: a small element-themed particle burst at head height,
#      front of the mesh. Reads as the breath being inhaled/exhaled.
#   2. Blade coat: particles emitting along the katana that wrap the
#      blade in the matching element for ~0.6s. Looks like the blade
#      is dressed in water / fire / lightning / etc.
#
# Driven by the ability_id -> style map (`_trail_style_for`). Each
# style has its own color + emission texture preference, mapped here.

const BREATH_COLORS := {
	&"water":   Color(0.40, 0.75, 1.00, 1.0),
	&"thunder": Color(1.00, 0.95, 0.40, 1.0),
	&"flame":   Color(1.00, 0.45, 0.15, 1.0),
	&"wind":    Color(0.65, 0.95, 0.55, 1.0),
	&"stone":   Color(0.75, 0.55, 0.30, 1.0),
	&"mist":    Color(0.92, 0.92, 0.95, 1.0),
	&"sun":     Color(1.00, 0.92, 0.50, 1.0),
	&"moon":    Color(0.85, 0.30, 0.45, 1.0),
}

func _breath_color_for(style: StringName) -> Color:
	return BREATH_COLORS.get(style, Color(0.95, 0.95, 0.95, 1.0))

# Per-swing weapon-trail arc. Spawns a curved ribbon of alpha quads
# that sweep horizontally in front of the player, then fade. Distinct
# from the breath/blade-coat VFX:
#   blade-coat = particles attached to the KatanaSocket
#   swing-arc  = a one-shot CURVE of quads anchored in world space
# that captures the SWEEP shape of the strike.
#
# Color matches the ability element (fire = orange, frost = blue, etc).
func _spawn_swing_arc(element: int) -> void:
	if mesh == null:
		return
	var color: Color = _color_for_element(element)
	# Build a Node3D parent so we can anchor + tween + queue_free as a unit
	var arc := Node3D.new()
	arc.name = "SwingArc"
	get_tree().current_scene.add_child(arc)
	arc.global_position = global_position + Vector3(0, 1.4, 0)
	# Orient the arc to face along the player's mesh forward (+Z for
	# Mixamo) so the sweep cuts in the swing direction.
	var fwd: Vector3 = mesh.global_transform.basis.z
	fwd.y = 0
	if fwd.length_squared() > 0.001:
		fwd = fwd.normalized()
		arc.look_at(arc.global_position + fwd, Vector3.UP)
	# Build the arc as 8 quads sampled along a horizontal half-circle
	# in front of the player, radius 1.2m. Each quad is rotated to
	# tangent the arc at its sample angle.
	var segments: int = 8
	var arc_radius: float = 1.2
	var arc_angle_total: float = deg_to_rad(140.0)  # ~140deg sweep
	for i in range(segments):
		var t: float = float(i) / float(segments - 1)
		var ang: float = -arc_angle_total * 0.5 + arc_angle_total * t
		var local_pos: Vector3 = Vector3(sin(ang) * arc_radius, 0, cos(ang) * arc_radius)
		var quad := MeshInstance3D.new()
		var qm := QuadMesh.new()
		qm.size = Vector2(0.30, 0.55)
		quad.mesh = qm
		var smat := StandardMaterial3D.new()
		smat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		smat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		# Alpha taper toward arc tail (last segment darkest)
		var seg_alpha: float = 1.0 - t * 0.65
		smat.albedo_color = Color(color.r, color.g, color.b, 0.95 * seg_alpha)
		smat.emission_enabled = true
		smat.emission = color
		smat.emission_energy_multiplier = 2.5
		smat.cull_mode = BaseMaterial3D.CULL_DISABLED
		quad.material_override = smat
		quad.position = local_pos
		# Tangent: face perpendicular to the arc curve so the quad
		# reads as motion blur along the sweep direction.
		quad.rotation = Vector3(0, ang + PI * 0.5, 0)
		arc.add_child(quad)
	# Fade out + scale up over 280ms
	var tw := arc.create_tween()
	tw.tween_property(arc, "scale", Vector3(1.15, 1.0, 1.15), 0.28).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	tw.parallel().tween_property(arc, "modulate:a", 0.0, 0.28)
	tw.tween_callback(func():
		if is_instance_valid(arc): arc.queue_free())

# Execution finisher: when the locked target is a STAGGERED boss within
# 3m, the next basic-attack press triggers a cinematic instead of a
# regular swing. Returns true if the execution fired (caller should
# skip its normal attack path).
#
# Mechanics:
# - 3.0x damage (closing the posture loop — staggering should mean
#   real reward, not just a free hit)
# - 0.20x slowmo for 0.8s (Mortal-Kombat-finisher cadence)
# - Camera spring tightens via temporary distance override
# - "EXECUTION!" toast in saturated gold
# - Crit audio cue at low pitch (heavy strike)
# - Burst of 80 gold particles at the boss's chest
# - Player anim plays the heavy strike (katana_jump_attack) as the
#   visible commit moment
const EXECUTION_RANGE: float = 3.0
const EXECUTION_DAMAGE_MULT: float = 3.0
const EXECUTION_SLOWMO_SCALE: float = 0.20
const EXECUTION_SLOWMO_DURATION: float = 0.80

func _try_execution_on_staggered_boss() -> bool:
	if not is_locked() or not is_instance_valid(_lock_target):
		return false
	var t: Node = _lock_target
	# Boss must expose `posture` and be staggered (Time check via
	# _staggered_until > now). Probe via duck-typing — only BossBase
	# carries these fields.
	if not ("_staggered_until" in t):
		return false
	var now: float = Time.get_ticks_msec() / 1000.0
	if now >= float(t.get("_staggered_until")):
		return false
	# Range gate
	var dist: float = global_position.distance_to((t as Node3D).global_position)
	if dist > EXECUTION_RANGE:
		return false
	_fire_execution(t)
	return true

func _fire_execution(target_node: Node) -> void:
	# Cinematic feedback
	var juice: Node = get_node_or_null("/root/Juice")
	if juice:
		if juice.has_method("slowmo"):
			juice.slowmo(EXECUTION_SLOWMO_SCALE, EXECUTION_SLOWMO_DURATION)
		if juice.has_method("flash"):
			juice.flash(Color(1.0, 0.92, 0.55), 0.50, 0.65)
		if juice.has_method("shake"):
			juice.shake(0.65, 0.40)
		if juice.has_method("toast"):
			juice.toast("EXECUTION!", Color(1.0, 0.92, 0.40), 2.5)
		if juice.has_method("hit_stop"):
			juice.hit_stop(0.18)
	# Audio chord
	var ab: Node = get_node_or_null("/root/AudioBus")
	if ab and ab.has_method("play_cue"):
		ab.play_cue(&"crit", target_node.global_position, -1.0, 0.55)
		ab.play_cue(&"victory", target_node.global_position, -3.0, 1.20)
	# Heavy strike anim if available — falls back to attack
	if anim_player:
		var heavy_name: String = _resolved_anims.get("heavy", _resolved_anims.get("attack", ""))
		if heavy_name != "":
			anim_player.stop()
			anim_player.play(heavy_name)
	# Camera dramatic zoom for the duration
	var cam_rig: Node3D = get_tree().get_first_node_in_group("camera_rig")
	if cam_rig and "distance" in cam_rig:
		var saved_distance: float = cam_rig.distance
		cam_rig.distance = max(3.5, saved_distance * 0.55)
		get_tree().create_timer(EXECUTION_SLOWMO_DURATION + 0.4).timeout.connect(func():
			if is_instance_valid(cam_rig):
				cam_rig.distance = saved_distance)
	# Apply 3.0x damage to the boss. Skip the hitbox path — direct
	# take_damage so the cinematic is reliably-deterministic instead
	# of dependent on hitbox overlap timing during slowmo.
	if target_node.has_method("take_damage"):
		var dmg: float = 35.0 + float(stats.strength) * 1.2 if stats else 50.0
		dmg *= EXECUTION_DAMAGE_MULT
		# Mark next attack as crit via direct call so the floater pops
		# at the right tier
		target_node.take_damage(dmg, self)
	# Gold burst at boss chest
	var burst := GPUParticles3D.new()
	burst.amount = 80
	burst.lifetime = 1.2
	burst.one_shot = true
	burst.explosiveness = 1.0
	burst.visibility_aabb = AABB(Vector3(-3, -1, -3), Vector3(6, 4, 6))
	var pm := ParticleProcessMaterial.new()
	pm.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_SPHERE
	pm.emission_sphere_radius = 0.3
	pm.direction = Vector3(0, 0.5, 0)
	pm.spread = 90.0
	pm.initial_velocity_min = 4.0
	pm.initial_velocity_max = 8.0
	pm.gravity = Vector3(0, -1.0, 0)
	pm.scale_min = 0.12
	pm.scale_max = 0.28
	pm.angular_velocity_min = -180.0
	pm.angular_velocity_max = 180.0
	pm.color = Color(1.0, 0.92, 0.45, 1.0)
	burst.process_material = pm
	var quad := QuadMesh.new()
	quad.size = Vector2(0.16, 0.16)
	var smat := StandardMaterial3D.new()
	smat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	smat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	smat.albedo_color = Color(1.0, 0.92, 0.45, 0.95)
	smat.emission_enabled = true
	smat.emission = Color(1.0, 0.95, 0.55)
	smat.emission_energy_multiplier = 3.5
	smat.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
	quad.material = smat
	burst.draw_pass_1 = quad
	get_tree().current_scene.add_child(burst)
	burst.global_position = (target_node as Node3D).global_position + Vector3(0, 1.6, 0)
	get_tree().create_timer(2.0).timeout.connect(func():
		if is_instance_valid(burst): burst.queue_free())

func _spawn_breath_vfx(ability_id: StringName) -> void:
	var style: StringName = _trail_style_for(ability_id)
	if style == &"":
		return
	var color: Color = _breath_color_for(style)
	_spawn_mouth_puff(color, style)
	_spawn_blade_coat(color, style)
	# Per-style signature layer — one ribbon for water, one arc for
	# thunder, etc. The puff+coat give the GENERIC 'this breathing
	# form just fired' read; the signature gives the SPECIFIC element.
	# Demon Slayer reference: Tanjiro's water dragon spiral, Zenitsu's
	# lightning trail, Rengoku's layered flame columns.
	_spawn_breath_signature(color, style)

# Per-style hero VFX. Built procedurally on top of the generic puff +
# blade coat so each style has an unmistakable visual signature
# instead of all 8 styles being color variants of the same quad burst.
func _spawn_breath_signature(color: Color, style: StringName) -> void:
	match style:
		&"water":   _signature_water(color)
		&"thunder": _signature_thunder(color)
		&"flame":   _signature_flame(color)
		&"wind":    _signature_wind(color)
		&"stone":   _signature_stone(color)
		&"sun":     _signature_sun(color)
		&"moon":    _signature_moon(color)
		&"mist":    _signature_mist(color)

# WATER: trailing ribbon of slow particles with strong tangential
# acceleration so they spiral around the blade like Tanjiro's dragon.
# Two layers — saturated core + lighter foam — for depth.
func _signature_water(color: Color) -> void:
	var socket: Node3D = mesh.get_node_or_null("KatanaSocket") if mesh else null
	if socket == null:
		return
	for layer_idx in 2:
		var ribbon := GPUParticles3D.new()
		ribbon.name = "WaterRibbon%d" % layer_idx
		ribbon.amount = 60
		ribbon.lifetime = 1.4
		ribbon.one_shot = true
		ribbon.explosiveness = 0.05  # SLOW continuous — long arc
		ribbon.visibility_aabb = AABB(Vector3(-2, -1, -2), Vector3(4, 3, 4))
		var pm := ParticleProcessMaterial.new()
		pm.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_BOX
		pm.emission_box_extents = Vector3(0.03, 0.03, 0.45)
		pm.direction = Vector3(0, 0.4, 1.0)
		pm.spread = 6.0
		pm.initial_velocity_min = 1.6
		pm.initial_velocity_max = 2.4
		# Tangential accel = curve away from forward = ribbon spiral
		pm.tangential_accel_min = 1.8 - layer_idx * 0.6
		pm.tangential_accel_max = 3.2 - layer_idx * 0.6
		pm.gravity = Vector3(0, -0.8, 0)
		pm.scale_min = 0.10 + layer_idx * 0.06
		pm.scale_max = 0.20 + layer_idx * 0.10
		pm.color = color.lightened(layer_idx * 0.30)
		ribbon.process_material = pm
		var quad := QuadMesh.new()
		quad.size = Vector2(0.16, 0.16)
		var smat := StandardMaterial3D.new()
		smat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		smat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		smat.albedo_color = color.lightened(layer_idx * 0.30)
		smat.emission_enabled = true
		smat.emission = color
		smat.emission_energy_multiplier = 1.4
		smat.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
		quad.material = smat
		ribbon.draw_pass_1 = quad
		socket.add_child(ribbon)
		ribbon.position = Vector3(0, 0.5, 0)
		get_tree().create_timer(2.0).timeout.connect(func():
			if is_instance_valid(ribbon): ribbon.queue_free())

# THUNDER: ImmediateMesh-based jagged bolt from hand to blade tip,
# flashes for one frame then fades. Plus a sparking particle burst
# at the tip. Demon Slayer reference: Zenitsu's first-form flash.
func _signature_thunder(color: Color) -> void:
	var socket: Node3D = mesh.get_node_or_null("KatanaSocket") if mesh else null
	if socket == null:
		return
	# Jagged bolt mesh — 6 segments with random perpendicular jitter
	var bolt := MeshInstance3D.new()
	bolt.name = "ThunderBolt"
	var im := ImmediateMesh.new()
	im.surface_begin(Mesh.PRIMITIVE_LINE_STRIP)
	for i in range(7):
		var t: float = float(i) / 6.0
		var jitter_x: float = (randf() - 0.5) * 0.10 if i not in [0, 6] else 0.0
		var jitter_y: float = (randf() - 0.5) * 0.10 if i not in [0, 6] else 0.0
		im.surface_add_vertex(Vector3(jitter_x, jitter_y, t * 0.95))
	im.surface_end()
	bolt.mesh = im
	var bm := StandardMaterial3D.new()
	bm.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	bm.albedo_color = color
	bm.emission_enabled = true
	bm.emission = color.lightened(0.4)
	bm.emission_energy_multiplier = 4.0
	bm.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	bm.no_depth_test = true
	bolt.material_override = bm
	socket.add_child(bolt)
	bolt.position = Vector3(0, 0.05, 0)
	# Fade the bolt over 0.18s via tween
	var tw := create_tween()
	tw.tween_property(bm, "albedo_color:a", 0.0, 0.18)
	tw.parallel().tween_property(bm, "emission_energy_multiplier", 0.0, 0.18)
	get_tree().create_timer(0.3).timeout.connect(func():
		if is_instance_valid(bolt): bolt.queue_free())
	# Sparking burst at the tip
	var spark := GPUParticles3D.new()
	spark.amount = 24
	spark.lifetime = 0.45
	spark.one_shot = true
	spark.explosiveness = 1.0
	spark.visibility_aabb = AABB(Vector3(-1, -1, -1), Vector3(2, 2, 2))
	var sm := ParticleProcessMaterial.new()
	sm.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_SPHERE
	sm.emission_sphere_radius = 0.05
	sm.direction = Vector3(0, 0, 1)
	sm.spread = 180.0
	sm.initial_velocity_min = 2.5
	sm.initial_velocity_max = 5.5
	sm.gravity = Vector3.ZERO
	sm.scale_min = 0.04
	sm.scale_max = 0.10
	sm.color = color
	spark.process_material = sm
	var sq := QuadMesh.new()
	sq.size = Vector2(0.08, 0.08)
	var ssm := StandardMaterial3D.new()
	ssm.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	ssm.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	ssm.emission_enabled = true
	ssm.emission = color.lightened(0.5)
	ssm.emission_energy_multiplier = 3.5
	ssm.albedo_color = color
	ssm.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
	sq.material = ssm
	spark.draw_pass_1 = sq
	socket.add_child(spark)
	spark.position = Vector3(0, 1.0, 0)  # tip of blade
	get_tree().create_timer(1.0).timeout.connect(func():
		if is_instance_valid(spark): spark.queue_free())

# FLAME: two-layer fire — saturated orange core rising fast, lighter
# yellow halo rising slower. Plus wisps drifting up from the blade.
# Demon Slayer reference: Rengoku's flame columns layered against
# each other.
func _signature_flame(color: Color) -> void:
	var socket: Node3D = mesh.get_node_or_null("KatanaSocket") if mesh else null
	if socket == null:
		return
	for layer_idx in 2:
		var fire := GPUParticles3D.new()
		fire.amount = 50
		fire.lifetime = 0.9
		fire.one_shot = true
		fire.explosiveness = 0.20
		fire.visibility_aabb = AABB(Vector3(-2, -1, -2), Vector3(4, 4, 4))
		var pm := ParticleProcessMaterial.new()
		pm.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_BOX
		pm.emission_box_extents = Vector3(0.05, 0.05, 0.45)
		pm.direction = Vector3(0, 1.0, 0)
		pm.spread = 18.0 + layer_idx * 8.0
		pm.initial_velocity_min = 2.5 - layer_idx * 0.6
		pm.initial_velocity_max = 4.0 - layer_idx * 0.6
		pm.gravity = Vector3(0, 1.6, 0)  # flames RISE
		pm.scale_min = 0.10 + layer_idx * 0.05
		pm.scale_max = 0.22 + layer_idx * 0.08
		# Outer halo lighter / yellower than the core
		var fc: Color = color if layer_idx == 0 else Color(1.0, 0.78, 0.30)
		pm.color = fc
		fire.process_material = pm
		var q := QuadMesh.new()
		q.size = Vector2(0.18, 0.18)
		var ssm := StandardMaterial3D.new()
		ssm.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		ssm.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		ssm.albedo_color = fc
		ssm.emission_enabled = true
		ssm.emission = fc
		ssm.emission_energy_multiplier = 2.4 if layer_idx == 0 else 1.4
		ssm.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
		q.material = ssm
		fire.draw_pass_1 = q
		socket.add_child(fire)
		fire.position = Vector3(0, 0.5, 0)
		get_tree().create_timer(1.6).timeout.connect(func():
			if is_instance_valid(fire): fire.queue_free())

# WIND: tangential-accelerating particles forming a vortex around the
# blade. Demon Slayer reference: Sanemi's seventh form spiral.
func _signature_wind(color: Color) -> void:
	var socket: Node3D = mesh.get_node_or_null("KatanaSocket") if mesh else null
	if socket == null:
		return
	var v := GPUParticles3D.new()
	v.amount = 80
	v.lifetime = 0.9
	v.one_shot = true
	v.explosiveness = 0.10
	v.visibility_aabb = AABB(Vector3(-2, -1, -2), Vector3(4, 3, 4))
	var pm := ParticleProcessMaterial.new()
	pm.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_BOX
	pm.emission_box_extents = Vector3(0.10, 0.10, 0.40)
	pm.direction = Vector3(0, 0, 1)
	pm.spread = 35.0
	pm.initial_velocity_min = 1.0
	pm.initial_velocity_max = 2.0
	# Strong tangential = vortex
	pm.tangential_accel_min = 4.0
	pm.tangential_accel_max = 7.0
	pm.gravity = Vector3.ZERO
	pm.scale_min = 0.06
	pm.scale_max = 0.14
	pm.color = color
	v.process_material = pm
	var q := QuadMesh.new()
	q.size = Vector2(0.12, 0.12)
	var ssm := StandardMaterial3D.new()
	ssm.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	ssm.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	ssm.albedo_color = color
	ssm.emission_enabled = true
	ssm.emission = color
	ssm.emission_energy_multiplier = 1.0
	ssm.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
	q.material = ssm
	v.draw_pass_1 = q
	socket.add_child(v)
	v.position = Vector3(0, 0.5, 0)
	get_tree().create_timer(1.6).timeout.connect(func():
		if is_instance_valid(v): v.queue_free())

# STONE: heavy chunks falling away from the blade with strong gravity.
# Demon Slayer reference: Gyomei's stone-form rubble.
func _signature_stone(color: Color) -> void:
	var socket: Node3D = mesh.get_node_or_null("KatanaSocket") if mesh else null
	if socket == null:
		return
	var s := GPUParticles3D.new()
	s.amount = 28
	s.lifetime = 1.4
	s.one_shot = true
	s.explosiveness = 0.95
	s.visibility_aabb = AABB(Vector3(-2, -2, -2), Vector3(4, 4, 4))
	var pm := ParticleProcessMaterial.new()
	pm.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_BOX
	pm.emission_box_extents = Vector3(0.06, 0.06, 0.45)
	pm.direction = Vector3(0, -0.3, 1.0)
	pm.spread = 50.0
	pm.initial_velocity_min = 2.5
	pm.initial_velocity_max = 4.5
	pm.gravity = Vector3(0, -8.0, 0)  # heavy fall
	pm.scale_min = 0.10
	pm.scale_max = 0.22
	pm.angular_velocity_min = -180.0
	pm.angular_velocity_max = 180.0
	pm.color = color
	s.process_material = pm
	var box := BoxMesh.new()
	box.size = Vector3(0.08, 0.08, 0.10)
	var ssm := StandardMaterial3D.new()
	ssm.albedo_color = color
	ssm.roughness = 0.90
	box.material = ssm
	s.draw_pass_1 = box
	socket.add_child(s)
	s.position = Vector3(0, 0.5, 0)
	get_tree().create_timer(2.5).timeout.connect(func():
		if is_instance_valid(s): s.queue_free())

# SUN: radial beam of bright particles fanning out from blade tip.
# Demon Slayer reference: Yoriichi's sun-breath dance corona.
func _signature_sun(color: Color) -> void:
	var socket: Node3D = mesh.get_node_or_null("KatanaSocket") if mesh else null
	if socket == null:
		return
	var s := GPUParticles3D.new()
	s.amount = 80
	s.lifetime = 0.7
	s.one_shot = true
	s.explosiveness = 1.0
	s.visibility_aabb = AABB(Vector3(-3, -2, -3), Vector3(6, 4, 6))
	var pm := ParticleProcessMaterial.new()
	pm.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_SPHERE
	pm.emission_sphere_radius = 0.05
	pm.direction = Vector3(0, 0, 1)
	pm.spread = 60.0
	pm.initial_velocity_min = 4.0
	pm.initial_velocity_max = 7.0
	pm.gravity = Vector3.ZERO
	pm.scale_min = 0.10
	pm.scale_max = 0.22
	pm.color = color
	s.process_material = pm
	var q := QuadMesh.new()
	q.size = Vector2(0.18, 0.18)
	var ssm := StandardMaterial3D.new()
	ssm.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	ssm.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	ssm.albedo_color = color
	ssm.emission_enabled = true
	ssm.emission = color
	ssm.emission_energy_multiplier = 3.0
	ssm.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
	q.material = ssm
	s.draw_pass_1 = q
	socket.add_child(s)
	s.position = Vector3(0, 0.95, 0)  # tip
	get_tree().create_timer(1.4).timeout.connect(func():
		if is_instance_valid(s): s.queue_free())

# MOON: crescent-shaped sweep — particles emit in a horizontal arc and
# fade fast for the hanging-crescent silhouette.
# Demon Slayer reference: Kokushibo's crescent moon arcs.
func _signature_moon(color: Color) -> void:
	var socket: Node3D = mesh.get_node_or_null("KatanaSocket") if mesh else null
	if socket == null:
		return
	var s := GPUParticles3D.new()
	s.amount = 40
	s.lifetime = 0.8
	s.one_shot = true
	s.explosiveness = 0.6
	s.visibility_aabb = AABB(Vector3(-2, -1, -2), Vector3(4, 3, 4))
	var pm := ParticleProcessMaterial.new()
	pm.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_RING
	pm.emission_ring_axis = Vector3(0, 1, 0)
	pm.emission_ring_radius = 0.50
	pm.emission_ring_inner_radius = 0.40
	pm.emission_ring_height = 0.05
	pm.direction = Vector3(0, 0, 1)
	pm.spread = 12.0
	pm.initial_velocity_min = 0.5
	pm.initial_velocity_max = 1.2
	pm.gravity = Vector3.ZERO
	pm.scale_min = 0.08
	pm.scale_max = 0.18
	pm.color = color
	s.process_material = pm
	var q := QuadMesh.new()
	q.size = Vector2(0.14, 0.14)
	var ssm := StandardMaterial3D.new()
	ssm.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	ssm.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	ssm.albedo_color = color
	ssm.emission_enabled = true
	ssm.emission = color
	ssm.emission_energy_multiplier = 2.0
	ssm.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
	q.material = ssm
	s.draw_pass_1 = q
	socket.add_child(s)
	s.position = Vector3(0, 0.5, 0)
	get_tree().create_timer(1.5).timeout.connect(func():
		if is_instance_valid(s): s.queue_free())

# MIST: large soft particles drifting slowly outward at low alpha.
# Reads as 'breath fogging the air' instead of an attack.
func _signature_mist(color: Color) -> void:
	var socket: Node3D = mesh.get_node_or_null("KatanaSocket") if mesh else null
	if socket == null:
		return
	var s := GPUParticles3D.new()
	s.amount = 30
	s.lifetime = 1.6
	s.one_shot = true
	s.explosiveness = 0.30
	s.visibility_aabb = AABB(Vector3(-2, -1, -2), Vector3(4, 3, 4))
	var pm := ParticleProcessMaterial.new()
	pm.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_BOX
	pm.emission_box_extents = Vector3(0.20, 0.10, 0.30)
	pm.direction = Vector3(0, 0.2, 1)
	pm.spread = 60.0
	pm.initial_velocity_min = 0.3
	pm.initial_velocity_max = 0.9
	pm.gravity = Vector3(0, 0.05, 0)  # slow drift up
	pm.scale_min = 0.30
	pm.scale_max = 0.60
	pm.color = Color(color.r, color.g, color.b, 0.45)
	s.process_material = pm
	var q := QuadMesh.new()
	q.size = Vector2(0.40, 0.40)
	var ssm := StandardMaterial3D.new()
	ssm.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	ssm.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	ssm.albedo_color = Color(color.r, color.g, color.b, 0.35)
	ssm.emission_enabled = true
	ssm.emission = color
	ssm.emission_energy_multiplier = 0.6
	ssm.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
	q.material = ssm
	s.draw_pass_1 = q
	socket.add_child(s)
	s.position = Vector3(0, 0.5, 0)
	get_tree().create_timer(2.5).timeout.connect(func():
		if is_instance_valid(s): s.queue_free())

# Small puff at the player's mouth (head height, ~0.4m forward).
# 14 particles, 0.5s lifetime, gentle outward drift.
func _spawn_mouth_puff(color: Color, style: StringName) -> void:
	if mesh == null:
		return
	var puff := GPUParticles3D.new()
	puff.name = "MouthPuff"
	puff.amount = 14
	puff.lifetime = 0.5
	puff.one_shot = true
	puff.explosiveness = 0.92
	puff.visibility_aabb = AABB(Vector3(-1, -0.5, -1), Vector3(2, 1.5, 2))
	var mat := ParticleProcessMaterial.new()
	mat.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_SPHERE
	mat.emission_sphere_radius = 0.10
	# Forward + slightly up, matching breath direction
	mat.direction = Vector3(0.0, 0.2, -1.0)
	mat.spread = 25.0
	mat.initial_velocity_min = 1.2
	mat.initial_velocity_max = 2.4
	mat.gravity = Vector3(0, -0.8, 0)
	# Style-specific shape: thunder = small + sharp, mist = big + soft
	match style:
		&"thunder":
			mat.scale_min = 0.06; mat.scale_max = 0.14
			mat.angular_velocity_min = -240.0; mat.angular_velocity_max = 240.0
		&"flame":
			mat.scale_min = 0.16; mat.scale_max = 0.30
		&"mist", &"water":
			mat.scale_min = 0.20; mat.scale_max = 0.40
		_:
			mat.scale_min = 0.12; mat.scale_max = 0.24
	mat.color = color
	puff.process_material = mat
	var quad := QuadMesh.new()
	quad.size = Vector2(0.18, 0.18)
	var smat := StandardMaterial3D.new()
	smat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	smat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	smat.albedo_color = color
	smat.emission_enabled = true
	smat.emission = color
	smat.emission_energy_multiplier = 1.6
	smat.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
	smat.billboard_keep_scale = true
	quad.material = smat
	puff.draw_pass_1 = quad
	# Position at head + forward. Mesh is +Z-forward (Mixamo).
	var fwd := mesh.global_transform.basis.z
	fwd.y = 0
	if fwd.length_squared() > 0.001:
		fwd = fwd.normalized()
	get_tree().current_scene.add_child(puff)
	puff.global_position = global_position + Vector3(0, 1.55, 0) + fwd * 0.30
	get_tree().create_timer(1.2).timeout.connect(func(): if is_instance_valid(puff): puff.queue_free())

# Blade coat: stream of particles emitted along the katana for ~0.6s.
# Parented to the KatanaSocket so it tracks blade movement during the
# swing animation. Ramps OUT after lifetime (one_shot).
func _spawn_blade_coat(color: Color, style: StringName) -> void:
	var socket: Node3D = mesh.get_node_or_null("KatanaSocket") if mesh else null
	if socket == null:
		return
	var coat := GPUParticles3D.new()
	coat.name = "BladeCoat"
	coat.amount = 35
	coat.lifetime = 0.65
	coat.one_shot = true
	coat.explosiveness = 0.45  # staggered emission, looks like the blade catches the element
	coat.visibility_aabb = AABB(Vector3(-1, -0.5, -1.5), Vector3(2, 1, 3))
	var mat := ParticleProcessMaterial.new()
	# Emit along a narrow box matching the blade's local Z axis
	mat.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_BOX
	mat.emission_box_extents = Vector3(0.06, 0.06, 0.50)  # along blade length (~1m)
	mat.direction = Vector3(0, 0, 1)
	mat.spread = 12.0
	mat.initial_velocity_min = 0.2
	mat.initial_velocity_max = 0.6
	mat.gravity = Vector3.ZERO
	mat.scale_min = 0.07
	mat.scale_max = 0.14
	mat.color = color
	mat.tangential_accel_min = -0.4
	mat.tangential_accel_max = 0.4
	# Style accent: thunder crackle (high angular velocity), water flow
	# (smooth tangential), flame upward bias
	match style:
		&"thunder":
			mat.angular_velocity_min = -360.0
			mat.angular_velocity_max = 360.0
		&"flame":
			mat.gravity = Vector3(0, 1.5, 0)  # flame rises off the blade
		&"water":
			mat.tangential_accel_min = 0.6
			mat.tangential_accel_max = 1.2
	coat.process_material = mat
	var quad := QuadMesh.new()
	quad.size = Vector2(0.10, 0.10)
	var smat := StandardMaterial3D.new()
	smat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	smat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	smat.albedo_color = color
	smat.emission_enabled = true
	smat.emission = color
	smat.emission_energy_multiplier = 2.0
	smat.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
	smat.billboard_keep_scale = true
	quad.material = smat
	coat.draw_pass_1 = quad
	# Parent under the KatanaSocket so the coat tracks blade movement
	# during the swing anim. Local position at the blade midpoint.
	socket.add_child(coat)
	coat.position = Vector3(0, 0.5, 0)  # local: blade middle
	get_tree().create_timer(1.3).timeout.connect(func(): if is_instance_valid(coat): coat.queue_free())

func _color_for_element(element: int) -> Color:
	match element:
		Ability.DamageType.FIRE:      return Color(1.00, 0.45, 0.20)
		Ability.DamageType.LIGHTNING: return Color(0.95, 0.95, 0.40)
		Ability.DamageType.FROST:     return Color(0.65, 0.85, 1.00)
		Ability.DamageType.HOLY:      return Color(1.00, 0.85, 0.45)
		Ability.DamageType.SHADOW:    return Color(0.55, 0.20, 0.65)
		Ability.DamageType.ARCANE:    return Color(0.45, 0.40, 0.95)
	return Color(0.85, 0.85, 0.85)  # physical = pale

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

# Class aura: a soft particle ring at the player's feet that subtly
# tells the world 'this character is a Ronin' (gold motes) or 'this
# is a Mage' (blue arcane wisps). Spawned once class is known.
var _class_aura: GPUParticles3D = null

# Walks every MeshInstance3D under the player mesh root and gives it
# a next_pass rim-lit material so the character silhouette glows in
# class-buff color. Non-destructive: the original material renders
# unchanged, the rim is added on top.
# Find the player's Skeleton3D, pick the right-hand bone (Mixamo
# convention 'mixamorig_RightHand'), spawn a BoneAttachment3D, and
# reparent the existing KatanaSocket under it. The katana now tracks
# every hand keyframe in every anim -- swings actually swing.
#
# Run via call_deferred from _ready so the Mixamo .glb scene tree
# is fully attached when we walk it.
func _attach_katana_to_hand_bone() -> void:
	if mesh == null:
		return
	var skeleton: Skeleton3D = _find_skeleton_recursive(mesh)
	if skeleton == null:
		push_warning("[Player] No Skeleton3D found under mesh; katana stays at fixed offset")
		return
	# Pick the right-hand bone. Mixamo standard:
	#   mixamorig_RightHand
	# Some imports use ':' instead of '_' separator. Try both.
	var hand_bone_idx: int = skeleton.find_bone("mixamorig_RightHand")
	if hand_bone_idx < 0:
		hand_bone_idx = skeleton.find_bone("mixamorig:RightHand")
	if hand_bone_idx < 0:
		# Fall back to any bone with 'hand' in its name
		for i in range(skeleton.get_bone_count()):
			var bn: String = skeleton.get_bone_name(i).to_lower()
			if "righthand" in bn or "hand_r" in bn or "hand.r" in bn:
				hand_bone_idx = i
				break
	if hand_bone_idx < 0:
		push_warning("[Player] No right-hand bone found in skeleton")
		return
	# Find the existing KatanaSocket and reparent it under a new
	# BoneAttachment3D pinned to the hand bone.
	var socket: Node3D = mesh.get_node_or_null("KatanaSocket")
	if socket == null:
		return
	var attachment := BoneAttachment3D.new()
	attachment.name = "RightHandAttachment"
	attachment.bone_idx = hand_bone_idx
	attachment.bone_name = skeleton.get_bone_name(hand_bone_idx)
	skeleton.add_child(attachment)
	var old_parent: Node = socket.get_parent()
	if old_parent:
		old_parent.remove_child(socket)
	attachment.add_child(socket)
	# Strip the inherited tsuka tilt on KatanaMesh first. The 45deg
	# rotation from sword_vow_ruins.tscn was relative to a free-floating
	# socket on MeshRoot; under the bone it would compound with the
	# bone's pose and twist the blade off-axis. Reset to identity so
	# the SOCKET transform alone determines orientation.
	var katana_mesh: Node3D = socket.get_node_or_null("KatanaMesh")
	if katana_mesh:
		katana_mesh.transform = Transform3D.IDENTITY
	# Mixamo right-hand bone local frame, EMPIRICALLY PROBED via
	# get_bone_global_pose on the Ronin .glb in T-pose:
	#   +X = world +Z direction = "forward" (perpendicular to forearm,
	#        pointing where the character is facing)
	#   +Y = world -X direction = along the arm toward fingertips
	#   +Z = world -Y direction = downward through the palm
	# (This differs from naive Mixamo-doc guesses — always probe
	# before assuming a rig's local axes.)
	#
	# Procedural katana extends along its OWN local +Y (grip at origin,
	# blade tip at far +Y). For a natural samurai grip the blade
	# should point FORWARD relative to the body — that's bone +X.
	# Rotate the socket -90 around its own +Z so the katana's +Y axis
	# rotates to align with the local +X axis (= bone +X = forward).
	# Then -10 around bone +Y angles the blade slightly forward-and-
	# down for the iaido resting stance.
	# Position offset (0, 0.04, 0) seats the grip ~4cm along bone +Y
	# toward the fingers — between thumb and forefinger, where a
	# real katana sits.
	socket.transform = Transform3D(
		Basis().rotated(Vector3(0, 0, 1), deg_to_rad(-90))
		      .rotated(Vector3(0, 1, 0), deg_to_rad(-10)),
		Vector3(0.0, 0.04, 0.0)
	)
	# Defensive bone-tracking: BoneAttachment3D's bone_idx can become
	# stale if the skeleton's bone count changes (e.g. some imports
	# rebuild the skeleton when an animation library is added). Set
	# both bone_idx AND bone_name so Godot can re-resolve via name
	# if idx goes out of range.
	attachment.bone_name = skeleton.get_bone_name(hand_bone_idx)
	attachment.bone_idx = hand_bone_idx
	# Force the attachment to update its local transform from the
	# bone pose immediately, so the sword shows up in the right place
	# on the very first rendered frame instead of one frame later.
	attachment.use_external_skeleton = false  # default; explicit for clarity
	attachment.notify_property_list_changed()
	print("[Player] Katana attached to bone '%s' (idx %d)" % [skeleton.get_bone_name(hand_bone_idx), hand_bone_idx])

func _find_skeleton_recursive(node: Node) -> Skeleton3D:
	if node is Skeleton3D:
		return node
	for c in node.get_children():
		var f := _find_skeleton_recursive(c)
		if f != null:
			return f
	return null

func _apply_character_rim() -> void:
	if mesh == null:
		return
	var color: Color = _class_buff_color()
	var rim_shader: Shader = load("res://shaders/rim_pass.gdshader")
	if rim_shader == null:
		return
	# Power 2.4 keeps the rim tight to the silhouette; strength 0.7
	# keeps it readable without dominating the base material.
	_apply_rim_recursive(mesh, rim_shader, color, 2.4, 0.7)

func _apply_rim_recursive(node: Node, shader: Shader, color: Color, power: float, strength: float) -> void:
	if node is MeshInstance3D:
		var mi := node as MeshInstance3D
		if mi.mesh:
			for i in range(mi.mesh.get_surface_count()):
				# Source material: prefer override, fall back to mesh-level
				var src: Material = mi.get_surface_override_material(i)
				if src == null:
					src = mi.mesh.surface_get_material(i)
				# Build the rim pass
				var rim_mat := ShaderMaterial.new()
				rim_mat.shader = shader
				rim_mat.set_shader_parameter("rim_color", color)
				rim_mat.set_shader_parameter("rim_power", power)
				rim_mat.set_shader_parameter("rim_strength", strength)
				if src:
					var src_dup: Material = src.duplicate()
					src_dup.next_pass = rim_mat
					mi.set_surface_override_material(i, src_dup)
				else:
					# No source: just override with rim shader directly
					mi.set_surface_override_material(i, rim_mat)
	for c in node.get_children():
		_apply_rim_recursive(c, shader, color, power, strength)

func _spawn_class_aura() -> void:
	if _class_aura and is_instance_valid(_class_aura):
		_class_aura.queue_free()
	if not stats or not stats.class_def:
		return
	var color: Color = _class_buff_color()
	var p := GPUParticles3D.new()
	p.name = "ClassAura"
	p.amount = 28
	p.lifetime = 1.6
	p.preprocess = 0.8
	p.visibility_aabb = AABB(Vector3(-1.5, 0, -1.5), Vector3(3, 1.5, 3))
	var mat := ParticleProcessMaterial.new()
	# Emit from a thin ring at the feet so the aura halos the player
	mat.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_RING
	mat.emission_ring_radius = 0.55
	mat.emission_ring_inner_radius = 0.40
	mat.emission_ring_axis = Vector3.UP
	mat.emission_ring_height = 0.05
	mat.direction = Vector3.UP
	mat.spread = 8.0
	mat.initial_velocity_min = 0.10
	mat.initial_velocity_max = 0.30
	mat.gravity = Vector3.ZERO
	mat.scale_min = 0.04
	mat.scale_max = 0.10
	mat.color = color
	mat.tangential_accel_min = 0.5  # orbital swirl
	mat.tangential_accel_max = 1.0
	p.process_material = mat
	var quad := QuadMesh.new()
	quad.size = Vector2(0.10, 0.10)
	var smat := StandardMaterial3D.new()
	smat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	smat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	smat.albedo_color = color
	smat.emission_enabled = true
	smat.emission = color
	smat.emission_energy_multiplier = 1.4
	smat.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
	smat.billboard_keep_scale = true
	quad.material = smat
	p.draw_pass_1 = quad
	add_child(p)
	p.position = Vector3(0, 0.1, 0)
	_class_aura = p

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

# --- BLOCK + PARRY (universal defensive verb) ---
#
# Sekiro pattern: single input (block), the first 0.15s of holding it
# is the PARRY window. Tap-time correctly = deflect + boss posture
# damage + brief riposte; hold through the strike = standard block
# (65% damage soak, drains stamina).
#
# Why one input instead of two: avoids decision-paralysis between
# "block now" vs "parry now". The input is the SAME; only timing
# differentiates outcome. This is the Sekiro design choice that made
# its combat feel approachable AND skill-rewarding.
const BLOCK_DAMAGE_SOAK: float = 0.65   # 35% damage taken while blocking
const BLOCK_STAMINA_DRAIN_PER_SEC: float = 22.0  # cost of holding block
const PARRY_WINDOW: float = 0.15
const PARRY_POSTURE_DAMAGE: float = 60.0  # added to boss posture on parry
var _blocking: bool = false
var _block_started_at: float = 0.0

func is_blocking() -> bool:
	return _blocking

# Called by take_damage to determine what happened to an incoming hit.
# Returns:
#   "parry" — the player deflected at the perfect moment (ZERO damage,
#             brief riposte buff applied, attacker's posture damaged)
#   "block" — soaked 65% (caller multiplies amount by 0.35)
#   ""      — not blocking; full damage applies
func resolve_block_state(attacker: Node) -> String:
	if not _blocking:
		return ""
	var now: float = Time.get_ticks_msec() / 1000.0
	if now - _block_started_at <= PARRY_WINDOW:
		_fire_parry(attacker)
		return "parry"
	return "block"

func _fire_parry(attacker: Node) -> void:
	# Cinematic feedback: gold flash + audio chord + brief slowmo
	var juice: Node = get_node_or_null("/root/Juice")
	if juice:
		if juice.has_method("flash"):
			juice.flash(Color(1.0, 0.92, 0.55), 0.18, 0.30)
		if juice.has_method("shake"):
			juice.shake(0.15, 0.12)
		if juice.has_method("hit_stop"):
			juice.hit_stop(0.10)
		if juice.has_method("toast"):
			juice.toast("PARRY!", Color(1.0, 0.92, 0.45), 1.4)
	var ab: Node = get_node_or_null("/root/AudioBus")
	if ab and ab.has_method("play_cue"):
		ab.play_cue(&"block", global_position, -3.0, 1.30)
		ab.play_cue(&"crit", global_position, -7.0, 1.50)
	# Riposte buff: parry sets up the same +50% damage window as
	# perfect-dodge. Stacking the two systems means players can chain
	# parry -> heavy hit for max damage on parryable patterns.
	_riposte_until = Time.get_ticks_msec() / 1000.0 + RIPOSTE_DURATION
	emit_signal("perfect_dodge_triggered")
	# Damage attacker's posture if they're a boss-class enemy
	if attacker and attacker.has_method("_apply_posture_damage"):
		attacker._apply_posture_damage(PARRY_POSTURE_DAMAGE)
	# Spawn a small deflect-ring at the player's chest
	_spawn_riposte_ring()

func _tick_block(delta: float) -> void:
	# Read input every frame. Block requires the F key held; we also
	# require some stamina (or the resource_value pool) so blocking
	# isn't free.
	if locked or _dodging or stats == null or not InputMap.has_action("block"):
		if _blocking:
			_blocking = false
		return
	var holding: bool = Input.is_action_pressed("block")
	if holding and not _blocking:
		# Block-start
		_blocking = true
		_block_started_at = Time.get_ticks_msec() / 1000.0
	elif not holding and _blocking:
		_blocking = false
	# Drain stamina while blocking. If stamina runs out, force-release
	# the block — player has to catch their breath.
	if _blocking:
		# Use stamina_value (always present) rather than resource_value
		# (which may be mana for Mage, blood for Demon, etc.) so block
		# is class-agnostic.
		stamina_value = max(0.0, stamina_value - BLOCK_STAMINA_DRAIN_PER_SEC * delta)
		if stamina_value <= 0.0:
			_blocking = false

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
	# Water Breathing Forms 1-3 for Phase 1 demo. Chain: W1 -> W2 -> W3.
	# chain_predecessor / chain_window / chain_bonus_mult mirror the .tres resources.
	return [
		# Q: Water Form 1 — Flowing Cut. Entry form, no chain predecessor.
		{"id": &"water_1", "name": "Flowing Cut", "damage": 22.0, "range": 2.4, "radius": 1.4, "cooldown": 0.4, "cost": 12.0, "element": Ability.DamageType.PHYSICAL, "anim": "attack", "pitch": 1.2, "desc": "First Form — a fluid forward slash.", "chain_predecessor": &"", "chain_window": 0.0, "chain_bonus_mult": 1.0, "target_mode": Ability.TargetMode.FORWARD_CONE},
		# E: Water Form 2 — Still Water Redirect. Chains from W1 at 1.35x.
		{"id": &"water_2", "name": "Still Water Redirect", "damage": 18.0, "range": 2.0, "radius": 1.0, "cooldown": 0.55, "cost": 10.0, "element": Ability.DamageType.PHYSICAL, "anim": "block", "pitch": 1.0, "desc": "Second Form — deflect and counter.", "chain_predecessor": &"water_1", "chain_window": 1.8, "chain_bonus_mult": 1.35, "target_mode": Ability.TargetMode.FORWARD_CONE},
		# R: Water Form 3 — Rising Tide. Full chain from W1->W2->W3 pays 1.60x. AoE finisher.
		{"id": &"water_3", "name": "Rising Tide", "damage": 38.0, "range": 0.0, "radius": 2.6, "cooldown": 0.85, "cost": 20.0, "element": Ability.DamageType.PHYSICAL, "anim": "heavy", "pitch": 0.85, "desc": "Third Form — rising arc AoE. Punishes whiffs.", "chain_predecessor": &"water_2", "chain_window": 1.8, "chain_bonus_mult": 1.60, "target_mode": Ability.TargetMode.AOE_AROUND_SELF, "miss_punishment": 0.40},
		# F: Stance Resolve — +35% damage 6s buff.
		{"id": &"katana_power_up", "name": "Stance Resolve", "damage": 0.0, "range": 1.0, "radius": 1.0, "cooldown": 18.0, "anim": "power_up", "desc": "Center yourself. +35% damage for 6 seconds.", "chain_predecessor": &"", "chain_window": 0.0, "chain_bonus_mult": 1.0, "target_mode": Ability.TargetMode.SELF},
	]

func _kit_berserker() -> Array:
	# Aggression. War Cry triggers Battle Cry buff (red rage flash).
	return [
		{"id": &"cleave_1", "name": "Cleave", "damage": 40.0, "range": 3.0, "radius": 2.0, "cooldown": 0.8, "element": Ability.DamageType.PHYSICAL, "anim": "attack", "pitch": 0.85, "desc": "A wide horizontal swing. Hits everything in front."},
		{"id": &"leap_smash", "name": "Leap Smash", "damage": 60.0, "range": 4.0, "radius": 2.4, "cooldown": 6.0, "element": Ability.DamageType.PHYSICAL, "anim": "heavy", "pitch": 0.8, "desc": "Leap forward and slam down. Knocks back lighter mobs."},
		{"id": &"war_cry", "name": "War Cry", "damage": 0.0, "range": 6.0, "radius": 6.0, "cooldown": 14.0, "anim": "power_up", "desc": "Roar of rage. +35% damage for 6 seconds."},
		{"id": &"fury_swing", "name": "Fury Swing", "damage": 80.0, "range": 3.5, "radius": 2.0, "cooldown": 4.0, "element": Ability.DamageType.PHYSICAL, "anim": "heavy", "pitch": 0.75, "desc": "Two-handed overhead chop. Heaviest strike in the kit."},
	]

func _kit_assassin() -> Array:
	# Quick precision; Stealth doubles as a Battle Cry buff trigger.
	return [
		{"id": &"dagger_1", "name": "Dagger Combo", "damage": 24.0, "range": 2.2, "radius": 1.0, "cooldown": 0.4, "cost": 5.0, "element": Ability.DamageType.PHYSICAL, "anim": "iai", "pitch": 1.5, "desc": "Three-stab combo. Builds combo stacks fast."},
		{"id": &"backstab", "name": "Backstab", "damage": 70.0, "range": 2.0, "radius": 0.8, "cooldown": 5.0, "cost": 18.0, "element": Ability.DamageType.PHYSICAL, "anim": "heavy", "pitch": 1.3, "desc": "Massive single-target hit. Crit chance bumps from behind."},
		{"id": &"throw_kunai", "name": "Throw Kunai", "damage": 22.0, "range": 12.0, "radius": 0.6, "cooldown": 1.0, "cost": 8.0, "element": Ability.DamageType.PHYSICAL, "anim": "attack", "pitch": 1.6, "desc": "Ranged thrown blade. Long-range pickoff."},
		{"id": &"stealth_form", "name": "Shadow Veil", "damage": 0.0, "range": 1.0, "radius": 1.0, "cooldown": 18.0, "element": Ability.DamageType.SHADOW, "anim": "power_up", "desc": "Wrap yourself in shadow. +35% damage for 6 seconds."},
	]

func _kit_ranger() -> Array:
	# Bow class: range + Hawk's Eye buff.
	return [
		{"id": &"arrow_shot", "name": "Arrow Shot", "damage": 30.0, "range": 14.0, "radius": 0.6, "cooldown": 0.5, "cost": 5.0, "element": Ability.DamageType.PHYSICAL, "anim": "attack", "pitch": 1.3, "desc": "Quick bow shot. Sustained ranged DPS."},
		{"id": &"snipe", "name": "Snipe", "damage": 90.0, "range": 24.0, "radius": 0.5, "cooldown": 6.0, "cost": 22.0, "element": Ability.DamageType.PHYSICAL, "anim": "heavy", "pitch": 1.0, "desc": "Charged precision shot from extreme range."},
		{"id": &"hawk_command", "name": "Hawk's Eye", "damage": 0.0, "range": 1.0, "radius": 1.0, "cooldown": 14.0, "anim": "power_up", "desc": "Focus the hunt. +35% damage for 6 seconds."},
		{"id": &"trap_set", "name": "Bear Trap", "damage": 35.0, "range": 4.0, "radius": 1.5, "cooldown": 10.0, "element": Ability.DamageType.PHYSICAL, "anim": "block", "desc": "Place a snare in front of you. Triggers on contact."},
	]

func _kit_mage() -> Array:
	# Spell-slinger: Mana Shield is Guard, Frost Nova is AOE.
	return [
		{"id": &"spark", "name": "Spark", "damage": 22.0, "range": 12.0, "radius": 1.0, "cooldown": 0.6, "cost": 5.0, "element": Ability.DamageType.LIGHTNING, "anim": "iai", "pitch": 1.5, "desc": "Quick lightning bolt. Sustained ranged DPS."},
		{"id": &"fireball", "name": "Fireball", "damage": 65.0, "range": 14.0, "radius": 2.5, "cooldown": 3.0, "cost": 22.0, "element": Ability.DamageType.FIRE, "anim": "heavy", "pitch": 0.85, "desc": "Hurl a flaming sphere. AOE on impact."},
		{"id": &"frost_nova", "name": "Frost Nova", "damage": 45.0, "range": 5.0, "radius": 5.0, "cooldown": 8.0, "cost": 28.0, "element": Ability.DamageType.FROST, "anim": "attack", "pitch": 0.7, "desc": "Burst of ice in all directions. Slows enemies on hit."},
		{"id": &"mana_shield", "name": "Mana Shield", "damage": 0.0, "range": 1.0, "radius": 1.0, "cooldown": 6.0, "cost": 15.0, "element": Ability.DamageType.ARCANE, "anim": "power_up", "desc": "Soak 55% damage for 2 seconds."},
	]

func _kit_druid() -> Array:
	# Shapeshifter; Druid Form triggers Battle Cry-equivalent buff.
	return [
		{"id": &"vine_lash", "name": "Vine Lash", "damage": 30.0, "range": 5.0, "radius": 1.5, "cooldown": 0.7, "cost": 6.0, "element": Ability.DamageType.PHYSICAL, "anim": "attack", "pitch": 0.9, "desc": "Whip out vines from the earth. Mid-range pull."},
		{"id": &"bear_swipe", "name": "Bear Swipe", "damage": 55.0, "range": 3.0, "radius": 2.4, "cooldown": 4.0, "cost": 18.0, "element": Ability.DamageType.PHYSICAL, "anim": "heavy", "pitch": 0.7, "desc": "Channel the bear. Heavy clawed swipe."},
		{"id": &"druid_form", "name": "Primal Form", "damage": 0.0, "range": 1.0, "radius": 1.0, "cooldown": 18.0, "anim": "power_up", "desc": "Become the wild. +35% damage for 6 seconds."},
		{"id": &"totem_plant", "name": "Plant Totem", "damage": 0.0, "range": 3.0, "radius": 4.0, "cooldown": 18.0, "cost": 25.0, "element": Ability.DamageType.PHYSICAL, "anim": "stand_up", "desc": "Plant a healing totem. Allies in the radius regenerate."},
	]

func _kit_demon() -> Array:
	# Hellfire + soul magic; Demon Form is the buff cap.
	return [
		{"id": &"claw_rake", "name": "Claw Rake", "damage": 38.0, "range": 2.6, "radius": 1.4, "cooldown": 0.5, "element": Ability.DamageType.SHADOW, "anim": "iai", "pitch": 0.95, "desc": "Fast clawed rake. Inflicts bleed."},
		{"id": &"hellfire_burst", "name": "Hellfire Burst", "damage": 70.0, "range": 5.0, "radius": 5.0, "cooldown": 6.0, "element": Ability.DamageType.FIRE, "anim": "heavy", "pitch": 0.7, "desc": "Erupt hellfire around you. AOE inferno."},
		{"id": &"soul_drain", "name": "Soul Drain", "damage": 55.0, "range": 8.0, "radius": 1.5, "cooldown": 4.0, "element": Ability.DamageType.SHADOW, "anim": "attack", "pitch": 0.85, "desc": "Drain a foe's life-force. Heals you for 25% damage dealt."},
		{"id": &"demon_form", "name": "Demon Unleashed", "damage": 0.0, "range": 1.0, "radius": 1.0, "cooldown": 18.0, "element": Ability.DamageType.SHADOW, "anim": "power_up", "desc": "Embrace the demon. +35% damage for 6 seconds."},
	]

func _kit_paladin_guardian() -> Array:
	# Tank-paladin: Divine Shield is Guard, holy strikes for damage.
	return [
		{"id": &"sword_smite", "name": "Sword Smite", "damage": 42.0, "range": 3.0, "radius": 1.6, "cooldown": 0.7, "cost": 6.0, "element": Ability.DamageType.HOLY, "anim": "attack", "pitch": 1.1, "desc": "Holy melee strike. Bonus damage to undead."},
		{"id": &"shield_bash", "name": "Shield Bash", "damage": 28.0, "range": 2.4, "radius": 1.6, "cooldown": 4.0, "cost": 12.0, "element": Ability.DamageType.PHYSICAL, "anim": "block", "pitch": 0.9, "desc": "Slam your shield. Staggers the target."},
		{"id": &"judgment", "name": "Judgment Strike", "damage": 110.0, "range": 3.5, "radius": 2.0, "cooldown": 18.0, "cost": 50.0, "element": Ability.DamageType.HOLY, "anim": "heavy", "pitch": 0.9, "desc": "Capstone holy slam. Massive AOE damage."},
		{"id": &"divine_shield", "name": "Divine Shield", "damage": 0.0, "range": 1.0, "radius": 1.0, "cooldown": 12.0, "cost": 30.0, "element": Ability.DamageType.HOLY, "anim": "power_up", "desc": "Halve incoming damage for 2 seconds."},
	]

func _kit_paladin_light() -> Array:
	# Holy support: Sun Beam ranged, Healing Aura HEALS the player.
	return [
		{"id": &"mace_swing", "name": "Mace Swing", "damage": 30.0, "range": 2.6, "radius": 1.4, "cooldown": 0.6, "cost": 4.0, "element": Ability.DamageType.HOLY, "anim": "attack", "desc": "Holy mace strike. Sustained holy DPS."},
		{"id": &"sun_beam", "name": "Sun Beam", "damage": 60.0, "range": 12.0, "radius": 1.0, "cooldown": 5.0, "cost": 24.0, "element": Ability.DamageType.HOLY, "anim": "iai", "pitch": 1.4, "desc": "Focused beam of sunlight. Long-range holy."},
		{"id": &"holy_pillar", "name": "Holy Pillar", "damage": 80.0, "range": 5.0, "radius": 2.5, "cooldown": 12.0, "cost": 35.0, "element": Ability.DamageType.HOLY, "anim": "heavy", "pitch": 1.0, "desc": "Pillar of light from above. AOE smite."},
		{"id": &"healing_aura", "name": "Healing Aura", "damage": 0.0, "range": 4.0, "radius": 8.0, "cooldown": 18.0, "cost": 35.0, "element": Ability.DamageType.HOLY, "anim": "power_up", "desc": "Heal yourself for 30% max HP."},
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
	# Direction: current input dir if moving, else mesh forward.
	# Mesh is +Z-forward (Mixamo) so use +basis.z, not -basis.z.
	var dir: Vector3 = input_dir
	if dir.length_squared() < 0.001 and mesh:
		dir = mesh.global_transform.basis.z
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
	# +basis.z (mesh is +Z-forward Mixamo). Without this, dodge
	# directional anims swap front/back constantly.
	var forward: Vector3 = mesh.global_transform.basis.z
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

# --- PERFECT DODGE / RIPOSTE ---
#
# Perfect-dodge window = the LAST 0.10s of the dodge i-frame window.
# If an enemy attack hitbox overlaps the player during that narrow
# slice, we trigger a Riposte buff:
#   - 1.0s window during which the player's NEXT attack does +50%
#     damage and crits automatically
#   - 0.40s slowmo at 0.30x time scale
#   - Gold ring VFX expands from the player's feet
#   - Audio chord + camera flash
#   - "PERFECT DODGE" toast
#
# This is the Sekiro/Bloodborne risk-reward: the player is rewarded
# for dodging AT THE LAST possible frame, not jumping early. Without
# this mechanic, dodge is a binary 'safe / not safe' choice; with it,
# dodge becomes a SKILL EXPRESSION.
const PERFECT_DODGE_WINDOW: float = 0.10
const RIPOSTE_DURATION: float = 1.0
const RIPOSTE_DAMAGE_MULT: float = 1.5
var _riposte_until: float = 0.0
signal perfect_dodge_triggered

# Called by enemies/bosses when their attack would have hit the player.
# If the player is in the LATE i-frame slice (perfect-dodge window),
# this triggers Riposte and returns true (caller should treat the
# attack as "dodged with style"); else returns false.
#
# Attacks that hit the player NORMALLY just call is_invulnerable()
# and skip damage; perfect_dodge_check is for the more rewarding
# cinematic path.
func check_perfect_dodge() -> bool:
	if not _dodging:
		return false
	var now: float = Time.get_ticks_msec() / 1000.0
	# The perfect window is the LAST 0.10s of the i-frame duration —
	# i.e. the player dodged AT THE LAST FRAME. Compute the window
	# start as iframe_end - PERFECT_DODGE_WINDOW.
	var perfect_window_start: float = _dodge_iframes_until - PERFECT_DODGE_WINDOW
	if now >= perfect_window_start and now <= _dodge_iframes_until:
		_trigger_riposte()
		return true
	return false

func _trigger_riposte() -> void:
	_riposte_until = Time.get_ticks_msec() / 1000.0 + RIPOSTE_DURATION
	perfect_dodge_triggered.emit()
	# Slowmo punch — 0.30x for 0.40s
	var juice: Node = get_node_or_null("/root/Juice")
	if juice:
		if juice.has_method("slowmo"):
			juice.slowmo(0.30, 0.40)
		if juice.has_method("flash"):
			juice.flash(Color(1.0, 0.92, 0.55), 0.20, 0.25)
		if juice.has_method("toast"):
			juice.toast("PERFECT DODGE", Color(1.0, 0.92, 0.55), 1.5)
		if juice.has_method("hit_stop"):
			juice.hit_stop(0.10)
	# Audio chord (use victory cue at higher pitch — short triumphant)
	var ab: Node = get_node_or_null("/root/AudioBus")
	if ab and ab.has_method("play_cue"):
		ab.play_cue(&"crit", global_position, -3.0, 1.4)
	# Gold ring VFX expanding from player's feet
	_spawn_riposte_ring()

func _spawn_riposte_ring() -> void:
	var ring := GPUParticles3D.new()
	ring.name = "RiposteRing"
	ring.amount = 60
	ring.lifetime = 0.7
	ring.one_shot = true
	ring.explosiveness = 1.0
	ring.visibility_aabb = AABB(Vector3(-5, -1, -5), Vector3(10, 3, 10))
	var pm := ParticleProcessMaterial.new()
	pm.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_RING
	pm.emission_ring_axis = Vector3(0, 1, 0)
	pm.emission_ring_radius = 0.3
	pm.emission_ring_inner_radius = 0.15
	pm.emission_ring_height = 0.05
	pm.direction = Vector3(0, 0.4, 0)
	pm.spread = 25.0
	pm.initial_velocity_min = 5.0
	pm.initial_velocity_max = 8.0
	pm.gravity = Vector3.ZERO
	pm.tangential_accel_min = 1.5
	pm.tangential_accel_max = 3.0
	pm.scale_min = 0.18
	pm.scale_max = 0.32
	pm.color = Color(1.0, 0.92, 0.55, 1.0)
	ring.process_material = pm
	var quad := QuadMesh.new()
	quad.size = Vector2(0.20, 0.20)
	var smat := StandardMaterial3D.new()
	smat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	smat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	smat.albedo_color = Color(1.0, 0.92, 0.55, 0.95)
	smat.emission_enabled = true
	smat.emission = Color(1.0, 0.95, 0.65)
	smat.emission_energy_multiplier = 3.5
	smat.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
	quad.material = smat
	ring.draw_pass_1 = quad
	get_tree().current_scene.add_child(ring)
	ring.global_position = global_position + Vector3(0, 0.1, 0)
	get_tree().create_timer(1.5).timeout.connect(func():
		if is_instance_valid(ring): ring.queue_free())

func has_riposte_buff() -> bool:
	return Time.get_ticks_msec() / 1000.0 < _riposte_until

# Consume the Riposte buff. Called by attack code AFTER the damage
# calc reads has_riposte_buff() and applies the multiplier — this
# clears the buff so it only applies to the FIRST hit.
func consume_riposte_buff() -> void:
	_riposte_until = 0.0

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
	# EXECUTION CHECK — closes the posture loop. If the locked target
	# is a boss in the staggered window AND the player is within 3m
	# (deep melee range) AND facing it, fire the cinematic finisher
	# instead of a regular swing.
	if _try_execution_on_staggered_boss():
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
	# +basis.z (mesh is +Z-forward Mixamo). With -basis.z the basic-attack
	# hitbox spawned BEHIND the player and the swing felt "weightless".
	var fwd := mesh.global_transform.basis.z if mesh else global_transform.basis.z
	fwd.y = 0; fwd = fwd.normalized()
	# Add to tree FIRST so look_at_from_position works (look_at on
	# pre-tree node fires 'Node not inside tree' error). Set position
	# + look_at via global helpers after add_child.
	get_tree().current_scene.add_child(hb)
	hb.global_position = global_position + fwd * (swing.range * 0.5)
	hb.look_at(global_position + fwd * swing.range, Vector3.UP)

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
			# Surface-aware step cue. Raycast straight down 1.2m and
			# read the metadata of whatever StaticBody3D we hit. Each
			# zone's procedural builds tag floor / dojo / bridge etc
			# with `surface_type` metadata; default is stone.
			var step_cue: StringName = _classify_step_surface()
			# Slight pitch jitter so steps don't drone, plus per-surface
			# pitch bias (wood is brighter, stone is heavier)
			var pitch_bias: float = 1.0
			match step_cue:
				&"step_wood":  pitch_bias = 1.08
				&"step_grass": pitch_bias = 0.92
				&"step_stone": pitch_bias = 0.95
			ab.play_cue(step_cue, global_position, -14.0, pitch_bias * randf_range(0.92, 1.08))

# Probe what the player is standing on. Returns a step cue StringName
# that AudioBus knows how to play. Default = step_stone.
# Without a per-surface raycast every footstep would sound the same
# regardless of whether the player is walking on the stone path or
# the wood dojo floor or the grass perimeter.
func _classify_step_surface() -> StringName:
	var space := get_world_3d().direct_space_state
	var origin := global_position + Vector3(0, 0.2, 0)
	var query := PhysicsRayQueryParameters3D.create(origin, origin + Vector3(0, -1.6, 0))
	query.collision_mask = 1  # world geometry layer
	query.exclude = [get_rid()]
	var hit := space.intersect_ray(query)
	if hit.is_empty():
		return &"step"  # generic fallback
	var collider: Object = hit.get("collider")
	# Procedural dojo and similar buildings tag their StaticBody3Ds
	# with metadata. Read whichever the hit had; fall back to stone.
	if collider and collider.has_meta("surface_type"):
		var st: String = String(collider.get_meta("surface_type"))
		match st:
			"wood":  return &"step_wood"
			"grass": return &"step_grass"
			"stone": return &"step_stone"
	# Heuristic: if collider's scene path contains 'dojo' or 'wood',
	# treat as wood; if 'floor' or 'tile' default to stone.
	if collider and collider is Node:
		var nm: String = (collider as Node).name.to_lower()
		if nm.contains("dojo") or nm.contains("wood") or nm.contains("plank") or nm.contains("tatami"):
			return &"step_wood"
	return &"step_stone"

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
	_tick_posture_decay(delta)
	_tick_block(delta)

func _tick_posture_decay(delta: float) -> void:
	if player_posture <= 0.0:
		return
	var now: float = Time.get_ticks_msec() / 1000.0
	if now - _last_player_posture_hit_at < PLAYER_POSTURE_DECAY_DELAY:
		return
	player_posture = max(0.0, player_posture - PLAYER_POSTURE_DECAY_PER_SEC * delta)
	posture_changed.emit(player_posture, PLAYER_MAX_POSTURE)
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
	var horizontal_speed: float = Vector2(velocity.x, velocity.z).length()
	var moving: bool = horizontal_speed > 0.5 and is_on_floor()
	# Walk/run threshold: above 5.5 m/s (sprinting) play run anim, below
	# play walk. Idle when stopped. This lets the Ronin's katana_run
	# vs katana_walk overrides actually fire based on movement speed
	# instead of always using walk.
	var slot: String
	if not moving:
		slot = "idle"
	elif horizontal_speed > 5.5:
		slot = "run"
	else:
		slot = "walk"
	# Resolve the slot through our alias map to whatever the imported character provides
	var resolved: String = _resolved_anims.get(slot, "")
	if resolved == "":
		# Fall back: if run anim missing, use walk
		if slot == "run":
			resolved = _resolved_anims.get("walk", "")
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
	# BLOCK / PARRY resolution. Tap-time within 0.15s of block-start
	# = parry (zero damage, riposte buff, +60 attacker posture).
	# Hold-through = block (65% soaked, stamina drained).
	var block_state: String = resolve_block_state(source)
	if block_state == "parry":
		return  # Parry zeroed the damage entirely
	if block_state == "block":
		amount *= (1.0 - BLOCK_DAMAGE_SOAK)
		# Block hit feedback (smaller than parry)
		var jc: Node = get_node_or_null("/root/Juice")
		if jc and jc.has_method("shake"):
			jc.shake(0.08, 0.10)
		var ab2: Node = get_node_or_null("/root/AudioBus")
		if ab2 and ab2.has_method("play_cue"):
			ab2.play_cue(&"block", global_position, -8.0, 0.95)
	# PLAYER POSTURE — each hit adds clamped posture. Full = brief
	# stagger (locks input for 1s). Symmetric to the boss posture
	# system so combat is bidirectional risk.
	var posture_dmg: float = min(PLAYER_POSTURE_DAMAGE_PER_HIT_MAX, amount * PLAYER_POSTURE_DAMAGE_SCALE)
	player_posture = clamp(player_posture + posture_dmg, 0.0, PLAYER_MAX_POSTURE)
	_last_player_posture_hit_at = Time.get_ticks_msec() / 1000.0
	posture_changed.emit(player_posture, PLAYER_MAX_POSTURE)
	if player_posture >= PLAYER_MAX_POSTURE - 0.01:
		_player_staggered_until = Time.get_ticks_msec() / 1000.0 + PLAYER_STAGGER_DURATION
		player_posture = 0.0  # consumed by stagger
		posture_changed.emit(player_posture, PLAYER_MAX_POSTURE)
		# Lock input for the duration
		locked = true
		# Cinematic feedback so the player KNOWS they got staggered
		var jcs: Node = get_node_or_null("/root/Juice")
		if jcs:
			if jcs.has_method("shake"):
				jcs.shake(0.45, 0.30)
			if jcs.has_method("flash"):
				jcs.flash(Color(0.95, 0.20, 0.18), 0.30, 0.40)
		# Hit-react anim is already played below via take_damage flow
		get_tree().create_timer(PLAYER_STAGGER_DURATION).timeout.connect(func():
			if not is_instance_valid(self): return
			locked = false)
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
	# Combat scar: if this hit took >= 25% max HP, the ScarManager records it.
	var scar_mgr: Node = get_node_or_null("ScarManager")
	if scar_mgr and scar_mgr.has_method("record_hit_taken"):
		scar_mgr.record_hit_taken(amount, stats.max_hp, source, 0)
	# Achievement tracker: marks any active boss-fight as "took damage" so
	# no-hit achievements (the_untouched, the_unmarked) fail gracefully.
	var ach_tracker: Node = get_node_or_null("AchievementTracker")
	if ach_tracker and ach_tracker.has_method("on_damage_taken"):
		ach_tracker.on_damage_taken(amount)
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

# CharacterCreator handoff: AppearanceRegistry stashes the just-created
# CharacterAppearance + chosen name in pending slots when the Storyteller
# flow finishes. The first Player to spawn in the new scene consumes them.
# Gracefully no-ops if nothing is pending (eg legacy direct-load of an intro).
func _attach_quest_log() -> void:
	if get_node_or_null("QuestLog"):
		return  # already attached (eg loaded from save with the node restored)
	var qlog_script: GDScript = load("res://scripts/quests/quest_log.gd")
	if not qlog_script:
		return
	var qlog: Node = qlog_script.new()
	qlog.name = "QuestLog"
	qlog.owner_player = self
	add_child(qlog)

func _attach_achievement_tracker() -> void:
	if get_node_or_null("AchievementTracker"):
		return
	var tr_script: GDScript = load("res://scripts/achievements/achievement_tracker.gd")
	if not tr_script:
		return
	var tracker: Node = tr_script.new()
	tracker.name = "AchievementTracker"
	tracker.owner_player = self
	add_child(tracker)
	# Bridge CombatBus.kill_registered -> tracker.on_enemy_killed.
	# CombatBus emits the killed Node; the tracker decides which trigger applies.
	var cb: Node = get_node_or_null("/root/CombatBus")
	if cb and cb.has_signal("kill_registered"):
		if not cb.kill_registered.is_connected(_on_combatbus_kill):
			cb.kill_registered.connect(_on_combatbus_kill)

# Forwards CombatBus.kill_registered into the local AchievementTracker. We
# infer tags from the killed node — bosses always count, mobs use their
# `mob_id` as a tag, and demon/undead/human group memberships add tags.
func _on_combatbus_kill(target: Node, _killer: Node) -> void:
	var tracker: Node = get_node_or_null("AchievementTracker")
	if not tracker or not tracker.has_method("on_enemy_killed") or not target or not is_instance_valid(target):
		return
	var tags: Array = []
	if target.is_in_group("demon"):    tags.append("demon")
	if target.is_in_group("undead"):   tags.append("undead")
	if target.is_in_group("boss"):     tags.append("boss")
	if target.is_in_group("tiamat_spawn"): tags.append("tiamat_spawn")
	if "mob_id" in target and target.mob_id != &"":
		tags.append(String(target.mob_id))
	tracker.on_enemy_killed(target, tags)

func _consume_pending_appearance() -> void:
	var ar: Node = get_node_or_null("/root/AppearanceRegistry")
	if not ar or not ar.has_method("take_pending"):
		return
	var pending: Dictionary = ar.take_pending()
	var appearance = pending.get("appearance")
	var picked_name: String = String(pending.get("name", ""))
	if appearance:
		character_appearance = appearance
		# If the creator picked a class, seed the stats with it so the
		# zone's auto-assign skips. Direct field write (not via class
		# resource registry) so the appearance.class_id is the source of truth.
		if appearance.class_id != &"" and stats and not stats.class_def:
			var class_registry: Node = get_node_or_null("/root/ClassRegistry")
			if class_registry and class_registry.has_method("get_class_def"):
				stats.class_def = class_registry.get_class_def(appearance.class_id)
				if stats.class_def:
					stats.recompute_derived()
		# Apply the visual layer (skin/hair/eye tint, height scale, halos, founder mark).
		# Deferred so the mesh tree is fully _ready before tinting.
		call_deferred("_apply_appearance_now", ar)
	if picked_name != "":
		character_name = picked_name

func _apply_appearance_now(ar: Node) -> void:
	if ar and ar.has_method("apply") and character_appearance:
		ar.apply(self, character_appearance)

# HUD reads these to show cooldown overlays and ability names without needing
# direct access to the private dictionary kit.
func get_ability_cooldown_remaining(slot: int) -> float:
	if slot < 0 or slot >= _ability_cooldowns.size():
		return 0.0
	var now := Time.get_ticks_msec() / 1000.0
	return max(0.0, float(_ability_cooldowns[slot]) - now)

func get_ability_slot_info(slot: int) -> Dictionary:
	if slot < 0 or slot >= _ability_kit.size():
		return {}
	var k = _ability_kit[slot]
	return k if k is Dictionary else {}

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
	if consumed:
		# Apothecary saturation: record the drink on character_appearance for the
		# Tier 2 living-character system (CHARACTER_DESIGN.md § 8.5.5). Each type
		# has a 0..1000 lifetime track; the dominant track tints the character.
		# Resolved via item.id first (handles potion_champions_draught precisely),
		# then by tag/field (catches custom potions defined outside the registry).
		if character_appearance and character_appearance.has_method("record_potion_drink"):
			var ptype: StringName = _classify_potion_for_saturation(item)
			if ptype != &"":
				character_appearance.record_potion_drink(ptype)
		if inventory:
			inventory.remove_item(item.id, 1)
	return consumed

# Maps an Item to its apothecary-saturation track. Returns &"" to skip.
# Champion's Draught is checked first (most specific), then surge tags, then
# the consumable-type fields.
func _classify_potion_for_saturation(item: Item) -> StringName:
	if String(item.id).begins_with("potion_champions"):
		return &"champion"
	if &"surge_hp" in item.unique_tags or item.heal_amount > 0.0:
		return &"hp"
	if &"surge_mana" in item.unique_tags or item.mana_amount > 0.0:
		return &"mana"
	if &"surge_stamina" in item.unique_tags or &"restore_stamina" in item.unique_tags:
		return &"stamina"
	return &""

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
