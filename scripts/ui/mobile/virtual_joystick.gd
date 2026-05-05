extends Control
class_name VirtualJoystick

# Touch joystick. Renders a fixed circle with a draggable inner thumb.
# Outputs normalized direction vector via `direction` property and emits
# input synthesized events mapped to move_up / move_down / move_left / move_right.

@export var radius: float = 100.0
@export var deadzone: float = 0.2
@export var background_color: Color = Color(0.1, 0.1, 0.15, 0.5)
@export var thumb_color: Color = Color(0.85, 0.7, 0.4, 0.8)

var direction: Vector2 = Vector2.ZERO
var _active_touch: int = -1
var _thumb_offset: Vector2 = Vector2.ZERO

func _ready() -> void:
	custom_minimum_size = Vector2(radius * 2.0, radius * 2.0)

func _draw() -> void:
	var center := size / 2.0
	draw_circle(center, radius, background_color)
	draw_arc(center, radius, 0.0, TAU, 32, Color(0.85, 0.7, 0.4, 0.8), 2.0, true)
	draw_circle(center + _thumb_offset, radius * 0.3, thumb_color)

func _input(event: InputEvent) -> void:
	if event is InputEventScreenTouch:
		var local: Vector2 = event.position - global_position
		if event.pressed and _active_touch == -1 and _is_within(local):
			_active_touch = event.index
			_update_thumb(local)
			accept_event()
		elif not event.pressed and event.index == _active_touch:
			_active_touch = -1
			_thumb_offset = Vector2.ZERO
			direction = Vector2.ZERO
			_emit_movement()
			queue_redraw()
			accept_event()
	elif event is InputEventScreenDrag and event.index == _active_touch:
		var local: Vector2 = event.position - global_position
		_update_thumb(local)
		accept_event()

func _is_within(local: Vector2) -> bool:
	return local.distance_to(size / 2.0) <= radius * 1.5

func _update_thumb(local: Vector2) -> void:
	var center := size / 2.0
	var diff: Vector2 = local - center
	if diff.length() > radius:
		diff = diff.normalized() * radius
	_thumb_offset = diff
	direction = diff / radius
	if direction.length() < deadzone:
		direction = Vector2.ZERO
	_emit_movement()
	queue_redraw()

func _emit_movement() -> void:
	# Synthesize InputEventActions so existing player movement code reacts.
	for action in [&"move_up", &"move_down", &"move_left", &"move_right"]:
		var ev := InputEventAction.new()
		ev.action = action
		ev.strength = 0.0
		ev.pressed = false
		Input.parse_input_event(ev)
	if direction == Vector2.ZERO:
		return
	if direction.x > 0:
		_emit_action(&"move_right", direction.x)
	if direction.x < 0:
		_emit_action(&"move_left", -direction.x)
	if direction.y > 0:
		_emit_action(&"move_down", direction.y)
	if direction.y < 0:
		_emit_action(&"move_up", -direction.y)

func _emit_action(action: StringName, strength: float) -> void:
	var ev := InputEventAction.new()
	ev.action = action
	ev.strength = strength
	ev.pressed = true
	Input.parse_input_event(ev)
