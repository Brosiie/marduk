extends CanvasLayer
class_name VendorPanel

# Generic vendor shop panel. Two tabs: Buy (vendor's stock) and Sell
# (player's bag). Each row: item name + qty + price + action button.
# Reads gold from player.inventory.gold; routes purchases through
# Vendor.sell_price + inventory.add_item / spend_gold + Vendor.consume_stock.
#
# Spawned by NPCs (Iddinu, Belitu, etc) on player interact instead of
# their dialog flow.

signal closed

const TAB_BUY := 0
const TAB_SELL := 1

@onready var dim: ColorRect = $Dim if has_node("Dim") else null
@onready var panel: PanelContainer = $Panel if has_node("Panel") else null

var vendor = null  # Vendor resource
var player: Node = null
var npc: Node = null
var _current_tab: int = TAB_BUY
var _gold_label: Label = null
# Cached at open() so every row prices off the same snapshot. Hostile
# vendors (rep < -3000) refuse to trade entirely.
var _player_rep: int = 0
var _vendor_will_trade: bool = true

func _ready() -> void:
	visible = false
	process_mode = Node.PROCESS_MODE_ALWAYS

func open(p_vendor, p_player: Node, p_npc: Node = null) -> void:
	vendor = p_vendor
	player = p_player
	npc = p_npc
	_resolve_player_rep()
	visible = true
	get_tree().paused = true
	_build()

func _resolve_player_rep() -> void:
	_player_rep = 0
	_vendor_will_trade = true
	if vendor == null or not "faction" in vendor or vendor.faction == &"":
		return
	var fr: Node = get_node_or_null("/root/FactionRegistry")
	if fr and fr.has_method("get_rep"):
		_player_rep = int(fr.get_rep(vendor.faction))
	if vendor.has_method("will_trade"):
		_vendor_will_trade = bool(vendor.will_trade(_player_rep))

func close() -> void:
	visible = false
	get_tree().paused = false
	closed.emit()

func _input(event: InputEvent) -> void:
	if visible and event.is_action_pressed("ui_cancel"):
		close()

func _build() -> void:
	if not panel:
		return
	for c in panel.get_children():
		c.queue_free()

	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 24)
	margin.add_theme_constant_override("margin_right", 24)
	margin.add_theme_constant_override("margin_top", 22)
	margin.add_theme_constant_override("margin_bottom", 22)
	panel.add_child(margin)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 12)
	margin.add_child(vbox)

	# Header — vendor name + greeting + gold + close
	var header := HBoxContainer.new()
	vbox.add_child(header)
	var title := Label.new()
	title.text = vendor.display_name if vendor else "Vendor"
	title.add_theme_font_size_override("font_size", 22)
	title.add_theme_color_override("font_color", Color(0.95, 0.85, 0.45))
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header.add_child(title)
	_gold_label = Label.new()
	_gold_label.text = _gold_text()
	_gold_label.add_theme_font_size_override("font_size", 16)
	_gold_label.add_theme_color_override("font_color", Color(1.00, 0.85, 0.30))
	header.add_child(_gold_label)
	var close_btn := Button.new()
	close_btn.text = "Leave [Esc]"
	close_btn.custom_minimum_size = Vector2(120, 32)
	close_btn.pressed.connect(close)
	header.add_child(close_btn)

	if vendor and vendor.greeting != "":
		var greeting := Label.new()
		greeting.text = vendor.greeting
		greeting.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		greeting.custom_minimum_size = Vector2(720, 0)
		greeting.add_theme_font_size_override("font_size", 12)
		greeting.add_theme_color_override("font_color", Color(0.78, 0.72, 0.60))
		vbox.add_child(greeting)

	# Faction badge — shows the player's tier with this vendor and the
	# resulting price modifier. Skipped for vendors with no faction.
	var badge := _make_faction_badge()
	if badge:
		vbox.add_child(badge)

	# Hostile vendors refuse trade outright. Render a single refusal line
	# and skip the tabs / stock entirely.
	if not _vendor_will_trade:
		var refusal := Label.new()
		refusal.text = "%s refuses to trade with you." % (vendor.display_name if vendor else "The vendor")
		refusal.add_theme_font_size_override("font_size", 16)
		refusal.add_theme_color_override("font_color", Color(0.85, 0.30, 0.25))
		refusal.custom_minimum_size = Vector2(720, 0)
		vbox.add_child(refusal)
		var hint := Label.new()
		hint.text = "Earn standing with their faction first."
		hint.add_theme_font_size_override("font_size", 12)
		hint.add_theme_color_override("font_color", Color(0.65, 0.55, 0.45))
		vbox.add_child(hint)
		return

	# Tabs
	var tabs := HBoxContainer.new()
	tabs.add_theme_constant_override("separation", 8)
	vbox.add_child(tabs)
	tabs.add_child(_make_tab("Buy", TAB_BUY))
	tabs.add_child(_make_tab("Sell", TAB_SELL))

	# Content
	var scroll := ScrollContainer.new()
	scroll.custom_minimum_size = Vector2(720, 420)
	scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	vbox.add_child(scroll)
	var content := VBoxContainer.new()
	content.add_theme_constant_override("separation", 6)
	content.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(content)

	if _current_tab == TAB_BUY:
		_render_buy(content)
	else:
		_render_sell(content)

