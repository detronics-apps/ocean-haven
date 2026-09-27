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
	position = Vector2(cell * Terrain.TILE) + Vector2(data.size * Terrain.TILE) / 2.0
	_sprite.texture = data.texture
	if data.spawns:
		add_child(data.spawns.instantiate())
	_coin.visible = false


func add_funds(amount: int) -> void:
	pending_funds += amount
	_coin.visible = pending_funds > 0


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
	_hint.visible = data.action != &"" and _ranger_in_range(use_range)
	if _hint.visible and data.action == &"sleep":
		_hint.text = "E / tap: sleep until morning" if GameClock.is_night() else "Rest here when it gets dark"


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
