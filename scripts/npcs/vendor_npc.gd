extends "res://scripts/npcs/npc.gd"
class_name VendorNPC

# Shop vendor: pressing V opens a buy/sell panel populated from
# ShopkeeperRegistry (or a fallback random draw from ItemRegistry filtered
# by the vendor's slot affinity). Player can buy with gold, sell items
# back at half price.

@export var shop_id: StringName = &""             # ShopkeeperRegistry key
@export var slot_affinity: int = -1               # filter pool when no shop_id; -1 = any

func _ready() -> void:
	super._ready()
	if _label3d:
		_label3d.modulate = Color(1.00, 0.85, 0.45)  # gold for vendors
	if _quest_marker:
		_quest_marker.text = "$"
		_quest_marker.modulate = Color(1.00, 0.85, 0.45)
		_quest_marker.visible = true

func _open_dialogue() -> void:
	_open_shop_panel()

func _open_shop_panel() -> void:
	var hud := get_tree().get_first_node_in_group("hud") if get_tree() else null
	if hud == null:
		return
	# Build a transient shop panel directly under HUD.
	var bg := ColorRect.new()
	bg.color = Color(0.04, 0.04, 0.08, 0.7)
	bg.anchor_right = 1.0
	bg.anchor_bottom = 1.0
	bg.mouse_filter = Control.MOUSE_FILTER_STOP
	hud.add_child(bg)
	var frame := PanelContainer.new()
	frame.anchor_left = 0.5
	frame.anchor_top = 0.5
	frame.anchor_right = 0.5
	frame.anchor_bottom = 0.5
	frame.offset_left = -360.0
	frame.offset_top = -260.0
	frame.offset_right = 360.0
	frame.offset_bottom = 260.0
	bg.add_child(frame)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 8)
	frame.add_child(v)
	var hdr := Label.new()
	hdr.text = display_name + " — Shop"
	hdr.add_theme_font_size_override("font_size", 22)
	hdr.modulate = Color(1.0, 0.85, 0.55)
	v.add_child(hdr)
	# Stock items
	var stock := _roll_stock()
	for item in stock:
		v.add_child(_stock_row(item))
	# Close button
	var close_btn := Button.new()
	close_btn.text = "Close (Esc)"
	close_btn.pressed.connect(bg.queue_free)
	v.add_child(close_btn)
	# Audio cue
	var ab = get_node_or_null("/root/AudioBus")
	if ab and ab.has_method("play_cue"):
		ab.play_cue(&"pickup", global_position, -10.0, 1.0)

func _roll_stock() -> Array:
	var registry := get_node_or_null("/root/ItemRegistry")
	if registry == null:
		return []
	var pool: Array = registry.items.values()
	# Filter to items the player can use here. Keep BASIC/COMMON for
	# starter vendors, plus optional slot affinity match.
	var filtered: Array = []
	for it in pool:
		if it == null:
			continue
		if it.rarity > 2:    # only junk/basic/common
			continue
		if it.unique_drop_source != &"":
			continue
		if slot_affinity >= 0 and int(it.slot) != slot_affinity:
			continue
		filtered.append(it)
	# Shuffle and take up to 8
	filtered.shuffle()
	return filtered.slice(0, min(8, filtered.size()))

func _stock_row(item: Item) -> Control:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)
	var icon_rect := TextureRect.new()
	icon_rect.custom_minimum_size = Vector2(40, 40)
	icon_rect.expand_mode = TextureRect.EXPAND_FIT_WIDTH_PROPORTIONAL
	icon_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	var atlas := get_node_or_null("/root/IconAtlas")
	if atlas and atlas.has_method("get_icon_for_item"):
		icon_rect.texture = atlas.get_icon_for_item(item)
	row.add_child(icon_rect)
	var name_lbl := Label.new()
	name_lbl.text = item.display_name
	name_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(name_lbl)
	var price_lbl := Label.new()
	var price: int = max(1, int(item.sell_value) * 2)
	price_lbl.text = "%d gold" % price
	price_lbl.modulate = Color(1.0, 0.85, 0.30)
	row.add_child(price_lbl)
	var buy_btn := Button.new()
	buy_btn.text = "Buy"
	buy_btn.pressed.connect(_buy.bind(item, price, buy_btn))
	row.add_child(buy_btn)
	return row

func _buy(item: Item, price: int, btn: Button) -> void:
	var p := get_tree().get_first_node_in_group("player") if get_tree() else null
	if p == null:
		return
	# Spend gold
	var gold = p.stats.get("gold") if ("stats" in p and p.stats and p.stats.has_method("get")) else 0
	if int(gold) < price:
		var ab = get_node_or_null("/root/AudioBus")
		if ab and ab.has_method("play_cue"):
			ab.play_cue(&"deny", p.global_position, -8.0, 1.0)
		return
	if "gold" in p.stats:
		p.stats.gold -= price
	# Add to inventory
	if p.has_method("collect_item"):
		p.collect_item(item, 1)
	if btn:
		btn.disabled = true
		btn.text = "Sold"
	var ab2 = get_node_or_null("/root/AudioBus")
	if ab2 and ab2.has_method("play_cue"):
		ab2.play_cue(&"pickup", p.global_position, -8.0, 1.4)
