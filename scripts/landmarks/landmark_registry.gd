extends Node

# Autoload: 35+ landmarks scattered through the world. Each tells one piece
# of the lore. A patient player who finds them all has read most of the
# Enuma Elish through environmental storytelling.

var landmarks: Dictionary = {}  # StringName -> Landmark

func _ready() -> void:
	_register_cradle()
	_register_iron_crown()
	_register_reed_wastes()
	_register_lapis_bay()
	_register_bone_mountains()
	_register_verdant_wound()
	_register_ember_steppes()
	_register_mist_vale()
	_register_shrieking_highlands()
	_register_sundered_coast()
	_register_endgame()

func get_landmark(id: StringName) -> Landmark:
	return landmarks.get(id)

func landmarks_in_zone(zone: StringName) -> Array[Landmark]:
	var arr: Array[Landmark] = []
	for L: Landmark in landmarks.values():
		if L.zone_id == zone:
			arr.append(L)
	return arr

func _make(id: StringName, name: String, zone: StringName, kind: int,
		lore: String, inscription: String = "", xp: int = 100,
		ach_id: StringName = &"") -> Landmark:
	var L := Landmark.new()
	L.id = id
	L.display_name = name
	L.zone_id = zone
	L.kind = kind
	L.lore_on_discover = lore
	L.inscription = inscription
	L.xp_reward = xp
	L.unlocks_achievement_id = ach_id
	landmarks[id] = L
	return L

# ----------------------------------------------------------------
# CRADLE landmarks
# ----------------------------------------------------------------
func _register_cradle() -> void:
	_make(&"ash_step_cairn", "The Ash-Step Cairn",
		&"ash_step_camp", Landmark.Kind.GRAVE,
		"A pile of stones beside the road. Each stone has one name carved into it. The freshest stone has your father's name. Someone has scratched 'remember' under it. The handwriting is your sister's.",
		"REMEMBER")

	_make(&"whisper_initiate_stone", "The Whisper-Stone",
		&"whisper_shrine", Landmark.Kind.MONUMENT,
		"A black stone obelisk in the antechamber of the Whisper Shrine. The names of every initiate are carved into it. Yours is here. Newer than you remember being old enough to be carved.",
		"NAMES KEPT FOR THOSE WHO CANNOT KEEP THEIR OWN")

	_make(&"sword_vow_stone", "The Vow Stone",
		&"sword_vow_ruins", Landmark.Kind.MONUMENT,
		"The stone the sword-vow ceremonies were sworn over. Lord Ennum's blood is still on it. Someone has wiped it many times. It still shows.",
		"BY OATH GIVEN AND OATH KEPT")

	_make(&"greenheart_mother_tree", "The Mother Tree of Greenheart",
		&"greenheart_glade", Landmark.Kind.TREE,
		"An ash-tree at the center of the Glade. Older than the village. The bark is scored with countless small marks: a pilgrim's tally, a hunter's prayer, a child's name. Yours is somewhere here.",
		"")

	_make(&"inkstone_observation", "The Inkstone Observation Window",
		&"inkstone_tower", Landmark.Kind.OBSERVATION,
		"A small window cut into the seventh floor's outer wall, sized for a single eye. From here, on a clear night, you can see the Iron Pillar of Babilim glowing faintly. Old Asaridu used to stand here at dusk and sigh.",
		"")

	_make(&"coven_circle", "The Coven Circle",
		&"coven_glen", Landmark.Kind.ALTAR,
		"A ring of standing stones arranged for a moon-prayer. The grass inside is greener than outside. The Inquisition has tried to burn the circle three times. The circle is still here.",
		"")

	_make(&"sunsworn_altar", "The Sun-Sworn Altar",
		&"sunsworn_chapel", Landmark.Kind.ALTAR,
		"The chapel's altar, simple beaten copper in the shape of a sun. The chapel-master was kneeling here when the siege began. The kneeling-marks are still on the floor.",
		"")

	_make(&"ashurim_storyteller_door", "The Storyteller's Door",
		&"ashurim", Landmark.Kind.OTHER,
		"The door to the Storyteller's room above the Singing Goat. It is always slightly ajar. The cat that sits on the threshold is named after a god you have never heard of. The cat does not move when you approach.",
		"WALK IN. THE KETTLE IS ON.")

