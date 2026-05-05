extends Node

# Autoload registry of every Zone in Marduk. Built in code for the same reasons
# breathing forms are: 20+ zones with rich data are easier to read in one file
# than as 20+ .tres siblings.
#
# Diablo-4-style per-zone scaling floor: each zone has min_level (won't scale below)
# and recommended_level (target). Mobs scale to max(zone.min_level, player_level)
# clamped to zone.max_level. Cycle/prestige multiplier stacks on top.

var zones: Dictionary = {}  # StringName -> Zone

func _ready() -> void:
	# THE CRADLE - starter region, class intros + Ashurim convergence
	_register_class_intros()
	_register_ashurim()

	# THE IRON CROWN - Babilim metropolis
	_register_babilim()
	_register_iron_crown_outskirts()

	# THE REED WASTES - lvl 10-20
	_register_reed_wastes()

	# LAPIS BAY - lvl 15-25 (the "Salt Sea" - Tiamat's old domain, coastal)
	_register_lapis_bay()
	_register_pirate_isles()

	# BONE MOUNTAINS - lvl 25-40 (stone breathing dojo)
	_register_bone_mountains()
	_register_stone_dojo()

	# VERDANT WOUND - lvl 30-45 (corrupted forest, druid sanctum)
	_register_verdant_wound()
	_register_druid_sanctum()

	# EMBER STEPPES - lvl 35-50 (fire breathing temple)
	_register_ember_steppes()
	_register_flame_temple()

	# MIST VALE - lvl 40-55
	_register_mist_vale()

	# SHRIEKING HIGHLANDS - lvl 50-65
	_register_shrieking_highlands()

	# SUNDERED COAST - lvl 60-75
	_register_sundered_coast()

	# BLACK CITADEL - lvl 70-85, climactic stack
	_register_black_citadel()

	# POST-TIAMAT - SUN GATE + FIRE STAIR (Lucifer)
	_register_sun_gate()
	_register_fire_stair()

	# PRESTIGE-ONLY
	_register_ascension_plane()

func get_zone(id: StringName) -> Zone:
	return zones.get(id)

func all_zones() -> Array[Zone]:
	var arr: Array[Zone] = []
	for z in zones.values():
		arr.append(z)
	return arr

func zones_in_region(region: int) -> Array[Zone]:
	var arr: Array[Zone] = []
	for z: Zone in zones.values():
		if z.region == region:
			arr.append(z)
	return arr

func can_player_enter(zone: Zone) -> Dictionary:
	# Returns {ok: bool, reason: String}
	if zone.required_permanent_flag != &"" and not SaveFlags.has_permanent(zone.required_permanent_flag):
		return {"ok": false, "reason": zone.lock_hint if zone.lock_hint != "" else "Path is sealed."}
	if zone.required_run_flag != &"" and not SaveFlags.has_run(zone.required_run_flag):
		return {"ok": false, "reason": zone.lock_hint if zone.lock_hint != "" else "Door is barred this cycle."}
	if zone.blocks_after_run_flag != &"" and SaveFlags.has_run(zone.blocks_after_run_flag):
		return {"ok": false, "reason": "This way is closed for this cycle."}
	return {"ok": true, "reason": ""}

# ----------------------------------------------------------------
# Helper: build a Zone in one call, keep registrations terse.
# ----------------------------------------------------------------
func _make(id: StringName, name: String, region: int, safety: int,
		min_lvl: int, max_lvl: int, rec_lvl: int,
		fog: Color, ambient: Color, lore: String,
		connections: Array = [], scene: String = "") -> Zone:
	var z := Zone.new()
	z.id = id
	z.display_name = name
	z.region = region
	z.safety = safety
	z.min_level = min_lvl
	z.max_level = max_lvl
	z.recommended_level = rec_lvl
	z.fog_color = fog
	z.ambient_color = ambient
	z.lore = lore
	for c in connections:
		z.connections.append(c)
	z.scene_path = scene if scene != "" else "res://scenes/world/placeholder.tscn"
	zones[id] = z
	return z

