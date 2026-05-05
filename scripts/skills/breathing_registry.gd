extends Node

# Autoload: holds the canonical Ronin breathing styles. Inspired by Demon Slayer.
# Six styles available from start (skill-point gated within each), one capstone style
# (Sun Breathing) gated behind Tiamat + mastery of 2 other styles.
#
# Style philosophies:
#   Water    - flow, parry, sustain, mid-range arcs
#   Flame    - aggression, burn DoT, forward momentum
#   Mist     - illusion, single-target burst, teleport-strikes
#   Thunder  - one-form-mastered (highest single-strike damage), instant dash hits
#   Stone    - heavy, slow, defensive bulwark, armor pen
#   Wind    - mobility, multi-hit sweeps, knockback
#   Sun     - capstone, all-elements, screen-wide ultimates (LOCKED)

var styles: Dictionary = {}  # StringName -> BreathingStyle

func _ready() -> void:
	_register_water()
	_register_flame()
	_register_mist()
	_register_thunder()
	_register_stone()
	_register_wind()
	_register_sun()

func get_style(id: StringName) -> BreathingStyle:
	return styles.get(id)

func all_styles() -> Array[BreathingStyle]:
	var arr: Array[BreathingStyle] = []
	for s in styles.values():
		arr.append(s)
	return arr

func selectable_styles_for(player_level: int, mastered_count: int) -> Array[BreathingStyle]:
	var arr: Array[BreathingStyle] = []
	for s: BreathingStyle in styles.values():
		var ok := true
		if s.unlock_save_flag != &"" and not SaveFlags.has_permanent(s.unlock_save_flag):
			ok = false
		if mastered_count < s.requires_mastered_styles:
			ok = false
		if player_level < s.min_player_level_for_first_form:
			ok = false
		if ok:
			arr.append(s)
	return arr

# ----------------------------------------------------------------
# Form factory: collapses verbose Resource construction into one line.
# ----------------------------------------------------------------
func _form(
	style_id: StringName, num: int, name: String, desc: String,
	base_dmg: float, mana: float, cd: float, cast_time: float,
	target_mode: int, range_m: float, radius_m: float,
	stance_cost: int, perfect_window: float, miss_punish: float,
	min_level: int, anim_name: String, vfx_color: Color,
	chain_pre: StringName = &"", damage_type: int = 0
) -> BreathingForm:
	var f := BreathingForm.new()
	f.id = StringName("%s_%d" % [style_id, num])
	f.style_id = style_id
	f.form_number = num
	f.display_name = "%s Form: %s" % [_ord(num), name]
	f.description = desc
	f.base_damage = base_dmg
	f.mana_cost = mana
	f.cooldown = cd
	f.cast_time = cast_time
	f.target_mode = target_mode
	f.range = range_m
	f.radius = radius_m
	f.stance_charge_cost = stance_cost
	f.perfect_window_seconds = perfect_window
	f.miss_punishment_seconds = miss_punish
	f.min_player_level = min_level
	f.animation_name = StringName(anim_name)
	f.vfx_color = vfx_color
	f.chain_predecessor = chain_pre
	f.damage_type = damage_type
	f.attribute_scaling = 0.85  # Ronin scales hard with primary attribute
	# Capstone (Form 7) crit bonus
	if num == 7:
		f.crit_bonus_chance = 0.25
		f.chain_bonus_mult = 1.8
	if num > 1:
		f.prereq_form_id = StringName("%s_%d" % [style_id, num - 1])
	return f

func _ord(n: int) -> String:
	match n:
		1: return "First"
		2: return "Second"
		3: return "Third"
		4: return "Fourth"
		5: return "Fifth"
		6: return "Sixth"
		7: return "Seventh"
		_: return str(n)

