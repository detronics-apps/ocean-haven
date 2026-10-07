class_name ControlledBody
extends CharacterBody2D
## Something the player steers (the ranger on foot, the boat): move_* actions
## (keyboard / controller) or tap/click a spot to head there.

@export var speed: float = 110.0
## The ranger's water supply: clean water bottles stored at their tent or house. While any
## are left, the ranger moves faster, on foot and in the boat; each bottle lasts half a day, so
## the supply drops by 2 a day (kept as the GameClock.now() when it runs dry).
static var water_until := -1.0
const BOTTLE_DAYS := 0.5
## The water bar is full at this many bottles.
const FULL_BOTTLES := 10.0
const WATER_SPEED := 1.3


## Bottles of clean water left at home (part of one counts as one). (The clock is looked up at
## runtime: tests compile this without autoloads.)
static func water_bottles(tree: SceneTree) -> int:
	var clock := tree.root.get_node_or_null("GameClock")
	return maxi(ceili((water_until - clock.now()) / BOTTLE_DAYS - 0.001), 0) if clock else 0


## How full the water bar is, 0..1 (FULL_BOTTLES or more: full).
static func water_level(tree: SceneTree) -> float:
	var clock := tree.root.get_node_or_null("GameClock")
	return clampf((water_until - clock.now()) / (BOTTLE_DAYS * FULL_BOTTLES), 0.0, 1.0) if clock else 0.0


## Stores `bottles` of clean water at home: half a day of water each.
static func store_water(tree: SceneTree, bottles: int) -> void:
	var clock := tree.root.get_node_or_null("GameClock")
	if clock:
		water_until = maxf(water_until, clock.now()) + bottles * BOTTLE_DAYS


## Hands the view over to `camera` (boarding / going ashore) without a jump: it starts where
## the old view was and glides to its own spot.
static func switch_camera(camera: Camera2D, glide := 0.3) -> void:
	var old := camera.get_viewport().get_camera_2d()
	var from := old.get_screen_center_position() if old and old.is_inside_tree() else camera.global_position
	camera.make_current()
	camera.reset_smoothing()
	camera.offset = from - camera.global_position
	if camera.offset.length() < 0.5 or not camera.is_inside_tree():
		camera.offset = Vector2.ZERO
		return
	camera.create_tween().tween_property(camera, "offset", Vector2.ZERO, glide) \
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)


## Only the body the player is currently steering responds to input.
@export var controlled := true

var _target: Vector2
var _has_target := false
## The finger (or mouse button) is still down after a tap on the world: follow it.
var _holding := false

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
	# Touch taps arrive as mouse clicks (emulate_mouse_from_touch is on by default). A tap walks
	# all the way there; holding the finger down, the ranger follows it.
	if controlled and is_tap(event):
		_target = get_global_mouse_position()
		_has_target = true
		_holding = true


func _input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and not event.pressed:
		_holding = false  # let go: keep walking to where the finger last was


func _physics_process(_delta: float) -> void:
	if not controlled:
		return
	var dir := Input.get_vector("move_left", "move_right", "move_up", "move_down")
	if _holding and dir == Vector2.ZERO:
		_target = get_global_mouse_position()
		_has_target = true
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
	_holding = false
	velocity = Vector2.ZERO


static func is_tap(event: InputEvent) -> bool:
	return event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT
