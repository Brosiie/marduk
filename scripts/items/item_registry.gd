extends Node

# Autoload: the canonical item catalog. Built in code via factory helpers.
# 130+ items spanning every slot, every weapon type, every rarity.
# Class-unique drops are tagged via class_restriction + unique_drop_source.
#
# Lookup: ItemRegistry.get_item(&"id"). Filter by slot/weapon/rarity for vendors,
# loot tables, auction defaults, recipe outputs.
#
# Naming convention: lowercase ids with underscores. Display names are the lore name.

var items: Dictionary = {}  # StringName id -> Item

func _ready() -> void:
	# Weapons
	_build_swords()
	_build_greatswords()
	_build_axes()
	_build_greataxes()
	_build_bludgeons()
	_build_great_bludgeons()
	_build_staves()
	_build_wands()
	_build_katanas()
	_build_nodachi()
	_build_daggers()
	_build_bows()
	_build_crossbows()
	_build_throwing_knives()
	_build_shuriken()
	_build_polearms()
	_build_scythes()
	_build_fists()
	_build_whips()
	# Off-hands
	_build_shields()
	_build_offhand_books()
	_build_tomes()
	_build_parrying_daggers()
	_build_quivers()
	_build_totems()
	# Armor
	_build_helms()
	_build_chests()
	_build_legs()
	_build_boots()
	_build_gloves()
	_build_cloaks()
	_build_belts()
	# Accessories
	_build_amulets()
	_build_rings()
	_build_charms()
	# Paladin gear (hammers, shields, plate/mail sets, charms)
	_build_paladin_weapons()
	# Consumable potions
	_build_potions()

func get_item(id: StringName) -> Item:
	return items.get(id)

func all_of_slot(slot: int) -> Array[Item]:
	var out: Array[Item] = []
	for it: Item in items.values():
		if it.slot == slot:
			out.append(it)
	return out

func all_of_rarity(rarity: int) -> Array[Item]:
	var out: Array[Item] = []
	for it: Item in items.values():
		if it.rarity == rarity:
			out.append(it)
	return out

func all_of_weapon_type(wt: int) -> Array[Item]:
	var out: Array[Item] = []
	for it: Item in items.values():
		if it.weapon_type == wt:
			out.append(it)
	return out

# ----------------------------------------------------------------
# Weapon factory: 1H weapons
# ----------------------------------------------------------------
func _w(id: StringName, name: String, lore: String,
		wt: int, rarity: int, ilvl: int,
		base_dmg: float, element: int = Item.Element.PHYSICAL, elem_pct: float = 0.0,
		atk_speed: float = 1.0, reach: float = 2.0,
		two_handed: bool = false,
		class_restrict: Array = []) -> Item:
	var i := Item.new()
	i.id = id
	i.display_name = name
	i.description = lore
	i.slot = Item.Slot.WEAPON_MAIN
	i.weapon_type = wt
	i.rarity = rarity
	i.item_level = ilvl
	i.base_damage = base_dmg
	i.element = element
	i.element_damage_pct = elem_pct
	i.attack_speed = atk_speed
	i.weapon_range = reach
	i.is_two_handed = two_handed
	for c in class_restrict:
		i.class_restriction.append(StringName(c))
	# Sell value rough scale: ilvl + rarity bonus
	i.sell_value = max(1, ilvl) * (1 + rarity * 4)
	items[id] = i
	return i

func _armor(id: StringName, name: String, lore: String,
		slot: int, rarity: int, ilvl: int,
		hp: float, armor_v: float, mr: float = 0.0,
		class_restrict: Array = [],
		armor_type: int = Item.ArmorType.LEATHER) -> Item:
	var i := Item.new()
	i.id = id
	i.display_name = name
	i.description = lore
	i.slot = slot
	i.rarity = rarity
	i.item_level = ilvl
	i.hp_bonus = hp
	i.armor_bonus = armor_v
	i.magic_resist_bonus = mr
	# Cloaks and belts are armor-type NONE; full body armor (head/chest/legs/feet/hands)
	# infers an armor_type if caller did not override.
	if slot in [Item.Slot.BACK, Item.Slot.BELT]:
		i.armor_type = Item.ArmorType.NONE
	else:
		i.armor_type = armor_type
	for c in class_restrict:
		i.class_restriction.append(StringName(c))
	i.sell_value = max(1, ilvl) * (1 + rarity * 3)
	items[id] = i
	return i

func _accessory(id: StringName, name: String, lore: String,
		slot: int, rarity: int, ilvl: int) -> Item:
	var i := Item.new()
	i.id = id
	i.display_name = name
	i.description = lore
	i.slot = slot
	i.rarity = rarity
	i.item_level = ilvl
	i.sell_value = max(1, ilvl) * (2 + rarity * 4)
	items[id] = i
	return i

# ================================================================
# 1H SWORDS
# ================================================================
func _build_swords() -> void:
	var sw1 := _w(&"sword_iron", "Iron Sword", "Standard cradle-forge blade. Reliable.",
		Item.WeaponType.SWORD, Item.Rarity.BASIC, 1, 14.0)
	sw1.attack_speed = 1.0

	_w(&"sword_steel", "Steel Sword", "Better steel, better edge.",
		Item.WeaponType.SWORD, Item.Rarity.COMMON, 5, 22.0).strength_bonus = 2.0

	var sw3 := _w(&"sword_temple", "Temple Acolyte's Sword", "Carried by the new initiates of the Inkstone.",
		Item.WeaponType.SWORD, Item.Rarity.COMMON, 8, 28.0)
	sw3.intellect_bonus = 3.0

	var sw4 := _w(&"sword_silver_edge", "Silver-Edged Longsword", "Cuts shadow-things cleaner than steel does.",
		Item.WeaponType.SWORD, Item.Rarity.RARE, 15, 42.0, Item.Element.HOLY, 0.20)
	sw4.crit_chance_bonus = 0.04

	var sw5 := _w(&"sword_lapis", "Lapis-Hilted Sabre", "Lapis Bay nobility favoured this curve.",
		Item.WeaponType.SWORD, Item.Rarity.RARE, 22, 55.0, Item.Element.FROST, 0.15)
	sw5.dexterity_bonus = 6.0
	sw5.attack_speed = 1.15

	var sw6 := _w(&"sword_pirate_kings", "Black-Sail Cutlass", "Forged from the spar of a Crown ship. Smells of brine and grudge.",
		Item.WeaponType.SWORD, Item.Rarity.VERY_RARE, 32, 88.0, Item.Element.PHYSICAL, 0.0)
	sw6.dexterity_bonus = 12.0
	sw6.crit_chance_bonus = 0.08
	sw6.crit_multiplier_bonus = 0.20
	sw6.unique_drop_source = &"pirate_king_first"
	sw6.unique_drop_chance = 0.20
	sw6.implicit_text = "+30% damage on bleeding targets."

	var sw7 := _w(&"sword_etemenanki", "Etemenanki's Bone-Edge", "Carved from a wraith-pillar. Hums when it nears wraiths still walking.",
		Item.WeaponType.SWORD, Item.Rarity.VERY_RARE, 12, 38.0, Item.Element.SHADOW, 0.30)
	sw7.intellect_bonus = 8.0
	sw7.unique_drop_source = &"lord_of_outskirts"
	sw7.unique_drop_chance = 0.25
	sw7.implicit_text = "+50% damage to undead. Hits drain 2% mana from target into wielder."

# ================================================================
# 2H GREATSWORDS
# ================================================================
func _build_greatswords() -> void:
	_w(&"greatsword_iron", "Iron Greatsword", "Two-handed cradle steel. Ugly but honest.",
		Item.WeaponType.GREATSWORD, Item.Rarity.BASIC, 5, 38.0,
		Item.Element.PHYSICAL, 0.0, 0.7, 2.6, true).strength_bonus = 4.0

	var gs2 := _w(&"greatsword_butcher", "Butcher's Cleaver", "Used to be a meat-cleaver. Used to be a tool.",
		Item.WeaponType.GREATSWORD, Item.Rarity.COMMON, 12, 60.0,
		Item.Element.PHYSICAL, 0.0, 0.65, 2.4, true)
	gs2.strength_bonus = 8.0
	gs2.implicit_text = "+15% damage on already-bleeding targets."

	var gs3 := _w(&"greatsword_kingu_brand", "Kingu's Lesser Brand", "Forged in imitation of the Tablet-Bearer's blade. Imitation is enough.",
		Item.WeaponType.GREATSWORD, Item.Rarity.RARE, 38, 145.0,
		Item.Element.SHADOW, 0.20, 0.7, 2.7, true)
	gs3.strength_bonus = 18.0
	gs3.crit_multiplier_bonus = 0.30

	var gs4 := _w(&"greatsword_sun_edge", "Sun-Edge Greatsword", "Forged in Babilim by a smith who once saw Sun Breathing. Pale gold in any light.",
		Item.WeaponType.GREATSWORD, Item.Rarity.VERY_RARE, 65, 240.0,
		Item.Element.HOLY, 0.30, 0.72, 2.8, true)
	gs4.strength_bonus = 28.0
	gs4.damage_bonus_pct = 0.15
	gs4.implicit_text = "+50% damage to demons."

	var gs5 := _w(&"greatsword_ennum_lost", "Ennum's Lost Blade", "Lord Ennum's coronation greatsword. The Ronin wakes in a sweat just holding it.",
		Item.WeaponType.GREATSWORD, Item.Rarity.VERY_RARE, 85, 320.0,
		Item.Element.PHYSICAL, 0.0, 0.7, 2.7, true,
		[&"ronin"])
	gs5.strength_bonus = 32.0
	gs5.dexterity_bonus = 18.0
	gs5.crit_chance_bonus = 0.10
	gs5.unique_drop_source = &"citadel_fifth"
	gs5.unique_drop_chance = 0.10
	gs5.implicit_text = "Ronin only. Perfect parries restore 5% HP. Killing blow grants +1 stance charge."

