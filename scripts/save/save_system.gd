extends Node

# Multi-slot character save system. Each slot stores: class_id, character_name,
# stats (level, xp, skill points, unlocked nodes), inventory, equipment,
# completed quests, current zone. Run flags are global and live in SaveFlags;
# permanent flags are also global. Per-slot live data is here.
#
# Add to project.godot autoload as `SaveSystem`.

const SAVE_DIR := "user://saves"
const SLOT_FILE_FMT := "user://saves/slot_%d.cfg"
const MAX_SLOTS := 6

signal save_completed(slot: int)
signal load_completed(slot: int)
signal slot_deleted(slot: int)

func _ready() -> void:
	DirAccess.make_dir_recursive_absolute(SAVE_DIR)

func slot_path(slot: int) -> String:
	return SLOT_FILE_FMT % slot

func slot_exists(slot: int) -> bool:
	return FileAccess.file_exists(slot_path(slot))

func list_slots() -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for i in range(MAX_SLOTS):
		if slot_exists(i):
			out.append(read_slot_summary(i))
		else:
			out.append({"slot": i, "empty": true})
	return out

func read_slot_summary(slot: int) -> Dictionary:
	var cfg := ConfigFile.new()
	if cfg.load(slot_path(slot)) != OK:
		return {"slot": slot, "empty": true}
	return {
		"slot": slot,
		"empty": false,
		"character_name": cfg.get_value("meta", "character_name", ""),
		"class_id": cfg.get_value("meta", "class_id", ""),
		"level": int(cfg.get_value("stats", "level", 1)),
		"prestige": int(cfg.get_value("meta", "prestige_at_save", 0)),
		"current_zone": cfg.get_value("world", "current_zone", ""),
		"playtime_seconds": int(cfg.get_value("meta", "playtime_seconds", 0)),
		"saved_at": cfg.get_value("meta", "saved_at_iso", ""),
	}

func save_slot(slot: int, player) -> bool:
	if not player or not player.stats:
		return false
	var cfg := ConfigFile.new()
	# Meta
	cfg.set_value("meta", "character_name", player.get("character_name") if player.get("character_name") else "Champion")
	cfg.set_value("meta", "class_id", String(player.stats.class_def.class_id) if player.stats.class_def else "")
	cfg.set_value("meta", "saved_at_iso", Time.get_datetime_string_from_system(true, true))
	cfg.set_value("meta", "prestige_at_save", get_node_or_null("/root/Prestige").current_prestige_level() if get_node_or_null("/root/Prestige") else 0)
	# Stats
	cfg.set_value("stats", "level", player.stats.level)
	cfg.set_value("stats", "xp", player.stats.xp)
	cfg.set_value("stats", "unspent_skill_points", player.stats.unspent_skill_points)
	cfg.set_value("stats", "unlocked_skill_node_ids", _stringnames_to_strings(player.stats.unlocked_skill_node_ids))
	cfg.set_value("stats", "hp", player.stats.hp)
	cfg.set_value("stats", "mana", player.stats.mana)
	cfg.set_value("stats", "resource_value", player.resource_value)
	# Inventory (paths only; items are Resources, full serialization is a follow-up)
	if player.has_method("get_inventory"):
		var inv: Inventory = player.get_inventory()
		if inv:
			cfg.set_value("inventory", "gold", inv.gold)
			cfg.set_value("inventory", "bag_item_ids", _bag_to_ids(inv))
			cfg.set_value("inventory", "equipped_item_ids", _equipped_to_ids(inv))
	# World
	var loader: Node = get_tree().root.get_node_or_null("ZoneLoader")
	if loader and loader.current_zone:
		cfg.set_value("world", "current_zone", String(loader.current_zone.id))
	cfg.set_value("world", "position", player.global_position)
	# Persist
	var err := cfg.save(slot_path(slot))
	if err == OK:
		# Capture a 240x135 thumbnail of the current viewport beside the
		# slot file. Slot picker reads the .png to render a preview row.
		# Skipped silently if the viewport isn't ready (eg headless tests).
		_save_thumbnail(slot)
		save_completed.emit(slot)
		return true
	push_warning("SaveSystem: failed to save slot %d: %s" % [slot, err])
	return false

const THUMBNAIL_FMT := "user://saves/slot_%d_thumb.png"
const THUMBNAIL_SIZE := Vector2i(240, 135)

func thumbnail_path(slot: int) -> String:
	return THUMBNAIL_FMT % slot

# Captures the current viewport, downscales to THUMBNAIL_SIZE, writes PNG.
# All failure modes (missing viewport, unwritable user://) are silent —
# thumbnails are nice-to-have, not required.
func _save_thumbnail(slot: int) -> void:
	var viewport: Viewport = get_viewport()
	if viewport == null:
		return
	var img: Image = viewport.get_texture().get_image()
	if img == null or img.is_empty():
		return
	# Downscale to thumbnail size. Lanczos preserves the toon shader's
	# crisp edges better than the default bilinear downsample.
	img.resize(THUMBNAIL_SIZE.x, THUMBNAIL_SIZE.y, Image.INTERPOLATE_LANCZOS)
	# Make sure the saves dir exists (first-save case)
	DirAccess.make_dir_recursive_absolute(SAVE_DIR.replace("user://", OS.get_user_data_dir() + "/"))
	var save_err: int = img.save_png(thumbnail_path(slot))
	if save_err != OK:
		push_warning("SaveSystem: thumbnail write failed for slot %d: %s" % [slot, save_err])

