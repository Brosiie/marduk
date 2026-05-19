extends Node

# Autoload: registers all 5 races at boot, applies CharacterAppearance to a Player node.
#
# Tier 1: data layer + skin/hair/eye material override on the existing class mesh.
# Tier 2 (later): mesh swapping for body type, gender variants, equipped armor visualisation.
#
# class_name removed: registered as autoload "AppearanceRegistry" in project.godot.
# Access via get_node("/root/AppearanceRegistry").

const RACE_FILES := {
	&"anunnaki":         "res://resources/races/anunnaki.tres",
	&"ash_born":         "res://resources/races/ash_born.tres",
	&"reed_walker":      "res://resources/races/reed_walker.tres",
	&"mountain_forged":  "res://resources/races/mountain_forged.tres",
	&"wound_marked":     "res://resources/races/wound_marked.tres",
}


# Time-of-creation event windows. All checked against real-world UTC date.
# Calendar windows widen for in-game festival anniversaries (TODO: world_clock hooks).
const ECLIPSE_DATES_2026 := ["2026-08-12", "2027-08-02"]      # solar eclipses
const BLOOD_MOON_DATES_2026 := ["2026-03-03", "2026-08-28"]   # lunar eclipses
const SUN_FESTIVAL := "06-21"   # summer solstice (date format MM-DD, year-agnostic)
const DARK_SOLSTICE := "12-21"  # winter solstice
const FOUNDING_DATE := "05-08"  # Marduk's founding day

var races: Dictionary = {}  # StringName -> Race resource

# Cross-scene handoff: the CharacterCreator stashes the just-created appearance
# (and chosen name) here at flow-finish, then changes scene. The first Player
# that enters the new scene consumes them via take_pending().
var pending_appearance: CharacterAppearance = null
var pending_name: String = ""

signal appearance_applied(player: Node, appearance: CharacterAppearance)

func _ready() -> void:
	# Known headless-only limitation: `type="Race"` in the .tres files
	# triggers ClassDB.instantiate("Race") which can't find GDScript-defined
	# class_names in headless boot order. Loads succeed in the editor and in
	# release builds where ClassDB is fully populated before autoload _ready.
	# Headless still produces the warning below; gameplay is unaffected because
	# get_race() returns null and the character creator falls back to defaults.
	_load_all_races()

func _load_all_races() -> void:
	for race_id in RACE_FILES.keys():
		var path: String = RACE_FILES[race_id]
		var race: Race = load(path)
		if race:
			races[race_id] = race
		else:
			push_warning("[AppearanceRegistry] failed to load race: %s" % path)
	print("[AppearanceRegistry] loaded %d races" % races.size())

func get_race(id: StringName) -> Race:
	return races.get(id, null)

func all_races() -> Array:
	return races.values()

# Apply a CharacterAppearance to a Player node. Tier 1: tints the existing class mesh
# with race-derived skin/hair/eye colors and applies the height_scale modifier.
# Tier 2 will add gender mesh swapping, body-type proportions, and equipment overlays.
func apply(player: Node, appearance: CharacterAppearance) -> void:
	if not player or not appearance:
		return
	var race: Race = get_race(appearance.race_id)
	if not race:
		push_warning("[AppearanceRegistry] unknown race_id: %s" % appearance.race_id)
		return

	# Apply height scale (race baseline × creator slider modifier)
	var final_height: float = race.height_scale * appearance.height_scale_modifier
	if "scale" in player:
		player.scale = Vector3.ONE * final_height

	# Apply skin/hair/eye tint via material overrides on the mesh
	var skin_color: Color = race.get_skin_tone(appearance.skin_tone)
	var hair_color: Color = race.get_hair_color(appearance.hair_color)
	var eye_color: Color = race.get_eye_color(appearance.eye_color)
	_tint_mesh(player, skin_color, hair_color, eye_color)

	# Apply temporal gifts (eclipse halo, founder mark, etc.)
	_apply_temporal_gifts(player, appearance)

	# Apply apothecary saturation tint (Tier 2 § 8.5.5)
	_apply_apothecary_saturation(player, appearance)

	appearance_applied.emit(player, appearance)

func _tint_mesh(player: Node, skin: Color, _hair: Color, _eye: Color) -> void:
	# Tier 1: apply skin tint as a soft modulate on the player mesh.
	# Tier 2 will split the mesh into skin/hair/eye material slots and apply individually.
	var mesh_root: Node = null
	if player.has_node("MeshRoot"):
		mesh_root = player.get_node("MeshRoot")
	elif player.has_node("PlayerMesh"):
		mesh_root = player.get_node("PlayerMesh")
	if not mesh_root:
		return
	# Apply modulate to all MeshInstance3D children
	_apply_modulate_recursive(mesh_root, skin)

func _apply_modulate_recursive(node: Node, color: Color) -> void:
	if node is MeshInstance3D:
		var mi: MeshInstance3D = node
		if mi.get_surface_override_material_count() > 0:
			var mat: Material = mi.get_active_material(0)
			if mat is BaseMaterial3D:
				var new_mat: StandardMaterial3D = (mat as StandardMaterial3D).duplicate()
				new_mat.albedo_color = (mat as BaseMaterial3D).albedo_color * color
				mi.set_surface_override_material(0, new_mat)
	for c in node.get_children():
		_apply_modulate_recursive(c, color)

