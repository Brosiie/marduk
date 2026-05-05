extends Control
class_name StartMenu

# Title screen for Marduk. Buttons: New Character, Continue (if save exists),
# Settings, Credits, Quit. New Character routes to CharacterCreation, which
# routes to the chosen class's intro zone.

@onready var new_btn: Button = $Centered/Buttons/NewButton if has_node("Centered/Buttons/NewButton") else null
@onready var continue_btn: Button = $Centered/Buttons/ContinueButton if has_node("Centered/Buttons/ContinueButton") else null
@onready var settings_btn: Button = $Centered/Buttons/SettingsButton if has_node("Centered/Buttons/SettingsButton") else null
@onready var credits_btn: Button = $Centered/Buttons/CreditsButton if has_node("Centered/Buttons/CreditsButton") else null
@onready var quit_btn: Button = $Centered/Buttons/QuitButton if has_node("Centered/Buttons/QuitButton") else null

func _ready() -> void:
	if new_btn: new_btn.pressed.connect(_on_new)
	if continue_btn:
		continue_btn.pressed.connect(_on_continue)
		continue_btn.disabled = not _has_existing_save()
	if settings_btn: settings_btn.pressed.connect(_on_settings)
	if credits_btn: credits_btn.pressed.connect(_on_credits)
	if quit_btn: quit_btn.pressed.connect(_on_quit)

func _has_existing_save() -> bool:
	return SaveSystem and SaveSystem.list_slots().any(func(s): return not s.get("empty", true))

func _on_new() -> void:
	get_tree().change_scene_to_file("res://scenes/menus/character_creation.tscn")

func _on_continue() -> void:
	# Phase 2: route to slot-pick screen, then load slot, then jump into the saved zone
	get_tree().change_scene_to_file("res://scenes/world/intros/sword_vow_ruins.tscn")

func _on_settings() -> void:
	# Phase 2: open Settings menu inline as a child overlay
	pass

func _on_credits() -> void:
	pass

func _on_quit() -> void:
	get_tree().quit()
