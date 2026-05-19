extends "res://scripts/npcs/npc.gd"
class_name VendorNPC

# Shop vendor: pressing V opens a buy/sell panel populated from
# ShopkeeperRegistry (or a fallback random draw from ItemRegistry filtered
# by the vendor's slot affinity). Player can buy with gold, sell items
# back at half price.

@export var shop_id: StringName = &""             # ShopkeeperRegistry key
@export var slot_affinity: int = -1               # filter pool when no shop_id; -1 = any
@export var max_rarity: int = 2                   # Item.Rarity ceiling for stock rolls.
                                                  # Default 2 = COMMON (starter-town vendors).
                                                  # Set to 3 (RARE) for Babilim-tier shops,
                                                  # 4 (VERY_RARE) for late-game faction halls.
                                                  # Affixes still roll on top of the base item.

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
	# Visual restock cue: small gold sparkle puff over the stall so the
	# player visually catches the daily rotation even if they're not in
	# range to hear the toast. Self-cleans after 2s.
	_spawn_restock_sparkle()

# One-shot particle burst over the vendor's head. Reads as "shop just
# refreshed." Color matches the gold deal accent so the rotation +
# the deal-of-the-day badge share a visual language.
func _spawn_restock_sparkle() -> void:
	var p := GPUParticles3D.new()
	p.name = "RestockSparkle"
	p.amount = 35
	p.lifetime = 1.4
	p.preprocess = 0.0
	p.one_shot = true
	p.explosiveness = 0.95
	p.visibility_aabb = AABB(Vector3(-2, -1, -2), Vector3(4, 4, 4))
	var mat := ParticleProcessMaterial.new()
	mat.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_SPHERE
	mat.emission_sphere_radius = 0.30
	mat.direction = Vector3(0, 1, 0)
	mat.spread = 28.0
	mat.initial_velocity_min = 0.8
	mat.initial_velocity_max = 1.6
	mat.gravity = Vector3(0, -0.3, 0)  # slight fall so the burst settles
	mat.scale_min = 0.08
	mat.scale_max = 0.16
	mat.color = Color(1.0, 0.85, 0.30)
	# Tiny rotational swirl so the burst doesn't look like a balloon pop
	mat.tangential_accel_min = -0.6
	mat.tangential_accel_max = 0.6
	p.process_material = mat
	var quad := QuadMesh.new()
	quad.size = Vector2(0.10, 0.10)
	var smat := StandardMaterial3D.new()
	smat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	smat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	smat.albedo_color = Color(1.0, 0.85, 0.30)
	smat.emission_enabled = true
	smat.emission = Color(1.0, 0.85, 0.30)
	smat.emission_energy_multiplier = 2.4
	smat.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
	quad.material = smat
	p.draw_pass_1 = quad
	p.position = Vector3(0, 2.4, 0)
	add_child(p)
	# Cleanup after the lifetime + a generous tail to ensure no stutter
	get_tree().create_timer(p.lifetime + 0.5).timeout.connect(func():
		if is_instance_valid(p): p.queue_free())
	# Audio sting: pickup cue at bright pitch reads as "shop opening"
	var ab: Node = get_node_or_null("/root/AudioBus")
	if ab and ab.has_method("play_cue"):
		ab.play_cue(&"pickup", global_position, -10.0, 1.6)

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
	# === BUY section ===
	var buy_hdr := Label.new()
	buy_hdr.text = "— BUY —"
	buy_hdr.add_theme_font_size_override("font_size", 14)
	buy_hdr.modulate = Color(0.95, 0.85, 0.55)
	v.add_child(buy_hdr)
	var stock := _roll_stock()
	for item in stock:
		v.add_child(_stock_row(item))
	# === SELL section ===
	# Closes the economy loop. Vendor panel header said "sell items back
	# at half price" since day one but no code ran — Bond's Kazat drop
	# had nowhere to go. Pulls the player's bag, lists each non-soulbound
	# item with a Sell button. Sell price = sell_value (already the half-
	# price baseline that buys reference *2 to set the buy price).
	var sell_hdr := Label.new()
	sell_hdr.text = "— SELL —"
	sell_hdr.add_theme_font_size_override("font_size", 14)
	sell_hdr.modulate = Color(0.55, 0.95, 0.55)
	v.add_child(sell_hdr)
	var sell_rows := _build_sell_rows()
	if sell_rows.is_empty():
		var empty := Label.new()
		empty.text = "(bag empty)"
		empty.modulate = Color(0.65, 0.65, 0.65)
		v.add_child(empty)
	else:
		for row in sell_rows:
			v.add_child(row)
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
		# max_rarity caps the stock tier per vendor: starter towns stock
		# COMMON (2), Babilim hubs stock RARE (3), late-game factions
		# could go higher. Junk/basic always pass since they're under the
		# floor.
		if it.rarity > max_rarity:
			continue
		if it.unique_drop_source != &"":
			continue
		if slot_affinity >= 0 and int(it.slot) != slot_affinity:
			continue
		filtered.append(it)
	# Shuffle and take up to 8
	filtered.shuffle()
	var picked: Array = filtered.slice(0, min(8, filtered.size()))
	# Roll affixes on the stock so vendor wares feel as varied as drops.
	# Without this pass every "Bronze Sword" in every shop would look
	# identical. With it: Bel-Ituru's stock can show "Heavy Bronze Sword
	# of Cleaving" sitting next to a plain Bronze Sword (if the affix
	# roll yielded nothing). Re-rolls on each shop open so the rotation
	# loop feels alive.
	var affixed: Array = []
	for base in picked:
		affixed.append(_apply_vendor_affixes(base))
	return affixed

