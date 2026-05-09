extends CanvasLayer
class_name DeathScreen

# YOU DIED screen. Replaces the old auto-respawn-after-2.5s + camera-replay
# flow with an explicit player choice. Three actions:
#   - Respawn at Lodestone, warps to the most recently attuned lodestone
#   - Wait for Revive, sits with a countdown for a party member to res;
#                       in single-player, falls through to auto-respawn
#                       at REVIVE_TIMEOUT_SECONDS
#   - Quit to Title, change_scene_to_file back to the start menu
#
# Visual: blood-red dripping "YOU DIED" centered, dim red full-screen
# overlay, slow heartbeat fade animation. Heavy. No subtle.

signal respawn_chosen(player: Node)
signal revive_requested(player: Node)
signal quit_chosen()

# 45s = committed but not punitive. Solo players almost never pick Wait
# (they Respawn instantly), so the value primarily defines the multiplayer
# revive window. 30s is too short for a party member to react; 90s makes
# solo wait-and-see feel like the game is sulking. 45 reads as deliberate
# without being slow.
const REVIVE_TIMEOUT_SECONDS: float = 45.0
const HEARTBEAT_PERIOD: float = 1.6

var player: Node = null

# Wait-for-Revive state
var _waiting_for_revive: bool = false
var _revive_started_at: float = 0.0
var _revive_timer_label: Label = null

# UI references
@onready var dim: ColorRect = $Dim if has_node("Dim") else null
@onready var content: Control = $Content if has_node("Content") else null

func _ready() -> void:
	visible = false
	process_mode = Node.PROCESS_MODE_ALWAYS

func open(p_player: Node) -> void:
	player = p_player
	visible = true
	get_tree().paused = true
	_waiting_for_revive = false
	_build()

func close() -> void:
	visible = false
	get_tree().paused = false

func _input(event: InputEvent) -> void:
	# Esc on the death screen does NOTHING, death is a commitment moment.
	# The player must pick. (Quit to Title button is the escape hatch.)
	pass

# ───────────────────── Build ─────────────────────

func _build() -> void:
	if not content:
		return
	for c in content.get_children():
		c.queue_free()

	# Title, "YOU DIED" in heavy blood-red, large
	var title := Label.new()
	title.text = "YOU DIED"
	title.add_theme_font_size_override("font_size", 96)
	title.add_theme_color_override("font_color", Color(0.85, 0.05, 0.05))
	title.add_theme_color_override("font_outline_color", Color(0.20, 0.0, 0.0))
	title.add_theme_constant_override("outline_size", 12)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	title.anchor_left = 0.0; title.anchor_right = 1.0
	title.anchor_top = 0.0; title.anchor_bottom = 0.0
	title.offset_top = 120
	title.offset_bottom = 280
	content.add_child(title)
	# Slow heartbeat fade so the title pulses like the player's last
	# heartbeat, sells the moment without animating particles.
	_animate_heartbeat(title)

	# Sub-line, context. The bug-report-style "what killed you."
	var subtitle := Label.new()
	subtitle.text = _killer_subtitle()
	subtitle.add_theme_font_size_override("font_size", 16)
	subtitle.add_theme_color_override("font_color", Color(0.65, 0.20, 0.20, 0.85))
	subtitle.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	subtitle.anchor_left = 0.0; subtitle.anchor_right = 1.0
	subtitle.offset_top = 290
	subtitle.offset_bottom = 320
	content.add_child(subtitle)

	# Buttons stacked center-bottom
	var btns := VBoxContainer.new()
	btns.anchor_left = 0.5; btns.anchor_right = 0.5
	btns.anchor_top = 1.0; btns.anchor_bottom = 1.0
	btns.offset_left = -180
	btns.offset_right = 180
	btns.offset_top = -260
	btns.offset_bottom = -60
	btns.add_theme_constant_override("separation", 14)
	content.add_child(btns)

	btns.add_child(_make_button("Respawn at Last Lodestone", _on_respawn))
	# Lodestone chooser: lets the player pick ANY discovered stone instead
	# of being forced to the most-recent one. Soulslike convention is "Last
	# Bonfire" being the default but every bonfire being available, this
	# button surfaces that without leaving the death modal.
	btns.add_child(_make_button("Choose Lodestone...", _on_open_lodestone_picker))
	btns.add_child(_make_button("Wait for Revive", _on_wait_for_revive))
	btns.add_child(_make_button("Quit to Title", _on_quit))