# ----------------------------------------------------------------
# WATER BREATHING - flow, parry, sustain, mid-arcs
# ----------------------------------------------------------------
func _register_water() -> void:
	var s := BreathingStyle.new()
	s.id = &"water"
	s.display_name = "Water Breathing"
	s.lore = "The first style most ronin learn. Flow over the enemy as a river over stone. Adapt, redirect, never resist."
	s.element = &"water"
	s.primary_color = Color(0.2, 0.6, 0.9)
	s.min_player_level_for_first_form = 1
	var blue := Color(0.3, 0.7, 1.0)
	# Ability.TargetMode -> 0=SELF, 1=FORWARD_CONE, 2=AOE_AROUND_SELF, 3=PROJECTILE, 4=GROUND_TARGETED
	# Ability.DamageType -> 0=PHYSICAL, 1=ARCANE, 2=FIRE, 3=FROST, 4=LIGHTNING, 5=HOLY, 6=SHADOW
	s.forms = [
		_form(&"water", 1, "River Cleave", "Foundation slash. Horizontal arc, low cost, fast recovery.",
			28.0, 6.0, 0.6, 0.15, 1, 2.4, 1.4, 1, 0.0, 0.0, 1, "breath_water_1", blue),
		_form(&"water", 2, "Wheel of the Stream", "Spinning blade wheel, hits everything in melee radius.",
			34.0, 10.0, 1.2, 0.25, 2, 0.0, 2.2, 1, 0.0, 0.2, 3, "breath_water_2", blue),
		_form(&"water", 3, "Dance of the Tide", "Dash forward then slash. Closes distance, repositions.",
			38.0, 12.0, 1.6, 0.10, 1, 5.0, 1.6, 1, 0.0, 0.3, 5, "breath_water_3", blue),
		_form(&"water", 4, "Striking Current", "Forward thrust, line attack, pierces armor by 30%.",
			46.0, 14.0, 1.8, 0.30, 1, 4.5, 0.8, 2, 0.15, 0.5, 8, "breath_water_4", blue),
		_form(&"water", 5, "Calm After Storm", "Parry stance. Successful parry refunds stance charge and heals 8% HP.",
			0.0, 8.0, 4.0, 0.0, 0, 0.0, 0.0, 1, 0.30, 1.0, 10, "breath_water_5", blue),
		_form(&"water", 6, "Whirlpool", "Spinning AOE that pulls enemies inward. 6m radius.",
			52.0, 22.0, 6.0, 0.45, 2, 0.0, 6.0, 2, 0.0, 0.6, 14, "breath_water_6", blue),
		_form(&"water", 7, "Constant Flow", "Sustained 3-second blade flurry. Channeled, vulnerable to interrupt.",
			120.0, 40.0, 14.0, 1.20, 1, 3.5, 2.5, 3, 0.0, 1.5, 22, "breath_water_7",
			Color(0.5, 0.85, 1.0), &"water_6")
	]
	styles[s.id] = s

