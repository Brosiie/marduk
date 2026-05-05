extends Control
class_name TouchAbilityBar

# Touch-screen ability bar. Renders 4 ability buttons + 4 item slots + dodge/parry
# in a draggable arrangement. Player can long-press a slot to enter rebind mode and
# pick a different ability from the unlocked list.
#
# Anchors bottom-right when virtual joystick is bottom-left, else mirrors.

const SLOT_COUNT := 4
const ITEM_SLOT_COUNT := 4

@export var ability_runner_path: NodePath
@export var slot_size: float = 80.0
@export var spacing: float = 12.0
@export var allow_customization: bool = true

@onready var runner: AbilityRunner = get_node_or_null(ability_runner_path) if ability_runner_path else null
@onready var slots: Array = []
@onready var item_slots: Array = []

var bound_abilities: Array[Ability] = [null, null, null, null]
var bound_items: Array[Item] = [null, null, null, null]
var _customizing_slot: int = -1   # set on long-press, opens picker

func _ready() -> void:
	_build_layout()

func _build_layout() -> void:
	# Ability slots in a 2x2 grid
	for i in range(SLOT_COUNT):
		var btn := _make_slot_button("Q" if i == 0 else ("E" if i == 1 else ("R" if i == 2 else "F")))
		btn.pressed.connect(_on_ability_pressed.bind(i))
		btn.gui_input.connect(_on_slot_input.bind(i, false))
		slots.append(btn)
		add_child(btn)

	# Item slots row
	for i in range(ITEM_SLOT_COUNT):
		var btn := _make_slot_button(str(i + 1))
		btn.pressed.connect(_on_item_pressed.bind(i))
		btn.gui_input.connect(_on_slot_input.bind(i, true))
		item_slots.append(btn)
		add_child(btn)

	# Dodge button (large, separate)
	var dodge := _make_slot_button("DODGE")
	dodge.pressed.connect(func():
		var ev := InputEventAction.new()
		ev.action = &"dodge"
		ev.pressed = true
		Input.parse_input_event(ev))
	add_child(dodge)
	dodge.position = Vector2(0, slot_size * 2 + spacing * 3)
	dodge.custom_minimum_size = Vector2(slot_size * 1.5, slot_size)

	_arrange()

func _make_slot_button(label: String) -> Button:
	var b := Button.new()
	b.custom_minimum_size = Vector2(slot_size, slot_size)
	b.text = label
	b.flat = false
	return b

func _arrange() -> void:
	for i in range(SLOT_COUNT):
		slots[i].position = Vector2((i % 2) * (slot_size + spacing),
			(i / 2) * (slot_size + spacing))
	for i in range(ITEM_SLOT_COUNT):
		item_slots[i].position = Vector2(
			(slot_size + spacing) * 2 + spacing + i * (slot_size + spacing) * 0.6,
			0)

func bind_ability(slot: int, ability: Ability) -> void:
	if slot < 0 or slot >= SLOT_COUNT:
		return
	bound_abilities[slot] = ability
	if ability and ability.icon:
		(slots[slot] as Button).icon = ability.icon
	(slots[slot] as Button).text = ability.display_name if ability else ["Q","E","R","F"][slot]

func bind_item(slot: int, item: Item) -> void:
	if slot < 0 or slot >= ITEM_SLOT_COUNT:
		return
	bound_items[slot] = item
	if item and item.icon:
		(item_slots[slot] as Button).icon = item.icon

func _on_ability_pressed(slot_index: int) -> void:
	if not runner:
		return
	var ab: Ability = bound_abilities[slot_index]
	if ab:
		runner.try_cast(ab)

func _on_item_pressed(slot_index: int) -> void:
	var it: Item = bound_items[slot_index]
	if not it:
		return
	var player = get_tree().get_first_node_in_group("player")
	if player and player.has_method("use_potion"):
		player.use_potion(it)

func _on_slot_input(event: InputEvent, slot_index: int, is_item: bool) -> void:
	# Long-press detection for rebind: tracked via a Timer would be cleaner.
	# Stub: emit a signal the customization screen can pick up.
	if event is InputEventScreenTouch and event.pressed:
		_customizing_slot = slot_index
		# In a full impl, start a timer; if held > 0.6s, open picker.
