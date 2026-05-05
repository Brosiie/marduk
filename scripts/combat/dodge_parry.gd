extends Node
class_name DodgeParry

# Player input layer for evasive actions:
#   - Dodge (Shift): brief invincibility frame burst, locks horizontal motion to dodge direction
#   - Parry (RMB): short window where incoming melee hits trigger a perfect-parry response
#                   (no damage taken, large posture damage to attacker, free hit window)
#   - Block (RMB hold): reduces incoming damage and posture impact

signal dodge_started(direction: Vector3)
signal dodge_ended
signal parry_window_open
signal parry_window_closed
signal perfect_parry_landed(attacker: Node)

@export var owner_player: Node

@export_group("Dodge")
@export var dodge_distance: float = 5.0
@export var dodge_duration: float = 0.35
@export var dodge_iframes: float = 0.25
@export var dodge_stamina_cost: float = 20.0  # uses player resource if mana-typed
@export var dodge_cooldown: float = 0.5

@export_group("Parry")
@export var parry_window: float = 0.18  # tight!
@export var parry_cooldown: float = 0.6
@export var perfect_parry_posture_damage: float = 35.0
@export var block_damage_reduction: float = 0.55
@export var block_posture_dampening: float = 0.5

var _is_dodging: bool = false
var _dodge_iframe_until: float = -INF
var _dodge_cd_until: float = -INF
var _parry_open_until: float = -INF
var _parry_cd_until: float = -INF
var _is_blocking: bool = false

func _physics_process(_delta: float) -> void:
	if not owner_player:
		return
	# Block hold (RMB) when not in parry window
	_is_blocking = Input.is_mouse_button_pressed(MOUSE_BUTTON_RIGHT) and not _in_parry_window()

func _input(event: InputEvent) -> void:
	if event is InputEventKey:
		if event.keycode == KEY_SHIFT and event.pressed:
			try_dodge()
	elif event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_RIGHT and event.pressed:
			try_parry()

func try_dodge() -> void:
	# Universal dodge/roll for every class. Direction = current input vector;
	# if no input, dodges backward (away from current target if locked, else
	# away from facing). Stamina cost scales: melee classes pay less stamina
	# than caster classes (mana classes pay equivalent mana). Demon: free dodge.
	var now := Time.get_ticks_msec() / 1000.0
	if now < _dodge_cd_until or _is_dodging:
		return
	if not owner_player or not owner_player.stats or not owner_player.stats.class_def:
		return

	var mech: StringName = owner_player.stats.class_def.resource_mechanic
	var cost := dodge_stamina_cost
	var paid := true

	# Pay cost based on class resource. Demon pays nothing (Bond's spec).
	match mech:
		&"stamina":
			if owner_player.resource_value < cost:
				return
			owner_player.resource_value -= cost
		&"mana":
			# Druids and Mages pay mana, but at half cost (they spent the budget on spells)
			cost = cost * 0.5
			if owner_player.resource_value < cost:
				return
			owner_player.resource_value -= cost
		&"rage":
			# Berserkers pay nothing; rage is for offense, dodge is free
			pass
		&"blood":
			# Demons dodge free
			pass
		_:
			# Stance / focus / form_energy: dodge consumes from a separate stamina pool if available
			if owner_player.stamina_value >= cost:
				owner_player.stamina_value -= cost
			else:
				paid = false
	if not paid:
		return

	_is_dodging = true
	_dodge_iframe_until = now + dodge_iframes
	_dodge_cd_until = now + dodge_cooldown

	# Direction resolution
	var dir: Vector3 = owner_player.input_dir
	if dir.length() < 0.1:
		# No input: dodge backward (away from current heading)
		var fwd: Vector3 = -owner_player.mesh.global_transform.basis.z if owner_player.mesh else Vector3.FORWARD
		dir = -fwd
	dir = dir.normalized()
	owner_player.velocity.x = dir.x * (dodge_distance / dodge_duration)
	owner_player.velocity.z = dir.z * (dodge_distance / dodge_duration)
	owner_player.locked = true
	dodge_started.emit(dir)
	get_tree().create_timer(dodge_duration).timeout.connect(_end_dodge)

func _end_dodge() -> void:
	_is_dodging = false
	if owner_player:
		owner_player.locked = false
	dodge_ended.emit()

func try_parry() -> void:
	var now := Time.get_ticks_msec() / 1000.0
	if now < _parry_cd_until:
		return
	_parry_open_until = now + parry_window
	_parry_cd_until = now + parry_cooldown
	parry_window_open.emit()
	get_tree().create_timer(parry_window).timeout.connect(func():
		parry_window_closed.emit())

func _in_parry_window() -> bool:
	return Time.get_ticks_msec() / 1000.0 < _parry_open_until

func is_iframing() -> bool:
	return Time.get_ticks_msec() / 1000.0 < _dodge_iframe_until

func is_blocking() -> bool:
	return _is_blocking

# Called by Hurtbox/damage handler. Returns dict {damage_mult, posture_mult, was_perfect_parry, was_iframe}
func intercept_incoming(amount: float, attacker: Node) -> Dictionary:
	if is_iframing():
		return {"damage_mult": 0.0, "posture_mult": 0.0, "was_perfect_parry": false, "was_iframe": true}
	if _in_parry_window():
		# perfect parry: no damage, push posture damage onto attacker
		if attacker and attacker.has_node("Posture"):
			attacker.get_node("Posture").add_posture_damage(perfect_parry_posture_damage, false, false, 1.0)
		if owner_player and owner_player.has_method("on_perfect_parry"):
			owner_player.on_perfect_parry()
		perfect_parry_landed.emit(attacker)
		return {"damage_mult": 0.0, "posture_mult": 0.0, "was_perfect_parry": true, "was_iframe": false}
	if _is_blocking:
		return {"damage_mult": block_damage_reduction, "posture_mult": block_posture_dampening, "was_perfect_parry": false, "was_iframe": false}
	return {"damage_mult": 1.0, "posture_mult": 1.0, "was_perfect_parry": false, "was_iframe": false}
