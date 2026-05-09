extends Node
class_name SacrificeRitual

# Implements the Heaven Rule (CHARACTER_DESIGN.md § 8.4 + DEMON_VISUAL_TRANSFORMATION.md § 18).
#
# When a Demon-class character attempts to equip Heaven, the Inventory equip flow
# emits `sacrifice_required(player, item)`. The SacrificePrompt UI catches that
# signal, shows the modal, and on accept calls SacrificeRitual.walk_back(player).
#
# This module handles the irreversible state changes. It does NOT show UI.

# Demon-only items become these inert "Inheritance Trinkets" after the sacrifice.
# Their stats are zeroed but the lore lines persist (badges of what the Demon was).
const INHERITANCE_TRINKET_PREFIX := "Inheritance Trinket, "

# Performs the full walk-back ritual on the given Player node.
# Returns true on success, false if validation failed (and logs why).
static func walk_back(player: Node) -> bool:
	if not player or not is_instance_valid(player):
		push_warning("[SacrificeRitual] invalid player")
		return false

	var ca = player.get("character_appearance")
	if not ca:
		push_warning("[SacrificeRitual] player has no character_appearance")
		return false

	if ca.lucifer_walked_back:
		push_warning("[SacrificeRitual] this character has already walked back; the gate does not open twice")
		return false

	if not player.get("stats") or not player.stats.class_def or player.stats.class_def.class_id != &"demon":
		push_warning("[SacrificeRitual] only Demon-class characters can walk back")
		return false

	# Resolve the pre-Lucifer class (default Ronin if unset, see § 18.9 edge cases)
	var pre_class_id: StringName = ca.pre_lucifer_class_id
	if pre_class_id == &"":
		push_warning("[SacrificeRitual] pre_lucifer_class_id missing; defaulting to Ronin")
		pre_class_id = &"ronin"

	var class_registry: Node = player.get_node_or_null("/root/ClassRegistry")
	if not class_registry:
		push_warning("[SacrificeRitual] ClassRegistry autoload missing")
		return false

	var pre_class = class_registry.get_class_def(pre_class_id)
	if not pre_class:
		push_warning("[SacrificeRitual] unknown pre_lucifer_class_id: %s" % pre_class_id)
		return false

	# === Step 1: Lock the gate forever for this character ===
	ca.lucifer_walked_back = true
	var save_flags: Node = player.get_node_or_null("/root/SaveFlags")
	if save_flags and save_flags.has_method("set_permanent"):
		save_flags.set_permanent(&"lucifer_walked_back", true)

	# === Step 2: Strip the Demon class, restore pre-Lucifer ===
	player.stats.class_def = pre_class
	# Wipe Demon skill tree progression (all dm_* node ids)
	var stripped: Array[StringName] = []
	for nid in player.stats.unlocked_skill_node_ids:
		var s: String = String(nid)
		if not s.begins_with("dm_"):
			stripped.append(nid)
	player.stats.unlocked_skill_node_ids = stripped
	# Restore pre-Lucifer skill tree progression from the snapshot
	for nid in ca.pre_lucifer_skill_node_ids:
		if not (nid in player.stats.unlocked_skill_node_ids):
			player.stats.unlocked_skill_node_ids.append(nid)
	# Refresh resource mechanic (mana/stamina/rage instead of blood)
	player.resource_value = 0.0

	# === Step 3: Strip Demon visual overlay ===
	ca.demon_overlay = null
	ca.carries_sacrifice_scar = true
	# Reapply appearance from scratch, removes horns, eye glow, veins, claws.
	var appearance_registry: Node = player.get_node_or_null("/root/AppearanceRegistry")
	if appearance_registry and appearance_registry.has_method("apply"):
		appearance_registry.apply(player, ca)

	# === Step 4: Add the white sacrifice scar (HOLY element, never fades) ===
	var scar_mgr: Node = player.get_node_or_null("ScarManager")
	if scar_mgr:
		_apply_sacrifice_scar(scar_mgr)

	# === Step 5: Convert Demon-only items to Inheritance Trinkets ===
	if player.get("inventory") and player.inventory:
		_convert_demon_items_to_trinkets(player.inventory)

	# === Step 6: Award both Mortal Returned title variants ===
	# Player picks one to display, see TitleRegistry._register_sacrifice_titles.
	var title_registry: Node = player.get_node_or_null("/root/TitleRegistry")
	if title_registry and title_registry.has_method("award"):
		title_registry.award(&"the_mortal_returned")
		title_registry.award(&"twice_walker")

	# === Step 7: Rebuild Q/E/R/F kit with the restored class ===
	if player.has_method("_build_ability_kit"):
		player._build_ability_kit()

	# === Step 8: Emit class_changed so HUD refreshes ===
	if player.has_signal("class_changed"):
		player.emit_signal("class_changed", pre_class)

	# === Step 9: Cinematic + audio (Tier 2, placeholder hook) ===
	_play_walk_back_cinematic(player)

	# === Step 10: Auto-equip Heaven if the new class is Ronin ===
	if pre_class_id == &"ronin":
		_attempt_auto_equip_heaven(player)

	print("[SacrificeRitual] %s walked back. Pre-Lucifer class restored: %s" % [
		ca.gender if ca.gender else "character",
		pre_class.display_name,
	])
	return true

