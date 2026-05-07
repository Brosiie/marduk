extends RefCounted
class_name DamageCalc

# === DAMAGE FORMULA: SOULSLIKE-MULTIPLICATIVE ===
#
# Decision locked. Matches Marduk's Elden Ring / Sekiro inspiration.
#
# Six multiplicative layers, each tunable independently:
#   1. base_damage           - the swing's raw number from the Ability resource
#   2. attribute_factor      - 1 + attribute_scaling * stat / 100. Physical uses primary_attribute,
#                              spells use spell_attribute. Soft scaling, never explodes.
#   3. crit_factor           - 1.0, or attacker.crit_multiplier on roll. Multiplies ALL layers.
#   4. defense_factor        - 1 - armor / (armor + K), where K = 100 (Diablo-style diminishing).
#                              Armor is reduced by ability.armor_pen first.
#   5. variance_factor       - randf 0.92..1.08, +/- 8% spread so identical hits don't feel robotic.
#   6. pvp_factor            - 1.0 in PvE, 0.5 in PvP zones. Disabled by default until Phase 4.
#   7. heaven_factor         - 1 + 0.0001 * heaven_undead_kills, ONLY when wielder carries Heaven.
#                              Permanent stack survives prestige.
#
# Returns Result {damage, crit, killed}. Caller applies damage and handles death state.

const ARMOR_REACH := 100.0  # K in the diminishing armor curve. Tweak if armor feels strong/weak.
const VARIANCE_SPREAD := 0.08
const PVP_DAMAGE_MULT := 0.5  # Phase 4 lever
const PVP_HOOK_ENABLED := false  # flip to true when PvP zones land

class Result:
	var damage: float = 0.0
	var crit: bool = false
	var killed: bool = false
	var was_pvp: bool = false

