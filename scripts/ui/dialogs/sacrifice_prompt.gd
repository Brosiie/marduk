extends CanvasLayer
class_name SacrificePrompt

# UI controller for the Heaven-Rule sacrifice prompt.
# Subscribes to the player's Inventory.sacrifice_required signal at scene load.
# When fired, shows a modal dialog disclosing the full sacrifice cost upfront,
# then on accept calls SacrificeRitual.walk_back(player) and re-attempts the equip.
#
# See DEMON_VISUAL_TRANSFORMATION.md § 18 for the design.

signal sacrifice_accepted(player: Node, item: Item)
signal sacrifice_refused(player: Node, item: Item)

const RONIN_BIND_LINE := "Heaven will bind:   YES"
const NON_RONIN_NO_BIND_LINE := "Heaven will bind:   NO — the sword remains Ronin-only"

@onready var dim_layer: ColorRect = $DimLayer if has_node("DimLayer") else null
@onready var panel: PanelContainer = $Panel if has_node("Panel") else null
@onready var prose_label: Label = $Panel/Margin/VBox/ProseLabel if has_node("Panel/Margin/VBox/ProseLabel") else null
@onready var info_label: Label = $Panel/Margin/VBox/InfoLabel if has_node("Panel/Margin/VBox/InfoLabel") else null
@onready var accept_btn: Button = $Panel/Margin/VBox/HBox/AcceptBtn if has_node("Panel/Margin/VBox/HBox/AcceptBtn") else null
@onready var refuse_btn: Button = $Panel/Margin/VBox/HBox/RefuseBtn if has_node("Panel/Margin/VBox/HBox/RefuseBtn") else null

var _bound_player: Node = null
var _pending_item: Item = null

func _ready() -> void:
	# Default hidden until triggered
	visible = false
	# Wire buttons
	if accept_btn:
		accept_btn.pressed.connect(_on_accept_pressed)
	if refuse_btn:
		refuse_btn.pressed.connect(_on_refuse_pressed)
	# Auto-bind to the player when one is present in the scene
	_try_bind_player()
	# Re-bind if a player is added later
	get_tree().node_added.connect(_on_node_added)

func _on_node_added(node: Node) -> void:
	if not _bound_player and node.is_in_group("player"):
		_bound_player = node
		_subscribe_to_inventory(node)

func _try_bind_player() -> void:
	for p in get_tree().get_nodes_in_group("player"):
		if is_instance_valid(p):
			_bound_player = p
			_subscribe_to_inventory(p)
			break

func _subscribe_to_inventory(player: Node) -> void:
	if not player.get("inventory") or not player.inventory:
		return
	var inv = player.inventory
	if inv.has_signal("sacrifice_required") and not inv.sacrifice_required.is_connected(_on_sacrifice_required):
		inv.sacrifice_required.connect(_on_sacrifice_required)

# Called when Inventory.equip detects the Demon + Heaven mismatch.
func _on_sacrifice_required(item: Item, _class_def) -> void:
	if not _bound_player or not is_instance_valid(_bound_player):
		return
	_pending_item = item
	_show_modal()

func _show_modal() -> void:
	if not _bound_player or not _pending_item:
		return
	visible = true
	if dim_layer:
		dim_layer.color = Color(0, 0, 0, 0.7)
	# Pause the game while the prompt is up — this is a sacred moment
	get_tree().paused = true
	process_mode = Node.PROCESS_MODE_ALWAYS  # we keep ticking even while paused

	# Compose the prose. Pre-Lucifer class drives the binding line.
	var pre_class_id: StringName = &""
	var ca = _bound_player.get("character_appearance")
	if ca:
		pre_class_id = ca.pre_lucifer_class_id
	if pre_class_id == &"":
		pre_class_id = &"ronin"  # fallback per § 18.9
	var class_registry: Node = get_node_or_null("/root/ClassRegistry")
	var pre_display: String = "Unknown"
	if class_registry and class_registry.has_method("get_class_def"):
		var pre = class_registry.get_class_def(pre_class_id)
		if pre:
			pre_display = pre.display_name
	var bind_line: String = RONIN_BIND_LINE if pre_class_id == &"ronin" else NON_RONIN_NO_BIND_LINE

	if prose_label:
		prose_label.text = (
			"The katana lies still in your demon-hand.\n"
			+ "It will not warm to you.\n\n"
			+ "You may walk back through Lucifer's gate. Once.\n\n"
			+ "The Demon you became will dissolve. The soul you walked into Lucifer with will return.\n"
			+ "You will be mortal again.\n\n"
			+ "Your race, your face, the marks you bear from the fight to here — these stay.\n"
			+ "The horns, the veins, the hunger — these go.\n\n"
			+ "The gate does not open twice. Once chosen, this cannot be undone."
		)
	if info_label:
		info_label.text = "Pre-Lucifer class:  %s\n%s" % [pre_display.to_upper(), bind_line]

	# Accept button label echoes the binding outcome
	if accept_btn:
		if pre_class_id == &"ronin":
			accept_btn.text = "ACCEPT — WALK BACK AND CLAIM HEAVEN"
		else:
			accept_btn.text = "ACCEPT — WALK BACK (Heaven will not bind)"

func _hide_modal() -> void:
	visible = false
	get_tree().paused = false
	_pending_item = null

func _on_accept_pressed() -> void:
	if not _bound_player or not _pending_item:
		_hide_modal()
		return
	var item: Item = _pending_item
	# Run the ritual
	var ok: bool = SacrificeRitual.walk_back(_bound_player)
	_hide_modal()
	if ok:
		sacrifice_accepted.emit(_bound_player, item)
		# After the ritual, retry the equip on the original item.
		# If pre-Lucifer was Ronin, the ritual already auto-equipped Heaven.
		if _bound_player.get("inventory") and _bound_player.inventory.has_method("equip"):
			# Only retry if we still have the item and the class can now wield it
			if _bound_player.stats and _bound_player.stats.class_def:
				_bound_player.inventory.equip(item, -1, _bound_player.stats.class_def)

func _on_refuse_pressed() -> void:
	_hide_modal()
	if _bound_player and _pending_item:
		sacrifice_refused.emit(_bound_player, _pending_item)
