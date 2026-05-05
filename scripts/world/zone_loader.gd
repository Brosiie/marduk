extends Node
class_name ZoneLoader

# Handles zone transitions: warning prompt if under-leveled, lock-check via SaveFlags,
# loading screen during scene swap, spawn-point placement at destination.
#
# Use as a child of the Main scene or instantiate on demand. Connect to UI for warnings.
#
# Flow:
#   request_travel(zone_id, on_confirm) ->
#     check_lock -> show error or proceed
#     check_level -> if under, show warning -> player confirms or cancels
#     load_scene -> show loading screen -> swap scene -> position player

signal travel_requested(zone: Zone)
signal travel_blocked(zone: Zone, reason: String)
signal level_warning(zone: Zone, player_level: int)
signal travel_started(zone: Zone)
signal travel_completed(zone: Zone)
signal travel_progress(percent: float)  # 0.0 - 1.0

var current_zone: Zone

func request_travel(zone_id: StringName, player) -> void:
	var zone := WorldMap.get_zone(zone_id)
	if not zone:
		push_error("ZoneLoader: unknown zone %s" % zone_id)
		return

	# Lock checks first (permanent or run gating)
	var entry: Dictionary = WorldMap.can_player_enter(zone)
	if not entry["ok"]:
		travel_blocked.emit(zone, entry["reason"])
		return

	# Level check (non-blocking, just warns)
	if player and player.stats and zone.is_under_leveled(player.stats.level):
		level_warning.emit(zone, player.stats.level)
		# Caller decides whether to call confirm_travel(zone_id, player)
		return

	confirm_travel(zone_id, player)

func confirm_travel(zone_id: StringName, player) -> void:
	var zone := WorldMap.get_zone(zone_id)
	if not zone:
		return
	travel_started.emit(zone)
	_load_scene(zone, player)

func _load_scene(zone: Zone, player) -> void:
	# Threaded load so the loading screen can animate.
	var err := ResourceLoader.load_threaded_request(zone.scene_path, "PackedScene")
	if err != OK:
		push_warning("ZoneLoader: failed to start threaded load for %s: %s" % [zone.scene_path, err])
		_swap_immediate(zone, player)
		return
	_poll_load(zone, player)

func _poll_load(zone: Zone, player) -> void:
	var status := ResourceLoader.load_threaded_get_status(zone.scene_path)
	match status:
		ResourceLoader.THREAD_LOAD_LOADED:
			var scene: PackedScene = ResourceLoader.load_threaded_get(zone.scene_path)
			_perform_swap(zone, scene, player)
		ResourceLoader.THREAD_LOAD_IN_PROGRESS:
			var progress: Array = []
			ResourceLoader.load_threaded_get_status(zone.scene_path, progress)
			if progress.size() > 0:
				travel_progress.emit(float(progress[0]))
			get_tree().create_timer(0.05).timeout.connect(_poll_load.bind(zone, player))
		ResourceLoader.THREAD_LOAD_FAILED, ResourceLoader.THREAD_LOAD_INVALID_RESOURCE:
			push_warning("ZoneLoader: threaded load failed for %s" % zone.scene_path)
			_swap_immediate(zone, player)

func _swap_immediate(zone: Zone, player) -> void:
	var scene := load(zone.scene_path) as PackedScene
	if scene:
		_perform_swap(zone, scene, player)
	else:
		push_error("ZoneLoader: scene missing at %s" % zone.scene_path)

func _perform_swap(zone: Zone, scene: PackedScene, player) -> void:
	var tree := get_tree()
	var new_root := scene.instantiate()
	tree.root.add_child(new_root)

	# Move player into new scene if it expects one
	if player and is_instance_valid(player) and new_root.has_node("PlayerSpawn"):
		var spawn: Node3D = new_root.get_node("PlayerSpawn")
		var old_parent := player.get_parent()
		if old_parent:
			old_parent.remove_child(player)
		new_root.add_child(player)
		player.global_position = spawn.global_position

	# Free the previous main scene if any
	var old_main := tree.current_scene
	if old_main and old_main != new_root:
		old_main.queue_free()
	tree.current_scene = new_root

	current_zone = zone
	travel_completed.emit(zone)