func _make_button(text: String, on_press: Callable) -> Button:
	var b := Button.new()
	b.text = text
	b.custom_minimum_size = Vector2(360, 48)
	b.add_theme_font_size_override("font_size", 16)
	b.add_theme_color_override("font_color", Color(0.85, 0.78, 0.55))
	b.add_theme_color_override("font_hover_color", Color(1.0, 0.92, 0.65))
	# Subtle red border that intensifies on hover
	var sb_normal := StyleBoxFlat.new()
	sb_normal.bg_color = Color(0.10, 0.04, 0.04, 0.92)
	sb_normal.border_color = Color(0.55, 0.10, 0.10, 0.85)
	sb_normal.border_width_left = 1; sb_normal.border_width_right = 1
	sb_normal.border_width_top = 1; sb_normal.border_width_bottom = 1
	sb_normal.corner_radius_top_left = 4; sb_normal.corner_radius_top_right = 4
	sb_normal.corner_radius_bottom_left = 4; sb_normal.corner_radius_bottom_right = 4
	b.add_theme_stylebox_override("normal", sb_normal)
	var sb_hover: StyleBoxFlat = sb_normal.duplicate()
	sb_hover.border_color = Color(0.95, 0.20, 0.20, 1.0)
	sb_hover.bg_color = Color(0.14, 0.05, 0.05, 0.95)
	b.add_theme_stylebox_override("hover", sb_hover)
	b.pressed.connect(on_press)
	return b

func _killer_subtitle() -> String:
	if not player:
		return ""
	# Two-line subtitle: the class flavor line (top) + the killer attribution
	# (bottom). The class line is the in-character whisper the protagonist
	# would think as they fall; the killer line is the bug-report data.
	# Example for a Ronin killed by the Crown Captain:
	#   "The blade is patient. So is the man behind it."
	#   "Killed by Crown Captain"
	var class_line: String = _class_death_line()
	var killer_line: String = ""
	var src = player.get("_last_damage_source") if player else null
	if src and is_instance_valid(src):
		var name: String = ""
		if "display_name" in src:
			name = String(src.display_name)
		elif "boss_id" in src and src.boss_id != &"":
			name = String(src.boss_id).replace("_", " ").capitalize()
		elif "mob_id" in src and src.mob_id != &"":
			name = String(src.mob_id).replace("_", " ").capitalize()
		if name != "":
			killer_line = "Killed by %s" % name
	if class_line != "" and killer_line != "":
		return "%s\n%s" % [class_line, killer_line]
	if class_line != "":
		return class_line
	return killer_line

# Class-specific death whisper. Lore-flavored single-line that lands as
# the player reads "YOU DIED." Each class has its own tone:
#   Ronin -> haiku-flat patience
#   Berserker -> rage-cooled
#   Assassin -> deadpan failure
#   Mage -> lament for spent spells
#   Druid -> the wound consumes the healer
#   Demon -> crueler than the player expected
#   Paladin (both specs) -> faith / failure tension
#
# Lines rotate by a hash of the kill timestamp so the same class doesn't
# read the same line every death.
func _class_death_line() -> String:
	if not player or not "stats" in player or player.stats == null:
		return ""
	var class_def = player.stats.class_def if "class_def" in player.stats else null
	if class_def == null:
		return ""
	var class_id: StringName = StringName(class_def.class_id) if "class_id" in class_def else &""
	if class_id == &"":
		return ""
	var pool: Array = _DEATH_LINES_BY_CLASS.get(class_id, [])
	if pool.is_empty():
		return ""
	# Hash by current second so consecutive deaths cycle lines without RNG
	# state to persist. Visually random enough; deterministic enough that
	# a given second's death is reproducible if Bond ever needs to bug-
	# report a particular line.
	var idx: int = int(Time.get_ticks_msec() / 1000) % pool.size()
	return String(pool[idx])