# ----------------------------------------------------------------
# CRADLE - 6 class intro zones + Ashurim convergence
# ----------------------------------------------------------------
func _register_class_intros() -> void:
	# BERSERKER intro: Ash-Step Camp. Family murdered by raiders.
	var bz := _make(&"ash_step_camp", "The Ash-Step Camp",
		Zone.Region.CRADLE, Zone.SafetyTier.WILD, 1, 5, 1,
		Color(0.4, 0.25, 0.20), Color(0.5, 0.4, 0.35),
		"Wind-scoured plains where the Ash-Step clans range. The smoke on the horizon is your village. You are the last of it.",
		[&"ashurim"], "res://scenes/world/intros/ash_step_camp.tscn")
	bz.is_class_intro = true
	bz.intro_for_class = &"berserker"
	bz.encounter_table = [&"raider_grunt", &"raider_archer", &"raid_captain"]

	# ASSASSIN intro: Whisper Shrine. Master betrayed.
	var az := _make(&"whisper_shrine", "The Whisper Shrine",
		Zone.Region.CRADLE, Zone.SafetyTier.HOSTILE, 1, 5, 1,
		Color(0.15, 0.13, 0.18), Color(0.25, 0.22, 0.30),
		"A subterranean temple cut from black stone. You trained here. The brothers and sisters now hunt you.",
		[&"ashurim"], "res://scenes/world/intros/whisper_shrine.tscn")
	az.is_class_intro = true
	az.intro_for_class = &"assassin"
	az.encounter_table = [&"shrine_acolyte", &"shrine_zealot", &"corrupt_master"]

	# RONIN intro: Sword-Vow Ruins. Lord killed in coup.
	var rz := _make(&"sword_vow_ruins", "The Sword-Vow Ruins",
		Zone.Region.CRADLE, Zone.SafetyTier.WILD, 1, 5, 1,
		Color(0.3, 0.3, 0.35), Color(0.45, 0.42, 0.45),
		"A burned-out fortress on a windswept ridge. Your lord lies in the throne hall, his banner torn under boot prints. The usurper's enforcer still walks the halls.",
		[&"ashurim"], "res://scenes/world/intros/sword_vow_ruins.tscn")
	rz.is_class_intro = true
	rz.intro_for_class = &"ronin"
	rz.encounter_table = [&"usurper_footman", &"usurper_archer", &"usurper_enforcer"]

	# RANGER intro: Greenheart Glade. Forest village destroyed by Tiamat-spawn beast.
	var gz := _make(&"greenheart_glade", "The Greenheart Glade",
		Zone.Region.CRADLE, Zone.SafetyTier.WILD, 1, 5, 1,
		Color(0.25, 0.35, 0.25), Color(0.35, 0.5, 0.35),
		"Old-growth forest split by a stinking blood trail. The thing that came through here ate your kin. You read its tracks and follow.",
		[&"ashurim"], "res://scenes/world/intros/greenheart_glade.tscn")
	gz.is_class_intro = true
	gz.intro_for_class = &"ranger"
	gz.encounter_table = [&"corrupted_wolf", &"forest_blight", &"glade_terror"]

	# MAGE intro: Inkstone Tower. Master sacrificed self repelling invasion.
	var mz := _make(&"inkstone_tower", "The Inkstone Tower",
		Zone.Region.CRADLE, Zone.SafetyTier.HOSTILE, 1, 5, 1,
		Color(0.20, 0.20, 0.35), Color(0.30, 0.30, 0.45),
		"Seven floors of pages and ash. Your master died on the third. The construct that broke through still patrols the upper stories.",
		[&"ashurim"], "res://scenes/world/intros/inkstone_tower.tscn")
	mz.is_class_intro = true
	mz.intro_for_class = &"mage"
	mz.encounter_table = [&"binding_construct", &"animated_book", &"tower_warden"]

	# CHAOS DRUID intro: Coven Glen. Coven attacked, chaos awakens.
	var dz := _make(&"coven_glen", "The Coven Glen",
		Zone.Region.CRADLE, Zone.SafetyTier.HOSTILE, 1, 5, 1,
		Color(0.30, 0.20, 0.35), Color(0.40, 0.30, 0.45),
		"A standing-stone circle in a marsh. The hunters who burned your coven still search the reeds. The thing inside you starts to wake.",
		[&"ashurim"], "res://scenes/world/intros/coven_glen.tscn")
	dz.is_class_intro = true
	dz.intro_for_class = &"chaos_druid"
	dz.encounter_table = [&"blood_hunter", &"witch_burner", &"inquisitor_prime"]

	# PALADIN intro: Sun-Sworn Chapel. The chapel is besieged; you choose your spec.
	var pz := _make(&"sunsworn_chapel", "The Sun-Sworn Chapel",
		Zone.Region.CRADLE, Zone.SafetyTier.HOSTILE, 1, 5, 1,
		Color(0.5, 0.4, 0.20), Color(0.85, 0.7, 0.4),
		"A stone chapel on a hill west of Ashurim. Built before Babilim. Dedicated to Marduk's Light. The chapel is under siege; you wake in the crypt with a hammer in your hand and a shield on your back. The siege-master is in the nave, killing the wounded. The chapel-master is in the apse, healing the dying. You choose which one you stand beside.",
		[&"ashurim"], "res://scenes/world/intros/sunsworn_chapel.tscn")
	pz.is_class_intro = true
	pz.intro_for_class = &"paladin"  # spec_group_id; both paladin specs intro here
	pz.encounter_table = [&"siege_lieutenant", &"chapel_breaker", &"siege_master"]