func _make_tab(text: String, tab_id: int) -> Button:
	var b := Button.new()
	b.text = text
	b.custom_minimum_size = Vector2(120, 32)
	b.modulate = Color(1, 1, 1) if _current_tab == tab_id else Color(0.65, 0.65, 0.65)
	b.pressed.connect(func():
		_current_tab = tab_id
		_build()
	)
	return b

# ───────── Buy ─────────

func _render_buy(content: VBoxContainer) -> void:
	if not vendor or not "stocked_items" in vendor or vendor.stocked_items.is_empty():
		# Try to populate from auto-stock recipe
		_auto_populate_if_needed()
	if vendor.stocked_items.is_empty():
		content.add_child(_make_label("Nothing for sale right now. Come back later."))
		return
	var registry: Node = get_node_or_null("/root/ItemRegistry")
	for stock in vendor.stocked_items:
		var item_id: StringName = stock.get("item_id", &"") if stock is Dictionary else stock.item_id
		var qty: int = int(stock.get("quantity", -1)) if stock is Dictionary else stock.quantity
		var item = registry.get_item(item_id) if registry and registry.has_method("get_item") else null
		if not item:
			continue
		content.add_child(_make_buy_row(item, qty, stock))

func _make_buy_row(item: Item, qty: int, stock) -> Control:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 14)

	var name_label := Label.new()
	var qty_str: String = ("  (×%d)" % qty) if qty > 1 else ("  (∞)" if qty < 0 else "")
	name_label.text = item.display_name + qty_str
	name_label.add_theme_font_size_override("font_size", 13)
	name_label.add_theme_color_override("font_color", item.rarity_color() if item.has_method("rarity_color") else Color(0.95, 0.92, 0.80))
	name_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	name_label.tooltip_text = item.description
	row.add_child(name_label)

	var price: int = vendor.sell_price(item, _player_rep) if vendor.has_method("sell_price") else int(item.sell_value)
	var price_label := Label.new()
	price_label.text = "%d g" % price
	price_label.add_theme_font_size_override("font_size", 13)
	price_label.add_theme_color_override("font_color", Color(1.00, 0.85, 0.30))
	price_label.custom_minimum_size = Vector2(80, 0)
	row.add_child(price_label)

	var buy_btn := Button.new()
	buy_btn.text = "Buy"
	buy_btn.custom_minimum_size = Vector2(80, 28)
	buy_btn.disabled = not _player_has_gold(price) or qty == 0
	buy_btn.pressed.connect(_on_buy.bind(item, price, stock))
	row.add_child(buy_btn)

	return row

func _on_buy(item: Item, price: int, stock) -> void:
	if not _player_has_gold(price):
		_toast("Not enough gold.")
		return
	if not _spend_gold(price):
		return
	if player.inventory and player.inventory.has_method("add_item"):
		player.inventory.add_item(item, 1)
	# Decrement vendor stock if finite
	if stock is Dictionary:
		var q: int = int(stock.get("quantity", -1))
		if q > 0:
			stock["quantity"] = q - 1
	elif stock and "quantity" in stock and stock.quantity > 0:
		stock.quantity -= 1
	_play_pickup_cue()
	_build()

# ───────── Sell ─────────

func _render_sell(content: VBoxContainer) -> void:
	if not player or not player.inventory or not "bag" in player.inventory or player.inventory.bag.is_empty():
		content.add_child(_make_label("Your bag is empty. Nothing to sell."))
		return
	for stack in player.inventory.bag:
		if not stack or not stack.item:
			continue
		var item: Item = stack.item
		# Vendor refuses some items
		if vendor.has_method("can_buy") and not vendor.can_buy(item, _player_rep):
			continue
		content.add_child(_make_sell_row(item, stack.count))

func _make_sell_row(item: Item, qty: int) -> Control:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 14)

	var name_label := Label.new()
	name_label.text = "%s%s" % [item.display_name, "  (×%d)" % qty if qty > 1 else ""]
	name_label.add_theme_font_size_override("font_size", 13)
	name_label.add_theme_color_override("font_color", item.rarity_color() if item.has_method("rarity_color") else Color(0.95, 0.92, 0.80))
	name_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	name_label.tooltip_text = item.description
	row.add_child(name_label)

	var price: int = vendor.buy_price(item, _player_rep) if vendor.has_method("buy_price") else int(item.sell_value * 0.35)
	var price_label := Label.new()
	price_label.text = "%d g" % price
	price_label.add_theme_font_size_override("font_size", 13)
	price_label.add_theme_color_override("font_color", Color(0.85, 0.78, 0.55))
	price_label.custom_minimum_size = Vector2(80, 0)
	row.add_child(price_label)

	var sell_btn := Button.new()
	sell_btn.text = "Sell"
	sell_btn.custom_minimum_size = Vector2(80, 28)
	sell_btn.disabled = item.is_soulbound or item.is_quest_item
	sell_btn.pressed.connect(_on_sell.bind(item, price))
	row.add_child(sell_btn)

	return row

