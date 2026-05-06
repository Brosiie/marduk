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
	"die":    ["marduk/death", "marduk/death_forward", "marduk/death_react_forward", "marduk/death_react_right", "marduk/death_back", "Mixamo_Dying", "die", "Death_A", "Death_A_Pose", "Death_B"],
	"hit":    ["marduk/hit_react", "marduk/hit_react_left", "marduk/hit_react_right", "Mixamo_Hit", "hit", "Hit_A", "Hit_B"],
	"jump":   ["marduk/jump_up", "marduk/jump_down", "Mixamo_Jump", "jump", "Jump_Full_Long", "Jump_Start"],
	"taunt":  ["marduk/taunt", "Mixamo_Taunt"],
	"stand_up": ["marduk/stand_up", "Mixamo_Stand"],
	"block":  ["marduk/block_idle", "marduk/katana_blocking", "marduk/shield_block"],
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
	# Force-fresh HP/mana so HUD doesn't show stale values from the ProgressBar defaults
	stats.hp = stats.max_hp
	stats.mana = stats.max_mana
	if stats.class_def:
		resource_value = stats.class_def.resource_max if stats.class_def.resource_mechanic == &"mana" else 0.0
	_camera_basis_provider = get_tree().get_first_node_in_group("camera_rig")
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
	_load_marduk_animation_library()
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
	var biggest: float = max(size.x, max(size.y, size.z))
	# Mixamo skin can render with valid Y AABB but collapsed Z (~0.13m)
	# when skeleton bones lack a proper rest pose pre-retarget. Force a
	# fallback capsule whenever ANY axis is below 0.3m or no meshes exist,
	# so the player position is always unambiguous.
	var smallest: float = min(size.x, min(size.y, size.z))
	if meshes.is_empty() or biggest < 0.2 or smallest < 0.3:
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

# Pulls the Mixamo .fbx animations declared in AnimationRegistry onto this
# Player's AnimationPlayer under the canonical "marduk/<slot>" namespace.
# Keeps gameplay decoupled from filenames; ANIM_ALIASES picks up the merged
# names automatically. No-op if the autoloads or AnimationPlayer aren't ready.
func _load_marduk_animation_library() -> void:
	if anim_player == null:
		return
	if not stats or not stats.class_def:
		return
	var loader_script: GDScript = load("res://scripts/anim/animation_library_loader.gd")
	if loader_script == null:
		return
	var loader = loader_script.new()
	loader.apply(self, "class", StringName(stats.class_def.class_id))

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

# --- Class kits ---
func _kit_default() -> Array:
	return [
		{"id": &"basic_swing", "name": "Swing", "damage": 25.0, "range": 2.5, "radius": 1.4, "cooldown": 0.6, "anim": "attack"},
		{}, {}, {}
	]

func _kit_ronin() -> Array:
	return [
		{"id": &"iai_strike", "name": "Iai Strike", "damage": 38.0, "range": 3.2, "radius": 1.0, "cooldown": 0.6, "cost": 8.0, "anim": "attack", "pitch": 1.4},
		{"id": &"water_breath_1", "name": "Water Breath: First Form", "damage": 32.0, "range": 4.5, "radius": 2.0, "cooldown": 1.2, "cost": 12.0, "anim": "attack", "pitch": 0.95},
		{"id": &"thunder_breath_1", "name": "Thunder Breath: First Form", "damage": 56.0, "range": 6.5, "radius": 1.6, "cooldown": 4.0, "cost": 24.0, "anim": "attack", "pitch": 1.6},
		{"id": &"parry", "name": "Parry", "damage": 0.0, "range": 2.0, "radius": 1.0, "cooldown": 6.0, "anim": "block"},
	]

func _kit_berserker() -> Array:
	return [
		{"id": &"cleave_1", "name": "Cleave", "damage": 40.0, "range": 3.0, "radius": 2.0, "cooldown": 0.8, "anim": "attack", "pitch": 0.85},
		{"id": &"war_cry", "name": "War Cry", "damage": 0.0, "range": 6.0, "radius": 6.0, "cooldown": 12.0, "anim": "taunt"},
		{"id": &"leap_smash", "name": "Leap Smash", "damage": 60.0, "range": 4.0, "radius": 2.4, "cooldown": 6.0, "anim": "attack", "pitch": 0.8},
		{"id": &"fury_swing", "name": "Fury Swing", "damage": 80.0, "range": 3.5, "radius": 2.0, "cooldown": 4.0, "anim": "attack", "pitch": 0.75},
	]