# ----------------------------------------------------------------
# FLAME BREATHING - aggression, burn, forward momentum
# ----------------------------------------------------------------
func _register_flame() -> void:
	var s := BreathingStyle.new()
	s.id = &"flame"
	s.display_name = "Flame Breathing"
	s.lore = "Burn the path forward. Flame breathing rewards the bold and punishes the hesitant. Hesitate and burn."
	s.element = &"fire"
	s.primary_color = Color(1.0, 0.45, 0.15)
	s.min_player_level_for_first_form = 1
	var red := Color(1.0, 0.5, 0.2)
	s.forms = [
		_form(&"flame", 1, "First Pyre", "Upward slash that ignites. Applies 8 dmg/s burn for 3s.",
			30.0, 6.0, 0.7, 0.18, 1, 2.5, 1.2, 1, 0.0, 0.0, 1, "breath_flame_1", red, &"", 2),
		_form(&"flame", 2, "Rising Inferno", "Leap from above, slam-strike. 4m vertical.",
			40.0, 12.0, 1.4, 0.30, 1, 3.0, 2.0, 1, 0.0, 0.4, 3, "breath_flame_2", red, &"", 2),
		_form(&"flame", 3, "Blazing Cosmos", "Wide horizontal cleave with fire trail. Trail burns enemies who cross it.",
			44.0, 14.0, 1.8, 0.25, 1, 3.5, 2.6, 2, 0.0, 0.4, 5, "breath_flame_3", red, &"", 2),
		_form(&"flame", 4, "Bloom of Flame", "Spinning fire arc. Two rotations, hits twice.",
			52.0, 18.0, 2.6, 0.40, 2, 0.0, 3.0, 2, 0.0, 0.6, 9, "breath_flame_4", red, &"", 2),
		_form(&"flame", 5, "Tiger of Embers", "Dash that leaves a fire trail. Trail lasts 4s.",
			46.0, 20.0, 3.0, 0.20, 1, 7.0, 1.4, 2, 0.20, 0.5, 12, "breath_flame_5", red, &"", 2),
		_form(&"flame", 6, "Pyre's Edge", "Charged forward slash, 1s windup. Ignites a 8m line.",
			68.0, 26.0, 5.0, 1.00, 1, 8.0, 1.0, 3, 0.15, 1.2, 16, "breath_flame_6", red, &"", 2),
		_form(&"flame", 7, "Crimson Suffering Sun", "Massive cone, 12s scorching DoT, ignites the ground.",
			140.0, 48.0, 16.0, 1.40, 1, 8.0, 4.5, 3, 0.0, 2.0, 24, "breath_flame_7",
			Color(1.0, 0.25, 0.05), &"flame_6", 2)
	]
	styles[s.id] = s

# ----------------------------------------------------------------
# MIST BREATHING - illusion, speed, single-target burst
# ----------------------------------------------------------------
func _register_mist() -> void:
	var s := BreathingStyle.new()
	s.id = &"mist"
	s.display_name = "Mist Breathing"
	s.lore = "Disappear. Strike. Disappear again. Mist is the hardest style to read and the hardest to learn. Master it and you fight unseen."
	s.element = &"shadow"
	s.primary_color = Color(0.7, 0.75, 0.85)
	s.min_player_level_for_first_form = 1
	var grey := Color(0.75, 0.8, 0.9)
	s.forms = [
		_form(&"mist", 1, "Low Cloud, Distant Haze", "Brief teleport-strike. 4m blink + slash.",
			32.0, 10.0, 1.0, 0.10, 1, 4.0, 0.8, 1, 0.0, 0.3, 1, "breath_mist_1", grey, &"", 6),
		_form(&"mist", 2, "Eight-Layered Mist", "8 rapid stabs on a single target. Multi-hit single-target.",
			56.0, 16.0, 2.0, 0.50, 1, 1.8, 0.6, 1, 0.10, 0.6, 4, "breath_mist_2", grey, &"", 6),
		_form(&"mist", 3, "Scattering Mist Splash", "Cone in front, brief blind on hit (-50% accuracy 3s).",
			36.0, 14.0, 1.8, 0.25, 1, 4.0, 2.5, 1, 0.0, 0.4, 6, "breath_mist_3", grey, &"", 6),
		_form(&"mist", 4, "Shifting Flow Slash", "Feint, then strike. Counts as crit if used 0.5s after dodge.",
			44.0, 16.0, 2.4, 0.30, 1, 3.0, 1.0, 2, 0.5, 0.5, 9, "breath_mist_4", grey, &"", 6),
		_form(&"mist", 5, "Sea of Clouds and Haze", "AOE blind cloud, 5m radius, 4s duration.",
			0.0, 22.0, 8.0, 0.30, 2, 0.0, 5.0, 2, 0.0, 0.4, 12, "breath_mist_5", grey, &"", 6),
		_form(&"mist", 6, "Lunar Dispersion Mist", "2-second invisibility. Next hit while invisible is guaranteed crit.",
			0.0, 30.0, 14.0, 0.20, 0, 0.0, 0.0, 2, 0.0, 0.0, 16, "breath_mist_6", grey, &"", 6),
		_form(&"mist", 7, "Obscuring Clouds", "5-second invisibility + auto-crit on next strike + 200% damage on that strike.",
			180.0, 50.0, 22.0, 0.30, 0, 0.0, 0.0, 3, 0.0, 0.0, 22, "breath_mist_7",
			Color(0.85, 0.9, 1.0), &"mist_6", 6)
	]
	styles[s.id] = s