const _DEATH_LINES_BY_CLASS := {
	&"ronin": [
		"The blade is patient. So is the man behind it.",
		"You were a hand on the hilt. Not the hilt.",
		"Breath was the answer. You forgot to breathe.",
		"The cut found the gap. There was always a gap.",
	],
	&"berserker": [
		"The rage cools. The cold lasts longer.",
		"You spent the fury before you spent the foe.",
		"The wound was always going to outrun you.",
		"Strength is not the same as victory.",
	],
	&"assassin": [
		"Seen.",
		"The shadow was not deep enough.",
		"You blinked. Once was enough.",
		"The first knife is the only knife.",
	],
	&"ranger": [
		"The arrow was already in the air. Wrong arrow.",
		"You read the wind. The wind read you back.",
		"Hawk does not return for the falconer who falls.",
		"You ran out of ground before you ran out of arrows.",
	],
	&"mage": [
		"The spell ended. The world did not.",
		"Mana cools. Bone does not.",
		"You spoke a word with no second word.",
		"The arcane is patient. You are not.",
	],
	&"chaos_druid": [
		"The Wound takes its tender first.",
		"You were the corruption you were meant to tend.",
		"Roots forget the gardener.",
		"The grove kept growing. You did not.",
	],
	&"demon": [
		"The pact remembers what you forgot.",
		"Lucifer's wings are not yours to spend.",
		"The contract was always shorter than you read.",
		"You wore the demon. The demon wears you now.",
	],
	&"paladin_guardian": [
		"The shield was held. The shield was not enough.",
		"Duty does not ward off the strike that lands.",
		"You stood. The line broke around you.",
		"Faith asks. The blow answers.",
	],
	&"paladin_lightbringer": [
		"The Sun sets even on the blessed.",
		"You shone. The dark drank.",
		"Hymns end. The night does not.",
		"Mercy was a slower sword than the one that struck.",
	],
}

# Slow heartbeat: pulse alpha 1.0 → 0.55 → 1.0 over HEARTBEAT_PERIOD.
# Sustains forever while the screen is up, heart's still trying.
func _animate_heartbeat(node: Control) -> void:
	var tw := node.create_tween().set_loops()
	tw.tween_property(node, "modulate:a", 0.55, HEARTBEAT_PERIOD * 0.5).set_trans(Tween.TRANS_SINE)
	tw.tween_property(node, "modulate:a", 1.00, HEARTBEAT_PERIOD * 0.5).set_trans(Tween.TRANS_SINE)

# ───────────────────── Actions ─────────────────────

func _on_respawn() -> void:
	if not player:
		close()
		return
	if player.has_method("_respawn"):
		player._respawn()
	respawn_chosen.emit(player)
	close()

# Wait for revive: a party member's res-skill brings the player back.
# In single-player there's no party, so this becomes a forced-wait timer
# that auto-respawns at REVIVE_TIMEOUT_SECONDS. The player can still
# Quit to Title or click Respawn anytime.
func _on_wait_for_revive() -> void:
	_waiting_for_revive = true
	_revive_started_at = Time.get_ticks_msec() / 1000.0
	revive_requested.emit(player)
	_render_wait_state()

func _render_wait_state() -> void:
	if not content:
		return
	for c in content.get_children():
		c.queue_free()

	var title := Label.new()
	title.text = "AWAITING REVIVE"
	title.add_theme_font_size_override("font_size", 56)
	title.add_theme_color_override("font_color", Color(0.85, 0.20, 0.20))
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.anchor_left = 0.0; title.anchor_right = 1.0
	title.offset_top = 160
	title.offset_bottom = 240
	content.add_child(title)
	_animate_heartbeat(title)

	# Countdown label updates each frame from _process
	_revive_timer_label = Label.new()
	_revive_timer_label.add_theme_font_size_override("font_size", 22)
	_revive_timer_label.add_theme_color_override("font_color", Color(0.85, 0.40, 0.40, 0.85))
	_revive_timer_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_revive_timer_label.anchor_left = 0.0; _revive_timer_label.anchor_right = 1.0
	_revive_timer_label.offset_top = 280
	_revive_timer_label.offset_bottom = 320
	content.add_child(_revive_timer_label)

	# Hint, clarifies the multiplayer-vs-single-player behavior
	var hint := Label.new()
	hint.text = "A party member with a revive ability can bring you back. With no allies near, you will respawn at the last lodestone when the timer expires."
	hint.add_theme_font_size_override("font_size", 13)
	hint.add_theme_color_override("font_color", Color(0.65, 0.45, 0.45, 0.85))
	hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	hint.anchor_left = 0.0; hint.anchor_right = 1.0
	hint.offset_left = 200
	hint.offset_right = -200
	hint.offset_top = 340
	hint.offset_bottom = 410
	content.add_child(hint)

	# Bottom buttons, escape hatches stay
	var btns := VBoxContainer.new()
	btns.anchor_left = 0.5; btns.anchor_right = 0.5
	btns.anchor_top = 1.0; btns.anchor_bottom = 1.0
	btns.offset_left = -180
	btns.offset_right = 180
	btns.offset_top = -200
	btns.offset_bottom = -60
	btns.add_theme_constant_override("separation", 14)
	content.add_child(btns)
	btns.add_child(_make_button("Respawn Now", _on_respawn))
	btns.add_child(_make_button("Quit to Title", _on_quit))

