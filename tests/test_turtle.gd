extends SceneTree
## Turtle wanders for 10 s without ever touching land or straying from home;
## then the ranger comes close: the turtle is discovered and swims away.
## Run: godot --headless --path . --script res://tests/test_turtle.gd

var _world: Node
var _turtle: Node2D  # untyped: Animal uses autoloads
var _home: Vector2
var _frames := 0
var _moved := false
var _ranger_start_gap := 0.0


func _initialize() -> void:
	_world = load("res://scenes/world/ocean_world.tscn").instantiate()
	root.add_child(_world)
	_turtle = _world.get_node("GreenTurtle")
	_home = _turtle.global_position


func _physics_process(_delta: float) -> bool:
	_frames += 1
	if _frames <= 600:
		if _turtle.call("_is_land", _turtle.global_position):
			return _fail("turtle went onto land at %s" % _turtle.global_position)
		if _turtle.global_position.distance_to(_home) > 140.0 + 70.0:
			return _fail("turtle strayed from home: %s" % _turtle.global_position)
		_moved = _moved or _turtle.global_position.distance_to(_home) > 8.0
		return false
	if _frames == 601:
		if not _moved:
			return _fail("turtle never swam")
		# Ranger walks up (teleported onto the water next to the turtle).
		var player: Node2D = _world.get_node("Player")
		player.global_position = _turtle.global_position + Vector2(30, 0)
		_ranger_start_gap = 30.0
		return false
	if _frames == 660:
		var player: Node2D = _world.get_node("Player")
		var gap := _turtle.global_position.distance_to(player.global_position)
		if not root.get_node("Journal").has(&"green_turtle"):
			return _fail("turtle was not discovered")
		if gap <= _ranger_start_gap + 20.0:
			return _fail("turtle did not swim away (gap %.1f)" % gap)
		print("PASS")
		quit(0)
		return true
	return false


func _fail(why: String) -> bool:
	printerr("FAIL: " + why)
	quit(1)
	return true
