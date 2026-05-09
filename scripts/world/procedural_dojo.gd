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
#   4. Hipped ROOF, a 2-tier angled tile slab construction. Lower tier
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

# Material colors, warm cedar palette
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
	# 1. Floor, a raised wooden slab. Two layers: planks on top, dark
	# trim ring around the edge. Tagged with `surface_type` so the
	# player's footstep raycast can pick the wooden step audio cue.
	var floor_node := _make_box(Vector3(w, 0.10, d), COL_FLOOR, true)
	floor_node.name = "DojoFloor"
	floor_node.set_meta("surface_type", "wood")
	floor_node.position = Vector3(0, fy, 0)
	add_child(floor_node)
	# Trim, slightly larger flat slab below the floor for the edge
	# overhang look
	var trim := _make_box(Vector3(w + 0.6, 0.06, d + 0.6), COL_FLOOR_TRIM, false)
	trim.position = Vector3(0, fy - 0.06, 0)
	add_child(trim)
	# Three step risers in front of the entrance, stairs from ground
	# up to the dojo floor. Player walks UP into the building.
	for i in range(3):
		var step_y: float = fy * float(i + 1) / 3.0 - 0.05
		var step_z: float = d * 0.5 + 0.4 + float(i) * 0.4
		var step := _make_box(Vector3(entrance_width + 1.5, 0.10, 0.45), COL_FLOOR_TRIM, true)
		step.position = Vector3(0, step_y, step_z)
		add_child(step)

	# 2. Posts, six corner+entrance posts, each a tapered cylinder
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

	# 3. Walls, back wall full-width, left/right walls full-depth,
	# front wall split into two pieces flanking the entrance gap.
	var wall_height: float = 2.6
	var wall_y: float = fy + wall_height * 0.5 + 0.1
	# Back wall (z = -hd)
	_spawn_wall(Vector3(0, wall_y, -hd), Vector3(w, wall_height, wall_thickness))
	# Left wall (x = -hw)
	_spawn_wall(Vector3(-hw, wall_y, 0), Vector3(wall_thickness, wall_height, d))
	# Right wall (x = +hw)
	_spawn_wall(Vector3(hw, wall_y, 0), Vector3(wall_thickness, wall_height, d))
	# Front wall, two segments flanking the entrance
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

	# 4. Roof, two-tier hipped roof. Lower tier (veranda eaves) is
	# wide+flat; upper tier is the iconic angled-up hipped roof. Built
	# from 4 angled BoxMesh slabs forming the inverted-pyramid roof.
	var eave_overhang: float = 1.6
	var lower_y: float = beam_y + 0.10
	# Lower tier, a flat slab wider than the building footprint, gold-
	# trimmed gable feel
	var lower_roof := _make_box(Vector3(w + eave_overhang * 2.0, 0.20, d + eave_overhang * 2.0), COL_ROOF, false)
	lower_roof.position = Vector3(0, lower_y, 0)
	add_child(lower_roof)
	# Gold filigree strip around the lower roof edge
	var gold_strip := _make_box(Vector3(w + eave_overhang * 2.0 + 0.2, 0.04, d + eave_overhang * 2.0 + 0.2), COL_GOLD, false)
	gold_strip.position = Vector3(0, lower_y - 0.10, 0)
	add_child(gold_strip)
	# Upper tier, 4 angled slabs forming a hipped roof. Each slab is
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
	# Roof crest, a thin gold beam along the ridge (top of hipped roof)
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

	# 7. Interior dressing, Bond's "we go inside to fight the boss"
	# means the interior should READ as a dojo, not an empty crate.
	# Add tatami mat pattern + wall scrolls + weapon rack + throne.
	_dress_interior(w, d, fy)

