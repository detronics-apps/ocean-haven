class_name Player
extends CharacterBody2D
## Walks with keyboard / controller (move_* actions) or by tapping/clicking a spot.

@export var speed: float = 110.0

var _target: Vector2
var _has_target := false

@onready var _look: Node2D = $Look


func _unhandled_input(event: InputEvent) -> void:
	# Touch taps arrive as mouse clicks (emulate_mouse_from_touch is on by default).
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		_target = get_global_mouse_position()
		_has_target = true


func _physics_process(_delta: float) -> void:
	var dir := Input.get_vector("move_left", "move_right", "move_up", "move_down")
	if dir != Vector2.ZERO:
		_has_target = false
	elif _has_target:
		var to_target := _target - global_position
		if to_target.length() < 2.0:
			_has_target = false
		else:
			dir = to_target.normalized()

	velocity = dir * speed
	move_and_slide()

	# Tapped into the sea: stop instead of pushing against the shore forever.
	if _has_target and get_real_velocity().length() < 1.0:
		_has_target = false
	if dir.x != 0.0:
		_look.scale.x = signf(dir.x)
