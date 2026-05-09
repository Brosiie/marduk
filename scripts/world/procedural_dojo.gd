extends Node3D
class_name ProceduralDojo

# A procedural Japanese dojo (bujutsu-style training hall). Built from
# primitive meshes so it can land in any zone without a .glb pipeline.
# Composition:
#   1. Raised wooden FLOOR platform (boss-fight arena)
#   2. Four corner POSTS plus two flanking-the-entrance posts
#   3. Outer WALLS along three sides (back + left + right) with gold
#      framing strips. Front wall has a wide entrance gap so the player
#      walks straight in from the path
#   4. Hipped ROOF — a 2-tier angled tile slab construction. Lower tier
#      is wide and flat (gable veranda); upper tier is the iconic
#      curved-eaves Japanese roof
#   5. Two PAPER LANTERNS hanging from the front roof eaves
#   6. Hanging tatami-style mats on the side walls (visual decoration)
#   7. Decorative columns at the rear marking the throne position
#
# Public params let the zone composer place + size the dojo:
#   dojo_size  -- Vector2 (width, depth) of the floor in meters
#   floor_y    -- vertical offset for the platform (raised above ground)
#   entrance_width -- width of the front-wall gap (default 4m)
#
# Collision: every wall + post + roof slab gets a StaticBody3D + Box
# collision so the player can't clip through walls. The floor uses a
# trimesh collision via the existing CSG / static-mesh pattern that
# the rest of the zone uses.

@export var dojo_size: Vector2 = Vector2(14.0, 16.0)
@export var floor_y: float = 0.45
@export var entrance_width: float = 4.0
@export var post_radius: float = 0.18
@export var wall_thickness: float = 0.20
@export var roof_pitch_deg: float = 18.0

# Material colors — warm cedar palette
const COL_FLOOR: Color = Color(0.55, 0.36, 0.20, 1.0)
const COL_FLOOR_TRIM: Color = Color(0.40, 0.24, 0.14, 1.0)
const COL_WALL: Color = Color(0.92, 0.85, 0.72, 1.0)  # off-white shoji
const COL_POST: Color = Color(0.32, 0.20, 0.14, 1.0)  # dark cedar
const COL_BEAM: Color = Color(0.42, 0.26, 0.16, 1.0)  # mid cedar
const COL_ROOF: Color = Color(0.18, 0.12, 0.10, 1.0)  # blackened tile
const COL_GOLD: Color = Color(0.78, 0.62, 0.28, 1.0)
const COL_LANTERN: Color = Color(1.00, 0.68, 0.30, 1.0)

func _ready() -> void:
	_build()

