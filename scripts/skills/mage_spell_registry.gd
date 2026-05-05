extends Node

# Autoload: Mage's seven elemental schools, ~7 spells each. ~49 spells total.
# Mana cost scales 5 -> 100 across tiers. Damage scales aggressively to match.
# School identities:
#   FIRE     - aggressive AoE, burn DoT, ignite chains
#   FROST    - control, slow, single-target burst, freeze
#   LIGHTNING - chain damage, fast cast, low cooldown
#   ARCANE   - raw damage, mana efficiency, missiles
#   HOLY     - bonus vs demon/undead, smite, healing-light
#   SHADOW   - DoT, drain, mark, life-tap
#   VOID     - high damage with HP self-cost, anti-armor

var schools: Dictionary = {}  # StringName -> SpellSchool

func _ready() -> void:
	_register_fire()
	_register_frost()
	_register_lightning()
	_register_arcane()
	_register_holy()
	_register_shadow()
	_register_void()

func get_school(id: StringName) -> SpellSchool:
	return schools.get(id)

func all_schools() -> Array[SpellSchool]:
	var arr: Array[SpellSchool] = []
	for s in schools.values():
		arr.append(s)
	return arr

func _spell(school_id: StringName, tier: int, name: String, desc: String,
		mana_cost: float, base_dmg: float, cd: float, cast_time: float,
		target_mode: int, range_m: float, radius_m: float,
		element: int, anim_name: String, vfx_color: Color,
		min_level: int = 1) -> MageSpell:
	var s := MageSpell.new()
	s.id = StringName("%s_%d" % [school_id, tier])
	s.school_id = school_id
	s.tier = tier
	s.display_name = name
	s.description = desc
	s.mana_cost = mana_cost
	s.base_damage = base_dmg
	s.cooldown = cd
	s.cast_time = cast_time
	s.target_mode = target_mode
	s.range = range_m
	s.radius = radius_m
	s.damage_type = element
	s.animation_name = StringName(anim_name)
	s.vfx_color = vfx_color
	s.attribute_scaling = 1.0  # mage spells scale hard with intellect/spellpower
	if tier > 1:
		s.prereq_spell_id = StringName("%s_%d" % [school_id, tier - 1])
	if tier == 7:
		s.crit_bonus_chance = 0.20
	return s

# ============================================================
# FIRE
# ============================================================
func _register_fire() -> void:
	var s := SpellSchool.new()
	s.id = &"fire"
	s.display_name = "Fire"
	s.lore = "The first syllable Marduk taught humans was for fire. The flames remember."
	s.element = Item.Element.FIRE
	s.primary_color = Color(1.0, 0.4, 0.1)
	var c := Color(1.0, 0.4, 0.1)
	# Ability.TargetMode: 0=SELF 1=FORWARD_CONE 2=AOE_AROUND_SELF 3=PROJECTILE 4=GROUND_TARGETED
	s.spells = [
		_spell(&"fire", 1, "Spark", "A small bolt of fire. Cheap, fast, gateway spell.",
			5.0, 18.0, 0.4, 0.20, 3, 12.0, 0.5, Item.Element.FIRE, "spell_fire_1", c, 1),
		_spell(&"fire", 2, "Ember Volley", "3 fire bolts in rapid succession.",
			15.0, 38.0, 1.2, 0.55, 3, 14.0, 0.5, Item.Element.FIRE, "spell_fire_2", c, 4),
		_spell(&"fire", 3, "Flame Lance", "Long line of fire. Pierces all in line.",
			28.0, 70.0, 2.4, 0.80, 1, 14.0, 1.0, Item.Element.FIRE, "spell_fire_3", c, 8),
		_spell(&"fire", 4, "Cinder Cloud", "AOE on the ground, burns enemies entering it for 4 sec.",
			40.0, 60.0, 5.0, 0.50, 4, 16.0, 4.0, Item.Element.FIRE, "spell_fire_4", c, 14),
		_spell(&"fire", 5, "Pyroclasm", "Burst of fire centered on caster, knockback and burn.",
			55.0, 130.0, 7.0, 0.60, 2, 0.0, 6.0, Item.Element.FIRE, "spell_fire_5", c, 22),
		_spell(&"fire", 6, "Phoenix Strike", "Mage dashes in a flame trail; damages and ignites all in path.",
			70.0, 180.0, 10.0, 0.30, 1, 12.0, 1.5, Item.Element.FIRE, "spell_fire_6", c, 32),
		_spell(&"fire", 7, "Rain of Cinders", "60-meter sky-fire over 4 seconds. Channeled.",
			100.0, 320.0, 30.0, 4.00, 4, 60.0, 12.0, Item.Element.FIRE, "spell_fire_7",
			Color(1.0, 0.2, 0.0), 50)
	]
	schools[s.id] = s