# Public: load a slot's thumbnail as Texture2D for the slot picker UI.
# Returns null if the file doesn't exist (older saves, fresh slots).
func load_thumbnail(slot: int) -> Texture2D:
	var path: String = thumbnail_path(slot)
	if not FileAccess.file_exists(path):
		return null
	var img: Image = Image.new()
	if img.load(path) != OK:
		return null
	return ImageTexture.create_from_image(img)

func load_slot(slot: int, player) -> bool:
	var cfg := ConfigFile.new()
	if cfg.load(slot_path(slot)) != OK:
		return false
	# Class first (to set class_def before stats compute)
	var class_id := StringName(cfg.get_value("meta", "class_id", ""))
	if class_id != &"":
		var cls := ClassRegistry.get_class_def(class_id)
		if cls and player.stats:
			player.stats.class_def = cls
	# Stats
	player.stats.level = int(cfg.get_value("stats", "level", 1))
	player.stats.xp = int(cfg.get_value("stats", "xp", 0))
	player.stats.unspent_skill_points = int(cfg.get_value("stats", "unspent_skill_points", 0))
	var node_ids: Array = cfg.get_value("stats", "unlocked_skill_node_ids", [])
	player.stats.unlocked_skill_node_ids = _strings_to_stringnames(node_ids)
	player.stats.recompute_base()
	player.stats.apply_all_skill_effects()
	player.stats.hp = float(cfg.get_value("stats", "hp", player.stats.max_hp))
	player.stats.mana = float(cfg.get_value("stats", "mana", player.stats.max_mana))
	player.resource_value = float(cfg.get_value("stats", "resource_value", 0.0))
	# Inventory restore — re-instantiate items by id via ItemRegistry,
	# add to bag, restore equipped slots. Without this, loading a save
	# silently drops the player's loot — the biggest 'feels broken'
	# bug Bond would notice on first relaunch.
	if player.has_method("get_inventory"):
		var inv: Inventory = player.get_inventory()
		if inv:
			inv.gold = int(cfg.get_value("inventory", "gold", 0))
			# Clear current bag + equipped before reload to avoid
			# duplication on repeated load_slot calls in the same run.
			inv.bag.clear()
			var registry: Node = get_node_or_null("/root/ItemRegistry")
			# Bag: list of {"id": "...", "count": N}
			var bag_data: Array = cfg.get_value("inventory", "bag_item_ids", [])
			for entry in bag_data:
				if typeof(entry) != TYPE_DICTIONARY:
					continue
				var iid: StringName = StringName(entry.get("id", ""))
				var qty: int = int(entry.get("count", 1))
				if iid == &"" or registry == null:
					continue
				var item: Item = registry.get_item(iid)
				if item:
					inv.add_item(item, qty)
			# Equipped: list of {"slot": int, "id": "..."}
			var equip_data: Array = cfg.get_value("inventory", "equipped_item_ids", [])
			for entry in equip_data:
				if typeof(entry) != TYPE_DICTIONARY:
					continue
				var iid: StringName = StringName(entry.get("id", ""))
				var slot_idx: int = int(entry.get("slot", -1))
				if iid == &"" or registry == null:
					continue
				var item: Item = registry.get_item(iid)
				if item:
					inv.equip(item, slot_idx, player.stats.class_def if player.stats else null)
			# Refresh derived stats now that gear is restored
			if player.stats.has_method("recompute_derived"):
				player.stats.recompute_derived()
	# Position
	var pos = cfg.get_value("world", "position", Vector3.ZERO)
	if pos is Vector3:
		player.global_position = pos
	load_completed.emit(slot)
	return true

func delete_slot(slot: int) -> bool:
	var path := slot_path(slot)
	if not FileAccess.file_exists(path):
		return false
	DirAccess.remove_absolute(path)
	# Best-effort thumbnail cleanup so deleted slots don't leak the
	# previous character's screenshot into the next save.
	var thumb: String = thumbnail_path(slot)
	if FileAccess.file_exists(thumb):
		DirAccess.remove_absolute(thumb)
	slot_deleted.emit(slot)
	return true

func _stringnames_to_strings(arr: Array) -> Array:
	var out: Array = []
	for x in arr:
		out.append(String(x))
	return out

func _strings_to_stringnames(arr: Array) -> Array[StringName]:
	var out: Array[StringName] = []
	for x in arr:
		out.append(StringName(x))
	return out

func _bag_to_ids(inv: Inventory) -> Array:
	var out: Array = []
	for s in inv.bag:
		out.append({"id": String(s.item.id), "count": s.count})
	return out

func _equipped_to_ids(inv: Inventory) -> Array:
	var out: Array = []
	for slot in inv.equipped.keys():
		out.append({"slot": slot, "id": String(inv.equipped[slot].item.id)})
	return out