# Layered dojo interior: tatami floor pattern, scroll banners, weapon
# rack, low throne dais behind the boss spawn. Each is a small mesh
# composition built relative to the dojo dimensions so resizing the
# dojo automatically rescales the dressing.
func _dress_interior(w: float, d: float, fy: float) -> void:
	var hw: float = w * 0.5
	var hd: float = d * 0.5
	# 7a. Tatami mats, 3x4 grid of large rectangular mats with their
	# own dark border. Tatami are traditionally laid in alternating
	# orientations, but the simple grid reads correctly at gameplay
	# distance and doesn't require complex layout logic.
	var mat_cols: int = 4
	var mat_rows: int = 5
	var mat_w: float = (w - 2.0) / float(mat_cols)
	var mat_d: float = (d - 2.0) / float(mat_rows)
	var mat_y: float = fy + 0.06  # 1mm above floor planks so it reads
	for r in range(mat_rows):
		for c in range(mat_cols):
			# Skip the front 2 rows so the entrance step area stays clean
			if r >= mat_rows - 1:
				continue
			var cx: float = -hw + 1.0 + (float(c) + 0.5) * mat_w
			var cz: float = -hd + 1.0 + (float(r) + 0.5) * mat_d
			# Body
			var tatami := MeshInstance3D.new()
			tatami.name = "Tatami_%d_%d" % [r, c]
			var tm := BoxMesh.new()
			tm.size = Vector3(mat_w * 0.95, 0.02, mat_d * 0.95)
			tatami.mesh = tm
			var tmat := StandardMaterial3D.new()
			# Two-tone alternation for the woven-mat look
			if (r + c) % 2 == 0:
				tmat.albedo_color = Color(0.78, 0.62, 0.36, 1.0)
			else:
				tmat.albedo_color = Color(0.72, 0.55, 0.30, 1.0)
			tmat.roughness = 0.92
			tatami.material_override = tmat
			tatami.position = Vector3(cx, mat_y, cz)
			add_child(tatami)
			# Dark border strip, a slightly larger box just under
			# the mat that shows around the edges
			var border := MeshInstance3D.new()
			var bm := BoxMesh.new()
			bm.size = Vector3(mat_w * 0.99, 0.018, mat_d * 0.99)
			border.mesh = bm
			var bmat := StandardMaterial3D.new()
			bmat.albedo_color = Color(0.22, 0.14, 0.08, 1.0)
			border.material_override = bmat
			border.position = Vector3(cx, mat_y - 0.005, cz)
			add_child(border)

	# 7b. Wall scrolls, 4 hanging vertical banners on the back wall
	# and one on each side wall. Cream paper with a red kanji-like
	# stripe down the middle (we don't have a real kanji texture so
	# the stripe is decorative only).
	# Back wall: 4 scrolls at z = -hd + small offset
	for i in range(4):
		var scroll_x: float = -hw + 1.5 + (float(i) + 0.5) * (w - 3.0) / 4.0
		_spawn_scroll(Vector3(scroll_x, fy + 1.8, -hd + 0.30))
	# Side walls: 2 scrolls per side
	for i in range(2):
		var scroll_z: float = -hd * 0.4 + float(i) * 0.8 * hd * 0.5
		_spawn_scroll(Vector3(-hw + 0.30, fy + 1.8, scroll_z), 90.0)
		_spawn_scroll(Vector3(hw - 0.30, fy + 1.8, scroll_z), -90.0)

	# 7c. Weapon rack, left wall, mid-height. 3 katanas resting on
	# horizontal pegs.
	_spawn_weapon_rack(Vector3(-hw + 0.45, fy + 0.0, hd * 0.35), 90.0)

	# 7d. Throne dais, a low wide raised platform at the rear with
	# a simple cushion-style block. Marks the boss's anchor visually
	# so the player reads "this is where the master sits".
	var dais := _make_box(Vector3(4.0, 0.20, 1.6), Color(0.32, 0.20, 0.14, 1.0), false)
	dais.position = Vector3(0, fy + 0.10, -hd + 1.5)
	add_child(dais)
	# Gold trim on the dais
	var dais_trim := _make_box(Vector3(4.2, 0.04, 1.8), COL_GOLD, false)
	dais_trim.position = Vector3(0, fy + 0.04, -hd + 1.5)
	add_child(dais_trim)
	# Cushion, dark red velvet block
	var cushion := _make_box(Vector3(2.0, 0.18, 1.0), Color(0.55, 0.12, 0.10, 1.0), false)
	cushion.position = Vector3(0, fy + 0.30, -hd + 1.5)
	add_child(cushion)
	# Small gold finials at dais corners
	for sx in [-1.0, 1.0]:
		for sz in [-1.0, 1.0]:
			var fin := MeshInstance3D.new()
			var fm := SphereMesh.new()
			fm.radius = 0.08
			fm.height = 0.16
			fin.mesh = fm
			var fmat := StandardMaterial3D.new()
			fmat.albedo_color = COL_GOLD
			fmat.metallic = 0.85
			fmat.roughness = 0.20
			fin.material_override = fmat
			fin.position = Vector3(sx * 1.95, fy + 0.30, -hd + 1.5 + sz * 0.75)
			add_child(fin)

	# 7e. Floor lanterns at the corners of the boss arena interior
	# (smaller than the hanging eave lanterns). Each casts warm light
	# so the interior has proper illumination instead of dark gloom.
	for sx in [-1.0, 1.0]:
		for sz in [-1.0, 1.0]:
			var fx: float = sx * (hw - 1.0)
			var fz: float = sz * (hd - 1.0)
			# Skip the front-right and front-left to leave the entrance area clean
			if sz > 0:
				continue
			_spawn_floor_lantern(Vector3(fx, fy, fz))

