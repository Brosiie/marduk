extends Resource
class_name Item

# An equippable / consumable / quest item. Defined as a Resource so designers
# can author .tres files in the inspector OR factory-build via ItemRegistry.

# === Equipment slots (13 total) ===
enum Slot {
	NONE,
	WEAPON_MAIN,
	WEAPON_OFFHAND,    # shield, off-hand book, parrying dagger, focus, totem
	HEAD,              # helm, hood, circlet, mask
	CHEST,             # plate, robe, leather, gi
	LEGS,              # greaves, leggings, hakama, skirts
	FEET,              # boots, sandals, sabaton
	HANDS,             # gauntlets, gloves, wraps
	BACK,              # cloak, cape, mantle
	BELT,              # girdle, sash, war-belt
	RING_LEFT,
	RING_RIGHT,
	AMULET,            # necklace
	CHARM              # accessory, class-specific bonuses
}

# === Weapon variety ===
enum WeaponType {
	NONE,
	SWORD,
	GREATSWORD,        # 2H
	AXE,
	GREATAXE,          # 2H
	BLUDGEON,          # mace, club, mace-and-chain
	GREAT_BLUDGEON,    # 2H maul, hammer
	STAFF,             # 2H caster, also Druid weapon
	WAND,              # 1H caster
	KATANA,            # Ronin signature
	NODACHI,           # 2H katana
	DAGGER,            # Assassin signature, off-hand-able
	BOW,               # 2H ranged
	CROSSBOW,          # 2H ranged, slower harder
	THROWING_KNIVES,   # consumable stack, can off-hand
	SHURIKEN,          # consumable stack
	POLEARM,           # 2H, spear/glaive
	SCYTHE,            # 2H
	FIST,              # 1H punch weapons
	WHIP               # 1H, reach
}

# === Off-hand variety (when not wielding 2H) ===
enum OffhandType {
	NONE,
	SHIELD,            # tower, kite, buckler
	BOOK,              # spellbook, codex
	TOME,              # focus, orb
	TOTEM,             # Druid spirit-totem
	PARRYING_DAGGER,
	FOCUS,             # mage focus crystal
	QUIVER             # ranger arrow capacity bonus
}

# === Damage element / school ===
enum Element {
	PHYSICAL,
	FIRE,
	FROST,
	LIGHTNING,
	ARCANE,
	HOLY,
	SHADOW,
	VOID,
	NATURE,
	BLOOD
}

# Armor material tiers, lightest to heaviest. Class.max_armor_type caps wearable items.
# NONE applies to non-armor slots (weapons, accessories, cloaks, belts).
enum ArmorType {
	NONE,
	CLOTH,    # Mages: lowest armor, +intellect/spellpower bias
	LEATHER,  # Assassins/Rangers/Druids/Ronin: light armor, +dex bias
	MAIL,     # Paladin Healer / mid-armor classes: balanced
	PLATE     # Berserker, Demon, Paladin Tank: heaviest, +strength/vitality bias
}

enum Rarity {
	JUNK, BASIC, COMMON, RARE, VERY_RARE, LEGENDARY, HEAVEN
}

@export var id: StringName = &""
@export var display_name: String = ""
@export_multiline var description: String = ""
@export var icon: Texture2D
@export var mesh_scene: PackedScene  # for ground display + on-character render

@export_group("Classification")
@export var slot: Slot = Slot.NONE
@export var weapon_type: WeaponType = WeaponType.NONE  # NONE for non-weapons
@export var offhand_type: OffhandType = OffhandType.NONE  # NONE for main weapons / armor
@export var armor_type: ArmorType = ArmorType.NONE  # NONE for non-armor; cap-checked vs class
@export var rarity: Rarity = Rarity.COMMON
@export var stack_size: int = 1
@export var item_level: int = 1
@export var class_restriction: Array[StringName] = []  # empty = any class
@export var is_two_handed: bool = false  # locks WEAPON_OFFHAND when equipped

@export_group("Damage (weapons only)")
@export var base_damage: float = 0.0  # physical + element split below
@export var element: Element = Element.PHYSICAL
@export var element_damage_pct: float = 0.0  # 0.0 = pure physical, 0.5 = half element on top
@export var attack_speed: float = 1.0  # 1.0 = baseline, 0.7 = slow great-weapon, 1.3 = fast dagger
@export var weapon_range: float = 2.0   # metres reach (long for spears, short for fists)

@export_group("Equipment Stats")
@export var hp_bonus: float = 0.0
@export var mana_bonus: float = 0.0
@export var strength_bonus: float = 0.0
@export var dexterity_bonus: float = 0.0
@export var intellect_bonus: float = 0.0
@export var vitality_bonus: float = 0.0
@export var armor_bonus: float = 0.0
@export var magic_resist_bonus: float = 0.0
@export var crit_chance_bonus: float = 0.0
@export var crit_multiplier_bonus: float = 0.0
@export var damage_bonus_pct: float = 0.0  # +% all outgoing damage
@export var attack_speed_bonus: float = 0.0
@export var move_speed_bonus: float = 0.0