# Duplicate the base item, roll affixes via AffixRegistry, stamp them
# onto the copy, recompute display_name. Same pattern as LootTable but
# operating at vendor-stock-roll time. Returns the base item unchanged
# for rarity < COMMON or when AffixRegistry isn't reachable.
func _apply_vendor_affixes(base):
	if base == null:
		return base
	if int(base.rarity) < 2:  # JUNK + BASIC: skip
		return base
	if base.is_soulbound or base.is_quest_item:
		return base
	var reg: Node = get_node_or_null("/root/AffixRegistry")
	if reg == null or not reg.has_method("roll_for_rarity"):
		return base
	var rolled: Array = reg.roll_for_rarity(base, int(base.rarity), base.item_level)
	if rolled.is_empty():
		return base
	var copy = base.duplicate(true)
	for a in rolled:
		if a == null:
			continue
		if int(a.kind) == 0:
			copy.prefix_affixes.append(a.id)
		else:
			copy.suffix_affixes.append(a.id)
	if reg.has_method("format_item_name"):
		copy.display_name = reg.format_item_name(copy)
	return copy

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

# Build a Control row per sellable item in the player's bag. Iterates
# Inventory.bag, skips soulbound + quest items (never sellable), shows
# icon + name + price + Sell button per row. Stacks are reduced one
# unit per click so the player can choose to keep some.
func _build_sell_rows() -> Array:
	var out: Array = []
	var p: Node = get_tree().get_first_node_in_group("player") if get_tree() else null
	if p == null or not ("inventory" in p) or p.inventory == null:
		return out
	if not ("bag" in p.inventory):
		return out
	for stack in p.inventory.bag:
		if stack == null or stack.item == null:
			continue
		var it = stack.item
		if it.is_soulbound or it.is_quest_item:
			continue
		out.append(_sell_row(it, int(stack.count)))
	return out

func _sell_row(item: Item, qty: int) -> Control:
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
	# Affixed name comes through automatically since display_name was set
	# at drop-time by LootTable._with_affixes.
	name_lbl.text = "%s%s" % [item.display_name, ("  ×%d" % qty) if qty > 1 else ""]
	name_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(name_lbl)
	var price: int = max(1, int(item.sell_value))
	var price_lbl := Label.new()
	price_lbl.text = "%d gold" % price
	price_lbl.modulate = Color(0.85, 0.75, 0.30)
	row.add_child(price_lbl)
	var sell_btn := Button.new()
	sell_btn.text = "Sell"
	sell_btn.pressed.connect(_sell.bind(item, price, sell_btn, name_lbl, qty))
	row.add_child(sell_btn)
	return row

# Removes one unit of `item` from the player's inventory and credits
# `price` gold. If the stack had >1, re-renders the name label to show
# the new count; if it was the last one, disables the button so the
# row visually reflects "sold out" without rebuilding the whole panel.
func _sell(item: Item, price: int, btn: Button, name_lbl: Label, _starting_qty: int) -> void:
	var p: Node = get_tree().get_first_node_in_group("player") if get_tree() else null
	if p == null or not ("inventory" in p) or p.inventory == null:
		return
	# Remove from bag (one unit). Uses remove_item if present, falls back
	# to manual stack decrement.
	var removed: bool = false
	if p.inventory.has_method("remove_item"):
		# remove_item takes item_id (StringName), not the Item resource.
		# Returns count actually removed (1 = success for our single unit).
		removed = (p.inventory.remove_item(item.id, 1) > 0)
	else:
		for stack in p.inventory.bag:
			if stack and stack.item == item and stack.count > 0:
				stack.count -= 1
				if stack.count <= 0:
					p.inventory.bag.erase(stack)
				removed = true
				break
	if not removed:
		return
	# Credit gold
	# Gold lives on Inventory (declared @export, save_system persists it).
	# Older code paths wrote to stats.gold which was never declared on
	# PlayerStats, so they silently no-op'd. Route through inventory
	# directly so the value actually changes + the HUD gold counter
	# reflects the increment.
	if "inventory" in p and p.inventory:
		p.inventory.gold += price
		if p.inventory.has_signal("gold_changed"):
			p.inventory.gold_changed.emit(p.inventory.gold)
	# Audio + visual feedback
	var ab: Node = get_node_or_null("/root/AudioBus")
	if ab and ab.has_method("play_cue"):
		ab.play_cue(&"pickup", p.global_position, -8.0, 1.2)
	# Re-count this stack so the row stays honest about remaining qty.
	var remaining: int = 0
	for stack in p.inventory.bag:
		if stack and stack.item == item:
			remaining += stack.count
			break
	if remaining <= 0:
		btn.disabled = true
		btn.text = "Sold"
		name_lbl.modulate = Color(0.5, 0.5, 0.5)
	else:
		name_lbl.text = "%s  ×%d" % [item.display_name, remaining]

func _buy(item: Item, price: int, btn: Button) -> void:
	var p := get_tree().get_first_node_in_group("player") if get_tree() else null
	if p == null:
		return
	# Spend gold from inventory (canonical store; save_system persists it).
	if not ("inventory" in p and p.inventory):
		return
	var gold: int = int(p.inventory.gold)
	if gold < price:
		var ab = get_node_or_null("/root/AudioBus")
		if ab and ab.has_method("play_cue"):
			ab.play_cue(&"deny", p.global_position, -8.0, 1.0)
		return
	p.inventory.gold -= price
	if p.inventory.has_signal("gold_changed"):
		p.inventory.gold_changed.emit(p.inventory.gold)
	# Add to inventory
	if p.has_method("collect_item"):
		p.collect_item(item, 1)
	if btn:
		btn.disabled = true
		btn.text = "Sold"
	var ab2 = get_node_or_null("/root/AudioBus")
	if ab2 and ab2.has_method("play_cue"):
		ab2.play_cue(&"pickup", p.global_position, -8.0, 1.4)