func _process(_delta: float) -> void:
	if not visible or not _waiting_for_revive:
		return
	var now: float = Time.get_ticks_msec() / 1000.0
	var elapsed: float = now - _revive_started_at
	var remaining: float = max(0.0, REVIVE_TIMEOUT_SECONDS - elapsed)
	if _revive_timer_label:
		_revive_timer_label.text = "%d seconds remaining" % int(ceil(remaining))
	if remaining <= 0.0:
		_on_respawn()  # forced respawn at lodestone

func _on_quit() -> void:
	get_tree().paused = false
	quit_chosen.emit()
	close()
	get_tree().change_scene_to_file("res://scenes/menus/start_menu.tscn")

# ───────── Lodestone picker ─────────
#
# Opens a scrollable list of every discovered lodestone. Picking one
# warps via LodestoneRegistry.travel(id), which handles scene-change +
# warp SFX. Player HP is restored by the same path _on_respawn uses
# (Player._respawn handles HP), but here we restore manually because
# we're skipping _respawn() to control the destination.

func _on_open_lodestone_picker() -> void:
	if not content:
		return
	for c in content.get_children():
		c.queue_free()

	var title := Label.new()
	title.text = "CHOOSE A LODESTONE"
	title.add_theme_font_size_override("font_size", 36)
	title.add_theme_color_override("font_color", Color(1.0, 0.85, 0.45))
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.anchor_left = 0.0; title.anchor_right = 1.0
	title.offset_top = 80
	title.offset_bottom = 130
	content.add_child(title)

	var registry: Node = get_node_or_null("/root/LodestoneRegistry")
	if registry == null or not registry.has_method("get_discovered"):
		_lodestone_picker_show_empty("Lodestone registry unavailable.")
		return
	var disc: Dictionary = registry.get_discovered()
	if disc.is_empty():
		# Soft-fail: discovered nothing yet means there's only the starting
		# hub. Tell the player so the empty list isn't mysterious.
		_lodestone_picker_show_empty("No lodestones discovered. Respawn at the Sword-Vow Dais.")
		return

	# Scrollable list, anchored mid-screen so it doesn't fight the title
	# at the top or the back button at the bottom.
	var scroll := ScrollContainer.new()
	scroll.anchor_left = 0.5; scroll.anchor_right = 0.5
	scroll.anchor_top = 0.0; scroll.anchor_bottom = 1.0
	scroll.offset_left = -260
	scroll.offset_right = 260
	scroll.offset_top = 150
	scroll.offset_bottom = -130
	content.add_child(scroll)
	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 6)
	vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(vbox)

	# Sort: hub first, then villages, then wilderness, then dungeon-bosses,
	# then cities. Within each group alphabetical by name. Reads top-down
	# from "safest" to "deepest."
	var ordered_kinds := ["hub", "village", "wilderness", "city", "dungeon_boss", "fortress"]
	var grouped: Dictionary = {}
	for id in disc.keys():
		var meta: Dictionary = disc[id]
		var k: String = String(meta.get("kind", "wilderness"))
		if not grouped.has(k):
			grouped[k] = []
		grouped[k].append({"id": id, "name": String(meta.get("name", String(id)))})
	for kind in ordered_kinds:
		if not grouped.has(kind):
			continue
		var entries: Array = grouped[kind]
		entries.sort_custom(func(a, b): return String(a["name"]) < String(b["name"]))
		for e in entries:
			vbox.add_child(_make_lodestone_button(StringName(e["id"]), String(e["name"]), kind))
	# Catch any unrecognized kinds we forgot to order, display them at the
	# bottom rather than dropping them silently.
	for k in grouped.keys():
		if k in ordered_kinds:
			continue
		for e in grouped[k]:
			vbox.add_child(_make_lodestone_button(StringName(e["id"]), String(e["name"]), String(k)))

	# Back button, bottom-center
	var back := _make_button("← Back", _build)
	back.anchor_left = 0.5; back.anchor_right = 0.5
	back.anchor_top = 1.0; back.anchor_bottom = 1.0
	back.offset_left = -180
	back.offset_right = 180
	back.offset_top = -100
	back.offset_bottom = -50
	content.add_child(back)

