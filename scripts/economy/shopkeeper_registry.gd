extends Node

# Autoload: canonical shopkeeper roster. Each town and major zone has at least one
# vendor offering potions and basic gear matching the zone's recommended level.
# Specialty vendors (Six Breaths trainers, Druid Sanctum herbalist, etc) carry
# class-themed wares.

var vendors: Dictionary = {}  # StringName id -> Vendor

func _ready() -> void:
	_register_ashurim_vendors()
	_register_babilim_vendors()
	_register_region_vendors()

func get_vendor(id: StringName) -> Vendor:
	return vendors.get(id)

func vendors_in_zone(zone_id: StringName) -> Array[Vendor]:
	var arr: Array[Vendor] = []
	for v: Vendor in vendors.values():
		if v.home_zone_id == zone_id:
			arr.append(v)
	return arr

func _make(id: StringName, name: String, greeting: String, zone: StringName,
		min_lvl: int, max_lvl: int) -> Vendor:
	var v := Vendor.new()
	v.id = id
	v.display_name = name
	v.greeting = greeting
	v.home_zone_id = zone
	v.basic_gear_min_level = min_lvl
	v.basic_gear_max_level = max_lvl
	vendors[id] = v
	return v

# ----------------------------------------------------------------
# Ashurim - convergence town (lvl 5-8)
# ----------------------------------------------------------------
func _register_ashurim_vendors() -> void:
	_make(&"ashurim_innkeep", "Belitu the Innkeeper",
		"Singing Goat's open. Beds upstairs, drinks down here. Anything else, you ask Ulima two doors over.",
		&"ashurim", 1, 8).auto_stock_potions = true

	var u := _make(&"ashurim_general", "Ulima the General-Goods",
		"Got common gear, basics, and the kind of arrows that won't betray you when it matters.",
		&"ashurim", 4, 12)
	u.auto_stock_potions = true
	u.auto_stock_basic_gear = true

	_make(&"ashurim_storyteller", "The Storyteller",
		"Sit. The kettle is on. I don't sell what you came for; I tell you where it is.",
		&"ashurim", 1, 100).auto_stock_potions = false

# ----------------------------------------------------------------
# Babilim - main city (all-tier hub)
# ----------------------------------------------------------------
func _register_babilim_vendors() -> void:
	_make(&"babilim_market_general", "Iddinu's Caravan",
		"Best prices in the Lapis Quarter. Don't haggle. I'm tired.",
		&"babilim", 6, 60)

	_make(&"babilim_alchemy", "Salt-and-Stone Apothecary",
		"Potions, salves, the occasional truthing-elixir. Don't ask about that last one.",
		&"babilim", 1, 100).auto_stock_potions = true

	var sm := _make(&"babilim_smithy", "The Iron Pillar Smithy",
		"Hot work. Hammers, plate, mail, the lot. Show me a bar of mithril and we'll talk about the back room.",
		&"babilim", 10, 70)
	sm.auto_stock_basic_gear = true

	_make(&"babilim_arcane_scribe", "The Arcane Scribe",
		"Wands, focus crystals, books with most of their pages. Mage business only.",
		&"babilim", 8, 60).auto_stock_basic_gear = true

	_make(&"babilim_thieves_kitchen", "The Black Counter",
		"Quiet. Very quiet. Knives and lockpicks. Pretend you didn't see me.",
		&"babilim", 6, 60).auto_stock_basic_gear = true

	_make(&"babilim_stable_master", "The Stable Master",
		"Mounts, saddles, oats. Ask me about the heavy horses if you're going to the Reed Wastes.",
		&"babilim", 1, 60)

# ----------------------------------------------------------------
# Region vendors - one per major outpost
# ----------------------------------------------------------------
func _register_region_vendors() -> void:
	_make(&"reed_wastes_post", "Outpost Quartermaster",
		"Wastes-fit gear and antivenom. Wastes-fit means fits when worn under a corpse for camouflage.",
		&"reed_wastes", 10, 22).auto_stock_basic_gear = true

	_make(&"lapis_bay_dockmaster", "Dockmaster Mukin",
		"Dock prices, dock goods. Frost-hardy salt-leather, lapis ink, harpoons.",
		&"lapis_bay", 14, 30)

	_make(&"stone_dojo_quartermaster", "Anshar's Foothold Quartermaster",
		"Stone Breathing dojo issue. Heavy gear, heavy hammers, heavy boots. Mountain prices.",
		&"stone_dojo", 24, 45).auto_stock_basic_gear = true

	_make(&"druid_sanctum_herbalist", "Sanctum Herbalist",
		"Druid potions, salves, season-fresh poultices. The Sanctum-Mother trades by need, not gold.",
		&"druid_sanctum", 28, 50)

	_make(&"flame_temple_quartermaster", "Pillar of Nergal Quartermaster",
		"Flame Breathing temple supplies. Heat-treated. Warm even in your hand.",
		&"flame_temple", 34, 55).auto_stock_basic_gear = true

	_make(&"sundered_coast_smuggler", "Coast Smuggler",
		"Spawn-bone, spawn-ichor, things they don't sell in Babilim. Cash only.",
		&"sundered_coast", 60, 80)