# ----------------------------------------------------------------
# THUNDER BREATHING - one-form mastery, highest single-hit damage
# ----------------------------------------------------------------
func _register_thunder() -> void:
	var s := BreathingStyle.new()
	s.id = &"thunder"
	s.display_name = "Thunder Breathing"
	s.lore = "Most thunder ronin master only one form, but master it perfectly. Speed of light, weight of mountain."
	s.element = &"lightning"
	s.primary_color = Color(1.0, 0.95, 0.4)
	s.min_player_level_for_first_form = 1
	var yellow := Color(1.0, 0.95, 0.5)
	s.forms = [
		_form(&"thunder", 1, "Thunderclap and Flash", "Instant dash strike. Tightest perfect window in the game.",
			52.0, 14.0, 1.4, 0.05, 1, 6.0, 0.8, 1, 0.10, 0.4, 1, "breath_thunder_1", yellow, &"", 4),
		_form(&"thunder", 2, "Rice Spirit", "Spinning blade strike, hits up to 5 enemies.",
			36.0, 14.0, 1.6, 0.30, 2, 0.0, 2.4, 1, 0.0, 0.4, 4, "breath_thunder_2", yellow, &"", 4),
		_form(&"thunder", 3, "Thunder Swarm", "Chain lightning between up to 4 enemies. 60% damage per chain.",
			48.0, 22.0, 3.5, 0.30, 3, 8.0, 0.0, 1, 0.0, 0.3, 7, "breath_thunder_3", yellow, &"", 4),
		_form(&"thunder", 4, "Distant Thunder", "Delayed shockwave, lands 0.8s after cast. Trains anticipation.",
			60.0, 22.0, 4.0, 0.10, 4, 7.0, 3.0, 2, 0.0, 0.2, 10, "breath_thunder_4", yellow, &"", 4),
		_form(&"thunder", 5, "Heat Lightning", "Line attack through enemies, pierces all in path.",
			55.0, 24.0, 4.5, 0.40, 1, 12.0, 1.0, 2, 0.20, 0.6, 13, "breath_thunder_5", yellow, &"", 4),
		_form(&"thunder", 6, "Rumble and Flash", "Zigzag dash combo, 3 hits across 3 positions.",
			78.0, 30.0, 6.0, 0.30, 1, 8.0, 1.4, 3, 0.15, 0.8, 17, "breath_thunder_6", yellow, &"", 4),
		_form(&"thunder", 7, "Flaming Thunder God", "Instantly hits up to 7 enemies in 0.4s. Ronin's lethal stroke.",
			220.0, 55.0, 24.0, 0.05, 1, 10.0, 0.0, 3, 0.05, 1.5, 25, "breath_thunder_7",
			Color(1.0, 1.0, 0.2), &"thunder_6", 4)
	]
	styles[s.id] = s

