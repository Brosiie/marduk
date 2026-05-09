extends Node3D
class_name ProceduralKatana

# Procedural katana mesh: builds a Node3D tree of BoxMesh / CylinderMesh
# primitives in the right proportions for a Japanese great-sword. Used
# when no actual katana .glb asset exists in the project (KayKit ships
# only sword_1handed / sword_2handed / dagger which don't read as a
# katana even with scaling).
#
# Composition (from top-down, blade pointing up by default):
#   Pommel (kashira):  small black box at the bottom of the grip
#   Tsuka (handle):    cylinder with diamond grip stripes
#   Tsuba (guard):     flat cylindrical disc at the grip top
#   Blade:             long thin BoxMesh, slight upward curve
#   Tip:               narrowed final inch with steel highlight
#
# Usage:
#   var k := ProceduralKatana.new()
#   socket.add_child(k)
# (transform/orientation set by parent socket)

const BLADE_LENGTH: float = 1.0
const BLADE_WIDTH: float = 0.05
const BLADE_THICKNESS: float = 0.022
const TSUKA_LENGTH: float = 0.26
const TSUKA_RADIUS: float = 0.022
const TSUBA_RADIUS: float = 0.07
const TSUBA_THICKNESS: float = 0.012

# Class-color used to tint the menuki ornament (small rivet on the
# grip). Defaults to gold for Ronin; passed in by caller for other
# classes that might use a katana variant.
@export var menuki_color: Color = Color(1.0, 0.85, 0.45, 1.0)

func _ready() -> void:
	_build()

