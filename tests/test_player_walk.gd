extends SceneTree
## Walks the player right for 5 seconds: they must move, and must stop on land at the shore.
## Run: godot --headless --path . --script res://tests/test_player_walk.gd

const LAND := [Vector2i(1, 0), Vector2i(2, 0)]  # sand, grass atlas coords

var _world: Node
var _player: Node2D
var _frames := 0
var _animated := false


func _initialize() -> void:
	_world = load("res://scenes/world/ocean_world.tscn").instantiate()
	root.add_child(_world)
	_player = _world.get_node("Player")
	Input.action_press("move_right")


func _physics_process(_delta: float) -> bool:
	_frames += 1
	if _frames == 40:
		var look: Node2D = _player.get_node("Look")
		_animated = _player.walking and (look.position.y != 0.0 or look.rotation != 0.0)
	if _frames < 300:
		return false
	Input.action_release("move_right")
	var ground: TileMapLayer = _world.get_node("StarterIsland/Ground")
	var cell := ground.local_to_map(ground.to_local(_player.global_position))
	var on_land := ground.get_cell_atlas_coords(cell) in LAND
	var moved := _player.global_position.x > 200.0
	print("player at %s, cell %s, on land: %s" % [_player.global_position, cell, on_land])
	if not _animated:
		printerr("FAIL: expected the ranger to animate (bob and sway) while walking")
		quit(1)
	elif not (on_land and moved):
		printerr("FAIL: expected player to walk right and stop on land at the shore")
		quit(1)
	else:
		print("PASS")
		quit(0)
	return true