# ================================================================
# 1H AXES
# ================================================================
func _build_axes() -> void:
	_w(&"axe_iron_hand", "Iron Hand-Axe", "One hand, one head, one job.",
		Item.WeaponType.AXE, Item.Rarity.BASIC, 2, 16.0).strength_bonus = 1.0

	_w(&"axe_steel", "Steel Hand-Axe", "Heavier, sharper.",
		Item.WeaponType.AXE, Item.Rarity.COMMON, 6, 24.0,
		Item.Element.PHYSICAL, 0.0, 0.95).strength_bonus = 3.0

	var ax3 := _w(&"axe_steppe_skull", "Skull-Splitter of the Steppes", "Berserker tradition: the wielder names every kill and recites the list at the next campfire.",
		Item.WeaponType.AXE, Item.Rarity.RARE, 18, 50.0,
		Item.Element.PHYSICAL, 0.0, 1.0, 1.8, false,
		[&"berserker"])
	ax3.strength_bonus = 8.0
	ax3.crit_chance_bonus = 0.06
	ax3.implicit_text = "Berserker only. +25% rage gain."

	var ax4 := _w(&"axe_blood_iron", "Blood-Iron Hatchet", "The metal still bleeds when struck.",
		Item.WeaponType.AXE, Item.Rarity.VERY_RARE, 35, 95.0,
		Item.Element.BLOOD, 0.30)
	ax4.strength_bonus = 16.0
	ax4.implicit_text = "Crits inflict bleed: 8 damage/sec for 5 sec, stacks to 5."

# ================================================================
# 2H GREATAXES
# ================================================================
func _build_greataxes() -> void:
	_w(&"greataxe_iron", "Iron Greataxe", "Heavy. Slow. Sometimes that is what is needed.",
		Item.WeaponType.GREATAXE, Item.Rarity.BASIC, 7, 48.0,
		Item.Element.PHYSICAL, 0.0, 0.6, 2.5, true).strength_bonus = 5.0

	_w(&"greataxe_steppe", "Ash-Step Doublehead", "Two heads, two grudges.",
		Item.WeaponType.GREATAXE, Item.Rarity.COMMON, 16, 78.0,
		Item.Element.PHYSICAL, 0.0, 0.62, 2.6, true,
		[&"berserker"]).strength_bonus = 10.0

	var ga3 := _w(&"greataxe_hassu_kin", "Hassu's Kin-Axe", "Forged by Hassu's clan for his lieutenants. Now ownerless.",
		Item.WeaponType.GREATAXE, Item.Rarity.RARE, 28, 130.0,
		Item.Element.PHYSICAL, 0.0, 0.6, 2.7, true,
		[&"berserker"])
	ga3.strength_bonus = 18.0
	ga3.implicit_text = "Berserker only. +40% damage from behind. Killing blow heals 3% HP."

	var ga4 := _w(&"greataxe_throat_eater", "Throat-Eater", "Mu-Ash's lesser servants used these. Each axe still mutters the names of who it ate.",
		Item.WeaponType.GREATAXE, Item.Rarity.VERY_RARE, 50, 220.0,
		Item.Element.SHADOW, 0.20, 0.58, 2.8, true)
	ga4.strength_bonus = 26.0
	ga4.crit_multiplier_bonus = 0.40
	ga4.unique_drop_source = &"reed_demon_lord"
	ga4.unique_drop_chance = 0.08
	ga4.implicit_text = "+50% damage to demons."

# ================================================================
# 1H BLUDGEONS
# ================================================================
func _build_bludgeons() -> void:
	_w(&"mace_iron", "Iron Mace", "Heavy round head, plain shaft.",
		Item.WeaponType.BLUDGEON, Item.Rarity.BASIC, 3, 18.0).strength_bonus = 2.0

	_w(&"mace_flanged", "Flanged Mace", "Six flanges, six chances.",
		Item.WeaponType.BLUDGEON, Item.Rarity.COMMON, 9, 32.0).strength_bonus = 5.0

	var m3 := _w(&"mace_inquisitor", "Inquisitor's Censer-Mace", "Used in the Bone Quarter. Smells of burned witches.",
		Item.WeaponType.BLUDGEON, Item.Rarity.RARE, 24, 70.0,
		Item.Element.HOLY, 0.25)
	m3.strength_bonus = 12.0
	m3.implicit_text = "+30% damage to chaos-touched (Druid spawn, hexed targets)."

	var m4 := _w(&"mace_pillar_fragment", "Pillar-Fragment Mace", "Made from a chip of the Edict pillar. The metal in it remembers.",
		Item.WeaponType.BLUDGEON, Item.Rarity.VERY_RARE, 45, 160.0,
		Item.Element.HOLY, 0.40)
	m4.strength_bonus = 22.0
	m4.intellect_bonus = 12.0
	m4.implicit_text = "Spells consume holy charges. Each charge restored on melee hit."

# ================================================================
# 2H GREAT BLUDGEONS
# ================================================================
func _build_great_bludgeons() -> void:
	_w(&"maul_iron", "Iron Maul", "Two hands, one head, all damage.",
		Item.WeaponType.GREAT_BLUDGEON, Item.Rarity.BASIC, 8, 52.0,
		Item.Element.PHYSICAL, 0.0, 0.55, 2.5, true).strength_bonus = 6.0

	_w(&"maul_warhammer", "Crown Warhammer", "Babilim's heavy infantry standard.",
		Item.WeaponType.GREAT_BLUDGEON, Item.Rarity.COMMON, 18, 88.0,
		Item.Element.PHYSICAL, 0.0, 0.58, 2.6, true).strength_bonus = 12.0

	var mh3 := _w(&"maul_adad_lesser", "Adad's Lesser Hammer", "Forged for Thunder dojo apprentices who never advanced to true hammers.",
		Item.WeaponType.GREAT_BLUDGEON, Item.Rarity.RARE, 38, 165.0,
		Item.Element.LIGHTNING, 0.30, 0.58, 2.7, true)
	mh3.strength_bonus = 18.0
	mh3.implicit_text = "+25% lightning damage. 10% chance per hit to chain to nearby enemy."

	var mh4 := _w(&"maul_mountain_splitter", "Pre-Mountain Splitter", "A practice maul shaped after the legendary Stone Form 7 ultimate. Heavy, but the practice paid off.",
		Item.WeaponType.GREAT_BLUDGEON, Item.Rarity.VERY_RARE, 60, 270.0,
		Item.Element.PHYSICAL, 0.0, 0.55, 2.8, true,
		[&"ronin", &"berserker"])
	mh4.strength_bonus = 28.0
	mh4.implicit_text = "Charged attacks ignore 50% armor."

# ================================================================
# 2H STAVES
# ================================================================
func _build_staves() -> void:
	_w(&"staff_apprentice", "Apprentice's Staff", "Stick with a crystal. Will get you through Inkstone Tower's first floor.",
		Item.WeaponType.STAFF, Item.Rarity.BASIC, 1, 12.0,
		Item.Element.ARCANE, 0.30, 0.85, 2.2, true).intellect_bonus = 4.0

	var st2 := _w(&"staff_inkstone", "Inkstone Initiate's Staff", "Carried by middle-floor students. The crystal is bigger.",
		Item.WeaponType.STAFF, Item.Rarity.COMMON, 8, 28.0,
		Item.Element.ARCANE, 0.40, 0.85, 2.3, true)
	st2.intellect_bonus = 8.0
	st2.mana_bonus = 20.0

	var st3 := _w(&"staff_lapis_drowned", "Drowned Lapis Staff", "Recovered from the wreckage of a Lapis Bay schoolship. Drips even when dry.",
		Item.WeaponType.STAFF, Item.Rarity.RARE, 22, 75.0,
		Item.Element.FROST, 0.50, 0.85, 2.4, true,
		[&"mage"])
	st3.intellect_bonus = 16.0
	st3.mana_bonus = 40.0
	st3.implicit_text = "Frost spells slow targets by 30% extra."

	var st4 := _w(&"staff_pillar_thread", "Thread of the Pillar", "A polished sliver of Edict-stone bound to ash-wood. Hums in libraries.",
		Item.WeaponType.STAFF, Item.Rarity.VERY_RARE, 50, 180.0,
		Item.Element.HOLY, 0.55, 0.85, 2.5, true,
		[&"mage"])
	st4.intellect_bonus = 26.0
	st4.mana_bonus = 90.0
	st4.crit_chance_bonus = 0.10
	st4.implicit_text = "Spells crit twice. Mana regen +50%."

	var st5 := _w(&"staff_druid_thorn", "Thorn-Wreath Staff", "Druid weapon, the wood remembers being a tree, and acts accordingly.",
		Item.WeaponType.STAFF, Item.Rarity.VERY_RARE, 55, 200.0,
		Item.Element.NATURE, 0.50, 0.85, 2.5, true,
		[&"chaos_druid"])
	st5.intellect_bonus = 24.0
	st5.vitality_bonus = 12.0
	st5.implicit_text = "Druid only. Form Energy regen +50% even while in form."

