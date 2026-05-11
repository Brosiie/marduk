extends Control
class_name CombatLog

# Bottom-left scrollable text log. Stores the last N events in a ring
# buffer. Listens for combat / loot / level / quest signals and prints
# color-coded lines. Auto-fades older lines so the log doesn't clutter
# the screen during heavy combat.
#
# Public API:
#   log_event(text: String, color: Color = white)
#   log_damage_dealt(target_name: String, amount: float, is_crit: bool)
#   log_damage_taken(source_name: String, amount: float)
#   log_loot(item_name: String, rarity: int)
#   log_level_up(new_level: int)

const MAX_LINES: int = 5
const LINE_FADE_AT: float = 6.0   # seconds before a line starts to fade
const LINE_REMOVE_AT: float = 9.0

# Panel sized to be a peripheral feed, not a screen quadrant.
const PANEL_WIDTH: float = 240.0
const PANEL_HEIGHT: float = 105.0

var _v: VBoxContainer
var _lines: Array[Dictionary] = []  # {label: Label, age: float}

# Spam-filter knobs. Default ON so Bond sees a curated feed of only the
# events that matter; flip via `set_interesting_only(false)` to get
# the verbose-old-style firehose for debugging.
var interesting_only: bool = true
# Damage-taken throttle: only log a "took N damage" line if EITHER it's
# been MIN_INTERVAL since the last one OR the hit is BIG (over BIG_PCT
# of max HP). Stops bleed/poison ticks from drowning the log.
const DMG_LOG_MIN_INTERVAL: float = 1.0
const DMG_LOG_BIG_PCT: float = 0.10
var _last_dmg_log_time: float = -INF

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	anchor_left = 0.0
	anchor_top = 1.0
	anchor_right = 0.0
	anchor_bottom = 1.0
	offset_left = 20.0
	offset_top = -PANEL_HEIGHT - 90.0  # above the ability bar
	offset_right = offset_left + PANEL_WIDTH
	offset_bottom = offset_top + PANEL_HEIGHT

	# Frame: dark slate with gold filigree edge, same language as the
	# rest of the HUD. Old version was a transparent black rect that
	# read as 'developer overlay' rather than 'UI element'.
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.05, 0.04, 0.06, 0.85)
	sb.border_color = Color(0.55, 0.42, 0.20, 0.85)
	sb.set_border_width_all(1)
	sb.border_width_top = 2  # thicker top edge = bevel-from-above read
	sb.set_corner_radius_all(4)
	sb.shadow_color = Color(0, 0, 0, 0.55)
	sb.shadow_size = 4
	sb.shadow_offset = Vector2(0, 2)
	sb.content_margin_left = 10
	sb.content_margin_top = 6
	sb.content_margin_right = 10
	sb.content_margin_bottom = 6
	var panel := PanelContainer.new()
	panel.anchor_right = 1.0
	panel.anchor_bottom = 1.0
	panel.add_theme_stylebox_override("panel", sb)
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(panel)

	_v = VBoxContainer.new()
	_v.alignment = BoxContainer.ALIGNMENT_END
	_v.add_theme_constant_override("separation", 1)
	panel.add_child(_v)

	# Wire to player signals once available
	_attach_signals()

func _attach_signals() -> void:
	var p := get_tree().get_first_node_in_group("player")
	if p == null:
		# defer until next frame
		get_tree().create_timer(0.1).timeout.connect(_attach_signals)
		return
	if p.has_signal("item_collected"):
		p.item_collected.connect(_on_item_collected)
	if p.has_signal("hp_changed"):
		# Damage taken events: track HP delta
		p.hp_changed.connect(_on_hp_changed)
	if p.has_signal("died"):
		p.died.connect(_on_died)
	if "stats" in p and p.stats and p.stats.has_signal("leveled_up"):
		p.stats.leveled_up.connect(log_level_up)

	# Quest registry
	var qr = get_node_or_null("/root/QuestRegistry")
	if qr and qr.has_signal("quest_accepted"):
		qr.quest_accepted.connect(_on_quest_accepted)
	if qr and qr.has_signal("quest_completed"):
		qr.quest_completed.connect(_on_quest_completed)

	# Achievement registry
	var ar = get_node_or_null("/root/AchievementRegistry")
	if ar and ar.has_signal("achievement_unlocked"):
		ar.achievement_unlocked.connect(_on_achievement)

	# Lodestone registry
	var lr = get_node_or_null("/root/LodestoneRegistry")
	if lr and lr.has_signal("discovered"):
		lr.discovered.connect(_on_lodestone)

	# CombatBus boss-defeat hook so kills log without each boss subclass
	# needing to know about us. Bridge: `kill_registered` fires for any
	# kill credited to the player; filter to bosses via group membership.
	var cb := get_node_or_null("/root/CombatBus")
	if cb and cb.has_signal("kill_registered"):
		cb.kill_registered.connect(_on_kill_registered)

func _process(delta: float) -> void:
	# Age out old lines (fade then remove)
	var to_remove: Array[int] = []
	for i in range(_lines.size()):
		_lines[i].age += delta
		var age: float = _lines[i].age
		var lbl: Label = _lines[i].label
		if age > LINE_FADE_AT:
			var t: float = clamp((age - LINE_FADE_AT) / (LINE_REMOVE_AT - LINE_FADE_AT), 0.0, 1.0)
			lbl.modulate.a = lerp(1.0, 0.0, t)
		if age > LINE_REMOVE_AT:
			to_remove.append(i)
	# Remove from the back so indices stay valid
	for i in range(to_remove.size() - 1, -1, -1):
		var idx: int = to_remove[i]
		var lbl: Label = _lines[idx].label
		if is_instance_valid(lbl):
			lbl.queue_free()
		_lines.remove_at(idx)

