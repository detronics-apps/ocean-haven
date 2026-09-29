class_name Boat
extends ControlledBody
## The ranger's boat: board it from the shore, sail on water, go ashore next to land.
## Board / go ashore with the interact action or by tapping the boat.

@export var board_range := 64.0

var _player: Player
var _driver: Node2D
var _warned_far := false

@onready var _camera: Camera2D = $Camera2D
@onready var _hint: Label = $Hint


func _ready() -> void:
	add_to_group("boat")
	add_to_group("interactables")
	_player = get_tree().get_first_node_in_group("player")
	RangerProfile.look_changed.connect(_apply_colour)
	_apply_colour()


func _apply_colour() -> void:
	$Look/Hull.modulate = RangerProfile.pick("boat")


func _unhandled_input(event: InputEvent) -> void:
	var tapped_boat := is_tap(event) and get_global_mouse_position().distance_to(global_position) < 20.0
	if (tapped_boat or event.is_action_pressed("interact")) and _toggle():
		get_viewport().set_input_as_handled()
		return
	super(event)


## The rowboat is a small coastal boat: past its region's waters it turns back.
func _physics_process(delta: float) -> void:
	super(delta)
	if not controlled:
		return
	var region := Regions.nearest(global_position)
	var from_centre := global_position - region.center
	if from_centre.length() > region.waters_radius:
		global_position = region.center + from_centre.limit_length(region.waters_radius)
		stop()
		if not _warned_far:
			_warned_far = true
			get_tree().call_group("hud", "show_toast",
				"This little boat can't go that far.\nBuild an Exploration Ship at your dock to discover other islands.")
	elif from_centre.length() < region.waters_radius - 150.0:
		_warned_far = false


func _process(_delta: float) -> void:
	if controlled:
		_hint.text = "E / tap boat: go ashore"
		_hint.visible = _shore_spot() != null
	else:
		_hint.text = "E / tap boat: board"
		_hint.visible = _player_in_range()


## What the ranger can do with the boat right now, for the action bar: [{label, do}].
func actions() -> Array:
	if controlled and _shore_spot() != null:
		return [{"label": "Go ashore", "do": _go_ashore}]
	if not controlled and _player_in_range() and _nearest_boat():
		return [{"label": "Board boat", "do": _board}]
	return []


func _toggle() -> bool:
	return _go_ashore() if controlled else _board()


## Puts the ranger in the boat without the range check (loading a save).
func restore_aboard() -> void:
	if not controlled:
		_board(false)


func _board(check_range := true) -> bool:
	if check_range and (not _player_in_range() or not _nearest_boat()):
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
	restore_ashore()
	_player.global_position = spot
	return true


## Takes the ranger out of the boat right where it is (e.g. setting off on a voyage).
func restore_ashore() -> void:
	if not controlled:
		return
	stop()
	controlled = false
	_driver.queue_free()
	_player.set_aboard(false)


## With several boats in reach, the ranger boards the nearest one.
func _nearest_boat() -> bool:
	var mine := _player.global_position.distance_to(global_position)
	for boat: Boat in get_tree().get_nodes_in_group("boat"):
		if boat != self and not boat.controlled and boat._player_in_range() \
				and _player.global_position.distance_to(boat.global_position) < mine:
			return false
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