func _lodestone_picker_show_empty(msg: String) -> void:
	var note := Label.new()
	note.text = msg
	note.add_theme_font_size_override("font_size", 18)
	note.add_theme_color_override("font_color", Color(0.85, 0.45, 0.45))
	note.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	note.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	note.anchor_left = 0.0; note.anchor_right = 1.0
	note.offset_left = 200
	note.offset_right = -200
	note.offset_top = 220
	note.offset_bottom = 320
	content.add_child(note)
	var back := _make_button("← Back", _build)
	back.anchor_left = 0.5; back.anchor_right = 0.5
	back.anchor_top = 1.0; back.anchor_bottom = 1.0
	back.offset_left = -180
	back.offset_right = 180
	back.offset_top = -100
	back.offset_bottom = -50
	content.add_child(back)

# Per-lodestone row. Kind tag in muted color so the player can scan tier
# at a glance, "the wilderness ones tend to be in danger zones."
func _make_lodestone_button(id: StringName, display_name: String, kind: String) -> Button:
	var b := Button.new()
	b.custom_minimum_size = Vector2(500, 44)
	b.add_theme_font_size_override("font_size", 16)
	b.add_theme_color_override("font_color", Color(0.95, 0.85, 0.55))
	b.add_theme_color_override("font_hover_color", Color(1.0, 0.95, 0.65))
	# Tag-prefix: bracketed kind in muted gold so the row reads
	# "[CITY]  Babilim Grand Altar" without needing two columns.
	var kind_label: String = "[%s]" % kind.to_upper().replace("_", " ")
	b.text = "%s  %s" % [kind_label, display_name]
	b.alignment = HORIZONTAL_ALIGNMENT_LEFT
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.10, 0.05, 0.05, 0.92)
	sb.border_color = Color(0.55, 0.30, 0.10, 0.85)
	sb.border_width_left = 1; sb.border_width_right = 1
	sb.border_width_top = 1; sb.border_width_bottom = 1
	sb.corner_radius_top_left = 3; sb.corner_radius_top_right = 3
	sb.corner_radius_bottom_left = 3; sb.corner_radius_bottom_right = 3
	sb.content_margin_left = 16
	b.add_theme_stylebox_override("normal", sb)
	var sb_hover: StyleBoxFlat = sb.duplicate()
	sb_hover.border_color = Color(1.0, 0.85, 0.30, 1.0)
	sb_hover.bg_color = Color(0.16, 0.08, 0.05, 0.95)
	b.add_theme_stylebox_override("hover", sb_hover)
	b.pressed.connect(_on_lodestone_picked.bind(id))
	return b

func _on_lodestone_picked(id: StringName) -> void:
	var registry: Node = get_node_or_null("/root/LodestoneRegistry")
	if registry == null or not registry.has_method("travel"):
		# Fail-open back to default respawn so the death screen doesn't
		# soft-lock if the registry vanished mid-session.
		_on_respawn()
		return
	# Restore HP first so the player doesn't arrive at the lodestone with
	# 0 HP and immediately die again. Player._respawn does this; we have
	# to mirror it here because we're skipping the default path.
	if player and "stats" in player and player.stats:
		player.stats.hp = player.stats.max_hp
		if player.has_signal("hp_changed"):
			player.emit_signal("hp_changed", player.stats.hp, player.stats.max_hp)
	if "locked" in player:
		player.locked = false
	respawn_chosen.emit(player)
	close()
	registry.travel(id)

# Public API for party revive, called by an ally's revive ability when
# the rezzer's hitbox overlaps the dead player. Closes the screen and
# resurrects without warping.
func consume_revive() -> bool:
	if not visible or not _waiting_for_revive or not player:
		return false
	# Restore player to half HP at current position
	if player.get("stats") and player.stats:
		player.stats.hp = player.stats.max_hp * 0.5
		if player.has_signal("hp_changed"):
			player.emit_signal("hp_changed", player.stats.hp, player.stats.max_hp)
	if "locked" in player:
		player.locked = false
	close()
	return true
