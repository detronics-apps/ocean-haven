class_name CameraZoom
extends Control
## Zooming the view in and out: pinch with two fingers, the mouse wheel, + / - keys
## (zoom_in / zoom_out actions) or the little + / − buttons. Out to see more of the island on a
## big screen, in to see the ranger up close on a small one. Applies to whichever camera is
## following (the ranger or a boat). Saved (`level`).

const MIN := 0.5
const MAX := 2.0
const STEP := 1.2

## The zoom now (1 = normal, bigger = closer).
static var level := 1.0

## Touch index -> screen position, for pinching.
var _touches := {}
var _pinch_from := 0.0
var _pinch_level := 1.0


func _ready() -> void:
	name = "CameraZoom"
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var buttons := VBoxContainer.new()
	buttons.name = "Buttons"
	buttons.add_theme_constant_override("separation", 6)
	add_child(buttons)
	buttons.set_anchors_and_offsets_preset(Control.PRESET_CENTER_LEFT, Control.PRESET_MODE_MINSIZE, 8)
	for sign: float in [1.0, -1.0]:
		var button := Button.new()
		button.name = "ZoomIn" if sign > 0.0 else "ZoomOut"
		button.text = "+" if sign > 0.0 else "−"
		button.focus_mode = Control.FOCUS_NONE
		button.custom_minimum_size = Vector2(44, 44)
		button.add_theme_font_size_override("font_size", 24)
		button.modulate = Color(1, 1, 1, 0.75)
		button.pressed.connect(step.bind(sign))
		buttons.add_child(button)
	buttons.reset_size()
	buttons.set_anchors_and_offsets_preset(Control.PRESET_CENTER_LEFT, Control.PRESET_MODE_MINSIZE, 8)


## One step closer (+1) or further out (-1).
static func step(direction: float) -> void:
	set_level(level * (STEP if direction > 0.0 else 1.0 / STEP))


static func set_level(value: float) -> void:
	level = clampf(value, MIN, MAX)


func _process(_delta: float) -> void:
	var camera := get_viewport().get_camera_2d()
	if camera and not is_equal_approx(camera.zoom.x, level):
		camera.zoom = Vector2.ONE * level


func _input(event: InputEvent) -> void:
	if not is_visible_in_tree():
		return
	if event.is_action_pressed("zoom_in"):
		step(1.0)
	elif event.is_action_pressed("zoom_out"):
		step(-1.0)
	elif event is InputEventMouseButton and event.pressed and event.button_index in [MOUSE_BUTTON_WHEEL_UP, MOUSE_BUTTON_WHEEL_DOWN]:
		step(1.0 if event.button_index == MOUSE_BUTTON_WHEEL_UP else -1.0)
	elif event is InputEventMagnifyGesture:
		set_level(level * event.factor)
	elif event is InputEventScreenTouch:
		if event.pressed:
			_touches[event.index] = event.position
		else:
			_touches.erase(event.index)
		_start_pinch()
	elif event is InputEventScreenDrag and _touches.has(event.index):
		_touches[event.index] = event.position
		if _touches.size() == 2 and _pinch_from > 0.0:
			var points: Array = _touches.values()
			set_level(_pinch_level * (points[0] as Vector2).distance_to(points[1]) / _pinch_from)
			get_viewport().set_input_as_handled()


func _start_pinch() -> void:
	_pinch_from = 0.0
	if _touches.size() == 2:
		var points: Array = _touches.values()
		_pinch_from = maxf((points[0] as Vector2).distance_to(points[1]), 1.0)
		_pinch_level = level
		var ranger := ControlledBody.active(get_tree())
		if ranger:
			ranger.stop()  # the first finger's tap isn't a walk