# ================================================================
# 1H WANDS
# ================================================================
func _build_wands() -> void:
	_w(&"wand_apprentice", "Apprentice's Wand", "Pointer with a crystal tip.",
		Item.WeaponType.WAND, Item.Rarity.BASIC, 1, 9.0,
		Item.Element.ARCANE, 0.40, 1.20, 1.8, false).intellect_bonus = 3.0

	var wn2 := _w(&"wand_burning_finger", "Burning Finger", "Old Asaridu used to teach with this. Always warm.",
		Item.WeaponType.WAND, Item.Rarity.COMMON, 7, 22.0,
		Item.Element.FIRE, 0.50, 1.25, 1.9, false,
		[&"mage"])
	wn2.intellect_bonus = 6.0
	wn2.implicit_text = "Mage only. Fire spells +15% damage."

	var wn3 := _w(&"wand_lightning_call", "Lightning-Call", "Carved from a Shrieking Highlands oak hit by the same bolt three times.",
		Item.WeaponType.WAND, Item.Rarity.RARE, 28, 70.0,
		Item.Element.LIGHTNING, 0.55, 1.30, 2.0, false,
		[&"mage"])
	wn3.intellect_bonus = 14.0
	wn3.implicit_text = "Lightning spells +20% chain count."

	var wn4 := _w(&"wand_void_finger", "Finger of the Void", "Asaridu had this in his sleeve when he sealed himself in the well. The heir found it.",
		Item.WeaponType.WAND, Item.Rarity.VERY_RARE, 55, 175.0,
		Item.Element.VOID, 0.60, 1.30, 2.0, false,
		[&"mage"])
	wn4.intellect_bonus = 24.0
	wn4.crit_chance_bonus = 0.10
	wn4.implicit_text = "Mage only. Void spells +30%. Crit kills extend mana to full."

# ================================================================
# 1H KATANAS (Ronin signature)
# ================================================================
func _build_katanas() -> void:
	_w(&"katana_temple", "Temple Katana", "Standard issue at any breathing temple.",
		Item.WeaponType.KATANA, Item.Rarity.BASIC, 4, 22.0,
		Item.Element.PHYSICAL, 0.0, 1.10, 2.1).dexterity_bonus = 3.0

	var kt2 := _w(&"katana_water_disciple", "Water Disciple's Katana", "Water Breathing first-year blade. Salt-rinsed nightly.",
		Item.WeaponType.KATANA, Item.Rarity.COMMON, 12, 42.0,
		Item.Element.FROST, 0.20, 1.15, 2.2)
	kt2.dexterity_bonus = 8.0
	kt2.implicit_text = "+20% Water-form damage."

	var kt3 := _w(&"katana_flame_disciple", "Flame Disciple's Katana", "Flame Breathing first-year. Heat-treated permanently.",
		Item.WeaponType.KATANA, Item.Rarity.COMMON, 12, 42.0,
		Item.Element.FIRE, 0.20, 1.15, 2.2)
	kt3.dexterity_bonus = 8.0
	kt3.implicit_text = "+20% Flame-form damage."

	var kt4 := _w(&"katana_thunder_disciple", "Thunder Disciple's Katana", "Thunder Breathing apprentice blade. Shaped to crack the air.",
		Item.WeaponType.KATANA, Item.Rarity.COMMON, 14, 48.0,
		Item.Element.LIGHTNING, 0.20, 1.20, 2.2)
	kt4.dexterity_bonus = 10.0
	kt4.implicit_text = "+20% Thunder-form damage."

	var kt5 := _w(&"katana_kazat_iron", "Iron-Faced Kazat's Sidearm", "Used by the enforcer who held your lord. Tarnished now.",
		Item.WeaponType.KATANA, Item.Rarity.RARE, 8, 32.0,
		Item.Element.PHYSICAL, 0.0, 1.20, 2.2, false,
		[&"ronin"])
	kt5.dexterity_bonus = 10.0
	kt5.crit_chance_bonus = 0.06
	kt5.unique_drop_source = &"usurper_enforcer"
	kt5.unique_drop_chance = 0.30
	kt5.implicit_text = "Ronin only. +1 starting stance charge."

	var kt6 := _w(&"katana_breathing_master", "Breath-Master's Katana", "Folded a thousand times by a Six Breaths grand-master who lived to 110.",
		Item.WeaponType.KATANA, Item.Rarity.VERY_RARE, 60, 220.0,
		Item.Element.PHYSICAL, 0.0, 1.20, 2.3, false,
		[&"ronin"])
	kt6.dexterity_bonus = 28.0
	kt6.crit_chance_bonus = 0.12
	kt6.crit_multiplier_bonus = 0.40
	kt6.implicit_text = "Ronin only. All breathing forms +15% damage. Chain bonus duration +1 sec."

# ================================================================
# 2H NODACHI
# ================================================================
func _build_nodachi() -> void:
	_w(&"nodachi_temple", "Temple Nodachi", "Long blade, two-hand grip, training grade.",
		Item.WeaponType.NODACHI, Item.Rarity.BASIC, 10, 60.0,
		Item.Element.PHYSICAL, 0.0, 0.85, 2.9, true).dexterity_bonus = 6.0

	var nd2 := _w(&"nodachi_storm_walker", "Storm-Walker Nodachi", "Made for Thunder Form 1 dashes. The wielder is supposed to leave a wake of broken air.",
		Item.WeaponType.NODACHI, Item.Rarity.RARE, 35, 155.0,
		Item.Element.LIGHTNING, 0.25, 0.90, 3.0, true,
		[&"ronin"])
	nd2.dexterity_bonus = 18.0
	nd2.implicit_text = "Thunder Forms +25% damage."

	var nd3 := _w(&"nodachi_constant_flow", "Constant Flow Nodachi", "Forged after a Water Breathing master held Form 7 for seven minutes straight without dropping it.",
		Item.WeaponType.NODACHI, Item.Rarity.VERY_RARE, 70, 280.0,
		Item.Element.FROST, 0.30, 0.90, 3.0, true,
		[&"ronin"])
	nd3.dexterity_bonus = 32.0
	nd3.crit_chance_bonus = 0.15
	nd3.implicit_text = "Ronin only. Channeled abilities cannot be interrupted by light hits. +25% Water Form damage."

# ================================================================
# 1H DAGGERS
# ================================================================
func _build_daggers() -> void:
	_w(&"dagger_iron", "Iron Dagger", "Short, mean.",
		Item.WeaponType.DAGGER, Item.Rarity.BASIC, 1, 10.0,
		Item.Element.PHYSICAL, 0.0, 1.40, 1.4).dexterity_bonus = 2.0

	_w(&"dagger_thieves_kitchen", "Thieves' Kitchen Knife", "Sold under the counter at the undercity market.",
		Item.WeaponType.DAGGER, Item.Rarity.COMMON, 6, 22.0,
		Item.Element.PHYSICAL, 0.0, 1.45, 1.5).dexterity_bonus = 5.0

	var dg3 := _w(&"dagger_whisper_initiate", "Whisper-Initiate's Knife", "Whisper Shrine first blade. The hilt has the initiate's true name carved into it; you do not know yours.",
		Item.WeaponType.DAGGER, Item.Rarity.RARE, 16, 48.0,
		Item.Element.SHADOW, 0.20, 1.50, 1.5, false,
		[&"assassin"])
	dg3.dexterity_bonus = 10.0
	dg3.crit_chance_bonus = 0.10
	dg3.implicit_text = "Assassin only. +30% damage from stealth."

	var dg4 := _w(&"dagger_five_mouth_pup", "The Five-Mouth's Pup", "Sapum let his disciples pet this dagger when they did well. Some still have all their fingers.",
		Item.WeaponType.DAGGER, Item.Rarity.VERY_RARE, 40, 130.0,
		Item.Element.SHADOW, 0.30, 1.55, 1.5, false,
		[&"assassin"])
	dg4.dexterity_bonus = 22.0
	dg4.crit_chance_bonus = 0.18
	dg4.implicit_text = "Crits inflict stacking poison (DoT)."