# ----------------------------------------------------------------
# STONE BREATHING - heavy, slow, defensive, armor-piercing
# ----------------------------------------------------------------
func _register_stone() -> void:
	var s := BreathingStyle.new()
	s.id = &"stone"
	s.display_name = "Stone Breathing"
	s.lore = "Be the mountain. Slow to move, slow to fall. The blade strikes only when the mountain decides."
	s.element = &"physical"
	s.primary_color = Color(0.55, 0.5, 0.45)
	s.min_player_level_for_first_form = 1
	var stone := Color(0.6, 0.55, 0.5)
	s.forms = [
		_form(&"stone", 1, "Granite Fall", "Heavy downward strike, slow but punishing.",
			46.0, 8.0, 1.6, 0.50, 1, 2.5, 1.6, 1, 0.0, 0.7, 1, "breath_stone_1", stone, &"", 0),
		_form(&"stone", 2, "Upper Smash", "Upward slam, stuns target 1.2s.",
			40.0, 14.0, 2.4, 0.40, 1, 2.0, 1.4, 1, 0.0, 0.5, 3, "breath_stone_2", stone, &"", 0),
		_form(&"stone", 3, "Stone Skin Stance", "Guard stance, reduces incoming damage 80% for 3s. Cannot move.",
			0.0, 16.0, 8.0, 0.20, 0, 0.0, 0.0, 1, 0.0, 0.0, 5, "breath_stone_3", stone, &"", 0),
		_form(&"stone", 4, "Volcanic Conquest", "Charged ground slam, 2s windup, AOE shockwave.",
			85.0, 26.0, 5.0, 2.00, 2, 0.0, 5.5, 2, 0.30, 1.5, 9, "breath_stone_4", stone, &"", 0),
		_form(&"stone", 5, "Arc of Mountain", "Sweeping arc strike, 180 degrees in front.",
			62.0, 22.0, 3.5, 0.60, 1, 3.5, 3.5, 2, 0.0, 0.8, 13, "breath_stone_5", stone, &"", 0),
		_form(&"stone", 6, "Iron Mountain Stance", "Immovable, parry counter does 250% damage. 4s window.",
			0.0, 28.0, 12.0, 0.0, 0, 0.0, 0.0, 2, 0.30, 0.0, 17, "breath_stone_6", stone, &"", 0),
		_form(&"stone", 7, "Mountain Splitter", "Massive overhead cleave. Ignores 100% armor. 1.8s windup.",
			260.0, 50.0, 22.0, 1.80, 1, 5.0, 3.0, 3, 0.30, 2.0, 24, "breath_stone_7",
			Color(0.4, 0.35, 0.3), &"stone_6", 0)
	]
	styles[s.id] = s

# ----------------------------------------------------------------
# WIND BREATHING - mobility, multi-hit, sweeping
# ----------------------------------------------------------------
func _register_wind() -> void:
	var s := BreathingStyle.new()
	s.id = &"wind"
	s.display_name = "Wind Breathing"
	s.lore = "Strike from where you weren't. Wind ronin trade armor for speed, depth for breadth. Hit many, hit hard, never stand still."
	s.element = &"physical"
	s.primary_color = Color(0.7, 0.95, 0.7)
	s.min_player_level_for_first_form = 1
	var green := Color(0.7, 0.95, 0.7)
	s.forms = [
		_form(&"wind", 1, "Dust Whirlwind", "Dash through enemies, hits all in path.",
			28.0, 8.0, 1.0, 0.10, 1, 6.0, 1.4, 1, 0.0, 0.3, 1, "breath_wind_1", green, &"", 0),
		_form(&"wind", 2, "Claws Purifying Wind", "5 rapid sweeping strikes, 0.6s total.",
			44.0, 14.0, 1.8, 0.60, 2, 0.0, 2.0, 1, 0.0, 0.4, 4, "breath_wind_2", green, &"", 0),
		_form(&"wind", 3, "Clear Storm Wind Tree", "Upward cyclone, lifts and damages enemies above 3m.",
			52.0, 18.0, 2.5, 0.30, 2, 0.0, 2.5, 2, 0.0, 0.5, 7, "breath_wind_3", green, &"", 0),
		_form(&"wind", 4, "Rising Dust Storm", "Jump and land slash, splits into 4 wind blades on landing.",
			60.0, 20.0, 3.0, 0.50, 2, 0.0, 4.0, 2, 0.20, 0.7, 10, "breath_wind_4", green, &"", 0),
		_form(&"wind", 5, "Cold Mountain Wind", "Line attack with 6m knockback.",
			54.0, 22.0, 3.6, 0.40, 1, 7.0, 1.0, 2, 0.0, 0.6, 13, "breath_wind_5", green, &"", 0),
		_form(&"wind", 6, "Black Wind Mountain Mist", "Charged dash, 2s windup, hits in straight 12m line.",
			95.0, 30.0, 6.0, 2.00, 1, 12.0, 1.6, 3, 0.20, 1.4, 17, "breath_wind_6", green, &"", 0),
		_form(&"wind", 7, "Gale, Sudden Gusts", "Tornado AOE, lifts all enemies in 8m, 12s sustained damage.",
			170.0, 45.0, 18.0, 1.20, 2, 0.0, 8.0, 3, 0.0, 1.6, 23, "breath_wind_7",
			Color(0.55, 1.0, 0.65), &"wind_6", 0)
	]
	styles[s.id] = s

