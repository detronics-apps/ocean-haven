class_name Animal
extends CharacterBody2D
## A sea animal that lives around a home spot: swims to random places in the
## water and rests. It reacts to *how* the ranger approaches: rushing at it makes
## it swim off; staying still nearby lets it relax (curious ones come closer).
## Once relaxed, the ranger can quietly observe it, photograph it, or free it if
## it's tangled in fishing line. Never touching, chasing or feeding.
## Species details come from `data` (an AnimalData .tres).

enum State { REST, SWIM, FLEE, CURIOUS }

## How long a startled animal swims away before settling.
const FLEE_SECONDS := 2.0
## A ranger "moving" further than this in one frame jumped (boarding, loading) — not rushing.
const JUMP_DISTANCE := 64.0

@export var data: AnimalData
## How far from its home spot it wanders.
@export var home_radius := 140.0
## Tangled in fishing line: swims slowly until the ranger frees it.
@export var tangled := false
## Added to the inventory when the ranger frees it (the line is litter too).
@export var tangle_item: ItemData

var _state := State.REST
var _target: Vector2
var _rest_left := 0.0
var _flee_left := 0.0
## Seconds the ranger has stayed calm nearby, and has watched it while relaxed.
var _calm := 0.0
var _watched := 0.0
var _last_ranger_pos := Vector2.INF

@onready var _home := global_position
@onready var _sprite: Sprite2D = $Sprite2D
@onready var _tangle: Sprite2D = $Sprite2D/Tangle
@onready var _hint: Label = $Hint


func _enter_tree() -> void:
	add_to_group("animals")


func _ready() -> void:
	_sprite.texture = data.sprite
	_tangle.visible = tangled
	_rest_left = randf_range(0.0, data.rest_max)


func is_relaxed() -> bool:
	return _calm >= data.calm_time


## Frees it without the reward (loading a save where it was already freed).
func restore_freed() -> void:
	tangled = false
	_tangle.visible = false


func _physics_process(delta: float) -> void:
	_react_to_ranger(delta)

	var speed := data.swim_speed * (0.5 if tangled else 1.0)
	match _state:
		State.REST:
			velocity = Vector2.ZERO
			_rest_left -= delta
			if _rest_left <= 0.0:
				_swim_to(_pick_target(), State.SWIM)
			return
		State.FLEE:
			speed *= 2.0
			_flee_left -= delta
			if _flee_left <= 0.0:
				_rest(data.rest_min)
				return
		State.CURIOUS:
			speed *= 0.6

	var to_target := _target - global_position
	if to_target.length() < 4.0:
		_rest(randf_range(data.rest_min, data.rest_max))
		return
	velocity = to_target.normalized() * speed
	move_and_slide()
	_sprite.rotation = lerp_angle(_sprite.rotation, velocity.angle(), 0.1)
	# Blocked by land (e.g. fled towards the beach): rest, then pick somewhere else.
	if get_real_velocity().length() < 1.0:
		_rest(data.rest_min)


func _react_to_ranger(delta: float) -> void:
	_hint.visible = false
	var ranger := ControlledBody.active(get_tree())
	if not ranger:
		return
	var pos := ranger.global_position
	var moved := pos.distance_to(_last_ranger_pos)
	_last_ranger_pos = pos
	var ranger_speed := 0.0 if moved > JUMP_DISTANCE else moved / delta
	var distance := global_position.distance_to(pos)
	if distance > data.discover_distance:
		_calm = 0.0
		_watched = 0.0
		return
	Journal.discover(data)

	if ranger_speed > data.calm_speed:
		_calm = 0.0
		if distance < data.shy_distance and _state != State.FLEE:
			_state = State.FLEE
			_flee_left = FLEE_SECONDS
			_target = global_position + pos.direction_to(global_position) * 96.0
	else:
		_calm += delta

	if is_relaxed() and _state != State.FLEE:
		if data.curious and distance > 48.0 and _state != State.CURIOUS:
			_swim_to(pos + pos.direction_to(global_position) * 36.0, State.CURIOUS)
		if distance <= data.interact_distance:
			_watched += delta
			if _watched >= data.observe_time:
				Journal.observe(data)

	if distance <= data.interact_distance:
		_hint.visible = true
		if not is_relaxed():
			_hint.text = "Stay still so it can relax..."
		elif tangled:
			_hint.text = "E / tap: free the %s" % data.display_name.to_lower()
		else:
			_hint.text = "E / tap: take a photo"


func _input(event: InputEvent) -> void:
	# _input (not _unhandled_input) so helping an animal wins over boarding/walking.
	if not (_hint.visible and is_relaxed()):
		return
	var tapped := ControlledBody.is_tap(event) and get_global_mouse_position().distance_to(global_position) < 24.0
	if tapped or event.is_action_pressed("interact"):
		get_viewport().set_input_as_handled()
		_interact()


func _interact() -> void:
	if tangled:
		restore_freed()
		if tangle_item:
			Inventory.add(tangle_item)
		SaveGame.mark_freed(self)
		Journal.help(data)
	else:
		Journal.photograph(data)


func _swim_to(target: Vector2, state: State) -> void:
	_target = target
	_state = state


func _rest(seconds: float) -> void:
	_state = State.REST
	_rest_left = seconds


## A random spot in the water within home_radius of home.
func _pick_target() -> Vector2:
	for attempt in 20:
		var spot := _home + Vector2.from_angle(randf() * TAU) * randf() * home_radius
		if not _is_land(spot):
			return spot
	return _home


func _is_land(point: Vector2) -> bool:
	for ground: TileMapLayer in get_tree().get_nodes_in_group("ground"):
		var tile := ground.get_cell_tile_data(ground.local_to_map(ground.to_local(point)))
		if tile and tile.get_custom_data("walkable"):
			return true
	return false