# ============================================================
# FROST
# ============================================================
func _register_frost() -> void:
	var s := SpellSchool.new()
	s.id = &"frost"
	s.display_name = "Frost"
	s.lore = "Quench the fire and what is left is frost. The Lapis Bay schools learn to drink the heat from a room."
	s.element = Item.Element.FROST
	s.primary_color = Color(0.4, 0.7, 1.0)
	var c := Color(0.4, 0.7, 1.0)
	s.spells = [
		_spell(&"frost", 1, "Frost Bolt", "Single bolt that slows on hit by 30% for 2 sec.",
			6.0, 16.0, 0.5, 0.25, 3, 14.0, 0.5, Item.Element.FROST, "spell_frost_1", c, 1),
		_spell(&"frost", 2, "Ice Shards", "Five small shards in a tight cone.",
			16.0, 35.0, 1.6, 0.50, 1, 8.0, 1.5, Item.Element.FROST, "spell_frost_2", c, 4),
		_spell(&"frost", 3, "Freeze", "Single target, 2 sec hold. Damage low; control high.",
			26.0, 30.0, 6.0, 0.45, 3, 12.0, 0.5, Item.Element.FROST, "spell_frost_3", c, 8),
		_spell(&"frost", 4, "Glacial Spike", "Charged single hit, breaks frozen targets for double damage.",
			42.0, 130.0, 5.0, 1.00, 3, 16.0, 0.5, Item.Element.FROST, "spell_frost_4", c, 14),
		_spell(&"frost", 5, "Blizzard", "Channeled AOE storm, slows all in 8m.",
			58.0, 120.0, 10.0, 3.00, 4, 18.0, 8.0, Item.Element.FROST, "spell_frost_5", c, 22),
		_spell(&"frost", 6, "Ring of Frost", "Plant ring at target spot; enemies entering are frozen 3 sec.",
			72.0, 150.0, 18.0, 0.80, 4, 14.0, 5.0, Item.Element.FROST, "spell_frost_6", c, 32),
		_spell(&"frost", 7, "Heart of Winter", "Full-screen wave; freezes all enemies 4 sec, deals frost burst.",
			100.0, 350.0, 40.0, 1.50, 2, 0.0, 30.0, Item.Element.FROST, "spell_frost_7",
			Color(0.7, 0.95, 1.0), 50)
	]
	schools[s.id] = s

# ============================================================
# LIGHTNING
# ============================================================
func _register_lightning() -> void:
	var s := SpellSchool.new()
	s.id = &"lightning"
	s.display_name = "Lightning"
	s.lore = "Adad's pulse. Fast, hot, gone before you hear the thunder."
	s.element = Item.Element.LIGHTNING
	s.primary_color = Color(1.0, 0.95, 0.5)
	var c := Color(1.0, 0.95, 0.5)
	s.spells = [
		_spell(&"lightning", 1, "Spark Bolt", "Instant lightning bolt. Lowest cast time of any tier-1 spell.",
			5.0, 22.0, 0.3, 0.05, 3, 14.0, 0.5, Item.Element.LIGHTNING, "spell_lightning_1", c, 1),
		_spell(&"lightning", 2, "Chain Spark", "Bolt that arcs to one nearby enemy at 60% damage.",
			14.0, 40.0, 1.0, 0.20, 3, 14.0, 0.5, Item.Element.LIGHTNING, "spell_lightning_2", c, 4),
		_spell(&"lightning", 3, "Static Field", "AOE field around caster, 3 sec, damages enemies entering.",
			24.0, 50.0, 5.0, 0.40, 2, 0.0, 6.0, Item.Element.LIGHTNING, "spell_lightning_3", c, 8),
		_spell(&"lightning", 4, "Forked Lightning", "Hits 3 targets in front cone instantly.",
			38.0, 105.0, 3.0, 0.20, 1, 12.0, 4.0, Item.Element.LIGHTNING, "spell_lightning_4", c, 14),
		_spell(&"lightning", 5, "Storm Call", "Channels for 4 sec, drops bolts on random nearby enemies.",
			55.0, 150.0, 9.0, 4.00, 2, 0.0, 12.0, Item.Element.LIGHTNING, "spell_lightning_5", c, 22),
		_spell(&"lightning", 6, "Thunderclap", "Instant bolt + 6m AOE shockwave, stuns 1 sec.",
			72.0, 200.0, 14.0, 0.10, 3, 18.0, 6.0, Item.Element.LIGHTNING, "spell_lightning_6", c, 32),
		_spell(&"lightning", 7, "Adad's Hammer", "12-strike chain across all visible enemies in 0.5 sec.",
			100.0, 380.0, 35.0, 0.10, 2, 0.0, 25.0, Item.Element.LIGHTNING, "spell_lightning_7",
			Color(1.0, 1.0, 0.9), 50)
	]
	schools[s.id] = s