func _kit_assassin() -> Array:
	return [
		{"id": &"dagger_1", "name": "Dagger Combo 1", "damage": 24.0, "range": 2.2, "radius": 1.0, "cooldown": 0.4, "cost": 5.0, "anim": "attack", "pitch": 1.5},
		{"id": &"backstab", "name": "Backstab", "damage": 70.0, "range": 2.0, "radius": 0.8, "cooldown": 5.0, "cost": 18.0, "anim": "attack", "pitch": 1.3},
		{"id": &"blink_dash", "name": "Blink Dash", "damage": 18.0, "range": 7.0, "radius": 1.0, "cooldown": 3.0, "cost": 12.0, "anim": "dodge", "pitch": 1.7},
		{"id": &"throw_kunai", "name": "Throw Kunai", "damage": 22.0, "range": 12.0, "radius": 0.6, "cooldown": 1.0, "cost": 8.0, "anim": "attack", "pitch": 1.6},
	]

func _kit_ranger() -> Array:
	return [
		{"id": &"arrow_shot", "name": "Arrow Shot", "damage": 30.0, "range": 14.0, "radius": 0.6, "cooldown": 0.5, "cost": 5.0, "anim": "attack", "pitch": 1.3},
		{"id": &"snipe", "name": "Snipe", "damage": 90.0, "range": 24.0, "radius": 0.5, "cooldown": 6.0, "cost": 22.0, "anim": "attack", "pitch": 1.0},
		{"id": &"hawk_command", "name": "Hawk Strike", "damage": 50.0, "range": 16.0, "radius": 1.5, "cooldown": 8.0, "cost": 20.0, "anim": "taunt"},
		{"id": &"trap_set", "name": "Bear Trap", "damage": 35.0, "range": 4.0, "radius": 1.5, "cooldown": 10.0, "anim": "stand_up"},
	]

func _kit_mage() -> Array:
	return [
		{"id": &"spark", "name": "Spark", "damage": 22.0, "range": 12.0, "radius": 1.0, "cooldown": 0.6, "cost": 5.0, "element": Ability.DamageType.LIGHTNING, "anim": "attack", "pitch": 1.5},
		{"id": &"fireball", "name": "Fireball", "damage": 65.0, "range": 14.0, "radius": 2.5, "cooldown": 3.0, "cost": 22.0, "element": Ability.DamageType.FIRE, "anim": "attack", "pitch": 0.85},
		{"id": &"frost_nova", "name": "Frost Nova", "damage": 45.0, "range": 5.0, "radius": 5.0, "cooldown": 8.0, "cost": 28.0, "element": Ability.DamageType.FROST, "anim": "attack", "pitch": 0.7},
		{"id": &"teleport", "name": "Teleport", "damage": 0.0, "range": 12.0, "radius": 0.5, "cooldown": 12.0, "cost": 30.0, "anim": "dodge", "pitch": 1.8},
	]

func _kit_druid() -> Array:
	return [
		{"id": &"vine_lash", "name": "Vine Lash", "damage": 30.0, "range": 5.0, "radius": 1.5, "cooldown": 0.7, "cost": 6.0, "anim": "attack", "pitch": 0.9},
		{"id": &"totem_plant", "name": "Plant Totem", "damage": 0.0, "range": 3.0, "radius": 4.0, "cooldown": 18.0, "cost": 25.0, "anim": "stand_up"},
		{"id": &"bear_form", "name": "Bear Swipe", "damage": 55.0, "range": 3.0, "radius": 2.4, "cooldown": 4.0, "cost": 18.0, "anim": "attack", "pitch": 0.7},
		{"id": &"wolf_form", "name": "Wolf Pounce", "damage": 40.0, "range": 6.0, "radius": 1.6, "cooldown": 5.0, "cost": 18.0, "anim": "dodge", "pitch": 1.3},
	]

func _kit_demon() -> Array:
	return [
		{"id": &"claw_rake", "name": "Claw Rake", "damage": 38.0, "range": 2.6, "radius": 1.4, "cooldown": 0.5, "anim": "attack", "pitch": 0.95},
		{"id": &"hellfire_burst", "name": "Hellfire Burst", "damage": 70.0, "range": 5.0, "radius": 5.0, "cooldown": 6.0, "element": Ability.DamageType.FIRE, "anim": "attack", "pitch": 0.7},
		{"id": &"soul_drain", "name": "Soul Drain", "damage": 55.0, "range": 8.0, "radius": 1.5, "cooldown": 4.0, "element": Ability.DamageType.SHADOW, "anim": "attack", "pitch": 0.85},
		{"id": &"wing_glide", "name": "Wing Glide", "damage": 0.0, "range": 9.0, "radius": 1.0, "cooldown": 8.0, "anim": "dodge", "pitch": 1.5},
	]

