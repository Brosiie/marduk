extends Node

# Autoload: maps class -> preferred WeaponTypes -> bonus multiplier.
#
# Wielding a weapon your class specializes in: +20% damage, +10% attack speed (default).
# Wielding a weapon your class is neutral on: 1.0x (no penalty).
# Wielding a weapon explicitly off-class: -10% damage (soft discouragement).
#
# Proficiency layer multiplies into damage_calc, applies on top of all other layers.

const PROFICIENT_DAMAGE_BONUS := 0.20
const NEUTRAL_DAMAGE_BONUS := 0.0
const OFF_CLASS_DAMAGE_PENALTY := -0.10
const PROFICIENT_SPEED_BONUS := 0.10

# class_id -> { weapon_type -> tier } where tier in {"proficient", "neutral", "off"}
var profile: Dictionary = {}

func _ready() -> void:
	_build_berserker()
	_build_assassin()
	_build_ronin()
	_build_ranger()
	_build_mage()
	_build_chaos_druid()
	_build_demon()
	_build_paladin_guardian()
	_build_paladin_lightbringer()

func damage_multiplier_for(class_id: StringName, weapon_type: int) -> float:
	if weapon_type == Item.WeaponType.NONE:
		return 1.0
	var cls_profile: Dictionary = profile.get(class_id, {})
	var tier: String = cls_profile.get(weapon_type, "neutral")
	match tier:
		"proficient": return 1.0 + PROFICIENT_DAMAGE_BONUS
		"off":        return 1.0 + OFF_CLASS_DAMAGE_PENALTY
		_:            return 1.0

func attack_speed_multiplier_for(class_id: StringName, weapon_type: int) -> float:
	var cls_profile: Dictionary = profile.get(class_id, {})
	if cls_profile.get(weapon_type, "neutral") == "proficient":
		return 1.0 + PROFICIENT_SPEED_BONUS
	return 1.0

func is_proficient(class_id: StringName, weapon_type: int) -> bool:
	var cls_profile: Dictionary = profile.get(class_id, {})
	return cls_profile.get(weapon_type, "neutral") == "proficient"

# ----------------------------------------------------------------
# Class profiles
# ----------------------------------------------------------------
func _build_berserker() -> void:
	# Heavy melee, 2H specialists, no caster anything
	profile[&"berserker"] = {
		Item.WeaponType.AXE:             "proficient",
		Item.WeaponType.GREATAXE:        "proficient",
		Item.WeaponType.BLUDGEON:        "proficient",
		Item.WeaponType.GREAT_BLUDGEON:  "proficient",
		Item.WeaponType.GREATSWORD:      "proficient",
		Item.WeaponType.SWORD:           "neutral",
		Item.WeaponType.POLEARM:         "neutral",
		Item.WeaponType.SCYTHE:          "neutral",
		Item.WeaponType.FIST:            "neutral",
		Item.WeaponType.STAFF:           "off",
		Item.WeaponType.WAND:            "off",
		Item.WeaponType.BOW:             "off",
		Item.WeaponType.CROSSBOW:        "off",
		Item.WeaponType.DAGGER:          "off",
	}

func _build_assassin() -> void:
	# Daggers, throwing weapons, shuriken
	profile[&"assassin"] = {
		Item.WeaponType.DAGGER:          "proficient",
		Item.WeaponType.THROWING_KNIVES: "proficient",
		Item.WeaponType.SHURIKEN:        "proficient",
		Item.WeaponType.SWORD:           "neutral",
		Item.WeaponType.WHIP:            "neutral",
		Item.WeaponType.KATANA:          "neutral",
		Item.WeaponType.GREATSWORD:      "off",
		Item.WeaponType.GREATAXE:        "off",
		Item.WeaponType.GREAT_BLUDGEON:  "off",
		Item.WeaponType.STAFF:           "off",
	}

func _build_ronin() -> void:
	# Katanas above all, then nodachi, supplemented by throwing weapons and bows
	profile[&"ronin"] = {
		Item.WeaponType.KATANA:          "proficient",
		Item.WeaponType.NODACHI:         "proficient",
		Item.WeaponType.SWORD:           "neutral",
		Item.WeaponType.DAGGER:          "neutral",
		Item.WeaponType.THROWING_KNIVES: "neutral",
		Item.WeaponType.SHURIKEN:        "neutral",
		Item.WeaponType.BOW:             "neutral",
		Item.WeaponType.POLEARM:         "neutral",
		Item.WeaponType.GREATAXE:        "off",
		Item.WeaponType.GREAT_BLUDGEON:  "off",
		Item.WeaponType.STAFF:           "off",
		Item.WeaponType.WAND:            "off",
	}