func _build() -> void:
	# Pommel (kashira) - small black box at base
	var pommel := MeshInstance3D.new()
	pommel.name = "Pommel"
	var pommel_mesh := BoxMesh.new()
	pommel_mesh.size = Vector3(0.045, 0.045, 0.025)
	pommel.mesh = pommel_mesh
	pommel.material_override = _wrap_mat()
	pommel.position = Vector3(0, 0.0, 0)
	add_child(pommel)

	# Tsuka (handle) - dark cylinder, slightly thicker than blade
	var tsuka := MeshInstance3D.new()
	tsuka.name = "Tsuka"
	var tsuka_mesh := CylinderMesh.new()
	tsuka_mesh.top_radius = TSUKA_RADIUS
	tsuka_mesh.bottom_radius = TSUKA_RADIUS * 1.05
	tsuka_mesh.height = TSUKA_LENGTH
	tsuka.mesh = tsuka_mesh
	tsuka.material_override = _wrap_mat()
	tsuka.position = Vector3(0, TSUKA_LENGTH * 0.5, 0)
	add_child(tsuka)

	# Diamond grip wrap (12 ring-rivet decorations along the tsuka)
	for i in range(8):
		var t: float = float(i) / 7.0
		var rivet := MeshInstance3D.new()
		var rivet_mesh := SphereMesh.new()
		rivet_mesh.radius = 0.008
		rivet_mesh.height = 0.012
		rivet.mesh = rivet_mesh
		var rmat := StandardMaterial3D.new()
		rmat.albedo_color = Color(0.45, 0.30, 0.15, 1)  # leather wrap brown
		rmat.metallic = 0.05
		rmat.roughness = 0.85
		rivet.material_override = rmat
		# Alternating sides for the diamond-wrap look
		var side: float = 1.0 if (i % 2 == 0) else -1.0
		rivet.position = Vector3(side * (TSUKA_RADIUS + 0.005), TSUKA_LENGTH * t + 0.02, 0)
		add_child(rivet)

	# Menuki - small ornament rivet at the grip midpoint
	var menuki := MeshInstance3D.new()
	menuki.name = "Menuki"
	var menuki_mesh := SphereMesh.new()
	menuki_mesh.radius = 0.010
	menuki_mesh.height = 0.010
	menuki.mesh = menuki_mesh
	var mmat := StandardMaterial3D.new()
	mmat.albedo_color = menuki_color
	mmat.metallic = 0.85
	mmat.roughness = 0.20
	mmat.emission_enabled = true
	mmat.emission = menuki_color
	mmat.emission_energy_multiplier = 0.25
	menuki.material_override = mmat
	menuki.position = Vector3(0, TSUKA_LENGTH * 0.55, TSUKA_RADIUS * 0.9)
	add_child(menuki)

	# Tsuba (crossguard) - flat dark disc at top of grip
	var tsuba := MeshInstance3D.new()
	tsuba.name = "Tsuba"
	var tsuba_mesh := CylinderMesh.new()
	tsuba_mesh.top_radius = TSUBA_RADIUS
	tsuba_mesh.bottom_radius = TSUBA_RADIUS
	tsuba_mesh.height = TSUBA_THICKNESS
	tsuba.mesh = tsuba_mesh
	# Darker patinated iron core, real tsuba are deeply blackened
	# steel, not the medium gray we had. Lower roughness on the rim
	# below makes the polished gold edge stand out against this.
	var tmat := StandardMaterial3D.new()
	tmat.albedo_color = Color(0.10, 0.09, 0.08, 1)
	tmat.metallic = 0.65
	tmat.roughness = 0.55
	tsuba.material_override = tmat
	tsuba.position = Vector3(0, TSUKA_LENGTH + TSUBA_THICKNESS * 0.5, 0)
	add_child(tsuba)

	# Polished rim, slightly larger cylinder behind the tsuba so we
	# see a thin gold ring around the edge. Two-tone tsuba is what
	# real katana have; one-tone reads as a hockey-puck guard.
	var tsuba_rim := MeshInstance3D.new()
	tsuba_rim.name = "TsubaRim"
	var rim_mesh := CylinderMesh.new()
	rim_mesh.top_radius = TSUBA_RADIUS + 0.006
	rim_mesh.bottom_radius = TSUBA_RADIUS + 0.006
	rim_mesh.height = TSUBA_THICKNESS * 0.92
	tsuba_rim.mesh = rim_mesh
	var rmat2 := StandardMaterial3D.new()
	rmat2.albedo_color = Color(0.78, 0.62, 0.28, 1)
	rmat2.metallic = 0.95
	rmat2.roughness = 0.18
	tsuba_rim.material_override = rmat2
	tsuba_rim.position = Vector3(0, TSUKA_LENGTH + TSUBA_THICKNESS * 0.5, 0)
	add_child(tsuba_rim)
	# Move the dark core forward 0.001 so the rim shows through behind
	tsuba.position.z = 0.0005

	# Habaki (blade collar) - small bright cylinder between tsuba and
	# blade. Real katana have this brass-colored band; without it the
	# blade meets the guard with a hard seam. Tiny detail but it makes
	# the silhouette read as 'real katana' instead of 'box on a stick'.
	var habaki := MeshInstance3D.new()
	habaki.name = "Habaki"
	var hab_mesh := CylinderMesh.new()
	hab_mesh.top_radius = BLADE_WIDTH * 0.55
	hab_mesh.bottom_radius = TSUBA_RADIUS * 0.45
	hab_mesh.height = 0.024
	habaki.mesh = hab_mesh
	var hbmat := StandardMaterial3D.new()
	hbmat.albedo_color = Color(0.78, 0.62, 0.30, 1)  # warm brass
	hbmat.metallic = 0.85
	hbmat.roughness = 0.30
	habaki.material_override = hbmat
	habaki.position = Vector3(0, TSUKA_LENGTH + TSUBA_THICKNESS + 0.012, 0)
	add_child(habaki)

	# Blade - long thin BoxMesh extending from tsuba. Slightly narrower
	# at the base, slightly wider at the middle (illusion via 3 segments
	# rather than a single box that looks slab-flat). The middle 80% is
	# the main blade; we tip it with a tapered kissaki.
	var blade := MeshInstance3D.new()
	blade.name = "Blade"
	var blade_mesh := BoxMesh.new()
	blade_mesh.size = Vector3(BLADE_THICKNESS, BLADE_LENGTH * 0.85, BLADE_WIDTH)
	blade.mesh = blade_mesh
	blade.material_override = _blade_mat()
	blade.position = Vector3(0, TSUKA_LENGTH + TSUBA_THICKNESS + BLADE_LENGTH * 0.425 + 0.024, 0)
	# Slight forward tilt for the iconic katana curve illusion
	blade.rotation = Vector3(deg_to_rad(-2.5), 0, 0)
	add_child(blade)

	# Kissaki (tapered tip). A second BoxMesh at the top that we
	# narrow via scale-z so the silhouette ends in a point instead of
	# a flat slab. Real katana taper to ~30% width at the kissaki.
	var kissaki := MeshInstance3D.new()
	kissaki.name = "Kissaki"
	var ki_mesh := BoxMesh.new()
	ki_mesh.size = Vector3(BLADE_THICKNESS * 0.85, BLADE_LENGTH * 0.15, BLADE_WIDTH * 0.85)
	kissaki.mesh = ki_mesh
	kissaki.material_override = _blade_mat()
	# Position above the main blade, oriented along the same tilt
	kissaki.position = Vector3(0, TSUKA_LENGTH + TSUBA_THICKNESS + BLADE_LENGTH * 0.925 + 0.024, 0)
	kissaki.rotation = blade.rotation
	# Scale Z down to taper the tip (0.85 -> 0.30 along Y is the visual
	# illusion since BoxMesh is uniform; we simulate via two nested
	# child instances). For 1-mesh approach, scale.z directly.
	kissaki.scale.z = 0.55
	add_child(kissaki)

	# Hamon (tempering wave) accent: thin lighter strip down one side
	# of the blade. Mirror-polish so it catches highlight at swing-time.
	var hamon := MeshInstance3D.new()
	hamon.name = "Hamon"
	var hamon_mesh := BoxMesh.new()
	hamon_mesh.size = Vector3(BLADE_THICKNESS * 0.4, BLADE_LENGTH * 0.80, BLADE_WIDTH * 1.01)
	hamon.mesh = hamon_mesh
	var hmat := StandardMaterial3D.new()
	hmat.albedo_color = Color(0.92, 0.96, 1.0, 1)
	hmat.metallic = 1.0
	hmat.roughness = 0.04  # mirror finish so it catches the sun
	hamon.material_override = hmat
	hamon.position = Vector3(BLADE_THICKNESS * 0.31, TSUKA_LENGTH + TSUBA_THICKNESS + BLADE_LENGTH * 0.42 + 0.024, 0)
	hamon.rotation = blade.rotation
	add_child(hamon)

# Steel blade material: high reflectivity, low roughness, NO emission.
# The cinematic envelope's bloom amplifies any emissive surface into a
# halo -- so even tiny emission turns the blade into a lightsaber.
# Pure PBR steel reads correctly against the post-process stack.
func _blade_mat() -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = Color(0.78, 0.82, 0.90, 1)
	m.metallic = 1.0
	m.metallic_specular = 0.85
	m.roughness = 0.18
	return m

# Wrap (handle/pommel) material: dark leather/lacquer, low reflectivity
func _wrap_mat() -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = Color(0.10, 0.08, 0.07, 1)
	m.metallic = 0.05
	m.roughness = 0.92
	return m
