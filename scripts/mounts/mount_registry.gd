extends Node

# Autoload: every mount sold in the store. ~10 SKUs. Cosmetic-rich; mechanically
# identical (all give the same +100% speed). Players choose by aesthetic.

var mounts: Dictionary = {}  # StringName -> Mount

func _ready() -> void:
	_register_starter()
	_register_purchasable()

func get_mount(id: StringName) -> Mount:
	return mounts.get(id)

func all_mounts() -> Array[Mount]:
	var arr: Array[Mount] = []
	for m in mounts.values():
		arr.append(m)
	return arr

func owned_mounts() -> Array[Mount]:
	var arr: Array[Mount] = []
	for m: Mount in mounts.values():
		if is_owned(m.id):
			arr.append(m)
	return arr

func is_owned(id: StringName) -> bool:
	if not mounts.has(id):
		return false
	var m: Mount = mounts[id]
	if m.is_starter_free:
		return true  # starter is free for everyone
	return SaveFlags.has_permanent(StringName("mount_owned_" + String(id)))

func grant_ownership(id: StringName) -> void:
	# Called on successful store purchase confirmation
	SaveFlags.set_permanent(StringName("mount_owned_" + String(id)), true)

func _make(id: StringName, name: String, lore: String, price: float, starter: bool = false) -> Mount:
	var m := Mount.new()
	m.id = id
	m.display_name = name
	m.lore = lore
	m.price_usd = price
	m.is_starter_free = starter
	mounts[id] = m
	return m

# ----------------------------------------------------------------
# STARTER MOUNT (free at level 5)
# ----------------------------------------------------------------
func _register_starter() -> void:
	_make(&"mount_chestnut_horse", "Chestnut Horse",
		"A reliable, square-shouldered farm horse. Crown-stable surplus. Yours when you reach level 5 in any class.",
		0.0, true)

# ----------------------------------------------------------------
# PURCHASABLE MOUNTS
# ----------------------------------------------------------------
func _register_purchasable() -> void:
	_make(&"mount_war_destrier", "War Destrier",
		"Bred for battle by the Iron Crown's stable-master. Heavy, fast, scarred. Refuses to canter.",
		4.99)

	_make(&"mount_lapis_pony", "Lapis-Spotted Pony",
		"Lapis Bay coastal stock. Smaller than a horse, faster than a mule, distinctive blue spotted coat.",
		4.99)

	_make(&"mount_steppe_runner", "Steppe Runner",
		"Ash-Step nomad horse. Tough on the ash-plain, tough on you. Eats sparingly, hates bridles.",
		4.99)

	_make(&"mount_bone_charger", "Bone Charger",
		"Bone Mountains ossuary mount. Looks dead. Is not. Doesn't blink. Refuses no road.",
		7.99)

	_make(&"mount_ember_steed", "Ember Steed",
		"Ember Steppes salamander-stock crossbreed. Steam rises from its flanks in cold weather. Loved by Flame Breathing senior monks.",
		7.99)

	_make(&"mount_shadow_courser", "Shadow Courser",
		"A Whisper Shrine courser. Black, silent on cobblestones. Refuses to enter sunlit streets without permission.",
		9.99)

	_make(&"mount_sun_pegasus", "Sun-Marked Stallion",
		"Bred at the Sun-Sworn Chapel before the chapel fell. Carries a sun-glyph birthmark on its flank.",
		12.99)

	_make(&"mount_dragon_pup", "Wyrmling (ground form)",
		"A juvenile Tiamat-spawn that has been domesticated. Walks on four legs. Will fly when older but cannot yet. Cannot enter dungeons.",
		14.99)

	_make(&"mount_marduks_chariot", "Marduk's Replica Chariot",
		"A scale-model chariot of fire. Cosmetic flames. Real wheels. Built by a Babilim wagonwright who got religious.",
		19.99)

	_make(&"mount_lifetime_white_stag", "The White Stag (Founder)",
		"Founders' edition mount. Sold only during the first cycle of the game's existence. After that, this slot becomes locked forever to current owners.",
		29.99)
