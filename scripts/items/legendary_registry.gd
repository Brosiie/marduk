extends Node

# Autoload: holds the 7 class-bound legendaries + the Heaven katana.
#
# Drop rules (enforced by LootTable.boss_roll()):
#   - Any boss (mini or main): guaranteed one VERY_RARE drop, plus 1% chance to drop
#     the LEGENDARY for the killer's class.
#   - Final boss (Tiamat): same as above, plus 1% chance to drop ANY of the 7 legendaries
#     (cross-class), plus 0.5% chance to drop Heaven.
#   - Lucifer (post-Tiamat secret): same as final boss + guaranteed Demon class unlock.
#
# Heaven cannot drop again once obtained on a save profile (permanent flag check).

var class_legendaries: Dictionary = {}  # StringName class_id -> Item (LEGENDARY rarity)
var heaven: Item

func _ready() -> void:
	_build_berserker_legendary()
	_build_assassin_legendary()
	_build_ronin_legendary()
	_build_ranger_legendary()
	_build_mage_legendary()
	_build_druid_legendary()
	_build_demon_legendary()
	_build_heaven()

func get_legendary_for(class_id: StringName) -> Item:
	return class_legendaries.get(class_id)

func random_legendary() -> Item:
	var keys: Array = class_legendaries.keys()
	if keys.is_empty():
		return null
	return class_legendaries[keys[randi() % keys.size()]]

func get_heaven() -> Item:
	return heaven

# ----------------------------------------------------------------
# Berserker - Hassu's Hooked Spear
# ----------------------------------------------------------------
func _build_berserker_legendary() -> void:
	var i := Item.new()
	i.id = &"legendary_berserker_hooked_spear"
	i.display_name = "Hassu's Hooked Spear"
	i.description = "Pulled from the chest of the Hooked himself. Tasted your father's blood. Tastes everyone's now."
	i.slot = Item.Slot.WEAPON_MAIN
	i.rarity = Item.Rarity.LEGENDARY
	i.class_restriction = [&"berserker"]
	i.item_level = 90
	i.strength_bonus = 28.0
	i.vitality_bonus = 12.0
	i.damage_bonus_pct = 0.18
	i.crit_chance_bonus = 0.06
	i.crit_multiplier_bonus = 0.25
	i.implicit_text = "Rage gain doubled. +50% damage when below 30% HP. Killing blow refunds full rage."
	i.unique_tags = [&"rage_on_damage_taken", &"low_hp_amplifier"]
	i.sell_value = 5000
	class_legendaries[&"berserker"] = i

# ----------------------------------------------------------------
# Assassin - The Five-Mouthed Whisper
# ----------------------------------------------------------------
func _build_assassin_legendary() -> void:
	var i := Item.new()
	i.id = &"legendary_assassin_five_mouthed"
	i.display_name = "The Five-Mouthed Whisper"
	i.description = "Master Sapum's last gift. The five mouths still whisper, but only to you, and only at night."
	i.slot = Item.Slot.WEAPON_MAIN
	i.rarity = Item.Rarity.LEGENDARY
	i.class_restriction = [&"assassin"]
	i.item_level = 90
	i.dexterity_bonus = 26.0
	i.intellect_bonus = 14.0
	i.crit_chance_bonus = 0.15
	i.crit_multiplier_bonus = 0.35
	i.implicit_text = "Crits inflict stacking poison. Stealth-broken hits guarantee crit. Each kill leaves a vanish-cloud."
	i.unique_tags = [&"poison_crit", &"stealth_amplifier"]
	i.sell_value = 5000
	class_legendaries[&"assassin"] = i

# ----------------------------------------------------------------
# Ronin - Vow's End
# ----------------------------------------------------------------
func _build_ronin_legendary() -> void:
	var i := Item.new()
	i.id = &"legendary_ronin_vows_end"
	i.display_name = "Vow's End"
	i.description = "Lord Ennum's blade, recovered from the throne hall. The breaths sing through it cleaner than through any temple steel."
	i.slot = Item.Slot.WEAPON_MAIN
	i.rarity = Item.Rarity.LEGENDARY
	i.class_restriction = [&"ronin"]
	i.item_level = 90
	i.dexterity_bonus = 28.0
	i.strength_bonus = 14.0
	i.crit_chance_bonus = 0.10
	i.crit_multiplier_bonus = 0.50
	i.implicit_text = "Chain bonus multiplier x2. Perfect parries deal posture damage back. Stance charges build double."
	i.unique_tags = [&"chain_amplifier", &"parry_counter"]
	i.sell_value = 5000
	class_legendaries[&"ronin"] = i

# ----------------------------------------------------------------
# Ranger - Glade-Mother's Bow
# ----------------------------------------------------------------
func _build_ranger_legendary() -> void:
	var i := Item.new()
	i.id = &"legendary_ranger_glade_mothers_bow"
	i.display_name = "Glade-Mother's Bow"
	i.description = "Carved from the heart-tree of the Greenheart, strung with a sister's hair. Aimed always true."
	i.slot = Item.Slot.WEAPON_MAIN
	i.rarity = Item.Rarity.LEGENDARY
	i.class_restriction = [&"ranger"]
	i.item_level = 90
	i.dexterity_bonus = 30.0
	i.intellect_bonus = 10.0
	i.crit_chance_bonus = 0.12
	i.implicit_text = "Arrows pierce all enemies in line. Focus stacks build at 3x rate. Critical kills shatter into seeking sparks (3 extra hits)."
	i.unique_tags = [&"piercing_focus", &"shatter_arrows"]
	i.sell_value = 5000
	class_legendaries[&"ranger"] = i