func _register_ashurim() -> void:
	# Convergence town. All classes funnel here at level 5 after their mini-boss.
	var z := _make(&"ashurim", "Ashurim",
		Zone.Region.CRADLE, Zone.SafetyTier.SAFE, 5, 8, 5,
		Color(0.5, 0.4, 0.3), Color(0.7, 0.6, 0.45),
		"A market town on the road to Babilim, named for Anshar the Hidden. Six classes meet here for the first time, drawn by news of Marduk's edict failing. The town's Storyteller knows your face before you tell her your name.",
		[&"ash_step_camp", &"whisper_shrine", &"sword_vow_ruins", &"greenheart_glade",
			&"inkstone_tower", &"coven_glen", &"iron_crown_outskirts", &"reed_wastes"],
		"res://scenes/world/cities/ashurim.tscn")
	z.music_track = "res://assets/audio/music_ashurim.ogg"

# ----------------------------------------------------------------
# THE IRON CROWN - Babilim and surrounds
# ----------------------------------------------------------------
func _register_babilim() -> void:
	var z := _make(&"babilim", "Babilim, the Iron Crown",
		Zone.Region.IRON_CROWN, Zone.SafetyTier.HUB, 1, 100, 8,
		Color(0.45, 0.40, 0.25), Color(0.85, 0.75, 0.5),
		"The capital. Marduk's edict was carved into its central pillar in letters of gold leaf. Spired ziggurats, lapis-blue walls, six gates each named for a god. The Hanging Gardens still grow, fed by water from the Twin Rivers (Idiglat and Buranum, drawn from Tiamat's slain eyes). Vendors, fast-travel anchor, faction halls.",
		[&"iron_crown_outskirts", &"reed_wastes", &"lapis_bay", &"ascension_plane"],
		"res://scenes/world/cities/babilim.tscn")
	z.music_track = "res://assets/audio/music_babilim.ogg"

func _register_iron_crown_outskirts() -> void:
	_make(&"iron_crown_outskirts", "Iron Crown Outskirts",
		Zone.Region.IRON_CROWN, Zone.SafetyTier.WILD, 6, 12, 8,
		Color(0.5, 0.4, 0.3), Color(0.65, 0.55, 0.4),
		"The road outside Babilim's gates. Caravan brigands, escaped temple-slaves, the occasional minor demon that slipped through a thinning seal.",
		[&"babilim", &"ashurim", &"reed_wastes"],
		"res://scenes/world/regions/iron_crown_outskirts.tscn")