@export_group("Resistances")
@export var resist_fire: float = 0.0
@export var resist_frost: float = 0.0
@export var resist_lightning: float = 0.0
@export var resist_arcane: float = 0.0
@export var resist_holy: float = 0.0
@export var resist_shadow: float = 0.0
@export var resist_void: float = 0.0

@export_group("Affixes")
@export var implicit_text: String = ""  # base intrinsic effect
@export var prefix_affixes: Array[StringName] = []
@export var suffix_affixes: Array[StringName] = []

@export_group("Consumable (when not equipment)")
@export var heal_amount: float = 0.0
@export var mana_amount: float = 0.0
@export var grants_status: StatusEffect

@export_group("Trade")
@export var sell_value: int = 0
@export var is_quest_item: bool = false
@export var is_soulbound: bool = false
@export var auto_returns_to_inventory: bool = false

@export_group("Unique Mechanics (legendaries)")
@export var unique_tags: Array[StringName] = []
@export var passive_heal_radius: float = 0.0
@export var passive_heal_per_sec: float = 0.0
@export var permanent_dmg_stack_per_kill: float = 0.0

@export_group("Unique Drop")
# When set, this item only drops from a specific source.
@export var unique_drop_source: StringName = &""  # eg &"raid_captain" or &"tiamat"
@export var unique_drop_chance: float = 0.0       # 0.0-1.0 chance from that source

# ----------------------------------------------------------------
# Display helpers
# ----------------------------------------------------------------
func rarity_color() -> Color:
	match rarity:
		Rarity.JUNK:       return Color(0.45, 0.45, 0.45)
		Rarity.BASIC:      return Color(0.95, 0.95, 0.95)
		Rarity.COMMON:     return Color(0.30, 0.85, 0.30)
		Rarity.RARE:       return Color(0.30, 0.55, 1.00)
		Rarity.VERY_RARE:  return Color(0.70, 0.30, 1.00)
		Rarity.LEGENDARY:  return Color(1.00, 0.78, 0.20)
		Rarity.HEAVEN:     return Color(1.00, 1.00, 1.00)
		_: return Color.WHITE

func rarity_name() -> String:
	match rarity:
		Rarity.JUNK: return "Junk"
		Rarity.BASIC: return "Basic"
		Rarity.COMMON: return "Common"
		Rarity.RARE: return "Rare"
		Rarity.VERY_RARE: return "Very Rare"
		Rarity.LEGENDARY: return "Legendary"
		Rarity.HEAVEN: return "Heaven"
		_: return ""

func weapon_type_name() -> String:
	match weapon_type:
		WeaponType.SWORD: return "Sword"
		WeaponType.GREATSWORD: return "Greatsword"
		WeaponType.AXE: return "Axe"
		WeaponType.GREATAXE: return "Greataxe"
		WeaponType.BLUDGEON: return "Bludgeon"
		WeaponType.GREAT_BLUDGEON: return "Maul"
		WeaponType.STAFF: return "Staff"
		WeaponType.WAND: return "Wand"
		WeaponType.KATANA: return "Katana"
		WeaponType.NODACHI: return "Nodachi"
		WeaponType.DAGGER: return "Dagger"
		WeaponType.BOW: return "Bow"
		WeaponType.CROSSBOW: return "Crossbow"
		WeaponType.THROWING_KNIVES: return "Throwing Knives"
		WeaponType.SHURIKEN: return "Shuriken"
		WeaponType.POLEARM: return "Polearm"
		WeaponType.SCYTHE: return "Scythe"
		WeaponType.FIST: return "Fist Weapon"
		WeaponType.WHIP: return "Whip"
		_: return ""

func element_name() -> String:
	match element:
		Element.PHYSICAL: return "Physical"
		Element.FIRE: return "Fire"
		Element.FROST: return "Frost"
		Element.LIGHTNING: return "Lightning"
		Element.ARCANE: return "Arcane"
		Element.HOLY: return "Holy"
		Element.SHADOW: return "Shadow"
		Element.VOID: return "Void"
		Element.NATURE: return "Nature"
		Element.BLOOD: return "Blood"
		_: return ""

func can_be_dropped() -> bool:
	return not is_quest_item and not is_soulbound

func can_be_traded() -> bool:
	return can_be_dropped() and rarity != Rarity.HEAVEN

func can_be_auctioned() -> bool:
	return can_be_traded()

func is_weapon() -> bool:
	return weapon_type != WeaponType.NONE
