extends Node

# Autoload: cosmetic + utility pets. The Yak is special: +30 inventory slots
# party-wide. All others are purely cosmetic flavor.

var pets: Dictionary = {}  # StringName -> Pet

func _ready() -> void:
	_register_starter()
	_register_yak()
	_register_cosmetics()

func get_pet(id: StringName) -> Pet:
	return pets.get(id)

func all_pets() -> Array[Pet]:
	var arr: Array[Pet] = []
	for p in pets.values():
		arr.append(p)
	return arr

func owned_pets() -> Array[Pet]:
	var arr: Array[Pet] = []
	for p: Pet in pets.values():
		if is_owned(p.id):
			arr.append(p)
	return arr

func is_owned(id: StringName) -> bool:
	if not pets.has(id):
		return false
	var p: Pet = pets[id]
	if p.is_starter_free:
		return true
	return SaveFlags.has_permanent(StringName("pet_owned_" + String(id)))

func grant_ownership(id: StringName) -> void:
	SaveFlags.set_permanent(StringName("pet_owned_" + String(id)), true)

func _make(id: StringName, name: String, lore: String, price: float, starter: bool = false) -> Pet:
	var p := Pet.new()
	p.id = id
	p.display_name = name
	p.lore = lore
	p.price_usd = price
	p.is_starter_free = starter
	pets[id] = p
	return p

# ----------------------------------------------------------------
# STARTER (free at level 3)
# ----------------------------------------------------------------
func _register_starter() -> void:
	_make(&"pet_alley_cat", "Alley Cat",
		"Adopted you in Ashurim, technically. Cleans itself often, follows the smell of fish, occasionally trips you. Yours when you reach level 3.",
		0.0, true)

# ----------------------------------------------------------------
# THE YAK (utility - +30 inventory party-wide)
# ----------------------------------------------------------------
func _register_yak() -> void:
	var yak := _make(&"pet_yak", "Bone-Mountains Pack-Yak",
		"A patient, woolly Bone-Mountains pack-yak. Carries inventory like a moving warehouse. While summoned, every party member within 30m gains +30 bag slots. The yak does not complain. The yak prefers cold weather.",
		50.00)
	yak.inventory_bonus = 30
	yak.party_share_radius = 30.0

# ----------------------------------------------------------------
# PURELY COSMETIC PETS
# ----------------------------------------------------------------
func _register_cosmetics() -> void:
	_make(&"pet_raven", "Cradle Raven",
		"A black-feathered Greenheart raven. Says nothing in particular but says it loudly.",
		20.00)

	_make(&"pet_lapis_otter", "Lapis Bay Otter",
		"A bay-stock river otter. Carries a smooth pebble. Refuses to part with it.",
		20.00)

	_make(&"pet_steppe_dog", "Ash-Step Sheepdog",
		"Herds you when you wander. Has opinions about cliffs.",
		20.00)

	_make(&"pet_temple_butterfly", "Temple Butterfly",
		"A six-Breaths-temple butterfly, dyed gold by years of incense smoke. Lands on opposite-class players without prejudice.",
		20.00)

	_make(&"pet_sun_chick", "Sun-Sworn Chick",
		"A chapel hatchling that the chapel-master raised by hand before the siege. Big eyes. Will not stop following.",
		20.00)

	_make(&"pet_bone_lamb", "Bone-Mountains Lamb",
		"A small lamb from the Bone Mountains foothills. Bleats gently. Does not understand the bones it walks on.",
		20.00)

	_make(&"pet_apsu_eel", "Apsu Eel (jar)",
		"A small Apsu eel kept in a glass jar that you carry. The jar has been blessed by a senior mage. The eel is approximately three centuries old.",
		20.00)

	_make(&"pet_crown_kitten", "Crown Stables Kitten",
		"From the Iron Crown's stable mews. Has the run of Babilim's rooftops. Now has the run of your pack.",
		20.00)

	_make(&"pet_storyteller_cat", "The Storyteller's Cat",
		"She let you take it on credit. The cat watches you carefully. Reports back, presumably.",
		20.00)

	_make(&"pet_lifetime_world_serpent", "World-Serpent (Founder)",
		"Founders' edition. A small constrictor descended directly from one of Tiamat's pre-binding spawn. Cosmetic only - it does not eat anyone.",
		20.00)