# ============================================================
# ARCANE
# ============================================================
func _register_arcane() -> void:
	var s := SpellSchool.new()
	s.id = &"arcane"
	s.display_name = "Arcane"
	s.lore = "Pure magic, untouched by element. Highest raw damage per mana. The bookkeeper's school."
	s.element = Item.Element.ARCANE
	s.primary_color = Color(0.85, 0.55, 1.0)
	var c := Color(0.85, 0.55, 1.0)
	s.spells = [
		_spell(&"arcane", 1, "Magic Missile", "Two seeking missiles per cast.",
			7.0, 26.0, 0.5, 0.30, 3, 14.0, 0.5, Item.Element.ARCANE, "spell_arcane_1", c, 1),
		_spell(&"arcane", 2, "Arcane Barrage", "Five bolts in rapid succession.",
			18.0, 60.0, 1.5, 0.60, 3, 14.0, 0.5, Item.Element.ARCANE, "spell_arcane_2", c, 4),
		_spell(&"arcane", 3, "Arcane Blast", "Big single hit at one target.",
			30.0, 95.0, 2.4, 0.80, 3, 14.0, 0.5, Item.Element.ARCANE, "spell_arcane_3", c, 8),
		_spell(&"arcane", 4, "Mana Burn", "Hits target, drains 30% of their mana into yours.",
			15.0, 45.0, 6.0, 0.50, 3, 14.0, 0.5, Item.Element.ARCANE, "spell_arcane_4", c, 14),
		_spell(&"arcane", 5, "Slow Time", "Slows all enemies in 12m to 50% speed for 6 sec.",
			55.0, 0.0, 18.0, 0.50, 2, 0.0, 12.0, Item.Element.ARCANE, "spell_arcane_5", c, 22),
		_spell(&"arcane", 6, "Arcane Explosion", "Blast around caster, damages all in 8m.",
			68.0, 180.0, 8.0, 0.40, 2, 0.0, 8.0, Item.Element.ARCANE, "spell_arcane_6", c, 32),
		_spell(&"arcane", 7, "Word of Unmaking", "Highest single-target damage in the game. 2-sec cast.",
			100.0, 480.0, 40.0, 2.00, 3, 18.0, 0.5, Item.Element.ARCANE, "spell_arcane_7",
			Color(1.0, 0.8, 1.0), 50)
	]
	schools[s.id] = s

# ============================================================
# HOLY
# ============================================================
func _register_holy() -> void:
	var s := SpellSchool.new()
	s.id = &"holy"
	s.display_name = "Holy"
	s.lore = "The sun-magic. Marduk's gift. Burns demons and undead twice."
	s.element = Item.Element.HOLY
	s.primary_color = Color(1.0, 0.9, 0.4)
	var c := Color(1.0, 0.9, 0.4)
	s.spells = [
		_spell(&"holy", 1, "Light Bolt", "Bolt of light, +25% damage to demons/undead.",
			6.0, 18.0, 0.5, 0.30, 3, 14.0, 0.5, Item.Element.HOLY, "spell_holy_1", c, 1),
		_spell(&"holy", 2, "Heal", "Restore 80 HP to self or ally. Mage's emergency button.",
			18.0, 0.0, 4.0, 0.50, 0, 8.0, 0.5, Item.Element.HOLY, "spell_holy_2", c, 4),
		_spell(&"holy", 3, "Smite", "Big bolt at one target, +40% damage to demons/undead.",
			28.0, 90.0, 3.0, 0.55, 3, 14.0, 0.5, Item.Element.HOLY, "spell_holy_3", c, 8),
		_spell(&"holy", 4, "Sacred Flame", "Channel beam for 2 sec, 200 dmg total to demon/undead.",
			42.0, 130.0, 8.0, 2.00, 1, 12.0, 1.0, Item.Element.HOLY, "spell_holy_4", c, 14),
		_spell(&"holy", 5, "Aura of Light", "20-sec self-buff. Damage taken -15% in radius.",
			55.0, 0.0, 30.0, 0.30, 0, 0.0, 0.5, Item.Element.HOLY, "spell_holy_5", c, 22),
		_spell(&"holy", 6, "Banish", "Single-target dispel; instantly kills enemy below 25% HP if it is undead/demon.",
			70.0, 200.0, 15.0, 1.00, 3, 14.0, 0.5, Item.Element.HOLY, "spell_holy_6", c, 32),
		_spell(&"holy", 7, "Light of Marduk", "Channeled pillar, 4 sec. Heals allies and damages enemies in 12m.",
			100.0, 350.0, 40.0, 4.00, 2, 0.0, 12.0, Item.Element.HOLY, "spell_holy_7",
			Color(1.0, 1.0, 0.7), 50)
	]
	schools[s.id] = s