# ----------------------------------------------------------------
# THE REED WASTES - lvl 10-20
# ----------------------------------------------------------------
func _register_reed_wastes() -> void:
	_make(&"reed_wastes", "The Reed Wastes",
		Zone.Region.REED_WASTES, Zone.SafetyTier.WILD, 10, 20, 14,
		Color(0.5, 0.45, 0.30), Color(0.7, 0.6, 0.4),
		"Cracked dry plains where the marsh used to be. Tiamat's blood salted the ground when Marduk slew her. Demon incursions are common; minor seals fail nightly. The reeds remember.",
		[&"ashurim", &"iron_crown_outskirts", &"lapis_bay", &"ember_steppes"],
		"res://scenes/world/regions/reed_wastes.tscn")

# ----------------------------------------------------------------
# LAPIS BAY - the Salt Sea, coastal kingdom
# ----------------------------------------------------------------
func _register_lapis_bay() -> void:
	_make(&"lapis_bay", "Lapis Bay",
		Zone.Region.LAPIS_BAY, Zone.SafetyTier.SAFE, 15, 25, 18,
		Color(0.20, 0.40, 0.55), Color(0.45, 0.65, 0.85),
		"The old Salt Sea was Tiamat's body before Marduk cut her open. Now it is a lapis-blue bay ringed by white cities. The Water Breathing dojo is here. Pirate clans hold the outer isles; the bay's port-master pretends not to know.",
		[&"reed_wastes", &"pirate_isles", &"sundered_coast"],
		"res://scenes/world/regions/lapis_bay.tscn")

func _register_pirate_isles() -> void:
	_make(&"pirate_isles", "The Pirate Isles",
		Zone.Region.LAPIS_BAY, Zone.SafetyTier.HOSTILE, 18, 28, 22,
		Color(0.18, 0.30, 0.45), Color(0.4, 0.5, 0.7),
		"Three islands held by three pirate kings, each a former Lapis Bay noble who chose teeth over taxes.",
		[&"lapis_bay"],
		"res://scenes/world/regions/pirate_isles.tscn")

# ----------------------------------------------------------------
# BONE MOUNTAINS - stone breathing dojo, ossuaries
# ----------------------------------------------------------------
func _register_bone_mountains() -> void:
	_make(&"bone_mountains", "The Bone Mountains",
		Zone.Region.BONE_MOUNTAINS, Zone.SafetyTier.WILD, 25, 40, 30,
		Color(0.35, 0.32, 0.30), Color(0.5, 0.48, 0.45),
		"A range carved from a single ossuary. The bones are not human. Old hunting parties chased Tiamat's elder spawn into these peaks before the binding; the spawn lost, the hunters lost too.",
		[&"reed_wastes", &"stone_dojo", &"shrieking_highlands"],
		"res://scenes/world/regions/bone_mountains.tscn")

func _register_stone_dojo() -> void:
	_make(&"stone_dojo", "Anshar's Foothold",
		Zone.Region.BONE_MOUNTAINS, Zone.SafetyTier.SAFE, 25, 40, 30,
		Color(0.45, 0.42, 0.40), Color(0.65, 0.6, 0.55),
		"The Stone Breathing dojo, named for Anshar (the elder god, father-of-skies). Square-jawed teachers, square-jawed students, mountain in the heart of every breath.",
		[&"bone_mountains"],
		"res://scenes/world/regions/stone_dojo.tscn")