# ================================================================
# 2H BOWS
# ================================================================
func _build_bows() -> void:
	_w(&"bow_short", "Short Bow", "First bow most rangers learn.",
		Item.WeaponType.BOW, Item.Rarity.BASIC, 2, 18.0,
		Item.Element.PHYSICAL, 0.0, 1.0, 18.0, true).dexterity_bonus = 3.0

	_w(&"bow_long", "Yeoman's Longbow", "Reach further, hit harder.",
		Item.WeaponType.BOW, Item.Rarity.COMMON, 9, 35.0,
		Item.Element.PHYSICAL, 0.0, 0.90, 22.0, true,
		[&"ranger"]).dexterity_bonus = 8.0

	var bw3 := _w(&"bow_storm", "Storm-Caller Bow", "Strung with a hair from a Shrieking Highlands monk. Lightning tickles the string.",
		Item.WeaponType.BOW, Item.Rarity.RARE, 28, 95.0,
		Item.Element.LIGHTNING, 0.25, 0.95, 22.0, true,
		[&"ranger"])
	bw3.dexterity_bonus = 18.0
	bw3.implicit_text = "Ranger only. 15% chance per hit to summon a chain-bolt to nearest enemy."

	var bw4 := _w(&"bow_glade_widow", "The Glade Widow's Recurve", "Found leaning against a tree in Greenheart. The widow is gone; the bow waited.",
		Item.WeaponType.BOW, Item.Rarity.VERY_RARE, 55, 200.0,
		Item.Element.NATURE, 0.30, 1.00, 24.0, true,
		[&"ranger"])
	bw4.dexterity_bonus = 30.0
	bw4.crit_chance_bonus = 0.15
	bw4.implicit_text = "Ranger only. Arrows seek (homing). Crit kills heal 8% HP."

# ================================================================
# 2H CROSSBOWS
# ================================================================
func _build_crossbows() -> void:
	_w(&"crossbow_simple", "Simple Crossbow", "Slow load, hard hit.",
		Item.WeaponType.CROSSBOW, Item.Rarity.BASIC, 3, 28.0,
		Item.Element.PHYSICAL, 0.0, 0.55, 18.0, true).dexterity_bonus = 4.0

	var cb2 := _w(&"crossbow_repeater", "Crown Repeater", "Issued to Babilim's wall-archers.",
		Item.WeaponType.CROSSBOW, Item.Rarity.RARE, 30, 95.0,
		Item.Element.PHYSICAL, 0.0, 0.75, 18.0, true,
		[&"ranger"])
	cb2.dexterity_bonus = 14.0
	cb2.implicit_text = "Ranger only. Reload time -30%."

	var cb3 := _w(&"crossbow_inquisitor", "Inquisitor's Heavy Crossbow", "Fires bolts inscribed with banishment-glyphs.",
		Item.WeaponType.CROSSBOW, Item.Rarity.VERY_RARE, 55, 215.0,
		Item.Element.HOLY, 0.30, 0.55, 22.0, true)
	cb3.dexterity_bonus = 22.0
	cb3.crit_multiplier_bonus = 0.50
	cb3.implicit_text = "Crits banish demons (instant kill below 30% HP)."

# ================================================================
# THROWING KNIVES (stack)
# ================================================================
func _build_throwing_knives() -> void:
	var tk1 := _w(&"throwing_iron", "Iron Throwing Knives", "A handful is a serious threat.",
		Item.WeaponType.THROWING_KNIVES, Item.Rarity.BASIC, 1, 12.0,
		Item.Element.PHYSICAL, 0.0, 1.50, 12.0)
	tk1.stack_size = 50
	tk1.dexterity_bonus = 1.0

	var tk2 := _w(&"throwing_serrated", "Serrated Throwing Knives", "Bite on the way out, too.",
		Item.WeaponType.THROWING_KNIVES, Item.Rarity.COMMON, 7, 22.0,
		Item.Element.PHYSICAL, 0.0, 1.55, 12.0)
	tk2.stack_size = 50
	tk2.implicit_text = "Inflicts bleed: 4 damage/sec for 4 sec."

	var tk3 := _w(&"throwing_silver", "Silver Throwing Knives", "Fold-silver, sun-blessed.",
		Item.WeaponType.THROWING_KNIVES, Item.Rarity.RARE, 22, 55.0,
		Item.Element.HOLY, 0.30, 1.55, 14.0)
	tk3.stack_size = 50
	tk3.implicit_text = "+50% damage to demons."

	var tk4 := _w(&"throwing_master", "Master's Throwing Set", "Each blade has been thrown over a thousand times. They remember the arc.",
		Item.WeaponType.THROWING_KNIVES, Item.Rarity.VERY_RARE, 50, 130.0,
		Item.Element.PHYSICAL, 0.0, 1.65, 16.0, false,
		[&"assassin", &"ranger", &"ronin"])
	tk4.stack_size = 50
	tk4.crit_chance_bonus = 0.20
	tk4.implicit_text = "Always returns to inventory after kill. Crits bypass all armor."

# ================================================================
# SHURIKEN (stack)
# ================================================================
func _build_shuriken() -> void:
	var sh1 := _w(&"shuriken_iron", "Iron Shuriken", "Star-shaped throwing irons.",
		Item.WeaponType.SHURIKEN, Item.Rarity.BASIC, 1, 9.0,
		Item.Element.PHYSICAL, 0.0, 1.70, 10.0)
	sh1.stack_size = 80

	var sh2 := _w(&"shuriken_poisoned", "Poisoned Shuriken", "Tipped with the venom of a Verdant Wound serpent.",
		Item.WeaponType.SHURIKEN, Item.Rarity.RARE, 15, 30.0,
		Item.Element.NATURE, 0.40, 1.70, 12.0)
	sh2.stack_size = 60
	sh2.implicit_text = "Each hit applies poison (3 damage/sec for 6 sec)."

	var sh3 := _w(&"shuriken_lightning", "Lightning-Etched Shuriken", "The runes hum on a clear day.",
		Item.WeaponType.SHURIKEN, Item.Rarity.VERY_RARE, 38, 90.0,
		Item.Element.LIGHTNING, 0.50, 1.75, 14.0)
	sh3.stack_size = 60
	sh3.implicit_text = "Hits chain to one nearby enemy at 50% damage."

# ================================================================
# 2H POLEARMS
# ================================================================
func _build_polearms() -> void:
	_w(&"polearm_spear", "Crown Spear", "Footsoldier issue.",
		Item.WeaponType.POLEARM, Item.Rarity.BASIC, 4, 32.0,
		Item.Element.PHYSICAL, 0.0, 0.95, 4.0, true).dexterity_bonus = 4.0

	_w(&"polearm_glaive", "Cradle Glaive", "Curved blade on a long pole. Mountain village standard.",
		Item.WeaponType.POLEARM, Item.Rarity.COMMON, 12, 60.0,
		Item.Element.PHYSICAL, 0.0, 0.90, 4.5, true).dexterity_bonus = 9.0

	var pl3 := _w(&"polearm_thorn_pike", "Thorn-Pike", "Druid weapon, the haft is a still-living thorn-vine.",
		Item.WeaponType.POLEARM, Item.Rarity.RARE, 28, 130.0,
		Item.Element.NATURE, 0.30, 0.95, 4.5, true,
		[&"chaos_druid"])
	pl3.dexterity_bonus = 14.0
	pl3.intellect_bonus = 8.0
	pl3.implicit_text = "Druid only. Hits poison and root briefly."

	var pl4 := _w(&"polearm_kingu_lesser", "Kingu's Lesser Spear", "A spear forged in imitation of Kingu's. Nearly as long. Nearly as cruel.",
		Item.WeaponType.POLEARM, Item.Rarity.VERY_RARE, 60, 240.0,
		Item.Element.SHADOW, 0.25, 0.90, 5.0, true)
	pl4.dexterity_bonus = 22.0
	pl4.strength_bonus = 12.0
	pl4.implicit_text = "Reach +1m. First hit on a target deals double damage."

# ================================================================
# 2H SCYTHES
# ================================================================
func _build_scythes() -> void:
	_w(&"scythe_field", "Field Scythe", "Reaper's tool, repurposed.",
		Item.WeaponType.SCYTHE, Item.Rarity.BASIC, 6, 42.0,
		Item.Element.PHYSICAL, 0.0, 0.80, 3.0, true).dexterity_bonus = 5.0

	var sc2 := _w(&"scythe_blood_cradle", "Blood-Cradle Scythe", "The handle drinks. The blade gives back.",
		Item.WeaponType.SCYTHE, Item.Rarity.RARE, 26, 110.0,
		Item.Element.BLOOD, 0.30, 0.80, 3.2, true)
	sc2.strength_bonus = 14.0
	sc2.implicit_text = "Heals 5% of damage dealt."

	var sc3 := _w(&"scythe_lucifer_pup", "The Fall's Pup", "A scythe Lucifer's lesser servants carry. Trades neatly with him.",
		Item.WeaponType.SCYTHE, Item.Rarity.VERY_RARE, 75, 280.0,
		Item.Element.SHADOW, 0.40, 0.80, 3.5, true,
		[&"demon", &"chaos_druid"])
	sc3.strength_bonus = 22.0
	sc3.intellect_bonus = 18.0
	sc3.implicit_text = "Each kill grants 5 corruption (Demon) or 5 Form Energy (Druid)."

# ================================================================
# 1H FIST
# ================================================================
func _build_fists() -> void:
	_w(&"fist_iron", "Iron Knuckles", "Brass would be too soft.",
		Item.WeaponType.FIST, Item.Rarity.BASIC, 1, 9.0,
		Item.Element.PHYSICAL, 0.0, 1.60, 1.0).strength_bonus = 1.0

	var f2 := _w(&"fist_serpent_scale", "Serpent-Scale Wraps", "Made from the shed skin of a Verdant Wound serpent.",
		Item.WeaponType.FIST, Item.Rarity.RARE, 22, 55.0,
		Item.Element.NATURE, 0.30, 1.65, 1.0)
	f2.strength_bonus = 12.0
	f2.implicit_text = "Each hit applies a stacking nature DoT."

