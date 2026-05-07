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
		# Rarity sparkle column: rising particle pillar tinted to rarity
		# color so the player can spot drops at distance. Higher rarities
		# get bigger/brighter columns. Common items get nothing, just the
		# OmniLight; epics+ get unmistakable beacons.
		_spawn_rarity_column(item.rarity)
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
	# First-pickup achievement
	var ar = player.get_node_or_null("/root/AchievementRegistry")
	if ar and ar.has_method("unlock"):
		ar.unlock(&"a_first_pickup")
	if player.has_method("collect_item"):
		player.collect_item(item, quantity)
	elif "inventory" in player and player.inventory and player.inventory.has_method("add_item"):
		player.inventory.add_item(item, quantity)
	# Pickup SFX, pitch-shift by rarity so rares sound shinier
	var ab = player.get_node_or_null("/root/AudioBus")
	if ab and ab.has_method("play_cue") and item:
		var pitch: float = 1.0 + 0.12 * float(int(item.rarity))
		ab.play_cue(&"pickup", global_position, -4.0, pitch)
	looted.emit(item, quantity)
	queue_free()

func _build_placeholder_mesh() -> Node3D:
	# Try to load a KayKit weapon/item mesh that matches the item's
	# weapon_type or slot. Falls back to a tinted box if no match.
	if item:
		var mesh_path: String = _path_for_item(item)
		if mesh_path != "" and ResourceLoader.exists(mesh_path):
			var packed: PackedScene = load(mesh_path)
			if packed:
				var inst: Node3D = packed.instantiate()
				# Strip any baked-in colliders so the mesh doesn't block
				# the player from walking near the drop
				_strip_colliders(inst)
				# Apply rarity glow as emission tint via a subtle outline
				# StandardMaterial3D override on first surface
				_apply_rarity_glow(inst)
				return inst
	# Fallback box tinted by rarity
	var mi := MeshInstance3D.new()
	var box := BoxMesh.new()
	box.size = Vector3(0.4, 0.4, 0.4)
	mi.mesh = box
	var mat := StandardMaterial3D.new()
	mat.albedo_color = _rarity_glow(item.rarity if item else 2) if item else Color(0.6, 0.6, 0.6)
	mat.emission_enabled = true
	mat.emission = mat.albedo_color
	mat.emission_energy_multiplier = 0.8
	mi.material_override = mat
	return mi

# Map an Item to its KayKit prop mesh path.
const KAYKIT_PROPS := "res://assets/characters/kaykit/Assets/gltf/"

func _path_for_item(it: Item) -> String:
	# Try by weapon_type first
	match it.weapon_type:
		1:  return KAYKIT_PROPS + "sword_1handed.gltf"      # SWORD
		2:  return KAYKIT_PROPS + "sword_2handed.gltf"      # GREATSWORD
		3:  return KAYKIT_PROPS + "axe_1handed.gltf"        # AXE
		4:  return KAYKIT_PROPS + "axe_2handed.gltf"        # GREATAXE
		7:  return KAYKIT_PROPS + "staff.gltf"              # STAFF
		8:  return KAYKIT_PROPS + "wand.gltf"               # WAND
		9:  return KAYKIT_PROPS + "sword_1handed.gltf"      # KATANA -> reuse sword
		10: return KAYKIT_PROPS + "sword_2handed.gltf"      # NODACHI
		11: return KAYKIT_PROPS + "dagger.gltf"             # DAGGER
		12: return KAYKIT_PROPS + "crossbow_2handed.gltf"   # BOW -> crossbow stand-in
		13: return KAYKIT_PROPS + "crossbow_1handed.gltf"   # CROSSBOW
	# Off-hands
	if it.slot == Item.Slot.WEAPON_OFFHAND:
		return KAYKIT_PROPS + "shield_round.gltf"
	# Books for caster off-hands / quest items
	if it.slot == Item.Slot.CHARM:
		return KAYKIT_PROPS + "spellbook_closed.gltf"
	# Consumables (potions): use mug as a stand-in
	if it.stack_size > 1:
		return KAYKIT_PROPS + "mug_full.gltf"
	return ""

# Walk the prop tree and disable any colliders the kaykit mesh ships
# with. ItemPickup has its own trigger Area3D for player contact.
func _strip_colliders(node: Node) -> void:
	for c in node.get_children():
		if c is CollisionShape3D:
			c.disabled = true
		elif c is StaticBody3D:
			(c as StaticBody3D).collision_layer = 0
			(c as StaticBody3D).collision_mask = 0
		_strip_colliders(c)

# Apply a colored emission tint to every MeshInstance3D's first surface
# to signal the item's rarity at a glance.
func _apply_rarity_glow(root: Node) -> void:
	if item == null:
		return
	var glow_color: Color = _rarity_glow(item.rarity)
	var meshes: Array[MeshInstance3D] = []
	_collect_meshes(root, meshes)
	for mi in meshes:
		if mi.mesh == null:
			continue
		# Take the existing material's albedo if any; layer emission on top
		var existing := mi.get_active_material(0)
		var mat := StandardMaterial3D.new()
		mat.albedo_color = glow_color.lerp(Color.WHITE, 0.6)  # mostly white, rarity-tinted
		if existing is BaseMaterial3D:
			mat.albedo_color = (existing as BaseMaterial3D).albedo_color
		mat.emission_enabled = true
		mat.emission = glow_color
		mat.emission_energy_multiplier = 0.4 + 0.15 * float(int(item.rarity))
		mat.metallic = 0.4
		mat.roughness = 0.5
		mi.set_surface_override_material(0, mat)

func _collect_meshes(node: Node, out: Array[MeshInstance3D]) -> void:
	if node is MeshInstance3D:
		out.append(node)
	for c in node.get_children():
		_collect_meshes(c, out)

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

# Particle pillar rising from the drop. Higher rarity = taller, brighter
# column so the player spots loot from across the courtyard. Common
# tier and below skip the column (just the OmniLight halo). Epics+
# light up like a beacon.
func _spawn_rarity_column(rarity: int) -> void:
	if rarity < 3:
		return  # Common and below: no column
	var color := _rarity_glow(rarity)
	var p := GPUParticles3D.new()
	p.name = "RarityColumn"
	# Higher rarity = bigger column. Heaven gets a 6m pillar.
	var height: float = lerp(2.5, 6.5, float(rarity - 3) / 4.0)
	var amount: int = int(lerp(40.0, 140.0, float(rarity - 3) / 4.0))
	p.amount = amount
	p.lifetime = 2.0
	p.preprocess = 1.0
	p.visibility_aabb = AABB(Vector3(-1, 0, -1), Vector3(2, height + 1, 2))
	var mat := ParticleProcessMaterial.new()
	mat.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_SPHERE
	mat.emission_sphere_radius = 0.25
	mat.direction = Vector3.UP
	mat.spread = 8.0
	mat.initial_velocity_min = height * 0.8
	mat.initial_velocity_max = height * 1.0
	mat.gravity = Vector3.ZERO
	mat.scale_min = 0.06
	mat.scale_max = 0.14
	mat.color = color
	# Slight horizontal swirl gives the column a magical curl
	mat.tangential_accel_min = -0.5
	mat.tangential_accel_max = 0.5
	p.process_material = mat
	var quad := QuadMesh.new()
	quad.size = Vector2(0.12, 0.12)
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
	p.draw_pass_1 = quad
	add_child(p)
