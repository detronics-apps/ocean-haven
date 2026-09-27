extends SceneTree
## Turtle: wanders without touching land or straying from home; is discovered;
## swims off when the ranger rushes at it; relaxes when the ranger stays still,
## then can be freed from fishing line, observed and photographed — never fleeing
## from a calm ranger.
## Run: godot --headless --path . --script res://tests/test_turtle.gd --quit-after 100000

var _failed := false


func _initialize() -> void:
	await process_frame
	var journal := root.get_node("Journal")  # autoloads: looked up at runtime
	var inventory := root.get_node("Inventory")
	var world: Node = load("res://scenes/world/ocean_world.tscn").instantiate()
	root.add_child(world)
	var turtle: Node2D = world.get_node("GreenTurtle")  # untyped: Animal uses autoloads
	var player: Node2D = world.get_node("Player")
	var home := turtle.global_position
	_expect(turtle.tangled, "starts tangled in fishing line")

	# --- Wanders for 10 s, always in water, near home ---
	var moved := false
	for i in 600:
		await physics_frame
		if turtle.call("_is_land", turtle.global_position):
			_expect(false, "stayed in the water (was on land at %s)" % turtle.global_position)
			break
		if turtle.global_position.distance_to(home) > 140.0 + 70.0:
			_expect(false, "stayed near home (strayed to %s)" % turtle.global_position)
			break
		moved = moved or turtle.global_position.distance_to(home) > 8.0
	_expect(moved, "swims around")

	# --- Rushing at it: it swims off ---
	var start := turtle.global_position + Vector2(120, 0)
	player.global_position = start
	for i in 10:
		await physics_frame  # arrive (a jump, so not counted as rushing)
	var gap_when_close := 0.0
	for i in 60:
		player.global_position = player.global_position.move_toward(turtle.global_position, 3.0)  # 180 px/s
		await physics_frame
		if player.global_position.distance_to(turtle.global_position) < 40.0:
			gap_when_close = player.global_position.distance_to(turtle.global_position)
			break
	for i in 45:
		await physics_frame
	_expect(journal.has(&"green_turtle"), "discovered")
	_expect(turtle.global_position.distance_to(player.global_position) > gap_when_close + 20.0,
		"swims off when rushed")

	# --- Staying still nearby: it relaxes and can be helped ---
	player.global_position = turtle.global_position + Vector2(400, 0)  # step well away
	for i in 150:
		await physics_frame  # let it finish fleeing
	# Arrive in one jump (like boarding), so the turtle doesn't see it as rushing.
	player.global_position = turtle.global_position + Vector2(50, 0)
	var calm_start := player.global_position.distance_to(turtle.global_position)
	for i in 150:
		await physics_frame
	_expect(turtle.is_relaxed(), "relaxes when the ranger stays still")
	_expect(turtle.global_position.distance_to(player.global_position) <= calm_start + 4.0,
		"doesn't flee from a calm ranger")
	_interact()
	for i in 5:
		await physics_frame
	_expect(not turtle.tangled, "freed from the fishing line")
	_expect(inventory.count(&"fishing_line") == 1, "the line goes into the inventory")
	_expect(journal.helped_count(&"green_turtle") == 1, "help recorded in the journal")
	for i in 260:
		await physics_frame  # quiet watching
	_expect(journal.has_observed(&"green_turtle"), "observed after watching quietly")
	_interact()
	for i in 5:
		await physics_frame
	_expect(journal.photos(&"green_turtle") == 1, "photo taken")

	if not _failed:
		print("PASS")
	quit(1 if _failed else 0)


func _interact() -> void:
	var e := InputEventAction.new()
	e.action = &"interact"
	e.pressed = true
	Input.parse_input_event(e)


func _expect(ok: bool, what: String) -> void:
	print("%s: %s" % [what, "ok" if ok else "FAILED"])
	_failed = _failed or not ok