# ================================================================
# 1H WHIPS
# ================================================================
func _build_whips() -> void:
	_w(&"whip_leather", "Leather Whip", "Long reach, low damage.",
		Item.WeaponType.WHIP, Item.Rarity.BASIC, 2, 11.0,
		Item.Element.PHYSICAL, 0.0, 1.30, 5.0).dexterity_bonus = 2.0

	var w2 := _w(&"whip_inquisitor", "Inquisitor's Discipline", "Used in the Bone Quarter. Glowing rune-tips.",
		Item.WeaponType.WHIP, Item.Rarity.RARE, 24, 60.0,
		Item.Element.HOLY, 0.30, 1.35, 6.0)
	w2.intellect_bonus = 8.0
	w2.implicit_text = "Hits silence (cancel cast) on a 5% chance."

# ================================================================
# OFF-HAND: SHIELDS
# ================================================================
func _build_shields() -> void:
	var shd1 := Item.new()
	shd1.id = &"shield_buckler"
	shd1.display_name = "Iron Buckler"
	shd1.description = "Small. Cheap. Better than nothing."
	shd1.slot = Item.Slot.WEAPON_OFFHAND
	shd1.offhand_type = Item.OffhandType.SHIELD
	shd1.rarity = Item.Rarity.BASIC
	shd1.item_level = 3
	shd1.armor_bonus = 6.0
	shd1.sell_value = 5
	items[shd1.id] = shd1

	var shd2 := Item.new()
	shd2.id = &"shield_kite"
	shd2.display_name = "Kite Shield"
	shd2.description = "Crown footsoldier issue."
	shd2.slot = Item.Slot.WEAPON_OFFHAND
	shd2.offhand_type = Item.OffhandType.SHIELD
	shd2.rarity = Item.Rarity.COMMON
	shd2.item_level = 9
	shd2.armor_bonus = 14.0
	shd2.implicit_text = "+10% block chance."
	shd2.sell_value = 30
	items[shd2.id] = shd2

	var shd3 := Item.new()
	shd3.id = &"shield_tower"
	shd3.display_name = "Tower Shield"
	shd3.description = "Better as cover than as offense."
	shd3.slot = Item.Slot.WEAPON_OFFHAND
	shd3.offhand_type = Item.OffhandType.SHIELD
	shd3.rarity = Item.Rarity.RARE
	shd3.item_level = 22
	shd3.armor_bonus = 32.0
	shd3.hp_bonus = 60.0
	shd3.implicit_text = "+25% block chance. Reduces move speed by 10%."
	shd3.sell_value = 220
	items[shd3.id] = shd3

	var shd4 := Item.new()
	shd4.id = &"shield_pillar_disc"
	shd4.display_name = "Pillar-Disc Shield"
	shd4.description = "A round shield bound around a polished disc of Edict-stone."
	shd4.slot = Item.Slot.WEAPON_OFFHAND
	shd4.offhand_type = Item.OffhandType.SHIELD
	shd4.rarity = Item.Rarity.VERY_RARE
	shd4.item_level = 50
	shd4.armor_bonus = 65.0
	shd4.magic_resist_bonus = 28.0
	shd4.hp_bonus = 130.0
	shd4.resist_holy = 0.40
	shd4.resist_shadow = 0.20
	shd4.implicit_text = "Perfect parries spawn a holy retaliation pulse (small AOE)."
	shd4.sell_value = 1500
	items[shd4.id] = shd4

# ================================================================
# OFF-HAND: BOOKS
# ================================================================
func _build_offhand_books() -> void:
	var b1 := Item.new()
	b1.id = &"book_apprentice"
	b1.display_name = "Apprentice's Codex"
	b1.description = "Bindings 101. Smudged margins."
	b1.slot = Item.Slot.WEAPON_OFFHAND
	b1.offhand_type = Item.OffhandType.BOOK
	b1.rarity = Item.Rarity.BASIC
	b1.item_level = 2
	b1.intellect_bonus = 3.0
	b1.mana_bonus = 15.0
	items[b1.id] = b1

	var b2 := Item.new()
	b2.id = &"book_burning_pages"
	b2.display_name = "Codex of Burning Pages"
	b2.description = "Some pages are missing. The remaining pages are warm."
	b2.slot = Item.Slot.WEAPON_OFFHAND
	b2.offhand_type = Item.OffhandType.BOOK
	b2.rarity = Item.Rarity.RARE
	b2.item_level = 25
	b2.intellect_bonus = 14.0
	b2.mana_bonus = 50.0
	b2.implicit_text = "Fire spells +20% damage. -10% cast time."
	b2.class_restriction = [&"mage"]
	items[b2.id] = b2

	var b3 := Item.new()
	b3.id = &"book_asaridu_left"
	b3.display_name = "Asaridu's Left-Hand Book"
	b3.description = "Old Asaridu kept his left-hand book on his desk every day for forty years. He never put it away the day he sealed himself in the well."
	b3.slot = Item.Slot.WEAPON_OFFHAND
	b3.offhand_type = Item.OffhandType.BOOK
	b3.rarity = Item.Rarity.VERY_RARE
	b3.item_level = 55
	b3.intellect_bonus = 26.0
	b3.mana_bonus = 110.0
	b3.crit_chance_bonus = 0.10
	b3.implicit_text = "Mana cost -25% on all spells. Spells you have cast in the last 5 sec do +10% damage on next cast."
	b3.class_restriction = [&"mage"]
	items[b3.id] = b3

# ================================================================
# OFF-HAND: TOMES (foci)
# ================================================================
func _build_tomes() -> void:
	var t1 := Item.new()
	t1.id = &"tome_focus_clear"
	t1.display_name = "Clear Focus Crystal"
	t1.description = "Trainer-level focus."
	t1.slot = Item.Slot.WEAPON_OFFHAND
	t1.offhand_type = Item.OffhandType.FOCUS
	t1.rarity = Item.Rarity.COMMON
	t1.item_level = 10
	t1.intellect_bonus = 6.0
	t1.mana_bonus = 25.0
	items[t1.id] = t1

	var t2 := Item.new()
	t2.id = &"tome_lapis_orb"
	t2.display_name = "Lapis Orb of Tides"
	t2.description = "A polished lapis sphere, cool to the touch even in summer."
	t2.slot = Item.Slot.WEAPON_OFFHAND
	t2.offhand_type = Item.OffhandType.FOCUS
	t2.rarity = Item.Rarity.RARE
	t2.item_level = 30
	t2.intellect_bonus = 16.0
	t2.mana_bonus = 60.0
	t2.implicit_text = "Frost spells +25% damage. Targets struck slow by 30% extra."
	items[t2.id] = t2

# ================================================================
# OFF-HAND: PARRYING DAGGERS
# ================================================================
func _build_parrying_daggers() -> void:
	var p1 := Item.new()
	p1.id = &"parrying_dagger_iron"
	p1.display_name = "Iron Parrying Dagger"
	p1.description = "Held in the off-hand, used to deflect."
	p1.slot = Item.Slot.WEAPON_OFFHAND
	p1.offhand_type = Item.OffhandType.PARRYING_DAGGER
	p1.rarity = Item.Rarity.BASIC
	p1.item_level = 4
	p1.dexterity_bonus = 3.0
	p1.implicit_text = "+15% parry window."
	items[p1.id] = p1

	var p2 := Item.new()
	p2.id = &"parrying_dagger_master"
	p2.display_name = "Master's Parrying Stiletto"
	p2.description = "Long, thin, precise."
	p2.slot = Item.Slot.WEAPON_OFFHAND
	p2.offhand_type = Item.OffhandType.PARRYING_DAGGER
	p2.rarity = Item.Rarity.VERY_RARE
	p2.item_level = 50
	p2.dexterity_bonus = 18.0
	p2.crit_chance_bonus = 0.10
	p2.implicit_text = "+50% parry window. Successful parry deals counter-damage."
	items[p2.id] = p2

# ================================================================
# OFF-HAND: QUIVERS
# ================================================================
func _build_quivers() -> void:
	var q1 := Item.new()
	q1.id = &"quiver_leather"
	q1.display_name = "Leather Quiver"
	q1.description = "Holds arrows. Holds them well."
	q1.slot = Item.Slot.WEAPON_OFFHAND
	q1.offhand_type = Item.OffhandType.QUIVER
	q1.rarity = Item.Rarity.BASIC
	q1.item_level = 3
	q1.dexterity_bonus = 3.0
	q1.implicit_text = "+15% bow attack speed."
	items[q1.id] = q1

	var q2 := Item.new()
	q2.id = &"quiver_glade_widow"
	q2.display_name = "The Widow's Quiver"
	q2.description = "Found beside the recurve bow."
	q2.slot = Item.Slot.WEAPON_OFFHAND
	q2.offhand_type = Item.OffhandType.QUIVER
	q2.rarity = Item.Rarity.VERY_RARE
	q2.item_level = 55
	q2.dexterity_bonus = 18.0
	q2.crit_chance_bonus = 0.08
	q2.implicit_text = "+30% bow attack speed. First arrow each second is auto-crit."
	q2.class_restriction = [&"ranger"]
	items[q2.id] = q2

