extends Control
class_name CharacterCreation

# Character creation screen. Lists selectable classes (filtered by SaveFlags
# unlock state for Demon), shows class lore + base stats + resource type, lets
# the player input a name, then routes to the class-specific intro zone.

signal class_chosen(class_def: PlayerClass, character_name: String)
signal cancelled

@onready var class_list: ItemList = $Margin/Panel/Layout/Left/ClassList if has_node("Margin/Panel/Layout/Left/ClassList") else null
@onready var preview_name: Label = $Margin/Panel/Layout/Right/Header/ClassName if has_node("Margin/Panel/Layout/Right/Header/ClassName") else null
@onready var preview_lore: RichTextLabel = $Margin/Panel/Layout/Right/Body/Lore if has_node("Margin/Panel/Layout/Right/Body/Lore") else null
@onready var preview_stats: Label = $Margin/Panel/Layout/Right/Body/Stats if has_node("Margin/Panel/Layout/Right/Body/Stats") else null
@onready var preview_resource: Label = $Margin/Panel/Layout/Right/Body/Resource if has_node("Margin/Panel/Layout/Right/Body/Resource") else null
@onready var lock_hint: Label = $Margin/Panel/Layout/Right/Body/LockHint if has_node("Margin/Panel/Layout/Right/Body/LockHint") else null
@onready var name_input: LineEdit = $Margin/Panel/Layout/Right/Footer/NameInput if has_node("Margin/Panel/Layout/Right/Footer/NameInput") else null
@onready var begin_button: Button = $Margin/Panel/Layout/Right/Footer/BeginButton if has_node("Margin/Panel/Layout/Right/Footer/BeginButton") else null

var _classes: Array[PlayerClass] = []
var _selected: PlayerClass = null

func _ready() -> void:
	_classes = ClassRegistry.all_classes()
	if class_list:
		class_list.item_selected.connect(_on_class_selected)
	if begin_button:
		begin_button.pressed.connect(_on_begin)
	_populate()

func _populate() -> void:
	if not class_list:
		return
	class_list.clear()
	for c in _classes:
		var label := c.display_name
		if not SaveFlags.is_class_unlocked(c):
			label += "  (LOCKED)"
		class_list.add_item(label)
	if _classes.size() > 0:
		class_list.select(0)
		_on_class_selected(0)

func _on_class_selected(index: int) -> void:
	if index < 0 or index >= _classes.size():
		return
	_selected = _classes[index]
	if preview_name: preview_name.text = _selected.display_name
	if preview_lore: preview_lore.text = _selected.lore
	if preview_stats:
		preview_stats.text = "HP %d  MP %d  STR %d  DEX %d  INT %d  VIT %d" % [
			int(_selected.base_hp), int(_selected.base_mana),
			_selected.base_strength, _selected.base_dexterity,
			_selected.base_intellect, _selected.base_vitality
		]
	if preview_resource:
		preview_resource.text = "Resource: %s" % String(_selected.resource_mechanic).to_upper()
	if lock_hint:
		var locked := not SaveFlags.is_class_unlocked(_selected)
		lock_hint.visible = locked
		lock_hint.text = _selected.unlock_hint if locked else ""
	if begin_button:
		begin_button.disabled = not SaveFlags.is_class_unlocked(_selected)

func _on_begin() -> void:
	if not _selected or not SaveFlags.is_class_unlocked(_selected):
		return
	var nm := "Champion"
	if name_input and name_input.text.strip_edges() != "":
		nm = name_input.text.strip_edges()
	class_chosen.emit(_selected, nm)