# ----------------------------------------------------------------
# Mage - Asaridu's Final Page
# ----------------------------------------------------------------
func _build_mage_legendary() -> void:
	var i := Item.new()
	i.id = &"legendary_mage_final_page"
	i.display_name = "Asaridu's Final Page"
	i.description = "The single page Old Asaridu tore from the Codex of Bindings before sealing himself in the well. The ink is still wet."
	i.slot = Item.Slot.WEAPON_MAIN
	i.rarity = Item.Rarity.LEGENDARY
	i.class_restriction = [&"mage"]
	i.item_level = 90
	i.intellect_bonus = 32.0
	i.mana_bonus = 60.0
	i.damage_bonus_pct = 0.20
	i.implicit_text = "Spells cost 30% less mana. Crits deal damage twice. Mana regen doubled while standing still."
	i.unique_tags = [&"double_crit_spells", &"mana_efficiency"]
	i.sell_value = 5000
	class_legendaries[&"mage"] = i

# ----------------------------------------------------------------
# Chaos Druid - The Sanctum's Ash
# ----------------------------------------------------------------
func _build_druid_legendary() -> void:
	var i := Item.new()
	i.id = &"legendary_druid_sanctums_ash"
	i.display_name = "The Sanctum's Ash"
	i.description = "What was left of your coven, pressed into a stone the size of a sparrow's heart. It is warm. Always warm."
	i.slot = Item.Slot.CHARM
	i.rarity = Item.Rarity.LEGENDARY
	i.class_restriction = [&"chaos_druid"]
	i.item_level = 90
	i.intellect_bonus = 22.0
	i.vitality_bonus = 16.0
	i.armor_bonus = 14.0
	i.implicit_text = "Form duration +50%. Dragon form available without skill-tree capstone. Form Energy regenerates while transformed at half rate."
	i.unique_tags = [&"capstone_dragon_free", &"in_form_regen"]
	i.sell_value = 5000
	class_legendaries[&"chaos_druid"] = i

# ----------------------------------------------------------------
# Demon - Lucifer's Shed
# ----------------------------------------------------------------
func _build_demon_legendary() -> void:
	var i := Item.new()
	i.id = &"legendary_demon_lucifers_shed"
	i.display_name = "Lucifer's Shed"
	i.description = "He molted before he died. The skin is still thinking about the negotiations you refused."
	i.slot = Item.Slot.CHEST
	i.rarity = Item.Rarity.LEGENDARY
	i.class_restriction = [&"demon"]
	i.item_level = 95
	i.strength_bonus = 18.0
	i.intellect_bonus = 18.0
	i.vitality_bonus = 24.0
	i.armor_bonus = 18.0
	i.magic_resist_bonus = 18.0
	i.implicit_text = "Corruption builds from damage dealt instead of self-bleed. HP-cost abilities cost half. Reduces all damage taken by 15%."
	i.unique_tags = [&"corrupt_from_damage", &"halved_self_bleed"]
	i.sell_value = 7500
	class_legendaries[&"demon"] = i

# ----------------------------------------------------------------
# HEAVEN - the pure-white katana, soulbound, demon/undead one-shot
# ----------------------------------------------------------------
func _build_heaven() -> void:
	var i := Item.new()
	i.id = &"heaven"
	i.display_name = "Heaven"
	i.description = "A pure white katana. The handle is wrapped in cloth that does not yellow. The guard is a circle in the shape of a sun. It is not warm, not cold, not heavy. It does not weigh on the carrier; the carrier weighs on it. It chooses you. It will not choose another. Only those who have walked the seven breaths to the sun can hold it."
	i.slot = Item.Slot.WEAPON_MAIN
	i.rarity = Item.Rarity.HEAVEN
	# Heaven is Ronin's alone. The sword chooses the seven-breath sword-master.
	# Drops only when a Ronin lands the killing blow (BossBase enforces this).
	# Wielding additionally requires Sun Breathing access (Player enforces this).
	i.class_restriction = [&"ronin"]
	i.item_level = 100
	i.strength_bonus = 25.0
	i.dexterity_bonus = 25.0
	i.intellect_bonus = 25.0
	i.vitality_bonus = 25.0
	i.armor_bonus = 30.0
	i.magic_resist_bonus = 30.0
	i.crit_chance_bonus = 0.10
	i.crit_multiplier_bonus = 0.50
	i.damage_bonus_pct = 0.30  # base; permanent stack adds to this
	i.is_soulbound = true
	i.auto_returns_to_inventory = true
	i.is_quest_item = false  # not a quest item per se, but bound to carrier forever
	i.implicit_text = "Ronin only. Wielding requires Sun Breathing (Form 1 minimum).\nSoulbound. Cannot be dropped, traded, or auctioned. Returns to inventory if removed.\nHeals the wielder and all allies within 6m for 5 HP/sec at all times.\nInstantly slays any demon or undead struck. Slain enemies turn to ash and are absorbed.\nEach absorbed kill increases all damage by 0.01% permanently. The stack does not reset on prestige."
	i.unique_tags = [
		&"infinite_heal_aura",
		&"oneshot_demon_undead",
		&"absorbs_kills",
		&"bound_to_carrier",
		&"requires_sun_breathing"
	]
	i.passive_heal_radius = 6.0
	i.passive_heal_per_sec = 5.0
	i.permanent_dmg_stack_per_kill = 0.0001  # 0.01% per kill
	i.sell_value = 0  # cannot be sold
	heaven = i