# ================================================================
# OFF-HAND: TOTEMS (Druid)
# ================================================================
func _build_totems() -> void:
	var t1 := Item.new()
	t1.id = &"totem_bone"
	t1.display_name = "Bone Totem"
	t1.description = "First totem druids carve."
	t1.slot = Item.Slot.WEAPON_OFFHAND
	t1.offhand_type = Item.OffhandType.TOTEM
	t1.rarity = Item.Rarity.COMMON
	t1.item_level = 8
	t1.intellect_bonus = 5.0
	t1.implicit_text = "+10% Form Energy regen out of form."
	t1.class_restriction = [&"chaos_druid"]
	items[t1.id] = t1

	var t2 := Item.new()
	t2.id = &"totem_dragon_pup"
	t2.display_name = "Dragon-Pup Totem"
	t2.description = "Carved from a Tiamat-spawn pup's first scale, lost when it grew."
	t2.slot = Item.Slot.WEAPON_OFFHAND
	t2.offhand_type = Item.OffhandType.TOTEM
	t2.rarity = Item.Rarity.VERY_RARE
	t2.item_level = 65
	t2.intellect_bonus = 22.0
	t2.vitality_bonus = 14.0
	t2.implicit_text = "Dragon form duration +50%. Form Energy regen also active in form."
	t2.class_restriction = [&"chaos_druid"]
	items[t2.id] = t2

# ================================================================
# ARMOR: HEADS
# ================================================================
func _build_helms() -> void:
	_armor(&"helm_leather", "Leather Cap", "Better than no cap.",
		Item.Slot.HEAD, Item.Rarity.BASIC, 1, 8.0, 3.0, 0.0, [], Item.ArmorType.LEATHER)
	_armor(&"helm_iron", "Iron Helm", "Standard infantry kit.",
		Item.Slot.HEAD, Item.Rarity.COMMON, 6, 18.0, 8.0, 0.0, [], Item.ArmorType.PLATE)
	_armor(&"helm_circlet_apprentice", "Apprentice's Circlet", "Costume-grade. Adds focus.",
		Item.Slot.HEAD, Item.Rarity.COMMON, 8, 14.0, 4.0, 0.0, [], Item.ArmorType.CLOTH).intellect_bonus = 6.0
	_armor(&"helm_steppe_skull", "Steppe Skull-Cap", "Berserker tradition; carved from an enemy you respected.",
		Item.Slot.HEAD, Item.Rarity.RARE, 18, 35.0, 14.0, 0.0, [], Item.ArmorType.PLATE).strength_bonus = 8.0
	_armor(&"helm_inquisitor_hood", "Inquisitor's Hood", "Black cloth, brass mask underneath.",
		Item.Slot.HEAD, Item.Rarity.RARE, 22, 30.0, 12.0, 0.0, [], Item.ArmorType.CLOTH).intellect_bonus = 12.0
	var hl6 := _armor(&"helm_pillar_diadem", "Pillar-Stone Diadem", "Carved from a chip of the Edict pillar.",
		Item.Slot.HEAD, Item.Rarity.VERY_RARE, 55, 90.0, 28.0, 0.0, [], Item.ArmorType.CLOTH)
	hl6.intellect_bonus = 18.0
	hl6.crit_chance_bonus = 0.06
	hl6.resist_shadow = 0.20
	hl6.implicit_text = "Spells crit +6%. Holy spells +15%."

# ================================================================
# ARMOR: CHESTS
# ================================================================
func _build_chests() -> void:
	_armor(&"chest_leather", "Leather Cuirass", "Basic.",
		Item.Slot.CHEST, Item.Rarity.BASIC, 1, 18.0, 6.0, 0.0, [], Item.ArmorType.LEATHER)
	_armor(&"chest_iron", "Iron Brigandine", "Standard.",
		Item.Slot.CHEST, Item.Rarity.COMMON, 7, 38.0, 18.0, 0.0, [], Item.ArmorType.MAIL)
	_armor(&"chest_robe_apprentice", "Apprentice's Robe", "Cloth and pockets.",
		Item.Slot.CHEST, Item.Rarity.COMMON, 8, 28.0, 4.0, 12.0, [], Item.ArmorType.CLOTH).intellect_bonus = 8.0
	var ch4 := _armor(&"chest_water_disciple", "Water Disciple's Gi", "Water Breathing temple uniform.",
		Item.Slot.CHEST, Item.Rarity.RARE, 18, 52.0, 16.0, 8.0, [], Item.ArmorType.LEATHER)
	ch4.dexterity_bonus = 10.0
	ch4.class_restriction = [&"ronin"]
	ch4.implicit_text = "Water Forms +10% damage."
	var ch5 := _armor(&"chest_kazat_iron_plate", "Kazat's Iron-Faced Plate", "Heavy. Smells of old blood.",
		Item.Slot.CHEST, Item.Rarity.RARE, 25, 80.0, 32.0, 0.0, [], Item.ArmorType.PLATE)
	ch5.strength_bonus = 14.0
	var ch6 := _armor(&"chest_pillar_robe", "Pillar-Threaded Robe", "Robe woven with single threads of Edict-stone.",
		Item.Slot.CHEST, Item.Rarity.VERY_RARE, 55, 130.0, 22.0, 50.0, [], Item.ArmorType.CLOTH)
	ch6.intellect_bonus = 26.0
	ch6.mana_bonus = 80.0
	ch6.resist_holy = 0.30
	ch6.implicit_text = "Spells cost -10% mana."

# ================================================================
# ARMOR: LEGS
# ================================================================
func _build_legs() -> void:
	_armor(&"legs_leather_pants", "Leather Pants", "Functional.",
		Item.Slot.LEGS, Item.Rarity.BASIC, 1, 14.0, 5.0, 0.0, [], Item.ArmorType.LEATHER)
	_armor(&"legs_iron_greaves", "Iron Greaves", "Standard footsoldier.",
		Item.Slot.LEGS, Item.Rarity.COMMON, 7, 28.0, 14.0, 0.0, [], Item.ArmorType.PLATE)
	_armor(&"legs_hakama", "Disciple's Hakama", "Pleated and split for breathing-form footwork.",
		Item.Slot.LEGS, Item.Rarity.RARE, 18, 38.0, 12.0, 8.0, [], Item.ArmorType.LEATHER).dexterity_bonus = 10.0
	var lg4 := _armor(&"legs_storm_walker", "Storm-Walker Greaves", "Run faster in lightning.",
		Item.Slot.LEGS, Item.Rarity.VERY_RARE, 50, 95.0, 26.0, 20.0, [], Item.ArmorType.MAIL)
	lg4.dexterity_bonus = 18.0
	lg4.move_speed_bonus = 0.10
	lg4.resist_lightning = 0.30

# ================================================================
# ARMOR: BOOTS
# ================================================================
func _build_boots() -> void:
	_armor(&"boots_leather", "Leather Boots", "Walks fine.",
		Item.Slot.FEET, Item.Rarity.BASIC, 1, 6.0, 2.0, 0.0, [], Item.ArmorType.LEATHER)
	_armor(&"boots_sabaton", "Iron Sabatons", "Heavy. Loud.",
		Item.Slot.FEET, Item.Rarity.COMMON, 7, 14.0, 8.0, 0.0, [], Item.ArmorType.PLATE)
	var bt3 := _armor(&"boots_dancer", "Dancer's Boots", "Light. Silent.",
		Item.Slot.FEET, Item.Rarity.RARE, 22, 22.0, 6.0, 4.0, [], Item.ArmorType.LEATHER)
	bt3.dexterity_bonus = 12.0
	bt3.move_speed_bonus = 0.08
	var bt4 := _armor(&"boots_silent_step", "The Silent Step", "Whisper Shrine senior-disciple boots. Make no sound on stone.",
		Item.Slot.FEET, Item.Rarity.VERY_RARE, 50, 55.0, 16.0, 12.0)
	bt4.dexterity_bonus = 20.0
	bt4.crit_chance_bonus = 0.06
	bt4.move_speed_bonus = 0.12
	bt4.class_restriction = [&"assassin"]
	bt4.implicit_text = "Footsteps inaudible. +25% damage from stealth."

# ================================================================
# ARMOR: GLOVES
# ================================================================
func _build_gloves() -> void:
	_armor(&"gloves_leather", "Leather Gloves", "Hand cover.",
		Item.Slot.HANDS, Item.Rarity.BASIC, 1, 6.0, 2.0, 0.0, [], Item.ArmorType.LEATHER)
	_armor(&"gloves_iron_gauntlets", "Iron Gauntlets", "Knuckle-bashers.",
		Item.Slot.HANDS, Item.Rarity.COMMON, 7, 14.0, 8.0, 0.0, [], Item.ArmorType.PLATE).strength_bonus = 4.0
	var gv3 := _armor(&"gloves_archer", "Archer's Bracers", "Right hand string-grooved.",
		Item.Slot.HANDS, Item.Rarity.RARE, 20, 22.0, 8.0, 0.0, [], Item.ArmorType.LEATHER)
	gv3.dexterity_bonus = 12.0
	gv3.implicit_text = "Bow draw time -20%."
	var gv4 := _armor(&"gloves_burning_palm", "Burning-Palm Wraps", "Flame Breathing senior monks wrap their hands like this.",
		Item.Slot.HANDS, Item.Rarity.VERY_RARE, 48, 50.0, 14.0, 0.0, [], Item.ArmorType.LEATHER)
	gv4.dexterity_bonus = 14.0
	gv4.crit_chance_bonus = 0.06
	gv4.implicit_text = "Flame Forms +15% damage. Ignite duration +50%."

