extends Resource
class_name Vendor

# A shopkeeper. Can be placed in zones via NPCs or attached as a vendor record on
# an NPC node. Inventory is regenerated periodically, item levels match the
# zone's recommended_level so vendors never sell content the player has outgrown.

class Stock:
	var item_id: StringName
	var quantity: int = 1     # -1 = infinite
	var price_override: int = 0  # 0 = use item.sell_value * sell_markup

@export var id: StringName = &""
@export var display_name: String = ""
@export_multiline var greeting: String = ""
@export var faction: StringName = &""
@export var home_zone_id: StringName = &""

@export_group("Pricing")
@export var sell_markup: float = 1.5     # vendor sells at sell_value * 1.5
@export var buy_markup: float = 0.35     # vendor buys junk at sell_value * 0.35
@export var refuses_quest_items: bool = true
@export var refuses_soulbound: bool = true

@export_group("Inventory")
@export var stocked_items: Array = []     # of Stock dicts (use add_stock helper)
@export var refresh_interval_seconds: float = 600.0  # 10-minute restock

@export_group("Stocking Recipe")
# Auto-stock by recipe: vendor offers tiered consumables and basic gear matching its zone.
@export var auto_stock_potions: bool = true   # health/mana/stamina by region tier
@export var auto_stock_basic_gear: bool = true # 2-3 white/green pieces per slot
@export var basic_gear_min_level: int = 1
@export var basic_gear_max_level: int = 10

func add_stock(item_id: StringName, quantity: int = -1, price_override: int = 0) -> void:
	stocked_items.append({"item_id": String(item_id), "quantity": quantity, "price_override": price_override})

func sell_price(item: Item, player_rep: int = 0) -> int:
	if not item:
		return 0
	var mod: Dictionary = tier_modifier(player_rep)
	if bool(mod.get("refuses_trade", false)):
		return 0
	var mult: float = float(mod.get("sell_mult", 1.0))
	return int(round(float(item.sell_value) * sell_markup * mult))

func buy_price(item: Item, player_rep: int = 0) -> int:
	if not item:
		return 0
	if refuses_quest_items and item.is_quest_item:
		return 0
	if refuses_soulbound and item.is_soulbound:
		return 0
	var mod: Dictionary = tier_modifier(player_rep)
	if bool(mod.get("refuses_trade", false)):
		return 0
	var mult: float = float(mod.get("buy_mult", 1.0))
	return int(round(float(item.sell_value) * buy_markup * mult))

func can_buy(item: Item, player_rep: int = 0) -> bool:
	return buy_price(item, player_rep) > 0

func will_trade(player_rep: int) -> bool:
	# Hostile and Hated tiers refuse trade outright. Tier breakpoints
	# mirror FactionRegistry so the boundary is consistent.
	# Vendors with no faction (faction == &"") trade with anyone.
	if faction == &"":
		return true
	return player_rep >= -3000  # >= Unfriendly floor

func tier_modifier(player_rep: int) -> Dictionary:
	# Returns {sell_mult, buy_mult, refuses_trade} based on rep with the
	# vendor's faction. Vendors with no faction return baseline.
	# Sell mult < 1.0 = vendor charges player less. Buy mult > 1.0 =
	# vendor pays player more for junk. Both lean toward the player as
	# rep climbs, so the tier ladder is a tangible reward.
	if faction == &"":
		return {"sell_mult": 1.0, "buy_mult": 1.0, "refuses_trade": false}
	if player_rep < -3000:
		return {"sell_mult": 1.0, "buy_mult": 1.0, "refuses_trade": true}
	if player_rep < 0:
		return {"sell_mult": 1.20, "buy_mult": 0.80, "refuses_trade": false}  # Unfriendly
	if player_rep < 3000:
		return {"sell_mult": 1.00, "buy_mult": 1.00, "refuses_trade": false}  # Neutral
	if player_rep < 9000:
		return {"sell_mult": 0.95, "buy_mult": 1.05, "refuses_trade": false}  # Friendly
	if player_rep < 21000:
		return {"sell_mult": 0.90, "buy_mult": 1.10, "refuses_trade": false}  # Honored
	if player_rep < 42000:
		return {"sell_mult": 0.85, "buy_mult": 1.15, "refuses_trade": false}  # Revered
	return {"sell_mult": 0.80, "buy_mult": 1.20, "refuses_trade": false}      # Exalted

func auto_generated_potions() -> Array[StringName]:
	# Picks the right potion tier based on basic_gear_min_level.
	var tier_pool: Array[StringName] = []
	var min_lvl := basic_gear_min_level
	if min_lvl < 10:
		tier_pool = [&"potion_hp_minor", &"potion_mana_minor", &"potion_stamina_minor"]
	elif min_lvl < 25:
		tier_pool = [&"potion_hp_lesser", &"potion_mana_lesser", &"potion_stamina_minor"]
	elif min_lvl < 45:
		tier_pool = [&"potion_hp_greater", &"potion_mana_greater", &"potion_stamina_minor"]
	elif min_lvl < 70:
		tier_pool = [&"potion_hp_major", &"potion_mana_major", &"potion_stamina_minor", &"potion_mana_surge", &"potion_hp_surge", &"potion_stamina_surge"]
	else:
		tier_pool = [&"potion_hp_supreme", &"potion_mana_major", &"potion_champions_draught", &"potion_mana_surge", &"potion_stamina_surge"]
	return tier_pool
