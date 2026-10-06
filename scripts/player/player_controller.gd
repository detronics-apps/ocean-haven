class_name Player
extends ControlledBody
## The ranger on foot. Hidden and paused while aboard the boat.

## The way the ranger last walked (the tile in front of them is used by the sand shovel).
var facing := Vector2i.DOWN

@onready var _camera: Camera2D = $Camera2D
@onready var _boots: Node2D = $Look/Boots
@onready var _boots_at: Vector2 = _boots.position
## Walking animation: steps a second, how high each step bobs, how far the body sways.
@export var steps_per_second := 4.0
@export var step_bob := 2.0
@export var step_sway := 0.06
var _step := 0.0
var walking := false


## Only ever on land or a deck: can't step off the end of a jetty into the sea.
func _physics_process(delta: float) -> void:
	var before := global_position
	super(delta)
	if not Terrain.walkable(get_tree(), global_position):
		global_position = before
	var moved := global_position - before
	_animate_walk(moved, delta)
	if moved.length() > 0.5:
		if absf(moved.x) >= absf(moved.y):
			facing = Vector2i.RIGHT if moved.x > 0.0 else Vector2i.LEFT
		else:
			facing = Vector2i.DOWN if moved.y > 0.0 else Vector2i.UP


## While walking the ranger bobs with each step, sways a little, the boots step back and
## forth, and they face the way they're going; standing still, they settle back.
func _animate_walk(moved: Vector2, delta: float) -> void:
	walking = moved.length() > 0.3
	if walking:
		_step += delta * steps_per_second * TAU / 2.0
		if absf(moved.x) > 0.3:
			_look.scale.x = -1.0 if moved.x < 0.0 else 1.0
		_look.position.y = -absf(sin(_step)) * step_bob
		_look.rotation = sin(_step) * step_sway
		_boots.position = _boots_at + Vector2(roundf(sin(_step) * 1.5), 0)
	else:
		_step = 0.0
		_look.position.y = move_toward(_look.position.y, 0.0, delta * 20.0)
		_look.rotation = move_toward(_look.rotation, 0.0, delta * 2.0)
		_boots.position = _boots_at


func set_aboard(aboard: bool) -> void:
	stop()
	controlled = not aboard
	visible = not aboard
	process_mode = PROCESS_MODE_DISABLED if aboard else PROCESS_MODE_INHERIT
	if not aboard:
		ControlledBody.switch_camera(_camera)