# Internal: spawn the white-gold permanent scar marking the sacrifice.
static func _apply_sacrifice_scar(scar_mgr: Node) -> void:
	var scar = preload("res://scripts/player/combat_scar.gd").new()
	scar.scar_id = &"sacrifice_scar"
	scar.location = &"chest"
	scar.intensity = 0.6
	scar.element = 5  # HOLY
	scar.timestamp = int(Time.get_unix_time_from_system())
	scar.is_boss_scar = true  # never fades
	scar.source_id = &"lucifer_gate_walked_back"
	scar.source_display_name = "Lucifer's Gate, walked back"
	if "scars" in scar_mgr:
		scar_mgr.scars.append(scar)
	if scar_mgr.has_method("_spawn_scar_visual"):
		scar_mgr._spawn_scar_visual(scar)
	if scar_mgr.has_signal("scar_added"):
		scar_mgr.emit_signal("scar_added", scar)

# Internal: every Demon-restricted item in the bag becomes an inert trinket.
# Stats are zeroed but the item persists for lore (a memento of what the Demon was).
static func _convert_demon_items_to_trinkets(inventory: Object) -> void:
	if not inventory or not "bag" in inventory:
		return
	for stack in inventory.bag:
		var item = stack.item if stack else null
		if not item:
			continue
		if not (&"demon" in item.class_restriction):
			continue
		# Soulbind off, stats zeroed, name prefixed
		item.display_name = INHERITANCE_TRINKET_PREFIX + item.display_name
		item.class_restriction = []
		item.is_soulbound = false
		item.base_damage = 0.0
		item.strength_bonus = 0.0
		item.dexterity_bonus = 0.0
		item.intellect_bonus = 0.0
		item.vitality_bonus = 0.0
		item.armor_bonus = 0.0
		item.magic_resist_bonus = 0.0
		item.crit_chance_bonus = 0.0
		item.crit_multiplier_bonus = 0.0
		item.damage_bonus_pct = 0.0

# Internal: try to put Heaven in the mainhand slot now that the player is Ronin.
# If Heaven is in the bag, equip it; otherwise this is a no-op (player will equip later).
static func _attempt_auto_equip_heaven(player: Node) -> void:
	if not player.get("inventory") or not player.inventory:
		return
	var heaven_in_bag: Object = null
	for stack in player.inventory.bag:
		if stack and stack.item and stack.item.id == &"heaven":
			heaven_in_bag = stack.item
			break
	if heaven_in_bag and player.inventory.has_method("equip"):
		player.inventory.equip(heaven_in_bag, -1, player.stats.class_def)

# Internal: hook for the 8-second outbound gate-walk cinematic.
# Tier 2 implementation, for now it just plays a juice flash + slowmo.
static func _play_walk_back_cinematic(player: Node) -> void:
	var juice: Node = player.get_node_or_null("/root/Juice")
	if juice:
		if juice.has_method("slowmo"):
			juice.slowmo(0.20, 2.5)  # half-speed for 2.5 seconds
		if juice.has_method("flash"):
			juice.flash(Color(0.95, 0.92, 0.80), 0.8, 1.6)  # warm dawn-light flash
		if juice.has_method("toast"):
			juice.toast("THE GATE DOES NOT OPEN TWICE", Color(0.95, 0.92, 0.80), 3.0)
	# Audio: layered cue, victory arpeggio (the player won) + lodestone
	# (the gate-walk-out). The combo sells "this was a transformation, not
	# a defeat." `&"sacrifice"` was a hypothetical cue name; using existing
	# cues so the audio actually plays.
	var audio: Node = player.get_node_or_null("/root/AudioBus")
	if audio and audio.has_method("play_cue"):
		var pos: Vector3 = player.global_position if player is Node3D else Vector3.ZERO
		audio.play_cue(&"victory", pos, -2.0, 0.65)
		audio.play_cue(&"lodestone", pos, -4.0, 0.55)
