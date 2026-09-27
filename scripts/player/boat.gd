class_name Boat
extends ControlledBody
## The ranger's boat: board it from the shore, sail on water, go ashore next to land.
## Board / go ashore with the interact action or by tapping the boat.

@export var board_range := 48.0

var _player: Player
var _driver: Node2D

@onready var _camera: Camera2D = $Camera2D
@onready var _hint: Label = $Hint


func _ready() -> void:
	_player = get_tree().get_first_node_in_group("player")


func _unhandled_input(event: InputEvent) -> void:
	var tapped_boat := is_tap(event) and get_global_mouse_position().distance_to(global_position) < 20.0
	if (tapped_boat or event.is_action_pressed("interact")) and _toggle():
		get_viewport().set_input_as_handled()
		return
	super(event)


func _process(_delta: float) -> void:
	if controlled:
		_hint.text = "E / tap boat: go ashore"
		_hint.visible = _shore_spot() != null
	else:
		_hint.text = "E / tap boat: board"
		_hint.visible = _player_in_range()


func _toggle() -> bool:
	return _go_ashore() if controlled else _board()


func _board() -> bool:
	if not _player_in_range():
		return false
	_player.set_aboard(true)
	# Show the ranger (with their current look) sitting in the boat, behind the hull.
	_driver = _player.get_node("Look").duplicate()
	_driver.position = Vector2(-2, 2)
	_look.add_child(_driver)
	_look.move_child(_driver, 0)
	controlled = true
	_camera.make_current()
	return true


func _go_ashore() -> bool:
	var spot: Variant = _shore_spot()
	if spot == null:
		return false
	stop()
	controlled = false
	_driver.queue_free()
	_player.global_position = spot
	_player.set_aboard(false)
	return true


func _player_in_range() -> bool:
	return _player.visible and _player.global_position.distance_to(global_position) <= board_range


## Centre of the nearest walkable tile touching the boat, or null if none.
func _shore_spot() -> Variant:
	var best: Variant = null
	for ground: TileMapLayer in get_tree().get_nodes_in_group("ground"):
		var here := ground.local_to_map(ground.to_local(global_position))
		for dy in range(-1, 2):
			for dx in range(-1, 2):
				var cell := here + Vector2i(dx, dy)
				var data := ground.get_cell_tile_data(cell)
				if data and data.get_custom_data("walkable"):
					var pos := ground.to_global(ground.map_to_local(cell))
					if best == null or pos.distance_to(global_position) < (best as Vector2).distance_to(global_position):
						best = pos
	return best
