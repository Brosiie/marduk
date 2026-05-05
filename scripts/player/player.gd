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
@onready var anim_player: AnimationPlayer = $MeshRoot/AnimationPlayer if has_node("MeshRoot/AnimationPlayer") else null

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

func _ready() -> void:
	add_to_group("player")
	if not stats:
		stats = PlayerStats.new()
		stats.recompute_derived()
	if stats.class_def:
		resource_value = stats.class_def.resource_max if stats.class_def.resource_mechanic == &"mana" else 0.0
	_camera_basis_provider = get_tree().get_first_node_in_group("camera_rig")

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
	var moving := Vector2(velocity.x, velocity.z).length() > 0.5 and is_on_floor()
	var want := "walk" if moving else "idle"
	if anim_player.has_animation(want) and anim_player.current_animation != want:
		anim_player.play(want)

# Combat hooks
func take_damage(amount: float, source: Node = null) -> void:
	if stats.hp <= 0:
		return
	stats.hp = max(0.0, stats.hp - amount)
	hp_changed.emit(stats.hp, stats.max_hp)
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
	if anim_player and anim_player.has_animation("die"):
		anim_player.play("die")

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
