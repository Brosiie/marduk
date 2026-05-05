extends Control
class_name DonationPrompt

# Polite, dismissible prompt asking for a $1 donation. Marduk is free and open source;
# this prompt fires once per "first login per day" via SaveFlags last-shown-at timestamp.
# Always skippable. Never blocks gameplay.

signal donate_clicked
signal dismissed

const DONATION_URL := "https://ko-fi.com/marduk_game"  # placeholder; swap for real link
const MIN_INTERVAL_SECONDS := 86400  # show at most once per 24h
const SHOWN_FLAG := &"donation_prompt_last_shown_unix"

@onready var donate_btn: Button = $Panel/Margin/VBox/Buttons/DonateButton if has_node("Panel/Margin/VBox/Buttons/DonateButton") else null
@onready var skip_btn: Button = $Panel/Margin/VBox/Buttons/SkipButton if has_node("Panel/Margin/VBox/Buttons/SkipButton") else null
@onready var never_btn: Button = $Panel/Margin/VBox/Buttons/NeverButton if has_node("Panel/Margin/VBox/Buttons/NeverButton") else null

func _ready() -> void:
	if donate_btn: donate_btn.pressed.connect(_on_donate)
	if skip_btn: skip_btn.pressed.connect(_on_skip)
	if never_btn: never_btn.pressed.connect(_on_never)
	visible = false

# Returns true if shown; false if suppressed by interval or "never" flag.
func maybe_show() -> bool:
	if SaveFlags.has_permanent(&"donation_never_show"):
		return false
	var now := int(Time.get_unix_time_from_system())
	var last_shown := int(SaveFlags.get_permanent(SHOWN_FLAG, 0))
	if now - last_shown < MIN_INTERVAL_SECONDS:
		return false
	SaveFlags.set_permanent(SHOWN_FLAG, now)
	visible = true
	return true

func _on_donate() -> void:
	OS.shell_open(DONATION_URL)
	donate_clicked.emit()
	visible = false

func _on_skip() -> void:
	dismissed.emit()
	visible = false

func _on_never() -> void:
	SaveFlags.set_permanent(&"donation_never_show", true)
	dismissed.emit()
	visible = false
