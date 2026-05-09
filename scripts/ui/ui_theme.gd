extends RefCounted
class_name UITheme

# Central UI constants. Pulls the duplicated magic numbers and palette
# entries out of every panel and into one place so the game has a coherent
# visual language. Use via `const T := preload("res://scripts/ui/ui_theme.gd")`
# at the top of a panel script, then reference `T.HEADING_GOLD`,
# `T.FONT_TITLE`, etc.
#
# The preload-bypass pattern is intentional: same lesson as FactionRegistry,
# stale .godot/global_script_class_cache.cfg can leave class_name unresolved
# and take downstream panels offline. Preload is order-independent.

# ─────── Palette ───────

# Headings + accents. The game's "you should look at this" color.
const HEADING_GOLD       := Color(0.95, 0.85, 0.45)
# Body / running text. Slightly warm cream.
const BODY_CREAM         := Color(0.95, 0.92, 0.80)
# Hint / tertiary text. Muted bronze.
const HINT_BRONZE        := Color(0.78, 0.72, 0.60)
# Currency (gold pieces). Brighter than headings to stand out.
const CURRENCY_GOLD      := Color(1.00, 0.85, 0.30)
# Warning / refuse / danger.
const DANGER_RED         := Color(0.85, 0.30, 0.25)
# Positive / accept / quest-complete.
const SUCCESS_GREEN      := Color(0.45, 0.95, 0.55)
# Quest active / in-progress (gold-y but cooler than headings).
const QUEST_ACTIVE       := Color(0.95, 0.85, 0.30)
# Faction tier-up / rep gain.
const REP_GAIN           := Color(0.55, 0.85, 0.40)
# Subtle separator / disabled state.
const DIM_GRAY           := Color(0.65, 0.65, 0.65)

# Panel backgrounds. Dark warm tone with high opacity so the world dims
# behind without being invisible.
const PANEL_BG_DARK      := Color(0.08, 0.06, 0.05, 0.95)
const PANEL_BG_DIM       := Color(0, 0, 0, 0.55)  # outer dim layer
const PANEL_BG_CARD      := Color(0.08, 0.06, 0.05, 0.92)  # inner cards
# Border default, neutral so factions/quests can override per-card.
const PANEL_BORDER       := Color(0.45, 0.40, 0.30)

# ─────── Font sizes ───────
# Pulled from the de facto values in pause_menu / faction_rep / quest_log.

const FONT_TITLE        := 24  # panel title (Paused, Reputation, etc)
const FONT_HEADING      := 22  # main heading (vendor name, class title)
const FONT_SUBHEAD      := 18  # section heading (Buy / Sell, tier name)
const FONT_BUTTON       := 16  # menu buttons
const FONT_BODY         := 14  # body text + tooltips
const FONT_ITEM_NAME    := 13  # row labels (item, quest, faction names)
const FONT_HINT         := 12  # subtitle / hint text below body
const FONT_TINY         := 11  # tertiary stats (rep numerics, etc)

# ─────── Layout ───────
# Standard panel paddings. Top/bottom slightly less than left/right so the
# panel looks horizontally generous without towering vertically.

const PANEL_MARGIN_X    := 24
const PANEL_MARGIN_Y    := 22
const PANEL_MARGIN_X_LG := 32  # used by pause menu (larger sense of weight)
const PANEL_MARGIN_Y_LG := 28

const VBOX_SEPARATION   := 12
const VBOX_SEPARATION_TIGHT := 6
const HBOX_SEPARATION   := 14

# ─────── Button sizes ───────

const BUTTON_SIZE_SMALL  := Vector2(80, 28)   # row actions (Buy / Sell)
const BUTTON_SIZE_MEDIUM := Vector2(120, 32)  # close / leave
const BUTTON_SIZE_TAB    := Vector2(120, 32)  # tab buttons
const BUTTON_SIZE_MENU   := Vector2(280, 44)  # pause menu / settings

# ─────── Card / panel sizes ───────

const CARD_INNER_WIDTH   := 680.0  # standard card content width
const CARD_INNER_HEIGHT  := 460.0  # standard scroll content height
const CONTENT_WIDTH      := 720.0  # standard panel content width
const CONTENT_HEIGHT     := 420.0  # standard panel scroll height

# ─────── Helpers ───────

# Build the canonical panel background StyleBoxFlat. Border color is
# overridable per-card. Corner radius and padding mirror the de facto
# styling found across panels before consolidation.
static func panel_box(border_color: Color = PANEL_BORDER, bg_color: Color = PANEL_BG_CARD) -> StyleBoxFlat:
	var bg := StyleBoxFlat.new()
	bg.bg_color = bg_color
	bg.border_color = border_color
	bg.border_width_left = 2
	bg.border_width_right = 1
	bg.border_width_top = 1
	bg.border_width_bottom = 1
	bg.corner_radius_top_left = 4
	bg.corner_radius_top_right = 4
	bg.corner_radius_bottom_left = 4
	bg.corner_radius_bottom_right = 4
	bg.content_margin_left = 14
	bg.content_margin_right = 14
	bg.content_margin_top = 12
	bg.content_margin_bottom = 12
	return bg

# Build a label with the canonical title styling. Saves four lines per
# panel (size, color, alignment, autowrap).
static func make_title(text: String) -> Label:
	var lab := Label.new()
	lab.text = text
	lab.add_theme_font_size_override("font_size", FONT_HEADING)
	lab.add_theme_color_override("font_color", HEADING_GOLD)
	lab.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	return lab

# Build a label with the canonical body styling.
static func make_body(text: String, autowrap: bool = true) -> Label:
	var lab := Label.new()
	lab.text = text
	lab.add_theme_font_size_override("font_size", FONT_BODY)
	lab.add_theme_color_override("font_color", BODY_CREAM)
	if autowrap:
		lab.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		lab.custom_minimum_size = Vector2(CONTENT_WIDTH, 0)
	return lab

# Build a label with the canonical hint styling (small, muted).
static func make_hint(text: String, autowrap: bool = true) -> Label:
	var lab := Label.new()
	lab.text = text
	lab.add_theme_font_size_override("font_size", FONT_HINT)
	lab.add_theme_color_override("font_color", HINT_BRONZE)
	if autowrap:
		lab.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		lab.custom_minimum_size = Vector2(CONTENT_WIDTH, 0)
	return lab

# Build a standard close-button row: title on the left, close button on
# the right. Returns the HBoxContainer so callers can add it to their vbox.
static func make_header_row(title_text: String, close_callable: Callable, close_text: String = "Close [Esc]") -> HBoxContainer:
	var row := HBoxContainer.new()
	row.add_child(make_title(title_text))
	var close_btn := Button.new()
	close_btn.text = close_text
	close_btn.custom_minimum_size = BUTTON_SIZE_MEDIUM
	close_btn.pressed.connect(close_callable)
	row.add_child(close_btn)
	return row
