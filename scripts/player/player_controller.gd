class_name Player
extends ControlledBody
## The ranger on foot. Hidden and paused while aboard the boat.

## The way the ranger last walked (the tile in front of them is used by the sand shovel).
var facing := Vector2i.DOWN

@onready var _camera: Camera2D = $Camera2D
@onready var _avatar: Avatar = $Look
@onready var _boots: Node2D = $Look/Boots
@onready var _boots_at: Vector2 = _boots.position
## Walking animation: steps a second, how high each step bobs, how far the body sways.
@export var steps_per_second := 4.0
@export var step_bob := 2.0
@export var step_sway := 0.06
var _step := 0.0
var walking := false
## A little hop going up or down a step of the ground (TerrainEdges heights) at least
## `hop_from` px tall: how high and how long. Looks only: speed and paths don't change.
## Going down it's a quick little drop (the owner: a full hop down floated too long).
@export var hop_from := 5
@export var hop_height := 4.0
@export var hop_time := 0.25
@export var drop_height := 2.0
@export var drop_time := 0.14
var _ground_level := -1
var _hop := 1.0
var _hop_up := true
## The walking bob, kept apart from the hop (a hop added to it as it settled stacked up: too high)
var _bob := 0.0


func _ready() -> void:
	Shadow.under(self, null, 22.0, Vector2(0, -2))  # (round the boots: lower, they seemed to float)

## Only ever on land or a deck: can't step off the end of a jetty into the sea.
func _physics_process(delta: float) -> void:
	var before := global_position
	super(delta)
	if not Terrain.walkable(get_tree(), global_position):
		global_position = before
	var moved := global_position - before
	var level := TerrainEdges.height_at(get_tree(), global_position)
	if _ground_level >= 0 and absi(level - _ground_level) >= hop_from:
		_hop = 0.0
		_hop_up = level > _ground_level
	_ground_level = level
	_animate_walk(moved, delta)
	var lift := 0.0
	if _hop < 1.0:
		_hop = minf(_hop + delta / (hop_time if _hop_up else drop_time), 1.0)
		lift = sin(_hop * PI) * (hop_height if _hop_up else drop_height)
	_look.position.y = _bob - lift
	if moved.length() > 0.5:
		if absf(moved.x) >= absf(moved.y):
			facing = Vector2i.RIGHT if moved.x > 0.0 else Vector2i.LEFT
		else:
			facing = Vector2i.DOWN if moved.y > 0.0 else Vector2i.UP
		_turn()


## While walking the ranger bobs with each step, sways a little, the boots step back and
## forth, and they face the way they're going; standing still, they settle back.
func _animate_walk(moved: Vector2, delta: float) -> void:
	walking = moved.length() > 0.3
	if walking:
		_step += delta * steps_per_second * TAU / 2.0
		if absf(moved.x) > 0.3:
			_look.scale.x = -1.0 if moved.x < 0.0 else 1.0
		_bob = -absf(sin(_step)) * step_bob
		_look.rotation = sin(_step) * step_sway
		if _avatar.view == Avatar.View.SIDE or _avatar.view == Avatar.View.STEP:
			var stride := Avatar.View.STEP if sin(_step) > 0.0 else Avatar.View.SIDE  # (a stride, then together)
			if stride != _avatar.view:
				_avatar.set_view(stride)
		else:
			_boots.position = _boots_at + Vector2(roundf(sin(_step) * 1.5), 0)
	else:
		_step = 0.0
		_bob = move_toward(_bob, 0.0, delta * 20.0)
		_look.rotation = move_toward(_look.rotation, 0.0, delta * 2.0)
		_boots.position = _boots_at
		if _avatar.view == Avatar.View.STEP:
			_avatar.set_view(Avatar.View.SIDE)


func set_aboard(aboard: bool) -> void:
	stop()
	_ground_level = -1  # (no hop for stepping ashore)
	controlled = not aboard
	visible = not aboard
	process_mode = PROCESS_MODE_DISABLED if aboard else PROCESS_MODE_INHERIT
	if not aboard:
		ControlledBody.switch_camera(_camera)


## Seen the way they're walking: from the side (flipped for left), the back going up, the
## front coming down. Standing still, they stay turned that way.
func _turn() -> void:
	var view := Avatar.View.BACK if facing == Vector2i.UP else Avatar.View.SIDE if facing.x != 0 else Avatar.View.FRONT
	var turned := _avatar.view == Avatar.View.SIDE or _avatar.view == Avatar.View.STEP
	if view != _avatar.view and not (view == Avatar.View.SIDE and turned):
		_avatar.set_view(view)
