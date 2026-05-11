extends Node

# CodexRegistry, autoload that holds the canonical lore archive. The
# Codex is the player's compounding archive of everything they have
# encountered: regions visited, characters spoken to, items found,
# lore notes read, achievements earned. Each entry is registered once
# (statically by other autoloads, or dynamically when the player first
# encounters it) and unlocked the first time the player sees it.
#
# Other systems push entries here. Examples:
#   - Region scenes call CodexRegistry.unlock(&"r_<region_id>") on _ready
#   - NPCs call unlock(&"c_<npc_id>") on first dialogue
#   - Items call unlock(&"i_<item_id>") on first pickup
#   - Achievements unlock a paired codex entry on completion
#
# Public API:
#   register(entry: Dictionary) -> declare an entry exists
#   unlock(id: StringName) -> bool (true if newly unlocked)
#   is_unlocked(id: StringName) -> bool
#   entries_by_category(category: StringName) -> Array
#   get_entry(id: StringName) -> Dictionary
#   get_categories() -> Array[StringName]
#   count_unlocked() -> int
#   count_total() -> int
#
# Signals:
#   entry_unlocked(entry: Dictionary), fires after a successful unlock
#
# Persistence: each unlock writes a SaveFlags permanent flag named
# "codex_<id>". On _ready the registry walks all known entries and
# rebuilds the unlocked dict from those flags. Codex progress survives
# prestige cycles by design (lore should not be erased).

const SAVEFLAG_PREFIX := "codex_"

# Standard categories. Other systems may register under any string but
# these are the displayed groupings in the panel.
const CATEGORY_REGIONS:      StringName = &"regions"
const CATEGORY_CHARACTERS:   StringName = &"characters"
const CATEGORY_ITEMS:        StringName = &"items"
const CATEGORY_LORE:         StringName = &"lore"
const CATEGORY_BESTIARY:     StringName = &"bestiary"
const CATEGORY_ACHIEVEMENTS: StringName = &"achievements"

var _entries: Dictionary = {}      # id -> entry Dictionary
var _by_category: Dictionary = {}  # category StringName -> Array[StringName id]
var _unlocked: Dictionary = {}     # id -> true

signal entry_unlocked(entry: Dictionary)

func _ready() -> void:
	_load_from_save_flags()

# Declare an entry exists. Safe to call multiple times; later calls
# overwrite the entry's metadata (useful for re-seeding lore prose
# after edits without resetting unlock state).
func register(entry: Dictionary) -> void:
	var id: StringName = entry.get("id", &"")
	if id == &"":
		push_warning("CodexRegistry.register: entry missing id")
		return
	_entries[id] = entry
	var cat: StringName = entry.get("category", &"misc")
	if not _by_category.has(cat):
		_by_category[cat] = []
	if not (id in _by_category[cat]):
		_by_category[cat].append(id)

# Mark an entry as unlocked. Returns true only on the first unlock.
# Subsequent calls are silent no-ops (so call sites can fire freely).
func unlock(id: StringName) -> bool:
	if not _entries.has(id):
		# Tolerate unlocks for entries not yet registered, register a
		# minimal stub so progress is captured. The owning system can
		# call register() later with the real prose.
		register({"id": id, "category": &"misc", "display_name": String(id)})
	if _unlocked.has(id):
		return false
	_unlocked[id] = true
	_save_flag(id)
	entry_unlocked.emit(_entries[id])
	# Soft toast, codex unlocks accumulate fast and shouldn't
	# interrupt with a screen flash. Just a smaller banner.
	var juice = get_node_or_null("/root/Juice")
	if juice:
		var entry: Dictionary = _entries.get(id, {})
		var name: String = entry.get("display_name", String(id))
		juice.toast("Codex: %s" % name, Color(0.55, 0.85, 0.95), 2.0)
	return true

func is_unlocked(id: StringName) -> bool:
	return _unlocked.has(id)

func entries_by_category(category: StringName) -> Array:
	var ids: Array = _by_category.get(category, [])
	var out: Array = []
	for id in ids:
		if _entries.has(id):
			out.append(_entries[id])
	return out

func get_entry(id: StringName) -> Dictionary:
	return _entries.get(id, {})

func get_categories() -> Array:
	return _by_category.keys()

func count_unlocked() -> int:
	return _unlocked.size()

func count_total() -> int:
	return _entries.size()

# ───── Bestiary kill counters ─────
#
# Per-mob_id integer count of how many times the player has killed this
# mob type. Stored as SaveFlags permanent (key = "kills_<mob_id>") so it
# persists across saves + prestige. Bumped from EnemyBase._die; read by
# the codex bestiary tab to render "kills: 47" under each entry.

const KILL_COUNT_PREFIX := "kills_"

func bump_kill_count(mob_id: StringName) -> void:
	if mob_id == &"":
		return
	var current: int = get_kill_count(mob_id)
	var sf: Node = get_node_or_null("/root/SaveFlags")
	if sf and sf.has_method("set_permanent"):
		sf.set_permanent(StringName(KILL_COUNT_PREFIX + String(mob_id)), current + 1)

func get_kill_count(mob_id: StringName) -> int:
	if mob_id == &"":
		return 0
	var sf: Node = get_node_or_null("/root/SaveFlags")
	if sf == null or not sf.has_method("get_permanent"):
		return 0
	return int(sf.get_permanent(StringName(KILL_COUNT_PREFIX + String(mob_id)), 0))

# Append a paragraph to an existing entry's body. Used by BossBase._die
# to add a player-authored "I killed this thing at level X" postscript
# to the boss's lore entry. The append accumulates across kills so a
# player who slays the same boss multiple times builds up a small
# journal under the canonical lore.
#
# Idempotent: if the entry doesn't exist, no-op. If the entry doesn't
# carry a body field, treat as empty string. Newlines added between
# the existing body and the appended text so the journal entries read
# as distinct stanzas, not a wall of text.
func append_to_body(id: StringName, paragraph: String) -> void:
	if not _entries.has(id) or paragraph == "":
		return
	var entry: Dictionary = _entries[id]
	var current_body: String = String(entry.get("body", ""))
	if current_body.length() > 0:
		entry["body"] = current_body + "\n\n" + paragraph
	else:
		entry["body"] = paragraph
	_entries[id] = entry

func _save_flag(id: StringName) -> void:
	var sf := get_node_or_null("/root/SaveFlags")
	if sf and sf.has_method("set_permanent"):
		sf.set_permanent(StringName(SAVEFLAG_PREFIX + String(id)), true)

func _load_from_save_flags() -> void:
	var sf := get_node_or_null("/root/SaveFlags")
	if sf == null:
		return
	if not sf.has_method("has_permanent"):
		return
	for id in _entries.keys():
		var key := StringName(SAVEFLAG_PREFIX + String(id))
		if sf.has_permanent(key):
			_unlocked[id] = true