func _build() -> void:
	var w: float = dojo_size.x
	var d: float = dojo_size.y
	var fy: float = floor_y
	# 1. Floor — a raised wooden slab. Two layers: planks on top, dark
	# trim ring around the edge.
	var floor_node := _make_box(Vector3(w, 0.10, d), COL_FLOOR, true)
	floor_node.name = "Floor"
	floor_node.position = Vector3(0, fy, 0)
	add_child(floor_node)
	# Trim — slightly larger flat slab below the floor for the edge
	# overhang look
	var trim := _make_box(Vector3(w + 0.6, 0.06, d + 0.6), COL_FLOOR_TRIM, false)
	trim.position = Vector3(0, fy - 0.06, 0)
	add_child(trim)
	# Three step risers in front of the entrance — stairs from ground
	# up to the dojo floor. Player walks UP into the building.
	for i in range(3):
		var step_y: float = fy * float(i + 1) / 3.0 - 0.05
		var step_z: float = d * 0.5 + 0.4 + float(i) * 0.4
		var step := _make_box(Vector3(entrance_width + 1.5, 0.10, 0.45), COL_FLOOR_TRIM, true)
		step.position = Vector3(0, step_y, step_z)
		add_child(step)

	# 2. Posts — six corner+entrance posts, each a tapered cylinder
	# from floor to roof underside (height 3.6m).
	var post_height: float = 3.6
	var post_y: float = fy + post_height * 0.5
	var hw: float = w * 0.5  # half-width
	var hd: float = d * 0.5  # half-depth
	# Corners
	for sx in [-1.0, 1.0]:
		for sz in [-1.0, 1.0]:
			_spawn_post(Vector3(hw * sx, post_y, hd * sz), post_height)
	# Entrance flank posts (front side, flanking the gap)
	var ex: float = entrance_width * 0.5 + 0.3
	_spawn_post(Vector3(-ex, post_y, hd), post_height)
	_spawn_post(Vector3(ex, post_y, hd), post_height)

	# 3. Walls — back wall full-width, left/right walls full-depth,
	# front wall split into two pieces flanking the entrance gap.
	var wall_height: float = 2.6
	var wall_y: float = fy + wall_height * 0.5 + 0.1
	# Back wall (z = -hd)
	_spawn_wall(Vector3(0, wall_y, -hd), Vector3(w, wall_height, wall_thickness))
	# Left wall (x = -hw)
	_spawn_wall(Vector3(-hw, wall_y, 0), Vector3(wall_thickness, wall_height, d))
	# Right wall (x = +hw)
	_spawn_wall(Vector3(hw, wall_y, 0), Vector3(wall_thickness, wall_height, d))
	# Front wall — two segments flanking the entrance
	var front_seg_w: float = (w - entrance_width) * 0.5
	_spawn_wall(Vector3(-(entrance_width * 0.5 + front_seg_w * 0.5), wall_y, hd),
		Vector3(front_seg_w, wall_height, wall_thickness))
	_spawn_wall(Vector3(entrance_width * 0.5 + front_seg_w * 0.5, wall_y, hd),
		Vector3(front_seg_w, wall_height, wall_thickness))
	# Lintel above the entrance (closes the top of the gap)
	var lintel_h: float = 0.6
	_spawn_wall(Vector3(0, fy + wall_height + 0.1 - lintel_h * 0.5, hd),
		Vector3(entrance_width + 0.6, lintel_h, wall_thickness))

	# Top beam ring around the perimeter for structural read
	var beam_y: float = fy + wall_height + 0.45
	_spawn_beam(Vector3(0, beam_y, hd), Vector3(w + 0.4, 0.18, 0.18))
	_spawn_beam(Vector3(0, beam_y, -hd), Vector3(w + 0.4, 0.18, 0.18))
	_spawn_beam(Vector3(hw, beam_y, 0), Vector3(0.18, 0.18, d + 0.4))
	_spawn_beam(Vector3(-hw, beam_y, 0), Vector3(0.18, 0.18, d + 0.4))

	# 4. Roof — two-tier hipped roof. Lower tier (veranda eaves) is
	# wide+flat; upper tier is the iconic angled-up hipped roof. Built
	# from 4 angled BoxMesh slabs forming the inverted-pyramid roof.
	var eave_overhang: float = 1.6
	var lower_y: float = beam_y + 0.10
	# Lower tier — a flat slab wider than the building footprint, gold-
	# trimmed gable feel
	var lower_roof := _make_box(Vector3(w + eave_overhang * 2.0, 0.20, d + eave_overhang * 2.0), COL_ROOF, false)
	lower_roof.position = Vector3(0, lower_y, 0)
	add_child(lower_roof)
	# Gold filigree strip around the lower roof edge
	var gold_strip := _make_box(Vector3(w + eave_overhang * 2.0 + 0.2, 0.04, d + eave_overhang * 2.0 + 0.2), COL_GOLD, false)
	gold_strip.position = Vector3(0, lower_y - 0.10, 0)
	add_child(gold_strip)
	# Upper tier — 4 angled slabs forming a hipped roof. Each slab is
	# tilted up toward the center via Z rotation, producing the signature
	# Japanese roof silhouette.
	var upper_y: float = lower_y + 0.7
	var pitch: float = deg_to_rad(roof_pitch_deg)
	var upper_w: float = w + 0.6
	var upper_d: float = d + 0.6
	# Front slab (tilts up toward back)
	_spawn_roof_slab(
		Vector3(0, upper_y, hd * 0.5),
		Vector3(upper_w, 0.18, upper_d * 0.7),
		Vector3.RIGHT, -pitch
	)
	# Back slab (tilts up toward front)
	_spawn_roof_slab(
		Vector3(0, upper_y, -hd * 0.5),
		Vector3(upper_w, 0.18, upper_d * 0.7),
		Vector3.RIGHT, pitch
	)
	# Left slab
	_spawn_roof_slab(
		Vector3(-hw * 0.5, upper_y + 0.15, 0),
		Vector3(upper_w * 0.7, 0.18, upper_d),
		Vector3.FORWARD, pitch
	)
	# Right slab
	_spawn_roof_slab(
		Vector3(hw * 0.5, upper_y + 0.15, 0),
		Vector3(upper_w * 0.7, 0.18, upper_d),
		Vector3.FORWARD, -pitch
	)
	# Roof crest — a thin gold beam along the ridge (top of hipped roof)
	var crest := _make_box(Vector3(w * 0.35, 0.10, 0.20), COL_GOLD, false)
	crest.position = Vector3(0, upper_y + 0.65, 0)
	add_child(crest)

	# 5. Two paper lanterns hanging from the front roof eaves
	_spawn_lantern(Vector3(-ex - 0.6, lower_y - 0.4, hd + eave_overhang * 0.5))
	_spawn_lantern(Vector3(ex + 0.6, lower_y - 0.4, hd + eave_overhang * 0.5))

	# 6. Two decorative throne pillars at the rear marking the boss spot
	for sx in [-1.0, 1.0]:
		var pillar := MeshInstance3D.new()
		var pm := CylinderMesh.new()
		pm.bottom_radius = 0.30
		pm.top_radius = 0.28
		pm.height = 2.4
		pillar.mesh = pm
		var pmat := StandardMaterial3D.new()
		pmat.albedo_color = COL_POST
		pmat.roughness = 0.85
		pillar.material_override = pmat
		pillar.position = Vector3(sx * (hw - 1.5), fy + 1.2, -hd + 1.5)
		add_child(pillar)
		# Gold cap at top
		var cap := MeshInstance3D.new()
		var cm := BoxMesh.new()
		cm.size = Vector3(0.5, 0.10, 0.5)
		cap.mesh = cm
		var cap_mat := StandardMaterial3D.new()
		cap_mat.albedo_color = COL_GOLD
		cap_mat.metallic = 0.7
		cap_mat.roughness = 0.30
		cap.material_override = cap_mat
		cap.position = pillar.position + Vector3(0, 1.25, 0)
		add_child(cap)