# ----------------------------------------------------------------
# SUN BREATHING - capstone, gated behind Tiamat + 2 other styles mastered
# ----------------------------------------------------------------
func _register_sun() -> void:
	var s := BreathingStyle.new()
	s.id = &"sun"
	s.display_name = "Sun Breathing"
	s.lore = "The first breath. Marduk's own. All other styles are pale derivations. Walk with the sun and the dark cannot find you."
	s.element = &"holy"
	s.primary_color = Color(1.0, 0.85, 0.3)
	s.unlock_save_flag = &"sun_breathing_unlocked"  # permanent flag, survives prestige
	s.requires_mastered_styles = 6  # must have 7th form unlocked in ALL 6 other styles
	s.min_player_level_for_first_form = 18
	s.unlock_hint = "Sealed. The sun is not given to the half-trained. Master Water, Flame, Mist, Thunder, Stone, and Wind to their seventh forms. Walk through the sun-gate after Tiamat falls. Then the first breath remembers you."
	var gold := Color(1.0, 0.9, 0.4)
	s.forms = [
		_form(&"sun", 1, "Dance of the Fire God", "360 degree fire slash, all elements in one swing.",
			95.0, 24.0, 4.0, 0.40, 2, 0.0, 3.5, 2, 0.10, 0.6, 18, "breath_sun_1", gold, &"", 5),
		_form(&"sun", 2, "Clear Blue Sky", "Horizontal cleave with light beam, ignores cover.",
			110.0, 28.0, 5.0, 0.50, 1, 9.0, 2.0, 2, 0.10, 0.7, 19, "breath_sun_2", gold, &"", 5),
		_form(&"sun", 3, "Raging Sun", "Charged forward thrust, 1s windup, hard pierce.",
			135.0, 32.0, 6.5, 1.00, 1, 8.0, 1.0, 2, 0.20, 1.0, 20, "breath_sun_3", gold, &"", 5),
		_form(&"sun", 4, "Burning Bones, Summer Sun", "3-hit chain, rising momentum (each hit +20%).",
			130.0, 36.0, 7.0, 0.70, 1, 4.0, 1.5, 3, 0.10, 0.8, 21, "breath_sun_4", gold, &"", 5),
		_form(&"sun", 5, "Setting Sun Transformation", "Dash through enemy with mid-air flip and double slash.",
			145.0, 38.0, 7.0, 0.40, 1, 8.0, 1.0, 3, 0.15, 0.9, 22, "breath_sun_5", gold, &"", 5),
		_form(&"sun", 6, "Solar Heat Haze", "Illusion strike, two false images, real one auto-crits.",
			165.0, 42.0, 8.0, 0.30, 1, 5.0, 1.5, 3, 0.20, 0.5, 24, "breath_sun_6", gold, &"", 5),
		_form(&"sun", 7, "Beneficent Radiance", "13-hit ultimate, screen-wide, 4s channel. Cannot be interrupted once started.",
			420.0, 80.0, 60.0, 4.00, 2, 0.0, 18.0, 3, 0.0, 3.0, 28, "breath_sun_7",
			Color(1.0, 1.0, 0.6), &"sun_6", 5)
	]
	styles[s.id] = s