# ============================================================
# SHADOW
# ============================================================
func _register_shadow() -> void:
	var s := SpellSchool.new()
	s.id = &"shadow"
	s.display_name = "Shadow"
	s.lore = "What Tiamat dreamed before the binding. Forbidden in Babilim's libraries; taught anyway."
	s.element = Item.Element.SHADOW
	s.primary_color = Color(0.5, 0.2, 0.7)
	var c := Color(0.5, 0.2, 0.7)
	s.spells = [
		_spell(&"shadow", 1, "Shadow Bolt", "DoT bolt, 12 dmg/sec for 4 sec on hit.",
			6.0, 12.0, 0.6, 0.30, 3, 14.0, 0.5, Item.Element.SHADOW, "spell_shadow_1", c, 1),
		_spell(&"shadow", 2, "Curse of Weakness", "Target deals 25% less damage for 12 sec.",
			15.0, 0.0, 8.0, 0.40, 3, 14.0, 0.5, Item.Element.SHADOW, "spell_shadow_2", c, 4),
		_spell(&"shadow", 3, "Drain Life", "Deals damage and heals caster for 50% of damage dealt.",
			28.0, 70.0, 3.0, 0.60, 3, 12.0, 0.5, Item.Element.SHADOW, "spell_shadow_3", c, 8),
		_spell(&"shadow", 4, "Mark of Hunger", "Hits target, all damage to it for 8 sec is +30%.",
			36.0, 50.0, 12.0, 0.40, 3, 14.0, 0.5, Item.Element.SHADOW, "spell_shadow_4", c, 14),
		_spell(&"shadow", 5, "Soul Tap", "Spend 15% HP to instantly refill 60 mana. 5 sec CD.",
			0.0, 0.0, 5.0, 0.20, 0, 0.0, 0.5, Item.Element.SHADOW, "spell_shadow_5", c, 22),
		_spell(&"shadow", 6, "Shadow Word", "Instant 200 dmg if target is below 30% HP. Fails otherwise.",
			60.0, 200.0, 8.0, 0.10, 3, 16.0, 0.5, Item.Element.SHADOW, "spell_shadow_6", c, 32),
		_spell(&"shadow", 7, "Tiamat's Whisper", "Curse all enemies in 14m: take +50% damage and bleed for 30 sec.",
			100.0, 0.0, 60.0, 1.50, 2, 0.0, 14.0, Item.Element.SHADOW, "spell_shadow_7",
			Color(0.7, 0.3, 0.9), 50)
	]
	schools[s.id] = s

# ============================================================
# VOID
# ============================================================
func _register_void() -> void:
	var s := SpellSchool.new()
	s.id = &"void"
	s.display_name = "Void"
	s.lore = "What was before Apsu. Old Asaridu specialized here. He paid for it."
	s.element = Item.Element.VOID
	s.primary_color = Color(0.2, 0.0, 0.4)
	var c := Color(0.2, 0.0, 0.4)
	s.spells = [
		_spell(&"void", 1, "Void Bolt", "Ignores 30% of target armor.",
			8.0, 22.0, 0.6, 0.40, 3, 14.0, 0.5, Item.Element.VOID, "spell_void_1", c, 1),
		_spell(&"void", 2, "Rend", "Hits target, ignores 50% armor. 8 dmg/sec bleed for 6 sec.",
			18.0, 50.0, 2.5, 0.50, 3, 12.0, 0.5, Item.Element.VOID, "spell_void_2", c, 4),
		_spell(&"void", 3, "Maw", "Mouth opens at target, swallows for 1 sec, deals heavy damage.",
			32.0, 100.0, 6.0, 0.80, 3, 14.0, 0.5, Item.Element.VOID, "spell_void_3", c, 8),
		_spell(&"void", 4, "Singularity", "Pulls all enemies in 8m to a point and damages them.",
			48.0, 90.0, 12.0, 0.80, 4, 16.0, 8.0, Item.Element.VOID, "spell_void_4", c, 14),
		_spell(&"void", 5, "Annihilate", "Massive single-target damage, costs 10% HP to cast.",
			55.0, 220.0, 8.0, 1.00, 3, 14.0, 0.5, Item.Element.VOID, "spell_void_5", c, 22),
		_spell(&"void", 6, "Unmake", "Hits all enemies in front cone, ignores 80% armor.",
			75.0, 220.0, 14.0, 1.20, 1, 12.0, 4.0, Item.Element.VOID, "spell_void_6", c, 32),
		_spell(&"void", 7, "Word from the Apsu", "Costs 30% HP. 600 dmg to all enemies in 18m.",
			100.0, 600.0, 60.0, 2.00, 2, 0.0, 18.0, Item.Element.VOID, "spell_void_7",
			Color(0.4, 0.0, 0.6), 50)
	]
	schools[s.id] = s