# ----- Construction helpers -----

# Make a BoxMesh, optionally with a StaticBody3D + collision so player
# can't clip through it.
func _make_box(size: Vector3, color: Color, with_collision: bool) -> Node3D:
	var node: Node3D
	if with_collision:
		node = StaticBody3D.new()
	else:
		node = Node3D.new()
	var mi := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = size
	mi.mesh = bm
	var mat := StandardMaterial3D.new()
	mat.albedo_color = color
	mat.roughness = 0.85
	mat.metallic = 0.05
	mi.material_override = mat
	node.add_child(mi)
	if with_collision:
		var cs := CollisionShape3D.new()
		var bs := BoxShape3D.new()
		bs.size = size
		cs.shape = bs
		node.add_child(cs)
	return node

# Tapered post (corner column). StaticBody so player can't clip.
func _spawn_post(pos: Vector3, height: float) -> void:
	var post := StaticBody3D.new()
	var mi := MeshInstance3D.new()
	var cm := CylinderMesh.new()
	cm.bottom_radius = post_radius * 1.2
	cm.top_radius = post_radius
	cm.height = height
	mi.mesh = cm
	var pmat := StandardMaterial3D.new()
	pmat.albedo_color = COL_POST
	pmat.roughness = 0.85
	mi.material_override = pmat
	post.add_child(mi)
	var cs := CollisionShape3D.new()
	var caps := CapsuleShape3D.new()
	caps.radius = post_radius * 1.3
	caps.height = height
	cs.shape = caps
	post.add_child(cs)
	post.position = pos
	add_child(post)

