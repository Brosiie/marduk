extends Resource
class_name Party

# A 1-4 player group. Lives on the Cloudflare backend (server-authoritative);
# this resource is the local mirror. Members share XP boost, loot rolls, voice
# channel, dungeon eligibility.

const MAX_MEMBERS := 4
const FULL_PARTY_XP_BONUS := 0.10  # +10% XP at 4 members

class Member:
	var account_id: StringName
	var character_name: String
	var class_id: StringName
	var level: int = 1
	var prestige: int = 0
	var current_zone: StringName = &""
	var hp_pct: float = 1.0
	var mana_pct: float = 1.0
	var is_leader: bool = false
	var is_online: bool = true

@export var party_id: StringName = &""
@export var leader_account_id: StringName = &""
@export var loot_mode: StringName = &"round_robin"  # round_robin / free_for_all / leader_decides
@export var members: Array = []  # of Member
@export var open_to_join: bool = false  # public flag (for "looking for group" finder)
@export var name_for_lfg: String = ""

func size() -> int:
	return members.size()

func is_full() -> bool:
	return members.size() >= MAX_MEMBERS

func xp_multiplier() -> float:
	# +10% only at full 4 members. Smaller parties get nothing extra (Bond's spec).
	return 1.0 + FULL_PARTY_XP_BONUS if is_full() else 1.0

func contains(account_id: StringName) -> bool:
	for m: Member in members:
		if m.account_id == account_id:
			return true
	return false

func member_for(account_id: StringName) -> Member:
	for m: Member in members:
		if m.account_id == account_id:
			return m
	return null