# ================================================================
# ARMOR: CLOAKS (BACK)
# ================================================================
func _build_cloaks() -> void:
	_armor(&"cloak_traveler", "Traveler's Cloak", "Wool. Practical.",
		Item.Slot.BACK, Item.Rarity.BASIC, 2, 8.0, 4.0)
	var ck2 := _armor(&"cloak_mist_shroud", "Mist Shroud", "Mist Vale temple weave; you blur a little when you stand still.",
		Item.Slot.BACK, Item.Rarity.RARE, 30, 25.0, 10.0, 10.0)
	ck2.dexterity_bonus = 10.0
	ck2.implicit_text = "Take 10% less damage while stationary."
	var ck3 := _armor(&"cloak_sun_bearer", "Sun-Bearer's Mantle", "Worn in Babilim by retired Sun-Sworn.",
		Item.Slot.BACK, Item.Rarity.VERY_RARE, 60, 60.0, 18.0, 18.0)
	ck3.intellect_bonus = 12.0
	ck3.resist_holy = 0.30
	ck3.resist_shadow = 0.20
	ck3.implicit_text = "Heal 1% HP per sec while above 50% HP."

# ================================================================
# ARMOR: BELTS
# ================================================================
func _build_belts() -> void:
	_armor(&"belt_leather", "Leather Belt", "Holds the rest up.",
		Item.Slot.BELT, Item.Rarity.BASIC, 1, 4.0, 1.0)
	var bl2 := _armor(&"belt_war", "War Belt", "Steel-buckled, pouch-rigged.",
		Item.Slot.BELT, Item.Rarity.COMMON, 8, 12.0, 4.0)
	bl2.strength_bonus = 4.0
	bl2.implicit_text = "+1 consumable slot."
	var bl3 := _armor(&"belt_pirate_kings_sash", "Pirate-King's Sash", "Worn by all three Black-Sails. They started with one.",
		Item.Slot.BELT, Item.Rarity.RARE, 30, 22.0, 6.0)
	bl3.dexterity_bonus = 10.0
	bl3.implicit_text = "+10% gold from kills."
	var bl4 := _armor(&"belt_storm_girdle", "Storm Girdle", "Thunder Highlands forge work. The buckle hums.",
		Item.Slot.BELT, Item.Rarity.VERY_RARE, 55, 50.0, 14.0)
	bl4.strength_bonus = 12.0
	bl4.dexterity_bonus = 8.0
	bl4.resist_lightning = 0.40

# ================================================================
# ACCESSORIES: AMULETS
# ================================================================
func _build_amulets() -> void:
	var a1 := _accessory(&"amulet_simple", "Simple Amulet", "Bronze, plain chain.",
		Item.Slot.AMULET, Item.Rarity.BASIC, 1)
	a1.hp_bonus = 10.0

	var a2 := _accessory(&"amulet_lapis_drop", "Lapis Drop", "Lapis Bay craftsmanship.",
		Item.Slot.AMULET, Item.Rarity.COMMON, 12)
	a2.intellect_bonus = 6.0
	a2.mana_bonus = 25.0

	var a3 := _accessory(&"amulet_storyteller", "The Storyteller's Token", "She gave one to each of the six. Yours.",
		Item.Slot.AMULET, Item.Rarity.RARE, 8, )
	a3.hp_bonus = 30.0
	a3.implicit_text = "When HP would drop below 20%, restore to 25% (once per dungeon). Cooldown 600s."

	var a4 := _accessory(&"amulet_sun_drop", "Sun-Drop", "A bead of melted sun-temple gold from the days when Sun Breathing still had a temple.",
		Item.Slot.AMULET, Item.Rarity.VERY_RARE, 60)
	a4.hp_bonus = 80.0
	a4.intellect_bonus = 15.0
	a4.crit_chance_bonus = 0.06
	a4.resist_shadow = 0.25
	a4.implicit_text = "+10% damage to demons and undead."

# ================================================================
# ACCESSORIES: RINGS (RING_LEFT and RING_RIGHT both accept these)
# ================================================================
func _build_rings() -> void:
	# Rings register to RING_LEFT slot for cataloging; both ring slots accept any ring.
	var r1 := _accessory(&"ring_iron", "Iron Band", "Plain.",
		Item.Slot.RING_LEFT, Item.Rarity.BASIC, 1)
	r1.hp_bonus = 5.0

	var r2 := _accessory(&"ring_bronze_strength", "Bronze Ring of Strength", "Cheap charm. Works.",
		Item.Slot.RING_LEFT, Item.Rarity.COMMON, 8)
	r2.strength_bonus = 5.0

	var r3 := _accessory(&"ring_silver_dexterity", "Silver Ring of Dexterity", "Worth tilting at.",
		Item.Slot.RING_LEFT, Item.Rarity.COMMON, 8)
	r3.dexterity_bonus = 5.0

	var r4 := _accessory(&"ring_gold_intellect", "Gold Ring of Intellect", "Heavier than it looks.",
		Item.Slot.RING_LEFT, Item.Rarity.COMMON, 8)
	r4.intellect_bonus = 5.0

	var r5 := _accessory(&"ring_blood", "Blood Ring", "Gem in the center is not a gem.",
		Item.Slot.RING_LEFT, Item.Rarity.RARE, 22)
	r5.hp_bonus = 60.0
	r5.implicit_text = "+5% damage when below 50% HP."

	var r6 := _accessory(&"ring_focus", "Focus Ring", "Mages set bigger gems in this band.",
		Item.Slot.RING_LEFT, Item.Rarity.RARE, 22)
	r6.intellect_bonus = 12.0
	r6.mana_bonus = 40.0
	r6.implicit_text = "Crit kills with spells refund 20% mana."

	var r7 := _accessory(&"ring_pillar_seal", "Pillar Seal Ring", "A Crown signet from the Iron Pillar offices.",
		Item.Slot.RING_LEFT, Item.Rarity.VERY_RARE, 55)
	r7.hp_bonus = 100.0
	r7.intellect_bonus = 14.0
	r7.armor_bonus = 12.0
	r7.resist_shadow = 0.20
	r7.implicit_text = "All damage reduction +5%."

	var r8 := _accessory(&"ring_kingu_marker", "Kingu's Marker Ring", "He wore this to single combats.",
		Item.Slot.RING_LEFT, Item.Rarity.VERY_RARE, 70)
	r8.strength_bonus = 18.0
	r8.dexterity_bonus = 14.0
	r8.crit_chance_bonus = 0.10
	r8.crit_multiplier_bonus = 0.30

# ================================================================
# ACCESSORIES: CHARMS
# ================================================================
func _build_charms() -> void:
	var c1 := _accessory(&"charm_traveler", "Traveler's Pebble", "Picked up the day you left home.",
		Item.Slot.CHARM, Item.Rarity.COMMON, 5)
	c1.hp_bonus = 15.0

	var c2 := _accessory(&"charm_breathing_stone", "Breathing Stone", "Six-Breath students rub these for luck.",
		Item.Slot.CHARM, Item.Rarity.RARE, 25)
	c2.dexterity_bonus = 10.0
	c2.implicit_text = "+1 stance charge max (Ronin only)."
	c2.class_restriction = [&"ronin"]

	var c3 := _accessory(&"charm_inkstone_seal", "Inkstone Seal Charm", "A wax seal preserved in resin.",
		Item.Slot.CHARM, Item.Rarity.VERY_RARE, 50)
	c3.intellect_bonus = 18.0
	c3.mana_bonus = 80.0
	c3.implicit_text = "Mana regen +25%."
	c3.class_restriction = [&"mage"]

	var c4 := _accessory(&"charm_sanctum_petal", "Sanctum-Mother's Petal", "A pressed petal from the Mother-Tree.",
		Item.Slot.CHARM, Item.Rarity.VERY_RARE, 50)
	c4.intellect_bonus = 14.0
	c4.vitality_bonus = 10.0
	c4.implicit_text = "Form duration +25% (Druid only)."
	c4.class_restriction = [&"chaos_druid"]

	# Paladin charms
	var c5 := _accessory(&"charm_oath_locket", "Oath-Locket", "Engraved with Marduk's seal. Worn by sworn Guardians.",
		Item.Slot.CHARM, Item.Rarity.RARE, 20)
	c5.vitality_bonus = 14.0
	c5.implicit_text = "Allies in 8m gain +5 HP regen while you are alive."
	c5.class_restriction = [&"paladin_guardian"]

	var c6 := _accessory(&"charm_sun_phylactery", "Sun-Phylactery", "Lightbringer's prayer-beads. The center bead is gold.",
		Item.Slot.CHARM, Item.Rarity.RARE, 20)
	c6.intellect_bonus = 14.0
	c6.implicit_text = "Healing spells +20% effective."
	c6.class_restriction = [&"paladin_lightbringer"]