# ----------------------------------------------------------------
# IRON CROWN landmarks
# ----------------------------------------------------------------
func _register_iron_crown() -> void:
	_make(&"iron_pillar", "The Iron Pillar",
		&"babilim", Landmark.Kind.MONUMENT,
		"Marduk's edict, carved in gold leaf into a pillar of nickel-iron. The script is older than Akkadian. Some of the words have no translation. The pillar hums when you stand near it. The hum changes pitch when you speak.",
		"BY THE WORD AND THE WIND, THE WORLD STANDS.",
		300, &"examine_pillar")

	_make(&"silent_gate", "The Silent Gate",
		&"babilim", Landmark.Kind.GATE,
		"The seventh gate of Babilim. The one Marduk shut. The seal is visibly cracked, hairline, near the keystone. If you put your ear to it you hear nothing, but you feel something listening back.",
		"NOT FOR MORTAL HANDS",
		500, &"examine_silent_gate")

	_make(&"hanging_gardens_well", "The Hanging Gardens Wellhead",
		&"babilim", Landmark.Kind.WELL,
		"A spring fed from the Twin Rivers, which themselves come from Tiamat's eyes. The water tastes faintly of salt. The garden's keepers say it always has.",
		"")

	_make(&"crown_oracle_pillar", "The Oracle's Pillar",
		&"babilim", Landmark.Kind.MONUMENT,
		"A column in the Iron Pillar district where the blind, mute Oracle of the Pillar writes prophecies in chalk. Today's chalk-line reads: 'Champion-Of-Marduk. The cycle begins. The cycle ends. Eat the bread.'",
		"")

	_make(&"asaridu_well", "The Master's Well",
		&"inkstone_tower", Landmark.Kind.WELL,
		"The well in the basement of the Inkstone Tower. Old Asaridu sealed himself in here. Some days you can hear him reading, slowly, from the books he took down with him.",
		"",
		400, &"examine_apsu_well")

# ----------------------------------------------------------------
# REED WASTES landmarks
# ----------------------------------------------------------------
func _register_reed_wastes() -> void:
	_make(&"failed_seal_marker", "The Marker at Mu-Ash",
		&"reed_wastes", Landmark.Kind.MONUMENT,
		"A bronze marker driven into the salt where Marduk's third seal cracked. The marker says 'sealed' in three languages. None of them are true anymore.",
		"SEALED")

	_make(&"buried_pilgrim_road", "The Pilgrim's Lost Road",
		&"reed_wastes", Landmark.Kind.RUIN,
		"A stone road that surfaces and vanishes through the wastes. Walking on it makes the wind stop, briefly. The pilgrims who walked it never finished the journey, and they are still walking.",
		"")

	_make(&"ash_step_grave_field", "The Grave Field of Ash-Step",
		&"reed_wastes", Landmark.Kind.GRAVE,
		"Where the Ash-Step clans buried their dead before they were nomadic. Hundreds of cairns. Some are fresh; the clans still come here to bury, even though they live elsewhere now.",
		"")

# ----------------------------------------------------------------
# LAPIS BAY landmarks
# ----------------------------------------------------------------
func _register_lapis_bay() -> void:
	_make(&"salt_sea_marker", "Tiamat's Edge",
		&"lapis_bay", Landmark.Kind.MONUMENT,
		"A pillar at the bay's high-tide line marking where Marduk first cut Tiamat's body. The pillar is salt-eaten almost to nothing, but the inscription is still legible: 'HERE THE SEA WAS THE GODDESS.'",
		"HERE THE SEA WAS THE GODDESS")

	_make(&"sunken_ship_alanak", "Wreck of the Alanak",
		&"lapis_bay", Landmark.Kind.RUIN,
		"A Crown war-galley sunk seventy years ago in a storm. The captain's logbook washes up sometimes. The last entry reads: 'A song from below. We will not answer.' The crew apparently did.",
		"")

	_make(&"three_kings_thrones", "The Three Pirate Thrones",
		&"pirate_isles", Landmark.Kind.MONUMENT,
		"Three thrones, one per island, carved from beached whale-ribs. The first throne is where the eldest Black-Sail sits. The second sits empty more often than not. The third faces away from the sea.",
		"")

# ----------------------------------------------------------------
# BONE MOUNTAINS landmarks
# ----------------------------------------------------------------
func _register_bone_mountains() -> void:
	_make(&"first_climber_marker", "Marker of the First Climber",
		&"bone_mountains", Landmark.Kind.GRAVE,
		"A small bronze plaque on a peak. 'The First-Climber, who measured these peaks, and was buried by them.' The bones of the survey-party are scattered for half a kilometre. Some still hold their rulers.",
		"")

	_make(&"anshar_foothold_dojo_stone", "The First Stance",
		&"stone_dojo", Landmark.Kind.MONUMENT,
		"The first standing-stone of the Stone Breathing dojo. Every senior monk who has died here has had their ashes pressed into the stone. The stone is heavier than its volume should suggest.",
		"BE THE MOUNTAIN")

	_make(&"bone_mountains_old_road", "The Charnel-Road",
		&"bone_mountains", Landmark.Kind.RUIN,
		"A road paved with bone, that winds through the mountains. The bones are all human. They do not crunch under boots. They have been walked by too many people for too long.",
		"")

