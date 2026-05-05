extends Control
class_name AbilityBar

# Ability slot bar (Q E R F). Each slot binds to an Ability and shows icon, cooldown
# overlay, hotkey label, and resource cost preview.

@export var runner_path: NodePath
@onready var runner: AbilityRunner = get_node_or_null(runner_path) if runner_path else null

@onready var slots: Array[Control] = [
	$Slots/Slot1 if has_node("Slots/Slot1") else null,
	$Slots/Slot2 if has_node("Slots/Slot2") else null,
	$Slots/Slot3 if has_node("Slots/Slot3") else null,
	$Slots/Slot4 if has_node("Slots/Slot4") else null
]

# Mapping: input action -> slot index (Q/E/R/F)
const ACTIONS := [&"ability_1", &"ability_2", &"ability_3", &"ability_4"]
const HOTKEY_LABELS := ["Q", "E", "R", "F"]

var bound_abilities: Array[Ability] = [null, null, null, null]

func _process(_delta: float) -> void:
	if not runner:
		return
	for i in range(slots.size()):
		var slot := slots[i]
		if not slot:
			continue
		var ab: Ability = bound_abilities[i]
		if not ab:
			continue
		# Cooldown overlay
		var cd_remaining: float = runner.cooldown_remaining(ab.id)
		if slot.has_node("Cooldown"):
			var cd_label: Label = slot.get_node("Cooldown")
			if cd_remaining > 0.05:
				cd_label.visible = true
				cd_label.text = "%.1f" % cd_remaining
			else:
				cd_label.visible = false

func bind_ability(slot: int, ability: Ability) -> void:
	if slot < 0 or slot >= 4:
		return
	bound_abilities[slot] = ability
	if slots[slot] and slots[slot].has_node("Icon") and ability.icon:
		(slots[slot].get_node("Icon") as TextureRect).texture = ability.icon
	if slots[slot] and slots[slot].has_node("Hotkey"):
		(slots[slot].get_node("Hotkey") as Label).text = HOTKEY_LABELS[slot]

func _input(event: InputEvent) -> void:
	if not runner:
		return
	for i in range(ACTIONS.size()):
		if event.is_action_pressed(ACTIONS[i]):
			var ab: Ability = bound_abilities[i]
			if ab:
				runner.try_cast(ab)