# Wall with collision (StaticBody + BoxShape)
func _spawn_wall(pos: Vector3, size: Vector3) -> void:
	var wall := _make_box(size, COL_WALL, true)
	wall.position = pos
	add_child(wall)
	# Gold horizontal trim strip across the wall — visible on inside +
	# outside. Slightly inset depth so it shows even when the wall is
	# thick.
	var trim_h: float = 0.05
	var trim := _make_box(
		Vector3(size.x * 1.005, trim_h, size.z * 1.05),
		COL_GOLD, false)
	trim.position = pos + Vector3(0, size.y * 0.25, 0)
	add_child(trim)
	var trim2 := _make_box(
		Vector3(size.x * 1.005, trim_h, size.z * 1.05),
		COL_GOLD, false)
	trim2.position = pos + Vector3(0, -size.y * 0.25, 0)
	add_child(trim2)

# Decorative beam (no collision needed; just visual)
func _spawn_beam(pos: Vector3, size: Vector3) -> void:
	var beam := _make_box(size, COL_BEAM, false)
	beam.position = pos
	add_child(beam)

# Roof slab — angled BoxMesh tilted by `angle_rad` around `axis`.
# Static body so the roof reads as solid (player can't fly through it).
func _spawn_roof_slab(pos: Vector3, size: Vector3, axis: Vector3, angle_rad: float) -> void:
	var slab := _make_box(size, COL_ROOF, true)
	slab.position = pos
	slab.transform.basis = slab.transform.basis.rotated(axis.normalized(), angle_rad)
	add_child(slab)

# Paper lantern: bright orange-gold cylinder with an OmniLight inside.
# Hangs from a thin black rope (cylinder) above.
func _spawn_lantern(pos: Vector3) -> void:
	# Rope (thin dark cylinder)
	var rope := MeshInstance3D.new()
	var rm := CylinderMesh.new()
	rm.top_radius = 0.018
	rm.bottom_radius = 0.018
	rm.height = 0.40
	rope.mesh = rm
	var rmat := StandardMaterial3D.new()
	rmat.albedo_color = Color(0.10, 0.07, 0.06)
	rope.material_override = rmat
	rope.position = pos + Vector3(0, 0.20, 0)
	add_child(rope)
	# Lantern body — short fat cylinder, glowing
	var lant := MeshInstance3D.new()
	var lm := CylinderMesh.new()
	lm.top_radius = 0.20
	lm.bottom_radius = 0.20
	lm.height = 0.40
	lant.mesh = lm
	var lmat := StandardMaterial3D.new()
	lmat.albedo_color = COL_LANTERN
	lmat.emission_enabled = true
	lmat.emission = Color(1.0, 0.55, 0.20)
	lmat.emission_energy_multiplier = 1.6
	lant.material_override = lmat
	lant.position = pos
	add_child(lant)
	# Top + bottom caps (gold)
	for cy in [0.20, -0.20]:
		var cap := MeshInstance3D.new()
		var cm := CylinderMesh.new()
		cm.top_radius = 0.22
		cm.bottom_radius = 0.22
		cm.height = 0.04
		cap.mesh = cm
		var cmat := StandardMaterial3D.new()
		cmat.albedo_color = COL_POST
		cap.material_override = cmat
		cap.position = pos + Vector3(0, cy, 0)
		add_child(cap)
	# OmniLight so the lantern actually casts light
	var light := OmniLight3D.new()
	light.light_color = Color(1.0, 0.62, 0.28)
	light.light_energy = 1.5
	light.omni_range = 6.0
	light.position = pos
	add_child(light)
