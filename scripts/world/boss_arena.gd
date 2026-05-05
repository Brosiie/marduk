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
	_release_gates()
	# Hide the boss bar via HUD
	for hud in get_tree().get_nodes_in_group("hud"):
		if hud.has_method("unbind_boss"):
			hud.unbind_boss()
			break

func _on_boss_died() -> void:
	_release_gates()
	for hud in get_tree().get_nodes_in_group("hud"):
		if hud.has_method("unbind_boss"):
			hud.unbind_boss()
			break

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