func _apply_temporal_gifts(player: Node, appearance: CharacterAppearance) -> void:
	if not appearance.has_temporal_gifts():
		return
	# Eclipse halo: faint dim crescent above the head
	if appearance.gift_eclipse_halo:
		_spawn_halo(player, Color(0.5, 0.5, 0.6, 0.4), 0.6)
	# Sun dawn aura
	if appearance.gift_sun_dawn_aura:
		_spawn_aura(player, Color(1.0, 0.85, 0.5, 0.5), 0.8)
	# Founder mark
	if appearance.gift_founder_mark_year > 0:
		_spawn_founder_mark(player, appearance.gift_founder_mark_year)

func _spawn_halo(player: Node, color: Color, scale: float) -> void:
	if not player.has_node("MeshRoot"):
		return
	var halo := MeshInstance3D.new()
	halo.name = "TemporalHalo"
	var torus := TorusMesh.new()
	torus.inner_radius = 0.18 * scale
	torus.outer_radius = 0.22 * scale
	halo.mesh = torus
	var mat := StandardMaterial3D.new()
	mat.albedo_color = color
	mat.emission_enabled = true
	mat.emission = color
	mat.emission_energy_multiplier = 1.5
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	halo.material_override = mat
	halo.position = Vector3(0, 2.0, 0)
	halo.rotation_degrees = Vector3(90, 0, 0)
	player.get_node("MeshRoot").add_child(halo)

func _spawn_aura(player: Node, color: Color, intensity: float) -> void:
	if not player.has_node("MeshRoot"):
		return
	var light := OmniLight3D.new()
	light.name = "TemporalAura"
	light.light_color = color
	light.light_energy = intensity
	light.omni_range = 4.0
	light.position = Vector3(0, 1.0, 0)
	player.get_node("MeshRoot").add_child(light)

func _spawn_founder_mark(player: Node, year: int) -> void:
	# Small Label3D on the chest with the founder year. Visible to other players.
	if not player.has_node("MeshRoot"):
		return
	var label := Label3D.new()
	label.name = "FounderMark"
	label.text = "F-%d" % year
	label.font_size = 18
	label.outline_size = 4
	label.outline_modulate = Color(0, 0, 0, 0.9)
	label.modulate = Color(1.0, 0.85, 0.30)
	label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	label.no_depth_test = false
	label.position = Vector3(0.0, 1.30, 0.20)
	label.pixel_size = 0.004
	player.get_node("MeshRoot").add_child(label)

func _apply_apothecary_saturation(player: Node, appearance: CharacterAppearance) -> void:
	# At full saturation (1000+ drinks), apply a colored tint matching the dominant potion type.
	var dominant: StringName = appearance.dominant_potion_type()
	if dominant == &"":
		return
	var saturation: int = 0
	match dominant:
		&"hp":       saturation = appearance.apothecary_hp_drinks
		&"mana":     saturation = appearance.apothecary_mana_drinks
		&"stamina":  saturation = appearance.apothecary_stamina_drinks
		&"champion": saturation = appearance.apothecary_champion_drinks
	if saturation < 100:
		return  # below threshold for any visible effect
	var tint_strength: float = clamp(float(saturation) / 1000.0, 0.0, 1.0) * 0.20
	var tint_color: Color = Color.WHITE
	match dominant:
		&"hp":       tint_color = Color(1.0, 0.7, 0.7).lerp(Color.WHITE, 1.0 - tint_strength)
		&"mana":     tint_color = Color(0.7, 0.8, 1.0).lerp(Color.WHITE, 1.0 - tint_strength)
		&"stamina":  tint_color = Color(0.75, 1.0, 0.75).lerp(Color.WHITE, 1.0 - tint_strength)
		&"champion": tint_color = Color(1.0, 0.9, 0.5).lerp(Color.WHITE, 1.0 - tint_strength)
	# Apply the tint on top of the existing skin tint
	if player.has_node("MeshRoot"):
		_apply_modulate_recursive(player.get_node("MeshRoot"), tint_color)

# Public: pop the pending appearance + name (one-shot consumption pattern).
# Returns {appearance, name}; both fields may be null/"" if nothing is pending.
# After return, the slots are cleared so subsequent Players don't re-consume.
func take_pending() -> Dictionary:
	var out := {
		"appearance": pending_appearance,
		"name": pending_name,
	}
	pending_appearance = null
	pending_name = ""
	return out

# Public: detects which time-of-creation gifts are active right now (real-world clock).
# Called by the character creator at confirm-time to bake gift flags into the appearance.
func active_gifts_now() -> Dictionary:
	var today: String = Time.get_date_string_from_system()  # YYYY-MM-DD
	var month_day: String = today.substr(5)  # MM-DD
	var current_year: int = int(today.substr(0, 4))
	return {
		&"eclipse":       today in ECLIPSE_DATES_2026,
		&"blood_moon":    today in BLOOD_MOON_DATES_2026,
		&"sun_festival":  month_day == SUN_FESTIVAL,
		&"dark_solstice": month_day == DARK_SOLSTICE,
		&"founder":       month_day == FOUNDING_DATE,
		&"current_year":  current_year,
	}
