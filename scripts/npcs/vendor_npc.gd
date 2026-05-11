extends "res://scripts/npcs/npc.gd"
class_name VendorNPC

# Shop vendor: pressing V opens a buy/sell panel populated from
# ShopkeeperRegistry (or a fallback random draw from ItemRegistry filtered
# by the vendor's slot affinity). Player can buy with gold, sell items
# back at half price.

@export var shop_id: StringName = &""             # ShopkeeperRegistry key
@export var slot_affinity: int = -1               # filter pool when no shop_id; -1 = any

func _ready() -> void:
	# Vendors are anchored at their stalls -- override wander_radius BEFORE
	# super._ready() locks _home and starts the state machine. Otherwise
	# the merchant strolls away from his shop.
	wander_radius = 0.0
	super._ready()
	if _label3d:
		_label3d.modulate = Color(1.00, 0.85, 0.45)  # gold for vendors
	if _quest_marker:
		_quest_marker.text = "$"
		_quest_marker.modulate = Color(1.00, 0.85, 0.45)
		_quest_marker.visible = true
	# Daily rotation: each vendor picks ONE "today's deal" item that's
	# 30% off. Listens for WorldClock.became_day so the deal rotates at
	# dawn. The deal lives entirely on this vendor; no central registry.
	# Players who see "deal!" learn to shop at dawn for the best prices,
	# which reinforces the day/night cycle as a meaningful loop.
	_roll_todays_deal()
	var clock := get_node_or_null("/root/WorldClock")
	if clock and clock.has_signal("became_day"):
		clock.became_day.connect(_on_dawn)

# Today's deal: a single Item that's discounted 30% on this vendor today.
# Re-rolled at dawn. null = no deal active (e.g. this vendor's pool is
# empty). Read by _stock_row to render the "DEAL" badge + price slash.
var _todays_deal: Item = null
const DEAL_DISCOUNT_PCT: float = 0.30

func _roll_todays_deal() -> void:
	var registry := get_node_or_null("/root/ItemRegistry")
	if registry == null:
		_todays_deal = null
		return
	var pool: Array = registry.items.values()
	# Bias deals toward COMMON (rarity 2) so they feel meaningful but
	# don't undercut rare drops. Filter same way _roll_stock does.
	var deal_pool: Array = []
	for it in pool:
		if it == null or it.unique_drop_source != &"":
			continue
		if int(it.rarity) == 2 and (slot_affinity < 0 or int(it.slot) == slot_affinity):
			deal_pool.append(it)
	if deal_pool.is_empty():
		_todays_deal = null
		return
	deal_pool.shuffle()
	_todays_deal = deal_pool[0]

func _on_dawn() -> void:
	_roll_todays_deal()

func _open_dialogue() -> void:
	_open_shop_panel()

# Override the base NPC's chatter trigger so vendors with an active
# deal announce it specifically instead of saying "best prices on this
# side of Babilim" generically. Once-per-day flag so the toast doesn't
# spam every time the player crosses the radius.
const DEAL_TOAST_FLAG_PREFIX := "vendor_deal_toasted_"
var _deal_toasted_for_today: bool = false

func _on_body_entered(body: Node3D) -> void:
	super._on_body_entered(body)
	if not body.is_in_group("player"):
		return
	if _todays_deal == null:
		return
	if _deal_toasted_for_today:
		return
	_deal_toasted_for_today = true
	var juice: Node = get_node_or_null("/root/Juice")
	if juice and juice.has_method("toast"):
		var deal_name: String = _todays_deal.display_name if _todays_deal else "an item"
		juice.toast(
			"%s has a deal: %s (-%d%%)" % [display_name, deal_name, int(DEAL_DISCOUNT_PCT * 100)],
			Color(0.55, 0.95, 0.55),
			3.0,
		)

# Reset the once-per-day toast gate when the deal rotates at dawn.
# Override the base _on_dawn so we wrap, not replace.
func _on_dawn() -> void:
	super._on_dawn()
	_deal_toasted_for_today = false

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
	hdr.text = display_name + ", Shop"
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
	# Today's-deal pricing: if this is the rotating discount item, slash
	# the price + tag the row with a "DEAL!" badge in green so the
	# player's eye lands on it.
	var base_price: int = max(1, int(item.sell_value) * 2)
	var is_deal: bool = (_todays_deal != null and item == _todays_deal)
	var price: int = base_price
	if is_deal:
		price = max(1, int(round(float(base_price) * (1.0 - DEAL_DISCOUNT_PCT))))
		var deal_badge := Label.new()
		deal_badge.text = "DEAL!"
		deal_badge.add_theme_font_size_override("font_size", 11)
		deal_badge.add_theme_color_override("font_color", Color(0.45, 0.95, 0.55))
		deal_badge.add_theme_color_override("font_outline_color", Color(0, 0.05, 0, 0.95))
		deal_badge.add_theme_constant_override("outline_size", 3)
		row.add_child(deal_badge)
	var price_lbl := Label.new()
	if is_deal:
		# Strikethrough the base price + show discounted price after.
		# BBCode would be cleaner but a plain Label can't render it; use
		# two stacked labels.
		price_lbl.text = "%d (was %d)" % [price, base_price]
		price_lbl.modulate = Color(0.55, 0.95, 0.55)  # green = sale
	else:
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