# attacker_stats: PlayerStats or EnemyBase-like (must respond to .get_attr, .crit_chance, .crit_multiplier)
# defender: any node with `armor`, `magic_resist`, `hp`, `take_damage()`. Optional `is_in_group("player")`.
# ability: Ability resource. BreathingForm extends Ability so it works directly.
# attacker_node: optional, used to fetch Heaven multiplier and outgoing-damage-mult from status effects.
static func calc(attacker_stats, defender, ability: Ability, attacker_node: Node = null) -> Result:
	var r := Result.new()

	# Layer 1: base damage from the ability
	var dmg: float = ability.base_damage

	# Layer 2: attribute scaling. Physical -> primary_attribute (str/dex), magic -> spell_attribute (int).
	if attacker_stats and attacker_stats.has_method("get_attr"):
		var attr_name: StringName = _scaling_attr_for(ability, attacker_stats)
		var attr_value: float = attacker_stats.get_attr(attr_name)
		dmg *= 1.0 + ability.attribute_scaling * (attr_value / 100.0)

	# Layer 3: crit roll (multiplicative)
	var crit_roll := roll_crit(attacker_stats, ability)
	r.crit = crit_roll[0]
	dmg *= float(crit_roll[1])

	# Layer 4: defense reduction (Diablo-style diminishing curve, ignores neg armor)
	if defender:
		var armor_value: float = _defender_armor_for(defender, ability)
		var armor_after_pen: float = max(0.0, armor_value - ability.armor_pen)
		var reduction: float = armor_after_pen / (armor_after_pen + ARMOR_REACH)
		dmg *= 1.0 - reduction

	# Layer 5: variance (organic feel)
	dmg *= 1.0 + randf_range(-VARIANCE_SPREAD, VARIANCE_SPREAD)

	# Layer 6: PvP scaling (off until Phase 4)
	if PVP_HOOK_ENABLED and defender and defender.is_in_group("player"):
		dmg *= PVP_DAMAGE_MULT
		r.was_pvp = true

	# Layer 7: Heaven katana permanent damage stack (Ronin-only, applies only when actually wielding Heaven)
	if attacker_node and attacker_node.has_method("heaven_damage_multiplier"):
		dmg *= attacker_node.heaven_damage_multiplier()

	# Layer 7b: Class weapon proficiency bonus (+20% on-class, -10% off-class, 1.0 neutral)
	# Guard with `in` since enemy attacker_stats objects (EnemyBase/BossBase)
	# do not have a class_def field; reading it would throw.
	if attacker_node and attacker_stats and "class_def" in attacker_stats and attacker_stats.class_def:
		var weapon: Item = null
		if attacker_node.has_method("get_inventory"):
			var inv: Inventory = attacker_node.get_inventory()
			if inv:
				weapon = inv.equipped_in(Item.Slot.WEAPON_MAIN)
		if weapon and weapon.weapon_type != Item.WeaponType.NONE:
			var prof_node = Engine.get_main_loop().root.get_node_or_null("ClassProficiencyRegistry")
			if prof_node:
				dmg *= prof_node.damage_multiplier_for(attacker_stats.class_def.class_id, weapon.weapon_type)

	# Layer 7c: stamina-vs-mana damage scaling.
	# Bond's design: stamina abilities deal 1/4 of mana abilities so the 4x faster regen balances out.
	# Detection: if attacker's class uses stamina AND the ability was scaled as physical, no change.
	# If attacker's class uses mana AND ability is a spell, it gets the 4x mana-tier multiplier
	# baked in via base_damage authoring (mage spells already have higher base_damage in the registry).
	# This layer therefore applies a soft adjustment only if mismatch detected.
	if attacker_stats and "class_def" in attacker_stats and attacker_stats.class_def:
		var mech: StringName = attacker_stats.class_def.resource_mechanic
		# Stamina-class uses spell-tagged ability (eg Druid casting from a staff): apply 0.25 ratio
		if mech == &"stamina" and ability.damage_type != Ability.DamageType.PHYSICAL:
			dmg *= 0.25
		# Mana-class uses physical ability (eg Mage swinging a sword off-class): apply 0.25 ratio
		elif mech == &"mana" and ability.damage_type == Ability.DamageType.PHYSICAL:
			dmg *= 0.25

	# Layer 7d: Spellpower attribute scaling (only on spell abilities)
	if attacker_stats and ability.damage_type != Ability.DamageType.PHYSICAL:
		dmg *= 1.0 + attacker_stats.spellpower

	# Layer 7e: Hit chance roll (Accuracy attribute caps at 95%; if miss, return 0 damage)
	if attacker_stats and attacker_stats.hit_chance < 1.0:
		if randf() > attacker_stats.hit_chance:
			r.damage = 0.0
			return r

	# Layer 7f: Ambush bonus (Stealth first-strike)
	if attacker_node and attacker_node.has_method("consume_ambush_bonus"):
		var ambush: Dictionary = attacker_node.consume_ambush_bonus()
		dmg *= float(ambush.get("damage_mult", 1.0))
		if bool(ambush.get("guarantee_crit", false)):
			r.crit = true
			# Add crit multiplier post-hoc (already applied above? check)
			if not r.crit:
				dmg *= attacker_stats.crit_multiplier

	# Layer 7g: Berserker rage scaling (damage_mult from get_rage_buffs)
	if attacker_node and attacker_node.has_method("get_rage_buffs"):
		var rage: Dictionary = attacker_node.get_rage_buffs()
		dmg *= float(rage.get("damage_mult", 1.0))

	# Layer 7h: Demon time-of-day + Blood scaling (combined)
	if attacker_node and attacker_node.has_method("demon_damage_multiplier"):
		dmg *= attacker_node.demon_damage_multiplier()

	# Lifesteal: route 5% of dealt damage back as heal. Demon-only check inside Player.
	if attacker_node and attacker_node.has_method("apply_lifesteal"):
		attacker_node.apply_lifesteal(max(1.0, dmg))

	# Layer 8: status effect modifiers on attacker (eg weakness, mark) - optional, when SE holder exists
	if attacker_node and attacker_node.has_node("StatusEffectsHolder"):
		var seh = attacker_node.get_node("StatusEffectsHolder")
		dmg *= seh.damage_dealt_multiplier()
	if defender and defender.has_node("StatusEffectsHolder"):
		var seh2 = defender.get_node("StatusEffectsHolder")
		dmg *= seh2.damage_taken_multiplier()

	r.damage = max(1.0, dmg)
	return r

# Returns the StringName of the attacker stat the ability scales off of.
# Physical abilities use the class's primary_attribute. Magical abilities use spell_attribute.
static func _scaling_attr_for(ability: Ability, attacker_stats) -> StringName:
	if not attacker_stats or not attacker_stats.class_def:
		return &"strength"
	if ability.damage_type == Ability.DamageType.PHYSICAL:
		return attacker_stats.class_def.primary_attribute
	return attacker_stats.class_def.spell_attribute

static func _defender_armor_for(defender, ability: Ability) -> float:
	if ability.damage_type == Ability.DamageType.PHYSICAL:
		return float(defender.get("armor")) if defender.get("armor") != null else 0.0
	return float(defender.get("magic_resist")) if defender.get("magic_resist") != null else 0.0

static func roll_crit(attacker_stats, ability: Ability) -> Array:
	if not attacker_stats:
		return [false, 1.0]
	var chance: float = attacker_stats.crit_chance + ability.crit_bonus_chance
	if randf() < chance:
		return [true, attacker_stats.crit_multiplier]
	return [false, 1.0]

static func variance(amount: float, spread: float = 0.10) -> float:
	return amount * (1.0 + randf_range(-spread, spread))
