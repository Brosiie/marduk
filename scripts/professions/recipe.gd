extends Resource
class_name Recipe

# A crafting recipe: input items + output item + profession requirement.
# Each successful craft awards profession XP scaled by required level.

class Ingredient:
	var item_id: StringName
	var count: int = 1

@export var id: StringName = &""
@export var display_name: String = ""
@export_multiline var description: String = ""
@export var icon: Texture2D

@export_group("Requirements")
@export var profession_id: StringName = &""
@export var required_profession_level: int = 1
@export var required_class: Array[StringName] = []  # empty = any
@export var required_recipe_unlocked: StringName = &""  # for chained tech tree

@export_group("Inputs")
@export var ingredients_data: Array = []  # serialized: [{item_id, count}, ...]

@export_group("Output")
@export var output_item: Item
@export var output_count: int = 1
@export var output_rarity_min: int = Item.Rarity.BASIC
@export var output_rarity_max: int = Item.Rarity.RARE  # crafting can roll up

@export_group("Reward")
@export var xp_award: int = 25
@export var craft_time_seconds: float = 1.5

func build_ingredients() -> Array:
	var arr: Array = []
	for d in ingredients_data:
		var ing := Ingredient.new()
		ing.item_id = StringName(d.get("item_id", ""))
		ing.count = int(d.get("count", 1))
		arr.append(ing)
	return arr
