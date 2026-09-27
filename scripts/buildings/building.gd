class_name Building
extends Node2D
## A building the player placed. Its top-left footprint tile is `cell`.
## Buildings with an action (e.g. the tent's "sleep") offer it when the ranger is close.

@export var data: BuildingData
@export var cell: Vector2i
@export var use_range := 56.0

@onready var _sprite: Sprite2D = $Sprite2D
@onready var _hint: Label = $Hint


func _enter_tree() -> void:
	add_to_group("buildings")


func _ready() -> void:
	position = Vector2(cell * Terrain.TILE) + Vector2(data.size * Terrain.TILE) / 2.0
	_sprite.texture = data.texture


## The footprint in tiles.
func rect() -> Rect2i:
	return Rect2i(cell, data.size)


func _process(_delta: float) -> void:
	_hint.visible = data.action != &"" and _ranger_in_range()
	if _hint.visible and data.action == &"sleep":
		_hint.text = "E / tap: sleep until morning" if GameClock.is_night() else "Rest here when it gets dark"


func _unhandled_input(event: InputEvent) -> void:
	if not _hint.visible:
		return
	var tapped := ControlledBody.is_tap(event) and get_global_mouse_position().distance_to(global_position) < 32.0
	if (tapped or event.is_action_pressed("interact")) and data.action == &"sleep" and GameClock.is_night():
		get_viewport().set_input_as_handled()
		get_tree().call_group("hud", "sleep_through_night")


func _ranger_in_range() -> bool:
	var ranger := ControlledBody.active(get_tree())
	return ranger is Player and ranger.global_position.distance_to(global_position) <= use_range
