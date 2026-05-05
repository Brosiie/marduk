extends Control

# Options / pause menu. Resume, save, return to start menu, quit.
# Settings (auto-loot, sensitivity, audio) read/write GameSettings autoload.

var _player: Node = null

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_PASS
	_player = get_tree().get_first_node_in_group("player")

	var title := Label.new()
	title.text = "Options & Pause"
	title.add_theme_font_size_override("font_size", 22)
	add_child(title)

	var v := VBoxContainer.new()
	v.anchor_left = 0.5
	v.anchor_top = 0.5
	v.anchor_right = 0.5
	v.anchor_bottom = 0.5
	v.offset_left = -160.0
	v.offset_top = -200.0
	v.offset_right = 160.0
	v.offset_bottom = 200.0
	v.add_theme_constant_override("separation", 12)
	add_child(v)

	v.add_child(_section("Settings"))
	v.add_child(_settings_row("Auto-loot", "auto_loot"))
	v.add_child(_settings_row("Mouse sensitivity", "mouse_sensitivity"))
	v.add_child(_settings_row("Master volume", "master_volume"))
	v.add_child(_settings_row("SFX volume", "sfx_volume"))

	v.add_child(_section("Save"))
	var save_btn := Button.new()
	save_btn.text = "Save Game"
	save_btn.pressed.connect(_on_save)
	v.add_child(save_btn)

	v.add_child(_section("Navigation"))
	var resume := Button.new()
	resume.text = "Resume"
	resume.pressed.connect(_on_resume)
	v.add_child(resume)
	var menu := Button.new()
	menu.text = "Return to Main Menu"
	menu.pressed.connect(_on_main_menu)
	v.add_child(menu)
	var quit := Button.new()
	quit.text = "Quit Game"
	quit.pressed.connect(_on_quit)
	v.add_child(quit)

func refresh() -> void:
	pass

func _section(t: String) -> Label:
	var l := Label.new()
	l.text = t
	l.modulate = Color(0.95, 0.85, 0.30)
	l.add_theme_font_size_override("font_size", 14)
	return l

func _settings_row(label_text: String, key: String) -> Control:
	var row := HBoxContainer.new()
	var lbl := Label.new()
	lbl.text = label_text
	lbl.custom_minimum_size = Vector2(160, 0)
	row.add_child(lbl)

	var settings: Node = get_node_or_null("/root/GameSettings")
	var current: Variant = null
	if settings and settings.has_method("get_value"):
		current = settings.get_value(key)

	if key == "auto_loot":
		var cb := CheckBox.new()
		cb.button_pressed = bool(current) if current != null else false
		cb.toggled.connect(_on_setting_changed.bind(key))
		row.add_child(cb)
	else:
		var slider := HSlider.new()
		slider.min_value = 0.0
		slider.max_value = 1.0
		slider.step = 0.01
		slider.custom_minimum_size = Vector2(200, 18)
		slider.value = float(current) if current != null else 0.7
		slider.value_changed.connect(_on_setting_changed.bind(key))
		row.add_child(slider)
	return row

func _on_setting_changed(value: Variant, key: String) -> void:
	var settings: Node = get_node_or_null("/root/GameSettings")
	if settings and settings.has_method("set_value"):
		settings.set_value(key, value)

func _on_save() -> void:
	var save_sys: Node = get_node_or_null("/root/SaveSystem")
	if save_sys and save_sys.has_method("save_game"):
		save_sys.save_game()

func _on_resume() -> void:
	var menu := get_parent().get_parent().get_parent()  # MenuPanel
	while menu and not menu.has_method("close"):
		menu = menu.get_parent()
	if menu:
		menu.close()

func _on_main_menu() -> void:
	if ResourceLoader.exists("res://scenes/world/start_menu.tscn"):
		get_tree().change_scene_to_file("res://scenes/world/start_menu.tscn")
	elif ResourceLoader.exists("res://scenes/start.tscn"):
		get_tree().change_scene_to_file("res://scenes/start.tscn")

func _on_quit() -> void:
	get_tree().quit()