# ----------------------------------------------------------------
# VERDANT WOUND - corrupted forest, druid sanctum
# ----------------------------------------------------------------
func _register_verdant_wound() -> void:
	_make(&"verdant_wound", "The Verdant Wound",
		Zone.Region.VERDANT_WOUND, Zone.SafetyTier.HOSTILE, 30, 45, 36,
		Color(0.20, 0.30, 0.20), Color(0.35, 0.5, 0.30),
		"A forest where Tiamat bled when Marduk's first arrow struck. The trees grew wrong. Something in the loam thinks. Beast-lords roam at night.",
		[&"reed_wastes", &"druid_sanctum", &"ember_steppes"],
		"res://scenes/world/regions/verdant_wound.tscn")

func _register_druid_sanctum() -> void:
	_make(&"druid_sanctum", "The Mother-Tree Sanctum",
		Zone.Region.VERDANT_WOUND, Zone.SafetyTier.SAFE, 30, 45, 36,
		Color(0.30, 0.40, 0.30), Color(0.5, 0.65, 0.4),
		"Druid hold under a thousand-year ash. Chaos Druids who survived past coven attacks come here to learn the old shapes. The Sanctum-Mother knows your blood from sniff.",
		[&"verdant_wound"],
		"res://scenes/world/regions/druid_sanctum.tscn")

# ----------------------------------------------------------------
# EMBER STEPPES - fire breathing temple, bandits
# ----------------------------------------------------------------
func _register_ember_steppes() -> void:
	_make(&"ember_steppes", "The Ember Steppes",
		Zone.Region.EMBER_STEPPES, Zone.SafetyTier.WILD, 35, 50, 42,
		Color(0.55, 0.30, 0.20), Color(0.85, 0.55, 0.30),
		"Volcanic plain where the Flame Breathing temple sits over a permanent fissure. The land shrugs off ash daily. Bandits ride salamanders. The temple's senior monks have never extinguished their inner flame, even in sleep.",
		[&"reed_wastes", &"verdant_wound", &"flame_temple", &"mist_vale"],
		"res://scenes/world/regions/ember_steppes.tscn")

func _register_flame_temple() -> void:
	_make(&"flame_temple", "Pillar of Nergal",
		Zone.Region.EMBER_STEPPES, Zone.SafetyTier.SAFE, 35, 50, 42,
		Color(0.7, 0.4, 0.2), Color(1.0, 0.7, 0.4),
		"The Flame Breathing temple, built around the Pillar of Nergal (lord of fire and underworld). The flame in its central well has burned for seventeen hundred years.",
		[&"ember_steppes"],
		"res://scenes/world/regions/flame_temple.tscn")

# ----------------------------------------------------------------
# MIST VALE
# ----------------------------------------------------------------
func _register_mist_vale() -> void:
	_make(&"mist_vale", "The Mist Vale",
		Zone.Region.MIST_VALE, Zone.SafetyTier.HOSTILE, 40, 55, 47,
		Color(0.55, 0.55, 0.65), Color(0.7, 0.7, 0.8),
		"A high vale that stays in cloud year-round. The Mist Breathing temple is in here somewhere. Many who enter without a guide do not come out. Some never leave at all but you see them in the fog at dusk.",
		[&"ember_steppes", &"shrieking_highlands"],
		"res://scenes/world/regions/mist_vale.tscn")

# ----------------------------------------------------------------
# SHRIEKING HIGHLANDS
# ----------------------------------------------------------------
func _register_shrieking_highlands() -> void:
	_make(&"shrieking_highlands", "The Shrieking Highlands",
		Zone.Region.SHRIEKING_HIGHLANDS, Zone.SafetyTier.HOSTILE, 50, 65, 56,
		Color(0.45, 0.45, 0.65), Color(0.6, 0.6, 0.85),
		"Storm peaks where Adad's hammer still strikes. Lightning lives here as a constant low-grade rain. The Thunder Breathing dojo's apprentices are taught to walk in wet armor and not flinch when the bolt finds the iron.",
		[&"bone_mountains", &"mist_vale", &"sundered_coast"],
		"res://scenes/world/regions/shrieking_highlands.tscn")

