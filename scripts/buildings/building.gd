class_name Building
extends Node2D
## A building the player placed. Its top-left footprint tile is `cell`.
## Buildings with an action (e.g. the tent's "sleep") offer it when the ranger is close.
## Visitor donations wait here (a bobbing coin) until the ranger walks up to collect them.

@export var data: BuildingData
@export var cell: Vector2i
@export var use_range := 56.0
## How close the ranger must come to collect waiting donations.
@export var collect_range := 72.0

## Visitor donations waiting to be collected here.
var pending_funds := 0
var _bob := 0.0

@onready var _sprite: Sprite2D = $Sprite2D
@onready var _hint: Label = $Hint
@onready var _coin: Sprite2D = $Coin


func _enter_tree() -> void:
	add_to_group("buildings")


func _ready() -> void:
	move_to(cell)
	_sprite.texture = data.texture
	if data.spawns:
		add_child(data.spawns.instantiate())
	_coin.visible = false


## Puts it with its top-left footprint tile at `new_cell`.
func move_to(new_cell: Vector2i) -> void:
	cell = new_cell
	position = Vector2(cell * Terrain.TILE) + Vector2(data.size * Terrain.TILE) / 2.0


## Whether the ranger (on foot) is standing next to it.
func ranger_is_near() -> bool:
	return _ranger_in_range(use_range)


func add_funds(amount: int) -> void:
	pending_funds += amount
	_coin.visible = pending_funds > 0


## Animals that belong here (not counting hatchlings heading out to sea).
func animals_here() -> int:
	return get_tree().get_nodes_in_group("animals").filter(
		func(a: Node) -> bool: return a.get("home_area") == self and not a.get("leaving")).size()


## How many more animals can join this area.
func room_for_animals() -> int:
	return maxi(data.animal_capacity - animals_here(), 0)


## The footprint in tiles.
func rect() -> Rect2i:
	return Rect2i(cell, data.size)


func _process(delta: float) -> void:
	if pending_funds > 0:
		_bob += delta
		_coin.position.y = -data.size.y * Terrain.TILE / 2.0 - 12.0 + roundf(sin(_bob * 3.0) * 2.0)
		if _ranger_in_range(collect_range):
			Funding.earn(pending_funds, "You collected the visitors' donations at your %s!" % data.display_name)
			pending_funds = 0
			_coin.visible = false
	var near := _ranger_in_range(use_range)
	_hint.visible = near and (data.action != &"" or data.animal_capacity > 0)
	if _hint.visible and data.action == &"sleep":
		_hint.text = "E / tap: sleep until morning" if GameClock.is_night() else "Rest here when it gets dark"
	elif _hint.visible:
		var here := animals_here()
		_hint.text = "Turtles here: %d / %d%s" % [here, data.animal_capacity,
			"  (full: new hatchlings swim out to sea)" if here >= data.animal_capacity else ""]


func _unhandled_input(event: InputEvent) -> void:
	if not _hint.visible:
		return
	var tapped := ControlledBody.is_tap(event) and get_global_mouse_position().distance_to(global_position) < 32.0
	if (tapped or event.is_action_pressed("interact")) and data.action == &"sleep" and GameClock.is_night():
		get_viewport().set_input_as_handled()
		get_tree().call_group("hud", "sleep_through_night")


func _ranger_in_range(distance: float) -> bool:
	var ranger := ControlledBody.active(get_tree())
	return ranger is Player and ranger.global_position.distance_to(global_position) <= distance
