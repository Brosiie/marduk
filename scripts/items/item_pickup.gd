extends Area3D
class_name ItemPickup

# A 3D representation of a dropped item the player can walk over (auto-loot)
# or press F (manual). Spawned by EnemyBase._die() and chest containers.
#
# Visual: a small floating box with the item's rarity color glow, slowly
# bobbing and rotating. The mesh comes from `item.mesh_scene` if provided,
# otherwise we build a placeholder cube tinted to rarity.

const PICKUP_RADIUS: float = 1.4
const BOB_AMPLITUDE: float = 0.15
const BOB_SPEED: float = 2.5
const SPIN_SPEED: float = 1.2
const POP_DURATION: float = 0.4
const POP_HEIGHT: float = 0.7
const AUTO_LOOT_DEFAULT: bool = false

@export var item: Item
@export var quantity: int = 1
@export var auto_loot_after: float = 30.0  # if not picked up by then, auto-cleanup

var _t0: float = 0.0
var _bob_offset: float = 0.0
var _initial_y: float = 0.0
var _can_pickup: bool = false  # blocks pickup while popping out

signal looted(item: Item, quantity: int)

func _ready() -> void:
	add_to_group("item_pickup")
	collision_layer = 16   # custom layer for items
	collision_mask = 2     # players-only layer
	# Visual mesh
	var visual: Node3D = null
	if item and item.mesh_scene:
		visual = item.mesh_scene.instantiate()
	else:
		visual = _build_placeholder_mesh()
	visual.name = "Visual"
	add_child(visual)
	visual.scale = Vector3.ONE * 0.5
	# Trigger area
	var shape := CollisionShape3D.new()
	var sphere := SphereShape3D.new()
	sphere.radius = PICKUP_RADIUS
	shape.shape = sphere
	add_child(shape)
	# Glow per rarity (cheap OmniLight)
	if item:
		var lit := OmniLight3D.new()
		lit.light_color = _rarity_glow(item.rarity)
		lit.light_energy = 0.6
		lit.omni_range = 3.0
		add_child(lit)
		lit.position = Vector3(0, 0.4, 0)
	# Pickup hookups
	body_entered.connect(_on_body_entered)
	_initial_y = position.y
	_bob_offset = randf() * TAU
	# Pop animation: lock pickup briefly so it doesn't latch immediately
	_can_pickup = false
	var tween := create_tween()
	tween.tween_property(self, "position:y", _initial_y + POP_HEIGHT, POP_DURATION).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	tween.tween_callback(func(): _can_pickup = true)
	# Cleanup timer
	if auto_loot_after > 0.0:
		var t := Timer.new()
		t.one_shot = true
		t.wait_time = auto_loot_after
		t.timeout.connect(queue_free)
		add_child(t)
		t.start()

func _process(delta: float) -> void:
	_t0 += delta
	rotation.y = _t0 * SPIN_SPEED
	# Bob
	if _can_pickup:
		position.y = _initial_y + POP_HEIGHT * 0.5 + sin((_t0 + _bob_offset) * BOB_SPEED) * BOB_AMPLITUDE

func _on_body_entered(body: Node3D) -> void:
	if not _can_pickup or item == null:
		return
	if not body.is_in_group("player"):
		return
	# Auto-loot if enabled OR honor F key (handled in player.gd input)
	var settings = get_node_or_null("/root/GameSettings")
	var auto: bool = AUTO_LOOT_DEFAULT
	if settings and settings.has_method("get_auto_loot"):
		auto = settings.get_auto_loot()
	if auto:
		_pickup(body)

# Public: triggered by player.gd when F is pressed and we're inside the radius.
func try_pickup(player: Node) -> bool:
	if not _can_pickup or item == null:
		return false
	if global_position.distance_to(player.global_position) > PICKUP_RADIUS * 1.4:
		return false
	_pickup(player)
	return true

func _pickup(player: Node) -> void:
	if not is_instance_valid(player):
		return
	if player.has_method("collect_item"):
		player.collect_item(item, quantity)
	elif player.has("inventory") and player.inventory and player.inventory.has_method("add_item"):
		player.inventory.add_item(item, quantity)
	looted.emit(item, quantity)
	queue_free()

func _build_placeholder_mesh() -> Node3D:
	var mi := MeshInstance3D.new()
	var box := BoxMesh.new()
	box.size = Vector3(0.6, 0.6, 0.6)
	mi.mesh = box
	var mat := StandardMaterial3D.new()
	mat.albedo_color = _rarity_glow(item.rarity if item else 2) if item else Color(0.6, 0.6, 0.6)
	mat.emission_enabled = true
	mat.emission = mat.albedo_color
	mat.emission_energy_multiplier = 0.6
	mi.material_override = mat
	return mi

func _rarity_glow(rarity: int) -> Color:
	match rarity:
		0: return Color(0.40, 0.40, 0.40)  # JUNK
		1: return Color(0.85, 0.85, 0.85)  # BASIC
		2: return Color(0.55, 0.85, 0.45)  # COMMON
		3: return Color(0.40, 0.50, 0.95)  # RARE
		4: return Color(0.75, 0.30, 0.95)  # VERY_RARE
		5: return Color(1.00, 0.65, 0.10)  # LEGENDARY
		6: return Color(1.00, 0.95, 0.55)  # HEAVEN
	return Color.WHITE
