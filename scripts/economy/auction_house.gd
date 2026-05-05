extends Node

# Auction house autoload. Holds active listings, processes bids and buyouts,
# expires old listings, validates seller eligibility (item must be tradeable).
#
# Single-player mode: listings persist locally to user://auction_house.cfg.
# Multiplayer Phase 4 mode: host owns the truth; clients send RPC requests.

const SAVE_PATH := "user://auction_house.cfg"
const LISTING_FEE_PCT := 0.05      # 5% of starting bid taken at listing time
const SALE_TAX_PCT := 0.10         # 10% of sale price taken on completion

var listings: Dictionary = {}  # listing_id (StringName) -> AuctionListing
var _next_id: int = 1

signal listing_created(listing: AuctionListing)
signal listing_cancelled(listing: AuctionListing)
signal listing_expired(listing: AuctionListing)
signal bid_placed(listing: AuctionListing, bidder_id: StringName, amount: int)
signal sale_completed(listing: AuctionListing, buyer_id: StringName, price: int)

func _ready() -> void:
	_load()
	# Tick expirations every minute
	var t := Timer.new()
	t.wait_time = 60.0
	t.autostart = true
	t.timeout.connect(_check_expirations)
	add_child(t)

# === Listing creation ===
func list_item(seller_id: StringName, seller_name: String, item: Item, count: int,
		starting_bid: int, buyout: int, duration_seconds: int = 86400) -> AuctionListing:
	if not item or not item.can_be_auctioned():
		return null
	if count <= 0 or starting_bid < 1:
		return null
	var L := AuctionListing.new()
	L.listing_id = StringName("listing_%d" % _next_id)
	_next_id += 1
	L.seller_id = seller_id
	L.seller_display_name = seller_name
	L.item = item
	L.item_count = count
	L.starting_bid = starting_bid
	L.current_bid = 0
	L.buyout_price = buyout
	L.listed_at_unix = int(Time.get_unix_time_from_system())
	L.duration_seconds = duration_seconds
	L.state = AuctionListing.State.ACTIVE
	listings[L.listing_id] = L
	listing_created.emit(L)
	_save()
	return L

func cancel_listing(listing_id: StringName, requester_id: StringName) -> bool:
	var L: AuctionListing = listings.get(listing_id)
	if not L or L.state != AuctionListing.State.ACTIVE:
		return false
	if L.seller_id != requester_id:
		return false
	# Cannot cancel if there are active bids
	if L.current_bid > 0:
		return false
	L.state = AuctionListing.State.CANCELLED
	listing_cancelled.emit(L)
	_save()
	return true

# === Bidding ===
func place_bid(listing_id: StringName, bidder_id: StringName, amount: int) -> bool:
	var L: AuctionListing = listings.get(listing_id)
	if not L or L.state != AuctionListing.State.ACTIVE:
		return false
	if L.seller_id == bidder_id:
		return false
	var min_bid: int = max(L.starting_bid, L.current_bid + 1)
	if amount < min_bid:
		return false
	L.current_bid = amount
	L.current_high_bidder_id = bidder_id
	bid_placed.emit(L, bidder_id, amount)
	_save()
	# Auto-buyout
	if L.buyout_price > 0 and amount >= L.buyout_price:
		_complete_sale(L, bidder_id, L.buyout_price)
	return true

func buyout(listing_id: StringName, buyer_id: StringName) -> bool:
	var L: AuctionListing = listings.get(listing_id)
	if not L or not L.can_buyout():
		return false
	if L.seller_id == buyer_id:
		return false
	_complete_sale(L, buyer_id, L.buyout_price)
	return true

# === Search ===
func search(filter: Dictionary = {}) -> Array[AuctionListing]:
	# filter keys (all optional):
	#   class_id, slot, rarity_min, rarity_max, item_level_min, item_level_max,
	#   max_buyout, max_current_bid, query (substring of display_name)
	var results: Array[AuctionListing] = []
	for L: AuctionListing in listings.values():
		if L.state != AuctionListing.State.ACTIVE:
			continue
		if not _matches(L, filter):
			continue
		results.append(L)
	return results

func _matches(L: AuctionListing, f: Dictionary) -> bool:
	if not L.item:
		return false
	if f.has("class_id"):
		var c: StringName = f["class_id"]
		if L.item.class_restriction.size() > 0 and not (c in L.item.class_restriction):
			return false
	if f.has("slot") and L.item.slot != int(f["slot"]):
		return false
	if f.has("rarity_min") and L.item.rarity < int(f["rarity_min"]):
		return false
	if f.has("rarity_max") and L.item.rarity > int(f["rarity_max"]):
		return false
	if f.has("item_level_min") and L.item.item_level < int(f["item_level_min"]):
		return false
	if f.has("item_level_max") and L.item.item_level > int(f["item_level_max"]):
		return false
	if f.has("max_buyout") and L.buyout_price > 0 and L.buyout_price > int(f["max_buyout"]):
		return false
	if f.has("query"):
		var q: String = String(f["query"]).to_lower()
		if q != "" and not L.item.display_name.to_lower().contains(q):
			return false
	return true

# === Completion ===
func _complete_sale(L: AuctionListing, buyer_id: StringName, price: int) -> void:
	L.state = AuctionListing.State.SOLD
	L.sold_to_id = buyer_id
	sale_completed.emit(L, buyer_id, price)
	_save()
	# Buyer/seller gold transfer is handled by the multiplayer/single-player wrapper;
	# this autoload only manages listing state. UI/network layer wires the gold flow.

func _check_expirations() -> void:
	var now: int = int(Time.get_unix_time_from_system())
	for L: AuctionListing in listings.values():
		if L.state == AuctionListing.State.ACTIVE and L.is_expired(now):
			if L.current_bid > 0 and L.current_high_bidder_id != &"":
				# Auction won by highest bid
				_complete_sale(L, L.current_high_bidder_id, L.current_bid)
			else:
				L.state = AuctionListing.State.EXPIRED
				listing_expired.emit(L)
	_save()

# === Persistence ===
func _save() -> void:
	# Lightweight: store only IDs and primitive fields. Item objects are referenced by id;
	# the loader matches them back to ItemRegistry entries.
	var cfg := ConfigFile.new()
	cfg.set_value("meta", "next_id", _next_id)
	for id in listings.keys():
		var L: AuctionListing = listings[id]
		var section := String(id)
		cfg.set_value(section, "seller_id", String(L.seller_id))
		cfg.set_value(section, "seller_display_name", L.seller_display_name)
		cfg.set_value(section, "item_id", String(L.item.id) if L.item else "")
		cfg.set_value(section, "item_count", L.item_count)
		cfg.set_value(section, "buyout_price", L.buyout_price)
		cfg.set_value(section, "starting_bid", L.starting_bid)
		cfg.set_value(section, "current_bid", L.current_bid)
		cfg.set_value(section, "current_high_bidder_id", String(L.current_high_bidder_id))
		cfg.set_value(section, "listed_at_unix", L.listed_at_unix)
		cfg.set_value(section, "duration_seconds", L.duration_seconds)
		cfg.set_value(section, "state", L.state)
		cfg.set_value(section, "sold_to_id", String(L.sold_to_id))
	cfg.save(SAVE_PATH)

func _load() -> void:
	var cfg := ConfigFile.new()
	if cfg.load(SAVE_PATH) != OK:
		return
	_next_id = int(cfg.get_value("meta", "next_id", 1))
	# Note: full deserialization requires an ItemRegistry to map item_id -> Item Resource.
	# This stub leaves listings empty on load; first-class implementation comes when
	# ItemRegistry exists.