# ----------------------------------------------------------------
# VERDANT WOUND landmarks
# ----------------------------------------------------------------
func _register_verdant_wound() -> void:
	_make(&"sanctum_mother_tree", "The Sanctum Mother-Tree",
		&"druid_sanctum", Landmark.Kind.TREE,
		"A thousand-year ash. Druids born here are sworn to the tree before they learn to walk. The Sanctum-Mother lives in a hollow at its base. She has eyes like the eyes of small animals.",
		"")

	_make(&"wound_first_drop", "The First Drop",
		&"verdant_wound", Landmark.Kind.MONUMENT,
		"A blackened patch of earth where the first drop of Tiamat's blood landed when Marduk's arrow opened her side. Nothing has grown here since. Nothing will.",
		"")

	_make(&"twelve_handed_circle", "The Twelve-Handed Circle",
		&"verdant_wound", Landmark.Kind.RUIN,
		"A clearing where the Twelve-Handed sings. Twelve sets of handprints in the dirt; each set is a different size. Each is human.",
		"")

# ----------------------------------------------------------------
# EMBER STEPPES landmarks
# ----------------------------------------------------------------
func _register_ember_steppes() -> void:
	_make(&"pillar_of_nergal", "The Pillar of Nergal",
		&"flame_temple", Landmark.Kind.ALTAR,
		"A column of black basalt at the heart of the Flame Breathing temple. The flame in its central well has burned for seventeen hundred years. Each year the senior monk feeds it one of their own teeth.",
		"NERGAL EATS THE LATE.")

	_make(&"sun_eater_camp", "The Sun-Eater's Camp",
		&"ember_steppes", Landmark.Kind.RUIN,
		"The campsite where Nergal-Iddin first ate a piece of the Pillar of Nergal. The fire-pit is still warm. The sky directly above the camp does not have a sun in it.",
		"")

# ----------------------------------------------------------------
# MIST VALE landmarks
# ----------------------------------------------------------------
func _register_mist_vale() -> void:
	_make(&"vale_first_step", "The First Step",
		&"mist_vale", Landmark.Kind.MONUMENT,
		"A stone step at the entrance of the Mist Vale. The names of pilgrims who entered and did not leave are carved into the riser. There are many. They are recent.",
		"")

	_make(&"forgiveness_stone", "The Forgiveness Stone",
		&"mist_vale", Landmark.Kind.ALTAR,
		"A flat stone where pilgrims used to leave the things they wanted forgiveness for. The stone is empty now. The fog took everything.",
		"")

# ----------------------------------------------------------------
# SHRIEKING HIGHLANDS landmarks
# ----------------------------------------------------------------
func _register_shrieking_highlands() -> void:
	_make(&"adad_first_strike", "The First Strike",
		&"shrieking_highlands", Landmark.Kind.MONUMENT,
		"The peak where Adad first struck his hammer. The rock here is fused; the lightning has been arcing between the same two points for a thousand years. Standing in the gap is illegal under Crown law.",
		"")

	_make(&"hammer_widow_grave", "The Hammer-Widow's Grave",
		&"shrieking_highlands", Landmark.Kind.GRAVE,
		"Her husband's grave. The hammer is not here. She has it.",
		"HE WAS A KIND MAN")

# ----------------------------------------------------------------
# SUNDERED COAST landmarks
# ----------------------------------------------------------------
func _register_sundered_coast() -> void:
	_make(&"sundering_marker", "The Sundering Marker",
		&"sundered_coast", Landmark.Kind.MONUMENT,
		"A seven-foot iron stake driven into the sand where Marduk first dragged Tiamat's corpse. The iron has not rusted in seventeen hundred years.",
		"HERE BEGAN THE WORLD")

	_make(&"first_rib_arch", "The First Rib",
		&"sundered_coast", Landmark.Kind.RUIN,
		"The first half-sunken rib of Tiamat's body. From it Marduk made the cradle of the world. The rib still rises and falls, very slowly, with the tide. As if breathing.",
		"")

# ----------------------------------------------------------------
# ENDGAME landmarks
# ----------------------------------------------------------------
func _register_endgame() -> void:
	_make(&"tiamat_throne_skull", "Tiamat's Throne",
		&"black_citadel", Landmark.Kind.MONUMENT,
		"The skull is the throne. The throne is the skull. You are not supposed to sit on it before the fight. There is no one here to stop you.",
		"",
		1500)

	_make(&"sun_gate_top", "The Sun Gate, Topward",
		&"sun_gate", Landmark.Kind.GATE,
		"The gate of beaten gold that opens after Tiamat falls. Above the lintel, a single line: 'RETURN, IF YOU CAN.'",
		"RETURN, IF YOU CAN.")

	_make(&"fire_stair_first_step", "The First Step of the Stair",
		&"fire_stair", Landmark.Kind.MONUMENT,
		"The first basalt step. Warm to the touch. There is a single thread of woven gold draped over it; someone went down before you and came back, briefly, to leave the thread.",
		"")