func _on_sell(item: Item, price: int) -> void:
	if player.inventory and player.inventory.has_method("remove_item"):
		player.inventory.remove_item(item.id, 1)
	_add_gold(price)
	_play_pickup_cue()
	_build()

# ───────── Helpers ─────────

func _gold_text() -> String:
	var g: int = 0
	if player and player.inventory:
		if player.inventory.has_method("gold") and player.inventory.gold is Callable:
			g = int(player.inventory.gold.call())
		elif "gold" in player.inventory:
			var v = player.inventory.gold
			g = int(v.call() if v is Callable else v)
	return "%d g" % g

func _player_has_gold(amount: int) -> bool:
	if not player or not player.inventory:
		return false
	if "gold" in player.inventory:
		var v = player.inventory.gold
		return int(v.call() if v is Callable else v) >= amount
	return false

func _spend_gold(amount: int) -> bool:
	if not player or not player.inventory:
		return false
	if player.inventory.has_method("spend_gold"):
		return bool(player.inventory.spend_gold(amount))
	if "gold" in player.inventory and not (player.inventory.gold is Callable):
		player.inventory.gold = max(0, int(player.inventory.gold) - amount)
		return true
	return false

func _add_gold(amount: int) -> void:
	if not player or not player.inventory:
		return
	if player.inventory.has_method("add_gold"):
		player.inventory.add_gold(amount)
	elif "gold" in player.inventory and not (player.inventory.gold is Callable):
		player.inventory.gold = int(player.inventory.gold) + amount

func _auto_populate_if_needed() -> void:
	# If the vendor has auto_stock_potions / auto_stock_basic_gear and no
	# stocked items, populate from the recipe. Real auto-stock lives on the
	# Vendor resource; this is a fallback for vendors that lazy-init.
	if not vendor:
		return
	if "auto_stock_potions" in vendor and vendor.auto_stock_potions:
		if vendor.has_method("auto_generated_potions"):
			for item_id in vendor.auto_generated_potions():
				if vendor.has_method("add_stock"):
					vendor.add_stock(item_id, -1)

func _make_label(text: String) -> Label:
	var lab := Label.new()
	lab.text = text
	lab.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	lab.custom_minimum_size = Vector2(720, 0)
	lab.add_theme_font_size_override("font_size", 14)
	lab.add_theme_color_override("font_color", Color(0.75, 0.70, 0.60))
	return lab

func _make_faction_badge() -> Control:
	# Renders a colored "Crown - Friendly (-5%/+5%)" line so the player
	# can see exactly what their reputation buys them at this vendor.
	# Returns null when the vendor has no faction or registries are
	# missing — caller skips on null.
	if vendor == null or not "faction" in vendor or vendor.faction == &"":
		return null
	var fr: Node = get_node_or_null("/root/FactionRegistry")
	if fr == null or not fr.has_method("tier_for") or not fr.has_method("get_faction"):
		return null
	var tier: String = fr.tier_for(_player_rep)
	var tier_color: Color = fr.tier_color_for(_player_rep) if fr.has_method("tier_color_for") else Color(0.85, 0.85, 0.85)
	var f = fr.get_faction(vendor.faction)
	var fname: String = f.display_name if f else String(vendor.faction)
	var mod: Dictionary = vendor.tier_modifier(_player_rep) if vendor.has_method("tier_modifier") else {"sell_mult": 1.0, "buy_mult": 1.0}
	var sell_pct: int = int(round((float(mod.get("sell_mult", 1.0)) - 1.0) * 100.0))
	var buy_pct: int = int(round((float(mod.get("buy_mult", 1.0)) - 1.0) * 100.0))
	var lab := Label.new()
	if sell_pct == 0 and buy_pct == 0:
		lab.text = "%s · %s" % [fname, tier]
	else:
		var sell_str: String = ("%+d%%" % sell_pct) if sell_pct != 0 else "0%"
		var buy_str: String = ("%+d%%" % buy_pct) if buy_pct != 0 else "0%"
		lab.text = "%s · %s   (buy %s · sell %s)" % [fname, tier, sell_str, buy_str]
	lab.add_theme_font_size_override("font_size", 12)
	lab.add_theme_color_override("font_color", tier_color)
	return lab

func _toast(msg: String) -> void:
	var juice: Node = get_node_or_null("/root/Juice")
	if juice and juice.has_method("toast"):
		juice.toast(msg, Color(0.85, 0.78, 0.55), 2.0)

func _play_pickup_cue() -> void:
	var ab: Node = get_node_or_null("/root/AudioBus")
	if ab and ab.has_method("play_cue"):
		ab.play_cue(&"pickup", player.global_position if player is Node3D else Vector3.ZERO, -6.0, 1.2)
