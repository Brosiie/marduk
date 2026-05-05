extends Resource
class_name PlayerClass

# A class is a Resource so it can be saved as .tres and edited in inspector.
# Each class is data: starting stats, growth, primary attribute, signature abilities, skill tree.

@export var class_id: StringName = &"warrior"
@export var display_name: String = "Warrior"
@export_multiline var lore: String = ""

# Base stats at level 1
@export_group("Base Stats")
@export var base_hp: float = 120.0
@export var base_mana: float = 30.0
@export var base_strength: int = 14
@export var base_dexterity: int = 10
@export var base_intellect: int = 8
@export var base_vitality: int = 14

# Per-level growth (linear; non-linear curves hook via gain_xp signal in PlayerStats)
@export_group("Growth")
@export var hp_per_level: float = 12.0
@export var mana_per_level: float = 3.0
@export var strength_per_level: float = 1.0
@export var dexterity_per_level: float = 0.6
@export var intellect_per_level: float = 0.4
@export var vitality_per_level: float = 0.8

# Mechanics
@export_group("Mechanics")
@export var primary_attribute: StringName = &"strength"  # used by damage calc to scale phys damage
@export var spell_attribute: StringName = &"intellect"   # used to scale spell damage
@export var armor: float = 5.0
@export var magic_resist: float = 5.0
@export var crit_chance: float = 0.05
@export var crit_multiplier: float = 1.75

@export_group("Abilities and Tree")
@export var starting_abilities: Array[Ability] = []
@export var skill_tree: SkillTree

# Resource mechanic. Mana is default; classes can override with rage/focus/stance/corruption/etc.
# The HUD reads this to label the secondary bar correctly and Player uses it for spend logic.
@export_group("Resource System")
@export var resource_mechanic: StringName = &"mana"  # mana, rage, focus, stance, corruption, form_energy
@export var resource_max: float = 50.0
@export var resource_regen_per_sec: float = 1.5

# Unlock gating. Most classes are available from creation. Demon is locked behind defeating Lucifer.
@export_group("Unlock Gating")
@export var unlocked_by_default: bool = true
@export var unlock_save_flag: StringName = &""  # eg &"lucifer_defeated" for Demon
@export_multiline var unlock_hint: String = ""  # shown in character creator when locked

# Druid-only: forms the player can shapeshift into. Empty for non-druids.
@export_group("Shapeshift (Druid only)")
@export var available_forms: Array[Transformation] = []

# Armor cap: highest armor material this class may wear. CLOTH = mages only,
# LEATHER = rogues/rangers/druids/ronin, MAIL = healers/rangers, PLATE = tanks/berserkers.
@export_group("Armor Restriction")
@export var max_armor_type: int = Item.ArmorType.PLATE  # default: all allowed; class registry sets per-class

# Spec grouping: classes sharing a spec_group_id appear together in CharacterCreation.
# Eg paladin_tank and paladin_healer both have spec_group_id = &"paladin".
@export_group("Spec Grouping")
@export var spec_group_id: StringName = &""
@export var spec_role: StringName = &""  # eg &"tank", &"healer", &"dps"
