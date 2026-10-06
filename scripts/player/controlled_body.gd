class_name ControlledBody
extends CharacterBody2D
## Something the player steers (the ranger on foot, the boat): move_* actions
## (keyboard / controller) or tap/click a spot to head there.

@export var speed: float = 110.0
## The ranger's water: clean water drunk at their tent or house fills it up, and it runs out
## over WATER_DAYS (GameClock.now() when it's empty). While there's water in it, the ranger
## moves faster, on foot and in the boat.
static var water_until := -1.0
const WATER_DAYS := 2.0
const WATER_SPEED := 1.3


## How full the ranger's water is, 0..1. (The clock is looked up at runtime: tests compile
## this without autoloads.)
static func water_level(tree: SceneTree) -> float:
	var clock := tree.root.get_node_or_null("GameClock")
	return clampf((water_until - clock.now()) / WATER_DAYS, 0.0, 1.0) if clock else 0.0


## Drinks clean water: the ranger's water is full again.
static func fill_water(tree: SceneTree) -> void:
	var clock := tree.root.get_node_or_null("GameClock")
	if clock:
		water_until = clock.now() + WATER_DAYS
## Only the body the player is currently steering responds to input.
@export var controlled := true

var _target: Vector2
var _has_target := false

@onready var _look: Node2D = get_node_or_null("Look")


## The body the player is steering right now (the ranger or the boat), or null.
static func active(tree: SceneTree) -> ControlledBody:
	for body: ControlledBody in tree.get_nodes_in_group("controllable"):
		if body.controlled:
			return body
	return null


func _enter_tree() -> void:
	add_to_group("controllable")


func _unhandled_input(event: InputEvent) -> void:
	# Touch taps arrive as mouse clicks (emulate_mouse_from_touch is on by default).
	if controlled and is_tap(event):
		_target = get_global_mouse_position()
		_has_target = true


func _physics_process(_delta: float) -> void:
	if not controlled:
		return
	var dir := Input.get_vector("move_left", "move_right", "move_up", "move_down")
	if dir != Vector2.ZERO:
		_has_target = false
	elif _has_target:
		var to_target := _target - global_position
		if to_target.length() < 2.0:
			_has_target = false
		else:
			dir = to_target.normalized()

	velocity = dir * speed * (WATER_SPEED if water_level(get_tree()) > 0.0 else 1.0)
	move_and_slide()

	# Tapped somewhere unreachable: stop instead of pushing against the shore forever.
	if _has_target and get_real_velocity().length() < 1.0:
		_has_target = false
	if _look and dir.x != 0.0:
		_look.scale.x = signf(dir.x)


func stop() -> void:
	_has_target = false
	velocity = Vector2.ZERO


static func is_tap(event: InputEvent) -> bool:
	return event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT
