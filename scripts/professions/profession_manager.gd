extends Node
class_name ProfessionManager

# Per-player tracker of profession progress. Each profession has its own level + XP.
# XP curve is independent of character level: 1-100 per profession, no shared pool.

const MAX_LEVEL := 100

class Track:
	var profession_id: StringName
	var level: int = 1
	var xp: int = 0
	var unlocked_recipes: Array[StringName] = []

@export var owner_player: Node

var tracks: Dictionary = {}  # StringName id -> Track

signal profession_leveled_up(profession_id: StringName, new_level: int)
signal profession_xp_gained(profession_id: StringName, amount: int)
signal recipe_unlocked(profession_id: StringName, recipe_id: StringName)
signal craft_completed(recipe_id: StringName, output: Item, count: int)
signal gather_completed(profession_id: StringName, item: Item, count: int)

func _ready() -> void:
	# Default tracks for the four canonical professions
	for kind_id in [&"smithing", &"mining", &"woodcutting", &"crafting"]:
		var t := Track.new()
		t.profession_id = kind_id
		tracks[kind_id] = t

func get_track(prof_id: StringName) -> Track:
	return tracks.get(prof_id)

func level_of(prof_id: StringName) -> int:
	var t := get_track(prof_id)
	return t.level if t else 1

func xp_to_next_level(prof_id: StringName) -> int:
	var t := get_track(prof_id)
	if not t or t.level >= MAX_LEVEL:
		return 0
	# Slightly steeper than character XP - profession mastery is a long road
	return int(50 * pow(t.level, 1.7))

func gain_xp(prof_id: StringName, amount: int) -> void:
	var t := get_track(prof_id)
	if not t or t.level >= MAX_LEVEL:
		return
	t.xp += amount
	profession_xp_gained.emit(prof_id, amount)
	while t.level < MAX_LEVEL and t.xp >= xp_to_next_level(prof_id):
		t.xp -= xp_to_next_level(prof_id)
		t.level += 1
		profession_leveled_up.emit(prof_id, t.level)

# Gathering: called when a node is harvested
func register_gather(prof_id: StringName, item: Item, count: int, xp: int) -> void:
	gain_xp(prof_id, xp)
	gather_completed.emit(prof_id, item, count)
	if owner_player and owner_player.has_method("get_inventory"):
		var inv: Inventory = owner_player.get_inventory()
		if inv and item:
			inv.add_item(item, count)

# Crafting: validate recipe, consume ingredients, award output + XP
func try_craft(recipe: Recipe) -> bool:
	if not recipe or not recipe.output_item:
		return false
	var t := get_track(recipe.profession_id)
	if not t:
		return false
	if t.level < recipe.required_profession_level:
		return false
	if recipe.required_recipe_unlocked != &"" and not (recipe.required_recipe_unlocked in t.unlocked_recipes):
		return false
	if not owner_player or not owner_player.has_method("get_inventory"):
		return false
	var inv: Inventory = owner_player.get_inventory()
	if not inv:
		return false
	# Verify ingredients
	var ings: Array = recipe.build_ingredients()
	for ing in ings:
		if inv.count_of(ing.item_id) < ing.count:
			return false
	# Consume
	for ing in ings:
		inv.remove_item(ing.item_id, ing.count)
	# Award output
	inv.add_item(recipe.output_item, recipe.output_count)
	gain_xp(recipe.profession_id, recipe.xp_award)
	craft_completed.emit(recipe.id, recipe.output_item, recipe.output_count)
	return true

func unlock_recipe(prof_id: StringName, recipe_id: StringName) -> void:
	var t := get_track(prof_id)
	if t and not (recipe_id in t.unlocked_recipes):
		t.unlocked_recipes.append(recipe_id)
		recipe_unlocked.emit(prof_id, recipe_id)