# ----------------------------------------------------------------
# SUNDERED COAST - Tiamat's spawn nesting grounds
# ----------------------------------------------------------------
func _register_sundered_coast() -> void:
	_make(&"sundered_coast", "The Sundered Coast",
		Zone.Region.SUNDERED_COAST, Zone.SafetyTier.HOSTILE, 60, 75, 68,
		Color(0.30, 0.20, 0.30), Color(0.45, 0.30, 0.40),
		"The shore where Marduk dragged Tiamat's corpse before splitting her. Spawn nest in the half-sunken ribs. The tides taste of iron. Every wave brings something with too many limbs.",
		[&"lapis_bay", &"shrieking_highlands", &"black_citadel"],
		"res://scenes/world/regions/sundered_coast.tscn")

# ----------------------------------------------------------------
# BLACK CITADEL - climactic dungeon stack
# ----------------------------------------------------------------
func _register_black_citadel() -> void:
	var z := _make(&"black_citadel", "The Black Citadel",
		Zone.Region.BLACK_CITADEL, Zone.SafetyTier.BOSS, 70, 85, 78,
		Color(0.10, 0.05, 0.15), Color(0.20, 0.15, 0.25),
		"Tiamat's seat. The throne is her skull. Six-tier dungeon climbing into open sky. The final tier has no ceiling. She is waiting.",
		[&"sundered_coast"],
		"res://scenes/world/regions/black_citadel.tscn")
	z.blocks_after_run_flag = &"tiamat_defeated"  # door seals after kill in this cycle
	z.lock_hint = "She breathes again only when the cycle resets."

# ----------------------------------------------------------------
# SUN GATE + FIRE STAIR (post-Tiamat)
# ----------------------------------------------------------------
func _register_sun_gate() -> void:
	var z := _make(&"sun_gate", "The Sun Gate",
		Zone.Region.SUN_GATE, Zone.SafetyTier.SAFE, 80, 90, 84,
		Color(1.0, 0.8, 0.3), Color(1.0, 0.9, 0.5),
		"After Tiamat falls, a gate of beaten gold opens in her throne hall. Through it, a stair of light, and below it, a stair of fire.",
		[&"black_citadel", &"fire_stair"],
		"res://scenes/world/regions/sun_gate.tscn")
	z.required_run_flag = &"tiamat_defeated"
	z.lock_hint = "The gate opens only when she falls."

func _register_fire_stair() -> void:
	var z := _make(&"fire_stair", "The Fire Stair",
		Zone.Region.FIRE_STAIR, Zone.SafetyTier.BOSS, 85, 100, 92,
		Color(0.9, 0.2, 0.05), Color(1.0, 0.4, 0.1),
		"A descending spiral of basalt and embers. The light above is Marduk's. The light below is something else. Lucifer waits at the bottom, polite, courteous, perfectly willing to negotiate. Do not negotiate.",
		[&"sun_gate"],
		"res://scenes/world/regions/fire_stair.tscn")
	z.required_run_flag = &"tiamat_defeated"
	z.blocks_after_run_flag = &"lucifer_defeated"
	z.lock_hint = "The Stair burns again only when the cycle resets."

# ----------------------------------------------------------------
# ASCENSION PLANE - prestige-only
# ----------------------------------------------------------------
func _register_ascension_plane() -> void:
	var z := _make(&"ascension_plane", "The Ascension Plane",
		Zone.Region.ASCENSION_PLANE, Zone.SafetyTier.HUB, 1, 100, 1,
		Color(0.7, 0.7, 0.9), Color(0.85, 0.85, 1.0),
		"A pale folded space between cycles. Reachable from Babilim once you have prestiged at least once. NG+ vendors trade in soul-fragments. The Storyteller meets you here too, but she remembers things you have not done yet.",
		[&"babilim"],
		"res://scenes/world/regions/ascension_plane.tscn")
	z.required_permanent_flag = &"prestige_level"
	z.lock_hint = "This place is between. Only those who have closed a cycle find the door."