func _build_ranger() -> void:
	# Bows primary, crossbows, throwing knives, daggers as backup
	profile[&"ranger"] = {
		Item.WeaponType.BOW:             "proficient",
		Item.WeaponType.CROSSBOW:        "proficient",
		Item.WeaponType.THROWING_KNIVES: "proficient",
		Item.WeaponType.DAGGER:          "neutral",
		Item.WeaponType.SWORD:           "neutral",
		Item.WeaponType.POLEARM:         "neutral",
		Item.WeaponType.STAFF:           "off",
		Item.WeaponType.WAND:            "off",
		Item.WeaponType.GREATSWORD:      "off",
		Item.WeaponType.GREATAXE:        "off",
		Item.WeaponType.GREAT_BLUDGEON:  "off",
	}

func _build_mage() -> void:
	# Staves, wands, off-hand books and tomes
	profile[&"mage"] = {
		Item.WeaponType.STAFF:           "proficient",
		Item.WeaponType.WAND:            "proficient",
		Item.WeaponType.DAGGER:          "neutral",  # spell-blade flexibility
		Item.WeaponType.SWORD:           "off",
		Item.WeaponType.AXE:             "off",
		Item.WeaponType.GREATSWORD:      "off",
		Item.WeaponType.GREATAXE:        "off",
		Item.WeaponType.BOW:             "off",
		Item.WeaponType.CROSSBOW:        "off",
		Item.WeaponType.KATANA:          "off",
		Item.WeaponType.NODACHI:         "off",
	}

func _build_chaos_druid() -> void:
	# Staves, polearms, totems, scythes; flexible
	profile[&"chaos_druid"] = {
		Item.WeaponType.STAFF:           "proficient",
		Item.WeaponType.POLEARM:         "proficient",
		Item.WeaponType.SCYTHE:          "proficient",
		Item.WeaponType.GREAT_BLUDGEON:  "neutral",
		Item.WeaponType.WAND:            "neutral",
		Item.WeaponType.DAGGER:          "neutral",
		Item.WeaponType.FIST:            "neutral",
		Item.WeaponType.WHIP:            "neutral",
		Item.WeaponType.GREATSWORD:      "off",
		Item.WeaponType.GREATAXE:        "off",
	}

func _build_paladin_guardian() -> void:
	# Tank: hammers and shields. Holy magic.
	profile[&"paladin_guardian"] = {
		Item.WeaponType.BLUDGEON:        "proficient",
		Item.WeaponType.GREAT_BLUDGEON:  "proficient",
		Item.WeaponType.SWORD:           "neutral",
		Item.WeaponType.AXE:             "neutral",
		Item.WeaponType.STAFF:           "off",
		Item.WeaponType.WAND:            "off",
		Item.WeaponType.BOW:             "off",
		Item.WeaponType.CROSSBOW:        "off",
		Item.WeaponType.DAGGER:          "off",
		Item.WeaponType.KATANA:          "off",
		Item.WeaponType.NODACHI:         "off",
	}

func _build_paladin_lightbringer() -> void:
	# Healer: hammers (light/ceremonial), can off-hand book or shield. Holy magic.
	profile[&"paladin_lightbringer"] = {
		Item.WeaponType.BLUDGEON:        "proficient",
		Item.WeaponType.STAFF:           "neutral",  # can use staves, not optimal
		Item.WeaponType.WAND:            "neutral",
		Item.WeaponType.SWORD:           "neutral",
		Item.WeaponType.AXE:             "off",
		Item.WeaponType.GREAT_BLUDGEON:  "off",  # too heavy for the gilded mace style
		Item.WeaponType.GREATSWORD:      "off",
		Item.WeaponType.GREATAXE:        "off",
		Item.WeaponType.BOW:             "off",
		Item.WeaponType.CROSSBOW:        "off",
		Item.WeaponType.DAGGER:          "off",
		Item.WeaponType.KATANA:          "off",
	}

func _build_demon() -> void:
	# Hybrid all-arounder; post-Lucifer carries his old steel and is versatile
	profile[&"demon"] = {
		Item.WeaponType.KATANA:          "proficient",
		Item.WeaponType.GREATSWORD:      "proficient",
		Item.WeaponType.SCYTHE:          "proficient",
		Item.WeaponType.SWORD:           "neutral",
		Item.WeaponType.AXE:             "neutral",
		Item.WeaponType.WAND:            "neutral",
		Item.WeaponType.STAFF:           "neutral",
		Item.WeaponType.DAGGER:          "neutral",
		Item.WeaponType.THROWING_KNIVES: "neutral",
		Item.WeaponType.BOW:             "neutral",
	}
