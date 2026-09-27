class_name Animal
extends CharacterBody2D
## A sea animal that lives around a home spot: swims to a random place in the
## water, rests, repeats. Shy: swims away when the ranger gets close.
## Species details come from `data` (an AnimalData .tres).

enum State { REST, SWIM }

@export var data: AnimalData
## How far from its home spot it wanders.
@export var home_radius := 140.0

var _state := State.REST
var _target: Vector2
var _rest_left := 0.0

@onready var _home := global_position
@onready var _sprite: Sprite2D = $Sprite2D


func _ready() -> void:
	_sprite.texture = data.sprite
	_rest_left = randf_range(0.0, data.rest_max)


func _physics_process(delta: float) -> void:
	var speed := data.swim_speed
	var ranger := ControlledBody.active(get_tree())
	if ranger:
		var distance := global_position.distance_to(ranger.global_position)
		if distance < data.discover_distance:
			Journal.discover(data)
		if distance < data.shy_distance:
			_target = global_position + ranger.global_position.direction_to(global_position) * 64.0
			_state = State.SWIM
			speed *= 2.0

	if _state == State.REST:
		velocity = Vector2.ZERO
		_rest_left -= delta
		if _rest_left <= 0.0:
			_target = _pick_target()
			_state = State.SWIM
		return

	var to_target := _target - global_position
	if to_target.length() < 4.0:
		_state = State.REST
		_rest_left = randf_range(data.rest_min, data.rest_max)
		return
	velocity = to_target.normalized() * speed
	move_and_slide()
	_sprite.rotation = lerp_angle(_sprite.rotation, velocity.angle(), 0.1)
	# Blocked by land (e.g. fled towards the beach): rest, then pick somewhere else.
	if get_real_velocity().length() < 1.0:
		_state = State.REST
		_rest_left = data.rest_min


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