# Hanging vertical scroll banner on a wall. cream paper + red stripe.
# rot_y = wall side (0 = back wall, ±90 = side walls).
func _spawn_scroll(pos: Vector3, rot_y_deg: float = 0.0) -> void:
	var scroll := MeshInstance3D.new()
	scroll.name = "Scroll"
	var sm := QuadMesh.new()
	sm.size = Vector2(0.45, 1.4)
	scroll.mesh = sm
	var smat := StandardMaterial3D.new()
	smat.albedo_color = Color(0.92, 0.87, 0.74, 1.0)  # cream paper
	smat.roughness = 0.85
	smat.cull_mode = BaseMaterial3D.CULL_DISABLED  # double-sided
	scroll.material_override = smat
	scroll.position = pos
	scroll.rotation_degrees = Vector3(0, rot_y_deg, 0)
	add_child(scroll)
	# Vertical red stripe down the middle (decorative kanji column)
	var stripe := MeshInstance3D.new()
	var sm2 := QuadMesh.new()
	sm2.size = Vector2(0.10, 1.0)
	stripe.mesh = sm2
	var stripe_mat := StandardMaterial3D.new()
	stripe_mat.albedo_color = Color(0.62, 0.12, 0.10, 1.0)  # vermilion
	stripe_mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	stripe.material_override = stripe_mat
	stripe.position = pos + Vector3(0, 0, 0.001) * (1 if abs(rot_y_deg) < 1.0 else -1)
	stripe.rotation_degrees = Vector3(0, rot_y_deg, 0)
	add_child(stripe)
	# Top + bottom rod (dark wood)
	for ry in [0.72, -0.72]:
		var rod := MeshInstance3D.new()
		var rm := CylinderMesh.new()
		rm.top_radius = 0.025
		rm.bottom_radius = 0.025
		rm.height = 0.55
		rod.mesh = rm
		var rmat := StandardMaterial3D.new()
		rmat.albedo_color = Color(0.20, 0.12, 0.08, 1.0)
		rod.material_override = rmat
		rod.rotation_degrees = Vector3(0, 0, 90)  # horizontal
		rod.rotation_degrees.y = rot_y_deg
		rod.position = pos + Vector3(0, ry, 0)
		add_child(rod)