# --- Public log functions ---

func log_event(text: String, color: Color = Color(0.9, 0.9, 0.9)) -> void:
	if _v == null:
		return
	if _lines.size() >= MAX_LINES:
		var oldest: Dictionary = _lines[0]
		var oldest_lbl: Label = oldest.label
		if is_instance_valid(oldest_lbl):
			oldest_lbl.queue_free()
		_lines.remove_at(0)
	var lbl := Label.new()
	lbl.text = text
	lbl.add_theme_font_size_override("font_size", 12)
	lbl.add_theme_color_override("font_color", color)
	lbl.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.92))
	lbl.add_theme_constant_override("outline_size", 3)
	lbl.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.65))
	lbl.add_theme_constant_override("shadow_offset_x", 1)
	lbl.add_theme_constant_override("shadow_offset_y", 1)
	lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_v.add_child(lbl)
	_lines.append({"label": lbl, "age": 0.0})

func log_damage_dealt(target_name: String, amount: float, is_crit: bool) -> void:
	var color := Color(0.95, 0.85, 0.30) if is_crit else Color(0.85, 0.85, 0.85)
	var prefix := "CRIT " if is_crit else ""
	log_event("→ %s%s for %d" % [prefix, target_name, int(amount)], color)

func log_damage_taken(source_name: String, amount: float) -> void:
	log_event("← %s hits you for %d" % [source_name, int(amount)], Color(0.95, 0.40, 0.40))

func log_loot(item_name: String, rarity: int) -> void:
	var color := _rarity_color(rarity)
	log_event("+ %s" % item_name, color)

func log_level_up(new_level: int) -> void:
	log_event("Level up, %d" % new_level, Color(0.95, 0.85, 0.30))

# --- Signal handlers ---

var _last_hp: float = -1.0

func _on_hp_changed(cur: float, mx: float) -> void:
	if _last_hp > 0.0 and cur < _last_hp:
		var delta: float = _last_hp - cur
		if delta >= 1.0:
			# Throttle: in interesting_only mode, suppress damage logs that
			# fire faster than DMG_LOG_MIN_INTERVAL UNLESS the hit is big
			# (over DMG_LOG_BIG_PCT of max HP). Catches the "DoT tick spam"
			# case while still surfacing actual heavy hits in real time.
			var now: float = Time.get_ticks_msec() / 1000.0
			var big_pct_threshold: float = mx * DMG_LOG_BIG_PCT
			var is_big: bool = delta >= big_pct_threshold
			if interesting_only:
				if not is_big and (now - _last_dmg_log_time) < DMG_LOG_MIN_INTERVAL:
					_last_hp = cur
					return
			_last_dmg_log_time = now
			# Big hits get a louder color + a "!" suffix so they stand out
			# from chip damage in the log.
			var color: Color = Color(0.95, 0.20, 0.20) if is_big else Color(0.95, 0.55, 0.55)
			var suffix: String = "!" if is_big else ""
			log_event("← took %d damage%s" % [int(delta), suffix], color)
	_last_hp = cur

# Public API to flip the filter at runtime (settings panel hookup).
func set_interesting_only(enabled: bool) -> void:
	interesting_only = enabled

func _on_item_collected(item: Item, qty: int) -> void:
	if item == null:
		return
	# Filter out junk + basic loot in interesting_only mode. Player still
	# gets the toast notification; this just keeps the log focused on
	# meaningful pickups (rare and above).
	if interesting_only and int(item.rarity) <= 1:  # 0=JUNK, 1=BASIC
		return
	log_loot("%s%s" % [item.display_name, (" x%d" % qty) if qty > 1 else ""], int(item.rarity))

func _on_kill_registered(target: Node, _killer: Node) -> void:
	# Only log boss kills here; mob kills would spam the feed during
	# arena clears. BossBase adds itself to the "boss" group so the
	# group check is enough.
	if target == null or not is_instance_valid(target):
		return
	if not target.is_in_group("boss"):
		return
	var name: String = String(target.get("display_name") if target.has_method("get") else "")
	if name == "":
		name = String(target.name)
	log_event("⚔ %s slain" % name, Color(1.0, 0.65, 0.10))

func _on_died() -> void:
	log_event("You have died.", Color(0.95, 0.40, 0.40))

func _on_quest_accepted(q: Variant) -> void:
	var name: String = q.display_name if q.has_method("get") else "Quest"
	log_event("Quest accepted: %s" % name, Color(0.95, 0.85, 0.30))

func _on_quest_completed(q: Variant) -> void:
	var name: String = q.display_name if q.has_method("get") else "Quest"
	log_event("Quest complete: %s" % name, Color(0.45, 0.95, 0.55))

func _on_achievement(a: Variant) -> void:
	var name: String = a.display_name if a.has_method("get") else "Achievement"
	log_event("★ %s" % name, Color(1.0, 0.65, 0.10))

func _on_lodestone(_id: StringName, name: String) -> void:
	log_event("Attuned: %s" % name, Color(0.45, 0.65, 1.00))

func _rarity_color(rarity: int) -> Color:
	match rarity:
		0: return Color(0.40, 0.40, 0.40)
		1: return Color(0.85, 0.85, 0.85)
		2: return Color(0.55, 0.85, 0.45)
		3: return Color(0.40, 0.50, 0.95)
		4: return Color(0.75, 0.30, 0.95)
		5: return Color(1.00, 0.65, 0.10)
		6: return Color(1.00, 0.95, 0.55)
	return Color.WHITE
