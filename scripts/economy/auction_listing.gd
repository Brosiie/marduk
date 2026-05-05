extends Resource
class_name AuctionListing

# A single item listing on the auction house.
# Soulbound items (Heaven, quest items) cannot be listed (Item.can_be_auctioned filters).

enum State { ACTIVE, SOLD, EXPIRED, CANCELLED }

@export var listing_id: StringName = &""
@export var seller_id: StringName = &""        # player profile id (multiplayer) or local profile name
@export var seller_display_name: String = ""
@export var item: Item
@export var item_count: int = 1
@export var buyout_price: int = 0              # 0 = bids only
@export var starting_bid: int = 1
@export var current_bid: int = 0
@export var current_high_bidder_id: StringName = &""
@export var listed_at_unix: int = 0            # epoch seconds
@export var duration_seconds: int = 86400      # default 24h
@export var state: int = State.ACTIVE
@export var sold_to_id: StringName = &""

func is_expired(now_unix: int) -> bool:
	return state == State.ACTIVE and (now_unix - listed_at_unix) > duration_seconds

func time_left_seconds(now_unix: int) -> int:
	return max(0, duration_seconds - (now_unix - listed_at_unix))

func can_buyout() -> bool:
	return buyout_price > 0 and state == State.ACTIVE