func _build_paladin_weapons() -> void:
	# Tank-focused war hammers (1H + shield combat)
	_w(&"hammer_iron", "Iron War-Hammer", "Heavy-headed hammer, simple grip.",
		Item.WeaponType.BLUDGEON, Item.Rarity.BASIC, 4, 24.0,
		Item.Element.PHYSICAL, 0.0, 0.95, 1.8).strength_bonus = 4.0

	var hm2 := _w(&"hammer_crown_warhammer", "Crown War-Hammer", "Babilim's heavy infantry standard, paladin-grade.",
		Item.WeaponType.BLUDGEON, Item.Rarity.RARE, 22, 70.0,
		Item.Element.HOLY, 0.20, 0.95, 1.9, false,
		[&"paladin_guardian", &"paladin_lightbringer"])
	hm2.strength_bonus = 12.0
	hm2.intellect_bonus = 8.0
	hm2.implicit_text = "Holy hits +20% damage to demons and undead."

	var hm3 := _w(&"hammer_sun_brand", "Sun-Brand War-Hammer", "The hammer that broke the door at the Outer Citadel.",
		Item.WeaponType.BLUDGEON, Item.Rarity.VERY_RARE, 55, 195.0,
		Item.Element.HOLY, 0.40, 1.00, 2.0, false,
		[&"paladin_guardian"])
	hm3.strength_bonus = 22.0
	hm3.vitality_bonus = 12.0
	hm3.implicit_text = "Guardian only. Strikes restore 15 mana to caster."

	var hm4 := _w(&"hammer_lightbringers_mace", "Lightbringer's Mace", "Gilded ceremonial mace, sharp prayer-script up the haft.",
		Item.WeaponType.BLUDGEON, Item.Rarity.VERY_RARE, 55, 145.0,
		Item.Element.HOLY, 0.50, 1.05, 1.9, false,
		[&"paladin_lightbringer"])
	hm4.intellect_bonus = 22.0
	hm4.implicit_text = "Lightbringer only. Healing spells +25% effective. Hits restore 5 mana."

	# Paladin shields
	var psh1 := Item.new()
	psh1.id = &"shield_paladin_kite"
	psh1.display_name = "Paladin's Kite-Shield"
	psh1.description = "Iron rim, embossed sun motif on the boss."
	psh1.slot = Item.Slot.WEAPON_OFFHAND
	psh1.offhand_type = Item.OffhandType.SHIELD
	psh1.rarity = Item.Rarity.RARE
	psh1.item_level = 18
	psh1.armor_bonus = 25.0
	psh1.hp_bonus = 50.0
	psh1.implicit_text = "+15% block. Allies within 5m take 5% less damage."
	psh1.class_restriction = [&"paladin_guardian", &"paladin_lightbringer"]
	psh1.sell_value = 200
	items[psh1.id] = psh1

	var psh2 := Item.new()
	psh2.id = &"shield_dawn_bulwark"
	psh2.display_name = "Dawn Bulwark"
	psh2.description = "A tower shield said to have stopped Tiamat-spawn for an hour while a Lightbringer healed behind it."
	psh2.slot = Item.Slot.WEAPON_OFFHAND
	psh2.offhand_type = Item.OffhandType.SHIELD
	psh2.rarity = Item.Rarity.VERY_RARE
	psh2.item_level = 60
	psh2.armor_bonus = 80.0
	psh2.magic_resist_bonus = 35.0
	psh2.hp_bonus = 220.0
	psh2.resist_holy = 0.30
	psh2.resist_shadow = 0.30
	psh2.implicit_text = "+30% block. Perfect blocks heal 5% HP. Allies within 8m take 8% less damage."
	psh2.class_restriction = [&"paladin_guardian"]
	psh2.sell_value = 2200
	items[psh2.id] = psh2

	# Plate set sample for Paladin Guardian
	_armor(&"chest_paladin_plate", "Sun-Plate Cuirass", "Iron-Crown forge work. Sun-disc on the breast.",
		Item.Slot.CHEST, Item.Rarity.RARE, 22, 110.0, 42.0, 14.0,
		[&"paladin_guardian"], Item.ArmorType.PLATE).strength_bonus = 8.0

	_armor(&"helm_paladin_great", "Sun-Great Helm", "Visor closes; the slit is sun-shaped.",
		Item.Slot.HEAD, Item.Rarity.RARE, 22, 60.0, 24.0, 8.0,
		[&"paladin_guardian"], Item.ArmorType.PLATE).vitality_bonus = 8.0

	_armor(&"chest_lightbringer_mail", "Sun-Mail Hauberk", "Mail set woven with prayer-rings.",
		Item.Slot.CHEST, Item.Rarity.RARE, 22, 70.0, 24.0, 22.0,
		[&"paladin_lightbringer"], Item.ArmorType.MAIL).intellect_bonus = 12.0

# ================================================================
# POTIONS (consumable)
# ================================================================
func _build_potions() -> void:
	# Health potions (instant heal)
	for tier in [
		{"id": &"potion_hp_minor", "name": "Minor Health Potion", "ilvl": 1, "rarity": Item.Rarity.BASIC, "heal": 75.0, "value": 25, "stack": 20},
		{"id": &"potion_hp_lesser", "name": "Lesser Health Potion", "ilvl": 10, "rarity": Item.Rarity.COMMON, "heal": 200.0, "value": 60, "stack": 20},
		{"id": &"potion_hp_greater", "name": "Greater Health Potion", "ilvl": 25, "rarity": Item.Rarity.COMMON, "heal": 500.0, "value": 150, "stack": 20},
		{"id": &"potion_hp_major", "name": "Major Health Potion", "ilvl": 45, "rarity": Item.Rarity.RARE, "heal": 1200.0, "value": 400, "stack": 20},
		{"id": &"potion_hp_supreme", "name": "Supreme Health Potion", "ilvl": 70, "rarity": Item.Rarity.RARE, "heal": 3000.0, "value": 950, "stack": 20},
	]:
		_make_potion(tier["id"], tier["name"], "Restores %d HP instantly." % int(tier["heal"]),
			tier["ilvl"], tier["rarity"], tier["heal"], 0.0, [], int(tier["value"]), int(tier["stack"]))

	# Mana potions (instant mana refill, Mage / casters)
	for tier in [
		{"id": &"potion_mana_minor", "name": "Minor Mana Potion", "ilvl": 1, "rarity": Item.Rarity.BASIC, "mana": 50.0, "value": 25, "stack": 20},
		{"id": &"potion_mana_lesser", "name": "Lesser Mana Potion", "ilvl": 10, "rarity": Item.Rarity.COMMON, "mana": 100.0, "value": 60, "stack": 20},
		{"id": &"potion_mana_greater", "name": "Greater Mana Potion", "ilvl": 25, "rarity": Item.Rarity.COMMON, "mana": 200.0, "value": 150, "stack": 20},
		{"id": &"potion_mana_major", "name": "Major Mana Potion", "ilvl": 45, "rarity": Item.Rarity.RARE, "mana": 500.0, "value": 400, "stack": 20},
	]:
		_make_potion(tier["id"], tier["name"], "Restores %d Mana instantly." % int(tier["mana"]),
			tier["ilvl"], tier["rarity"], 0.0, tier["mana"], [], int(tier["value"]), int(tier["stack"]))

	# Surge potions (10x regen for 10 sec)
	_make_potion(&"potion_mana_surge", "Mana Surge Draught",
		"Mana regen accelerates 10x for 10 seconds.",
		15, Item.Rarity.RARE, 0.0, 0.0, [&"surge_mana"], 200, 10)

	_make_potion(&"potion_hp_surge", "Lifeblood Surge",
		"HP regen accelerates 10x for 10 seconds.",
		15, Item.Rarity.RARE, 0.0, 0.0, [&"surge_hp"], 200, 10)

	# Stamina potions (instant + surge)
	_make_potion(&"potion_stamina_minor", "Minor Stamina Potion",
		"Restores 100 stamina (full bar) instantly. For Assassin, Ronin, Ranger.",
		1, Item.Rarity.BASIC, 0.0, 0.0, [&"restore_stamina"], 30, 20)

	_make_potion(&"potion_stamina_surge", "Stamina Surge Draught",
		"Stamina regen accelerates 10x for 10 seconds.",
		15, Item.Rarity.RARE, 0.0, 0.0, [&"surge_stamina"], 200, 10)

	# Combo potion: Champion's Draught (lvl 50+ all-three boost)
	var combo := _make_potion(&"potion_champions_draught", "Champion's Draught",
		"Restores 500 HP, 200 Mana, 100 Stamina. Surges all three for 10 seconds.",
		50, Item.Rarity.VERY_RARE, 500.0, 200.0,
		[&"surge_mana", &"surge_hp", &"surge_stamina", &"restore_stamina"], 1500, 5)
	combo.implicit_text = "All resource regen 10x for 10 seconds."

func _make_potion(id: StringName, name: String, desc: String,
		ilvl: int, rarity: int, heal: float, mana: float,
		tags: Array, value: int, stack: int) -> Item:
	var p := Item.new()
	p.id = id
	p.display_name = name
	p.description = desc
	p.slot = Item.Slot.NONE
	p.rarity = rarity
	p.item_level = ilvl
	p.stack_size = stack
	p.heal_amount = heal
	p.mana_amount = mana
	for t in tags:
		p.unique_tags.append(StringName(t))
	p.sell_value = value
	items[id] = p
	return p