# Weapon rack, vertical posts + horizontal pegs holding 3 katanas.
# Decorative; players can't pick them up. Reads as "this is a place
# where weapons are kept."
func _spawn_weapon_rack(pos: Vector3, rot_y_deg: float = 0.0) -> void:
	var rack := Node3D.new()
	rack.name = "WeaponRack"
	rack.position = pos
	rack.rotation_degrees = Vector3(0, rot_y_deg, 0)
	add_child(rack)
	# Two vertical posts
	var post_h: float = 1.4
	for sx in [-0.8, 0.8]:
		var post := MeshInstance3D.new()
		var pm := CylinderMesh.new()
		pm.bottom_radius = 0.04
		pm.top_radius = 0.04
		pm.height = post_h
		post.mesh = pm
		var pmat := StandardMaterial3D.new()
		pmat.albedo_color = Color(0.22, 0.14, 0.08, 1.0)
		post.material_override = pmat
		post.position = Vector3(sx, post_h * 0.5, 0)
		rack.add_child(post)
	# Three horizontal pegs at staggered heights
	for i in range(3):
		var peg_y: float = 0.4 + float(i) * 0.4
		var peg := MeshInstance3D.new()
		var pm := CylinderMesh.new()
		pm.bottom_radius = 0.02
		pm.top_radius = 0.02
		pm.height = 1.7
		peg.mesh = pm
		var pmat := StandardMaterial3D.new()
		pmat.albedo_color = Color(0.20, 0.12, 0.08, 1.0)
		peg.material_override = pmat
		peg.rotation_degrees = Vector3(0, 0, 90)  # horizontal
		peg.position = Vector3(0, peg_y, 0)
		rack.add_child(peg)
		# Katana resting on the peg, simplified: thin BoxMesh blade
		# with brown grip. Just visual.
		var blade := MeshInstance3D.new()
		var bm := BoxMesh.new()
		bm.size = Vector3(0.04, 0.05, 1.4)
		blade.mesh = bm
		var bmat := StandardMaterial3D.new()
		bmat.albedo_color = Color(0.78, 0.82, 0.90, 1.0)
		bmat.metallic = 1.0
		bmat.roughness = 0.18
		blade.material_override = bmat
		blade.position = Vector3(0, peg_y + 0.05, 0)
		rack.add_child(blade)
		# Grip section (left end of blade)
		var grip := MeshInstance3D.new()
		var gm := BoxMesh.new()
		gm.size = Vector3(0.05, 0.06, 0.35)
		grip.mesh = gm
		var gmat := StandardMaterial3D.new()
		gmat.albedo_color = Color(0.18, 0.10, 0.08, 1.0)
		grip.material_override = gmat
		grip.position = Vector3(0, peg_y + 0.05, -0.6)
		rack.add_child(grip)

# Standing floor lantern, short stone base + paper-orange glowing
# upper. Casts warm light into the dojo interior so the boss arena
# isn't a dark cave.
func _spawn_floor_lantern(pos: Vector3) -> void:
	# Base
	var base := MeshInstance3D.new()
	var bm := CylinderMesh.new()
	bm.bottom_radius = 0.18
	bm.top_radius = 0.16
	bm.height = 0.30
	base.mesh = bm
	var bmat := StandardMaterial3D.new()
	bmat.albedo_color = Color(0.42, 0.40, 0.36, 1.0)
	bmat.roughness = 0.92
	base.material_override = bmat
	base.position = pos + Vector3(0, 0.15, 0)
	add_child(base)
	# Stem
	var stem := MeshInstance3D.new()
	var sm := CylinderMesh.new()
	sm.top_radius = 0.04
	sm.bottom_radius = 0.04
	sm.height = 0.50
	stem.mesh = sm
	stem.material_override = bmat
	stem.position = pos + Vector3(0, 0.55, 0)
	add_child(stem)
	# Paper lantern body, glowing
	var body := MeshInstance3D.new()
	var bb := CylinderMesh.new()
	bb.top_radius = 0.18
	bb.bottom_radius = 0.18
	bb.height = 0.40
	body.mesh = bb
	var bbmat := StandardMaterial3D.new()
	bbmat.albedo_color = COL_LANTERN
	bbmat.emission_enabled = true
	bbmat.emission = Color(1.0, 0.55, 0.20)
	bbmat.emission_energy_multiplier = 1.5
	body.material_override = bbmat
	body.position = pos + Vector3(0, 1.00, 0)
	add_child(body)
	# OmniLight inside
	var light := OmniLight3D.new()
	light.light_color = Color(1.0, 0.62, 0.28)
	light.light_energy = 1.2
	light.omni_range = 5.0
	light.position = pos + Vector3(0, 1.00, 0)
	add_child(light)

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
	# Gold horizontal trim strip across the wall, visible on inside +
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

# Roof slab, angled BoxMesh tilted by `angle_rad` around `axis`.
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
	# Lantern body, short fat cylinder, glowing
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
