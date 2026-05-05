extends Resource
class_name SpellSchool

@export var id: StringName = &""
@export var display_name: String = ""
@export_multiline var lore: String = ""
@export var element: int = Item.Element.ARCANE
@export var primary_color: Color = Color.WHITE
@export var spells: Array[MageSpell] = []
@export var min_player_level_for_first_spell: int = 1

func get_spell(tier: int) -> MageSpell:
	for s: MageSpell in spells:
		if s.tier == tier:
			return s
	return null