func _kit_paladin_guardian() -> Array:
	return [
		{"id": &"sword_smite", "name": "Sword Smite", "damage": 42.0, "range": 3.0, "radius": 1.6, "cooldown": 0.7, "cost": 6.0, "element": Ability.DamageType.HOLY, "anim": "attack", "pitch": 1.1},
		{"id": &"shield_bash", "name": "Shield Bash", "damage": 28.0, "range": 2.4, "radius": 1.6, "cooldown": 4.0, "cost": 12.0, "anim": "block", "pitch": 0.9},
		{"id": &"holy_pillar", "name": "Holy Pillar", "damage": 80.0, "range": 5.0, "radius": 2.5, "cooldown": 12.0, "cost": 35.0, "element": Ability.DamageType.HOLY, "anim": "attack", "pitch": 1.0},
		{"id": &"judgment", "name": "Judgment Strike", "damage": 110.0, "range": 3.5, "radius": 2.0, "cooldown": 18.0, "cost": 50.0, "element": Ability.DamageType.HOLY, "anim": "attack", "pitch": 0.9},
	]

func _kit_paladin_light() -> Array:
	return [
		{"id": &"mace_swing", "name": "Mace Swing", "damage": 30.0, "range": 2.6, "radius": 1.4, "cooldown": 0.6, "cost": 4.0, "element": Ability.DamageType.HOLY, "anim": "attack"},
		{"id": &"sun_beam", "name": "Sun Beam", "damage": 60.0, "range": 12.0, "radius": 1.0, "cooldown": 5.0, "cost": 24.0, "element": Ability.DamageType.HOLY, "anim": "attack", "pitch": 1.4},
		{"id": &"healing_aura", "name": "Healing Aura", "damage": 0.0, "range": 4.0, "radius": 8.0, "cooldown": 18.0, "cost": 35.0, "element": Ability.DamageType.HOLY, "anim": "stand_up"},
		{"id": &"divine_shield", "name": "Divine Shield", "damage": 0.0, "range": 1.0, "radius": 1.0, "cooldown": 30.0, "cost": 50.0, "anim": "block"},
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
	# Animation
	if anim_player:
		var dodge_name: String = _resolved_anims.get("dodge", "")
		if dodge_name != "":
			anim_player.stop()
			anim_player.play(dodge_name)
	# Direction: current input dir if moving, else mesh forward
	var dir: Vector3 = input_dir
	if dir.length_squared() < 0.001 and mesh:
		dir = -mesh.global_transform.basis.z
	dir.y = 0
	if dir.length_squared() < 0.001:
		return
	dir = dir.normalized()
	_dodging = true
	_dodge_iframes_until = (Time.get_ticks_msec() / 1000.0) + DODGE_IFRAME_DURATION
	# Tween position over DODGE_DURATION
	var target_pos := global_position + dir * DODGE_DISTANCE
	var tw := create_tween()
	tw.tween_property(self, "global_position", target_pos, DODGE_DURATION).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	tw.tween_callback(func(): _dodging = false)

# Combat damage filter — dodging i-frames make the player invulnerable
# during the early window. Combat code can call this gate before applying
# damage.
func is_invulnerable() -> bool:
	return Time.get_ticks_msec() / 1000.0 < _dodge_iframes_until

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

func _physics_process(delta: float) -> void:
	if locked:
		velocity.x = 0
		velocity.z = 0
	else:
		_read_input()
		_apply_horizontal(delta)
	_apply_vertical(delta)
	move_and_slide()
	_update_animation()
	_tick_resource(delta)
	_tick_form(delta)
	_tick_heaven_aura(delta)

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
	if input_dir.length() > 0.1:
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
func take_damage(amount: float, source: Node = null) -> void:
	if stats.hp <= 0:
		return
	# Dodge i-frames absorb the hit completely
	if is_invulnerable():
		return
	stats.hp = max(0.0, stats.hp - amount)
	hp_changed.emit(stats.hp, stats.max_hp)
	# Damage floater above the player so the player sees what's hitting them
	var floater_script: GDScript = load("res://scripts/combat/damage_floater.gd")
	if floater_script and floater_script.has_method("spawn"):
		floater_script.spawn(self, amount, false, &"physical")
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
