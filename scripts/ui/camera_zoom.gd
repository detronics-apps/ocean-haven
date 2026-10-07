class_name CameraZoom
extends Control
## Zooming the view: five fixed steps, only with the + / − buttons on the left (or the + / -
## keys: zoom_in / zoom_out). Out to see more of the island on a big screen, in to see the
## ranger up close on a small one. No pinching, so a finger on the screen always walks.
## Applies to whichever camera is following (the ranger or a boat). Saved (`level`).

## The zoom steps (1 = normal, bigger = closer).
const LEVELS: Array[float] = [0.5, 0.7, 1.0, 1.4, 2.0]

## The zoom now.
static var level := 1.0


func _ready() -> void:
	name = "CameraZoom"
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var buttons := VBoxContainer.new()
	buttons.name = "Buttons"
	buttons.add_theme_constant_override("separation", 6)
	add_child(buttons)
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
	var at := _nearest_step()
	set_level(LEVELS[clampi(at + (1 if direction > 0.0 else -1), 0, LEVELS.size() - 1)])


## Snaps to the nearest of the steps (a save from before the steps keeps its closest one).
static func set_level(value: float) -> void:
	level = value
	level = LEVELS[_nearest_step()]


static func _nearest_step() -> int:
	var best := 0
	for i in LEVELS.size():
		if absf(LEVELS[i] - level) < absf(LEVELS[best] - level):
			best = i
	return best


func _process(_delta: float) -> void:
	var camera := get_viewport().get_camera_2d()
	if camera and not is_equal_approx(camera.zoom.x, level):
		camera.zoom = Vector2.ONE * level


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("zoom_in"):
		step(1.0)
	elif event.is_action_pressed("zoom_out"):
		step(-1.0)
